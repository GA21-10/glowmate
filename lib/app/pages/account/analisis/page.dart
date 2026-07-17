// ─────────────────────────────────────────────
// app/pages/report/report_analisis_page.dart
// ─────────────────────────────────────────────
// Halaman Analisis Laporan.
//
// Alur:
// 1. Tombol pilih tanggal di paling atas.
// 2. Setelah tanggal dipilih, di bawahnya muncul riwayat analisis untuk
//    tanggal itu -- persis seperti kartu riwayat di AnalysisPage,
//    lengkap dengan rekonstruksi 3D wajah (Face3DViewer) & datanya
//    (status, tanggal, jumlah wajah, skor kulit, kondisi kulit, tipe
//    kulit, kemajuan dibanding record sebelumnya).
// 3. Di bawahnya lagi, rekomendasi kandungan & produk berdasarkan Tipe
//    Kulit yang terdeteksi (RecommendationRepository, sinkron otomatis
//    dengan AnalysisRepository). Klik salah satu chip Tipe Kulit untuk
//    hanya menampilkan data tipe itu; sebelum diklik apa pun (default),
//    SEMUA tipe kulit yang terdeteksi ditampilkan sekaligus.
// ─────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analysis/model/data.dart';
import '../../analysis/model/model.dart';
import '../../analysis/repository/analisis.dart';
import '../../analysis/skin/model/health.dart';
import '../../camera/enggine/painter.dart';
import '../../camera/model/mesh.dart';
import '../../report/model/req.dart';
import '../../report/provider/req.dart';

class ReportAnalisisPage extends StatefulWidget {
  const ReportAnalisisPage({super.key});

  @override
  State<ReportAnalisisPage> createState() => _ReportAnalisisPageState();
}

class _ReportAnalisisPageState extends State<ReportAnalisisPage> {
  DateTime? _selectedDate;

  /// Kunci kanonik ProblemGroup yang sedang difilter (mis. 'jerawat').
  /// Null = tampilkan SEMUA tipe kulit/masalah sekaligus (default).
  String? _selectedProblemKey;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Pilih Tanggal Analisis',
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _selectedProblemKey = null; // reset filter tiap ganti tanggal
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final analysisRepo = context.watch<AnalysisRepository>();
    final recRepo = context.watch<RecommendationRepository>();

    final allRecords = analysisRepo.records; // terbaru -> terlama
    final selectedDate = _selectedDate;
    final recordsForDate = selectedDate == null
        ? const <AnalysisRecord>[]
        : allRecords.where((r) => _isSameDay(r.capturedAt, selectedDate)).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Analisis')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ===== 1. Tombol pilih tanggal =====
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              sliver: SliverToBoxAdapter(
                child: _DatePickerButton(
                  selectedDate: selectedDate,
                  onTap: _pickDate,
                ),
              ),
            ),

            if (selectedDate == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyPickDateState(cs: cs),
              )
            else ...[
              // ===== 2. Riwayat analisis untuk tanggal terpilih =====
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle('Riwayat Analisis'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    formatTanggalIndo(selectedDate),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                ),
              ),
              if (recordsForDate.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Tidak ada riwayat deteksi pada tanggal ini.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  sliver: SliverList.separated(
                    itemCount: recordsForDate.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = recordsForDate[index];
                      // Ambil pembanding "record sebelumnya" dari daftar
                      // LENGKAP (bukan cuma yang tanggal ini) supaya chip
                      // Kemajuan/Perlu Perhatian tetap mengacu ke urutan
                      // kronologis yang benar.
                      final fullIndex = allRecords.indexOf(record);
                      final previous = (fullIndex != -1 &&
                          fullIndex + 1 < allRecords.length)
                          ? allRecords[fullIndex + 1]
                          : null;
                      return _AnalysisHistoryCard(
                        key: ValueKey(record.id),
                        record: record,
                        previous: previous,
                      );
                    },
                  ),
                ),

              // ===== 3. Rekomendasi kandungan berdasarkan Tipe Kulit =====
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: _SectionTitle('Rekomendasi Kandungan'),
                ),
              ),
              if (!recRepo.hasAnyProblem)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Belum ada tipe kulit/masalah kulit yang terdeteksi '
                          'untuk direkomendasikan.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ),
                )
              else ...[
                // Chip "Tipe Kulit" -- klik untuk filter satu per satu;
                // default (belum diklik apa pun / "Semua" aktif) ->
                // tampilkan SEMUA tipe kulit yang terdeteksi sekaligus.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SkinTypeFilterChip(
                          label: 'Semua',
                          selected: _selectedProblemKey == null,
                          onTap: () => setState(() => _selectedProblemKey = null),
                        ),
                        for (final group in recRepo.problemGroups)
                          _SkinTypeFilterChip(
                            label: group.label,
                            selected: _selectedProblemKey == group.key,
                            onTap: () =>
                                setState(() => _selectedProblemKey = group.key),
                          ),
                      ],
                    ),
                  ),
                ),
                for (final group in recRepo.problemGroups)
                  if (_selectedProblemKey == null ||
                      _selectedProblemKey == group.key)
                    ..._buildProblemGroupSlivers(cs, group),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProblemGroupSlivers(ColorScheme cs, ProblemGroup group) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
        sliver: SliverToBoxAdapter(
          child: _SectionTitle('Untuk ${group.label}'),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Terdeteksi dari: ${group.rawLabels.join(', ')}',
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Untuk mengatasi ${group.label.toLowerCase()}, gunakan kandungan '
                'berikut:',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
            group.ingredients.map((i) => _IngredientTile(ingredient: i)).toList(),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        sliver: SliverToBoxAdapter(
          child: Text(
            'Produk yang mengandung kandungan di atas:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.75),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: group.products.isEmpty
            ? SliverToBoxAdapter(
          child: Text(
            'Belum ada produk yang cocok untuk masalah ini.',
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface.withOpacity(0.55),
            ),
          ),
        )
            : SliverList.separated(
          itemCount: group.products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _ProductTile(rec: group.products[index]),
        ),
      ),
    ];
  }
}

/// ===== 1. Tombol pilih tanggal =====
class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({required this.selectedDate, required this.onTap});
  final DateTime? selectedDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDate = selectedDate != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate ? formatTanggalIndo(selectedDate!) : 'Pilih Tanggal',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: hasDate ? null : cs.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: cs.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPickDateState extends StatelessWidget {
  const _EmptyPickDateState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_note_rounded,
                  size: 44, color: cs.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Tanggal Dulu',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Ketuk tombol di atas untuk memilih tanggal, lalu riwayat '
                  'analisis & rekomendasi kandungan untuk tanggal itu akan '
                  'muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _SkinTypeFilterChip extends StatelessWidget {
  const _SkinTypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

/// ===== 2. Kartu riwayat analisis (3D view + data), untuk tanggal
/// terpilih. Selaras dengan `_RecordCard` di AnalysisPage: rekonstruksi
/// 3D wajah lewat `Face3DViewer` (mesh yang sama persis dibekukan saat
/// capture), switch privasi, status, tanggal, jumlah wajah, skor kulit,
/// kondisi kulit, dan tipe kulit yang bisa diklik satu per satu.
class _AnalysisHistoryCard extends StatefulWidget {
  const _AnalysisHistoryCard({super.key, required this.record, this.previous});
  final AnalysisRecord record;
  final AnalysisRecord? previous;

  @override
  State<_AnalysisHistoryCard> createState() => _AnalysisHistoryCardState();
}

class _AnalysisHistoryCardState extends State<_AnalysisHistoryCard> {
  static const _panelWidth = 220.0;
  static const _panelHeight = 140.0;

  double _revealAmount = 0.0;
  int _selectedTypeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final record = widget.record;
    final hasPhoto = !kIsWeb && record.imagePath != null;
    final mesh = record.toFaceMeshSnapshot();
    final has3D = mesh != null;
    final hasContent = has3D || hasPhoto;

    final safeTypeIndex = record.knownSkinTypes.isEmpty
        ? 0
        : _selectedTypeIndex.clamp(0, record.knownSkinTypes.length - 1);

    final progress = SkinHealthAnalyzer.progressBetween(widget.previous, record);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Center(
              child: _buildPanel(cs, record, has3D, hasPhoto, hasContent, mesh),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadgeRA(status: record.status),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (record.status == AnalysisStatus.completed &&
                    record.skinScore != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Skor kulit: ${record.skinScore!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
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
          if (record.knownSkinConditionLabel != null ||
              record.knownLatestFindingLabel != null ||
              progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (progress != null) _ProgressChipRA(trend: progress),
                  if (record.knownSkinConditionLabel != null)
                    _InfoChipRA(Icons.spa_rounded, record.knownSkinConditionLabel!),
                  if (record.knownLatestFindingLabel != null &&
                      record.knownLatestFindingLabel != kLatestFindingPlaceholder)
                    _InfoChipRA(
                      Icons.auto_awesome_rounded,
                      record.knownLatestFindingLabel!,
                    ),
                ],
              ),
            ),
          if (record.knownSkinTypes.isNotEmpty)
            _buildSelectableSkinTypes(cs, record, safeTypeIndex)
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPanel(
      ColorScheme cs,
      AnalysisRecord record,
      bool has3D,
      bool hasPhoto,
      bool hasContent,
      FaceMeshSnapshot? mesh,
      ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRevealPanel(cs, record, has3D, hasPhoto, mesh),
        const SizedBox(width: 2),
        SizedBox(
          width: 30,
          height: _panelHeight,
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
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
              Icon(Icons.spa_rounded, size: 14, color: cs.onSurface.withOpacity(0.2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevealPanel(
      ColorScheme cs,
      AnalysisRecord record,
      bool has3D,
      bool hasPhoto,
      FaceMeshSnapshot? mesh,
      ) {
    final hasSomethingToReveal = has3D || hasPhoto;

    return Container(
      width: _panelWidth,
      height: _panelHeight,
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
          width: _panelWidth,
          height: _panelHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Face3DViewer(
                mesh: mesh,
                size: const Size(_panelWidth, _panelHeight),
                showSkin: true,
              ),
              if (!has3D && hasPhoto)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(record.imagePath!),
                      fit: BoxFit.contain,
                      width: _panelWidth * 0.72,
                      height: _panelHeight * 0.72,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (hasSomethingToReveal)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: (1 - _revealAmount).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 120),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.94)),
                      child: const Center(
                        child: Icon(Icons.lock_rounded, size: 20, color: Colors.white38),
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

  Widget _buildSelectableSkinTypes(
      ColorScheme cs,
      AnalysisRecord record,
      int safeTypeIndex,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected ? cs.primary : cs.outline.withOpacity(0.15),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.face_retouching_natural_rounded, size: 16, color: cs.primary),
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

class _StatusBadgeRA extends StatelessWidget {
  const _StatusBadgeRA({required this.status});
  final AnalysisStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      AnalysisStatus.captured => (Colors.blueAccent, 'Baru diambil'),
      AnalysisStatus.analyzing => (Colors.orangeAccent, 'Menganalisis'),
      AnalysisStatus.completed => (Colors.green, 'Selesai'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _InfoChipRA extends StatelessWidget {
  const _InfoChipRA(this.icon, this.label);
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

class _ProgressChipRA extends StatelessWidget {
  const _ProgressChipRA({required this.trend});
  final SkinTrend trend;

  @override
  Widget build(BuildContext context) {
    final improving = trend == SkinTrend.improving;
    final color = improving ? Colors.green : Colors.redAccent;
    final label = improving ? 'Kemajuan' : 'Perlu Perhatian';
    final icon = improving ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// ===== 3. Baris detail kandungan (nama + manfaat) =====
class _IngredientTile extends StatelessWidget {
  const _IngredientTile({required this.ingredient});
  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  ingredient.benefit,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu produk rekomendasi.
class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.rec});
  final ProductRecommendation rec;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final product = rec.product;
    final description = rec.matchedIngredients.map((i) => i.name).join(', ');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomRight: Radius.circular(16),
            ),
            child: Image.network(
              product.imageUrl,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 92,
                  height: 92,
                  color: cs.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: 92,
                height: 92,
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.image_not_supported_rounded,
                    color: cs.onSurface.withOpacity(0.3)),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 15, color: Colors.amber.shade600),
                      const SizedBox(width: 3),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mengandung: $description',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}