// ─────────────────────────────────────────────
// core/services/user_local_service.dart
// (UPDATE: alamat detail Indonesia — RT, RW, Kelurahan, Kecamatan)
// (UPDATE: subscriptionPlan kini disertai billingCycle & nextBillingDate)
// ─────────────────────────────────────────────

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../pages/account/paket/model/berlangganan.dart';
import '../models/users/global.dart';

class UserLocalService {
  UserLocalService._();

  static const _uid        = 'user_uid';
  static const _email      = 'user_email';
  static const _name       = 'user_name';
  static const _photo      = 'user_photo';
  static const _birth      = 'user_birth';
  static const _loggedOut  = 'user_logged_out';

  // ── Alamat — umum ─────────────────────────────
  static const _street     = 'user_street';
  static const _unit       = 'user_unit_number';
  static const _city       = 'user_city';
  static const _province   = 'user_province';
  static const _postal     = 'user_postal_code';
  static const _country    = 'user_country_iso';

  // ── Alamat — khusus Indonesia ──────────────────
  static const _rt         = 'user_rt';
  static const _rw         = 'user_rw';
  static const _kelurahan  = 'user_kelurahan';
  static const _kecamatan  = 'user_kecamatan';

  // ── Telepon ───────────────────────────────────
  static const _phoneDial  = 'user_phone_dial_code';
  static const _phoneNum   = 'user_phone_number';

  // ── Kulit ─────────────────────────────────────
  static const _skinTypes  = 'user_skin_types';
  static const _skin       = 'user_skin_condition';

  // ── Langganan ──────────────────────────────────
  static const _plan          = 'user_subscription_plan';
  static const _billingCycle  = 'user_billing_cycle';
  static const _nextBilling   = 'user_next_billing_date';

  static const _accountsKey = 'known_accounts';

  // ══════════════════════════════════════════════
  // SAVE / UPDATE
  // ══════════════════════════════════════════════

  static Future<void> saveUser(UserModel user) async {
    final p = await SharedPreferences.getInstance();

    final prevUid = p.getString(_uid);
    final isDifferentAccount = prevUid != null && prevUid != user.uid;

    await p.setString(_uid,   user.uid);
    await p.setString(_email, user.email);

    if (user.name != null && user.name!.isNotEmpty) {
      await p.setString(_name, user.name!);
    } else if (isDifferentAccount) {
      await p.remove(_name);
    }

    if (user.photo != null && user.photo!.isNotEmpty) {
      await p.setString(_photo, user.photo!);
    } else if (isDifferentAccount) {
      await p.remove(_photo);
    }

    if (user.birthDate != null) {
      await p.setString(_birth, user.birthDate!.toIso8601String());
    } else if (isDifferentAccount) {
      await p.remove(_birth);
    }

    if (user.street != null && user.street!.isNotEmpty) {
      await p.setString(_street, user.street!);
    } else if (isDifferentAccount) {
      await p.remove(_street);
    }
    if (user.unitNumber != null && user.unitNumber!.isNotEmpty) {
      await p.setString(_unit, user.unitNumber!);
    } else if (isDifferentAccount) {
      await p.remove(_unit);
    }
    if (user.city != null && user.city!.isNotEmpty) {
      await p.setString(_city, user.city!);
    } else if (isDifferentAccount) {
      await p.remove(_city);
    }
    if (user.province != null && user.province!.isNotEmpty) {
      await p.setString(_province, user.province!);
    } else if (isDifferentAccount) {
      await p.remove(_province);
    }
    if (user.postalCode != null && user.postalCode!.isNotEmpty) {
      await p.setString(_postal, user.postalCode!);
    } else if (isDifferentAccount) {
      await p.remove(_postal);
    }
    if (user.countryIso != null && user.countryIso!.isNotEmpty) {
      await p.setString(_country, user.countryIso!);
    } else if (isDifferentAccount) {
      await p.remove(_country);
    }

    if (user.rt != null && user.rt!.isNotEmpty) {
      await p.setString(_rt, user.rt!);
    } else if (isDifferentAccount) {
      await p.remove(_rt);
    }
    if (user.rw != null && user.rw!.isNotEmpty) {
      await p.setString(_rw, user.rw!);
    } else if (isDifferentAccount) {
      await p.remove(_rw);
    }
    if (user.kelurahan != null && user.kelurahan!.isNotEmpty) {
      await p.setString(_kelurahan, user.kelurahan!);
    } else if (isDifferentAccount) {
      await p.remove(_kelurahan);
    }
    if (user.kecamatan != null && user.kecamatan!.isNotEmpty) {
      await p.setString(_kecamatan, user.kecamatan!);
    } else if (isDifferentAccount) {
      await p.remove(_kecamatan);
    }

    if (user.phoneDialCode != null && user.phoneDialCode!.isNotEmpty) {
      await p.setString(_phoneDial, user.phoneDialCode!);
    } else if (isDifferentAccount) {
      await p.remove(_phoneDial);
    }
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      await p.setString(_phoneNum, user.phoneNumber!);
    } else if (isDifferentAccount) {
      await p.remove(_phoneNum);
    }

    if (user.skinTypes.isNotEmpty) {
      await p.setString(_skinTypes, SkinTypeX.encodeList(user.skinTypes));
    } else if (isDifferentAccount) {
      await p.remove(_skinTypes);
    }

    if (user.skinCondition != null) {
      await p.setString(_skin, user.skinCondition!.storageValue);
    } else if (isDifferentAccount) {
      await p.remove(_skin);
    }

    // ── Langganan — selalu ditulis ulang; kalau beda akun & user baru
    // Free, field-nya sudah otomatis benar (key 'free' & null tanggal).
    await p.setString(_plan, user.subscriptionPlan.key);
    await p.setString(_billingCycle, user.billingCycle.key);
    if (user.nextBillingDate != null) {
      await p.setString(_nextBilling, user.nextBillingDate!.toIso8601String());
    } else {
      await p.remove(_nextBilling);
    }

    await p.setBool(_loggedOut, false);
    await _upsertKnownAccount(user);
  }

  static Future<void> updateNameAndPhoto({String? name, String? photo}) async {
    final p = await SharedPreferences.getInstance();
    if (name  != null && name.isNotEmpty)  await p.setString(_name,  name);
    if (photo != null && photo.isNotEmpty) await p.setString(_photo, photo);

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  static Future<void> removePhoto() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_photo);

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  static Future<void> updateBirthDate(DateTime date) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_birth, date.toIso8601String());

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  /// Perbarui alamat. Field khusus Indonesia (RT/RW/Kelurahan/Kecamatan)
  /// opsional — kirim [clearIndonesianFields]=true saat pengguna
  /// berpindah dari negara ID ke luar negeri, supaya data lama dihapus
  /// (bukan sekadar diabaikan).
  static Future<void> updateAddress({
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
    bool clearIndonesianFields = false,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (street     != null && street.isNotEmpty)     await p.setString(_street, street);
    if (unitNumber != null && unitNumber.isNotEmpty)  await p.setString(_unit, unitNumber);
    if (city       != null && city.isNotEmpty)        await p.setString(_city, city);
    if (province   != null && province.isNotEmpty)    await p.setString(_province, province);
    if (postalCode != null && postalCode.isNotEmpty)  await p.setString(_postal, postalCode);
    if (countryIso != null && countryIso.isNotEmpty)  await p.setString(_country, countryIso);

    if (clearIndonesianFields) {
      await p.remove(_rt);
      await p.remove(_rw);
      await p.remove(_kelurahan);
      await p.remove(_kecamatan);
    } else {
      if (rt        != null && rt.isNotEmpty)        await p.setString(_rt, rt);
      if (rw        != null && rw.isNotEmpty)        await p.setString(_rw, rw);
      if (kelurahan != null && kelurahan.isNotEmpty) await p.setString(_kelurahan, kelurahan);
      if (kecamatan != null && kecamatan.isNotEmpty) await p.setString(_kecamatan, kecamatan);
    }

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  static Future<void> updatePhone({
    String? dialCode,
    String? number,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (dialCode != null && dialCode.isNotEmpty) await p.setString(_phoneDial, dialCode);
    if (number   != null && number.isNotEmpty)   await p.setString(_phoneNum, number);

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  static Future<void> updateSkinTypes(List<SkinType> types) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_skinTypes, SkinTypeX.encodeList(types));

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  static Future<void> updateSkinCondition(SkinConditionStatus status) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_skin, status.storageValue);

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  /// Perbarui paket langganan + siklus tagihan. Kirim [nextBillingDate]
  /// = null untuk mengosongkan (dipakai saat downgrade ke Free).
  static Future<void> updateSubscriptionPlan({
    required SubscriptionPlan plan,
    required BillingCycle cycle,
    DateTime? nextBillingDate,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_plan, plan.key);
    await p.setString(_billingCycle, cycle.key);
    if (nextBillingDate != null) {
      await p.setString(_nextBilling, nextBillingDate.toIso8601String());
    } else {
      await p.remove(_nextBilling);
    }

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  static Future<void> updateProfile({
    String? name,
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
    bool clearIndonesianFields = false,
    String? phoneDialCode,
    String? phoneNumber,
    List<SkinType>? skinTypes,
    SkinConditionStatus? skinCondition,
  }) async {
    final p = await SharedPreferences.getInstance();

    if (name != null && name.isNotEmpty) await p.setString(_name, name);
    if (birthDate != null) await p.setString(_birth, birthDate.toIso8601String());
    if (street != null && street.isNotEmpty) await p.setString(_street, street);
    if (unitNumber != null && unitNumber.isNotEmpty) await p.setString(_unit, unitNumber);
    if (city != null && city.isNotEmpty) await p.setString(_city, city);
    if (province != null && province.isNotEmpty) await p.setString(_province, province);
    if (postalCode != null && postalCode.isNotEmpty) await p.setString(_postal, postalCode);
    if (countryIso != null && countryIso.isNotEmpty) await p.setString(_country, countryIso);

    if (clearIndonesianFields) {
      await p.remove(_rt);
      await p.remove(_rw);
      await p.remove(_kelurahan);
      await p.remove(_kecamatan);
    } else {
      if (rt != null && rt.isNotEmpty) await p.setString(_rt, rt);
      if (rw != null && rw.isNotEmpty) await p.setString(_rw, rw);
      if (kelurahan != null && kelurahan.isNotEmpty) await p.setString(_kelurahan, kelurahan);
      if (kecamatan != null && kecamatan.isNotEmpty) await p.setString(_kecamatan, kecamatan);
    }

    if (phoneDialCode != null && phoneDialCode.isNotEmpty) await p.setString(_phoneDial, phoneDialCode);
    if (phoneNumber != null && phoneNumber.isNotEmpty) await p.setString(_phoneNum, phoneNumber);
    if (skinTypes != null) await p.setString(_skinTypes, SkinTypeX.encodeList(skinTypes));
    if (skinCondition != null) await p.setString(_skin, skinCondition.storageValue);

    final user = await getUser();
    if (user != null) await _upsertKnownAccount(user);
  }

  // ══════════════════════════════════════════════
  // READ
  // ══════════════════════════════════════════════

  static Future<UserModel?> getUser() async {
    final p   = await SharedPreferences.getInstance();
    final uid = p.getString(_uid);
    if (uid == null || uid.isEmpty) return null;
    return UserModel(
      uid:       uid,
      email:     p.getString(_email) ?? '',
      name:      p.getString(_name),
      photo:     p.getString(_photo),
      birthDate: p.getString(_birth) != null
          ? DateTime.tryParse(p.getString(_birth)!)
          : null,
      street:        p.getString(_street),
      unitNumber:    p.getString(_unit),
      city:          p.getString(_city),
      province:      p.getString(_province),
      postalCode:    p.getString(_postal),
      countryIso:    p.getString(_country),
      rt:            p.getString(_rt),
      rw:            p.getString(_rw),
      kelurahan:     p.getString(_kelurahan),
      kecamatan:     p.getString(_kecamatan),
      phoneDialCode: p.getString(_phoneDial),
      phoneNumber:   p.getString(_phoneNum),
      skinTypes:     SkinTypeX.decodeList(p.getString(_skinTypes)),
      skinCondition: SkinConditionStatusX.fromStorage(p.getString(_skin)),
      subscriptionPlan: SubscriptionPlan.fromKey(p.getString(_plan)),
      billingCycle:     BillingCycleX.fromKey(p.getString(_billingCycle)),
      nextBillingDate:  p.getString(_nextBilling) != null
          ? DateTime.tryParse(p.getString(_nextBilling)!)
          : null,
    );
  }

  static Future<String?> getName()  async =>
      (await SharedPreferences.getInstance()).getString(_name);

  static Future<String?> getPhoto() async =>
      (await SharedPreferences.getInstance()).getString(_photo);

  static Future<bool> hasCompleteProfile() async {
    final user = await getUser();
    if (user == null || user.uid.isEmpty) return false;
    return user.birthDate != null &&
        user.name != null &&
        user.name!.trim().isNotEmpty;
  }

  // ══════════════════════════════════════════════
  // RIWAYAT AKUN
  // ══════════════════════════════════════════════

  static Future<void> _upsertKnownAccount(UserModel user) async {
    final accounts = await getKnownAccounts();
    accounts.removeWhere((a) => a.uid == user.uid);
    accounts.insert(0, user);

    final p    = await SharedPreferences.getInstance();
    final json = accounts.map((u) => jsonEncode(u.toMap())).toList();
    await p.setStringList(_accountsKey, json);
  }

  static Future<List<UserModel>> getKnownAccounts() async {
    final p    = await SharedPreferences.getInstance();
    final list = p.getStringList(_accountsKey) ?? [];
    return list
        .map((s) => UserModel.fromMap(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<UserModel?> getLastAccount() async {
    final accounts = await getKnownAccounts();
    return accounts.isEmpty ? null : accounts.first;
  }

  // ══════════════════════════════════════════════
  // AUTH STATUS
  // ══════════════════════════════════════════════

  static Future<void> markLoggedIn() async =>
      (await SharedPreferences.getInstance()).setBool(_loggedOut, false);

  static Future<void> markLoggedOut() async =>
      (await SharedPreferences.getInstance()).setBool(_loggedOut, true);

  static Future<bool> isLoggedOut() async =>
      (await SharedPreferences.getInstance()).getBool(_loggedOut) ?? false;

  static Future<bool> isLoggedIn() async => !(await isLoggedOut());

  // ══════════════════════════════════════════════
  // CLEAR
  // ══════════════════════════════════════════════

  static Future<void> clear() async {
    await markLoggedOut();
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_uid);
    await p.remove(_email);
    await p.remove(_name);
    await p.remove(_photo);
    await p.remove(_birth);
    await p.remove(_loggedOut);
    await p.remove(_street);
    await p.remove(_unit);
    await p.remove(_city);
    await p.remove(_province);
    await p.remove(_postal);
    await p.remove(_country);
    await p.remove(_rt);
    await p.remove(_rw);
    await p.remove(_kelurahan);
    await p.remove(_kecamatan);
    await p.remove(_phoneDial);
    await p.remove(_phoneNum);
    await p.remove(_skinTypes);
    await p.remove(_skin);
    await p.remove(_plan);
    await p.remove(_billingCycle);
    await p.remove(_nextBilling);
    await p.remove(_accountsKey);
  }
}