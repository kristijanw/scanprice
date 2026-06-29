import 'package:hive/hive.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class ProductInfo {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final double price;

  @HiveField(2)
  final double priceDiscount;

  @HiveField(3)
  final bool card;

  @HiveField(4)
  final String? imagePath; // Za spremljenu sliku

  @HiveField(5)
  final int quantity;

  ProductInfo({
    required this.title,
    required this.price,
    required this.priceDiscount,
    required this.card,
    this.imagePath,
    this.quantity = 1,
  });

  /// Efektivna cijena jedne stavke (popust ako postoji, inače redovna).
  double get unitPrice => priceDiscount > 0 ? priceDiscount : price;

  /// Ukupna cijena ove stavke uzimajući u obzir količinu.
  double get lineTotal => unitPrice * quantity;

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      title: json['title'],
      price: (json['price'] as num).toDouble(),
      priceDiscount: (json['price_discount'] as num?)?.toDouble() ?? 0.0,
      card: json['card'] as bool,
    );
  }

  ProductInfo copyWith({String? title, double? price, double? priceDiscount, bool? card, String? imagePath, int? quantity}) {
    return ProductInfo(
      title: title ?? this.title,
      price: price ?? this.price,
      priceDiscount: priceDiscount ?? this.priceDiscount,
      card: card ?? this.card,
      imagePath: imagePath ?? this.imagePath,
      quantity: quantity ?? this.quantity,
    );
  }
}
