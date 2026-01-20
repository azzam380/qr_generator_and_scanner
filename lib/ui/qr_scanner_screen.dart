import 'dart:typed_data'; // FIX: Gunakan titik dua
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

const Color primaryColor = Color(0xFF0D47A1);
const Color accentColor = Color(0xFFF57C00);

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: true,
    formats: [BarcodeFormat.qrCode],
  );

  late AnimationController _animController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    WidgetsBinding.instance.addObserver(this);

    // Inisialisasi Animasi Garis Naik Turun
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  Future<void> _openHistoryPicker() async {
    _controller.stop();
    final selectedQr = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QrPickerScreen()),
    );

    if (selectedQr != null) {
      _launchURL(selectedQr);
    } else {
      _controller.start();
    }
  }

  Future<void> _scanFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    _controller.stop();
    // Di versi baru analyzeImage tidak perlu ditampung ke bool found
    try {
      await _controller.analyzeImage(image.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menganalisis gambar')),
      );
      _controller.start();
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (url.startsWith('http')) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showTextDialog(url);
      }
    } else {
      _showTextDialog(url);
    }
    _controller.start();
  }

  void _showTextDialog(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konten QR'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Pindai QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode != null && barcode.rawValue != null) {
                _showResultDialog(barcode.rawValue!);
              }
            },
          ),
          
          // Overlay Lubang Tengah
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                Center(
                  child: Container(
                    height: 260, width: 260,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),

          // ANIMASI GARIS NAIK TURUN
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Container(
                  width: 240,
                  height: 260,
                  alignment: Alignment(0, -1 + (_animController.value * 2)),
                  child: Container(
                    width: 240,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accentColor,
                      boxShadow: [
                        BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Tombol Aksi
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Column(
              children: [
                _buildActionButton(onTap: _openHistoryPicker, icon: Icons.history, label: 'Ambil dari Riwayat'),
                const SizedBox(height: 15),
                _buildActionButton(onTap: _scanFromGallery, icon: Icons.image, label: 'Ambil dari Galeri'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback onTap, required IconData icon, required String label}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(String value) {
    _controller.stop();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Terdeteksi'),
        content: Text(value),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); _controller.start(); }, child: const Text('Batal')),
          ElevatedButton(onPressed: () { Navigator.pop(ctx); _launchURL(value); }, child: const Text('Proses')),
        ],
      ),
    );
  }
}

// QrPickerScreen class sama seperti kode Anda sebelumnya
class QrPickerScreen extends StatelessWidget {
  const QrPickerScreen({super.key});

  Future<List<dynamic>> _getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('qr_history');
    if (data != null) return json.decode(data);
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih dari Riwayat'), backgroundColor: primaryColor, foregroundColor: Colors.white),
      body: FutureBuilder<List<dynamic>>(
        future: _getHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Riwayat kosong'));
          final history = snapshot.data!.reversed.toList();
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.qr_code, color: primaryColor),
                  title: Text(item['data'], maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, item['data']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

//