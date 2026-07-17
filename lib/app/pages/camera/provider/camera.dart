// lib/app/pages/camera/provider/camera.dart
//
// Tidak ada perubahan — wrapper Provider sederhana ini tidak pernah
// memuat kode apa pun yang berhubungan dengan deteksi wajah, jadi tidak
// terpengaruh oleh ketentuan #5.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../controller/camera.dart';

/// Wrapper provider untuk CameraPageController.
class CameraProvider extends StatelessWidget {
  const CameraProvider({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CameraPageController>(
      create: (_) => CameraPageController(),
      child: child,
    );
  }
}