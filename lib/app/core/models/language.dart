// ─────────────────────────────────────────────
// app/core/models/language.dart
// ─────────────────────────────────────────────
//
// Model bahasa aplikasi + daftar 17 bahasa yang didukung.
// File ini SENGAJA berdiri sendiri (tidak bergantung pada file
// data negara/countries.dart) supaya mudah dipasang di project mana
// pun tanpa dependensi tambahan.
//
// Aturan yang dijaga oleh SET FILE INI (lihat juga
// services/language.dart & providers/settings/language.dart):
//   1. Total 17 bahasa didukung aplikasi — lihat kSupportedLanguages
//      di bawah.
//   2. Bahasa aktif otomatis berubah di SELURUH aplikasi begitu
//      diganti dari halaman Pengaturan (ditangani LanguageProvider).
//   3. Saat pertama kali login/buka aplikasi, bahasa ditebak otomatis
//      dari lokasi/region yang tertera di sistem perangkat. Jika
//      tidak terdeteksi → default ke Amerika Serikat (English/"en").
//      Begitu pengguna memilih bahasa manual di Pengaturan, pilihan
//      itu disimpan permanen dan TIDAK ditimpa lagi oleh deteksi
//      otomatis (lihat LanguageProvider.setLanguage()).
// ─────────────────────────────────────────────

class LanguageInfo {
  /// Kode bahasa BCP-47, mis. "id", "en", "zh-TW".
  final String code;

  /// Nama bahasa dalam bahasa itu sendiri, mis. "Bahasa Indonesia".
  final String name;

  /// Nama bahasa dalam Bahasa Inggris, mis. "Indonesian".
  final String englishName;

  /// Emoji bendera negara representatif, mis. "🇮🇩".
  final String flag;

  const LanguageInfo({
    required this.code,
    required this.name,
    required this.englishName,
    required this.flag,
  });

  /// Label untuk tombol/list pemilih bahasa, mis. "🇮🇩 Bahasa Indonesia".
  String get label => '$flag $name';

  @override
  String toString() => code;
}

/// Kode & negara default aplikasi bila lokasi/region sistem tidak
/// bisa dideteksi. Sesuai ketentuan #3: fallback ke Amerika Serikat
/// (English / "en" / "US").
const String kDefaultLanguageCode = 'en';
const String kDefaultCountryIso = 'US';

/// ── 17 BAHASA YANG DIDUKUNG APLIKASI ──────────────────────────────
const List<LanguageInfo> kSupportedLanguages = [
  LanguageInfo(code: 'id',    name: 'Bahasa Indonesia', englishName: 'Indonesian',            flag: '🇮🇩'),
  LanguageInfo(code: 'ms',    name: 'Bahasa Melayu',    englishName: 'Malay',                 flag: '🇲🇾'),
  LanguageInfo(code: 'en',    name: 'English',          englishName: 'English',               flag: '🇺🇸'),
  LanguageInfo(code: 'th',    name: 'ภาษาไทย',           englishName: 'Thai',                  flag: '🇹🇭'),
  LanguageInfo(code: 'fil',   name: 'Filipino',         englishName: 'Filipino',              flag: '🇵🇭'),
  LanguageInfo(code: 'vi',    name: 'Tiếng Việt',       englishName: 'Vietnamese',            flag: '🇻🇳'),
  LanguageInfo(code: 'km',    name: 'ភាសាខ្មែរ',         englishName: 'Khmer',                 flag: '🇰🇭'),
  LanguageInfo(code: 'pt',    name: 'Português',        englishName: 'Portuguese',            flag: '🇹🇱'),
  LanguageInfo(code: 'ja',    name: '日本語',             englishName: 'Japanese',              flag: '🇯🇵'),
  LanguageInfo(code: 'ko',    name: '한국어',             englishName: 'Korean',                flag: '🇰🇷'),
  LanguageInfo(code: 'zh',    name: '中文 (简体)',         englishName: 'Chinese (Simplified)',  flag: '🇨🇳'),
  LanguageInfo(code: 'zh-TW', name: '中文 (繁體)',         englishName: 'Chinese (Traditional)', flag: '🇹🇼'),
  LanguageInfo(code: 'hi',    name: 'हिन्दी',             englishName: 'Hindi',                 flag: '🇮🇳'),
  LanguageInfo(code: 'ar',    name: 'العربية',           englishName: 'Arabic',                flag: '🇸🇦'),
  LanguageInfo(code: 'de',    name: 'Deutsch',          englishName: 'German',                flag: '🇩🇪'),
  LanguageInfo(code: 'nl',    name: 'Nederlands',       englishName: 'Dutch',                 flag: '🇳🇱'),
  LanguageInfo(code: 'fr',    name: 'Français',         englishName: 'French',                flag: '🇫🇷'),
];

/// Pemetaan kode ISO negara → kode bahasa BCP-47 di atas. Dipakai
/// LanguageService untuk menebak bahasa default dari region sistem
/// pengguna. Satu bahasa boleh dipetakan dari banyak negara supaya
/// deteksi lebih akurat (mis. "GB" & "AU" sama-sama → "en").
const Map<String, String> kLanguageByCountryIso = {
  'ID': 'id', // Indonesia
  'MY': 'ms', // Malaysia
  'BN': 'ms', // Brunei
  'SG': 'en', // Singapura
  'TH': 'th', // Thailand
  'PH': 'fil', // Filipina
  'VN': 'vi', // Vietnam
  'KH': 'km', // Kamboja
  'TL': 'pt', // Timor Leste
  'BR': 'pt', // Brasil
  'PT': 'pt', // Portugal
  'US': 'en', // Amerika Serikat (default)
  'CA': 'en', // Kanada
  'AU': 'en', // Australia
  'NZ': 'en', // Selandia Baru
  'GB': 'en', // Inggris
  'IE': 'en', // Irlandia
  'JP': 'ja', // Jepang
  'KR': 'ko', // Korea Selatan
  'KP': 'ko', // Korea Utara
  'CN': 'zh', // Tiongkok
  'HK': 'zh', // Hong Kong
  'MO': 'zh', // Makau
  'TW': 'zh-TW', // Taiwan
  'IN': 'hi', // India
  'SA': 'ar', // Arab Saudi
  'AE': 'ar', // Uni Emirat Arab
  'EG': 'ar', // Mesir
  'QA': 'ar', // Qatar
  'KW': 'ar', // Kuwait
  'DE': 'de', // Jerman
  'AT': 'de', // Austria
  'CH': 'de', // Swiss
  'NL': 'nl', // Belanda
  'BE': 'nl', // Belgia
  'FR': 'fr', // Perancis
  'MC': 'fr', // Monako
};

/// Bahasa default aplikasi (Amerika Serikat / English) — dipakai
/// sebagai fallback terakhir kalau deteksi lokasi/region gagal total.
LanguageInfo get kDefaultLanguage => languageByCode(kDefaultLanguageCode);

/// Cari [LanguageInfo] berdasarkan kode bahasa. Fallback ke bahasa
/// default (English/US) bila kode tidak ditemukan atau null — supaya
/// tidak pernah crash walau kode bahasa tidak valid.
LanguageInfo languageByCode(String? code) {
  return kSupportedLanguages.firstWhere(
        (l) => l.code == code,
    orElse: () => kSupportedLanguages.firstWhere(
          (l) => l.code == kDefaultLanguageCode,
      orElse: () => kSupportedLanguages.first,
    ),
  );
}

/// Tebak kode bahasa dari kode ISO negara (mis. hasil deteksi
/// region sistem). Mengembalikan [kDefaultLanguageCode] (en/US) bila
/// negara tidak dikenali atau tidak punya pemetaan bahasa.
String languageCodeFromCountryIso(String? iso) {
  if (iso == null) return kDefaultLanguageCode;
  return kLanguageByCountryIso[iso.toUpperCase()] ?? kDefaultLanguageCode;
}