import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/supermarket.dart';
import '../../providers/product_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../widgets/product_card.dart';
import 'price_history_screen.dart';
import 'product_form.dart';

class SupermarketProductsScreen extends StatefulWidget {
  final Supermarket supermarket;
  const SupermarketProductsScreen({super.key, required this.supermarket});

  @override
  State<SupermarketProductsScreen> createState() =>
      _SupermarketProductsScreenState();
}

class _SupermarketProductsScreenState
    extends State<SupermarketProductsScreen> {
  String _query = '';
  String _category = 'Todos';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadForSupermarket(widget.supermarket.id);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final color = widget.supermarket.flutterColor;

    var products = provider.forSupermarket(widget.supermarket.id);

    if (_query.isNotEmpty) {
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(_query.toLowerCase()) ||
              p.brand.toLowerCase().contains(_query.toLowerCase()) ||
              p.barcode == _query)
          .toList();
    }
    if (_category != 'Todos') {
      products = products.where((p) => p.category == _category).toList();
    }

    final categories = [
      'Todos',
      ...{
        ...provider.forSupermarket(widget.supermarket.id).map((p) => p.category)
      }
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(widget.supermarket.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Buscar productos...',
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
                  children: categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _category == cat,
                        onSelected: (v) =>
                            setState(() => _category = v ? cat : 'Todos'),
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
          : products.isEmpty
              ? _EmptyState(query: _query, category: _category)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    return ProductCard(
                      product: p,
                      supermarketColor: color,
                      onEdit: () => _openForm(p),
                      onDelete: () => _confirmDelete(p.id, p.name),
                      onFavorite: () =>
                          context.read<ProductProvider>().toggleFavorite(p),
                      onHistory: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PriceHistoryScreen(product: p)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: color,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Añadir producto'),
      ),
    );
  }

  void _openForm(dynamic product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductForm(
          supermarket: widget.supermarket,
          existing: product,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "$name"?'),
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
      context.read<ProductProvider>().delete(widget.supermarket.id, id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final String category;
  const _EmptyState({required this.query, required this.category});

  @override
  Widget build(BuildContext context) {
    final msg = query.isNotEmpty || category != 'Todos'
        ? 'No se encontraron productos.'
        : 'No hay productos.\nAñade uno con el botón +.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined,
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
