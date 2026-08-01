import 'dart:typed_data';

class LocalReceiptFile {
  const LocalReceiptFile({required this.relativePath, required this.bytes});
  final String relativePath;
  final Uint8List bytes;
}

enum BackupExportKind { minimalJson, minimalCsv, fullZip }

enum BackupImportMode { addCopies, replaceLocal }
