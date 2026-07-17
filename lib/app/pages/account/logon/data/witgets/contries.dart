// ─────────────────────────────────────────────
// core/data/countries.dart
// ─────────────────────────────────────────────
//
// Daftar negara (nama, kode ISO, kode telepon, bendera emoji) yang
// dipakai bersama oleh:
//   • Dropdown "Negara" pada form Alamat
//   • Tombol kode negara pada field "No. Telepon (WhatsApp)"
//
// Juga menyediakan `guessCountryIsoFromCity()` — dipakai supaya
// dropdown Negara otomatis menyesuaikan begitu pengguna mengetik
// nama Kota (kota dijadikan parameter untuk menebak negara).
//
// PEMBARUAN:
//   • Menambahkan `PhoneRule` (panjang digit minimum/maksimum + contoh
//     format lokal) per negara — dipakai untuk validasi & hint pada
//     field No. Telepon supaya format selalu sesuai negara terpilih.
//   • `nameLabel` TIDAK menampilkan kode dial (dipakai khusus di
//     tombol pilih Negara pada form Alamat).
//   • `dialLabel` tetap menampilkan kode dial (dipakai khusus di
//     tombol pilih kode negara pada field No. Telepon).
// ─────────────────────────────────────────────

class CountryInfo {
  final String name;     // Nama tampilan, mis. "Indonesia"
  final String isoCode;  // Kode ISO 3166-1 alpha-2, mis. "ID"
  final String dialCode; // Kode telepon, mis. "+62"
  final String flag;     // Emoji bendera

  const CountryInfo({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
  });

  /// Label lengkap untuk tombol kode telepon, mis. "🇮🇩 +62"
  String get dialLabel => '$flag $dialCode';

  /// Label untuk dropdown/tombol Negara pada form Alamat — TANPA kode
  /// dial, mis. "🇮🇩 Indonesia" (bukan "🇮🇩 Indonesia +62").
  String get nameLabel => '$flag $name';
}

/// Aturan validasi & contoh format nomor telepon lokal (tanpa kode
/// negara) untuk sebuah negara. Dipakai supaya field No. Telepon
/// selalu meminta jumlah digit & format yang benar sesuai negara yang
/// aktif saat itu.
class PhoneRule {
  final int minDigits;
  final int maxDigits;
  final String example; // Contoh nomor lokal, tanpa kode negara & tanpa 0 di depan
  final String hint;    // Placeholder yang ditampilkan di field

  const PhoneRule({
    required this.minDigits,
    required this.maxDigits,
    required this.example,
    required this.hint,
  });
}

const List<CountryInfo> kCountries = [
  CountryInfo(name: 'Indonesia', isoCode: 'ID', dialCode: '+62', flag: '🇮🇩'),
  CountryInfo(name: 'Malaysia', isoCode: 'MY', dialCode: '+60', flag: '🇲🇾'),
  CountryInfo(name: 'Singapura', isoCode: 'SG', dialCode: '+65', flag: '🇸🇬'),
  CountryInfo(name: 'Brunei Darussalam', isoCode: 'BN', dialCode: '+673', flag: '🇧🇳'),
  CountryInfo(name: 'Thailand', isoCode: 'TH', dialCode: '+66', flag: '🇹🇭'),
  CountryInfo(name: 'Filipina', isoCode: 'PH', dialCode: '+63', flag: '🇵🇭'),
  CountryInfo(name: 'Vietnam', isoCode: 'VN', dialCode: '+84', flag: '🇻🇳'),
  CountryInfo(name: 'Kamboja', isoCode: 'KH', dialCode: '+855', flag: '🇰🇭'),
  CountryInfo(name: 'Timor Leste', isoCode: 'TL', dialCode: '+670', flag: '🇹🇱'),
  CountryInfo(name: 'Amerika Serikat', isoCode: 'US', dialCode: '+1', flag: '🇺🇸'),
  CountryInfo(name: 'Australia', isoCode: 'AU', dialCode: '+61', flag: '🇦🇺'),
  CountryInfo(name: 'Jepang', isoCode: 'JP', dialCode: '+81', flag: '🇯🇵'),
  CountryInfo(name: 'Korea Selatan', isoCode: 'KR', dialCode: '+82', flag: '🇰🇷'),
  CountryInfo(name: 'Tiongkok', isoCode: 'CN', dialCode: '+86', flag: '🇨🇳'),
  CountryInfo(name: 'Hong Kong', isoCode: 'HK', dialCode: '+852', flag: '🇭🇰'),
  CountryInfo(name: 'Taiwan', isoCode: 'TW', dialCode: '+886', flag: '🇹🇼'),
  CountryInfo(name: 'India', isoCode: 'IN', dialCode: '+91', flag: '🇮🇳'),
  CountryInfo(name: 'Arab Saudi', isoCode: 'SA', dialCode: '+966', flag: '🇸🇦'),
  CountryInfo(name: 'Uni Emirat Arab', isoCode: 'AE', dialCode: '+971', flag: '🇦🇪'),
  CountryInfo(name: 'Inggris', isoCode: 'GB', dialCode: '+44', flag: '🇬🇧'),
  CountryInfo(name: 'Jerman', isoCode: 'DE', dialCode: '+49', flag: '🇩🇪'),
  CountryInfo(name: 'Belanda', isoCode: 'NL', dialCode: '+31', flag: '🇳🇱'),
  CountryInfo(name: 'Perancis', isoCode: 'FR', dialCode: '+33', flag: '🇫🇷'),
  CountryInfo(name: 'Korea Utara', isoCode: 'KP', dialCode: '+850', flag: '🇰🇵'),
];

/// Aturan nomor telepon per kode ISO. Fallback umum dipakai bila
/// negara tidak terdaftar di sini (lihat [phoneRuleFor]).
const Map<String, PhoneRule> kPhoneRules = {
  'ID': PhoneRule(minDigits: 9, maxDigits: 12, example: '81234567890', hint: '81234567890'),
  'MY': PhoneRule(minDigits: 9, maxDigits: 10, example: '123456789', hint: '123456789'),
  'SG': PhoneRule(minDigits: 8, maxDigits: 8, example: '81234567', hint: '81234567'),
  'BN': PhoneRule(minDigits: 7, maxDigits: 7, example: '7123456', hint: '7123456'),
  'TH': PhoneRule(minDigits: 9, maxDigits: 9, example: '812345678', hint: '812345678'),
  'PH': PhoneRule(minDigits: 10, maxDigits: 10, example: '9123456789', hint: '9123456789'),
  'VN': PhoneRule(minDigits: 9, maxDigits: 9, example: '912345678', hint: '912345678'),
  'KH': PhoneRule(minDigits: 8, maxDigits: 9, example: '12345678', hint: '12345678'),
  'TL': PhoneRule(minDigits: 7, maxDigits: 8, example: '7712345', hint: '7712345'),
  'US': PhoneRule(minDigits: 10, maxDigits: 10, example: '2015550123', hint: '2015550123'),
  'AU': PhoneRule(minDigits: 9, maxDigits: 9, example: '412345678', hint: '412345678'),
  'JP': PhoneRule(minDigits: 10, maxDigits: 10, example: '9012345678', hint: '9012345678'),
  'KR': PhoneRule(minDigits: 9, maxDigits: 10, example: '1012345678', hint: '1012345678'),
  'CN': PhoneRule(minDigits: 11, maxDigits: 11, example: '13812345678', hint: '13812345678'),
  'HK': PhoneRule(minDigits: 8, maxDigits: 8, example: '51234567', hint: '51234567'),
  'TW': PhoneRule(minDigits: 9, maxDigits: 9, example: '912345678', hint: '912345678'),
  'IN': PhoneRule(minDigits: 10, maxDigits: 10, example: '9876543210', hint: '9876543210'),
  'SA': PhoneRule(minDigits: 9, maxDigits: 9, example: '512345678', hint: '512345678'),
  'AE': PhoneRule(minDigits: 9, maxDigits: 9, example: '501234567', hint: '501234567'),
  'GB': PhoneRule(minDigits: 10, maxDigits: 10, example: '7123456789', hint: '7123456789'),
  'DE': PhoneRule(minDigits: 10, maxDigits: 11, example: '15123456789', hint: '15123456789'),
  'NL': PhoneRule(minDigits: 9, maxDigits: 9, example: '612345678', hint: '612345678'),
  'FR': PhoneRule(minDigits: 9, maxDigits: 9, example: '612345678', hint: '612345678'),
  'KP': PhoneRule(minDigits: 10, maxDigits: 10, example: '1912345678', hint: '1912345678'),
};

const PhoneRule kDefaultPhoneRule =
PhoneRule(minDigits: 7, maxDigits: 13, example: '8123456789', hint: '8123456789');

/// Ambil aturan nomor telepon untuk kode ISO tertentu (fallback aman
/// jika negara tidak ada di daftar).
PhoneRule phoneRuleFor(String iso) => kPhoneRules[iso.toUpperCase()] ?? kDefaultPhoneRule;

/// Cari [CountryInfo] berdasarkan kode ISO. Fallback ke Indonesia.
CountryInfo countryByIso(String? iso) => kCountries.firstWhere(
      (c) => c.isoCode == iso,
  orElse: () => kCountries.first,
);

/// Cari [CountryInfo] berdasarkan kode dial (mis. "+62"). Fallback ke Indonesia.
CountryInfo countryByDialCode(String? dial) => kCountries.firstWhere(
      (c) => c.dialCode == dial,
  orElse: () => kCountries.first,
);

// ── Peta kota → kode negara (untuk auto-deteksi) ─────────────────
//
// Daftar tidak lengkap (bukan API geocoding), tapi mencakup kota-kota
// besar Indonesia (mayoritas pengguna aplikasi) serta beberapa kota
// besar dunia sebagai fallback. Kalau kota tidak dikenali, dropdown
// negara TIDAK diubah — pengguna tetap bisa memilih manual.
const Map<String, String> _kCityCountryMap = {
  // Indonesia
  'jakarta': 'ID', 'bandung': 'ID', 'surabaya': 'ID', 'medan': 'ID',
  'semarang': 'ID', 'makassar': 'ID', 'palembang': 'ID', 'yogyakarta': 'ID',
  'jogja': 'ID', 'denpasar': 'ID', 'bali': 'ID', 'malang': 'ID',
  'bogor': 'ID', 'depok': 'ID', 'tangerang': 'ID', 'bekasi': 'ID',
  'batam': 'ID', 'balikpapan': 'ID', 'manado': 'ID', 'padang': 'ID',
  'pekanbaru': 'ID', 'banjarmasin': 'ID', 'samarinda': 'ID', 'solo': 'ID',
  'surakarta': 'ID', 'cirebon': 'ID', 'sukabumi': 'ID', 'cimahi': 'ID',
  'tasikmalaya': 'ID', 'serang': 'ID', 'jambi': 'ID', 'lampung': 'ID',
  'pontianak': 'ID', 'mataram': 'ID', 'kupang': 'ID', 'ambon': 'ID',
  'jayapura': 'ID', 'gorontalo': 'ID', 'palu': 'ID', 'kendari': 'ID',
  // Malaysia
  'kuala lumpur': 'MY', 'penang': 'MY', 'johor bahru': 'MY', 'ipoh': 'MY',
  // Singapura
  'singapore': 'SG', 'singapura': 'SG',
  // Lainnya
  'bandar seri begawan': 'BN',
  'bangkok': 'TH', 'chiang mai': 'TH',
  'manila': 'PH', 'cebu': 'PH',
  'hanoi': 'VN', 'ho chi minh': 'VN', 'ho chi minh city': 'VN',
  'phnom penh': 'KH',
  'dili': 'TL',
  'tokyo': 'JP', 'osaka': 'JP', 'kyoto': 'JP',
  'seoul': 'KR', 'busan': 'KR',
  'beijing': 'CN', 'shanghai': 'CN', 'guangzhou': 'CN', 'shenzhen': 'CN',
  'hong kong': 'HK',
  'taipei': 'TW',
  'new delhi': 'IN', 'mumbai': 'IN', 'bangalore': 'IN',
  'riyadh': 'SA', 'jeddah': 'SA', 'mekah': 'SA', 'mecca': 'SA', 'madinah': 'SA',
  'dubai': 'AE', 'abu dhabi': 'AE',
  'london': 'GB', 'manchester': 'GB',
  'berlin': 'DE', 'munich': 'DE',
  'amsterdam': 'NL', 'rotterdam': 'NL',
  'paris': 'FR',
  'new york': 'US', 'los angeles': 'US', 'san francisco': 'US', 'seattle': 'US',
  'sydney': 'AU', 'melbourne': 'AU',
};

/// Tebak kode ISO negara dari nama kota yang diketik pengguna.
/// Mengembalikan null jika tidak ada yang cocok (dropdown negara
/// dibiarkan seperti semula, tidak dipaksa berubah).
String? guessCountryIsoFromCity(String city) {
  final key = city.trim().toLowerCase();
  if (key.isEmpty) return null;

  if (_kCityCountryMap.containsKey(key)) return _kCityCountryMap[key];

  // Pencocokan sebagian (mis. "kota bandung" tetap kena "bandung")
  for (final entry in _kCityCountryMap.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return null;
}

// ── Data dummy RT/RW/Kelurahan/Kecamatan/Kode Pos per Nama Jalan ──
//
// CATATAN PENTING: Ini BUKAN sumber data resmi (bukan API Kodepos/
// PosIndonesia/Dukcapil). Dipakai murni sebagai fallback offline agar
// form bisa "auto-isi" RT/RW/Kelurahan/Kecamatan/Kode Pos ketika
// pengguna mengetik nama jalan tertentu yang kebetulan cocok di
// daftar ini. Semua field tetap BISA diedit manual oleh pengguna.
// Untuk data akurat & lengkap, sambungkan ke API geocoding resmi
// (mis. Google Geocoding API / Kodepos.co.id) di [lookupIndoStreet].
class IndoStreetGuess {
  final String rt;
  final String rw;
  final String kelurahan;
  final String kecamatan;
  final String city;
  final String province;
  final String postalCode;

  const IndoStreetGuess({
    required this.rt,
    required this.rw,
    required this.kelurahan,
    required this.kecamatan,
    required this.city,
    required this.province,
    required this.postalCode,
  });
}

const Map<String, IndoStreetGuess> _kIndoStreetMap = {
  'jl. merdeka': IndoStreetGuess(
    rt: '001', rw: '002', kelurahan: 'Merdeka', kecamatan: 'Sumur Bandung',
    city: 'Bandung', province: 'Jawa Barat', postalCode: '40111',
  ),
  'jl. sudirman': IndoStreetGuess(
    rt: '003', rw: '004', kelurahan: 'Karet Tengsin', kecamatan: 'Tanah Abang',
    city: 'Jakarta Pusat', province: 'DKI Jakarta', postalCode: '10250',
  ),
  'jl. thamrin': IndoStreetGuess(
    rt: '002', rw: '003', kelurahan: 'Gondangdia', kecamatan: 'Menteng',
    city: 'Jakarta Pusat', province: 'DKI Jakarta', postalCode: '10350',
  ),
  'jl. gatot subroto': IndoStreetGuess(
    rt: '004', rw: '005', kelurahan: 'Setiabudi', kecamatan: 'Setiabudi',
    city: 'Jakarta Selatan', province: 'DKI Jakarta', postalCode: '12930',
  ),
  'jl. asia afrika': IndoStreetGuess(
    rt: '001', rw: '001', kelurahan: 'Braga', kecamatan: 'Sumur Bandung',
    city: 'Bandung', province: 'Jawa Barat', postalCode: '40111',
  ),
  'jl. malioboro': IndoStreetGuess(
    rt: '002', rw: '002', kelurahan: 'Sosromenduran', kecamatan: 'Gedong Tengen',
    city: 'Yogyakarta', province: 'DI Yogyakarta', postalCode: '55271',
  ),
  'jl. diponegoro': IndoStreetGuess(
    rt: '003', rw: '003', kelurahan: 'Darmo', kecamatan: 'Wonokromo',
    city: 'Surabaya', province: 'Jawa Timur', postalCode: '60241',
  ),
};

/// Tebak kelengkapan alamat (RT/RW/Kelurahan/Kecamatan/Kota/Provinsi/
/// Kode Pos) dari Nama Jalan yang diketik pengguna. Hanya berlaku
/// untuk alamat Indonesia. Mengembalikan null jika nama jalan tidak
/// dikenali — form tetap kosong dan harus diisi manual.
IndoStreetGuess? guessIndoAddressFromStreet(String street) {
  final key = street.trim().toLowerCase();
  if (key.isEmpty) return null;
  if (_kIndoStreetMap.containsKey(key)) return _kIndoStreetMap[key];
  for (final entry in _kIndoStreetMap.entries) {
    if (key.contains(entry.key)) return entry.value;
  }
  return null;
}