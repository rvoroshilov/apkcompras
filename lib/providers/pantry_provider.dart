import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/pantry_item.dart';
import '../utils/notification_helper.dart';

class PantryProvider extends ChangeNotifier {
  final _db = DBHelper();
  List<PantryItem> _items = [];
  bool _loading = false;

  List<PantryItem> get items => _items;
  bool get loading => _loading;

  List<PantryItem> get expired => _items.where((i) => i.isExpired).toList();
  List<PantryItem> get expiringSoon =>
      _items.where((i) => i.isExpiringSoon).toList();
  List<PantryItem> get alertItems =>
      _items.where((i) => i.isExpired || i.isExpiringSoon).toList();
  List<PantryItem> get itemsBelowMinStock =>
      _items.where((i) => i.isBelowMinStock).toList();

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _db.getPantryItems();
    _loading = false;
    notifyListeners();
    if (_items.any((i) => i.isExpired || i.isExpiringSoon)) {
      NotificationHelper.checkExpiringItems(_items);
    }
  }

  Future<void> add(PantryItem item) async {
    final toAdd = PantryItem(
      id: const Uuid().v4(),
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      expiryDate: item.expiryDate,
      imagePath: item.imagePath,
      notes: item.notes,
      productId: item.productId,
      minStock: item.minStock,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.insertPantryItem(toAdd);
    _items.add(toAdd);
    _items.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> update(PantryItem item) async {
    await _db.updatePantryItem(item);
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) _items[idx] = item;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _db.deletePantryItem(id);
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  List<PantryItem> filter(String query, String filterType) {
    var result = _items;
    if (query.isNotEmpty) {
      result =
          result.where((i) => i.name.toLowerCase().contains(query.toLowerCase())).toList();
    }
    switch (filterType) {
      case 'expired':
        return result.where((i) => i.isExpired).toList();
      case 'expiring':
        return result.where((i) => i.isExpiringSoon).toList();
      case 'ok':
        return result.where((i) => !i.isExpired && !i.isExpiringSoon).toList();
      case 'low_stock':
        return result.where((i) => i.isBelowMinStock).toList();
      default:
        return result;
    }
  }
}
