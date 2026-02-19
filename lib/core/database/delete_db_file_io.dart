import 'dart:io';

/// Deletes the file at [path] if it exists. Used for schema-recovery reset.
Future<void> deleteDbFile(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
