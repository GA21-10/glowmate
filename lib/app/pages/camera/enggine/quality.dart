// lib/app/pages/camera/enggine/capture_quality_engine.dart
//
// BARU (ketentuan #8 & #9) — engine BUATAN SENDIRI yang MENGGANTIKAN
// seluruh pipeline deteksi wajah (ML Kit/MediaPipe) yang sudah dihapus
// total dari modul kamera (ketentuan #5). Engine ini TIDAK PERNAH
// membaca satu landmark wajah pun — ia murni bekerja di level PIKSEL &
// metadata kamera (exposure offset, flash), supaya bisa dipakai SERAGAM
// di semua platform (Android, iOS, Web, Windows, macOS, Linux) tanpa
// bergantung pada satu pun plugin deteksi wajah yang platform-spesifik.
//
// TANGGUNG JAWAB:
// 1. `sample()` -> perkiraan cepat KECERAHAN & PERGERAKAN 1 frame kamera
//    langsung dari byte plane mentah (tanpa decode penuh, supaya ringan
//    & bisa dipanggil tiap frame tanpa nge-lag UI):
//      - Kecerahan: rata-rata byte plane pertama (plane luma untuk
//        YUV420/NV21 di Android, atau byte BGRA mentah di iOS/macOS —
//        pendekatan yang jujur diakui hanya proksi, bukan luminance
//        sempurna, tapi cukup untuk auto-exposure sederhana).
//      - Pergerakan: selisih rata-rata antara "sidik jari" (sampel byte
//        yang sama posisinya) frame ini vs frame sebelumnya -> makin
//        besar selisihnya, makin besar kemungkinan kamera/tangan goyang.
//    Kalau format frame tidak bisa dianalisis mentah dengan aman (mis.
//    JPEG terkompresi di Flutter Web, atau ImageFormatGroup.unknown di
//    sebagian desktop native), `sample()` mengembalikan nilai kosong
//    (brightness & motionScore null) -> pemanggil (controller) tahu
//    harus fallback ke jalur "grace period" tanpa analisis piksel,
//    supaya alur TETAP OTOMATIS LANJUT (ketentuan #9) walau di platform
//    yang tidak bisa diukur.
// 2. `recommendExposureOffset()` -> auto-exposure sederhana: kalau frame
//    kegelapan, exposure offset kamera dinaikkan bertahap (dan flash
//    torch dinyalakan sebagai bantuan tambahan kalau exposure sudah
//    mentok tapi masih gelap, khusus platform yang mendukung); kalau
//    kelebihan cahaya, diturunkan lagi — SEMUA dijalankan otomatis oleh
//    `CameraPageController`, pengguna tidak perlu melakukan apa pun.
// 3. `enhanceFinalImage()` -> pasca-proses foto akhir: perbesar (upscale
//    halus) kalau resolusi aslinya rendah, lalu pertajam (unsharp mask)
//    supaya hasil dokumentasi tetap terlihat jernih, tajam, dan stabil
//    (ketentuan #8/#9) — dijalankan di isolate terpisah (`compute()`)
//    supaya UI tidak freeze, sama seperti pendekatan processor lama.
// 4. `isLikelyBlurry()` -> pengaman terakhir di level piksel: varians
//    "Laplacian" sederhana pada foto yang BENAR-BENAR sudah diambil.
//    Kalau masih blur, `CameraPageController` akan mengambil ulang foto
//    secara otomatis (maks beberapa kali) tanpa perlu aksi pengguna,
//    memastikan "tidak ada kesalahan sekecil apa pun ketika menangkap
//    gambar" (ketentuan #9).
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Hasil satu kali sampling kualitas frame kamera.
class FrameQualitySample {
  /// Perkiraan kecerahan rata-rata (0..255). Null kalau format frame ini
  /// tidak bisa dianalisis mentah dengan aman di platform saat ini.
  final double? brightness;

  /// Perkiraan skor pergerakan dibanding frame sebelumnya (0..1, makin
  /// besar makin goyang). Null kalau belum ada frame sebelumnya untuk
  /// dibandingkan, atau formatnya tidak bisa dianalisis.
  final double? motionScore;

  const FrameQualitySample({this.brightness, this.motionScore});
}

class CaptureQualityEngine {
  CaptureQualityEngine();

  /// Target kecerahan "ideal" (skala 0..255, kira-kira abu-abu sedang).
  static const double targetBrightness = 120;

  /// Toleransi di sekitar target yang masih dianggap "cukup terang".
  static const double brightnessTolerance = 35;

  /// Ambang skor pergerakan (0..1) di bawah mana frame dianggap "stabil,
  /// tidak goyang".
  static const double motionStableThreshold = 0.020;

  List<int>? _previousThumbprint;

  /// Reset riwayat perbandingan antar-frame — dipanggil setiap kali
  /// kamera baru dinyalakan (`CameraPageController.start()`) supaya
  /// frame pertama sesi baru tidak dibandingkan dengan sesi sebelumnya.
  void reset() => _previousThumbprint = null;

  /// True kalau format gambar frame ini adalah data piksel mentah yang
  /// aman dianalisis langsung dari byte plane (BUKAN data terkompresi
  /// seperti JPEG, yang byte-nya tidak berkorelasi linear dengan
  /// kecerahan piksel).
  bool _isRawPixelFormat(CameraImage image) {
    final group = image.format.group;
    return group == ImageFormatGroup.yuv420 ||
        group == ImageFormatGroup.nv21 ||
        group == ImageFormatGroup.bgra8888;
  }

  /// Ambil sampel kecerahan & pergerakan dari satu frame kamera. Lihat
  /// catatan di header file untuk penjelasan lengkap & keterbatasan
  /// jujurnya per-platform.
  FrameQualitySample sample(CameraImage image) {
    if (!_isRawPixelFormat(image) || image.planes.isEmpty) {
      return const FrameQualitySample();
    }

    final plane = image.planes.first.bytes;
    if (plane.isEmpty) return const FrameQualitySample();

    // Stride ganjil & bukan kelipatan pola umum (lebar gambar dsb) supaya
    // titik sampel tersebar merata ke seluruh frame, bukan cuma satu
    // baris/kolom berulang.
    const stride = 37;
    double sum = 0;
    var count = 0;
    final thumbprint = <int>[];
    for (var i = 0; i < plane.length; i += stride) {
      final v = plane[i];
      sum += v;
      count++;
      thumbprint.add(v);
    }
    if (count == 0) return const FrameQualitySample();

    final brightness = sum / count;

    double? motionScore;
    final prev = _previousThumbprint;
    if (prev != null && prev.length == thumbprint.length) {
      double diff = 0;
      for (var i = 0; i < thumbprint.length; i++) {
        diff += (thumbprint[i] - prev[i]).abs();
      }
      motionScore = (diff / thumbprint.length) / 255.0;
    }
    _previousThumbprint = thumbprint;

    return FrameQualitySample(brightness: brightness, motionScore: motionScore);
  }

  bool isTooDark(double brightness) =>
      brightness < targetBrightness - brightnessTolerance;

  bool isTooBright(double brightness) =>
      brightness > targetBrightness + brightnessTolerance;

  bool isWellLit(double brightness) =>
      !isTooDark(brightness) && !isTooBright(brightness);

  bool isStable(double? motionScore) =>
      motionScore != null && motionScore <= motionStableThreshold;

  /// Rekomendasi exposure offset kamera berikutnya (auto-exposure
  /// sederhana), sudah di-clamp ke rentang yang benar-benar didukung
  /// device saat ini (`minOffset`/`maxOffset`, diambil dari
  /// `CameraController.getMinExposureOffset()/getMaxExposureOffset()`).
  double recommendExposureOffset({
    required double currentOffset,
    required double brightness,
    required double minOffset,
    required double maxOffset,
  }) {
    var next = currentOffset;
    if (isTooDark(brightness)) {
      next += 0.5;
    } else if (isTooBright(brightness)) {
      next -= 0.5;
    }
    if (next < minOffset) next = minOffset;
    if (next > maxOffset) next = maxOffset;
    return next;
  }

  /// Pengaman terakhir di level PIKSEL: varians "Laplacian" sederhana
  /// (selisih piksel bertetangga) sebagai proksi ketajaman — nilai
  /// rendah = kemungkinan besar hasil masih goyang/blur meski kondisi
  /// live tadi sudah dianggap stabil.
  static Future<bool> isLikelyBlurry(
      Uint8List bytes, {
        double sharpnessThreshold = 45.0,
      }) async {
    try {
      return await compute(
        _blurCheckIsolate,
        _BlurJob(bytes: bytes, threshold: sharpnessThreshold),
      );
    } catch (_) {
      // Kalau pengecekan gagal, JANGAN blokir alur capture.
      return false;
    }
  }

  /// Perjelas foto akhir: upscale halus kalau resolusinya rendah, lalu
  /// pertajam (unsharp mask) — TIDAK PERNAH bergantung pada landmark
  /// wajah, murni pemrosesan gambar umum (ketentuan #8/#9).
  static Future<Uint8List> enhanceFinalImage(
      Uint8List bytes, {
        int clarityTargetLongSide = 960,
      }) async {
    try {
      return await compute(
        _enhanceIsolate,
        _EnhanceJob(bytes: bytes, targetLongSide: clarityTargetLongSide),
      );
    } catch (_) {
      // Presisi tinggi tetap kalah penting dibanding "jangan pernah
      // gagal total" -> kalau enhance error, kembalikan foto asli.
      return bytes;
    }
  }
}

// ============================================================================
// ISOLATE JOBS (harus top-level/static supaya bisa dikirim ke isolate lain)
// ============================================================================

class _BlurJob {
  const _BlurJob({required this.bytes, required this.threshold});
  final Uint8List bytes;
  final double threshold;
}

bool _blurCheckIsolate(_BlurJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return false;

  final small = img.copyResize(
    decoded,
    width: decoded.width > 320 ? 320 : decoded.width,
  );
  final gray = img.grayscale(small);

  double sumSq = 0;
  double sum = 0;
  var count = 0;

  for (var y = 1; y < gray.height - 1; y++) {
    for (var x = 1; x < gray.width - 1; x++) {
      final center = gray.getPixel(x, y).r;
      final right = gray.getPixel(x + 1, y).r;
      final down = gray.getPixel(x, y + 1).r;
      final lap = (2 * center - right - down).toDouble();
      sumSq += lap * lap;
      sum += lap;
      count++;
    }
  }

  if (count == 0) return false;
  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);

  return variance < job.threshold;
}

class _EnhanceJob {
  const _EnhanceJob({required this.bytes, required this.targetLongSide});
  final Uint8List bytes;
  final int targetLongSide;
}

Uint8List _enhanceIsolate(_EnhanceJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return job.bytes;

  var working = decoded;

  // (ketentuan #8/#9) Kalau resolusi rendah, perbesar dulu dengan
  // interpolasi halus (cubic) sebelum dipertajam, supaya hasil akhirnya
  // tetap terlihat jernih alih-alih pecah/pixelated.
  final longSide = max(working.width, working.height);
  if (longSide > 0 && longSide < job.targetLongSide) {
    final scale = job.targetLongSide / longSide;
    working = img.copyResize(
      working,
      width: (working.width * scale).round(),
      height: (working.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  working = _sharpen(working);

  return Uint8List.fromList(img.encodeJpg(working, quality: 92));
}

/// Unsharp mask manual & ringan: setiap piksel dibandingkan dengan
/// rata-rata 4 tetangganya (atas/bawah/kiri/kanan) sebagai perkiraan
/// versi "blur"-nya, lalu selisihnya (detail) ditambahkan kembali ke
/// piksel asli supaya tepi terlihat lebih tegas — teknik umum
/// pertajaman foto, sama sekali tidak spesifik wajah.
img.Image _sharpen(img.Image src) {
  final out = img.Image.from(src);
  const amount = 0.6; // kekuatan moderat supaya hasil tetap natural

  for (var y = 1; y < src.height - 1; y++) {
    for (var x = 1; x < src.width - 1; x++) {
      final c = src.getPixel(x, y);
      final up = src.getPixel(x, y - 1);
      final down = src.getPixel(x, y + 1);
      final left = src.getPixel(x - 1, y);
      final right = src.getPixel(x + 1, y);

      final r = _sharpenChannel(c.r, up.r, down.r, left.r, right.r, amount);
      final g = _sharpenChannel(c.g, up.g, down.g, left.g, right.g, amount);
      final b = _sharpenChannel(c.b, up.b, down.b, left.b, right.b, amount);

      out.setPixelRgba(x, y, r, g, b, c.a.toInt());
    }
  }
  return out;
}

int _sharpenChannel(
    num c,
    num up,
    num down,
    num left,
    num right,
    double amount,
    ) {
  final blurredEstimate = (up + down + left + right) / 4;
  final detail = c - blurredEstimate;
  var value = c + detail * amount;
  if (value < 0) value = 0;
  if (value > 255) value = 255;
  return value.round();
}