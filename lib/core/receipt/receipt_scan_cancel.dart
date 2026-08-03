/// Cooperative cancel for receipt scan. Native OCR/LLM may still finish in
/// the background; callers ignore late results after [cancel].
class ReceiptScanCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const ReceiptScanCancelledException();
  }
}

class ReceiptScanCancelledException implements Exception {
  const ReceiptScanCancelledException();

  @override
  String toString() => 'ReceiptScanCancelledException';
}
