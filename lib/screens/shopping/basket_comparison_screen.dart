import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../models/supermarket.dart';
import '../../providers/product_provider.dart';
import '../../providers/shopping_provider.dart';
import '../../providers/supermarket_provider.dart';

/// Compara cuánto costaría una lista de la compra en cada supermercado,
/// usando los precios del catálogo, y muestra dónde sale más barato.
class BasketComparisonScreen extends StatefulWidget {
  final String listId;
  final String listName;

  const BasketComparisonScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<BasketComparisonScreen> createState() =>
      _BasketComparisonScreenState();
}

class _BasketComparisonScreenState extends State<BasketComparisonScreen> {
  List<Product> _allProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await context.read<ProductProvider>().getAll();
    if (mounted) {
      setState(() {
        _allProducts = products;
        _loading = false;
      });
    }
  }

  String _key(String name) => name.toLowerCase().trim();

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final shopping = context.watch<ShoppingProvider>();
    final markets = context.watch<SupermarketProvider>().items;
    final items = shopping.itemsFor(widget.listId);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparar precios')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Cantidad deseada por producto (agregando nombres repetidos).
    final desiredQty = <String, double>{};
    final desiredName = <String, String>{};
    for (final item in items) {
      final k = _key(item.productName);
      desiredQty[k] = (desiredQty[k] ?? 0) + item.quantity;
      desiredName[k] = item.productName;
    }

    // Índice de catálogo: precio mínimo por (tienda, nombre).
    final catalog = <String, Map<String, double>>{}; // marketId -> key -> price
    for (final p in _allProducts) {
      final k = _key(p.name);
      final byKey = catalog.putIfAbsent(p.supermarketId, () => {});
      if (!byKey.containsKey(k) || p.price < byKey[k]!) {
        byKey[k] = p.price;
      }
    }

    // Cálculo por supermercado.
    final results = <_MarketResult>[];
    for (final m in markets) {
      final prices = catalog[m.id] ?? {};
      double subtotal = 0;
      int covered = 0;
      for (final entry in desiredQty.entries) {
        final price = prices[entry.key];
        if (price != null) {
          subtotal += price * entry.value;
          covered++;
        }
      }
      results.add(_MarketResult(
        market: m,
        subtotal: subtotal,
        covered: covered,
        total: desiredQty.length,
      ));
    }

    // Orden: primero los que más cubren, luego los más baratos.
    results.sort((a, b) {
      if (a.covered != b.covered) return b.covered.compareTo(a.covered);
      return a.subtotal.compareTo(b.subtotal);
    });

    final fullCoverage =
        results.where((r) => r.covered == desiredQty.length && r.covered > 0);
    final cheapestFull = fullCoverage.isEmpty
        ? null
        : fullCoverage.reduce((a, b) => a.subtotal <= b.subtotal ? a : b);
    final mostExpensiveFull = fullCoverage.isEmpty
        ? null
        : fullCoverage.reduce((a, b) => a.subtotal >= b.subtotal ? a : b);

    // Mejor combinación: cada producto donde esté más barato.
    double mixTotal = 0;
    int mixCovered = 0;
    final mixBreakdown = <_MixLine>[];
    final notFound = <String>[];
    for (final entry in desiredQty.entries) {
      Supermarket? bestMarket;
      double? bestPrice;
      for (final m in markets) {
        final price = catalog[m.id]?[entry.key];
        if (price != null && (bestPrice == null || price < bestPrice)) {
          bestPrice = price;
          bestMarket = m;
        }
      }
      if (bestPrice != null && bestMarket != null) {
        mixTotal += bestPrice * entry.value;
        mixCovered++;
        mixBreakdown.add(_MixLine(
          name: desiredName[entry.key]!,
          market: bestMarket,
          price: bestPrice,
          quantity: entry.value,
        ));
      } else {
        notFound.add(desiredName[entry.key]!);
      }
    }

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparar precios')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'La lista está vacía. Añade productos para compararlos.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_allProducts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comparar precios')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Aún no tienes productos en el catálogo de tus supermercados.\n\n'
              'Añade productos con precio en la pestaña "Tiendas" para poder '
              'comparar dónde compras más barato.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Comparar: ${widget.listName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Resumen destacado
          if (cheapestFull != null)
            _HighlightCard(
              icon: Icons.emoji_events,
              color: cheapestFull.market.flutterColor,
              title: 'Más barato (cesta completa)',
              market: cheapestFull.market.name,
              amount: fmt.format(cheapestFull.subtotal),
              footer: (mostExpensiveFull != null &&
                      mostExpensiveFull.subtotal > cheapestFull.subtotal)
                  ? 'Ahorras ${fmt.format(mostExpensiveFull.subtotal - cheapestFull.subtotal)} frente a ${mostExpensiveFull.market.name}'
                  : 'Cubre todos los productos de la lista',
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ningún supermercado tiene todos los productos. '
                      'Mira abajo la mejor combinación y la cobertura de cada tienda.',
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          _SectionTitle('Coste por supermercado'),
          const SizedBox(height: 4),
          ...results.map((r) => _MarketResultCard(
                result: r,
                isCheapest: cheapestFull != null &&
                    r.market.id == cheapestFull.market.id,
                fmt: fmt,
              )),

          const SizedBox(height: 20),
          _SectionTitle('Mejor combinación (comprando en varias tiendas)'),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Total óptimo: ${fmt.format(mixTotal)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  if (cheapestFull != null &&
                      cheapestFull.subtotal > mixTotal) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ahorras ${fmt.format(cheapestFull.subtotal - mixTotal)} '
                      'frente a comprar todo en ${cheapestFull.market.name}',
                      style: TextStyle(
                          color: Colors.green[700], fontSize: 13),
                    ),
                  ],
                  const Divider(height: 20),
                  ...mixBreakdown.map((line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: line.market.flutterColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_fmtQty(line.quantity)}× ${line.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              line.market.name,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: line.market.flutterColor,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(fmt.format(line.price * line.quantity),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),

          if (notFound.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle('Sin precio en el catálogo'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estos productos no están en el catálogo de ninguna tienda, '
                    'así que no se han comparado:',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  ...notFound.map((n) => Text('• $n',
                      style: TextStyle(color: Colors.grey[700]))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _MarketResult {
  final Supermarket market;
  final double subtotal;
  final int covered;
  final int total;

  _MarketResult({
    required this.market,
    required this.subtotal,
    required this.covered,
    required this.total,
  });
}

class _MixLine {
  final String name;
  final Supermarket market;
  final double price;
  final double quantity;

  _MixLine({
    required this.name,
    required this.market,
    required this.price,
    required this.quantity,
  });
}

class _HighlightCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String market;
  final String amount;
  final String footer;

  const _HighlightCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.market,
    required this.amount,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.75)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            market,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22),
          ),
          Text(
            amount,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 28),
          ),
          const SizedBox(height: 4),
          Text(
            footer,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MarketResultCard extends StatelessWidget {
  final _MarketResult result;
  final bool isCheapest;
  final NumberFormat fmt;

  const _MarketResultCard({
    required this.result,
    required this.isCheapest,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final fullCoverage = result.covered == result.total;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 40,
              decoration: BoxDecoration(
                color: result.market.flutterColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          result.market.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCheapest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('MÁS BARATO',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fullCoverage
                        ? 'Tiene todos los productos'
                        : 'Cubre ${result.covered}/${result.total} productos',
                    style: TextStyle(
                      fontSize: 12,
                      color: fullCoverage
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              result.covered == 0 ? '—' : fmt.format(result.subtotal),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: isCheapest
                    ? Colors.green[700]
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
