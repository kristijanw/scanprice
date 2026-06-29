import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/service/api_service.dart';
import 'package:scanprice/service/cart_service.dart';
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

  static const _primary = Color(0xFF6366F1);

  // Sklopljeni sheet zauzima ovaj udio ekrana; ostatak je vidljiva kamera.
  static const double _collapsed = 0.16;
  static const double _expanded = 0.9;

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
    const portraitSize = Size(200, 280);
    const landscapeSize = Size(280, 200);
    final cropSize = portraitMode ? portraitSize : landscapeSize;
    final imageWidth = originalImage.width;
    final imageHeight = originalImage.height;
    int cropWidth = (imageWidth * cropSize.width / 300).toInt().clamp(0, imageWidth);
    int cropHeight = (imageHeight * cropSize.height / 300).toInt().clamp(0, imageHeight);
    final left = (centerX - cropWidth ~/ 2).clamp(0, imageWidth - cropWidth);
    final top = (centerY - cropHeight ~/ 2).clamp(0, imageHeight - cropHeight);
    var cropped = img.copyCrop(originalImage, x: left, y: top, width: cropWidth, height: cropHeight);
    // Downscale so the longest side is at most 1000px (still readable for OCR)
    // to keep the upload small and reduce vision token cost.
    const maxSide = 1000;
    if (cropped.width > maxSide || cropped.height > maxSide) {
      if (cropped.width >= cropped.height) {
        cropped = img.copyResize(cropped, width: maxSide);
      } else {
        cropped = img.copyResize(cropped, height: maxSide);
      }
    }
    final tempDir = await getTemporaryDirectory();
    final croppedFile = File('${tempDir.path}/cropped.jpg');
    // quality: 80 compresses well with no visible loss on a price tag.
    await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 80));
    return croppedFile;
  }

  Future<String> _saveImageToLocal(File image) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return (await image.copy(path)).path;
  }

  Future<void> _captureAndAnalyze() async {
    if (!_cameraController.value.isInitialized) return;
    final image = await _cameraController.takePicture();
    final file = await _cropImage(File(image.path), _isPortraitOverlay);
    setState(() => _isLoading = true);
    try {
      final raw = await OpenAIService().sendImage(file);
      final Map<String, dynamic> decoded = jsonDecode(raw);
      if (decoded.containsKey('title') && decoded.containsKey('price') && decoded.containsKey('price_discount') && decoded.containsKey('card')) {
        final savedImagePath = await _saveImageToLocal(file);
        final box = Hive.box<ProductInfo>('cart');
        // ignore: use_build_context_synchronously
        final quantity = await _showQuantityInputDialog(context);
        if (quantity != null && quantity > 0) {
          final product = ProductInfo.fromJson(decoded).copyWith(imagePath: savedImagePath, quantity: quantity);
          box.add(product);
        }
      } else {
        _showError("Scan nije prepoznao sve potrebne podatke.");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<int?> _showQuantityInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    return await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Količina", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Upiši broj",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
          ),
        ),
        actions: [
          TextButton(child: const Text("Odustani"), onPressed: () => Navigator.of(context).pop(null)),
          FilledButton(
            child: const Text("Dodaj"),
            onPressed: () {
              final input = int.tryParse(controller.text);
              if (input != null && input > 0) {
                Navigator.of(context).pop(input);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text("Unesi ispravan broj!"), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showImagePreview(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.file(imageFile)),
            Positioned(
              top: 24,
              right: 24,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obriši sve'),
        content: const Text('Jesi li siguran da želiš obrisati sve proizvode?'),
        actions: [
          TextButton(child: const Text('Odustani'), onPressed: () => Navigator.of(context).pop(false)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši sve'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirm == true) Hive.box<ProductInfo>('cart').clear();
  }

  Future<void> _confirmDeleteOne(dynamic key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obriši proizvod'),
        content: const Text('Jesi li siguran?'),
        actions: [
          TextButton(child: const Text('Odustani'), onPressed: () => Navigator.of(context).pop(false)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirm == true) Hive.box<ProductInfo>('cart').delete(key);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final collapsedHeight = media.size.height * _collapsed;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen camera preview
          Positioned.fill(child: _buildCameraPreview()),

          // Scan frame overlay (centered – matches the center crop)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isPortraitOverlay ? 270 : 350,
                  height: _isPortraitOverlay ? 400 : 270,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2.5),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),

          // Top controls
          Positioned(
            top: media.padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _circleButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
                const Spacer(),
                _circleButton(
                  icon: Icons.flip_camera_android_rounded,
                  onTap: () => setState(() => _isPortraitOverlay = !_isPortraitOverlay),
                ),
              ],
            ),
          ),

          // Hint + capture button, sit just above the collapsed sheet
          Positioned(
            bottom: collapsedHeight + 24,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                    'Pozicioniraj deklaraciju unutar okvira',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 18),
                _buildCaptureButton(),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 14),
                      Text("Analiziram...", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),

          // Draggable product sheet
          _buildSheet(context),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!isCameraReady) {
      return Container(color: const Color(0xFF1A1A2E), child: const Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final preview = _cameraController.value.previewSize!;
    // previewSize is reported in landscape orientation, so swap for portrait cover.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(_cameraController),
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.white, size: 22)),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _captureAndAnalyze,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.25),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: const Icon(Icons.camera_alt, color: _primary, size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _collapsed,
      minChildSize: _collapsed,
      maxChildSize: _expanded,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, -4))],
          ),
          child: ValueListenableBuilder(
            valueListenable: Hive.box<ProductInfo>('cart').listenable(),
            builder: (context, Box<ProductInfo> box, _) {
              final total = box.values.fold<double>(0.0, (sum, item) => sum + item.lineTotal);
              return CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(child: _sheetHeader(box, total)),
                  if (box.isEmpty)
                    SliverToBoxAdapter(child: _emptyState())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final reverseIndex = box.length - 1 - index;
                          final key = box.keyAt(reverseIndex);
                          final item = box.get(key)!;
                          return _productTile(key, item);
                        },
                        childCount: box.length,
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _sheetHeader(Box<ProductInfo> box, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                box.isEmpty ? 'Košarica' : '${box.length} ${box.length == 1 ? 'proizvod' : 'proizvoda'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _primary)),
            ],
          ),
          if (box.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => CartService.completePurchase(context),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Završi kupnju', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: IconButton(
                    onPressed: _confirmDeleteAll,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text("Nema skeniranih proizvoda", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text(
            "Slikaj deklaraciju i proizvod će se pojaviti ovdje.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _productTile(dynamic key, ProductInfo item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Dismissible(
        key: Key(key.toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => Hive.box<ProductInfo>('cart').delete(key),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: item.imagePath != null ? () => _showImagePreview(context, File(item.imagePath!)) : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.imagePath != null
                        ? Image.file(File(item.imagePath!), width: 56, height: 56, fit: BoxFit.cover)
                        : Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFFF2F2F7),
                            child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFFAEAEB2)),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          if (item.quantity > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('×${item.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (item.priceDiscount > 0) ...[
                            Text('${item.price.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2), decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text('${item.priceDiscount.toStringAsFixed(2)} €', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                            ),
                          ] else
                            Text('${item.price.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                          if (item.card) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Kartica', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _primary)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFAEAEB2), size: 20),
                  onPressed: () => _confirmDeleteOne(key),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
