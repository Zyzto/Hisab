import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/repository/repository_providers.dart';
import '../../core/widgets/sheet_helpers.dart';
import '../../core/widgets/toast.dart';
import 'backup_service.dart';
import 'backup_types.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'package:hisab/core/settings/settings_definitions.dart';

Future<void> runBackupExportFlow(BuildContext context, WidgetRef ref) async {
  final kind = await showOptionPickerSheet<BackupExportKind>(
    context,
    title: 'export_data'.tr(),
    centerInFullViewport: false,
    options: [
      SheetPickerOption(
        value: BackupExportKind.minimalJson,
        label: 'export_minimal_json'.tr(),
        subtitle: 'export_minimal_json_subtitle'.tr(),
      ),
      SheetPickerOption(
        value: BackupExportKind.minimalCsv,
        label: 'export_minimal_csv'.tr(),
        subtitle: 'export_minimal_csv_subtitle'.tr(),
      ),
      SheetPickerOption(
        value: BackupExportKind.fullZip,
        label: 'export_full_zip'.tr(),
        subtitle: 'export_full_zip_subtitle'.tr(),
      ),
    ],
  );
  if (kind == null || !context.mounted) return;

  final service = BackupService(
    db: ref.read(powerSyncDatabaseProvider),
    groupRepo: ref.read(groupRepositoryProvider),
    participantRepo: ref.read(participantRepositoryProvider),
    expenseRepo: ref.read(expenseRepositoryProvider),
    tagRepo: ref.read(tagRepositoryProvider),
    effectiveLocalOnly: ref.read(effectiveLocalOnlyProvider),
  );

  try {
    late final BackupExportResult exported;
    switch (kind) {
      case BackupExportKind.minimalJson:
        exported = await service.exportMinimalJson();
        break;
      case BackupExportKind.minimalCsv:
        exported = await service.exportMinimalCsv();
        break;
      case BackupExportKind.fullZip:
        exported = await service.exportFullZip(
          locale: context.locale.languageCode,
        );
        break;
    }
    if (!context.mounted) return;
    final ext = kind == BackupExportKind.fullZip
        ? 'zip'
        : kind == BackupExportKind.minimalCsv
        ? 'csv'
        : 'json';
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'export_data'.tr(),
      fileName: exported.fileName,
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: exported.bytes,
    );
    if (!context.mounted) return;
    if (result != null && result.isNotEmpty) {
      Log.info('Backup exported to $result');
      context.showSuccess('export_success'.tr());
    } else {
      context.showToast('export_cancelled'.tr());
    }
  } catch (e, st) {
    Log.warning('Backup export failed', error: e, stackTrace: st);
    if (context.mounted) context.showError('export_failed'.tr());
  }
}

Future<void> runBackupImportFlow(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      context.showError('import_failed'.tr());
      return;
    }

    final localOnly = ref.read(effectiveLocalOnlyProvider);
    final service = BackupService.forImport(
      db: ref.read(powerSyncDatabaseProvider),
      effectiveLocalOnly: localOnly,
    );
    final parsed = service.parsePackageBytes(
      Uint8List.fromList(bytes),
      fileName: file.name,
    );
    if (parsed.preview == null) {
      if (context.mounted) {
        context.showError(
          parsed.errorMessageKey?.tr() ?? 'import_invalid_file'.tr(),
        );
      }
      return;
    }
    final preview = parsed.preview!;
    final existingGroups = await ref.read(groupRepositoryProvider).getAll();
    final hasPersonal = existingGroups.any((g) => g.isPersonal);
    final importingPersonal = preview.data.groups.any((g) => g.isPersonal);
    final warnings = [...preview.warnings];
    if (hasPersonal && importingPersonal) {
      warnings.add('backup_warning_multi_personal');
    }
    if (!localOnly) {
      warnings.add('backup_warning_archive_online');
    }

    if (!context.mounted) return;
    final mode = await showOptionPickerSheet<BackupImportMode>(
      context,
      title: 'import_preview_title'.tr(),
      centerInFullViewport: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'import_preview_counts'.tr(
              namedArgs: {
                'groups': '${preview.data.groups.length}',
                'expenses': '${preview.data.expenses.length}',
                'participants': '${preview.data.participants.length}',
                'version': '${preview.schemaVersion}',
              },
            ),
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...warnings.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${w.tr()}'),
              ),
            ),
          ],
        ],
      ),
      options: [
        SheetPickerOption(
          value: BackupImportMode.addCopies,
          label: 'import_mode_add'.tr(),
          subtitle: 'import_mode_add_subtitle'.tr(),
        ),
        SheetPickerOption(
          value: BackupImportMode.replaceLocal,
          label: 'import_mode_replace'.tr(),
          subtitle: localOnly
              ? 'import_mode_replace_subtitle'.tr()
              : 'import_mode_replace_requires_local'.tr(),
          enabled: localOnly,
        ),
      ],
    );
    if (mode == null || !context.mounted) return;

    final confirmKey = mode == BackupImportMode.replaceLocal
        ? 'import_confirm_replace'
        : 'import_confirm_add';
    final confirmed = await showConfirmSheet(
      context,
      title: 'import_data'.tr(),
      content: confirmKey.tr(),
      confirmLabel: 'import_data'.tr(),
      centerInFullViewport: false,
    );
    if (confirmed != true || !context.mounted) return;

    final sync = ref.read(dataSyncServiceProvider.notifier);
    sync.pause();
    try {
      final result = await service.importBackup(
        data: preview.data,
        mode: mode,
        zipReceipts: preview.zipReceipts,
        restoreArchivedAt: localOnly,
      );
      if (mode == BackupImportMode.replaceLocal && context.mounted) {
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          await ref
              .read(settings.provider(homeListCustomOrderSettingDef).notifier)
              .set('');
          await ref
              .read(settings.provider(homeListPinnedIdsSettingDef).notifier)
              .set('');
        }
      }
      if (!context.mounted) return;
      if (result.hasFailures) {
        context.showError(
          'import_partial_failed'.tr(
            namedArgs: {
              'ok': '${result.succeededGroups}',
              'fail': result.failedGroups.join(', '),
            },
          ),
        );
      } else {
        context.showSuccess('import_success'.tr());
      }

      if (!localOnly && result.succeededGroups > 0 && context.mounted) {
        final syncNow = await showConfirmSheet(
          context,
          title: 'import_sync_now_title'.tr(),
          content: 'import_sync_now_body'.tr(),
          confirmLabel: 'import_sync_now'.tr(),
          centerInFullViewport: false,
        );
        if (syncNow == true) {
          await sync.syncNow();
        }
      }
    } finally {
      sync.resume();
    }
  } catch (e, st) {
    Log.warning('Backup import failed', error: e, stackTrace: st);
    try {
      ref.read(dataSyncServiceProvider.notifier).resume();
    } catch (e) {
      Log.debug('Resume sync after import failure failed', error: e);
    }
    if (context.mounted) context.showError('import_failed'.tr());
  }
}
