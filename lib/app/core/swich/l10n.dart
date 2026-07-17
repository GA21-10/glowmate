// ─────────────────────────────────────────────
// app/core/swich/l10n.dart
// ─────────────────────────────────────────────
//
// Ekstensi kecil supaya widget bisa panggil `context.tr('key')` dan
// otomatis dapat teks sesuai bahasa aktif (LanguageProvider). Widget
// yang memakai `context.tr(...)` otomatis rebuild saat bahasa
// diganti (KETENTUAN #2), karena `tr()` men-`watch` LanguageProvider.
//
// PENTING: hanya untuk teks/label MILIK APLIKASI. Jangan pernah
// dipakai untuk menampilkan data pengguna (nama, email, alamat,
// UID, No. WhatsApp, dsb) — data itu harus tampil apa adanya, tidak
// melalui `tr()`, supaya tidak ikut "diterjemahkan"/berubah.
//
// ── KETENTUAN #4 — RTL TANPA MEMBALIK UI ──────────────────────────
// Untuk bahasa yang ditulis kanan-ke-kiri (Arab), APLIKASI TIDAK
// dibungkus `Directionality(textDirection: TextDirection.rtl)` secara
// global — itu akan membalik SELURUH UI (nav bar pindah ke kanan,
// ikon-ikon mirror, alignment kebalik, dsb). MaterialApp aplikasi ini
// harus TETAP `TextDirection.ltr` untuk semua bahasa.
//
// Yang berubah HANYA arah baca huruf & angka di dalam teks itu
// sendiri, di posisi yang sama seperti bahasa lain. Untuk itu, pakai
// `AppText` (atau `context.trText(...)`) di bawah, BUKAN `Text(context.tr(...))`
// biasa, untuk teks yang perlu ikut kaidah RTL (judul, label, isi
// terjemahan). Widget ini men-set `textDirection` per-teks sesuai
// bahasa aktif, tapi alignment blok tetap dikunci `TextAlign.left`
// (bukan `TextAlign.start`, yang ikut berubah sisi kalau
// `textDirection` RTL) — jadi posisi teks di layout TIDAK bergeser
// ke kanan.
// ─────────────────────────────────────────────

import 'package:flutter/widgets.dart';
import 'package:glowmate/app/core/swich/trans.dart';
import 'package:provider/provider.dart';

import '../providers/settings/language.dart';

extension L10nX on BuildContext {
  /// Terjemahkan [key] sesuai bahasa aktif aplikasi.
  /// [params] dipakai untuk interpolasi placeholder `{nama}` di dalam
  /// string terjemahan, mis. `tr('toggle_enabled_with_label', params: {'label': 'Face ID'})`.
  String tr(String key, {Map<String, String>? params}) {
    final code = watch<LanguageProvider>().languageCode;
    return AppTranslations.t(code, key, params: params);
  }

  /// Versi yang tidak men-`watch` (tidak memicu rebuild) — dipakai di
  /// callback / method biasa (bukan di dalam `build()`), mis. di
  /// dalam `showModalBottomSheet` builder atau `onPressed`.
  String trRead(String key, {Map<String, String>? params}) {
    final code = read<LanguageProvider>().languageCode;
    return AppTranslations.t(code, key, params: params);
  }

  /// Versi `tr()` yang langsung mengembalikan widget `AppText` —
  /// dipakai untuk teks yang perlu otomatis mengikuti arah baca RTL
  /// tanpa menggeser posisi UI (lihat KETENTUAN #4 di atas). Rebuild
  /// otomatis saat bahasa berganti.
  ///
  /// Contoh: `context.trText('settings_title', style: titleStyle)`
  Widget trText(
      String key, {
        Map<String, String>? params,
        TextStyle? style,
        TextAlign? textAlign,
        int? maxLines,
        TextOverflow? overflow,
        bool softWrap = true,
      }) {
    return AppText(
      tr(key, params: params),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}

/// Widget teks yang menyesuaikan ARAH BACA huruf/angka (LTR/RTL)
/// sesuai bahasa aktif — TANPA memindahkan posisi/alignment blok di
/// layout (lihat KETENTUAN #4 di komentar atas file ini).
///
/// Beda dengan `Text` biasa: `textDirection` di sini SELALU di-set
/// eksplisit dari `LanguageProvider.isRtl` (bukan ambient
/// `Directionality` dari `MaterialApp`), dan `textAlign` default
/// dikunci ke `TextAlign.left` (bukan `TextAlign.start`) supaya blok
/// teks tidak ikut lompat ke kanan ketika bahasa aktif RTL — hanya
/// urutan karakter di dalam teks itu yang mengikuti kaidah RTL.
///
/// Pakai widget ini (atau `context.trText(...)`) untuk semua teks
/// hasil `context.tr(...)`. Untuk data pengguna (nama, email, dsb —
/// yang memang tidak boleh melalui `tr()`), `Text` biasa tetap boleh
/// dipakai apa adanya.
class AppText extends StatelessWidget {
  const AppText(
      this.data, {
        super.key,
        this.style,
        this.textAlign,
        this.maxLines,
        this.overflow,
        this.softWrap = true,
      });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final isRtl = context.watch<LanguageProvider>().isRtl;
    return Text(
      data,
      style: style,
      // Arah baca teks (huruf & angka) mengikuti bahasa aktif...
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      // ...tapi posisi/alignment blok TETAP dikunci ke kiri, tidak
      // ikut berpindah ke kanan seperti `TextAlign.start` akan
      // lakukan saat `textDirection` = rtl. Kalau pemanggil secara
      // eksplisit minta alignment lain (mis. `TextAlign.center` untuk
      // judul di tengah), itu dihormati apa adanya.
      textAlign: textAlign ?? TextAlign.left,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}