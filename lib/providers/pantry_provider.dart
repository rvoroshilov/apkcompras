import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/pantry_item.dart';
import '../services/activity_service.dart';
import '../services/firebase_service.dart';
import '../utils/notification_helper.dart';

class PantryProvider extends ChangeNotifier {
  List<PantryItem> _items = [];
  bool _loading = false;
  StreamSubscription? _sub;

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
    final fs = FirebaseService();
    _sub?.cancel();
    _sub = fs.collection('pantry_items')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      _items = snap.docs.map((d) {
        final data = d.data();
        return PantryItem.fromMap({...data, 'id': d.id});
      }).toList();
      _loading = false;
      notifyListeners();
      if (_items.any((i) => i.isExpired || i.isExpiringSoon)) {
        NotificationHelper.checkExpiringItems(_items);
      }
      // Reprograma los avisos de caducidad (cubre reinicios y cambios remotos).
      NotificationHelper.rescheduleExpiryNotifications(_items);
    }, onError: (e) {
      debugPrint('PantryProvider stream error: $e');
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> add(PantryItem item) async {
    final toAdd = PantryItem(
      id: const Uuid().v4(),
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      category: item.category,
      expiryDate: item.expiryDate,
      imagePath: item.imagePath,
      notes: item.notes,
      productId: item.productId,
      minStock: item.minStock,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final map = toAdd.toMap()..remove('id');
    await FirebaseService().collection('pantry_items').doc(toAdd.id).set(map);
    ActivityService().log('added_pantry', item.name);
    // Stream will update _items automatically
  }

  Future<void> update(PantryItem item) async {
    final map = item.toMap()..remove('id');
    await FirebaseService().collection('pantry_items').doc(item.id).update(map);
    // Stream will update _items automatically
  }

  Future<void> delete(String id) async {
    final match = _items.where((i) => i.id == id);
    final name = match.isNotEmpty ? match.first.name : '';
    await FirebaseService().collection('pantry_items').doc(id).delete();
    if (name.isNotEmpty) ActivityService().log('deleted_pantry', name);
    NotificationHelper.cancelForItem(id);
    // Stream will update _items automatically
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
      case 'empty':
        return result.where((i) => i.isOutOfStock).toList();
      default:
        return result;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
