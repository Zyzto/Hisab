/// Stub: receipt upload to cloud not supported on this platform (e.g. web).
/// Returns null so callers keep the local path.
Future<String?> uploadReceiptToStorage(
  String localPath,
  String groupId,
  String expenseId,
) async {
  return null;
}
