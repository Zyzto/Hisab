import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Copies the receipt image to app documents/receipts/ and returns the stored path.
Future<String> copyReceiptToAppStorage(String sourcePath) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(path.join(dir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    final ext = path.extension(sourcePath).isEmpty
        ? '.jpg'
        : path.extension(sourcePath);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = path.join(receiptsDir.path, name);
    await File(sourcePath).copy(destPath);
    Log.debug('Receipt stored: $destPath');
    return destPath;
  } catch (e, st) {
    Log.error('Receipt storage failed', error: e, stackTrace: st);
    rethrow;
  }
}

/// Writes receipt [bytes] into app documents/receipts/ with a generated name.
Future<String> writeReceiptBytesToAppStorage(
  Uint8List bytes, {
  String extension = '.jpg',
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final receiptsDir = Directory(path.join(dir.path, 'receipts'));
  if (!await receiptsDir.exists()) {
    await receiptsDir.create(recursive: true);
  }
  var ext = extension.startsWith('.') ? extension : '.$extension';
  final allowed = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};
  if (!allowed.contains(ext.toLowerCase())) {
    ext = '.jpg';
  }
  final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
  final destPath = path.join(receiptsDir.path, name);
  await File(destPath).writeAsBytes(bytes, flush: true);
  Log.debug('Receipt bytes stored: $destPath');
  return destPath;
}

/// Deletes all files under documents/receipts/ (best-effort).
Future<void> clearReceiptAppStorage() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(path.join(dir.path, 'receipts'));
    if (!await receiptsDir.exists()) return;
    await for (final entity in receiptsDir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  } catch (e, st) {
    Log.warning('clearReceiptAppStorage failed', error: e, stackTrace: st);
  }
}
