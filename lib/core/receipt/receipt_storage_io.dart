import 'dart:io';

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
