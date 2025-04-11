import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool isCameraReady = false;

  bool _isPortraitOverlay = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(_cameras.first, ResolutionPreset.high);
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

  Future<String> _saveImageToLocal(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final newFile = await image.copy(path);
    return newFile.path;
  }

  Future<void> _captureAndAnalyze() async {
    if (!_cameraController.value.isInitialized) return;

    final image = await _cameraController.takePicture();
    final file = await _cropImage(File(image.path), _isPortraitOverlay);

    setState(() {
      _isLoading = true;
    });

    try {
      final service = GeminiAIService();
      final raw = await service.sendImage(file);
      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> decoded = jsonDecode(cleaned);

      // Validacija ključeva
      if (decoded.containsKey('title') && decoded.containsKey('price') && decoded.containsKey('price_discount') && decoded.containsKey('card')) {
        final savedImagePath = await _saveImageToLocal(file);
        final product = ProductInfo.fromJson(decoded).copyWith(imagePath: savedImagePath);
        final box = Hive.box<ProductInfo>('cart');

        // ignore: use_build_context_synchronously
        final quantity = await _showQuantityInputDialog(context);

        if (quantity != null && quantity > 0) {
          for (int i = 0; i < quantity; i++) {
            box.add(product);
          }
        }
      } else {
        _showError("Scan nije prepoznao sve potrebne podatke.");
      }
    } catch (e) {
      _showError("Greška pri analizi slike.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int?> _showQuantityInputDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();

    return await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Unesi količinu"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Npr. 1, 2, 3..."),
          ),
          actions: [
            TextButton(child: const Text("Odustani"), onPressed: () => Navigator.of(context).pop(null)),
            TextButton(
              child: const Text("Dodaj"),
              onPressed: () {
                final input = int.tryParse(controller.text);
                if (input != null && input > 0) {
                  Navigator.of(context).pop(input);
                } else {
                  // Ako unese nešto nevalidno, ostaje u dialogu
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unesi ispravan broj!")));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showImagePreview(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                InteractiveViewer(child: Image.file(imageFile)),
                Positioned(
                  top: 24,
                  right: 24,
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.of(context).pop()),
                ),
              ],
            ),
          ),
    );
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
          SizedBox(
            // aspectRatio: isCameraReady ? _cameraController.value.aspectRatio : 1.0,
            height: 300,
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

          if (_isLoading) const CircularProgressIndicator(),

          // Lista proizvoda ili "ponovi pokušaj"
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<ProductInfo>('cart').listenable(),
              builder: (context, Box<ProductInfo> box, _) {
                if (box.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Nema skeniranih proizvoda."),
                        const Text(
                          "Prije skeniranja proizvoda, pozicionirajte kameru prema deklaraciji i neka bude unutar zelenog okvira!!",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: box.length,
                  padding: const EdgeInsets.only(bottom: 100),
                  itemBuilder: (context, index) {
                    final reverseIndex = box.length - 1 - index;
                    final key = box.keyAt(reverseIndex);
                    final items = box.get(key);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      child: ListTile(
                        leading:
                            items!.imagePath != null
                                ? GestureDetector(
                                  onTap: () => _showImagePreview(context, File(items.imagePath!)),
                                  child: Image.file(File(items.imagePath!), width: 50, height: 50, fit: BoxFit.cover),
                                )
                                : null,
                        title: Text(items.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Cijena: ${items.price.toStringAsFixed(2)} €"),
                            Text("Akcijska: ${items.priceDiscount.toStringAsFixed(2)} €"),
                            Text("Kartica: ${items.card ? 'DA' : 'NE'}"),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Potvrdi brisanje'),
                                  content: const Text('Jesi li siguran da želiš obrisati ovaj proizvod?'),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Odustani'),
                                      onPressed: () {
                                        Navigator.of(context).pop(false);
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('Obriši', style: TextStyle(color: Colors.red)),
                                      onPressed: () {
                                        Navigator.of(context).pop(true);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              Hive.box<ProductInfo>('cart').delete(key);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          _isLoading
              ? SizedBox()
              : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _captureAndAnalyze,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Slikaj"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      iconColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Obriši sve'),
                            content: const Text('Jesi li siguran da želiš obrisati sve proizvode iz liste?'),
                            actions: <Widget>[
                              TextButton(child: const Text('Odustani'), onPressed: () => Navigator.of(context).pop(false)),
                              TextButton(
                                child: const Text('Obriši sve', style: TextStyle(color: Colors.red)),
                                onPressed: () => Navigator.of(context).pop(true),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm == true) {
                        Hive.box<ProductInfo>('cart').clear();
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Obriši sve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      iconColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ],
              ),
      bottomNavigationBar: ValueListenableBuilder(
        valueListenable: Hive.box<ProductInfo>('cart').listenable(),
        builder: (context, Box<ProductInfo> box, _) {
          final products = box.values.toList();
          final total = products.fold<double>(0.0, (sum, item) => sum + (item.priceDiscount > 0 ? item.priceDiscount : item.price));

          return Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ukupno:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
}
