// lib/app/pages/recommendation/repository/rekomendasi.dart
import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../../analysis/model/model.dart' show AnalysisRecord;
import '../model/data.dart';
import '../model/req.dart';

/// Satu baris hasil rekomendasi produk: produk + kandungan yang relevan
/// (irisan antara kandungan produk & kandungan yang dibutuhkan untuk
/// SATU masalah kulit tertentu) -- dipakai UI untuk menampilkan
/// deskripsi kandungan yang relate pada tiap kartu produk.
class ProductRecommendation {
  final Product product;
  final List<Ingredient> matchedIngredients;

  const ProductRecommendation({
    required this.product,
    required this.matchedIngredients,
  });
}

/// Satu kelompok rekomendasi UNTUK SATU masalah kulit (mis. "Jerawat").
///
/// Ini yang bikin tampilan jadi PER-MASALAH: jerawat -> kandungan +
/// produknya sendiri, berminyak -> kandungan + produknya sendiri, dst --
/// bukan digabung rata jadi satu daftar kandungan/produk besar seperti
/// sebelumnya.
class ProblemGroup {
  /// Kunci kanonik masalah, mis. 'jerawat', 'berminyak'.
  final String key;

  /// Label yang ditampilkan ke user, mis. "Jerawat".
  final String label;

  /// Label mentah (apa adanya dari data user/analisis) yang match ke
  /// kunci ini. Contoh: kalau ada label "Kulit Berjerawat" dan "Jerawat
  /// Parah", keduanya match ke kunci 'jerawat' dan akan ada di sini.
  final Set<String> rawLabels;

  /// Kandungan yang disarankan KHUSUS untuk masalah ini.
  final List<Ingredient> ingredients;

  /// Produk yang mengandung minimal satu dari [ingredients], terurut
  /// rating tertinggi -> terendah. Produk HANYA muncul di sini kalau
  /// kandungannya sudah tertera di [ingredients].
  final List<ProductRecommendation> products;

  const ProblemGroup({
    required this.key,
    required this.label,
    required this.rawLabels,
    required this.ingredients,
    required this.products,
  });
}

/// Repository rekomendasi kandungan & produk, REAKTIF terhadap
/// `AnalysisRepository` -- SATU MEKANISME SINKRONISASI yang sama
/// persis dipakai di AnalysisPage & ReportPage: begitu
/// `AnalysisRepository` memanggil `notifyListeners()` (ada capture
/// baru, atau `updateSkinProblems()` dipanggil), repository ini dihitung
/// ulang dan semua halaman yang nonton (Analysis, Report, Recommendation)
/// otomatis rebuild dengan data terbaru.
///
/// CARA DAFTAR DI main.dart (satu blok Provider, taruh SETELAH
/// AnalysisRepository didaftarkan):
///
/// ```dart
/// import 'app/pages/analysis/repository/analisis.dart';
/// import 'app/pages/recommendation/repository/rekomendasi.dart';
///
/// MultiProvider(
///   providers: [
///     ChangeNotifierProvider.value(value: analysisRepository),
///     ChangeNotifierProxyProvider<AnalysisRepository, RecommendationRepository>(
///       create: (_) => RecommendationRepository(),
///       update: (_, analysisRepo, recRepo) =>
///           (recRepo ?? RecommendationRepository())
///             ..updateFromRecords(analysisRepo.records),
///     ),
///   ],
///   child: const MyApp(),
/// )
/// ```
///
/// Alur (PER MASALAH KULIT, bukan digabung rata):
/// 1. Ambil semua masalah kulit MENTAH dari SELURUH AnalysisRecord
///    (gabungan `knownSkinConditionLabel` + `analysisData['skinProblems']`,
///    lihat model/data.dart -- `extractAllRawSkinProblems()`). Data ini
///    ditampilkan APA ADANYA sebagai chip "Masalah Kulit Terdeteksi".
/// 2. Cocokkan tiap masalah mentah ke kunci kanonik (`matchProblemKeys`).
///    Satu masalah mentah bisa match ke lebih dari satu kunci (mis.
///    "Berjerawat & Berminyak" -> {'jerawat', 'berminyak'}).
/// 3. Untuk TIAP kunci kanonik yang match, bentuk satu [ProblemGroup]:
///    - kandungan = `problemToIngredientIds[key]` (KHUSUS untuk masalah
///      itu, mis. jerawat -> salicylic acid dkk, berminyak -> niacinamide
///      dkk -- tidak dicampur).
///    - produk = produk di `productCatalog` yang punya MINIMAL SATU
///      kandungan tsb, terurut rating tertinggi -> terendah. Produk yang
///      sama boleh muncul di beberapa grup kalau memang mengandung
///      kandungan yang relevan untuk masalah-masalah tsb.
/// 4. `problemGroups` berisi satu grup per masalah kulit yang
///    terdeteksi -- UI merender "Jerawat -> kandungan & produk X",
///    "Berminyak -> kandungan & produk Y" secara terpisah.
/// 5. Karena diambil dari SEMUA record, begitu ada capture baru dengan
///    masalah BARU, grup baru otomatis ditambahkan tanpa menghilangkan
///    grup yang sudah ada.
class RecommendationRepository extends ChangeNotifier {
  List<String> _detectedProblems = [];
  List<ProblemGroup> _problemGroups = [];

  /// Label masalah kulit MENTAH (apa adanya dari data user/analisis),
  /// dipakai UI untuk menampilkan chip "Masalah kulit terdeteksi".
  List<String> get detectedProblems => List.unmodifiable(_detectedProblems);

  /// Rekomendasi kandungan & produk, dikelompokkan PER masalah kulit.
  List<ProblemGroup> get problemGroups => List.unmodifiable(_problemGroups);

  bool get hasAnyProblem => _detectedProblems.isNotEmpty;

  /// Hitung ulang rekomendasi dari NOL berdasarkan seluruh riwayat
  /// record yang ada saat ini. Dipanggil oleh ChangeNotifierProxyProvider
  /// setiap kali AnalysisRepository berubah (lihat contoh main.dart di
  /// atas), tapi juga aman dipanggil manual kalau perlu.
  void updateFromRecords(List<AnalysisRecord> records) {
    final rawProblems = extractAllRawSkinProblems(records);

    // Kunci kanonik -> kumpulan label mentah yang match ke kunci itu.
    final keyToRawLabels = <String, Set<String>>{};
    for (final raw in rawProblems) {
      for (final key in matchProblemKeys(raw)) {
        keyToRawLabels.putIfAbsent(key, () => <String>{}).add(raw);
      }
    }

    final groups = <ProblemGroup>[];
    for (final entry in keyToRawLabels.entries) {
      final key = entry.key;
      final rawLabels = entry.value;

      final neededIds = problemToIngredientIds[key] ?? const [];
      final ingredients = neededIds
          .map((id) => ingredientCatalog[id])
          .whereType<Ingredient>()
          .toList();

      final products = <ProductRecommendation>[];
      for (final product in productCatalog) {
        final matched = product.ingredientIds
            .where((id) => neededIds.contains(id))
            .map((id) => ingredientCatalog[id])
            .whereType<Ingredient>()
            .toList();
        // Produk hanya masuk grup ini kalau kandungannya sudah tertera
        // di daftar kandungan yang disarankan untuk masalah ini.
        if (matched.isNotEmpty) {
          products.add(
            ProductRecommendation(
              product: product,
              matchedIngredients: matched,
            ),
          );
        }
      }
      // Produk berdasarkan rating tertinggi.
      products.sort((a, b) => b.product.rating.compareTo(a.product.rating));

      groups.add(
        ProblemGroup(
          key: key,
          label: _prettyLabel(key),
          rawLabels: rawLabels,
          ingredients: ingredients,
          products: products,
        ),
      );
    }

    _detectedProblems = rawProblems;
    _problemGroups = groups;
    notifyListeners();
  }

  String _prettyLabel(String key) {
    if (key.isEmpty) return key;
    return key[0].toUpperCase() + key.substring(1);
  }
}