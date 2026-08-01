/// Whether [path] is an image URL (http/https or protocol-relative).
/// Used to decide upload vs display: URLs are not uploaded; non-URLs are local paths.
bool isImageUrl(String? path) {
  if (path == null || path.isEmpty) return false;
  final p = path.trim().toLowerCase();
  return p.startsWith('http://') ||
      p.startsWith('https://') ||
      p.startsWith('//');
}

/// Alias used by backup import strip logic.
bool isNetworkImagePath(String? path) => isImageUrl(path);

@Deprecated('Use isImageUrl instead.')
bool isReceiptImageUrl(String? path) => isImageUrl(path);
