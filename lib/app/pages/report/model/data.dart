// lib/app/pages/recommendation/model/data.dart
import 'package:glowmate/app/pages/report/model/req.dart';

import '../../analysis/model/model.dart'
    show AnalysisRecord, kLatestFindingPlaceholder;

/// ============================================================
/// SUMBER DATA REKOMENDASI (TAHAP DUMMY / LOKAL)
/// ============================================================
/// Tiga hal di file ini dipakai bersama oleh RecommendationRepository:
/// 1. `problemToIngredientIds` : masalah kulit -> kandungan yang perlu.
/// 2. `ingredientCatalog`      : detail tiap kandungan (nama, manfaat).
/// 3. `productCatalog`         : daftar produk beserta kandungannya &
///    rating -- rating inilah yang dipakai untuk urutan "rating
///    tertinggi dari Google".
///
/// TODO (saat sudah siap ganti ke data asli / API sungguhan):
/// - `productCatalog` -> ganti jadi hasil panggilan service/API produk
///   (mis. `ProductRepository.fetchByIngredientIds(...)`), tapi bentuk
///   `Product` & logic sort-by-rating di RecommendationRepository TIDAK
///   perlu diubah sama sekali.
/// - `Product.imageUrl` -> isi dari hasil pencarian gambar produk yang
///   sesungguhnya (mis. Google Custom Search Image API, atau provider
///   lain) alih-alih placeholder di bawah.

/// Kunci kanonik masalah kulit -> daftar id kandungan yang dibutuhkan.
/// Cocokkan label bebas dari analysis (mis. "Kulit Berjerawat") ke kunci
/// ini lewat `matchProblemKeys()` di bawah (substring match, longgar).
const Map<String, List<String>> problemToIngredientIds = {
  'jerawat': ['salicylic_acid', 'niacinamide', 'tea_tree_oil', 'zinc_pca'],
  'komedo': ['salicylic_acid', 'niacinamide'],
  'kusam': ['vitamin_c', 'aha', 'niacinamide'],
  'kering': ['hyaluronic_acid', 'ceramide', 'glycerin'],
  'berminyak': ['niacinamide', 'salicylic_acid', 'zinc_pca'],
  'pori': ['niacinamide', 'bha'],
  'flek': ['vitamin_c', 'alpha_arbutin', 'kojic_acid'],
  'hiperpigmentasi': ['vitamin_c', 'alpha_arbutin', 'kojic_acid'],
  'kerutan': ['retinol', 'peptide', 'vitamin_c'],
  'penuaan': ['retinol', 'peptide', 'hyaluronic_acid'],
  'sensitif': ['centella_asiatica', 'ceramide', 'panthenol'],
  'kemerahan': ['centella_asiatica', 'panthenol'],
  'dehidrasi': ['hyaluronic_acid', 'glycerin'],
};

/// Cocokkan satu label masalah kulit bebas (mis. dari
/// `knownSkinConditionLabel` atau `analysisData['skinProblems']`) ke
/// satu/lebih kunci kanonik di [problemToIngredientIds]. Longgar: pakai
/// substring match supaya label seperti "Kulit Berjerawat & Berminyak"
/// tetap kena kunci `jerawat` DAN `berminyak` sekaligus.
Set<String> matchProblemKeys(String rawLabel) {
  final lower = rawLabel.toLowerCase();
  final matched = <String>{};
  for (final key in problemToIngredientIds.keys) {
    if (lower.contains(key)) matched.add(key);
  }
  return matched;
}

const Map<String, Ingredient> ingredientCatalog = {
  'salicylic_acid': Ingredient(
    id: 'salicylic_acid',
    name: 'Salicylic Acid (BHA)',
    benefit: 'Membersihkan pori & mengurangi jerawat/komedo',
  ),
  'niacinamide': Ingredient(
    id: 'niacinamide',
    name: 'Niacinamide',
    benefit: 'Mengontrol minyak, mengecilkan pori, mencerahkan',
  ),
  'tea_tree_oil': Ingredient(
    id: 'tea_tree_oil',
    name: 'Tea Tree Oil',
    benefit: 'Antibakteri alami untuk kulit berjerawat',
  ),
  'zinc_pca': Ingredient(
    id: 'zinc_pca',
    name: 'Zinc PCA',
    benefit: 'Mengontrol produksi minyak berlebih',
  ),
  'vitamin_c': Ingredient(
    id: 'vitamin_c',
    name: 'Vitamin C',
    benefit: 'Mencerahkan & meratakan warna kulit',
  ),
  'aha': Ingredient(
    id: 'aha',
    name: 'AHA (Glycolic/Lactic Acid)',
    benefit: 'Mengangkat sel kulit mati, mengatasi kusam',
  ),
  'hyaluronic_acid': Ingredient(
    id: 'hyaluronic_acid',
    name: 'Hyaluronic Acid',
    benefit: 'Melembapkan & menjaga hidrasi kulit',
  ),
  'ceramide': Ingredient(
    id: 'ceramide',
    name: 'Ceramide',
    benefit: 'Memperkuat skin barrier & mencegah kering',
  ),
  'glycerin': Ingredient(
    id: 'glycerin',
    name: 'Glycerin',
    benefit: 'Menarik & mengunci kelembapan kulit',
  ),
  'bha': Ingredient(
    id: 'bha',
    name: 'BHA',
    benefit: 'Membersihkan pori dari dalam',
  ),
  'alpha_arbutin': Ingredient(
    id: 'alpha_arbutin',
    name: 'Alpha Arbutin',
    benefit: 'Memudarkan flek hitam & hiperpigmentasi',
  ),
  'kojic_acid': Ingredient(
    id: 'kojic_acid',
    name: 'Kojic Acid',
    benefit: 'Mencerahkan area flek/bekas jerawat',
  ),
  'retinol': Ingredient(
    id: 'retinol',
    name: 'Retinol',
    benefit: 'Menyamarkan garis halus & tanda penuaan',
  ),
  'peptide': Ingredient(
    id: 'peptide',
    name: 'Peptide',
    benefit: 'Merangsang produksi kolagen kulit',
  ),
  'centella_asiatica': Ingredient(
    id: 'centella_asiatica',
    name: 'Centella Asiatica (Cica)',
    benefit: 'Menenangkan kulit sensitif & kemerahan',
  ),
  'panthenol': Ingredient(
    id: 'panthenol',
    name: 'Panthenol (Pro-Vitamin B5)',
    benefit: 'Menenangkan & memperbaiki skin barrier',
  ),
};

/// Katalog produk dummy. `rating` mensimulasikan rating tertinggi dari
/// Google/e-commerce; `imageUrl` masih placeholder (lihat TODO di atas
/// file untuk cara mengganti ke sumber gambar asli).
const List<Product> productCatalog = [
  Product(
    id: 'p001',
    name: 'Acne Care Serum',
    brand: 'Somethinc',
    rating: 4.8,
    imageUrl: 'https://picsum.photos/seed/acne-care-serum/300/300',
    ingredientIds: ['salicylic_acid', 'niacinamide', 'zinc_pca'],
  ),
  Product(
    id: 'p002',
    name: 'Clear Skin Tea Tree Gel',
    brand: 'Some By Mi',
    rating: 4.7,
    imageUrl: 'https://picsum.photos/seed/tea-tree-gel/300/300',
    ingredientIds: ['tea_tree_oil', 'niacinamide'],
  ),
  Product(
    id: 'p003',
    name: 'Niacinamide 10% + Zinc 1%',
    brand: 'The Ordinary',
    rating: 4.9,
    imageUrl: 'https://picsum.photos/seed/niacinamide-zinc/300/300',
    ingredientIds: ['niacinamide', 'zinc_pca'],
  ),
  Product(
    id: 'p004',
    name: 'Brightening Vitamin C Serum',
    brand: 'Avoskin',
    rating: 4.6,
    imageUrl: 'https://picsum.photos/seed/vit-c-serum/300/300',
    ingredientIds: ['vitamin_c', 'alpha_arbutin'],
  ),
  Product(
    id: 'p005',
    name: 'Glow AHA Toner',
    brand: 'Skintific',
    rating: 4.5,
    imageUrl: 'https://picsum.photos/seed/aha-toner/300/300',
    ingredientIds: ['aha', 'vitamin_c'],
  ),
  Product(
    id: 'p006',
    name: 'Hydra Barrier Moisturizer',
    brand: 'Somethinc',
    rating: 4.9,
    imageUrl: 'https://picsum.photos/seed/hydra-moisturizer/300/300',
    ingredientIds: ['hyaluronic_acid', 'ceramide', 'glycerin'],
  ),
  Product(
    id: 'p007',
    name: 'Barrier Repair Cream',
    brand: 'Skintific',
    rating: 4.7,
    imageUrl: 'https://picsum.photos/seed/barrier-cream/300/300',
    ingredientIds: ['ceramide', 'panthenol', 'centella_asiatica'],
  ),
  Product(
    id: 'p008',
    name: 'Dark Spot Corrector',
    brand: 'Avoskin',
    rating: 4.6,
    imageUrl: 'https://picsum.photos/seed/dark-spot/300/300',
    ingredientIds: ['alpha_arbutin', 'kojic_acid', 'vitamin_c'],
  ),
  Product(
    id: 'p009',
    name: 'Retinol Anti-Aging Serum',
    brand: 'The Ordinary',
    rating: 4.8,
    imageUrl: 'https://picsum.photos/seed/retinol-serum/300/300',
    ingredientIds: ['retinol', 'peptide'],
  ),
  Product(
    id: 'p010',
    name: 'Centella Calming Toner',
    brand: 'Some By Mi',
    rating: 4.8,
    imageUrl: 'https://picsum.photos/seed/centella-toner/300/300',
    ingredientIds: ['centella_asiatica', 'panthenol'],
  ),
  Product(
    id: 'p011',
    name: 'Pore Refining Essence',
    brand: 'Skintific',
    rating: 4.5,
    imageUrl: 'https://picsum.photos/seed/pore-essence/300/300',
    ingredientIds: ['niacinamide', 'bha'],
  ),
  Product(
    id: 'p012',
    name: 'Peptide Firming Cream',
    brand: 'Avoskin',
    rating: 4.7,
    imageUrl: 'https://picsum.photos/seed/peptide-cream/300/300',
    ingredientIds: ['peptide', 'hyaluronic_acid'],
  ),
];

/// Ambil semua label masalah kulit MENTAH (belum dicocokkan ke kunci
/// kanonik) dari satu [AnalysisRecord], GABUNGAN dari tiga sumber:
///
/// 1. `record.knownSkinTypesLabel` -- Tipe Kulit yang sudah diketahui
///    user saat capture (mis. "Berminyak", "Berjerawat").
/// 2. `record.knownLatestFindingLabel` -- Temuan Tipe Kulit Terbaru,
///    hasil analisis lanjutan (masih placeholder selama fiturnya belum
///    tersedia -- lihat pengecualian `kLatestFindingPlaceholder` di
///    bawah).
/// 3. `record.analysisData['skinProblems']` -- hasil analisis lanjutan
///    lain, diisi lewat `AnalysisRepository.updateSkinProblems()`.
///    Isinya `List<String>` ATAU `String` tunggal (dipisah koma).
///
/// CATATAN PENTING: `record.knownSkinConditionLabel` (Kondisi Kulit)
/// SENGAJA TIDAK ikut jadi sumber di sini lagi. Kondisi Kulit sekarang
/// murni ditampilkan sebagai keterangan informatif di RecommendationPage
/// (lihat `_KnownConditionCard`), bukan lagi dipakai untuk mencari
/// kandungan/produk -- rekomendasi kandungan & produk sekarang murni
/// berbasis Tipe Kulit + Temuan Tipe Kulit Terbaru.
///
/// Label yang berisi banyak kondisi dipisah koma (mis. "Berjerawat,
/// Berminyak") ikut dipecah jadi item terpisah. Teks placeholder "Sabar
/// ya, fitur sedang dikembangkan" (temuan lanjutan yang belum tersedia)
/// sengaja DIKECUALIKAN karena itu bukan masalah kulit sungguhan.
List<String> extractRawSkinProblems(AnalysisRecord record) {
  final problems = <String>{};

  void addLabel(String? label) {
    if (label == null) return;
    // PENTING: placeholder-nya sendiri ("Sabar ya, fitur sedang
    // dikembangkan") MENGANDUNG KOMA. Kalau pengecualian ini dicek
    // SESUDAH di-split per koma, teksnya keburu pecah jadi "Sabar ya"
    // dan "fitur sedang dikembangkan" -- dua fragmen itu tidak akan
    // pernah persis sama dengan placeholder utuh, jadi keduanya lolos
    // dan tetap nongol sebagai "masalah kulit" di UI. Makanya
    // pengecualian harus dicek terhadap label UTUH, sebelum di-split.
    if (label.trim() == kLatestFindingPlaceholder) return;

    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    for (final part in trimmed.split(',')) {
      final p = part.trim();
      if (p.isEmpty) continue;
      problems.add(p);
    }
  }

  addLabel(record.knownSkinTypesLabel);
  addLabel(record.knownLatestFindingLabel);

  final data = record.analysisData;
  if (data != null) {
    final raw =
        data['skinProblems'] ?? data['masalahKulit'] ?? data['problems'];
    if (raw is List) {
      for (final item in raw) {
        addLabel(item?.toString());
      }
    } else if (raw is String) {
      addLabel(raw);
    }
  }

  return problems.toList();
}

/// Gabungkan label masalah kulit dari SEMUA record (bukan cuma yang
/// terbaru) -- supaya kalau ada masalah BARU dari capture berikutnya,
/// kandungan & produk yang direkomendasikan BERTAMBAH, bukan menggantikan
/// yang lama.
List<String> extractAllRawSkinProblems(List<AnalysisRecord> records) {
  final problems = <String>{};
  for (final r in records) {
    problems.addAll(extractRawSkinProblems(r));
  }
  return problems.toList();
}