import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/product.dart';
import '../models/price_history.dart';

class ProductProvider extends ChangeNotifier {
  final _db = DBHelper();
  final Map<String, List<Product>> _bySupermarket = {};
  List<Product> _searchResults = [];
  bool _loading = false;

  bool get loading => _loading;
  List<Product> get searchResults => _searchResults;

  List<Product> forSupermarket(String supermarketId) =>
      _bySupermarket[supermarketId] ?? [];

  Future<void> load() async {}

  Future<void> loadForSupermarket(String supermarketId) async {
    _loading = true;
    notifyListeners();
    _bySupermarket[supermarketId] = await _db.getProducts(supermarketId);
    _loading = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _searchResults = await _db.searchProducts(query.trim());
    notifyListeners();
  }

  Future<List<Product>> getByName(String name) =>
      _db.getProductsByName(name);

  Future<List<Product>> getAll() => _db.getAllProducts();

  Future<Product?> getByBarcode(String barcode) =>
      _db.getProductByBarcode(barcode);

  Future<List<PriceHistory>> getPriceHistory(String productId) =>
      _db.getPriceHistory(productId);

  Future<void> add(Product product) async {
    await _db.insertProduct(product);
    final list = _bySupermarket[product.supermarketId] ?? [];
    list.add(product);
    list.sort((a, b) => a.name.compareTo(b.name));
    _bySupermarket[product.supermarketId] = list;
    notifyListeners();
  }

  Future<void> update(Product product) async {
    await _db.updateProduct(product);
    final list = _bySupermarket[product.supermarketId] ?? [];
    final idx = list.indexWhere((p) => p.id == product.id);
    if (idx >= 0) list[idx] = product;
    notifyListeners();
  }

  Future<void> delete(String supermarketId, String productId) async {
    await _db.deleteProduct(productId);
    _bySupermarket[supermarketId]?.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  String generateId() => const Uuid().v4();

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void clearSupermarket(String supermarketId) {
    _bySupermarket.remove(supermarketId);
  }
}
