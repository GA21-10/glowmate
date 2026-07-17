// ─────────────────────────────────────────────
// app/theme/app_theme.dart
// ─────────────────────────────────────────────
//
// Tema aplikasi terpusat.
// • Default: MODE TERANG dengan warna dasar PUTIH.
// • Tersedia juga MODE GELAP dengan palet yang senada.
// • Pasang di MaterialApp:
//     theme:      AppTheme.light,
//     darkTheme:  AppTheme.dark,
//     themeMode:  ThemeMode.system, // atau ThemeMode.light sebagai default
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// Warna aksen utama brand (dipakai untuk kedua mode, disesuaikan
  /// kecerahannya oleh ColorScheme.fromSeed).
  static const Color _seed = Color(0xFF2F7D6B); // hijau teal — nuansa skincare

  // ── LIGHT (default) ─────────────────────────
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F8F7),
      surfaceContainer: const Color(0xFFF1F3F1),
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: _appBarTheme(scheme, elevation: 0),
    );
  }

  // ── DARK ─────────────────────────────────────
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );

    return _base(scheme).copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: _appBarTheme(scheme, elevation: 0),
    );
  }

  // ── Shared base ──────────────────────────────
  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withOpacity(0.35)),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.3),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainer,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android)
          .black
          .apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  static AppBarTheme _appBarTheme(ColorScheme scheme, {required double elevation}) {
    return AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: elevation,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}