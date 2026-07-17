// lib/app/pages/analysis/model/data.dart

const _hariIndo = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

const _bulanIndo = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Format: "Senin, Juni 7 2026 : 12:00 PM"
String formatTanggalIndo(DateTime dt) {
  final hari = _hariIndo[dt.weekday - 1];
  final bulan = _bulanIndo[dt.month - 1];

  final hour12Raw = dt.hour % 12;
  final hour12 = hour12Raw == 0 ? 12 : hour12Raw;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');

  return '$hari, $bulan ${dt.day} ${dt.year} : $hour12:$minute $period';
}

/// Format singkat untuk item list: "7 Jun 2026, 12:00 PM"
String formatTanggalSingkat(DateTime dt) {
  const bulanSingkat = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final hour12Raw = dt.hour % 12;
  final hour12 = hour12Raw == 0 ? 12 : hour12Raw;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${bulanSingkat[dt.month - 1]} ${dt.year}, $hour12:$minute $period';
}

/// Sapaan berdasarkan jam saat ini (dipakai di header AnalysisPage).
///
/// Pembagian:
/// - 04:00 - 10:59 -> "Selamat pagi"
/// - 11:00 - 14:59 -> "Selamat siang"
/// - 15:00 - 17:59 -> "Selamat sore"
/// - 18:00 - 03:59 -> "Selamat malam"
String sapaanBerdasarkanWaktu(DateTime dt) {
  final jam = dt.hour;
  if (jam >= 4 && jam < 11) return 'Selamat pagi';
  if (jam >= 11 && jam < 15) return 'Selamat siang';
  if (jam >= 15 && jam < 18) return 'Selamat sore';
  return 'Selamat malam';
}