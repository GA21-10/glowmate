// lib/app/pages/camera/popup.dart
//
// (ketentuan #6) Popup ini TIDAK PERNAH menampilkan data apa pun
// (Kondisi Kulit, Tipe Kulit, Usia, dst) — badan popup HANYA berisi
// judul "ANALISIS SELESAI" dan tombol SELESAI. `knownUserData` tetap
// diterima sebagai parameter (diteruskan `pages.dart` ke
// `CameraPageController.captureFinalData()` saat tombol SELESAI
// ditekan) TAPI TIDAK PERNAH dibaca/ditampilkan oleh widget ini —
// datanya (termasuk usia dari global, ketentuan #3) baru benar-benar
// muncul di halaman Analisis SETELAH tombol SELESAI ditekan.
//
// (ketentuan #1) UI (bottom sheet bulat, drag handle, judul, tombol
// SELESAI, state loading/error) DIPERTAHANKAN PERSIS seperti sebelumnya.
import 'package:flutter/material.dart';

import 'model/camera.dart';

class PopupCamera extends StatefulWidget {
  const PopupCamera({
    super.key,
    required this.onSelesai,
    required this.knownUserData,
  });

  final Future<void> Function() onSelesai;

  /// Diterima HANYA untuk kompatibilitas alur (diteruskan apa adanya ke
  /// `captureFinalData()` lewat closure `onSelesai`), TIDAK PERNAH
  /// dibaca untuk ditampilkan di widget ini (ketentuan #6).
  final KnownUserDataSnapshot knownUserData;

  static Future<void> show(
      BuildContext context, {
        required Future<void> Function() onSelesai,
        required KnownUserDataSnapshot knownUserData,
      }) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => PopupCamera(
        onSelesai: onSelesai,
        knownUserData: knownUserData,
      ),
    );
  }

  @override
  State<PopupCamera> createState() => _PopupCameraState();
}

class _PopupCameraState extends State<PopupCamera> {
  bool _isLoading = false;
  String? _errorText;

  Future<void> _handleTap() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await widget.onSelesai();
      // Kalau berhasil, popup ditutup oleh caller (_onSelesai di
      // pages.dart) lewat Navigator.pop(), widget ini biasanya sudah
      // unmount di sini.
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Gagal menyimpan hasil: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ANALISIS SELESAI',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            // Ketentuan #6: badan popup SENGAJA dikosongkan — tidak ada
            // data, fungsi, atau metode apa pun yang ditampilkan di sini.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox.shrink(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleTap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('SELESAI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}