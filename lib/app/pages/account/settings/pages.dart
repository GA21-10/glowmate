import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/language.dart';
import '../../../core/providers/settings/biometric.dart';
import '../../../core/providers/settings/language.dart';
import '../../../core/providers/theme/app.dart';
import '../../../core/swich/l10n.dart';
import '../../../core/swich/trans.dart';
import '../logon/legals/privacy/polecy.dart';
import '../logon/legals/term/use.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs            = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final bioProvider   = context.watch<BiometricProvider>();
    final langProvider  = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tampilan ────────────────────────────────────
          _SectionHeader(label: context.tr('section_display')),

          Card(
            child: Column(
              children: [
                // Mode Tema
                ListTile(
                  leading: Icon(
                    themeProvider.isDark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    color: cs.primary,
                  ),
                  title: Text(context.tr('dark_theme')),
                  subtitle: Text(
                    themeProvider.mode == ThemeMode.system
                        ? context.tr('dark_theme_system')
                        : themeProvider.isDark
                        ? context.tr('dark_theme_active')
                        : context.tr('dark_theme_inactive'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Switch(
                    value: themeProvider.isDark,
                    activeColor: cs.primary,
                    onChanged: (_) => themeProvider.toggle(),
                  ),
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // Pilihan tema lengkap
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: cs.primary),
                  title: Text(context.tr('theme_mode')),
                  trailing: DropdownButton<ThemeMode>(
                    value: themeProvider.mode,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(context.tr('theme_mode_auto')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(context.tr('theme_mode_light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(context.tr('theme_mode_dark')),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) themeProvider.setMode(mode);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Bahasa ──────────────────────────────────────
          // Default bahasa mengikuti lokasi/GPS & region yang tertera
          // di sistem perangkat (lihat LanguageService); kalau tidak
          // terdeteksi, default ke Amerika Serikat (English). Setelah
          // pengguna memilih manual di sini, pilihan itu tersimpan dan
          // tidak ditimpa lagi oleh deteksi otomatis.
          _SectionHeader(label: context.tr('section_language')),
          Card(
            child: ListTile(
              leading: Icon(Icons.language, color: cs.primary),
              title: Text(context.tr('app_language')),
              // NB: `langProvider.current.label` (nama bahasa) BUKAN
              // data otentik pengguna — boleh ditampilkan langsung.
              subtitle: Text(
                langProvider.isAutoDetected
                    ? '${langProvider.current.label} · ${context.tr('auto_detected_suffix')}'
                    : langProvider.current.label,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLanguagePicker(context, langProvider),
            ),
          ),

          const SizedBox(height: 20),

          // ── Keamanan ────────────────────────────────────
          // gunakan bioProvider.isSupported (bukan _isMobile), karena
          // isSupported sudah mengurus 3 kondisi dengan benar:
          //   • web            → LocalAuthKind.none  → false → hidden
          //   • android/iOS    → LocalAuthKind.biometric → true kalau ada
          //     sidik jari/face id terdaftar
          //   • windows/macOS  → LocalAuthKind.devicePin → true kalau
          //     device mendukung PIN/password sistem
          if (bioProvider.isSupported) ...[
            _SectionHeader(label: context.tr('section_security')),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      bioProvider.icon,
                      color: bioProvider.available
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.3),
                    ),
                    // NB: bioProvider.label (mis. "Face ID", "Sidik
                    // Jari") adalah nama fitur perangkat, bukan data
                    // pengguna — tetap ditampilkan apa adanya.
                    title: Text(bioProvider.label),
                    subtitle: Text(
                      bioProvider.available
                          ? (bioProvider.enabled
                          ? context.tr('biometric_active_with_label',
                          params: {'label': bioProvider.label.toLowerCase()})
                          : context.tr('biometric_inactive'))
                          : (bioProvider.lastError ??
                          context.tr('biometric_unavailable_default')),
                      style: TextStyle(
                        fontSize: 12,
                        color: bioProvider.available ? null : cs.error,
                      ),
                    ),
                    trailing: bioProvider.available
                        ? Switch(
                      value: bioProvider.enabled,
                      activeColor: cs.primary,
                      onChanged: (val) => _handleToggle(context, bioProvider, val),
                    )
                    // kalau available=false, tampilkan tombol refresh,
                    // BUKAN switch mati permanen — supaya bisa retry
                    // setelah, misal, mendaftarkan sidik jari di HP.
                        : IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: context.tr('retry_detect'),
                      onPressed: () => bioProvider.load(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Tentang ─────────────────────────────────────
          _SectionHeader(label: context.tr('section_about')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: cs.primary),
                  title: Text(context.tr('app_version')),
                  trailing: const Text('1.0.0', style: TextStyle(fontSize: 13)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
                  title: Text(context.tr('privacy_policy')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage()),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.article_outlined, color: cs.primary),
                  title: Text(context.tr('terms_of_service')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsOfServicePage()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggle(
      BuildContext context,
      BiometricProvider bioProvider,
      bool wantEnabled,
      ) async {
    final result = await bioProvider.requestToggle(wantEnabled);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final msg = switch (result) {
      ToggleResult.success => wantEnabled
          ? context.trRead('toggle_enabled_with_label', params: {'label': bioProvider.label})
          : context.trRead('toggle_disabled_with_label', params: {'label': bioProvider.label}),
      ToggleResult.cancelledByUser => context.trRead('toggle_cancelled'),
      ToggleResult.notAvailable => context.trRead('toggle_not_available'),
      ToggleResult.failed => context.trRead('toggle_failed'),
    };
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Tampilkan bottom sheet daftar bahasa (diturunkan dari
  /// countries.dart lewat `LanguageProvider.supported`). Memilih salah
  /// satu langsung memanggil `setLanguage()` & menutup sheet.
  void _showLanguagePicker(BuildContext context, LanguageProvider langProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      sheetContext.tr('choose_language'),
                      style: Theme.of(sheetContext)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (!langProvider.isAutoDetected)
                      TextButton.icon(
                        icon: const Icon(Icons.my_location, size: 16),
                        label: Text(sheetContext.tr('automatic')),
                        onPressed: () {
                          langProvider.resetToAutoDetect();
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: langProvider.supported.length,
                  itemBuilder: (context, index) {
                    final LanguageInfo lang = langProvider.supported[index];
                    final bool selected = lang.code == langProvider.current.code;
                    return ListTile(
                      leading: Text(lang.flag, style: const TextStyle(fontSize: 22)),
                      // Nama bahasa (native & English) — bukan data
                      // pengguna, jadi ditampilkan apa adanya.
                      title: Text(lang.name),
                      subtitle: Text(lang.englishName, style: const TextStyle(fontSize: 12)),
                      trailing: selected
                          ? Icon(Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        langProvider.setLanguage(lang.code);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}