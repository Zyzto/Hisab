part of 'expense_form_page.dart';

/// Exchange-rate / base-amount helpers for [_ExpenseFormPageState].
mixin _ExpenseFormExchangeMixin on ConsumerState<ExpenseFormPage> {
  final _exchangeRateController = TextEditingController();
  final _baseAmountController = TextEditingController();
  double _exchangeRate = 1.0;
  bool _fetchingRate = false;

  /// Listener for amount field; runs base-amount recalc only when it changes.
  late final VoidCallback _amountListener;

  /// Coalesces recalc to at most once per frame when amount changes rapidly.
  bool _recalcBaseAmountPending = false;

  _ExpenseFormPageState get _exchangeForm => this as _ExpenseFormPageState;

  bool get _isDifferentCurrency =>
      _exchangeForm._currencyCode != _exchangeForm._groupCurrencyCode;

  void _initExchangeAmountListener() {
    _amountListener = () {
      if (_recalcBaseAmountPending) return;
      _recalcBaseAmountPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalcBaseAmountPending = false;
        if (mounted) _onAmountChangedForExchangeRate();
      });
    };
    _exchangeForm._amountController.addListener(_amountListener);
  }

  void _disposeExchangeControllers() {
    _exchangeForm._amountController.removeListener(_amountListener);
    _exchangeRateController.dispose();
    _baseAmountController.dispose();
  }

  Future<void> _fetchLiveRate() async {
    setState(() => _fetchingRate = true);
    try {
      final service = ExchangeRateService();
      final rate = await service.getRate(
        _exchangeForm._currencyCode,
        _exchangeForm._groupCurrencyCode,
      );
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
    final amount = double.tryParse(_exchangeForm._amountController.text.trim());
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
    final amount = double.tryParse(_exchangeForm._amountController.text.trim());
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
}
