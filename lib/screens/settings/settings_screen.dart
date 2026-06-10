import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../utils/backup_helper.dart';
import '../../utils/notification_helper.dart';
import '../spending/spending_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final monthFmt = DateFormat('MMMM yyyy', 'es_ES');
    final shopping = context.watch<ShoppingProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Presupuesto mensual
          _SectionTitle('Presupuesto mensual'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Presupuesto global'),
                  subtitle: Text(
                    shopping.monthlyBudget > 0
                        ? '${fmt.format(shopping.monthlyBudget)} / mes'
                        : 'Sin límite establecido',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editBudget(context, shopping),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: const Text('Panel de gastos'),
                  subtitle: const Text('Gráficos de gasto mensual y por tienda'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SpendingScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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

          // Appearance section
          _SectionTitle('Apariencia'),
          Card(
            child: ListTile(
              leading: Icon(_themeIcon(settings.themeMode)),
              title: const Text('Tema'),
              subtitle: Text(_themeLabel(settings.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectTheme(context, settings),
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
                  title: const Text('Exportar datos (.zip)'),
                  subtitle: const Text(
                      'Empaqueta tus datos y fotos para transferirlos a otro móvil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _export(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Importar datos'),
                  subtitle: const Text(
                      'Restaura una copia (.zip) de MiCompra desde este dispositivo'),
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
                  subtitle:
                      Text('SQLite local · Los datos no salen del dispositivo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        _ => Icons.brightness_auto_outlined,
      };

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
        _ => 'Automático (sistema)',
      };

  Future<void> _selectTheme(
      BuildContext context, SettingsProvider settings) async {
    final mode = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tema'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.system),
            child: const ListTile(
              leading: Icon(Icons.brightness_auto_outlined),
              title: Text('Automático (sistema)'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.light),
            child: const ListTile(
              leading: Icon(Icons.light_mode_outlined),
              title: Text('Claro'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.dark),
            child: const ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Oscuro'),
            ),
          ),
        ],
      ),
    );
    if (mode != null && context.mounted) {
      await context.read<SettingsProvider>().setThemeMode(mode);
    }
  }

  Future<void> _editBudget(
      BuildContext context, ShoppingProvider shopping) async {
    final ctrl = TextEditingController(
      text: shopping.monthlyBudget > 0
          ? shopping.monthlyBudget.toStringAsFixed(2)
          : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Presupuesto mensual'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Importe (€)',
            hintText: '0 para sin límite',
            prefixText: '€ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final budget =
          double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
      await context.read<ShoppingProvider>().setMonthlyBudget(budget);
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      await BackupHelper.exportBackup();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar datos'),
        content: const Text(
          'Vas a restaurar una copia de seguridad (.zip o .db).\n\n'
          'ATENCIÓN: esto SUSTITUIRÁ todos los datos actuales de la app '
          '(despensa, tiendas, productos y listas). Haz primero un export si '
          'quieres conservarlos.\n\n¿Continuar y elegir el archivo?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elegir archivo'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final ok = await BackupHelper.importBackup(path);

    if (!context.mounted) return;
    if (ok) {
      await context.read<SupermarketProvider>().load();
      await context.read<PantryProvider>().load();
      await context.read<ShoppingProvider>().load();
      context.read<ProductProvider>().clearSearch();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Copia restaurada correctamente ✓')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No se pudo importar. ¿El archivo es una copia de MiCompra?')),
      );
    }
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
          child:
              Text(label, style: TextStyle(color: Colors.grey[700])),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
