import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';

class ShoppingProvider extends ChangeNotifier {
  final _db = DBHelper();
  List<ShoppingList> _lists = [];
  final Map<String, List<ShoppingListItem>> _items = {};
  bool _loading = false;
  double _monthlySpend = 0.0;
  double _monthlyBudget = 0.0;

  List<ShoppingList> get lists => _lists;
  bool get loading => _loading;
  double get monthlySpend => _monthlySpend;
  double get monthlyBudget => _monthlyBudget;

  List<ShoppingList> get activeLists =>
      _lists.where((l) => !l.isCompleted && !l.isTemplate).toList();
  List<ShoppingList> get completedLists =>
      _lists.where((l) => l.isCompleted && !l.isTemplate).toList();
  List<ShoppingList> get templates =>
      _lists.where((l) => l.isTemplate).toList();

  List<ShoppingListItem> itemsFor(String listId) => _items[listId] ?? [];

  double totalFor(String listId) =>
      itemsFor(listId).fold(0.0, (sum, i) => sum + i.totalPrice);

  double checkedTotalFor(String listId) => itemsFor(listId)
      .where((i) => i.isChecked)
      .fold(0.0, (sum, i) => sum + i.totalPrice);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _lists = await _db.getShoppingLists();
    _monthlySpend = await _db.getMonthlySpend();
    _monthlyBudget = await _db.getMonthlyBudget();
    _loading = false;
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double budget) async {
    await _db.setMonthlyBudget(budget);
    _monthlyBudget = budget;
    notifyListeners();
  }

  Future<void> loadItems(String listId) async {
    _items[listId] = await _db.getShoppingListItems(listId);
    notifyListeners();
  }

  Future<void> addList(String name, double budget) async {
    final list = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      budget: budget,
      createdAt: DateTime.now(),
    );
    await _db.insertShoppingList(list);
    _lists.insert(0, list);
    notifyListeners();
  }

  Future<void> addTemplate(String name) async {
    final list = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      isTemplate: true,
      createdAt: DateTime.now(),
    );
    await _db.insertShoppingList(list);
    _lists.insert(0, list);
    notifyListeners();
  }

  /// Copies all items from [templateId] into a new active list named [newName].
  Future<ShoppingList> createFromTemplate(
      String templateId, String newName, double budget) async {
    if (_items[templateId] == null) {
      _items[templateId] = await _db.getShoppingListItems(templateId);
    }
    final templateItems = _items[templateId] ?? [];

    final newList = ShoppingList(
      id: const Uuid().v4(),
      name: newName,
      budget: budget,
      createdAt: DateTime.now(),
    );
    await _db.insertShoppingList(newList);
    _lists.insert(0, newList);

    final newItems = <ShoppingListItem>[];
    for (final item in templateItems) {
      final copy = ShoppingListItem(
        id: const Uuid().v4(),
        listId: newList.id,
        productId: item.productId,
        productName: item.productName,
        supermarketName: item.supermarketName,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
        unit: item.unit,
        discountPercent: item.discountPercent,
        notes: item.notes,
      );
      await _db.insertShoppingListItem(copy);
      newItems.add(copy);
    }
    _items[newList.id] = newItems;
    notifyListeners();
    return newList;
  }

  Future<void> updateList(ShoppingList list) async {
    await _db.updateShoppingList(list);
    final idx = _lists.indexWhere((l) => l.id == list.id);
    if (idx >= 0) _lists[idx] = list;
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    await _db.deleteShoppingList(id);
    _lists.removeWhere((l) => l.id == id);
    _items.remove(id);
    notifyListeners();
  }

  Future<void> completeList(String id) async {
    final idx = _lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final updated = _lists[idx].copyWith(completedAt: DateTime.now());
    await _db.updateShoppingList(updated);
    _lists[idx] = updated;
    _monthlySpend = await _db.getMonthlySpend();
    notifyListeners();
  }

  Future<void> reopenList(String id) async {
    final idx = _lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final updated = _lists[idx].copyWith(clearCompletedAt: true);
    await _db.updateShoppingList(updated);
    _lists[idx] = updated;
    notifyListeners();
  }

  Future<void> addItem(ShoppingListItem item) async {
    final toAdd = ShoppingListItem(
      id: const Uuid().v4(),
      listId: item.listId,
      productId: item.productId,
      productName: item.productName,
      supermarketName: item.supermarketName,
      unitPrice: item.unitPrice,
      quantity: item.quantity,
      unit: item.unit,
      discountPercent: item.discountPercent,
      notes: item.notes,
    );
    await _db.insertShoppingListItem(toAdd);
    _items[item.listId] = [...(itemsFor(item.listId)), toAdd];
    notifyListeners();
  }

  Future<void> updateItem(ShoppingListItem item) async {
    await _db.updateShoppingListItem(item);
    final list = _items[item.listId] ?? [];
    final idx = list.indexWhere((i) => i.id == item.id);
    if (idx >= 0) list[idx] = item;
    notifyListeners();
  }

  Future<void> toggleItem(ShoppingListItem item) async {
    final updated = item.copyWith(isChecked: !item.isChecked);
    await updateItem(updated);
  }

  Future<void> deleteItem(ShoppingListItem item) async {
    await _db.deleteShoppingListItem(item.id);
    _items[item.listId]?.removeWhere((i) => i.id == item.id);
    notifyListeners();
  }

  Map<String, List<ShoppingListItem>> groupByMarket(String listId) {
    final map = <String, List<ShoppingListItem>>{};
    for (final item in itemsFor(listId)) {
      final key =
          item.supermarketName.isEmpty ? 'Sin tienda' : item.supermarketName;
      (map[key] ??= []).add(item);
    }
    return map;
  }
}
