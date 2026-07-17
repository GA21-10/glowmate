// lib/app/pages/camera/enggine/face3d_math.dart
//
// DIPERTAHANKAN (ketentuan #7): fungsi rotasi/proyeksi 3D murni
// (`rotate3D`) dipakai `enggine/face3d_painter.dart` (`Face3DViewer`)
// untuk menggambar ulang mesh 3D dari record HISTORIS (mis. di
// AnalysisPage/ReportPage). File ini TIDAK bergantung pada engine
// deteksi wajah apa pun — murni matematika geometri — sehingga aman
// tetap ada meski seluruh ML Kit/MediaPipe sudah dihapus dari modul
// kamera (ketentuan #5).
//
// `createSymmetricForehead` & konstanta indeks MediaPipe tetap
// dipertahankan karena masih dipakai `Face3DViewer` untuk merapikan
// bentuk dahi pada mesh MediaPipe (isMediaPipeIndexing == true) milik
// data historis — bukan untuk deteksi live apa pun.
import 'dart:math';
import 'dart:ui';

/// Indeks landmark MediaPipe (skema 468 titik) pembentuk kontur oval
/// wajah tertutup — dipakai `Face3DViewer` untuk menggambar kontur pada
/// data historis yang punya `isMediaPipeIndexing == true`.
const List<int> kMediaPipeFaceContour = [
  10,
  338, 297, 332, 284, 251,
  389, 356, 454,
  323, 361,
  288, 397, 365, 379, 378,
  400, 377, 152,
  148, 176, 149, 150,
  136, 172, 58,
  132, 93, 234,
  127, 162, 21, 54, 103, 67,
  109,
];

/// Subset indeks di atas yang termasuk area dahi.
const Set<int> kMediaPipeForeheadIndices = {
  10, 338, 297, 332, 284, 251,
  127, 162, 21, 54, 103, 67, 109,
};

/// Anchor MediaPipe standar (leftFace=234, rightFace=454, topFace=10,
/// bottomFace=152) dipakai untuk menghitung pusat & skala wajah.
const int kMediaPipeLeftFace = 234;
const int kMediaPipeRightFace = 454;
const int kMediaPipeTopFace = 10;
const int kMediaPipeBottomFace = 152;

/// Titik hasil proyeksi 3D->2D; `z` disimpan untuk pewarnaan/urutan depth.
class Projected3D {
  final double x;
  final double y;
  final double z;
  const Projected3D(this.x, this.y, this.z);
}

/// Rotasi Y lalu X di sekitar (centerX, centerY), lalu proyeksi
/// perspektif sederhana. Dipakai `Face3DViewer` saat pengguna men-drag
/// panel 3D untuk memutar tampilan.
Projected3D rotate3D(
    double x,
    double y,
    double z, {
      required double rotateX,
      required double rotateY,
      double centerX = 320,
      double centerY = 240,
      double perspectiveDistance = 900,
    }) {
  var px = x - centerX;
  var py = y - centerY;
  var pz = z;

  final cosY = cos(rotateY);
  final sinY = sin(rotateY);
  final dxY = px * cosY - pz * sinY;
  final dzY = px * sinY + pz * cosY;
  px = dxY;
  pz = dzY;

  final cosX = cos(rotateX);
  final sinX = sin(rotateX);
  final dyX = py * cosX - pz * sinX;
  final dzX = py * sinX + pz * cosX;
  py = dyX;
  pz = dzX;

  final perspective = perspectiveDistance / (perspectiveDistance + pz);
  px *= perspective;
  py *= perspective;

  return Projected3D(px + centerX, py + centerY, pz / 320);
}

/// Makin jauh dari tengah wajah, makin kecil kenaikan lengkungan dahinya
/// (dahi terlihat melengkung natural, bukan naik rata). Dipakai
/// `Face3DViewer` untuk data historis dengan indeks MediaPipe.
Offset createSymmetricForehead(double x, double y, double centerX) {
  final distance = (x - centerX).abs();
  var curveHeight = 60 - (distance * 0.08);
  if (curveHeight < 24) curveHeight = 24;
  return Offset(x, y - curveHeight);
}