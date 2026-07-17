// lib/app/pages/analysis/widgets/skin_health_chart.dart
//
// Grafik "Tingkat Kulit Sehat" (kemajuan analisis kulit dari waktu ke
// waktu). Semua logika angka/kalkulasi ada di
// `pages/analysis/model/skin_health.dart` (`SkinHealthAnalyzer`) --
// widget ini murni bertugas menggambar & menyediakan switch
// Per Hari/Bulan/Tahun.
//
// Dipakai murni sebagai CustomPainter (tanpa dependency chart eksternal
// tambahan) supaya konsisten dengan gaya `Face3DViewer` di modul kamera
// (lihat pages/camera/enggine/face3d_painter.dart).
import 'package:flutter/material.dart';

import '../model/data.dart';
import '../model/model.dart';
import 'model/health.dart';

class SkinHealthChart extends StatefulWidget {
  const SkinHealthChart({super.key, required this.records});

  /// SELURUH riwayat (bukan cuma yang tampil di daftar "Riwayat
  /// Deteksi" pada AnalysisPage) -- grafik harus selalu menghitung dari
  /// data keseluruhan, terlepas dari berapa banyak yang ditampilkan di
  /// daftar riwayat. Lihat pemakaian di pages.dart.
  final List<AnalysisRecord> records;

  @override
  State<SkinHealthChart> createState() => _SkinHealthChartState();
}

class _SkinHealthChartState extends State<SkinHealthChart> {
  ChartPeriod _period = ChartPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Dihitung ULANG setiap build -- baik karena tombol period di-klik
    // (setState di bawah) MAUPUN karena `widget.records` berubah (ada
    // capture/report baru masuk lewat AnalysisRepository di halaman
    // lain) -- sehingga grafik selalu realtime, tidak pernah memakai
    // data basi/cache.
    final points = SkinHealthAnalyzer.buildTimeline(widget.records, _period);
    // KETENTUAN BARU: perbandingan 2 SCAN TERAKHIR (bukan agregat per
    // periode) -- dipakai kartu ringkasan di bawah grafik. Sumbernya
    // `widget.records`, SELALU SELURUH riwayat, sama seperti sumber
    // yang dibaca ReportPage & AnalysisPage lewat AnalysisRepository
    // yang sama -- jadi hasilnya selalu konsisten di kedua halaman.
    final lastScanComparison =
    SkinHealthAnalyzer.compareLastTwoScans(widget.records);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tingkat Kulit Sehat',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _LatestTrendBadge(points: points),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rata-rata skor kesehatan kulit dari seluruh riwayat, '
                'dikelompokkan ${_period.label.toLowerCase()}.',
            style: TextStyle(
              fontSize: 11.5,
              color: cs.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: points.length < 2
                ? _ChartEmptyState(pointCount: points.length)
                : CustomPaint(
              painter: _SkinHealthPainter(
                points: points,
                period: _period,
                textColor: cs.onSurface.withOpacity(0.55),
                gridColor: cs.outline.withOpacity(0.12),
                neutralColor: cs.onSurface.withOpacity(0.35),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildLegend(cs),
          const SizedBox(height: 14),
          _buildPeriodSelector(cs),
          // KETENTUAN BARU: kalau status hasilnya "Perlu Perhatian"
          // (worsening), "Stabil" (stable), ATAU "Membaik" (improving)
          // -- tampilkan detail perbandingan skor dari 2 kali scan
          // terakhir. Kalau data belum cukup (< 2 scan yang bisa
          // dinilai), kartu ini tidak ditampilkan sama sekali.
          if (lastScanComparison.isComparable) ...[
            const SizedBox(height: 14),
            _LastScanComparisonCard(comparison: lastScanComparison),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(ColorScheme cs) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        const _LegendDot(color: Colors.green, label: 'Membaik'),
        const _LegendDot(color: Colors.redAccent, label: 'Memburuk'),
        _LegendDot(
          color: cs.onSurface.withOpacity(0.35),
          label: 'Stabil / belum cukup data',
        ),
      ],
    );
  }

  /// KETENTUAN #4: 3 tombol Per Hari/Bulan/Tahun -- klik salah satu ->
  /// `setState` -> `build()` jalan ulang -> `SkinHealthAnalyzer
  /// .buildTimeline` dipanggil ULANG dengan `_period` baru -> grafik
  /// otomatis menghitung ulang secara realtime, sesuai permintaan.
  Widget _buildPeriodSelector(ColorScheme cs) {
    return Row(
      children: ChartPeriod.values.map((p) {
        final selected = p == _period;
        final isLast = p == ChartPeriod.values.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                    selected ? cs.primary : cs.outline.withOpacity(0.15),
                  ),
                ),
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? cs.onPrimary : cs.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _LatestTrendBadge extends StatelessWidget {
  const _LatestTrendBadge({required this.points});
  final List<SkinHealthPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final trend = points.last.trend;
    final (color, label, icon) = switch (trend) {
      SkinTrend.improving => (
      Colors.green,
      'Membaik',
      Icons.trending_up_rounded
      ),
      SkinTrend.worsening => (
      Colors.redAccent,
      'Memburuk',
      Icons.trending_down_rounded
      ),
      SkinTrend.stable => (
      Colors.blueGrey,
      'Stabil',
      Icons.trending_flat_rounded
      ),
      SkinTrend.insufficientData => (
      Colors.grey,
      'Data belum cukup',
      Icons.hourglass_empty_rounded
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkasan perbandingan DUA SCAN TERAKHIR -- ditampilkan di
/// bawah grafik "Tingkat Kulit Sehat" saat statusnya "Perlu Perhatian"
/// (memburuk), "Stabil", atau "Membaik" (lihat
/// `LastScanComparison.isComparable`). Data yang dipakai SAMA PERSIS
/// dengan yang dibaca ReportPage & AnalysisPage lewat
/// `AnalysisRepository` yang sama, sehingga angka & tanggal di kartu
/// ini selalu konsisten di kedua halaman.
class _LastScanComparisonCard extends StatelessWidget {
  const _LastScanComparisonCard({required this.comparison});
  final LastScanComparison comparison;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trend = comparison.trend;
    final (color, label, icon) = switch (trend) {
      SkinTrend.improving => (
      Colors.green,
      'Membaik',
      Icons.trending_up_rounded,
      ),
      SkinTrend.worsening => (
      Colors.redAccent,
      'Perlu Perhatian',
      Icons.trending_down_rounded,
      ),
      SkinTrend.stable => (
      Colors.blueGrey,
      'Stabil',
      Icons.trending_flat_rounded,
      ),
      SkinTrend.insufficientData => (
      Colors.grey,
      'Data belum cukup',
      Icons.hourglass_empty_rounded,
      ),
    };

    final prevScore = comparison.previousScore!;
    final currScore = comparison.currentScore!;
    final prevDate = comparison.previousDate!;
    final currDate = comparison.currentDate!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                'Berdasarkan 2 scan terakhir',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ScanScoreTile(
                  title: 'Scan Sebelumnya',
                  date: formatTanggalSingkat(prevDate),
                  score: prevScore,
                  cs: cs,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: cs.onSurface.withOpacity(0.35),
                ),
              ),
              Expanded(
                child: _ScanScoreTile(
                  title: 'Scan Terbaru',
                  date: formatTanggalSingkat(currDate),
                  score: currScore,
                  cs: cs,
                  highlight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanScoreTile extends StatelessWidget {
  const _ScanScoreTile({
    required this.title,
    required this.date,
    required this.score,
    required this.cs,
    this.highlight = false,
  });

  final String title;
  final String date;
  final double score;
  final ColorScheme cs;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? cs.primary.withOpacity(0.08) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? cs.primary.withOpacity(0.2)
              : cs.outline.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? cs.primary : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Ditampilkan selagi titik data belum cukup untuk digambar sebagai
/// garis (minimal 2 titik). KETENTUAN #2 (warmup 5 titik untuk tren)
/// berjalan TERPISAH dari ini -- begitu ada >= 2 titik, garis & skor
/// tetap digambar (lihat `_SkinHealthPainter`), hanya warna trennya yang
/// baru berarti setelah titik ke-5.
class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.pointCount});
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insights_rounded,
            size: 28,
            color: cs.onSurface.withOpacity(0.25),
          ),
          const SizedBox(height: 8),
          Text(
            pointCount == 0
                ? 'Belum ada data untuk periode ini'
                : 'Butuh minimal 2 titik data untuk mulai menggambar grafik',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

/// Garis grafik sederhana (tanpa dependency eksternal). Tiap SEGMEN
/// diwarnai sesuai tren TITIK TUJUANNYA -- KETENTUAN #3: kalau report
/// terus bertambah tanpa perubahan, skor & garis tetap flat/rendah;
/// begitu ada perkembangan (masalah berkurang), garis naik & berwarna
/// hijau.
class _SkinHealthPainter extends CustomPainter {
  _SkinHealthPainter({
    required this.points,
    required this.period,
    required this.textColor,
    required this.gridColor,
    required this.neutralColor,
  });

  final List<SkinHealthPoint> points;
  final ChartPeriod period;
  final Color textColor;
  final Color gridColor;
  final Color neutralColor;

  static const _leftAxisWidth = 26.0;
  static const _bottomAxisHeight = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(
      _leftAxisWidth,
      4,
      size.width - _leftAxisWidth,
      size.height - _bottomAxisHeight - 4,
    );

    _drawGrid(canvas, chartRect);
    _drawYLabels(canvas, chartRect);

    final xs = List.generate(points.length, (i) {
      if (points.length == 1) return chartRect.left + chartRect.width / 2;
      return chartRect.left + (chartRect.width / (points.length - 1)) * i;
    });

    double yOf(double score) {
      final t = score.clamp(0, 100) / 100;
      return chartRect.bottom - (t * chartRect.height);
    }

    for (var i = 0; i < points.length - 1; i++) {
      final p1 = Offset(xs[i], yOf(points[i].score));
      final p2 = Offset(xs[i + 1], yOf(points[i + 1].score));
      final paint = Paint()
        ..color = _colorForTrend(points[i + 1].trend)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }

    for (var i = 0; i < points.length; i++) {
      final center = Offset(xs[i], yOf(points[i].score));
      final color = i == 0 ? neutralColor : _colorForTrend(points[i].trend);
      canvas.drawCircle(center, 4, Paint()..color = color);
      canvas.drawCircle(
        center,
        4,
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    _drawXLabels(canvas, chartRect, xs);
  }

  Color _colorForTrend(SkinTrend trend) {
    switch (trend) {
      case SkinTrend.improving:
        return Colors.green;
      case SkinTrend.worsening:
        return Colors.redAccent;
      case SkinTrend.stable:
        return Colors.blueGrey;
      case SkinTrend.insufficientData:
        return neutralColor;
    }
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = rect.top + (rect.height / 4) * i;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
  }

  void _drawYLabels(Canvas canvas, Rect rect) {
    const values = [100, 75, 50, 25, 0];
    for (var i = 0; i < values.length; i++) {
      final y = rect.top + (rect.height / 4) * i;
      _paintText(canvas, '${values[i]}', Offset(0, y - 6), width: 22);
    }
  }

  void _drawXLabels(Canvas canvas, Rect rect, List<double> xs) {
    // Maksimal ~4 label supaya tidak berdesakan kalau titiknya banyak.
    final step = (points.length / 4).ceil().clamp(1, points.length);
    for (var i = 0; i < points.length; i += step) {
      _paintText(
        canvas,
        _formatLabel(points[i].periodStart),
        Offset(xs[i] - 16, rect.bottom + 6),
        width: 32,
      );
    }
  }

  String _formatLabel(DateTime dt) {
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    switch (period) {
      case ChartPeriod.daily:
        return '${dt.day} ${bulan[dt.month - 1]}';
      case ChartPeriod.monthly:
        return '${bulan[dt.month - 1]} ${dt.year % 100}';
      case ChartPeriod.yearly:
        return '${dt.year}';
    }
  }

  void _paintText(
      Canvas canvas,
      String text,
      Offset offset, {
        double width = 24,
      }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SkinHealthPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.period != period;
  }
}