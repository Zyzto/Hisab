import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/receipt/receipt_ocr_io.dart';
import 'package:hisab/core/receipt/receipt_scan_cancel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('hisab/receipt_ocr');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('recognizeReceiptText returns trimmed text', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognize');
      expect(call.arguments['path'], '/tmp/r.jpg');
      expect(call.arguments['languages'], 'eng+ara');
      return '  Hello\nTotal 12.50  ';
    });

    final text = await recognizeReceiptText('/tmp/r.jpg');
    expect(text, 'Hello\nTotal 12.50');
  });

  test('recognizeReceiptText maps cancelled PlatformException', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'cancelled', message: 'OCR cancelled');
    });

    await expectLater(
      recognizeReceiptText('/tmp/r.jpg'),
      throwsA(isA<ReceiptScanCancelledException>()),
    );
  });

  test('recognizeReceiptText respects cancel token before invoke', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      fail('should not call platform when already cancelled');
    });
    final cancel = ReceiptScanCancelToken()..cancel();

    await expectLater(
      recognizeReceiptText('/tmp/r.jpg', cancel: cancel),
      throwsA(isA<ReceiptScanCancelledException>()),
    );
  });

  test('cancelReceiptOcr invokes cancel', () async {
    var cancelled = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'cancel');
      cancelled = true;
      return null;
    });

    await cancelReceiptOcr();
    expect(cancelled, isTrue);
  });
}
