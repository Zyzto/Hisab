/// Stub for web: cannot delete SQLite DB file (no dart:io).
Future<void> deleteDbFile(String path) async {
  // No-op on web; DB is in-memory or managed by the engine.
}
