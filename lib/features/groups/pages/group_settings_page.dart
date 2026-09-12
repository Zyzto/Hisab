import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/groups_provider.dart';
import '../providers/group_member_provider.dart';
import '../widgets/group_color_picker.dart';
import '../widgets/group_section_header.dart';
import '../widgets/settlement_method_picker.dart';
import '../utils/group_icon_utils.dart';
import '../../../core/celebration/celebration_controller.dart';
import '../../../core/celebration/celebration_kind.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/navigation/route_transition_ready.dart';
import '../../../core/widgets/missing_route_page.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/services/household_service.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/settings/providers/settings_framework_providers.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupSettingsPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage>
    with RouteTransitionReady {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: RoutePaths.groupDetail(widget.groupId),
        currentPath: RoutePaths.groupSettings(widget.groupId),
      );
      ensureRouteReady(context);
    });
  }

  @override
  void dispose() {
    disposeRouteReady();
    super.dispose();
  }

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

  Widget _settingsShell(BuildContext context, {String? title, Widget? body}) {
    final groupPath = RoutePaths.groupDetail(widget.groupId);
    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        final canPop = routerCanPop(context);
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) popOrGo(context, groupPath);
          },
          child: Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => popOrGo(context, groupPath),
              ),
              title: Text(title ?? 'group_settings'.tr()),
            ),
            body: body ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ensureRouteReady(context);
    // Defer multi-provider watches until the push transition finishes.
    if (!routeReady) {
      return _settingsShell(context);
    }

    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    final participantsAsync = ref.watch(
      activeParticipantsByGroupProvider(widget.groupId),
    );
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));
    const localOnly = true;
    const myRoleAsync = AsyncValue<GroupRole?>.data(null);
    final localArchivedIdsAsync = ref.watch(locallyArchivedGroupIdsProvider);

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          return const MissingRoutePage(
            titleKey: 'group_not_found',
            messageKey: 'group_not_found_message',
          );
        }
        final myRole = myRoleAsync.asData?.value;
        final isOwnerOrAdmin =
            localOnly || myRole == GroupRole.owner || myRole == GroupRole.admin;
        final canEditSettings =
            isOwnerOrAdmin || group.allowMemberChangeSettings;
        final groupPath = RoutePaths.groupDetail(widget.groupId);
        return LayoutBuilder(
          builder: (context, layoutConstraints) {
            final canPop = routerCanPop(context);
            return PopScope(
              canPop: canPop,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) popOrGo(context, groupPath);
              },
              child: Scaffold(
                appBar: ContentAlignedAppBar(
                  contentAreaWidth: layoutConstraints.maxWidth,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => popOrGo(context, groupPath),
                  ),
                  title: Text(
                    (group.isPersonal ? 'list_settings' : 'group_settings')
                        .tr(),
                  ),
                ),
                body: ConstrainedContent(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThemeConfig.spacingM,
                      vertical: ThemeConfig.spacingS,
                    ),
                    children: [
                      // ── Group Header ──
                      _buildProfileHeader(
                        context,
                        group,
                        canEditSettings: canEditSettings,
                      ),
                      const SizedBox(height: ThemeConfig.spacingL),

                      // ── Currency Section ──
                      _buildSection(
                        context,
                        title:
                            (group.isPersonal ? 'currency' : 'group_currency')
                                .tr(),
                        children: [
                          _buildCurrencyRow(
                            context,
                            group,
                            expensesAsync,
                            ref,
                            canEditSettings: canEditSettings,
                          ),
                        ],
                      ),
                      const SizedBox(height: ThemeConfig.spacingL),

                      // ── Categories ──
                      if (canEditSettings)
                        _buildSection(
                          context,
                          title: 'manage_categories'.tr(),
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.label_outlined),
                              title: Text('manage_categories'.tr()),
                              subtitle: Text('manage_categories_subtitle'.tr()),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                RoutePaths.groupCategories(widget.groupId),
                              ),
                            ),
                          ],
                        ),
                      if (canEditSettings)
                        const SizedBox(height: ThemeConfig.spacingL),

                      // ── My budget (personal only) ──
                      if (group.isPersonal) ...[
                        _buildSection(
                          context,
                          title: 'my_budget'.tr(),
                          children: [
                            _buildMyBudgetRow(
                              context,
                              group,
                              ref,
                              canEditSettings: canEditSettings,
                            ),
                          ],
                        ),
                        const SizedBox(height: ThemeConfig.spacingL),
                      ],

                      // ── Settlement Section (group only) ──
                      if (!group.isPersonal)
                        _buildSection(
                          context,
                          title: 'settlement_settings'.tr(),
                          children: [
                            SettlementMethodPickerButton(
                              method: group.settlementMethod,
                              enabled: canEditSettings && !_saving,
                              onChanged: (method) =>
                                  _onMethodChanged(ref, group, method),
                            ),
                            const SizedBox(height: ThemeConfig.spacingM),
                            SettlementMethodGuideCard(
                              method: group.settlementMethod,
                              showExample: true,
                            ),
                            if (group.settlementMethod ==
                                SettlementMethod.treasurer)
                              _buildTreasurerContent(
                                context,
                                group,
                                participantsAsync,
                                ref,
                                canEditSettings: canEditSettings,
                              ),
                            _buildFreezeContent(
                              context,
                              group,
                              participantsAsync,
                              expensesAsync,
                              ref,
                              canEditSettings: canEditSettings,
                            ),
                          ],
                        ),
                      if (!group.isPersonal)
                        const SizedBox(height: ThemeConfig.spacingL),

                      // ── Household counting ──
                      if (!group.isPersonal && canEditSettings)
                        _buildSection(
                          context,
                          title: 'household_counting'.tr(),
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text('household_counting_title'.tr()),
                              subtitle: Text(
                                group.householdCountingEnabled
                                    ? 'household_counting_enabled_hint'.tr()
                                    : 'household_counting_disabled_hint'.tr(),
                              ),
                              value: group.householdCountingEnabled,
                              onChanged: _saving
                                  ? null
                                  : (value) =>
                                        _onHouseholdChanged(ref, group, value),
                            ),
                            Text(
                              'household_counting_example'.tr(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      if (!group.isPersonal && canEditSettings)
                        const SizedBox(height: ThemeConfig.spacingL),

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
              ),
            );
          },
        );
      },
      loading: () => _settingsShell(
        context,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) {
        return _settingsShell(
          context,
          title: 'list_settings'.tr(),
          body: Center(
            child: ErrorContentWidget(
              message: e.toString(),
              details: e.toString(),
              stackTrace: st,
              onRetry: () =>
                  ref.invalidate(futureGroupProvider(widget.groupId)),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Group Header
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileHeader(
    BuildContext context,
    Group group, {
    required bool canEditSettings,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avatarColor = group.color != null
        ? Color(group.color!)
        : colorScheme.primary;
    final avatarFg = group.color != null
        ? ThemeConfig.foregroundOnBackground(avatarColor)
        : colorScheme.onPrimary;
    final iconData = groupIconFromKey(group.icon);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeConfig.spacingM,
        vertical: ThemeConfig.spacingM,
      ),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: context.subtleAccents,
        accentContainer: group.color != null
            ? Color(group.color!).withValues(alpha: 0.35)
            : colorScheme.primaryContainer,
        accentBorder: group.color != null
            ? Color(group.color!)
            : colorScheme.primary,
        radius: ThemeConfig.radiusXL,
      ),
      child: Row(
        children: [
          // Avatar – tap to change icon/color
          GestureDetector(
            onTap: canEditSettings
                ? () => _showIconColorPicker(context, group)
                : null,
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
                if (canEditSettings)
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
                  onTap: canEditSettings
                      ? () => _showEditNameDialog(context, group)
                      : null,
                  child: Row(
                    children: [
                      Flexible(
                        child: UserText(
                          group.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: ThemeConfig.spacingXS),
                      if (canEditSettings)
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroupSectionHeader(
          label: title,
          trailing: trailing,
          barColor: titleColor,
          labelColor: titleColor,
        ),
        const SizedBox(height: ThemeConfig.spacingM),
        ...children,
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // My budget (personal only)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMyBudgetRow(
    BuildContext context,
    Group group,
    WidgetRef ref, {
    required bool canEditSettings,
  }) {
    final theme = Theme.of(context);
    final currencyCode = group.currencyCode;
    final budgetCents = group.budgetAmountCents;
    final display = budgetCents != null && budgetCents > 0
        ? CurrencyFormatter.formatCentsAsWholeUnits(budgetCents, currencyCode)
        : '—';

    return InkWell(
      onTap: _saving || !canEditSettings
          ? null
          : () => _showMyBudgetDialog(context, group, ref),
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
    final budgetCents = group.budgetAmountCents;
    String initialValue = '';
    if (budgetCents != null && budgetCents > 0) {
      final currency = CurrencyHelpers.fromCode(group.currencyCode);
      final decimals = currency?.decimalDigits ?? 2;
      final divisor = CurrencyHelpers.divisorForDecimalDigits(decimals);
      initialValue = (budgetCents / divisor).round().toString();
    }
    final hint =
        CurrencyHelpers.fromCode(group.currencyCode)?.symbol ??
        group.currencyCode;
    final bodyKey = GlobalKey<_BudgetSheetBodyState>();
    final isTablet = LayoutBreakpoints.isTabletOrWider(context);
    final result = await showResponsiveSheet<String?>(
      context: context,
      title: isTablet ? 'my_budget'.tr() : null,
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => buildSheetShell(
          ctx,
          title: 'my_budget'.tr(),
          showTitleInBody: !isTablet,
          body: _BudgetSheetBody(
            key: bodyKey,
            initialValue: initialValue,
            hint: hint,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text('clear'.tr()),
            ),
            if (!isTablet)
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('cancel'.tr()),
              ),
            FilledButton(
              onPressed: () {
                final text = bodyKey.currentState?.controller.text.trim() ?? '';
                Navigator.pop(ctx, text);
              },
              child: Text('done'.tr()),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    int? newBudgetCents;
    if (result.isNotEmpty) {
      final value = int.tryParse(result.replaceAll(',', '').trim());
      if (value != null && value >= 0) {
        final currency = CurrencyHelpers.fromCode(group.currencyCode);
        final decimals = currency?.decimalDigits ?? 2;
        final divisor = CurrencyHelpers.divisorForDecimalDigits(decimals);
        newBudgetCents = value * divisor;
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
        Log.info(
          'Group setting: budget_updated groupId=${widget.groupId} '
          'budgetCents=${newBudgetCents ?? "cleared"}',
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
    WidgetRef ref, {
    required bool canEditSettings,
  }) {
    final theme = Theme.of(context);
    final currency = CurrencyHelpers.fromCode(group.currencyCode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving || !canEditSettings
            ? null
            : () => _onCurrencyTap(context, group, expensesAsync, ref),
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
      ),
    );
  }

  Future<void> _onCurrencyTap(
    BuildContext sheetContext,
    Group group,
    AsyncValue<List<Expense>> expensesAsync,
    WidgetRef ref,
  ) async {
    if (!sheetContext.mounted) return;
    final stored = ref.read(favoriteCurrenciesProvider);
    final favorites = CurrencyHelpers.getEffectiveFavorites(stored);
    CurrencyHelpers.showPicker(
      context: sheetContext,
      favorite: favorites,
      centerInFullViewport: true,
      onSelect: (Currency currency) async {
        if (currency.code == group.currencyCode) return;
        if (!sheetContext.mounted) return;

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
            if (sheetContext.mounted) {
              sheetContext.showSuccess('group_currency_updated'.tr());
            }
          });
        } catch (e, st) {
          Log.warning('Currency change failed', error: e, stackTrace: st);
          if (sheetContext.mounted) {
            sheetContext.showError('generic_error'.tr());
          }
        }
      },
    );
  }

  Widget _buildTreasurerContent(
    BuildContext context,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    WidgetRef ref, {
    required bool canEditSettings,
  }) {
    final theme = Theme.of(context);
    return participantsAsync.when(
      data: (participants) {
        if (participants.isEmpty) {
          return const SizedBox.shrink();
        }
        final selectedId =
            group.treasurerParticipantId ?? participants.first.id;
        final selected =
            participants.where((p) => p.id == selectedId).firstOrNull ??
            participants.first;
        final canEdit = !_saving && canEditSettings;
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
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(ThemeConfig.radiusXL),
                onTap: !canEdit
                    ? null
                    : () async {
                        final chosen = await showOptionPickerSheet<String>(
                          context,
                          title: 'select_treasurer'.tr(),
                          selected: selectedId,
                          options: [
                            for (final p in participants)
                              SheetPickerOption(
                                value: p.id,
                                label: p.name,
                                leading: ParticipantAvatar(
                                  name: p.name,
                                  avatarId: p.avatarId,
                                  radius: 16,
                                ),
                              ),
                          ],
                        );
                        if (chosen != null) {
                          await _onTreasurerChanged(ref, group, chosen);
                        }
                      },
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThemeConfig.radiusXL),
                    ),
                    enabled: canEdit,
                  ),
                  child: Row(
                    children: [
                      ParticipantAvatar(
                        name: selected.name,
                        avatarId: selected.avatarId,
                        radius: 14,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: UserText(
                          selected.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, st) {
        Log.warning('Group settings load error', error: e, stackTrace: st);
        return ErrorContentWidget(
          titleKey: 'generic_error',
          message: e.toString(),
          details: e.toString(),
          stackTrace: st,
        );
      },
    );
  }

  Widget _buildFreezeContent(
    BuildContext context,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    AsyncValue<List<Expense>> expensesAsync,
    WidgetRef ref, {
    required bool canEditSettings,
  }) {
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
      onChanged: _saving || !canEditSettings || group.isArchived
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
      // Personal: archive, delete, or share as group.
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
      maxLength: FormValidators.groupNameMax,
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
    if (FormValidators.groupName(newName) != null) {
      if (context.mounted) {
        context.showToast(
          'field_too_long'.tr(
            namedArgs: {'max': '${FormValidators.groupNameMax}'},
          ),
        );
      }
      return;
    }

    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(group.copyWith(name: newName, updatedAt: DateTime.now()));
        Log.info(
          'Group setting: name_updated groupId=${widget.groupId} name="$newName"',
        );
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
                padding: const EdgeInsets.fromLTRB(
                  ThemeConfig.spacingM,
                  0,
                  ThemeConfig.spacingM,
                  ThemeConfig.spacingM,
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
        Log.info('Group setting: icon_color_updated groupId=${widget.groupId}');
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
        Log.info(
          'Group setting: permissions_updated groupId=${widget.groupId}',
        );
        ref.invalidate(futureGroupProvider(widget.groupId));
      });
    } catch (e, st) {
      Log.warning('Permission change failed', error: e, stackTrace: st);
    }
  }

  Future<void> _onHouseholdChanged(
    WidgetRef ref,
    Group group,
    bool enabled,
  ) async {
    try {
      await _withSaving(() async {
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(
                householdCountingEnabled: enabled,
                updatedAt: DateTime.now(),
              ),
            );
        ref.invalidate(futureGroupProvider(widget.groupId));
        Log.info(
          'Household counting changed: groupId=${widget.groupId} enabled=$enabled',
        );
      });
    } catch (e, st) {
      Log.warning('Household counting change failed', error: e, stackTrace: st);
      if (mounted) context.showError('generic_error'.tr());
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
        Log.info('Group setting: share_as_group groupId=${widget.groupId}');
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
        await ref
            .read(groupRepositoryProvider)
            .update(
              group.copyWith(isPersonal: true, updatedAt: DateTime.now()),
            );
        Log.info('Group setting: use_as_personal groupId=${widget.groupId}');
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
    final chosen = await showOptionPickerSheet<String>(
      context,
      title: 'transfer_ownership'.tr(),
      options: [
        for (final m in others)
          SheetPickerOption(
            value: m.id,
            label: '${m.userId.substring(0, 8)}...',
            subtitle: m.role,
          ),
      ],
    );
    if (chosen == null || !context.mounted) return;
    try {
      await _withSaving(() async {
        await ref
            .read(groupMemberRepositoryProvider)
            .transferOwnership(widget.groupId, chosen);
        ref.invalidate(futureGroupProvider(widget.groupId));
        ref.invalidate(membersByGroupProvider(widget.groupId));
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
        Log.info('Group setting: archived groupId=${widget.groupId}');
        if (context.mounted) {
          context.showSuccess(
            (isPersonal ? 'list_archived' : 'group_archived').tr(),
          );
          popOrGo(context, RoutePaths.home);
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
        Log.info('Group setting: unarchived groupId=${widget.groupId}');
        ref.invalidate(futureGroupProvider(widget.groupId));
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
        Log.info('Group setting: hide_from_list groupId=${widget.groupId}');
        if (context.mounted) {
          context.showSuccess('group_hidden_from_list'.tr());
          popOrGo(context, RoutePaths.home);
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
        Log.info('Group setting: unhide_from_list groupId=${widget.groupId}');
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
    final ok = await showConfirmSheet(
      context,
      title: (isPersonal ? 'delete_list' : 'delete_group').tr(),
      content: (isPersonal ? 'delete_list_confirm' : 'delete_group_confirm')
          .tr(),
      confirmLabel: (isPersonal ? 'delete_list' : 'delete_group').tr(),
      isDestructive: true,
      centerInFullViewport: true,
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
    final ok = await showConfirmSheet(
      context,
      title: 'leave_group'.tr(),
      content: 'leave_group_confirm'.tr(),
      confirmLabel: 'leave_group'.tr(),
      isDestructive: true,
      centerInFullViewport: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      await _withSaving(() async {
        await _preserveHouseholdBeforeLeave(ref);
        await ref.read(groupMemberRepositoryProvider).leave(widget.groupId);
        // Farewell overlay on the way home (no participant id on this path).
        await fireCelebration(ref, CelebrationKind.personLeft);
        if (context.mounted) context.go(RoutePaths.home);
      });
    } catch (e, st) {
      Log.warning('Leave failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  /// Keep the shared directory valid when the signed-in participant leaves.
  /// The leave RPC removes the membership and archives the participant, so
  /// direct child branches must be promoted before that server-side change.
  Future<void> _preserveHouseholdBeforeLeave(WidgetRef ref) async {
    final member = await ref.read(
      myMemberInGroupProvider(widget.groupId).future,
    );
    final participantId = member?.participantId;
    if (participantId == null) return;
    final participant = await ref
        .read(participantRepositoryProvider)
        .getById(participantId);
    if (participant == null) return;
    final group = await ref
        .read(groupRepositoryProvider)
        .getById(widget.groupId);
    final allParticipants = await ref
        .read(participantRepositoryProvider)
        .getByGroupId(widget.groupId);
    final children =
        allParticipants
            .where((p) => p.parentParticipantId == participant.id)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    if (children.isEmpty) return;

    if (group?.householdCountingEnabled == true) {
      final reassignmentRepo = ref.read(
        householdBalanceReassignmentRepositoryProvider,
      );
      final existing = await reassignmentRepo.getByGroupId(widget.groupId);
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .getByGroupId(widget.groupId);
      final parentBalance =
          HouseholdService.applyReassignments(
            balances: computeBalances(
              allParticipants,
              expenses,
              group!.currencyCode,
            ),
            reassignments: existing,
          ).firstWhere(
            (balance) => balance.participantId == participant.id,
            orElse: () => ParticipantBalance(
              participantId: participant.id,
              balanceCents: 0,
              currencyCode: group.currencyCode,
            ),
          );
      final weights = <String, int>{
        for (final child in children)
          child.id: HouseholdService.subtreeSize(child.id, allParticipants),
      };
      final totalWeight = weights.values.fold<int>(0, (a, b) => a + b);
      var assigned = 0;
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        final amount = i == children.length - 1
            ? parentBalance.balanceCents - assigned
            : (parentBalance.balanceCents * weights[child.id]! / totalWeight)
                  .round();
        assigned += amount;
        await reassignmentRepo.create(
          groupId: widget.groupId,
          sourceParticipantId: participant.id,
          targetParticipantId: child.id,
          amountCents: amount,
        );
      }
    }

    for (final child in children) {
      await ref
          .read(participantRepositoryProvider)
          .update(child.copyWith(clearParentParticipantId: true));
    }
  }
}

/// Sheet body that owns a [TextEditingController] so it is disposed when
/// the route is removed (avoids "used after being disposed").
class _BudgetSheetBody extends StatefulWidget {
  const _BudgetSheetBody({
    super.key,
    required this.initialValue,
    required this.hint,
  });

  final String initialValue;
  final String hint;

  @override
  State<_BudgetSheetBody> createState() => _BudgetSheetBodyState();
}

class _BudgetSheetBodyState extends State<_BudgetSheetBody> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'budget_amount'.tr(),
        hintText: widget.hint,
        border: const OutlineInputBorder(),
      ),
      autofocus: true,
    );
  }
}
