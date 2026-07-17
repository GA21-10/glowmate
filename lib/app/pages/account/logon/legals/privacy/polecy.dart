// ─────────────────────────────────────────────
// app/account/settings/legal/privacy_page.dart
// ─────────────────────────────────────────────
// Kebijakan Privasi lengkap -- fokus utama pada penanganan data wajah
// (foto, rekonstruksi 3D, hasil analisis kulit) karena itu data paling
// sensitif yang diproses aplikasi ini.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _lastUpdated = '12 Juli 2026';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _HeaderCard(
              icon: Icons.privacy_tip_rounded,
              title: 'Kebijakan Privasi',
              subtitle:
              'Bagaimana kami mengumpulkan, menyimpan, dan melindungi '
                  'data wajah serta data pribadi Anda saat menggunakan '
                  'Glowmate.',
              lastUpdated: _lastUpdated,
            ),
            const SizedBox(height: 20),
            const _HighlightGrid(items: [
              (Icons.smartphone_rounded, 'Foto wajah disimpan LOKAL di perangkat Anda, bukan di server kami'),
              (Icons.delete_forever_rounded, 'Anda bisa menghapus riwayat kapan saja, permanen'),
              (Icons.block_rounded, 'Tidak pernah dijual ke pihak ketiga'),
              (Icons.medical_services_outlined, 'Bukan pengganti diagnosis dokter kulit'),
            ]),
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
              title: 'Ada pertanyaan tentang privasi Anda?',
              body:
              'Hubungi kami kapan saja jika ingin mengetahui data apa '
                  'yang kami simpan tentang Anda, atau ingin data tersebut '
                  'dihapus sepenuhnya.',
              email: 'privacy@glowmate.app',
            ),
          ],
        ),
      ),
    );
  }
}

final List<_LegalSection> _sections = [
  _LegalSection(
    icon: Icons.face_retouching_natural_rounded,
    title: '1. Data Wajah yang Kami Kumpulkan',
    paragraphs: [
      'Saat Anda menggunakan fitur kamera untuk deteksi/analisis kulit, '
          'kami memproses beberapa jenis data terkait wajah Anda:',
    ],
    bullets: [
      'Foto wajah — diambil saat proses capture, boleh berupa foto penuh '
          'atau versi terpotong mengikuti garis kontur wajah (area di luar '
          'wajah otomatis transparan).',
      'Titik landmark wajah 3D — ratusan titik koordinat (x, y, z) yang '
          'membentuk rekonstruksi 3D wajah Anda, dipakai untuk menampilkan '
          'ulang "3D construction" di riwayat analisis.',
      'Data kondisi kulit — kondisi kulit, tipe kulit, dan masalah kulit '
          'yang terdeteksi atau Anda konfirmasi sendiri (mis. "Berjerawat", '
          '"Berminyak").',
      'Skor kulit & temuan analisis lanjutan — hasil perhitungan tingkat '
          'kesehatan kulit dari waktu ke waktu.',
      'Metadata capture — waktu pengambilan, jumlah wajah terdeteksi, '
          'jumlah percobaan ulang (mis. karena foto buram/goyang).',
    ],
  ),
  _LegalSection(
    icon: Icons.sd_storage_rounded,
    title: '2. Di Mana & Bagaimana Data Wajah Disimpan',
    paragraphs: [
      'Kami merancang penyimpanan data wajah seminim dan seaman mungkin:',
    ],
    bullets: [
      'Di Android, iOS, dan Desktop: foto disimpan sebagai file di folder '
          'dokumen privat aplikasi pada perangkat Anda sendiri — TIDAK '
          'diunggah otomatis ke server kami.',
      'Di Web: karena tidak ada penyimpanan berkas yang aman & persisten '
          'di browser, foto SENGAJA TIDAK disimpan sama sekali. Hanya '
          'metadata (waktu, hasil analisis, data yang Anda konfirmasi) yang '
          'tersimpan.',
      'Titik landmark 3D & metadata riwayat disimpan sebagai data '
          'terstruktur di penyimpanan lokal perangkat, agar riwayat & grafik '
          'kemajuan kulit bisa ditampilkan kembali dengan cepat tanpa '
          'koneksi internet.',
      'Rekonstruksi 3D di kartu riwayat SELALU memakai data yang sudah '
          'dibekukan saat capture — kami tidak pernah menghasilkan ulang '
          'atau menganalisis ulang wajah Anda tanpa sepengetahuan Anda.',
    ],
  ),
  _LegalSection(
    icon: Icons.rule_folder_rounded,
    title: '3. Bagaimana Kami Menggunakan Data Anda',
    bullets: [
      'Menampilkan riwayat deteksi & grafik tingkat kesehatan kulit Anda '
          'dari waktu ke waktu.',
      'Menghasilkan rekomendasi kandungan skincare & produk yang relevan '
          'dengan tipe/masalah kulit yang terdeteksi.',
      'Membandingkan hasil analisis dengan capture sebelumnya untuk '
          'menampilkan status "Kemajuan" atau "Perlu Perhatian".',
      'Memperbaiki akurasi fitur deteksi wajah & analisis kulit di masa '
          'depan (hanya bila Anda secara eksplisit mengizinkan berbagi data '
          'untuk pengembangan, lihat bagian 7).',
    ],
  ),
  _LegalSection(
    icon: Icons.lock_person_rounded,
    title: '4. Kontrol Privasi Bawaan di Aplikasi',
    paragraphs: [
      'Beberapa desain aplikasi sengaja dibuat "privasi-lebih-dulu":',
    ],
    bullets: [
      'Rekonstruksi 3D & foto pada kartu riwayat secara default '
          'TERKUNCI (tertutup layar gelap) — Anda harus menggeser sakelar '
          'secara manual untuk melihatnya.',
      'Foto disimpan dengan format yang sesuai konten sebenarnya (PNG '
          'ber-alpha untuk hasil crop wajah, JPG untuk foto penuh) agar '
          'tidak ada kesalahan penanganan file.',
    ],
  ),
  _LegalSection(
    icon: Icons.auto_delete_rounded,
    title: '5. Retensi & Penghapusan Data',
    bullets: [
      'Data riwayat (termasuk foto & landmark 3D) disimpan selama Anda '
          'tidak menghapusnya, atau selama akun/aplikasi masih Anda '
          'gunakan.',
      'Anda dapat menghapus SATU entri riwayat kapan saja — foto & '
          'metadatanya akan dihapus permanen dari perangkat.',
      'Anda juga dapat menghapus SELURUH riwayat sekaligus lewat menu '
          'pengaturan — tindakan ini permanen dan tidak dapat dibatalkan.',
      'Menghapus aplikasi dari perangkat Anda akan otomatis menghapus '
          'seluruh data lokal, termasuk foto wajah.',
    ],
  ),
  _LegalSection(
    icon: Icons.groups_rounded,
    title: '6. Berbagi Data dengan Pihak Ketiga',
    paragraphs: [
      'Kami TIDAK menjual data wajah, hasil analisis kulit, atau data '
          'pribadi Anda kepada pihak mana pun. Data hanya dapat dibagikan '
          'dalam kondisi terbatas berikut:',
    ],
    bullets: [
      'Katalog rekomendasi produk skincare ditampilkan berdasarkan '
          'kandungan yang cocok dengan masalah kulit Anda — proses ini '
          'terjadi sepenuhnya di perangkat Anda, TANPA mengirim data wajah '
          'Anda ke pihak brand/e-commerce mana pun.',
      'Jika suatu saat kami mengaktifkan fitur analisis berbasis cloud/AI '
          'pihak ketiga, kami akan meminta izin eksplisit Anda terlebih '
          'dahulu sebelum mengirim data apa pun ke luar perangkat.',
      'Kami dapat mengungkap data jika diwajibkan oleh hukum yang '
          'berlaku, mis. perintah pengadilan yang sah.',
    ],
  ),
  _LegalSection(
    icon: Icons.security_rounded,
    title: '7. Keamanan Data',
    bullets: [
      'Data disimpan di ruang penyimpanan privat aplikasi yang terisolasi '
          'dari aplikasi lain di perangkat Anda.',
      'Kami menerapkan praktik pengembangan yang aman & pembaruan berkala '
          'untuk menutup celah keamanan yang mungkin ditemukan.',
      'Karena sebagian besar data disimpan lokal, risiko kebocoran massal '
          'lewat peretasan server sangat diminimalkan — namun Anda tetap '
          'bertanggung jawab menjaga keamanan perangkat & akun Anda sendiri '
          '(mis. kunci layar, tidak membagikan perangkat ke orang asing).',
    ],
  ),
  _LegalSection(
    icon: Icons.checklist_rtl_rounded,
    title: '8. Hak-Hak Anda atas Data',
    bullets: [
      'Hak akses — melihat sendiri seluruh riwayat & data yang tersimpan '
          'langsung di halaman Laporan/Analisis.',
      'Hak hapus — menghapus sebagian atau seluruh data kapan saja tanpa '
          'perlu alasan.',
      'Hak menolak — menolak izin kamera kapan saja lewat pengaturan '
          'perangkat; fitur analisis wajah otomatis tidak akan berjalan '
          'tanpa izin ini.',
      'Hak informasi — meminta penjelasan lebih rinci tentang data apa '
          'saja yang kami proses lewat kontak di bawah.',
    ],
  ),
  _LegalSection(
    icon: Icons.escalator_warning_rounded,
    title: '9. Anak di Bawah Umur',
    paragraphs: [
      'Layanan ini tidak ditujukan untuk anak di bawah 13 tahun. Kami '
          'tidak dengan sengaja mengumpulkan data wajah dari anak di bawah '
          'umur tanpa persetujuan orang tua/wali. Jika Anda mengetahui '
          'adanya penggunaan oleh anak di bawah umur tanpa izin orang tua, '
          'segera hubungi kami agar data terkait dapat dihapus.',
    ],
  ),
  _LegalSection(
    icon: Icons.update_rounded,
    title: '10. Perubahan Kebijakan Ini',
    paragraphs: [
      'Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu '
          'mengikuti perkembangan fitur aplikasi. Perubahan signifikan '
          '(terutama yang memengaruhi data wajah) akan diberitahukan lewat '
          'notifikasi dalam aplikasi sebelum berlaku efektif. Tanggal '
          '"Terakhir diperbarui" di bagian atas halaman ini selalu '
          'mencerminkan versi terbaru.',
    ],
  ),
];

/// ===================== Widget bersama (privacy_page.dart) =====================

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

class _HighlightGrid extends StatelessWidget {
  const _HighlightGrid({required this.items});
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: items.map((item) {
        final (icon, text) = item;
        return Container(
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
                text,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      // FIX: Material di sini supaya ListTile di dalam ExpansionTile
      // punya "kanvas" sendiri untuk menggambar ink splash & background,
      // bukan tertutup warna dari Container di luar.
      child: Material(
        color: Colors.transparent,
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