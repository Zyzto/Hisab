import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/layout/constrained_content.dart';
import '../domain/scanner_pattern.dart';
import '../providers/scanner_providers.dart';

const _uuid = Uuid();

class ScannerPatternsPage extends ConsumerWidget {
  const ScannerPatternsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patternsAsync = ref.watch(scannerPatternsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_patterns_title'.tr()),
      ),
      body: ConstrainedContent(
        child: patternsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (patterns) => patterns.isEmpty
              ? _buildEmptyState(context)
              : _buildList(context, ref, patterns),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pattern,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'scanner_no_patterns'.tr(),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'scanner_no_patterns_subtitle'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ScannerPattern> patterns,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final pattern = patterns[index];
        return _PatternTile(
          pattern: pattern,
          onEdit: () => _openEditor(context, ref, pattern),
        );
      },
    );
  }

  void _openEditor(
    BuildContext context,
    WidgetRef ref,
    ScannerPattern? existing,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PatternEditorPage(existing: existing),
      ),
    );
  }
}

class _PatternTile extends ConsumerWidget {
  final ScannerPattern pattern;
  final VoidCallback onEdit;

  const _PatternTile({required this.pattern, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: pattern.isBuiltIn
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          pattern.isBuiltIn ? Icons.lock_outline : Icons.edit_note,
          color: pattern.isBuiltIn
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(pattern.name),
      subtitle: Text(
        '${pattern.senderMatch}  •  ${pattern.successCount} ${'scanner_matches'.tr()}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(
            value: pattern.enabled,
            onChanged: (v) {
              final updated = pattern.copyWith(enabled: v);
              ref
                  .read(scannerRepositoryProvider)
                  .upsertPattern(updated)
                  .then((_) => ref.invalidate(scannerPatternsProvider));
            },
          ),
          if (!pattern.isBuiltIn)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
            ),
        ],
      ),
      onLongPress: pattern.isBuiltIn
          ? null
          : () => _confirmDelete(context, ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('scanner_delete_pattern'.tr()),
        content: Text(pattern.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref
            .read(scannerRepositoryProvider)
            .deletePattern(pattern.id)
            .then((_) => ref.invalidate(scannerPatternsProvider));
      }
    });
  }
}

/// Editor page for creating or modifying a scanner pattern.
class _PatternEditorPage extends ConsumerStatefulWidget {
  final ScannerPattern? existing;

  const _PatternEditorPage({this.existing});

  @override
  ConsumerState<_PatternEditorPage> createState() =>
      _PatternEditorPageState();
}

class _PatternEditorPageState extends ConsumerState<_PatternEditorPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _senderCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _currencyCtrl;
  late TextEditingController _cardCtrl;
  late TextEditingController _merchantCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _dateFormatCtrl;
  late TextEditingController _testCtrl;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _senderCtrl = TextEditingController(text: e?.senderMatch ?? '');
    _amountCtrl = TextEditingController(text: e?.amountRegex ?? '');
    _currencyCtrl = TextEditingController(text: e?.currencyRegex ?? '');
    _cardCtrl = TextEditingController(text: e?.cardRegex ?? '');
    _merchantCtrl = TextEditingController(text: e?.merchantRegex ?? '');
    _dateCtrl = TextEditingController(text: e?.dateRegex ?? '');
    _dateFormatCtrl = TextEditingController(text: e?.dateFormat ?? '');
    _testCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _senderCtrl.dispose();
    _amountCtrl.dispose();
    _currencyCtrl.dispose();
    _cardCtrl.dispose();
    _merchantCtrl.dispose();
    _dateCtrl.dispose();
    _dateFormatCtrl.dispose();
    _testCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew
            ? 'scanner_new_pattern'.tr()
            : 'scanner_edit_pattern'.tr()),
      ),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_nameCtrl, 'scanner_pattern_name'.tr()),
            _field(_senderCtrl, 'scanner_pattern_sender'.tr(),
                hint: 'com.example.*'),
            _field(_amountCtrl, 'scanner_pattern_amount'.tr(),
                hint: r'(\d+\.\d{2})', required: true),
            _field(_currencyCtrl, 'scanner_pattern_currency'.tr(),
                hint: r'(SAR|USD)'),
            _field(_cardCtrl, 'scanner_pattern_card'.tr(),
                hint: r'\*(\d{4})'),
            _field(_merchantCtrl, 'scanner_pattern_merchant'.tr(),
                hint: r'at\s+(.+?)\.'),
            _field(_dateCtrl, 'scanner_pattern_date'.tr(),
                hint: r'(\d{2}/\d{2}/\d{4})'),
            _field(_dateFormatCtrl, 'scanner_pattern_date_format'.tr(),
                hint: 'MM/dd/yyyy'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text(
              'scanner_test_pattern'.tr(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _testCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'scanner_test_paste_notification'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _runTest,
              icon: const Icon(Icons.play_arrow),
              label: Text('scanner_test_run'.tr()),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _testResult!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text('scanner_save_pattern'.tr()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  void _runTest() {
    final text = _testCtrl.text.trim();
    if (text.isEmpty || _amountCtrl.text.trim().isEmpty) {
      setState(() => _testResult = 'Provide text and amount regex');
      return;
    }

    try {
      final pattern = _buildPattern();
      final result = _tryMatch(text, pattern);
      setState(() => _testResult = result);
    } catch (e) {
      setState(() => _testResult = 'Regex error: $e');
    }
  }

  String _tryMatch(String text, ScannerPattern pattern) {
    final buf = StringBuffer();
    final amountMatch = RegExp(pattern.amountRegex).firstMatch(text);
    buf.writeln(
      'Amount: ${amountMatch?.group(1) ?? amountMatch?.group(0) ?? "NOT FOUND"}',
    );

    if (pattern.currencyRegex != null && pattern.currencyRegex!.isNotEmpty) {
      final m = RegExp(pattern.currencyRegex!).firstMatch(text);
      buf.writeln('Currency: ${m?.group(1) ?? "NOT FOUND"}');
    }
    if (pattern.cardRegex != null && pattern.cardRegex!.isNotEmpty) {
      final m = RegExp(pattern.cardRegex!).firstMatch(text);
      buf.writeln('Card: ${m?.group(1) ?? "NOT FOUND"}');
    }
    if (pattern.merchantRegex != null && pattern.merchantRegex!.isNotEmpty) {
      final m = RegExp(pattern.merchantRegex!).firstMatch(text);
      buf.writeln('Merchant: ${m?.group(1) ?? "NOT FOUND"}');
    }
    if (pattern.dateRegex != null && pattern.dateRegex!.isNotEmpty) {
      final m = RegExp(pattern.dateRegex!).firstMatch(text);
      buf.writeln('Date: ${m?.group(0) ?? "NOT FOUND"}');
    }
    return buf.toString().trim();
  }

  ScannerPattern _buildPattern() {
    return ScannerPattern(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      senderMatch: _senderCtrl.text.trim(),
      amountRegex: _amountCtrl.text.trim(),
      currencyRegex: _currencyCtrl.text.trim().isEmpty
          ? null
          : _currencyCtrl.text.trim(),
      cardRegex:
          _cardCtrl.text.trim().isEmpty ? null : _cardCtrl.text.trim(),
      merchantRegex: _merchantCtrl.text.trim().isEmpty
          ? null
          : _merchantCtrl.text.trim(),
      dateRegex:
          _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
      dateFormat: _dateFormatCtrl.text.trim().isEmpty
          ? null
          : _dateFormatCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _amountCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('scanner_pattern_required_fields'.tr())),
      );
      return;
    }

    final pattern = _buildPattern();
    final nav = Navigator.of(context);
    ref
        .read(scannerRepositoryProvider)
        .upsertPattern(pattern)
        .then((_) {
      ref.invalidate(scannerPatternsProvider);
      nav.pop();
    });
  }
}
