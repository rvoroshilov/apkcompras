import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/supermarket.dart';
import '../utils/constants.dart';

class SupermarketProvider extends ChangeNotifier {
  final _db = DBHelper();
  List<Supermarket> _items = [];
  bool _loading = false;

  List<Supermarket> get items => _items;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _items = await _db.getSupermarkets();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(String name, int color) async {
    final s = Supermarket(
      id: const Uuid().v4(),
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );
    await _db.insertSupermarket(s);
    _items.add(s);
    _items.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> update(Supermarket s) async {
    await _db.updateSupermarket(s);
    final idx = _items.indexWhere((i) => i.id == s.id);
    if (idx >= 0) _items[idx] = s;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _db.deleteSupermarket(id);
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  Supermarket? getById(String id) {
    try {
      return _items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  int nextColor() {
    final used = _items.map((s) => s.color).toSet();
    for (final c in AppConstants.supermarketColors) {
      if (!used.contains(c.value)) return c.value;
    }
    return AppConstants.supermarketColors[
            _items.length % AppConstants.supermarketColors.length]
        .value;
  }
}
