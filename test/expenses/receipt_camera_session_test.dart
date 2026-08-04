import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/expenses/camera/receipt_camera_session.dart';
import 'package:image_picker/image_picker.dart';

XFile _file(String name) => XFile('/tmp/$name.jpg');

void main() {
  group('ReceiptCameraSession', () {
    test('addCapture commits and opens review', () {
      final session = ReceiptCameraSession(maxRemaining: 5);
      expect(session.addCapture(_file('a')), isTrue);
      expect(session.captures, hasLength(1));
      expect(session.viewingIndex, 0);
      expect(session.isReviewing, isTrue);
      expect(session.hintDismissed, isTrue);
      expect(session.canCapture, isFalse);
    });

    test('retakeCurrent drops photo and returns to camera', () {
      final session = ReceiptCameraSession(maxRemaining: 5);
      session.addCapture(_file('a'));
      session.retakeCurrent();
      expect(session.captures, isEmpty);
      expect(session.viewingIndex, isNull);
      expect(session.canCapture, isTrue);
    });

    test('returnToCamera keeps captures for add-more', () {
      final session = ReceiptCameraSession(maxRemaining: 5);
      session.addCapture(_file('a'));
      session.returnToCamera();
      expect(session.captures, hasLength(1));
      expect(session.viewingIndex, isNull);
      expect(session.canCapture, isTrue);
    });

    test('caps at maxRemaining', () {
      final session = ReceiptCameraSession(maxRemaining: 2);
      expect(session.addCapture(_file('1')), isTrue);
      session.returnToCamera();
      expect(session.addCapture(_file('2')), isTrue);
      expect(session.atMax, isTrue);
      expect(session.canCapture, isFalse);
      session.returnToCamera();
      expect(session.addCapture(_file('3')), isFalse);
      expect(session.captures, hasLength(2));
    });

    test('strip review remove adjusts viewing index', () {
      final session = ReceiptCameraSession(maxRemaining: 5);
      session.addCapture(_file('a'));
      session.returnToCamera();
      session.addCapture(_file('b'));
      session.openStripItem(0);
      expect(session.viewingIndex, 0);
      expect(session.removeStripItem(0), isTrue);
      expect(session.captures, hasLength(1));
      expect(session.viewingIndex, 0);
      expect(session.captures.first.path, '/tmp/b.jpg');
    });

    test('takeAll returns a copy', () {
      final session = ReceiptCameraSession(maxRemaining: 5);
      session.addCapture(_file('a'));
      final all = session.takeAll();
      all.clear();
      expect(session.captures, hasLength(1));
    });

    test('swipe setViewingIndex', () {
      final session = ReceiptCameraSession(maxRemaining: 5);
      session.addCapture(_file('a'));
      session.returnToCamera();
      session.addCapture(_file('b'));
      session.setViewingIndex(0);
      expect(session.viewingIndex, 0);
    });
  });
}
