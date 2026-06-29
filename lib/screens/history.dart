import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scanprice/models/purchase.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _primary = Color(0xFF6366F1);

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}. ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Povijest kupnji', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              Text('Tvoje spremljene košarice', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 20),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: Hive.box<Purchase>('history').listenable(),
                  builder: (context, Box<Purchase> box, _) {
                    if (box.isEmpty) {
                      return _emptyState();
                    }
                    // Najnovije prvo.
                    final keys = box.keys.toList().reversed.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: keys.length,
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        final purchase = box.get(key)!;
                        return _PurchaseCard(
                          purchase: purchase,
                          onTap: () => _showDetail(context, purchase),
                          onDelete: () => _confirmDelete(context, box, key),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text('Još nema spremljenih kupnji', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[500])),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Skeniraj proizvode i pritisni "Završi kupnju" da spremiš košaricu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Box<Purchase> box, dynamic key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obriši kupnju'),
        content: const Text('Jesi li siguran da želiš obrisati ovu kupnju iz povijesti?'),
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
    if (confirm == true) await box.delete(key);
  }

  void _showDetail(BuildContext context, Purchase purchase) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PurchaseDetail(purchase: purchase),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PurchaseCard({required this.purchase, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HistoryScreen._primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: HistoryScreen._primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(purchase.store, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    '${HistoryScreen._formatDate(purchase.date)} · ${purchase.itemCount} kom',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${purchase.total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: HistoryScreen._primary)),
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDetail extends StatelessWidget {
  final Purchase purchase;

  const _PurchaseDetail({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(purchase.store, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(HistoryScreen._formatDate(purchase.date), style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${purchase.products.length} stavki', style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: purchase.products.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = purchase.products[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: p.imagePath != null && File(p.imagePath!).existsSync()
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
                            if (p.quantity > 1)
                              Text('${p.unitPrice.toStringAsFixed(2)} € × ${p.quantity}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Text('${p.lineTotal.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                Text('${purchase.total.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF6366F1))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
