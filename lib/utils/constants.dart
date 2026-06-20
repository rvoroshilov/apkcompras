import 'package:flutter/material.dart';

class AppConstants {
  static const List<String> units = [
    'ud', 'kg', 'g', 'L', 'mL', 'pack', 'caja', 'botella', 'lata', 'bolsa',
  ];

  static const List<String> categories = [
    'General', 'Frutas y verduras', 'Carnes', 'Pescados', 'Lácteos',
    'Frigorífico', 'Panadería', 'Bebidas', 'Congelados', 'Conservas',
    'Cereales y legumbres', 'Snacks y dulces', 'Higiene', 'Limpieza', 'Otros',
  ];

  static const List<({String name, String emoji, Color color})> colorThemes = [
    (name: 'Esmeralda', emoji: '🌿', color: Color(0xFF2E7D32)),
    (name: 'Rosa',      emoji: '🌸', color: Color(0xFFE91E63)),
    (name: 'Lavanda',   emoji: '💜', color: Color(0xFF7B1FA2)),
    (name: 'Cielo',     emoji: '🩵', color: Color(0xFF0288D1)),
    (name: 'Coral',     emoji: '🍊', color: Color(0xFFE64A19)),
    (name: 'Turquesa',  emoji: '🌊', color: Color(0xFF00897B)),
    (name: 'Dorado',    emoji: '✨', color: Color(0xFFF57F17)),
  ];

  static IconData categoryIcon(String category) => switch (category) {
    'Frutas y verduras'    => Icons.eco_outlined,
    'Carnes'               => Icons.kebab_dining_outlined,
    'Pescados'             => Icons.set_meal_outlined,
    'Lácteos'              => Icons.egg_alt_outlined,
    'Frigorífico'          => Icons.kitchen_outlined,
    'Panadería'            => Icons.bakery_dining_outlined,
    'Bebidas'              => Icons.local_drink_outlined,
    'Congelados'           => Icons.ac_unit,
    'Conservas'            => Icons.lunch_dining_outlined,
    'Cereales y legumbres' => Icons.grain,
    'Snacks y dulces'      => Icons.cookie_outlined,
    'Higiene'              => Icons.soap_outlined,
    'Limpieza'             => Icons.cleaning_services_outlined,
    'General'              => Icons.category_outlined,
    _                      => Icons.more_horiz,
  };

  static Color categoryColor(String category) => switch (category) {
    'Frutas y verduras'    => const Color(0xFF4CAF50),
    'Carnes'               => const Color(0xFFE53935),
    'Pescados'             => const Color(0xFF1E88E5),
    'Lácteos'              => const Color(0xFFFDD835),
    'Frigorífico'          => const Color(0xFF29B6F6),
    'Panadería'            => const Color(0xFFFF8F00),
    'Bebidas'              => const Color(0xFF00ACC1),
    'Congelados'           => const Color(0xFF42A5F5),
    'Conservas'            => const Color(0xFF795548),
    'Cereales y legumbres' => const Color(0xFFFFB300),
    'Snacks y dulces'      => const Color(0xFFE91E63),
    'Higiene'              => const Color(0xFF9C27B0),
    'Limpieza'             => const Color(0xFF009688),
    'General'              => const Color(0xFF607D8B),
    _                      => const Color(0xFF9E9E9E),
  };

  static const List<String> avatarEmojis = [
    '🏠', '🌿', '🌸', '🌟', '🦋', '🍀',
    '🌈', '🎨', '🧁', '🍕', '🎵', '🌙',
    '🦊', '🐱', '🐶', '🌺', '🍓', '🎯',
    '🦄', '🌊', '🍉', '🎪',
  ];

  static const List<({String name, String description})> backgroundStyles = [
    (name: 'Plano',     description: 'Sin degradado'),
    (name: 'Suave',     description: 'Toque de color'),
    (name: 'Degradado', description: 'Vibrante'),
  ];

  static const List<Color> supermarketColors = [
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFC62828),
    Color(0xFF6A1B9A), Color(0xFFE65100), Color(0xFF00695C),
    Color(0xFF4527A0), Color(0xFF37474F), Color(0xFF558B2F),
    Color(0xFFAD1457),
  ];

  static const String notificationChannelId   = 'expiry_alerts';
  static const String notificationChannelName = 'Alertas de caducidad';
  static const String notificationChannelDesc =
      'Notificaciones para productos próximos a caducar';

  // ── Tokens de diseño ───────────────────────────────────────────
  // Radios unificados para que todas las superficies tengan la misma
  // redondez según su jerarquía.
  static const double radiusLg = 20; // tarjetas grandes
  static const double radiusMd = 16; // filas y contenedores internos
  static const double radiusSm = 12; // chips y badges pequeños

  // ── Colores semánticos de estado ───────────────────────────────
  // Son constantes (no dependen del tema de color) para que el rojo
  // signifique siempre "peligro", el naranja "aviso", etc. en toda la app.
  static const Color danger  = Color(0xFFE53935); // caducado / eliminar / agotado
  static const Color warning = Color(0xFFFB8C00); // caduca pronto
  static const Color success = Color(0xFF43A047); // todo correcto
  static const Color info    = Color(0xFF1E88E5); // stock bajo / informativo
}

