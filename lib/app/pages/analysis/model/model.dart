// lib/app/pages/analysis/model/model.dart
//
// UPDATE (3D view di kartu riwayat menggantikan field hitam polos):
// `AnalysisRecord` sekarang menyimpan bukan cuma titik landmark mentah
// (`faceLandmarks`), tapi juga metadata yang dibutuhkan untuk merekonstruksi
// `FaceMeshSnapshot` PERSIS seperti yang dipakai `Face3DViewer` di halaman
// kamera (`contourIndices`, anchor kiri/kanan/atas/bawah, `hasMeshDepth`,
// `isMediaPipeIndexing`). Semua ini datang APA ADANYA dari
// `CameraCaptureResult.mesh3D` saat capture (lihat
// `AnalysisRepository.addFromCapture`) -- halaman analisis TIDAK PERNAH
// menghasilkan data 3D sendiri, hanya menggambar ulang data yang sudah
// dibekukan di halaman kamera. Lihat `toFaceMeshSnapshot()` di bawah.

import '../../camera/model/mesh.dart';

/// Status pemrosesan satu record analisis.
/// - captured   : foto baru diambil, belum ada hasil analisis apa pun.
/// - analyzing  : sedang diproses (dipakai nanti kalau analisis async/API).
/// - completed  : hasil analisis (mis. skor kulit) sudah tersedia.
enum AnalysisStatus { captured, analyzing, completed }

/// Teks placeholder untuk "Temuan Tipe Kulit Terbaru" selama fitur
/// analisis lanjutan memang belum tersedia -- SAMA PERSIS dengan yang
/// ditampilkan di popup kamera (popup.dart) & yang disimpan lewat
/// `AnalysisRepository.addFromCapture()`.
const kLatestFindingPlaceholder = 'Sabar ya, fitur sedang dikembangkan';

AnalysisStatus _statusFromName(String? name) {
  return AnalysisStatus.values.firstWhere(
        (s) => s.name == name,
    orElse: () => AnalysisStatus.captured,
  );
}

/// Parsing List<String> yang aman dari JSON dinamis (dipakai utk field
/// baru `knownSkinTypes` maupun saat memigrasi data lama).
List<String> _stringListFrom(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).toList(growable: false);
  }
  return const [];
}

/// Parsing List<int> aman dari JSON dinamis (dipakai untuk
/// `contourIndices`). Record lama tidak punya key ini -> `[]`.
List<int> _intListFrom(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => (e as num).toInt()).toList(growable: false);
}

/// Parsing aman `List<List<double>>` (titik landmark `[x,y,z]`) dari JSON
/// dinamis. Record lama (sebelum fitur 3D view) tidak punya key ini sama
/// sekali -> otomatis balik `[]`, bukan error.
List<List<double>> _landmarksFrom(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<List>()
      .map(
        (point) => point
        .map((v) => (v as num).toDouble())
        .toList(growable: false),
  )
      .where((p) => p.length >= 2)
      .toList(growable: false);
}

/// Satu entri riwayat hasil analisis kamera.
///
/// UPDATE (selaras dengan revisi AnalysisPage & CameraCaptureResult):
/// 1. `knownSkinTypes` — BERUBAH dari `knownSkinTypesLabel` (String hasil
///    join ', ') menjadi `List<String>`. Ini WAJIB supaya setiap tipe
///    kulit bisa dirender sebagai chip TERPISAH yang bisa di-klik
///    satu-persatu di AnalysisPage (ketentuan: tipe kulit bisa diklik,
///    klik menampilkan data itu saja, default ambil yang paling kiri).
///    Getter `knownSkinTypesLabel` tetap disediakan (kompatibilitas
///    mundur) untuk kode lain yang mungkin masih mengharap satu String.
/// 2. `isFaceCropped` & `captureAttempts` — BARU, disalin apa adanya dari
///    `CameraCaptureResult` (lihat pages/camera/model/camera.dart).
///    `isFaceCropped` penting bagi AnalysisPage: kalau true, `imagePath`
///    adalah PNG ber-alpha hasil `FaceCaptureProcessor.cropToFaceOutline`
///    (area di luar outline wajah transparan) sehingga aman ditampilkan
///    di atas field HITAM (area transparan otomatis terlihat hitam,
///    hanya wajah yang tampak). Kalau false, foto adalah foto penuh biasa
///    (JPEG, platform fallback tanpa landmark).
///
/// Gerbangnya SAMA PERSIS dengan popup.dart:
/// - `knownSkinConditionLabel == null` -> kondisi kulit belum diketahui
///   -> `knownSkinTypes` & `knownLatestFindingLabel` ikut kosong/null.
/// - `knownSkinConditionLabel != null` -> `knownSkinTypes` terisi kalau
///   datanya ada, dan `knownLatestFindingLabel` SELALU terisi placeholder
///   selama fitur analisis lanjutannya belum tersedia.
class AnalysisRecord {
  final String id;
  final DateTime capturedAt;
  final int detectedHumanCount;

  /// Path file foto di penyimpanan internal. Null di Web.
  final String? imagePath;

  final AnalysisStatus status;

  /// Hasil analisis (mis. skor kulit 0-100). Null selama belum dianalisis.
  final double? skinScore;

  /// Slot bebas untuk hasil analisis tambahan lain di masa depan
  /// (mis. {"skinProblems": [...]}).
  final Map<String, dynamic>? analysisData;

  /// True kalau [imagePath] adalah PNG ber-alpha hasil crop-ke-outline
  /// (lihat penjelasan panjang di header class).
  final bool isFaceCropped;

  /// Jumlah percobaan pengambilan foto (>1 = sempat auto-retake karena
  /// goyang/blur, lihat FaceCaptureProcessor.isLikelyShaken/isImageLikelyBlurry).
  final int captureAttempts;

  /// Kondisi Kulit — gerbang utama (lihat catatan gerbang di atas).
  final String? knownSkinConditionLabel;

  /// Tipe Kulit — daftar per-item (bukan lagi satu String gabungan),
  /// supaya masing-masing bisa jadi chip yang bisa dipilih satu per satu
  /// di AnalysisPage. Hanya terisi kalau Kondisi Kulit sudah diketahui.
  final List<String> knownSkinTypes;

  /// Temuan Tipe Kulit Terbaru — untuk saat ini selalu berisi teks
  /// placeholder ketika Kondisi Kulit sudah diketahui.
  final String? knownLatestFindingLabel;

  /// Titik-titik landmark wajah 3D (mis. 468 titik MediaPipe Face Mesh)
  /// yang DIAMBIL SAAT CAPTURE di halaman kamera — BUKAN dihasilkan di
  /// halaman ini. Setiap entri adalah `[x, y, z]` ternormalisasi persis
  /// seperti output deteksi wajah kamera (x,y dalam rentang 0..1 relatif
  /// lebar/tinggi frame, z adalah kedalaman relatif).
  ///
  /// Dipakai `Face3DView` (lihat pages/analysis/widgets/face_3d_view.dart)
  /// untuk merekonstruksi "3D construction" seperti pada referensi
  /// point-cloud wajah — ditampilkan di field hitam kartu riwayat,
  /// bisa diputar dengan drag. Kosong (`[]`) untuk record lama yang
  /// diambil sebelum fitur ini ada (fallback otomatis ke foto datar).
  final List<List<double>> faceLandmarks;

  /// Indeks landmark pembentuk kontur oval wajah tertutup -- SAMA PERSIS
  /// dengan `FaceMeshSnapshot.contourIndices` yang dibekukan di halaman
  /// kamera saat capture. Dipakai `Face3DViewer` untuk menggambar garis
  /// pinggir wajah pada rekonstruksi 3D.
  final List<int> contourIndices;

  /// Anchor kiri/kanan/atas/bawah wajah (skema MediaPipe: 234/454/10/152)
  /// -- null kalau tidak tersedia (mis. ML Kit di Android/iOS), viewer
  /// akan fallback ke bounding-box seluruh titik.
  final int? leftFaceIndex;
  final int? rightFaceIndex;
  final int? topFaceIndex;
  final int? bottomFaceIndex;

  /// True kalau nilai z pada [faceLandmarks] benar-benar merepresentasikan
  /// kedalaman (Web/MediaPipe). False kalau z hanya diisi 0 (Android/iOS
  /// lewat ML Kit) -- SAMA PERSIS `FaceMeshSnapshot.hasDepth`.
  final bool hasMeshDepth;

  /// True kalau [faceLandmarks] mengikuti skema indeks 468 titik MediaPipe
  /// -- SAMA PERSIS `FaceMeshSnapshot.isMediaPipeIndexing`.
  final bool isMediaPipeIndexing;

  const AnalysisRecord({
    required this.id,
    required this.capturedAt,
    required this.detectedHumanCount,
    required this.status,
    this.imagePath,
    this.skinScore,
    this.analysisData,
    this.isFaceCropped = false,
    this.captureAttempts = 1,
    this.knownSkinConditionLabel,
    this.knownSkinTypes = const [],
    this.knownLatestFindingLabel,
    this.faceLandmarks = const [],
    this.contourIndices = const [],
    this.leftFaceIndex,
    this.rightFaceIndex,
    this.topFaceIndex,
    this.bottomFaceIndex,
    this.hasMeshDepth = false,
    this.isMediaPipeIndexing = false,
  });

  /// True kalau record ini punya data landmark 3D yang cukup untuk
  /// direkonstruksi jadi "3D construction" (bukan sekadar foto datar).
  bool get hasFaceLandmarks => faceLandmarks.length >= 50;

  /// Rekonstruksi `FaceMeshSnapshot` dari data yang tersimpan, SAMA PERSIS
  /// data yang dibekukan `CameraPageController` saat capture -- dipakai
  /// `Face3DViewer` di kartu riwayat AnalysisPage menggantikan foto datar
  /// di atas field hitam. Null kalau data landmark tidak cukup (record
  /// lama sebelum fitur ini ada, atau platform capture tanpa mesh sama
  /// sekali).
  FaceMeshSnapshot? toFaceMeshSnapshot() {
    if (!hasFaceLandmarks) return null;
    return FaceMeshSnapshot(
      landmarks: faceLandmarks
          .map((p) => FaceLandmark3D(p[0], p[1], p.length > 2 ? p[2] : 0))
          .toList(growable: false),
      contourIndices: contourIndices,
      leftFaceIndex: leftFaceIndex,
      rightFaceIndex: rightFaceIndex,
      topFaceIndex: topFaceIndex,
      bottomFaceIndex: bottomFaceIndex,
      hasDepth: hasMeshDepth,
      isMediaPipeIndexing: isMediaPipeIndexing,
    );
  }

  /// Kompatibilitas mundur: kode lain (mis. RecommendationPage) yang
  /// masih mengharap satu String gabungan seperti versi sebelumnya.
  String? get knownSkinTypesLabel =>
      knownSkinTypes.isEmpty ? null : knownSkinTypes.join(', ');

  /// True kalau ADA setidaknya satu dari 3 data prioritas yang sudah
  /// diketahui, dipakai AnalysisPage untuk menentukan apakah menampilkan
  /// chip data di kartu riwayat.
  bool get hasKnownData =>
      knownSkinConditionLabel != null ||
          knownSkinTypes.isNotEmpty ||
          knownLatestFindingLabel != null;

  AnalysisRecord copyWith({
    AnalysisStatus? status,
    double? skinScore,
    Map<String, dynamic>? analysisData,
  }) {
    return AnalysisRecord(
      id: id,
      capturedAt: capturedAt,
      detectedHumanCount: detectedHumanCount,
      imagePath: imagePath,
      isFaceCropped: isFaceCropped,
      captureAttempts: captureAttempts,
      status: status ?? this.status,
      skinScore: skinScore ?? this.skinScore,
      analysisData: analysisData ?? this.analysisData,
      knownSkinConditionLabel: knownSkinConditionLabel,
      knownSkinTypes: knownSkinTypes,
      knownLatestFindingLabel: knownLatestFindingLabel,
      faceLandmarks: faceLandmarks,
      contourIndices: contourIndices,
      leftFaceIndex: leftFaceIndex,
      rightFaceIndex: rightFaceIndex,
      topFaceIndex: topFaceIndex,
      bottomFaceIndex: bottomFaceIndex,
      hasMeshDepth: hasMeshDepth,
      isMediaPipeIndexing: isMediaPipeIndexing,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'capturedAt': capturedAt.toIso8601String(),
    'detectedHumanCount': detectedHumanCount,
    'imagePath': imagePath,
    'status': status.name,
    'skinScore': skinScore,
    'analysisData': analysisData,
    'isFaceCropped': isFaceCropped,
    'captureAttempts': captureAttempts,
    'knownSkinConditionLabel': knownSkinConditionLabel,
    'knownSkinTypes': knownSkinTypes,
    'knownLatestFindingLabel': knownLatestFindingLabel,
    'faceLandmarks': faceLandmarks,
    'contourIndices': contourIndices,
    'leftFaceIndex': leftFaceIndex,
    'rightFaceIndex': rightFaceIndex,
    'topFaceIndex': topFaceIndex,
    'bottomFaceIndex': bottomFaceIndex,
    'hasMeshDepth': hasMeshDepth,
    'isMediaPipeIndexing': isMediaPipeIndexing,
  };

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    // MIGRASI DATA LAMA: sebelum revisi ini, tipe kulit tersimpan sebagai
    // satu String gabungan di key 'knownSkinTypesLabel'. Kalau key BARU
    // ('knownSkinTypes') belum ada di data tersimpan tapi key LAMA ada,
    // pecah string lama itu jadi List supaya riwayat lama tetap tampil
    // benar (bukan hilang begitu saja) setelah update ini.
    List<String> skinTypes;
    if (json.containsKey('knownSkinTypes')) {
      skinTypes = _stringListFrom(json['knownSkinTypes']);
    } else {
      final legacy = json['knownSkinTypesLabel'] as String?;
      skinTypes =
      (legacy == null || legacy.isEmpty) ? const [] : legacy.split(', ');
    }

    return AnalysisRecord(
      id: json['id'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      detectedHumanCount: json['detectedHumanCount'] as int? ?? 0,
      imagePath: json['imagePath'] as String?,
      status: _statusFromName(json['status'] as String?),
      skinScore: (json['skinScore'] as num?)?.toDouble(),
      analysisData: (json['analysisData'] as Map?)?.cast<String, dynamic>(),
      isFaceCropped: json['isFaceCropped'] as bool? ?? false,
      captureAttempts: json['captureAttempts'] as int? ?? 1,
      // NOTE: record lama mungkin masih punya key seperti
      // 'knownName'/'knownAddress'/dll di JSON tersimpan — sengaja
      // dibiarkan, key yang sudah tidak dipakai lagi otomatis terabaikan
      // di sini tanpa error.
      knownSkinConditionLabel: json['knownSkinConditionLabel'] as String?,
      knownSkinTypes: skinTypes,
      knownLatestFindingLabel: json['knownLatestFindingLabel'] as String?,
      faceLandmarks: _landmarksFrom(json['faceLandmarks']),
      // Record lama (sebelum fitur 3D view di AnalysisPage) tidak punya
      // key-key ini sama sekali -> otomatis fallback ke default aman
      // (list kosong / null / false), bukan error.
      contourIndices: _intListFrom(json['contourIndices']),
      leftFaceIndex: (json['leftFaceIndex'] as num?)?.toInt(),
      rightFaceIndex: (json['rightFaceIndex'] as num?)?.toInt(),
      topFaceIndex: (json['topFaceIndex'] as num?)?.toInt(),
      bottomFaceIndex: (json['bottomFaceIndex'] as num?)?.toInt(),
      hasMeshDepth: json['hasMeshDepth'] as bool? ?? false,
      isMediaPipeIndexing: json['isMediaPipeIndexing'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'AnalysisRecord(id: $id, humans: $detectedHumanCount, '
          'at: $capturedAt, hasKnownData: $hasKnownData, '
          'cropped: $isFaceCropped, attempts: $captureAttempts, '
          'landmarks: ${faceLandmarks.length})';
}