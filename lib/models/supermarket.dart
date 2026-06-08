import 'package:flutter/material.dart';

class Supermarket {
  final String id;
  final String name;
  final int color;
  final DateTime createdAt;

  const Supermarket({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Color get flutterColor => Color(color);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'created_at': createdAt.toIso8601String(),
      };

  factory Supermarket.fromMap(Map<String, dynamic> map) => Supermarket(
        id: map['id'] as String,
        name: map['name'] as String,
        color: map['color'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Supermarket copyWith({String? name, int? color}) => Supermarket(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        createdAt: createdAt,
      );
}
