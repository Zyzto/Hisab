/// Stub for platforms that do not support dart:io (e.g. web).
/// Copy is not supported; caller should not invoke this on web.
Future<String> copyReceiptToAppStorage(String sourcePath) async {
  throw UnsupportedError('Receipt storage is not supported on this platform');
}
