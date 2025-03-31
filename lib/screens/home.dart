import 'package:flutter/material.dart';
import 'package:scanprice/screens/camera.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.camera_alt),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text('Dobrodošao u ScanPrice!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Skeniraj deklaraciju proizvoda i saznaj sve podatke u trenu.', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
