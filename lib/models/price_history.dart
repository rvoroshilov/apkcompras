class PriceHistory {
  final String id;
  final String productId;
  final double price;
  final DateTime recordedAt;

  const PriceHistory({
    required this.id,
    required this.productId,
    required this.price,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'price': price,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory PriceHistory.fromMap(Map<String, dynamic> map) => PriceHistory(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        price: (map['price'] as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at'] as String),
      );
}
