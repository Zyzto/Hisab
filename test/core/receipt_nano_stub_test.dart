import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/receipt/receipt_nano_service.dart';

void main() {
  test('stub/default checkNanoStatus is unavailable in test VM', () async {
    // On Linux CI / flutter test VM there is no AI Core.
    final status = await checkNanoStatus();
    expect(status, NanoFeatureStatus.unavailable);
  });

  test('extractReceiptJsonWithNano returns null when unavailable', () async {
    final raw = await extractReceiptJsonWithNano(ocrText: 'TOTAL 1.00');
    expect(raw, isNull);
  });
}
