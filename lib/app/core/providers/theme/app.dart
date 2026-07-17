// ─────────────────────────────────────────────
// core/providers/settings/theme_provider.dart
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  bool get isDark  => _mode == ThemeMode.dark;
  bool get isLight => _mode == ThemeMode.light;

  Future<void> load() async {
    final p   = await SharedPreferences.getInstance();
    final val = p.getString(_key);
    _mode = _fromString(val);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, _toString(mode));
    notifyListeners();
  }

  Future<void> toggle() async =>
      setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  static String _toString(ThemeMode m) => switch (m) {
    ThemeMode.light  => 'light',
    ThemeMode.dark   => 'dark',
    ThemeMode.system => 'system',
    _ => 'system',
  };

  static ThemeMode _fromString(String? s) => switch (s) {
    'light'  => ThemeMode.light,
    'dark'   => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.system,
  };
}