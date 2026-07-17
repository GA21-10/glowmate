// lib/app/pages/camera/services/camera.dart
//
// SATU-SATUNYA sumber CameraService di project ini.
//
// TIDAK ADA PERUBAHAN FUNGSIONAL (ketentuan #2 — pertahankan controller
// untuk ON/OFF kamera & fungsi kamera itu sendiri): file ini murni
// mengurus siklus hidup CameraController (init, image stream, capture,
// dispose) dan TIDAK PERNAH memuat kode yang berhubungan dengan deteksi
// wajah — jadi tidak ada apa pun di sini yang perlu dihapus untuk
// ketentuan #5. Diberikan ulang di sini apa adanya supaya modul kamera
// yang baru tetap satu paket yang lengkap & konsisten.
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';

class UnsupportedCameraPlatformException implements Exception {
  final String message;
  UnsupportedCameraPlatformException(this.message);
  @override
  String toString() => message;
}

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Platform yang didukung package `camera`:
  /// - Android & iOS: implementasi resmi.
  /// - Web: via camera_web.
  /// - Windows & macOS: didukung selama plugin camera_windows /
  ///   camera_avfoundation terpasang di pubspec.yaml.
  /// - Linux: belum ada implementasi resmi -> dianggap unsupported.
  bool get isPlatformSupported {
    if (kIsWeb) return true;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows;
  }

  /// - Android/iOS -> default kamera depan
  /// - Web / Desktop -> kamera pertama yang terdaftar di sistem
  Future<CameraController> initializeCamera() async {
    if (!isPlatformSupported) {
      throw UnsupportedCameraPlatformException(
        'Kamera belum didukung di platform ini (Linux). '
            'Gunakan Android, iOS, Web, Windows, atau macOS.',
      );
    }

    // Buang controller lama kalau ada (mis. saat resume/restart) supaya
    // tidak ada dua controller aktif berebut kamera yang sama.
    await dispose();

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraException(
        e.code,
        'Gagal mengambil daftar kamera: ${e.description ?? e.code}',
      );
    } catch (e) {
      // Biasanya MissingPluginException kalau plugin platform
      // (camera_windows / camera_avfoundation) belum ditambahkan ke pubspec.
      throw UnsupportedCameraPlatformException(
        'Plugin kamera untuk platform ini belum terpasang dengan benar. '
            'Pastikan dependency camera (dan camera_windows/camera_macos bila '
            'perlu) sudah ditambahkan di pubspec.yaml.',
      );
    }

    if (cameras.isEmpty) {
      throw CameraException('noCameraFound', 'Tidak ada kamera tersedia');
    }

    final selected = _selectDefaultCamera(cameras);

    final controller = CameraController(
      selected,
      // Desktop webcam umumnya butuh resolusi yang lebih toleran; medium
      // aman untuk semua platform dan tetap ringan untuk pemantauan
      // kualitas frame (CaptureQualityEngine).
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: _resolveImageFormatGroup(),
    );

    try {
      await controller.initialize();
    } catch (e) {
      await controller.dispose();
      rethrow;
    }

    _controller = controller;
    return controller;
  }

  /// nv21 hanya valid di Android, iOS/macOS wajib bgra8888, web pakai
  /// jpeg. Windows dibiarkan pakai default plugin (unknown) karena belum
  /// ada format khusus yang wajib.
  ///
  /// CATATAN untuk `CaptureQualityEngine`: hanya frame dengan grup
  /// yuv420/nv21/bgra8888 yang bisa dianalisis mentah (piksel asli).
  /// Grup jpeg (Web) & unknown (sebagian desktop) sengaja DILEWATI oleh
  /// engine tersebut karena datanya bukan piksel mentah — lihat
  /// `enggine/capture_quality_engine.dart` untuk penanganannya.
  ImageFormatGroup _resolveImageFormatGroup() {
    if (kIsWeb) return ImageFormatGroup.jpeg;
    if (Platform.isAndroid) return ImageFormatGroup.nv21;
    if (Platform.isIOS || Platform.isMacOS) return ImageFormatGroup.bgra8888;
    return ImageFormatGroup.unknown;
  }

  CameraDescription _selectDefaultCamera(List<CameraDescription> cameras) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile) {
      return cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
    }
    // Web & Desktop -> kamera pertama yang terdaftar di sistem.
    return cameras.first;
  }

  void startImageStream(void Function(CameraImage image) onImage) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isStreamingImages) return;
    _controller!.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  /// Ambil gambar terakhir saat kondisi sudah terkonfirmasi baik.
  Future<XFile> captureFinalImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw CameraException('notInitialized', 'Kamera belum siap');
    }
    if (_controller!.value.isStreamingImages) {
      await stopImageStream();
    }
    return _controller!.takePicture();
  }

  /// Matikan kamera total. Aman dipanggil berkali-kali (idempotent).
  Future<void> dispose() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) {
        await c.stopImageStream();
      }
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }
}