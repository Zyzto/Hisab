part of 'expense_form_page.dart';

/// Custom split (parts/amounts) helpers for [_ExpenseFormPageState].
mixin _ExpenseFormSplitLogicMixin on ConsumerState<ExpenseFormPage> {
  /// For Parts: participantId -> part string. For Amounts: -> amount string.
  final Map<String, String> _customSplitValues = {};
  final Map<String, TextEditingController> _splitEditControllers = {};
  final Map<String, FocusNode> _splitFocusNodes = {};

  /// Once user edits any amount field, stop auto-updating from total.
  bool _amountsFieldsTouched = false;

  /// In amounts split: ids the user explicitly edited; never overwrite these.
  final Set<String> _amountsManuallySetIds = {};

  /// Last expense total (cents) used in [_applyAmountsChange].
  int? _lastAmountCentsForAmounts;

  _ExpenseFormPageState get _splitForm => this as _ExpenseFormPageState;

  String _formatCentsAsAmount(int cents) => (cents / 100).toStringAsFixed(2);

  /// When an amount field loses focus with 0 or empty, fill with remainder.
  void _handleAmountFieldUnfocused(Participant p) {
    if (_splitForm._splitType != SplitType.amounts) return;
    final value = _splitEditControllers[p.id]?.text ?? '';
    final v = double.tryParse(value.trim());
    if (v != null && v > 0) return;
    final participants = ref
        .read(activeParticipantsByGroupProvider(widget.groupId))
        .when(
          data: (d) => d,
          loading: () => <Participant>[],
          error: (_, _) => <Participant>[],
        );
    final includedList = participants
        .where((x) => _splitForm._includedInSplitIds.contains(x.id))
        .toList();
    if (includedList.isEmpty) return;
    final amountCentsInt =
        ((double.tryParse(_splitForm._amountController.text.trim()) ?? 0) * 100)
            .round();
    if (amountCentsInt <= 0) return;
    var othersSumCents = 0;
    for (final o in includedList) {
      if (o.id == p.id) continue;
      final ov = double.tryParse(_customSplitValues[o.id]?.trim() ?? '');
      othersSumCents += (ov != null && ov >= 0) ? (ov * 100).round() : 0;
    }
    final remainderCents = (amountCentsInt - othersSumCents).clamp(
      0,
      amountCentsInt,
    );
    final fillValue = _formatCentsAsAmount(remainderCents);
    final ctrl = _splitEditControllers[p.id];
    if (!mounted) return;
    setState(() {
      _customSplitValues[p.id] = fillValue;
      ctrl?.text = fillValue;
      ctrl?.selection = TextSelection.collapsed(offset: fillValue.length);
      _amountsManuallySetIds.add(p.id);
    });
  }

  /// Apply one participant's amount change and redistribute the remainder
  /// only to participants not manually set.
  void _applyAmountsChange(
    Participant changedParticipant,
    String valueText,
    int amountCents,
    List<Participant> includedList,
    TextEditingController? controller,
  ) {
    _amountsFieldsTouched = true;
    if (amountCents != _lastAmountCentsForAmounts) {
      _lastAmountCentsForAmounts = amountCents;
      _amountsManuallySetIds.clear();
    }
    final totalCurrency = amountCents / 100.0;
    double val = double.tryParse(valueText) ?? 0;
    val = val.clamp(0.0, totalCurrency);
    final str = val == val.roundToDouble()
        ? val.toInt().toString()
        : val.toStringAsFixed(2);
    _customSplitValues[changedParticipant.id] = str;
    controller?.text = str;
    controller?.selection = TextSelection.collapsed(offset: str.length);
    _amountsManuallySetIds.add(changedParticipant.id);
    final others = includedList
        .where((x) => x.id != changedParticipant.id)
        .toList();
    if (others.isEmpty) return;
    final userSetOthers = others
        .where((o) => _amountsManuallySetIds.contains(o.id))
        .toList();
    final nonUserSetOthers = others
        .where((o) => !_amountsManuallySetIds.contains(o.id))
        .toList();
    double userSetSum = 0;
    for (final o in userSetOthers) {
      userSetSum +=
          double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
    }
    final remainder = totalCurrency - val - userSetSum;
    if (remainder <= 0) {
      for (final o in nonUserSetOthers) {
        _customSplitValues[o.id] = '0';
        _splitEditControllers[o.id]?.text = '0';
        _splitEditControllers[o.id]?.selection = const TextSelection.collapsed(
          offset: 1,
        );
      }
      return;
    }
    if (nonUserSetOthers.isEmpty) return;
    double nonUserSetSum = 0;
    for (final o in nonUserSetOthers) {
      nonUserSetSum +=
          double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
    }
    if (nonUserSetSum <= 0) {
      final remainderCents = (remainder * 100).round();
      final k = nonUserSetOthers.length;
      final baseCents = k > 0 ? remainderCents ~/ k : 0;
      final rem = k > 0 ? remainderCents - baseCents * k : 0;
      for (var i = 0; i < nonUserSetOthers.length; i++) {
        final o = nonUserSetOthers[i];
        final shareCents = baseCents + (i < rem ? 1 : 0);
        final s = _formatCentsAsAmount(shareCents);
        _customSplitValues[o.id] = s;
        _splitEditControllers[o.id]?.text = s;
        _splitEditControllers[o.id]?.selection = TextSelection.collapsed(
          offset: s.length,
        );
      }
    } else {
      final remainderCents = (remainder * 100).round();
      final targetCentsList = <int>[];
      var sumCents = 0;
      for (final o in nonUserSetOthers) {
        final ov =
            double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0;
        final targetCents = (remainder * (ov / nonUserSetSum) * 100).round();
        targetCentsList.add(targetCents);
        sumCents += targetCents;
      }
      final diffCents = remainderCents - sumCents;
      if (nonUserSetOthers.isNotEmpty && diffCents != 0) {
        targetCentsList[0] = targetCentsList[0] + diffCents;
      }
      for (var i = 0; i < nonUserSetOthers.length; i++) {
        final o = nonUserSetOthers[i];
        final s = _formatCentsAsAmount(targetCentsList[i]);
        _customSplitValues[o.id] = s;
        _splitEditControllers[o.id]?.text = s;
        _splitEditControllers[o.id]?.selection = TextSelection.collapsed(
          offset: s.length,
        );
      }
    }
  }

  /// Initialize [_customSplitValues] for parts/amounts when missing.
  void _ensureCustomSplitValues(
    int amountCents,
    List<Participant> participants,
  ) {
    final included = participants
        .where((p) => _splitForm._includedInSplitIds.contains(p.id))
        .toList();
    if (included.isEmpty) return;
    final n = included.length;
    if (_splitForm._splitType == SplitType.parts) {
      for (final p in included) {
        _customSplitValues.putIfAbsent(p.id, () => '1');
      }
    } else if (_splitForm._splitType == SplitType.amounts) {
      final shareStrings = <String>[];
      if (n > 0 && amountCents >= 0) {
        final baseCents = amountCents ~/ n;
        final remainderCents = amountCents - baseCents * n;
        for (var i = 0; i < n; i++) {
          final shareCents = baseCents + (i < remainderCents ? 1 : 0);
          shareStrings.add(_formatCentsAsAmount(shareCents));
        }
      }
      for (var i = 0; i < included.length; i++) {
        _customSplitValues.putIfAbsent(
          included[i].id,
          () => i < shareStrings.length ? shareStrings[i] : '0',
        );
      }
      // Sync amounts to equal split when total changes, until user touches a field.
      if (amountCents > 0 && n > 0 && !_amountsFieldsTouched) {
        for (var i = 0; i < included.length; i++) {
          final s = i < shareStrings.length ? shareStrings[i] : '0';
          _customSplitValues[included[i].id] = s;
          _splitEditControllers[included[i].id]?.dispose();
          _splitEditControllers.remove(included[i].id);
        }
      }
    }
  }

  void _disposeSplitControllers() {
    for (final c in _splitEditControllers.values) {
      c.dispose();
    }
    _splitEditControllers.clear();
    for (final f in _splitFocusNodes.values) {
      f.dispose();
    }
    _splitFocusNodes.clear();
  }
}
