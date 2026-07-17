// lib/app/pages/camera/enggine/face3d_painter.dart
//
// DIPERTAHANKAN UTUH (ketentuan #7 — "pertahankan 3D viewer pada file
// file yang lama di file terbaru"). Widget `Face3DViewer` di file ini
// TIDAK BERUBAH sama sekali secara fungsional dibanding versi lama:
// tetap menggambar grid latar, point-cloud, garis kontur wajah dengan
// kurva halus (`buildClosedFaceOutlinePath` dari geometry.dart),
// pewarnaan titik berdasarkan kedalaman (z), serta interaksi drag untuk
// memutar tampilan yang otomatis kembali ke depan (damping).
//
// CATATAN PENTING soal integrasi dengan modul kamera yang baru: karena
// seluruh engine deteksi wajah (ML Kit/MediaPipe) sudah dihapus total
// dari `controller/camera.dart` (ketentuan #5), kamera SEKARANG TIDAK
// PERNAH lagi menghasilkan `FaceMeshSnapshot` baru — `mesh` yang
// dikirim ke widget ini dari alur live kamera akan selalu `null`.
// Widget ini tetap dipertahankan APA ADANYA supaya:
//   1. Halaman lain (mis. AnalysisPage/ReportPage) yang merekonstruksi
//      `FaceMeshSnapshot` dari RECORD LAMA/HISTORIS (sebelum fitur mesh
//      3D dihapus dari kamera) tetap bisa menampilkannya dengan benar.
//   2. Kalau suatu saat sumber landmark baru ditambahkan lagi ke
//      project ini, panel "3D CONSTRUCTION" tidak perlu ditulis ulang
//      dari nol.
// `mesh == null` sudah ditangani dengan aman di `paint()` (grid kosong
// saja, tidak crash).
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../model/mesh.dart';
import 'geometry.dart';
import 'math.dart' as math3d;

class Face3DViewer extends StatefulWidget {
  const Face3DViewer({
    super.key,
    required this.mesh,
    required this.size,
    this.showSkin = true,
  });

  /// Snapshot mesh 3D yang ingin ditampilkan (biasanya data historis).
  /// Null -> panel menampilkan grid kosong saja.
  final FaceMeshSnapshot? mesh;

  final Size size;

  /// True -> kontur wajah digambar dengan fill tipis ("kulit"). False ->
  /// wireframe murni tanpa fill.
  final bool showSkin;

  @override
  State<Face3DViewer> createState() => _Face3DViewerState();
}

class _Face3DViewerState extends State<Face3DViewer>
    with SingleTickerProviderStateMixin {
  double _rotateX = 0;
  double _rotateY = 0;
  double _targetRotateX = 0;
  double _targetRotateY = 0;
  Offset? _lastDragPosition;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Loop animasi ringan yang men-damping rotasi kembali ke depan saat
    // tidak sedang di-drag.
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastDragPosition == null) {
      _targetRotateX *= 0.92;
      _targetRotateY *= 0.92;
    }
    final nextX = _rotateX + (_targetRotateX - _rotateX) * 0.08;
    final nextY = _rotateY + (_targetRotateY - _rotateY) * 0.08;

    if ((nextX - _rotateX).abs() > 0.0002 ||
        (nextY - _rotateY).abs() > 0.0002 ||
        _targetRotateX.abs() > 0.0002 ||
        _targetRotateY.abs() > 0.0002) {
      setState(() {
        _rotateX = nextX;
        _rotateY = nextY;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _lastDragPosition = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final last = _lastDragPosition;
    if (last == null) return;
    final delta = details.localPosition - last;
    _lastDragPosition = details.localPosition;

    setState(() {
      _targetRotateY = (_targetRotateY + delta.dx * 0.01).clamp(-1.2, 1.2);
      _targetRotateX = (_targetRotateX + delta.dy * 0.01).clamp(-1.0, 1.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _lastDragPosition = null;
  }

  void _onPanCancel() {
    _lastDragPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: Container(
        width: widget.size.width,
        height: widget.size.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00D0FF), width: 2),
          gradient: const RadialGradient(
            colors: [Color(0xFF002838), Colors.black],
            radius: 1.15,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x8000D0FF), blurRadius: 20, spreadRadius: 1),
          ],
        ),
        child: CustomPaint(
          painter: _Face3DPainter(
            mesh: widget.mesh,
            rotateX: _rotateX,
            rotateY: _rotateY,
            showSkin: widget.showSkin,
          ),
        ),
      ),
    );
  }
}

class _Face3DPainter extends CustomPainter {
  _Face3DPainter({
    required this.mesh,
    required this.rotateX,
    required this.rotateY,
    required this.showSkin,
  });

  final FaceMeshSnapshot? mesh;
  final double rotateX;
  final double rotateY;
  final bool showSkin;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    final m = mesh;
    if (m == null || m.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final centerY = h / 2;

    final anchors = _resolveFaceAnchors(m, w, h);
    if (anchors == null) return;
    final faceCenterX = anchors[0];
    final faceCenterY = anchors[1];
    final faceWidth = anchors[2];
    if (faceWidth <= 1) return;

    final offsetX = centerX - faceCenterX;
    final offsetY = centerY - faceCenterY;

    final targetWidth = w * 0.38;
    final scale = targetWidth / faceWidth;
    final isMp = m.isMediaPipeIndexing;

    final projected = <math3d.Projected3D>[];
    for (var i = 0; i < m.landmarks.length; i++) {
      final p = m.landmarks[i];

      var x = p.x * w + offsetX;
      var y = p.y * h + offsetY;

      x = centerX + (x - centerX) * scale;
      y = centerY + (y - centerY) * scale;

      x += (x - centerX) * 0.15;

      if (isMp && math3d.kMediaPipeForeheadIndices.contains(i)) {
        final fh = math3d.createSymmetricForehead(x, y, centerX);
        x = fh.dx;
        y = fh.dy;
      }

      projected.add(math3d.rotate3D(
        x,
        y,
        p.z * scale,
        rotateX: rotateX,
        rotateY: rotateY,
        centerX: centerX,
        centerY: centerY,
        perspectiveDistance: h * 1.9,
      ));
    }

    _drawConnections(canvas, projected, w);
    _drawPoints(canvas, projected, w);
    _drawContour(canvas, projected, m.contourIndices, w);
  }

  List<double>? _resolveFaceAnchors(FaceMeshSnapshot m, double w, double h) {
    final li = m.leftFaceIndex, ri = m.rightFaceIndex;
    final ti = m.topFaceIndex, bi = m.bottomFaceIndex;

    if (li != null &&
        ri != null &&
        ti != null &&
        bi != null &&
        li < m.landmarks.length &&
        ri < m.landmarks.length &&
        ti < m.landmarks.length &&
        bi < m.landmarks.length) {
      final left = m.landmarks[li];
      final right = m.landmarks[ri];
      final top = m.landmarks[ti];
      final bottom = m.landmarks[bi];
      return [
        (left.x + right.x) / 2 * w,
        (top.y + bottom.y) / 2 * h,
        (right.x - left.x).abs() * w,
      ];
    }

    if (m.landmarks.isEmpty) return null;
    double minX = m.landmarks.first.x, maxX = m.landmarks.first.x;
    double minY = m.landmarks.first.y, maxY = m.landmarks.first.y;
    for (final p in m.landmarks) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return [
      (minX + maxX) / 2 * w,
      (minY + maxY) / 2 * h,
      (maxX - minX) * w,
    ];
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00B4FF).withOpacity(0.06)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  double _mirror(double x, double w) => w - x;

  void _drawConnections(
      Canvas canvas,
      List<math3d.Projected3D> points,
      double w,
      ) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF00DCFF).withOpacity(0.15)
      ..strokeWidth = 1;
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      canvas.drawLine(
        Offset(_mirror(p1.x, w), p1.y),
        Offset(_mirror(p2.x, w), p2.y),
        paint,
      );
    }
  }

  void _drawPoints(Canvas canvas, List<math3d.Projected3D> points, double w) {
    for (final p in points) {
      final x = _mirror(p.x, w);
      final y = p.y;
      final z = p.z;

      var radius = 3.2 - z * 1.6;
      if (radius < 1) radius = 1;

      var alpha = 1.2 - (z * 2).abs();
      if (alpha < 0.2) alpha = 0.2;
      if (alpha > 1) alpha = 1;

      var green = (180 + (-z * 220)).round();
      if (green < 0) green = 0;
      if (green > 255) green = 255;

      final paint = Paint()
        ..color = Color.fromRGBO(0, green, 255, alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawContour(
      Canvas canvas,
      List<math3d.Projected3D> points,
      List<int> contourIndices,
      double w,
      ) {
    if (contourIndices.length < 3) return;

    final contour = <Offset>[];
    for (final idx in contourIndices) {
      if (idx < 0 || idx >= points.length) continue;
      final p = points[idx];
      contour.add(Offset(_mirror(p.x, w), p.y));
    }
    if (contour.length < 3) return;

    final path = buildClosedFaceOutlinePath(contour);

    if (showSkin) {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF00FFFF).withOpacity(0.06);
      canvas.drawPath(path, fillPaint);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF00FFFF).withOpacity(0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF00FFFF).withOpacity(0.85);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _Face3DPainter oldDelegate) {
    return oldDelegate.mesh != mesh ||
        oldDelegate.rotateX != rotateX ||
        oldDelegate.rotateY != rotateY ||
        oldDelegate.showSkin != showSkin;
  }
}