import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../database/db_helper.dart';

/// Maneja el almacenamiento de imágenes y las copias de seguridad portables.
///
/// Las imágenes se guardan SOLO por nombre de archivo en la base de datos y se
/// resuelven a ruta absoluta en tiempo de ejecución. Así, una copia de
/// seguridad (BD + carpeta de imágenes empaquetadas en un .zip) se puede
/// restaurar en cualquier dispositivo sin perder las fotos.
class BackupHelper {
  static String? _imagesDirPath;

  /// Debe llamarse en main() antes de runApp().
  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    _imagesDirPath = imagesDir.path;
  }

  static Future<String> getImagesDirectory() async {
    if (_imagesDirPath == null) await init();
    return _imagesDirPath!;
  }

  /// Copia la imagen seleccionada a la carpeta de imágenes y devuelve solo el
  /// nombre del archivo (para guardarlo en la BD).
  static Future<String> saveImage(String sourcePath) async {
    final imagesDir = await getImagesDirectory();
    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = p.join(imagesDir, filename);
    await File(sourcePath).copy(target);
    return filename;
  }

  /// Resuelve un valor guardado en la BD a una ruta absoluta usable.
  /// Acepta nombres de archivo nuevos y rutas absolutas antiguas (compatibilidad).
  static String resolveImagePath(String stored) {
    if (stored.isEmpty) return '';
    if (stored.contains('/')) return stored; // ruta absoluta antigua
    if (_imagesDirPath == null) return stored;
    return p.join(_imagesDirPath!, stored);
  }

  // ── COPIA DE SEGURIDAD (ZIP con BD + imágenes) ─────────────────────────────

  /// Exporta toda la app (base de datos + fotos) a un .zip y abre el diálogo
  /// de compartir para enviarlo a otro dispositivo o guardarlo.
  static Future<void> exportBackup() async {
    final dbPath = await DBHelper().getDatabasePath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('No hay datos que exportar todavía.');
    }

    final imagesDir = await getImagesDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    final tmpDir = await getTemporaryDirectory();
    final zipPath = p.join(tmpDir.path, 'micompra_backup_$stamp.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    // La base de datos siempre como 'micompra.db' dentro del zip.
    encoder.addFile(dbFile, 'micompra.db');
    // Todas las imágenes bajo images/
    final imagesDirectory = Directory(imagesDir);
    if (await imagesDirectory.exists()) {
      await for (final entity in imagesDirectory.list()) {
        if (entity is File) {
          encoder.addFile(entity, 'images/${p.basename(entity.path)}');
        }
      }
    }
    encoder.close();

    await Share.shareXFiles(
      [XFile(zipPath)],
      subject: 'Copia de seguridad de MiCompra',
      text:
          'Copia de seguridad de MiCompra (datos + fotos). Ábrela desde Ajustes → Importar en otro móvil con la app instalada.',
    );
  }

  /// Restaura una copia desde un .zip (BD + imágenes) o desde un .db suelto.
  /// Cierra la BD actual, sustituye los archivos y la reabre.
  static Future<bool> importBackup(String filePath) async {
    try {
      final db = DBHelper();
      final dbPath = await db.getDatabasePath();
      final imagesDir = await getImagesDirectory();

      await db.closeDB();

      if (filePath.toLowerCase().endsWith('.zip')) {
        final bytes = await File(filePath).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        bool foundDb = false;
        for (final entry in archive) {
          if (!entry.isFile) continue;
          final name = entry.name;
          if (name == 'micompra.db' || name.endsWith('/micompra.db')) {
            await File(dbPath).writeAsBytes(entry.content as List<int>);
            foundDb = true;
          } else if (name.startsWith('images/')) {
            final outPath = p.join(imagesDir, p.basename(name));
            await File(outPath).writeAsBytes(entry.content as List<int>);
          }
        }
        if (!foundDb) return false;
      } else {
        // .db suelto (compatibilidad con backups antiguos)
        await File(filePath).copy(dbPath);
      }

      // Reabrir la BD para las siguientes consultas.
      await db.db;
      return true;
    } catch (_) {
      return false;
    }
  }
}
