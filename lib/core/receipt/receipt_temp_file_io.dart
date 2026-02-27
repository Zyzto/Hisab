import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Writes [bytes] to a temp file and returns its path. Call only when dart:io is available.
Future<String?> writeReceiptBytesToTempFile(Uint8List bytes) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File(
      path.join(dir.path, 'receipt_scan_${DateTime.now().millisecondsSinceEpoch}.jpg'),
    );
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
