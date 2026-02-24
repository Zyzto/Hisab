import 'dart:io';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/supabase_config.dart';

const String _bucket = 'receipt-images';

/// Uploads the receipt image at [localPath] to Supabase Storage under
/// [groupId]/[expenseId]/{uuid}.{ext}. Returns the public URL, or null on failure.
/// Call only when Supabase is configured and user is authenticated.
Future<String?> uploadReceiptToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  if (!supabaseConfigAvailable) return null;
  final file = File(localPath);
  if (!await file.exists()) {
    Log.warning('Receipt upload: file not found: $localPath');
    return null;
  }
  final ext = path.extension(localPath).isEmpty ? 'jpg' : path.extension(localPath).replaceFirst('.', '');
  final bucketKey = '$groupId/$expenseId/${const Uuid().v4()}.$ext';
  try {
    final bytes = await file.readAsBytes();
    final client = Supabase.instance.client;
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
