// lib/app/pages/analysis/model/skin_health.dart
//
// FITUR BARU: "Grafik Kemajuan Kulit" (Tingkat Kulit Sehat).
//
// KETENTUAN dari permintaan revisi:
// 1. Berdasarkan riwayat analisis pada TIPE KULIT: kalau per-harinya ada
//    penurunan jumlah masalah / tipe kulit yang tercatat (membaik /
//    masalah hilang), itu dikategorikan "Kemajuan". Kalau bertambah,
//    "Perlu Perhatian".
// 2. Field baru untuk grafik kemajuan kulit: "Tingkat Kulit Sehat" —
//    indikator dua arah, MEMBAIK & MEMBURUK. Kalau ini pemakaian
//    pertama, tren baru mulai "terhitung" sejak titik data ke-5
//    (`warmupPoints`) — sebelum itu grafik tetap tampil (garis & skor
//    tetap digambar) tapi belum diwarnai membaik/memburuk.
// 3. Grafik juga membaca data tipe kulit dari REPORT
//    (`analysisData['skinProblems']`, diisi lewat
//    `AnalysisRepository.updateSkinProblems`) — kalau report terus
//    bertambah banyak TANPA ada perubahan (masalah tidak berkurang),
//    skor tetap flat/rendah. Begitu ada masalah yang berkurang, skor
//    naik.
// 4. Grafik punya 3 mode pengelompokan (Per Hari/Bulan/Tahun) yang
//    dihitung ULANG secara realtime saat mode diganti — lihat
//    `buildTimeline`, dipanggil ulang tiap kali `SkinHealthChart`
//    (widgets/skin_health_chart.dart) di-build ulang.
// 5. Grafik SELALU dihitung dari SELURUH riwayat (`allRecords`), TIDAK
//    peduli AnalysisPage cuma menampilkan sebagian (terbaru saja) di
//    daftar "Riwayat Deteksi" — lihat pemakaian di pages.dart.
//
// CATATAN DESAIN: "field baru" di atas SENGAJA diimplementasikan
// sebagai kalkulasi TURUNAN (derived) dari data yang sudah ada
// (`skinScore`, `knownSkinTypes`, `analysisData['skinProblems']`),
// BUKAN sebagai key baru yang disimpan mentah di JSON
// `AnalysisRecord`. Alasannya sama seperti STATUS LAPORAN di
// `report/pages.dart` (`_computeReportStage`): "kemajuan"/"tingkat
// kulit sehat" adalah metrik RELATIF — selalu dibandingkan dengan
// record/periode lain — sehingga kalau disimpan mentah, nilainya akan
// basi begitu ada record baru masuk atau dihapus. Menghitung ulang
// setiap kali dipanggil menjamin hasilnya selalu akurat & realtime,
// selaras dengan mekanisme `notifyListeners()` di AnalysisRepository.

import '../../model/model.dart';

/// Mode pengelompokan titik data pada grafik "Tingkat Kulit Sehat".
enum ChartPeriod { daily, monthly, yearly }

extension ChartPeriodLabel on ChartPeriod {
  String get label => switch (this) {
    ChartPeriod.daily => 'Per Hari',
    ChartPeriod.monthly => 'Per Bulan',
    ChartPeriod.yearly => 'Per Tahun',
  };
}

/// Arah tren dibanding titik/record pembanding sebelumnya.
enum SkinTrend { improving, worsening, stable, insufficientData }

extension SkinTrendLabel on SkinTrend {
  String get label => switch (this) {
    SkinTrend.improving => 'Membaik',
    SkinTrend.worsening => 'Memburuk',
    SkinTrend.stable => 'Stabil',
    SkinTrend.insufficientData => 'Data belum cukup',
  };
}

/// Satu titik pada grafik, sudah diagregasi menurut [ChartPeriod] yang
/// sedang aktif.
class SkinHealthPoint {
  const SkinHealthPoint({
    required this.periodStart,
    required this.score,
    required this.recordCount,
    required this.trend,
  });

  /// Awal periode (mis. tengah malam hari itu untuk mode harian, tanggal
  /// 1 untuk mode bulanan, 1 Januari untuk mode tahunan).
  final DateTime periodStart;

  /// Skor kesehatan kulit 0-100, rata-rata dari seluruh record yang
  /// jatuh pada periode ini.
  final double score;

  /// Banyaknya record (capture/report) yang menyusun titik ini —
  /// KETENTUAN #3: dipakai untuk konteks "makin banyak report".
  final int recordCount;

  final SkinTrend trend;
}

/// Hasil perbandingan DUA SCAN TERAKHIR (record paling baru vs record
/// tepat sebelumnya secara kronologis) -- dipakai untuk menampilkan
/// ringkasan "Tingkat Kulit Sehat" berdasarkan 2 kali scan yang
/// terdeteksi, konsisten dipakai baik di AnalysisPage maupun ReportPage
/// karena keduanya menonton `AnalysisRepository` yang sama.
///
/// Beda dengan `SkinHealthAnalyzer.progressBetween` (dipakai chip di
/// kartu riwayat, HANYA mengembalikan improving/worsening dan `null`
/// untuk kasus stabil), kelas ini SELALU mengembalikan status --
/// termasuk `SkinTrend.stable` -- supaya bisa ditampilkan apa adanya:
/// "Perlu Perhatian" (worsening), "Stabil" (stable), atau "Membaik"
/// (improving).
class LastScanComparison {
  const LastScanComparison({
    required this.trend,
    required this.previousScore,
    required this.currentScore,
    required this.previousDate,
    required this.currentDate,
  });

  final SkinTrend trend;

  /// Skor kesehatan kulit pada scan SEBELUMNYA (null kalau belum ada
  /// scan sebelumnya, atau datanya belum bisa dinilai).
  final double? previousScore;

  /// Skor kesehatan kulit pada scan TERBARU.
  final double? currentScore;

  final DateTime? previousDate;
  final DateTime? currentDate;

  /// True kalau ada cukup data (2 scan, keduanya bisa dinilai) untuk
  /// ditampilkan sebagai perbandingan yang berarti.
  bool get isComparable =>
      trend != SkinTrend.insufficientData &&
          previousScore != null &&
          currentScore != null;
}

class SkinHealthAnalyzer {
  SkinHealthAnalyzer._();

  /// KETENTUAN #2: jumlah titik minimum sebelum tren MULAI dihitung.
  /// Sebelum jumlah titik (hari/bulan/tahun) mencapai angka ini, grafik
  /// tetap digambar (skor & garis tetap tampil) tapi seluruh titik
  /// dianggap `SkinTrend.insufficientData` (netral/abu-abu) karena data
  /// belum cukup untuk menyimpulkan tren yang meyakinkan.
  static const int warmupPoints = 5;

  /// Toleransi selisih skor supaya tren tidak "flip-flop" akibat
  /// perbedaan desimal yang tidak signifikan.
  static const double trendThreshold = 1.0;

  /// KETENTUAN #3: gabungan "data tipe kulit dari report" — yaitu
  /// `knownSkinTypes` (tipe kulit dari gerbang popup kamera) DAN
  /// `analysisData['skinProblems']` (hasil analisis/report lanjutan,
  /// lihat `AnalysisRepository.updateSkinProblems`) — digabung jadi
  /// SATU himpunan tanpa duplikat per record.
  static List<String> problemsOf(AnalysisRecord r) {
    final set = <String>{};
    set.addAll(r.knownSkinTypes);
    final reportProblems = r.analysisData?['skinProblems'];
    if (reportProblems is List) {
      set.addAll(reportProblems.map((e) => e.toString()));
    }
    return set.toList(growable: false);
  }

  /// Skor kesehatan kulit 0-100 untuk SATU record.
  /// - Kalau `skinScore` (hasil analisis API/lokal) sudah ada, dipakai
  ///   apa adanya — ini sumber paling akurat kalau tersedia.
  /// - Kalau belum, diturunkan dari BANYAKNYA masalah kulit yang
  ///   terkumpul (KETENTUAN #3): makin banyak masalah & tidak berkurang
  ///   antar record -> skor tetap rendah/flat. Makin sedikit -> skor
  ///   naik.
  /// - Null kalau record ini sama sekali belum punya data yang bisa
  ///   dinilai (baru `captured`, belum ada Kondisi Kulit sama sekali) —
  ///   record seperti ini DILEWATI, tidak ikut dirata-rata di grafik.
  static double? healthScoreOf(AnalysisRecord r) {
    if (r.skinScore != null) {
      return r.skinScore!.clamp(0, 100).toDouble();
    }

    final problems = problemsOf(r);
    if (problems.isEmpty) {
      // Kondisi kulit sudah diketahui tapi belum ada masalah spesifik
      // tercatat -> baseline "cukup baik", bukan skor sempurna (masih
      // menunggu Temuan Tipe Kulit Terbaru yang sungguhan).
      return r.knownSkinConditionLabel != null ? 85.0 : null;
    }
    final score = 100 - (problems.length * 15);
    return score.clamp(5, 95).toDouble();
  }

  static SkinTrend _compareScores(double previous, double current) {
    final diff = current - previous;
    if (diff > trendThreshold) return SkinTrend.improving;
    if (diff < -trendThreshold) return SkinTrend.worsening;
    return SkinTrend.stable;
  }

  static DateTime _bucketKey(DateTime dt, ChartPeriod period) {
    switch (period) {
      case ChartPeriod.daily:
        return DateTime(dt.year, dt.month, dt.day);
      case ChartPeriod.monthly:
        return DateTime(dt.year, dt.month);
      case ChartPeriod.yearly:
        return DateTime(dt.year);
    }
  }

  /// KETENTUAN #4 & #5: membangun ULANG timeline grafik dari SELURUH
  /// riwayat (`allRecords`), dikelompokkan sesuai [period] yang sedang
  /// aktif. Dipanggil ulang setiap kali tombol Per Hari/Bulan/Tahun
  /// di-klik ATAU setiap kali `AnalysisRepository` memberi tahu ada data
  /// baru — sehingga hasilnya SELALU realtime, tidak pernah di-cache
  /// lintas rebuild.
  static List<SkinHealthPoint> buildTimeline(
      List<AnalysisRecord> allRecords,
      ChartPeriod period,
      ) {
    // Urutkan ASCENDING (lama -> baru) dulu karena grafik dibaca
    // kiri -> kanan mengikuti berjalannya waktu.
    final sorted = List<AnalysisRecord>.of(allRecords)
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    final buckets = <DateTime, List<double>>{};
    for (final r in sorted) {
      final score = healthScoreOf(r);
      if (score == null) continue; // lewati record tanpa data ternilai
      final key = _bucketKey(r.capturedAt, period);
      buckets.putIfAbsent(key, () => []).add(score);
    }

    final keys = buckets.keys.toList()..sort();
    final rawPoints = <SkinHealthPoint>[];
    for (final key in keys) {
      final scores = buckets[key]!;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      rawPoints.add(
        SkinHealthPoint(
          periodStart: key,
          score: avg,
          recordCount: scores.length,
          trend: SkinTrend.insufficientData, // diisi ulang di bawah
        ),
      );
    }

    if (rawPoints.isEmpty) return const [];

    // KETENTUAN #2: warmup. Sebelum TOTAL titik >= `warmupPoints`,
    // seluruh titik tetap `insufficientData` -- baru "mulai terhitung"
    // sejak titik ke-5. Skor & garis tetap dikembalikan apa adanya
    // supaya grafik tetap bisa digambar selama masa pengumpulan data.
    if (rawPoints.length < warmupPoints) {
      return rawPoints;
    }

    final result = <SkinHealthPoint>[rawPoints.first];
    for (var i = 1; i < rawPoints.length; i++) {
      final prev = rawPoints[i - 1];
      final curr = rawPoints[i];
      result.add(
        SkinHealthPoint(
          periodStart: curr.periodStart,
          score: curr.score,
          recordCount: curr.recordCount,
          trend: _compareScores(prev.score, curr.score),
        ),
      );
    }
    return result;
  }

  /// KETENTUAN #1: kategori "Kemajuan" PER RECORD (bukan per titik
  /// grafik) — dipakai kartu riwayat (`_RecordCard` di pages.dart) untuk
  /// menampilkan chip "Kemajuan" / "Perlu Perhatian". Membandingkan
  /// [current] dengan [previous] (record TEPAT SEBELUMNYA secara
  /// kronologis).
  ///
  /// - Skor [current] lebih tinggi dari [previous] (masalah tipe kulit
  ///   berkurang/hilang) -> `SkinTrend.improving` ("Kemajuan").
  /// - Skor [current] lebih rendah (masalah bertambah) ->
  ///   `SkinTrend.worsening` ("Perlu Perhatian").
  /// - Sama saja, atau salah satu data belum bisa dinilai -> `null`
  ///   (kartu tidak menampilkan chip apa pun, supaya tidak menyesatkan).
  static SkinTrend? progressBetween(
      AnalysisRecord? previous,
      AnalysisRecord current,
      ) {
    if (previous == null) return null;
    final prevScore = healthScoreOf(previous);
    final currScore = healthScoreOf(current);
    if (prevScore == null || currScore == null) return null;
    final trend = _compareScores(prevScore, currScore);
    return trend == SkinTrend.stable ? null : trend;
  }

  /// KETENTUAN BARU: ringkasan "Tingkat Kulit Sehat" dari DUA SCAN
  /// TERAKHIR (bukan agregat per periode seperti `buildTimeline`) --
  /// dipakai untuk menampilkan detail perbandingan di bawah grafik,
  /// baik status hasilnya "Perlu Perhatian", "Stabil", maupun
  /// "Membaik". [allRecords] boleh dikirim apa adanya (urutan bebas) --
  /// diurutkan ulang di sini berdasarkan `capturedAt` supaya "2 scan
  /// terakhir" selalu benar secara kronologis, terlepas urutan input.
  ///
  /// Sumber data SAMA PERSIS dengan yang dipakai ReportPage &
  /// AnalysisPage (`AnalysisRepository.records`), jadi hasil di kedua
  /// halaman selalu konsisten satu sama lain.
  static LastScanComparison compareLastTwoScans(
      List<AnalysisRecord> allRecords,
      ) {
    final sorted = List<AnalysisRecord>.of(allRecords)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    if (sorted.length < 2) {
      final only = sorted.isNotEmpty ? sorted.first : null;
      return LastScanComparison(
        trend: SkinTrend.insufficientData,
        previousScore: null,
        currentScore: only != null ? healthScoreOf(only) : null,
        previousDate: null,
        currentDate: only?.capturedAt,
      );
    }

    final current = sorted[0];
    final previous = sorted[1];
    final currentScore = healthScoreOf(current);
    final previousScore = healthScoreOf(previous);

    if (currentScore == null || previousScore == null) {
      return LastScanComparison(
        trend: SkinTrend.insufficientData,
        previousScore: previousScore,
        currentScore: currentScore,
        previousDate: previous.capturedAt,
        currentDate: current.capturedAt,
      );
    }

    return LastScanComparison(
      trend: _compareScores(previousScore, currentScore),
      previousScore: previousScore,
      currentScore: currentScore,
      previousDate: previous.capturedAt,
      currentDate: current.capturedAt,
    );
  }
}