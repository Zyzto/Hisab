import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/domain.dart';
import '../../balance/providers/balance_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../providers/expense_navigation_direction.dart';

/// Shell for expense detail: fixed app bar and body that slides by direction.
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
  late Widget _displayedChild;
  String? _displayedExpenseId;
  AnimationController? _controller;
  Animation<Offset>? _incomingSlide;
  Animation<double>? _incomingFade;
  bool _pendingEnter = true;
  bool _hasPlayedEnter = false;

  @override
  void initState() {
    super.initState();
    _displayedChild = widget.child;
    _displayedExpenseId = widget.expenseId;
  }

  /// Next (1) enters from the end edge; prev from the start. Flipped in RTL.
  double _slideDxForDirection(int direction) {
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    var dx = direction == 1 ? 1.0 : -1.0;
    if (isRtl) dx = -dx;
    return dx;
  }

  double _subtleEnterDx() {
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    return isRtl ? -AppMotion.pageSlideFraction : AppMotion.pageSlideFraction;
  }

  void _clearDirectionProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(expenseNavigationDirectionProvider.notifier).state = null;
      }
    });
  }

  /// Dispose [controller] only after the tree has dropped its listeners.
  void _disposeControllerAfterFrame(AnimationController? controller) {
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  void _runMotion({
    required double beginDx,
    required bool withFade,
  }) {
    final previous = _controller;
    // Detach old animations from fields first so the next build drops listeners.
    _incomingSlide = null;
    _incomingFade = null;

    final next = AnimationController(vsync: this, duration: AppMotion.page);
    _controller = next;
    final curved = next.drive(CurveTween(curve: AppMotion.enterCurve));
    _incomingFade = withFade ? curved : null;
    _incomingSlide = Tween<Offset>(
      begin: Offset(beginDx, 0),
      end: Offset.zero,
    ).animate(curved);

    _disposeControllerAfterFrame(previous);

    next.forward().then((_) {
      if (!mounted || !identical(_controller, next)) return;
      setState(() {
        _incomingSlide = null;
        _incomingFade = null;
        _controller = null;
      });
      _disposeControllerAfterFrame(next);
    });
  }

  /// First paint of ready body: subtle enter, or full paging slide when this
  /// shell was remounted via invite `pushReplacement` with a direction set.
  void _startEnterIfNeeded() {
    if (!_pendingEnter || _hasPlayedEnter) return;
    _pendingEnter = false;
    _hasPlayedEnter = true;
    final direction = ref.read(expenseNavigationDirectionProvider);
    if (direction != null) {
      _clearDirectionProvider();
      _runMotion(beginDx: _slideDxForDirection(direction), withFade: false);
    } else {
      _runMotion(beginDx: _subtleEnterDx(), withFade: true);
    }
    setState(() {});
  }

  void _startPagingMotion(int? direction) {
    _clearDirectionProvider();
    if (direction == null) {
      // Unknown direction — subtle fade+slide, not a fake "prev" full slide.
      _runMotion(beginDx: _subtleEnterDx(), withFade: true);
      return;
    }
    _runMotion(beginDx: _slideDxForDirection(direction), withFade: false);
  }

  @override
  void didUpdateWidget(ExpenseDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expenseId != _displayedExpenseId) {
      final direction = ref.read(expenseNavigationDirectionProvider);
      _displayedChild = widget.child;
      _displayedExpenseId = widget.expenseId;
      _startPagingMotion(direction);
      setState(() {});
    } else if (widget.child != oldWidget.child) {
      _displayedChild = widget.child;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _awaitingEnter => _pendingEnter && !_hasPlayedEnter;

  Widget _animatedBody(Widget child) {
    // Hold transparent until first enter starts (avoids a full-opacity flash).
    if (_awaitingEnter) {
      return IgnorePointer(
        child: Opacity(opacity: 0, child: child),
      );
    }
    Widget result = child;
    if (_incomingSlide != null && _controller != null) {
      result = SlideTransition(position: _incomingSlide!, child: result);
    }
    if (_incomingFade != null && _controller != null) {
      result = FadeTransition(opacity: _incomingFade!, child: result);
    }
    return ClipRect(child: result);
  }

  bool get _isAnimating => _controller?.isAnimating == true;

  bool get _blockInteraction => _awaitingEnter || _isAnimating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseAsync = ref.watch(futureExpenseProvider(widget.expenseId));
    final participantsAsync = ref.watch(
      participantsByGroupProvider(widget.groupId),
    );
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));

    // Resolve prev/next and expense for app bar; null when loading or invalid.
    final expense = expenseAsync.when(
      data: (e) => e,
      loading: () => null,
      error: (_, _) => null,
    );
    final hasValidExpense =
        expense != null && expense.groupId == widget.groupId;
    final participants = participantsAsync.when(
      data: (p) => p,
      loading: () => null,
      error: (_, _) => null,
    );
    final expensesList = expensesAsync.when(
      data: (l) => l,
      loading: () => null,
      error: (_, _) => null,
    );
    String? prevId;
    String? nextId;
    if (hasValidExpense && participants != null && expensesList != null) {
      final sorted = List<Expense>.from(expensesList)
        ..sort((a, b) => b.date.compareTo(a.date));
      final index = sorted.indexWhere((e) => e.id == expense.id);
      if (index > 0) prevId = sorted[index - 1].id;
      if (index >= 0 && index < sorted.length - 1) {
        nextId = sorted[index + 1].id;
      }
    }

    void goPrev() {
      final id = prevId;
      if (id == null) return;
      _navigateToExpense(context, id, direction: -1);
    }

    void goNext() {
      final id = nextId;
      if (id == null) return;
      _navigateToExpense(context, id, direction: 1);
    }

    final appBarLeading = IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.pop(),
    );
    final appBarTitle = expense != null
        ? Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : const SizedBox.shrink();
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
                      RoutePaths.groupExpenseEdit(widget.groupId, widget.expenseId),
                    );
                    if (context.mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          ref.invalidate(futureExpenseProvider(widget.expenseId));
                          ref.invalidate(expensesByGroupProvider(widget.groupId));
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

    final bodyReady = expenseAsync.maybeWhen(
      data: (e) =>
          e != null &&
          e.groupId == widget.groupId &&
          participantsAsync.hasValue &&
          expensesAsync.hasValue,
      orElse: () => false,
    );

    // Keep sliding the previous/current child while the next id loads so the
    // enter/paging animation is not replaced by a spinner mid-flight.
    final Widget body;
    if (bodyReady) {
      if (_pendingEnter && !_hasPlayedEnter) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startEnterIfNeeded();
        });
      }
      body = _animatedBody(_displayedChild);
    } else if (_isAnimating || _hasPlayedEnter) {
      body = _animatedBody(_displayedChild);
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, layoutConstraints) => Scaffold(
        appBar: ContentAlignedAppBar(
          contentAreaWidth: layoutConstraints.maxWidth,
          leading: appBarLeading,
          title: appBarTitle,
          actions: appBarActions,
        ),
        body: ConstrainedContent(
          child: IgnorePointer(
            ignoring: _blockInteraction,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 250) return;
                // easy_localization exports intl, which shadows Flutter's
                // TextDirection (intl uses .RTL; Flutter uses .rtl).
                final isRtl =
                    Directionality.of(context) == ui.TextDirection.rtl;
                // LTR: swipe left → next, swipe right → prev. RTL flips.
                final toNext = isRtl ? velocity > 0 : velocity < 0;
                if (toNext) {
                  goNext();
                } else {
                  goPrev();
                }
              },
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToExpense(
    BuildContext context,
    String expenseId, {
    required int direction,
  }) {
    ref.read(expenseNavigationDirectionProvider.notifier).state = direction;
    if (widget.readOnlyPreview && widget.previewToken != null) {
      context.pushReplacement(
        RoutePaths.invitePreviewExpenseDetail(widget.previewToken!, expenseId),
      );
    } else {
      context.pushReplacement(
        RoutePaths.groupExpenseDetail(widget.groupId, expenseId),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: 'delete_expense_confirm'.tr(),
      content:
          '${expense.title} – ${CurrencyFormatter.formatCents(expense.amountCents, expense.currencyCode)}',
      confirmLabel: 'delete'.tr(),
      isDestructive: true,
      centerInFullViewport: true,
    );
    if (ok == true && context.mounted) {
      await ref.read(expenseRepositoryProvider).delete(expense.id);
      ref.invalidate(futureExpenseProvider(expense.id));
      ref.invalidate(expensesByGroupProvider(widget.groupId));
      ref.invalidate(groupBalanceProvider(widget.groupId));
      if (context.mounted) context.pop();
    }
  }
}
