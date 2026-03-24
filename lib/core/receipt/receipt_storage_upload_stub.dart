import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/supabase_config.dart';

const String _bucket = 'expense-images';

/// Stub path upload: returns null so callers do not overwrite with a URL (web has no local path).
Future<String?> uploadExpenseImageToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  return null;
}

/// Uploads expense image [bytes] to Supabase Storage (used on web where file path is unavailable).
Future<String?> uploadExpenseImageBytesToStorage(
  Uint8List bytes,
  String groupId,
  String expenseId, {
  String? fileExt,
}) async {
  final client = supabaseClientIfConfigured;
  if (client == null) return null;
  final ext = _normalizeImageExt(fileExt ?? 'jpg');
  final bucketKey = '$groupId/$expenseId/${const Uuid().v4()}.$ext';
  try {
    await client.storage
        .from(_bucket)
        .uploadBinary(
          bucketKey,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentTypeForExt(ext),
          ),
        );
    final url = client.storage.from(_bucket).getPublicUrl(bucketKey);
    Log.debug('Expense image uploaded: $bucketKey');
    return url;
  } catch (e, st) {
    Log.error('Expense image upload failed', error: e, stackTrace: st);
    return null;
  }
}

@Deprecated('Use uploadExpenseImageToStorage instead.')
Future<String?> uploadReceiptToStorage(
  String localPath,
  String groupId,
  String expenseId,
) => uploadExpenseImageToStorage(localPath, groupId, expenseId);

@Deprecated('Use uploadExpenseImageBytesToStorage instead.')
Future<String?> uploadReceiptBytesToStorage(
  Uint8List bytes,
  String groupId,
  String expenseId, {
  String? fileExt,
}) => uploadExpenseImageBytesToStorage(
  bytes,
  groupId,
  expenseId,
  fileExt: fileExt,
);

String _normalizeImageExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'jpg';
    case 'png':
      return 'png';
    case 'webp':
      return 'webp';
    default:
      return 'jpg';
  }
}

String _contentTypeForExt(String ext) {
  switch (_normalizeImageExt(ext)) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    default:
      return 'image/jpeg';
  }
}
