import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/service/api_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  bool _isLoading = false;
  List<ProductInfo> _products = [];

  Future<void> _openCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isLoading = true;
      });

      final service = GeminiAIService();
      final raw = await service.sendImage(_image!);

      final cleaned = raw.replaceAll('```json', '').replaceAll('```', '');
      final decoded = jsonDecode(cleaned);

      // ako je lista proizvoda, mapiraj
      final product = ProductInfo.fromJson(decoded);

      setState(() {
        _products = [product];
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Skeniraj proizvod")),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (_image != null) Image.file(_image!, height: 200, fit: BoxFit.cover),
                  const SizedBox(height: 10),
                  Expanded(
                    child:
                        _products.isEmpty
                            ? const Text("Nema podataka.")
                            : ListView.builder(
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
                            ),
                  ),
                ],
              ),
    );
  }
}
