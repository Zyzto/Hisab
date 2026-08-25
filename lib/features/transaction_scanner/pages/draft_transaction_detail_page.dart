import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/constrained_content.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/settings/providers/settings_framework_providers.dart';
import '../../../core/settings/settings_definitions.dart';
import '../../expenses/category_icons.dart';
import '../../groups/providers/groups_provider.dart';
import '../domain/draft_transaction.dart';
import '../domain/field_span.dart';
import '../providers/scanner_providers.dart';
import '../widgets/notification_annotator.dart';
import '../widgets/scanner_group_picker.dart';

class DraftTransactionDetailPage extends ConsumerStatefulWidget {
  final DraftTransaction draft;

  const DraftTransactionDetailPage({super.key, required this.draft});

  @override
  ConsumerState<DraftTransactionDetailPage> createState() =>
      _DraftTransactionDetailPageState();
}

class _DraftTransactionDetailPageState
    extends ConsumerState<DraftTransactionDetailPage> {
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late TextEditingController _placeController;
  late List<FieldSpan> _spans;
  late String _currencyCode;
  late bool _isIncome;
  late String? _groupId;
  late String? _category;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _isIncome = draft.amountCents < 0;
    _merchantController = TextEditingController(text: draft.merchantName ?? '');
    _placeController = TextEditingController(text: draft.placeName ?? '');
    _amountController = TextEditingController(
      text: (draft.amountCents.abs() / 100).toStringAsFixed(2),
    );
    _currencyCode = draft.currencyCode;
    _spans = List.of(draft.fieldSpans);
    _groupId = draft.targetGroupId;
    _category = draft.merchantCategory;
    final settings = ref.read(hisabSettingsProvidersProvider);
    final fallback = settings?.controller.get(scannerDefaultGroupIdSettingDef);
    if (fallback is String && fallback.isNotEmpty) {
      _groupId ??= fallback;
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  void _applySpans(List<FieldSpan> spans) {
    final values = valuesFromSpans(widget.draft.rawNotificationText, spans);
    setState(() {
      _spans = spans;
      if (values.merchant != null) _merchantController.text = values.merchant!;
      if (values.place != null) _placeController.text = values.place!;
      if (values.amountCents != null) {
        _amountController.text = (values.amountCents! / 100).toStringAsFixed(2);
      }
      if (values.currency != null) _currencyCode = values.currency!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = widget.draft;
    final groups = ref.watch(groupsProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_draft_detail'.tr()),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(scannerControllerProvider).dismissDraft(draft.id);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'scanner_dismiss'.tr(),
          ),
        ],
      ),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NotificationAnnotator(
              title: draft.senderTitle ?? draft.senderPackage,
              body: draft.rawNotificationText,
              spans: _spans,
              onSpansChanged: _applySpans,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: 'scanner_merchant'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _placeController,
              decoration: InputDecoration(
                labelText: 'scanner_place'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'scanner_amount'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(label: Text(_currencyCode)),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(
                    _isIncome ? 'scanner_income'.tr() : 'scanner_expense'.tr(),
                  ),
                  selected: _isIncome,
                  onSelected: (v) => setState(() => _isIncome = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'scanner_category'.tr(),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                FilterChip(
                  label: Text('scanner_no_category'.tr()),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...presetCategoryTags.map((t) {
                  return FilterChip(
                    avatar: Icon(t.icon, size: 16),
                    label: Text('category_${t.id}'.tr()),
                    selected: _category == t.id,
                    onSelected: (_) => setState(() => _category = t.id),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'scanner_default_group'.tr(),
              style: theme.textTheme.labelLarge,
            ),
            ScannerGroupPicker(
              groups: groups,
              selectedId: _groupId,
              onSelected: (id) => setState(() => _groupId = id),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _confirm(context),
            icon: const Icon(Icons.check),
            label: Text('scanner_confirm_add'.tr()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final editedMerchant = _merchantController.text.trim();
    final editedAmount = double.tryParse(_amountController.text.trim());
    int? editedCents;
    if (editedAmount != null) {
      final absCents = (editedAmount * 100).round();
      editedCents = _isIncome ? -absCents : absCents;
    }

    final ok = await ref
        .read(scannerControllerProvider)
        .confirmDraft(
          widget.draft.id,
          targetGroupId: _groupId,
          overrideMerchant: editedMerchant.isNotEmpty ? editedMerchant : null,
          overrideAmountCents: editedCents,
          overridePlace: _placeController.text.trim().isEmpty
              ? null
              : _placeController.text.trim(),
          overrideCategory: _category,
        );
    if (!context.mounted) return;
    if (!ok) {
      context.showToast('scanner_confirm_failed'.tr());
      return;
    }
    Navigator.pop(context);
  }
}
