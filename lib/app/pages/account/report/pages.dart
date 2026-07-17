// lib/app/pages/report/pages.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../../analysis/model/data.dart';
import '../../analysis/model/model.dart';
import '../../analysis/repository/analisis.dart';
import '../../camera/enggine/painter.dart';
import '../../camera/model/mesh.dart';
import '../../report/model/data.dart';

// SAMAKAN VISUAL DENGAN AnalysisPage: box "3D CONSTRUCTION" (grid tipis +
// border/glow cyan) yang sama persis dipakai `_RecordCard` di
// pages/analysis/pages.dart, dipakai ulang di sini supaya kartu riwayat di
// Laporan identik dengan kartu riwayat di Analisis -- bukan lagi field
// hitam polos + foto seperti versi sebelumnya.

/// ReportPage menampilkan seluruh riwayat hasil analisis.
///
/// SINKRONISASI REALTIME dengan AnalysisPage & RecommendationPage: SEMUA
/// halaman ini nonton (langsung atau tidak langsung) instance
/// [AnalysisRepository] yang SAMA (didaftarkan sekali di root app lewat
/// ChangeNotifierProvider.value di main.dart). Begitu AnalysisPage (atau
/// alur kamera) menambah/mengubah record, `notifyListeners()` di
/// repository otomatis memicu rebuild halaman ini juga — tidak perlu
/// tarik-refresh, tidak perlu event bus terpisah, dan tidak akan pernah
/// "ketinggalan" data karena sumber datanya memang satu-satunya.
///
/// UPDATE (kartu riwayat disamakan dengan AnalysisPage):
/// Kartu di halaman ini SEKARANG memakai box yang PERSIS SAMA dengan
/// `_RecordCard` di AnalysisPage --  `Face3DViewer` (rekonstruksi 3D wajah,
/// bukan lagi foto datar di atas field hitam), ukuran box landscape tetap
/// 220x140 logical-pixel di semua platform, switch vertikal ikon
/// `spa_rounded` untuk reveal/privasi, dan gaya chip (`_InfoChip`,
/// `_StatusBadge`-style) yang sama. Ini penting supaya identitas visual
/// AnalysisPage <-> ReportPage konsisten -- user melihat riwayat yang
/// sama persis di kedua halaman, hanya beda kebutuhan informasi status.
///
/// STATUS LAPORAN (regulasi -- TIDAK dibaca dari `record.status` semata,
/// dihitung ULANG tiap build dari data yang SUNGGUH-SUNGGUH ada di
/// record, supaya selalu akurat & realtime) TETAP DIPERTAHANKAN karena
/// ini kebutuhan KHUSUS halaman Laporan (AnalysisPage tidak perlu tahu
/// soal status rekomendasi):
///
/// 1. "Menunggu analisis"  -> BELUM ADA data apa pun yang bisa
///    ditampilkan (Kondisi Kulit masih null -- sesuai gerbang utama
///    yang sama dipakai popup kamera & AnalysisPage: kalau Kondisi
///    Kulit belum diketahui, Tipe Kulit & Temuan Tipe Kulit Terbaru
///    ikut dianggap belum ada).
/// 2. "Sedang dianalisis"  -> SUDAH ada sebagian data (minimal Kondisi
///    Kulit), TAPI belum lengkap sampai Temuan Tipe Kulit Terbaru yang
///    SUNGGUHAN (bukan cuma placeholder "Sabar ya, fitur sedang
///    dikembangkan" -- lihat `kLatestFindingPlaceholder`).
/// 3. "Selesai"            -> Kondisi Kulit + Tipe Kulit + Temuan Tipe
///    Kulit Terbaru (asli) SUDAH LENGKAP semua, DAN Rekomendasi untuk
///    SETIAP masalah yang terdeteksi dari data itu SUDAH ADA (kandungan
///    + minimal satu produk yang cocok) -- dihitung langsung dari
///    logic yang sama dipakai RecommendationRepository
///    (`extractRawSkinProblems` + `matchProblemKeys` +
///    `problemToIngredientIds` + `productCatalog` dari
///    recommendation/model/data.dart), jadi kalau nanti kandungan/produk
///    untuk suatu masalah belum tersedia di katalog, status record itu
///    TIDAK akan pernah "Selesai" walau datanya sendiri sudah lengkap.
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch -> rebuild otomatis tiap ada perubahan di repository
    // (dipicu dari Kamera saat capture baru, atau dari proses analisis
    // lanjutan yang mengisi Temuan Tipe Kulit Terbaru / skor kulit).
    final repo = context.watch<AnalysisRepository>();

    if (!repo.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final records = repo.records; // sudah terurut terbaru -> terlama

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          if (records.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua riwayat',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context, repo),
            ),
        ],
      ),
      body: records.isEmpty
          ? const _EmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final record = records[index];
          return _ReportCard(
            // key by id supaya State kartu (posisi slider & tipe kulit
            // terpilih) tidak tertukar antar record saat list berubah
            // (mis. ada record baru masuk paling atas).
            key: ValueKey(record.id),
            record: record,
            onDelete: () => repo.deleteRecord(record.id),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(
      BuildContext context,
      AnalysisRepository repo,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Semua riwayat hasil analisis & foto tersimpan akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.clearAll();
    }
  }
}

// ============================================================
// REGULASI STATUS LAPORAN (poin #1-#3) -- dihitung dari data record,
// bukan dari `record.status` (field itu masih dipertahankan di model
// untuk kompatibilitas & dipakai `updateAnalysisResult`, tapi UI
// laporan sekarang menilai kelengkapan data secara langsung supaya
// selalu sinkron realtime dengan Kamera -> Analisis -> Rekomendasi).
// ============================================================

enum _ReportStage { waiting, analyzing, completed }

class _ReportStageInfo {
  const _ReportStageInfo(this.stage, this.detectedProblemCount);
  final _ReportStage stage;

  /// Jumlah masalah kulit MENTAH yang berhasil diekstrak dari record ini
  /// (Tipe Kulit + Temuan Tipe Kulit Terbaru), dipakai untuk keterangan
  /// tambahan di kartu saat status "Selesai".
  final int detectedProblemCount;
}

_ReportStageInfo _computeReportStage(AnalysisRecord record) {
  // Poin #1: Kondisi Kulit adalah gerbang utama (SAMA PERSIS dengan
  // popup.dart & AnalysisRepository.addFromCapture) -- kalau ini belum
  // diketahui, tidak ada data apa pun yang bisa ditampilkan sama
  // sekali, jadi otomatis "Menunggu analisis".
  final hasCondition = record.knownSkinConditionLabel != null;
  if (!hasCondition) {
    return const _ReportStageInfo(_ReportStage.waiting, 0);
  }

  final hasType = record.knownSkinTypes.isNotEmpty;

  final hasRealFinding = record.knownLatestFindingLabel != null &&
      record.knownLatestFindingLabel!.trim().isNotEmpty &&
      record.knownLatestFindingLabel != kLatestFindingPlaceholder;

  // Poin #2: sudah ada data (Kondisi Kulit, mungkin juga Tipe Kulit),
  // tapi belum lengkap sampai Temuan Tipe Kulit Terbaru yang SUNGGUHAN.
  if (!hasType || !hasRealFinding) {
    return const _ReportStageInfo(_ReportStage.analyzing, 0);
  }

  // Data sudah lengkap (Kondisi Kulit + Tipe Kulit + Temuan Tipe Kulit
  // Terbaru asli). Poin #3: masih perlu pastikan REKOMENDASI sudah ada
  // untuk SETIAP masalah yang terdeteksi dari data ini -- pakai logic
  // yang SAMA PERSIS dengan RecommendationRepository supaya tidak
  // pernah ada dua sumber kebenaran yang berbeda.
  final rawProblems = extractRawSkinProblems(record);
  if (rawProblems.isEmpty) {
    // Datanya lengkap tapi tidak ada satu pun masalah yang bisa
    // dikenali -> rekomendasi mustahil ada -> belum bisa "Selesai".
    return const _ReportStageInfo(_ReportStage.analyzing, 0);
  }

  for (final raw in rawProblems) {
    final keys = matchProblemKeys(raw);
    if (keys.isEmpty) {
      // Ada masalah yang terdeteksi tapi belum dikenali sistem
      // rekomendasi -> belum lengkap.
      return _ReportStageInfo(_ReportStage.analyzing, rawProblems.length);
    }
    final hasProductForThisProblem = keys.any((key) {
      final neededIds = problemToIngredientIds[key] ?? const [];
      if (neededIds.isEmpty) return false;
      return productCatalog.any(
            (p) => p.ingredientIds.any((id) => neededIds.contains(id)),
      );
    });
    if (!hasProductForThisProblem) {
      // Masalah dikenali tapi belum ada kandungan/produk yang cocok di
      // katalog untuk masalah itu -> rekomendasi belum lengkap.
      return _ReportStageInfo(_ReportStage.analyzing, rawProblems.length);
    }
  }

  return _ReportStageInfo(_ReportStage.completed, rawProblems.length);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 72,
            color: cs.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat analisis',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hasil dari halaman Kamera akan muncul di sini secara otomatis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu record di halaman Laporan.
///
/// UPDATE (disamakan PERSIS dengan `_RecordCard` di AnalysisPage):
/// 1. BOX FOTO — bukan lagi field hitam polos + `Image.file`. Sekarang
///    memakai `Face3DViewer` yang SAMA PERSIS dipakai panel "3D
///    CONSTRUCTION" live di kamera & kartu riwayat AnalysisPage (grid
///    tipis + border/glow cyan). Kalau record punya data mesh 3D
///    (`record.toFaceMeshSnapshot()`), box menampilkan rekonstruksi
///    point-cloud wajah. Kalau tidak (record lama tanpa landmark),
///    fallback ke foto datar ditumpuk di tengah box -- box itu sendiri
///    (grid + border cyan) TETAP tampil, tidak pernah polos hitam.
///    Ukuran box tetap 220x140 logical-pixel (identik di semua
///    platform), sama seperti AnalysisPage.
/// 2. SWITCH VERTIKAL — ikon `spa_rounded` (bukan mata), perilaku sama:
///    geser ke ATAS = makin terlihat, ke BAWAH = kembali terkunci
///    (privasi default). Overlay gembok hanya muncul kalau memang ada
///    sesuatu (mesh atau foto) untuk disembunyikan.
/// 3. TIPE KULIT — chip-chip yang bisa diklik satu per satu, gaya
///    identik dengan AnalysisPage. Klik salah satu -> hanya tipe itu
///    yang ditampilkan di panel detail. Default -> entri paling kiri
///    (index 0).
/// 4. STATUS & DATA REKOMENDASI — TETAP KHUSUS milik ReportPage (3
///    tahap: Menunggu/Sedang dianalisis/Selesai + info jumlah masalah
///    yang sudah punya rekomendasi), karena ini kebutuhan halaman
///    Laporan yang tidak dimiliki AnalysisPage.
/// 5. SWIPE-TO-DELETE (`Dismissible`) TETAP DIPERTAHANKAN — ini fitur
///    khusus Laporan untuk menghapus satu riwayat.
///
/// Dibuat StatefulWidget karena posisi slider & tipe kulit terpilih
/// adalah state lokal per-kartu, bukan bagian dari data tersimpan.
class _ReportCard extends StatefulWidget {
  const _ReportCard({super.key, required this.record, required this.onDelete});

  final AnalysisRecord record;
  final VoidCallback onDelete;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  // SAMA PERSIS dengan `_RecordCard` di AnalysisPage: konstanta
  // logical-pixel, landscape 11:7, identik di semua platform.
  static const _photoWidth = 220.0;
  static const _photoHeight = 140.0;

  /// 0 = box terkunci (privasi default -- belum ada apa pun yang
  ///     terlihat, baik itu 3D construction maupun foto).
  /// 1 = rekonstruksi 3D wajah (atau foto, kalau data 3D tidak
  ///     tersedia) terlihat penuh.
  double _revealAmount = 0.0;

  /// Index chip Tipe Kulit yang sedang aktif. Default 0 = paling kiri.
  int _selectedTypeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final record = widget.record;
    final hasPhoto = !kIsWeb && record.imagePath != null;
    // Data 3D construction (SAMA PERSIS sumbernya dengan AnalysisPage)
    // yang dibekukan saat capture di halaman kamera.
    final mesh = record.toFaceMeshSnapshot();
    final stageInfo = _computeReportStage(record);

    final safeTypeIndex = record.knownSkinTypes.isEmpty
        ? 0
        : _selectedTypeIndex.clamp(0, record.knownSkinTypes.length - 1);

    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        widget.onDelete();
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== BOX 3D/FOTO (Face3DViewer + switch) — DI TENGAH =====
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Center(
                child: _buildPhotoWithRevealSwitch(cs, hasPhoto, mesh),
              ),
            ),
            // ===== TULISAN & DATA — DI SEBELAH KIRI =====
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status KHUSUS Laporan (3 tahap), bukan `_StatusBadge`
                  // 3-status milik AnalysisPage -- ini kebutuhan berbeda.
                  _StatusChip(record: record, stageInfo: stageInfo),
                  const SizedBox(height: 6),
                  Text(
                    formatTanggalSingkat(record.capturedAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.detectedHumanCount} wajah terdeteksi',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (record.captureAttempts > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Diambil ulang otomatis (${record.captureAttempts}x)',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurface.withOpacity(0.45),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Data realtime dari Analisis (Kondisi Kulit / Temuan Tipe
            // Kulit Terbaru asli) -- gaya `_InfoChip` sama dengan
            // AnalysisPage. Placeholder "fitur belum dikembangkan"
            // sengaja tidak pernah dirender di sini.
            if (record.knownSkinConditionLabel != null ||
                (record.knownLatestFindingLabel != null &&
                    record.knownLatestFindingLabel !=
                        kLatestFindingPlaceholder)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (record.knownSkinConditionLabel != null)
                      _InfoChip(
                        Icons.spa_rounded,
                        record.knownSkinConditionLabel!,
                      ),
                    if (record.knownLatestFindingLabel != null &&
                        record.knownLatestFindingLabel !=
                            kLatestFindingPlaceholder)
                      _InfoChip(
                        Icons.auto_awesome_rounded,
                        record.knownLatestFindingLabel!,
                      ),
                  ],
                ),
              ),
            ],
            if (record.knownSkinTypes.isNotEmpty)
              _buildSelectableSkinTypes(cs, record, safeTypeIndex)
            else
              const SizedBox(height: 12),
            // Data realtime dari Rekomendasi -- KHUSUS Laporan, hanya
            // tampil begitu status record ini benar-benar "Selesai"
            // (lihat poin #3 di regulasi status).
            if (stageInfo.stage == _ReportStage.completed)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stageInfo.detectedProblemCount > 1
                            ? 'Rekomendasi tersedia untuk ${stageInfo.detectedProblemCount} masalah kulit -- lihat halaman Rekomendasi.'
                            : 'Rekomendasi tersedia -- lihat halaman Rekomendasi.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// SAMA PERSIS dengan `_buildPhotoWithRevealSwitch` di AnalysisPage:
  /// box `Face3DViewer` di kiri + switch vertikal ikon `spa_rounded` di
  /// kanan. Geser ke ATAS -> makin terlihat, ke BAWAH -> kembali
  /// terkunci (privasi default).
  Widget _buildPhotoWithRevealSwitch(
      ColorScheme cs,
      bool hasPhoto,
      FaceMeshSnapshot? mesh,
      ) {
    final has3D = mesh != null;
    final hasContent = has3D || hasPhoto;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRevealPanel(cs, has3D, hasPhoto, mesh),
        const SizedBox(width: 2),
        SizedBox(
          width: 30,
          height: _photoHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.spa_rounded,
                size: 14,
                color: hasContent
                    ? cs.primary.withOpacity(0.7)
                    : cs.onSurface.withOpacity(0.2),
              ),
              Expanded(
                child: RotatedBox(
                  // quarterTurns: 3 -> ujung MAX slider di ATAS, ujung
                  // MIN di BAWAH -> "geser ke atas = makin terlihat".
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: _revealAmount,
                      onChanged: hasContent
                          ? (v) => setState(() => _revealAmount = v)
                          : null,
                    ),
                  ),
                ),
              ),
              Icon(
                Icons.spa_rounded,
                size: 14,
                color: cs.onSurface.withOpacity(0.2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// SAMA PERSIS dengan `_buildRevealPanel` di AnalysisPage: bingkai
  /// "3D CONSTRUCTION" (grid tipis + border/glow cyan) SELALU tampil.
  /// - Ada data mesh (`has3D`) -> rekonstruksi point-cloud + kontur
  ///   wajah, identik live-preview kamera.
  /// - Tidak ada mesh tapi ada foto (record lama) -> box tetap tampil,
  ///   foto ditumpuk di tengahnya.
  /// - Tidak ada keduanya -> box tampil kosong (hanya grid).
  /// Overlay "terkunci" hanya muncul kalau ADA sesuatu untuk
  /// disembunyikan.
  Widget _buildRevealPanel(
      ColorScheme cs,
      bool has3D,
      bool hasPhoto,
      FaceMeshSnapshot? mesh,
      ) {
    final record = widget.record;
    final hasSomethingToReveal = has3D || hasPhoto;

    return Container(
      width: _photoWidth,
      height: _photoHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF00D0FF).withOpacity(0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: _photoWidth,
          height: _photoHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bingkai SELALU tampil -- widget yang SAMA PERSIS dipakai
              // panel "3D CONSTRUCTION" live di kamera & kartu riwayat
              // AnalysisPage. Kalau `mesh` null, `Face3DViewer` otomatis
              // hanya menggambar grid latar -- box tetap elegan, tidak
              // pernah polos hitam.
              Face3DViewer(
                mesh: mesh,
                size: Size(_photoWidth, _photoHeight),
                showSkin: true,
              ),
              // FALLBACK foto (record lama tanpa data mesh): ditumpuk di
              // tengah bingkai, bukan menggantikannya.
              if (!has3D && hasPhoto)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(record.imagePath!),
                      fit: BoxFit.contain,
                      width: _photoWidth * 0.72,
                      height: _photoHeight * 0.72,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // ===== OVERLAY "TERKUNCI" (privasi default) =====
              // Hanya tampil kalau ada sesuatu untuk disembunyikan.
              // Memudar seiring _revealAmount naik.
              if (hasSomethingToReveal)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: (1 - _revealAmount).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 120),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.94),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tipe Kulit sebagai chip-chip yang bisa diklik satu per satu -- gaya
  /// IDENTIK dengan `_buildSelectableSkinTypes` di AnalysisPage. Klik ->
  /// hanya data tipe kulit itu yang ditampilkan di panel detail. Default
  /// -> entri paling kiri (index 0).
  Widget _buildSelectableSkinTypes(
      ColorScheme cs,
      AnalysisRecord record,
      int safeTypeIndex,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipe Kulit',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: cs.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(record.knownSkinTypes.length, (i) {
              final selected = i == safeTypeIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedTypeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : cs.outline.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    record.knownSkinTypes[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Panel detail -- HANYA menampilkan data tipe kulit yang
          // sedang dipilih (default paling kiri).
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 16,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.knownSkinTypes[safeTypeIndex],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip data (Kondisi Kulit / Temuan Tipe Kulit Terbaru) -- gaya IDENTIK
/// dengan `_InfoChip` milik AnalysisPage supaya identitas visual antar
/// halaman konsisten (sebelumnya bernama `_DataChip` dengan ukuran/skala
/// sedikit berbeda; sekarang disamakan).
class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status KHUSUS Laporan (3 tahap: Menunggu/Sedang dianalisis/Selesai) --
/// TETAP DIPERTAHANKAN karena ini kebutuhan berbeda dari `_StatusBadge`
/// (3-status: Baru diambil/Menganalisis/Selesai) milik AnalysisPage.
/// AnalysisPage tidak butuh tahu soal kelengkapan rekomendasi; Laporan
/// butuh.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.record, required this.stageInfo});
  final AnalysisRecord record;
  final _ReportStageInfo stageInfo;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    switch (stageInfo.stage) {
      case _ReportStage.waiting:
      // Poin #1: tidak ada data apa pun yang ditampilkan.
        label = 'Menunggu analisis';
        color = Colors.orangeAccent;
        break;
      case _ReportStage.analyzing:
      // Poin #2: sudah ada data, tapi belum lengkap sampai Temuan
      // Tipe Kulit Terbaru asli.
        label = 'Sedang dianalisis…';
        color = Colors.blueAccent;
        break;
      case _ReportStage.completed:
      // Poin #3: Kondisi Kulit + Tipe Kulit + Temuan Tipe Kulit
      // Terbaru + Rekomendasi semuanya sudah ada.
        label = record.skinScore != null
            ? 'Skor kulit: ${record.skinScore!.toStringAsFixed(0)}'
            : 'Selesai';
        color = Colors.greenAccent.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}