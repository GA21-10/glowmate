// lib/app/pages/recommendation/model/model.dart

/// Satu jenis kandungan (bahan aktif) skincare, mis. "Niacinamide",
/// "Salicylic Acid", dll.
///
/// [id] dipakai sebagai key unik untuk mencocokkan Ingredient <-> Product
/// (lihat `Product.ingredientIds`) dan untuk mencocokkan Ingredient <->
/// masalah kulit (lihat `model/data.dart`).
class Ingredient {
  final String id;
  final String name;

  /// Alasan singkat kenapa kandungan ini direkomendasikan (ditampilkan
  /// sebagai deskripsi di chip kandungan / kartu produk).
  final String benefit;

  const Ingredient({
    required this.id,
    required this.name,
    required this.benefit,
  });
}

/// Satu produk skincare dalam katalog rekomendasi.
///
/// CATATAN SUMBER DATA (lihat juga model/data.dart):
/// Untuk tahap ini semua field di bawah diisi dari data LOKAL/DUMMY
/// (bukan dari API Google beneran), termasuk [rating] dan [imageUrl].
/// Struktur class ini sudah disiapkan supaya nanti gampang diganti ke
/// sumber data asli (mis. hasil panggilan API pencarian produk/gambar)
/// tanpa perlu ubah UI atau logic rekomendasi -- cukup ganti cara
/// katalog produk diisi (lihat TODO di model/data.dart).
class Product {
  final String id;
  final String name;
  final String brand;

  /// Rating produk (skala 0-5). Di tahap dummy ini diisi manual meniru
  /// rating yang biasa muncul di Google/e-commerce, supaya urutan
  /// "produk berdasarkan rating tertinggi dari Google" tetap bisa
  /// disimulasikan -- lihat RecommendationRepository, daftar produk
  /// SELALU diurutkan dari rating tertinggi -> terendah.
  final double rating;

  /// URL foto produk. Di tahap dummy diisi placeholder; nanti saat
  /// sudah terhubung ke sumber gambar Google, cukup isi field ini
  /// dengan URL hasil pencarian gambar produk yang sesuai.
  final String imageUrl;

  /// Daftar id kandungan (harus cocok dengan `Ingredient.id` di
  /// ingredientCatalog) yang terkandung dalam produk ini.
  final List<String> ingredientIds;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.rating,
    required this.imageUrl,
    required this.ingredientIds,
  });
}