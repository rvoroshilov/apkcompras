import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/supermarket.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';

class SupermarketProvider extends ChangeNotifier {
  List<Supermarket> _items = [];
  bool _loading = false;
  StreamSubscription? _sub;

  List<Supermarket> get items => _items;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final fs = FirebaseService();
    _sub?.cancel();
    _sub = fs.collection('supermarkets')
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      _items = snap.docs.map((d) {
        final data = d.data();
        return Supermarket.fromMap({...data, 'id': d.id});
      }).toList();
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('SupermarketProvider stream error: $e');
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> add(String name, int color) async {
    final s = Supermarket(
      id: const Uuid().v4(),
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );
    await FirebaseService().collection('supermarkets').doc(s.id).set(s.toMap()..remove('id'));
    // Stream will update _items automatically
  }

  Future<void> update(Supermarket s) async {
    final map = s.toMap()..remove('id');
    await FirebaseService().collection('supermarkets').doc(s.id).update(map);
    // Stream will update _items automatically
  }

  Future<void> delete(String id) async {
    await FirebaseService().collection('supermarkets').doc(id).delete();
    // Stream will update _items automatically
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

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
