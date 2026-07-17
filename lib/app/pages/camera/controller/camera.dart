// lib/app/pages/camera/controller/camera.dart
//
// State + business logic halaman kamera. Tidak ada widget/UI di sini.
//
// PEROMBAKAN BESAR dibanding versi lama, sesuai ketentuan:
//
// (#2) FUNGSI KAMERA ITU SENDIRI DIPERTAHANKAN: start()/pauseForBackground()/
//   resumeFromBackground()/stopAndClear() TETAP ada dengan tanggung jawab
//   yang SAMA PERSIS (nyalakan kamera, kelola siklus hidup, matikan
//   total saat halaman ditutup) — hanya isi pemantauan framenya yang
//   diganti total (lihat poin #5/#8/#9 di bawah).
//
// (#5) SEMUA fungsi/metode yang berhubungan dengan WAJAH sudah dihapus
//   total dari controller ini: tidak ada lagi HumanDetectionService, ML
//   Kit, MediaPipe, outline wajah (`faceOutlinePoints`), pembekuan mesh
//   3D dari live detection, crop-ke-outline, maupun deteksi "goyang"
//   berbasis pergerakan landmark. Semua referensi ke folder
//   `services/detector/` sudah dihapus dari import.
//
// (#8/#9) DIGANTI dengan `CaptureQualityEngine` (enggine/
//   capture_quality_engine.dart) — engine BUATAN SENDIRI yang bekerja di
//   level piksel & metadata kamera (BUKAN wajah) untuk:
//     - Auto-exposure: kalau frame gelap, exposure offset kamera
//       dinaikkan bertahap (dan flash torch dinyalakan sebagai bantuan
//       tambahan kalau exposure sudah mentok, khusus platform yang
//       mendukung); kalau kelebihan cahaya, diturunkan lagi.
//     - Deteksi stabil/goyang lewat perbandingan "sidik jari" piksel
//       antar-frame (bukan landmark wajah).
//     - Begitu kondisi (cahaya + stabil) sudah baik & bertahan penuh
//       selama `_confirmationDelay`, alur OTOMATIS lanjut ke popup —
//       PERSIS pola "tahan X detik lalu lanjut" versi lama, hanya
//       pemicunya sekarang kualitas gambar, bukan wajah terdeteksi.
//     - Di platform/format yang TIDAK BISA dianalisis piksel-nya (mis.
//       Web yang framenya JPEG terkompresi, atau sebagian desktop native
//       yang tidak mendukung image stream sama sekali) -> otomatis
//       fallback ke "grace period" (jeda singkat lalu tetap lanjut),
//       supaya alur TETAP OTOMATIS di semua platform (Android, iOS, Web,
//       Windows, macOS, Linux) seperti diminta ketentuan #9, bukannya
//       menggantung menunggu sesuatu yang memang tidak bisa diukur di
//       sana.
//   - Foto akhir juga diproses lewat `CaptureQualityEngine.enhanceFinalImage`
//     (upscale halus + pertajam kalau resolusi rendah) dan dicek ulang
//     levelnya lewat `CaptureQualityEngine.isLikelyBlurry` sebelum
//     benar-benar diterima — kalau masih kurang tajam, otomatis diambil
//     ulang (maks beberapa kali) TANPA aksi apa pun dari pengguna.
//
// (#4) Data yang DIKIRIM lewat `captureFinalData()` (CameraCaptureResult)
//   TETAP memakai kontrak field yang SAMA PERSIS seperti sebelumnya —
//   lihat catatan di model/camera.dart untuk konsekuensi nilai per field.
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier, Uint8List;

import '../enggine/quality.dart';
import '../model/camera.dart';
import '../services/camera.dart';

class CameraPageController extends ChangeNotifier {
  CameraPageController({
    CameraService? cameraService,
    CaptureQualityEngine? qualityEngine,
  })  : _cameraService = cameraService ?? CameraService(),
        _qualityEngine = qualityEngine ?? CaptureQualityEngine();

  final CameraService _cameraService;
  final CaptureQualityEngine _qualityEngine;

  /// Lama kondisi (cahaya+stabil) harus bertahan TANPA gangguan sebelum
  /// dianggap terkonfirmasi & popup ditampilkan. Menggantikan makna
  /// "5 detik wajah terdeteksi" versi lama dengan "5 detik kondisi
  /// gambar bagus" — nilainya sengaja dipertahankan sama (5 detik) demi
  /// konsistensi rasa alur bagi pengguna.
  static const _confirmationDelay = Duration(seconds: 5);

  /// Maksimal percobaan ulang otomatis kalau foto akhir masih terdeteksi
  /// kurang tajam (ketentuan #8/#9).
  static const _maxCaptureRetries = 3;

  /// Jarak minimum antar penyesuaian exposure offset, supaya kamera
  /// tidak "kedip-kedip" menyesuaikan tiap frame (yang justru bikin
  /// preview terlihat gemetar) — penyesuaian dibuat halus & bertahap.
  static const _exposureAdjustInterval = Duration(milliseconds: 350);

  /// Jeda "grace period" dipakai di platform/format yang tidak bisa
  /// dianalisis piksel-nya sama sekali (ketentuan #9 — tetap harus
  /// otomatis lanjut di semua platform).
  static const _graceDelayNoAnalysis = Duration(seconds: 3);

  CameraController? get controller => _cameraService.controller;

  CameraPageStatus _status = CameraPageStatus.initializing;
  CameraPageStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Default MERAH: kamera dianggap belum siap sampai start() berhasil.
  CameraIndicatorStatus _indicatorStatus = CameraIndicatorStatus.notReady;
  CameraIndicatorStatus get indicatorStatus => _indicatorStatus;

  bool _showPopup = false;
  bool get showPopup => _showPopup;

  /// True selama controller sedang mengambil ulang foto otomatis akibat
  /// hasil terdeteksi kurang tajam (ketentuan #8/#9).
  bool _isRetrying = false;
  bool get isRetryingCapture => _isRetrying;

  /// Pesan status kualitas kamera saat ini, ditampilkan kecil di UI
  /// (mis. "Menyesuaikan pencahayaan...", "Menstabilkan kamera...").
  /// Menggantikan overlay outline hijau versi lama sebagai bentuk umpan
  /// balik visual ke pengguna (ketentuan #5 — tidak ada lagi outline di
  /// atas preview, tapi pengguna tetap perlu tahu apa yang sedang
  /// terjadi).
  String _qualityMessage = 'Menyiapkan kamera...';
  String get qualityMessage => _qualityMessage;

  /// True kalau platform/format frame saat ini BISA dianalisis mentah
  /// oleh `CaptureQualityEngine` (lihat `_isRawPixelFormat` di sana).
  /// False -> UI bisa menampilkan sedikit info bahwa penyesuaian
  /// otomatis berjalan lebih sederhana di platform ini (grace period).
  bool _analysisSupported = true;
  bool get analysisSupported => _analysisSupported;

  double? _minExposureOffset;
  double? _maxExposureOffset;
  double _currentExposureOffset = 0;
  DateTime? _lastExposureAdjustAt;
  bool _flashOn = false;

  Timer? _stabilityTimer;
  Timer? _graceTimer;
  bool _isStreaming = false;
  bool _isStarting = false;
  bool _isDisposed = false;

  /// Nyalakan kamera. Dipanggil sekali saat halaman kamera dibuka (dan
  /// lagi saat resume dari background).
  Future<void> start() async {
    if (_isStarting || _isDisposed) return;
    _isStarting = true;

    _setStatus(CameraPageStatus.initializing);
    _setIndicator(CameraIndicatorStatus.notReady); // MERAH selama belum siap

    try {
      await _cameraService.initializeCamera();
      if (_isDisposed) {
        await _cameraService.dispose();
        return;
      }

      _errorMessage = null;
      _qualityEngine.reset();
      _currentExposureOffset = 0;
      _flashOn = false;
      _qualityMessage = 'Menyesuaikan kondisi kamera...';
      _setStatus(CameraPageStatus.ready);
      _setIndicator(CameraIndicatorStatus.ready); // BIRU: kamera siap

      await _prepareExposureRange();
      await _beginQualityMonitoring();
    } catch (e) {
      if (_isDisposed) return;
      _errorMessage = e.toString();
      _setStatus(CameraPageStatus.error);
      _setIndicator(CameraIndicatorStatus.notReady);
    } finally {
      _isStarting = false;
    }
  }

  /// Ambil rentang exposure offset yang benar-benar didukung device saat
  /// ini — dipakai `CaptureQualityEngine.recommendExposureOffset` supaya
  /// penyesuaian tidak pernah melebihi kemampuan hardware. Sebagian
  /// platform (mis. beberapa desktop) tidak mendukung ini sama sekali ->
  /// ditangkap dengan aman, auto-exposure lewat offset otomatis
  /// dilewati di sana (kamera tetap dipakai apa adanya).
  Future<void> _prepareExposureRange() async {
    final c = controller;
    if (c == null) return;
    try {
      _minExposureOffset = await c.getMinExposureOffset();
      _maxExposureOffset = await c.getMaxExposureOffset();
    } catch (_) {
      _minExposureOffset = null;
      _maxExposureOffset = null;
    }
  }

  /// Mulai memantau kualitas frame (kecerahan & kestabilan). Kalau
  /// platform ini tidak mendukung image stream sama sekali (umumnya
  /// sebagian desktop native), fallback ke grace-period supaya alur
  /// tetap otomatis lanjut (ketentuan #9).
  Future<void> _beginQualityMonitoring() async {
    final c = controller;
    if (c == null) return;

    try {
      if (!c.value.isStreamingImages) {
        await c.startImageStream(_onFrame);
      }
      _isStreaming = true;
      _analysisSupported = true;
    } catch (_) {
      _isStreaming = false;
      _analysisSupported = false;
      _startGracePeriod();
    }
  }

  /// Jeda singkat tanpa analisis piksel, lalu anggap kondisi sudah cukup
  /// baik (mengandalkan auto-exposure bawaan OS/driver kamera) supaya
  /// alur tetap otomatis lanjut walau di platform yang tidak bisa
  /// diukur kualitas frame-nya secara langsung.
  void _startGracePeriod() {
    _qualityMessage = 'Menyiapkan pengambilan otomatis...';
    notifyListeners();
    _graceTimer?.cancel();
    _graceTimer = Timer(_graceDelayNoAnalysis, () {
      if (_isDisposed || _showPopup) return;
      _startStabilityTimerIfNeeded();
    });
  }

  void _onFrame(CameraImage image) {
    if (_isDisposed || _showPopup || _status == CameraPageStatus.capturing) {
      return;
    }

    final sample = _qualityEngine.sample(image);
    if (sample.brightness == null) {
      // Format frame di platform ini ternyata tidak bisa dianalisis
      // mentah (mis. Web yang mengirim JPEG lewat image stream) ->
      // hentikan stream (tidak ada gunanya terus dipanggil) dan pindah
      // ke jalur grace-period yang sama seperti desktop tanpa streaming.
      if (_analysisSupported) {
        _analysisSupported = false;
        _stopStreamSafely();
        _startGracePeriod();
      }
      return;
    }

    _maybeAdjustExposure(sample.brightness!);

    final wellLit = _qualityEngine.isWellLit(sample.brightness!);
    final stable = _qualityEngine.isStable(sample.motionScore);

    if (wellLit && stable) {
      _qualityMessage = 'Kondisi bagus, menahan sebentar...';
      _startStabilityTimerIfNeeded();
    } else {
      _stabilityTimer?.cancel();
      _stabilityTimer = null;
      if (_status == CameraPageStatus.stabilizing) {
        _setStatus(CameraPageStatus.ready);
      }
      _qualityMessage = !wellLit
          ? (sample.brightness! < CaptureQualityEngine.targetBrightness
          ? 'Menyesuaikan pencahayaan (terlalu gelap)...'
          : 'Menyesuaikan pencahayaan (terlalu terang)...')
          : 'Menstabilkan kamera, tahan sebentar...';
    }
    notifyListeners();
  }

  /// Auto-exposure: naikkan/turunkan exposure offset kamera secara
  /// bertahap berdasar kecerahan frame terkini, dan nyalakan flash torch
  /// sebagai bantuan tambahan kalau exposure sudah mentok maksimum tapi
  /// masih gelap (khusus platform yang mendukung flash — dibungkus
  /// try/catch supaya aman di platform yang tidak punya, mis. web/
  /// desktop).
  void _maybeAdjustExposure(double brightness) {
    final c = controller;
    final minO = _minExposureOffset;
    final maxO = _maxExposureOffset;
    if (c == null || minO == null || maxO == null) return;

    final now = DateTime.now();
    if (_lastExposureAdjustAt != null &&
        now.difference(_lastExposureAdjustAt!) < _exposureAdjustInterval) {
      return;
    }

    final next = _qualityEngine.recommendExposureOffset(
      currentOffset: _currentExposureOffset,
      brightness: brightness,
      minOffset: minO,
      maxOffset: maxO,
    );

    final shouldFlash = _qualityEngine.isTooDark(brightness) && next >= maxO - 0.05;
    if (shouldFlash != _flashOn) {
      _flashOn = shouldFlash;
      c.setFlashMode(shouldFlash ? FlashMode.torch : FlashMode.off)
          .catchError((_) {});
    }

    if ((next - _currentExposureOffset).abs() < 0.05) return;
    _currentExposureOffset = next;
    _lastExposureAdjustAt = now;
    c.setExposureOffset(next).catchError((_) => 0.0);
  }

  void _startStabilityTimerIfNeeded() {
    if (_stabilityTimer != null || _showPopup) return;
    if (_status != CameraPageStatus.stabilizing) {
      _setStatus(CameraPageStatus.stabilizing);
    }
    _stabilityTimer = Timer(_confirmationDelay, _confirmReady);
  }

  /// Fallback manual untuk pengguna: langsung lanjutkan tanpa menunggu
  /// penuh — berguna kalau kondisi ruangan sudah dirasa cukup baik namun
  /// auto-monitoring sedang lambat, atau di platform yang memang tidak
  /// bisa dianalisis (grace period). Menggantikan tombol "SAYA SUDAH
  /// SIAP" versi lama yang dulu hanya muncul di platform tanpa ML Kit —
  /// sekarang tersedia SERAGAM di semua platform (ketentuan #9).
  void continueNow() {
    if (_isDisposed || _showPopup) return;
    if (controller == null || !controller!.value.isInitialized) return;
    if (_status == CameraPageStatus.error ||
        _status == CameraPageStatus.initializing ||
        _status == CameraPageStatus.capturing) {
      return;
    }
    _graceTimer?.cancel();
    _graceTimer = null;
    _stabilityTimer?.cancel();
    _stabilityTimer = null;
    _confirmReady();
  }

  Future<void> _confirmReady() async {
    _stabilityTimer = null;
    if (_isDisposed || _showPopup) return;

    await _stopStreamSafely();
    if (_isDisposed) return;

    // Matikan torch (kalau sempat dinyalakan) sebelum shutter final,
    // supaya tidak mengganggu exposure foto akhir.
    if (_flashOn) {
      _flashOn = false;
      try {
        await controller?.setFlashMode(FlashMode.off);
      } catch (_) {}
    }

    _showPopup = true;
    _qualityMessage = 'Siap!';
    _indicatorStatus = CameraIndicatorStatus.detected; // HIJAU
    _setStatus(CameraPageStatus.confirmed);
  }

  /// Dipanggil setelah tombol SELESAI di popup ditekan. [knownUserData]
  /// WAJIB diisi oleh pemanggil (pages.dart) — persis sama dengan data
  /// yang sudah dipegang sebelum popup tampil (ketentuan #3/#6), supaya
  /// data yang dikirim ke halaman Analisis konsisten.
  ///
  /// (#8/#9) Foto akhir diperjelas otomatis (`enhanceFinalImage`) dan
  /// dicek ketajamannya (`isLikelyBlurry`); kalau masih kurang tajam,
  /// otomatis diambil ulang (maks `_maxCaptureRetries` kali) sebelum
  /// hasil dikembalikan ke UI — semua tanpa aksi apa pun dari pengguna.
  Future<CameraCaptureResult> captureFinalData({
    required KnownUserDataSnapshot knownUserData,
  }) async {
    _setStatus(CameraPageStatus.capturing);

    Uint8List? finalBytes;
    String? finalPath;
    var attempts = 0;

    try {
      while (true) {
        attempts++;
        final file = await _cameraService.captureFinalImage();
        var bytes = await file.readAsBytes();

        bytes = await CaptureQualityEngine.enhanceFinalImage(bytes);

        final isBlurry = await CaptureQualityEngine.isLikelyBlurry(bytes);

        if (!isBlurry || attempts >= _maxCaptureRetries) {
          finalBytes = bytes;
          finalPath = kIsWeb ? null : file.path;
          break;
        }

        _isRetrying = true;
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 400));
        if (_isDisposed) break;
      }
    } finally {
      _isRetrying = false;
    }

    return CameraCaptureResult(
      imageBytes: finalBytes!,
      imagePath: finalPath,
      capturedAt: DateTime.now(),
      detectedHumanCount: 1,
      knownUserData: knownUserData,
      // Ketentuan #5: tidak ada lagi crop-ke-outline wajah -> selalu
      // false (lihat catatan lengkap di model/camera.dart).
      isFaceCropped: false,
      captureAttempts: attempts,
      // Ketentuan #5/#7: tidak ada lagi sumber landmark wajah -> selalu
      // null (lihat catatan lengkap di model/camera.dart).
      mesh3D: null,
    );
  }

  Future<void> _stopStreamSafely() async {
    if (!_isStreaming) return;
    _isStreaming = false;
    try {
      await _cameraService.stopImageStream();
    } catch (_) {}
  }

  /// App masuk background -> hentikan stream & timer, tapi controller
  /// tetap ada.
  void pauseForBackground() {
    if (_status == CameraPageStatus.initializing || _showPopup) return;
    _stabilityTimer?.cancel();
    _stabilityTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _stopStreamSafely();
  }

  /// App kembali ke foreground -> re-init total (paling aman lintas
  /// platform).
  Future<void> resumeFromBackground() async {
    if (_isDisposed || _showPopup) return;
    await start();
  }

  /// Matikan kamera TOTAL & bersihkan semua state. WAJIB dipanggil saat
  /// halaman kamera ditutup (tombol back / pindah tab).
  Future<void> stopAndClear() async {
    _stabilityTimer?.cancel();
    _stabilityTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _isStreaming = false;
    _showPopup = false;
    _errorMessage = null;
    _qualityMessage = 'Menyiapkan kamera...';
    _qualityEngine.reset();
    _currentExposureOffset = 0;

    if (_flashOn) {
      _flashOn = false;
      try {
        await controller?.setFlashMode(FlashMode.off);
      } catch (_) {}
    }

    await _cameraService.dispose();

    _status = CameraPageStatus.initializing;
    _indicatorStatus = CameraIndicatorStatus.notReady; // balik ke MERAH
    if (!_isDisposed) notifyListeners();
  }

  void _setStatus(CameraPageStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  void _setIndicator(CameraIndicatorStatus value) {
    if (_indicatorStatus == value) return;
    _indicatorStatus = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stabilityTimer?.cancel();
    _stabilityTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _cameraService.dispose();
    super.dispose();
  }
}