import 'package:flutter/material.dart';

class AppConstants {
  static const List<String> units = [
    'ud',
    'kg',
    'g',
    'L',
    'mL',
    'pack',
    'caja',
    'botella',
    'lata',
    'bolsa',
  ];

  static const List<String> categories = [
    'General',
    'Frutas y verduras',
    'Carnes',
    'Pescados',
    'Lácteos',
    'Panadería',
    'Bebidas',
    'Congelados',
    'Conservas',
    'Cereales y legumbres',
    'Snacks y dulces',
    'Higiene',
    'Limpieza',
    'Otros',
  ];

  static const List<Color> supermarketColors = [
    Color(0xFF1565C0), // Azul oscuro
    Color(0xFF2E7D32), // Verde oscuro
    Color(0xFFC62828), // Rojo oscuro
    Color(0xFF6A1B9A), // Morado
    Color(0xFFE65100), // Naranja oscuro
    Color(0xFF00695C), // Verde azulado
    Color(0xFF4527A0), // Índigo
    Color(0xFF37474F), // Gris azul
    Color(0xFF558B2F), // Verde oliva
    Color(0xFFAD1457), // Rosa oscuro
  ];

  static const String notificationChannelId = 'expiry_alerts';
  static const String notificationChannelName = 'Alertas de caducidad';
  static const String notificationChannelDesc =
      'Notificaciones para productos próximos a caducar';
}
