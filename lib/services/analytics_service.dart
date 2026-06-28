import 'firebase_service.dart';

/// Computes spending/usage aggregations from Firestore household data.
/// Firestore has no JOINs, so we load the relevant collections once and
/// aggregate in Dart. Data volume for a household is small.
class AnalyticsService {
  final _fs = FirebaseService();

  /// Loads all completed (non-template) lists and their items, returning a
  /// flat list of item maps enriched with the list's completed_at date.
  Future<List<_CompletedItem>> _completedItems() async {
    final listsSnap = await _fs.collection('shopping_lists').get();
    final completed = <String, DateTime>{};
    for (final doc in listsSnap.docs) {
      final data = doc.data();
      final isTemplate = (data['is_template'] as int? ?? 0) == 1;
      final completedAt = data['completed_at'];
      if (!isTemplate && completedAt != null) {
        completed[doc.id] = DateTime.parse(completedAt as String);
      }
    }
    if (completed.isEmpty) return [];

    final itemsSnap = await _fs.collection('shopping_list_items').get();
    final result = <_CompletedItem>[];
    for (final doc in itemsSnap.docs) {
      final data = doc.data();
      final listId = data['list_id'] as String?;
      if (listId == null || !completed.containsKey(listId)) continue;
      final unitPrice = (data['unit_price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (data['quantity'] as num?)?.toDouble() ?? 1.0;
      final discount = (data['discount_percent'] as num?)?.toDouble() ?? 0.0;
      result.add(_CompletedItem(
        name: (data['product_name'] as String?) ?? '',
        unit: (data['unit'] as String?) ?? 'ud',
        productId: data['product_id'] as String?,
        supermarketName: (data['supermarket_name'] as String?) ?? '',
        unitPrice: unitPrice,
        total: unitPrice * quantity * (1 - discount / 100),
        completedAt: completed[listId]!,
      ));
    }
    return result;
  }

  /// Monthly spend totals for the last [months] months, oldest→newest.
  /// Each entry: {'month': 'YYYY-MM', 'total': double}
  Future<List<Map<String, dynamic>>> getSpendingHistory(int months) async {
    final items = await _completedItems();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final totals = <String, double>{};
    for (final it in items) {
      if (it.completedAt.isBefore(start)) continue;
      final key =
          '${it.completedAt.year}-${it.completedAt.month.toString().padLeft(2, '0')}';
      totals[key] = (totals[key] ?? 0) + it.total;
    }
    final keys = totals.keys.toList()..sort();
    return keys.map((k) => {'month': k, 'total': totals[k]!}).toList();
  }

  /// Spending by supermarket for the current month, descending.
  Future<List<Map<String, dynamic>>> getSpendBySupermarket() async {
    final items = await _completedItems();
    final now = DateTime.now();
    final totals = <String, double>{};
    for (final it in items) {
      if (it.completedAt.month != now.month ||
          it.completedAt.year != now.year) continue;
      final key = it.supermarketName.isEmpty ? 'Sin tienda' : it.supermarketName;
      totals[key] = (totals[key] ?? 0) + it.total;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => {'market': e.key, 'total': e.value}).toList();
  }

  /// Spending by product category for the current month, descending.
  Future<List<Map<String, dynamic>>> getSpendByCategory() async {
    final items = await _completedItems();
    final now = DateTime.now();

    // Build product_id → category map
    final productsSnap = await _fs.collection('products').get();
    final categoryById = <String, String>{};
    for (final doc in productsSnap.docs) {
      categoryById[doc.id] =
          (doc.data()['category'] as String?) ?? 'Sin categoría';
    }

    final totals = <String, double>{};
    for (final it in items) {
      if (it.completedAt.month != now.month ||
          it.completedAt.year != now.year) continue;
      final cat = (it.productId != null ? categoryById[it.productId] : null) ??
          'Sin categoría';
      totals[cat] = (totals[cat] ?? 0) + it.total;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => {'category': e.key, 'total': e.value}).toList();
  }

  /// Predicción de reposición: para cada producto comprado en al menos
  /// [minPurchases] días distintos, calcula el intervalo medio entre compras y
  /// estima cuándo tocará volver a comprarlo. Devuelve los que ya tocan o
  /// están a punto (daysUntil <= [withinDays]), ordenados por urgencia.
  /// Cada entrada: {name, unit, avg_price, supermarket_name, interval_days,
  /// last_purchase (DateTime), days_until (int, negativo = ya pasado)}.
  Future<List<Map<String, dynamic>>> getRepurchasePredictions({
    int minPurchases = 2,
    int withinDays = 5,
  }) async {
    final items = await _completedItems();
    final groups = <String, List<_CompletedItem>>{};
    for (final it in items) {
      if (it.name.trim().isEmpty) continue;
      final key = '${it.name.trim().toLowerCase()}|${it.unit}';
      (groups[key] ??= []).add(it);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <Map<String, dynamic>>[];

    for (final group in groups.values) {
      // Días distintos de compra (evita contar varias líneas del mismo ticket).
      final days = <DateTime>{};
      for (final it in group) {
        days.add(DateTime(it.completedAt.year, it.completedAt.month,
            it.completedAt.day));
      }
      if (days.length < minPurchases) continue;

      final sorted = days.toList()..sort();
      var totalGap = 0;
      for (var i = 1; i < sorted.length; i++) {
        totalGap += sorted[i].difference(sorted[i - 1]).inDays;
      }
      final avgInterval = totalGap / (sorted.length - 1);
      if (avgInterval <= 0) continue;

      final last = sorted.last;
      final predictedNext = last.add(Duration(days: avgInterval.round()));
      final daysUntil = predictedNext.difference(today).inDays;
      if (daysUntil > withinDays) continue;

      final avgPrice =
          group.fold(0.0, (s, i) => s + i.unitPrice) / group.length;
      result.add({
        'name': group.first.name,
        'unit': group.first.unit,
        'avg_price': double.parse(avgPrice.toStringAsFixed(2)),
        'supermarket_name': group
            .map((i) => i.supermarketName)
            .firstWhere((s) => s.isNotEmpty, orElse: () => ''),
        'interval_days': avgInterval.round(),
        'last_purchase': last,
        'days_until': daysUntil,
      });
    }

    result.sort(
        (a, b) => (a['days_until'] as int).compareTo(b['days_until'] as int));
    return result;
  }

  /// Most frequently purchased items across completed lists.
  /// Each entry: {'name', 'unit', 'count', 'avg_price', 'supermarket_name'}
  Future<List<Map<String, dynamic>>> getFrequentItems({
    int minCount = 2,
    int limit = 10,
  }) async {
    final items = await _completedItems();
    final groups = <String, List<_CompletedItem>>{};
    for (final it in items) {
      final key = '${it.name.trim().toLowerCase()}|${it.unit}';
      (groups[key] ??= []).add(it);
    }
    final result = <Map<String, dynamic>>[];
    for (final group in groups.values) {
      if (group.length < minCount) continue;
      final avgPrice =
          group.fold(0.0, (s, i) => s + i.unitPrice) / group.length;
      result.add({
        'name': group.first.name,
        'unit': group.first.unit,
        'count': group.length,
        'avg_price': double.parse(avgPrice.toStringAsFixed(2)),
        'supermarket_name': group
            .map((i) => i.supermarketName)
            .firstWhere((s) => s.isNotEmpty, orElse: () => ''),
      });
    }
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return result.take(limit).toList();
  }
}

class _CompletedItem {
  final String name;
  final String unit;
  final String? productId;
  final String supermarketName;
  final double unitPrice;
  final double total;
  final DateTime completedAt;

  _CompletedItem({
    required this.name,
    required this.unit,
    required this.productId,
    required this.supermarketName,
    required this.unitPrice,
    required this.total,
    required this.completedAt,
  });
}
