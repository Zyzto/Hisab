import 'dart:typed_data';

/// Web / non-IO: zip packaging without local receipt files.
class BackupZipReceipt {
  const BackupZipReceipt({required this.relativePath, required this.bytes});
  final String relativePath;
  final Uint8List bytes;
}

Uint8List encodeBackupZip({
  required String manifestJson,
  required String backupJson,
  required String reportHtml,
  required String expensesCsv,
  List<BackupZipReceipt> receipts = const [],
}) {
  throw UnsupportedError('Full zip export requires dart:io');
}

class DecodedBackupZip {
  const DecodedBackupZip({
    required this.backupJson,
    this.receipts = const {},
  });
  final String backupJson;
  final Map<String, Uint8List> receipts;
}

DecodedBackupZip decodeBackupZip(Uint8List bytes) {
  throw UnsupportedError('Full zip import requires dart:io');
}

Future<List<BackupZipReceipt>> collectLocalReceipts(
  Iterable<String> localPaths,
) async =>
    const [];
