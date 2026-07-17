import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:glowmate/app/pages/account/paket/model/berlangganan.dart';
import 'package:glowmate/app/pages/account/paket/pages.dart';
import 'package:glowmate/app/pages/account/report/pages.dart';
import 'package:glowmate/app/pages/account/settings/pages.dart';
import 'package:glowmate/app/pages/account/support/faq.dart';
import 'package:glowmate/app/pages/account/support/help.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/providers/user/users.dart';
import '../../core/services/local.dart';
import '../report/pages.dart';
import '../widgets/routes/app.dart';
import 'analisis/page.dart';
import 'edit/users.dart';
import 'info/pages.dart';
import 'logon/data/avatar.dart';


// ─────────────────────────────────────────────
// app/pages/account/account_page.dart
// ─────────────────────────────────────────────
//
// • Kartu profil tetap paling atas. Sekarang punya 2 area tap terpisah:
//     - FOTO PROFIL   → tap membuka viewer foto (preview besar) dengan
//       tombol "Ganti Foto" di bawahnya. Tap tombol itu memunculkan
//       dropdown (bottom sheet) Ambil Foto/Pilih dari Galeri/Hapus
//       Foto — sama seperti di halaman Edit Profil — lalu langsung
//       tersimpan ke `UserProvider` tanpa perlu buka halaman Edit.
//     - NAMA & EMAIL  → tap langsung membuka `AccountInfoPage`.
//   Kartu ini RESPONSIF terhadap lebar layar:
//     - Web/Desktop (lebar >= 700): konten kartu (foto → nama →
//       email) disusun VERTIKAL & DI-CENTER.
//     - Android/iOS (lebar < 700): tetap seperti UI lama, Row
//       (foto di kiri, nama+email di kanan).
//   Field "usia akun" (tanggal lahir) DIHAPUS dari kartu ini sesuai
//   permintaan.
// • Di bawah kartu profil ada FIELD status paket berlangganan
//   (`_SubscriptionField`), BUKAN lagi sekadar tombol biasa:
//     - Paket Free  → judul "PAKET FREE", subjudul "Upgrade akun
//       kamu untuk fitur lebih lengkap", tombol "UPGRADE PAKET"
//       berwarna MERAH.
//     - Paket berbayar (Pro/Max/Premium) → judul "PAKET <NAMA>",
//       subjudul berisi ringkasan singkat paket, dan tombol berisi
//       "NEXT BILLING: <tanggal>" dengan warna:
//         • HIJAU   → jika tanggal tagihan berikutnya masih > 3 hari
//                     lagi, ATAU sudah lewat dari tanggalnya (berarti
//                     sudah otomatis diperpanjang ke siklus berikut).
//         • MERAH   → jika tanggal tagihan berikutnya tinggal ≤ 3
//                     hari lagi (mendekati jatuh tempo).
//   Seluruh field ini bisa DI-TAP (judul, subjudul, maupun tombol)
//   dan akan membuka `SubscriptionPage`.
//   Field ini SELALU sinkron dengan plan pengguna secara REAL TIME
//   karena dibaca langsung dari `UserProvider` via `context.watch`;
//   begitu provider memanggil `notifyListeners()` (mis. setelah user
//   upgrade/downgrade paket di SubscriptionPage), tampilan di sini
//   otomatis ikut berubah tanpa perlu reload manual.
// • Menu dikelompokkan: AKUN (Info, Edit) → SUBSCRIPTION (Paket
//   Berlangganan) → DATA (Analisis, Laporan) → PENGATURAN →
//   DUKUNGAN (Bantuan, FAQ).
// • Tombol "Keluar" tetap berdiri sendiri di bagian bawah.
// ─────────────────────────────────────────────

bool get _isMobileNative {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

enum _PhotoAction { camera, gallery, remove }

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // Cegah tap ganda saat proses logout / dialog masih terbuka.
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700; // true = web/desktop, false = android/iOS

    // `UserProvider` sudah menyediakan getter siap pakai untuk kedua
    // field ini (masing-masing sudah fallback ke default yang benar
    // saat `user` null / paket Free), jadi tidak perlu cast manual.
    final currentPlan = userProvider.subscriptionPlan;
    final DateTime? nextBillingDate = userProvider.nextBillingDate;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 20,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileCard(
                    user: user,
                    isWide: isWide,
                    onTapPhoto: () => _openPhotoViewer(context),
                    onTapInfo: () =>
                        _openPage(context, const AccountInfoPage()),
                  ),
                  const SizedBox(height: 14),

                  // ── Field Paket Berlangganan ────────────────────
                  _SubscriptionField(
                    plan: currentPlan,
                    nextBillingDate: nextBillingDate,
                    onTap: () => _openPage(context, const SubscriptionPage()),
                  ),
                  const SizedBox(height: 28),

                  const _SectionLabel('Akun'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItemData(
                        icon: Icons.info_outline,
                        label: 'Info',
                        onTap: () => _openPage(context, const AccountInfoPage()),
                      ),
                      _MenuItemData(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () => _openPage(context, const AccountEditPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _SectionLabel('Subscription'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItemData(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Paket Berlangganan',
                        onTap: () => _openPage(context, const SubscriptionPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _SectionLabel('Data'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItemData(
                        icon: Icons.analytics_outlined,
                        label: 'Analisis',
                        onTap: () =>
                            _openPage(context, const ReportAnalisisPage()),
                      ),
                      _MenuItemData(
                        icon: Icons.description_outlined,
                        label: 'Laporan',
                        onTap: () => _openPage(context, const ReportPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _SectionLabel('Pengaturan'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItemData(
                        icon: Icons.settings_outlined,
                        label: 'Pengaturan',
                        onTap: () => _openPage(context, const SettingsPage()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _SectionLabel('Dukungan'),
                  const SizedBox(height: 8),
                  _MenuGroup(
                    items: [
                      _MenuItemData(
                        icon: Icons.support_agent_outlined,
                        label: 'Bantuan',
                        onTap: () => _openPage(context, const HelpCenterPage()),
                      ),
                      _MenuItemData(
                        icon: Icons.quiz_outlined,
                        label: 'FAQ',
                        onTap: () => _openPage(context, const FaqPage()),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Tombol Keluar — terpisah dari menu ───────────
                  _LogoutButton(
                    isLoading: _isLoggingOut,
                    onPressed: _isLoggingOut ? null : () => _confirmLogout(context),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ── Foto Profil: viewer + ganti foto (dropdown) ───────────────────
  //
  // 1) Tap foto di kartu profil → buka viewer (preview besar) dengan
  //    tombol "Ganti Foto" di bawahnya.
  // 2) Tap "Ganti Foto" → viewer ditutup, lalu muncul dropdown (bottom
  //    sheet) Ambil Foto (Kamera) / Pilih dari Galeri / Hapus Foto.
  // 3) Pilihan langsung dieksekusi & disimpan ke `UserProvider` — tidak
  //    perlu masuk ke halaman Edit Profil untuk sekadar ganti foto.

  Future<void> _openPhotoViewer(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final photo = userProvider.user?.photo;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(photo: photo, radius: 110),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _changePhotoFlow(context);
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Ganti Foto'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_PhotoAction?> _showPhotoOptionsSheet(
      BuildContext context, {
        required bool showRemove,
      }) {
    return showModalBottomSheet<_PhotoAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Foto Profil',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            if (_isMobileNative) ...[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto (Kamera)'),
                onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Pilih Foto'),
                onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
              ),
            ],
            if (showRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhotoFlow(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    final hasCurrentPhoto = user?.photo?.isNotEmpty ?? false;

    final action = await _showPhotoOptionsSheet(context, showRemove: hasCurrentPhoto);
    if (action == null) return;

    if (action == _PhotoAction.remove) {
      await userProvider.removePhoto();
      return;
    }

    final source =
    action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery;

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (file == null) return;

      String? photoToSave;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        photoToSave = 'data:image/jpg;base64,${base64Encode(bytes)}';
      } else {
        final uid = user?.uid ?? 'unknown';
        final dir = await getApplicationDocumentsDirectory();
        final avatarDir = Directory('${dir.path}/avatars');
        if (!await avatarDir.exists()) {
          await avatarDir.create(recursive: true);
        }
        final ext = file.path.contains('.') ? file.path.split('.').last : 'jpg';
        final destPath = '${avatarDir.path}/avatar_$uid.$ext';
        final destFile = File(destPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }
        await File(file.path).copy(destPath);
        photoToSave = destPath;
      }

      await userProvider.updateNameAndPhoto(photo: photoToSave);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengganti foto: $e')),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    // Set flag + trigger rebuild supaya tombol "Keluar" disable dan
    // tampil spinner selama proses berjalan.
    setState(() => _isLoggingOut = true);

    // ── Logout SEBENARNYA ────────────────────────────────────────────
    // Wajib sign out dari Firebase DAN dari GoogleSignIn (bukan cuma
    // ubah flag lokal), supaya:
    //  1. `FirebaseAuth.instance.currentUser` benar-benar jadi null.
    //  2. Halaman login berikutnya TIDAK menganggap sesi masih aktif.
    //
    // `UserLocalService.clear()` HANYA mengubah flag `_loggedOut = true`.
    // Data akun & riwayat akun (`known_accounts`) TETAP tersimpan.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // abaikan jika memang tidak ada sesi google_sign_in aktif
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // abaikan jika memang tidak ada sesi firebase aktif
    }
    await UserLocalService.clear();

    if (!context.mounted) return;

    await context.read<UserProvider>().clear();

    if (!context.mounted) return;

    setState(() => _isLoggingOut = false);

    Navigator.pushNamedAndRemoveUntil(
      context, AppRoutes.login, (_) => false,
    );
  }
}

// ─────────────────────────────────────────────
// Kartu profil — menggantikan judul "Akun".
//
// Sekarang punya 2 area tap terpisah:
//   • FOTO   → `onTapPhoto` (buka viewer + tombol Ganti Foto)
//   • NAMA & EMAIL → `onTapInfo` (langsung buka AccountInfoPage)
//
// isWide == true  (web/desktop) → konten center, vertikal:
//                                   foto → nama → email
// isWide == false (android/iOS) → tetap Row seperti UI lama
// Tidak ada lagi field usia/tanggal lahir.
// ─────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.isWide,
    required this.onTapPhoto,
    required this.onTapInfo,
  });

  final dynamic user; // UserModel?
  final bool isWide;
  final VoidCallback onTapPhoto;
  final VoidCallback onTapInfo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: isWide ? _buildWide(context, cs) : _buildCompact(context, cs),
    );
  }

  // ── Web / Desktop: foto → nama → email, semua center ──────────
  Widget _buildWide(BuildContext context, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTapPhoto,
          child: UserAvatar(photo: user?.photo, radius: 40),
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTapInfo,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (user?.name as String?) ?? 'Pengguna',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (user?.email as String?) ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Android / iOS: tetap UI lama (Row) ─────────────────────────
  Widget _buildCompact(BuildContext context, ColorScheme cs) {
    return Row(
      children: [
        GestureDetector(
          onTap: onTapPhoto,
          child: UserAvatar(photo: user?.photo, radius: 34),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapInfo,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user?.name as String?) ?? 'Pengguna',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (user?.email as String?) ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Field status paket berlangganan — di bawah kartu profil.
// Bukan sekadar tombol: berupa card dengan judul + subjudul + tombol
// aksi, SELALU sinkron real-time dengan plan aktif pengguna karena
// nilai `plan` / `billingCycle` / `nextBillingDate` dibaca dari
// `UserProvider` (context.watch) di level `AccountPage`.
//
//   - Free    → "PAKET FREE" · "Upgrade akun kamu untuk fitur lebih
//               lengkap" · tombol "UPGRADE PAKET" (MERAH).
//   - Lainnya → "PAKET <NAMA>" · ringkasan singkat paket · tombol
//               "NEXT BILLING: <tanggal>" (HIJAU/MERAH tergantung
//               sisa waktu ke tanggal tagihan berikutnya).
//
// Seluruh area field bisa di-tap untuk membuka SubscriptionPage.
// ─────────────────────────────────────────────
class _SubscriptionField extends StatelessWidget {
  const _SubscriptionField({
    required this.plan,
    required this.nextBillingDate,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final DateTime? nextBillingDate;
  final VoidCallback onTap;

  static const Color _red = Color(0xFFE53935);
  static const Color _green = Color(0xFF2E7D32);

  static const List<String> _bulanIndonesia = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _formatDate(DateTime date) {
    return '${date.day} ${_bulanIndonesia[date.month - 1]} ${date.year}';
  }

  /// Warna tombol "NEXT BILLING" berdasarkan sisa waktu:
  ///  - Sudah lewat dari tanggal tagihan  → HIJAU (dianggap sudah
  ///    otomatis diperpanjang ke siklus berikutnya).
  ///  - Sisa waktu ≤ 3 hari (belum lewat) → MERAH (mendekati jatuh
  ///    tempo).
  ///  - Selain itu (> 3 hari lagi)        → HIJAU.
  Color _billingColor(DateTime? next) {
    if (next == null) return _green;
    final now = DateTime.now();
    final diff = next.difference(now);
    if (diff.isNegative) return _green; // sudah lewat → hijau kembali
    if (diff.inDays <= 3) return _red; // mendekati due date
    return _green;
  }

  String _shortDescription(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.pro:
        return 'Analisis lengkap & bebas iklan';
      case SubscriptionPlan.max:
        return 'Laporan mendalam & dukungan prioritas';
      case SubscriptionPlan.premium:
        return 'Akses fitur baru lebih awal & dukungan personal';
      case SubscriptionPlan.free:
        return 'Upgrade akun kamu untuk fitur lebih lengkap';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFree = plan.isFree;

    final Color buttonColor = isFree ? _red : _billingColor(nextBillingDate);
    final String buttonText = isFree
        ? 'UPGRADE PAKET'
        : 'NEXT BILLING: ${nextBillingDate != null ? _formatDate(nextBillingDate!) : '-'}';

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text(
                'PAKET ${plan.label.toUpperCase()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _shortDescription(plan),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ─────────────────────────────────────────────
// Kartu grup menu — kumpulan _MenuItemData ditampilkan sebagai
// ListTile berjajar dengan divider tipis di antaranya (satu card per
// section, konsisten dengan gaya kartu di halaman Info Akun).
// ─────────────────────────────────────────────
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuTile(data: items[i]),
            if (i != items.length - 1)
              Divider(
                height: 1,
                indent: 52,
                color: cs.outlineVariant.withOpacity(0.3),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.data});

  final _MenuItemData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(data.icon, size: 20, color: cs.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: cs.outline.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tombol Keluar — berdiri sendiri, terpisah dari kartu menu.
// ─────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: isLoading
            ? SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.error,
          ),
        )
            : const Icon(Icons.logout_rounded, size: 19),
        label: Text(isLoading ? 'Sedang keluar...' : 'Keluar'),
      ),
    );
  }
}