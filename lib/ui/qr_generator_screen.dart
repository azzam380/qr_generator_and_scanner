import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// Import untuk PDF dan Printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color primaryColor = Color(0xFF0D47A1);
const Color accentColor = Color(0xFFF57C00);

const List<Color> bgColors = [
  Colors.white,
  Color(0xFFF5F5F5),
  Color(0xFFE3F2FD),
  Color(0xFFE8F5E9),
  Color(0xFFFFF3E0),
  Color(0xFFF3E5F5),
];

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final TextEditingController _textController = TextEditingController();

  String? _activeData;
  bool _showResult = false;
  Color _selectedBgColor = Colors.white;

  Future<void> _saveToHistory(String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyData = prefs.getString('qr_history');
      List<dynamic> historyList = historyData != null
          ? json.decode(historyData)
          : [];

      if (historyList.isNotEmpty && historyList.last['data'] == data) return;

      historyList.add({
        'data': data,
        'date': DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()),
      });
      await prefs.setString('qr_history', json.encode(historyList));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil disimpan ke riwayat"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal simpan history: $e");
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  void _generateQr() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Masukkan link atau teks terlebih dahulu!"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _activeData = _textController.text.trim();
      _showResult = true;
    });
  }

  void _resetAll() {
    setState(() {
      _textController.clear();
      _activeData = null;
      _showResult = false;
      _selectedBgColor = Colors.white;
    });
  }

  Future<void> _captureAndShare() async {
    if (_activeData == null) return;
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    _showLoading();
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: pixelRatio,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (imageBytes != null) {
        await Share.shareXFiles([
          XFile.fromData(
            imageBytes,
            name: 'qr_code.png',
            mimeType: 'image/png',
          ),
        ], text: 'QR Code: $_activeData');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _generateAndPrintPdf() async {
    if (_activeData == null) return;
    _showLoading();
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) return;
      final pdf = pw.Document();
      final qrImage = pw.MemoryImage(imageBytes);
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'QR Code Generated',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Image(qrImage, width: 250, height: 250),
                pw.SizedBox(height: 20),
                pw.Text(_activeData!, style: pw.TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Generator QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              height: 100, // Sesuaikan tinggi header
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  // Ikon QR Code standar sebagai pengganti logo sebelumnya
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 50,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- INPUT CARD ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            labelText: 'Link atau Teks',
                            hintText: 'Tempel link di sini...',
                            prefixIcon: const Icon(
                              Icons.link,
                              color: primaryColor,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Warna Latar Belakang QR:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 45,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: bgColors.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _selectedBgColor = bgColors[index],
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 15),
                                  width: 45,
                                  decoration: BoxDecoration(
                                    color: bgColors[index],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedBgColor == bgColors[index]
                                          ? primaryColor
                                          : Colors.grey.shade200,
                                      width: _selectedBgColor == bgColors[index]
                                          ? 3
                                          : 1,
                                    ),
                                    boxShadow:
                                        _selectedBgColor == bgColors[index]
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: _selectedBgColor == bgColors[index]
                                      ? const Icon(
                                          Icons.check,
                                          color: primaryColor,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _generateQr,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shadowColor: primaryColor.withOpacity(0.4),
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'BUAT QR CODE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // --- HASIL QR & TOMBOL ELEGAN ---
                  if (_showResult) ...[
                    Center(
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: _selectedBgColor,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: PrettyQrView.data(
                            data: _activeData!,
                            decoration: const PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // GRID TOMBOL ELEGAN
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 2.2,
                      children: [
                        _buildElegantBtn(
                          Icons.picture_as_pdf_rounded,
                          'Simpan PDF',
                          Colors.red.shade600,
                          _generateAndPrintPdf,
                        ),
                        _buildElegantBtn(
                          Icons.ios_share_rounded,
                          'Bagikan',
                          Colors.blue.shade600,
                          _captureAndShare,
                        ),
                        _buildElegantBtn(
                          Icons.bookmark_added_rounded,
                          'Ke Riwayat',
                          Colors.teal.shade600,
                          () => _saveToHistory(_activeData!),
                        ),
                        _buildElegantBtn(
                          Icons.restart_alt_rounded,
                          'Buat Baru',
                          Colors.blueGrey.shade600,
                          _resetAll,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET TOMBOL ELEGAN
  Widget _buildElegantBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(0.1), width: 1),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
