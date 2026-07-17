// lib/app/pages/camera/enggine/geometry.dart
//
// DIPANGKAS (ketentuan #5 — hapus semua fungsi/metode berhubungan
// dengan wajah termasuk outline wajah pada UI frame kamera):
// versi lama file ini punya 4 fungsi: `buildClosedFaceOutlinePath`,
// `tessellateClosedFaceOutline`, `isPointInsidePolygon`, dan
// `boundingBoxWithPadding`. Tiga fungsi terakhir HANYA dipakai untuk
// crop-ke-outline wajah (`FaceCaptureProcessor.cropToFaceOutline`,
// sudah dihapus) & painter outline hijau di preview kamera
// (`FaceOutlinePainter`, sudah dihapus) — jadi ketiganya ikut dihapus.
//
// `buildClosedFaceOutlinePath` TETAP DIPERTAHANKAN karena masih dipakai
// `enggine/face3d_painter.dart` (`Face3DViewer`) untuk menggambar garis
// kontur pada panel "3D CONSTRUCTION" (ketentuan #7 — 3D viewer tetap
// ada) — ini murni fungsi geometri kurva umum, tidak spesifik wajah,
// dan tidak pernah dipakai untuk overlay/crop pada frame kamera.
import 'dart:ui';

/// Ubah titik-titik kontur "kasar" menjadi path tertutup yang HALUS,
/// dengan teknik: mulai dari titik tengah (P[n-1], P[0]), lalu setiap
/// titik jadi *control point* kurva quadratic menuju titik tengah
/// pasangan berikutnya, dan kembali menutup ke titik awal (closed
/// Catmull-Rom-like spline tanpa titik "patah" di sambungan akhir->awal).
///
/// Dipakai HANYA oleh `Face3DViewer` (enggine/face3d_painter.dart) untuk
/// menggambar kontur wajah pada panel 3D — TIDAK PERNAH dipakai untuk
/// overlay atau crop pada frame kamera live (fitur itu sudah dihapus,
/// ketentuan #5).
Path buildClosedFaceOutlinePath(List<Offset> points) {
  final n = points.length;
  if (n < 3) return Path();

  final start = Offset(
    (points[n - 1].dx + points[0].dx) / 2,
    (points[n - 1].dy + points[0].dy) / 2,
  );

  final path = Path()..moveTo(start.dx, start.dy);

  for (int i = 0; i < n; i++) {
    final current = points[i];
    final next = points[(i + 1) % n];
    final midX = (current.dx + next.dx) / 2;
    final midY = (current.dy + next.dy) / 2;
    path.quadraticBezierTo(current.dx, current.dy, midX, midY);
  }

  path.close();
  return path;
}