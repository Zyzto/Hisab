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

  int _unitCount(Participant participant) {
    if (!_splitForm._householdMode) return 1;
    final count =
        _splitForm._loadedHouseholdSnapshot?.includedUnitCounts[participant
            .id] ??
        participant.directHouseholdSize;
    return count < 1 ? 1 : count;
  }

  int _includedUnitCount(List<Participant> participants) => participants
      .where((p) => _splitForm._includedInSplitIds.contains(p.id))
      .fold<int>(0, (sum, p) => sum + _unitCount(p));

  String _formatCentsAsAmount(int cents) => (cents / 100).toStringAsFixed(2);

  /// Format a household row's per-person amount.  A row with multiple units
  /// can represent a fractional cent per person (for example, 1.00 split
  /// across three units).  Keep the ordinary two-decimal currency look when
  /// it divides cleanly, but retain enough precision for the weighted total
  /// to round back to the exact expense amount.
  String _formatPerPersonAmount(int rowCents, int units) {
    if (units <= 1 || rowCents % units == 0) {
      return _formatCentsAsAmount(units <= 1 ? rowCents : rowCents ~/ units);
    }
    var value = (rowCents / units / 100).toStringAsFixed(6);
    value = value.replaceFirst(RegExp(r'0+$'), '');
    value = value.replaceFirst(RegExp(r'\.$'), '');
    return value.isEmpty ? '0' : value;
  }

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
      othersSumCents += (ov != null && ov >= 0)
          ? (ov * 100 * _unitCount(o)).round()
          : 0;
    }
    final remainderCents = (amountCentsInt - othersSumCents).clamp(
      0,
      amountCentsInt,
    );
    final units = _unitCount(p);
    final fillValue = _formatPerPersonAmount(remainderCents, units);
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
          (double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0) *
          _unitCount(o);
    }
    final remainder =
        totalCurrency - (val * _unitCount(changedParticipant)) - userSetSum;
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
          (double.tryParse(_customSplitValues[o.id]?.trim() ?? '0') ?? 0) *
          _unitCount(o);
    }
    if (nonUserSetSum <= 0) {
      final remainderCents = (remainder * 100).round();
      final totalUnits = nonUserSetOthers.fold<int>(
        0,
        (sum, p) => sum + _unitCount(p),
      );
      final baseCents = totalUnits > 0 ? remainderCents ~/ totalUnits : 0;
      final rem = totalUnits > 0 ? remainderCents - baseCents * totalUnits : 0;
      var remainingExtra = rem;
      for (var i = 0; i < nonUserSetOthers.length; i++) {
        final o = nonUserSetOthers[i];
        final units = _unitCount(o);
        final extra = remainingExtra.clamp(0, units);
        remainingExtra -= extra;
        final shareCents = baseCents + (units > 0 ? extra ~/ units : 0);
        final s = _formatPerPersonAmount(shareCents, _unitCount(o));
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
        final targetCents =
            (remainder * (ov * _unitCount(o) / nonUserSetSum) * 100).round();
        targetCentsList.add(targetCents);
        sumCents += targetCents;
      }
      final diffCents = remainderCents - sumCents;
      if (nonUserSetOthers.isNotEmpty && diffCents != 0) {
        targetCentsList[0] = targetCentsList[0] + diffCents;
      }
      for (var i = 0; i < nonUserSetOthers.length; i++) {
        final o = nonUserSetOthers[i];
        final s = _formatPerPersonAmount(targetCentsList[i], _unitCount(o));
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
    final n = _includedUnitCount(participants);
    if (_splitForm._splitType == SplitType.parts) {
      for (final p in included) {
        _customSplitValues.putIfAbsent(p.id, () => '1');
      }
    } else if (_splitForm._splitType == SplitType.amounts) {
      for (var i = 0; i < included.length; i++) {
        final p = included[i];
        final units = _unitCount(p);
        final rowCents = n > 0 ? (amountCents * units / n).round() : 0;
        _customSplitValues.putIfAbsent(
          p.id,
          () => _formatPerPersonAmount(rowCents, units),
        );
      }
      // Sync amounts to equal split when total changes, until user touches a field.
      if (amountCents > 0 && n > 0 && !_amountsFieldsTouched) {
        for (final p in included) {
          final units = _unitCount(p);
          final rowCents = n > 0 ? (amountCents * units / n).round() : 0;
          final s = _formatPerPersonAmount(rowCents, units);
          _customSplitValues[p.id] = s;
          _splitEditControllers[p.id]?.dispose();
          _splitEditControllers.remove(p.id);
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
