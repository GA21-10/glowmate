// ─────────────────────────────────────────────
// app/profile/otp_verification_page.dart
// ─────────────────────────────────────────────
//
// Halaman verifikasi OTP — DUMMY (tidak ada backend/SMS/Email asli).
// Kode 6 digit acak dicetak ke konsol/terminal (`debugPrint`) setiap
// kali dikirim/kirim-ulang, meniru apa yang biasanya dikirim lewat
// Gmail atau SMS.
//
// Fitur:
//  • Keterangan tujuan pengiriman (Gmail / No. Telepon) di tengah,
//    dengan info alamat/nomor tersamar.
//  • 6 kotak kode terpisah, HANYA menerima angka:
//      - isi 1 digit → otomatis pindah ke kotak berikutnya.
//      - hapus 1x pada kotak kosong → fokus mundur ke kotak
//        sebelumnya (dan digit di kotak itu ikut terhapus).
//      - hapus pada kotak terisi → hanya kotak itu yang kosong,
//        fokus tetap di situ.
//      - kotak terakhir terisi → otomatis mencoba verifikasi.
//  • Jika kode SALAH → seluruh kotak diberi garis tepi merah (efek
//    highlight singkat) lalu otomatis dikosongkan semua & fokus balik
//    ke kotak pertama, pengguna input ulang.
//  • Countdown "Kirim ulang kode" (60 detik).
//  • Tombol "Ganti ke No. Telepon" / "Ganti ke Gmail" di kanan bawah
//    keterangan, sesuai tujuan yang sedang aktif.
//  • Jika kode BENAR → otomatis lanjut (pop halaman ini dengan
//    `Navigator.pop(context, true)`), dan halaman pemanggil
//    (`profile_setup_page.dart`) yang menavigasikan ke HomePage.
// ─────────────────────────────────────────────
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/swich/l10n.dart';

enum OtpTarget { email, phone }

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({
    super.key,
    required this.initialTarget,
    this.email,
    this.phone,
  });

  /// Tujuan awal pengiriman OTP.
  final OtpTarget initialTarget;

  /// Alamat Gmail (ditampilkan tersamar). Boleh null jika tidak ada.
  final String? email;

  /// Nomor telepon lengkap dengan kode negara (ditampilkan tersamar).
  /// Boleh null jika tidak ada.
  final String? phone;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with SingleTickerProviderStateMixin {
  static const int _codeLength = 6;
  static const int _resendSeconds = 60;

  late OtpTarget _target;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  String _currentCode = '';
  bool _hasError = false;
  bool _verifying = false;

  Timer? _resendTimer;
  int _secondsLeft = _resendSeconds;

  late AnimationController _shakeController;

  bool get _canSwitchTarget =>
      (widget.email?.isNotEmpty ?? false) && (widget.phone?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget;
    _controllers = List.generate(_codeLength, (_) => TextEditingController());
    _focusNodes = List.generate(_codeLength, (_) => FocusNode());
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _generateAndSendCode();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _resendTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Dummy OTP generator — hanya tampil di terminal/console ──────
  void _generateAndSendCode() {
    final code = (Random().nextInt(900000) + 100000).toString();
    _currentCode = code;
    final destination = _target == OtpTarget.email
        ? (widget.email ?? '-')
        : (widget.phone ?? '-');
    // ── INI DUMMY: kode HANYA dicetak ke terminal, bukan dikirim
    // ── sungguhan lewat Gmail/SMS. Ganti dengan integrasi provider
    // ── OTP asli (mis. Firebase Auth / SMS gateway) untuk produksi.
    debugPrint('══════════════════════════════════════════');
    debugPrint(' [DUMMY OTP] Kode verifikasi untuk $destination');
    debugPrint(' [DUMMY OTP] KODE: $code');
    debugPrint('══════════════════════════════════════════');
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    _clearAll(refocusFirst: true);
    _generateAndSendCode();
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('otp_resent_message'))),
    );
  }

  void _switchTarget() {
    if (!_canSwitchTarget) return;
    setState(() {
      _target = _target == OtpTarget.email ? OtpTarget.phone : OtpTarget.email;
      _hasError = false;
    });
    _clearAll(refocusFirst: true);
    _generateAndSendCode();
    _startResendTimer();
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Hanya ambil karakter terakhir (jaga-jaga jika tempel banyak digit).
      final digit = value.characters.last;
      _controllers[index].text = digit;
      _controllers[index].selection = const TextSelection.collapsed(offset: 1);

      if (index < _codeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
    }

    if (_hasError) setState(() => _hasError = false);

    if (_enteredCode.length == _codeLength) {
      _verifyCode();
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isNotEmpty) {
      // Kotak ini masih terisi → cukup kosongkan kotak ini, fokus tetap.
      setState(() => _controllers[index].clear());
      return;
    }
    // Kotak ini sudah kosong & backspace ditekan lagi → mundur satu
    // kotak, hapus isinya, lalu fokus pindah ke sana. Efek ini akan
    // otomatis berulang mundur terus jika pengguna terus menghapus.
    if (index > 0) {
      setState(() => _controllers[index - 1].clear());
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyCode() async {
    if (_verifying) return;
    setState(() => _verifying = true);

    // Simulasikan sedikit delay verifikasi supaya terasa natural.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (_enteredCode == _currentCode) {
      setState(() => _verifying = false);
      Navigator.pop(context, true); // → sukses, lanjut ke HomePage
      return;
    }

    // Kode salah → highlight merah pada seluruh kotak, lalu bersihkan.
    setState(() {
      _hasError = true;
      _verifying = false;
    });
    _shakeController.forward(from: 0);
    HapticFeedback.mediumImpact();

    // Beri jeda visual agar pengguna sempat melihat highlight merah,
    // lalu otomatis bersihkan semua kotak & kembali ke kotak pertama.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _clearAll(refocusFirst: true);
  }

  void _clearAll({bool refocusFirst = false}) {
    setState(() {
      for (final c in _controllers) c.clear();
      _hasError = false;
    });
    if (refocusFirst) {
      Future.microtask(() {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final visible = name.length <= 2 ? name : name.substring(0, 2);
    return '$visible${'*' * max(1, name.length - 2)}@${parts[1]}';
  }

  /// Menyamarkan nomor telepon lengkap (mis. "+62 812345678901") menjadi
  /// "+62 8123***8901" — kode negara & beberapa digit awal/akhir tetap
  /// terlihat, bagian tengah disamarkan.
  String _maskedPhone(String phone) {
    final trimmed = phone.trim();
    final spaceIdx = trimmed.indexOf(' ');
    final dialPart = spaceIdx > 0 ? trimmed.substring(0, spaceIdx) : '';
    final digits = (spaceIdx > 0 ? trimmed.substring(spaceIdx + 1) : trimmed)
        .replaceAll(RegExp(r'\s+'), '');

    if (digits.length <= 6) {
      return '$dialPart ${'*' * digits.length}'.trim();
    }
    final start = digits.substring(0, 4);
    final end = digits.substring(digits.length - 4);
    final maskedMiddle = '*' * (digits.length - 8);
    return '$dialPart $start$maskedMiddle$end'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final destination = _target == OtpTarget.email
        ? (widget.email != null ? _maskedEmail(widget.email!) : '-')
        : (widget.phone != null ? _maskedPhone(widget.phone!) : '-');

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _target == OtpTarget.email
                          ? Icons.mark_email_read_outlined
                          : Icons.sms_outlined,
                      size: 34,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('otp_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _target == OtpTarget.email
                        ? context.tr('otp_sent_to_email')
                        : context.tr('otp_sent_to_phone'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: cs.onSurface.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.primary),
                  ),

                  const SizedBox(height: 34),

                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final shake = sin(_shakeController.value * pi * 6) *
                          (1 - _shakeController.value) *
                          8;
                      return Transform.translate(offset: Offset(shake, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_codeLength, (i) {
                        return Padding(
                          padding: EdgeInsets.only(right: i == _codeLength - 1 ? 0 : 10),
                          child: _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            hasError: _hasError,
                            onChanged: (v) => _onDigitChanged(i, v),
                            onBackspace: () => _onBackspace(i),
                          ),
                        );
                      }),
                    ),
                  ),

                  if (_hasError) ...[
                    const SizedBox(height: 14),
                    Text(
                      context.tr('otp_wrong_code'),
                      style: TextStyle(fontSize: 12.5, color: cs.error, fontWeight: FontWeight.w600),
                    ),
                  ],

                  if (_verifying) ...[
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _secondsLeft > 0
                          ? Text(
                        context.tr('otp_resend_countdown', params: {'seconds': '$_secondsLeft'}),
                        style: TextStyle(fontSize: 12.5, color: cs.onSurface.withOpacity(0.55)),
                      )
                          : TextButton(
                        onPressed: _resend,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(context.tr('otp_resend_button')),
                      ),
                      if (_canSwitchTarget)
                        TextButton.icon(
                          onPressed: _switchTarget,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          icon: Icon(
                            _target == OtpTarget.email
                                ? Icons.sms_outlined
                                : Icons.mail_outline,
                            size: 16,
                          ),
                          label: Text(
                            _target == OtpTarget.email
                                ? context.tr('otp_switch_to_phone')
                                : context.tr('otp_switch_to_email'),
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onBackspace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 46,
      height: 56,
      // AnimatedBuilder mendengarkan `focusNode` (Listenable) supaya
      // border ikut berubah warna tepat saat fokus pindah antar kotak,
      // tanpa perlu setState manual di parent.
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final borderColor = hasError
              ? cs.error
              : (focusNode.hasFocus ? cs.primary : cs.outline.withOpacity(0.35));
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.surfaceContainerHighest.withOpacity(0.45),
              border: Border.all(
                color: borderColor,
                width: hasError || focusNode.hasFocus ? 2 : 1.2,
              ),
            ),
            child: child,
          );
        },
        child: Focus(
          // Backspace pada TextField yang sudah kosong tidak dikonsumsi
          // oleh TextField (tidak ada apa pun untuk dihapus), sehingga
          // event ini "naik" (bubble) ke `Focus` ancestor ini — di
          // sinilah mundur-ke-kotak-sebelumnya ditangani.
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.backspace &&
                controller.text.isEmpty) {
              onBackspace();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
            onTap: () => controller.selection =
                TextSelection(baseOffset: 0, extentOffset: controller.text.length),
          ),
        ),
      ),
    );
  }
}