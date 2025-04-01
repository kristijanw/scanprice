import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/service/api_service.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isLoading = false;
  List<ProductInfo> _products = [];

  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool isCameraReady = false;

  bool _isPortraitOverlay = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(_cameras.first, ResolutionPreset.medium);
    await _cameraController.initialize();
    setState(() => isCameraReady = true);
  }

  Future<File> _cropImage(File imageFile, bool portraitMode) async {
    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) throw Exception("Ne mogu dekodirati sliku.");

    final centerX = originalImage.width ~/ 2;
    final centerY = originalImage.height ~/ 2;

    // Dimenzije okvira koji koristiš (u pikselima, skalirat ćemo ih dolje)
    const portraitSize = Size(150, 250);
    const landscapeSize = Size(250, 150);

    final cropSize = portraitMode ? portraitSize : landscapeSize;

    // Uzmi dimenzije slike
    final imageWidth = originalImage.width;
    final imageHeight = originalImage.height;

    // Pretvori crop dimenzije u odnosu na sliku
    final widthRatio = cropSize.width / 300; // 300 = total width u UI previewu (pretpostavljeno)
    final heightRatio = cropSize.height / 300;

    int cropWidth = (imageWidth * widthRatio).toInt();
    int cropHeight = (imageHeight * heightRatio).toInt();

    // Ako je crop veći od slike, prilagodi
    cropWidth = cropWidth.clamp(0, imageWidth);
    cropHeight = cropHeight.clamp(0, imageHeight);

    final left = (centerX - cropWidth ~/ 2).clamp(0, imageWidth - cropWidth);
    final top = (centerY - cropHeight ~/ 2).clamp(0, imageHeight - cropHeight);

    final cropped = img.copyCrop(originalImage, x: left, y: top, width: cropWidth, height: cropHeight);

    final tempDir = await getTemporaryDirectory();
    final croppedFile = File('${tempDir.path}/cropped.jpg');
    await croppedFile.writeAsBytes(img.encodeJpg(cropped));

    return croppedFile;
  }

  Future<void> _captureAndAnalyze() async {
    if (!_cameraController.value.isInitialized) return;

    final image = await _cameraController.takePicture();
    final file = await _cropImage(File(image.path), _isPortraitOverlay);

    setState(() {
      _isLoading = true;
      _products.clear();
    });

    try {
      final service = GeminiAIService();
      final raw = await service.sendImage(file);
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> decoded = jsonDecode(cleaned);

      // Validacija ključeva
      if (decoded.containsKey('title') && decoded.containsKey('price') && decoded.containsKey('price_discount') && decoded.containsKey('card')) {
        final product = ProductInfo.fromJson(decoded);
        setState(() {
          _products = [product];
        });
      } else {
        _showError("AI nije prepoznao sve potrebne podatke.");
      }
    } catch (e) {
      _showError("Greška pri analizi slike.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Skeniraj proizvod")),
      body: Column(
        children: [
          // Kamera prikaz
          AspectRatio(
            aspectRatio: isCameraReady ? _cameraController.value.aspectRatio : 1.0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                isCameraReady ? CameraPreview(_cameraController) : const Center(child: CircularProgressIndicator()),

                // Overlay kvadrat
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _isPortraitOverlay ? 220 : 340,
                    height: _isPortraitOverlay ? 340 : 220,
                    decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent, width: 3), borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                // Ikonica za rotaciju
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _isPortraitOverlay = !_isPortraitOverlay;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Gumb za slikanje ili loader
          _isLoading
              ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
              : ElevatedButton.icon(onPressed: _captureAndAnalyze, icon: const Icon(Icons.camera_alt), label: const Text("Slikaj i analiziraj")),

          const SizedBox(height: 10),

          // Lista proizvoda ili "ponovi pokušaj"
          Expanded(
            child:
                _products.isNotEmpty
                    ? ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final p = _products[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          child: ListTile(
                            title: Text(p.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cijena: ${p.price.toStringAsFixed(2)} €"),
                                Text("Akcijska: ${p.priceDiscount.toStringAsFixed(2)} €"),
                                Text("Kartica: ${p.card ? 'DA' : 'NE'}"),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                    : !_isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Nema podataka."),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(onPressed: _captureAndAnalyze, icon: const Icon(Icons.refresh), label: const Text("Pokušaj ponovno")),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
