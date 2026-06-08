class ShoppingListItem {
  final String id;
  final String listId;
  final String? productId;
  final String productName;
  final String supermarketName;
  final double unitPrice;
  final double quantity;
  final String unit;
  final double discountPercent;
  final String notes;
  final bool isChecked;

  const ShoppingListItem({
    required this.id,
    required this.listId,
    this.productId,
    required this.productName,
    this.supermarketName = '',
    required this.unitPrice,
    this.quantity = 1.0,
    this.unit = 'ud',
    this.discountPercent = 0.0,
    this.notes = '',
    this.isChecked = false,
  });

  double get discountedUnitPrice => unitPrice * (1 - discountPercent / 100);
  double get totalPrice => discountedUnitPrice * quantity;
  bool get hasDiscount => discountPercent > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'list_id': listId,
        'product_id': productId,
        'product_name': productName,
        'supermarket_name': supermarketName,
        'unit_price': unitPrice,
        'quantity': quantity,
        'unit': unit,
        'discount_percent': discountPercent,
        'notes': notes,
        'is_checked': isChecked ? 1 : 0,
      };

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) =>
      ShoppingListItem(
        id: map['id'] as String,
        listId: map['list_id'] as String,
        productId: map['product_id'] as String?,
        productName: map['product_name'] as String,
        supermarketName: (map['supermarket_name'] as String?) ?? '',
        unitPrice: (map['unit_price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        unit: (map['unit'] as String?) ?? 'ud',
        discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0.0,
        notes: (map['notes'] as String?) ?? '',
        isChecked: (map['is_checked'] as int) == 1,
      );

  ShoppingListItem copyWith({
    double? unitPrice,
    double? quantity,
    String? unit,
    double? discountPercent,
    String? notes,
    bool? isChecked,
  }) =>
      ShoppingListItem(
        id: id,
        listId: listId,
        productId: productId,
        productName: productName,
        supermarketName: supermarketName,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        discountPercent: discountPercent ?? this.discountPercent,
        notes: notes ?? this.notes,
        isChecked: isChecked ?? this.isChecked,
      );
}
