// ─────────────────────────────────────────────
// core/routes/app_router.dart
// ─────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/logon/data/users.dart';
import '../../account/logon/pages.dart';
import '../../account/pages.dart';
import '../../account/report/pages.dart';
import '../../account/settings/pages.dart';
import '../../../core/providers/user/users.dart';
import '../../../core/services/local.dart';
import '../../report/pages.dart';
import '../appstart/spash.dart';
import '../home/pages.dart';
import 'app.dart';

class AppRouter {
  AppRouter._();

  /// Widget awal berdasarkan platform.
  /// Web & Desktop → _StartupGate (cek login dulu).
  /// Android & iOS → SplashPage (ada animasi + biometrik).
  static Widget get initialWidget {
    if (kIsWeb) return const StartupGate();
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return const StartupGate();
      default:
        return const SplashPage();
    }
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fade(const SplashPage());

      case AppRoutes.login:
        return _fade(const LoginPage());

      case AppRoutes.profile:
        return _fade(const ProfileSetupPage());

      case AppRoutes.home:
        return _fade(const HomePage());

      case AppRoutes.account:
        return _fade(const AccountPage());

      case AppRoutes.settings:
        return _fade(const SettingsPage());

      case AppRoutes.report:
        return _fade(const ReportPage());

      case AppRoutes.recommendation:
        return _fade(const RecommendationPage());
      default:
        return _fade(_notFound(settings.name));
    }
  }

  static Widget _notFound(String? name) => Scaffold(
    body: Center(child: Text('Route "$name" tidak ditemukan.')),
  );

  static PageRouteBuilder<dynamic> _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

// ─────────────────────────────────────────────
// StartupGate
// Dipakai Web & Desktop sebagai pengganti SplashPage.
// Mengecek status login → routing ke halaman yang tepat.
// Android & iOS tetap menggunakan SplashPage (ada animasi + biometrik).
// ─────────────────────────────────────────────

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    // Animasi fade-in logo ringan selama cek status berjalan
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // Jalankan routing setelah frame pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    // Tunggu minimal 800 ms agar animasi logo sempat terlihat
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();

    // Baca status dari penyimpanan lokal
    final isLoggedIn = await UserLocalService.isLoggedIn();
    final hasProfile = await UserLocalService.hasCompleteProfile();

    // Refresh provider agar data in-memory sinkron dengan lokal
    await userProvider.refresh();
    if (!mounted) return;

    if (!isLoggedIn || !userProvider.hasUser) {
      // Belum login → ke halaman login
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else if (!hasProfile) {
      // Sudah login tapi profil belum lengkap
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
    } else {
      // Semua OK → ke home
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Gunakan warna scaffold dari tema agar tidak hitam/putih polos
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // Nama app
              Text(
                'GlowMate',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Your skin, beautifully tracked.',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.5),
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 48),

              // Loading indicator kecil
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}