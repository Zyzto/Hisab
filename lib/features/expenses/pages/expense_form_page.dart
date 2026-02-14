import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/receipt/receipt_image_view.dart';
import '../../../core/receipt/receipt_scan_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/services/exchange_rate_service.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../features/settings/providers/settings_framework_providers.dart';
import '../../groups/providers/groups_provider.dart';
import '../constants/expense_form_constants.dart';
import '../widgets/expense_amount_section.dart';
import '../widgets/expense_bill_breakdown_section.dart';
import '../widgets/expense_title_section.dart';
import '../widgets/expense_split_section.dart';
import '../widgets/expense_transaction_type_pill.dart';
import '../../../domain/domain.dart';

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
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _currencyCode = 'USD';
  String _groupCurrencyCode = 'USD';
  DateTime _date = DateTime.now();
  String? _payerParticipantId;
  String? _toParticipantId;
  SplitType _splitType = SplitType.equal;
  TransactionType _transactionType = TransactionType.expense;
  bool _saving = false;

  // Exchange rate state
  final _exchangeRateController = TextEditingController();
  final _baseAmountController = TextEditingController();
  double _exchangeRate = 1.0;
  bool _fetchingRate = false;
  bool _groupCurrencyInitialized = false;

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

  /// Selected category/tag: preset id (e.g. 'food') or custom tag id (ExpenseTag.id).
  String? _selectedTag;

  /// Optional bill/receipt breakdown (description + amount per line).
  List<ReceiptLineItem> _lineItems = [];

  /// Controllers for bill breakdown rows (one desc + amount per line).
  final List<({TextEditingController desc, TextEditingController amount})>
  _lineItemControllers = [];

  /// Path to attached receipt image (when AI not configured or LLM failed).
  String? _receiptImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _loadExpenseForEdit();
    }
  }

  Future<void> _loadExpenseForEdit() async {
    final expense = await ref
        .read(expenseRepositoryProvider)
        .getById(widget.expenseId!);
    if (!mounted || expense == null || expense.groupId != widget.groupId) {
      return;
    }
    final participants = await ref
        .read(participantRepositoryProvider)
        .getByGroupId(widget.groupId);
    if (!mounted) return;
    setState(() {
      _initialExpense = expense;
      _currencyCode = expense.currencyCode;
      _exchangeRate = expense.exchangeRate;
      if (expense.exchangeRate != 1.0) {
        _exchangeRateController.text =
            expense.exchangeRate.toStringAsFixed(4);
      }
      if (expense.baseAmountCents != null) {
        _baseAmountController.text =
            (expense.baseAmountCents! / 100).toStringAsFixed(2);
      }
      _titleController.text = expense.title;
      _descriptionController.text = expense.description ?? '';
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
          _customSplitValues[entry.key] = (entry.value / 100).toStringAsFixed(
            2,
          );
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
      _selectedTag = expense.tag;
      _lineItems = expense.lineItems != null
          ? List.from(expense.lineItems!)
          : [];
      for (final item in _lineItems) {
        _lineItemControllers.add((
          desc: TextEditingController(text: item.description),
          amount: TextEditingController(
            text: item.amountCents > 0
                ? (item.amountCents / 100).toStringAsFixed(2)
                : '',
          ),
        ));
      }
      _receiptImagePath = expense.receiptImagePath;
      _editLoaded = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _exchangeRateController.dispose();
    _baseAmountController.dispose();
    for (final c in _splitEditControllers.values) {
      c.dispose();
    }
    _splitEditControllers.clear();
    for (final f in _splitFocusNodes.values) {
      f.dispose();
    }
    _splitFocusNodes.clear();
    for (final c in _lineItemControllers) {
      c.desc.dispose();
      c.amount.dispose();
    }
    _lineItemControllers.clear();
    super.dispose();
  }

  bool get _isDifferentCurrency => _currencyCode != _groupCurrencyCode;

  void _openExpenseCurrencyPicker() {
    final stored = ref.read(favoriteCurrenciesProvider);
    final favorites = CurrencyHelpers.getEffectiveFavorites(stored);
    CurrencyHelpers.showPicker(
      context: context,
      favorite: favorites,
      onSelect: (Currency currency) {
        if (currency.code == _currencyCode) return;
        setState(() {
          _currencyCode = currency.code;
          if (_isDifferentCurrency) {
            _fetchLiveRate();
          } else {
            _exchangeRate = 1.0;
            _exchangeRateController.clear();
            _baseAmountController.clear();
          }
        });
      },
    );
  }

  Future<void> _fetchLiveRate() async {
    setState(() => _fetchingRate = true);
    try {
      final service = ExchangeRateService();
      final rate = await service.getRate(_currencyCode, _groupCurrencyCode);
      if (!mounted) return;
      if (rate != null && rate > 0) {
        setState(() {
          _exchangeRate = rate;
          _exchangeRateController.text = rate.toStringAsFixed(4);
          _recalcBaseAmount();
        });
      }
    } catch (e) {
      Log.debug('Exchange rate fetch failed: $e');
    } finally {
      if (mounted) setState(() => _fetchingRate = false);
    }
  }

  void _onExchangeRateChanged(String value) {
    final rate = double.tryParse(value);
    if (rate == null || rate <= 0) return;
    _exchangeRate = rate;
    _recalcBaseAmount();
  }

  void _onBaseAmountChanged(String value) {
    final baseAmount = double.tryParse(value);
    final amount = double.tryParse(_amountController.text.trim());
    if (baseAmount != null && baseAmount > 0 && amount != null && amount > 0) {
      final newRate = amount / baseAmount;
      setState(() {
        _exchangeRate = newRate;
        _exchangeRateController.text = newRate.toStringAsFixed(4);
      });
    }
  }

  /// Recalculate the base amount from current amount and exchange rate.
  void _recalcBaseAmount() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount != null && amount > 0 && _exchangeRate > 0) {
      final baseAmount = amount / _exchangeRate;
      _baseAmountController.text = baseAmount.toStringAsFixed(2);
    }
  }

  /// Recalculate base amount when the main amount field changes.
  void _onAmountChangedForExchangeRate() {
    if (_isDifferentCurrency && _exchangeRate > 0) {
      _recalcBaseAmount();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountText = _amountController.text.trim();
    final amount = (double.tryParse(amountText) ?? 0) * 100;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('amount_positive'.tr())));
      return;
    }
    final participants = await ref
        .read(participantRepositoryProvider)
        .getByGroupId(widget.groupId);
    if (!mounted) return;
    if (participants.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('add_participants_first'.tr())));
      return;
    }

    final payerId = _payerParticipantId ?? participants.first.id;
    final isTransfer = _transactionType == TransactionType.transfer;
    if (isTransfer) {
      if (_toParticipantId == null || _toParticipantId == payerId) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('choose_different_to'.tr())));
        return;
      }
    }

    final included = participants
        .where((p) => _includedInSplitIds.contains(p.id))
        .toList();
    if (!isTransfer && included.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('include_at_least_one'.tr())));
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
            final cents = value != null && value >= 0
                ? (value * 100).round()
                : 0;
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
      final title = isTransfer ? 'Transfer' : _titleController.text.trim();
      final desc = _descriptionController.text.trim();

      // Compute base amount in group currency when currencies differ
      int? baseAmountCents;
      double exchangeRate = 1.0;
      if (_isDifferentCurrency && _exchangeRate > 0) {
        exchangeRate = _exchangeRate;
        final baseAmountText = _baseAmountController.text.trim();
        final baseAmount = double.tryParse(baseAmountText);
        if (baseAmount != null && baseAmount > 0) {
          baseAmountCents = (baseAmount * 100).round();
        } else {
          // Fallback: compute from amount and rate
          baseAmountCents = (amount / _exchangeRate).round();
        }
      }

      final expense = Expense(
        id: _initialExpense?.id ?? '',
        groupId: widget.groupId,
        payerParticipantId: payerId,
        amountCents: amount.toInt(),
        currencyCode: _currencyCode,
        exchangeRate: exchangeRate,
        baseAmountCents: baseAmountCents,
        title: title,
        description: desc.isEmpty ? null : desc,
        date: _date,
        splitType: isTransfer ? SplitType.equal : _splitType,
        splitShares: splitShares,
        createdAt: _initialExpense?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        transactionType: _transactionType,
        toParticipantId: isTransfer ? _toParticipantId : null,
        tag: _selectedTag,
        lineItems: _effectiveLineItemsForSave(),
        receiptImagePath: _receiptImagePath,
      );
      if (_initialExpense != null) {
        await ref.read(expenseRepositoryProvider).update(expense);
        Log.info(
          'Expense updated: id=${expense.id} title="${expense.title}" amountCents=${expense.amountCents}',
        );
      } else {
        final id = await ref.read(expenseRepositoryProvider).create(expense);
        Log.info(
          'Expense created: id=$id groupId=${expense.groupId} title="${expense.title}" amountCents=${expense.amountCents} currencyCode=${expense.currencyCode}',
        );
        try {
          TelemetryService.sendEvent('expense_created', {
            'groupId': expense.groupId,
            'amountCents': expense.amountCents,
          }, enabled: ref.read(telemetryEnabledProvider));
        } catch (_) {}
      }
      if (!mounted) return;
      context.pop();
      didPop = true;
    } catch (e, st) {
      Log.warning('Expense save failed', error: e, stackTrace: st);
    } finally {
      if (!didPop && mounted) setState(() => _saving = false);
    }
  }

  /// Per-participant share in cents for preview (equal split among included only).
  List<int> _splitSharesPreview(
    int totalCents,
    List<Participant> participants,
  ) {
    final included = participants
        .where((p) => _includedInSplitIds.contains(p.id))
        .toList();
    if (included.isEmpty || totalCents <= 0) {
      return List.filled(participants.length, 0);
    }
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
  List<int> _customSharesPreview(
    int totalCents,
    List<Participant> participants,
  ) {
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
    final str = val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(2);
    _customSplitValues[changedParticipant.id] = str;
    controller?.text = str;
    controller?.selection = TextSelection.collapsed(offset: str.length);
    final others = includedList
        .where((x) => x.id != changedParticipant.id)
        .toList();
    if (others.isEmpty) return;
    final remainder = totalCurrency - val;
    if (remainder <= 0) {
      for (final o in others) {
        _customSplitValues[o.id] = '0';
        _splitEditControllers[o.id]?.text = '0';
        _splitEditControllers[o.id]?.selection = const TextSelection.collapsed(
          offset: 1,
        );
      }
      return;
    }
    double othersSum = 0;
    for (final o in others) {
      othersSum +=
          double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
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
        _splitEditControllers[o.id]?.selection = TextSelection.collapsed(
          offset: s.length,
        );
      }
    } else {
      final scale = remainder / othersSum;
      var assigned = 0.0;
      final newValues = <String, String>{};
      for (final o in others) {
        final ov =
            double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
        final nv = ov * scale;
        newValues[o.id] = nv == nv.roundToDouble()
            ? nv.toInt().toString()
            : nv.toStringAsFixed(2);
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
        _splitEditControllers[o.id]?.selection = TextSelection.collapsed(
          offset: s.length,
        );
      }
    }
  }

  /// Initialize _customSplitValues for parts/amounts when missing.
  void _ensureCustomSplitValues(
    int amountCents,
    List<Participant> participants,
  ) {
    final included = participants
        .where((p) => _includedInSplitIds.contains(p.id))
        .toList();
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
        if (group.isSettlementFrozen && widget.expenseId == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text('add_expense'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pause_circle_outline,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'add_expense_blocked_frozen'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: Text('done'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final currencyCode = group.currencyCode;

        return participantsAsync.when(
          data: (participants) {
            // Set group currency once; don't override user's expense currency selection
            if (!_groupCurrencyInitialized) {
              _groupCurrencyCode = group.currencyCode;
              if (widget.expenseId == null) {
                _currencyCode = group.currencyCode;
              }
              _groupCurrencyInitialized = true;
            }
            if (widget.expenseId != null && !_editLoaded) {
              return Scaffold(
                appBar: AppBar(
                  title: Text('edit_expense'.tr()),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            if (participants.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    (widget.expenseId != null ? 'edit_expense' : 'add_expense')
                        .tr(),
                  ),
                ),
                body: Center(child: Text('add_participants_first'.tr())),
              );
            }
            final payerId = _payerParticipantId ?? participants.first.id;
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
            final toId =
                _toParticipantId ??
                (participants.length > 1
                    ? participants
                          .firstWhere(
                            (p) => p.id != payerId,
                            orElse: () => participants.first,
                          )
                          .id
                    : participants.first.id);
            final tagsAsync = ref.watch(tagsByGroupProvider(widget.groupId));
            final customTags = tagsAsync.value ?? [];

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  (widget.expenseId != null ? 'edit_expense' : 'add_expense')
                      .tr(),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    ExpenseTransactionTypePill(
                      value: _transactionType,
                      onChanged: (type) {
                        setState(() {
                          _transactionType = type;
                          if (type == TransactionType.transfer &&
                              _toParticipantId == null) {
                            final participants =
                                ref
                                    .read(
                                      participantsByGroupProvider(
                                        widget.groupId,
                                      ),
                                    )
                                    .value ??
                                [];
                            final payerId =
                                _payerParticipantId ??
                                (participants.isNotEmpty
                                    ? participants.first.id
                                    : null);
                            if (participants.length > 1 && payerId != null) {
                              _toParticipantId = participants
                                  .firstWhere(
                                    (p) => p.id != payerId,
                                    orElse: () => participants.first,
                                  )
                                  .id;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    if (!isTransfer) ...[
                      ExpenseTitleSection(
                        controller: _titleController,
                        selectedTag: _selectedTag,
                        customTags: customTags,
                        onTagPicker: () => _showTagPicker(customTags),
                        onPickReceipt: _pickReceiptImage,
                      ),
                      if (_receiptImagePath != null) ...[
                        const SizedBox(height: 8),
                        _buildReceiptAttachedChip(context),
                        GestureDetector(
                          onTap: () => showReceiptImageFullScreen(
                            context,
                            _receiptImagePath!,
                          ),
                          child: buildReceiptImageView(
                            _receiptImagePath,
                            maxHeight: 180,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _buildDescriptionSection(context),
                      const SizedBox(height: 20),
                    ],
                    ListenableBuilder(
                      listenable: _amountController,
                      builder: (context, _) {
                        // Trigger base amount recalc when amount changes
                        _onAmountChangedForExchangeRate();
                        return ExpenseAmountSection(
                          controller: _amountController,
                          currencyCode: _currencyCode,
                          onCurrencyTap: _openExpenseCurrencyPicker,
                          groupCurrencyCode: _groupCurrencyCode,
                          exchangeRateController: _exchangeRateController,
                          baseAmountController: _baseAmountController,
                          fetchingRate: _fetchingRate,
                          onExchangeRateChanged: _onExchangeRateChanged,
                          onBaseAmountChanged: _onBaseAmountChanged,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    if (isTransfer) ...[
                      _buildTransferFromToRow(
                        context,
                        participants,
                        payerId,
                        toId,
                      ),
                      const SizedBox(height: 20),
                      _buildWhenSection(context),
                    ] else
                      _buildPaidByAndWhenRow(
                        context,
                        participants,
                        payerId,
                      ),
                    if (!isTransfer) ...[
                      const SizedBox(height: 20),
                      ExpenseBillBreakdownSection(
                        lineItems: _lineItems,
                        lineItemControllers: _lineItemControllers,
                        onAddItem: () {
                          setState(() {
                            _lineItems.add(
                              const ReceiptLineItem(
                                description: '',
                                amountCents: 0,
                              ),
                            );
                            _lineItemControllers.add((
                              desc: TextEditingController(),
                              amount: TextEditingController(),
                            ));
                          });
                        },
                        onRemoveItem: (i) {
                          setState(() {
                            _lineItemControllers[i].desc.dispose();
                            _lineItemControllers[i].amount.dispose();
                            _lineItemControllers.removeAt(i);
                            _lineItems.removeAt(i);
                          });
                        },
                        onItemChanged: (i, desc, amountCents) {
                          setState(() {
                            _lineItems[i] = ReceiptLineItem(
                              description: desc,
                              amountCents: amountCents,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      ListenableBuilder(
                        listenable: _amountController,
                        builder: (context, _) {
                          final amountCents =
                              (double.tryParse(_amountController.text.trim()) ??
                                  0) *
                              100;
                          final amountCentsInt = amountCents.toInt();
                          if (_splitType == SplitType.parts ||
                              _splitType == SplitType.amounts) {
                            _ensureCustomSplitValues(
                              amountCentsInt,
                              participants,
                            );
                          }
                          final shares = amountCentsInt > 0
                              ? (_splitType == SplitType.equal
                                    ? _splitSharesPreview(
                                        amountCentsInt,
                                        participants,
                                      )
                                    : _customSharesPreview(
                                        amountCentsInt,
                                        participants,
                                      ))
                              : <int>[];
                          final participantIds = participants
                              .map((e) => e.id)
                              .toSet();
                          for (final id in List.from(
                            _splitEditControllers.keys,
                          )) {
                            if (!participantIds.contains(id)) {
                              _splitEditControllers[id]?.dispose();
                              _splitEditControllers.remove(id);
                              _splitFocusNodes[id]?.dispose();
                              _splitFocusNodes.remove(id);
                            }
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExpenseSplitSection(
                                participants: participants,
                                sharesCents: shares,
                                amountCents: amountCentsInt,
                                currencyCode: currencyCode,
                                splitType: _splitType,
                                includedInSplitIds: _includedInSplitIds,
                                customSplitValues: _customSplitValues,
                                splitEditControllers: _splitEditControllers,
                                splitFocusNodes: _splitFocusNodes,
                                getOrCreateController: (p) {
                                  var c = _splitEditControllers[p.id];
                                  if (c == null &&
                                      (_splitType == SplitType.parts ||
                                          _splitType == SplitType.amounts)) {
                                    c = TextEditingController(
                                      text: _customSplitValues[p.id] ?? '1',
                                    );
                                    _splitEditControllers[p.id] = c;
                                    _splitFocusNodes[p.id] ??= FocusNode();
                                  }
                                  return c;
                                },
                                getOrCreateFocusNode: (p) =>
                                    _splitFocusNodes[p.id],
                                onSplitTypeTap: () =>
                                    _showSplitTypePicker(context),
                                onIncludeChanged: (p, included) {
                                  setState(() {
                                    if (included) {
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
                                onAmountChanged: (p, v, includedList, ctrl) {
                                  setState(() {
                                    _applyAmountsChange(
                                      p,
                                      v,
                                      amountCentsInt,
                                      includedList,
                                      ctrl,
                                    );
                                  });
                                },
                                onPartsChanged: (p, v) {
                                  setState(() => _customSplitValues[p.id] = v);
                                },
                                amountsSumCents: () =>
                                    _amountsSumCents(participants),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 32),
                    ListenableBuilder(
                      listenable: _amountController,
                      builder: (context, _) {
                        final amountCentsInt =
                            ((double.tryParse(_amountController.text.trim()) ??
                                        0) *
                                    100)
                                .toInt();
                        return SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed:
                                (_saving ||
                                    (_splitType == SplitType.amounts &&
                                        _amountsSumCents(participants) !=
                                            amountCentsInt))
                                ? null
                                : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    (widget.expenseId != null
                                            ? 'submit'
                                            : 'add_expense')
                                        .tr(),
                                  ),
                          ),
                        );
                      },
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

  void _showTagPicker(List<ExpenseTag> customTags) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'category'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...presetExpenseTags.map((preset) {
                    final selected = _selectedTag == preset.id;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedTag = preset.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              preset.icon,
                              size: 20,
                              color: selected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              preset.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: selected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  ...customTags.map((tag) {
                    final selected = _selectedTag == tag.id;
                    final iconData =
                        selectableExpenseIcons[tag.iconName] ??
                        Icons.label_outlined;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedTag = tag.id);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData,
                              size: 20,
                              color: selected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tag.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: selected
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  InkWell(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final created = await _showCreateTagDialog();
                      if (created != null && mounted) {
                        setState(() => _selectedTag = created.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'create_new_tag'.tr(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<ExpenseTag?> _showCreateTagDialog() async {
    final nameController = TextEditingController();
    String selectedIconName = selectableExpenseIcons.keys.first;
    return showDialog<ExpenseTag>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('create_new_tag'.tr()),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'tag_name'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'choose_icon'.tr(),
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectableExpenseIcons.entries.map((e) {
                      final selected = selectedIconName == e.key;
                      return InkWell(
                        onTap: () =>
                            setDialogState(() => selectedIconName = e.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                : Theme.of(
                                    ctx,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            e.value,
                            size: 28,
                            color: selected
                                ? Theme.of(ctx).colorScheme.onPrimaryContainer
                                : Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('cancel'.tr()),
              ),
              FilledButton(
                onPressed: () async {
                  final label = nameController.text.trim();
                  if (label.isEmpty) return;
                  final id = await ref
                      .read(tagRepositoryProvider)
                      .create(widget.groupId, label, selectedIconName);
                  if (!ctx.mounted) return;
                  final tag = ExpenseTag(
                    id: id,
                    groupId: widget.groupId,
                    label: label,
                    iconName: selectedIconName,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop(tag);
                },
                child: Text('done'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Pick image from camera or gallery, run OCR, then branch: heuristic parse, LLM extract, or attach image.
  /// ML Kit text recognition is not available on web; only Android and iOS are supported.
  Future<void> _pickReceiptImage() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('receipt_scan_web_unavailable'.tr())),
        );
      }
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('camera'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('gallery'.tr()),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (!mounted) return;

    // Pre-check permission before opening the picker.
    final bool hasPermission;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else {
      hasPermission = await PermissionService.requestPhotosPermission(context);
    }
    if (!hasPermission || !mounted) return;

    const double maxDimension = 1920;
    final XFile? file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
    );
    if (file == null || !mounted) return;
    try {
      final result = await processReceiptFile(file, ref, _date);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('receipt_no_text'.tr())));
        return;
      }
      switch (result) {
        case ReceiptScanParsed():
          setState(() {
            _titleController.text = result.vendor;
            _date = result.date;
            _amountController.text = result.total.toStringAsFixed(2);
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('receipt_scan_applied'.tr())));
        case ReceiptScanFallback():
          setState(() {
            _titleController.text = 'Receipt';
            _descriptionController.text = result.ocrText;
            _receiptImagePath = result.receiptImagePath;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('receipt_attached'.tr())));
      }
    } catch (e, stack) {
      if (mounted) {
        final msg = shortReceiptErrorMessage(e);
        debugPrint('Receipt scan error: $e');
        debugPrintStack(stackTrace: stack);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('receipt_scan_error'.tr(args: [msg]))),
        );
      }
    }
  }

  /// Line items to persist: exclude rows that are both empty description and zero amount.
  List<ReceiptLineItem>? _effectiveLineItemsForSave() {
    final filtered = _lineItems
        .where((e) => e.description.trim().isNotEmpty || e.amountCents > 0)
        .toList();
    return filtered.isEmpty ? null : filtered;
  }

  Widget _buildDescriptionSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'expense_description'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'expense_description_hint'.tr(),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          minLines: 2,
        ),
      ],
    );
  }

  Widget _buildReceiptAttachedChip(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text('receipt_attached'.tr(), style: theme.textTheme.bodySmall),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () => setState(() => _receiptImagePath = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
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
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
                      Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
    final payer = participants.firstWhere(
      (p) => p.id == payerId,
      orElse: () => participants.first,
    );
    final toParticipant = participants.firstWhere(
      (p) => p.id == toId,
      orElse: () => participants.first,
    );
    final others = participants.where((p) => p.id != payerId).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'from'.tr(),
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
                          payer.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
                'to'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
                            child: Text(
                              'to'.tr(),
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                          ),
                          ...others.map(
                            (p) => ListTile(
                              title: Text(p.name),
                              onTap: () => Navigator.of(ctx).pop(p.id),
                            ),
                          ),
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
                      Expanded(
                        child: Text(
                          toParticipant.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPayerPicker(
    BuildContext context,
    List<Participant> participants,
  ) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'paid_by_label'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...participants.map(
              (p) => ListTile(
                title: Text(p.name),
                onTap: () => Navigator.of(ctx).pop(p.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _payerParticipantId = chosen);
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
              child: Text(
                'split_type'.tr(),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ...SplitType.values.map(
              (e) => ListTile(
                title: Text(
                  e == SplitType.equal
                      ? 'equal'.tr()
                      : e == SplitType.parts
                      ? 'parts'.tr()
                      : 'amounts'.tr(),
                ),
                onTap: () => Navigator.of(ctx).pop(e),
              ),
            ),
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
