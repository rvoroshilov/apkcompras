import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/shopping_provider.dart';
import '../../services/analytics_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_app_bar.dart';
import 'shopping_list_screen.dart';

/// Predicción de reposición: muestra los productos que, según el ritmo con que
/// los compras, toca volver a comprar pronto o ya tocaba. Permite crear una
/// lista de la compra con los seleccionados.
class RepurchasePredictionScreen extends StatefulWidget {
  const RepurchasePredictionScreen({super.key});

  @override
  State<RepurchasePredictionScreen> createState() =>
      _RepurchasePredictionScreenState();
}

class _RepurchasePredictionScreenState
    extends State<RepurchasePredictionScreen> {
  List<Map<String, dynamic>> _predictions = [];
  final Set<int> _selected = {};
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AnalyticsService().getRepurchasePredictions();
    if (!mounted) return;
    setState(() {
      _predictions = p;
      // Preselecciona los que ya tocaban (días restantes <= 0).
      _selected.clear();
      for (var i = 0; i < p.length; i++) {
        if ((p[i]['days_until'] as int) <= 0) _selected.add(i);
      }
      _loading = false;
    });
  }

  String _statusText(int daysUntil, int interval) {
    final cada = 'cada ~$interval días';
    if (daysUntil < 0) return 'Tocaba hace ${-daysUntil} días · $cada';
    if (daysUntil == 0) return 'Toca hoy · $cada';
    return 'En $daysUntil días · $cada';
  }

  Color _statusColor(int daysUntil) {
    if (daysUntil < 0) return AppConstants.danger;
    if (daysUntil <= 1) return AppConstants.warning;
    return AppConstants.info;
  }

  Future<void> _createList() async {
    if (_selected.isEmpty) return;
    final shop = context.read<ShoppingProvider>();
    final navigator = Navigator.of(context);
    setState(() => _creating = true);

    final name = 'Reposición ${DateFormat('dd/MM').format(DateTime.now())}';
    final newList = await shop.addListReturning(name, 0);
    for (final i in _selected) {
      final p = _predictions[i];
      await shop.addItem(ShoppingListItem(
        id: '',
        listId: newList.id,
        productName: p['name'] as String,
        quantity: 1,
        unit: p['unit'] as String,
        unitPrice: p['avg_price'] as double,
        supermarketName: p['supermarket_name'] as String,
      ));
    }
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(
          builder: (_) => ShoppingListScreen(shoppingList: newList)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: Text('Toca reponer')),
      body: _loading
          ? const AppLoader()
          : _predictions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: AppEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Aún no hay predicciones',
                    message:
                        'Necesito que compres un producto al menos 2 veces para '
                        'aprender tu ritmo y avisarte de cuándo reponerlo.',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
                  itemCount: _predictions.length,
                  itemBuilder: (_, i) {
                    final p = _predictions[i];
                    final daysUntil = p['days_until'] as int;
                    final color = _statusColor(daysUntil);
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: CheckboxListTile(
                        value: _selected.contains(i),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        }),
                        title: Text(p['name'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _statusText(daysUntil, p['interval_days'] as int),
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w500),
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(
                            daysUntil <= 0
                                ? Icons.notifications_active_outlined
                                : Icons.schedule_outlined,
                            color: color,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _predictions.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed:
                      _selected.isEmpty || _creating ? null : _createList,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_shopping_cart),
                  label: Text('Crear lista (${_selected.length})'),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ),
    );
  }
}
