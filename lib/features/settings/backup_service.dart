import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:powersync/powersync.dart';

import '../../core/receipt/receipt_storage.dart';
import '../../core/receipt/receipt_utils.dart';
import '../../core/repository/expense_repository.dart';
import '../../core/repository/group_repository.dart';
import '../../core/repository/participant_repository.dart';
import '../../core/repository/powersync_repository.dart';
import '../../core/repository/tag_repository.dart';
import '../../domain/domain.dart';
import 'backup_csv.dart';
import 'backup_helper.dart';
import 'backup_html_report.dart';
import 'backup_receipt_files.dart';
import 'backup_types.dart';
import 'backup_wipe.dart';
import 'backup_zip.dart';

typedef BackupProgress = void Function(String phase, double? progress);

class BackupExportResult {
  const BackupExportResult({
    required this.bytes,
    required this.fileName,
    required this.mimeHint,
  });
  final Uint8List bytes;
  final String fileName;
  final String mimeHint;
}

class BackupImportPreview {
  const BackupImportPreview({
    required this.data,
    required this.schemaVersion,
    required this.warnings,
    this.receiptCount = 0,
    this.fromZip = false,
    this.zipReceipts = const {},
  });
  final BackupData data;
  final int schemaVersion;
  final List<String> warnings;
  final int receiptCount;
  final bool fromZip;
  final Map<String, Uint8List> zipReceipts;
}

class BackupImportResult {
  const BackupImportResult({
    required this.succeededGroups,
    required this.failedGroups,
  });
  final int succeededGroups;
  final List<String> failedGroups;
  bool get hasFailures => failedGroups.isNotEmpty;
}

class BackupPackageParse {
  const BackupPackageParse({this.preview, this.errorMessageKey});
  final BackupImportPreview? preview;
  final String? errorMessageKey;
}

/// Export / import orchestration for Settings → Data & Backup.
class BackupService {
  BackupService({
    required this.db,
    required this.groupRepo,
    required this.participantRepo,
    required this.expenseRepo,
    required this.tagRepo,
    required this.effectiveLocalOnly,
  });

  final PowerSyncDatabase db;
  final IGroupRepository groupRepo;
  final IParticipantRepository participantRepo;
  final IExpenseRepository expenseRepo;
  final ITagRepository tagRepo;
  final bool effectiveLocalOnly;

  /// Repos that never hot-loop PostgREST (queue when not local-only).
  static BackupService forImport({
    required PowerSyncDatabase db,
    required bool effectiveLocalOnly,
  }) {
    // Local-only: SQLite only. Online: treat offline so writes enqueue silently.
    final reposLocalOnly = effectiveLocalOnly;
    return BackupService(
      db: db,
      groupRepo: PowerSyncGroupRepository(
        db,
        client: null,
        isOnline: false,
        isLocalOnly: reposLocalOnly,
      ),
      participantRepo: PowerSyncParticipantRepository(
        db,
        client: null,
        isOnline: false,
        isLocalOnly: reposLocalOnly,
      ),
      expenseRepo: PowerSyncExpenseRepository(
        db,
        client: null,
        isOnline: false,
        isLocalOnly: reposLocalOnly,
      ),
      tagRepo: PowerSyncTagRepository(
        db,
        client: null,
        isOnline: false,
        isLocalOnly: reposLocalOnly,
      ),
      effectiveLocalOnly: effectiveLocalOnly,
    );
  }

  Future<BackupExportResult> exportMinimalJson({
    Set<String>? groupIds,
    BackupProgress? onProgress,
  }) async {
    onProgress?.call('export_building', 0.2);
    final data = await exportDataToJson(
      groupRepo: groupRepo,
      participantRepo: participantRepo,
      expenseRepo: expenseRepo,
      tagRepo: tagRepo,
      groupIdsFilter: groupIds,
    );
    onProgress?.call('export_building', 0.8);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    return BackupExportResult(
      bytes: Uint8List.fromList(utf8.encode(json)),
      fileName: 'hisab_export_${_stamp()}.json',
      mimeHint: 'application/json',
    );
  }

  Future<BackupExportResult> exportMinimalCsv({
    Set<String>? groupIds,
    BackupProgress? onProgress,
  }) async {
    onProgress?.call('export_building', 0.2);
    final data = await exportDataToJson(
      groupRepo: groupRepo,
      participantRepo: participantRepo,
      expenseRepo: expenseRepo,
      tagRepo: tagRepo,
      groupIdsFilter: groupIds,
    );
    final backup = parseBackupJson(jsonEncode(data)).data!;
    onProgress?.call('export_building', 0.7);
    final csv = buildExpensesCsv(
      groups: backup.groups,
      participants: backup.participants,
      expenses: backup.expenses,
      expenseTags: backup.expenseTags,
    );
    return BackupExportResult(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'hisab_expenses_${_stamp()}.csv',
      mimeHint: 'text/csv',
    );
  }

  Future<BackupExportResult> exportFullZip({
    Set<String>? groupIds,
    String locale = 'en',
    BackupProgress? onProgress,
  }) async {
    onProgress?.call('export_building', 0.1);
    final data = await exportDataToJson(
      groupRepo: groupRepo,
      participantRepo: participantRepo,
      expenseRepo: expenseRepo,
      tagRepo: tagRepo,
      groupIdsFilter: groupIds,
    );
    final backup = parseBackupJson(jsonEncode(data)).data!;
    onProgress?.call('export_receipts', 0.35);

    final localPaths = <String>[];
    for (final e in backup.expenses) {
      for (final path in e.effectiveImageUrls) {
        if (!isNetworkImagePath(path)) localPaths.add(path);
      }
    }
    final receiptMap = await collectLocalReceiptFiles(localPaths);
    final rewrittenExpenses = backup.expenses.map((e) {
      final newPaths = <String>[];
      for (final path in e.effectiveImageUrls) {
        if (isNetworkImagePath(path)) continue;
        final rel = receiptMap[path]?.relativePath;
        if (rel != null) newPaths.add(rel);
      }
      return Expense(
        id: e.id,
        groupId: e.groupId,
        payerParticipantId: e.payerParticipantId,
        amountCents: e.amountCents,
        currencyCode: e.currencyCode,
        exchangeRate: e.exchangeRate,
        baseAmountCents: e.baseAmountCents,
        title: e.title,
        description: e.description,
        date: e.date,
        splitType: e.splitType,
        splitShares: e.splitShares,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        transactionType: e.transactionType,
        toParticipantId: e.toParticipantId,
        tag: e.tag,
        lineItems: e.lineItems,
        imagePath: newPaths.isNotEmpty ? newPaths.first : null,
        imagePaths: newPaths.isNotEmpty ? newPaths : null,
      );
    }).toList();

    final rewritten = {
      ...data,
      'expenses': rewrittenExpenses.map(_expenseToExportMap).toList(),
    };

    onProgress?.call('export_building', 0.55);
    final backupJson = const JsonEncoder.withIndent('  ').convert(rewritten);
    final csv = buildExpensesCsv(
      groups: backup.groups,
      participants: backup.participants,
      expenses: rewrittenExpenses,
      expenseTags: backup.expenseTags,
    );
    final info = await PackageInfo.fromPlatform();
    final exportedAt = DateTime.now();
    final manifest = jsonEncode({
      'version': kBackupSchemaVersion,
      'exportKind': 'full',
      'exportedAt': exportedAt.toIso8601String(),
      'appVersion': info.version,
      'counts': {
        'groups': backup.groups.length,
        'participants': backup.participants.length,
        'expenses': rewrittenExpenses.length,
        'tags': backup.expenseTags.length,
        'receipts': receiptMap.length,
      },
    });
    final html = buildBackupHtmlReport(
      backupJson: rewritten,
      groups: backup.groups,
      expenses: rewrittenExpenses,
      exportedAt: exportedAt,
      locale: locale,
      expenseTags: backup.expenseTags,
    );
    onProgress?.call('export_building', 0.85);
    final bytes = encodeBackupZip(
      manifestJson: manifest,
      backupJson: backupJson,
      reportHtml: html,
      expensesCsv: csv,
      receipts: receiptMap.values.toList(),
    );
    return BackupExportResult(
      bytes: bytes,
      fileName: 'hisab_backup_${_stamp()}.zip',
      mimeHint: 'application/zip',
    );
  }

  BackupPackageParse parsePackageBytes(Uint8List bytes, {String? fileName}) {
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.csv')) {
      return const BackupPackageParse(
        errorMessageKey: 'backup_import_csv_not_supported',
      );
    }
    try {
      if (lower.endsWith('.zip') || _looksLikeZip(bytes)) {
        final decoded = decodeBackupZip(bytes);
        final parsed = parseBackupJson(decoded.backupJson);
        if (parsed.data == null) {
          return BackupPackageParse(errorMessageKey: parsed.errorMessageKey);
        }
        final warnings = [...parsed.warnings];
        if (decoded.receipts.isEmpty) {
          warnings.add('backup_warning_no_receipts');
        }
        return BackupPackageParse(
          preview: BackupImportPreview(
            data: parsed.data!,
            schemaVersion: parsed.schemaVersion ?? 1,
            warnings: warnings,
            receiptCount: decoded.receipts.length,
            fromZip: true,
            zipReceipts: decoded.receipts,
          ),
        );
      }
      final parsed = parseBackupJson(utf8.decode(bytes));
      if (parsed.data == null) {
        return BackupPackageParse(errorMessageKey: parsed.errorMessageKey);
      }
      final warnings = [
        ...parsed.warnings,
        'backup_warning_minimal_no_receipts',
      ];
      return BackupPackageParse(
        preview: BackupImportPreview(
          data: parsed.data!,
          schemaVersion: parsed.schemaVersion ?? 1,
          warnings: warnings,
          fromZip: false,
        ),
      );
    } on FormatException catch (_) {
      return const BackupPackageParse(
        errorMessageKey: 'backup_parse_invalid_format',
      );
    } catch (e, st) {
      Log.warning('parsePackageBytes failed', error: e, stackTrace: st);
      return const BackupPackageParse(errorMessageKey: 'backup_parse_failed');
    }
  }

  Future<BackupImportResult> importBackup({
    required BackupData data,
    required BackupImportMode mode,
    Map<String, Uint8List> zipReceipts = const {},
    BackupProgress? onProgress,
    required bool restoreArchivedAt,
  }) async {
    if (mode == BackupImportMode.replaceLocal) {
      if (!effectiveLocalOnly) {
        throw StateError('Replace import requires local-only mode');
      }
      onProgress?.call('import_wipe', 0.05);
      await wipeLocalDataTables(db);
    }

    final pendingBefore = await db.getAll('SELECT id FROM pending_writes');
    final pendingBeforeIds = pendingBefore
        .map((r) => r['id'] as String)
        .toSet();

    final failed = <String>[];
    var succeeded = 0;
    final total = data.groups.length;

    Future<BackupImportResult> run() async {
      for (var i = 0; i < data.groups.length; i++) {
        final g = data.groups[i];
        onProgress?.call('import_group', total == 0 ? 1.0 : (i / total));
        try {
          await _importOneGroup(
            g,
            data,
            zipReceipts: zipReceipts,
            restoreArchivedAt: restoreArchivedAt,
          );
          succeeded++;
        } catch (e, st) {
          Log.warning(
            'Import group failed: ${g.name}',
            error: e,
            stackTrace: st,
          );
          failed.add(g.name);
          // Fail-fast per plan: stop further groups after recording failure.
          break;
        }
      }
      return BackupImportResult(
        succeededGroups: succeeded,
        failedGroups: failed,
      );
    }

    try {
      if (effectiveLocalOnly) {
        return await run();
      }
      return await runWithSilentPendingWrites(run);
    } catch (e) {
      await _cleanupImportPendingWrites(pendingBeforeIds);
      rethrow;
    } finally {
      if (failed.isNotEmpty || succeeded == 0 && data.groups.isNotEmpty) {
        // On hard failure mid-way with enqueue, drop new silent rows.
        if (!effectiveLocalOnly && failed.isNotEmpty) {
          await _cleanupImportPendingWrites(pendingBeforeIds);
        }
      }
    }
  }

  Future<void> _cleanupImportPendingWrites(Set<String> keepIds) async {
    final rows = await db.getAll('SELECT id FROM pending_writes');
    for (final row in rows) {
      final id = row['id'] as String;
      if (!keepIds.contains(id)) {
        await db.execute('DELETE FROM pending_writes WHERE id = ?', [id]);
      }
    }
  }

  Future<void> _importOneGroup(
    Group g,
    BackupData data, {
    required Map<String, Uint8List> zipReceipts,
    required bool restoreArchivedAt,
  }) async {
    final newGroupId = await groupRepo.create(
      g.name,
      g.currencyCode,
      icon: g.icon,
      color: g.color,
      isPersonal: g.isPersonal,
      budgetAmountCents: g.budgetAmountCents,
      settlementMethod: g.settlementMethod,
      allowMemberAddExpense: g.allowMemberAddExpense,
      allowMemberChangeSettings: g.allowMemberChangeSettings,
      allowExpenseAsOtherParticipant: g.allowExpenseAsOtherParticipant,
      allowMemberSettleForOthers: g.allowMemberSettleForOthers,
    );

    final createdParticipants = await participantRepo.getByGroupId(newGroupId);
    createdParticipants.sort((a, b) => a.order.compareTo(b.order));
    final autoOwner = createdParticipants.isNotEmpty
        ? createdParticipants.first
        : null;

    final oldParticipants =
        data.participants.where((p) => p.groupId == g.id).toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final participantIds = <String, String>{};

    if (g.isPersonal) {
      final sole = oldParticipants.isNotEmpty ? oldParticipants.first : null;
      if (autoOwner != null && sole != null) {
        participantIds[sole.id] = autoOwner.id;
        await participantRepo.update(
          autoOwner.copyWith(
            name: sole.name,
            avatarId: sole.avatarId,
            leftAt: sole.leftAt,
          ),
        );
      }
    } else {
      Participant? backupOwner;
      for (final p in oldParticipants) {
        if (p.order == 0) {
          backupOwner = p;
          break;
        }
      }
      backupOwner ??= oldParticipants.isNotEmpty ? oldParticipants.first : null;

      if (autoOwner != null && backupOwner != null) {
        participantIds[backupOwner.id] = autoOwner.id;
        await participantRepo.update(
          autoOwner.copyWith(
            name: backupOwner.name,
            avatarId: backupOwner.avatarId,
            leftAt: backupOwner.leftAt,
          ),
        );
      }

      for (final p in oldParticipants) {
        if (participantIds.containsKey(p.id)) continue;
        final newId = await participantRepo.create(newGroupId, p.name, p.order);
        participantIds[p.id] = newId;
        if (p.leftAt != null || p.avatarId != null) {
          final created = await participantRepo.getById(newId);
          if (created != null) {
            await participantRepo.update(
              created.copyWith(leftAt: p.leftAt, avatarId: p.avatarId),
            );
          }
        }
      }
    }

    // Create tags before expenses so custom tag ids on expenses can be remapped.
    final tagIds = <String, String>{};
    for (final t in data.expenseTags.where((t) => t.groupId == g.id)) {
      final newTagId = await tagRepo.create(
        newGroupId,
        t.label,
        t.iconName,
        colorHex: t.colorHex,
      );
      tagIds[t.id] = newTagId;
    }

    final expenseIds = <String, String>{};
    final oldExpenses = data.expenses.where((e) => e.groupId == g.id).toList();
    for (final e in oldExpenses) {
      final newPayer = participantIds[e.payerParticipantId];
      if (newPayer == null) continue;
      final toId = e.toParticipantId != null
          ? participantIds[e.toParticipantId!]
          : null;
      final paths = e.effectiveImageUrls
          .where((p) => !isNetworkImagePath(p))
          .toList();
      final storedPaths = <String>[];
      for (final rel in paths) {
        final key = rel.startsWith('receipts/')
            ? rel
            : 'receipts/${rel.split('/').last}';
        final bytes = zipReceipts[key] ?? zipReceipts[rel];
        if (bytes == null) continue;
        try {
          final ext = rel.contains('.') ? '.${rel.split('.').last}' : '.jpg';
          final stored = await writeReceiptBytesToAppStorage(
            bytes,
            extension: ext,
          );
          storedPaths.add(stored);
        } catch (err) {
          Log.warning('Receipt restore skipped', error: err);
        }
      }

      final remappedTag = e.tag == null ? null : (tagIds[e.tag!] ?? e.tag);

      final expense = Expense(
        id: '',
        groupId: newGroupId,
        payerParticipantId: newPayer,
        amountCents: e.amountCents,
        currencyCode: e.currencyCode,
        exchangeRate: e.exchangeRate,
        baseAmountCents: e.baseAmountCents,
        title: e.title,
        description: e.description,
        date: e.date,
        splitType: e.splitType,
        splitShares: remapSplitShares(e.splitShares, participantIds),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
        transactionType: e.transactionType,
        toParticipantId: toId,
        tag: remappedTag,
        lineItems: e.lineItems,
        imagePath: storedPaths.isNotEmpty ? storedPaths.first : null,
        imagePaths: storedPaths.isNotEmpty ? storedPaths : null,
      );
      final newExpenseId = await expenseRepo.create(expense);
      expenseIds[e.id] = newExpenseId;
    }

    final created = await groupRepo.getById(newGroupId);
    if (created != null) {
      final treasurer = g.treasurerParticipantId != null
          ? participantIds[g.treasurerParticipantId!]
          : null;
      final snapshot = remapSettlementSnapshotJson(
        g.settlementSnapshotJson,
        participantIds,
        expenseIds,
      );
      await groupRepo.update(
        created.copyWith(
          settlementMethod: g.settlementMethod,
          treasurerParticipantId: treasurer,
          settlementFreezeAt: g.settlementFreezeAt,
          settlementSnapshotJson: snapshot,
          allowMemberAddExpense: g.allowMemberAddExpense,
          allowMemberChangeSettings: g.allowMemberChangeSettings,
          allowExpenseAsOtherParticipant: g.allowExpenseAsOtherParticipant,
          allowMemberSettleForOthers: g.allowMemberSettleForOthers,
          icon: g.icon,
          color: g.color,
          archivedAt: restoreArchivedAt ? g.archivedAt : null,
          isPersonal: g.isPersonal,
          budgetAmountCents: g.budgetAmountCents,
        ),
      );
    }

    if (data.localArchivedGroupIds.contains(g.id)) {
      await groupRepo.setLocalArchived(newGroupId);
    }
  }

  static bool _looksLikeZip(Uint8List bytes) =>
      bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b;

  static String _stamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  static Map<String, dynamic> _expenseToExportMap(Expense e) => {
    'id': e.id,
    'groupId': e.groupId,
    'payerParticipantId': e.payerParticipantId,
    'amountCents': e.amountCents,
    'currencyCode': e.currencyCode,
    'exchangeRate': e.exchangeRate,
    'baseAmountCents': e.baseAmountCents,
    'title': e.title,
    'description': e.description,
    'date': e.date.toIso8601String(),
    'splitType': e.splitType.name,
    'splitShares': e.splitShares,
    'createdAt': e.createdAt.toIso8601String(),
    'updatedAt': e.updatedAt.toIso8601String(),
    'transactionType': e.transactionType.name,
    'toParticipantId': e.toParticipantId,
    'tag': e.tag,
    'lineItems': e.lineItems?.map((l) => l.toJson()).toList(),
    'imagePath': e.imagePath,
    'imagePaths': e.imagePaths,
  };
}
