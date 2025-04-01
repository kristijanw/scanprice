import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/screens/camera.dart';
import 'package:scanprice/widgets/animated_cart_card.dart';
import 'package:scanprice/widgets/cart_preview.dart';

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

              const SizedBox(height: 40),

              // 👇 Dodaj prikaz košarice ako postoje proizvodi
              ValueListenableBuilder(
                valueListenable: Hive.box<ProductInfo>('cart').listenable(),
                builder: (context, Box<ProductInfo> box, _) {
                  if (box.isEmpty) return const SizedBox.shrink();

                  final products = box.values.toList();
                  final total = products.fold<double>(0.0, (sum, item) => sum + (item.priceDiscount > 0 ? item.priceDiscount : item.price));

                  return AnimatedCartCard(
                    itemCount: products.length,
                    total: total,
                    onTap: () {
                      // Navigacija npr. na CartScreen (ako postoji)
                      showModalBottomSheet(context: context, builder: (_) => CartPreview(products: products, total: total));
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
