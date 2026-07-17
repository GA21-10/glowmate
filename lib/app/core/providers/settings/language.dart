// ─────────────────────────────────────────────
// app/core/providers/settings/language.dart
// ─────────────────────────────────────────────
//
// Provider untuk mengelola bahasa aktif aplikasi. Mengikat 3
// ketentuan bahasa:
//
//   1. 17 bahasa didukung — lihat `kSupportedLanguages`
//      (app/core/models/language.dart).
//   2. Bahasa aktif otomatis berganti di SELURUH aplikasi begitu
//      diubah dari halaman Pengaturan — cukup panggil `setLanguage()`,
//      semua widget yang memakai `context.watch<LanguageProvider>()`
//      atau `context.tr()` otomatis rebuild ke bahasa baru.
//   3. Saat PERTAMA KALI login/buka aplikasi (belum ada preferensi
//      tersimpan) → bahasa ditebak otomatis dari LOKASI GPS FISIK
//      perangkat (lihat `LanguageService.detectViaGps()`, pakai
//      `geolocator` + `geocoding`). Kalau GPS tidak tersedia/izin
//      ditolak/timeout → coba tebak dari region locale sistem
//      (`detectDefaultLanguageCode()`). Kalau itu pun gagal → default
//      ke Amerika Serikat (English/"en"). Lihat `_safeDetect()` di
//      bawah untuk urutan 3 lapis ini. Begitu pengguna memilih bahasa
//      manual lewat Pengaturan, pilihan itu disimpan permanen
//      (SharedPreferences) dan TIDAK PERNAH ditimpa lagi oleh deteksi
//      otomatis di sesi-sesi berikutnya.
//
//   4. Bahasa RTL (mis. Arab, "ar") TIDAK membalik layout UI secara
//      keseluruhan. `isRtl` di bawah HANYA dipakai untuk menentukan
//      arah baca TEKS per widget (lihat `AppText`/`context.trText()`
//      di l10n.dart) — posisi/alignment elemen UI tetap LTR di
//      seluruh aplikasi. JANGAN bungkus `MaterialApp` dengan
//      `Directionality(textDirection: isRtl ? TextDirection.rtl : ...)`
//      karena itu akan membalik seluruh UI (nav bar, ikon, alignment),
//      bukan cuma tulisannya.
//
// Pemakaian di UI:
//   final langProvider = context.watch<LanguageProvider>();
//   langProvider.current      // LanguageInfo aktif
//   langProvider.supported    // daftar 17 bahasa yang bisa dipilih
//   langProvider.setLanguage('id')
//
// Untuk teks aplikasi, pakai:
//   context.tr('settings_title')   // lihat app/core/swich/l10n.dart
//
// Wiring di main.dart (WAJIB load() sebelum runApp, supaya bahasa
// hasil deteksi/tersimpan sudah siap sejak frame pertama):
//
//   final languageProvider = LanguageProvider();
//   await languageProvider.load();
//
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider.value(value: languageProvider),
//         ...
//       ],
//       child: const MyApp(),
//     ),
//   );
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/language.dart';
import '../../services/language.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider({LanguageService? service})
      : _service = service ?? const LanguageService();

  static const _prefsKey = 'app_language_code';

  final LanguageService _service;

  LanguageInfo _current = kDefaultLanguage;
  bool _isLoading = true;
  bool _isAutoDetected = false; // true = nilai saat ini hasil auto-deteksi (belum pernah dipilih manual)

  /// Bahasa yang sedang aktif.
  LanguageInfo get current => _current;

  /// Kode bahasa aktif, mis. "id", "en".
  String get languageCode => _current.code;

  /// `Locale` Flutter yang sesuai (dipakai di `MaterialApp.locale`).
  Locale get locale {
    final parts = _current.code.split('-');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  /// true bila bahasa aktif ditulis kanan-ke-kiri (mis. Arab).
  ///
  /// PENTING (ketentuan #4): dipakai HANYA untuk arah baca teks per
  /// widget lewat `AppText` / `context.trText()` (lihat l10n.dart) —
  /// BUKAN untuk membungkus seluruh `MaterialApp` dalam
  /// `Directionality.rtl`. Posisi & alignment UI aplikasi tetap LTR
  /// untuk semua bahasa; yang berubah arah hanya urutan huruf/angka
  /// di dalam teks itu sendiri, di posisi yang sama.
  bool get isRtl => _rtlLanguageCodes.contains(_current.code);

  /// Semua bahasa yang bisa dipilih pengguna (17 bahasa).
  List<LanguageInfo> get supported => kSupportedLanguages;

  bool get isLoading => _isLoading;

  /// true bila bahasa saat ini masih hasil auto-deteksi lokasi/region
  /// sistem (pengguna belum pernah memilih bahasa secara manual).
  bool get isAutoDetected => _isAutoDetected;

  /// Dipanggil SEKALI saat aplikasi start / pertama kali login (lihat
  /// contoh wiring di atas — sebelum `runApp`). Membaca pilihan
  /// tersimpan; kalau belum ada (login pertama kali), deteksi
  /// otomatis dari lokasi/region sistem, fallback ke Amerika Serikat
  /// (English) bila gagal total.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefsKey);

      if (savedCode != null && savedCode.isNotEmpty) {
        // KETENTUAN #3 (bagian kedua): pengguna sudah pernah memilih
        // bahasa manual sebelumnya → itu yang terus dipakai, tidak
        // dideteksi ulang dari lokasi.
        _current = languageByCode(savedCode);
        _isAutoDetected = false;
      } else {
        // KETENTUAN #3 (bagian pertama): belum ada pilihan manual
        // (mis. login pertama kali) → deteksi otomatis dari
        // lokasi/region sistem.
        final detectedCode = await _safeDetect();
        _current = languageByCode(detectedCode);
        _isAutoDetected = true;
      }
    } catch (_) {
      // Gagal total (mis. SharedPreferences error) → fallback aman ke
      // Amerika Serikat (English), sesuai ketentuan.
      _current = kDefaultLanguage;
      _isAutoDetected = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Ganti bahasa aktif secara manual (dipanggil dari pemilih bahasa
  /// di halaman Pengaturan). KETENTUAN #2: seluruh aplikasi langsung
  /// mengikuti bahasa baru ini lewat `notifyListeners()`. Pilihan ini
  /// juga disimpan permanen dan tidak akan ditimpa lagi oleh deteksi
  /// otomatis (KETENTUAN #3).
  Future<void> setLanguage(String? code) async {
    if (code == null || code.trim().isEmpty) return;

    final next = languageByCode(code);
    // Sudah aktif & sudah tersimpan manual → tidak perlu apa-apa.
    if (next.code == _current.code && !_isAutoDetected) return;

    _current = next;
    _isAutoDetected = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.code);
    } catch (_) {
      // Simpan gagal (jarang terjadi) — bahasa tetap berubah di sesi
      // ini, hanya tidak persist ke sesi berikutnya.
    }
  }

  /// Reset ke deteksi otomatis (hapus preferensi manual tersimpan).
  /// Bisa dipakai untuk tombol opsional "Gunakan bahasa sistem" di
  /// halaman Pengaturan.
  Future<void> resetToAutoDetect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {
      // Diamkan — tetap lanjut set state in-memory ke auto-detect.
    }

    final detectedCode = await _safeDetect();
    _current = languageByCode(detectedCode);
    _isAutoDetected = true;
    notifyListeners();
  }

  /// Deteksi bahasa default, 3 lapis, sesuai KETENTUAN #3:
  ///
  ///   LAPIS 1 — GPS fisik (`_service.detectViaGps()`): posisi asli
  ///             perangkat direverse-geocode ke negara. Ini yang
  ///             dimaksud "lokasi/GPS" pada ketentuan.
  ///   LAPIS 2 — Region locale sistem (`_service.detectDefaultLanguageCode()`):
  ///             dipakai HANYA kalau GPS gagal/ditolak/servis lokasi
  ///             mati/timeout — supaya tetap ada tebakan yang masuk
  ///             akal sebelum jatuh ke default.
  ///   LAPIS 3 — `kDefaultLanguageCode` (en/US): dipakai kalau LAPIS 1
  ///             & LAPIS 2 sama-sama tidak berhasil mendeteksi apa
  ///             pun — sesuai ketentuan "jika lokasi/GPS tidak
  ///             terdeteksi, default ke Amerika Serikat".
  ///
  /// Seluruh lapis dibungkus try-catch berlapis supaya error apa pun
  /// (permission plugin belum terdaftar, servis lokasi mati, region
  /// tidak dikenali, dsb) TIDAK PERNAH membuat provider crash.
  Future<String> _safeDetect() async {
    // LAPIS 1 — GPS fisik.
    try {
      final gpsCode = await _service.detectViaGps();
      if (gpsCode != null && gpsCode.isNotEmpty) return gpsCode;
    } catch (_) {
      // Diamkan — lanjut ke LAPIS 2.
    }

    // LAPIS 2 — Region sistem (locale perangkat, tanpa perlu izin).
    try {
      final localeCode = _service.detectDefaultLanguageCode();
      if (localeCode.isNotEmpty) return localeCode;
    } catch (_) {
      // Diamkan — lanjut ke LAPIS 3.
    }

    // LAPIS 3 — Default Amerika Serikat (English), sesuai ketentuan.
    return kDefaultLanguageCode;
  }
}

/// Daftar kode bahasa RTL (ditulis kanan-ke-kiri). Diduplikasi minimal
/// di sini secara sengaja supaya provider ini tidak perlu bergantung
/// pada layer terjemahan (`app_translations.dart`) — satu-satunya
/// sumber kebenaran lain tetap `AppTranslations.rtlLanguageCodes` di
/// app/core/swich/trans.dart.
const Set<String> _rtlLanguageCodes = {'ar'};