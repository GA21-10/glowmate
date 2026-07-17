// ─────────────────────────────────────────────
// core/theme/app_theme.dart
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';

/// Warna brand utama GlowMate
const Color _kPrimary   = Color(0xFF7C4DFF);
const Color _kSecondary = Color(0xFFE040FB);
const Color _kSurface   = Color(0xFFF6F0FF);

class AppTheme {
  AppTheme._();

  // ── LIGHT ──────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _kPrimary,
      secondary: _kSecondary,
      surface: _kSurface,
      brightness: Brightness.light,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: const Color(0xFFF8F4FF),
    cardTheme: CardThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black87,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
  );

  // ── DARK ───────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _kPrimary,
      secondary: _kSecondary,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: const Color(0xFF0F0A1E),
    cardTheme: CardThemeData(
      elevation: 4,
      color: const Color(0xFF1C1533),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1C1533),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E2050)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
  );
}