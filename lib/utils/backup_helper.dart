import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class BackupHelper {
  static Future<void> exportDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'apkcompras.db'));

    if (!await dbFile.exists()) return;

    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final filename =
        'micompra_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.db';
    final backupPath = p.join(dir.path, filename);
    await dbFile.copy(backupPath);

    await Share.shareXFiles(
      [XFile(backupPath)],
      subject: 'Backup MiCompra',
      text:
          'Copia de seguridad de MiCompra. Importa este archivo en la app para restaurar tus datos.',
    );
  }

  static Future<bool> importDatabase(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final targetPath = p.join(dbPath, 'apkcompras.db');
      await File(filePath).copy(targetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getImagesDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir.path;
  }

  static Future<String> saveImage(String sourcePath) async {
    final imagesDir = await getImagesDirectory();
    final filename = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = p.join(imagesDir, filename);
    await File(sourcePath).copy(target);
    return target;
  }
}
