/// Whether [path] is a receipt image URL (http/https).
/// Used to decide upload vs display: URLs are not uploaded; non-URLs are local paths.
bool isReceiptImageUrl(String? path) {
  if (path == null || path.isEmpty) return false;
  return path.startsWith('http://') || path.startsWith('https://');
}
