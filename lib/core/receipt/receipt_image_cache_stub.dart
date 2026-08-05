import 'dart:typed_data';

/// Stub (web/non-io): no local file cache.
Future<String?> getCachedReceiptPathForUrl(String url) async {
  return null;
}

/// Stub (web/non-io): no local file cache.
Future<String?> getOrFetchCachedReceiptPathForUrl(String url) async {
  return null;
}

/// Stub (web/non-io): no local file cache — caller may fetch over the network.
Future<Uint8List?> loadReceiptImageBytesForUrl(String url) async {
  return null;
}

/// Stub (web/non-io): no local file cache.
Future<void> warmReceiptImageCacheForUrl(
  String url,
  Uint8List bytes, {
  String? fileExt,
}) async {}
