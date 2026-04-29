import 'dart:io';
import 'package:flutter/material.dart';
import 'package:scanprice/models/product.dart';

class CartPreview extends StatelessWidget {
  final List<ProductInfo> products;
  final double total;

  const CartPreview({super.key, required this.products, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text('Košarica', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${products.length} stavki', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = products[index];
                final effectivePrice = p.priceDiscount > 0 ? p.priceDiscount : p.price;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: p.imagePath != null
                            ? Image.file(File(p.imagePath!), width: 46, height: 46, fit: BoxFit.cover)
                            : Container(
                                width: 46,
                                height: 46,
                                color: const Color(0xFFF2F2F7),
                                child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFFAEAEB2), size: 20),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (p.priceDiscount > 0)
                              Text('${p.price.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2), decoration: TextDecoration.lineThrough)),
                          ],
                        ),
                      ),
                      Text('${effectivePrice.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                const Text('Ukupno', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
