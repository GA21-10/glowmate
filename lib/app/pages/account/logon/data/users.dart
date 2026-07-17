// ─────────────────────────────────────────────
// app/profile/profile_setup_page.dart
// ─────────────────────────────────────────────
//
// PEMBARUAN PADA VERSI INI:
//  1. UI responsif & berbeda per platform:
//       • Android / iOS   → satu kolom, lebar mengikuti layar (mobile).
//       • Web  (lebar<900)→ satu kolom seperti tablet.
//       • Web / Desktop (lebar>=900) → dua kolom (panel "kertas" di
//         tengah, kartu Alamat & No. Telepon berdampingan) — lihat
//         `_ResponsiveBody`.
//  2. Foto profil konsisten 100% di Android/iOS/Web/Desktop — lihat
//     `user_avatar.dart` (Image.network + loading/error builder) dan
//     `_buildAvatar()` di bawah: prioritas foto SELALU →
//       (a) foto baru yang baru saja dipilih pengguna (jika ada), lalu
//       (b) foto tersimpan (dari Google/gmail ATAU upload sebelumnya)
//           jika tidak dihapus, lalu
//       (c) tidak ada foto → ikon default.
//     Saat "Simpan", foto yang tampil TERAKHIR itulah yang disimpan
//     (baik dari kosong→ada, atau gmail→diganti pengguna).
//  3. Alamat: mengetik Nama Jalan (+No. Rumah) akan mencoba
//     auto-mengisi RT/RW/Kelurahan/Kecamatan/Kota/Provinsi/Kode Pos
//     (khusus Indonesia) — semua tetap BISA diedit manual. Untuk
//     negara luar, field disesuaikan menjadi: Address Line 1,
//     Address Line 2, City, State/Province/Region, ZIP, Country.
//     Default alamat diisi dari GPS/lokasi (lihat `_detectLocation`);
//     jika GPS tidak terdeteksi, pengguna WAJIB memilih Negara secara
//     manual sebelum bisa menyimpan. Kode dial TIDAK ditampilkan lagi
//     di tombol pilih Negara pada form Alamat.
//  4. Negara pada Alamat otomatis menyinkronkan bendera & kode negara
//     pada No. Telepon secara real-time (masih bisa diedit manual —
//     begitu diedit manual, sinkronisasi otomatis berhenti sampai
//     Negara Alamat diganti lagi). Field No. Telepon hanya menerima
//     angka, dengan contoh & batas panjang sesuai negara terpilih.
//  5. Tipe kulit: daftar diperluas termasuk kulit Albino & kulit
//     Hitam (lihat catatan di `_skinTypeIconFor` — daftar 15 tipe
//     harus ditambahkan ke `core/models/users/global.dart`, karena
//     enum SkinType didefinisikan di sana).
//  6. Tombol "Simpan & Lanjutkan" sekarang membuka pop-up (di tengah
//     layar) untuk verifikasi OTP — bisa dikirim ke Gmail atau No.
//     Telepon (nama/nomor ditampilkan) — lalu lanjut ke halaman OTP
//     (`otp_verification_page.dart`).
//  7. PERBAIKAN BUG (root cause crash "Unexpected null value" saat
//     jalan di Web): paket `geocoding` (Baseflow) HANYA punya platform
//     implementation resmi untuk Android, iOS, dan macOS. Di Web,
//     Windows, dan Linux belum ada implementasinya — memanggil
//     `Geocoding()` di platform itu melempar null-check exception saat
//     runtime karena `GeocodingPlatform.instance` masih null. Sekarang
//     instance-nya dibuat lazy & selalu dicek dulu lewat
//     `_geocodingSupported` (lihat `_geocoder` getter di bawah) —
//     di platform yang tidak didukung, app langsung fallback ke alur
//     "pilih Negara manual" yang memang sudah ada, tanpa pernah
//     menyentuh package geocoding sama sekali.
// ─────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glowmate/app/pages/account/logon/data/witgets/contries.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// ⚠️ WAJIB: paket lokasi berikut HARUS ada di pubspec.yaml (versi yang
// dipakai project ini: geolocator 14.x & geocoding 5.x — KEDUANYA
// punya breaking change dari versi lama, sudah disesuaikan di kode
// bawah ini):
//
//   dependencies:
//     geolocator: ^14.0.3
//     geocoding: ^5.0.0
//
// • geocoding 5.0.0 : fungsi top-level `placemarkFromCoordinates(...)`
//   DIHAPUS — sekarang wajib lewat instance `Geocoding()` (lihat
//   getter `_geocoder` di bawah).
// • geocoding hanya mendukung Android / iOS / macOS secara resmi —
//   TIDAK ada implementasi untuk Web / Windows / Linux, karena itu
//   semua pemakaiannya di file ini dijaga oleh `_geocodingSupported`.
// • geolocator 14.x : parameter `desiredAccuracy` pada
//   `getCurrentPosition()` sudah deprecated — diganti `locationSettings:
//   LocationSettings(accuracy: ...)`.
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../../../../core/models/users/global.dart';
import '../../../../core/providers/user/users.dart';
import '../../../widgets/routes/app.dart';
import '../otp/password.dart';
import 'avatar.dart';

const List<String> _bulanList = [
  'Januari', 'Februari', 'Maret', 'April',
  'Mei', 'Juni', 'Juli', 'Agustus',
  'September', 'Oktober', 'November', 'Desember',
];

// ── Platform helper ───────────────────────────
bool get _isMobileNative {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get _isDesktopNative {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// true untuk Web ATAU Desktop (dipakai untuk memilih tata-letak lebar
/// / 2-kolom, dan gaya pemilih foto "Pilih Foto" tanpa opsi kamera).
bool get _isWebOrDesktop => kIsWeb || _isDesktopNative;

/// true HANYA jika platform saat ini punya implementasi resmi paket
/// `geocoding` (Android / iOS / macOS). Web, Windows, dan Linux belum
/// didukung oleh package ini — jangan pernah construct `Geocoding()`
/// atau memanggil method-nya di luar platform ini.
bool get _geocodingSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// ── Ikon tipe kulit — dicocokkan lewat NAMA enum (t.name), bukan
//    referensi langsung ke value enum. Ini supaya file ini tetap bisa
//    dikompilasi walau `SkinType` di core/models/users/global.dart
//    belum / sudah ditambah 15 tipe (termasuk albino & kulit hitam).
//    Lihat catatan lengkap yang menyertai jawaban ini untuk snippet
//    yang perlu ditambahkan ke global.dart.
const Map<String, IconData> _skinTypeIconsByName = {
  'normal': Icons.face_outlined,
  'jerawat': Icons.grain,
  'kusam': Icons.blur_on,
  'berminyak': Icons.opacity,
  'kering': Icons.grain_outlined,
  'sensitif': Icons.warning_amber_outlined,
  'kombinasi': Icons.blur_circular,
  'albino': Icons.brightness_7_outlined,
  'kulitHitam': Icons.dark_mode_outlined,
  'komedo': Icons.scatter_plot_outlined,
  'poriBesar': Icons.grid_on_outlined,
  'flek': Icons.gradient_outlined,
  'hiperpigmentasi': Icons.contrast_outlined,
  'kerutan': Icons.waves_outlined,
  'kantungMata': Icons.visibility_outlined,
  'kemerahan': Icons.local_fire_department_outlined,
  'bekasLuka': Icons.healing_outlined,
  'kulitMengelupas': Icons.layers_clear_outlined,
  'milia': Icons.circle_outlined,
  'dermatitis': Icons.coronavirus_outlined,
  'rosacea': Icons.whatshot_outlined,
};

IconData _skinTypeIconFor(SkinType t) =>
    _skinTypeIconsByName[t.name] ?? Icons.circle_outlined;

// ── Formatter input ────────────────────────────
/// Hanya angka (dipakai untuk RT, RW, Kode Pos/ZIP, No. Telepon).
final _digitsOnlyFormatter = FilteringTextInputFormatter.digitsOnly;

/// Hanya huruf, spasi, dan tanda baca umum nama tempat
/// (dipakai untuk Kota, Provinsi, Kelurahan, Kecamatan, State/Region).
final _lettersOnlyFormatter =
FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\u00C0-\u024F\s.'-]"));

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  // PEMBARUAN — geocoding v5.0.0 (breaking change): fungsi top-level
  // `placemarkFromCoordinates(...)` DIHAPUS, diganti jadi method dari
  // instance `Geocoding()`. Nama variabel sengaja `_geocoder` (BUKAN
  // `geocoding`) supaya tidak bentrok dengan alias import
  // `import 'package:geocoding/geocoding.dart' as geocoding;` di atas.
  //
  // PERBAIKAN BUG: instance ini TIDAK dibuat eager sebagai field
  // initializer lagi (itu penyebab crash di Web — lihat catatan di
  // atas file). Sekarang dibuat lazy lewat getter `_geocoder`, dan
  // HANYA jika `_geocodingSupported` true. Di platform yang tidak
  // didukung, getter ini mengembalikan `null` dan semua pemanggilnya
  // sudah menjaga (guard) hal itu terlebih dahulu.
  geocoding.Geocoding? _geocoderInstance;

  geocoding.Geocoding? get _geocoder {
    if (!_geocodingSupported) return null;
    return _geocoderInstance ??= geocoding.Geocoding();
  }

  late TextEditingController _nameCtrl;

  // ── Alamat — umum ────────────────────────────
  late TextEditingController _streetCtrl;      // Nama Jalan / Address Line 1
  late TextEditingController _unitCtrl;        // Blok/No/Unit / Address Line 2
  late TextEditingController _cityCtrl;
  late TextEditingController _provinceCtrl;    // Provinsi / State-Province-Region
  late TextEditingController _postalCtrl;      // Kode Pos / ZIP

  /// null = negara BELUM ditentukan (GPS gagal & pengguna belum
  /// memilih manual). Wajib terisi sebelum bisa Simpan.
  String? _countryIso;

  // ── Alamat — khusus Indonesia ─────────────────
  late TextEditingController _rtCtrl;
  late TextEditingController _rwCtrl;
  late TextEditingController _kelurahanCtrl;
  late TextEditingController _kecamatanCtrl;

  bool get _isIndonesia => (_countryIso ?? '').toUpperCase() == 'ID';

  /// Debounce untuk auto-isi Provinsi/State & ZIP alamat LUAR NEGERI
  /// (forward-geocoding dari Address Line 1 + City), supaya tidak
  /// memanggil geocoding di setiap ketikan huruf.
  Timer? _intlLookupDebounce;
  bool _intlLookupInProgress = false;

  // ── Telepon (WhatsApp aktif) ────────────────
  late TextEditingController _phoneCtrl;
  String? _phoneCountryIso;
  /// Setelah pengguna mengganti kode negara telepon secara manual,
  /// sinkronisasi otomatis dari Negara Alamat berhenti sampai Negara
  /// Alamat diganti lagi.
  bool _phoneCountryManuallySet = false;

  // ── Tipe & kondisi kulit ─────────────────────
  final Set<SkinType> _skinTypes = {};
  SkinConditionStatus? _skinCondition;

  int? _day;
  int? _month;
  int? _year;

  bool _saving = false;
  bool _detectingLocation = false;
  bool _locationDetected = false;

  // ── State foto profil ───────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();

  Uint8List? _pickedBytes;      // hasil pilih foto di Web
  String?    _pickedPath;       // hasil pilih foto di Android/iOS/Desktop
  bool       _photoRemoved = false; // user menekan "Hapus Foto"

  bool get _hasNewPickedPhoto => _pickedBytes != null || _pickedPath != null;

  bool _hasAnyPhoto(dynamic user) =>
      _hasNewPickedPhoto ||
          (!_photoRemoved && (user?.photo as String?)?.isNotEmpty == true);

  /// Foto yang AKAN aktif / tersimpan saat ini — dipakai baik untuk
  /// preview avatar maupun untuk logika simpan, supaya perilaku sama
  /// persis di Android, iOS, Web, dan Desktop:
  ///   kosong→ada, ada→diganti, ada→dihapus semuanya konsisten.
  String? _resolvedPhotoFor(dynamic user) {
    if (_photoRemoved) return null;
    if (_pickedBytes != null) {
      return 'data:image/jpg;base64,${base64Encode(_pickedBytes!)}';
    }
    if (_pickedPath != null && !kIsWeb) return _pickedPath;
    return (user?.photo as String?);
  }

  Future<String?> _persistPickedPhoto(String uid) async {
    if (!_hasNewPickedPhoto) return null;

    if (kIsWeb) {
      if (_pickedBytes == null) return null;
      return 'data:image/jpg;base64,${base64Encode(_pickedBytes!)}';
    }

    if (_pickedPath == null) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${dir.path}/avatars');
      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }

      final ext = _pickedPath!.contains('.')
          ? _pickedPath!.split('.').last
          : 'jpg';
      final destPath = '${avatarDir.path}/avatar_$uid.$ext';

      final destFile = File(destPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }

      await File(_pickedPath!).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Gagal menyimpan foto ke penyimpanan internal: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameCtrl     = TextEditingController(text: user?.name ?? '');
    _streetCtrl   = TextEditingController(text: user?.street ?? '');
    _unitCtrl     = TextEditingController(text: user?.unitNumber ?? '');
    _cityCtrl     = TextEditingController(text: user?.city ?? '');
    _provinceCtrl = TextEditingController(text: user?.province ?? '');
    _postalCtrl   = TextEditingController(text: user?.postalCode ?? '');
    _rtCtrl         = TextEditingController(text: user?.rt ?? '');
    _rwCtrl         = TextEditingController(text: user?.rw ?? '');
    _kelurahanCtrl  = TextEditingController(text: user?.kelurahan ?? '');
    _kecamatanCtrl  = TextEditingController(text: user?.kecamatan ?? '');
    _phoneCtrl    = TextEditingController(text: user?.phoneNumber ?? '');

    _countryIso = (user?.countryIso as String?)?.isNotEmpty == true
        ? user!.countryIso
        : null;
    _phoneCountryIso = user?.phoneDialCode != null
        ? countryByDialCode(user?.phoneDialCode).isoCode
        : null;
    _phoneCountryManuallySet = _phoneCountryIso != null;

    _skinTypes.addAll(user?.skinTypes ?? const []);
    _skinCondition    = user?.skinCondition;

    _streetCtrl.addListener(_onStreetChanged);
    _cityCtrl.addListener(_onCityChanged);
    // Field lain tidak punya logika auto-isi, tapi tetap WAJIB memicu
    // rebuild supaya status tombol "Simpan & Lanjutkan" (yang bergantung
    // pada `_isValid`/`_missingRequirements`) selalu sinkron dengan isi
    // form saat ini — sebelumnya field ini tidak pernah men-trigger
    // setState() sehingga tombol tidak update saat diisi manual.
    _unitCtrl.addListener(_markDirty);
    _provinceCtrl.addListener(_markDirty);
    _postalCtrl.addListener(_markDirty);
    _rtCtrl.addListener(_markDirty);
    _rwCtrl.addListener(_markDirty);
    _kelurahanCtrl.addListener(_markDirty);
    _kecamatanCtrl.addListener(_markDirty);
    _phoneCtrl.addListener(_markDirty);

    // Jika alamat belum pernah diisi sama sekali, coba deteksi lokasi
    // otomatis (GPS). Jika gagal / ditolak, negara TETAP null →
    // pengguna wajib memilih manual sebelum bisa Simpan.
    if (_countryIso == null && _streetCtrl.text.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detectLocation());
    }
  }

  @override
  void dispose() {
    _intlLookupDebounce?.cancel();
    _nameCtrl.dispose();
    _streetCtrl.removeListener(_onStreetChanged);
    _streetCtrl.dispose();
    _unitCtrl.removeListener(_markDirty);
    _unitCtrl.dispose();
    _cityCtrl.removeListener(_onCityChanged);
    _cityCtrl.dispose();
    _provinceCtrl.removeListener(_markDirty);
    _provinceCtrl.dispose();
    _postalCtrl.removeListener(_markDirty);
    _postalCtrl.dispose();
    _rtCtrl.removeListener(_markDirty);
    _rtCtrl.dispose();
    _rwCtrl.removeListener(_markDirty);
    _rwCtrl.dispose();
    _kelurahanCtrl.removeListener(_markDirty);
    _kelurahanCtrl.dispose();
    _kecamatanCtrl.removeListener(_markDirty);
    _kecamatanCtrl.dispose();
    _phoneCtrl.removeListener(_markDirty);
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// Trigger rebuild sederhana — dipakai oleh field yang tidak punya
  /// logika auto-isi tapi tetap harus memengaruhi status tombol Simpan.
  void _markDirty() {
    if (mounted) setState(() {});
  }

  // ── Deteksi lokasi via GPS → isi default alamat & negara ────────
  Future<void> _detectLocation() async {
    if (_detectingLocation) return;

    // PERBAIKAN BUG: di Web / Windows / Linux, paket `geocoding` tidak
    // punya platform implementation — jangan pernah menyentuhnya.
    // Langsung fallback ke alur "pilih Negara manual" yang memang
    // sudah ada (lihat alert `countryUnset` di `_AddressCard`).
    if (!_geocodingSupported) {
      if (mounted) setState(() => _countryIso = null);
      return;
    }

    setState(() => _detectingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // GPS tidak tersedia / ditolak → negara WAJIB dipilih manual.
        if (mounted) setState(() => _countryIso = null);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 12));

      final List<geocoding.Placemark> placemarks =
      await _geocoder!.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));

      if (placemarks.isEmpty) {
        if (mounted) setState(() => _countryIso = null);
        return;
      }

      final geocoding.Placemark p = placemarks.first;
      final guessedIso = _isoFromCountryName(p.isoCountryCode, p.country);

      if (!mounted) return;
      setState(() {
        _countryIso = guessedIso;
        // PENTING: Nama Jalan / Address Line 1 HANYA berisi nama jalan
        // (`thoroughfare`) — nomor rumah/blok/unit (`subThoroughfare`)
        // dipisah ke field Blok/No/Unit / Address Line 2, supaya kedua
        // field tetap terisi sesuai fungsinya masing-masing.
        if (_streetCtrl.text.trim().isEmpty) {
          _streetCtrl.text = (p.thoroughfare ?? '').trim();
        }
        if (_unitCtrl.text.trim().isEmpty &&
            (p.subThoroughfare ?? '').trim().isNotEmpty) {
          _unitCtrl.text = p.subThoroughfare!.trim();
        }
        if (_cityCtrl.text.trim().isEmpty) {
          _cityCtrl.text = p.locality?.isNotEmpty == true
              ? p.locality!
              : (p.subAdministrativeArea ?? '');
        }
        if (_provinceCtrl.text.trim().isEmpty) {
          _provinceCtrl.text = p.administrativeArea ?? '';
        }
        if (_postalCtrl.text.trim().isEmpty) {
          _postalCtrl.text = p.postalCode ?? '';
        }
        _locationDetected = true;
        _syncPhoneCountryFromAddress();
      });
    } catch (e) {
      debugPrint('Deteksi lokasi gagal: $e');
      // Gagal total → negara tetap null, pengguna wajib memilih manual.
      if (mounted) setState(() => _countryIso = null);
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  String? _isoFromCountryName(String? isoCode, String? countryName) {
    if (isoCode != null && isoCode.isNotEmpty) {
      final match = kCountries.where(
            (c) => c.isoCode.toUpperCase() == isoCode.toUpperCase(),
      );
      if (match.isNotEmpty) return match.first.isoCode;
    }
    if (countryName != null) {
      final match = kCountries.where(
            (c) => c.name.toLowerCase() == countryName.toLowerCase(),
      );
      if (match.isNotEmpty) return match.first.isoCode;
    }
    // Negara terdeteksi tapi di luar daftar kCountries — biarkan null
    // supaya pengguna memilih manual dari daftar yang didukung app.
    return null;
  }

  void _onStreetChanged() {
    if (_isIndonesia) {
      // `_streetCtrl` di sini HANYA berisi nama jalan (tanpa nomor —
      // nomor rumah/blok/unit ada di `_unitCtrl`), jadi pencocokan ke
      // `_kIndoStreetMap` akurat dan tidak salah tebak karena kepanjangan
      // teks nomor rumah.
      final guess = guessIndoAddressFromStreet(_streetCtrl.text);
      setState(() {
        if (guess != null) {
          // Auto-isi hanya field yang masih kosong — tidak menimpa
          // input manual pengguna yang sudah ada, tapi semua tetap
          // bisa diedit.
          if (_rtCtrl.text.trim().isEmpty) _rtCtrl.text = guess.rt;
          if (_rwCtrl.text.trim().isEmpty) _rwCtrl.text = guess.rw;
          if (_kelurahanCtrl.text.trim().isEmpty) _kelurahanCtrl.text = guess.kelurahan;
          if (_kecamatanCtrl.text.trim().isEmpty) _kecamatanCtrl.text = guess.kecamatan;
          if (_cityCtrl.text.trim().isEmpty) _cityCtrl.text = guess.city;
          if (_provinceCtrl.text.trim().isEmpty) _provinceCtrl.text = guess.province;
          if (_postalCtrl.text.trim().isEmpty) _postalCtrl.text = guess.postalCode;
        }
        // setState kosong pun tetap perlu dipanggil (lihat komentar di
        // `_markDirty`) supaya status tombol Simpan selalu sinkron.
      });
    } else {
      // Alamat luar negeri: tidak ada tabel tebakan offline, jadi minta
      // State/Province/Region & ZIP ditebak lewat forward-geocoding
      // dari Address Line 1 + City (lihat `_scheduleIntlAddressLookup`).
      setState(() {});
      _scheduleIntlAddressLookup();
    }
  }

  void _onCityChanged() {
    final guessed = guessCountryIsoFromCity(_cityCtrl.text);
    if (guessed != null && guessed != _countryIso) {
      setState(() {
        _countryIso = guessed;
        _syncPhoneCountryFromAddress();
      });
    } else {
      setState(() {});
    }
    if (!_isIndonesia) _scheduleIntlAddressLookup();
  }

  /// Jadwalkan pencarian State/Province/Region & ZIP untuk alamat LUAR
  /// NEGERI, dengan debounce supaya tidak memanggil geocoding di setiap
  /// ketikan huruf. Dipanggil setiap Address Line 1 / City / Negara
  /// (non-Indonesia) berubah.
  void _scheduleIntlAddressLookup() {
    _intlLookupDebounce?.cancel();
    _intlLookupDebounce = Timer(
      const Duration(milliseconds: 700),
      _lookupIntlAddress,
    );
  }

  /// Forward-geocode "Address Line 1 + City (+ Negara)" lalu reverse-
  /// geocode koordinatnya untuk mendapatkan State/Province/Region &
  /// ZIP yang akurat & lengkap sesuai data pada Address Line 1 & City —
  /// hanya mengisi field yang MASIH KOSONG (tidak menimpa input manual).
  Future<void> _lookupIntlAddress() async {
    if (!mounted || _isIndonesia) return;

    // PERBAIKAN BUG: sama seperti `_detectLocation`, jangan pernah
    // menyentuh `geocoding` di platform yang tidak didukung.
    if (!_geocodingSupported) return;

    final street = _streetCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (street.isEmpty || city.isEmpty) return;
    // Sudah lengkap semua → tidak perlu memanggil geocoding lagi.
    if (_provinceCtrl.text.trim().isNotEmpty &&
        _postalCtrl.text.trim().isNotEmpty) {
      return;
    }
    if (_intlLookupInProgress) return;

    _intlLookupInProgress = true;
    try {
      final countryName =
      _countryIso != null ? countryByIso(_countryIso).name : '';
      final query = [street, city, countryName]
          .where((e) => e.isNotEmpty)
          .join(', ');

      final locations = await _geocoder!
          .locationFromAddress(query)
          .timeout(const Duration(seconds: 8));
      if (locations.isEmpty || !mounted) return;

      final loc = locations.first;
      final placemarks = await _geocoder!
          .placemarkFromCoordinates(loc.latitude, loc.longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty || !mounted) return;

      final p = placemarks.first;
      setState(() {
        if (_provinceCtrl.text.trim().isEmpty) {
          _provinceCtrl.text = p.administrativeArea ?? '';
        }
        if (_postalCtrl.text.trim().isEmpty) {
          _postalCtrl.text = p.postalCode ?? '';
        }
        // Kalau pengguna belum mengisi City secara lengkap (mis. hanya
        // singkatan) dan geocoding menemukan nama kota yang lebih
        // lengkap, isi hanya jika field masih kosong — City sendiri
        // sudah diisi pengguna jadi tidak ditimpa di sini.
      });
    } catch (e) {
      debugPrint('Lookup alamat internasional gagal: $e');
    } finally {
      _intlLookupInProgress = false;
    }
  }

  /// Sinkronkan kode negara telepon mengikuti Negara Alamat — HANYA
  /// jika pengguna belum pernah mengubah kode negara telepon secara
  /// manual. Tetap bisa diedit manual kapan pun.
  void _syncPhoneCountryFromAddress() {
    if (_phoneCountryManuallySet) return;
    if (_countryIso == null) return;
    _phoneCountryIso = _countryIso;
  }

  DateTime? get _birthDate {
    if (_day == null || _month == null || _year == null) return null;
    return DateTime(_year!, _month!, _day!);
  }

  Map<String, int>? get _age {
    final bd = _birthDate;
    if (bd == null) return null;
    final now = DateTime.now();
    int years  = now.year  - bd.year;
    int months = now.month - bd.month;
    int days   = now.day   - bd.day;
    if (days < 0) {
      months--;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) { years--; months += 12; }
    return {'years': years, 'months': months, 'days': days};
  }

  /// Alamat dianggap lengkap jika:
  ///  • Indonesia   → Nama Jalan, Blok/No/Unit, RT, RW, Kelurahan,
  ///                  Kecamatan, Kota/Kabupaten, Provinsi, Kode Pos.
  ///  • Luar negeri → Address Line 1, City, State/Province/Region, ZIP
  ///                  (Address Line 2 tetap opsional, sesuai hint-nya).
  bool get _isAddressValid {
    if (_countryIso == null) return false;
    if (_streetCtrl.text.trim().isEmpty) return false;
    if (_cityCtrl.text.trim().isEmpty) return false;
    if (_provinceCtrl.text.trim().isEmpty) return false;
    if (_postalCtrl.text.trim().isEmpty) return false;
    if (_isIndonesia) {
      if (_unitCtrl.text.trim().isEmpty) return false;
      if (_rtCtrl.text.trim().isEmpty) return false;
      if (_rwCtrl.text.trim().isEmpty) return false;
      if (_kelurahanCtrl.text.trim().isEmpty) return false;
      if (_kecamatanCtrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  bool get _isPhoneValid =>
      _phoneCtrl.text.trim().isNotEmpty && _phoneCountryIso != null;

  bool get _isSkinConditionValid => _skinCondition != null;

  /// Daftar isian yang masih kurang — dipakai untuk menonaktifkan
  /// tombol "Simpan & Lanjutkan" SEKALIGUS menampilkan alasannya ke
  /// pengguna (lihat `_buildSaveButton`).
  List<String> get _missingRequirements {
    final missing = <String>[];
    if (_nameCtrl.text.trim().isEmpty) missing.add('Nama');
    if (_birthDate == null) missing.add('Tanggal Lahir');

    if (_countryIso == null) {
      missing.add('Negara');
    } else {
      if (_streetCtrl.text.trim().isEmpty) {
        missing.add(_isIndonesia ? 'Nama Jalan' : 'Address Line 1');
      }
      if (_isIndonesia && _unitCtrl.text.trim().isEmpty) {
        missing.add('Blok / No. Rumah / Unit');
      }
      if (_isIndonesia && _rtCtrl.text.trim().isEmpty) missing.add('RT');
      if (_isIndonesia && _rwCtrl.text.trim().isEmpty) missing.add('RW');
      if (_isIndonesia && _kelurahanCtrl.text.trim().isEmpty) {
        missing.add('Kelurahan / Desa');
      }
      if (_isIndonesia && _kecamatanCtrl.text.trim().isEmpty) {
        missing.add('Kecamatan');
      }
      if (_cityCtrl.text.trim().isEmpty) {
        missing.add(_isIndonesia ? 'Kota / Kabupaten' : 'City');
      }
      if (_provinceCtrl.text.trim().isEmpty) {
        missing.add(_isIndonesia ? 'Provinsi' : 'State / Province / Region');
      }
      if (_postalCtrl.text.trim().isEmpty) {
        missing.add(_isIndonesia ? 'Kode Pos' : 'ZIP');
      }
    }

    if (!_isPhoneValid) missing.add('No. Telepon');
    if (!_isSkinConditionValid) missing.add('Pemahaman Kondisi Kulit');

    return missing;
  }

  bool get _isValid => _missingRequirements.isEmpty;

  // ── Pilih / Hapus Foto ───────────────────────────────────────────

  Future<void> _openImageSource(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (file == null) return;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _pickedBytes  = bytes;
          _pickedPath   = null;
          _photoRemoved = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _pickedPath   = file.path;
          _pickedBytes  = null;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedBytes  = null;
      _pickedPath   = null;
      _photoRemoved = true;
    });
  }

  Future<void> _pickPhoto() async {
    final user = context.read<UserProvider>().user;
    final showRemove = _hasAnyPhoto(user);
    await _showPhotoOptionsSheet(showRemove: showRemove);
  }

  /// Bottom sheet opsi foto — berbeda per platform:
  ///  • Android / iOS         → Kamera, Galeri, (Hapus Foto jika ada foto)
  ///  • Web / Desktop         → Pilih Foto, (Hapus Foto jika ada foto)
  Future<void> _showPhotoOptionsSheet({required bool showRemove}) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Foto Profil',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            if (_isMobileNative) ...[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto (Kamera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImageSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImageSource(ImageSource.gallery);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Pilih Foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImageSource(ImageSource.gallery);
                },
              ),
            ],
            if (showRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Pilih Negara ─────────────────────────────────────────────────
  //
  // `showDialCode`: tampilkan kode dial di trailing list (dipakai saat
  // memilih kode negara TELEPON). Untuk memilih Negara ALAMAT, kode
  // dial disembunyikan sesuai permintaan.
  Future<CountryInfo?> _showCountryPickerSheet({
    required String title,
    bool showDialCode = false,
  }) {
    return showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.7,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: kCountries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = kCountries[i];
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name),
                        trailing: showDialCode
                            ? Text(
                          c.dialCode,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        )
                            : null,
                        onTap: () => Navigator.pop(ctx, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Save ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    try {
      final provider = context.read<UserProvider>();
      final uid = provider.user?.uid ?? 'unknown';

      if (_hasNewPickedPhoto) {
        final photoToSave = await _persistPickedPhoto(uid);
        if (photoToSave == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan foto, profil tetap disimpan tanpa foto baru.'),
            ),
          );
        } else {
          await provider.updateNameAndPhoto(name: _nameCtrl.text.trim(), photo: photoToSave);
        }
      } else if (_photoRemoved) {
        await provider.removePhoto();
        await provider.updateNameAndPhoto(name: _nameCtrl.text.trim());
      } else {
        await provider.updateNameAndPhoto(name: _nameCtrl.text.trim());
      }

      await provider.updateBirthDate(_birthDate!);

      final isIndonesia = _isIndonesia;
      await provider.updateAddress(
        street:     _streetCtrl.text.trim().isEmpty ? null : _streetCtrl.text.trim(),
        unitNumber: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        city:       _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        province:   _provinceCtrl.text.trim().isEmpty ? null : _provinceCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
        countryIso: _countryIso!,
        rt:         isIndonesia && _rtCtrl.text.trim().isNotEmpty ? _rtCtrl.text.trim() : null,
        rw:         isIndonesia && _rwCtrl.text.trim().isNotEmpty ? _rwCtrl.text.trim() : null,
        kelurahan:  isIndonesia && _kelurahanCtrl.text.trim().isNotEmpty ? _kelurahanCtrl.text.trim() : null,
        kecamatan:  isIndonesia && _kecamatanCtrl.text.trim().isNotEmpty ? _kecamatanCtrl.text.trim() : null,
        clearIndonesianFields: !isIndonesia,
      );

      String? fullPhone;
      if (_phoneCtrl.text.trim().isNotEmpty && _phoneCountryIso != null) {
        final dial = countryByIso(_phoneCountryIso).dialCode;
        await provider.updatePhone(
          dialCode: dial,
          number:   _phoneCtrl.text.trim(),
        );
        fullPhone = '$dial ${_phoneCtrl.text.trim()}';
      }

      if (_skinTypes.isNotEmpty) {
        await provider.updateSkinTypes(_skinTypes.toList());
      }

      if (_skinCondition != null) {
        await provider.updateSkinCondition(_skinCondition!);
      }

      if (!mounted) return;

      final email = provider.user?.email;
      final verified = await _showOtpDispatchDialog(email: email, phone: fullPhone);

      if (verified == true && mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (_) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Pop-up di tengah layar untuk memilih tujuan pengiriman OTP
  /// (Gmail / No. Telepon), lalu membuka halaman verifikasi OTP.
  /// Mengembalikan `true` jika OTP berhasil diverifikasi.
  Future<bool?> _showOtpDispatchDialog({String? email, String? phone}) {
    final hasEmail = (email ?? '').isNotEmpty;
    final hasPhone = (phone ?? '').isNotEmpty;

    // PERBAIKAN: dialog ini men-pop nilai `OtpTarget` (lihat
    // Navigator.pop(dialogCtx, OtpTarget.email/.phone) di bawah), BUKAN
    // bool — sebelumnya di-generic-kan sebagai showDialog<bool> sehingga
    // `target` ikut bertipe bool dan tidak bisa dioper ke parameter
    // `initialTarget` (bertipe OtpTarget) pada OtpVerificationPage.
    return showDialog<OtpTarget>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final cs = Theme.of(dialogCtx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_user_outlined, color: cs.primary, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verifikasi Akun',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: cs.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Profil berhasil disimpan. Pilih tujuan pengiriman kode OTP untuk melanjutkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 20),
                  if (hasEmail)
                    _OtpDestinationTile(
                      icon: Icons.mail_outline,
                      title: 'Kirim ke Gmail',
                      subtitle: email!,
                      onTap: () => Navigator.pop(dialogCtx, OtpTarget.email),
                    ),
                  if (hasEmail && hasPhone) const SizedBox(height: 10),
                  if (hasPhone)
                    _OtpDestinationTile(
                      icon: Icons.sms_outlined,
                      title: 'Kirim ke No. Telepon',
                      subtitle: phone!,
                      onTap: () => Navigator.pop(dialogCtx, OtpTarget.phone),
                    ),
                  if (!hasEmail && !hasPhone) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tidak ada Gmail atau No. Telepon yang bisa dipakai untuk OTP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: cs.error),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx, null),
                      child: const Text('Lewati'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ).then((target) async {
      if (target == null) return null;
      if (!mounted) return null;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            initialTarget: target,
            email: email,
            phone: phone,
          ),
        ),
      );
      return result ?? false;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final cs   = Theme.of(context).colorScheme;
    final now  = DateTime.now();

    final days  = List.generate(31, (i) => i + 1);
    final years = List.generate(100, (i) => now.year - i);

    final age = _age;
    final addressCountry = _countryIso != null ? countryByIso(_countryIso) : null;
    final phoneCountry   = _phoneCountryIso != null ? countryByIso(_phoneCountryIso) : null;

    final dataDiriCard = _buildDataDiriCard(context, cs, user, days, years, age);
    final addressCard = _AddressCard(
      isIndonesia: _isIndonesia,
      streetCtrl: _streetCtrl,
      unitCtrl: _unitCtrl,
      rtCtrl: _rtCtrl,
      rwCtrl: _rwCtrl,
      kelurahanCtrl: _kelurahanCtrl,
      kecamatanCtrl: _kecamatanCtrl,
      cityCtrl: _cityCtrl,
      provinceCtrl: _provinceCtrl,
      postalCtrl: _postalCtrl,
      countryLabel: addressCountry?.nameLabel ?? 'Pilih Negara',
      countryUnset: addressCountry == null,
      detectingLocation: _detectingLocation,
      onTapCountry: () async {
        final picked = await _showCountryPickerSheet(
          title: 'Pilih Negara',
          showDialCode: false,
        );
        if (picked != null) {
          setState(() {
            _countryIso = picked.isoCode;
            _syncPhoneCountryFromAddress();
          });
          if (!_isIndonesia) _scheduleIntlAddressLookup();
        }
      },
      onRetryLocation: _detectLocation,
    );
    final phoneCard = _buildPhoneCard(context, cs, phoneCountry);
    final skinCard = _buildSkinCard(context, cs);

    return Scaffold(
      backgroundColor: _isWebOrDesktop ? cs.surfaceContainerLowest : cs.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isWide = _isWebOrDesktop && width >= 900;

            final header = _buildHeader(context, cs, user);
            final saveButton = _buildSaveButton();

            if (isWide) {
              // ── Web / Desktop, layar lebar → panel 2 kolom ──────
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Container(
                    width: 980,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withOpacity(0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                      border: Border.all(color: cs.outline.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        header,
                        const SizedBox(height: 32),
                        dataDiriCard,
                        const SizedBox(height: 20),
                        // Alamat & Telepon berdampingan di layar lebar.
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: addressCard),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [phoneCard],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        skinCard,
                        const SizedBox(height: 28),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(width: 260, child: saveButton),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // ── Android / iOS / Web & Desktop sempit → satu kolom ──
            // Lebar mengikuti layar (fleksibel), dibatasi maxWidth
            // agar tetap nyaman dibaca di tablet/layar lebar sedang.
            final maxWidth = width < 480 ? width : (width < 900 ? 560.0 : 640.0);
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: width < 480 ? 20 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      header,
                      const SizedBox(height: 28),
                      dataDiriCard,
                      const SizedBox(height: 18),
                      addressCard,
                      const SizedBox(height: 18),
                      phoneCard,
                      const SizedBox(height: 18),
                      skinCard,
                      const SizedBox(height: 24),
                      saveButton,
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, dynamic user) {
    return Column(
      children: [
        Center(child: _buildAvatar(cs, user)),
        const SizedBox(height: 16),
        Text(
          'Lengkapi Profil',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Isi data berikut sebelum menggunakan GlowMate',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final missing = _missingRequirements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: missing.isEmpty ? _save : null,
            child: _saving
                ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('Simpan & Lanjutkan'),
          ),
        ),
        if (missing.isNotEmpty && !_saving) ...[
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Text(
              'Lengkapi dulu: ${missing.join(', ')}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11.5, color: cs.error),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildDataDiriCard(
      BuildContext context,
      ColorScheme cs,
      dynamic user,
      List<int> days,
      List<int> years,
      Map<String, int>? age,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LockedField(label: 'UID', value: user?.uid ?? '-'),
            const SizedBox(height: 12),
            _LockedField(label: 'Email (Gmail)', value: user?.email ?? '-'),
            const SizedBox(height: 20),

            Text('Nama', style: _labelStyle(context)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Masukkan nama Anda',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Tanggal Lahir', textAlign: TextAlign.center, style: _labelStyle(context)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _DropdownField<int>(
                            hint: 'Hari',
                            value: _day,
                            items: days,
                            label: (v) => '$v',
                            onChanged: (v) => setState(() => _day = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _DropdownField<int>(
                            hint: 'Bulan',
                            value: _month,
                            items: List.generate(12, (i) => i + 1),
                            label: (v) => _bulanList[v - 1],
                            onChanged: (v) => setState(() => _month = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _DropdownField<int>(
                            hint: 'Tahun',
                            value: _year,
                            items: years,
                            label: (v) => '$v',
                            onChanged: (v) => setState(() => _year = v),
                          ),
                        ),
                      ],
                    ),
                    if (age != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              '${age['years']} Tahun  ${age['months']} Bulan  ${age['days']} Hari',
                              style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneCard(BuildContext context, ColorScheme cs, CountryInfo? phoneCountry) {
    final rule = phoneRuleFor(_phoneCountryIso ?? 'ID');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.chat_outlined,
              title: 'No. Telepon (WhatsApp Aktif) *',
              subtitle: 'Dipakai untuk notifikasi & verifikasi',
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 118,
                  child: _PickerButton(
                    label: phoneCountry?.dialLabel ?? 'Pilih Kode',
                    onTap: () async {
                      final picked = await _showCountryPickerSheet(
                        title: 'Pilih Kode Negara',
                        showDialCode: true,
                      );
                      if (picked != null) {
                        setState(() {
                          _phoneCountryIso = picked.isoCode;
                          _phoneCountryManuallySet = true;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      _digitsOnlyFormatter,
                      LengthLimitingTextInputFormatter(rule.maxDigits),
                    ],
                    decoration: InputDecoration(
                      hintText: rule.hint,
                      prefixIcon: const Icon(Icons.phone_iphone_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Contoh: ${phoneCountry?.dialCode ?? ''} ${rule.example} (${rule.minDigits == rule.maxDigits ? '${rule.minDigits}' : '${rule.minDigits}-${rule.maxDigits}'} digit, angka saja)',
              style: TextStyle(fontSize: 11.5, color: cs.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkinCard(BuildContext context, ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.face_retouching_natural_outlined,
              title: 'Tipe Kulit',
              subtitle: 'Pilih satu atau lebih tipe kulit Anda',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: SkinType.values.map((t) {
                final selected = _skinTypes.contains(t);
                return _SkinTypeChip(
                  label: t.label,
                  icon: _skinTypeIconFor(t),
                  selected: selected,
                  onTap: () => setState(() {
                    if (selected) {
                      _skinTypes.remove(t);
                    } else {
                      _skinTypes.add(t);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _SectionHeader(
              icon: Icons.help_outline,
              title: 'Pemahaman Kondisi Kulit *',
              subtitle: 'Seberapa jauh Anda memahami kondisi kulit Anda?',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SkinToggleButton(
                    label: SkinConditionStatus.belumPaham.label,
                    icon: Icons.help_outline,
                    selected: _skinCondition == SkinConditionStatus.belumPaham,
                    onTap: () => setState(() => _skinCondition = SkinConditionStatus.belumPaham),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SkinToggleButton(
                    label: SkinConditionStatus.sudahMengetahui.label,
                    icon: Icons.check_circle_outline,
                    selected: _skinCondition == SkinConditionStatus.sudahMengetahui,
                    onTap: () => setState(() => _skinCondition = SkinConditionStatus.sudahMengetahui),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar widget ────────────────────────────────────────────────
  //
  // Prioritas SELALU konsisten di Android/iOS/Web/Desktop:
  //   1) foto yang baru saja dipilih pengguna (belum disimpan) — preview
  //      langsung dari memory/file lokal.
  //   2) foto tersimpan (Gmail ATAU upload sebelumnya) jika tidak dihapus.
  //   3) tidak ada apa-apa → ikon default (lihat UserAvatar).
  Widget _buildAvatar(ColorScheme cs, dynamic user) {
    ImageProvider? previewProvider;
    if (_pickedBytes != null) {
      previewProvider = MemoryImage(_pickedBytes!);
    } else if (_pickedPath != null && !kIsWeb) {
      previewProvider = FileImage(File(_pickedPath!));
    }

    final photoForAvatar = _resolvedPhotoFor(user);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (previewProvider != null)
          CircleAvatar(
            radius: 44,
            backgroundColor: cs.primary.withOpacity(0.15),
            backgroundImage: previewProvider,
          )
        else
          UserAvatar(photo: photoForAvatar, radius: 44),
        Positioned(
          right: -4,
          bottom: -4,
          child: InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _labelStyle(BuildContext ctx) => TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _OtpDestinationTile extends StatelessWidget {
  const _OtpDestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({required this.label, required this.onTap, this.isPlaceholder = false});
  final String label;
  final VoidCallback onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPlaceholder ? cs.error.withOpacity(0.6) : cs.outline.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPlaceholder ? cs.error : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.expand_more, size: 18, color: cs.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _SkinTypeChip extends StatelessWidget {
  const _SkinTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? cs.primary : cs.outline.withOpacity(0.25),
              width: selected ? 0 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinToggleButton extends StatelessWidget {
  const _SkinToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? cs.primary : cs.outline.withOpacity(0.25),
          width: selected ? 0 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.6)),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.55))),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 14, color: cs.onSurface.withOpacity(0.4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<T>(
      value: value,
      hint: Text(hint, style: const TextStyle(fontSize: 13)),
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem<T>(value: e, child: Text(label(e), style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu Alamat — struktur field BERBEDA untuk Indonesia vs luar negeri.
///
/// Indonesia: Nama Jalan, Blok/No/Unit, RT, RW, Kelurahan, Kecamatan,
/// Kota/Kabupaten, Provinsi, Kode Pos, Negara. Mengetik Nama Jalan yang
/// dikenali akan mencoba auto-isi field lain (tetap bisa diedit).
///
/// Luar negeri: Address Line 1, Address Line 2, City, State/Province/
/// Region, ZIP, Country — tanpa RT/RW/Kelurahan/Kecamatan.
class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.isIndonesia,
    required this.streetCtrl,
    required this.unitCtrl,
    required this.rtCtrl,
    required this.rwCtrl,
    required this.kelurahanCtrl,
    required this.kecamatanCtrl,
    required this.cityCtrl,
    required this.provinceCtrl,
    required this.postalCtrl,
    required this.countryLabel,
    required this.countryUnset,
    required this.detectingLocation,
    required this.onTapCountry,
    required this.onRetryLocation,
  });

  final bool isIndonesia;
  final TextEditingController streetCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController rtCtrl;
  final TextEditingController rwCtrl;
  final TextEditingController kelurahanCtrl;
  final TextEditingController kecamatanCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController provinceCtrl;
  final TextEditingController postalCtrl;
  final String countryLabel;
  final bool countryUnset;
  final bool detectingLocation;
  final VoidCallback onTapCountry;
  final VoidCallback onRetryLocation;

  TextStyle _labelStyle(BuildContext ctx) => TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget field({
      required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle(context)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on_outlined, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alamat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        isIndonesia
                            ? 'Format alamat Indonesia (RT/RW, Kelurahan, Kecamatan)'
                            : 'Format alamat internasional',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55)),
                      ),
                      Text(
                        '* wajib diisi',
                        style: TextStyle(fontSize: 11, color: cs.error.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                if (detectingLocation)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Deteksi lokasi saat ini',
                    icon: Icon(Icons.my_location_outlined, size: 20, color: cs.primary),
                    onPressed: onRetryLocation,
                  ),
              ],
            ),
            if (countryUnset) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: cs.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi tidak terdeteksi. Silakan pilih Negara secara manual.',
                        style: TextStyle(fontSize: 12, color: cs.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            field(
              controller: streetCtrl,
              label: isIndonesia ? 'Nama Jalan *' : 'Address Line 1 *',
              hint: isIndonesia ? 'mis. Jl. Merdeka (tanpa nomor)' : 'mis. 221B Baker Street',
              icon: Icons.signpost_outlined,
            ),
            const SizedBox(height: 16),

            field(
              controller: unitCtrl,
              label: isIndonesia ? 'Blok / No. Rumah / Unit *' : 'Address Line 2',
              hint: isIndonesia ? 'mis. No. 12, Blok A' : 'mis. Apt 4B (opsional)',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 16),

            if (isIndonesia) ...[
              Row(
                children: [
                  Expanded(
                    child: field(
                      controller: rtCtrl,
                      label: 'RT *',
                      hint: '003',
                      icon: Icons.grid_view_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_digitsOnlyFormatter, LengthLimitingTextInputFormatter(3)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: field(
                      controller: rwCtrl,
                      label: 'RW *',
                      hint: '005',
                      icon: Icons.grid_view_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_digitsOnlyFormatter, LengthLimitingTextInputFormatter(3)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              field(
                controller: kelurahanCtrl,
                label: 'Kelurahan / Desa *',
                hint: 'mis. Sukamaju',
                icon: Icons.holiday_village_outlined,
                inputFormatters: [_lettersOnlyFormatter],
              ),
              const SizedBox(height: 16),

              field(
                controller: kecamatanCtrl,
                label: 'Kecamatan *',
                hint: 'mis. Coblong',
                icon: Icons.apartment_outlined,
                inputFormatters: [_lettersOnlyFormatter],
              ),
              const SizedBox(height: 16),
            ],

            field(
              controller: cityCtrl,
              label: isIndonesia ? 'Kota / Kabupaten *' : 'City *',
              hint: isIndonesia ? 'mis. Bandung' : 'mis. New York',
              icon: Icons.location_city_outlined,
              inputFormatters: [_lettersOnlyFormatter],
            ),
            const SizedBox(height: 16),

            field(
              controller: provinceCtrl,
              label: isIndonesia ? 'Provinsi *' : 'State / Province / Region *',
              hint: isIndonesia ? 'mis. Jawa Barat' : 'mis. New York',
              icon: Icons.map_outlined,
              inputFormatters: [_lettersOnlyFormatter],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: field(
                    controller: postalCtrl,
                    label: isIndonesia ? 'Kode Pos *' : 'ZIP *',
                    hint: isIndonesia ? '40123' : '10001',
                    icon: Icons.markunread_mailbox_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_digitsOnlyFormatter, LengthLimitingTextInputFormatter(10)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Country', style: _labelStyle(context)),
                      const SizedBox(height: 6),
                      _PickerButton(
                        label: countryLabel,
                        onTap: onTapCountry,
                        isPlaceholder: countryUnset,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}