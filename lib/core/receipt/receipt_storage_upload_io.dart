import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';
import 'package:path/path.dart' as path;

/// Uploads the expense image at [localPath]. Returns its URL, or null on
/// failure — a receipt photo that fails to upload must not fail the expense.
Future<String?> uploadExpenseImageToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  if (!cloudAvailable) return null;
  final file = File(localPath);
  if (!await file.exists()) {
    Log.warning('Expense image upload: file not found: $localPath');
    return null;
  }
  final bytes = await file.readAsBytes();
  final ext = normalizeImageExt(
    path.extension(localPath).isEmpty
        ? 'jpg'
        : path.extension(localPath).replaceFirst('.', ''),
  );
  return uploadExpenseImageBytesToStorage(
    bytes,
    groupId,
    expenseId,
    fileExt: ext,
  );
}

/// Uploads expense image [bytes]. Returns its URL, or null on failure.
Future<String?> uploadExpenseImageBytesToStorage(
  Uint8List bytes,
  String groupId,
  String expenseId, {
  String? fileExt,
}) async {
  final files = cloudBackend?.files;
  if (files == null) return null;
  return files.uploadExpenseImage(
    bytes,
    groupId: groupId,
    expenseId: expenseId,
    fileExt: normalizeImageExt(fileExt ?? 'jpg'),
  );
}

/// Narrows an arbitrary extension to one the backend is required to accept.
String normalizeImageExt(String ext) {
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
