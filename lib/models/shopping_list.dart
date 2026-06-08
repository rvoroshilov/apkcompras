class ShoppingList {
  final String id;
  final String name;
  final double budget;
  final bool isTemplate;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ShoppingList({
    required this.id,
    required this.name,
    this.budget = 0.0,
    this.isTemplate = false,
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => completedAt != null;
  bool get hasBudget => budget > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'budget': budget,
        'is_template': isTemplate ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  factory ShoppingList.fromMap(Map<String, dynamic> map) => ShoppingList(
        id: map['id'] as String,
        name: map['name'] as String,
        budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
        isTemplate: (map['is_template'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
      );

  ShoppingList copyWith({
    String? name,
    double? budget,
    bool? isTemplate,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) =>
      ShoppingList(
        id: id,
        name: name ?? this.name,
        budget: budget ?? this.budget,
        isTemplate: isTemplate ?? this.isTemplate,
        createdAt: createdAt,
        completedAt:
            clearCompletedAt ? null : (completedAt ?? this.completedAt),
      );
}
