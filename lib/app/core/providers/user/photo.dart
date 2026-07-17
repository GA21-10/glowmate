// ─────────────────────────────────────────────
// core/providers/profile/profile_image_provider.dart
// ─────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan & menyebarkan path foto profil ke seluruh widget tree.
/// Digunakan oleh AccountPage (untuk mengubah foto) dan
/// header/footer di HomePage (untuk menampilkan foto secara reaktif).
class ProfileImageProvider extends ChangeNotifier {
  static const _key = 'profile_image_path';

  String? _imagePath;

  /// Path lokal foto profil. Null jika belum dipilih.
  String? get imagePath => _imagePath;

  /// ImageProvider siap pakai. Null jika tidak ada foto.
  ImageProvider? get imageProvider {
    if (_imagePath == null || _imagePath!.isEmpty) return null;
    if (kIsWeb) return null; // Web tidak mendukung File path
    final file = File(_imagePath!);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _imagePath = p.getString(_key);
    notifyListeners();
  }

  Future<void> setImagePath(String? path) async {
    _imagePath = path;
    final p = await SharedPreferences.getInstance();
    if (path != null) {
      await p.setString(_key, path);
    } else {
      await p.remove(_key);
    }
    notifyListeners();
  }

  void clearImage() => setImagePath(null);
}