// lib/app/pages/analysis/pages.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:glowmate/app/pages/analysis/repository/analisis.dart';
import 'package:glowmate/app/pages/analysis/skin/chart.dart';
import 'package:glowmate/app/pages/analysis/skin/model/health.dart';
import 'package:provider/provider.dart';

import '../../core/providers/user/users.dart';
import '../account/report/pages.dart';
import '../camera/enggine/painter.dart';
import '../camera/model/mesh.dart';
import '../report/pages.dart';
import 'model/data.dart';
import 'model/model.dart';

// ASUMSI #1: sesuaikan path import ini dengan CameraPage & CameraProvider
// yang sebenarnya di project kamu (berdasarkan file yang sudah dibagikan
// sebelumnya: lib/app/pages/camera/pages.dart & .../provider/camera.dart).
import '../camera/pages.dart' show CameraPage;
import '../camera/provider/camera.dart' show CameraProvider;

// BARU (3D view menggantikan foto datar di atas field hitam pada kartu
// riwayat): `Face3DViewer` adalah widget YANG SAMA PERSIS dipakai panel
// "3D CONSTRUCTION" live di halaman kamera -- di sini kita pakai ulang
// dengan data yang sudah dibekukan (`AnalysisRecord.toFaceMeshSnapshot()`)
// supaya rekonstruksi 3D di riwayat identik dengan yang dilihat user saat
// capture, bukan gambar baru yang dibuat terpisah.

// Halaman rekomendasi kandungan & produk berdasarkan masalah kulit yang
// terdeteksi -- dibuka dari tombol di header (lihat _GreetingHeader).

// ASUMSI #2: sesuaikan path & nama class UserProvider ini dengan yang
// sebenarnya dipakai di project kamu. Provider ini diasumsikan punya
// getter `user` bertipe `UserModel?` dengan `hasName` & `name` (persis
// seperti yang dipakai `KnownUserDataSnapshot.fromUser` di
// pages/camera/model/camera.dart).

/// AnalysisPage murni "reaktif" terhadap [AnalysisRepository]: tidak
/// menerima `captureResult` lewat constructor. Data baru masuk ke
/// repository langsung dari HomePage saat tombol SELESAI di kamera
/// ditekan, lalu repository memberi tahu SEMUA listener-nya lewat
/// `notifyListeners()` — halaman ini otomatis ter-update, dan setiap
/// data baru langsung tampil paling atas, berulang setiap kali ada
/// capture baru.
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  /// KETENTUAN #5: daftar "Riwayat Deteksi" di halaman ini HANYA
  /// menampilkan yang TERBARU (dibatasi jumlahnya) -- riwayat LENGKAP
  /// tetap bisa dilihat di halaman Laporan (`ReportPage`, sudah ada
  /// tombol "Lihat Semua Riwayat" kalau data melebihi batas ini).
  /// Grafik "Tingkat Kulit Sehat" di atasnya TETAP menghitung dari
  /// SELURUH data (`repo.records`, bukan `visibleRecords`) -- lihat
  /// pemakaian `SkinHealthChart` di `build()`.
  static const int _maxVisibleRecords = 1;

  Future<void> _openCamera(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CameraProvider(child: CameraPage()),
      ),
    );
  }

  Future<void> _openRecommendation(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecommendationPage()),
    );
  }

  Future<void> _openReport(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReportPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // context.watch -> widget ini rebuild setiap kali repository
    // memanggil notifyListeners() (mis. ada capture baru, atau hasil
    // analisis tambahan masuk belakangan).
    final repo = context.watch<AnalysisRepository>();
    final records = repo.records; // terbaru -> terlama, SELURUH riwayat
    final latest = repo.latest;
    final hasData = records.isNotEmpty;

    // KETENTUAN #5: daftar yang DITAMPILKAN dibatasi hanya yang
    // terbaru -- `records` (lengkap) tetap dipakai apa adanya untuk
    // grafik (`SkinHealthChart`) dan untuk mencari "record sebelumnya"
    // pada tiap kartu (lihat `_RecordCard.previous`), supaya
    // perbandingan kemajuan tetap benar walau kartunya sendiri tidak
    // ditampilkan di daftar yang dipotong ini.
    final visibleRecords = records.length > _maxVisibleRecords
        ? records.sublist(0, _maxVisibleRecords)
        : records;
    final hasMoreRecords = records.length > visibleRecords.length;

    final userProvider = context.watch<UserProvider?>();
    final user = userProvider?.user;
    final userName =
    (user != null && user.hasName) ? user.name! : 'Pengguna';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _GreetingHeader(
                userName: userName,
                lastUsedText: latest != null
                    ? formatTanggalIndo(latest.capturedAt)
                    : null,
                onOpenRecommendation: () => _openRecommendation(context),
              ),
            ),
            if (!hasData)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onOpenCamera: () => _openCamera(context)),
              )
            else ...[
              // URUTAN DIBALIK (permintaan revisi): "Riwayat Deteksi
              // Terbaru" sekarang tampil PALING ATAS, disusul grafik
              // "Tingkat Kulit Sehat" di bawahnya -- kebalikan dari
              // urutan sebelumnya. `_maxVisibleRecords` = 1 -> daftar
              // ini SELALU hanya menampilkan SATU kartu (record paling
              // baru); kalau ada riwayat lain, "Lihat Semua" mengarah
              // ke ReportPage untuk melihat seluruhnya.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Riwayat Deteksi Terbaru',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (hasMoreRecords)
                        TextButton(
                          onPressed: () => _openReport(context),
                          child: const Text('Lihat Semua'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                sliver: SliverList.separated(
                  itemCount: visibleRecords.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    // key by id supaya State (posisi slider & tipe kulit
                    // terpilih) tidak "ketuker" antar kartu saat list
                    // berubah urutan/panjang (mis. ada capture baru masuk
                    // di posisi paling atas).
                    //
                    // KETENTUAN #1: `previous` diambil dari `records`
                    // (daftar LENGKAP, bukan `visibleRecords`) supaya
                    // perbandingan "Kemajuan" tetap mengacu ke record
                    // TEPAT SEBELUMNYA secara kronologis, walau batas
                    // tampilan cuma `_maxVisibleRecords` kartu (sekarang
                    // 1).
                    final record = visibleRecords[index];
                    final recordIndexInFull = index; // urutan sama (0..N)
                    final previous =
                    recordIndexInFull + 1 < records.length
                        ? records[recordIndexInFull + 1]
                        : null;
                    return _RecordCard(
                      key: ValueKey(record.id),
                      record: record,
                      previous: previous,
                    );
                  },
                ),
              ),
              // KETENTUAN #2-#5: grafik "Tingkat Kulit Sehat" -- SELALU
              // dihitung dari `records` (seluruh riwayat), TIDAK peduli
              // daftar di atasnya cuma menampilkan satu kartu terbaru.
              // Ditaruh di BAWAH daftar riwayat (posisi dibalik dari
              // sebelumnya).
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                sliver: SliverToBoxAdapter(
                  child: SkinHealthChart(records: records),
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: hasData
          ? FloatingActionButton.extended(
        onPressed: () => _openCamera(context),
        icon: const Icon(Icons.face_retouching_natural_rounded),
        label: const Text('Deteksi Baru'),
      )
          : null,
    );
  }
}

/// Header sapaan: "Selamat pagi/siang/sore/malam, {Nama}" + info kapan
/// terakhir kali memakai kamera. Elegan lewat gradient lembut & kartu
/// melayang di atasnya.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.userName,
    required this.lastUsedText,
    required this.onOpenRecommendation,
  });

  final String userName;
  final String? lastUsedText;
  final VoidCallback onOpenRecommendation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sapaan = sapaanBerdasarkanWaktu(DateTime.now());

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.95),
            cs.primary.withOpacity(0.65),
          ],
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$sapaan,',
                style: TextStyle(
                  color: cs.onPrimary.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                // beri ruang kanan supaya nama tidak tertindih tombol
                // rekomendasi di pojok kanan atas.
                padding: const EdgeInsets.only(right: 40),
                child: Text(
                  userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    size: 14,
                    color: cs.onPrimary.withOpacity(0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastUsedText != null
                          ? 'Terakhir menggunakan kamera: $lastUsedText'
                          : 'Belum pernah menggunakan kamera',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onPrimary.withOpacity(0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Lihat rekomendasi kandungan & produk',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onOpenRecommendation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.spa_rounded,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ditampilkan saat BELUM ADA satupun hasil capture.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onOpenCamera});
  final VoidCallback onOpenCamera;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 44,
                color: cs.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tidak Ada Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada riwayat deteksi wajah. Mulai deteksi\nuntuk melihat hasilnya di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurface.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenCamera,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Buka Halaman Kamera'),
              style: FilledButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu satu hasil capture.
///
/// UPDATE (2 ketentuan baru dari user):
/// 1. FOTO — sekarang ditampilkan di atas FIELD HITAM dengan wajah di
///    tengah, ditemani SWITCH VERTIKAL di sisi kanan foto: makin ke ATAS
///    posisi switch, makin terlihat kulit wajahnya; makin ke BAWAH,
///    kembali ke field hitam polos ("tanpa kulit" -- privasi default).
///    Ini SELARAS dengan `FaceCaptureProcessor.cropToFaceOutline`
///    (services/face_capture_processor.dart) yang menghasilkan PNG
///    dengan area DI LUAR outline wajah transparan (alpha 0) -- di atas
///    latar hitam, area transparan itu otomatis terlihat hitam, jadi
///    hanya wajah yang "mengambang" di tengah field hitam.
/// 2. TIPE KULIT — sekarang dirender sebagai CHIP-CHIP yang bisa diklik
///    satu per satu (bukan lagi satu teks gabungan). Klik salah satu
///    chip -> hanya data tipe kulit itu yang ditampilkan di panel detail
///    di bawahnya. Default (sebelum ada interaksi) memilih entri PALING
///    KIRI (index 0), sesuai urutan yang tersimpan di
///    `AnalysisRecord.knownSkinTypes`.
///
/// Dibuat StatefulWidget karena kedua interaksi di atas (posisi slider &
/// tipe kulit terpilih) adalah STATE lokal per-kartu, bukan bagian dari
/// data tersimpan.
class _RecordCard extends StatefulWidget {
  const _RecordCard({super.key, required this.record, this.previous});
  final AnalysisRecord record;

  /// Record TEPAT SEBELUMNYA secara kronologis (satu urutan lebih lama)
  /// -- dipakai untuk KETENTUAN #1 ("Kemajuan" per hari): kalau himpunan
  /// masalah tipe kulit pada [record] lebih sedikit/ringan dibanding
  /// [previous], kartu ini menampilkan chip "Kemajuan"; kalau bertambah,
  /// "Perlu Perhatian". Null kalau [record] adalah data paling lama
  /// (tidak ada pembanding) -- chip tidak ditampilkan.
  final AnalysisRecord? previous;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  // PENTING: nilai ini adalah KONSTANTA logical-pixel (bukan turunan dari
  // `MediaQuery.size` atau pengecekan platform apa pun) -- artinya box
  // ini akan SELALU berukuran identik di Android, iOS, Web, maupun
  // Desktop, terlepas dari lebar layar atau kepadatan piksel perangkat.
  // Rasio ~11:7 (LANDSCAPE / horizontal, lebih lebar daripada tinggi)
  // dipilih supaya rekonstruksi wajah punya ruang gerak horizontal yang
  // lega -- bukan lagi kartu potret sempit seperti sebelumnya.
  static const _photoWidth = 220.0;
  static const _photoHeight = 140.0;

  /// 0 = panel terkunci (privasi default, belum ada apa pun yang
  ///     terlihat -- baik itu 3D construction maupun foto).
  /// 1 = rekonstruksi 3D wajah (atau foto, kalau data 3D tidak tersedia)
  ///     terlihat penuh.
  double _revealAmount = 0.0;

  /// Index chip Tipe Kulit yang sedang aktif. Default 0 = paling kiri.
  int _selectedTypeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final record = widget.record;
    final hasPhoto = !kIsWeb && record.imagePath != null;
    // BARU: data 3D construction (SAMA PERSIS sumbernya dengan panel "3D
    // CONSTRUCTION" di halaman kamera) yang dibekukan saat capture. Kalau
    // ada, panel di kartu ini menampilkan rekonstruksi 3D menggantikan
    // foto datar di atas field hitam. Kalau tidak ada (record lama /
    // platform tanpa mesh), tetap fallback ke foto datar seperti semula.
    final mesh = record.toFaceMeshSnapshot();

    // Jaga-jaga: kalau karena suatu sebab panjang `knownSkinTypes` lebih
    // pendek dari index yang tersimpan di state (mis. hot-reload), clamp
    // supaya tidak RangeError.
    final safeTypeIndex = record.knownSkinTypes.isEmpty
        ? 0
        : _selectedTypeIndex.clamp(0, record.knownSkinTypes.length - 1);

    // KETENTUAN #1: kategori "Kemajuan"/"Perlu Perhatian" dibanding
    // record sebelumnya -- null kalau tidak ada pembanding atau datanya
    // sama saja (lihat `SkinHealthAnalyzer.progressBetween`).
    final progress =
    SkinHealthAnalyzer.progressBetween(widget.previous, record);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== FOTO (field hitam + indikator/switch) — DI TENGAH =====
          // Dibuat baris tersendiri lalu dibungkus `Center` supaya, tidak
          // seperti versi sebelumnya (foto nempel kiri sejajar teks),
          // seluruh unit foto+switch kini berada di TENGAH lebar kartu.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Center(
              child: _buildPhotoWithRevealSwitch(cs, hasPhoto, mesh),
            ),
          ),
          // ===== TULISAN & DATA — DI SEBELAH KIRI =====
          // Dipindah ke baris terpisah di BAWAH foto, rata kiri
          // (`CrossAxisAlignment.start`), bukan lagi jadi kolom di
          // sebelah kanan foto.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadge(status: record.status),
                const SizedBox(height: 6),
                Text(
                  formatTanggalSingkat(record.capturedAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.detectedHumanCount} wajah terdeteksi',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (record.status == AnalysisStatus.completed &&
                    record.skinScore != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Skor kulit: ${record.skinScore!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
                if (record.captureAttempts > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Diambil ulang otomatis (${record.captureAttempts}x)',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurface.withOpacity(0.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (record.knownSkinConditionLabel != null ||
              record.knownLatestFindingLabel != null ||
              progress != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // KETENTUAN #1: chip "Kemajuan" / "Perlu Perhatian" --
                  // dari perbandingan `record` vs `widget.previous`
                  // (lihat `SkinHealthAnalyzer.progressBetween`).
                  // Ditaruh PALING KIRI supaya langsung terlihat begitu
                  // kartu di-scroll.
                  if (progress != null) _ProgressChip(trend: progress),
                  if (record.knownSkinConditionLabel != null)
                    _InfoChip(
                      Icons.spa_rounded,
                      record.knownSkinConditionLabel!,
                    ),
                  // Chip "Temuan Tipe Kulit Terbaru" SENGAJA disembunyikan
                  // selama isinya masih placeholder -- itu bukan temuan
                  // sungguhan, cuma penanda fitur analisis lanjutan
                  // belum tersedia.
                  if (record.knownLatestFindingLabel != null &&
                      record.knownLatestFindingLabel !=
                          kLatestFindingPlaceholder)
                    _InfoChip(
                      Icons.auto_awesome_rounded,
                      record.knownLatestFindingLabel!,
                    ),
                ],
              ),
            ),
          ],
          if (record.knownSkinTypes.isNotEmpty)
            _buildSelectableSkinTypes(cs, record, safeTypeIndex)
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// KETENTUAN (revisi 3D view):
  /// - Panel di sebelah kiri sekarang menampilkan REKONSTRUKSI 3D wajah
  ///   (`Face3DViewer`, SAMA PERSIS widget & data yang dipakai panel
  ///   "3D CONSTRUCTION" live di halaman kamera) menggantikan foto datar
  ///   di atas field hitam polos. Kalau data mesh tidak tersedia (record
  ///   lama / platform capture tanpa landmark), tetap fallback ke foto
  ///   datar seperti sebelumnya -- tidak pernah menampilkan layar kosong.
  /// - Switch vertikal di kanan panel TETAP ada dengan perilaku yang
  ///   sama: geser ke ATAS -> makin terlihat, geser ke BAWAH -> kembali
  ///   terkunci (privasi default). Ikon mata diganti jadi ikon KULIT
  ///   (`spa_rounded`) supaya lebih relevan dengan konteks analisis kulit
  ///   (bukan sekadar "lihat/sembunyikan foto").
  Widget _buildPhotoWithRevealSwitch(
      ColorScheme cs,
      bool hasPhoto,
      FaceMeshSnapshot? mesh,
      ) {
    final record = widget.record;
    final has3D = mesh != null;
    final hasContent = has3D || hasPhoto;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRevealPanel(cs, record, has3D, hasPhoto, mesh),
        const SizedBox(width: 2),
        // ===== SWITCH VERTIKAL =====
        // Geser ke ATAS -> _revealAmount naik -> rekonstruksi kulit/wajah
        // makin terlihat. Geser ke BAWAH -> kembali terkunci. Default
        // (belum disentuh) = 0 -> tersembunyi, sesuai prinsip "privasi
        // dulu, baru user yang membuka sendiri".
        SizedBox(
          width: 30,
          height: _photoHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.spa_rounded,
                size: 14,
                color: hasContent
                    ? cs.primary.withOpacity(0.7)
                    : cs.onSurface.withOpacity(0.2),
              ),
              Expanded(
                child: RotatedBox(
                  // quarterTurns: 3 -> ujung MAX slider berada di ATAS,
                  // ujung MIN di BAWAH (lihat penjelasan rotasi di
                  // komentar kelas). Ini yang membuat "geser ke atas =
                  // makin terlihat".
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: _revealAmount,
                      onChanged: hasContent
                          ? (v) => setState(() => _revealAmount = v)
                          : null,
                    ),
                  ),
                ),
              ),
              Icon(
                // Ikon kulit yang sama, diredupkan -- penanda "kondisi
                // tersembunyi" tanpa perlu ikon berbeda yang belum tentu
                // tersedia di semua versi Material Icons.
                Icons.spa_rounded,
                size: 14,
                color: cs.onSurface.withOpacity(0.2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Panel utama: SEKARANG SELALU memakai `Face3DViewer` sebagai bingkai
  /// (grid tipis + border cyan + glow, SAMA PERSIS box "3D CONSTRUCTION"
  /// yang tampil di halaman kamera) -- bukan lagi kotak hitam polos.
  /// - Ada data mesh (`has3D`) -> box menampilkan rekonstruksi point-cloud
  ///   + kontur wajah, sama seperti live-preview di kamera.
  /// - Tidak ada mesh tapi ada foto (record lama) -> box tetap tampil
  ///   (grid + border cyan), foto ditumpuk elegan di tengahnya.
  /// - Tidak ada keduanya -> box tampil kosong (hanya grid), PERSIS
  ///   seperti kondisi "belum ada wajah terdeteksi" di kamera.
  /// Overlay "terkunci" (gembok) hanya muncul kalau memang ADA sesuatu
  /// yang perlu disembunyikan (`has3D` atau `hasPhoto`) -- kalau box
  /// kosong, tidak ada privasi yang perlu dijaga, jadi tanpa overlay.
  Widget _buildRevealPanel(
      ColorScheme cs,
      AnalysisRecord record,
      bool has3D,
      bool hasPhoto,
      FaceMeshSnapshot? mesh,
      ) {
    final hasSomethingToReveal = has3D || hasPhoto;

    // Wrapper luar: bayangan lembut + sedikit glow cyan supaya box terasa
    // "melayang" di atas kartu -- murni dekorasi tambahan, ukuran tetap
    // dikontrol oleh `_photoWidth`/`_photoHeight` (konstanta, identik di
    // semua platform) lewat `SizedBox` di dalamnya.
    return Container(
      width: _photoWidth,
      height: _photoHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF00D0FF).withOpacity(0.12),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: _photoWidth,
          height: _photoHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bingkai SELALU tampil -- widget yang SAMA PERSIS dipakai
              // panel "3D CONSTRUCTION" live di kamera. Kalau `mesh` null,
              // `Face3DViewer` otomatis hanya menggambar grid latar (lihat
              // `_drawGrid` di face3d_painter.dart) -- box tetap elegan,
              // tidak pernah polos hitam.
              Face3DViewer(
                mesh: mesh,
                size: Size(_photoWidth, _photoHeight),
                showSkin: true,
              ),
              // FALLBACK foto (record lama tanpa data mesh): ditumpuk di
              // tengah bingkai, bukan menggantikannya, supaya box tetap
              // konsisten bergaya kamera.
              if (!has3D && hasPhoto)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(record.imagePath!),
                      fit: BoxFit.contain,
                      width: _photoWidth * 0.72,
                      height: _photoHeight * 0.72,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // ===== OVERLAY "TERKUNCI" (privasi default) =====
              // Hanya tampil kalau ada sesuatu untuk disembunyikan.
              // Memudar seiring _revealAmount naik -- di 0 menutup penuh
              // (gelap + ikon kunci), di 1 transparan total sehingga
              // rekonstruksi 3D/foto di baliknya terlihat jelas.
              if (hasSomethingToReveal)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: (1 - _revealAmount).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 120),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.94),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// KETENTUAN #2: Tipe Kulit sebagai chip-chip yang bisa diklik satu
  /// per satu. Klik -> hanya data tipe kulit itu yang ditampilkan di
  /// panel detail. Default -> entri paling kiri (index 0).
  Widget _buildSelectableSkinTypes(
      ColorScheme cs,
      AnalysisRecord record,
      int safeTypeIndex,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipe Kulit',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: cs.onSurface.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(record.knownSkinTypes.length, (i) {
              final selected = i == safeTypeIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedTypeIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : cs.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected
                          ? cs.primary
                          : cs.outline.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    record.knownSkinTypes[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Panel detail -- HANYA menampilkan data tipe kulit yang
          // sedang dipilih (default paling kiri), bukan semuanya
          // sekaligus seperti versi sebelumnya.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.face_retouching_natural_rounded,
                  size: 16,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.knownSkinTypes[safeTypeIndex],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AnalysisStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      AnalysisStatus.captured => (Colors.blueAccent, 'Baru diambil'),
      AnalysisStatus.analyzing => (Colors.orangeAccent, 'Menganalisis'),
      AnalysisStatus.completed => (Colors.green, 'Selesai'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cs.outline.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// KETENTUAN #1: chip "Kemajuan" (hijau, masalah tipe kulit
/// berkurang/hilang dibanding record sebelumnya) atau "Perlu Perhatian"
/// (merah, masalah bertambah) di kartu riwayat. Dipakai `_RecordCard`
/// lewat `SkinHealthAnalyzer.progressBetween`.
class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.trend});
  final SkinTrend trend;

  @override
  Widget build(BuildContext context) {
    final improving = trend == SkinTrend.improving;
    final color = improving ? Colors.green : Colors.redAccent;
    final label = improving ? 'Kemajuan' : 'Perlu Perhatian';
    final icon =
    improving ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}