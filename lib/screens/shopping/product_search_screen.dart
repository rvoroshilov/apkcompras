import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/shopping_list_item.dart';
import '../../providers/product_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/product_card.dart';

class ProductSearchScreen extends StatefulWidget {
  final String listId;
  const ProductSearchScreen({super.key, required this.listId});

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _supermarketFilter;
  List<Product> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text;
    if (q == _query) return;
    setState(() => _query = q);
    _performSearch(q);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    var results =
        await context.read<ProductProvider>().getByName(query.trim());
    if (_supermarketFilter != null) {
      results =
          results.where((p) => p.supermarketId == _supermarketFilter).toList();
    }
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  Set<String> _computeCheapest(List<Product> products) {
    final byName = <String, List<Product>>{};
    for (final p in products) {
      byName.putIfAbsent(p.name.toLowerCase().trim(), () => []).add(p);
    }
    final ids = <String>{};
    for (final group in byName.values) {
      final markets = group.map((p) => p.supermarketId).toSet();
      if (markets.length < 2) continue; // solo si hay comparación entre tiendas
      final minPrice =
          group.map((p) => p.price).reduce((a, b) => a < b ? a : b);
      for (final p in group) {
        if (p.price == minPrice) ids.add(p.id);
      }
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final markets = context.watch<SupermarketProvider>().items;

    var displayResults = _results;
    if (_supermarketFilter != null) {
      displayResults = _results
          .where((p) => p.supermarketId == _supermarketFilter)
          .toList();
    }

    // Marca como "más barato" el producto con menor precio cuando el mismo
    // nombre aparece en más de un supermercado (comparación útil).
    final cheapestIds = _computeCheapest(displayResults);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar productos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SearchBar(
                  controller: _searchCtrl,
                  hintText: 'Buscar producto...',
                  leading: const Icon(Icons.search),
                  autofocus: true,
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _query = '';
                            _results = [];
                          });
                        },
                      ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Todos'),
                        selected: _supermarketFilter == null,
                        onSelected: (v) {
                          if (v) {
                            setState(() => _supermarketFilter = null);
                            _performSearch(_query);
                          }
                        },
                      ),
                    ),
                    ...markets.map((m) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(m.name),
                            selected: _supermarketFilter == m.id,
                            selectedColor: m.flutterColor.withOpacity(0.2),
                            onSelected: (v) {
                              setState(() => _supermarketFilter =
                                  v ? m.id : null);
                              _performSearch(_query);
                            },
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Manual add button
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () => _addManual(),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Añadir producto manualmente'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),

          Expanded(
            child: _query.isEmpty
                ? _FavoritesOrHint(
                    onAdd: _addProductToList,
                  )
                : _searching
                    ? const Center(child: CircularProgressIndicator())
                    : displayResults.isEmpty
                        ? _NoResultsState(
                            query: _query,
                            onAddManual: () => _addManual(productName: _query),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: displayResults.length,
                            itemBuilder: (ctx, i) {
                              final product = displayResults[i];
                              final market = context
                                  .read<SupermarketProvider>()
                                  .getById(product.supermarketId);
                              return ProductCard(
                                product: product,
                                supermarketName: market?.name ?? '',
                                supermarketColor:
                                    market?.flutterColor ?? Colors.grey,
                                showSupermarket: true,
                                isCheapest: cheapestIds.contains(product.id),
                                onTap: () => _addProductToList(product),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _addProductToList(Product product) async {
    final market = context
        .read<SupermarketProvider>()
        .getById(product.supermarketId);

    final qtyCtrl = TextEditingController(text: '1');
    final discountCtrl = TextEditingController();
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (market != null)
                Text(
                  market.name,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              const SizedBox(height: 4),
              Text(
                '${fmt.format(product.price)} / ${product.unit}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (product.hasNormalizedPrice)
                Text(
                  '${fmt.format(product.pricePerKgOrL)} / ${product.normalizedUnit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cantidad (${product.unit})',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setDState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: discountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Descuento (%) - opcional',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                onChanged: (_) => setDState(() {}),
              ),
              const SizedBox(height: 12),
              // Preview total
              Builder(builder: (_) {
                final qty =
                    double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ??
                        1;
                final discount = double.tryParse(
                        discountCtrl.text.replaceAll(',', '.')) ??
                    0;
                final total =
                    product.price * (1 - discount / 100) * qty;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        fmt.format(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final qty =
          double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
      final discount =
          double.tryParse(discountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final item = ShoppingListItem(
        id: '',
        listId: widget.listId,
        productId: product.id,
        productName: product.name,
        supermarketName: market?.name ?? '',
        unitPrice: product.price,
        quantity: qty,
        unit: product.unit,
        discountPercent: discount,
      );
      await context.read<ShoppingProvider>().addItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} añadido a la lista')),
        );
      }
    }
  }

  Future<void> _addManual({String? productName}) async {
    final nameCtrl = TextEditingController(text: productName ?? '');
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final discountCtrl = TextEditingController();
    String unit = 'ud';
    String market = '';
    final markets = context.read<SupermarketProvider>().items;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Añadir producto manualmente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Producto *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Precio *',
                          border: OutlineInputBorder(),
                          prefixText: '€ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        decoration: const InputDecoration(
                          labelText: 'Unidad',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: AppConstants.units
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setDState(() => unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cantidad ($unit)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Descuento (%)',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
                if (markets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: market.isEmpty ? null : market,
                    decoration: const InputDecoration(
                      labelText: 'Tienda (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Sin tienda')),
                      ...markets.map((m) => DropdownMenuItem(
                          value: m.name, child: Text(m.name))),
                    ],
                    onChanged: (v) => setDState(() => market = v ?? ''),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Añadir'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final price =
          double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final qty =
          double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1.0;
      final discount =
          double.tryParse(discountCtrl.text.replaceAll(',', '.')) ?? 0.0;

      final item = ShoppingListItem(
        id: '',
        listId: widget.listId,
        productName: name,
        supermarketName: market,
        unitPrice: price,
        quantity: qty,
        unit: unit,
        discountPercent: discount,
      );
      await context.read<ShoppingProvider>().addItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name añadido a la lista')),
        );
      }
    }
  }
}

class _FavoritesOrHint extends StatelessWidget {
  final Future<void> Function(Product) onAdd;

  const _FavoritesOrHint({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<ProductProvider>().favorites;
    final markets = context.read<SupermarketProvider>();

    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Busca un producto por nombre\no filtra por supermercado',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Marca productos como favoritos ♥\npara encontrarlos aquí rápidamente',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 16),
              const SizedBox(width: 6),
              Text(
                'Favoritos',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: favorites.length,
            itemBuilder: (ctx, i) {
              final product = favorites[i];
              final market = markets.getById(product.supermarketId);
              return ProductCard(
                product: product,
                supermarketName: market?.name ?? '',
                supermarketColor: market?.flutterColor ?? Colors.grey,
                showSupermarket: true,
                onTap: () => onAdd(product),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoResultsState extends StatelessWidget {
  final String query;
  final VoidCallback onAddManual;

  const _NoResultsState({required this.query, required this.onAddManual});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No se encontró "$query"',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onAddManual,
            icon: const Icon(Icons.add),
            label: const Text('Añadir manualmente'),
          ),
        ],
      ),
    );
  }
}
