import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scanprice/models/product.dart';
import 'package:scanprice/models/purchase.dart';

/// Pomoćne radnje nad košaricom koje se dijele između ekrana.
class CartService {
  static const _primary = Color(0xFF6366F1);

  /// Završi kupnju: pita za trgovinu, spremi košaricu u povijest i isprazni je.
  /// Vraća `true` ako je kupnja spremljena.
  static Future<bool> completePurchase(BuildContext context) async {
    final cart = Hive.box<ProductInfo>('cart');
    if (cart.isEmpty) {
      _snack(context, 'Košarica je prazna.');
      return false;
    }

    final store = await _askStore(context);
    if (store == null) return false; // odustao

    final products = cart.values.toList();
    final total = products.fold<double>(0.0, (sum, p) => sum + p.lineTotal);

    final purchase = Purchase(
      date: DateTime.now(),
      store: store.trim().isEmpty ? 'Nepoznata trgovina' : store.trim(),
      products: products,
      total: total,
    );

    await Hive.box<Purchase>('history').add(purchase);
    await cart.clear();

    // ignore: use_build_context_synchronously
    if (context.mounted) _snack(context, 'Kupnja spremljena u povijest.');
    return true;
  }

  static Future<String?> _askStore(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Završi kupnju', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('U kojoj trgovini si kupovao?', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'npr. Konzum, Lidl, Plodine',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(child: const Text('Odustani'), onPressed: () => Navigator.of(context).pop(null)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            child: const Text('Spremi'),
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
