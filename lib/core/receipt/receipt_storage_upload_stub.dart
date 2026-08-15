import 'dart:typed_data';

import 'package:hisab_backend/hisab_backend.dart';

/// Stub path upload: returns null so callers do not overwrite with a URL (web has no local path).
Future<String?> uploadExpenseImageToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  return null;
}

/// Uploads expense image [bytes] (used on web where the file path is unavailable).
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
