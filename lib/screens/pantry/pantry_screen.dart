import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/pantry_item.dart';
import '../../providers/pantry_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/pantry_item_card.dart';
import 'pantry_item_form.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  String _query = '';
  String _filter = 'all';
  String _category = 'all';
  String _sort = 'expiry';
  bool _grouped = false;
  final _searchCtrl = TextEditingController();

  final _filters = const [
    ('all',       'Todos'),
    ('expiring',  'Caducan pronto'),
    ('expired',   'Caducados'),
    ('ok',        'Bien'),
    ('low_stock', 'Stock bajo'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PantryProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PantryItem> _applySort(List<PantryItem> items) {
    final list = [...items];
    switch (_sort) {
      case 'name':
        list.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'recent':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      default:
        list.sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
    }
    return list;
  }

  List<PantryItem> _applyCategory(List<PantryItem> items) {
    if (_category == 'all') return items;
    return items.where((i) => i.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantryProvider>();
    final items = _applySort(_applyCategory(provider.filter(_query, _filter)));

    return Scaffold(
      appBar: GradientAppBar(
        title: const Text('Despensa'),
        actions: [
          IconButton(
            icon: Icon(_grouped ? Icons.view_list_outlined : Icons.folder_outlined),
            tooltip: _grouped ? 'Vista lista' : 'Vista carpetas',
            onPressed: () => setState(() => _grouped = !_grouped),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'expiry',  child: Text('Por caducidad')),
              PopupMenuItem(value: 'name',    child: Text('Por nombre (A-Z)')),
              PopupMenuItem(value: 'recent',  child: Text('Añadido recientemente')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_grouped ? 96 : 148),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Buscar en despensa...',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                  ],
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              // Estado filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: _filters.map((f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (v) => setState(() => _filter = v ? f.$1 : 'all'),
                    ),
                  )).toList(),
                ),
              ),
              // Category filter (solo en vista lista)
              if (!_grouped)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('Todas'),
                          selected: _category == 'all',
                          onSelected: (_) => setState(() => _category = 'all'),
                        ),
                      ),
                      ...AppConstants.categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(AppConstants.categoryIcon(cat),
                              size: 14,
                              color: AppConstants.categoryColor(cat)),
                          label: Text(cat),
                          selected: _category == cat,
                          onSelected: (v) =>
                              setState(() => _category = v ? cat : 'all'),
                        ),
                      )),
                    ],
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _EmptyState(filter: _filter)
              : _grouped
                  ? _GroupedView(
                      items: items,
                      onEdit: _openForm,
                      onDelete: _confirmDelete,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        return PantryItemCard(
                          item: item,
                          onTap: () => _openForm(item),
                          onDelete: () => _confirmDelete(item.id, item.name),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
    );
  }

  void _openForm(dynamic item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PantryItemForm(existing: item)),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "$name" de la despensa?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<PantryProvider>().delete(id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Vista agrupada por categoría (carpetas desplegables)
// ─────────────────────────────────────────────────────────────────

class _GroupedView extends StatelessWidget {
  final List<PantryItem> items;
  final void Function(PantryItem) onEdit;
  final void Function(String id, String name) onDelete;

  const _GroupedView({
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Group by category, preserving order from AppConstants.categories
    final grouped = <String, List<PantryItem>>{};
    for (final item in items) {
      (grouped[item.category] ??= []).add(item);
    }
    // Sort keys: categories with items first, in the AppConstants order
    final keys = [
      ...AppConstants.categories.where(grouped.containsKey),
      ...grouped.keys.where((k) => !AppConstants.categories.contains(k)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: keys.length,
      itemBuilder: (ctx, i) {
        final cat = keys[i];
        final catItems = grouped[cat]!;
        final catColor = AppConstants.categoryColor(cat);
        return _CategoryFolder(
          category: cat,
          color: catColor,
          items: catItems,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _CategoryFolder extends StatefulWidget {
  final String category;
  final Color color;
  final List<PantryItem> items;
  final void Function(PantryItem) onEdit;
  final void Function(String id, String name) onDelete;

  const _CategoryFolder({
    required this.category,
    required this.color,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CategoryFolder> createState() => _CategoryFolderState();
}

class _CategoryFolderState extends State<_CategoryFolder> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAlert = widget.items.any((i) => i.isExpired || i.isExpiringSoon);
    final hasLow = widget.items.any((i) => i.isBelowMinStock);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(_expanded ? 0 : 20),
              bottomRight: Radius.circular(_expanded ? 0 : 20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppConstants.categoryIcon(widget.category),
                      color: widget.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.category,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (hasAlert)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange[700]),
                    ),
                  if (hasLow)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.inventory_2_outlined,
                          size: 16, color: Colors.blue[700]),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Items
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...widget.items.map((item) => _CompactItem(
                  item: item,
                  color: widget.color,
                  onEdit: () => widget.onEdit(item),
                  onDelete: () => widget.onDelete(item.id, item.name),
                )),
          ],
        ],
      ),
    );
  }
}

class _CompactItem extends StatelessWidget {
  final PantryItem item;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompactItem({
    required this.item,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = item.isExpired
        ? Colors.red
        : item.isExpiringSoon
            ? Colors.orange
            : color;
    final fmt = DateFormat('dd/MM/yy');

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              item.isExpired
                  ? Icons.error_outline
                  : item.isExpiringSoon
                      ? Icons.warning_amber_outlined
                      : Icons.check_circle_outline,
              color: statusColor,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${_fmtQty(item.quantity)} ${item.unit}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
            if (item.expiryDate != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fmt.format(item.expiryDate!),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline,
                  size: 16, color: Colors.red[300]),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = filter == 'all'
        ? 'Tu despensa está vacía.\nAñade productos con el botón +.'
        : filter == 'low_stock'
            ? '¡Todo en orden!\nNingún producto por debajo del stock mínimo.'
            : 'No hay productos en esta categoría.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.kitchen_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
