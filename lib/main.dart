import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/service/api_service.dart'; // Import GeminiAIService

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanPrice',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'ScanPrice Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GeminiAIService _geminiAIService = GeminiAIService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  ProductInfo? _productInfo;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image first!')));
      return;
    }

    try {
      final rawResponse = await _geminiAIService.sendImage(_selectedImage!);

      // Ukloni eventualne ```json oznake ako postoje
      final cleanedJson = rawResponse.replaceAll('```json', '').replaceAll('```', '').trim();

      final Map<String, dynamic> jsonMap = jsonDecode(cleanedJson);
      final productInfo = ProductInfo.fromJson(jsonMap);

      setState(() {
        _productInfo = productInfo;
      });
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            if (_selectedImage != null) Image.file(_selectedImage!, height: 200, width: double.infinity, fit: BoxFit.contain),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _pickImage, child: const Text('Pick Image')),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _sendImage, child: const Text('Send Image')),
            const SizedBox(height: 20),
            if (_productInfo != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Naziv: ${_productInfo!.title}'),
                  Text('Cijena: ${_productInfo!.price.toStringAsFixed(2)} €'),
                  Text('Akcijska cijena: ${_productInfo!.priceDiscount.toStringAsFixed(2)} €'),
                  Text('Kartica pogodnosti: ${_productInfo!.card ? "DA" : "NE"}'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
