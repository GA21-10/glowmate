// ─────────────────────────────────────────────
// app/pages/account/paket/subscription_page.dart
// ─────────────────────────────────────────────
//
// Halaman pemilihan paket berlangganan.
//
// • Toggle Bulanan / Tahunan di atas (mengubah `BillingCycle` yang
//   dipakai untuk menghitung harga & tanggal tagihan berikutnya).
// • Kartu untuk tiap `SubscriptionPlan` (Free, Pro, Max, Premium)
//   menampilkan harga, fitur, badge hemat (untuk tahunan), dan
//   badge "Paket Aktif" bila itu paket yang sedang dipakai user.
// • Tap paket yang BUKAN paket aktif → dialog konfirmasi → panggil
//   `UserProvider.updateSubscriptionPlan(plan, cycle)`.
//   - Kalau plan Free  → provider otomatis membersihkan
//     billingCycle (balik ke monthly) & nextBillingDate (null).
//   - Kalau plan berbayar → provider otomatis menghitung
//     nextBillingDate dari sekarang sesuai `cycle` yang dikirim.
//   Jadi halaman ini TIDAK perlu menghitung nextBillingDate sendiri.
//
// Karena `AccountPage` membaca `UserProvider` lewat `context.watch`,
// begitu `updateSubscriptionPlan` memanggil `notifyListeners()`,
// field paket di AccountPage otomatis ikut ter-update (real time),
// tanpa perlu navigasi ulang atau refresh manual.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:glowmate/app/core/providers/user/users.dart';
import 'model/berlangganan.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  BillingCycle _cycle = BillingCycle.monthly;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentPlan = userProvider.subscriptionPlan;

    return Scaffold(
      appBar: AppBar(title: const Text('Paket Berlangganan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CycleToggle(
                    cycle: _cycle,
                    onChanged: (c) => setState(() => _cycle = c),
                  ),
                  const SizedBox(height: 20),
                  for (final plan in SubscriptionPlan.values) ...[
                    _PlanCard(
                      plan: plan,
                      cycle: _cycle,
                      isActive: plan == currentPlan,
                      isSaving: _isSaving,
                      onSelect: () => _onSelectPlan(context, plan, currentPlan),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSelectPlan(
      BuildContext context,
      SubscriptionPlan plan,
      SubscriptionPlan currentPlan,
      ) async {
    if (plan == currentPlan || _isSaving) return;

    final isDowngradeToFree = plan.isFree;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isDowngradeToFree ? 'Turunkan ke Free' : 'Konfirmasi Paket'),
        content: Text(
          isDowngradeToFree
              ? 'Anda akan berhenti berlangganan dan kembali ke paket Free. Lanjutkan?'
              : 'Anda akan berlangganan paket ${plan.label} '
              '(${plan.priceLabel(_cycle)}). Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isSaving = true);

    try {
      // `updateSubscriptionPlan` sudah menangani sendiri kapan
      // nextBillingDate dihitung ulang (paid) atau dikosongkan (free).
      await context.read<UserProvider>().updateSubscriptionPlan(plan, _cycle);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDowngradeToFree
                ? 'Berhasil kembali ke paket Free'
                : 'Berhasil berlangganan paket ${plan.label}',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui paket: $e')),
      );
    } finally {
      if (context.mounted) setState(() => _isSaving = false);
    }
  }
}

// ─────────────────────────────────────────────
// Toggle Bulanan / Tahunan.
// ─────────────────────────────────────────────
class _CycleToggle extends StatelessWidget {
  const _CycleToggle({required this.cycle, required this.onChanged});

  final BillingCycle cycle;
  final ValueChanged<BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget segment(BillingCycle value, String label) {
      final selected = cycle == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          segment(BillingCycle.monthly, 'Bulanan'),
          segment(BillingCycle.yearly, 'Tahunan'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Kartu satu paket.
// ─────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.isActive,
    required this.isSaving,
    required this.onSelect,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final bool isActive;
  final bool isSaving;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final savings = plan.yearlySavingsPercent;
    final showSavingsBadge = cycle == BillingCycle.yearly && savings > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? cs.primary : cs.outlineVariant.withOpacity(0.35),
          width: isActive ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Paket Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                )
              else if (showSavingsBadge)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hemat $savings%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            plan.priceLabel(cycle),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(feature)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActive || isSaving ? null : onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? cs.surfaceContainerHighest : cs.primary,
                foregroundColor: isActive ? cs.onSurfaceVariant : cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                isActive
                    ? 'Paket Aktif'
                    : plan.isFree
                    ? 'Turunkan ke Free'
                    : 'Pilih Paket ${plan.label}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}