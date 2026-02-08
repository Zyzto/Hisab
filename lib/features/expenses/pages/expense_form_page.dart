import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../groups/providers/groups_provider.dart';
import '../../../domain/domain.dart';

/// Restricts input to digits and at most one decimal point (e.g. 12.34).
class _DecimalOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    if (RegExp(r'^\d*\.?\d*$').hasMatch(t)) return newValue;
    return oldValue;
  }
}

final _decimalOnlyFormatter = _DecimalOnlyFormatter();

class ExpenseFormPage extends ConsumerStatefulWidget {
  final String groupId;
  final String? expenseId;

  const ExpenseFormPage({super.key, required this.groupId, this.expenseId});

  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _currencyCode = 'USD';
  DateTime _date = DateTime.now();
  String? _payerParticipantId;
  String? _toParticipantId;
  SplitType _splitType = SplitType.equal;
  TransactionType _transactionType = TransactionType.expense;
  bool _saving = false;
  /// When editing, the loaded expense (for id and createdAt on update).
  Expense? _initialExpense;
  bool _editLoaded = false;
  /// Participant ids included in the split (default all). Unchecking excludes them.
  final Set<String> _includedInSplitIds = {};
  /// Participant ids we've already seen (so we only auto-include newly added participants).
  Set<String> _previousParticipantIds = {};
  /// For Parts: participantId -> part string (e.g. "1"). For Amounts: participantId -> amount string (e.g. "50.00").
  final Map<String, String> _customSplitValues = {};
  final Map<String, TextEditingController> _splitEditControllers = {};
  final Map<String, FocusNode> _splitFocusNodes = {};
  /// Once user edits any amount field, we stop auto-updating amounts from total (avoids grabbing first digit while typing total).
  bool _amountsFieldsTouched = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _loadExpenseForEdit();
    }
  }

  Future<void> _loadExpenseForEdit() async {
    final expense = await ref.read(expenseRepositoryProvider).getById(widget.expenseId!);
    if (!mounted || expense == null || expense.groupId != widget.groupId) return;
    final participants = await ref.read(participantRepositoryProvider).getByGroupId(widget.groupId);
    if (!mounted) return;
    setState(() {
      _initialExpense = expense;
      _currencyCode = expense.currencyCode;
      _titleController.text = expense.title;
      _amountController.text = (expense.amountCents / 100).toStringAsFixed(2);
      _date = expense.date;
      _payerParticipantId = expense.payerParticipantId;
      _transactionType = expense.transactionType;
      _splitType = expense.splitType;
      _toParticipantId = expense.toParticipantId;
      _includedInSplitIds.addAll(expense.splitShares.keys);
      _previousParticipantIds = participants.map((p) => p.id).toSet();
      final total = expense.amountCents;
      if (expense.splitType == SplitType.amounts) {
        for (final entry in expense.splitShares.entries) {
          _customSplitValues[entry.key] = (entry.value / 100).toStringAsFixed(2);
        }
      } else if (expense.splitType == SplitType.parts && total > 0) {
        final sum = expense.splitShares.values.fold<int>(0, (a, b) => a + b);
        if (sum > 0) {
          for (final entry in expense.splitShares.entries) {
            final part = (entry.value * 10 / sum).round().clamp(1, 999);
            _customSplitValues[entry.key] = part.toString();
          }
        }
      }
      _amountsFieldsTouched = true;
      _editLoaded = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _splitEditControllers.values) {
      c.dispose();
    }
    _splitEditControllers.clear();
    for (final f in _splitFocusNodes.values) {
      f.dispose();
    }
    _splitFocusNodes.clear();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountText = _amountController.text.trim();
    final amount = (double.tryParse(amountText) ?? 0) * 100;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('amount_positive'.tr())),
      );
      return;
    }
    final participants = await ref
        .read(participantRepositoryProvider)
        .getByGroupId(widget.groupId);
    if (!mounted) return;
    if (participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_participants_first'.tr())),
      );
      return;
    }

    final payerId = _payerParticipantId ?? participants.first.id;
    final isTransfer = _transactionType == TransactionType.transfer;
    if (isTransfer) {
      if (_toParticipantId == null || _toParticipantId == payerId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('choose_different_to'.tr())),
        );
        return;
      }
    }

    final included = participants.where((p) => _includedInSplitIds.contains(p.id)).toList();
    if (!isTransfer && included.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('include_at_least_one'.tr())),
      );
      return;
    }

    Map<String, int> splitShares;
    if (isTransfer) {
      splitShares = {};
    } else {
      final n = included.length;
      switch (_splitType) {
        case SplitType.equal:
          final each = (amount / n).round();
          final remainder = amount.toInt() - each * n;
          splitShares = {};
          for (var i = 0; i < n; i++) {
            splitShares[included[i].id] = each + (i < remainder ? 1 : 0);
          }
          break;
        case SplitType.parts:
          splitShares = {};
          double sumParts = 0;
          for (final p in included) {
            final text = _customSplitValues[p.id]?.trim() ?? '';
            final part = double.tryParse(text);
            sumParts += (part != null && part >= 0) ? part : 0;
          }
          if (sumParts <= 0) {
            final each = amount.toInt() ~/ n;
            final remainder = amount.toInt() - each * n;
            for (var i = 0; i < n; i++) {
              splitShares[included[i].id] = each + (i < remainder ? 1 : 0);
            }
          } else {
            var assigned = 0;
            for (var i = 0; i < included.length; i++) {
              final p = included[i];
              final text = _customSplitValues[p.id]?.trim() ?? '';
              final part = double.tryParse(text);
              final v = (part != null && part >= 0) ? part : 0.0;
              final cents = (amount * v / sumParts).round();
              splitShares[p.id] = cents;
              assigned += cents;
            }
            final diff = amount.toInt() - assigned;
            if (diff != 0 && included.isNotEmpty) {
              splitShares[included[0].id] = splitShares[included[0].id]! + diff;
            }
          }
          break;
        case SplitType.amounts:
          splitShares = {};
          final totalCents = amount.toInt();
          var sumCents = 0;
          for (final p in included) {
            final text = _customSplitValues[p.id]?.trim() ?? '';
            final value = double.tryParse(text);
            final cents = value != null && value >= 0 ? (value * 100).round() : 0;
            sumCents += cents;
            splitShares[p.id] = cents;
          }
          if (sumCents != totalCents) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('amounts_must_equal_total'.tr())),
              );
              setState(() => _saving = false);
            }
            return;
          }
          break;
      }
    }

    setState(() => _saving = true);
    var didPop = false;
    try {
      final title = isTransfer
          ? 'Transfer'
          : _titleController.text.trim();
      final expense = Expense(
        id: _initialExpense?.id ?? '',
        groupId: widget.groupId,
        payerParticipantId: payerId,
        amountCents: amount.toInt(),
        currencyCode: _currencyCode,
        title: title,
        date: _date,
        splitType: isTransfer ? SplitType.equal : _splitType,
        splitShares: splitShares,
        createdAt: _initialExpense?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        transactionType: _transactionType,
        toParticipantId: isTransfer ? _toParticipantId : null,
      );
      if (_initialExpense != null) {
        await ref.read(expenseRepositoryProvider).update(expense);
      } else {
        await ref.read(expenseRepositoryProvider).create(expense);
      }
      if (!mounted) return;
      context.pop();
      didPop = true;
    } finally {
      if (!didPop && mounted) setState(() => _saving = false);
    }
  }

  /// Per-participant share in cents for preview (equal split among included only).
  List<int> _splitSharesPreview(int totalCents, List<Participant> participants) {
    final included = participants.where((p) => _includedInSplitIds.contains(p.id)).toList();
    if (included.isEmpty || totalCents <= 0) return List.filled(participants.length, 0);
    final n = included.length;
    final each = totalCents ~/ n;
    final remainder = totalCents - each * n;
    final shareById = <String, int>{};
    for (var i = 0; i < n; i++) {
      shareById[included[i].id] = each + (i < remainder ? 1 : 0);
    }
    return participants.map((p) => shareById[p.id] ?? 0).toList();
  }

  /// Shares in cents: parts = totalCents * (part / sumOfParts), amounts = direct currency entry.
  List<int> _customSharesPreview(int totalCents, List<Participant> participants) {
    final result = <int>[];
    if (_splitType == SplitType.parts) {
      double sumParts = 0;
      final parts = <String, double>{};
      for (final p in participants) {
        final text = _customSplitValues[p.id]?.trim() ?? '';
        final part = double.tryParse(text);
        final v = part != null && part >= 0 ? part : 0.0;
        parts[p.id] = v;
        sumParts += v;
      }
      if (sumParts <= 0) {
        return List.filled(participants.length, 0);
      }
      for (final p in participants) {
        result.add((totalCents * (parts[p.id]! / sumParts)).round());
      }
      return result;
    }
    if (_splitType == SplitType.amounts) {
      for (final p in participants) {
        final text = _customSplitValues[p.id]?.trim() ?? '';
        final value = double.tryParse(text);
        result.add(value != null && value >= 0 ? (value * 100).round() : 0);
      }
      return result;
    }
    return List.filled(participants.length, 0);
  }

  /// Sum of amount fields in cents (for amounts split type validation).
  int _amountsSumCents(List<Participant> participants) {
    var sum = 0;
    for (final p in participants) {
      if (!_includedInSplitIds.contains(p.id)) continue;
      final v = double.tryParse(_customSplitValues[p.id]?.trim() ?? '');
      if (v != null && v >= 0) sum += (v * 100).round();
    }
    return sum;
  }

  /// Apply one participant's amount change and redistribute the rest so sum = total.
  void _applyAmountsChange(
    Participant changedParticipant,
    String valueText,
    int amountCents,
    List<Participant> includedList,
    TextEditingController? controller,
  ) {
    _amountsFieldsTouched = true;
    final totalCurrency = amountCents / 100.0;
    double val = double.tryParse(valueText) ?? 0;
    val = val.clamp(0.0, totalCurrency);
    final str = val == val.roundToDouble() ? val.toInt().toString() : val.toStringAsFixed(2);
    _customSplitValues[changedParticipant.id] = str;
    controller?.text = str;
    controller?.selection = TextSelection.collapsed(offset: str.length);
    final others = includedList.where((x) => x.id != changedParticipant.id).toList();
    if (others.isEmpty) return;
    final remainder = totalCurrency - val;
    if (remainder <= 0) {
      for (final o in others) {
        _customSplitValues[o.id] = '0';
        _splitEditControllers[o.id]?.text = '0';
        _splitEditControllers[o.id]?.selection = const TextSelection.collapsed(offset: 1);
      }
      return;
    }
    double othersSum = 0;
    for (final o in others) {
      othersSum += double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
    }
    if (othersSum <= 0) {
      final each = remainder / others.length;
      for (var i = 0; i < others.length; i++) {
        final o = others[i];
        final s = i == others.length - 1
            ? (remainder - each * (others.length - 1)).toStringAsFixed(2)
            : each.toStringAsFixed(2);
        _customSplitValues[o.id] = s;
        _splitEditControllers[o.id]?.text = s;
        _splitEditControllers[o.id]?.selection = TextSelection.collapsed(offset: s.length);
      }
    } else {
      final scale = remainder / othersSum;
      var assigned = 0.0;
      final newValues = <String, String>{};
      for (final o in others) {
        final ov = double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
        final nv = ov * scale;
        newValues[o.id] = nv == nv.roundToDouble() ? nv.toInt().toString() : nv.toStringAsFixed(2);
        assigned += nv;
      }
      final diff = remainder - assigned;
      if (diff.abs() > 0.001 && others.isNotEmpty) {
        final first = others.first.id;
        final cur = double.tryParse(newValues[first] ?? '0') ?? 0;
        newValues[first] = (cur + diff).toStringAsFixed(2);
      }
      for (final o in others) {
        final s = newValues[o.id] ?? '0';
        _customSplitValues[o.id] = s;
        _splitEditControllers[o.id]?.text = s;
        _splitEditControllers[o.id]?.selection = TextSelection.collapsed(offset: s.length);
      }
    }
  }

  /// Initialize _customSplitValues for parts/amounts when missing.
  void _ensureCustomSplitValues(int amountCents, List<Participant> participants) {
    final included = participants.where((p) => _includedInSplitIds.contains(p.id)).toList();
    if (included.isEmpty) return;
    final n = included.length;
    if (_splitType == SplitType.parts) {
      for (final p in included) {
        _customSplitValues.putIfAbsent(p.id, () => '1');
      }
    } else if (_splitType == SplitType.amounts) {
      final each = n > 0 ? (amountCents / 100 / n) : 0.0;
      for (final p in included) {
        _customSplitValues.putIfAbsent(p.id, () => each.toStringAsFixed(2));
      }
      // Sync amounts to equal split when total changes, but only until user touches an amount field.
      if (amountCents > 0 && n > 0 && !_amountsFieldsTouched) {
        final perPerson = (amountCents / 100 / n).toStringAsFixed(2);
        for (final p in included) {
          _customSplitValues[p.id] = perPerson;
          _splitEditControllers[p.id]?.dispose();
          _splitEditControllers.remove(p.id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    final participantsAsync = ref.watch(
      participantsByGroupProvider(widget.groupId),
    );

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.pop();
          });
          return const SizedBox.shrink();
        }
        final currencyCode = group.currencyCode;

        return participantsAsync.when(
          data: (participants) {
            _currencyCode = group.currencyCode;
            if (widget.expenseId != null && !_editLoaded) {
              return Scaffold(
                appBar: AppBar(
                  title: Text('edit_expense'.tr()),
                  leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (participants.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  title: Text((widget.expenseId != null ? 'edit_expense' : 'add_expense').tr()),
                ),
                body: Center(child: Text('add_participants_first'.tr())),
              );
            }
            final payerId = _payerParticipantId ?? participants.first.id;
            final amountCents = (double.tryParse(_amountController.text.trim()) ?? 0) * 100;
            final amountCentsInt = amountCents.toInt();
            if (_splitType == SplitType.parts || _splitType == SplitType.amounts) {
              _ensureCustomSplitValues(amountCentsInt, participants);
            }
            final shares = amountCentsInt > 0
                ? (_splitType == SplitType.equal
                    ? _splitSharesPreview(amountCentsInt, participants)
                    : _customSharesPreview(amountCentsInt, participants))
                : <int>[];
            // Only add newly added participants to split by default (don't re-add unchecked)
            final currentIds = participants.map((p) => p.id).toSet();
            final newIds = currentIds.difference(_previousParticipantIds);
            if (newIds.isNotEmpty) {
              _previousParticipantIds = Set.from(currentIds);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  for (final id in newIds) {
                    _includedInSplitIds.add(id);
                  }
                });
              });
            } else {
              _previousParticipantIds = Set.from(currentIds);
            }

            final isTransfer = _transactionType == TransactionType.transfer;
            final toId = _toParticipantId ?? (participants.length > 1 ? participants.firstWhere((p) => p.id != payerId, orElse: () => participants.first).id : participants.first.id);

            return Scaffold(
              appBar: AppBar(
                title: Text((widget.expenseId != null ? 'edit_expense' : 'add_expense').tr()),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    _buildSegmentedPill(context),
                    const SizedBox(height: 24),
                    if (!isTransfer) ...[
                      _buildTitleSection(context),
                      const SizedBox(height: 20),
                    ],
                    _buildAmountSection(context, currencyCode),
                    const SizedBox(height: 20),
                    if (isTransfer) ...[
                      _buildTransferFromToRow(context, participants, payerId, toId),
                      const SizedBox(height: 20),
                      _buildWhenSection(context),
                    ] else
                      _buildPaidByAndWhenRow(context, participants, payerId),
                    if (!isTransfer) ...[
                      const SizedBox(height: 24),
                      _buildSplitSection(context, theme, participants, shares, amountCentsInt, currencyCode),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: (_saving || (_splitType == SplitType.amounts && _amountsSumCents(participants) != amountCentsInt)) ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text((widget.expenseId != null ? 'submit' : 'add_expense').tr()),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
    );
  }

  Widget _buildSegmentedPill(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _segmentChip(context, theme, TransactionType.expense, 'expenses'.tr()),
          _segmentChip(context, theme, TransactionType.income, 'income'.tr()),
          _segmentChip(context, theme, TransactionType.transfer, 'transfer'.tr()),
        ],
      ),
    );
  }

  Widget _segmentChip(BuildContext context, ThemeData theme, TransactionType type, String label) {
    final selected = _transactionType == type;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _transactionType = type;
                if (type == TransactionType.transfer && _toParticipantId == null) {
                  final participants = ref.read(participantsByGroupProvider(widget.groupId)).value ?? [];
                  final payerId = _payerParticipantId ?? (participants.isNotEmpty ? participants.first.id : null);
                  if (participants.length > 1 && payerId != null) {
                    _toParticipantId = participants.firstWhere((p) => p.id != payerId, orElse: () => participants.first).id;
                  }
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? theme.colorScheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'title'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            hintText: 'title'.tr(),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.label_outline, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt_outlined, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr() : null,
        ),
      ],
    );
  }

  Widget _buildAmountSection(BuildContext context, String currencyCode) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'amount'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currencyCode, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  hintText: '0',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalOnlyFormatter],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'required'.tr();
                  if (double.tryParse(v) == null) return 'invalid_number'.tr();
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaidByAndWhenRow(
    BuildContext context,
    List<Participant> participants,
    String payerId,
  ) {
    final theme = Theme.of(context);
    final payer = participants.firstWhere(
      (p) => p.id == payerId,
      orElse: () => participants.first,
    );
    final payerName = payer.name;
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'paid_by_label'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showPayerPicker(context, participants),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          payerName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'when'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateFormat.format(_date),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferFromToRow(
    BuildContext context,
    List<Participant> participants,
    String payerId,
    String toId,
  ) {
    final theme = Theme.of(context);
    final payer = participants.firstWhere((p) => p.id == payerId, orElse: () => participants.first);
    final toParticipant = participants.firstWhere((p) => p.id == toId, orElse: () => participants.first);
    final others = participants.where((p) => p.id != payerId).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('from'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _showPayerPicker(context, participants),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      Expanded(child: Text(payer.name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge)),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('to'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  if (others.isEmpty) return;
                  final chosen = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('to'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
                          ),
                          ...others.map((p) => ListTile(title: Text(p.name), onTap: () => Navigator.of(ctx).pop(p.id))),
                        ],
                      ),
                    ),
                  );
                  if (chosen != null) setState(() => _toParticipantId = chosen);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      Expanded(child: Text(toParticipant.name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge)),
                      Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWhenSection(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMMM d, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('when'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _date = picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              children: [
                Expanded(child: Text(dateFormat.format(_date), style: theme.textTheme.bodyLarge)),
                Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPayerPicker(BuildContext context, List<Participant> participants) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('paid_by_label'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...participants.map((p) => ListTile(
                  title: Text(p.name),
                  onTap: () => Navigator.of(ctx).pop(p.id),
                )),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _payerParticipantId = chosen);
  }

  static const double _kSplitRadius = 4;

  InputDecoration _splitInputDecoration(ThemeData theme) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kSplitRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kSplitRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kSplitRadius),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
    );
  }

  Widget _buildSplitSection(
    BuildContext context,
    ThemeData theme,
    List<Participant> participants,
    List<int> sharesCents,
    int amountCents,
    String currencyCode,
  ) {
    final participantIds = participants.map((e) => e.id).toSet();
    for (final id in List.from(_splitEditControllers.keys)) {
      if (!participantIds.contains(id)) {
        _splitEditControllers[id]?.dispose();
        _splitEditControllers.remove(id);
        _splitFocusNodes[id]?.dispose();
        _splitFocusNodes.remove(id);
      }
    }
    final includedList = participants.where((p) => _includedInSplitIds.contains(p.id)).toList();
    final includedCount = includedList.length;
    final isCustomSplit = _splitType == SplitType.parts || _splitType == SplitType.amounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                'split'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSplitTypePicker(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _splitType == SplitType.equal
                              ? 'equal'.tr()
                              : _splitType == SplitType.parts
                                  ? 'parts'.tr()
                                  : 'amounts'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 20, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(_kSplitRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kSplitRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: participants.length,
                itemBuilder: (context, i) {
                  final p = participants[i];
                  final cents = i < sharesCents.length ? sharesCents[i] : 0;
                  final included = _includedInSplitIds.contains(p.id);
                  final defaultAmountStr = '1'; // parts (e.g. 1, 2, 1 → total distributed by ratio)
                  final defaultAmountCurrencyStr = includedCount > 0
                      ? (amountCents / 100 / includedCount).toStringAsFixed(2)
                      : '0.00';
                  final defaultStr = _splitType == SplitType.parts ? defaultAmountStr : defaultAmountCurrencyStr;
                  final valueStr = _customSplitValues[p.id] ?? defaultStr;

                  TextEditingController? controller = _splitEditControllers[p.id];
                  FocusNode? focusNode = _splitFocusNodes[p.id];
                  if (isCustomSplit && controller == null) {
                    controller = TextEditingController(text: valueStr);
                    _splitEditControllers[p.id] = controller;
                    focusNode = FocusNode();
                    _splitFocusNodes[p.id] = focusNode;
                  }

                  // Fixed widths so layout doesn't shift when numbers change length
                  const double kSplitInputWidth = 88;
                  const double kSplitAmountWidth = 100;
                  const double kMinTapHeight = 48;

                  Widget trailing;
                  if (isCustomSplit && included) {
                    trailing = Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => focusNode?.requestFocus(),
                        borderRadius: BorderRadius.circular(_kSplitRadius),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: kMinTapHeight),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(_kSplitRadius),
                                  child: SizedBox(
                                    width: kSplitInputWidth,
                                    height: kMinTapHeight - 12,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: TextField(
                                        focusNode: focusNode,
                                        controller: controller,
                                        keyboardType: TextInputType.numberWithOptions(decimal: _splitType == SplitType.amounts),
                                        inputFormatters: _splitType == SplitType.amounts
                                            ? [_decimalOnlyFormatter]
                                            : [FilteringTextInputFormatter.digitsOnly],
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          height: 1.0,
                                        ),
                                        decoration: _splitInputDecoration(theme),
                            onChanged: (v) {
                              setState(() {
                                if (_splitType == SplitType.amounts) {
                                  _applyAmountsChange(p, v, amountCents, includedList, controller);
                                } else {
                                  _customSplitValues[p.id] = v;
                                }
                              });
                            },
                                    ),
                                  ),
                                ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: kSplitAmountWidth,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      CurrencyFormatter.formatCents(cents, currencyCode),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    trailing = SizedBox(
                      width: kSplitAmountWidth,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          CurrencyFormatter.formatCents(cents, currencyCode),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: included
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }

                  return CheckboxListTile(
                    value: included,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _includedInSplitIds.add(p.id);
                        } else {
                          _includedInSplitIds.remove(p.id);
                          _customSplitValues.remove(p.id);
                          _splitEditControllers[p.id]?.dispose();
                          _splitEditControllers.remove(p.id);
                          _splitFocusNodes[p.id]?.dispose();
                          _splitFocusNodes.remove(p.id);
                        }
                      });
                    },
                    title: Text(
                      p.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: included
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: trailing,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    dense: true,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_splitType == SplitType.amounts && includedList.isNotEmpty) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final sumCents = _amountsSumCents(participants);
              final ok = sumCents == amountCents;
              return Text(
                '${'total'.tr()}: ${(sumCents / 100).toStringAsFixed(2)} / ${(amountCents / 100).toStringAsFixed(2)}${ok ? '' : ' (${'amounts_must_equal_total'.tr()})'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ok ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Future<void> _showSplitTypePicker(BuildContext context) async {
    final chosen = await showModalBottomSheet<SplitType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('split_type'.tr(), style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...SplitType.values.map((e) => ListTile(
                  title: Text(e == SplitType.equal
                      ? 'equal'.tr()
                      : e == SplitType.parts
                          ? 'parts'.tr()
                          : 'amounts'.tr()),
                  onTap: () => Navigator.of(ctx).pop(e),
                )),
          ],
        ),
      ),
    );
    if (chosen != null) {
      setState(() {
        _splitType = chosen;
        if (chosen == SplitType.parts || chosen == SplitType.amounts) {
          _amountsFieldsTouched = false;
          for (final c in _splitEditControllers.values) {
            c.dispose();
          }
          _splitEditControllers.clear();
          for (final f in _splitFocusNodes.values) {
            f.dispose();
          }
          _splitFocusNodes.clear();
          _customSplitValues.clear();
        }
      });
    }
  }
}
