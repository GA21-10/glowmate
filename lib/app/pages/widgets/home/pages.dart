// ─────────────────────────────────────────────
// app/widgets/home/pages.dart
// ─────────────────────────────────────────────
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme/app.dart';
import '../../../core/providers/user/photo.dart';
import '../../../core/providers/user/users.dart';
import '../../../core/swich/l10n.dart';
import '../../account/logon/data/avatar.dart';
import '../../account/pages.dart';
import '../../analysis/pages.dart';
import '../../analysis/repository/analisis.dart';
import '../../camera/model/camera.dart' show CameraCaptureResult;
import '../../camera/pages.dart';
import '../../report/pages.dart';

// ── Konstanta indeks ──────────────────────────────────────────────────────────

const int _kAnalysisIndex = 0;
const int _kCameraIndex   = 1;
const int _kReportIndex   = 2;
const int _kAccountIndex  = 3;

// ── Nav items ─────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Label nav item diambil dari `context.tr()` supaya ikut berganti
/// bahasa (KETENTUAN #2 di l10n.dart) — TIDAK boleh lagi berupa
/// const top-level list dengan string hardcoded Bahasa Indonesia.
/// Ikon tidak perlu diterjemahkan, jadi tetap konstan.
List<_NavItem> _navItems(BuildContext context) => [
  _NavItem(label: context.tr('nav_analysis'), icon: Icons.bar_chart_rounded),
  _NavItem(label: context.tr('nav_camera'),   icon: Icons.camera_alt_rounded),
  _NavItem(label: context.tr('nav_report'),   icon: Icons.description_rounded),
  _NavItem(label: context.tr('nav_account'),  icon: Icons.person_rounded),
];

// ── Platform helper ───────────────────────────────────────────────────────────

bool get _isDesktopOrWeb =>
    kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

bool get _isMobile =>
    !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

// ── Warna gradien ─────────────────────────────────────────────────────────────

const _webGradient = LinearGradient(
  colors: [Color(0xFF6A11CB), Color(0xFF7C4DFF), Color(0xFFE040FB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _mobileGradientLight = LinearGradient(
  colors: [Color(0xFF8A4DFF), Color(0xFF7C4DFF), Color(0xFF5A1FB8)],
  stops: [0.0, 0.5, 1.0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

const _mobileGradientDark = LinearGradient(
  colors: [Color(0xFF3A1080), Color(0xFF2A0A6B), Color(0xFF190445)],
  stops: [0.0, 0.5, 1.0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// ─────────────────────────────────────────────────────────────────────────────
// HomePage
// ─────────────────────────────────────────────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = _kAnalysisIndex;

  // Menyimpan tab terakhir sebelum masuk ke Kamera, supaya tombol back
  // di CameraPage tahu harus kembali ke tab yang mana (bukan hardcode).
  int _previousIndex = _kAnalysisIndex;

  bool get _isCameraPage => _selectedIndex == _kCameraIndex;

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      // Hanya simpan sebagai "previous" kalau bukan dari Kamera itu sendiri,
      // supaya tidak muter balik ke Kamera lagi saat back ditekan.
      if (_selectedIndex != _kCameraIndex) {
        _previousIndex = _selectedIndex;
      }
      _selectedIndex = index;
    });
  }

  /// Dipanggil dari tombol back di dalam CameraPage.
  /// CameraPage adalah TAB/child di HomePage (bukan route yang di-push),
  /// jadi back-nya harus pindah index, bukan Navigator.pop().
  void _handleCameraBack() {
    setState(() {
      _selectedIndex =
      _previousIndex == _kCameraIndex ? _kAnalysisIndex : _previousIndex;
    });
  }

  /// Dipanggil CameraPage lewat widget.onFinished setelah tombol SELESAI
  /// ditekan & capture berhasil.
  ///
  /// PENTING: data TIDAK disimpan sebagai state lokal HomePage lagi.
  /// Langsung dikirim ke [AnalysisRepository] (satu-satunya sumber
  /// data yang juga dinonton AnalysisPage & ReportPage) supaya kedua
  /// halaman itu ter-update secara realtime lewat notifyListeners(),
  /// bukan lewat rebuild manual dari sini. HomePage di sini hanya
  /// bertanggung jawab pindah tab ke Analisis setelah selesai.
  Future<void> _handleCameraFinished(CameraCaptureResult result) async {
    await context.read<AnalysisRepository>().addFromCapture(result);
    if (!mounted) return;
    setState(() {
      _selectedIndex = _kAnalysisIndex;
    });
  }

  /// Dibangun ulang tiap build supaya callback onBack/onFinished selalu
  /// terhubung dengan state terbaru. State internal CameraPage (kamera,
  /// dsb) tetap terjaga karena posisi widget di tree & runtimeType-nya
  /// tidak berubah.
  List<Widget> _buildPages() => [
    // AnalysisPage & ReportPage sekarang tidak butuh data lewat
    // constructor sama sekali — keduanya nonton AnalysisRepository
    // langsung (lihat pages.dart masing-masing).
    const AnalysisPage(),
    CameraPage(
      onBack: _handleCameraBack,
      onFinished: _handleCameraFinished,
    ),
    const RecommendationPage(),
    const AccountPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return _isDesktopOrWeb
        ? _WebDesktopScaffold(
      selectedIndex: _selectedIndex,
      isCameraPage: _isCameraPage,
      pages: pages,
      onNavTap: _onNavTap,
    )
        : _MobileScaffold(
      selectedIndex: _selectedIndex,
      isCameraPage: _isCameraPage,
      pages: pages,
      onNavTap: _onNavTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web / Desktop Scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _WebDesktopScaffold extends StatelessWidget {
  const _WebDesktopScaffold({
    required this.selectedIndex,
    required this.isCameraPage,
    required this.pages,
    required this.onNavTap,
  });

  final int selectedIndex;
  final bool isCameraPage;
  final List<Widget> pages;
  final ValueChanged<int> onNavTap;

  @override
  Widget build(BuildContext context) {
    if (isCameraPage) {
      return Scaffold(body: pages[selectedIndex]);
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: false,
            floating: true,
            snap: true,
            expandedHeight: 160,
            toolbarHeight: 160,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: _webGradient,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A11CB).withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.12),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: _WebHeaderContent(
                  selectedIndex: selectedIndex,
                  onNavTap: onNavTap,
                ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ],
        body: pages[selectedIndex],
      ),
    );
  }
}

class _WebHeaderContent extends StatelessWidget {
  const _WebHeaderContent({
    required this.selectedIndex,
    required this.onNavTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onNavTap;

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems(context);

    return Row(
      children: [
        const SizedBox(width: 24 + 40 + 24),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < navItems.length - 1; i++)
                _WebNavButton(
                  item: navItems[i],
                  isActive: i == selectedIndex,
                  onTap: () => onNavTap(i),
                ),
            ],
          ),
        ),
        _ProfileAvatar(
          size: 40,
          onTap: () => onNavTap(_kAccountIndex),
          isActive: selectedIndex == _kAccountIndex,
        ),
        const SizedBox(width: 24),
      ],
    );
  }
}

class _WebNavButton extends StatelessWidget {
  const _WebNavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: isActive
                  ? Colors.white.withOpacity(0.22)
                  : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? Colors.white.withOpacity(0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: isActive ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.selectedIndex,
    required this.isCameraPage,
    required this.pages,
    required this.onNavTap,
  });

  final int selectedIndex;
  final bool isCameraPage;
  final List<Widget> pages;
  final ValueChanged<int> onNavTap;

  @override
  Widget build(BuildContext context) {
    if (isCameraPage) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        body: pages[selectedIndex],
      );
    }

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final gradient = isDark ? _mobileGradientDark : _mobileGradientLight;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: pages[selectedIndex],
      ),
      bottomNavigationBar: _GradientBottomNav(
        selectedIndex: selectedIndex,
        gradient: gradient,
        isDark: isDark,
        onTap: onNavTap,
      ),
    );
  }
}

// ── Gradient Bottom Navigation Bar ───────────────────────────────────────────

class _GradientBottomNav extends StatelessWidget {
  const _GradientBottomNav({
    required this.selectedIndex,
    required this.gradient,
    required this.isDark,
    required this.onTap,
  });

  final int selectedIndex;
  final LinearGradient gradient;
  final bool isDark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems(context);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 24,
              spreadRadius: 1,
              offset: const Offset(0, -6),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.14),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Row(
              children: [
                for (int i = 0; i < navItems.length; i++)
                  Expanded(
                    child: i == _kAccountIndex
                        ? _AccountNavItem(
                      isActive: selectedIndex == i,
                      onTap: () => onTap(i),
                    )
                        : _BottomNavItem(
                      item: navItems[i],
                      isActive: selectedIndex == i,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withOpacity(0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              item.icon,
              size: 24,
              color: isActive ? Colors.white : Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 11,
              letterSpacing: 0.2,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isActive ? 1 : 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountNavItem extends StatelessWidget {
  const _AccountNavItem({
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ProfileAvatar(size: 30, isActive: isActive),
          const SizedBox(height: 4),
          Text(
            // Sebelumnya hardcoded 'Akun' — sekarang ikut bahasa aktif
            // seperti label nav lainnya (lihat _navItems()).
            context.tr('nav_account'),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontSize: 11,
              letterSpacing: 0.2,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: isActive ? 1 : 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Avatar
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.size,
    this.onTap,
    this.isActive = false,
  });

  final double size;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final photo = context.watch<UserProvider>().user?.photo;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.white : Colors.white60,
            width: isActive ? 2.5 : 1.5,
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: UserAvatar(
          photo: photo,
          radius: size / 2,
          iconSize: size * 0.55,
        ),
      ),
    );
  }
}