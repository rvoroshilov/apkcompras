import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pantry_item.dart';
import '../../providers/pantry_provider.dart';
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
  String _sort = 'expiry';
  final _searchCtrl = TextEditingController();

  final _filters = const [
    ('all', 'Todos'),
    ('expiring', 'Caducan pronto'),
    ('expired', 'Caducados'),
    ('ok', 'Bien'),
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
        break;
      case 'recent':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'expiry':
      default:
        list.sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
          if (a.expiryDate == null) return 1; // sin fecha al final
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantryProvider>();
    final items = _applySort(provider.filter(_query, _filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Despensa'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'expiry', child: Text('Por caducidad')),
              PopupMenuItem(value: 'name', child: Text('Por nombre (A-Z)')),
              PopupMenuItem(
                  value: 'recent', child: Text('Añadido recientemente')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: _filters.map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        onSelected: (v) =>
                            setState(() => _filter = v ? f.$1 : 'all'),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _EmptyState(filter: _filter)
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

class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = filter == 'all'
        ? 'Tu despensa está vacía.\nAñade productos con el botón +.'
        : filter == 'low_stock'
            ? 'Ningún producto por debajo\ndel stock mínimo. ¡Bien!'
            : 'No hay productos en esta categoría.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.kitchen_outlined,
              size: 72, color: Colors.grey[300]),
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
