import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // Wajib untuk rootBundle

// Import untuk PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color kPrimaryColor = Color(0xFF0D47A1); 
const Color kSecondaryColor = Color(0xFFF57C00);
const Color kBgColor = Color(0xFFF8F9FA);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // FUNGSI BARU: Cetak semua riwayat ke satu file PDF
  Future<void> _generateAllHistoryPdf(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyData = prefs.getString('qr_history');

    if (historyData == null || historyData.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada riwayat untuk dicetak!")),
        );
      }
      return;
    }

    // Tampilkan Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. LOAD LOGO DARI ASSETS
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

      final List<dynamic> historyList = json.decode(historyData);
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // 2. HEADER DENGAN LOGO & NAMA APLIKASI
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LAPORAN RIWAYAT QR', 
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Aplikasi QR S&G - Akses Cepat & Aman', 
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Image(logoImage, width: 60, height: 60), // Menampilkan Logo
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 20),

            // 3. TABEL DATA
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              headers: ['No', 'Konten / Link QR', 'Tanggal Pembuatan'],
              data: List<List<String>>.generate(
                historyList.length,
                (index) => [
                  (index + 1).toString(),
                  historyList[index]['data'].toString(),
                  historyList[index]['date'].toString(),
                ],
              ),
            ),
            
            pw.SizedBox(height: 40),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Dicetak pada: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            )
          ],
          footer: (pw.Context context) => pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text('Halaman ${context.pageNumber} dari ${context.pagesCount}', 
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ),
        ),
      );

      if (context.mounted) Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Laporan_Riwayat_QR.pdf',
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Gagal cetak PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: Stack(
        children: [
          // Background Gradient Header
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryColor, Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildTopBar(),
                  const SizedBox(height: 30),
                  _buildProfileCard(), // UI dengan Foto Profil
                  const SizedBox(height: 30),
                  const Text('Layanan Utama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildMenuGrid(context),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Access by QR S&G', style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text('Selamat Datang!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        Container(
          decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kSecondaryColor, width: 2)),
            child: const CircleAvatar(
              radius: 30, 
              backgroundImage: AssetImage('assets/images/profile.jpg'), // Pastikan path ini benar
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Muhammad Azzam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Fullstack Developer', style: TextStyle(color: Colors.grey, fontSize: 14)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _MenuButton(icon: Icons.qr_code_2, label: 'Buat QR', subtitle: 'Baru', color: kPrimaryColor, route: '/create'),
        _MenuButton(icon: Icons.qr_code_scanner, label: 'Scan', subtitle: 'Pindai', color: kSecondaryColor, route: '/scan'),
        _MenuButton(icon: Icons.history, label: 'Riwayat', subtitle: 'Data Lama', color: Colors.teal, route: '/history'),
        _MenuButton(
          icon: Icons.print, 
          label: 'Cetak PDF', 
          subtitle: 'Semua Data', 
          color: Colors.redAccent, 
          onTap: () => _generateAllHistoryPdf(context) // Fungsi download PDF Riwayat
        ),
      ],
    );
  }
}

// ... (Bagian atas HomeScreen tetap sama) ...

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? route;
  final VoidCallback? onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.route,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.pushNamed(context, route!),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        // Menjaga agar background logo tidak keluar batas rounded
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
          // Gradien halus di background sesuai warna tombol
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withOpacity(0.05), // Sedikit sentuhan warna di pojok
            ],
          ),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            // --- BACKGROUND LOGO / WATERMARK (WARNA SESUAI TOMBOL) ---
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                icon,
                size: 110,
                color: color.withOpacity(0.07), // Warna transparan senada ikon
              ),
            ),
            
            // --- KONTEN UTAMA ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wadah Ikon Kecil
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(height: 14),
                  // Teks Label
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Teks Subtitle
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//