// ─────────────────────────────────────────────
// app/login/login_page.dart
// ─────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../../core/models/users/global.dart';
import '../../../core/providers/user/users.dart';
import '../../../core/services/local.dart';
import '../../../core/swich/l10n.dart';
import '../../widgets/routes/app.dart';
import '../logon/data/avatar.dart';
import 'email/page.dart';
import 'legals/privacy/polecy.dart';
import 'legals/term/use.dart';

// ── Platform helper ───────────────────────────

bool get _isDesktopNative {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

bool get _isMobileNative {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

// ─────────────────────────────────────────────
//
// CATATAN PENYIMPANAN:
// Firebase Auth di sini HANYA dipakai sebagai mekanisme login (untuk
// mendapatkan identitas Google: uid/email/name/photo). Setelah credential
// didapat, SEMUA data profil (nama, foto, tanggal lahir, alamat, telepon,
// kondisi kulit) disimpan & dibaca 100% dari penyimpanan internal
// (`UserLocalService`) lewat `UserProvider.setUser()` — tidak ada
// sinkronisasi data profil ke Firestore/Firebase apa pun. Gmail hanya
// jadi akun default (identitas + foto awal), lalu pengguna lanjut mengisi
// data di `ProfileSetupPage`.
// ─────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _agreed  = false;
  bool _loading = false;

  // ── Form login Email + Kata Sandi (terpisah dari tombol Google) ────
  final _emailFormKey    = GlobalKey<FormState>();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  bool  _obscurePassword = true;

  UserModel? _lastAccount;

  // ── PENTING ───────────────────────────────────────────────────────────
  // `_loggedOut` menandai bahwa user PERNAH login sebelumnya lalu
  // menekan tombol "Keluar" (logout). Ini beda dari sekadar "ada akun
  // tersimpan di local cache" — makanya dicek terpisah dari `_lastAccount`,
  // dan diambil LANGSUNG dari `UserLocalService.isLoggedOut()` (bukan
  // negasi dari isLoggedIn()) supaya sinkron 1:1 dengan flag asli di
  // storage tanpa risiko kebalik.
  //
  // "WELCOME BACK" HANYA muncul (fungsinya di-hidden selain itu) kalau
  // DUA-DUANYA benar:
  //   1. `_lastAccount != null`  → ada data akun tersimpan di local cache.
  //   2. `_loggedOut == true`    → user memang baru saja logout (bukan
  //                                 install pertama kali / belum pernah login).
  //
  // DEFAULT SELALU "WELCOME": baik saat state awal (sebelum data local
  // selesai dibaca) maupun kalau proses baca local storage gagal karena
  // sebab apapun, `_lastAccount` tetap null dan `_loggedOut` tetap false
  // → `_showWelcomeBack` tetap false → tampilan otomatis fallback ke
  // "WELCOME", tidak pernah nyangkut di state error.
  bool _loggedOut = false;

  bool get _showWelcomeBack => _lastAccount != null && _loggedOut;

  @override
  void initState() {
    super.initState();
    _loadLastAccount();
  }

  Future<void> _loadLastAccount() async {
    UserModel? acc;
    bool loggedOut = false;

    try {
      acc = await UserLocalService.getLastAccount();
    } catch (e) {
      debugPrint('getLastAccount gagal, fallback ke WELCOME: $e');
      acc = null;
    }

    try {
      loggedOut = await UserLocalService.isLoggedOut();
    } catch (e) {
      debugPrint('isLoggedOut gagal, fallback ke WELCOME: $e');
      loggedOut = false;
    }

    if (mounted) {
      setState(() {
        _lastAccount = acc;
        _loggedOut   = loggedOut;
      });
    }
  }

  // ── Lanjutkan sesi tersimpan (tanpa Google auth) ────────────────────
  //
  // Dipanggil dari tile "WELCOME BACK". SELALU langsung masuk ke
  // HomePage() memakai data akun yang sudah tersimpan di penyimpanan
  // internal — tidak pernah menampilkan pesan error apapun ke user.
  // `UserProvider.setUser()` sudah menangani penyimpanan + penandaan
  // login secara internal (auto CRUD), jadi cukup dipanggil sekali di
  // sini — tidak perlu memanggil `UserLocalService` secara terpisah lagi
  // supaya tidak ada tulis-ganda ke storage yang sama.
  Future<void> _continueWithSession() async {
    if (_loading || _lastAccount == null) return;

    setState(() => _loading = true);
    try {
      UserModel? existing;
      try {
        existing = await UserLocalService.getUser();
      } catch (_) {
        existing = null;
      }

      final fireUser = FirebaseAuth.instance.currentUser;
      final cached = _lastAccount!;

      final userModel = UserModel(
        uid:       fireUser?.uid ?? existing?.uid ?? cached.uid,
        email:     fireUser?.email ?? existing?.email ?? cached.email,
        name:      existing?.name ?? fireUser?.displayName ?? cached.name,
        photo:     existing?.photo ?? fireUser?.photoURL ?? cached.photo,
        birthDate: existing?.birthDate ?? cached.birthDate,
      );

      try {
        // `setUser` otomatis: (1) gabung dengan data lokal lengkap yang
        // sudah ada (termasuk alamat/telepon/kondisi kulit), (2) simpan
        // ke penyimpanan internal, (3) tandai status login → semua
        // dalam satu langkah, auto persist.
        await context.read<UserProvider>().setUser(userModel);
      } catch (e) {
        debugPrint('setUser (continue session) gagal, lanjut ke Home: $e');
      }
    } catch (e) {
      debugPrint('continueWithSession gagal, tetap lanjut ke Home: $e');
    } finally {
      if (mounted) {
        // Sesuai requirement: tile "WELCOME BACK" selalu langsung ke Home,
        // tidak pernah menampilkan pesan error ke user apapun yang terjadi.
        setState(() => _loading = false);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
              (_) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login via Email + Kata Sandi ────────────────────────────────────
  //
  // Berlaku untuk kedua state tampilan (WELCOME & WELCOME BACK) — field
  // ini SELALU tampil di atas tombol Google, tidak tersembunyi oleh
  // status login sebelumnya. Dipakai untuk akun yang didaftarkan lewat
  // `RegisterEmailPage` (Firebase Auth Email/Password), BUKAN akun
  // Google — walau UID yang dihasilkan Firebase formatnya identik untuk
  // kedua metode, jadi seluruh logic penyimpanan lokal di bawah ini bisa
  // dipakai apa adanya (sama seperti alur Google).
  Future<void> _loginWithEmailPassword() async {
    if (_loading) return;

    if (!_agreed) {
      _showError(context.tr('login_agree_required'));
      return;
    }
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final fireUser = credential.user;
      if (fireUser == null || !mounted) return;

      final existing = await UserLocalService.getUser();
      final sameUid  = existing?.uid == fireUser.uid;

      final userModel = UserModel(
        uid:       fireUser.uid,
        email:     fireUser.email ?? _emailCtrl.text.trim(),
        name:      sameUid ? existing?.name  : fireUser.displayName,
        photo:     sameUid ? existing?.photo : fireUser.photoURL,
        birthDate: sameUid ? existing?.birthDate : null,
      );

      // Sama seperti login Google: satu panggilan ini sudah cukup untuk
      // menggabung data lokal lengkap, menyimpan ke penyimpanan internal
      // secara real-time, dan menandai status login.
      await context.read<UserProvider>().setUser(userModel);

      if (!mounted) return;

      final hasProfile = await UserLocalService.hasCompleteProfile();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        hasProfile ? AppRoutes.home : AppRoutes.profile,
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Email login error: ${e.code} - ${e.message}');
      if (mounted) _showError(_firebaseErrorMessage(e.code));
    } catch (e) {
      debugPrint('Email login error: $e');
      if (mounted) _showError(context.tr('login_failed_generic'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Login penuh via Google (selalu memicu popup pemilih akun) ──────

  Future<void> _loginGoogle({UserModel? hint}) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      UserCredential? credential;

      if (kIsWeb) {
        // ── Web → popup sistem browser ────────────────────────────────
        //
        // PENTING: `prompt: 'select_account'` WAJIB ada. Tanpa ini, kalau
        // browser masih punya sesi Google aktif, popup bisa langsung
        // auto-pilih akun terakhir TANPA menampilkan daftar akun sama
        // sekali — jadi user tidak benar-benar "memilih" akun.
        // Dengan prompt ini, popup pemilih akun akan SELALU muncul,
        // baik untuk memilih akun yang sama maupun akun lain.
        final provider = GoogleAuthProvider();
        final params = <String, String>{'prompt': 'select_account'};
        if (hint?.email != null) params['login_hint'] = hint!.email;
        provider.setCustomParameters(params);
        credential = await FirebaseAuth.instance.signInWithPopup(provider);

      } else if (_isDesktopNative) {
        // ── Desktop (Windows/macOS/Linux) → browser DEFAULT sistem ───────
        //
        // signInWithProvider() bawaan firebase_auth di desktop TIDAK
        // memakai webview internal — plugin ini membuka flow OAuth lewat
        // BROWSER DEFAULT milik OS (Chrome/Edge/Safari/dll, sesuai
        // pengaturan sistem user), lalu SETELAH BERHASIL otomatis kembali
        // ke aplikasi desktop tanpa perlu user pindah-pindah app secara
        // manual.
        //
        // `prompt: 'select_account'` juga WAJIB di sini dengan alasan
        // yang sama seperti di web — supaya jendela pemilih akun selalu
        // muncul, tidak diam-diam pakai sesi browser yang masih tersimpan.
        final provider = GoogleAuthProvider();
        final params = <String, String>{'prompt': 'select_account'};
        if (hint?.email != null) params['login_hint'] = hint!.email;
        provider.setCustomParameters(params);
        credential = await FirebaseAuth.instance.signInWithProvider(provider);

      } else if (_isMobileNative) {
        // ── Android / iOS → google_sign_in v7 (native sheet / popup) ───
        final gsi = GoogleSignIn.instance;

        // PENTING: pastikan tidak ada sesi google_sign_in "nyantol" dari
        // sebelumnya supaya user benar-benar diminta memilih/konfirmasi
        // akun lagi (memenuhi requirement: popup pemilih akun WAJIB selalu
        // muncul, tidak boleh auto-pilih diam-diam).
        try {
          await gsi.signOut();
        } catch (_) {
          // abaikan kalau memang belum ada sesi
        }

        final GoogleSignInAccount googleUser = await gsi.authenticate();

        final String? idToken = googleUser.authentication.idToken;
        if (idToken == null) {
          throw Exception(
            'ID Token kosong. Pastikan SHA-1 fingerprint sudah didaftarkan '
                'di Firebase Console untuk package ini.',
          );
        }

        final oauthCred = GoogleAuthProvider.credential(idToken: idToken);
        credential = await FirebaseAuth.instance.signInWithCredential(oauthCred);
      }

      // ── Setelah credential didapat ─────────────────────────────────────
      // Firebase Auth berhenti di sini — cuma dipakai untuk dapat
      // identitas Google. Mulai baris ini semua persist 100% lokal.
      final fireUser = credential?.user;
      if (fireUser == null || !mounted) return;

      final existing = await UserLocalService.getUser();
      final userModel = UserModel(
        uid:       fireUser.uid,
        email:     fireUser.email ?? '',
        // Nama & foto: kalau UID sama dengan data lokal yang sudah ada,
        // pertahankan yang lokal (mis. foto yang pernah diambil sendiri).
        // Kalau tidak, pakai default dari Google (Gmail sebagai akun
        // default) — inilah foto yang tampil sebelum user ganti foto.
        name:      (existing?.uid == fireUser.uid && existing?.name != null)
            ? existing!.name
            : fireUser.displayName,
        photo:     (existing?.uid == fireUser.uid && existing?.photo != null)
            ? existing!.photo
            : fireUser.photoURL,
        birthDate: existing?.uid == fireUser.uid ? existing?.birthDate : null,
      );

      // Satu panggilan ini sudah cukup: gabung data lokal lengkap (alamat,
      // telepon, kondisi kulit ikut terbawa lewat merge di provider),
      // simpan ke penyimpanan internal, dan tandai status login.
      await context.read<UserProvider>().setUser(userModel);

      if (!mounted) return;

      final hasProfile = await UserLocalService.hasCompleteProfile();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        // Gmail sudah jadi akun default (identitas + foto) → lanjut ke
        // ProfileSetupPage untuk melengkapi data (nama/tanggal
        // lahir/alamat/telepon/kondisi kulit) kalau belum lengkap.
        hasProfile ? AppRoutes.home : AppRoutes.profile,
            (_) => false,
      );

    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      debugPrint('GoogleSignIn error: ${e.code} - ${e.description}');
      if (mounted) {
        _showError(context.tr(
          'login_failed_with_reason',
          params: {'reason': e.description ?? e.code.toString()},
        ));
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth error: ${e.code} - ${e.message}');
      if (mounted) {
        _showError(_firebaseErrorMessage(e.code));
      }
    } catch (e) {
      debugPrint('Login error: $e');
      if (mounted) {
        _showError(context.tr('login_failed_generic'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return context.tr('err_account_exists_diff_credential');
      case 'network-request-failed':
        return context.tr('err_network_failed');
      case 'user-not-found':
        return context.tr('err_user_not_found');
      case 'wrong-password':
        return context.tr('err_wrong_password');
      case 'invalid-credential':
        return context.tr('err_invalid_credential');
      case 'invalid-email':
        return context.tr('err_invalid_email');
      case 'user-disabled':
        return context.tr('err_user_disabled');
      case 'too-many-requests':
        return context.tr('err_too_many_requests');
      default:
        return context.tr('login_failed_with_code', params: {'code': code});
    }
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withOpacity(0.08), cs.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('app_name'),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            _buildWelcomeText(cs),
                            const SizedBox(height: 32),

                            if (_showWelcomeBack) ...[
                              _buildLastAccountTile(cs),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                      child: Divider(
                                          color: cs.outline.withOpacity(0.3))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      context.tr('login_or_use_other_account'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withOpacity(0.45),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                      child: Divider(
                                          color: cs.outline.withOpacity(0.3))),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // ── Login Email + Kata Sandi (di atas tombol Google) ──
                            _buildEmailPasswordForm(cs),

                            // ── Garis tipis pemisah ────────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Row(
                                children: [
                                  Expanded(child: Divider(color: cs.outline.withOpacity(0.3))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      context.tr('or_divider'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withOpacity(0.45),
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: cs.outline.withOpacity(0.3))),
                                ],
                              ),
                            ),

                            if (_isDesktopNative)
                              _buildDesktopInfo(cs)
                            else
                              _buildGoogleButton(cs),

                            const SizedBox(height: 20),
                            _buildAgreement(cs),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildRegisterLink(cs),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────

  Widget _buildWelcomeText(ColorScheme cs) {
    if (_showWelcomeBack) {
      // Sudah pernah login sebelumnya (baru saja logout / sesi tersimpan)
      return Column(
        children: [
          Text(
            context.tr('login_welcome_back_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('login_welcome_back_subtitle'),
            style:
            TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.55)),
          ),
        ],
      );
    }

    // Belum pernah login sama sekali (install pertama kali)
    return Column(
      children: [
        Text(
          context.tr('login_welcome_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: cs.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('login_welcome_subtitle'),
          textAlign: TextAlign.center,
          style:
          TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.55)),
        ),
      ],
    );
  }

  Widget _buildLastAccountTile(ColorScheme cs) {
    final acc = _lastAccount!;

    // Selalu melanjutkan sesi tersimpan → langsung ke HomePage(), tanpa
    // memicu Google auth lagi.
    final VoidCallback? onTap = !_agreed ? null : _continueWithSession;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withOpacity(0.2)),
        ),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              UserAvatar(photo: acc.photo, radius: 22, iconSize: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.name ?? context.tr('generic_user_fallback'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      acc.email,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.55)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: cs.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Form Email + Kata Sandi ────────────────────────────────────────
  //
  // Field ini SELALU tampil (baik WELCOME maupun WELCOME BACK), terpisah
  // dari tombol Google. Diletakkan di ATAS garis tipis pemisah + tombol
  // Google, sesuai urutan: [Email] → [Kata Sandi] → [tombol MASUK] →
  // garis tipis → tombol Google.
  Widget _buildEmailPasswordForm(ColorScheme cs) => Form(
    key: _emailFormKey,
    child: Column(
      children: [
        TextFormField(
          controller: _emailCtrl,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: context.tr('email'),
            hintText: context.tr('email_hint'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return context.tr('validation_email_required');
            final regex = RegExp(r'^[\w.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
            if (!regex.hasMatch(value)) return context.tr('validation_email_invalid');
            return null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _passwordCtrl,
          enabled: !_loading,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _loginWithEmailPassword(),
          decoration: InputDecoration(
            labelText: context.tr('password_label'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) =>
          (v == null || v.isEmpty) ? context.tr('validation_password_required') : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_agreed && !_loading) ? _loginWithEmailPassword : null,
            child: _loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : Text(context.tr('login_button')),
          ),
        ),
      ],
    ),
  );

  // ── Link "Belum punya akun? Registrasi disini" ──────────────────────
  //
  // Diletakkan di LUAR Card login (lihat build()), menuju halaman
  // `RegisterEmailPage` untuk membuat akun baru via Email + Kata Sandi.
  Widget _buildRegisterLink(ColorScheme cs) => Center(
    child: TextButton(
      onPressed: _loading
          ? null
          : () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterEmailPage()),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
          children: [
            TextSpan(text: context.tr('register_prompt_prefix')),
            TextSpan(
              text: context.tr('register_prompt_link'),
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildGoogleButton(ColorScheme cs) => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      // Tombol ini SELALU memanggil autentikasi Google penuh dengan popup
      // pemilih akun (tanpa hint), dipakai untuk pilih akun lain / akun baru.
      onPressed:
      (_agreed && !_loading) ? () => _loginGoogle() : null,
      icon: _loading
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white),
      )
          : const Icon(Icons.g_mobiledata, size: 28),
      label: Text(context.tr('continue_with_google')),
    ),
  );

  Widget _buildDesktopInfo(ColorScheme cs) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_browser_rounded,
                color: cs.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('desktop_google_info'),
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed:
          (_agreed && !_loading) ? () => _loginGoogle() : null,
          icon: _loading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Icon(Icons.g_mobiledata, size: 28),
          label: Text(context.tr('login_with_google')),
        ),
      ),
    ],
  );

  Widget _buildAgreement(ColorScheme cs) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Checkbox(
        value: _agreed,
        activeColor: cs.primary,
        onChanged: (v) => setState(() => _agreed = v ?? false),
      ),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall,
            children: [
              TextSpan(text: context.tr('agreement_prefix')),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage()),
                  ),
                  child: Text(
                    context.tr('privacy_policy'),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              TextSpan(text: context.tr('agreement_and')),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsOfServicePage()),
                  ),
                  child: Text(
                    context.tr('terms_of_service'),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}