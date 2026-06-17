class PantryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final DateTime? expiryDate;
  final String imagePath;
  final String notes;
  final String? productId;
  final double minStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    this.unit = 'ud',
    this.category = 'General',
    this.expiryDate,
    this.imagePath = '',
    this.notes = '',
    this.productId,
    this.minStock = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    return expiryDate!.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    return expiryDate!.difference(DateTime.now()).inDays <= 3;
  }

  bool get isBelowMinStock => minStock > 0 && quantity < minStock;

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    return expiryDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        'expiry_date': expiryDate?.toIso8601String(),
        'image_path': imagePath,
        'notes': notes,
        'product_id': productId,
        'min_stock': minStock,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PantryItem.fromMap(Map<String, dynamic> map) => PantryItem(
        id: map['id'] as String,
        name: map['name'] as String,
        quantity: (map['quantity'] as num).toDouble(),
        unit: (map['unit'] as String?) ?? 'ud',
        category: (map['category'] as String?) ?? 'General',
        expiryDate: map['expiry_date'] != null
            ? DateTime.parse(map['expiry_date'] as String)
            : null,
        imagePath: (map['image_path'] as String?) ?? '',
        notes: (map['notes'] as String?) ?? '',
        productId: map['product_id'] as String?,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  PantryItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? category,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    String? imagePath,
    String? notes,
    double? minStock,
  }) =>
      PantryItem(
        id: id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
        imagePath: imagePath ?? this.imagePath,
        notes: notes ?? this.notes,
        productId: productId,
        minStock: minStock ?? this.minStock,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
