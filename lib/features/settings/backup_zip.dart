import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'backup_limits.dart';
import 'backup_types.dart';

/// Encode a full backup zip in memory (works on web and IO).
Uint8List encodeBackupZip({
  required String manifestJson,
  required String backupJson,
  required String reportHtml,
  required String expensesCsv,
  List<LocalReceiptFile> receipts = const [],
}) {
  final archive = Archive();
  void add(String name, String content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add('manifest.json', manifestJson);
  add('backup.json', backupJson);
  add('report.html', reportHtml);
  add('expenses.csv', expensesCsv);
  for (final r in receipts) {
    final safe = _safeReceiptEntryName(r.relativePath);
    if (safe == null) continue;
    if (r.bytes.length > BackupLimits.maxReceiptBytes) continue;
    archive.addFile(ArchiveFile(safe, r.bytes.length, r.bytes));
  }
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
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
  if (bytes.length > BackupLimits.maxFileBytes) {
    throw FormatException('backup zip too large');
  }
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  if (archive.length > BackupLimits.maxZipEntries) {
    throw FormatException('too many zip entries');
  }
  var uncompressed = 0;
  String? backupJson;
  final receipts = <String, Uint8List>{};
  for (final file in archive) {
    if (!file.isFile) continue;
    final name = file.name.replaceAll('\\', '/');
    if (!_isSafeZipPath(name)) {
      throw FormatException('unsafe zip entry path');
    }
    final content = file.content;
    uncompressed += content.length;
    if (uncompressed > BackupLimits.maxUncompressedZipBytes) {
      throw FormatException('uncompressed zip too large');
    }
    if (name == 'backup.json' || name.endsWith('/backup.json')) {
      backupJson = utf8.decode(content);
    } else if (name.startsWith('receipts/') || name.contains('/receipts/')) {
      final base = p.basename(name);
      if (!_isAllowedImageExt(base)) continue;
      if (content.length > BackupLimits.maxReceiptBytes) continue;
      receipts[name] = content;
      receipts['receipts/$base'] = content;
      receipts[base] = content;
    }
  }
  if (backupJson == null || backupJson.isEmpty) {
    throw FormatException('backup.json missing from zip');
  }
  return DecodedBackupZip(backupJson: backupJson, receipts: receipts);
}

bool _isSafeZipPath(String name) {
  if (name.isEmpty || name.startsWith('/') || name.contains('\x00')) {
    return false;
  }
  final parts = name.split('/');
  for (final part in parts) {
    if (part == '..' || part == '.') return false;
  }
  return true;
}

String? _safeReceiptEntryName(String relativePath) {
  final name = relativePath.replaceAll('\\', '/');
  if (!_isSafeZipPath(name)) return null;
  if (!name.startsWith('receipts/')) return null;
  if (!_isAllowedImageExt(p.basename(name))) return null;
  return name;
}

bool _isAllowedImageExt(String filename) {
  final ext = p.extension(filename).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(ext);
}
