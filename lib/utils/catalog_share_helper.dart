import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/supermarket.dart';
import '../services/firebase_service.dart';

/// Resultado de una importación de catálogo.
class CatalogImportResult {
  final int supersAdded;
  final int supersMerged;
  final int productsAdded;
  final int productsUpdated;

  const CatalogImportResult({
    this.supersAdded = 0,
    this.supersMerged = 0,
    this.productsAdded = 0,
    this.productsUpdated = 0,
  });

  int get totalSupers => supersAdded + supersMerged;
  int get totalProducts => productsAdded + productsUpdated;

  String get summary {
    final parts = <String>[];
    if (supersAdded > 0) parts.add('$supersAdded súper nuevo${supersAdded == 1 ? '' : 's'}');
    if (supersMerged > 0) parts.add('$supersMerged fusionado${supersMerged == 1 ? '' : 's'}');
    if (productsAdded > 0) parts.add('$productsAdded producto${productsAdded == 1 ? '' : 's'} añadido${productsAdded == 1 ? '' : 's'}');
    if (productsUpdated > 0) parts.add('$productsUpdated actualizado${productsUpdated == 1 ? '' : 's'}');
    return parts.isEmpty ? 'No había nada que importar.' : parts.join(' · ');
  }
}

/// Exporta e importa el catálogo (supermercados + productos) entre casas
/// distintas mediante un archivo .json compartible.
///
/// Las imágenes de producto NO se incluyen (son locales a cada dispositivo);
/// al importar se quedan sin foto.
class CatalogShareHelper {
  static const _format = 'micompra_catalog';
  static const _version = 1;

  // ── EXPORTAR ───────────────────────────────────────────────────────────

  /// Comparte un único supermercado con todos sus productos.
  static Future<void> shareSupermarket(Supermarket supermarket) async {
    final fs = FirebaseService();
    final snap = await fs
        .collection('products')
        .where('supermarket_id', isEqualTo: supermarket.id)
        .get();
    final products = snap.docs
        .map((d) => Product.fromMap({...d.data(), 'id': d.id}))
        .toList();
    final json = _buildJson([(supermarket, products)]);
    await _shareJson(json, 'catalogo_${_slug(supermarket.name)}');
  }

  /// Comparte TODOS los supermercados y productos de la casa actual.
  static Future<void> shareAll() async {
    final fs = FirebaseService();
    final superSnap =
        await fs.collection('supermarkets').orderBy('name').get();
    final prodSnap = await fs.collection('products').get();

    final products = prodSnap.docs
        .map((d) => Product.fromMap({...d.data(), 'id': d.id}))
        .toList();

    final entries = superSnap.docs.map((d) {
      final s = Supermarket.fromMap({...d.data(), 'id': d.id});
      final its = products.where((pr) => pr.supermarketId == s.id).toList();
      return (s, its);
    }).toList();

    if (entries.isEmpty) {
      throw Exception('No hay supermercados que compartir todavía.');
    }

    final json = _buildJson(entries);
    await _shareJson(json, 'catalogo_completo');
  }

  static Map<String, dynamic> _buildJson(
      List<(Supermarket, List<Product>)> entries) {
    return {
      'format': _format,
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'supermarkets': [
        for (final (s, products) in entries)
          {
            'name': s.name,
            'color': s.color,
            'products': [
              for (final pr in products)
                {
                  'name': pr.name,
                  'brand': pr.brand,
                  'barcode': pr.barcode,
                  'category': pr.category,
                  'price': pr.price,
                  'unit': pr.unit,
                  'quantity_per_unit': pr.quantityPerUnit,
                },
            ],
          },
      ],
    };
  }

  static Future<void> _shareJson(
      Map<String, dynamic> json, String baseName) async {
    final tmpDir = await getTemporaryDirectory();
    final filePath = p.join(tmpDir.path, '$baseName.json');
    await File(filePath)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(json));

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/json')],
      subject: 'Catálogo de MiCompra',
      text:
          'Catálogo de supermercados de MiCompra. Ábrelo desde Ajustes → Importar catálogo en otro móvil.',
    );
  }

  // ── IMPORTAR ───────────────────────────────────────────────────────────

  /// Importa un catálogo desde un archivo .json, fusionando con lo existente.
  /// Lanza [FormatException] si el archivo no es un catálogo válido.
  static Future<CatalogImportResult> importFromFile(String filePath) async {
    final raw = await File(filePath).readAsString();
    final dynamic decoded = jsonDecode(raw);

    if (decoded is! Map ||
        decoded['format'] != _format ||
        decoded['supermarkets'] is! List) {
      throw const FormatException(
          'El archivo no es un catálogo de MiCompra válido.');
    }

    final fs = FirebaseService();
    const uuid = Uuid();

    // Supermercados existentes indexados por nombre normalizado.
    final existingSuperSnap = await fs.collection('supermarkets').get();
    final superByName = <String, String>{}; // nombre normalizado → docId
    for (final d in existingSuperSnap.docs) {
      final name = (d.data()['name'] as String?) ?? '';
      superByName[_norm(name)] = d.id;
    }

    int supersAdded = 0, supersMerged = 0, productsAdded = 0, productsUpdated = 0;
    final now = DateTime.now().toIso8601String();

    for (final dynamic rawSuper in decoded['supermarkets'] as List) {
      if (rawSuper is! Map) continue;
      final superName = (rawSuper['name'] as String?)?.trim() ?? '';
      if (superName.isEmpty) continue;
      final color = (rawSuper['color'] as num?)?.toInt() ?? 0xFF1565C0;

      String superId;
      final existingId = superByName[_norm(superName)];
      if (existingId != null) {
        superId = existingId;
        supersMerged++;
      } else {
        superId = uuid.v4();
        await fs.collection('supermarkets').doc(superId).set({
          'name': superName,
          'color': color,
          'created_at': now,
        });
        superByName[_norm(superName)] = superId;
        supersAdded++;
      }

      // Productos existentes de este súper indexados por nombre normalizado.
      final existingProdSnap = await fs
          .collection('products')
          .where('supermarket_id', isEqualTo: superId)
          .get();
      final prodByName = <String, String>{};
      for (final d in existingProdSnap.docs) {
        final name = (d.data()['name'] as String?) ?? '';
        prodByName[_norm(name)] = d.id;
      }

      final rawProducts = (rawSuper['products'] as List?) ?? const [];
      for (final dynamic rawProd in rawProducts) {
        if (rawProd is! Map) continue;
        final pName = (rawProd['name'] as String?)?.trim() ?? '';
        if (pName.isEmpty) continue;

        final data = <String, dynamic>{
          'supermarket_id': superId,
          'name': pName,
          'brand': (rawProd['brand'] as String?) ?? '',
          'barcode': (rawProd['barcode'] as String?) ?? '',
          'category': (rawProd['category'] as String?) ?? 'General',
          'image_path': '',
          'price': (rawProd['price'] as num?)?.toDouble() ?? 0.0,
          'unit': (rawProd['unit'] as String?) ?? 'ud',
          'quantity_per_unit':
              (rawProd['quantity_per_unit'] as num?)?.toDouble() ?? 1.0,
          'is_favorite': 0,
          'updated_at': now,
        };

        final existingProdId = prodByName[_norm(pName)];
        if (existingProdId != null) {
          await fs.collection('products').doc(existingProdId).update(data);
          productsUpdated++;
        } else {
          data['created_at'] = now;
          await fs.collection('products').doc(uuid.v4()).set(data);
          productsAdded++;
        }
      }
    }

    return CatalogImportResult(
      supersAdded: supersAdded,
      supersMerged: supersMerged,
      productsAdded: productsAdded,
      productsUpdated: productsUpdated,
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _norm(String s) => s.trim().toLowerCase();

  static String _slug(String s) {
    final cleaned = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'super' : cleaned;
  }
}
