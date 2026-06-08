import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/shopping_list.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/shopping_provider.dart';

/// Full-screen quick-shopping mode: large totals, one-tap item check, screen always on.
class SupermarketModeScreen extends StatefulWidget {
  final ShoppingList list;
  const SupermarketModeScreen({super.key, required this.list});

  @override
  State<SupermarketModeScreen> createState() => _SupermarketModeScreenState();
}

class _SupermarketModeScreenState extends State<SupermarketModeScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShoppingProvider>().loadItems(widget.list.id);
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final items = provider.itemsFor(widget.list.id);
    final total = provider.totalFor(widget.list.id);
    final checkedTotal = provider.checkedTotalFor(widget.list.id);
    final checkedCount = items.where((i) => i.isChecked).length;
    final grouped = provider.groupByMarket(widget.list.id);

    final budgetExceeded =
        widget.list.hasBudget && checkedTotal > widget.list.budget;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        title: Text(widget.list.name,
            style: const TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              backgroundColor: Colors.green[700],
              label: Text(
                '$checkedCount/${items.length}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Large total header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            color: budgetExceeded ? Colors.red[900] : Colors.grey[850],
            child: Column(
              children: [
                Text(
                  'En carrito',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  fmt.format(checkedTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                if (widget.list.hasBudget) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.list.budget > 0
                          ? (checkedTotal / widget.list.budget).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 8,
                      backgroundColor: Colors.grey[700],
                      color: budgetExceeded ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    budgetExceeded
                        ? '¡Presupuesto superado! (${fmt.format(widget.list.budget)})'
                        : 'Presupuesto: ${fmt.format(widget.list.budget)}  '
                            'Resta: ${fmt.format(widget.list.budget - checkedTotal)}',
                    style: TextStyle(
                      color: budgetExceeded ? Colors.red[300] : Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Total lista: ${fmt.format(total)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          // Items list
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'La lista está vacía',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (grouped.length > 1)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ...entry.value
                              .map((item) => _SupermarketItemRow(
                                    item: item,
                                    onToggle: () =>
                                        provider.toggleItem(item),
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
}

class _SupermarketItemRow extends StatelessWidget {
  final ShoppingListItem item;
  final VoidCallback onToggle;

  const _SupermarketItemRow({required this.item, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final checked = item.isChecked;

    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
          ),
          color: checked ? Colors.grey[850] : Colors.grey[900],
        ),
        child: Row(
          children: [
            // Big checkbox area
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? Colors.green : Colors.transparent,
                border: Border.all(
                  color: checked ? Colors.green : Colors.grey[600]!,
                  width: 2,
                ),
              ),
              child: checked
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: TextStyle(
                      color: checked ? Colors.grey[500] : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  Text(
                    '${_fmtQty(item.quantity)} ${item.unit}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.format(item.totalPrice),
                  style: TextStyle(
                    color: checked ? Colors.grey[600] : Colors.green[300],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.discountPercent > 0)
                  Text(
                    '-${item.discountPercent.toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.orange[300], fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
