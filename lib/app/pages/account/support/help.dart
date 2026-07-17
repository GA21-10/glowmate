// ─────────────────────────────────────────────
// app/pages/dukungan/help_center_page.dart
// ─────────────────────────────────────────────
// Pusat Bantuan: aksi cepat kontak, kategori topik, dan pintasan ke FAQ.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'faq.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  void _openFaq(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FaqPage()),
    );
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disalin ke clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Bantuan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _HeroCard(onOpenFaq: () => _openFaq(context)),
            const SizedBox(height: 20),
            Text(
              'Hubungi Kami',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              title: 'Email Dukungan',
              value: 'support@glowmate.app',
              hint: 'Balasan dalam 1x24 jam kerja',
              onTap: () => _copyToClipboard(context, 'support@glowmate.app', 'Email'),
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'WhatsApp',
              value: '+62 812-3456-7890',
              hint: 'Senin–Jumat, 09.00–18.00 WIB',
              onTap: () => _copyToClipboard(context, '+6281234567890', 'Nomor WhatsApp'),
            ),
            const SizedBox(height: 10),
            _ContactRow(
              icon: Icons.public_rounded,
              title: 'Pusat Bantuan Online',
              value: 'help.glowmate.app',
              hint: 'Artikel & panduan lengkap',
              onTap: () => _copyToClipboard(context, 'https://help.glowmate.app', 'Tautan'),
            ),
            const SizedBox(height: 24),
            Text(
              'Topik Bantuan',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _TopicGrid(onTap: () => _openFaq(context)),
            const SizedBox(height: 24),
            _EmergencyCard(),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onOpenFaq});
  final VoidCallback onOpenFaq;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withOpacity(0.95), cs.primary.withOpacity(0.65)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.onPrimary.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent_rounded, color: cs.onPrimary, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            'Ada yang Bisa Kami Bantu?',
            style: TextStyle(color: cs.onPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Cari jawaban cepat di FAQ, atau hubungi tim dukungan kami '
                'langsung.',
            style: TextStyle(color: cs.onPrimary.withOpacity(0.9), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onOpenFaq,
            icon: const Icon(Icons.quiz_outlined, size: 18),
            label: const Text('Buka FAQ'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.onPrimary,
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outline.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(hint,
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 16, color: cs.onSurface.withOpacity(0.35)),
          ],
        ),
      ),
    );
  }
}

class _TopicGrid extends StatelessWidget {
  const _TopicGrid({required this.onTap});
  final VoidCallback onTap;

  static const _topics = [
    (Icons.camera_alt_rounded, 'Kamera & Analisis Wajah'),
    (Icons.privacy_tip_rounded, 'Privasi & Data'),
    (Icons.spa_rounded, 'Rekomendasi Kandungan'),
    (Icons.account_circle_rounded, 'Akun & Login'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: _topics.map((topic) {
        final (icon, label) = topic;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: cs.primary),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.emergency_outlined, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mengalami reaksi kulit serius atau masalah medis? Segera '
                  'hubungi dokter kulit/dermatolog terdekat — jangan menunggu '
                  'balasan dari tim dukungan aplikasi.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: cs.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}