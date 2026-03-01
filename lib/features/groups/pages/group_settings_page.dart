import 'dart:async';

import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/groups_provider.dart';
import '../providers/group_member_provider.dart';
import '../providers/group_invite_provider.dart';
import '../widgets/create_invite_sheet.dart';
import '../widgets/group_color_picker.dart';
import '../utils/group_icon_utils.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/toast.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/settings_framework_providers.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupSettingsPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  bool _saving = false;

  /// Runs [fn] with _saving true; sets _saving false in finally when mounted.
  Future<void> _withSaving(Future<void> Function() fn) async {
    setState(() => _saving = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    final participantsAsync = ref.watch(
      activeParticipantsByGroupProvider(widget.groupId),
    );
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final myRoleAsync = localOnly
        ? const AsyncValue.data(null)
        : ref.watch(myRoleInGroupProvider(widget.groupId));
    final localArchivedIdsAsync = ref.watch(locallyArchivedGroupIdsProvider);

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LayoutBuilder(
          builder: (context, layoutConstraints) {
            return Scaffold(
              appBar: ContentAlignedAppBar(
                contentAreaWidth: layoutConstraints.maxWidth,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                title: Text(
                  (group.isPersonal ? 'list_settings' : 'group_settings').tr(),
                ),
              ),
              body: ConstrainedContent(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: ThemeConfig.spacingM,
                vertical: ThemeConfig.spacingS,
              ),
              children: [
                // ── Group Profile Header ──
                _buildProfileHeader(context, group),
                const SizedBox(height: ThemeConfig.spacingL),

                // ── Currency Section ──
                _buildSection(
                  context,
                  title: (group.isPersonal ? 'currency' : 'group_currency')
                      .tr(),
                  children: [
                    _buildCurrencyRow(context, group, expensesAsync, ref),
                  ],
                ),
                const SizedBox(height: ThemeConfig.spacingL),

                // ── My budget (personal only) ──
                if (group.isPersonal) ...[
                  _buildSection(
                    context,
                    title: 'my_budget'.tr(),
                    children: [_buildMyBudgetRow(context, group, ref)],
                  ),
                  const SizedBox(height: ThemeConfig.spacingL),
                ],

                // ── Settlement Section (group only) ──
                if (!group.isPersonal)
                  _buildSection(
                    context,
                    title: 'settlement_method'.tr(),
                    children: [
                      _buildSettlementMethodContent(context, group, ref),
                      if (group.settlementMethod == SettlementMethod.treasurer)
                        _buildTreasurerContent(
                          context,
                          group,
                          participantsAsync,
                          ref,
                        ),
                      _buildFreezeContent(
                        context,
                        group,
                        participantsAsync,
                        expensesAsync,
                        ref,
                      ),
                    ],
                  ),
                if (!group.isPersonal)
                  const SizedBox(height: ThemeConfig.spacingL),

                // ── Permissions Section (online only, group only) ──
                if (!localOnly && !group.isPersonal)
                  myRoleAsync.when(
                    data: (myRole) {
                      final isOwnerOrAdmin =
                          myRole == GroupRole.owner ||
                          myRole == GroupRole.admin;
                      if (!isOwnerOrAdmin || group.ownerId == null) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: ThemeConfig.spacingL),
                          _buildSection(
                            context,
                            title: 'group_permissions'.tr(),
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('allow_add_expense'.tr()),
                                value: group.allowMemberAddExpense,
                                onChanged: _saving
                                    ? null
                                    : (v) => _onPermissionChanged(
                                        ref,
                                        group,
                                        allowMemberAddExpense: v,
                                      ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('allow_change_settings'.tr()),
                                value: group.allowMemberChangeSettings,
                                onChanged: _saving
                                    ? null
                                    : (v) => _onPermissionChanged(
                                        ref,
                                        group,
                                        allowMemberChangeSettings: v,
                                      ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('allow_expense_as_other'.tr()),
                                value: group.allowExpenseAsOtherParticipant,
                                onChanged: _saving
                                    ? null
                                    : (v) => _onPermissionChanged(
                                        ref,
                                        group,
                                        allowExpenseAsOtherParticipant: v,
                                      ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('allow_settle_for_others'.tr()),
                                value: group.allowMemberSettleForOthers,
                                onChanged: _saving
                                    ? null
                                    : (v) => _onPermissionChanged(
                                        ref,
                                        group,
                                        allowMemberSettleForOthers: v,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                // ── Invite Section (online only, owner/admin, group only) ──
                if (!localOnly && !group.isPersonal)
                  myRoleAsync.when(
                    data: (myRole) {
                      final isOwnerOrAdmin =
                          myRole == GroupRole.owner ||
                          myRole == GroupRole.admin;
                      if (!isOwnerOrAdmin) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: ThemeConfig.spacingL),
                          _buildInviteSection(context, ref),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                // ── Danger Zone ──
                const SizedBox(height: ThemeConfig.spacingXL),
                localArchivedIdsAsync.when(
                  data: (ids) => _buildDangerZone(
                    context,
                    group,
                    localOnly,
                    myRoleAsync,
                    participantsAsync,
                    ref,
                    isLocallyArchived: ids.contains(widget.groupId),
                  ),
                  loading: () => _buildDangerZone(
                    context,
                    group,
                    localOnly,
                    myRoleAsync,
                    participantsAsync,
                    ref,
                    isLocallyArchived: false,
                  ),
                  error: (_, _) => _buildDangerZone(
                    context,
                    group,
                    localOnly,
                    myRoleAsync,
                    participantsAsync,
                    ref,
                    isLocallyArchived: false,
                  ),
                ),
                const SizedBox(height: ThemeConfig.spacingXL),
              ],
            ),
          ),
        );
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('list_settings'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(
          child: ErrorContentWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(futureGroupProvider(widget.groupId)),
          ),
        ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Profile Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileHeader(BuildContext context, Group group) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avatarColor = group.color != null
        ? Color(group.color!)
        : colorScheme.primary;
    final avatarFg = group.color != null
        ? ThemeConfig.foregroundOnBackground(avatarColor)
        : colorScheme.onPrimary;
    final iconData = groupIconFromKey(group.icon);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConfig.radiusXL),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ThemeConfig.spacingM,
          vertical: ThemeConfig.spacingM,
        ),
        child: Row(
          children: [
            // Avatar – tap to change icon/color
            GestureDetector(
              onTap: () => _showIconColorPicker(context, group),
              child: Stack(
                alignment: AlignmentDirectional.bottomEnd,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: avatarColor,
                    child: iconData != null
                        ? Icon(iconData, size: 30, color: avatarFg)
                        : Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: avatarFg,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ThemeConfig.spacingM),
            // Name + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name – tap to edit
                  GestureDetector(
                    onTap: () => _showEditNameDialog(context, group),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: ThemeConfig.spacingXS),
                        Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ThemeConfig.spacingXS),
                  // Created date
                  Text(
                    'created_on'.tr(
                      namedArgs: {
                        'date': DateFormat.yMMMd().format(group.createdAt),
                      },
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section Builder
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    Color? titleColor,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        const Divider(height: 1),
        const SizedBox(height: ThemeConfig.spacingM),
        ...children,
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // My budget (personal only)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMyBudgetRow(BuildContext context, Group group, WidgetRef ref) {
    final theme = Theme.of(context);
    final currencyCode = group.currencyCode;
    final budgetCents = group.budgetAmountCents;
    final display = budgetCents != null && budgetCents > 0
        ? CurrencyFormatter.formatCents(budgetCents, currencyCode)
        : '—';

    return InkWell(
      onTap: _saving ? null : () => _showMyBudgetDialog(context, group, ref),
      borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
        ),
        child: Row(
          children: [
            Expanded(child: Text(display, style: theme.textTheme.bodyLarge)),
            Icon(
              Icons.edit_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyBudgetDialog(
    BuildContext context,
    Group group,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final budgetCents = group.budgetAmountCents;
    if (budgetCents != null && budgetCents > 0) {
      final currency = CurrencyHelpers.fromCode(group.currencyCode);
      final decimals = currency?.decimalDigits ?? 2;
      final divisor = decimals == 0 ? 1.0 : (decimals == 1 ? 10.0 : 100.0);
      controller.text = (budgetCents / divisor).toStringAsFixed(decimals);
    }
    final hint =
        CurrencyHelpers.fromCode(group.currencyCode)?.symbol ??
        group.currencyCode;
    final result = await showResponsiveSheet<String?>(
      context: context,
      title: 'my_budget'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => buildSheetShell(
          ctx,
          title: 'my_budget'.tr(),
          showTitleInBody: !LayoutBreakpoints.isTabletOrWider(context),
          body: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'budget_amount'.tr(),
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text('clear'.tr()),
            ),
            if (!LayoutBreakpoints.isTabletOrWider(context))
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('cancel'.tr()),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text('done'.tr()),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;

    int? newBudgetCents;
    if (result.isNotEmpty) {
      final value = double.tryParse(result.replaceAll(',', '.'));
      if (value != null && value >= 0) {
        final currency = CurrencyHelpers.fromCode(group.currencyCode);
        final decimals = currency?.decimalDigits ?? 2;
        final divisor = decimals == 0 ? 1 : (decimals == 1 ? 10 : 100);
        newBudgetCents = (value * divisor).round();
      }
    }

    if (newBudgetCents == group.budgetAmountCents) return;

    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              newBudgetCents == null
                  ? group.copyWith(
                      clearBudgetAmountCents: true,
                      updatedAt: DateTime.now(),
                    )
                  : group.copyWith(
                      budgetAmountCents: newBudgetCents,
                      updatedAt: DateTime.now(),
                    ),
            );
        ref.invalidate(futureGroupProvider(widget.groupId));
        if (context.mounted) {
          context.showSuccess('budget_updated'.tr());
        }
      });
    } catch (e, st) {
      Log.warning('Budget update failed', error: e, stackTrace: st);
      if (context.mounted) context.showError('generic_error'.tr());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Currency
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCurrencyRow(
    BuildContext context,
    Group group,
    AsyncValue<List<Expense>> expensesAsync,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final currency = CurrencyHelpers.fromCode(group.currencyCode);

    return InkWell(
      onTap: _saving ? null : () => _onCurrencyTap(group, expensesAsync, ref),
      borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
        ),
        child: Row(
          children: [
            if (currency != null) ...[
              Text(
                CurrencyUtils.currencyToEmoji(currency),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  CurrencyHelpers.displayLabel(currency),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ] else ...[
              Expanded(
                child: Text(
                  group.currencyCode,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCurrencyTap(
    Group group,
    AsyncValue<List<Expense>> expensesAsync,
    WidgetRef ref,
  ) async {
    final stored = ref.read(favoriteCurrenciesProvider);
    final favorites = CurrencyHelpers.getEffectiveFavorites(stored);
    CurrencyHelpers.showPicker(
      context: context,
      favorite: favorites,
      centerInFullViewport: true,
      onSelect: (Currency currency) async {
        if (currency.code == group.currencyCode) return;
        if (!mounted) return;

        // Warn if expenses exist
        final expenses = expensesAsync.value;
        if (expenses != null && expenses.isNotEmpty) {
          final pageContext = context;
          final ok = await showConfirmSheet(
            pageContext,
            title: 'change_currency'.tr(),
            content: 'currency_change_warning'.tr(),
            confirmLabel: 'change_currency'.tr(),
            centerInFullViewport: true,
          );
          if (ok != true || !mounted) return;
        }

        try {
          await _withSaving(() async {
            await ref
                .read(groupRepositoryProvider)
                .update(
                  group.copyWith(
                    currencyCode: currency.code,
                    updatedAt: DateTime.now(),
                  ),
                );
            Log.info(
              'Currency changed: groupId=${widget.groupId} currency=${currency.code}',
            );
            ref.invalidate(futureGroupProvider(widget.groupId));
            if (mounted) context.showSuccess('group_currency_updated'.tr());
          });
        } catch (e, st) {
          Log.warning('Currency change failed', error: e, stackTrace: st);
          if (mounted) context.showError('generic_error'.tr());
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Settlement Method
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSettlementMethodContent(
    BuildContext context,
    Group group,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: _saving
          ? null
          : () => _showSettlementMethodPicker(context, group, ref),
      borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _methodLabel(group.settlementMethod),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _methodDescription(group.settlementMethod),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettlementMethodPicker(
    BuildContext context,
    Group group,
    WidgetRef ref,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chosen = await showResponsiveSheet<SettlementMethod>(
      context: context,
      title: 'settlement_method'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      sheetShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Builder(
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(ctx).padding.bottom + ThemeConfig.spacingM,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!LayoutBreakpoints.isTabletOrWider(context))
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: ThemeConfig.spacingM,
                      ),
                      child: Text(
                        'settlement_method'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ...SettlementMethod.values.map((method) {
                    final isSelected = method == group.settlementMethod;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        _methodLabel(method),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                      ),
                      subtitle: Text(
                        _methodDescription(method),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, method),
                    );
                  }),
                  const SizedBox(height: ThemeConfig.spacingM),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (chosen != null && chosen != group.settlementMethod) {
      _onMethodChanged(ref, group, chosen);
    }
  }

  Widget _buildTreasurerContent(
    BuildContext context,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    return participantsAsync.when(
      data: (participants) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: ThemeConfig.spacingS),
            Text(
              'select_treasurer'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: ThemeConfig.spacingS),
            DropdownButtonFormField<String>(
              initialValue:
                  group.treasurerParticipantId ??
                  (participants.isNotEmpty ? participants.first.id : null),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThemeConfig.radiusXL),
                ),
              ),
              items: participants
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => _onTreasurerChanged(ref, group, v),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, st) {
        Log.warning('Group settings load error', error: e, stackTrace: st);
        return const ErrorContentWidget(titleKey: 'generic_error');
      },
    );
  }

  Widget _buildFreezeContent(
    BuildContext context,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    AsyncValue<List<Expense>> expensesAsync,
    WidgetRef ref,
  ) {
    final isFrozen = group.isSettlementFrozen;

    final subtitle = isFrozen
        ? 'settlement_frozen_since'.tr().replaceAll(
            '{date}',
            group.settlementFreezeAt != null
                ? DateFormat.yMMMd().format(group.settlementFreezeAt!)
                : '',
          )
        : 'settlement_freeze_description'.tr();

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('settlement_freeze'.tr()),
      subtitle: Text(subtitle),
      value: isFrozen,
      onChanged: _saving
          ? null
          : (v) {
              if (v) {
                _onFreeze(ref, group, participantsAsync, expensesAsync);
              } else {
                _onUnfreeze(ref);
              }
            },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Danger Zone
  // ═══════════════════════════════════════════════════════════════════════════
  // Invite section – inline preview + manage button
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInviteSection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final invitesAsync = ref.watch(invitesByGroupProvider(widget.groupId));

    return _buildSection(
      context,
      title: 'invite_links'.tr(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'create_invite'.tr(),
            onPressed: () =>
                showCreateInviteSheet(context, ref, widget.groupId),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
      children: [
        invitesAsync.when(
          data: (invites) {
            if (invites.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: ThemeConfig.spacingS,
                ),
                child: Text(
                  'invite_empty'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            // Show up to 3 most recent active invites
            final sorted = List.of(invites)
              ..sort((a, b) {
                final aActive = a.status == InviteStatus.active ? 0 : 1;
                final bActive = b.status == InviteStatus.active ? 0 : 1;
                if (aActive != bActive) return aActive.compareTo(bActive);
                return b.createdAt.compareTo(a.createdAt);
              });
            final preview = sorted.take(3).toList();

            return Column(
              children: [
                ...preview.map((invite) => _InvitePreviewTile(invite: invite)),
                if (invites.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: ThemeConfig.spacingXS),
                    child: Text(
                      'invite_and_more'.tr(args: ['${invites.length - 3}']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                context.push(RoutePaths.groupInvites(widget.groupId)),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text('invite_manage_all'.tr()),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDangerZone(
    BuildContext context,
    Group group,
    bool localOnly,
    AsyncValue<GroupRole?> myRoleAsync,
    AsyncValue<List<Participant>> participantsAsync,
    WidgetRef ref, {
    required bool isLocallyArchived,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorColor = colorScheme.error;

    final List<Widget> actions = [];

    if (group.isPersonal) {
      // Personal: Archive (if online), Delete, Share as group only
      if (!localOnly) {
        myRoleAsync.whenData((myRole) {
          if (myRole == GroupRole.owner) {
            if (group.isArchived) {
              actions.add(
                _dangerButton(
                  icon: Icons.unarchive_outlined,
                  label: 'unarchive_list'.tr(),
                  color: errorColor,
                  onTap: _saving
                      ? null
                      : () => _showUnarchiveGroup(context, ref),
                ),
              );
            } else {
              actions.add(
                _dangerButton(
                  icon: Icons.archive_outlined,
                  label: 'archive_list'.tr(),
                  color: errorColor,
                  onTap: _saving ? null : () => _showArchiveGroup(context, ref),
                ),
              );
            }
          }
        });
      }
      actions.add(
        _dangerButton(
          icon: Icons.delete_outline,
          label: 'delete_list'.tr(),
          color: errorColor,
          onTap: _saving ? null : () => _showDeleteGroup(context, ref),
        ),
      );
      actions.add(
        _dangerButton(
          icon: Icons.share_outlined,
          label: 'share_as_group'.tr(),
          color: errorColor,
          onTap: _saving ? null : () => _showShareAsGroup(context, group, ref),
        ),
      );
    } else {
      // Group: existing logic, plus "Use as personal" when member count == 1
      final participantCount = participantsAsync.maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
      if (participantCount == 1) {
        actions.add(
          _dangerButton(
            icon: Icons.person_outline,
            label: 'use_as_personal'.tr(),
            color: errorColor,
            onTap: _saving
                ? null
                : () => _showUseAsPersonal(context, group, ref),
          ),
        );
      }
      if (localOnly) {
        actions.add(
          _dangerButton(
            icon: Icons.delete_outline,
            label: 'delete_group'.tr(),
            color: errorColor,
            onTap: _saving ? null : () => _showDeleteGroup(context, ref),
          ),
        );
      } else {
        myRoleAsync.whenData((myRole) {
          if (myRole == GroupRole.owner) {
            if (group.isArchived) {
              actions.add(
                _dangerButton(
                  icon: Icons.unarchive_outlined,
                  label: 'unarchive_group'.tr(),
                  color: errorColor,
                  onTap: _saving
                      ? null
                      : () => _showUnarchiveGroup(context, ref),
                ),
              );
            } else {
              actions.add(
                _dangerButton(
                  icon: Icons.archive_outlined,
                  label: 'archive_group'.tr(),
                  color: errorColor,
                  onTap: _saving ? null : () => _showArchiveGroup(context, ref),
                ),
              );
            }
            actions.add(
              _dangerButton(
                icon: Icons.swap_horiz,
                label: 'transfer_ownership'.tr(),
                color: errorColor,
                onTap: _saving
                    ? null
                    : () => _showTransferOwnership(context, ref),
              ),
            );
            actions.add(
              _dangerButton(
                icon: Icons.delete_outline,
                label: 'delete_group'.tr(),
                color: errorColor,
                onTap: _saving ? null : () => _showDeleteGroup(context, ref),
              ),
            );
          } else if (myRole != null) {
            if (isLocallyArchived) {
              actions.add(
                _dangerButton(
                  icon: Icons.visibility_outlined,
                  label: 'unhide_from_my_list'.tr(),
                  color: errorColor,
                  onTap: _saving
                      ? null
                      : () => _showUnhideFromMyList(context, ref),
                ),
              );
            } else {
              actions.add(
                _dangerButton(
                  icon: Icons.archive_outlined,
                  label: 'hide_from_my_list'.tr(),
                  color: errorColor,
                  onTap: _saving
                      ? null
                      : () => _showHideFromMyList(context, ref),
                ),
              );
            }
          }
          if (myRole != null) {
            actions.add(
              _dangerButton(
                icon: Icons.exit_to_app,
                label: 'leave_group'.tr(),
                color: errorColor,
                onTap: _saving ? null : () => _showLeaveGroup(context, ref),
              ),
            );
          }
        });
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    // Matrix of 3 columns: chunk actions into rows of 3
    const int columns = 3;
    final rows = <List<Widget>>[];
    for (var i = 0; i < actions.length; i += columns) {
      rows.add(
        actions.sublist(
          i,
          i + columns > actions.length ? actions.length : i + columns,
        ),
      );
    }

    return _buildSection(
      context,
      title: 'danger_zone'.tr(),
      titleColor: errorColor,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.asMap().entries.map((entry) {
            final rowActions = entry.value;
            final isLast = entry.key == rows.length - 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : ThemeConfig.spacingS,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: rowActions.isNotEmpty
                        ? rowActions[0]
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: ThemeConfig.spacingS),
                  Expanded(
                    child: rowActions.length > 1
                        ? rowActions[1]
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: ThemeConfig.spacingS),
                  Expanded(
                    child: rowActions.length > 2
                        ? rowActions[2]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dangerButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Edit Name Dialog
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showEditNameDialog(BuildContext context, Group group) async {
    final isPersonal = group.isPersonal;
    final newName = await showTextInputSheet(
      context,
      title: (isPersonal ? 'edit_list_name' : 'edit_group_name').tr(),
      hint: (isPersonal ? 'list_name' : 'group_name').tr(),
      initialValue: group.name,
      centerInFullViewport: true,
    );

    if (newName == null || newName.isEmpty || newName == group.name) {
      if (newName != null && newName.isEmpty && context.mounted) {
        context.showToast(
          (group.isPersonal ? 'list_name_empty' : 'group_name_empty').tr(),
        );
      }
      return;
    }

    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(group.copyWith(name: newName, updatedAt: DateTime.now()));
        ref.invalidate(futureGroupProvider(widget.groupId));
        if (context.mounted) {
          context.showSuccess(
            (group.isPersonal ? 'list_name_updated' : 'group_name_updated')
                .tr(),
          );
        }
      });
    } catch (e, st) {
      Log.warning('Name change failed', error: e, stackTrace: st);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Icon / Color Picker Bottom Sheet
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showIconColorPicker(BuildContext context, Group group) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String? selectedIcon = group.icon;
    Color selectedColor = group.color != null
        ? Color(group.color!)
        : groupColors.first;

    final result = await showResponsiveSheet<Map<String, dynamic>>(
      context: context,
      title: 'change_icon_color'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      sheetShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Builder(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ThemeConfig.spacingM,
                  0,
                  ThemeConfig.spacingM,
                  ThemeConfig.spacingM + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
                      Text(
                        'change_icon_color'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: ThemeConfig.spacingL),
                    ],
                    // Icon grid
                    Text(
                      'wizard_icon_label'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.spacingM),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: groupIcons.length,
                      itemBuilder: (context, index) {
                        final opt = groupIcons[index];
                        final isSelected = selectedIcon == opt.key;
                        return Material(
                          color: isSelected
                              ? selectedColor.withValues(alpha: 0.15)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            ThemeConfig.radiusL,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              ThemeConfig.radiusL,
                            ),
                            onTap: () =>
                                setSheetState(() => selectedIcon = opt.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ThemeConfig.radiusL,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? selectedColor
                                      : colorScheme.outline.withValues(
                                          alpha: 0.2,
                                        ),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    opt.icon,
                                    size: 28,
                                    color: isSelected
                                        ? selectedColor
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    opt.labelKey.tr(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isSelected
                                          ? selectedColor
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: ThemeConfig.spacingXL),

                    // Color palette
                    Text(
                      'wizard_color_label'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.spacingM),
                    GroupColorPicker(
                      selectedColor: selectedColor,
                      onColorSelected: (color) =>
                          setSheetState(() => selectedColor = color),
                    ),
                    const SizedBox(height: ThemeConfig.spacingXL),

                    // Confirm button
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, {
                        'icon': selectedIcon,
                        'color': selectedColor.toARGB32(),
                      }),
                      child: Text('done'.tr()),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (result == null || !mounted) return;

    final newIcon = result['icon'] as String?;
    final newColor = result['color'] as int?;

    // Only save if something changed
    if (newIcon == group.icon && newColor == group.color) return;

    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(
                icon: newIcon,
                color: newColor,
                updatedAt: DateTime.now(),
              ),
            );
        ref.invalidate(futureGroupProvider(widget.groupId));
        if (context.mounted) {
          context.showSuccess('group_icon_color_updated'.tr());
        }
      });
    } catch (e, st) {
      Log.warning('Icon/color change failed', error: e, stackTrace: st);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers (unchanged logic from previous version)
  // ═══════════════════════════════════════════════════════════════════════════

  String _methodLabel(SettlementMethod m) {
    switch (m) {
      case SettlementMethod.pairwise:
        return 'settlement_method_pairwise'.tr();
      case SettlementMethod.greedy:
        return 'settlement_method_greedy'.tr();
      case SettlementMethod.consolidated:
        return 'settlement_method_consolidated'.tr();
      case SettlementMethod.treasurer:
        return 'settlement_method_treasurer'.tr();
    }
  }

  String _methodDescription(SettlementMethod m) {
    switch (m) {
      case SettlementMethod.pairwise:
        return 'settlement_method_pairwise_desc'.tr();
      case SettlementMethod.greedy:
        return 'settlement_method_greedy_desc'.tr();
      case SettlementMethod.consolidated:
        return 'settlement_method_consolidated_desc'.tr();
      case SettlementMethod.treasurer:
        return 'settlement_method_treasurer_desc'.tr();
    }
  }

  Future<void> _onMethodChanged(
    WidgetRef ref,
    Group group,
    SettlementMethod? method,
  ) async {
    if (method == null) return;
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(
                settlementMethod: method,
                updatedAt: DateTime.now(),
              ),
            );
        Log.info(
          'Settlement method changed: groupId=${widget.groupId} method=$method',
        );
        ref.invalidate(futureGroupProvider(widget.groupId));
      });
    } catch (e, st) {
      Log.warning('Settlement method change failed', error: e, stackTrace: st);
    }
  }

  Future<void> _onTreasurerChanged(
    WidgetRef ref,
    Group group,
    String? treasurerId,
  ) async {
    if (treasurerId == null) return;
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(
                treasurerParticipantId: treasurerId,
                updatedAt: DateTime.now(),
              ),
            );
        Log.info(
          'Treasurer changed: groupId=${widget.groupId} treasurerId=$treasurerId',
        );
        ref.invalidate(futureGroupProvider(widget.groupId));
      });
    } catch (e, st) {
      Log.warning('Treasurer change failed', error: e, stackTrace: st);
    }
  }

  Future<void> _onFreeze(
    WidgetRef ref,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    AsyncValue<List<Expense>> expensesAsync,
  ) async {
    final participants = participantsAsync.value;
    final expenses = expensesAsync.value;
    if (participants == null || expenses == null) return;
    try {
      await _withSaving(() async {
        final snapshot = createSnapshot(participants, expenses, group);
        await ref
            .read(groupRepositoryProvider)
            .freezeSettlement(widget.groupId, snapshot);
        Log.info('Settlement frozen: groupId=${widget.groupId}');
        ref.invalidate(futureGroupProvider(widget.groupId));
      });
    } catch (e, st) {
      Log.warning('Settlement freeze failed', error: e, stackTrace: st);
    }
  }

  Future<void> _onUnfreeze(WidgetRef ref) async {
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .unfreezeSettlement(widget.groupId);
        Log.info('Settlement unfrozen: groupId=${widget.groupId}');
        ref.invalidate(futureGroupProvider(widget.groupId));
      });
    } catch (e, st) {
      Log.warning('Settlement unfreeze failed', error: e, stackTrace: st);
    }
  }

  Future<void> _onPermissionChanged(
    WidgetRef ref,
    Group group, {
    bool? allowMemberAddExpense,
    bool? allowMemberChangeSettings,
    bool? allowExpenseAsOtherParticipant,
    bool? allowMemberSettleForOthers,
  }) async {
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(
                allowMemberAddExpense:
                    allowMemberAddExpense ?? group.allowMemberAddExpense,
                allowMemberChangeSettings:
                    allowMemberChangeSettings ??
                    group.allowMemberChangeSettings,
                allowExpenseAsOtherParticipant:
                    allowExpenseAsOtherParticipant ??
                    group.allowExpenseAsOtherParticipant,
                allowMemberSettleForOthers:
                    allowMemberSettleForOthers ??
                    group.allowMemberSettleForOthers,
                updatedAt: DateTime.now(),
              ),
            );
        ref.invalidate(futureGroupProvider(widget.groupId));
      });
    } catch (e, st) {
      Log.warning('Permission change failed', error: e, stackTrace: st);
    }
  }

  Future<void> _showShareAsGroup(
    BuildContext context,
    Group group,
    WidgetRef ref,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: 'share_as_group'.tr(),
      content: 'share_as_group_confirm'.tr(),
      confirmLabel: 'share_as_group'.tr(),
      centerInFullViewport: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(isPersonal: false, updatedAt: DateTime.now()),
            );
        ref.invalidate(futureGroupProvider(widget.groupId));
        if (context.mounted) {
          context.showSuccess('share_as_group_done'.tr());
        }
      });
    } catch (e, st) {
      Log.warning('Share as group failed', error: e, stackTrace: st);
      if (context.mounted) context.showError('generic_error'.tr());
    }
  }

  Future<void> _showUseAsPersonal(
    BuildContext context,
    Group group,
    WidgetRef ref,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: 'use_as_personal'.tr(),
      content: 'use_as_personal_confirm'.tr(),
      confirmLabel: 'use_as_personal'.tr(),
      centerInFullViewport: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        final invites = await ref
            .read(groupInviteRepositoryProvider)
            .listByGroup(widget.groupId);
        for (final invite in invites) {
          if (invite.status == InviteStatus.active) {
            await ref.read(groupInviteRepositoryProvider).revoke(invite.id);
          }
        }
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(isPersonal: true, updatedAt: DateTime.now()),
            );
        ref.invalidate(futureGroupProvider(widget.groupId));
        if (context.mounted) {
          context.showSuccess('use_as_personal_done'.tr());
        }
      });
    } catch (e, st) {
      Log.warning('Use as personal failed', error: e, stackTrace: st);
      if (context.mounted) context.showError('generic_error'.tr());
    }
  }

  Future<void> _showTransferOwnership(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final members = await ref
        .read(groupMemberRepositoryProvider)
        .listByGroup(widget.groupId);
    if (!context.mounted) return;
    final others = members.where((m) => m.role != 'owner').toList();
    if (others.isEmpty) {
      context.showToast('no_other_members'.tr());
      return;
    }
    final chosen = await showResponsiveSheet<String>(
      context: context,
      title: 'transfer_ownership'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: others
                    .map(
                      (m) => ListTile(
                        title: Text(
                          '${m.userId.substring(0, 8)}... (${m.role})',
                        ),
                        onTap: () => Navigator.pop(ctx, m.id),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref
            .read(groupMemberRepositoryProvider)
            .transferOwnership(widget.groupId, chosen);
        TelemetryService.sendEvent('ownership_transferred', {
          'groupId': widget.groupId,
        }, enabled: ref.read(telemetryEnabledProvider));
        ref.invalidate(futureGroupProvider(widget.groupId));
        ref.invalidate(myRoleInGroupProvider(widget.groupId));
        if (context.mounted) {
          context.showSuccess('ownership_transferred'.tr());
        }
      });
    } catch (e, st) {
      Log.warning('Transfer failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showArchiveGroup(BuildContext context, WidgetRef ref) async {
    final isPersonal =
        ref
            .read(futureGroupProvider(widget.groupId))
            .whenOrNull(data: (g) => g?.isPersonal) ??
        false;
    final ok = await showConfirmSheet(
      context,
      title: (isPersonal ? 'archive_list' : 'archive_group').tr(),
      content: (isPersonal ? 'archive_list_confirm' : 'archive_group_confirm')
          .tr(),
      confirmLabel: (isPersonal ? 'archive_list' : 'archive_group').tr(),
      centerInFullViewport: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref.read(groupRepositoryProvider).archive(widget.groupId);
        if (context.mounted) {
          context.showSuccess(
            (isPersonal ? 'list_archived' : 'group_archived').tr(),
          );
          context.pop();
        }
      });
    } catch (e, st) {
      Log.warning('Archive group failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showUnarchiveGroup(BuildContext context, WidgetRef ref) async {
    final isPersonal =
        ref
            .read(futureGroupProvider(widget.groupId))
            .whenOrNull(data: (g) => g?.isPersonal) ??
        false;
    try {
      await _withSaving(() async {
        await ref.read(groupRepositoryProvider).unarchive(widget.groupId);
        if (context.mounted) {
          context.showSuccess(
            (isPersonal ? 'list_unarchived' : 'group_unarchived').tr(),
          );
        }
      });
    } catch (e, st) {
      Log.warning('Unarchive group failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showHideFromMyList(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmSheet(
      context,
      title: 'hide_from_my_list'.tr(),
      content: 'hide_from_my_list_confirm'.tr(),
      confirmLabel: 'hide_from_my_list'.tr(),
      centerInFullViewport: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .setLocalArchived(widget.groupId);
        if (context.mounted) {
          context.showSuccess('group_hidden_from_list'.tr());
          context.pop();
        }
      });
    } catch (e, st) {
      Log.warning('Hide from list failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showUnhideFromMyList(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .clearLocalArchived(widget.groupId);
        if (context.mounted) {
          context.showSuccess('group_unhidden_from_list'.tr());
        }
      });
    } catch (e, st) {
      Log.warning('Unhide from list failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showDeleteGroup(BuildContext context, WidgetRef ref) async {
    final isPersonal =
        ref
            .read(futureGroupProvider(widget.groupId))
            .whenOrNull(data: (g) => g?.isPersonal) ??
        false;
    final ok = await showResponsiveSheet<bool>(
      context: context,
      title: (isPersonal ? 'delete_list' : 'delete_group').tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => _TimedConfirmSheetContent(
          sheetContext: ctx,
          title: (isPersonal ? 'delete_list' : 'delete_group').tr(),
          content: (isPersonal ? 'delete_list_confirm' : 'delete_group_confirm')
              .tr(),
          confirmLabel: (isPersonal ? 'delete_list' : 'delete_group').tr(),
          seconds: 10,
          isDestructive: true,
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref.read(groupRepositoryProvider).delete(widget.groupId);
        if (context.mounted) context.go(RoutePaths.home);
      });
    } catch (e, st) {
      Log.warning('Delete group failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showLeaveGroup(BuildContext context, WidgetRef ref) async {
    final ok = await showResponsiveSheet<bool>(
      context: context,
      title: 'leave_group'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => _TimedConfirmSheetContent(
          sheetContext: ctx,
          title: 'leave_group'.tr(),
          content: 'leave_group_confirm'.tr(),
          confirmLabel: 'leave_group'.tr(),
          seconds: 10,
          isDestructive: true,
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref.read(groupMemberRepositoryProvider).leave(widget.groupId);
        TelemetryService.sendEvent('member_left', {
          'groupId': widget.groupId,
        }, enabled: ref.read(telemetryEnabledProvider));
        // Trigger immediate sync so the groups list reflects the change
        ref.read(dataSyncServiceProvider.notifier).syncNow();
        if (context.mounted) context.go(RoutePaths.home);
      });
    } catch (e, st) {
      Log.warning('Leave failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact invite preview tile for the settings page
// ─────────────────────────────────────────────────────────────────────────────

class _InvitePreviewTile extends StatelessWidget {
  final GroupInvite invite;
  const _InvitePreviewTile({required this.invite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayLabel = invite.label?.isNotEmpty == true
        ? invite.label!
        : 'invite_untitled'.tr();

    Color statusColor;
    String statusText;
    switch (invite.status) {
      case InviteStatus.active:
        statusColor = theme.colorScheme.primary;
        statusText = 'invite_status_active'.tr();
        break;
      case InviteStatus.expired:
        statusColor = theme.colorScheme.onSurfaceVariant;
        statusText = 'invite_status_expired'.tr();
        break;
      case InviteStatus.maxedOut:
        statusColor = theme.colorScheme.tertiary;
        statusText = 'invite_status_maxed'.tr();
        break;
      case InviteStatus.revoked:
        statusColor = theme.colorScheme.error;
        statusText = 'invite_status_revoked'.tr();
        break;
    }

    final usageText = invite.maxUses != null
        ? '${invite.useCount}/${invite.maxUses}'
        : '${invite.useCount}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.link, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayLabel,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.people_outline,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            usageText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timed confirmation sheet -- confirm button is disabled for [seconds] seconds
// ─────────────────────────────────────────────────────────────────────────────

class _TimedConfirmSheetContent extends StatefulWidget {
  final BuildContext sheetContext;
  final String title;
  final String content;
  final String confirmLabel;
  final int seconds;
  final bool isDestructive;

  const _TimedConfirmSheetContent({
    required this.sheetContext,
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.seconds,
    this.isDestructive = false,
  });

  @override
  State<_TimedConfirmSheetContent> createState() =>
      _TimedConfirmSheetContentState();
}

class _TimedConfirmSheetContentState extends State<_TimedConfirmSheetContent> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        _timer = null;
      }
      if (mounted) setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sheetContext;
    final colorScheme = Theme.of(ctx).colorScheme;
    final enabled = _remaining <= 0;

    return buildSheetShell(
      ctx,
      title: widget.title,
      showTitleInBody: !LayoutBreakpoints.isTabletOrWider(ctx),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(widget.content),
      ),
      actions: [
        if (!LayoutBreakpoints.isTabletOrWider(ctx))
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.isDestructive ? colorScheme.error : null,
            disabledBackgroundColor: widget.isDestructive
                ? colorScheme.error.withValues(alpha: 0.3)
                : null,
          ),
          onPressed: enabled ? () => Navigator.pop(ctx, true) : null,
          child: Text(
            enabled
                ? widget.confirmLabel
                : '${widget.confirmLabel} (${_remaining}s)',
          ),
        ),
      ],
    );
  }
}
