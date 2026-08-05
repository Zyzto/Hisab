import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/celebration/celebration_controller.dart';
import '../../../core/celebration/celebration_kind.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/navigation/decorative_route.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/navigation/route_transition_ready.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/run_guarded_async.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/widgets/group_section_header.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/sheet_option_tile.dart';
import '../../../core/widgets/user_text.dart';
import '../../../core/widgets/wizard_step_enter.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../utils/group_icon_utils.dart';
import '../widgets/group_color_picker.dart';
import '../widgets/settlement_method_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wizard entry point (keeps the same class name for router compatibility)
// ─────────────────────────────────────────────────────────────────────────────

/// Maps a create-wizard location path to a step index, or null if unmatched.
@visibleForTesting
int? groupCreateStepFromPath(String path, {required bool isPersonal}) {
  if (isPersonal) {
    if (path == RoutePaths.groupCreatePersonalDetails) return 0;
    if (path == RoutePaths.groupCreatePersonalStyle) return 1;
    if (path == RoutePaths.groupCreatePersonalReview) return 2;
    if (path == RoutePaths.groupCreatePersonal) return 0;
    return null;
  }
  if (path == RoutePaths.groupCreateDetails) return 0;
  if (path == RoutePaths.groupCreateParticipants) return 1;
  if (path == RoutePaths.groupCreateStyle) return 2;
  if (path == RoutePaths.groupCreateReview) return 3;
  if (path == RoutePaths.groupCreate) return 0;
  return null;
}

class GroupCreatePage extends ConsumerStatefulWidget {
  final bool isPersonal;
  final int initialStep;

  const GroupCreatePage({
    super.key,
    this.isPersonal = false,
    this.initialStep = 0,
  });

  @override
  ConsumerState<GroupCreatePage> createState() => _GroupCreatePageState();
}

/// Keeps a wizard step alive after first visit (FormState / WizardStepEnter).
class _KeepAliveStep extends StatefulWidget {
  const _KeepAliveStep({required this.child});

  final Widget child;

  @override
  State<_KeepAliveStep> createState() => _KeepAliveStepState();
}

class _KeepAliveStepState extends State<_KeepAliveStep>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _GroupCreatePageState extends ConsumerState<GroupCreatePage>
    with RouteTransitionReady {
  static const _kIndicatorActiveWidth = 28.0;
  static const _kIndicatorInactiveWidth = 8.0;

  int get _pageCount => widget.isPersonal ? 3 : 4;

  Duration get _pageAnimDuration =>
      UiPerf.preferInstantShellTabs ? Duration.zero : AppMotion.page;

  late final PageController _pageController;
  int _currentPage = 0;

  // ── Step 1 state ──
  final _nameFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _budgetController = TextEditingController();
  final _budgetFocusNode = FocusNode();
  late Currency _selectedCurrency;

  // ── Step 2 state ──
  final _participantController = TextEditingController();
  final _participantFocusNode = FocusNode();

  /// Prevents the Add button from stealing focus from the name field.
  late final FocusNode _addParticipantButtonFocusNode;
  final List<String> _participants = [];

  // ── Step 3 state ──
  String? _selectedIcon;
  Color _selectedColor = groupColors.first;

  // ── Group settings (group create only; not personal) ──
  SettlementMethod _settlementMethod = SettlementMethod.greedy;

  /// `null` = owner is treasurer; otherwise a name from [_participants].
  String? _treasurerParticipantName;
  bool _allowMemberAddExpense = true;
  bool _allowMemberChangeSettings = true;
  bool _allowExpenseAsOtherParticipant = true;
  bool _allowMemberSettleForOthers = false;

  // ── Step 4 state ──
  bool _saving = false;

  String _decorativePathForPage(int page) {
    if (widget.isPersonal) {
      switch (page.clamp(0, _pageCount - 1)) {
        case 1:
          return RoutePaths.groupCreatePersonalStyle;
        case 2:
          return RoutePaths.groupCreatePersonalReview;
        case 0:
        default:
          return RoutePaths.groupCreatePersonalDetails;
      }
    }
    switch (page.clamp(0, _pageCount - 1)) {
      case 1:
        return RoutePaths.groupCreateParticipants;
      case 2:
        return RoutePaths.groupCreateStyle;
      case 3:
        return RoutePaths.groupCreateReview;
      case 0:
      default:
        return RoutePaths.groupCreateDetails;
    }
  }

  /// Address bar only — canonical route stays [RoutePaths.groupCreate] /
  /// [RoutePaths.groupCreatePersonal] so this [State] is not recreated per step.
  void _syncDecorativeUrlToPage(int page) {
    syncDecorativeRoutePath(context, _decorativePathForPage(page));
  }

  int _resolveInitialStep() {
    // Prefer browser path on web so reload / remount stays aligned with the
    // decorative step URL even if GoRouter still matched the canonical route.
    final browserPath = webVisibleAppRoutePath();
    if (browserPath != null) {
      final fromPath = groupCreateStepFromPath(
        browserPath,
        isPersonal: widget.isPersonal,
      );
      if (fromPath != null) return fromPath.clamp(0, _pageCount - 1);
    }
    return widget.initialStep.clamp(0, _pageCount - 1);
  }

  @override
  void initState() {
    super.initState();
    _currentPage = _resolveInitialStep();
    _pageController = PageController(initialPage: _currentPage);
    _selectedCurrency = CurrencyHelpers.defaultCurrency();
    _addParticipantButtonFocusNode = FocusNode(canRequestFocus: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDecorativeUrlToPage(_currentPage);
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: RoutePaths.home,
        currentPath: _decorativePathForPage(_currentPage),
      );
      ensureRouteReady(context);
    });
  }

  @override
  void didUpdateWidget(covariant GroupCreatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.initialStep.clamp(0, _pageCount - 1);
    if (oldWidget.initialStep != widget.initialStep &&
        targetPage != _currentPage) {
      _currentPage = targetPage;
      _pageController.jumpToPage(targetPage);
    }
  }

  @override
  void dispose() {
    disposeRouteReady();
    _pageController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _budgetController.dispose();
    _budgetFocusNode.dispose();
    _participantController.dispose();
    _participantFocusNode.dispose();
    _addParticipantButtonFocusNode.dispose();
    super.dispose();
  }

  Widget _stepForIndex(BuildContext context, int index) {
    if (widget.isPersonal) {
      return switch (index) {
        0 => _buildStep1NameCurrency(context),
        1 => _buildStep3IconColor(context),
        _ => _buildStep4Summary(context),
      };
    }
    return switch (index) {
      0 => _buildStep1NameCurrency(context),
      1 => _buildStep2Participants(context),
      2 => _buildStep3IconColor(context),
      _ => _buildStep4Summary(context),
    };
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _animateToPage(int page) {
    if (_pageAnimDuration == Duration.zero) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(
        page,
        duration: _pageAnimDuration,
        curve: AppMotion.enterCurve,
      );
    }
  }

  void _goNext() {
    if (_currentPage == 0) {
      // Unfocus both step-0 fields so the keyboard reliably dismisses.
      _nameFocusNode.unfocus();
      _budgetFocusNode.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    // Validate before advancing from step 1
    if (_currentPage == 0 &&
        (_nameFormKey.currentState?.validate() ?? false) != true) {
      return;
    }
    if (_currentPage < _pageCount - 1) {
      if (_pageAnimDuration == Duration.zero) {
        _pageController.jumpToPage(_currentPage + 1);
      } else {
        _pageController.nextPage(
          duration: _pageAnimDuration,
          curve: AppMotion.enterCurve,
        );
      }
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      _nameFocusNode.unfocus();
      _budgetFocusNode.unfocus();
      _participantFocusNode.unfocus();
      if (_pageAnimDuration == Duration.zero) {
        _pageController.jumpToPage(_currentPage - 1);
      } else {
        _pageController.previousPage(
          duration: _pageAnimDuration,
          curve: AppMotion.enterCurve,
        );
      }
    } else {
      popOrGo(context, RoutePaths.home);
    }
  }

  // ── Participant helpers ─────────────────────────────────────────────────

  void _addParticipant() {
    final name = _participantController.text.trim();
    if (FormValidators.participantName(name) != null) return;
    setState(() {
      _participants.add(name);
      _participantController.clear();
    });
    // Re-focus after rebuild so Add / Done does not leave the field unfocused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _participantFocusNode.requestFocus();
    });
  }

  void _removeParticipant(int index) {
    setState(() => _participants.removeAt(index));
  }

  // ── Create ──────────────────────────────────────────────────────────────

  int? _budgetAmountCentsFromField() {
    final trimmed = _budgetController.text.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed.replaceAll(',', ''));
    if (value == null || value < 0) return null;
    final decimals =
        CurrencyHelpers.fromCode(_selectedCurrency.code)?.decimalDigits ?? 2;
    final divisor = CurrencyHelpers.divisorForDecimalDigits(decimals);
    return value * divisor;
  }

  Future<void> _createGroup() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (FormValidators.groupName(name) != null) {
      // Jump back to name step if somehow invalid on create.
      if (_currentPage != 0) {
        _pageController.jumpToPage(0);
        setState(() => _currentPage = 0);
      }
      _nameFormKey.currentState?.validate();
      return;
    }
    setState(() => _saving = true);
    try {
      final currencyCode = _selectedCurrency.code;
      final repo = ref.read(groupRepositoryProvider);
      final budgetAmountCents = widget.isPersonal
          ? _budgetAmountCentsFromField()
          : null;
      final id = await runGuardedAsync<String>(
        repo.create(
          name,
          currencyCode,
          icon: _selectedIcon,
          color: _selectedColor.toARGB32(),
          initialParticipants: widget.isPersonal ? [] : _participants,
          isPersonal: widget.isPersonal,
          budgetAmountCents: budgetAmountCents,
          settlementMethod: widget.isPersonal
              ? SettlementMethod.greedy
              : _settlementMethod,
          treasurerInitialParticipantName: widget.isPersonal
              ? null
              : (_settlementMethod == SettlementMethod.treasurer
                    ? _treasurerParticipantName
                    : null),
          allowMemberAddExpense: widget.isPersonal
              ? true
              : _allowMemberAddExpense,
          allowMemberChangeSettings: widget.isPersonal
              ? true
              : _allowMemberChangeSettings,
          allowExpenseAsOtherParticipant: widget.isPersonal
              ? true
              : _allowExpenseAsOtherParticipant,
          allowMemberSettleForOthers: widget.isPersonal
              ? false
              : _allowMemberSettleForOthers,
        ),
        'Group create failed',
        context: context,
        errorToastMessage: 'create_group_failed'.tr(),
        ref: ref,
      );
      if (id == null) return;
      Log.info(
        'Group created via wizard: id=$id name="$name" currency=$currencyCode participants=${_participants.length}',
      );
      try {
        TelemetryService.sendEvent('group_created', {
          'groupId': id,
          'currencyCode': currencyCode,
          'participantCount': _participants.length,
          'hasIcon': _selectedIcon != null,
        }, enabled: ref.read(telemetryEnabledProvider));
      } catch (_) {}
      await fireCelebration(
        ref,
        widget.isPersonal
            ? CelebrationKind.newPersonalList
            : CelebrationKind.newGroup,
        dedupeKey: CelebrationKeys.groupCreated(id),
      );
      if (mounted) context.go(RoutePaths.groupDetail(id));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _formPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AccentSurfaces.flatPanel(Theme.of(context).colorScheme),
      child: child,
    );
  }

  Widget _stepTitleBlock({
    required String titleKey,
    required String subtitleKey,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleKey.tr(),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        Text(
          subtitleKey.tr(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ensureRouteReady(context);
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return PopScope(
          canPop: _currentPage == 0 && routerCanPop(context),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_currentPage > 0) {
              _goBack();
            } else {
              popOrGo(context, RoutePaths.home);
            }
          },
          child: Scaffold(
            // Keep fields above the keyboard on mobile / mobile web.
            resizeToAvoidBottomInset: true,
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
              title: Text(
                widget.isPersonal
                    ? 'create_personal'.tr()
                    : 'create_group'.tr(),
              ),
            ),
            body: !routeReady
                ? const SizedBox.shrink()
                : ConstrainedContent(
                    child: SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _pageCount,
                              physics: const NeverScrollableScrollPhysics(),
                              onPageChanged: (i) {
                                final fromPage = _currentPage;
                                setState(() => _currentPage = i);
                                _syncDecorativeUrlToPage(i);
                                // Clear focus after returning to step 0 so keyboard does not reopen.
                                if (i == 0 && fromPage > 0) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    _nameFocusNode.unfocus();
                                    _budgetFocusNode.unfocus();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  });
                                }
                              },
                              itemBuilder: (context, index) {
                                return _KeepAliveStep(
                                  child: _stepForIndex(context, index),
                                );
                              },
                            ),
                          ),
                          _buildPageIndicator(context),
                          _buildBottomBar(context, colorScheme),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ── Page indicator ──────────────────────────────────────────────────────

  Widget _buildPageIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ThemeConfig.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pageCount, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: UiPerf.preferInstantShellTabs
                ? Duration.zero
                : ThemeConfig.animationShort,
            curve: AppMotion.enterCurve,
            margin: const EdgeInsets.symmetric(
              horizontal: ThemeConfig.spacingXS,
            ),
            width: isActive ? _kIndicatorActiveWidth : _kIndicatorInactiveWidth,
            height: isActive ? 8 : 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThemeConfig.radiusS),
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          );
        }),
      ),
    );
  }

  // ── Bottom navigation bar ───────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, ColorScheme colorScheme) {
    final isLastPage = _currentPage == _pageCount - 1;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final decoration = UiPerf.preferCheapShadows
        ? BoxDecoration(
            color: scaffoldBg,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          )
        : BoxDecoration(
            color: scaffoldBg,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      decoration: decoration,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Tooltip(
                message: _currentPage == 0 ? 'cancel'.tr() : 'wizard_back'.tr(),
                child: TextButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    _currentPage == 0 ? 'cancel'.tr() : 'wizard_back'.tr(),
                  ),
                ),
              ),
            ),
          ),
          Text(
            '${_currentPage + 1} / $_pageCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Tooltip(
                message: isLastPage
                    ? (widget.isPersonal
                          ? 'create_personal'.tr()
                          : 'create_group'.tr())
                    : 'wizard_next'.tr(),
                child: isLastPage
                    ? FilledButton.icon(
                        key: const Key('wizard_create_button'),
                        onPressed: _saving ? null : _createGroup,
                        icon: _saving
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          widget.isPersonal
                              ? 'create_personal'.tr()
                              : 'create_group'.tr(),
                        ),
                      )
                    : FilledButton.icon(
                        key: const Key('wizard_next_button'),
                        onPressed: _goNext,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          _currentPage == 1 && !widget.isPersonal
                              ? (_participants.isEmpty
                                    ? 'wizard_skip'.tr()
                                    : 'wizard_next'.tr())
                              : 'wizard_next'.tr(),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1 — Name & Currency
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1NameCurrency(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final titleKey = widget.isPersonal
        ? 'wizard_step1_title_personal'
        : 'wizard_step1_title';
    final subtitleKey = widget.isPersonal
        ? 'wizard_step1_subtitle_personal'
        : 'wizard_step1_subtitle';

    // Dense permission rows on mobile web — shorter scroll, same hit targets
    // via SwitchListTile; full density on desktop/native.
    final denseSettings = UiPerf.isWebMobile;

    return WizardStepEnter(
      child: Form(
        key: _nameFormKey,
        child: FocusTraversalGroup(
          child: ListView(
            padding: const EdgeInsets.all(ThemeConfig.spacingM),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const SizedBox(height: ThemeConfig.spacingM),
              _stepTitleBlock(titleKey: titleKey, subtitleKey: subtitleKey),
              const SizedBox(height: ThemeConfig.spacingXL),
              _formPanel(
                child: TextFormField(
                  key: const Key('wizard_name_field'),
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: InputDecoration(
                    labelText: (widget.isPersonal ? 'list_name' : 'group_name')
                        .tr(),
                    hintText: 'wizard_name_hint'.tr(),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      widget.isPersonal
                          ? Icons.person_outline
                          : Icons.group_outlined,
                    ),
                    counterText: '',
                  ),
                  validator: FormValidators.groupName,
                  maxLength: FormValidators.groupNameMax,
                  textInputAction: TextInputAction.next,
                  // Avoid setState-on-keystroke: step body includes heavy
                  // settings chrome (permissions) that must not rebuild per char.
                ),
              ),
              const SizedBox(height: ThemeConfig.spacingL),
              GroupSectionHeader(label: 'currency'.tr()),
              const SizedBox(height: ThemeConfig.spacingM),
              _buildSelectableFlatRow(
                context,
                onTap: _openCurrencyPicker,
                child: Row(
                  children: [
                    Text(
                      CurrencyUtils.currencyToEmoji(_selectedCurrency),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        CurrencyHelpers.displayLabel(_selectedCurrency),
                        style: theme.textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (widget.isPersonal) ...[
                const SizedBox(height: ThemeConfig.spacingL),
                GroupSectionHeader(label: 'my_budget'.tr()),
                const SizedBox(height: ThemeConfig.spacingM),
                _formPanel(
                  child: TextFormField(
                    key: const Key('wizard_budget_field'),
                    controller: _budgetController,
                    focusNode: _budgetFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'budget_amount'.tr(),
                      hintText:
                          CurrencyHelpers.fromCode(
                            _selectedCurrency.code,
                          )?.symbol ??
                          _selectedCurrency.code,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ] else ...[
                // Isolate settings chrome so name/currency edits do not repaint it.
                RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: ThemeConfig.spacingL),
                      GroupSectionHeader(label: 'settlement_method'.tr()),
                      const SizedBox(height: ThemeConfig.spacingM),
                      SettlementMethodPickerButton(
                        method: _settlementMethod,
                        onChanged: (method) {
                          setState(() {
                            _settlementMethod = method;
                            if (method != SettlementMethod.treasurer) {
                              _treasurerParticipantName = null;
                            } else {
                              _syncTreasurerSelection();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: ThemeConfig.spacingM),
                      SettlementMethodGuideCard(
                        method: _settlementMethod,
                        showExample: false,
                      ),
                      if (_settlementMethod == SettlementMethod.treasurer) ...[
                        const SizedBox(height: ThemeConfig.spacingM),
                        _buildTreasurerPicker(context),
                      ],
                      const SizedBox(height: ThemeConfig.spacingL),
                      GroupSectionHeader(label: 'group_permissions'.tr()),
                      const SizedBox(height: ThemeConfig.spacingM),
                      _buildPermissionsPanel(context, dense: denseSettings),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shared flat/emphasized tappable row (currency, settlement).
  Widget _buildSelectableFlatRow(
    BuildContext context, {
    required VoidCallback onTap,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: AccentSurfaces.emphasizedFill(
        colorScheme,
        subtle: context.subtleAccents,
      ),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AccentSurfaces.emphasizedBorder(
                colorScheme,
                subtle: context.subtleAccents,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }

  void _openCurrencyPicker() {
    FocusManager.instance.primaryFocus?.unfocus();
    final stored = ref.read(favoriteCurrenciesProvider);
    final favorites = CurrencyHelpers.getEffectiveFavorites(stored);
    CurrencyHelpers.showPicker(
      context: context,
      favorite: favorites,
      onSelect: (Currency currency) {
        setState(() => _selectedCurrency = currency);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2 — Participants
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2Participants(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WizardStepEnter(
      child: ListView(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const SizedBox(height: ThemeConfig.spacingM),
          _stepTitleBlock(
            titleKey: 'wizard_step2_title',
            subtitleKey: 'wizard_step2_subtitle',
          ),
          const SizedBox(height: ThemeConfig.spacingL),

          // Owner card (non-removable)
          Builder(
            builder: (context) {
              final profile = ref.watch(authUserProfileProvider).value;
              final profileName = profile?.name?.trim();
              final displayName =
                  (profileName != null && profileName.isNotEmpty)
                  ? profileName
                  : 'wizard_you'.tr();
              return Container(
                decoration: BoxDecoration(
                  color: AccentSurfaces.emphasizedFill(
                    colorScheme,
                    subtle: context.subtleAccents,
                  ),
                  borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                  border: Border.all(
                    color: AccentSurfaces.emphasizedBorder(
                      colorScheme,
                      subtle: context.subtleAccents,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: ParticipantAvatar(
                    name: displayName,
                    avatarId: profile?.avatarId,
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.16,
                    ),
                    foregroundColor: colorScheme.primary,
                  ),
                  title: Text(
                    'wizard_you'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text('wizard_owner'.tr()),
                ),
              );
            },
          ),
          const SizedBox(height: ThemeConfig.spacingS),

          // Added participants
          ...List.generate(_participants.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
              child: Container(
                decoration: AccentSurfaces.flatPanel(
                  colorScheme,
                  radius: ThemeConfig.radiusL,
                ),
                child: ListTile(
                  leading: ParticipantAvatar(
                    name: _participants[i],
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurface,
                  ),
                  title: UserText(_participants[i]),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: colorScheme.error),
                    onPressed: () => _removeParticipant(i),
                    tooltip: 'remove'.tr(),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: ThemeConfig.spacingM),

          _formPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _participantController,
                        focusNode: _participantFocusNode,
                        decoration: InputDecoration(
                          hintText: 'wizard_participant_hint'.tr(),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_add_outlined),
                          counterText: '',
                        ),
                        maxLength: FormValidators.participantNameMax,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addParticipant(),
                      ),
                    ),
                    const SizedBox(width: ThemeConfig.spacingS),
                    FilledButton.tonal(
                      focusNode: _addParticipantButtonFocusNode,
                      onPressed: _addParticipant,
                      child: Text('wizard_add'.tr()),
                    ),
                  ],
                ),
                const SizedBox(height: ThemeConfig.spacingS),
                Text(
                  'wizard_participants_hint'.tr(),
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
  // STEP 3 — Icon & Color
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3IconColor(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitleKey = widget.isPersonal
        ? 'wizard_step3_subtitle_personal'
        : 'wizard_step3_subtitle';
    final tileAnim = UiPerf.preferInstantShellTabs
        ? Duration.zero
        : ThemeConfig.animationShort;

    return WizardStepEnter(
      child: ListView(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        children: [
          const SizedBox(height: ThemeConfig.spacingM),
          _stepTitleBlock(
            titleKey: 'wizard_step3_title',
            subtitleKey: subtitleKey,
          ),
          const SizedBox(height: ThemeConfig.spacingL),

          GroupSectionHeader(label: 'wizard_icon_label'.tr()),
          const SizedBox(height: ThemeConfig.spacingM),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: groupIcons.length,
            itemBuilder: (context, index) {
              final opt = groupIcons[index];
              final isSelected = _selectedIcon == opt.key;
              return Material(
                color: isSelected
                    ? _selectedColor.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                child: InkWell(
                  borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                  onTap: () => setState(() => _selectedIcon = opt.key),
                  child: AnimatedContainer(
                    duration: tileAnim,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                      border: Border.all(
                        color: isSelected
                            ? _selectedColor
                            : colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
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
                              ? _selectedColor
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt.labelKey.tr(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected
                                ? _selectedColor
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

          GroupSectionHeader(label: 'wizard_color_label'.tr()),
          const SizedBox(height: ThemeConfig.spacingM),
          GroupColorPicker(
            selectedColor: _selectedColor,
            onColorSelected: (color) => setState(() => _selectedColor = color),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 4 — Summary
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4Summary(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconDef = groupIcons.where((g) => g.key == _selectedIcon).firstOrNull;
    final totalParticipants = 1 + _participants.length; // owner + added

    return WizardStepEnter(
      child: ListView(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        children: [
          const SizedBox(height: ThemeConfig.spacingM),
          _stepTitleBlock(
            titleKey: 'wizard_step4_title',
            subtitleKey: 'wizard_step4_subtitle',
          ),
          const SizedBox(height: ThemeConfig.spacingL),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ThemeConfig.spacingL),
            decoration: AccentSurfaces.panel(
              colorScheme,
              subtle: context.subtleAccents,
              accentContainer: _selectedColor.withValues(alpha: 0.35),
              accentBorder: _selectedColor,
              radius: ThemeConfig.radiusXL,
            ),
            child: Column(
              children: [
                Builder(
                  builder: (_) {
                    final fgOnColor = ThemeConfig.foregroundOnBackground(
                      _selectedColor,
                    );
                    return CircleAvatar(
                      radius: 40,
                      backgroundColor: _selectedColor,
                      child:
                          iconDef != null && iconDef.key != groupIconLetterKey
                          ? Icon(iconDef.icon, size: 40, color: fgOnColor)
                          : Text(
                              _nameController.text.trim().isNotEmpty
                                  ? _nameController.text.trim()[0].toUpperCase()
                                  : '?',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: fgOnColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(height: ThemeConfig.spacingM),
                UserText(
                  _nameController.text.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ThemeConfig.spacingL),
                const Divider(),
                const SizedBox(height: ThemeConfig.spacingS),

                _SummaryRow(
                  icon: Icons.attach_money,
                  label: 'currency'.tr(),
                  value: CurrencyHelpers.shortLabel(_selectedCurrency),
                  onEdit: () => _goToPage(0),
                ),
                if (widget.isPersonal) ...[
                  const SizedBox(height: ThemeConfig.spacingM),
                  Builder(
                    builder: (_) {
                      final budgetCents = _budgetAmountCentsFromField();
                      return _SummaryRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'my_budget'.tr(),
                        value: budgetCents != null
                            ? CurrencyFormatter.formatCentsAsWholeUnits(
                                budgetCents,
                                _selectedCurrency.code,
                              )
                            : '—',
                        onEdit: () => _goToPage(0),
                      );
                    },
                  ),
                ],
                const SizedBox(height: ThemeConfig.spacingM),

                _SummaryRow(
                  icon: Icons.people_outline,
                  label: 'participants'.tr(),
                  value: widget.isPersonal ? '1' : '$totalParticipants',
                  onEdit: () => _goToPage(widget.isPersonal ? 0 : 1),
                ),
                if (!widget.isPersonal && _participants.isNotEmpty) ...[
                  const SizedBox(height: ThemeConfig.spacingS),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _participants
                        .map(
                          (p) => Chip(
                            label: UserText(p),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: ThemeConfig.spacingM),

                if (_selectedIcon != null) ...[
                  _SummaryRow(
                    icon: iconDef?.icon ?? Icons.grid_view_rounded,
                    label: 'wizard_icon_label'.tr(),
                    value: iconDef?.labelKey.tr() ?? '',
                    onEdit: () => _goToPage(widget.isPersonal ? 1 : 2),
                  ),
                  const SizedBox(height: ThemeConfig.spacingM),
                ],

                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: ThemeConfig.spacingS),
                    Text(
                      'wizard_color_label'.tr(),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _goToPage(widget.isPersonal ? 1 : 2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (!widget.isPersonal) ...[
                  const SizedBox(height: ThemeConfig.spacingM),
                  _SummaryRow(
                    icon: Icons.account_balance_outlined,
                    label: 'settlement_method'.tr(),
                    value: settlementMethodLabel(_settlementMethod),
                    onEdit: () => _goToPage(0),
                  ),
                  if (_settlementMethod == SettlementMethod.treasurer) ...[
                    const SizedBox(height: ThemeConfig.spacingS),
                    _SummaryRow(
                      icon: Icons.person_pin_circle_outlined,
                      label: 'select_treasurer'.tr(),
                      value: _treasurerDisplayName(),
                      onEdit: () => _goToPage(0),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsPanel(BuildContext context, {required bool dense}) {
    return _formPanel(
      child: Column(
        children: [
          _permissionSwitch(
            titleKey: 'allow_add_expense',
            value: _allowMemberAddExpense,
            dense: dense,
            onChanged: (v) => setState(() => _allowMemberAddExpense = v),
          ),
          _permissionSwitch(
            titleKey: 'allow_change_settings',
            value: _allowMemberChangeSettings,
            dense: dense,
            onChanged: (v) => setState(() => _allowMemberChangeSettings = v),
          ),
          _permissionSwitch(
            titleKey: 'allow_expense_as_other',
            value: _allowExpenseAsOtherParticipant,
            dense: dense,
            onChanged: (v) =>
                setState(() => _allowExpenseAsOtherParticipant = v),
          ),
          _permissionSwitch(
            titleKey: 'allow_settle_for_others',
            value: _allowMemberSettleForOthers,
            dense: dense,
            onChanged: (v) => setState(() => _allowMemberSettleForOthers = v),
          ),
        ],
      ),
    );
  }

  Widget _permissionSwitch({
    required String titleKey,
    required bool value,
    required bool dense,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      title: Text(titleKey.tr(), maxLines: 3, overflow: TextOverflow.ellipsis),
      value: value,
      onChanged: onChanged,
    );
  }

  /// Owner display name for the treasurer picker (create-time, before save).
  String _ownerTreasurerLabel() {
    final user = ref.read(authServiceProvider).currentUser;
    final raw =
        user?.userMetadata?['display_name'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        user?.email;
    final trimmed = raw?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return 'default_owner_name'.tr();
  }

  String _treasurerDisplayName() {
    final selected = _treasurerParticipantName?.trim();
    if (selected != null &&
        selected.isNotEmpty &&
        _participants.contains(selected)) {
      return selected;
    }
    return _ownerTreasurerLabel();
  }

  void _syncTreasurerSelection() {
    final selected = _treasurerParticipantName?.trim();
    if (selected != null &&
        selected.isNotEmpty &&
        !_participants.contains(selected)) {
      _treasurerParticipantName = null;
    }
  }

  Widget _buildTreasurerPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    _syncTreasurerSelection();
    final valueLabel = _treasurerDisplayName();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'select_treasurer'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ThemeConfig.spacingS),
        Semantics(
          button: true,
          label: '${'select_treasurer'.tr()}: $valueLabel',
          child: _buildSelectableFlatRow(
            context,
            onTap: _showTreasurerPicker,
            child: Row(
              children: [
                Expanded(
                  child: Text(valueLabel, style: theme.textTheme.titleMedium),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTreasurerPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _syncTreasurerSelection();
    final theme = Theme.of(context);
    final ownerLabel = _ownerTreasurerLabel();
    // Use a wrapper so barrier-dismiss (null) ≠ explicit owner selection.
    final chosen = await showResponsiveSheet<_TreasurerPick>(
      context: context,
      title: 'select_treasurer'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'select_treasurer'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SheetOptionList(
                    children: [
                      SheetOptionTile(
                        title: ownerLabel,
                        selected: _treasurerParticipantName == null,
                        onTap: () =>
                            Navigator.pop(ctx, const _TreasurerPick.owner()),
                      ),
                      for (final name in _participants)
                        SheetOptionTile(
                          title: name,
                          selected: _treasurerParticipantName == name,
                          onTap: () =>
                              Navigator.pop(ctx, _TreasurerPick.named(name)),
                        ),
                    ],
                  ),
                  const SizedBox(height: ThemeConfig.spacingM),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    setState(() => _treasurerParticipantName = chosen.name);
  }

  void _goToPage(int page) {
    _animateToPage(page);
  }
}

/// Sheet result for treasurer picker (distinguishes dismiss from owner pick).
class _TreasurerPick {
  final String? name;
  const _TreasurerPick.owner() : name = null;
  const _TreasurerPick.named(this.name);
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary row widget
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: ThemeConfig.spacingS),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
