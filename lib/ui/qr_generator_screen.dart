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

const Color primaryColor = Color(0xFF0D47A1); // Biru KAI yang lebih elegan
const Color accentColor = Color(0xFFF57C00); // Orange KAI

const List<Color> qrColors = [
  Colors.white,
  Color(0xFFF5F5F5),
  Color(0xFFFFF3E0),
  Color(0xFFE8F5E9),
  Color(0xFFE1F5FE),
  Color(0xFFF3E5F5),
  Color(0xFFFFEBEE),
];

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  String? _qrData;
  Color _qrColor = Colors.white;

  // --- Fungsi: Simpan ke History ---
  Future<void> _saveToHistory(String data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyData = prefs.getString('qr_history');
      
      List<dynamic> historyList = historyData != null ? json.decode(historyData) : [];
      
      // Cegah duplikasi data yang sama persis di riwayat terbaru
      if (historyList.isNotEmpty && historyList.last['data'] == data) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data sudah ada di riwayat")),
        );
        return;
      }

      Map<String, String> newEntry = {
        'data': data,
        'date': DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now()),
      };

      historyList.add(newEntry);
      await prefs.setString('qr_history', json.encode(historyList));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil disimpan ke riwayat"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Gagal menyimpan history: $e");
    }
  }

  // --- Fungsi Helper: Loading Dialog ---
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
      ),
    );
  }

  // --- Fungsi: Capture & Share ---
  Future<void> _captureAndShare({bool isEmailFriendly = false}) async {
    if (_qrData == null || _qrData!.isEmpty) return;

    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;
    _showLoading();

    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: pixelRatio,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (imageBytes != null) {
        final String shareText = isEmailFriendly
            ? 'Ini QR Code untuk: $_qrData\nDibuat menggunakan QR S&G oleh Muhammad Azzam'
            : 'QR Code untuk: $_qrData\nDibuat dengan QR S&G';

        final String? subject = isEmailFriendly ? 'QR Code dari QR S&G App' : null;

        await Share.shareXFiles(
          [
            XFile.fromData(
              imageBytes,
              name: 'qr_code.png',
              mimeType: 'image/png',
            ),
          ],
          text: shareText,
          subject: subject,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error saat share: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal memproses gambar QR")),
      );
    }
  }

  // --- Fungsi: Generate & Print PDF ---
  Future<void> _generateAndPrintPdf() async {
    if (_qrData == null || _qrData!.isEmpty) return;
    
    _showLoading();
    
    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) return;
      
      final pdf = pw.Document();
      final qrImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('QR Code Generated',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Image(qrImage, width: 250, height: 250),
                  pw.SizedBox(height: 20),
                  pw.Text('Link/Teks:', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.Text('$_qrData',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 40),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  pw.Text('Dibuat melalui: QR S&G App',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            );
          },
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'QR_SNG_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error PDF: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Generator QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _qrColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade100, width: 1.5),
                            ),
                            child: _qrData == null || _qrData!.isEmpty
                                ? SizedBox(
                                    height: 200,
                                    width: 200,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.qr_code_2, size: 60, color: Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        const Text('Menunggu Input...',
                                            style: TextStyle(color: Colors.grey, fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : PrettyQrView.data(
                                    data: _qrData!,
                                    decoration: const PrettyQrDecoration(
                                      shape: PrettyQrSmoothSymbol(),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Link atau Teks',
                            labelStyle: const TextStyle(color: primaryColor, fontSize: 14),
                            hintText: 'Masukkan informasi di sini...',
                            prefixIcon: const Icon(Icons.edit_note, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F3F5),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          maxLines: 2,
                          style: const TextStyle(fontSize: 15),
                          onChanged: (value) => setState(() => 
                            _qrData = value.trim().isEmpty ? null : value.trim()
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Warna Latar Belakang",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: qrColors.map((color) => GestureDetector(
                              onTap: () => setState(() => _qrColor = color),
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _qrColor == color ? accentColor : Colors.grey.shade300,
                                    width: _qrColor == color ? 2.5 : 1,
                                  ),
                                ),
                                child: _qrColor == color
                                    ? const Icon(Icons.check, size: 18, color: accentColor)
                                    : null,
                              ),
                            )).toList(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Divider(thickness: 1, color: Color(0xFFF1F3F5)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildActionButton(
                                onPressed: _generateAndPrintPdf,
                                icon: Icons.picture_as_pdf_rounded,
                                label: 'PDF',
                                color: Colors.blueGrey.shade700,
                                isOutlined: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildActionButton(
                                onPressed: () => _captureAndShare(isEmailFriendly: false),
                                icon: Icons.share_rounded,
                                label: 'Share',
                                color: primaryColor,
                                isOutlined: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildActionButton(
                                onPressed: () {
                                  if (_qrData != null && _qrData!.isNotEmpty) {
                                    _saveToHistory(_qrData!);
                                  }
                                },
                                icon: Icons.save_rounded,
                                label: 'Simpan',
                                color: accentColor,
                                isOutlined: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _qrData = null;
                            _qrColor = Colors.white;
                          }),
                          child: const Text('Bersihkan Data',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isOutlined,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: onPressed == null ? Colors.grey : color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade300,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}