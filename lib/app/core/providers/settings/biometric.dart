import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocalAuthKind { biometric, devicePin, none }
enum ToggleResult { success, cancelledByUser, notAvailable, failed }

class BiometricProvider extends ChangeNotifier {
  static const _key = 'biometric_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled   = false;
  bool _available = false;
  bool _loaded    = false;
  LocalAuthKind _kind = LocalAuthKind.none;

  /// Log setiap langkah deteksi — ditampilkan di UI diagnostic supaya
  /// akar masalah kelihatan tanpa perlu ngecek console.
  final List<String> _diagnosticLog = [];
  List<String> get diagnosticLog => List.unmodifiable(_diagnosticLog);

  String? get lastError => _diagnosticLog.isEmpty ? null : _diagnosticLog.last;

  bool get enabled    => _enabled;
  bool get available  => _available;
  bool get loaded      => _loaded;
  LocalAuthKind get kind => _kind;
  bool get isSupported => _kind != LocalAuthKind.none;

  String get label => switch (_kind) {
    LocalAuthKind.biometric => 'Sidik Jari / Face ID',
    LocalAuthKind.devicePin => 'PIN Perangkat',
    LocalAuthKind.none => '',
  };

  IconData get icon => switch (_kind) {
    LocalAuthKind.biometric => Icons.fingerprint,
    LocalAuthKind.devicePin => Icons.pin_outlined,
    LocalAuthKind.none => Icons.lock_outline,
  };

  void _log(String msg) {
    _diagnosticLog.add(msg);
    debugPrint('[BiometricProvider] $msg');
  }

  Future<void> load() async {
    _diagnosticLog.clear();
    _loaded = false;

    if (kIsWeb) {
      _log('Platform: Web → fitur disembunyikan (sesuai desain).');
      _kind = LocalAuthKind.none;
      _available = false;
      _enabled = false;
      _loaded = true;
      notifyListeners();
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _kind = LocalAuthKind.biometric;
        _log('Platform: Android → mode biometrik.');
        break;
      case TargetPlatform.iOS:
        _kind = LocalAuthKind.biometric;
        _log('Platform: iOS → mode biometrik.');
        break;
      case TargetPlatform.windows:
        _kind = LocalAuthKind.devicePin;
        _log('Platform: Windows → mode PIN (Windows Hello).');
        break;
      case TargetPlatform.macOS:
        _kind = LocalAuthKind.devicePin;
        _log('Platform: macOS → mode PIN (Touch ID/password).');
        break;
      default:
        _kind = LocalAuthKind.none;
        _log('Platform: ${defaultTargetPlatform.name} → tidak didukung local_auth.');
    }

    if (_kind == LocalAuthKind.none) {
      _available = false;
      _enabled = false;
      _loaded = true;
      notifyListeners();
      return;
    }

    // ── Setiap panggilan API terpisah try/catch — satu gagal tidak
    // menjatuhkan semuanya, dan kita tahu PERSIS titik mana yang gagal.
    bool deviceSupported = false;
    try {
      deviceSupported = await _auth.isDeviceSupported();
      _log('isDeviceSupported() = $deviceSupported');
    } catch (e) {
      _log('ERROR isDeviceSupported(): $e');
    }

    if (_kind == LocalAuthKind.biometric) {
      bool canCheck = false;
      List<BiometricType> enrolled = [];

      try {
        canCheck = await _auth.canCheckBiometrics;
        _log('canCheckBiometrics = $canCheck');
      } catch (e) {
        _log('ERROR canCheckBiometrics: $e');
      }

      try {
        enrolled = await _auth.getAvailableBiometrics();
        _log('getAvailableBiometrics() = $enrolled');
      } catch (e) {
        _log('ERROR getAvailableBiometrics(): $e');
      }

      _available = deviceSupported && canCheck && enrolled.isNotEmpty;

      if (!_available) {
        if (!deviceSupported) {
          _log('KESIMPULAN: device tidak mendukung local auth sama sekali.');
        } else if (!canCheck) {
          _log('KESIMPULAN: hardware biometrik tidak terdeteksi.');
        } else {
          _log('KESIMPULAN: belum ada sidik jari/Face ID terdaftar di HP.');
        }
      } else {
        _log('KESIMPULAN: biometrik siap dipakai.');
      }
    } else {
      _available = deviceSupported;
      _log(_available
          ? 'KESIMPULAN: PIN/password sistem siap dipakai.'
          : 'KESIMPULAN: device tidak mendukung PIN/password sistem, atau plugin desktop belum terpasang benar.');
    }

    final p = await SharedPreferences.getInstance();
    _enabled = (p.getBool(_key) ?? false) && _available;
    _loaded = true;

    notifyListeners();
  }

  Future<ToggleResult> requestToggle(bool wantEnabled) async {
    if (!isSupported || !_available) {
      _log('requestToggle($wantEnabled) ditolak: not supported/available.');
      return ToggleResult.notAvailable;
    }
    if (_enabled == wantEnabled) return ToggleResult.success;

    final reason = wantEnabled
        ? 'Verifikasi identitas Anda untuk mengaktifkan ${label.toLowerCase()}'
        : 'Verifikasi identitas Anda untuk menonaktifkan ${label.toLowerCase()}';

    final verified = await _promptSystemAuth(reason);
    if (!verified) return ToggleResult.cancelledByUser;

    _enabled = wantEnabled;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, wantEnabled);
    notifyListeners();
    return ToggleResult.success;
  }

  Future<bool> authenticate() async {
    if (!isSupported || !_enabled) return true;
    return _promptSystemAuth(
      'Verifikasi identitas Anda untuk masuk ke GlowMate',
      allowFallback: true,
    );
  }

  Future<bool> _promptSystemAuth(String reason, {bool allowFallback = false}) async {
    const maxAttempts = 3;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      try {
        _log('Memanggil auth.authenticate() percobaan #$attempt...');
        final ok = await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: _kind == LocalAuthKind.biometric && !allowFallback,
          persistAcrossBackgrounding: true,
        );
        _log('authenticate() hasil = $ok');
        if (ok) return true;
        if (!allowFallback) return false;
      } on LocalAuthException catch (e) {
        _log('LocalAuthException: code=${e.code.name} description=${e.description}');

        if (e.code == LocalAuthExceptionCode.noBiometricHardware) {
          return true;
        }
        if (e.code == LocalAuthExceptionCode.uiUnavailable) {
          _log('KESIMPULAN: konfigurasi native bermasalah (bukan FragmentActivity). Stop retry.');
          return false; // langsung keluar loop, jangan retry
        }
        if (e.code == LocalAuthExceptionCode.userCanceled ||
            e.code == LocalAuthExceptionCode.systemCanceled) {
          if (!allowFallback) return false;
          continue;
        }
        if (e.code == LocalAuthExceptionCode.temporaryLockout ||
            e.code == LocalAuthExceptionCode.biometricLockout) {
          if (!allowFallback) return false;
          return _authenticateWithDeviceCredential(reason);
        }
        return false;
      } catch (e, st) {
        _log('ERROR tak terduga di authenticate(): $e');
        debugPrint('$st');
        return false;
      }
    }

    return allowFallback ? _authenticateWithDeviceCredential(reason) : false;
  }

  Future<bool> _authenticateWithDeviceCredential(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Masukkan PIN / Pola / Password perangkat Anda',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      _log('device credential authenticate() hasil = $ok');
      return ok;
    } catch (e) {
      _log('ERROR device credential: $e');
      return false;
    }
  }
}