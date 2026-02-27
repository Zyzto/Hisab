import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';
import '../providers/expense_navigation_direction.dart';

/// Shell for expense detail: fixed app bar and body that slides by direction.
class ExpenseDetailShell extends ConsumerStatefulWidget {
  final String groupId;
  final String expenseId;
  final Widget child;

  const ExpenseDetailShell({
    super.key,
    required this.groupId,
    required this.expenseId,
    required this.child,
  });

  @override
  ConsumerState<ExpenseDetailShell> createState() => _ExpenseDetailShellState();
}

class _ExpenseDetailShellState extends ConsumerState<ExpenseDetailShell>
    with TickerProviderStateMixin {
  late Widget _displayedChild;
  String? _displayedExpenseId;
  int? _direction;
  static const _duration = Duration(milliseconds: 280);
  AnimationController? _controller;
  Animation<Offset>? _incomingSlide;

  @override
  void initState() {
    super.initState();
    _displayedChild = widget.child;
    _displayedExpenseId = widget.expenseId;
  }

  @override
  void didUpdateWidget(ExpenseDetailShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expenseId != _displayedExpenseId) {
      _direction = ref.read(expenseNavigationDirectionProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(expenseNavigationDirectionProvider.notifier).state = null;
        }
      });
      _displayedChild = widget.child;
      _displayedExpenseId = widget.expenseId;
      _controller?.dispose();
      _controller = AnimationController(vsync: this, duration: _duration);
      final dx = _direction == 1 ? 1.0 : -1.0; // 1 = next (new from right)
      _incomingSlide = Tween<Offset>(
        begin: Offset(dx, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
      _controller!.forward().then((_) {
        if (mounted) {
          setState(() {
            _controller?.dispose();
            _controller = null;
            _incomingSlide = null;
          });
        }
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseAsync = ref.watch(futureExpenseProvider(widget.expenseId));
    final participantsAsync =
        ref.watch(participantsByGroupProvider(widget.groupId));
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));

    // Resolve prev/next and expense for app bar; null when loading or invalid.
    final expense = expenseAsync.when(
      data: (e) => e,
      loading: () => null,
      error: (_, _) => null,
    );
    final hasValidExpense = expense != null && expense.groupId == widget.groupId;
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
      if (index >= 0 && index < sorted.length - 1) nextId = sorted[index + 1].id;
    }

    // Single app bar for all states to avoid flash when async updates.
    final appBar = AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: prevId != null
              ? () {
                  ref
                      .read(expenseNavigationDirectionProvider.notifier)
                      .state = -1;
                  context.pushReplacement(
                    RoutePaths.groupExpenseDetail(widget.groupId, prevId!),
                  );
                }
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: nextId != null
              ? () {
                  ref
                      .read(expenseNavigationDirectionProvider.notifier)
                      .state = 1;
                  context.pushReplacement(
                    RoutePaths.groupExpenseDetail(widget.groupId, nextId!),
                  );
                }
              : null,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          enabled: expense != null,
          onSelected: expense != null
              ? (value) async {
                  if (value == 'edit') {
                    await context.push(
                      RoutePaths.groupExpenseEdit(
                        widget.groupId,
                        widget.expenseId,
                      ),
                    );
                    if (context.mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          ref.invalidate(
                            futureExpenseProvider(widget.expenseId),
                          );
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
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('edit'.tr()),
                  ),
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
      ],
    );

    final body = expenseAsync.when(
      data: (e) {
        if (e == null || e.groupId != widget.groupId) {
          return const Center(child: CircularProgressIndicator());
        }
        return participantsAsync.when(
          data: (_) => expensesAsync.when(
            data: (_) => ClipRect(
              child: _incomingSlide != null && _controller != null
                  ? SlideTransition(
                      position: _incomingSlide!,
                      child: _displayedChild,
                    )
                  : _displayedChild,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(child: CircularProgressIndicator()),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      appBar: appBar,
      body: ConstrainedContent(child: body),
    );
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
      if (context.mounted) context.pop();
    }
  }
}
