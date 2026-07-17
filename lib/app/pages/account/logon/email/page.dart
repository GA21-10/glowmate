// ─────────────────────────────────────────────
// app/login/register_email_page.dart
// ─────────────────────────────────────────────
//
// Halaman registrasi akun baru via Email + Kata Sandi (di luar Google).
//
// ALUR:
//  1. Pengguna mengisi Email, Kata Sandi, dan Konfirmasi Kata Sandi.
//  2. Sebelum akun dibuat, email divalidasi "berdasarkan Google": domain
//     email harus salah satu domain konsumen Google (gmail.com /
//     googlemail.com). Jika bukan → tampil pesan "Email tidak ada di
//     Google" dan proses registrasi dihentikan.
//
//     ⚠️ CATATAN PENTING (batasan teknis, tolong dibaca):
//     Client SDK Firebase TIDAK BISA benar-benar memverifikasi bahwa
//     sebuah email adalah inbox Gmail yang nyata & aktif — itu hanya
//     mungkin lewat OAuth Google (buka pilihan akun Google) atau lewat
//     backend (Admin SDK / Cloud Function) yang mengecek Google
//     Identity Toolkit API. Method client `fetchSignInMethodsForEmail`
//     yang sebelumnya dipakai sebagai pengecekan tambahan SUDAH DIHAPUS
//     dari SDK `firebase_auth` terbaru, jadi validasi sekarang murni
//     berdasarkan domain email (gmail.com / googlemail.com). Ini
//     memverifikasi FORMAT-nya konsisten dengan akun Google, bukan
//     memastikan inbox-nya benar-benar ada & aktif.
//     Kalau butuh validasi 100% pasti (termasuk domain Google Workspace
//     kustom, atau memastikan inbox benar-benar aktif), itu perlu
//     endpoint backend terpisah — beri tahu saya kalau mau saya bantu
//     rancang endpoint-nya.
//
//  3. Setelah lolos validasi, akun dibuat lewat
//     `FirebaseAuth.createUserWithEmailAndPassword` — Firebase akan
//     menerbitkan UID dengan FORMAT YANG SAMA PERSIS seperti UID akun
//     Google (Firebase Auth memakai satu skema UID untuk semua provider,
//     bukan skema terpisah per-provider).
//  4. UID + email tsb langsung disimpan ke penyimpanan lokal secara
//     real-time lewat `UserProvider.setUser()` (sama seperti alur
//     Google), lalu dikunci permanen di `ProfileSetupPage` (field
//     `_LockedField` di sana sudah generik, tidak spesifik Google).
//  5. Setelah tersimpan, otomatis lanjut ke `ProfileSetupPage` untuk
//     melengkapi profil (nama, tanggal lahir, alamat, dll).
// ─────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/users/global.dart';
import '../../../../core/providers/user/users.dart';
import '../../../widgets/routes/app.dart';

class RegisterEmailPage extends StatefulWidget {
  const RegisterEmailPage({super.key});

  @override
  State<RegisterEmailPage> createState() => _RegisterEmailPageState();
}

class _RegisterEmailPageState extends State<RegisterEmailPage> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  bool _saving           = false;
  bool _checkingEmail    = false;

  /// Pesan error validasi "email harus dari Google" — ditampilkan manual
  /// di bawah field Email (terpisah dari validator format biasa, karena
  /// pengecekan ini async / butuh panggilan ke Firebase).
  String? _emailGoogleError;

  static const _googleConsumerDomains = ['gmail.com', 'googlemail.com'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  /// True kalau email "dianggap valid berdasarkan Google" — lihat
  /// catatan batasan teknis di kepala file.
  ///
  /// CATATAN: sebelumnya di sini ada pengecekan tambahan lewat
  /// `FirebaseAuth.instance.fetchSignInMethodsForEmail(email)` untuk
  /// domain non-Gmail (mis. Google Workspace). Method itu SUDAH
  /// DIHAPUS dari `firebase_auth` versi terbaru (bukan sekadar
  /// dinonaktifkan oleh Email Enumeration Protection — API-nya memang
  /// tidak ada lagi di SDK), jadi sekarang validasi murni berdasarkan
  /// domain email. Kalau butuh validasi yang mencakup domain Google
  /// Workspace kustom atau verifikasi lebih pasti, itu perlu backend
  /// terpisah (Admin SDK / Cloud Function ke Identity Toolkit API) —
  /// beri tahu saya kalau mau saya bantu rancang endpoint-nya.
  Future<bool> _looksLikeGoogleEmail(String email) async {
    final domain = email.split('@').last.toLowerCase();
    return _googleConsumerDomains.contains(domain);
  }

  Future<void> _submit() async {
    if (_saving || _checkingEmail) return;

    setState(() => _emailGoogleError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailCtrl.text.trim();

    setState(() => _checkingEmail = true);
    final isGoogleEmail = await _looksLikeGoogleEmail(email);
    if (mounted) setState(() => _checkingEmail = false);

    if (!isGoogleEmail) {
      if (mounted) {
        setState(() => _emailGoogleError = 'Email tidak ada di Google');
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: _passwordCtrl.text,
      );

      final fireUser = credential.user;
      if (fireUser == null || !mounted) return;

      // UID di sini sudah pasti format Firebase asli (identik dengan
      // UID akun Google) — lihat catatan di kepala file.
      final userModel = UserModel(
        uid:   fireUser.uid,
        email: fireUser.email ?? email,
      );

      // Simpan real-time ke penyimpanan lokal + tandai status login,
      // dalam satu langkah (sama seperti alur login Google).
      await context.read<UserProvider>().setUser(userModel);

      if (!mounted) return;

      // Akun baru → selalu lanjut ke ProfileSetupPage untuk melengkapi
      // profil (UID & Email akan otomatis terkunci di sana).
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.profile,
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Register error: ${e.code} - ${e.message}');
      if (mounted) _showError(_firebaseErrorMessage(e.code));
    } catch (e) {
      debugPrint('Register error: $e');
      if (mounted) _showError('Registrasi gagal. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
      case 'email-already-in-use':
        return 'Email ini sudah terdaftar. Silakan masuk (login).';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah (minimal 8 karakter).';
      case 'operation-not-allowed':
        return 'Metode registrasi Email/Kata Sandi belum diaktifkan.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
      default:
        return 'Registrasi gagal ($code). Silakan coba lagi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Akun')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar dengan Email',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gunakan email Google (Gmail) kamu yang aktif untuk mendaftar.',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_emailGoogleError != null) {
                          setState(() => _emailGoogleError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'nama@gmail.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: _checkingEmail
                            ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                            : null,
                        errorText: _emailGoogleError,
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return 'Email wajib diisi';
                        final regex =
                        RegExp(r'^[\w.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                        if (!regex.hasMatch(value)) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !_saving,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi',
                        hintText: 'Minimal 8 karakter',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Kata sandi wajib diisi';
                        if (value.length < 8) return 'Minimal 8 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmCtrl,
                      enabled: !_saving,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Kata Sandi',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != _passwordCtrl.text) {
                          return 'Konfirmasi kata sandi tidak sama';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_saving || _checkingEmail) ? null : _submit,
                        child: (_saving || _checkingEmail)
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('Simpan & Lanjutkan'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('Sudah punya akun? Masuk di sini'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}