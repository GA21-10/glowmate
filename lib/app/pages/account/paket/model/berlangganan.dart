// ─────────────────────────────────────────────
// app/pages/account/paket/model/berlangganan.dart
// ─────────────────────────────────────────────
//
// Model paket berlangganan + siklus tagihan (Bulanan/Tahunan).
// `free` adalah nilai DEFAULT untuk setiap pengguna baru / pengguna
// yang belum pernah upgrade — dipakai sebagai fallback di mana pun
// plan pengguna tidak diketahui / null.
//
// Paket berbayar (pro/max/premium) punya 2 harga:
//   - priceMonthly → harga dasar per bulan
//   - priceYearly  → setara 10x harga bulanan (hemat 2 bulan / ~17%)
//
// `BillingCycle` dipakai untuk menandai siklus tagihan yang dipilih
// user (disimpan di UserModel.billingCycle) dan untuk menghitung
// tanggal tagihan berikutnya (UserModel.nextBillingDate).
// ─────────────────────────────────────────────

enum SubscriptionPlan {
  free,
  pro,
  max,
  premium;

  static SubscriptionPlan fromKey(String? key) {
    switch (key) {
      case 'pro':
        return SubscriptionPlan.pro;
      case 'max':
        return SubscriptionPlan.max;
      case 'premium':
        return SubscriptionPlan.premium;
      case 'free':
      default:
        return SubscriptionPlan.free;
    }
  }

  String get key {
    switch (this) {
      case SubscriptionPlan.free:
        return 'free';
      case SubscriptionPlan.pro:
        return 'pro';
      case SubscriptionPlan.max:
        return 'max';
      case SubscriptionPlan.premium:
        return 'premium';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.max:
        return 'Max';
      case SubscriptionPlan.premium:
        return 'Premium';
    }
  }

  bool get isFree => this == SubscriptionPlan.free;

  int get priceMonthly {
    switch (this) {
      case SubscriptionPlan.free:
        return 0;
      case SubscriptionPlan.pro:
        return 49000;
      case SubscriptionPlan.max:
        return 99000;
      case SubscriptionPlan.premium:
        return 149000;
    }
  }

  int get priceYearly => isFree ? 0 : priceMonthly * 10;

  String priceFor(BillingCycle cycle) {
    if (isFree) return 'Rp0';
    final amount = cycle == BillingCycle.monthly ? priceMonthly : priceYearly;
    return formatRupiah(amount);
  }

  String priceLabel(BillingCycle cycle) {
    if (isFree) return 'Rp0 / bulan';
    final suffix = cycle == BillingCycle.monthly ? 'bulan' : 'tahun';
    return '${priceFor(cycle)} / $suffix';
  }

  int get yearlySavingsPercent {
    if (isFree) return 0;
    final fullYear = priceMonthly * 12;
    final savings = fullYear - priceYearly;
    return ((savings / fullYear) * 100).round();
  }

  List<String> get features {
    switch (this) {
      case SubscriptionPlan.free:
        return const [
          'Fitur dasar aplikasi',
          'Analisis terbatas',
          'Tanpa Membayar Rp 5.000 Per satu scanner',
        ];
      case SubscriptionPlan.pro:
        return const [
          'Semua fitur Free',
          'Analisis lengkap',
          'Tanpa Membayar Rp 5.000 Per satu scanner',
        ];
      case SubscriptionPlan.max:
        return const [
          'Semua fitur Pro',
          'Laporan mendalam',
          'Tanpa Membayar Rp 5.000 Per satu scanner',
          'Dukungan prioritas terhadap kesalahan analisis',
        ];
      case SubscriptionPlan.premium:
        return const [
          'Semua fitur Max',
          'Akses fitur baru lebih awal',
          'Dukungan personal 1-on-1',
          'Ditangani langsung oleh Dokter Spesialis dermatologi untuk pengguna',
        ];
    }
  }
}

/// Siklus tagihan untuk paket berbayar.
enum BillingCycle { monthly, yearly }

extension BillingCycleX on BillingCycle {
  String get key => this == BillingCycle.monthly ? 'monthly' : 'yearly';

  String get label => this == BillingCycle.monthly ? 'Bulanan' : 'Tahunan';

  DateTime nextBillingFrom(DateTime start) {
    return this == BillingCycle.monthly
        ? DateTime(start.year, start.month + 1, start.day)
        : DateTime(start.year + 1, start.month, start.day);
  }

  /// Parse dari string tersimpan. Nilai apa pun yang tidak dikenali
  /// (termasuk null) dianggap `monthly`.
  static BillingCycle fromKey(String? key) =>
      key == 'yearly' ? BillingCycle.yearly : BillingCycle.monthly;

  /// Sama seperti [fromKey], tapi mengembalikan `null` bila [key]
  /// null/kosong — dipakai untuk membedakan "belum pernah
  /// berlangganan / paket Free" (null) dari "berlangganan siklus
  /// bulanan" (BillingCycle.monthly). Dipakai di AccountPage supaya
  /// field paket tidak salah menganggap user Free sebagai user
  /// bulanan.
  static BillingCycle? fromKeyOrNull(String? key) {
    if (key == null || key.isEmpty) return null;
    return key == 'yearly' ? BillingCycle.yearly : BillingCycle.monthly;
  }
}

/// Format Rupiah sederhana, mis. 149000 → "Rp149.000".
String formatRupiah(int amount) {
  final chars = amount.toString().split('');
  final result = <String>[];
  var count = 0;
  for (var i = chars.length - 1; i >= 0; i--) {
    result.insert(0, chars[i]);
    count++;
    if (count % 3 == 0 && i != 0) result.insert(0, '.');
  }
  return 'Rp${result.join()}';
}