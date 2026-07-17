// ─────────────────────────────────────────────
// app/widgets/avatar/user_avatar.dart
// ─────────────────────────────────────────────
//
// Widget avatar terpusat supaya semua halaman (Account, Profile Setup, dll)
// menampilkan foto profil dengan cara yang SAMA dan AMAN, apapun sumbernya:
//
//  1. Path file lokal   (disimpan di penyimpanan internal — Android/iOS/Desktop)
//  2. Data URI base64   (disimpan di SharedPreferences — khusus Web, karena
//                         Web tidak punya akses filesystem)
//  3. URL jaringan       (mis. foto Google bawaan sebelum user ganti foto
//                         sendiri) — dengan fallback otomatis ke avatar
//                         default kalau gagal dimuat (memperbaiki
//                         NetworkImageLoadException / error 429).
//
// PEMBARUAN — perbaikan bug "foto kadang tidak muncul di Web & Desktop":
//   • Sebelumnya memakai `CircleAvatar.backgroundImage` +
//     `onBackgroundImageError`, yang di beberapa kondisi (mis. saat
//     rebuild terjadi sebelum image selesai decode, atau saat CORS/redirect
//     lambat khusus di Web & Desktop) membuat gambar tidak pernah
//     ter-render walau URL sebenarnya valid.
//   • Sekarang untuk sumber URL jaringan dipakai `Image.network` langsung
//     di dalam `ClipOval`, dengan `loadingBuilder` (indikator saat memuat)
//     dan `errorBuilder` (fallback otomatis ke ikon default kalau gagal).
//     Ini jauh lebih andal di semua platform (Android, iOS, Web, Desktop).
//   • Prioritas sumber foto SELALU konsisten di 4 platform:
//       - Tidak ada foto sama sekali (kosong / null)      → avatar ikon default
//       - Ada foto tersimpan (dari Google/gmail ATAUPUN
//         hasil upload pengguna)                           → tampilkan foto itu
//       - Pengguna mengganti foto                          → foto TERBARU yang
//                                                             tampil & tersimpan
//     Widget ini murni "penampil" — keputusan foto mana yang aktif
//     (foto baru dipilih vs foto lama vs dihapus) ditentukan oleh
//     caller (lihat `profile_setup_page.dart`) sebelum di-passing ke sini,
//     supaya perilaku identik di Android, iOS, Web, dan Desktop.
// ─────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.photo,
    this.radius = 36,
    this.iconSize,
  });

  /// Bisa berupa: path file lokal, data URI base64 ("data:image/..;base64,.."),
  /// atau URL jaringan biasa. Boleh null / kosong.
  final String? photo;
  final double radius;
  final double? iconSize;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

enum _PhotoSourceKind { none, base64, localFile, network }

class _UserAvatarState extends State<UserAvatar> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photo = widget.photo;
    final kind = _classify(photo);

    return ClipOval(
      child: Container(
        width: widget.radius * 2,
        height: widget.radius * 2,
        color: cs.primary.withOpacity(0.15),
        alignment: Alignment.center,
        child: _buildContent(context, cs, kind, photo),
      ),
    );
  }

  _PhotoSourceKind _classify(String? photo) {
    if (photo == null || photo.trim().isEmpty) return _PhotoSourceKind.none;
    if (photo.startsWith('data:image')) return _PhotoSourceKind.base64;
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return _PhotoSourceKind.network;
    }
    // Selain itu dianggap path file lokal (Android/iOS/Desktop).
    return kIsWeb ? _PhotoSourceKind.none : _PhotoSourceKind.localFile;
  }

  Widget _defaultIcon(ColorScheme cs) => Icon(
    Icons.person,
    size: widget.iconSize ?? widget.radius,
    color: cs.primary,
  );

  Widget _buildContent(
      BuildContext context,
      ColorScheme cs,
      _PhotoSourceKind kind,
      String? photo,
      ) {
    switch (kind) {
      case _PhotoSourceKind.none:
        return _defaultIcon(cs);

      case _PhotoSourceKind.base64:
        try {
          final base64Str = photo!.substring(photo.indexOf(',') + 1);
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _defaultIcon(cs),
          );
        } catch (_) {
          return _defaultIcon(cs);
        }

      case _PhotoSourceKind.localFile:
        final file = File(photo!);
        if (!file.existsSync()) return _defaultIcon(cs);
        return Image.file(
          file,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _defaultIcon(cs),
        );

      case _PhotoSourceKind.network:
      // Image.network andal di Android, iOS, Web, dan Desktop —
      // termasuk saat gambar butuh waktu load (loadingBuilder) atau
      // gagal dimuat (errorBuilder → fallback otomatis, tidak pernah
      // membuat exception yang tidak tertangani).
        return Image.network(
          photo!,
          key: ValueKey(photo),
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: widget.radius * 0.7,
                height: widget.radius * 0.7,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary.withOpacity(0.6),
                  value: progress.expectedTotalBytes != null
                      ? (progress.cumulativeBytesLoaded /
                      (progress.expectedTotalBytes ?? 1))
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _defaultIcon(cs),
        );
    }
  }
}