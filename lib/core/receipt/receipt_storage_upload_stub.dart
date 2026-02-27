import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/supabase_config.dart';

const String _bucket = 'receipt-images';

/// Stub path upload: returns null so callers do not overwrite with a URL (web has no local path).
Future<String?> uploadReceiptToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  return null;
}

/// Uploads receipt image [bytes] to Supabase Storage (used on web where file path is unavailable).
Future<String?> uploadReceiptBytesToStorage(
  Uint8List bytes,
  String groupId,
  String expenseId, {
  String? fileExt,
}) async {
  final client = supabaseClientIfConfigured;
  if (client == null) return null;
  final ext = fileExt ?? 'jpg';
  final bucketKey = '$groupId/$expenseId/${const Uuid().v4()}.$ext';
  try {
    await client.storage.from(_bucket).uploadBinary(
          bucketKey,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );
    final url = client.storage.from(_bucket).getPublicUrl(bucketKey);
    Log.debug('Receipt uploaded: $bucketKey');
    return url;
  } catch (e, st) {
    Log.error('Receipt upload failed', error: e, stackTrace: st);
    return null;
  }
}
