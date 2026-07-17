// ─────────────────────────────────────────────
// features/account/presentation/pages/account_edit_page.dart
// (FULL — foto platform-aware + hapus, alamat kondisional Indonesia/
//  luar negeri dengan RT/RW/Kelurahan/Kecamatan, kode telepon via
//  picker negara, Tipe Kulit multi-select di atas Status Pemahaman)
//
// PEMBARUAN: area foto profil (_EditableIdentityStrip) sekarang bisa
// di-tap DI MANA SAJA (bukan cuma ikon kamera kecil) untuk langsung
// memunculkan dropdown (bottom sheet) Ambil Foto/Pilih dari Galeri/
// Hapus Foto — tidak ada langkah perantara lain.
// ─────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../../app/pages/account/logon/data/witgets/contries.dart';
import '../../../core/models/users/global.dart';
import '../../../core/providers/user/users.dart';
import '../logon/data/avatar.dart';

bool get _isMobileNative {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

// PEMBARUAN: formatter input SAMA seperti di `profile_setup_page.dart`
// supaya aturan input (RT/RW/Kode Pos/No. Telepon hanya angka; Kota/
// Provinsi/Kelurahan/Kecamatan hanya huruf) konsisten di kedua halaman.
final _digitsOnlyFormatter = FilteringTextInputFormatter.digitsOnly;
final _lettersOnlyFormatter =
FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\u00C0-\u024F\s.'-]"));

// PEMBARUAN: dicocokkan lewat NAMA enum (t.name), sama seperti di
// `profile_setup_page.dart`, supaya kalau `SkinType` di
// core/models/users/global.dart bertambah/berkurang, halaman ini
// tetap kompilasi dan otomatis dapat ikon yang sesuai (fallback ikon
// default kalau nama belum terdaftar di sini).
const Map<String, IconData> _skinTypeIconsByName = {
  'normal': Icons.face_outlined,
  'jerawat': Icons.grain,
  'kusam': Icons.blur_on,
  'berminyak': Icons.opacity,
  'kering': Icons.grain_outlined,
  'sensitif': Icons.warning_amber_outlined,
  'kombinasi': Icons.blur_circular,
  'albino': Icons.brightness_7_outlined,
  'kulitHitam': Icons.dark_mode_outlined,
  'komedo': Icons.scatter_plot_outlined,
  'poriBesar': Icons.grid_on_outlined,
  'flek': Icons.gradient_outlined,
  'hiperpigmentasi': Icons.contrast_outlined,
  'kerutan': Icons.waves_outlined,
  'kantungMata': Icons.visibility_outlined,
  'kemerahan': Icons.local_fire_department_outlined,
  'bekasLuka': Icons.healing_outlined,
  'kulitMengelupas': Icons.layers_clear_outlined,
  'milia': Icons.circle_outlined,
  'dermatitis': Icons.coronavirus_outlined,
  'rosacea': Icons.whatshot_outlined,
};

IconData _skinTypeIconFor(SkinType t) =>
    _skinTypeIconsByName[t.name] ?? Icons.circle_outlined;

class AccountEditPage extends StatefulWidget {
  const AccountEditPage({super.key});

  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;

  // ── Alamat — umum ────────────────────────────
  late final TextEditingController _streetCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _postalCtrl;
  String _countryIso = 'ID';

  // ── Alamat — khusus Indonesia ─────────────────
  late final TextEditingController _rtCtrl;
  late final TextEditingController _rwCtrl;
  late final TextEditingController _kelurahanCtrl;
  late final TextEditingController _kecamatanCtrl;

  bool get _isIndonesia => _countryIso.toUpperCase() == 'ID';

  late final TextEditingController _phoneNumCtrl;
  String _phoneCountryIso = 'ID';

  DateTime? _birthDate;
  final Set<SkinType> _skinTypes = {};
  SkinConditionStatus? _skinCondition;

  bool _saving = false;

  /// Alamat dianggap lengkap jika:
  ///  • Indonesia   → Nama Jalan, Blok/No/Unit, RT, RW, Kelurahan,
  ///                  Kecamatan, Kota/Kabupaten, Provinsi, Kode Pos.
  ///  • Luar negeri → Nama Jalan (Address Line 1), City,
  ///                  State/Province, Postal Code.
  bool get _isAddressValid {
    if (_streetCtrl.text.trim().isEmpty) return false;
    if (_cityCtrl.text.trim().isEmpty) return false;
    if (_provinceCtrl.text.trim().isEmpty) return false;
    if (_postalCtrl.text.trim().isEmpty) return false;
    if (_isIndonesia) {
      if (_unitCtrl.text.trim().isEmpty) return false;
      if (_rtCtrl.text.trim().isEmpty) return false;
      if (_rwCtrl.text.trim().isEmpty) return false;
      if (_kelurahanCtrl.text.trim().isEmpty) return false;
      if (_kecamatanCtrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  bool get _isPhoneValid => _phoneNumCtrl.text.trim().isNotEmpty;

  bool get _isSkinConditionValid => _skinCondition != null;

  /// Daftar isian yang masih kurang — dipakai untuk menonaktifkan
  /// tombol "Simpan Perubahan" SEKALIGUS menampilkan alasannya ke
  /// pengguna (lihat `_SaveButton` / `_buildMissingHint`).
  List<String> get _missingRequirements {
    final missing = <String>[];
    if (_nameCtrl.text.trim().isEmpty) missing.add('Nama Lengkap');
    if (_birthDate == null) missing.add('Tanggal Lahir');

    if (_streetCtrl.text.trim().isEmpty) {
      missing.add(_isIndonesia ? 'Nama Jalan' : 'Address Line 1');
    }
    if (_isIndonesia && _unitCtrl.text.trim().isEmpty) {
      missing.add('Blok / No. Rumah / Unit');
    }
    if (_isIndonesia && _rtCtrl.text.trim().isEmpty) missing.add('RT');
    if (_isIndonesia && _rwCtrl.text.trim().isEmpty) missing.add('RW');
    if (_isIndonesia && _kelurahanCtrl.text.trim().isEmpty) {
      missing.add('Kelurahan / Desa');
    }
    if (_isIndonesia && _kecamatanCtrl.text.trim().isEmpty) {
      missing.add('Kecamatan');
    }
    if (_cityCtrl.text.trim().isEmpty) {
      missing.add(_isIndonesia ? 'Kota / Kabupaten' : 'City');
    }
    if (_provinceCtrl.text.trim().isEmpty) {
      missing.add(_isIndonesia ? 'Provinsi' : 'State / Province');
    }
    if (_postalCtrl.text.trim().isEmpty) {
      missing.add(_isIndonesia ? 'Kode Pos' : 'Postal Code');
    }

    if (!_isPhoneValid) missing.add('Nomor WhatsApp');
    if (!_isSkinConditionValid) missing.add('Pemahaman Kondisi Kulit');

    return missing;
  }

  bool get _isValid => _missingRequirements.isEmpty;

  // ── State foto profil ────────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();
  Uint8List? _pickedBytes;
  String?    _pickedPath;
  bool       _photoRemoved = false;

  bool get _hasNewPickedPhoto => _pickedBytes != null || _pickedPath != null;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nameCtrl      = TextEditingController(text: user?.name ?? '');
    _streetCtrl    = TextEditingController(text: user?.street ?? '');
    _unitCtrl      = TextEditingController(text: user?.unitNumber ?? '');
    _cityCtrl      = TextEditingController(text: user?.city ?? '');
    _provinceCtrl  = TextEditingController(text: user?.province ?? '');
    _postalCtrl    = TextEditingController(text: user?.postalCode ?? '');
    _rtCtrl         = TextEditingController(text: user?.rt ?? '');
    _rwCtrl         = TextEditingController(text: user?.rw ?? '');
    _kelurahanCtrl  = TextEditingController(text: user?.kelurahan ?? '');
    _kecamatanCtrl  = TextEditingController(text: user?.kecamatan ?? '');
    _phoneNumCtrl  = TextEditingController(text: user?.phoneNumber ?? '');
    _countryIso       = user?.countryIso ?? 'ID';
    _phoneCountryIso  = countryByDialCode(user?.phoneDialCode).isoCode;
    _birthDate     = user?.birthDate;
    _skinTypes.addAll(user?.skinTypes ?? const []);
    _skinCondition = user?.skinCondition;

    // PERBAIKAN: sebelumnya field alamat & telepon TIDAK punya listener
    // sama sekali, sehingga status "lengkap/belum" pada form ini tidak
    // pernah ter-update saat pengguna mengetik. Sekarang semua field
    // wajib memicu rebuild supaya `_missingRequirements`/`_isValid`
    // (dipakai tombol Simpan) selalu sinkron dengan isi form saat ini.
    for (final c in [
      _nameCtrl,
      _streetCtrl,
      _unitCtrl,
      _cityCtrl,
      _provinceCtrl,
      _postalCtrl,
      _rtCtrl,
      _rwCtrl,
      _kelurahanCtrl,
      _kecamatanCtrl,
      _phoneNumCtrl,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _streetCtrl,
      _unitCtrl,
      _cityCtrl,
      _provinceCtrl,
      _postalCtrl,
      _rtCtrl,
      _rwCtrl,
      _kelurahanCtrl,
      _kecamatanCtrl,
      _phoneNumCtrl,
    ]) {
      c.removeListener(_markDirty);
    }
    _nameCtrl.dispose();
    _streetCtrl.dispose();
    _unitCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _postalCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    _kelurahanCtrl.dispose();
    _kecamatanCtrl.dispose();
    _phoneNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1930),
      lastDate: now,
      helpText: 'Pilih Tanggal Lahir',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  // ── Pilih / Hapus Foto ────────────────────────────────────────────

  Future<void> _openImageSource(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (file == null) return;

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _pickedBytes  = bytes;
          _pickedPath   = null;
          _photoRemoved = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _pickedPath   = file.path;
          _pickedBytes  = null;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedBytes  = null;
      _pickedPath   = null;
      _photoRemoved = true;
    });
  }

  Future<void> _pickPhoto() async {
    final user = context.read<UserProvider>().user;
    final hasCurrentPhoto =
        _hasNewPickedPhoto || (!_photoRemoved && (user?.photo?.isNotEmpty ?? false));
    await _showPhotoOptionsSheet(showRemove: hasCurrentPhoto);
  }

  Future<void> _showPhotoOptionsSheet({required bool showRemove}) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Foto Profil',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            if (_isMobileNative) ...[
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto (Kamera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImageSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImageSource(ImageSource.gallery);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Pilih Foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openImageSource(ImageSource.gallery);
                },
              ),
            ],
            if (showRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _persistPickedPhoto(String uid) async {
    if (!_hasNewPickedPhoto) return null;

    if (kIsWeb) {
      if (_pickedBytes == null) return null;
      return 'data:image/jpg;base64,${base64Encode(_pickedBytes!)}';
    }

    if (_pickedPath == null) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${dir.path}/avatars');
      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }

      final ext = _pickedPath!.contains('.')
          ? _pickedPath!.split('.').last
          : 'jpg';
      final destPath = '${avatarDir.path}/avatar_$uid.$ext';

      final destFile = File(destPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }

      await File(_pickedPath!).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Gagal menyimpan foto ke penyimpanan internal: $e');
      return null;
    }
  }

  // ── Pilih Negara ─────────────────────────────────────────────────

  Future<CountryInfo?> _showCountryPickerSheet({required String title}) {
    return showModalBottomSheet<CountryInfo>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.7,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outline.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: kCountries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = kCountries[i];
                      return ListTile(
                        leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name),
                        trailing: Text(
                          c.dialCode,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx, c),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Save ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    // PERBAIKAN: `_formKey.currentState!.validate()` sebelumnya SELALU
    // lolos karena tidak ada satupun `validator` yang dipasang di field
    // manapun (Nama, Alamat, RT/RW, dst) — jadi validasi itu sebenarnya
    // tidak pernah benar-benar mengecek apa-apa. Sekarang memakai
    // `_isValid` (lihat `_missingRequirements`) yang mengecek Nama,
    // Tanggal Lahir, seluruh field Alamat sesuai negara, No. Telepon,
    // dan Pemahaman Kondisi Kulit.
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    try {
      final provider = context.read<UserProvider>();
      final uid = provider.user?.uid ?? 'unknown';

      if (_hasNewPickedPhoto) {
        final photoToSave = await _persistPickedPhoto(uid);
        if (photoToSave == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan foto, profil tetap disimpan tanpa foto baru.'),
            ),
          );
        } else {
          await provider.updateNameAndPhoto(photo: photoToSave);
        }
      } else if (_photoRemoved) {
        await provider.removePhoto();
      }

      final isIndonesia = _isIndonesia;
      await provider.updateProfile(
        name: _nameCtrl.text.trim(),
        birthDate: _birthDate,
        street: _streetCtrl.text.trim(),
        unitNumber: _unitCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        postalCode: _postalCtrl.text.trim(),
        countryIso: _countryIso,
        rt: isIndonesia ? _rtCtrl.text.trim() : null,
        rw: isIndonesia ? _rwCtrl.text.trim() : null,
        kelurahan: isIndonesia ? _kelurahanCtrl.text.trim() : null,
        kecamatan: isIndonesia ? _kecamatanCtrl.text.trim() : null,
        clearIndonesianFields: !isIndonesia,
        phoneDialCode: countryByIso(_phoneCountryIso).dialCode,
        phoneNumber: _phoneNumCtrl.text.trim(),
        skinTypes: _skinTypes.toList(),
        skinCondition: _skinCondition,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text('Profil berhasil diperbarui.'),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700;
    final user = context.watch<UserProvider>().user;
    final addressCountry = countryByIso(_countryIso);
    final phoneCountry = countryByIso(_phoneCountryIso);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Edit Profil'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 20,
                  vertical: 24,
                ),
                children: [
                  _EditableIdentityStrip(
                    name: _nameCtrl.text.trim().isNotEmpty
                        ? _nameCtrl.text.trim()
                        : (user?.email ?? ''),
                    photo: _photoRemoved ? null : user?.photo,
                    pickedBytes: _pickedBytes,
                    pickedPath: _pickedPath,
                    onTapChangePhoto: _pickPhoto,
                  ),
                  const SizedBox(height: 28),

                  _SectionLabel('Data Pribadi *', icon: Icons.badge_outlined),
                  const SizedBox(height: 10),
                  _EditCard(
                    children: [
                      _ElegantField(
                        controller: _nameCtrl,
                        label: 'Nama Lengkap *',
                        icon: Icons.badge_outlined,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setState(() {}),
                      ),
                      const _FieldDivider(),
                      _DateField(
                        label: 'Tanggal Lahir *',
                        icon: Icons.cake_outlined,
                        value: _birthDate != null
                            ? _formatDate(_birthDate!)
                            : null,
                        onTap: _pickBirthDate,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel('Alamat *', icon: Icons.map_outlined),
                  const SizedBox(height: 10),
                  _EditCard(
                    children: [
                      _ElegantField(
                        controller: _streetCtrl,
                        label: _isIndonesia ? 'Nama Jalan *' : 'Address Line 1 *',
                        icon: Icons.signpost_outlined,
                      ),
                      const _FieldDivider(),
                      _ElegantField(
                        controller: _unitCtrl,
                        label: _isIndonesia
                            ? 'Blok / No. Rumah / Unit *'
                            : 'Unit / Apt / Suite No.',
                        icon: Icons.home_outlined,
                      ),
                      if (_isIndonesia) ...[
                        const _FieldDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ElegantField(
                                  controller: _rtCtrl,
                                  label: 'RT *',
                                  icon: Icons.grid_view_outlined,
                                  keyboardType: TextInputType.number,
                                  dense: true,
                                  inputFormatters: [
                                    _digitsOnlyFormatter,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ElegantField(
                                  controller: _rwCtrl,
                                  label: 'RW *',
                                  icon: Icons.grid_view_outlined,
                                  keyboardType: TextInputType.number,
                                  dense: true,
                                  inputFormatters: [
                                    _digitsOnlyFormatter,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _FieldDivider(),
                        _ElegantField(
                          controller: _kelurahanCtrl,
                          label: 'Kelurahan / Desa *',
                          icon: Icons.holiday_village_outlined,
                          inputFormatters: [_lettersOnlyFormatter],
                        ),
                        const _FieldDivider(),
                        _ElegantField(
                          controller: _kecamatanCtrl,
                          label: 'Kecamatan *',
                          icon: Icons.apartment_outlined,
                          inputFormatters: [_lettersOnlyFormatter],
                        ),
                      ],
                      const _FieldDivider(),
                      _ElegantField(
                        controller: _cityCtrl,
                        label: _isIndonesia ? 'Kota / Kabupaten *' : 'City *',
                        icon: Icons.location_city_outlined,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [_lettersOnlyFormatter],
                      ),
                      const _FieldDivider(),
                      _ElegantField(
                        controller: _provinceCtrl,
                        label: _isIndonesia ? 'Provinsi *' : 'State / Province *',
                        icon: Icons.map_outlined,
                        inputFormatters: [_lettersOnlyFormatter],
                      ),
                      const _FieldDivider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _ElegantField(
                                controller: _postalCtrl,
                                label: _isIndonesia ? 'Kode Pos *' : 'Postal Code *',
                                icon: Icons.markunread_mailbox_outlined,
                                keyboardType: TextInputType.number,
                                dense: true,
                                inputFormatters: [
                                  _digitsOnlyFormatter,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _CountryPickerField(
                                label: 'Negara',
                                value: addressCountry.nameLabel,
                                onTap: () async {
                                  final picked = await _showCountryPickerSheet(
                                    title: 'Pilih Negara',
                                  );
                                  if (picked != null) {
                                    setState(() => _countryIso = picked.isoCode);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel('Kontak WhatsApp *', icon: Icons.chat_outlined),
                  const SizedBox(height: 10),
                  _EditCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 118,
                              child: _CountryPickerField(
                                label: 'Kode',
                                value: phoneCountry.dialLabel,
                                onTap: () async {
                                  final picked = await _showCountryPickerSheet(
                                    title: 'Pilih Kode Negara',
                                  );
                                  if (picked != null) {
                                    setState(() => _phoneCountryIso = picked.isoCode);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ElegantField(
                                controller: _phoneNumCtrl,
                                label: 'Nomor WhatsApp *',
                                icon: Icons.chat_outlined,
                                keyboardType: TextInputType.phone,
                                dense: true,
                                inputFormatters: [
                                  _digitsOnlyFormatter,
                                  LengthLimitingTextInputFormatter(
                                    phoneRuleFor(_phoneCountryIso).maxDigits,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Builder(builder: (context) {
                          final rule = phoneRuleFor(_phoneCountryIso);
                          return Text(
                            'Contoh: ${phoneCountry.dialCode} ${rule.example} '
                                '(${rule.minDigits == rule.maxDigits ? '${rule.minDigits}' : '${rule.minDigits}-${rule.maxDigits}'} digit, angka saja)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel(
                    'Tipe Kulit',
                    icon: Icons.face_retouching_natural_outlined,
                  ),
                  const SizedBox(height: 10),
                  _EditCard(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: SkinType.values.map((t) {
                          final selected = _skinTypes.contains(t);
                          return _EleganChoiceChip(
                            label: t.label,
                            icon: _skinTypeIconFor(t),
                            selected: selected,
                            onTap: () => setState(() {
                              if (selected) {
                                _skinTypes.remove(t);
                              } else {
                                _skinTypes.add(t);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel(
                    'Pemahaman Kondisi Kulit *',
                    icon: Icons.help_outline,
                  ),
                  const SizedBox(height: 10),
                  _EditCard(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: SkinConditionStatus.values.map((status) {
                          final selected = _skinCondition == status;
                          return _EleganChoiceChip(
                            label: status.label,
                            selected: selected,
                            onTap: () =>
                                setState(() => _skinCondition = status),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),
                  _SaveButton(
                    saving: _saving,
                    onPressed: _save,
                    missing: _missingRequirements,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Komponen-komponen UI elegan (reusable)
// ═══════════════════════════════════════════════

class _EditableIdentityStrip extends StatelessWidget {
  const _EditableIdentityStrip({
    required this.name,
    required this.photo,
    required this.pickedBytes,
    required this.pickedPath,
    required this.onTapChangePhoto,
  });

  final String name;
  final String? photo;
  final Uint8List? pickedBytes;
  final String? pickedPath;
  final VoidCallback onTapChangePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ImageProvider? previewProvider;
    if (pickedBytes != null) {
      previewProvider = MemoryImage(pickedBytes!);
    } else if (pickedPath != null && !kIsWeb) {
      previewProvider = FileImage(File(pickedPath!));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.55),
            theme.colorScheme.primaryContainer.withOpacity(0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          // PEMBARUAN: seluruh area foto (bukan cuma ikon kamera kecil)
          // sekarang bisa di-tap untuk langsung memunculkan dropdown
          // (bottom sheet) ganti/hapus foto — tidak ada langkah
          // perantara lain.
          GestureDetector(
            onTap: onTapChangePhoto,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (previewProvider != null)
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.surface,
                    backgroundImage: previewProvider,
                  )
                else
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.surface,
                    child: ClipOval(child: UserAvatar(photo: photo, radius: 28)),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Profil Anda',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ketuk foto untuk ganti / hapus foto',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
    );
  }
}

class _ElegantField extends StatelessWidget {
  const _ElegantField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.dense = false,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool dense;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: dense
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          prefixIcon: Icon(icon, size: 19, color: theme.colorScheme.primary),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          suffixIcon: Icon(
            Icons.expand_more,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
        ),
        child: Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            labelStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            prefixIcon: Icon(icon, size: 19, color: theme.colorScheme.primary),
            suffixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: Text(
            value ?? 'Pilih tanggal lahir',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: value != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

class _EleganChoiceChip extends StatelessWidget {
  const _EleganChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withOpacity(0.6),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.onPressed,
    this.missing = const [],
  });

  final bool saving;
  final VoidCallback onPressed;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = missing.isEmpty && !saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ]
                : [],
          ),
          child: FilledButton(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            child: saving
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
                : const Text('Simpan Perubahan'),
          ),
        ),
        if (missing.isNotEmpty && !saving) ...[
          const SizedBox(height: 8),
          Text(
            'Lengkapi dulu: ${missing.join(', ')}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}