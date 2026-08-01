import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/receipt/receipt_utils.dart';
import 'backup_limits.dart';
import 'backup_types.dart';

/// original local path → zip-relative receipt file.
Future<Map<String, LocalReceiptFile>> collectLocalReceiptFiles(
  Iterable<String> localPaths,
) async {
  final out = <String, LocalReceiptFile>{};
  var i = 0;
  for (final path in localPaths) {
    if (isNetworkImagePath(path)) continue;
    if (path.isEmpty || out.containsKey(path)) continue;
    final file = File(path);
    if (!await file.exists()) continue;
    final len = await file.length();
    if (len <= 0 || len > BackupLimits.maxReceiptBytes) continue;
    final ext = p.extension(path).toLowerCase();
    if (!const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(ext)) {
      continue;
    }
    final bytes = await file.readAsBytes();
    i++;
    out[path] = LocalReceiptFile(
      relativePath: 'receipts/$i$ext',
      bytes: Uint8List.fromList(bytes),
    );
  }
  return out;
}
