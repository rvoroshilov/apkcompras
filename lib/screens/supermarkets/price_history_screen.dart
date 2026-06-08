import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/price_history.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import 'package:provider/provider.dart';

class PriceHistoryScreen extends StatefulWidget {
  final Product product;
  const PriceHistoryScreen({super.key, required this.product});

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  List<PriceHistory> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await context
        .read<ProductProvider>()
        .getPriceHistory(widget.product.id);
    if (mounted) setState(() { _history = h; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final product = widget.product;

    double? minPrice, maxPrice;
    if (_history.isNotEmpty) {
      minPrice = _history.map((h) => h.price).reduce((a, b) => a < b ? a : b);
      maxPrice = _history.map((h) => h.price).reduce((a, b) => a > b ? a : b);
    }
    final isAtMin = minPrice != null && product.price == minPrice;
    final priceRose = _history.length >= 2 &&
        _history.last.price > _history[_history.length - 2].price;

    return Scaffold(
      appBar: AppBar(title: Text('Historial: ${product.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current price card
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Precio actual',
                                  style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontSize: 12)),
                              Text(
                                fmt.format(product.price),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text('/ ${product.unit}',
                                  style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isAtMin)
                              _Badge(
                                  label: 'MÍN. HISTÓRICO',
                                  color: Colors.green),
                            if (priceRose)
                              _Badge(
                                  label: '↑ SUBIÓ',
                                  color: Colors.red),
                            if (minPrice != null) ...[
                              const SizedBox(height: 4),
                              Text('Mínimo: ${fmt.format(minPrice)}',
                                  style: const TextStyle(fontSize: 12)),
                              Text('Máximo: ${fmt.format(maxPrice!)}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_history.length < 2)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.show_chart,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              'No hay historial de cambios de precio todavía.\n'
                              'El gráfico aparecerá cuando el precio cambie.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  Text('Evolución del precio',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
                      child: _PriceLineChart(
                        history: _history,
                        minPrice: minPrice!,
                        maxPrice: maxPrice!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Historial completo',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: _history.reversed.map((h) {
                        final isMin = h.price == minPrice;
                        final isMax = h.price == maxPrice;
                        return ListTile(
                          dense: true,
                          title: Text(
                            fmt.format(h.price),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMin
                                  ? Colors.green
                                  : isMax
                                      ? Colors.red
                                      : null,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd/MM/yyyy HH:mm', 'es_ES')
                                .format(h.recordedAt),
                          ),
                          trailing: isMin
                              ? const Chip(
                                  label: Text('Mín'),
                                  backgroundColor: Colors.green,
                                  labelStyle: TextStyle(
                                      color: Colors.white, fontSize: 11),
                                )
                              : isMax
                                  ? const Chip(
                                      label: Text('Máx'),
                                      backgroundColor: Colors.red,
                                      labelStyle: TextStyle(
                                          color: Colors.white, fontSize: 11),
                                    )
                                  : null,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PriceLineChart extends StatelessWidget {
  final List<PriceHistory> history;
  final double minPrice;
  final double maxPrice;

  const _PriceLineChart({
    required this.history,
    required this.minPrice,
    required this.maxPrice,
  });

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.price);
    }).toList();

    final range = maxPrice - minPrice;
    final padding = range > 0 ? range * 0.2 : 0.5;
    final minY = minPrice - padding;
    final maxY = maxPrice + padding;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: spots.length > 2,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: history.length > 4
                    ? (history.length / 4).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= history.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('d/M').format(history[idx].recordedAt),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) => Text(
                  '€${value.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
