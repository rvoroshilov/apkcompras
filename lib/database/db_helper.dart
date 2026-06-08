import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/supermarket.dart';
import '../models/product.dart';
import '../models/price_history.dart';
import '../models/pantry_item.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'apkcompras.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE supermarkets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        supermarket_id TEXT NOT NULL,
        name TEXT NOT NULL,
        brand TEXT DEFAULT '',
        barcode TEXT DEFAULT '',
        category TEXT DEFAULT 'General',
        image_path TEXT DEFAULT '',
        price REAL NOT NULL,
        unit TEXT NOT NULL DEFAULT 'ud',
        quantity_per_unit REAL DEFAULT 1.0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supermarket_id) REFERENCES supermarkets(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE price_history (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        price REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pantry_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT NOT NULL DEFAULT 'ud',
        expiry_date TEXT,
        image_path TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        product_id TEXT,
        min_stock REAL NOT NULL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_lists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        budget REAL DEFAULT 0.0,
        is_template INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_list_items (
        id TEXT PRIMARY KEY,
        list_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        supermarket_name TEXT DEFAULT '',
        unit_price REAL NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT NOT NULL DEFAULT 'ud',
        discount_percent REAL NOT NULL DEFAULT 0.0,
        notes TEXT DEFAULT '',
        is_checked INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (list_id) REFERENCES shopping_lists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.execute(
          'ALTER TABLE products ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE pantry_items ADD COLUMN min_stock REAL NOT NULL DEFAULT 0.0');
      await db.execute(
          'ALTER TABLE shopping_lists ADD COLUMN is_template INTEGER NOT NULL DEFAULT 0');
    }
  }

  // ── APP SETTINGS ──────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final database = await db;
    final maps = await database
        .query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final database = await db;
    await database.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double> getMonthlyBudget() async {
    final v = await getSetting('monthly_budget');
    return double.tryParse(v ?? '') ?? 0.0;
  }

  Future<void> setMonthlyBudget(double budget) async {
    await setSetting('monthly_budget', budget.toString());
  }

  // ── SUPERMARKETS ──────────────────────────────────────────────────────────

  Future<List<Supermarket>> getSupermarkets() async {
    final database = await db;
    final maps = await database.query('supermarkets', orderBy: 'name ASC');
    return maps.map(Supermarket.fromMap).toList();
  }

  Future<void> insertSupermarket(Supermarket s) async {
    final database = await db;
    await database.insert('supermarkets', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSupermarket(Supermarket s) async {
    final database = await db;
    await database.update('supermarkets', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteSupermarket(String id) async {
    final database = await db;
    await database.delete('supermarkets', where: 'id = ?', whereArgs: [id]);
  }

  // ── PRODUCTS ──────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts(String supermarketId) async {
    final database = await db;
    final maps = await database.query('products',
        where: 'supermarket_id = ?',
        whereArgs: [supermarketId],
        orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final database = await db;
    final maps = await database.query('products',
        where: 'name LIKE ? OR brand LIKE ? OR barcode = ?',
        whereArgs: ['%$query%', '%$query%', query],
        orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final database = await db;
    final maps = await database.query('products',
        where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> getProductsByName(String name) async {
    final database = await db;
    final maps = await database.query('products',
        where: 'name LIKE ?', whereArgs: ['%$name%'], orderBy: 'price ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final database = await db;
    final maps = await database.query('products', orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<List<Product>> getFavoriteProducts() async {
    final database = await db;
    final maps = await database.query('products',
        where: 'is_favorite = 1', orderBy: 'name ASC');
    return maps.map(Product.fromMap).toList();
  }

  Future<void> toggleFavorite(String productId, bool isFavorite) async {
    final database = await db;
    await database.update('products', {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?', whereArgs: [productId]);
  }

  Future<void> insertProduct(Product product) async {
    final database = await db;
    await database.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await database.insert('price_history', {
      'id': '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
      'product_id': product.id,
      'price': product.price,
      'recorded_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProduct(Product product) async {
    final database = await db;
    final old = await database.query('products',
        where: 'id = ?', whereArgs: [product.id], limit: 1);
    await database.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
    if (old.isNotEmpty &&
        (old.first['price'] as num).toDouble() != product.price) {
      await database.insert('price_history', {
        'id': '${product.id}_${DateTime.now().millisecondsSinceEpoch}',
        'product_id': product.id,
        'price': product.price,
        'recorded_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> deleteProduct(String id) async {
    final database = await db;
    await database.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ── PRICE HISTORY ─────────────────────────────────────────────────────────

  Future<List<PriceHistory>> getPriceHistory(String productId) async {
    final database = await db;
    final maps = await database.query('price_history',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'recorded_at ASC');
    return maps.map(PriceHistory.fromMap).toList();
  }

  // ── PANTRY ────────────────────────────────────────────────────────────────

  Future<List<PantryItem>> getPantryItems() async {
    final database = await db;
    final maps = await database.query('pantry_items', orderBy: 'name ASC');
    return maps.map(PantryItem.fromMap).toList();
  }

  Future<List<PantryItem>> getItemsBelowMinStock() async {
    final database = await db;
    final maps = await database.rawQuery(
        'SELECT * FROM pantry_items WHERE min_stock > 0 AND quantity < min_stock');
    return maps.map(PantryItem.fromMap).toList();
  }

  Future<void> insertPantryItem(PantryItem item) async {
    final database = await db;
    await database.insert('pantry_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePantryItem(PantryItem item) async {
    final database = await db;
    await database.update('pantry_items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deletePantryItem(String id) async {
    final database = await db;
    await database.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  }

  // ── SHOPPING LISTS ────────────────────────────────────────────────────────

  Future<List<ShoppingList>> getShoppingLists() async {
    final database = await db;
    final maps = await database.query('shopping_lists',
        orderBy: 'completed_at ASC, created_at DESC');
    return maps.map(ShoppingList.fromMap).toList();
  }

  Future<void> insertShoppingList(ShoppingList list) async {
    final database = await db;
    await database.insert('shopping_lists', list.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateShoppingList(ShoppingList list) async {
    final database = await db;
    await database.update('shopping_lists', list.toMap(),
        where: 'id = ?', whereArgs: [list.id]);
  }

  Future<void> deleteShoppingList(String id) async {
    final database = await db;
    await database.delete('shopping_lists', where: 'id = ?', whereArgs: [id]);
  }

  // ── SHOPPING LIST ITEMS ───────────────────────────────────────────────────

  Future<List<ShoppingListItem>> getShoppingListItems(String listId) async {
    final database = await db;
    final maps = await database.query('shopping_list_items',
        where: 'list_id = ?',
        whereArgs: [listId],
        orderBy: 'supermarket_name ASC, product_name ASC');
    return maps.map(ShoppingListItem.fromMap).toList();
  }

  Future<void> insertShoppingListItem(ShoppingListItem item) async {
    final database = await db;
    await database.insert('shopping_list_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateShoppingListItem(ShoppingListItem item) async {
    final database = await db;
    await database.update('shopping_list_items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteShoppingListItem(String id) async {
    final database = await db;
    await database.delete('shopping_list_items',
        where: 'id = ?', whereArgs: [id]);
  }

  // ── STATS ─────────────────────────────────────────────────────────────────

  Future<double> getMonthlySpend() async {
    final database = await db;
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).toIso8601String();
    final result = await database.rawQuery('''
      SELECT SUM(sli.unit_price * sli.quantity * (1 - sli.discount_percent / 100)) as total
      FROM shopping_list_items sli
      JOIN shopping_lists sl ON sli.list_id = sl.id
      WHERE sl.completed_at IS NOT NULL
        AND sl.completed_at >= ?
        AND sl.is_template = 0
    ''', [startOfMonth]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Returns monthly spending for the last [months] months, ordered oldest→newest.
  /// Each entry: {'month': 'YYYY-MM', 'total': double}
  Future<List<Map<String, dynamic>>> getSpendingHistory(int months) async {
    final database = await db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - months + 1, 1);
    final result = await database.rawQuery('''
      SELECT strftime('%Y-%m', sl.completed_at) as month,
             SUM(sli.unit_price * sli.quantity * (1 - sli.discount_percent / 100)) as total
      FROM shopping_list_items sli
      JOIN shopping_lists sl ON sli.list_id = sl.id
      WHERE sl.completed_at IS NOT NULL
        AND sl.completed_at >= ?
        AND sl.is_template = 0
      GROUP BY strftime('%Y-%m', sl.completed_at)
      ORDER BY month ASC
    ''', [start.toIso8601String()]);
    return result
        .map((r) => {
              'month': r['month'] as String,
              'total': (r['total'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();
  }

  /// Returns spending breakdown by supermarket for the current month.
  /// Each entry: {'market': String, 'total': double}
  Future<List<Map<String, dynamic>>> getSpendBySupermarket() async {
    final database = await db;
    final now = DateTime.now();
    final startOfMonth =
        DateTime(now.year, now.month, 1).toIso8601String();
    final result = await database.rawQuery('''
      SELECT COALESCE(NULLIF(sli.supermarket_name, ''), 'Sin tienda') as market,
             SUM(sli.unit_price * sli.quantity * (1 - sli.discount_percent / 100)) as total
      FROM shopping_list_items sli
      JOIN shopping_lists sl ON sli.list_id = sl.id
      WHERE sl.completed_at IS NOT NULL
        AND sl.completed_at >= ?
        AND sl.is_template = 0
      GROUP BY sli.supermarket_name
      ORDER BY total DESC
    ''', [startOfMonth]);
    return result
        .map((r) => {
              'market': r['market'] as String,
              'total': (r['total'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return p.join(dbPath, 'apkcompras.db');
  }

  Future<void> closeDB() async {
    await _db?.close();
    _db = null;
  }
}
