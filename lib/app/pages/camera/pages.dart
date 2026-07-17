// lib/app/pages/camera/pages.dart
//
// PEROMBAKAN sesuai ketentuan:
//
// (#1) UI DIPERTAHANKAN: struktur halaman (top bar dengan indikator
//   warna, kotak preview kamera yang fit-nya beda untuk mobile vs
//   web/desktop, bottom sheet popup) TETAP SAMA seperti versi lama.
//
// (#5) DIHAPUS: overlay outline hijau di atas preview kamera
//   (`FaceOutlinePainter`) beserta seluruh state terkait wajah
//   (`faceOutlinePoints`, `faceImageSize`, `faceImageRotation`,
//   `detectionSupported`) — frame kamera sekarang ditampilkan POLOS,
//   tanpa overlay gambar wajah apa pun.
//
// (#8/#9) BARU: indikator status kualitas kamera kecil di bawah kotak
//   preview (`controller.qualityMessage`) sebagai pengganti umpan balik
//   visual yang dulu diberikan lewat outline hijau — memberi tahu
//   pengguna kalau kamera sedang menyesuaikan pencahayaan/menstabilkan
//   diri secara OTOMATIS. Tombol manual ("LANJUTKAN SEKARANG") sekarang
//   tersedia SERAGAM di semua platform (dulu hanya muncul di
//   Web/Desktop sebagai pengganti ML Kit) sebagai fallback kalau
//   pengguna ingin melewati proses tunggu otomatis.
//
// (#10) BUGFIX navigasi setelah popup SELESAI ditekan: versi lama
//   memanggil `Navigator.of(context)` tanpa embel-embel setelah popup
//   ditutup, yang di beberapa kasus (mis. saat CameraPage dipakai
//   sebagai tab di dalam HomePage yang punya Navigator bersarang)
//   mengambil ROOT NAVIGATOR alih-alih navigator lokal milik tab
//   tersebut — inilah yang membuat AnalysisPage tiba-tiba tampil FULL
//   LAYAR (menutupi bottom navigation/header web) alih-alih masuk rapi
//   sebagai halaman berikutnya di alur yang sama. Diperbaiki dengan
//   secara EKSPLISIT memakai `rootNavigator: false` supaya navigasi
//   selalu terjadi di Navigator TERDEKAT (lokal), persis seperti alur
//   `_handleBack` di halaman ini yang juga sudah memakai
//   `Navigator.of(context)` lokal.
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:glowmate/app/pages/analysis/pages.dart';
import 'package:provider/provider.dart';

import '../../core/providers/user/users.dart';
import '../analysis/repository/analisis.dart';
import 'controller/camera.dart';
import 'model/camera.dart';
import 'popup.dart';
import 'provider/camera.dart';

class CameraPage extends StatelessWidget {
  /// Isi [onBack] kalau CameraPage dipakai sebagai child/tab di HomePage
  /// (bukan halaman yang di-push via Navigator, sehingga Navigator.pop()
  /// tidak punya efek). Kalau null, fallback ke Navigator.pop().
  ///
  /// [onFinished] dipanggil setelah tombol SELESAI di popup ditekan &
  /// gambar berhasil di-capture, membawa `CameraCaptureResult` yang SUDAH
  /// berisi data user yang diketahui (ketentuan #3/#4).
  const CameraPage({super.key, this.onBack, this.onFinished});

  final VoidCallback? onBack;
  final ValueChanged<CameraCaptureResult>? onFinished;

  @override
  Widget build(BuildContext context) {
    return CameraProvider(
      child: _CameraView(onBack: onBack, onFinished: onFinished),
    );
  }
}

class _CameraView extends StatefulWidget {
  const _CameraView({this.onBack, this.onFinished});
  final VoidCallback? onBack;
  final ValueChanged<CameraCaptureResult>? onFinished;

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> with WidgetsBindingObserver {
  bool _popupShown = false;

  // PENTING: referensi controller disimpan di initState, BUKAN dicari
  // lagi lewat context.read() di dispose(). Saat tombol back ditekan,
  // seluruh subtree (termasuk CameraProvider yang menyediakan controller
  // ini) bisa di-deactivate BERSAMAAN, sehingga context.read() di
  // dispose() akan melempar "Looking up a deactivated widget's ancestor
  // is unsafe."
  late final CameraPageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<CameraPageController>();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.pauseForBackground();
    } else if (state == AppLifecycleState.resumed) {
      _controller.resumeFromBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.stopAndClear();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context, rootNavigator: false).canPop()) {
      Navigator.of(context, rootNavigator: false).pop();
    }
  }

  /// Ambil snapshot data user SAAT INI — dipanggil tepat sebelum popup
  /// ditampilkan, supaya data yang dikirim ke Analisis nanti konsisten
  /// dengan yang "dipegang" saat proses berlangsung (termasuk usia dari
  /// data global user, ketentuan #3).
  KnownUserDataSnapshot _readKnownUserData() {
    final userProvider = context.read<UserProvider>();
    return KnownUserDataSnapshot.fromUser(userProvider.user);
  }

  Future<void> _onSelesai(
      CameraPageController controller,
      KnownUserDataSnapshot knownUserData,
      ) async {
    final CameraCaptureResult result;
    try {
      result = await controller.captureFinalData(knownUserData: knownUserData);
    } catch (_) {
      rethrow; // ditangkap & ditampilkan oleh PopupCamera
    }
    if (!mounted) return;

    // Tutup popup dulu — pakai navigator LOKAL (bukan root) supaya tidak
    // pernah menyentuh route lain di luar subtree halaman ini.
    Navigator.of(context, rootNavigator: false).pop();

    if (widget.onFinished != null) {
      // CameraPage dipakai sebagai TAB di dalam HomePage. HomePage yang
      // bertanggung jawab menyimpan `result` ke AnalysisRepository DAN
      // memindah tab ke Analisis — cukup teruskan hasil capture ke
      // parent, jangan melakukan navigasi/penyimpanan apa pun di sini
      // (mencegah data dobel & AnalysisPage ter-push sebagai route baru
      // yang kehilangan bottom nav/header, ini akar masalah bug #10 versi
      // lama).
      widget.onFinished!(result);
      return;
    }

    // CameraPage dipakai BERDIRI SENDIRI (di-push langsung, bukan
    // sebagai tab HomePage) -> simpan sendiri ke AnalysisRepository,
    // lalu pindah ke AnalysisPage.
    await context.read<AnalysisRepository>().addFromCapture(result);

    if (!mounted) return;

    // (#10) BUGFIX: eksplisit `rootNavigator: false` supaya
    // pushReplacement terjadi di Navigator TERDEKAT milik halaman ini,
    // bukan root navigator aplikasi — mencegah AnalysisPage tampil full
    // layar menutupi bottom navigation/header. AnalysisPage sendiri
    // tidak menerima parameter apa pun — dia otomatis menampilkan record
    // terbaru begitu repository di atas memanggil notifyListeners().
    Navigator.of(context, rootNavigator: false).pushReplacement(
      MaterialPageRoute(builder: (_) => const AnalysisPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.shortestSide < 600; // heuristik mobile vs web/desktop

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Selector<CameraPageController, CameraIndicatorStatus>(
              selector: (_, c) => c.indicatorStatus,
              builder: (context, indicatorStatus, _) {
                return _TopBar(status: indicatorStatus, onBack: _handleBack);
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Center(
                      child: Selector<
                          CameraPageController,
                          (
                          CameraController?,
                          CameraPageStatus,
                          String?,
                          String,
                          )>(
                        selector: (_, c) => (
                        c.controller,
                        c.status,
                        c.errorMessage,
                        c.qualityMessage,
                        ),
                        builder: (context, data, _) {
                          return _CameraPreviewBox(
                            controller: data.$1,
                            isMobile: isMobile,
                            pageStatus: data.$2,
                            errorMessage: data.$3,
                            qualityMessage: data.$4,
                            onContinueNow: () => context
                                .read<CameraPageController>()
                                .continueNow(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Indikator kecil "Mengambil ulang foto..." — muncul otomatis
            // saat controller mendeteksi hasil capture kurang tajam dan
            // sedang mengulang pengambilan foto (ketentuan #8/#9). Murni
            // informatif, tidak butuh aksi apa pun dari pengguna.
            Selector<CameraPageController, bool>(
              selector: (_, c) => c.isRetryingCapture,
              builder: (context, isRetrying, _) {
                if (!isRetrying) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Hasil kurang tajam, mengambil ulang foto...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              },
            ),
            // Listener terpisah, hanya memicu popup saat showPopup jadi true.
            Selector<CameraPageController, bool>(
              selector: (_, c) => c.showPopup,
              builder: (context, showPopup, _) {
                if (showPopup && !_popupShown) {
                  _popupShown = true;
                  final controller = context.read<CameraPageController>();
                  final knownUserData = _readKnownUserData();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    PopupCamera.show(
                      context,
                      knownUserData: knownUserData,
                      onSelesai: () => _onSelesai(controller, knownUserData),
                    ).whenComplete(() {
                      _popupShown = false;
                    });
                  });
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Back button + indikator kecil: MERAH (not ready) / BIRU (ready) /
/// HIJAU (kondisi terkonfirmasi baik).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.status, required this.onBack});

  final CameraIndicatorStatus status;
  final VoidCallback onBack;

  Color get _color {
    switch (status) {
      case CameraIndicatorStatus.notReady:
        return Colors.redAccent;
      case CameraIndicatorStatus.ready:
        return Colors.blueAccent;
      case CameraIndicatorStatus.detected:
        return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color,
                boxShadow: [
                  BoxShadow(
                    color: _color.withOpacity(0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kotak preview kamera.
///
/// TIDAK ADA mirror, di platform manapun. Preview menampilkan feed
/// kamera APA ADANYA, sama seperti gambar yang benar-benar di-capture.
///
/// (ketentuan #5) TIDAK ADA overlay outline wajah apa pun di atas
/// preview — frame ditampilkan polos.
///
/// - Mobile (Android/iOS): layout & BoxFit.cover DIPERTAHANKAN persis
///   seperti sebelumnya (ketentuan #1).
/// - Web/Desktop: box preview mengikuti aspect ratio ASLI kamera dan
///   memakai BoxFit.contain, supaya seluruh frame selalu tampil utuh
///   tanpa terpotong.
class _CameraPreviewBox extends StatelessWidget {
  const _CameraPreviewBox({
    required this.controller,
    required this.isMobile,
    required this.pageStatus,
    required this.errorMessage,
    required this.qualityMessage,
    required this.onContinueNow,
  });

  final CameraController? controller;
  final bool isMobile;
  final CameraPageStatus pageStatus;
  final String? errorMessage;
  final String qualityMessage;
  final VoidCallback onContinueNow;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isReady = controller != null && controller!.value.isInitialized;
    final camAspect = isReady ? controller!.value.aspectRatio : 3 / 4;

    late double boxWidth;
    late double boxHeight;

    if (isMobile) {
      // DIPERTAHANKAN PERSIS seperti versi sebelumnya.
      boxWidth = size.width * 0.94;
      boxHeight = size.height * 0.8;
    } else {
      boxWidth = size.width * 0.7;
      boxHeight = boxWidth / camAspect;
      final maxHeight = size.height * 0.78;
      if (boxHeight > maxHeight) {
        boxHeight = maxHeight;
        boxWidth = boxHeight * camAspect;
      }
    }

    Widget content;
    if (pageStatus == CameraPageStatus.error) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            errorMessage ?? 'Kamera error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    } else if (!isReady) {
      content = const Center(child: CircularProgressIndicator(color: Colors.white54));
    } else if (isMobile) {
      final preview = AspectRatio(
        aspectRatio: controller!.value.aspectRatio,
        child: CameraPreview(controller!),
      );
      content = ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.previewSize?.height ?? boxWidth,
            height: controller!.value.previewSize?.width ?? boxHeight,
            child: preview,
          ),
        ),
      );
    } else {
      content = ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller!.value.previewSize?.width ?? boxWidth,
            height: controller!.value.previewSize?.height ?? boxHeight,
            child: CameraPreview(controller!),
          ),
        ),
      );
    }

    final showQualityStatus = isReady &&
        pageStatus != CameraPageStatus.error &&
        pageStatus != CameraPageStatus.capturing;

    // Tombol lanjut manual tersedia seragam di semua platform (dulu
    // hanya di Web/Desktop sebagai pengganti ML Kit) — fallback kalau
    // pengguna ingin melewati proses tunggu otomatis.
    final showContinueButton = isReady &&
        (pageStatus == CameraPageStatus.ready ||
            pageStatus == CameraPageStatus.stabilizing);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: boxWidth,
            height: boxHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(isMobile ? 28 : 16),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: content,
          ),
        ),
        if (showQualityStatus) ...[
          const SizedBox(height: 14),
          Text(
            qualityMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
        if (showContinueButton) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onContinueNow,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('LANJUTKAN SEKARANG'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ],
    );
  }
}