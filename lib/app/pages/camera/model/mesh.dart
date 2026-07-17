// lib/app/pages/camera/model/face_mesh.dart
//
// DIPERTAHANKAN (ketentuan #7 — "pertahankan 3D viewer pada file file
// yang lama di file terbaru"): model ini TIDAK DIHAPUS walau seluruh
// engine deteksi wajah (ML Kit / MediaPipe) sudah dihapus total
// (ketentuan #5). Alasannya:
//   - `enggine/face3d_painter.dart` (`Face3DViewer`, panel "3D
//     CONSTRUCTION") masih memakai tipe ini untuk menggambar ulang
//     riwayat mesh 3D yang SUDAH tersimpan (mis. dari record analisis
//     lama), jadi widget viewer-nya sendiri tetap harus punya tipe data
//     yang valid untuk dibaca.
//   - `CameraCaptureResult.mesh3D` (model/camera.dart) tetap punya field
//     bertipe `FaceMeshSnapshot?` supaya kontrak data yang dikirim ke
//     halaman Analisis TIDAK BERUBAH (ketentuan #4) dibanding versi
//     sebelumnya — hanya saja sekarang nilainya SELALU null, karena
//     sumber datanya (engine deteksi wajah) sudah tidak ada lagi.
//
// TIDAK ADA perubahan struktur pada file ini dibanding versi lama.
import 'dart:ui';

/// Satu titik landmark wajah. x & y ternormalisasi 0..1 relatif terhadap
/// frame gambar. z ternormalisasi relatif terhadap lebar wajah, HANYA
/// valid kalau `FaceMeshSnapshot.hasDepth == true`.
class FaceLandmark3D {
  final double x;
  final double y;
  final double z;
  const FaceLandmark3D(this.x, this.y, this.z);

  Offset toOffset(double width, double height) =>
      Offset(x * width, y * height);
}

/// Snapshot mesh 3D wajah pada satu momen (dipakai HANYA untuk
/// merekonstruksi/menggambar ulang data historis di `Face3DViewer` —
/// lihat catatan di header file ini soal kenapa tipe ini tetap ada
/// meski kamera sendiri sudah tidak pernah menghasilkan data baru).
class FaceMeshSnapshot {
  final List<FaceLandmark3D> landmarks;

  /// Indeks landmark pembentuk kontur oval wajah tertutup, dipakai
  /// `Face3DViewer` untuk menggambar garis pinggir wajah.
  final List<int> contourIndices;

  /// Indeks anchor kiri/kanan/atas/bawah wajah (skema MediaPipe: 234,
  /// 454, 10, 152) dipakai untuk menghitung pusat & skala wajah. Null
  /// kalau tidak tersedia — viewer akan fallback ke bounding-box seluruh
  /// titik.
  final int? leftFaceIndex;
  final int? rightFaceIndex;
  final int? topFaceIndex;
  final int? bottomFaceIndex;

  /// True kalau nilai z benar-benar merepresentasikan kedalaman.
  final bool hasDepth;

  /// True kalau `landmarks` mengikuti skema indeks 468 titik MediaPipe.
  final bool isMediaPipeIndexing;

  const FaceMeshSnapshot({
    required this.landmarks,
    required this.contourIndices,
    this.leftFaceIndex,
    this.rightFaceIndex,
    this.topFaceIndex,
    this.bottomFaceIndex,
    required this.hasDepth,
    required this.isMediaPipeIndexing,
  });

  bool get isEmpty => landmarks.isEmpty;
}