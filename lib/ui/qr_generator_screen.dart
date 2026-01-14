import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// Import untuk PDF dan Printing
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color primaryColor = Color(0xFF3A2EC3);

const List<Color> qrColors = [
  Colors.white,
  Colors.grey,
  Colors.orange,
  Colors.yellow,
  Colors.green,
  Colors.cyan,
  Colors.purple,
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

  // --- Fungsi Helper: Loading Dialog ---
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  // --- Fungsi: Capture & Share (Email Friendly) ---
  Future<void> _captureAndShare({bool isEmailFriendly = false}) async {
    if (_qrData == null || _qrData!.isEmpty) return;

    final Uint8List? imageBytes = await _screenshotController.capture(
      pixelRatio: MediaQuery.of(context).devicePixelRatio,
    );

    if (imageBytes != null) {
      final String shareText = isEmailFriendly
          ? 'Ini QR Code untuk: ${_qrData ?? 'tidak ada'}\nDibuat menggunakan QR S&G oleh [Nama Anda]'
          : 'QR Code untuk: $_qrData\nDibuat dengan QR S&G';

      final String? subject = isEmailFriendly
          ? 'QR Code dari QR S&G App'
          : null;

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
                  pw.Text(
                    'Link/Teks:',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    '$_qrData',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 40),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Dibuat oleh: [Nama Anda] - QR S&G App',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Tutup loading sebelum buka preview
      if (mounted) Navigator.pop(context);

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
      appBar: AppBar(
        title: const Text('Create QR', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(height: 220, color: primaryColor),
              Expanded(child: Container(color: Colors.grey.shade50)),
            ],
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _qrColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.black12,
                                width: 2,
                              ),
                            ),
                            child: _qrData == null || _qrData!.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Text(
                                      'Masukkan teks untuk QR',
                                      textAlign: TextAlign.center,
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
                        const SizedBox(height: 24),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Link atau Teks',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 2,
                          onChanged: (value) => setState(
                            () => _qrData = value.trim().isEmpty
                                ? null
                                : value.trim(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 10,
                          children: qrColors
                              .map(
                                (color) => GestureDetector(
                                  onTap: () => setState(() => _qrColor = color),
                                  child: CircleAvatar(
                                    backgroundColor: color,
                                    radius: 18,
                                    child: _qrColor == color
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.black,
                                          )
                                        : null,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // --- ROW ACTION BUTTONS ---
                        Row(
                          children: [
                            // Tombol Print (PDF) - Menggunakan ukuran proporsional
                            Expanded(
                              flex: 2, // Memberi sedikit ruang lebih sempit
                              child: OutlinedButton.icon(
                                onPressed: _generateAndPrintPdf,
                                icon: const Icon(Icons.print, size: 18),
                                label: const Text(
                                  'PDF',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blueGrey,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Tombol Share - Menggunakan ukuran fleksibel
                            Expanded(
                              flex:
                                  3, // Memberi ruang lebih luas untuk teks "Share"
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _captureAndShare(isEmailFriendly: false),
                                icon: const Icon(Icons.share, size: 18),
                                label: const Text(
                                  'Share',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Tombol Send
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _captureAndShare(isEmailFriendly: true),
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text(
                                  'Send',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _qrData = null;
                            _qrColor = Colors.white;
                          }),
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: Colors.red),
                          ),
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
}
