class Product {
  final String id;
  final String supermarketId;
  final String name;
  final String brand;
  final String barcode;
  final String category;
  final String imagePath;
  final double price;
  final String unit;
  final double quantityPerUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.supermarketId,
    required this.name,
    this.brand = '',
    this.barcode = '',
    this.category = 'General',
    this.imagePath = '',
    required this.price,
    this.unit = 'ud',
    this.quantityPerUnit = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  double get pricePerKgOrL {
    switch (unit) {
      case 'kg':
      case 'L':
        return price;
      case 'g':
        return quantityPerUnit > 0 ? (price / quantityPerUnit) * 1000 : price;
      case 'mL':
        return quantityPerUnit > 0 ? (price / quantityPerUnit) * 1000 : price;
      default:
        return price;
    }
  }

  String get normalizedUnit {
    switch (unit) {
      case 'g':
        return 'kg';
      case 'mL':
        return 'L';
      default:
        return unit;
    }
  }

  bool get hasNormalizedPrice => ['kg', 'L', 'g', 'mL'].contains(unit);

  Map<String, dynamic> toMap() => {
        'id': id,
        'supermarket_id': supermarketId,
        'name': name,
        'brand': brand,
        'barcode': barcode,
        'category': category,
        'image_path': imagePath,
        'price': price,
        'unit': unit,
        'quantity_per_unit': quantityPerUnit,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as String,
        supermarketId: map['supermarket_id'] as String,
        name: map['name'] as String,
        brand: (map['brand'] as String?) ?? '',
        barcode: (map['barcode'] as String?) ?? '',
        category: (map['category'] as String?) ?? 'General',
        imagePath: (map['image_path'] as String?) ?? '',
        price: (map['price'] as num).toDouble(),
        unit: (map['unit'] as String?) ?? 'ud',
        quantityPerUnit: (map['quantity_per_unit'] as num?)?.toDouble() ?? 1.0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Product copyWith({
    String? name,
    String? brand,
    String? barcode,
    String? category,
    String? imagePath,
    double? price,
    String? unit,
    double? quantityPerUnit,
  }) =>
      Product(
        id: id,
        supermarketId: supermarketId,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        barcode: barcode ?? this.barcode,
        category: category ?? this.category,
        imagePath: imagePath ?? this.imagePath,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        quantityPerUnit: quantityPerUnit ?? this.quantityPerUnit,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
