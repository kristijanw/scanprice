import 'package:hive/hive.dart';
import 'package:scanprice/models/product.dart';

part 'purchase.g.dart';

@HiveType(typeId: 1)
class Purchase {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final String store;

  @HiveField(2)
  final List<ProductInfo> products;

  @HiveField(3)
  final double total;

  Purchase({
    required this.date,
    required this.store,
    required this.products,
    required this.total,
  });

  /// Ukupan broj komada (zbroj količina svih stavki).
  int get itemCount => products.fold<int>(0, (sum, p) => sum + p.quantity);
}
