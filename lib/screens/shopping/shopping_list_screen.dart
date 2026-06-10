import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../database/db_helper.dart';
import '../../models/pantry_item.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/pantry_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../widgets/shopping_item_card.dart';
import 'basket_comparison_screen.dart';
import 'product_search_screen.dart';
import 'supermarket_mode_screen.dart';

class ShoppingListScreen extends StatefulWidget {
  final ShoppingList shoppingList;
  const ShoppingListScreen({super.key, required this.shoppingList});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late ShoppingList _list;
  final _db = DBHelper();
  List<Map<String, dynamic>> _suggestions = [];
  bool _suggestionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _list = widget.shoppingList;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingProvider>().loadItems(_list.id);
    });
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final s = await _db.getFrequentItems();
    if (mounted) setState(() => _suggestions = s);
  }

  Future<void> _addSuggestion(Map<String, dynamic> s) async {
    final item = ShoppingListItem(
      id: const Uuid().v4(),
      listId: _list.id,
      productId: null,
      productName: s['name'] as String,
      supermarketName: s['supermarket_name'] as String,
      unitPrice: s['avg_price'] as double,
      quantity: 1.0,
      unit: s['unit'] as String,
      discountPercent: 0.0,
      notes: '',
      isChecked: false,
    );
    await context.read<ShoppingProvider>().addItem(item);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final total = provider.totalFor(_list.id);
    final checkedTotal = provider.checkedTotalFor(_list.id);
    final grouped = provider.groupByMarket(_list.id);
    final items = provider.itemsFor(_list.id);

    final budgetExceeded = _list.hasBudget && total > _list.budget;

    return Scaffold(
      appBar: AppBar(
        title: Text(_list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Comparar dónde es más barato',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BasketComparisonScreen(
                  listId: _list.id,
                  listName: _list.name,
                ),
              ),
            ),
          ),
          if (!_list.isCompleted)
            IconButton(
              icon: const Icon(Icons.storefront_outlined),
              tooltip: 'Modo en el súper',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SupermarketModeScreen(list: _list),
                ),
              ),
            ),
          if (!_list.isCompleted)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Marcar como completada',
              onPressed: () => _completeList(provider),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reabrir lista',
              onPressed: () => _reopenList(provider),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editListDialog();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar lista'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Total header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: budgetExceeded
                  ? Colors.red.withOpacity(0.1)
                  : theme.colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Total: ${fmt.format(total)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: budgetExceeded
                                  ? Colors.red
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          if (budgetExceeded) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.warning_amber,
                                color: Colors.red, size: 20),
                          ],
                        ],
                      ),
                      if (_list.hasBudget) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Presupuesto: ${fmt.format(_list.budget)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _list.budget > 0
                              ? (total / _list.budget).clamp(0.0, 1.0)
                              : 0,
                          backgroundColor: Colors.grey[200],
                          color: budgetExceeded ? Colors.red : Colors.green,
                        ),
                      ],
                      if (items.any((i) => i.isChecked)) ...[
                        const SizedBox(height: 4),
                        Text(
                          'En carrito: ${fmt.format(checkedTotal)} '
                          '(${items.where((i) => i.isChecked).length}/${items.length} productos)',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!_list.isCompleted)
                  FilledButton.icon(
                    onPressed: () => _openProductSearch(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
              ],
            ),
          ),

          // Frequent items suggestions
          if (!_list.isCompleted && _suggestions.isNotEmpty)
            _SuggestionsSection(
              suggestions: _suggestions,
              expanded: _suggestionsExpanded,
              onToggle: () => setState(
                  () => _suggestionsExpanded = !_suggestionsExpanded),
              onAdd: _addSuggestion,
            ),

          // Items
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (grouped.length > 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.store, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    entry.key,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fmt.format(entry.value.fold(
                                        0.0, (s, i) => s + i.totalPrice)),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ...entry.value.map((item) => ShoppingItemCard(
                                item: item,
                                onToggle: _list.isCompleted
                                    ? null
                                    : () => provider.toggleItem(item),
                                onEdit: _list.isCompleted
                                    ? null
                                    : () => _editItem(item),
                                onDelete: _list.isCompleted
                                    ? null
                                    : () => provider.deleteItem(item),
                              )),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductSearch(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductSearchScreen(listId: _list.id),
      ),
    );
    if (mounted) {
      context.read<ShoppingProvider>().loadItems(_list.id);
    }
  }

  Future<void> _editItem(ShoppingListItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ItemEditSheet(
        item: item,
        onSave: (updated) {
          context.read<ShoppingProvider>().updateItem(updated);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _completeList(ShoppingProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completar lista'),
        content: const Text(
            '¿Marcar esta lista como completada? El total se sumará al gasto mensual.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Completar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final items = provider.itemsFor(_list.id);
    await provider.completeList(_list.id);
    if (mounted) setState(() => _list = _list.copyWith(completedAt: DateTime.now()));

    if (!mounted || items.isEmpty) return;
    _offerAddToPantry(items);
  }

  Future<void> _offerAddToPantry(List<ShoppingListItem> items) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddToPantrySheet(items: items),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    final pantry = context.read<PantryProvider>();
    for (final item in items.where((i) => selected.contains(i.id))) {
      await pantry.add(PantryItem(
        id: '',
        name: item.productName,
        quantity: item.quantity,
        unit: item.unit,
        imagePath: '',
        notes: '',
        minStock: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selected.length} producto${selected.length == 1 ? '' : 's'} añadido${selected.length == 1 ? '' : 's'} a la despensa'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _reopenList(ShoppingProvider provider) async {
    await provider.reopenList(_list.id);
    if (mounted) {
      setState(() {
        _list = _list.copyWith(clearCompletedAt: true);
      });
    }
  }

  Future<void> _editListDialog() async {
    final nameCtrl = TextEditingController(text: _list.name);
    final budgetCtrl = TextEditingController(
        text: _list.budget > 0 ? _list.budget.toStringAsFixed(2) : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Presupuesto (€)',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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

    if (ok == true && mounted && nameCtrl.text.trim().isNotEmpty) {
      final budget =
          double.tryParse(budgetCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final updated = _list.copyWith(
          name: nameCtrl.text.trim(), budget: budget);
      await context.read<ShoppingProvider>().updateList(updated);
      if (mounted) setState(() => _list = updated);
    }
  }
}

class _ItemEditSheet extends StatefulWidget {
  final ShoppingListItem item;
  final void Function(ShoppingListItem) onSave;

  const _ItemEditSheet({required this.item, required this.onSave});

  @override
  State<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<_ItemEditSheet> {
  late TextEditingController _priceCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
        text: widget.item.unitPrice.toStringAsFixed(2));
    _qtyCtrl = TextEditingController(
        text: widget.item.quantity.toStringAsFixed(
            widget.item.quantity == widget.item.quantity.truncateToDouble()
                ? 0
                : 1));
    _discountCtrl = TextEditingController(
        text: widget.item.discountPercent > 0
            ? widget.item.discountPercent.toStringAsFixed(0)
            : '');
    _notesCtrl = TextEditingController(text: widget.item.notes);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final price =
        double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final qty =
        double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1;
    final discount =
        double.tryParse(_discountCtrl.text.replaceAll(',', '.')) ?? 0;
    final total = price * (1 - discount / 100) * qty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.productName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.item.supermarketName.isNotEmpty)
              Text(
                widget.item.supermarketName,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio unitario (€)',
                      border: OutlineInputBorder(),
                      prefixText: '€ ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cantidad (${widget.item.unit})',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _discountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Descuento (%)',
                hintText: 'Ej: 15 para un 15%',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Total preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    fmt.format(total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final updated = widget.item.copyWith(
                    unitPrice: double.tryParse(
                            _priceCtrl.text.replaceAll(',', '.')) ??
                        widget.item.unitPrice,
                    quantity: double.tryParse(
                            _qtyCtrl.text.replaceAll(',', '.')) ??
                        widget.item.quantity,
                    discountPercent: double.tryParse(
                            _discountCtrl.text.replaceAll(',', '.')) ??
                        0.0,
                    notes: _notesCtrl.text.trim(),
                  );
                  widget.onSave(updated);
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_shopping_cart, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'La lista está vacía.\nPulsa "Añadir" para buscar productos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final bool expanded;
  final VoidCallback onToggle;
  final Future<void> Function(Map<String, dynamic>) onAdd;

  const _SuggestionsSection({
    required this.suggestions,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Frecuentes (${suggestions.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18),
                ],
              ),
            ),
          ),
          if (expanded)
            SizedBox(
              height: 84,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: suggestions.length,
                itemBuilder: (ctx, i) {
                  final s = suggestions[i];
                  return Card(
                    margin: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => onAdd(s),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              fmt.format(s['avg_price'] as double),
                              style: TextStyle(
                                color:
                                    Theme.of(ctx).colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '× ${s['count']}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _AddToPantrySheet extends StatefulWidget {
  final List<ShoppingListItem> items;
  const _AddToPantrySheet({required this.items});

  @override
  State<_AddToPantrySheet> createState() => _AddToPantrySheetState();
}

class _AddToPantrySheetState extends State<_AddToPantrySheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.items.map((i) => i.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == widget.items.length;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '¿Añadir a la despensa?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selected = allSelected
                          ? {}
                          : widget.items.map((i) => i.id).toSet()),
                      child: Text(allSelected ? 'Ninguno' : 'Todos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: widget.items.length,
              itemBuilder: (_, i) {
                final item = widget.items[i];
                final qty = item.quantity == item.quantity.truncateToDouble()
                    ? item.quantity.toInt().toString()
                    : item.quantity.toStringAsFixed(1);
                return CheckboxListTile(
                  value: _selected.contains(item.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.add(item.id);
                    } else {
                      _selected.remove(item.id);
                    }
                  }),
                  title: Text(item.productName),
                  subtitle: Text('$qty ${item.unit}'),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Saltar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, _selected),
                    child: Text('Añadir (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
