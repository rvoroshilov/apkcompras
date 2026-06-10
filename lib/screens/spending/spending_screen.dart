import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/db_helper.dart';

class SpendingScreen extends StatefulWidget {
  const SpendingScreen({super.key});

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  final _db = DBHelper();
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _bySupermarket = [];
  List<Map<String, dynamic>> _byCategory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final history = await _db.getSpendingHistory(6);
    final byMarket = await _db.getSpendBySupermarket();
    final byCategory = await _db.getSpendByCategory();
    if (mounted) {
      setState(() {
        _history = history;
        _bySupermarket = byMarket;
        _byCategory = byCategory;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exportar CSV',
            onPressed: _loading ? null : _exportCsv,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Monthly history chart
                  _SectionTitle('Gasto mensual (últimos 6 meses)'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      child: _history.isEmpty
                          ? _emptyChart(context)
                          : _MonthlyBarChart(history: _history),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Current month summary
                  _SectionTitle('Este mes por tienda'),
                  const SizedBox(height: 8),
                  if (_bySupermarket.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Sin compras completadas este mes',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ..._bySupermarket.asMap().entries.map((e) {
                      final index = e.key;
                      final entry = e.value;
                      final market = entry['market'] as String;
                      final total = entry['total'] as double;
                      final maxTotal =
                          (_bySupermarket.first['total'] as double);
                      final colors = [
                        theme.colorScheme.primary,
                        Colors.orange,
                        Colors.green,
                        Colors.purple,
                        Colors.teal,
                      ];
                      final color = colors[index % colors.length];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      market,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    fmt.format(total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: maxTotal > 0 ? total / maxTotal : 0,
                                  minHeight: 6,
                                  backgroundColor: color.withOpacity(0.15),
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 20),

                  // Category breakdown
                  _SectionTitle('Este mes por categoría'),
                  const SizedBox(height: 8),
                  if (_byCategory.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Sin datos de categorías este mes',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    ..._byCategory.asMap().entries.map((e) {
                      final index = e.key;
                      final entry = e.value;
                      final cat = entry['category'] as String;
                      final total = entry['total'] as double;
                      final maxTotal = (_byCategory.first['total'] as double);
                      final colors = [
                        Colors.indigo,
                        Colors.teal,
                        Colors.deepOrange,
                        Colors.cyan,
                        Colors.amber[700]!,
                        Colors.pink,
                      ];
                      final color = colors[index % colors.length];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cat,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    fmt.format(total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: maxTotal > 0 ? total / maxTotal : 0,
                                  minHeight: 6,
                                  backgroundColor: color.withOpacity(0.15),
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }

  Future<void> _exportCsv() async {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final sb = StringBuffer()
      ..writeln('MiCompra — Exportación de gastos')
      ..writeln('Fecha: ${dateFmt.format(DateTime.now())}')
      ..writeln()
      ..writeln('== Historial mensual ==')
      ..writeln('Mes,Gasto (€)');
    for (final h in _history) {
      sb.writeln('${h['month']},${(h['total'] as double).toStringAsFixed(2)}');
    }
    sb
      ..writeln()
      ..writeln('== Por tienda (mes actual) ==')
      ..writeln('Tienda,Gasto (€)');
    for (final m in _bySupermarket) {
      sb.writeln('"${m['market']}",${(m['total'] as double).toStringAsFixed(2)}');
    }
    sb
      ..writeln()
      ..writeln('== Por categoría (mes actual) ==')
      ..writeln('Categoría,Gasto (€)');
    for (final c in _byCategory) {
      sb.writeln('"${c['category']}",${(c['total'] as double).toStringAsFixed(2)}');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/micompra_gastos_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(sb.toString());
    await Share.shareXFiles([XFile(file.path)], subject: 'Gastos MiCompra');
  }

  Widget _emptyChart(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(
          'Sin compras completadas en los últimos 6 meses',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _MonthlyBarChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final rawMax = history
        .map((e) => e['total'] as double)
        .reduce((a, b) => a > b ? a : b);
    final maxY = rawMax > 0 ? rawMax * 1.25 : 10.0;

    // Build a map of month -> total so we can fill in empty months
    final monthMap = {for (final e in history) e['month'] as String: e['total'] as double};

    // Generate last 6 months labels in order
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    final barGroups = months.asMap().entries.map((e) {
      final x = e.key;
      final month = e.value;
      final total = monthMap[month] ?? 0.0;
      return BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: total,
            color: Theme.of(context).colorScheme.primary,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    final shortMonths = months.map((m) {
      final parts = m.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMM', 'es_ES').format(dt);
    }).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.blueGrey[800]!,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final fmt =
                    NumberFormat.currency(locale: 'es_ES', symbol: '€');
                return BarTooltipItem(
                  fmt.format(rod.toY),
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= shortMonths.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      shortMonths[idx],
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
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
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
