import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/navigation/decorative_route.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/expense_display_title.dart';
import '../../../core/utils/user_text.dart';
import '../../../domain/domain.dart';
import '../../balance/providers/balance_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../widgets/expense_detail_body.dart';

/// Shell for expense detail: fixed app bar and interactive prev/next paging.
///
/// Adjacent expenses are built in a [PageView] so the swipe gesture reveals the
/// next/previous expense live (not a velocity-only jump). The address bar is
/// updated via [syncDecorativeRoutePath] without remounting this shell.
class ExpenseDetailShell extends ConsumerStatefulWidget {
  final String groupId;
  final String expenseId;
  final Widget child;
  final bool readOnlyPreview;
  final String? previewToken;

  const ExpenseDetailShell({
    super.key,
    required this.groupId,
    required this.expenseId,
    required this.child,
    this.readOnlyPreview = false,
    this.previewToken,
  });

  @override
  ConsumerState<ExpenseDetailShell> createState() => _ExpenseDetailShellState();
}

class _ExpenseDetailShellState extends ConsumerState<ExpenseDetailShell>
    with TickerProviderStateMixin {
  PageController? _pageController;
  List<String> _pageIds = const [];
  String? _viewingExpenseId;

  AnimationController? _enterController;
  Animation<Offset>? _enterSlide;
  Animation<double>? _enterFade;
  bool _pendingEnter = true;
  bool _hasPlayedEnter = false;

  /// True while [onPageChanged] is syncing URL — skip remount reactions.
  bool _syncingFromPageView = false;

  @override
  void initState() {
    super.initState();
    _viewingExpenseId = widget.expenseId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final parent = widget.readOnlyPreview && widget.previewToken != null
          ? RoutePaths.invitePreviewExpenses(widget.previewToken!)
          : RoutePaths.groupExpenses(widget.groupId);
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: parent,
        currentPath: _pathForExpense(_activeExpenseId),
      );
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _enterController?.dispose();
    super.dispose();
  }

  String get _activeExpenseId => _viewingExpenseId ?? widget.expenseId;

  String _pathForExpense(String expenseId) {
    if (widget.readOnlyPreview && widget.previewToken != null) {
      return RoutePaths.invitePreviewExpenseDetail(
        widget.previewToken!,
        expenseId,
      );
    }
    return RoutePaths.groupExpenseDetail(widget.groupId, expenseId);
  }

  double _subtleEnterDx() {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? -AppMotion.pageSlideFraction : AppMotion.pageSlideFraction;
  }

  void _disposeControllerAfterFrame(AnimationController? controller) {
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  void _runEnterMotion({required double beginDx, required bool withFade}) {
    final previous = _enterController;
    _enterSlide = null;
    _enterFade = null;

    final next = AnimationController(vsync: this, duration: AppMotion.page);
    _enterController = next;
    final curved = next.drive(CurveTween(curve: AppMotion.enterCurve));
    _enterFade = withFade ? curved : null;
    _enterSlide = Tween<Offset>(
      begin: Offset(beginDx, 0),
      end: Offset.zero,
    ).animate(curved);

    _disposeControllerAfterFrame(previous);

    next.forward().then((_) {
      if (!mounted || !identical(_enterController, next)) return;
      setState(() {
        _enterSlide = null;
        _enterFade = null;
        _enterController = null;
      });
      _disposeControllerAfterFrame(next);
    });
  }

  void _startEnterIfNeeded() {
    if (!_pendingEnter || _hasPlayedEnter) return;
    _pendingEnter = false;
    _hasPlayedEnter = true;
    _runEnterMotion(beginDx: _subtleEnterDx(), withFade: true);
    setState(() {});
  }

  void _ensurePageController(List<Expense> sorted, int index) {
    final ids = [for (final e in sorted) e.id];
    final clamped = index.clamp(0, sorted.length - 1);
    if (_pageController == null || !listEquals(_pageIds, ids)) {
      final old = _pageController;
      _pageController = PageController(initialPage: clamped);
      _pageIds = ids;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      return;
    }
    final controller = _pageController!;
    if (!controller.hasClients) return;
    final current = controller.page?.round() ?? controller.initialPage;
    if (current != clamped) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pageController != controller) return;
        if (!controller.hasClients) return;
        final now = controller.page?.round() ?? controller.initialPage;
        if (now != clamped) controller.jumpToPage(clamped);
      });
    }
  }

  void _onPageChanged(int index, List<Expense> sorted) {
    if (index < 0 || index >= sorted.length) return;
    final id = sorted[index].id;
    if (id == _activeExpenseId) return;
    _syncingFromPageView = true;
    setState(() => _viewingExpenseId = id);
    syncDecorativeRoutePath(context, _pathForExpense(id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncingFromPageView = false;
    });
  }

  void _goToAdjacent({
    required bool next,
    required int index,
    required int length,
  }) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final target = next ? index + 1 : index - 1;
    if (target < 0 || target >= length) return;
    controller.animateToPage(
      target,
      duration: AppMotion.page,
      curve: AppMotion.enterCurve,
    );
  }

  @override
  void didUpdateWidget(ExpenseDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expenseId != oldWidget.expenseId && !_syncingFromPageView) {
      _viewingExpenseId = widget.expenseId;
    }
  }

  bool get _awaitingEnter => _pendingEnter && !_hasPlayedEnter;

  bool get _isEnterAnimating => _enterController?.isAnimating == true;

  bool get _blockInteraction => _awaitingEnter || _isEnterAnimating;

  Widget _wrapEnter(Widget child) {
    if (_awaitingEnter) {
      return IgnorePointer(child: Opacity(opacity: 0, child: child));
    }
    Widget result = child;
    if (_enterSlide != null && _enterController != null) {
      result = SlideTransition(position: _enterSlide!, child: result);
    }
    if (_enterFade != null && _enterController != null) {
      result = FadeTransition(opacity: _enterFade!, child: result);
    }
    return ClipRect(child: result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeId = _activeExpenseId;
    // One group-scoped watch for paging + app bar actions — no per-page
    // watchById (avoids N web poll streams while swiping).
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));

    final expensesList = expensesAsync.when(
      data: (l) => l,
      loading: () => null,
      error: (_, _) => null,
    );

    List<Expense>? sorted;
    var index = -1;
    if (expensesList != null) {
      sorted = List<Expense>.from(expensesList)
        ..sort((a, b) => b.date.compareTo(a.date));
      index = sorted.indexWhere((e) => e.id == activeId);
      if (index < 0) {
        index = sorted.indexWhere((e) => e.id == widget.expenseId);
      }
      if (index >= 0) {
        _ensurePageController(sorted, index);
      }
    }

    final Expense? expense =
        sorted != null && index >= 0 && sorted[index].groupId == widget.groupId
        ? sorted[index]
        : null;

    final prevId = sorted != null && index > 0 ? sorted[index - 1].id : null;
    final nextId = sorted != null && index >= 0 && index < sorted.length - 1
        ? sorted[index + 1].id
        : null;

    final pages = sorted;
    final pageController = _pageController;
    final pagingReady = pages != null && index >= 0 && pageController != null;

    void goPrev() {
      if (pages == null) return;
      _goToAdjacent(next: false, index: index, length: pages.length);
    }

    void goNext() {
      if (pages == null) return;
      _goToAdjacent(next: true, index: index, length: pages.length);
    }

    final parentPath = widget.readOnlyPreview && widget.previewToken != null
        ? RoutePaths.invitePreviewExpenses(widget.previewToken!)
        : RoutePaths.groupExpenses(widget.groupId);
    final appBarLeading = IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => popOrGo(context, parentPath),
    );
    final appBarActions = <Widget>[
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: prevId != null && !_blockInteraction ? goPrev : null,
      ),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: nextId != null && !_blockInteraction ? goNext : null,
      ),
      if (!widget.readOnlyPreview)
        PopupMenuButton<String>(
          useRootNavigator: true,
          icon: const Icon(Icons.more_vert),
          enabled: expense != null,
          onSelected: expense != null
              ? (value) async {
                  if (value == 'edit') {
                    await context.push(
                      RoutePaths.groupExpenseEdit(widget.groupId, activeId),
                    );
                    if (context.mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          ref.invalidate(futureExpenseProvider(activeId));
                          ref.invalidate(
                            expensesByGroupProvider(widget.groupId),
                          );
                        }
                      });
                    }
                  } else if (value == 'delete') {
                    _confirmDelete(context, ref, expense);
                  }
                }
              : (_) {},
          itemBuilder: (context) => expense != null
              ? [
                  PopupMenuItem(value: 'edit', child: Text('edit'.tr())),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'delete'.tr(),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ]
              : [
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: SizedBox.shrink(),
                  ),
                ],
        ),
    ];

    final bodyReady = pagingReady || expense != null;

    if (bodyReady && _pendingEnter && !_hasPlayedEnter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startEnterIfNeeded();
      });
    }

    final Widget body;
    if (pagingReady) {
      body = _wrapEnter(
        PageView.builder(
          controller: pageController,
          itemCount: pages.length,
          // Prefetch neighbors for live swipe feedback. Bodies share
          // expensesByGroupProvider — do not keepAlive (that retained
          // visited pages and their work indefinitely).
          allowImplicitScrolling: true,
          onPageChanged: (i) => _onPageChanged(i, pages),
          itemBuilder: (context, i) {
            final id = pages[i].id;
            return ExpenseDetailBody(
              key: ValueKey<String>('expense_page_$id'),
              groupId: widget.groupId,
              expenseId: id,
            );
          },
        ),
      );
    } else if (bodyReady || _hasPlayedEnter) {
      body = _wrapEnter(widget.child);
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    final canPop = routerCanPop(context);
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOrGo(context, parentPath);
      },
      child: LayoutBuilder(
        builder: (context, layoutConstraints) => Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            leading: appBarLeading,
            title: const SizedBox.shrink(),
            actions: appBarActions,
          ),
          body: ConstrainedContent(
            child: IgnorePointer(ignoring: _blockInteraction, child: body),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final participants =
        ref.read(participantsByGroupProvider(widget.groupId)).asData?.value ??
        const <Participant>[];
    final nameOf = {for (final p in participants) p.id: p.name};
    final displayTitle = expenseDisplayTitleFromMap(expense, nameOf);
    final ok = await showConfirmSheet(
      context,
      title: 'delete_expense_confirm'.tr(),
      content:
          '${isolateBidi(displayTitle)} – ${CurrencyFormatter.formatCents(expense.amountCents, expense.currencyCode)}',
      confirmLabel: 'delete'.tr(),
      isDestructive: true,
      centerInFullViewport: true,
    );
    if (ok == true && context.mounted) {
      await ref.read(expenseRepositoryProvider).delete(expense.id);
      ref.invalidate(futureExpenseProvider(expense.id));
      ref.invalidate(expensesByGroupProvider(widget.groupId));
      ref.invalidate(groupBalanceProvider(widget.groupId));
      if (context.mounted) {
        final parent = widget.readOnlyPreview && widget.previewToken != null
            ? RoutePaths.invitePreviewExpenses(widget.previewToken!)
            : RoutePaths.groupExpenses(widget.groupId);
        popOrGo(context, parent);
      }
    }
  }
}
