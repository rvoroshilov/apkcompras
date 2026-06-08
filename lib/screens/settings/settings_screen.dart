import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/shopping_provider.dart';
import '../../utils/backup_helper.dart';
import '../../utils/notification_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final monthFmt = DateFormat('MMMM yyyy', 'es_ES');
    final shopping = context.watch<ShoppingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats section
          _SectionTitle('Estadísticas del mes'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.euro,
                    label: 'Gasto en ${monthFmt.format(DateTime.now())}',
                    value: fmt.format(shopping.monthlySpend),
                  ),
                  const Divider(),
                  _InfoRow(
                    icon: Icons.check_circle_outline,
                    label: 'Listas completadas este mes',
                    value: shopping.completedLists
                        .where((l) =>
                            l.completedAt != null &&
                            l.completedAt!.month == DateTime.now().month &&
                            l.completedAt!.year == DateTime.now().year)
                        .length
                        .toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Backup section
          _SectionTitle('Copia de seguridad'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_outlined),
                  title: const Text('Exportar datos'),
                  subtitle: const Text(
                      'Exporta tu base de datos para transferirla o hacer backup'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _export(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Importar datos'),
                  subtitle: const Text(
                      'Importa un backup de MiCompra (archivo .db)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _import(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notifications section
          _SectionTitle('Notificaciones'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Activar notificaciones'),
              subtitle:
                  const Text('Permite recibir alertas de caducidad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => NotificationHelper.requestPermission(),
            ),
          ),
          const SizedBox(height: 16),

          // About section
          _SectionTitle('Acerca de'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('MiCompra'),
                  subtitle: Text(
                      'v1.0.0 — Gestiona tu despensa y lista de la compra'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Base de datos'),
                  subtitle: Text('SQLite local · Los datos no salen del dispositivo'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Características'),
                  subtitle: const Text(
                      'Escáner código de barras · Fotos de productos · Historial de precios · Alertas de caducidad'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      await BackupHelper.exportDatabase();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar datos'),
        content: const Text(
          'Para importar datos:\n\n'
          '1. Copia el archivo .db a tu dispositivo\n'
          '2. Usa un explorador de archivos para abrirlo con MiCompra\n\n'
          'O comparte el archivo directamente desde WhatsApp/correo y ábrelo con MiCompra.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(color: Colors.grey[700])),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
