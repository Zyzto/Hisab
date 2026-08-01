import 'dart:typed_data' show Uint8List;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/supabase_config.dart';

const String _bucket = 'feedback-screenshots';

/// Upload failure is non-fatal; issue body still includes fallback text.
/// Works on web and native when Supabase is configured and the user is authenticated.
Future<String?> uploadFeedbackScreenshot(Uint8List pngBytes) async {
  final client = supabaseClientIfConfigured;
  if (client == null || pngBytes.isEmpty) return null;
  final bucketKey = 'feedback/${const Uuid().v4()}.png';
  try {
    await client.storage
        .from(_bucket)
        .uploadBinary(
          bucketKey,
          pngBytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'image/png',
          ),
        );
    return client.storage.from(_bucket).getPublicUrl(bucketKey);
  } catch (_) {
    return null;
  }
}
