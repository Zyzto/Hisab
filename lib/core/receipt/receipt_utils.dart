/// Whether [path] is an image URL (http/https).
/// Used to decide upload vs display: URLs are not uploaded; non-URLs are local paths.
bool isImageUrl(String? path) {
  if (path == null || path.isEmpty) return false;
  return path.startsWith('http://') || path.startsWith('https://');
}

@Deprecated('Use isImageUrl instead.')
bool isReceiptImageUrl(String? path) => isImageUrl(path);
