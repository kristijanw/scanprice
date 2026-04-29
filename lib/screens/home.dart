import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/screens/camera.dart';
import 'package:scanprice/widgets/animated_cart_card.dart';
import 'package:scanprice/widgets/cart_preview.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _primary = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ScanPrice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                      Text('Pametno kupovanje', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 48),

              const Text('Skeniraj.\nUštedi.', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), height: 1.1)),
              const SizedBox(height: 14),
              Text(
                'Usmjeri kameru prema deklaraciji i odmah dobij naziv, cijenu i popust.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6),
              ),

              const SizedBox(height: 40),

              // Scan CTA
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScreen())),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: _primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Skeniraj proizvod', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Cart card
              ValueListenableBuilder(
                valueListenable: Hive.box<ProductInfo>('cart').listenable(),
                builder: (context, Box<ProductInfo> box, _) {
                  if (box.isEmpty) return const SizedBox.shrink();
                  final products = box.values.toList();
                  final total = products.fold<double>(0.0, (sum, item) => sum + (item.priceDiscount > 0 ? item.priceDiscount : item.price));
                  return AnimatedCartCard(
                    itemCount: products.length,
                    total: total,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CartPreview(products: products, total: total),
                    ),
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
