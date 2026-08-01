import 'dart:typed_data';

/// Stub for platforms that do not support dart:io (e.g. web).
Future<String> copyReceiptToAppStorage(String sourcePath) async {
  throw UnsupportedError('Receipt storage is not supported on this platform');
}

Future<String> writeReceiptBytesToAppStorage(
  Uint8List bytes, {
  String extension = '.jpg',
}) async {
  throw UnsupportedError('Receipt storage is not supported on this platform');
}

Future<void> clearReceiptAppStorage() async {}
