class ProductInfo {
  final String title;
  final double price;
  final double priceDiscount;
  final bool card;

  ProductInfo({required this.title, required this.price, required this.priceDiscount, required this.card});

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      title: json['title'],
      price: (json['price'] as num).toDouble(),
      priceDiscount: (json['price_discount'] as num).toDouble(),
      card: json['card'] as bool,
    );
  }
}
