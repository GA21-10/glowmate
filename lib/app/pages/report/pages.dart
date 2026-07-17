// lib/app/pages/recommendation/pages.dart
import 'package:flutter/material.dart';
import 'package:glowmate/app/pages/report/provider/req.dart';
import 'package:provider/provider.dart';

import '../analysis/repository/analisis.dart';
import 'model/req.dart';

/// Halaman rekomendasi kandungan & produk berdasarkan masalah kulit
/// yang terdeteksi di halaman Analysis.
///
/// TAMPILAN PER MASALAH KULIT: setiap masalah yang terdeteksi (mis.
/// "Jerawat", "Berminyak") punya bagiannya sendiri, lengkap dengan
/// kandungan yang disarankan KHUSUS untuk masalah itu dan produk yang
/// memang mengandung kandungan tsb -- bukan digabung rata jadi satu
/// daftar kandungan/produk besar.
///
/// SINKRONISASI REALTIME: sama seperti AnalysisPage & ReportPage,
/// halaman ini murni reaktif lewat `context.watch<RecommendationRepository>()`.
/// `RecommendationRepository` sendiri dihitung ulang otomatis setiap kali
/// `AnalysisRepository` berubah (lihat ChangeNotifierProxyProvider di
/// main.dart, contoh ada di komentar repository/rekomendasi.dart) --
/// jadi begitu ada capture baru dengan masalah kulit baru, bagian baru
/// otomatis muncul tanpa perlu buka-tutup halaman.
class RecommendationPage extends StatelessWidget {
  const RecommendationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final repo = context.watch<RecommendationRepository>();

    // Kondisi Kulit (poin #1): murni keterangan informatif, diambil dari
    // record TERBARU di AnalysisRepository. TIDAK dipakai untuk mencari
    // kandungan/produk -- itu sekarang berbasis Tipe Kulit & Temuan Tipe
    // Kulit Terbaru (lihat extractRawSkinProblems di model/data.dart).
    final analysisRepo = context.watch<AnalysisRepository>();
    final knownConditionLabel = analysisRepo.latest?.knownSkinConditionLabel;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Rekomendasi untuk Kulitmu')),
      body: SafeArea(
        child: Column(
          children: [
            // Poin #1: keterangan Kondisi Kulit -- murni informatif,
            // selalu tampil di atas terlepas dari ada/tidaknya masalah
            // kulit yang terdeteksi di bawah.
            _KnownConditionCard(label: knownConditionLabel),
            Expanded(
              child: !repo.hasAnyProblem
                  ? _EmptyState(cs: cs)
                  : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: _SectionTitle('Masalah Kulit Terdeteksi'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        // Poin #2: sumber masalah di sini adalah
                        // Tipe Kulit & Temuan Tipe Kulit Terbaru
                        // (lihat extractRawSkinProblems di
                        // model/data.dart) -- BUKAN Kondisi Kulit,
                        // yang sekarang murni keterangan di kartu
                        // atas.
                        'Berdasarkan Tipe Kulit & Temuan Tipe Kulit '
                            'Terbaru kamu, setiap masalah di bawah ini '
                            'punya rekomendasi kandungan & produknya '
                            'masing-masing:',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    sliver: SliverToBoxAdapter(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: repo.detectedProblems
                            .map((p) => _ProblemChip(label: p))
                            .toList(),
                      ),
                    ),
                  ),
                  // Satu blok per masalah kulit (poin #2 & #3):
                  // judul masalah, penjelasan kandungan yang
                  // disarankan KHUSUS untuknya secara detail
                  // (nama + manfaat, bukan cuma chip nama), lalu
                  // produk yang memang mengandung kandungan itu
                  // (poin #4). Produk hanya muncul kalau
                  // kandungannya sudah ada di daftar kandungan
                  // blok ini.
                  for (final group in repo.problemGroups) ...[
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
                          'Untuk mengatasi ${group.label.toLowerCase()}, '
                              'gunakan kandungan berikut:',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: group.ingredients
                              .map((i) =>
                              _IngredientDetailTile(ingredient: i))
                              .toList(),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          // Poin #4: produk di bawah ini ditentukan
                          // dari kandungan yang baru saja
                          // dijelaskan di atas.
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
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _ProductCard(
                            rec: group.products[index],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu keterangan Kondisi Kulit (poin #1) -- MURNI informatif, diambil
/// dari `AnalysisRecord.knownSkinConditionLabel` record terbaru. TIDAK
/// dipakai untuk mencari kandungan/produk (itu berbasis Tipe Kulit &
/// Temuan Tipe Kulit Terbaru, lihat `extractRawSkinProblems`), jadi
/// tetap ditampilkan apa adanya walau belum ada satupun masalah kulit
/// yang bisa direkomendasikan kandungannya.
class _KnownConditionCard extends StatelessWidget {
  const _KnownConditionCard({required this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLabel = label != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.spa_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kondisi Kulit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasLabel
                      ? label!
                      : 'Belum diketahui -- lakukan deteksi di halaman '
                      'Analysis terlebih dahulu.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: hasLabel ? FontWeight.w700 : FontWeight.w500,
                    fontStyle: hasLabel ? FontStyle.normal : FontStyle.italic,
                    color: hasLabel ? null : cs.onSurface.withOpacity(0.6),
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

/// Ditampilkan saat BELUM ADA satupun masalah kulit terdeteksi (mis.
/// user belum pernah capture, atau capture yang ada tidak membawa
/// data kondisi kulit apa pun).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
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
              child: Icon(
                Icons.spa_rounded,
                size: 44,
                color: cs.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Rekomendasi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Lakukan deteksi di halaman Analysis terlebih dahulu supaya '
                  'kami bisa menyarankan kandungan & produk yang sesuai dengan '
                  'kondisi kulitmu.',
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

class _ProblemChip extends StatelessWidget {
  const _ProblemChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: cs.onErrorContainer,
        ),
      ),
    );
  }
}

/// Baris detail satu kandungan: nama + manfaat SELALU terlihat (poin
/// #3 -- "secara detail"), bukan cuma nama di chip dengan manfaat
/// tersembunyi di tooltip seperti `_IngredientChip` sebelumnya.
class _IngredientDetailTile extends StatelessWidget {
  const _IngredientDetailTile({required this.ingredient});
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
            child: Icon(Icons.check_circle_rounded,
                size: 16, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ingredient.benefit,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.65),
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

/// Kartu satu produk: foto besar di kiri, lalu merek, nama, rating,
/// dan deskripsi kandungan yang relate dengan masalah kulit blok ini.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.rec});
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
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: cs.onSurface.withOpacity(0.3),
                ),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded,
                          size: 15, color: Colors.amber.shade600),
                      const SizedBox(width: 3),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
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