import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/toast.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';
import '../category_icons.dart';
import '../constants/expense_form_constants.dart';
import 'tag_style_fields.dart';

/// Content for the create-custom-tag sheet used by the expense form.
class CreateTagSheetContent extends StatefulWidget {
  const CreateTagSheetContent({
    super.key,
    required this.sheetContext,
    required this.groupId,
    required this.ref,
  });

  final BuildContext sheetContext;
  final String groupId;
  final WidgetRef ref;

  @override
  State<CreateTagSheetContent> createState() => _CreateTagSheetContentState();
}

class _CreateTagSheetContentState extends State<CreateTagSheetContent> {
  late final TextEditingController _nameController;
  late String _selectedIconName;
  late String _selectedColorHex;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _selectedIconName = selectableExpenseIcons.keys.first;
    _selectedColorHex = selectableTagColorHexes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final ctx = widget.sheetContext;
    final label = _nameController.text.trim();
    final error = FormValidators.expenseTagLabel(label);
    if (error != null) {
      setState(() => _nameError = error);
      return;
    }
    setState(() => _nameError = null);
    final existing =
        widget.ref.read(tagsByGroupProvider(widget.groupId)).asData?.value ??
        const <ExpenseTag>[];
    final reserved = presetCategoryTags.map((p) => 'category_${p.id}'.tr());
    if (expenseTagLabelExists(
      label,
      customTags: existing,
      extraReservedLabels: reserved,
    )) {
      if (ctx.mounted) {
        ctx.showError('tag_already_exists'.tr(namedArgs: {'name': label}));
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await widget.ref
          .read(tagRepositoryProvider)
          .create(
            widget.groupId,
            label,
            _selectedIconName,
            colorHex: _selectedColorHex,
          );
      if (!ctx.mounted) return;
      final tag = ExpenseTag(
        id: id,
        groupId: widget.groupId,
        label: label,
        iconName: _selectedIconName,
        colorHex: _selectedColorHex,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      if (ctx.mounted) Navigator.of(ctx).pop(tag);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      if (ctx.mounted) {
        ctx.showError('tag_create_failed'.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sheetContext;
    return TagEditorSheetShell(
      title: 'create_new_tag'.tr(),
      nameField: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'tag_name'.tr(),
          border: const OutlineInputBorder(),
          counterText: '',
          errorText: _nameError,
        ),
        maxLength: FormValidators.expenseTagLabelMax,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _nameError = null),
        onSubmitted: (_) => _submit(),
      ),
      styleFields: TagStyleFields(
        showPreview: false,
        selectedIconName: _selectedIconName,
        selectedColorHex: _selectedColorHex,
        onIconSelected: (v) => setState(() => _selectedIconName = v),
        onColorSelected: (v) => setState(() => _selectedColorHex = v),
      ),
      preview: TagPreviewChip(
        label: _nameController.text,
        iconName: _selectedIconName,
        colorHex: _selectedColorHex,
      ),
      actions: [
        if (!LayoutBreakpoints.isTabletOrWider(context))
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr()),
          ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text('done'.tr()),
        ),
      ],
    );
  }
}
