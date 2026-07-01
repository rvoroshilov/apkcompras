import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Diálogo de confirmación con icono de cabecera, centrado y coherente en
/// toda la app. Devuelve true si el usuario confirma.
///
/// Ejemplo:
/// ```dart
/// final ok = await confirmDialog(context,
///     icon: Icons.delete_outline,
///     title: 'Eliminar lista',
///     message: '¿Seguro?',
///     confirmLabel: 'Eliminar',
///     danger: true);
/// ```
Future<bool> confirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? message,
  String confirmLabel = 'Aceptar',
  String cancelLabel = 'Cancelar',
  Color? iconColor,
  bool danger = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final color = iconColor ?? (danger ? AppConstants.danger : cs.primary);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 30),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: message == null
          ? null
          : Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: AppConstants.danger)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
