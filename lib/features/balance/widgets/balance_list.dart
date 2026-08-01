import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/utils/error_report_helper.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/group_member_provider.dart';
import '../../groups/widgets/group_section_header.dart';
import '../providers/balance_provider.dart';
import 'record_settlement_sheet.dart';

/// Cap for the sticky settle-up preview so balance content stays readable.
const double _kSettleOverlayMaxHeightFraction = 0.32;

/// Peek rows in the docked overlay; full list lives in the Settle Up section.
const int _kSettleOverlayPeekCount = 1;

class BalanceList extends ConsumerWidget {
  final String groupId;
  final Future<void> Function()? onRefresh;
  final bool readOnlyMode;

  const BalanceList({
    super.key,
    required this.groupId,
    this.onRefresh,
    this.readOnlyMode = false,
  });

  static int _compareBalances(ParticipantBalance a, ParticipantBalance b) {
    final ac = a.balanceCents;
    final bc = b.balanceCents;
    if (ac >= 0 && bc < 0) return -1;
    if (ac < 0 && bc >= 0) return 1;
    if (ac >= 0 && bc >= 0) return bc.compareTo(ac);
    return ac.compareTo(bc);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(groupBalanceProvider(groupId));
    final myMemberAsync = ref.watch(myMemberInGroupProvider(groupId));
    final myRoleAsync = ref.watch(myRoleInGroupProvider(groupId));

    return balanceAsync.when(
      data: (result) {
        if (result == null) {
          return Center(child: Text('group_not_found'.tr()));
        }
        final group = result.group;
        final participants = result.participants;
        final balances = result.balances;
        final settlements = result.settlements;

        final myMember = myMemberAsync.hasValue ? myMemberAsync.value : null;
        final myRole = myRoleAsync.hasValue ? myRoleAsync.value : null;
        final myParticipantId = myMember?.participantId;
        final showHero = myParticipantId != null && myParticipantId.isNotEmpty;

        final sortedBalances = List<ParticipantBalance>.from(balances)
          ..sort(_compareBalances);
        final visibleBalances = sortedBalances
            .where((b) => b.balanceCents != 0)
            .toList();
        final groupBalances = showHero
            ? visibleBalances
                  .where((b) => b.participantId != myParticipantId)
                  .toList()
            : visibleBalances;

        ParticipantBalance? myBalance;
        if (showHero) {
          for (final b in balances) {
            if (b.participantId == myParticipantId) {
              myBalance = b;
              break;
            }
          }
          myBalance ??= ParticipantBalance(
            participantId: myParticipantId,
            balanceCents: 0,
            currencyCode: group.currencyCode,
          );
        }

        bool canRecordSettlement(SettlementTransaction s) {
          if (readOnlyMode) return false;
          if (group.isArchived) return false;
          if (group.isSettlementFrozen) return false;
          if (group.allowMemberSettleForOthers) return true;
          if (myRole == GroupRole.owner) return true;
          if (myMember?.participantId == s.fromParticipantId) return true;
          return false;
        }

        final nameOf = {for (final p in participants) p.id: p.name};
        final avatarOf = {for (final p in participants) p.id: p.avatarId};
        final hasFrozen = group.isSettlementFrozen || group.isArchived;

        return _BalanceListBody(
          groupId: groupId,
          currencyCode: group.currencyCode,
          settlementMethod: group.settlementMethod,
          settlements: settlements,
          myParticipantId: myParticipantId,
          myBalance: myBalance,
          showHero: showHero,
          groupBalances: groupBalances,
          nameOf: nameOf,
          avatarOf: avatarOf,
          hasFrozen: hasFrozen,
          readOnlyMode: readOnlyMode,
          onRefresh: onRefresh,
          canRecordSettlement: canRecordSettlement,
          onUnfreeze: () => context.push(RoutePaths.groupSettings(groupId)),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        sendErrorTelemetryIfOnline(
          ref,
          message: e.toString(),
          details: e.toString(),
        );
        return Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(groupBalanceProvider(groupId)),
          ),
        );
      },
    );
  }
}

class _BalanceListBody extends StatefulWidget {
  final String groupId;
  final String currencyCode;
  final SettlementMethod settlementMethod;
  final List<SettlementTransaction> settlements;
  final String? myParticipantId;
  final ParticipantBalance? myBalance;
  final bool showHero;
  final List<ParticipantBalance> groupBalances;
  final Map<String, String> nameOf;
  final Map<String, String?> avatarOf;
  final bool hasFrozen;
  final bool readOnlyMode;
  final Future<void> Function()? onRefresh;
  final bool Function(SettlementTransaction) canRecordSettlement;
  final VoidCallback onUnfreeze;

  const _BalanceListBody({
    required this.groupId,
    required this.currencyCode,
    required this.settlementMethod,
    required this.settlements,
    required this.myParticipantId,
    required this.myBalance,
    required this.showHero,
    required this.groupBalances,
    required this.nameOf,
    required this.avatarOf,
    required this.hasFrozen,
    required this.readOnlyMode,
    required this.onRefresh,
    required this.canRecordSettlement,
    required this.onUnfreeze,
  });

  @override
  State<_BalanceListBody> createState() => _BalanceListBodyState();
}

class _BalanceListBodyState extends State<_BalanceListBody> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _settleSectionKey = GlobalKey();
  final GlobalKey _overlayKey = GlobalKey();
  final ValueNotifier<double> _handoff = ValueNotifier<double>(0);
  double _overlayHeight = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateHandoff);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHandoff());
  }

  @override
  void didUpdateWidget(covariant _BalanceListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHandoff());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateHandoff);
    _scrollController.dispose();
    _handoff.dispose();
    super.dispose();
  }

  List<SettlementTransaction> _mySettlements() {
    final myId = widget.myParticipantId;
    if (myId == null) return const [];
    final mine = widget.settlements
        .where(
          (s) =>
              s.fromParticipantId == myId || s.toParticipantId == myId,
        )
        .toList();
    mine.sort((a, b) {
      int rank(SettlementTransaction s) {
        if (s.fromParticipantId == myId) return 0;
        return 1;
      }

      final rankCmp = rank(a).compareTo(rank(b));
      if (rankCmp != 0) return rankCmp;
      return b.amountCents.compareTo(a.amountCents);
    });
    return mine;
  }

  void _updateHandoff() {
    final settleCtx = _settleSectionKey.currentContext;
    if (settleCtx == null) {
      if (_handoff.value != 0) _handoff.value = 0;
      return;
    }
    final settleBox = settleCtx.findRenderObject() as RenderBox?;
    final bodyBox = context.findRenderObject() as RenderBox?;
    if (settleBox == null ||
        bodyBox == null ||
        !settleBox.hasSize ||
        !bodyBox.hasSize ||
        !settleBox.attached) {
      return;
    }

    final overlayCtx = _overlayKey.currentContext;
    if (overlayCtx != null) {
      final overlayBox = overlayCtx.findRenderObject() as RenderBox?;
      if (overlayBox != null && overlayBox.hasSize) {
        final h = overlayBox.size.height;
        if ((h - _overlayHeight).abs() > 0.5 && mounted) {
          setState(() => _overlayHeight = h);
        }
      }
    }

    final overlayH = _overlayHeight;
    if (overlayH <= 0) {
      // Still measuring — keep the preview fully docked.
      if (_handoff.value != 0) _handoff.value = 0;
      return;
    }

    // Use the body's bottom as the dock, not the translated overlay origin
    // (translation would feedback into progress and jitter).
    final settleTop = settleBox.localToGlobal(Offset.zero).dy;
    final dockTop =
        bodyBox.localToGlobal(Offset(0, bodyBox.size.height)).dy - overlayH;
    final progress = ((dockTop - settleTop) / overlayH).clamp(0.0, 1.0);
    if ((progress - _handoff.value).abs() > 0.004) {
      _handoff.value = progress;
    }
  }

  Future<void> _scrollToSettleUp() async {
    final ctx = _settleSectionKey.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: UiPerf.preferReducedChromeMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
    _updateHandoff();
  }

  @override
  Widget build(BuildContext context) {
    final mySettlements = _mySettlements();
    final showOverlay = mySettlements.isNotEmpty;
    // Overlay height already includes any safe-area padding it applies.
    final overlayReserve = showOverlay
        ? (_overlayHeight > 0 ? _overlayHeight : 168.0)
        : 0.0;

    final children = <Widget>[];

    if (widget.hasFrozen) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _FrozenBanner(
            readOnlyMode: widget.readOnlyMode,
            onUnfreeze: widget.onUnfreeze,
          ),
        ),
      );
    }

    if (widget.showHero && widget.myBalance != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _YourBalanceHero(
            balanceCents: widget.myBalance!.balanceCents,
            currencyCode: widget.currencyCode,
          ),
        ),
      );
    }

    if (widget.groupBalances.isNotEmpty || !widget.showHero) {
      children.add(
        GroupSectionHeader(
          label: widget.showHero ? 'everyone_else'.tr() : 'balance'.tr(),
        ),
      );
      children.add(const SizedBox(height: 10));
      if (widget.groupBalances.isEmpty) {
        children.add(
          _SettledHintCard(
            message: 'all_settled'.tr(),
            icon: Icons.check_circle_outline_rounded,
          ),
        );
      } else {
        for (final b in widget.groupBalances) {
          final name = widget.nameOf[b.participantId] ?? b.participantId;
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BalancePersonCard(
                name: name,
                avatarId: widget.avatarOf[b.participantId],
                balanceCents: b.balanceCents,
                currencyCode: widget.currencyCode,
              ),
            ),
          );
        }
      }
    }

    children.add(
      Padding(
        key: _settleSectionKey,
        padding: EdgeInsets.only(
          top: widget.groupBalances.isNotEmpty || !widget.showHero ? 12 : 0,
        ),
        child: _SettleUpSection(
          groupId: widget.groupId,
          currencyCode: widget.currencyCode,
          settlements: widget.settlements,
          settlementMethod: widget.settlementMethod,
          myParticipantId: widget.myParticipantId,
          nameOf: widget.nameOf,
          avatarOf: widget.avatarOf,
          readOnlyMode: widget.readOnlyMode,
          hasFrozen: widget.hasFrozen,
          canRecordSettlement: widget.canRecordSettlement,
        ),
      ),
    );

    final listView = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          _updateHandoff();
        }
        return false;
      },
      child: ListView(
        key: const ValueKey<String>('balance_list_scroll'),
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + overlayReserve),
        children: children,
      ),
    );

    final scrollable = widget.onRefresh != null
        ? RefreshIndicator(onRefresh: widget.onRefresh!, child: listView)
        : listView;

    if (!showOverlay) {
      return scrollable;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxOverlayHeight =
            constraints.maxHeight * _kSettleOverlayMaxHeightFraction;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            scrollable,
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<double>(
                valueListenable: _handoff,
                builder: (context, progress, child) {
                  final t = Curves.easeOutCubic.transform(progress);
                  // Collapse toward the docked bottom edge so Settle Up can
                  // replace the peek without a double-painted flash.
                  return IgnorePointer(
                    ignoring: t > 0.92,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: (1.0 - t).clamp(0.0, 1.0),
                        child: child,
                      ),
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: _overlayKey,
                  child: _SettlementBottomOverlay(
                    myParticipantId: widget.myParticipantId!,
                    settlements: mySettlements,
                    currencyCode: widget.currencyCode,
                    nameOf: widget.nameOf,
                    avatarOf: widget.avatarOf,
                    readOnlyMode: widget.readOnlyMode,
                    hasFrozen: widget.hasFrozen,
                    canRecordSettlement: widget.canRecordSettlement,
                    groupId: widget.groupId,
                    maxHeight: maxOverlayHeight,
                    onOpenSettleUp: _scrollToSettleUp,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sticky preview of the current user's settle-up transfers.
class _SettlementBottomOverlay extends ConsumerWidget {
  final String groupId;
  final String myParticipantId;
  final List<SettlementTransaction> settlements;
  final String currencyCode;
  final Map<String, String> nameOf;
  final Map<String, String?> avatarOf;
  final bool readOnlyMode;
  final bool hasFrozen;
  final bool Function(SettlementTransaction) canRecordSettlement;
  final double maxHeight;
  final VoidCallback onOpenSettleUp;

  const _SettlementBottomOverlay({
    required this.groupId,
    required this.myParticipantId,
    required this.settlements,
    required this.currencyCode,
    required this.nameOf,
    required this.avatarOf,
    required this.readOnlyMode,
    required this.hasFrozen,
    required this.canRecordSettlement,
    required this.maxHeight,
    required this.onOpenSettleUp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    var oweCents = 0;
    var owedCents = 0;
    for (final s in settlements) {
      if (s.fromParticipantId == myParticipantId) {
        oweCents += s.amountCents;
      } else {
        owedCents += s.amountCents;
      }
    }

    final peek = settlements.take(_kSettleOverlayPeekCount).toList();
    final moreCount = settlements.length - peek.length;

    final shadow = UiPerf.preferCheapShadows
        ? <BoxShadow>[
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ]
        : <BoxShadow>[
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          boxShadow: shadow,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenSettleUp,
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'settle_up'.tr(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (oweCents > 0)
                          _OverlayTotalChip(
                            label: 'you_owe'.tr(),
                            amountCents: oweCents,
                            currencyCode: currencyCode,
                            color: colorScheme.error,
                          ),
                        if (oweCents > 0 && owedCents > 0)
                          const SizedBox(width: 8),
                        if (owedCents > 0)
                          _OverlayTotalChip(
                            label: 'you_are_owed'.tr(),
                            amountCents: owedCents,
                            currencyCode: currencyCode,
                            color: colorScheme.primary,
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Non-scrollable peek — avoids nested ListView fighting the page scroll.
              for (var i = 0; i < peek.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final s = peek[i];
                    final iPay = s.fromParticipantId == myParticipantId;
                    final otherId =
                        iPay ? s.toParticipantId : s.fromParticipantId;
                    final otherName = nameOf[otherId] ?? otherId;
                    final from =
                        nameOf[s.fromParticipantId] ?? s.fromParticipantId;
                    final to = nameOf[s.toParticipantId] ?? s.toParticipantId;
                    final canRecord = canRecordSettlement(s);
                    return _OverlaySettlementRow(
                      iPay: iPay,
                      otherName: otherName,
                      otherAvatarId: avatarOf[otherId],
                      settlement: s,
                      canRecord: canRecord,
                      readOnlyMode: readOnlyMode,
                      hasFrozen: hasFrozen,
                      onRecord: () => showRecordSettlementSheet(
                        context,
                        ref,
                        groupId: groupId,
                        currencyCode: currencyCode,
                        settlement: s,
                        fromName: from,
                        toName: to,
                        fromAvatarId: avatarOf[s.fromParticipantId],
                        toAvatarId: avatarOf[s.toParticipantId],
                      ),
                    );
                  },
                ),
              ],
              if (moreCount > 0) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenSettleUp,
                  child: Text(
                    'settle_overlay_more'.tr(
                      namedArgs: {'count': '$moreCount'},
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact settle row for the sticky overlay — omits the current user name.
class _OverlaySettlementRow extends StatelessWidget {
  final bool iPay;
  final String otherName;
  final String? otherAvatarId;
  final SettlementTransaction settlement;
  final bool canRecord;
  final bool readOnlyMode;
  final bool hasFrozen;
  final VoidCallback onRecord;

  const _OverlaySettlementRow({
    required this.iPay,
    required this.otherName,
    this.otherAvatarId,
    required this.settlement,
    required this.canRecord,
    required this.readOnlyMode,
    required this.hasFrozen,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = iPay ? colorScheme.error : colorScheme.primary;
    final action = iPay ? 'settle_pay'.tr() : 'settle_receive'.tr();
    final canTap = !hasFrozen && !readOnlyMode && canRecord;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canTap ? onRecord : null,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              ParticipantAvatar(
                name: otherName,
                avatarId: otherAvatarId,
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.14),
                foregroundColor: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    UserText(
                      otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AmountWithSecondaryDisplay(
                amountCents: settlement.amountCents,
                groupCurrencyCode: settlement.currencyCode,
                primaryStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
                showSecondary: false,
              ),
              if (!readOnlyMode)
                Semantics(
                  label: canRecord
                      ? 'record_settlement'.tr()
                      : 'record_settlement_restricted'.tr(),
                  button: true,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.payments_outlined,
                      color: canRecord
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: canRecord
                        ? 'record_settlement'.tr()
                        : 'record_settlement_restricted'.tr(),
                    onPressed: canRecord ? onRecord : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayTotalChip extends StatelessWidget {
  final String label;
  final int amountCents;
  final String currencyCode;
  final Color color;

  const _OverlayTotalChip({
    required this.label,
    required this.amountCents,
    required this.currencyCode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          AmountWithSecondaryDisplay(
            amountCents: amountCents,
            groupCurrencyCode: currencyCode,
            primaryStyle: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
            showSecondary: false,
          ),
        ],
      ),
    );
  }
}

class _YourBalanceHero extends StatelessWidget {
  final int balanceCents;
  final String currencyCode;

  const _YourBalanceHero({
    required this.balanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEven = balanceCents == 0;
    final isPositive = balanceCents > 0;
    final accent = isEven
        ? colorScheme.primary
        : isPositive
        ? colorScheme.primary
        : colorScheme.error;
    final label = isEven
        ? 'you_are_even'.tr()
        : isPositive
        ? 'you_are_owed'.tr()
        : 'you_owe'.tr();
    final amountStyle =
        theme.textTheme.headlineSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ) ??
        TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 24);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: context.subtleAccents,
        accentContainer: isEven
            ? null
            : isPositive
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        accentBorder: isEven ? null : accent,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          if (!isEven)
            AmountWithSecondaryDisplay(
              amountCents: balanceCents.abs(),
              groupCurrencyCode: currencyCode,
              primaryStyle: amountStyle,
            ),
        ],
      ),
    );
  }
}

class _FrozenBanner extends StatelessWidget {
  final bool readOnlyMode;
  final VoidCallback onUnfreeze;

  const _FrozenBanner({
    required this.readOnlyMode,
    required this.onUnfreeze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 12, 14),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: context.subtleAccents,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause_circle_filled_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settlement_frozen'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'settlement_frozen_hint'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: readOnlyMode ? null : onUnfreeze,
              child: Text('unfreeze_settlement'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettledHintCard extends StatelessWidget {
  final String message;
  final IconData icon;

  const _SettledHintCard({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: AccentSurfaces.flatPanel(colorScheme),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancePersonCard extends StatelessWidget {
  final String name;
  final String? avatarId;
  final int balanceCents;
  final String currencyCode;

  const _BalancePersonCard({
    required this.name,
    this.avatarId,
    required this.balanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPositive = balanceCents >= 0;
    final color = isPositive ? colorScheme.primary : colorScheme.error;
    final status = isPositive ? 'balance_is_owed'.tr() : 'balance_owes'.tr();
    final amountStyle =
        theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(color: color, fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: AccentSurfaces.flatPanel(colorScheme),
      child: Row(
        children: [
          ParticipantAvatar(
            name: name,
            avatarId: avatarId,
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserText(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          AmountWithSecondaryDisplay(
            amountCents: balanceCents.abs(),
            groupCurrencyCode: currencyCode,
            primaryStyle: amountStyle,
            isNegative: !isPositive,
          ),
        ],
      ),
    );
  }
}

enum _SettleFilter { me, all }

class _SettleUpSection extends ConsumerStatefulWidget {
  final String groupId;
  final String currencyCode;
  final List<SettlementTransaction> settlements;
  final SettlementMethod settlementMethod;
  final String? myParticipantId;
  final Map<String, String> nameOf;
  final Map<String, String?> avatarOf;
  final bool readOnlyMode;
  final bool hasFrozen;
  final bool Function(SettlementTransaction) canRecordSettlement;

  const _SettleUpSection({
    required this.groupId,
    required this.currencyCode,
    required this.settlements,
    required this.settlementMethod,
    required this.myParticipantId,
    required this.nameOf,
    required this.avatarOf,
    required this.readOnlyMode,
    required this.hasFrozen,
    required this.canRecordSettlement,
  });

  @override
  ConsumerState<_SettleUpSection> createState() => _SettleUpSectionState();
}

class _SettleUpSectionState extends ConsumerState<_SettleUpSection> {
  late _SettleFilter _filter;

  /// Ensures we default to Me once when the linked participant becomes known
  /// (member stream can resolve after the first frame).
  bool _appliedLinkedDefault = false;

  @override
  void initState() {
    super.initState();
    final linked = widget.myParticipantId != null;
    _filter = linked ? _SettleFilter.me : _SettleFilter.all;
    _appliedLinkedDefault = linked;
  }

  @override
  void didUpdateWidget(covariant _SettleUpSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.myParticipantId == null) {
      if (_filter == _SettleFilter.me) _filter = _SettleFilter.all;
      _appliedLinkedDefault = false;
    } else if (!_appliedLinkedDefault) {
      _filter = _SettleFilter.me;
      _appliedLinkedDefault = true;
    }
  }

  static String _methodHint(SettlementMethod method) {
    switch (method) {
      case SettlementMethod.greedy:
        return 'settle_up_hint_greedy'.tr();
      case SettlementMethod.pairwise:
        return 'settle_up_hint_pairwise'.tr();
      case SettlementMethod.consolidated:
        return 'settle_up_hint_consolidated'.tr();
      case SettlementMethod.treasurer:
        return 'settle_up_hint_treasurer'.tr();
    }
  }

  List<SettlementTransaction> _sorted(List<SettlementTransaction> input) {
    final myId = widget.myParticipantId;
    int rank(SettlementTransaction s) {
      if (myId == null) return 2;
      if (s.fromParticipantId == myId) return 0; // you pay
      if (s.toParticipantId == myId) return 1; // you receive
      return 2;
    }

    final list = List<SettlementTransaction>.from(input);
    list.sort((a, b) {
      final rankCmp = rank(a).compareTo(rank(b));
      if (rankCmp != 0) return rankCmp;
      return b.amountCents.compareTo(a.amountCents);
    });
    return list;
  }

  List<SettlementTransaction> _filtered(List<SettlementTransaction> sorted) {
    final myId = widget.myParticipantId;
    if (_filter != _SettleFilter.me || myId == null) return sorted;
    return sorted
        .where(
          (s) =>
              s.fromParticipantId == myId || s.toParticipantId == myId,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canFilterMe = widget.myParticipantId != null;
    final sorted = _sorted(widget.settlements);
    final visible = _filtered(sorted);
    final showHint = widget.settlements.isNotEmpty;

    final showFilter = canFilterMe && widget.settlements.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupSectionHeader(
          label: 'settle_up'.tr(),
          trailing: showFilter
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SettleFilterChip(
                      label: 'settle_filter_me'.tr(),
                      selected: _filter == _SettleFilter.me,
                      onSelected: () =>
                          setState(() => _filter = _SettleFilter.me),
                    ),
                    const SizedBox(width: 6),
                    _SettleFilterChip(
                      label: 'settle_filter_all'.tr(),
                      selected: _filter == _SettleFilter.all,
                      onSelected: () =>
                          setState(() => _filter = _SettleFilter.all),
                    ),
                  ],
                )
              : null,
        ),
        if (showHint) ...[
          const SizedBox(height: 6),
          Text(
            _methodHint(widget.settlementMethod),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (widget.settlements.isEmpty)
          _SettledHintCard(
            message: 'all_settled'.tr(),
            icon: Icons.check_circle_outline_rounded,
          )
        else if (visible.isEmpty)
          _SettledHintCard(
            message: 'settle_up_none_for_me'.tr(),
            icon: Icons.person_outline_rounded,
          )
        else
          ...visible.map((s) {
            final from =
                widget.nameOf[s.fromParticipantId] ?? s.fromParticipantId;
            final to = widget.nameOf[s.toParticipantId] ?? s.toParticipantId;
            final canRecord = widget.canRecordSettlement(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SettlementCard(
                fromName: from,
                toName: to,
                fromAvatarId: widget.avatarOf[s.fromParticipantId],
                toAvatarId: widget.avatarOf[s.toParticipantId],
                settlement: s,
                canRecord: canRecord,
                readOnlyMode: widget.readOnlyMode,
                hasFrozen: widget.hasFrozen,
                onRecord: () => showRecordSettlementSheet(
                  context,
                  ref,
                  groupId: widget.groupId,
                  currencyCode: widget.currencyCode,
                  settlement: s,
                  fromName: from,
                  toName: to,
                  fromAvatarId: widget.avatarOf[s.fromParticipantId],
                  toAvatarId: widget.avatarOf[s.toParticipantId],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Compact filter chip sized for the Settle Up section header row.
class _SettleFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _SettleFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: EdgeInsets.zero,
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final String fromName;
  final String toName;
  final String? fromAvatarId;
  final String? toAvatarId;
  final SettlementTransaction settlement;
  final bool canRecord;
  final bool readOnlyMode;
  final bool hasFrozen;
  final VoidCallback onRecord;

  const _SettlementCard({
    required this.fromName,
    required this.toName,
    this.fromAvatarId,
    this.toAvatarId,
    required this.settlement,
    required this.canRecord,
    required this.readOnlyMode,
    required this.hasFrozen,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = settlement;
    final canTap = !hasFrozen && !readOnlyMode && canRecord;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canTap ? onRecord : null,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettlementNameChip(
                      name: fromName,
                      avatarId: fromAvatarId,
                    ),
                    const SizedBox(height: 6),
                    _SettlementNameChip(
                      name: toName,
                      avatarId: toAvatarId,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AmountWithSecondaryDisplay(
                amountCents: s.amountCents,
                groupCurrencyCode: s.currencyCode,
                primaryStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                showSecondary: false,
              ),
              if (!readOnlyMode)
                Semantics(
                  label: canRecord
                      ? 'record_settlement'.tr()
                      : 'record_settlement_restricted'.tr(),
                  button: true,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.payments_outlined,
                      color: canRecord
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: canRecord
                        ? 'record_settlement'.tr()
                        : 'record_settlement_restricted'.tr(),
                    onPressed: canRecord ? onRecord : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact avatar + single-line ellipsized name for settle-up rows.
class _SettlementNameChip extends StatelessWidget {
  final String name;
  final String? avatarId;

  const _SettlementNameChip({
    required this.name,
    this.avatarId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        ParticipantAvatar(
          name: name,
          avatarId: avatarId,
          radius: 14,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: colorScheme.primary,
          textStyle: theme.textTheme.labelMedium,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: UserText(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
