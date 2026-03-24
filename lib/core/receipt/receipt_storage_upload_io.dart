import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/supabase_config.dart';

const String _bucket = 'expense-images';

/// Uploads an expense image at [localPath] to Supabase Storage under
/// [groupId]/[expenseId]/{uuid}.{ext}. Returns the public URL, or null on failure.
/// Call only when Supabase is configured and user is authenticated.
Future<String?> uploadExpenseImageToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  if (!supabaseConfigAvailable) return null;
  final file = File(localPath);
  if (!await file.exists()) {
    Log.warning('Expense image upload: file not found: $localPath');
    return null;
  }
  final bytes = await file.readAsBytes();
  final ext = _normalizeImageExt(
    path.extension(localPath).isEmpty
        ? 'jpg'
        : path.extension(localPath).replaceFirst('.', ''),
  );
  return uploadExpenseImageBytesToStorage(bytes, groupId, expenseId, fileExt: ext);
}

/// Uploads expense image [bytes] to Supabase Storage under
/// [groupId]/[expenseId]/{uuid}.{ext}. Returns the public URL, or null on failure.
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
