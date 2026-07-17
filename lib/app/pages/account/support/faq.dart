// ─────────────────────────────────────────────
// app/pages/dukungan/faq_page.dart
// ─────────────────────────────────────────────
// FAQ lengkap: pencarian, filter kategori, dan daftar pertanyaan yang
// bisa dibuka/tutup satu per satu.
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';

class _FaqItem {
  const _FaqItem({required this.category, required this.question, required this.answer});
  final String category;
  final String question;
  final String answer;
}

const _categories = [
  'Semua',
  'Kamera & Analisis',
  'Privasi & Data',
  'Rekomendasi',
  'Akun',
  'Umum',
];

const _faqItems = <_FaqItem>[
  _FaqItem(
    category: 'Kamera & Analisis',
    question: 'Bagaimana cara kerja deteksi wajah di Glowmate?',
    answer:
    'Saat Anda membuka halaman kamera, aplikasi mendeteksi wajah secara '
        'real-time dan membangun rekonstruksi 3D dari ratusan titik '
        'landmark wajah. Setelah Anda menekan tombol Selesai, hasil capture '
        'tersebut dibekukan dan disimpan sebagai satu entri riwayat.',
  ),
  _FaqItem(
    category: 'Kamera & Analisis',
    question: 'Kenapa foto saya diambil ulang otomatis beberapa kali?',
    answer:
    'Aplikasi otomatis mendeteksi jika foto tampak buram atau perangkat '
        'bergoyang saat pengambilan, lalu mengulang capture supaya hasil '
        'analisisnya lebih akurat. Jumlah percobaan ditampilkan di kartu '
        'riwayat sebagai catatan transparansi.',
  ),
  _FaqItem(
    category: 'Kamera & Analisis',
    question: 'Kenapa hasil 3D construction tersembunyi di balik layar hitam?',
    answer:
    'Ini fitur privasi bawaan: rekonstruksi wajah dan foto Anda secara '
        'default terkunci. Geser sakelar kecil di samping panel ke atas '
        'untuk menampilkannya, dan geser ke bawah lagi untuk '
        'menyembunyikannya kembali kapan saja.',
  ),
  _FaqItem(
    category: 'Kamera & Analisis',
    question: 'Apakah saya butuh koneksi internet untuk memakai kamera?',
    answer:
    'Tidak. Deteksi wajah, rekonstruksi 3D, dan penyimpanan riwayat '
        'sepenuhnya berjalan di perangkat Anda tanpa perlu koneksi '
        'internet.',
  ),
  _FaqItem(
    category: 'Privasi & Data',
    question: 'Apakah foto wajah saya diunggah ke server?',
    answer:
    'Tidak. Di Android, iOS, dan Desktop, foto disimpan sebagai file di '
        'folder privat aplikasi pada perangkat Anda sendiri. Di Web, foto '
        'bahkan tidak disimpan sama sekali — hanya metadata hasil analisis '
        'yang tersimpan. Lihat Kebijakan Privasi untuk detail lengkap.',
  ),
  _FaqItem(
    category: 'Privasi & Data',
    question: 'Bagaimana cara menghapus riwayat analisis saya?',
    answer:
    'Buka halaman Laporan/Analisis, pilih entri riwayat yang ingin '
        'dihapus, lalu ketuk ikon hapus. Anda juga bisa menghapus SELURUH '
        'riwayat sekaligus lewat menu Pengaturan → Kelola Data. Tindakan '
        'ini permanen dan tidak dapat dibatalkan.',
  ),
  _FaqItem(
    category: 'Privasi & Data',
    question: 'Apakah data saya dibagikan ke merek skincare yang direkomendasikan?',
    answer:
    'Tidak. Pencocokan kandungan & produk dihitung sepenuhnya di dalam '
        'aplikasi berdasarkan katalog internal — data wajah atau kondisi '
        'kulit Anda tidak pernah dikirim ke pihak brand atau e-commerce '
        'mana pun.',
  ),
  _FaqItem(
    category: 'Rekomendasi',
    question: 'Dari mana rekomendasi kandungan & produk berasal?',
    answer:
    'Berdasarkan Tipe Kulit dan Temuan Tipe Kulit Terbaru yang '
        'terdeteksi, aplikasi mencocokkan setiap masalah kulit dengan '
        'daftar kandungan aktif yang relevan, lalu menampilkan produk-produk '
        'yang mengandung kandungan tersebut, diurutkan dari rating '
        'tertinggi.',
  ),
  _FaqItem(
    category: 'Rekomendasi',
    question: 'Apakah rekomendasi produk merupakan resep medis?',
    answer:
    'Bukan. Rekomendasi bersifat informatif berdasarkan kecocokan '
        'kandungan secara umum, bukan hasil pemeriksaan dokter. Untuk '
        'masalah kulit serius, tetap konsultasikan ke dokter kulit.',
  ),
  _FaqItem(
    category: 'Rekomendasi',
    question: 'Kenapa produk yang sama muncul di beberapa masalah kulit?',
    answer:
    'Satu produk bisa mengandung beberapa bahan aktif sekaligus, '
        'sehingga wajar jika produk tersebut relevan dan muncul di lebih '
        'dari satu kelompok masalah kulit (mis. jerawat & berminyak).',
  ),
  _FaqItem(
    category: 'Akun',
    question: 'Apakah saya wajib membuat akun untuk menggunakan Glowmate?',
    answer:
    'Sebagian fitur dasar dapat dicoba tanpa akun, namun untuk '
        'menyimpan riwayat secara berkelanjutan dan mendapatkan rekomendasi '
        'yang dipersonalisasi, disarankan untuk membuat akun.',
  ),
  _FaqItem(
    category: 'Akun',
    question: 'Bagaimana jika saya lupa kata sandi akun?',
    answer:
    'Gunakan opsi "Lupa Kata Sandi" di halaman login untuk menerima '
        'tautan reset lewat email terdaftar Anda.',
  ),
  _FaqItem(
    category: 'Umum',
    question: 'Apakah Glowmate bisa dipakai secara offline?',
    answer:
    'Ya, untuk fitur inti (kamera, riwayat, rekomendasi) Glowmate dapat '
        'berjalan sepenuhnya offline karena seluruh data diproses & '
        'disimpan lokal di perangkat Anda.',
  ),
  _FaqItem(
    category: 'Umum',
    question: 'Perangkat apa saja yang didukung?',
    answer:
    'Glowmate tersedia untuk Android, iOS, Web, dan Desktop. Beberapa '
        'fitur seperti kedalaman rekonstruksi 3D dapat sedikit berbeda '
        'tergantung kemampuan sensor kamera perangkat Anda.',
  ),
  _FaqItem(
    category: 'Umum',
    question: 'Apakah Glowmate berbayar?',
    answer:
    'Fitur inti Glowmate dapat digunakan secara gratis. Informasi '
        'terkini soal paket berbayar (jika ada) akan ditampilkan di dalam '
        'aplikasi.',
  ),
];

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  String _selectedCategory = 'Semua';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final filtered = _faqItems.where((item) {
      final matchesCategory =
          _selectedCategory == 'Semua' || item.category == _selectedCategory;
      final matchesQuery = _query.isEmpty ||
          item.question.toLowerCase().contains(_query.toLowerCase()) ||
          item.answer.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Cari pertanyaan...',
                    hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.45)),
                    prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withOpacity(0.5)),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? cs.primary : cs.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected ? cs.primary : cs.outline.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyResult(cs: cs)
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _FaqTile(item: filtered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      // FIX: sama seperti _SectionTile -- bungkus dengan Material supaya
      // ripple/ink splash ExpansionTile tidak tertutup DecoratedBox.
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(Icons.help_outline_rounded, size: 20, color: cs.primary),
            title: Text(
              item.question,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.answer,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: cs.onSurface.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: cs.primary.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'Tidak ada hasil yang cocok',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Coba kata kunci lain atau pilih kategori berbeda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55)),
            ),
          ],
        ),
      ),
    );
  }
}