import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/pantry_item.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../services/firebase_service.dart';

class ShoppingProvider extends ChangeNotifier {
  List<ShoppingList> _lists = [];
  final Map<String, List<ShoppingListItem>> _items = {};
  bool _loading = false;
  double _monthlyBudget = 0.0;
  StreamSubscription? _listSub;
  final Map<String, StreamSubscription> _itemSubs = {};

  List<ShoppingList> get lists => _lists;
  bool get loading => _loading;
  double get monthlyBudget => _monthlyBudget;

  double get monthlySpend {
    final now = DateTime.now();
    double total = 0.0;
    for (final list in _lists) {
      if (list.isCompleted &&
          !list.isTemplate &&
          list.completedAt != null &&
          list.completedAt!.month == now.month &&
          list.completedAt!.year == now.year) {
        final listItems = _items[list.id] ?? [];
        for (final item in listItems) {
          total += item.totalPrice;
        }
      }
    }
    return total;
  }

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

  /// Converts Firestore doc data to a map compatible with ShoppingList.fromMap.
  /// Firestore stores is_template as int but may receive it as-is.
  Map<String, dynamic> _listFromFirestore(Map<String, dynamic> data, String id) {
    return {
      ...data,
      'id': id,
      // Ensure is_template is an int (Firestore may store as int already)
      'is_template': (data['is_template'] as int?) ?? 0,
    };
  }

  /// Converts Firestore doc data to a map compatible with ShoppingListItem.fromMap.
  Map<String, dynamic> _itemFromFirestore(Map<String, dynamic> data, String id) {
    return {
      ...data,
      'id': id,
      // Ensure is_checked is an int
      'is_checked': (data['is_checked'] as int?) ?? 0,
    };
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    // Load monthly budget from Firestore household settings
    final fs = FirebaseService();
    final houseDoc = fs.db.collection('households').doc(fs.houseId);
    final snap = await houseDoc.get();
    if (snap.exists) {
      _monthlyBudget = (snap.data()?['monthly_budget'] as num?)?.toDouble() ?? 0.0;
    }

    _listSub?.cancel();
    _listSub = fs.collection('shopping_lists')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snap) {
      _lists = snap.docs
          .map((d) => ShoppingList.fromMap(_listFromFirestore(d.data(), d.id)))
          .toList();
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('ShoppingProvider list stream error: $e');
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> setMonthlyBudget(double budget) async {
    final fs = FirebaseService();
    await fs.db
        .collection('households')
        .doc(fs.houseId)
        .set({'monthly_budget': budget}, SetOptions(merge: true));
    _monthlyBudget = budget;
    notifyListeners();
  }

  Future<void> loadItems(String listId) async {
    // Cancel existing subscription for this list
    await _itemSubs[listId]?.cancel();

    final fs = FirebaseService();
    _itemSubs[listId] = fs.collection('shopping_list_items')
        .where('list_id', isEqualTo: listId)
        .snapshots()
        .listen((snap) {
      _items[listId] = snap.docs
          .map((d) => ShoppingListItem.fromMap(_itemFromFirestore(d.data(), d.id)))
          .toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('ShoppingProvider items stream error for $listId: $e');
    });
  }

  Future<void> addList(String name, double budget) async {
    final list = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      budget: budget,
      createdAt: DateTime.now(),
    );
    final map = list.toMap()..remove('id');
    await FirebaseService().collection('shopping_lists').doc(list.id).set(map);
    // Stream updates _lists
  }

  Future<void> addTemplate(String name) async {
    final list = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      isTemplate: true,
      createdAt: DateTime.now(),
    );
    final map = list.toMap()..remove('id');
    await FirebaseService().collection('shopping_lists').doc(list.id).set(map);
    // Stream updates _lists
  }

  /// Copies all items from [templateId] into a new active list named [newName].
  Future<ShoppingList> createFromTemplate(
      String templateId, String newName, double budget) async {
    // Load template items if not already loaded
    if (_items[templateId] == null) {
      final snap = await FirebaseService()
          .collection('shopping_list_items')
          .where('list_id', isEqualTo: templateId)
          .get();
      _items[templateId] = snap.docs
          .map((d) => ShoppingListItem.fromMap(_itemFromFirestore(d.data(), d.id)))
          .toList();
    }
    final templateItems = _items[templateId] ?? [];

    final newList = ShoppingList(
      id: const Uuid().v4(),
      name: newName,
      budget: budget,
      createdAt: DateTime.now(),
    );
    final listMap = newList.toMap()..remove('id');
    await FirebaseService().collection('shopping_lists').doc(newList.id).set(listMap);

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
      final itemMap = copy.toMap()..remove('id');
      await FirebaseService()
          .collection('shopping_list_items')
          .doc(copy.id)
          .set(itemMap);
      newItems.add(copy);
    }
    _items[newList.id] = newItems;
    notifyListeners();
    return newList;
  }

  Future<void> updateList(ShoppingList list) async {
    final map = list.toMap()..remove('id');
    await FirebaseService().collection('shopping_lists').doc(list.id).update(map);
    // Stream updates _lists
  }

  Future<void> deleteList(String id) async {
    // Delete all items in this list first
    final fs = FirebaseService();
    final itemsSnap = await fs.collection('shopping_list_items')
        .where('list_id', isEqualTo: id)
        .get();
    final batch = fs.db.batch();
    for (final doc in itemsSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(fs.collection('shopping_lists').doc(id));
    await batch.commit();

    // Cancel item subscription for this list
    await _itemSubs[id]?.cancel();
    _itemSubs.remove(id);
    _items.remove(id);
    // _lists stream will update automatically
  }

  Future<void> completeList(String id) async {
    final idx = _lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final updated = _lists[idx].copyWith(completedAt: DateTime.now());
    final map = updated.toMap()..remove('id');
    await FirebaseService().collection('shopping_lists').doc(id).update(map);
    // monthlySpend is computed from in-memory state
  }

  Future<void> reopenList(String id) async {
    final idx = _lists.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final updated = _lists[idx].copyWith(clearCompletedAt: true);
    final map = updated.toMap()..remove('id');
    await FirebaseService().collection('shopping_lists').doc(id).update(map);
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
    final map = toAdd.toMap()..remove('id');
    await FirebaseService()
        .collection('shopping_list_items')
        .doc(toAdd.id)
        .set(map);
    // Stream updates _items if subscribed
    if (_itemSubs.containsKey(item.listId)) {
      // Stream will fire automatically
    } else {
      // Optimistic local update
      _items[item.listId] = [...(itemsFor(item.listId)), toAdd];
      notifyListeners();
    }
  }

  Future<void> updateItem(ShoppingListItem item) async {
    final map = item.toMap()..remove('id');
    await FirebaseService()
        .collection('shopping_list_items')
        .doc(item.id)
        .update(map);
    // Stream will update if subscribed, otherwise update locally
    if (!_itemSubs.containsKey(item.listId)) {
      final list = _items[item.listId] ?? [];
      final idx = list.indexWhere((i) => i.id == item.id);
      if (idx >= 0) list[idx] = item;
      notifyListeners();
    }
  }

  Future<void> toggleItem(ShoppingListItem item) async {
    final updated = item.copyWith(isChecked: !item.isChecked);
    await updateItem(updated);
  }

  Future<void> addFromPantryItems(String listId, List<PantryItem> items) async {
    for (final p in items) {
      final needed = (p.minStock > p.quantity) ? p.minStock - p.quantity : 1.0;
      await addItem(ShoppingListItem(
        id: const Uuid().v4(),
        listId: listId,
        productId: p.productId,
        productName: p.name,
        quantity: needed,
        unit: p.unit,
        unitPrice: 0.0,
      ));
    }
  }

  Future<void> deleteItem(ShoppingListItem item) async {
    await FirebaseService()
        .collection('shopping_list_items')
        .doc(item.id)
        .delete();
    // Stream will update if subscribed, otherwise update locally
    if (!_itemSubs.containsKey(item.listId)) {
      _items[item.listId]?.removeWhere((i) => i.id == item.id);
      notifyListeners();
    }
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

  @override
  void dispose() {
    _listSub?.cancel();
    for (final sub in _itemSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
