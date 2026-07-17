// ─────────────────────────────────────────────
// core/theme/app_theme.dart
// ─────────────────────────────────────────────
//
// Tema terpusat — mode Terang & Gelap yang elegan (Material 3).
// Pakai warna seed lembut (teal-emerald) yang cocok untuk aplikasi
// perawatan kulit/kecantikan (GlowMate), dengan kontras yang nyaman
// dibaca di kedua mode.
//
// Cara pakai (di MaterialApp):
//
//   MaterialApp(
//     theme: AppTheme.light,
//     darkTheme: AppTheme.dark,
//     themeMode: ThemeMode.system, // atau ikuti provider tema sendiri
//     ...
//   )
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Warna seed utama — teal keemasan yang elegan & lembut di mata.
  static const Color _seed = Color(0xFF0E8F7E);

  // ── LIGHT ──────────────────────────────────
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  // ── DARK ───────────────────────────────────
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
      fontFamily: 'Inter',

      // ── AppBar ────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ── Card ──────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        elevation: isDark ? 0 : 2,
        shadowColor: cs.shadow.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: cs.outline.withOpacity(isDark ? 0.18 : 0.08),
            width: 1,
          ),
        ),
      ),

      // ── Input ─────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? cs.surfaceContainerHighest.withOpacity(0.5)
            : cs.surfaceContainerHighest.withOpacity(0.55),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.2),
        ),
      ),

      // ── Buttons ───────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary.withOpacity(0.5)),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ── Bottom sheet (mis. pemilih negara / sumber foto) ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outline.withOpacity(0.15),
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? cs.inverseSurface : cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}