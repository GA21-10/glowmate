// ─────────────────────────────────────────────
// core/providers/user/users.dart
// (UPDATE: updateAddress/updateProfile — RT, RW, Kelurahan, Kecamatan +
//  clearIndonesianFields untuk perpindahan negara ID → luar negeri)
// (UPDATE: updateSubscriptionPlan — plan + siklus tagihan + tanggal
//  tagihan berikutnya, sinkron real-time via notifyListeners)
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../pages/account/paket/model/berlangganan.dart';
import '../../models/users/global.dart';
import '../../services/local.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;

  UserModel? get user            => _user;
  String?    get name            => _user?.name;
  String?    get photo           => _user?.photo;
  String?    get email           => _user?.email;
  String?    get uid             => _user?.uid;
  bool       get hasUser         => _user != null;

  SubscriptionPlan get subscriptionPlan =>
      _user?.subscriptionPlan ?? SubscriptionPlan.free;
  BillingCycle get billingCycle =>
      _user?.billingCycle ?? BillingCycle.monthly;
  DateTime? get nextBillingDate => _user?.nextBillingDate;

  Future<void> loadFromLocal() async {
    _user = await UserLocalService.getUser();
    notifyListeners();
  }

  Future<void> setUser(UserModel user) async {
    final existing = await UserLocalService.getUser();
    if (existing != null && existing.uid == user.uid) {
      _user = UserModel(
        uid:            user.uid,
        email:          user.email.isNotEmpty ? user.email : existing.email,
        name:           existing.name  ?? user.name,
        photo:          existing.photo ?? user.photo,
        birthDate:      existing.birthDate,
        street:         existing.street,
        unitNumber:     existing.unitNumber,
        city:           existing.city,
        province:       existing.province,
        postalCode:     existing.postalCode,
        countryIso:     existing.countryIso,
        rt:             existing.rt,
        rw:             existing.rw,
        kelurahan:      existing.kelurahan,
        kecamatan:      existing.kecamatan,
        phoneDialCode:  existing.phoneDialCode,
        phoneNumber:    existing.phoneNumber,
        skinTypes:      existing.skinTypes,
        skinCondition:  existing.skinCondition,
        subscriptionPlan: existing.subscriptionPlan,
        billingCycle:     existing.billingCycle,
        nextBillingDate:  existing.nextBillingDate,
      );
    } else {
      _user = user;
    }
    await UserLocalService.saveUser(_user!);
    await UserLocalService.markLoggedIn();
    notifyListeners();
  }

  Future<void> updateNameAndPhoto({String? name, String? photo}) async {
    if (_user == null) return;
    _user = _user!.copyWith(name: name, photo: photo);
    await UserLocalService.updateNameAndPhoto(name: name, photo: photo);
    notifyListeners();
  }

  Future<void> removePhoto() async {
    if (_user == null) return;
    _user = _user!.copyWithPhotoCleared();
    await UserLocalService.removePhoto();
    notifyListeners();
  }

  Future<void> updateBirthDate(DateTime date) async {
    if (_user == null) return;
    _user = _user!.copyWith(birthDate: date);
    await UserLocalService.updateBirthDate(date);
    notifyListeners();
  }

  /// Perbarui alamat. Kirim [clearIndonesianFields]=true saat pengguna
  /// mengganti negara dari Indonesia ke luar negeri — RT/RW/Kelurahan/
  /// Kecamatan akan benar-benar dikosongkan (bukan sekadar diabaikan).
  Future<void> updateAddress({
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
    if (_user == null) return;

    _user = clearIndonesianFields
        ? _user!
        .copyWithIndonesianFieldsCleared()
        .copyWith(
      street: street,
      unitNumber: unitNumber,
      city: city,
      province: province,
      postalCode: postalCode,
      countryIso: countryIso,
    )
        : _user!.copyWith(
      street:     street,
      unitNumber: unitNumber,
      city:       city,
      province:   province,
      postalCode: postalCode,
      countryIso: countryIso,
      rt:         rt,
      rw:         rw,
      kelurahan:  kelurahan,
      kecamatan:  kecamatan,
    );

    await UserLocalService.updateAddress(
      street:     street,
      unitNumber: unitNumber,
      city:       city,
      province:   province,
      postalCode: postalCode,
      countryIso: countryIso,
      rt:         rt,
      rw:         rw,
      kelurahan:  kelurahan,
      kecamatan:  kecamatan,
      clearIndonesianFields: clearIndonesianFields,
    );
    notifyListeners();
  }

  Future<void> updatePhone({String? dialCode, String? number}) async {
    if (_user == null) return;
    _user = _user!.copyWith(phoneDialCode: dialCode, phoneNumber: number);
    await UserLocalService.updatePhone(dialCode: dialCode, number: number);
    notifyListeners();
  }

  Future<void> updateSkinTypes(List<SkinType> types) async {
    if (_user == null) return;
    _user = _user!.copyWith(skinTypes: types);
    await UserLocalService.updateSkinTypes(types);
    notifyListeners();
  }

  Future<void> updateSkinCondition(SkinConditionStatus status) async {
    if (_user == null) return;
    _user = _user!.copyWith(skinCondition: status);
    await UserLocalService.updateSkinCondition(status);
    notifyListeners();
  }

  /// Ganti paket langganan + siklus tagihan (Bulanan/Tahunan).
  /// - Kalau [plan] Free → tanggal tagihan berikutnya otomatis
  ///   dikosongkan & siklus balik ke `monthly`.
  /// - Kalau [plan] berbayar → tanggal tagihan berikutnya dihitung dari
  ///   sekarang sesuai [cycle] (mis. tahunan → +1 tahun dari hari ini).
  ///
  /// `notifyListeners()` di akhir memastikan `AccountPage` &
  /// `SubscriptionPage` (yang sama-sama `context.watch<UserProvider>()`)
  /// langsung ter-update tanpa perlu navigasi ulang.
  Future<void> updateSubscriptionPlan(
      SubscriptionPlan plan,
      BillingCycle cycle,
      ) async {
    if (_user == null) return;

    if (plan.isFree) {
      _user = _user!.copyWithPlanCleared();
      await UserLocalService.updateSubscriptionPlan(
        plan: SubscriptionPlan.free,
        cycle: BillingCycle.monthly,
        nextBillingDate: null,
      );
      notifyListeners();
      return;
    }

    final nextBilling = cycle.nextBillingFrom(DateTime.now());

    _user = _user!.copyWith(
      subscriptionPlan: plan,
      billingCycle: cycle,
      nextBillingDate: nextBilling,
    );

    await UserLocalService.updateSubscriptionPlan(
      plan: plan,
      cycle: cycle,
      nextBillingDate: nextBilling,
    );

    notifyListeners();
  }

  Future<void> updateProfile({
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
    if (_user == null) return;

    var updated = _user!.copyWith(
      name:           (name != null && name.isNotEmpty) ? name : null,
      birthDate:      birthDate,
      street:         (street != null && street.isNotEmpty) ? street : null,
      unitNumber:     (unitNumber != null && unitNumber.isNotEmpty) ? unitNumber : null,
      city:           (city != null && city.isNotEmpty) ? city : null,
      province:       (province != null && province.isNotEmpty) ? province : null,
      postalCode:     (postalCode != null && postalCode.isNotEmpty) ? postalCode : null,
      countryIso:     (countryIso != null && countryIso.isNotEmpty) ? countryIso : null,
      phoneDialCode:  (phoneDialCode != null && phoneDialCode.isNotEmpty) ? phoneDialCode : null,
      phoneNumber:    (phoneNumber != null && phoneNumber.isNotEmpty) ? phoneNumber : null,
      skinTypes:      skinTypes,
      skinCondition:  skinCondition,
    );

    if (clearIndonesianFields) {
      updated = updated.copyWithIndonesianFieldsCleared();
    } else {
      updated = updated.copyWith(
        rt:        (rt != null && rt.isNotEmpty) ? rt : null,
        rw:        (rw != null && rw.isNotEmpty) ? rw : null,
        kelurahan: (kelurahan != null && kelurahan.isNotEmpty) ? kelurahan : null,
        kecamatan: (kecamatan != null && kecamatan.isNotEmpty) ? kecamatan : null,
      );
    }

    _user = updated;

    await UserLocalService.updateProfile(
      name:           name,
      birthDate:      birthDate,
      street:         street,
      unitNumber:     unitNumber,
      city:           city,
      province:       province,
      postalCode:     postalCode,
      countryIso:     countryIso,
      rt:             rt,
      rw:             rw,
      kelurahan:      kelurahan,
      kecamatan:      kecamatan,
      clearIndonesianFields: clearIndonesianFields,
      phoneDialCode:  phoneDialCode,
      phoneNumber:    phoneNumber,
      skinTypes:      skinTypes,
      skinCondition:  skinCondition,
    );

    notifyListeners();
  }

  Future<void> refresh() async => loadFromLocal();

  Future<void> clear() async {
    _user = null;
    await UserLocalService.markLoggedOut();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _user = null;
    await UserLocalService.clearAll();
    notifyListeners();
  }
}