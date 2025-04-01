import 'package:flutter/material.dart';
import 'package:scanprice/models/product.dart';

class CartPreview extends StatelessWidget {
  final List<ProductInfo> products;
  final double total;

  const CartPreview({super.key, required this.products, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tvoja košarica', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...products.map(
            (p) => ListTile(title: Text(p.title), subtitle: Text('${(p.priceDiscount > 0 ? p.priceDiscount : p.price).toStringAsFixed(2)} €')),
          ),
          const Divider(),
          Text('Ukupno: ${total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
