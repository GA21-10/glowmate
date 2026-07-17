// lib/app/pages/camera/model/camera.dart
//
// UPDATE BESAR (perombakan sesuai 10 ketentuan terbaru):
//
// 1/2. UI & alur ON/OFF kamera dipertahankan — enum status di bawah ini
//    hanya diganti NAMA dua nilai tengahnya (`detecting`/`humanFound`
//    -> `stabilizing`/`confirmed`) supaya jujur mencerminkan alur BARU:
//    kamera sekarang menunggu kondisi PENCAHAYAAN & KESTABILAN yang baik
//    (lihat `enggine/capture_quality_engine.dart` +
//    `controller/camera.dart`), BUKAN lagi menunggu wajah terdeteksi.
//
// 3. `KnownUserDataSnapshot.ageLabel` TETAP ADA & TETAP diisi dari
//    `UserModel.ageLabel` (data usia dari provider/model user GLOBAL,
//    lihat `KnownUserDataSnapshot.fromUser`) — inilah "data usia dari
//    global" yang diikutsertakan ke halaman kamera lalu diteruskan apa
//    adanya ke halaman Analisis (ketentuan #3). Popup tidak pernah
//    menampilkannya (ketentuan #6), tapi datanya tetap ada & mengalir.
//
// 4. Kontrak data yang DITANGKAP kamera & DIKIRIM ke halaman Analisis
//    TIDAK BERUBAH SAMA SEKALI dibanding versi sebelumnya:
//    `CameraCaptureResult` masih punya field yang PERSIS SAMA
//    (imageBytes, imagePath, capturedAt, detectedHumanCount,
//    knownUserData, isFaceCropped, captureAttempts, mesh3D) dengan tipe
//    yang sama, supaya `AnalysisRepository.addFromCapture` (di luar
//    folder camera/) tidak perlu diubah sedikit pun. Yang berubah HANYA
//    nilai yang diisi ke sebagian field itu, sebagai konsekuensi wajar
//    dari ketentuan #5 (lihat catatan di field `isFaceCropped` & `mesh3D`
//    di bawah).
//
// 5. Semua hal yang berbau "wajah" (deteksi ML Kit/MediaPipe, outline,
//    crop-ke-outline) sudah dihapus total dari MODUL kamera. Model ini
//    sendiri tidak pernah menyimpan outline (tidak pernah ada field
//    outline di sini), jadi tidak ada yang perlu dihapus dari FILE ini
//    secara langsung — perubahan intinya ada di controller & enggine.
//
// 7. `mesh3D` (bertipe `FaceMeshSnapshot?`, lihat model/face_mesh.dart)
//    TETAP DIPERTAHANKAN sebagai field supaya `Face3DViewer` di halaman
//    lain (mis. AnalysisPage/ReportPage) tetap punya kontrak data yang
//    valid untuk merekonstruksi tampilan 3D dari record LAMA. Kamera
//    sendiri SELALU mengirim `null` di sini sekarang (tidak ada lagi
//    sumber landmark), lihat `captureFinalData()` di controller.
import 'dart:typed_data';

import '../../../core/models/users/global.dart';
import '../../account/paket/model/berlangganan.dart';
import 'mesh.dart';

/// Status indikator kecil di pojok kanan atas top bar.
/// - notReady -> MERAH : kamera belum bisa dipakai (masih init / error)
/// - ready    -> BIRU  : kamera menyala & siap (belum stabil sepenuhnya)
/// - detected -> HIJAU : kondisi sudah dikonfirmasi baik (popup tampil)
enum CameraIndicatorStatus { notReady, ready, detected }

/// Status internal halaman kamera.
///
/// - initializing : kamera sedang dinyalakan.
/// - ready         : kamera hidup, sedang memantau pencahayaan/gerakan.
/// - stabilizing   : kondisi (pencahayaan+gerakan) sudah bagus & sedang
///                   ditahan beberapa detik untuk memastikan benar-benar
///                   stabil sebelum lanjut (menggantikan bekas "wajah
///                   terdeteksi 5 detik" versi lama — sekarang berbasis
///                   kualitas gambar, BUKAN wajah, ketentuan #5/#8/#9).
/// - confirmed     : kondisi terkonfirmasi baik -> popup ditampilkan.
/// - capturing     : sedang mengambil & memproses foto akhir.
/// - error         : kamera gagal diinisialisasi / error lain.
enum CameraPageStatus {
  initializing,
  ready,
  stabilizing,
  confirmed,
  capturing,
  error,
}

/// Potret data user yang SUDAH diketahui, diambil dari `UserModel` tepat
/// sebelum popup "ANALISIS SELESAI" ditampilkan.
///
/// Kenapa snapshot (bukan referensi langsung ke UserModel)? Supaya hasil
/// akhir (`CameraCaptureResult`) membawa data yang PERSIS sama dengan
/// yang berlaku tepat saat proses berlangsung, meski UserProvider
/// berubah setelahnya. Halaman berikutnya (Analisis) tidak perlu tahu
/// apa-apa soal Provider, cukup baca field di sini.
///
/// CATATAN ketentuan #3: `ageLabel` adalah data usia yang diambil dari
/// GLOBAL user model (`UserModel.ageLabel`, dihitung dari tanggal
/// lahir) — ditangkap di sini SAMA seperti field lain, dan mengalir apa
/// adanya sampai ke halaman Analisis lewat `CameraCaptureResult`.
class KnownUserDataSnapshot {
  final String? name;
  final String? ageLabel;
  final String? fullAddress;
  final String? fullPhone;
  final List<SkinType> skinTypes;
  final SkinConditionStatus? skinCondition;
  final SubscriptionPlan subscriptionPlan;

  const KnownUserDataSnapshot({
    this.name,
    this.ageLabel,
    this.fullAddress,
    this.fullPhone,
    this.skinTypes = const [],
    this.skinCondition,
    this.subscriptionPlan = SubscriptionPlan.free,
  });

  /// Bangun snapshot dari `UserModel` — hanya field yang statusnya "sudah
  /// diketahui" (hasName/hasAddress/hasBirthDate/dll di global.dart) yang
  /// diisi, selain itu null/kosong. Kalau [user] null (belum login),
  /// hasilnya snapshot kosong.
  factory KnownUserDataSnapshot.fromUser(UserModel? user) {
    if (user == null) return const KnownUserDataSnapshot();
    return KnownUserDataSnapshot(
      name: user.hasName ? user.name : null,
      // Ketentuan #3: usia diambil dari data GLOBAL user (dihitung dari
      // tanggal lahir tersimpan di UserProvider/UserModel), ditangkap di
      // sini untuk halaman kamera lalu diteruskan apa adanya.
      ageLabel: user.hasBirthDate ? user.ageLabel : null,
      fullAddress: user.hasAddress ? user.fullAddress : null,
      fullPhone: user.hasPhone ? user.fullPhone : null,
      skinTypes: user.skinTypes,
      skinCondition: user.skinCondition,
      subscriptionPlan: user.subscriptionPlan,
    );
  }

  /// True kalau TIDAK ADA satupun data yang sudah diketahui.
  bool get isEmpty =>
      name == null &&
          ageLabel == null &&
          fullAddress == null &&
          fullPhone == null &&
          skinTypes.isEmpty &&
          skinCondition == null;
}

/// Data akhir yang dibawa ke halaman berikutnya (AnalysisPage) setelah
/// tombol SELESAI di popup ditekan.
///
/// KONTRAK FIELD TIDAK BERUBAH (ketentuan #4) dibanding versi
/// sebelumnya — lihat catatan per-field untuk konsekuensi ketentuan #5.
class CameraCaptureResult {
  final Uint8List imageBytes;
  final String? imagePath; // null di web
  final DateTime capturedAt;
  final int detectedHumanCount;

  /// Sama persis dengan yang "diam-diam" tersimpan sebelum popup tampil
  /// (ketentuan #3/#6) — termasuk `ageLabel`.
  final KnownUserDataSnapshot knownUserData;

  /// Ketentuan #5: fitur crop-ke-outline wajah sudah DIHAPUS TOTAL
  /// (tidak ada lagi sumber outline sama sekali). Field ini TETAP
  /// dipertahankan (ketentuan #4, supaya kontrak `AnalysisRepository`
  /// tidak berubah) tapi sekarang SELALU `false` — foto akhir yang
  /// dikirim selalu foto PENUH (sudah diperjelas otomatis oleh
  /// `CaptureQualityEngine`, bukan dipotong berdasarkan wajah).
  final bool isFaceCropped;

  /// Jumlah percobaan pengambilan foto. >1 berarti sempat diulang
  /// otomatis karena hasil foto terdeteksi kurang tajam/goyang oleh
  /// `CaptureQualityEngine` (ketentuan #8/#9 — pengecekan level piksel,
  /// bukan lagi level wajah).
  final int captureAttempts;

  /// Ketentuan #5/#7: kamera tidak lagi memiliki sumber landmark wajah
  /// apa pun, jadi field ini SELALU `null` dari kamera sekarang. Tetap
  /// dipertahankan bertipe `FaceMeshSnapshot?` supaya `Face3DViewer` di
  /// halaman lain tetap kompatibel untuk data historis.
  final FaceMeshSnapshot? mesh3D;

  const CameraCaptureResult({
    required this.imageBytes,
    required this.capturedAt,
    required this.detectedHumanCount,
    required this.knownUserData,
    this.imagePath,
    this.isFaceCropped = false,
    this.captureAttempts = 1,
    this.mesh3D,
  });

  @override
  String toString() =>
      'CameraCaptureResult(path: $imagePath, humans: $detectedHumanCount, '
          'at: $capturedAt, knownData: ${knownUserData.isEmpty ? "kosong" : "ada"}, '
          'age: ${knownUserData.ageLabel ?? "-"}, '
          'cropped: $isFaceCropped, attempts: $captureAttempts, '
          'mesh3D: ${mesh3D == null ? "tidak ada" : "${mesh3D!.landmarks.length} titik"})';
}