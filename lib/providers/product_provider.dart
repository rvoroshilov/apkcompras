import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/price_history.dart';
import '../services/firebase_service.dart';

class ProductProvider extends ChangeNotifier {
  final Map<String, List<Product>> _bySupermarket = {};
  List<Product> _searchResults = [];
  List<Product> _favorites = [];
  bool _loading = false;
  final Map<String, StreamSubscription> _supermarketSubs = {};

  bool get loading => _loading;
  List<Product> get searchResults => _searchResults;
  List<Product> get favorites => _favorites;

  List<Product> forSupermarket(String supermarketId) =>
      _bySupermarket[supermarketId] ?? [];

  /// Converts Firestore doc data to a map compatible with Product.fromMap.
  Map<String, dynamic> _productFromFirestore(Map<String, dynamic> data, String id) {
    return {
      ...data,
      'id': id,
      // Ensure is_favorite is an int
      'is_favorite': (data['is_favorite'] as int?) ?? 0,
    };
  }

  Future<void> load() async {
    await loadFavorites();
  }

  Future<void> loadFavorites() async {
    final fs = FirebaseService();
    final snap = await fs.collection('products')
        .where('is_favorite', isEqualTo: 1)
        .get();
    _favorites = snap.docs
        .map((d) => Product.fromMap(_productFromFirestore(d.data(), d.id)))
        .toList();
    notifyListeners();
  }

  Future<void> toggleFavorite(Product product) async {
    final newFav = !product.isFavorite;
    final updated = product.copyWith(isFavorite: newFav);
    final map = updated.toMap()..remove('id');
    await FirebaseService()
        .collection('products')
        .doc(product.id)
        .update(map);

    // Update in-memory supermarket cache
    final list = _bySupermarket[product.supermarketId];
    if (list != null) {
      final idx = list.indexWhere((p) => p.id == product.id);
      if (idx >= 0) list[idx] = updated;
    }
    // Update search results
    final sIdx = _searchResults.indexWhere((p) => p.id == product.id);
    if (sIdx >= 0) _searchResults[sIdx] = updated;
    // Refresh favorites list
    await loadFavorites();
  }

  Future<void> loadForSupermarket(String supermarketId) async {
    _loading = true;
    notifyListeners();

    // Cancel existing subscription
    await _supermarketSubs[supermarketId]?.cancel();

    final fs = FirebaseService();
    _supermarketSubs[supermarketId] = fs.collection('products')
        .where('supermarket_id', isEqualTo: supermarketId)
        .orderBy('name')
        .snapshots()
        .listen((snap) {
      _bySupermarket[supermarketId] = snap.docs
          .map((d) => Product.fromMap(_productFromFirestore(d.data(), d.id)))
          .toList();
      _loading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('ProductProvider stream error for $supermarketId: $e');
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    // Search across all products in Firestore for this household
    final q = query.trim().toLowerCase();
    final fs = FirebaseService();
    final snap = await fs.collection('products').get();
    _searchResults = snap.docs
        .map((d) => Product.fromMap(_productFromFirestore(d.data(), d.id)))
        .where((p) => p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
    notifyListeners();
  }

  Future<List<Product>> getByName(String name) async {
    final q = name.toLowerCase();
    final fs = FirebaseService();
    final snap = await fs.collection('products').get();
    return snap.docs
        .map((d) => Product.fromMap(_productFromFirestore(d.data(), d.id)))
        .where((p) => p.name.toLowerCase() == q)
        .toList();
  }

  Future<List<Product>> getAll() async {
    final fs = FirebaseService();
    final snap = await fs.collection('products').get();
    return snap.docs
        .map((d) => Product.fromMap(_productFromFirestore(d.data(), d.id)))
        .toList();
  }

  Future<Product?> getByBarcode(String barcode) async {
    final fs = FirebaseService();
    final snap = await fs.collection('products')
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Product.fromMap(_productFromFirestore(d.data(), d.id));
  }

  Future<List<PriceHistory>> getPriceHistory(String productId) async {
    final snap = await FirebaseService()
        .collection('price_history')
        .where('product_id', isEqualTo: productId)
        .get();
    final history = snap.docs
        .map((d) => PriceHistory.fromMap({...d.data(), 'id': d.id}))
        .toList();
    history.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return history;
  }

  Future<void> _recordPrice(String productId, double price) async {
    final id = const Uuid().v4();
    await FirebaseService().collection('price_history').doc(id).set({
      'product_id': productId,
      'price': price,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> add(Product product) async {
    final map = product.toMap()..remove('id');
    await FirebaseService().collection('products').doc(product.id).set(map);
    await _recordPrice(product.id, product.price);
    // Update in-memory cache optimistically if stream not active
    if (!_supermarketSubs.containsKey(product.supermarketId)) {
      final list = _bySupermarket[product.supermarketId] ?? [];
      list.add(product);
      list.sort((a, b) => a.name.compareTo(b.name));
      _bySupermarket[product.supermarketId] = list;
      notifyListeners();
    }
    // If stream is active it will update automatically
  }

  Future<void> update(Product product) async {
    // Record a price-history point if the price changed.
    final doc =
        await FirebaseService().collection('products').doc(product.id).get();
    final oldPrice = (doc.data()?['price'] as num?)?.toDouble();
    final map = product.toMap()..remove('id');
    await FirebaseService().collection('products').doc(product.id).update(map);
    if (oldPrice == null || oldPrice != product.price) {
      await _recordPrice(product.id, product.price);
    }
    // Stream will update if active
    if (!_supermarketSubs.containsKey(product.supermarketId)) {
      final list = _bySupermarket[product.supermarketId] ?? [];
      final idx = list.indexWhere((p) => p.id == product.id);
      if (idx >= 0) list[idx] = product;
      notifyListeners();
    }
  }

  Future<void> delete(String supermarketId, String productId) async {
    await FirebaseService().collection('products').doc(productId).delete();
    // Stream will update if active
    if (!_supermarketSubs.containsKey(supermarketId)) {
      _bySupermarket[supermarketId]?.removeWhere((p) => p.id == productId);
      notifyListeners();
    }
  }

  String generateId() => const Uuid().v4();

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void clearSupermarket(String supermarketId) {
    _supermarketSubs[supermarketId]?.cancel();
    _supermarketSubs.remove(supermarketId);
    _bySupermarket.remove(supermarketId);
  }

  @override
  void dispose() {
    for (final sub in _supermarketSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
