import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/services/migration_service.dart';

/// Progress UI while migrating local data to the cloud account.
class MigrationProgressSheet extends StatefulWidget {
  const MigrationProgressSheet({super.key, required this.migrationService});

  final MigrationService migrationService;

  @override
  State<MigrationProgressSheet> createState() => _MigrationProgressSheetState();
}

class _MigrationProgressSheetState extends State<MigrationProgressSheet> {
  int _completed = 0;
  int _total = 1;

  @override
  void initState() {
    super.initState();
    _runMigration();
  }

  Future<void> _runMigration() async {
    final result = await widget.migrationService.migrateLocalToOnline(
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _completed = completed;
            _total = total;
          });
        }
      },
    );
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _completed / _total : 0.0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!LayoutBreakpoints.isTabletOrWider(context))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'migration_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('migration_uploading'.tr()),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('$_completed / $_total'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
