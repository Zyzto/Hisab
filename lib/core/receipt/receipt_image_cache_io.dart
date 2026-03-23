import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> getCachedReceiptPathForUrl(String url) async {
  final file = await _cachedFileForUrl(url);
  if (await file.exists()) return file.path;
  return null;
}

Future<String?> getOrFetchCachedReceiptPathForUrl(String url) async {
  final cached = await getCachedReceiptPathForUrl(url);
  if (cached != null) return cached;

  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
    final ext = _extFromResponse(url, response.headers['content-type']);
    await warmReceiptImageCacheForUrl(url, response.bodyBytes, fileExt: ext);
    return getCachedReceiptPathForUrl(url);
  } catch (_) {
    return null;
  }
}

Future<void> warmReceiptImageCacheForUrl(
  String url,
  Uint8List bytes, {
  String? fileExt,
}) async {
  if (bytes.isEmpty) return;
  final ext = _normalizeExt(fileExt ?? _extFromUrl(url));
  final file = await _cachedFileForUrl(url, fileExt: ext);
  if (await file.exists()) return;
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<File> _cachedFileForUrl(String url, {String? fileExt}) async {
  final dir = await _cacheDirectory();
  final ext = _normalizeExt(fileExt ?? _extFromUrl(url));
  final hash = _stableHashHex(url);
  final name = '$hash.$ext';
  return File(p.join(dir.path, name));
}

Future<Directory> _cacheDirectory() async {
  final base = await getTemporaryDirectory();
  return Directory(p.join(base.path, 'receipt_image_cache'));
}

String _extFromResponse(String url, String? contentType) {
  final ct = (contentType ?? '').toLowerCase();
  if (ct.contains('image/jpeg') || ct.contains('image/jpg')) return 'jpg';
  if (ct.contains('image/png')) return 'png';
  if (ct.contains('image/webp')) return 'webp';
  return _extFromUrl(url);
}

String _extFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'jpg';
  final ext = p.extension(uri.path).replaceFirst('.', '').toLowerCase();
  return _normalizeExt(ext);
}

String _normalizeExt(String ext) {
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

String _stableHashHex(String input) {
  const int offset = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  var hash = offset;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
