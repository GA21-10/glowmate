// ─────────────────────────────────────────────
// core/models/users/global.dart
// (UPDATE: alamat detail Indonesia — RT, RW, Kelurahan, Kecamatan)
// (UPDATE: fullAddress format berbeda Indonesia vs luar negeri)
// (UPDATE: subscriptionPlan kini disertai billingCycle & nextBillingDate)
// ─────────────────────────────────────────────

import '../../../pages/account/paket/model/berlangganan.dart';

enum SkinConditionStatus { belumPaham, sudahMengetahui }

extension SkinConditionStatusX on SkinConditionStatus {
  String get label => switch (this) {
    SkinConditionStatus.belumPaham => 'Belum Begitu Paham',
    SkinConditionStatus.sudahMengetahui => 'Sudah Mengetahui',
  };

  String get storageValue => switch (this) {
    SkinConditionStatus.belumPaham => 'belum_paham',
    SkinConditionStatus.sudahMengetahui => 'sudah_mengetahui',
  };

  static SkinConditionStatus? fromStorage(String? value) {
    switch (value) {
      case 'belum_paham':
        return SkinConditionStatus.belumPaham;
      case 'sudah_mengetahui':
        return SkinConditionStatus.sudahMengetahui;
      default:
        return null;
    }
  }
}

// PEMBARUAN: daftar tipe kulit diperluas dari 7 → 21 tipe (termasuk
// kulit Albino & kulit Hitam) agar sinkron dengan chip pilihan yang
// dipakai di `profile_setup_page.dart` (_skinTypeIconsByName) dan
// `account_edit_page.dart` (_skinTypeIconFor). Enum ini menjadi SATU
// sumber kebenaran — kedua halaman membangun daftar chip lewat
// `SkinType.values`, jadi menambah/mengurangi tipe di sini otomatis
// terlihat di kedua halaman tanpa perlu ubah UI.
enum SkinType {
  normal,
  jerawat,
  kusam,
  berminyak,
  kering,
  sensitif,
  kombinasi,
  albino,
  kulitHitam,
  komedo,
  poriBesar,
  flek,
  hiperpigmentasi,
  kerutan,
  kantungMata,
  kemerahan,
  bekasLuka,
  kulitMengelupas,
  milia,
  dermatitis,
  rosacea,
}

extension SkinTypeX on SkinType {
  String get label => switch (this) {
    SkinType.normal => 'Normal',
    SkinType.jerawat => 'Jerawat',
    SkinType.kusam => 'Kusam',
    SkinType.berminyak => 'Berminyak',
    SkinType.kering => 'Kering',
    SkinType.sensitif => 'Sensitif',
    SkinType.kombinasi => 'Kombinasi',
    SkinType.albino => 'Kulit Albino',
    SkinType.kulitHitam => 'Kulit Hitam',
    SkinType.komedo => 'Komedo',
    SkinType.poriBesar => 'Pori-Pori Besar',
    SkinType.flek => 'Flek Hitam',
    SkinType.hiperpigmentasi => 'Hiperpigmentasi',
    SkinType.kerutan => 'Kerutan',
    SkinType.kantungMata => 'Kantung Mata',
    SkinType.kemerahan => 'Kemerahan',
    SkinType.bekasLuka => 'Bekas Luka',
    SkinType.kulitMengelupas => 'Kulit Mengelupas',
    SkinType.milia => 'Milia',
    SkinType.dermatitis => 'Dermatitis',
    SkinType.rosacea => 'Rosacea',
  };

  String get storageValue => switch (this) {
    SkinType.normal => 'normal',
    SkinType.jerawat => 'jerawat',
    SkinType.kusam => 'kusam',
    SkinType.berminyak => 'berminyak',
    SkinType.kering => 'kering',
    SkinType.sensitif => 'sensitif',
    SkinType.kombinasi => 'kombinasi',
    SkinType.albino => 'albino',
    SkinType.kulitHitam => 'kulit_hitam',
    SkinType.komedo => 'komedo',
    SkinType.poriBesar => 'pori_besar',
    SkinType.flek => 'flek',
    SkinType.hiperpigmentasi => 'hiperpigmentasi',
    SkinType.kerutan => 'kerutan',
    SkinType.kantungMata => 'kantung_mata',
    SkinType.kemerahan => 'kemerahan',
    SkinType.bekasLuka => 'bekas_luka',
    SkinType.kulitMengelupas => 'kulit_mengelupas',
    SkinType.milia => 'milia',
    SkinType.dermatitis => 'dermatitis',
    SkinType.rosacea => 'rosacea',
  };

  static SkinType? fromStorage(String? value) {
    for (final t in SkinType.values) {
      if (t.storageValue == value) return t;
    }
    return null;
  }

  static String encodeList(List<SkinType> types) =>
      types.map((t) => t.storageValue).join(',');

  static List<SkinType> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => SkinTypeX.fromStorage(s.trim()))
        .whereType<SkinType>()
        .toList();
  }
}

class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String? photo;
  final DateTime? birthDate;

  // ── Alamat — field UMUM (dipakai baik Indonesia maupun luar negeri) ──
  final String? street;      // Nama Jalan / Street
  final String? unitNumber;  // Blok/No/Unit (ID) atau Apt/Suite No. (luar)
  final String? city;        // Kota / Kabupaten (ID) atau City (luar)
  final String? province;    // Provinsi (ID) atau State/Province (luar)
  final String? postalCode;  // Kode Pos / ZIP
  final String? countryIso;  // Kode ISO negara, mis. "ID" (default Indonesia)

  // ── Alamat — KHUSUS Indonesia (null/kosong jika negara bukan ID) ─────
  final String? rt;          // RT
  final String? rw;          // RW
  final String? kelurahan;   // Kelurahan / Desa
  final String? kecamatan;   // Kecamatan

  // ── No. Telepon aktif WhatsApp ───────────────
  final String? phoneDialCode;
  final String? phoneNumber;

  // ── Kondisi & tipe kulit ──────────────────────
  final List<SkinType> skinTypes;
  final SkinConditionStatus? skinCondition;

  // ── Langganan ─────────────────────────────────
  final SubscriptionPlan subscriptionPlan;
  final BillingCycle billingCycle;     // hanya relevan jika !subscriptionPlan.isFree
  final DateTime? nextBillingDate;     // null jika Free

  const UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.photo,
    this.birthDate,
    this.street,
    this.unitNumber,
    this.city,
    this.province,
    this.postalCode,
    this.countryIso,
    this.rt,
    this.rw,
    this.kelurahan,
    this.kecamatan,
    this.phoneDialCode,
    this.phoneNumber,
    this.skinTypes = const [],
    this.skinCondition,
    this.subscriptionPlan = SubscriptionPlan.free,
    this.billingCycle = BillingCycle.monthly,
    this.nextBillingDate,
  });

  /// True jika alamat pengguna berada di Indonesia — menentukan apakah
  /// field RT/RW/Kelurahan/Kecamatan ditampilkan & dipakai.
  bool get isIndonesianAddress =>
      (countryIso ?? 'ID').toUpperCase() == 'ID';

  Map<String, int>? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int years  = now.year  - birthDate!.year;
    int months = now.month - birthDate!.month;
    int days   = now.day   - birthDate!.day;

    if (days < 0) {
      months -= 1;
      days   += _daysInMonth(now.year, now.month - 1 == 0 ? 12 : now.month - 1);
    }
    if (months < 0) {
      years  -= 1;
      months += 12;
    }
    return {'years': years, 'months': months, 'days': days};
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Label usia siap tampil, mis. "20 Tahun 3 Bulan 14 Hari".
  String? get ageLabel {
    final a = age;
    if (a == null) return null;
    return '${a['years']} Tahun ${a['months']} Bulan ${a['days']} Hari';
  }

  String? get fullPhone {
    if (phoneDialCode == null || phoneNumber == null || phoneNumber!.isEmpty) {
      return null;
    }
    return '$phoneDialCode$phoneNumber';
  }

  /// Alamat lengkap satu baris — format BERBEDA untuk Indonesia vs
  /// luar negeri:
  ///  • Indonesia: "Jl. Merdeka No. 12, RT 03/RW 05, Kel. Sukamaju,
  ///    Kec. Coblong, Bandung, Jawa Barat 40123"
  ///  • Luar negeri: "123 Main St, Apt 4B, New York, NY 10001"
  String? get fullAddress {
    if (isIndonesianAddress) {
      final line1Parts = <String>[
        if (street != null && street!.isNotEmpty) street!,
        if (unitNumber != null && unitNumber!.isNotEmpty) unitNumber!,
      ];
      final line1 = line1Parts.join(' ');

      String? rtRw;
      final hasRt = rt != null && rt!.isNotEmpty;
      final hasRw = rw != null && rw!.isNotEmpty;
      if (hasRt || hasRw) {
        rtRw = 'RT ${hasRt ? rt : '-'}/RW ${hasRw ? rw : '-'}';
      }

      final middleParts = <String>[
        if (rtRw != null) rtRw,
        if (kelurahan != null && kelurahan!.isNotEmpty) 'Kel. $kelurahan',
        if (kecamatan != null && kecamatan!.isNotEmpty) 'Kec. $kecamatan',
      ];

      final line3Parts = <String>[
        if (city != null && city!.isNotEmpty) city!,
        if (province != null && province!.isNotEmpty) province!,
      ];
      var line3 = line3Parts.join(', ');
      if (postalCode != null && postalCode!.isNotEmpty) {
        line3 = line3.isEmpty ? postalCode! : '$line3 $postalCode';
      }

      final all = [line1, ...middleParts, line3]
          .where((s) => s.isNotEmpty)
          .join(', ');
      return all.isEmpty ? null : all;
    }

    // ── Format luar negeri (lebih sederhana, tanpa RT/RW/Kel/Kec) ──────
    final line1Parts = <String>[
      if (street != null && street!.isNotEmpty) street!,
      if (unitNumber != null && unitNumber!.isNotEmpty) unitNumber!,
    ];
    final line1 = line1Parts.join(', ');

    final line2Parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (province != null && province!.isNotEmpty) province!,
    ];
    var line2 = line2Parts.join(', ');
    if (postalCode != null && postalCode!.isNotEmpty) {
      line2 = line2.isEmpty ? postalCode! : '$line2 $postalCode';
    }

    final all = [line1, line2].where((s) => s.isNotEmpty).join(', ');
    return all.isEmpty ? null : all;
  }

  bool get hasAddress =>
      (street != null && street!.isNotEmpty) ||
          (unitNumber != null && unitNumber!.isNotEmpty) ||
          (city != null && city!.isNotEmpty) ||
          (province != null && province!.isNotEmpty) ||
          (postalCode != null && postalCode!.isNotEmpty) ||
          (rt != null && rt!.isNotEmpty) ||
          (rw != null && rw!.isNotEmpty) ||
          (kelurahan != null && kelurahan!.isNotEmpty) ||
          (kecamatan != null && kecamatan!.isNotEmpty);

  // ── Status kelengkapan per-field ────────────────────────────────────
  bool get hasName => name != null && name!.trim().isNotEmpty;
  bool get hasPhoto => photo != null && photo!.trim().isNotEmpty;
  bool get hasBirthDate => birthDate != null;

  bool get hasPhone =>
      phoneDialCode != null &&
          phoneDialCode!.trim().isNotEmpty &&
          phoneNumber != null &&
          phoneNumber!.trim().isNotEmpty;

  bool get hasSkinType => skinTypes.isNotEmpty;
  bool get hasSkinCondition => skinCondition != null;

  // ── Status langganan ──────────────────────────────────────────────
  bool get isSubscribed => !subscriptionPlan.isFree;

  /// True jika paket berbayar & tanggal tagihan berikutnya sudah lewat
  /// (berguna untuk penanda "perlu perpanjangan" di UI, opsional dipakai).
  bool get isBillingOverdue =>
      isSubscribed &&
          nextBillingDate != null &&
          nextBillingDate!.isBefore(DateTime.now());

  bool get isProfileComplete =>
      hasName && hasBirthDate && hasAddress && hasPhone && hasSkinCondition;

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photo,
    DateTime? birthDate,
    String? street,
    String? unitNumber,
    String? city,
    String? province,
    String? postalCode,
    String? countryIso,
    String? rt,
    String? rw,
    String? kelurahan,
    String? kecamatan,
    String? phoneDialCode,
    String? phoneNumber,
    List<SkinType>? skinTypes,
    SkinConditionStatus? skinCondition,
    SubscriptionPlan? subscriptionPlan,
    BillingCycle? billingCycle,
    DateTime? nextBillingDate,
    bool clearNextBillingDate = false, // true → nextBillingDate dikosongkan
  }) =>
      UserModel(
        uid:               uid               ?? this.uid,
        email:             email             ?? this.email,
        name:              name              ?? this.name,
        photo:             photo             ?? this.photo,
        birthDate:         birthDate         ?? this.birthDate,
        street:            street            ?? this.street,
        unitNumber:        unitNumber        ?? this.unitNumber,
        city:              city              ?? this.city,
        province:          province          ?? this.province,
        postalCode:        postalCode        ?? this.postalCode,
        countryIso:        countryIso        ?? this.countryIso,
        rt:                rt                ?? this.rt,
        rw:                rw                ?? this.rw,
        kelurahan:         kelurahan         ?? this.kelurahan,
        kecamatan:         kecamatan         ?? this.kecamatan,
        phoneDialCode:     phoneDialCode     ?? this.phoneDialCode,
        phoneNumber:       phoneNumber       ?? this.phoneNumber,
        skinTypes:         skinTypes         ?? this.skinTypes,
        skinCondition:     skinCondition     ?? this.skinCondition,
        subscriptionPlan:  subscriptionPlan  ?? this.subscriptionPlan,
        billingCycle:      billingCycle      ?? this.billingCycle,
        nextBillingDate:   clearNextBillingDate
            ? null
            : (nextBillingDate ?? this.nextBillingDate),
      );

  UserModel copyWithPhotoCleared() => UserModel(
    uid: uid,
    email: email,
    name: name,
    photo: null,
    birthDate: birthDate,
    street: street,
    unitNumber: unitNumber,
    city: city,
    province: province,
    postalCode: postalCode,
    countryIso: countryIso,
    rt: rt,
    rw: rw,
    kelurahan: kelurahan,
    kecamatan: kecamatan,
    phoneDialCode: phoneDialCode,
    phoneNumber: phoneNumber,
    skinTypes: skinTypes,
    skinCondition: skinCondition,
    subscriptionPlan: subscriptionPlan,
    billingCycle: billingCycle,
    nextBillingDate: nextBillingDate,
  );

  /// Sama seperti [copyWith], tapi field RT/RW/Kelurahan/Kecamatan
  /// benar-benar DIKOSONGKAN — dipakai saat pengguna pindah negara dari
  /// Indonesia ke luar negeri (data khusus ID tidak relevan lagi).
  UserModel copyWithIndonesianFieldsCleared() => UserModel(
    uid: uid,
    email: email,
    name: name,
    photo: photo,
    birthDate: birthDate,
    street: street,
    unitNumber: unitNumber,
    city: city,
    province: province,
    postalCode: postalCode,
    countryIso: countryIso,
    rt: null,
    rw: null,
    kelurahan: null,
    kecamatan: null,
    phoneDialCode: phoneDialCode,
    phoneNumber: phoneNumber,
    skinTypes: skinTypes,
    skinCondition: skinCondition,
    subscriptionPlan: subscriptionPlan,
    billingCycle: billingCycle,
    nextBillingDate: nextBillingDate,
  );

  /// Dipakai saat downgrade ke Free — plan jadi Free, siklus balik ke
  /// monthly (default), dan tanggal tagihan berikutnya dikosongkan.
  UserModel copyWithPlanCleared() => UserModel(
    uid: uid,
    email: email,
    name: name,
    photo: photo,
    birthDate: birthDate,
    street: street,
    unitNumber: unitNumber,
    city: city,
    province: province,
    postalCode: postalCode,
    countryIso: countryIso,
    rt: rt,
    rw: rw,
    kelurahan: kelurahan,
    kecamatan: kecamatan,
    phoneDialCode: phoneDialCode,
    phoneNumber: phoneNumber,
    skinTypes: skinTypes,
    skinCondition: skinCondition,
    subscriptionPlan: SubscriptionPlan.free,
    billingCycle: BillingCycle.monthly,
    nextBillingDate: null,
  );

  Map<String, dynamic> toMap() => {
    'uid':              uid,
    'email':            email,
    'name':             name,
    'photo':            photo,
    'birthDate':        birthDate?.toIso8601String(),
    'street':           street,
    'unitNumber':       unitNumber,
    'city':             city,
    'province':         province,
    'postalCode':       postalCode,
    'countryIso':       countryIso,
    'rt':               rt,
    'rw':               rw,
    'kelurahan':        kelurahan,
    'kecamatan':        kecamatan,
    'phoneDialCode':    phoneDialCode,
    'phoneNumber':      phoneNumber,
    'skinTypes':        SkinTypeX.encodeList(skinTypes),
    'skinCondition':    skinCondition?.storageValue,
    'subscriptionPlan': subscriptionPlan.key,
    'billingCycle':     billingCycle.key,
    'nextBillingDate':  nextBillingDate?.toIso8601String(),
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    uid:       map['uid']   ?? '',
    email:     map['email'] ?? '',
    name:      map['name'],
    photo:     map['photo'],
    birthDate: map['birthDate'] != null
        ? DateTime.tryParse(map['birthDate'])
        : null,
    street:        map['street'],
    unitNumber:    map['unitNumber'],
    city:          map['city'],
    province:      map['province'],
    postalCode:    map['postalCode'],
    countryIso:    map['countryIso'],
    rt:            map['rt'],
    rw:            map['rw'],
    kelurahan:     map['kelurahan'],
    kecamatan:     map['kecamatan'],
    phoneDialCode: map['phoneDialCode'],
    phoneNumber:   map['phoneNumber'],
    skinTypes:     SkinTypeX.decodeList(map['skinTypes'] as String?),
    skinCondition: SkinConditionStatusX.fromStorage(map['skinCondition']),
    subscriptionPlan: SubscriptionPlan.fromKey(map['subscriptionPlan']),
    billingCycle:     BillingCycleX.fromKey(map['billingCycle']),
    nextBillingDate:  map['nextBillingDate'] != null
        ? DateTime.tryParse(map['nextBillingDate'])
        : null,
  );
}