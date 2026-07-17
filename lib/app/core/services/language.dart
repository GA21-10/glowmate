// ─────────────────────────────────────────────
// app/core/services/language.dart
// ─────────────────────────────────────────────
//
// Deteksi bahasa default aplikasi (KETENTUAN #3):
//   "bahasa akan secara otomatis berganti ketika pertama kali login
//    ke aplikasi berdasarkan lokasi/GPS. Jika lokasi/GPS tidak
//    mendeteksi, maka defaultnya bahasa Amerika Serikat."
//
// Dua lapis deteksi, dipanggil berurutan oleh `LanguageProvider._safeDetect()`:
//
//   LAPIS 1 — GPS FISIK (`detectViaGps`)
//     Pakai `geolocator` untuk ambil koordinat asli perangkat, lalu
//     `geocoding` untuk reverse-geocode koordinat itu ke kode negara
//     (ISO). Ini yang dimaksud "lokasi/GPS" di ketentuan #3. Minta
//     izin lokasi ke pengguna; kalau servis lokasi mati, izin
//     ditolak, timeout, atau reverse-geocode gagal → method ini
//     mengembalikan `null` (BUKAN melempar error), supaya provider
//     otomatis lanjut ke lapis berikutnya.
//
//   LAPIS 2 — REGION SISTEM (`detectDefaultLanguageCode`)
//     Fallback kalau GPS tidak tersedia/ditolak: baca region locale
//     yang tertera di sistem perangkat (tanpa perlu izin apa pun).
//     Instan dan selalu tersedia.
//
//   LAPIS 3 — DEFAULT AMERIKA SERIKAT
//     Kalau lapis 1 & 2 sama-sama gagal mendeteksi apa pun →
//     `kDefaultLanguageCode` ("en"), sesuai ketentuan #3.
//
// Alur detail LAPIS 2 (`detectDefaultLanguageCode`):
//   1. Baca locale sistem (mis. "id_ID", "en_US", "ja_JP").
//   2. Ambil kode region/negaranya (mis. "ID", "US", "JP").
//   3. Cocokkan ke `kLanguageByCountryIso` (models/language.dart)
//      untuk dapat kode bahasa.
//   4. Kalau region tidak dikenali, coba cocokkan langsung kode
//      bahasa sistem (mis. locale "id" tanpa region) ke salah satu
//      dari 17 bahasa yang didukung.
//   5. Kalau tetap tidak ketemu → fallback ke `kDefaultLanguageCode`.
//
// ── SETUP WAJIB DI LUAR FILE INI ──────────────────────────────────
// Package `geolocator` butuh izin lokasi terdaftar di native project:
//
//   android/app/src/main/AndroidManifest.xml (di dalam <manifest>, di
//   atas tag <application>):
//     <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//     <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//
//   ios/Runner/Info.plist (di dalam <dict> utama):
//     <key>NSLocationWhenInUseUsageDescription</key>
//     <string>GlowMate menggunakan lokasi untuk menyesuaikan bahasa aplikasi secara otomatis.</string>
//
// Tanpa entri ini, permintaan izin lokasi akan gagal/crash di
// masing-masing platform — `detectViaGps()` sudah dibungkus try-catch
// jadi tidak akan meng-crash APLIKASI, tapi tetap akan selalu jatuh
// ke LAPIS 2 kalau native permission belum didaftarkan.
// ─────────────────────────────────────────────

import 'dart:async';
import 'dart:ui' as ui;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/language.dart';

class LanguageService {
  const LanguageService();

  /// Batas waktu tunggu untuk lapis deteksi GPS (posisi + reverse
  /// geocode digabung). Dijaga singkat supaya start-up aplikasi tidak
  /// terasa lambat kalau sinyal lokasi buruk — begitu timeout, provider
  /// otomatis jatuh ke deteksi region sistem (LAPIS 2).
  static final Geocoding _geocoding = Geocoding();

  static const Duration _gpsTimeout = Duration(seconds: 8);

  Future<String?> detectViaGps() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: _gpsTimeout,
        ),
      ).timeout(_gpsTimeout);

      // ── PERUBAHAN DI SINI ──
      final placemarks = await _geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(_gpsTimeout);

      if (placemarks.isEmpty) return null;

      final iso = placemarks.first.isoCountryCode;
      if (iso == null || iso.isEmpty) return null;

      return kLanguageByCountryIso[iso.toUpperCase()];
    } catch (_) {
      return null;
    }
  }

  /// LAPIS 2 — Deteksi kode bahasa dari region/locale sistem
  /// perangkat. Dipanggil oleh `LanguageProvider._safeDetect()` HANYA
  /// bila LAPIS 1 (`detectViaGps`) gagal/tidak tersedia.
  /// SELALU mengembalikan kode bahasa yang valid (tidak pernah null)
  /// — fallback otomatis ke [kDefaultLanguageCode] (English/US) bila
  /// region sistem tidak terdeteksi atau tidak dikenali.
  String detectDefaultLanguageCode() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      final regionCode = systemLocale.countryCode;

      if (regionCode != null && regionCode.isNotEmpty) {
        final matched = kLanguageByCountryIso[regionCode.toUpperCase()];
        if (matched != null) return matched;
      }

      // Fallback kedua: region tidak ada, tapi kode bahasa sistem
      // (mis. locale "id" tanpa region) cocok dengan salah satu dari
      // 17 bahasa yang didukung aplikasi.
      final langCode = systemLocale.languageCode;
      final isSupported = kSupportedLanguages.any((l) => l.code == langCode);
      if (isSupported) return langCode;
    } catch (_) {
      // Diamkan — lanjut ke fallback default di bawah.
    }

    // Fallback terakhir sesuai ketentuan: Amerika Serikat (English).
    return kDefaultLanguageCode;
  }

  /// Deteksi kode ISO negara default dari region sistem (opsional —
  /// berguna kalau ada UI lain, mis. form alamat, yang ingin auto-set
  /// field "Negara" konsisten dengan bahasa yang terdeteksi). Tidak
  /// bergantung pada daftar negara manapun — mengembalikan kode
  /// region mentah dari sistem, atau [kDefaultCountryIso] ("US") bila
  /// tidak terdeteksi.
  String detectDefaultCountryIso() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      final regionCode = systemLocale.countryCode;
      if (regionCode != null && regionCode.isNotEmpty) {
        return regionCode.toUpperCase();
      }
    } catch (_) {
      // Diamkan — lanjut ke fallback default di bawah.
    }
    return kDefaultCountryIso;
  }

  /// Helper: [LanguageInfo] lengkap untuk bahasa default hasil deteksi.
  LanguageInfo detectDefaultLanguage() => languageByCode(detectDefaultLanguageCode());
}