import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';
import '../../expenses/category_icons.dart';
import '../../expenses/widgets/tag_style_fields.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../providers/group_member_provider.dart';
import '../providers/groups_provider.dart';

/// Manage custom expense categories for a group (rename / re-icon / delete).
class GroupCategoriesPage extends ConsumerStatefulWidget {
  const GroupCategoriesPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupCategoriesPage> createState() =>
      _GroupCategoriesPageState();
}

class _GroupCategoriesPageState extends ConsumerState<GroupCategoriesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: RoutePaths.groupSettings(widget.groupId),
        currentPath: RoutePaths.groupCategories(widget.groupId),
      );
    });
  }

  bool _canEdit(Group? group, GroupRole? myRole) {
    if (group == null) return false;
    final localOnly = ref.read(effectiveLocalOnlyProvider);
    final isOwnerOrAdmin =
        localOnly || myRole == GroupRole.owner || myRole == GroupRole.admin;
    return isOwnerOrAdmin || group.allowMemberChangeSettings;
  }

  Future<void> _editTag(ExpenseTag tag) async {
    final existing =
        ref.read(tagsByGroupProvider(widget.groupId)).asData?.value ??
        const <ExpenseTag>[];
    final result = await showResponsiveSheet<(String, String, String)>(
      context: context,
      title: 'edit_tag'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => _EditTagSheet(
          sheetContext: ctx,
          initialLabel: tag.label,
          initialIconName: tag.iconName,
          initialColorHex: tag.colorHex ?? selectableTagColorHexes.first,
          existingTags: existing,
          excludingTagId: tag.id,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final (label, iconName, colorHex) = result;
    try {
      await ref
          .read(tagRepositoryProvider)
          .update(
            tag.copyWith(
              label: label,
              iconName: iconName,
              colorHex: colorHex,
              updatedAt: DateTime.now(),
            ),
          );
      if (mounted) {
        ref.invalidate(tagsByGroupProvider(widget.groupId));
        context.showSuccess('done'.tr());
      }
    } catch (_) {
      if (mounted) context.showError('tag_create_failed'.tr());
    }
  }

  Future<void> _deleteTag(ExpenseTag tag, int usageCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_tag'.tr()),
        content: Text('delete_tag_confirm'.tr(namedArgs: {'name': tag.label})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('delete_tag'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (usageCount > 0) {
        final expenses = await ref
            .read(expenseRepositoryProvider)
            .getByGroupId(widget.groupId);
        for (final e in expenses.where((e) => e.tag == tag.id)) {
          await ref
              .read(expenseRepositoryProvider)
              .update(e.copyWith(clearTag: true, updatedAt: DateTime.now()));
        }
      }
      await ref.read(tagRepositoryProvider).delete(tag.id);
      if (mounted) {
        ref.invalidate(tagsByGroupProvider(widget.groupId));
        ref.invalidate(expensesByGroupProvider(widget.groupId));
        context.showSuccess('done'.tr());
      }
    } catch (_) {
      if (mounted) context.showError('tag_create_failed'.tr());
    }
  }

  Future<void> _createTag() async {
    final existing =
        ref.read(tagsByGroupProvider(widget.groupId)).asData?.value ??
        const <ExpenseTag>[];
    final result = await showResponsiveSheet<(String, String, String)>(
      context: context,
      title: 'create_new_tag'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => _EditTagSheet(
          sheetContext: ctx,
          initialLabel: '',
          initialIconName: selectableCategoryIcons.keys.first,
          initialColorHex: selectableTagColorHexes.first,
          existingTags: existing,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final (label, iconName, colorHex) = result;
    try {
      await ref
          .read(tagRepositoryProvider)
          .create(widget.groupId, label, iconName, colorHex: colorHex);
      if (mounted) {
        ref.invalidate(tagsByGroupProvider(widget.groupId));
        context.showSuccess('done'.tr());
      }
    } catch (_) {
      if (mounted) context.showError('tag_create_failed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    final tagsAsync = ref.watch(tagsByGroupProvider(widget.groupId));
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final myRoleAsync = localOnly
        ? const AsyncValue<GroupRole?>.data(null)
        : ref.watch(myRoleInGroupProvider(widget.groupId));
    final settingsPath = RoutePaths.groupSettings(widget.groupId);
    final canPop = routerCanPop(context);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGo(context, settingsPath);
      },
      child: LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('manage_categories'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => popOrGo(context, settingsPath),
              ),
            ),
            floatingActionButton: groupAsync.maybeWhen(
              data: (group) {
                final myRole = myRoleAsync.asData?.value;
                if (!_canEdit(group, myRole)) return null;
                return FloatingActionButton.extended(
                  onPressed: _createTag,
                  icon: const Icon(Icons.add),
                  label: Text('create_new_tag'.tr()),
                );
              },
              orElse: () => null,
            ),
            body: groupAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: ErrorContentWidget(
                  titleKey: 'generic_error',
                  message: '$e',
                  details: '$e',
                ),
              ),
              data: (group) {
                final myRole = myRoleAsync.asData?.value;
                final canEdit = _canEdit(group, myRole);
                if (!canEdit) {
                  return Center(
                    child: ErrorContentWidget(
                      titleKey: 'generic_error',
                      message: 'tag_create_restricted'.tr(),
                      details: 'tag_create_restricted'.tr(),
                    ),
                  );
                }
                return ConstrainedContent(
                  child: tagsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (tags) {
                      final expenses =
                          expensesAsync.asData?.value ?? const <Expense>[];
                      final usage = <String, int>{};
                      for (final e in expenses) {
                        final t = e.tag;
                        if (t == null || t.isEmpty) continue;
                        usage[t] = (usage[t] ?? 0) + 1;
                      }
                      if (tags.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'manage_categories_subtitle'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        );
                      }
                      final sorted = [...tags]
                        ..sort(
                          (a, b) => a.label.toLowerCase().compareTo(
                            b.label.toLowerCase(),
                          ),
                        );
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: ThemeConfig.spacingS),
                        itemBuilder: (context, index) {
                          final tag = sorted[index];
                          final chrome = chromeForExpenseTag(
                            tag.id,
                            brightness: Theme.of(context).brightness,
                            surface: Theme.of(context).colorScheme.surface,
                            customTags: [tag],
                          );
                          final icon =
                              selectableCategoryIcons[tag.iconName] ??
                              Icons.label_outlined;
                          final count = usage[tag.id] ?? 0;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            leading: CircleAvatar(
                              backgroundColor: chrome.container,
                              child: Icon(icon, color: chrome.onContainer),
                            ),
                            title: UserText(tag.label),
                            subtitle: Text(
                              'tag_usage_count'.tr(
                                namedArgs: {'count': '$count'},
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editTag(tag);
                                } else if (value == 'delete') {
                                  _deleteTag(tag, count);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('edit_tag'.tr()),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('delete_tag'.tr()),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EditTagSheet extends StatefulWidget {
  const _EditTagSheet({
    required this.sheetContext,
    required this.initialLabel,
    required this.initialIconName,
    required this.initialColorHex,
    required this.existingTags,
    this.excludingTagId,
  });

  final BuildContext sheetContext;
  final String initialLabel;
  final String initialIconName;
  final String initialColorHex;
  final List<ExpenseTag> existingTags;
  final String? excludingTagId;

  @override
  State<_EditTagSheet> createState() => _EditTagSheetState();
}

class _EditTagSheetState extends State<_EditTagSheet> {
  late final TextEditingController _nameController;
  late String _selectedIconName;
  late String _selectedColorHex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialLabel);
    _selectedIconName = widget.initialIconName;
    _selectedColorHex = widget.initialColorHex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sheetContext;
    final isCreate = widget.initialLabel.isEmpty;
    return buildSheetShell(
      ctx,
      title: (isCreate ? 'create_new_tag' : 'edit_tag').tr(),
      showTitleInBody: !LayoutBreakpoints.isTabletOrWider(context),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'tag_name'.tr(),
              border: const OutlineInputBorder(),
              counterText: '',
            ),
            maxLength: FormValidators.expenseTagLabelMax,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          TagStyleFields(
            selectedIconName: _selectedIconName,
            selectedColorHex: _selectedColorHex,
            onIconSelected: (v) => setState(() => _selectedIconName = v),
            onColorSelected: (v) => setState(() => _selectedColorHex = v),
          ),
        ],
      ),
      actions: [
        if (!LayoutBreakpoints.isTabletOrWider(context))
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr()),
          ),
        FilledButton(
          onPressed: () {
            final label = _nameController.text.trim();
            if (FormValidators.expenseTagLabel(label) != null) return;
            final reserved = presetCategoryTags.map(
              (p) => 'category_${p.id}'.tr(),
            );
            if (expenseTagLabelExists(
              label,
              customTags: widget.existingTags,
              excludingTagId: widget.excludingTagId,
              extraReservedLabels: reserved,
            )) {
              ctx.showError(
                'tag_already_exists'.tr(namedArgs: {'name': label}),
              );
              return;
            }
            Navigator.of(
              ctx,
            ).pop((label, _selectedIconName, _selectedColorHex));
          },
          child: Text('done'.tr()),
        ),
      ],
    );
  }
}
