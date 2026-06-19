import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/backup_helper.dart';
import '../../utils/constants.dart';
import '../../utils/notification_helper.dart';
import '../spending/spending_screen.dart';
import 'house_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final monthFmt = DateFormat('MMMM yyyy', 'es_ES');
    final shopping = context.watch<ShoppingProvider>();
    final settings = context.watch<SettingsProvider>();
    final houseCode = FirebaseService().houseCode ?? '------';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Casa compartida section
          _SectionTitle('Casa compartida'),
          Card(
            child: ListTile(
              leading: const _MenuIcon(
                  icon: Icons.home_outlined, color: Color(0xFF7B1FA2)),
              title: const Text('Casa compartida'),
              subtitle: Text('Código: $houseCode'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HouseSettingsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Presupuesto mensual
          _SectionTitle('Presupuesto mensual'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const _MenuIcon(
                      icon: Icons.savings_outlined, color: Color(0xFF2E7D32)),
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
                  leading: const _MenuIcon(
                      icon: Icons.bar_chart_outlined, color: Color(0xFF0288D1)),
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
            child: Column(
              children: [
                ListTile(
                  leading: _MenuIcon(
                      icon: _themeIcon(settings.themeMode),
                      color: const Color(0xFF5E35B1)),
                  title: const Text('Modo'),
                  subtitle: Text(_themeLabel(settings.themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectTheme(context, settings),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Color de la app',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: AppConstants.colorThemes.map((t) {
                          final selected = settings.seedColor == t.color.value;
                          return GestureDetector(
                            onTap: () => settings.setSeedColor(t.color.value),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: t.color,
                                    shape: BoxShape.circle,
                                    border: selected
                                        ? Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            width: 3)
                                        : null,
                                    boxShadow: selected
                                        ? [BoxShadow(
                                            color: t.color.withOpacity(0.5),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3))]
                                        : null,
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : Center(
                                          child: Text(t.emoji,
                                              style: const TextStyle(
                                                  fontSize: 18))),
                                ),
                                const SizedBox(height: 4),
                                Text(t.name,
                                    style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Personalisation section
          _SectionTitle('Personalización'),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar emoji picker
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avatar de la casa',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: AppConstants.avatarEmojis.map((emoji) {
                          final selected = settings.avatarEmoji == emoji;
                          final cs = Theme.of(context).colorScheme;
                          return GestureDetector(
                            onTap: () =>
                                context.read<SettingsProvider>().setAvatarEmoji(emoji),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border: selected
                                    ? Border.all(color: cs.primary, width: 2.5)
                                    : null,
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(emoji,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Background style picker
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fondo de cabecera',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(
                          AppConstants.backgroundStyles.length,
                          (i) {
                            final style = AppConstants.backgroundStyles[i];
                            final selected = settings.backgroundStyle == i;
                            final cs = Theme.of(context).colorScheme;
                            final List<Color> previewColors = switch (i) {
                              0 => [cs.primary, cs.primary],
                              2 => [
                                  cs.primary,
                                  Color.lerp(cs.primary, cs.tertiary, 0.65)!,
                                ],
                              _ => [
                                  cs.primary,
                                  Color.lerp(
                                      cs.primary, cs.primaryContainer, 0.55)!,
                                ],
                            };
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                child: GestureDetector(
                                  onTap: () => context
                                      .read<SettingsProvider>()
                                      .setBackgroundStyle(i),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: previewColors,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: selected
                                            ? cs.onPrimary
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: cs.primary
                                                    .withOpacity(0.4),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        if (selected)
                                          Icon(Icons.check_circle,
                                              color: cs.onPrimary, size: 18)
                                        else
                                          Icon(Icons.circle_outlined,
                                              color:
                                                  cs.onPrimary.withOpacity(0.6),
                                              size: 18),
                                        const SizedBox(height: 5),
                                        Text(
                                          style.name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                        Text(
                                          style.description,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color:
                                                cs.onPrimary.withOpacity(0.75),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Backup section
          _SectionTitle('Copia de seguridad'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const _MenuIcon(
                      icon: Icons.upload_outlined, color: Color(0xFF00897B)),
                  title: const Text('Exportar datos (.zip)'),
                  subtitle: const Text(
                      'Empaqueta tus datos y fotos para transferirlos a otro móvil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _export(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const _MenuIcon(
                      icon: Icons.download_outlined, color: Color(0xFF43A047)),
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
              leading: const _MenuIcon(
                  icon: Icons.notifications_outlined, color: Color(0xFFE64A19)),
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
                  leading: _MenuIcon(
                      icon: Icons.info_outline, color: Color(0xFF546E7A)),
                  title: Text('MiCompra'),
                  subtitle: Text(
                      'v1.0.0 — Gestiona tu despensa y lista de la compra'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: _MenuIcon(
                      icon: Icons.cloud_outlined, color: Color(0xFF1E88E5)),
                  title: Text('Almacenamiento'),
                  subtitle:
                      Text('Firebase Firestore · Sincronización en tiempo real'),
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

class _MenuIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _MenuIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
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
