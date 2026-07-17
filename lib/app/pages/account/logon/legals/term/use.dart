// ─────────────────────────────────────────────
// app/account/settings/legal/terms_page.dart
// ─────────────────────────────────────────────
// Syarat & Ketentuan Layanan -- termasuk aturan penggunaan kamera,
// analisis wajah, dan batas tanggung jawab hasil analisis kulit.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const _lastUpdated = '12 Juli 2026';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Syarat Layanan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _HeaderCard(
              icon: Icons.gavel_rounded,
              title: 'Syarat & Ketentuan Layanan',
              subtitle:
              'Aturan penggunaan Glowmate, termasuk fitur kamera & '
                  'analisis wajah, sebelum Anda mulai menggunakan aplikasi '
                  'ini.',
              lastUpdated: _lastUpdated,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Glowmate BUKAN alat medis dan hasil analisisnya '
                          'BUKAN diagnosis dokter. Selalu konsultasikan masalah '
                          'kulit serius ke dokter kulit/dermatolog bersertifikat.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Selengkapnya',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ..._sections.map((s) => _SectionTile(section: s)),
            const SizedBox(height: 24),
            _ContactCard(
              title: 'Pertanyaan tentang ketentuan ini?',
              body:
              'Tim kami siap membantu menjelaskan bagian mana pun dari '
                  'Syarat Layanan ini yang kurang jelas bagi Anda.',
              email: 'legal@glowmate.app',
            ),
          ],
        ),
      ),
    );
  }
}

final List<_LegalSection> _sections = [
  _LegalSection(
    icon: Icons.handshake_rounded,
    title: '1. Penerimaan Ketentuan',
    paragraphs: [
      'Dengan membuat akun, membuka kamera, atau menggunakan fitur '
          'apa pun di Glowmate, Anda menyatakan telah membaca, memahami, '
          'dan menyetujui seluruh Syarat Layanan ini beserta Kebijakan '
          'Privasi yang menyertainya. Jika Anda tidak setuju dengan salah '
          'satu ketentuan, mohon untuk tidak menggunakan aplikasi ini.',
    ],
  ),
  _LegalSection(
    icon: Icons.spa_rounded,
    title: '2. Deskripsi Layanan',
    paragraphs: [
      'Glowmate adalah aplikasi yang membantu Anda memantau kondisi '
          'kulit wajah dari waktu ke waktu menggunakan kamera perangkat, '
          'serta memberikan rekomendasi kandungan & produk skincare '
          'berdasarkan hasil deteksi. Layanan meliputi:',
    ],
    bullets: [
      'Deteksi & rekonstruksi wajah 3D lewat kamera perangkat.',
      'Pencatatan riwayat kondisi kulit dan grafik tingkat kesehatan '
          'kulit.',
      'Rekomendasi kandungan aktif & produk skincare berbasis katalog '
          'internal aplikasi.',
    ],
  ),
  _LegalSection(
    icon: Icons.camera_alt_rounded,
    title: '3. Izin Kamera & Penggunaan Perangkat',
    bullets: [
      'Fitur analisis wajah memerlukan izin akses kamera perangkat Anda. '
          'Izin ini hanya digunakan untuk mengambil foto/mendeteksi wajah '
          'saat Anda secara aktif membuka halaman kamera — kamera TIDAK '
          'aktif di latar belakang.',
      'Anda bertanggung jawab memastikan hanya wajah Anda sendiri (atau '
          'wajah orang yang telah memberi izin) yang diambil melalui fitur '
          'ini.',
      'Anda dapat mencabut izin kamera kapan saja lewat pengaturan '
          'perangkat; fitur deteksi wajah otomatis akan berhenti berfungsi '
          'sampai izin diberikan kembali.',
      'Kualitas hasil deteksi (pencahayaan, sudut wajah, resolusi kamera) '
          'dapat memengaruhi akurasi rekonstruksi 3D & analisis kulit.',
    ],
  ),
  _LegalSection(
    icon: Icons.medical_information_outlined,
    title: '4. Bukan Nasihat Medis',
    paragraphs: [
      'Seluruh hasil deteksi, skor kulit, kondisi kulit, dan rekomendasi '
          'kandungan/produk di Glowmate bersifat INFORMATIF dan TIDAK '
          'boleh dijadikan pengganti pemeriksaan, diagnosis, atau '
          'pengobatan oleh tenaga medis profesional. Jika Anda mengalami '
          'kondisi kulit yang serius, nyeri, infeksi, atau reaksi alergi, '
          'segera hubungi dokter kulit/dermatolog.',
    ],
  ),
  _LegalSection(
    icon: Icons.rule_rounded,
    title: '5. Akurasi Hasil Analisis',
    bullets: [
      'Teknologi deteksi wajah & analisis kulit memiliki keterbatasan '
          'dan tidak selalu 100% akurat.',
      'Hasil dapat bervariasi tergantung kondisi pencahayaan, kualitas '
          'kamera perangkat, dan sudut pengambilan wajah.',
      'Rekomendasi produk didasarkan pada kecocokan kandungan secara '
          'umum, BUKAN hasil uji klinis khusus kulit Anda — reaksi kulit '
          'terhadap suatu produk tetap dapat berbeda-beda per individu.',
    ],
  ),
  _LegalSection(
    icon: Icons.account_circle_rounded,
    title: '6. Akun & Keamanan',
    bullets: [
      'Anda bertanggung jawab menjaga kerahasiaan kredensial akun '
          '(kata sandi, PIN, dsb.) dan seluruh aktivitas yang terjadi di '
          'bawah akun Anda.',
      'Segera beri tahu kami bila Anda menduga ada akses tidak sah ke '
          'akun Anda.',
      'Kami berhak menangguhkan atau menghapus akun yang terbukti '
          'melanggar Syarat Layanan ini.',
    ],
  ),
  _LegalSection(
    icon: Icons.copyright_rounded,
    title: '7. Hak Kekayaan Intelektual',
    paragraphs: [
      'Seluruh desain aplikasi, logo, kode, dan konten katalog kandungan '
          '& produk adalah milik Glowmate atau pemberi lisensinya. Foto '
          'wajah dan data hasil analisis yang Anda hasilkan tetap menjadi '
          'milik Anda sepenuhnya — kami hanya menyimpannya untuk '
          'menjalankan fitur riwayat & rekomendasi sesuai Kebijakan '
          'Privasi.',
    ],
  ),
  _LegalSection(
    icon: Icons.block_rounded,
    title: '8. Larangan Penggunaan',
    paragraphs: ['Anda setuju untuk TIDAK:'],
    bullets: [
      'Menggunakan fitur kamera untuk mengambil wajah orang lain tanpa '
          'persetujuan mereka.',
      'Melakukan rekayasa balik (reverse engineering), membongkar, atau '
          'mencoba mengekstrak kode sumber aplikasi.',
      'Menggunakan aplikasi untuk tujuan ilegal, menipu, atau merugikan '
          'pihak lain.',
      'Mengganggu, membebani berlebihan, atau mencoba meretas sistem '
          'infrastruktur Glowmate.',
    ],
  ),
  _LegalSection(
    icon: Icons.storefront_rounded,
    title: '9. Rekomendasi Produk Pihak Ketiga',
    paragraphs: [
      'Produk & merek yang muncul dalam rekomendasi ditampilkan sebagai '
          'referensi kandungan yang relevan dengan kondisi kulit Anda. '
          'Glowmate tidak berafiliasi secara eksklusif dengan merek '
          'tertentu kecuali dinyatakan lain, dan tidak bertanggung jawab '
          'atas kualitas, ketersediaan, atau efek samping dari produk yang '
          'direkomendasikan.',
    ],
  ),
  _LegalSection(
    icon: Icons.shield_outlined,
    title: '10. Batasan Tanggung Jawab',
    paragraphs: [
      'Sepanjang diizinkan oleh hukum yang berlaku, Glowmate tidak '
          'bertanggung jawab atas kerugian tidak langsung, insidental, '
          'atau konsekuensial yang timbul dari penggunaan aplikasi ini, '
          'termasuk namun tidak terbatas pada reaksi terhadap produk '
          'skincare yang direkomendasikan, atau keputusan yang diambil '
          'semata-mata berdasarkan hasil analisis aplikasi.',
    ],
  ),
  _LegalSection(
    icon: Icons.cancel_schedule_send_rounded,
    title: '11. Penghentian Layanan',
    paragraphs: [
      'Anda dapat berhenti menggunakan Glowmate kapan saja dengan '
          'menghapus akun dan/atau aplikasi. Kami juga berhak menghentikan '
          'atau membatasi akses ke layanan tertentu, dengan pemberitahuan '
          'yang wajar bila memungkinkan, misalnya karena pemeliharaan, '
          'perubahan bisnis, atau pelanggaran ketentuan ini.',
    ],
  ),
  _LegalSection(
    icon: Icons.edit_note_rounded,
    title: '12. Perubahan Ketentuan',
    paragraphs: [
      'Kami dapat memperbarui Syarat Layanan ini sewaktu-waktu. '
          'Penggunaan Anda yang berkelanjutan atas aplikasi setelah '
          'perubahan berlaku dianggap sebagai persetujuan Anda terhadap '
          'ketentuan yang telah diperbarui.',
    ],
  ),
  _LegalSection(
    icon: Icons.balance_rounded,
    title: '13. Hukum yang Berlaku',
    paragraphs: [
      'Syarat Layanan ini diatur dan ditafsirkan sesuai dengan hukum '
          'yang berlaku di Republik Indonesia, tanpa memandang pertentangan '
          'kaidah hukum.',
    ],
  ),
];

/// ===================== Widget bersama (terms_page.dart) =====================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.lastUpdated,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String lastUpdated;

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
            child: Icon(icon, color: cs.onPrimary, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: cs.onPrimary.withOpacity(0.9),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.onPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'Terakhir diperbarui: $lastUpdated',
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.icon,
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
  });
  final IconData icon;
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});
  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        // Material ini yang jadi ancestor terdekat untuk ListTile
        // di dalam ExpansionTile, sehingga background & ink splash
        // ikut terlihat (tidak tertutup DecoratedBox lagi).
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(section.icon, color: cs.primary, size: 20),
            title: Text(
              section.title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in section.paragraphs) ...[
                Text(
                  p,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: cs.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final b in section.bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.title, required this.body, required this.email});
  final String title;
  final String body;
  final String email;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: cs.onSurface.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.alternate_email_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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