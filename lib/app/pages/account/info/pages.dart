// ─────────────────────────────────────────────
// features/account/presentation/pages/account_info_page.dart
// (FULL — foto via UserAvatar bersama + tap untuk lihat foto penuh,
//  urutan: Foto -> Data Pribadi -> Kondisi Kulit -> Kontak -> Alamat)
// ─────────────────────────────────────────────
//
// Halaman Info Akun — READ-ONLY, tanpa aksi navigasi/edit.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/pages/account/logon/data/witgets/contries.dart';
import '../../../core/models/users/global.dart';
import '../../../core/providers/user/users.dart';
import '../logon/data/avatar.dart'; // widget UserAvatar bersama

class AccountInfoPage extends StatelessWidget {
  const AccountInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Akun'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Theme.of(context).colorScheme.surface,
      ),
      body: Consumer<UserProvider>(
        builder: (context, provider, _) {
          final user = provider.user;
          if (user == null) {
            return const _EmptyAccountState();
          }
          return _AccountInfoBody(user: user);
        },
      ),
    );
  }
}

class _EmptyAccountState extends StatelessWidget {
  const _EmptyAccountState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Data akun tidak ditemukan.\nSilakan masuk (login) terlebih dahulu.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountInfoBody extends StatelessWidget {
  const _AccountInfoBody({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 20,
              vertical: 24,
            ),
            children: [
              // 1. Foto profil (tap untuk lihat penuh)
              _ProfileHeader(user: user),
              const SizedBox(height: 28),

              // 2. Data Pribadi
              _SectionLabel('Data Pribadi', icon: Icons.badge_outlined),
              const SizedBox(height: 10),
              _InfoCard(
                children: [
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Nama Lengkap',
                    value: user.name,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email.isNotEmpty ? user.email : null,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.cake_outlined,
                    label: 'Tanggal Lahir',
                    value: user.birthDate != null
                        ? _formatDate(user.birthDate!)
                        : null,
                    // Usia: Tahun, Bulan, Hari
                    subtitle: user.ageLabel,
                  ),
                ],
              ),

              // 3. Kondisi Kulit
              const SizedBox(height: 20),
              _SectionLabel(
                'Kondisi Kulit',
                icon: Icons.face_retouching_natural_outlined,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                children: [
                  _SkinTypeTile(skinTypes: user.skinTypes),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.help_outline,
                    label: 'Status Pemahaman',
                    value: user.skinCondition?.label,
                  ),
                ],
              ),

              // 4. Kontak
              const SizedBox(height: 20),
              _SectionLabel('Kontak', icon: Icons.chat_outlined),
              const SizedBox(height: 10),
              _InfoCard(
                children: [
                  _InfoTile(
                    icon: Icons.chat_outlined,
                    label: 'No. WhatsApp Aktif',
                    value: user.fullPhone,
                  ),
                ],
              ),

              // 5. Alamat
              const SizedBox(height: 20),
              _SectionLabel('Alamat', icon: Icons.map_outlined),
              const SizedBox(height: 10),
              _InfoCard(
                children: user.isIndonesianAddress
                    ? [
                  _InfoTile(
                    icon: Icons.signpost_outlined,
                    label: 'Nama Jalan',
                    value: user.street,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.home_outlined,
                    label: 'Blok / No. Rumah / Unit',
                    value: user.unitNumber,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.grid_view_outlined,
                    label: 'RT / RW',
                    value: (user.rt?.isNotEmpty ?? false) ||
                        (user.rw?.isNotEmpty ?? false)
                        ? 'RT ${(user.rt?.isNotEmpty ?? false) ? user.rt : '-'} / '
                        'RW ${(user.rw?.isNotEmpty ?? false) ? user.rw : '-'}'
                        : null,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.holiday_village_outlined,
                    label: 'Kelurahan / Desa',
                    value: user.kelurahan,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.apartment_outlined,
                    label: 'Kecamatan',
                    value: user.kecamatan,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.location_city_outlined,
                    label: 'Kota / Kabupaten',
                    value: user.city,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.map_outlined,
                    label: 'Provinsi',
                    value: user.province,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.markunread_mailbox_outlined,
                    label: 'Kode Pos',
                    value: user.postalCode,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.public_outlined,
                    label: 'Negara',
                    value: (user.countryIso?.isNotEmpty ?? false)
                        ? countryByIso(user.countryIso).nameLabel
                        : null,
                  ),
                ]
                    : [
                  _InfoTile(
                    icon: Icons.signpost_outlined,
                    label: 'Street',
                    value: user.street,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.home_outlined,
                    label: 'Unit / Apt / Suite No.',
                    value: user.unitNumber,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.location_city_outlined,
                    label: 'City',
                    value: user.city,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.map_outlined,
                    label: 'State / Province',
                    value: user.province,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.markunread_mailbox_outlined,
                    label: 'Postal Code',
                    value: user.postalCode,
                  ),
                  const _InfoDivider(),
                  _InfoTile(
                    icon: Icons.public_outlined,
                    label: 'Country',
                    value: (user.countryIso?.isNotEmpty ?? false)
                        ? countryByIso(user.countryIso).nameLabel
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  void _openFullPhoto(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // Foto full, bisa di-pinch zoom
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: ClipOval(
                    child: UserAvatar(photo: user.photo, radius: 140),
                  ),
                ),
              ),
              // Tombol tutup
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = user.photo != null;

    return Column(
      children: [
        GestureDetector(
          onTap: hasPhoto ? () => _openFullPhoto(context) : null,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.25),
                width: 2,
              ),
            ),
            // UserAvatar bersama: file lokal, base64 (Web), URL jaringan —
            // dengan fallback ikon default yang aman.
            child: UserAvatar(photo: user.photo, radius: 48),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          user.hasName ? user.name! : 'Nama belum diisi',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: user.hasName ? null : theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
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

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? subtitle;

  bool get _isEmpty => value == null || value!.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 3),
                if (_isEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 15, color: theme.colorScheme.error),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Anda belum isi data. Silahkan edit terlebih dahulu.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    value!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (!_isEmpty && subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
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

/// Tile khusus Tipe Kulit (multi-value), ditampilkan sebagai chip.
class _SkinTypeTile extends StatelessWidget {
  const _SkinTypeTile({required this.skinTypes});

  final List<SkinType> skinTypes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = skinTypes.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.face_retouching_natural_outlined,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipe Kulit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 6),
                if (isEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 15, color: theme.colorScheme.error),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Anda belum isi data. Silahkan edit terlebih dahulu.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skinTypes
                        .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.primary
                              .withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        t.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}