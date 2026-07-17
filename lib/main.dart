import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import 'app/core/models/language.dart';
import 'app/core/providers/settings/biometric.dart';
import 'app/core/providers/settings/language.dart';
import 'app/core/providers/theme/app.dart';
import 'app/core/providers/user/users.dart';
import 'app/core/providers/user/photo.dart';
import 'app/pages/account/logon/firebase_options.dart';
import 'app/pages/analysis/repository/analisis.dart';
import 'app/pages/report/provider/req.dart';
import 'app/pages/widgets/routes/router.dart';
import 'app/pages/widgets/theme/theme.dart';

const String _kGoogleWebClientId =
    '474911245185-n0qnnl54m3amnmj9l40pgfjt1ufpepau.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? _kGoogleWebClientId : null,
    );
  } catch (e, st) {
    debugPrint('GoogleSignIn init error: $e');
    debugPrint('$st');
  }

  final themeProvider        = ThemeProvider();
  final userProvider         = UserProvider();
  final biometricProvider    = BiometricProvider();
  final profileImageProvider = ProfileImageProvider();
  final analysisRepository   = AnalysisRepository();
  final languageProvider     = LanguageProvider();

  await Future.wait([
    themeProvider.load(),
    userProvider.loadFromLocal(),
    biometricProvider.load(),
    profileImageProvider.load(),
    analysisRepository.load(),
    languageProvider.load(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider.value(value: biometricProvider),
        ChangeNotifierProvider.value(value: profileImageProvider),
        ChangeNotifierProvider.value(value: analysisRepository),
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProxyProvider<AnalysisRepository, RecommendationRepository>(
          create: (_) => RecommendationRepository()
            ..updateFromRecords(analysisRepository.records),
          update: (_, analysisRepo, recRepo) =>
          (recRepo ?? RecommendationRepository())
            ..updateFromRecords(analysisRepo.records),
        ),
      ],
      child: const GlowMate(),
    ),
  );
}

class GlowMate extends StatelessWidget {
  const GlowMate({super.key});

  /// Delegate lokalisasi bawaan Flutter untuk widget Material/Cupertino
  /// (teks "OK"/"Cancel", format DatePicker, dsb). Ini yang TADI HILANG
  /// sehingga bahasa apa pun selain default ("en"/US) memicu error:
  /// "MaterialLocalizations delegate that supports the <locale> was
  /// not found".
  static const List<LocalizationsDelegate<dynamic>> _kDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Cek apakah [locale] benar-benar didukung oleh SEMUA delegate di
  /// atas. Dipakai supaya kita tidak pernah mengoper locale yang tidak
  /// ada terjemahan bawaan Flutter-nya (mis. Khmer "km" belum tentu
  /// didukung Material/Cupertino di semua versi Flutter).
  static bool _fullySupported(Locale locale) {
    for (final delegate in _kDelegates) {
      if (!delegate.isSupported(locale)) return false;
    }
    return true;
  }

  /// Tentukan locale AMAN untuk dioper ke `MaterialApp.locale` (yang
  /// dipakai widget bawaan Flutter). Urutan pengecekan:
  ///   1. Locale lengkap (bahasa + region) hasil pilihan pengguna.
  ///   2. Locale bahasa saja (tanpa region) — kadang variant regional
  ///      tidak terdaftar tapi bahasa dasarnya didukung.
  ///   3. Fallback ke English ("en") — SELALU didukung Flutter, jadi
  ///      tidak akan pernah error apa pun bahasa yang dipilih user.
  ///
  /// PENTING: ini HANYA memengaruhi teks bawaan Flutter (mis. tombol
  /// default DatePicker). Teks MILIK APLIKASI ini sendiri tetap penuh
  /// mengikuti bahasa pilihan user lewat `context.tr()`
  /// (core/localization/l10n.dart), yang membaca `LanguageProvider`
  /// langsung — TIDAK bergantung pada `MaterialApp.locale` sama
  /// sekali. Jadi walau widget bawaan Flutter fallback ke Inggris utk
  /// bahasa yang belum didukung Flutter, teks aplikasi (judul, label,
  /// tombol) tetap dalam bahasa yang dipilih user.
  static Locale _safeMaterialLocale(Locale wanted) {
    if (_fullySupported(wanted)) return wanted;

    final languageOnly = Locale(wanted.languageCode);
    if (_fullySupported(languageOnly)) return languageOnly;

    return const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode    = context.watch<ThemeProvider>().mode;
    final langProvider = context.watch<LanguageProvider>();

    // Locale "asli" pilihan pengguna (dipakai utk Directionality &
    // sebagai acuan bahasa aplikasi lewat LanguageProvider/context.tr).
    final wantedLocale = langProvider.locale;
    // Locale "aman" khusus utk widget bawaan Flutter — tidak pernah
    // memicu error delegate-not-found.
    final materialLocale = _safeMaterialLocale(wantedLocale);

    return MaterialApp(
      title: 'GlowMate',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,

      // ── Bahasa aplikasi ─────────────────────────────────
      // `locale` di sini HANYA menentukan bahasa widget BAWAAN
      // Flutter (DatePicker, dsb) — sudah dijamin selalu locale yang
      // benar-benar didukung (lihat `_safeMaterialLocale`), jadi tidak
      // akan pernah memicu error lagi walau user pilih bahasa yang
      // belum ada terjemahan bawaan Flutter-nya (mis. Khmer).
      //
      // Teks MILIK APLIKASI (judul, label, tombol, pesan) tetap 100%
      // mengikuti bahasa pilihan user via `context.tr()`, independen
      // dari nilai `locale` ini.
      locale: materialLocale,
      localizationsDelegates: _kDelegates,
      supportedLocales: kSupportedLanguages.map(
            (l) => l.code.contains('-')
            ? Locale(l.code.split('-')[0], l.code.split('-')[1])
            : Locale(l.code),
      ),

      // Arahkan penulisan kanan-ke-kiri otomatis utk bahasa spt Arab,
      // supaya seluruh halaman ikut menyesuaikan tanpa perlu diubah
      // satu per satu. Dihitung dari bahasa APLIKASI (wantedLocale via
      // LanguageProvider.isRtl), BUKAN dari materialLocale — supaya
      // arah teks tetap benar walau widget bawaan Flutter fallback ke
      // locale lain.
      builder: (context, child) {
        return Directionality(
          textDirection: langProvider.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },

      onGenerateRoute: AppRouter.generateRoute,
      home: AppRouter.initialWidget,
    );
  }
}