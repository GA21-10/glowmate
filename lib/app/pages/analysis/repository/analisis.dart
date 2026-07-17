// lib/app/core/providers/analysis/repository.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/users/global.dart';
import '../../../pages/camera/model/camera.dart' show CameraCaptureResult;
import '../model/model.dart';

/// Single source of truth untuk riwayat hasil analisis.
///
/// Didaftarkan SATU KALI sebagai singleton di root aplikasi (lihat
/// main.dart) lewat `ChangeNotifierProvider.value`. Karena AnalysisPage
/// dan ReportPage sama-sama nonton instance yang PERSIS SAMA ini
/// (bukan instance baru per halaman), begitu salah satu method di sini
/// memanggil `notifyListeners()`, kedua halaman otomatis rebuild dengan
/// data terbaru — itulah mekanisme "realtime sync"-nya, tanpa perlu
/// event bus atau polling apa pun.
///
/// Penyimpanan:
/// - Metadata (waktu, jumlah wajah, status, skor kulit, data user yang
///   sudah diketahui saat capture, dll) disimpan sebagai JSON di
///   shared_preferences — ringan & sesuai kebutuhan.
/// - Foto TIDAK disimpan di shared_preferences (byte foto terlalu besar
///   untuk storage key-value semacam itu). Di Android/iOS/Desktop, foto
///   disimpan sebagai file di folder dokumen aplikasi, dan hanya PATH
///   file itu yang ikut tersimpan di metadata.
/// - Di Web, tidak ada filesystem yang persisten & aman untuk ini, jadi
///   foto sengaja TIDAK dipersist (imagePath null) — hanya metadata
///   (waktu, jumlah wajah, hasil analisis, data user) yang tersimpan.
class AnalysisRepository extends ChangeNotifier {
  static const _prefsKey = 'analysis_records_v1';
  static const _photoFolderName = 'analysis_photos';

  final List<AnalysisRecord> _records = [];
  bool _isLoaded = false;

  /// Riwayat terurut dari yang TERBARU ke TERLAMA.
  List<AnalysisRecord> get records {
    final sorted = List<AnalysisRecord>.of(_records);
    sorted.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return List.unmodifiable(sorted);
  }

  AnalysisRecord? get latest => records.isEmpty ? null : records.first;

  bool get isLoaded => _isLoaded;

  /// Dipanggil sekali saat startup app (lihat main.dart), sebelum
  /// runApp, supaya begitu UI pertama kali render datanya sudah ada.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey) ?? const [];
      _records
        ..clear()
        ..addAll(
          raw.map(
                (s) => AnalysisRecord.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ),
          ),
        );
    } catch (_) {
      // Kalau data korup/gagal parse, mulai dari kosong daripada crash.
      _records.clear();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _records.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Dipanggil setelah tombol SELESAI di CameraPage ditekan & capture
  /// sukses. Ini titik tunggal yang "mengirim data ke penyimpanan
  /// internal" sesuai kebutuhan.
  ///
  /// Hanya 3 DATA PRIORITAS dari `result.knownUserData` yang ditangkap
  /// di sini — persis yang ditampilkan (dan gerbangnya) di popup
  /// "ANALISIS SELESAI": Kondisi Kulit, Tipe Kulit, dan Temuan Tipe
  /// Kulit Terbaru.
  ///
  /// Gerbang logikanya SAMA PERSIS dengan popup.dart:
  /// - `skinCondition == null` -> "belum begitu memahami" -> Tipe Kulit
  ///   & Temuan Tipe Kulit Terbaru ikut kosong/null.
  /// - `skinCondition != null` -> Kondisi Kulit terisi, Tipe Kulit
  ///   terisi kalau datanya ada, dan Temuan Tipe Kulit Terbaru SELALU
  ///   terisi placeholder.
  ///
  /// Selain 3 data prioritas di atas, `result.mesh3D` (data 3D construction
  /// yang dibekukan di halaman kamera) juga disalin apa adanya ke record
  /// -- inilah yang membuat kartu riwayat di AnalysisPage bisa menampilkan
  /// `Face3DViewer` yang sama persis dengan live-preview di kamera,
  /// menggantikan foto datar di atas field hitam.
  Future<AnalysisRecord> addFromCapture(CameraCaptureResult result) async {
    String? imagePath;
    if (!kIsWeb) {
      // BUGFIX: sebelumnya file SELALU disimpan dengan ekstensi ".jpg",
      // padahal byte yang dikirim `FaceCaptureProcessor.cropToFaceOutline`
      // (saat `isFaceCropped == true`) sebenarnya adalah PNG ber-alpha
      // (area di luar outline transparan) -- menyimpannya sebagai ".jpg"
      // menyesatkan (isi file sebenarnya PNG, hanya namanya yang salah)
      // dan berbahaya kalau nanti ada kode lain yang membaca file
      // berdasarkan ekstensi. Sekarang ekstensi mengikuti `isFaceCropped`:
      // true -> ".png" (perlu alpha channel, dipakai AnalysisPage untuk
      // menampilkan wajah di atas field hitam), false -> ".jpg" (foto
      // penuh apa adanya dari kamera, platform fallback tanpa landmark).
      imagePath = await _saveImageToDisk(
        result.imageBytes,
        result.capturedAt,
        isPng: result.isFaceCropped,
      );
    }

    final known = result.knownUserData;
    final skinConditionKnown = known.skinCondition != null;

    // BARU (3D view di kartu riwayat menggantikan field hitam polos):
    // `result.mesh3D` adalah mesh yang SUDAH dibekukan
    // `CameraPageController` tepat saat wajah terkonfirmasi (sama
    // persis sumbernya dengan yang dipakai `Face3DViewer` live di
    // halaman kamera). Di sini kita HANYA menyalin datanya apa adanya
    // ke record -> AnalysisPage nanti merekonstruksi `FaceMeshSnapshot`
    // yang identik lewat `AnalysisRecord.toFaceMeshSnapshot()`, tanpa
    // pernah menghitung ulang/menghasilkan data 3D baru di halaman
    // analisis. Null kalau capture terjadi di platform/alur tanpa
    // sumber landmark sama sekali (mis. manual-confirm desktop native).
    final mesh = result.mesh3D;

    final record = AnalysisRecord(
      id: '${result.capturedAt.microsecondsSinceEpoch}',
      capturedAt: result.capturedAt,
      detectedHumanCount: result.detectedHumanCount,
      imagePath: imagePath,
      isFaceCropped: result.isFaceCropped,
      captureAttempts: result.captureAttempts,
      status: AnalysisStatus.captured,
      knownSkinConditionLabel: known.skinCondition?.label,
      // Disimpan sebagai LIST (bukan lagi String gabungan) supaya
      // AnalysisPage bisa menampilkan tiap tipe kulit sebagai chip yang
      // bisa diklik satu-persatu (lihat pages/analysis/pages.dart).
      knownSkinTypes: (skinConditionKnown && known.skinTypes.isNotEmpty)
          ? known.skinTypes.map((t) => t.label).toList(growable: false)
          : const [],
      knownLatestFindingLabel:
      skinConditionKnown ? kLatestFindingPlaceholder : null,
      faceLandmarks: mesh != null
          ? mesh.landmarks
          .map((l) => [l.x, l.y, l.z])
          .toList(growable: false)
          : const [],
      contourIndices: mesh?.contourIndices ?? const [],
      leftFaceIndex: mesh?.leftFaceIndex,
      rightFaceIndex: mesh?.rightFaceIndex,
      topFaceIndex: mesh?.topFaceIndex,
      bottomFaceIndex: mesh?.bottomFaceIndex,
      hasMeshDepth: mesh?.hasDepth ?? false,
      isMediaPipeIndexing: mesh?.isMediaPipeIndexing ?? false,
    );

    _records.add(record);
    await _persist();
    notifyListeners();
    return record;
  }

  Future<String> _saveImageToDisk(
      Uint8List bytes,
      DateTime capturedAt, {
        required bool isPng,
      }) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/$_photoFolderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final ext = isPng ? 'png' : 'jpg';
    final file =
    File('${folder.path}/${capturedAt.millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Isi/perbarui hasil analisis (skor kulit dll) untuk record tertentu.
  Future<void> updateAnalysisResult(
      String id, {
        double? skinScore,
        Map<String, dynamic>? analysisData,
        AnalysisStatus status = AnalysisStatus.completed,
      }) async {
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _records[idx] = _records[idx].copyWith(
      skinScore: skinScore,
      analysisData: analysisData,
      status: status,
    );
    await _persist();
    notifyListeners();
  }

  /// Titik tunggal untuk mengisi hasil analisis masalah kulit setelah
  /// proses analisis (lokal atau API) selesai — dipanggil dengan `id`
  /// record yang sama dengan yang dikembalikan `addFromCapture()`.
  ///
  /// [skinProblems] adalah daftar label masalah kulit apa adanya (mis.
  /// ["Berjerawat", "Kusam"]) hasil deteksi/analisis. AnalysisPage
  /// menampilkan urutan list ini APA ADANYA (kiri -> kanan) dan secara
  /// default memilih entri PALING KIRI (index 0) sebagai yang aktif
  /// ditampilkan.
  Future<void> updateSkinProblems(
      String id, {
        required List<String> skinProblems,
        double? skinScore,
      }) async {
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    final currentData = Map<String, dynamic>.from(
      _records[idx].analysisData ?? const {},
    );
    currentData['skinProblems'] = skinProblems;

    _records[idx] = _records[idx].copyWith(
      skinScore: skinScore ?? _records[idx].skinScore,
      analysisData: currentData,
      status: AnalysisStatus.completed,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final path = _records[idx].imagePath;
    _records.removeAt(idx);
    await _persist();
    notifyListeners();

    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> clearAll() async {
    final paths = _records.map((r) => r.imagePath).whereType<String>();
    _records.clear();
    await _persist();
    notifyListeners();

    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}