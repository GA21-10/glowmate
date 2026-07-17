// ─────────────────────────────────────────────
// app/splash/splash_page.dart
// (UI splash HANYA tampil di Android & iOS.
//  Web & Desktop langsung diarahkan ke login/home
//  tanpa menampilkan tampilan splash sama sekali,
//  namun proses loading tetap berjalan di background.)
// ─────────────────────────────────────────────
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings/biometric.dart';
import '../../../core/providers/user/users.dart';
import '../../../core/services/local.dart';
import '../routes/app.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  /// Splash UI (logo + copyright) hanya boleh terlihat di Android & iOS.
  /// Di Web & Desktop, nilai ini false → build() tidak merender apa-apa.
  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Otentikasi lokal (biometrik/PIN) berlaku di Android, iOS, dan Desktop.
  /// Metode yang dipakai (sidik jari/wajah/PIN) ditentukan otomatis oleh
  /// sistem operasi masing-masing melalui package `local_auth`:
  ///   • Android  → BiometricPrompt (fingerprint / face, sesuai perangkat)
  ///   • iOS      → Face ID / Touch ID (sesuai perangkat)
  ///   • Windows  → Windows Hello (PIN / wajah / sidik jari sesuai setelan)
  ///   • macOS    → Touch ID / password
  /// Web tidak didukung, jadi selalu dilewati.
  bool get _supportsLocalAuth =>
      !kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isWindows ||
              Platform.isMacOS);

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    if (_isMobilePlatform) {
      // Android & iOS → tampilkan splash dengan animasi halus,
      // beri jeda sebentar sebelum proses navigasi berjalan.
      _ctrl.forward();
      Future.delayed(const Duration(milliseconds: 2000), _navigate);
    } else {
      // Web & Desktop → TIDAK ada tampilan splash sama sekali.
      // "Loading" tetap ada (proses cek sesi/profil/biometrik di
      // background), hanya saja UI-nya disembunyikan/tidak dirender.
      _navigate();
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final biometricProvider = context.read<BiometricProvider>();

    final isLoggedIn = await UserLocalService.isLoggedIn();
    final hasProfile = await UserLocalService.hasCompleteProfile();
    await userProvider.refresh();
    await biometricProvider.load(); // ← WAJIB, refresh status biometrik terbaru

    if (!mounted) return;

    if (!isLoggedIn || !userProvider.hasUser) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
      return;
    }

    // Otentikasi lokal berlaku di Android, iOS, dan Desktop (Windows/macOS).
    // Metode konkretnya (sidik jari, wajah, atau PIN) diputuskan otomatis
    // oleh sistem operasi masing-masing lewat local_auth — tidak perlu
    // dibedakan manual di sini. Web selalu dilewati.
    if (_supportsLocalAuth && biometricProvider.enabled) {
      final ok = await biometricProvider.authenticate();
      if (!mounted) return;
      if (!ok) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }
    }

    Navigator.pushReplacementNamed(
      context,
      hasProfile ? AppRoutes.home : AppRoutes.profile,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web & Desktop: tidak merender UI splash sama sekali.
    // Proses _navigate() sudah berjalan di initState(), user akan
    // langsung "lompat" ke halaman login/home tanpa jeda tampilan.
    if (!_isMobilePlatform) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final backgroundColor = isDark ? Colors.black : Colors.white;

    final copyrightColor = isDark ? Colors.white70 : Colors.grey.shade600;

    final logoSize = (size.width * 0.42).clamp(120.0, 260.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Image.asset(
                      'assets/logoapp.png',
                      width: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: size.height * 0.03),
              child: FadeTransition(
                opacity: _fade,
                child: Text(
                  '© ${DateTime.now().year} MindRellix. All Rights Reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: (size.width * 0.032).clamp(12.0, 16.0),
                    fontWeight: FontWeight.w400,
                    color: copyrightColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}