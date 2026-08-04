import 'package:image_picker/image_picker.dart';

/// Pure filmstrip / review state for the receipt camera (unit-testable).
///
/// Captures commit to [captures] immediately. [viewingIndex] null means live
/// camera; non-null means reviewing that strip item (swipeable).
class ReceiptCameraSession {
  ReceiptCameraSession({required this.maxRemaining});

  final int maxRemaining;

  final List<XFile> captures = [];
  int? viewingIndex;
  bool hintDismissed = false;

  bool get atMax => captures.length >= maxRemaining;
  bool get canCapture => !atMax && viewingIndex == null;
  bool get hasCaptures => captures.isNotEmpty;
  bool get isReviewing => viewingIndex != null;

  /// Commit [file] to the filmstrip and open review on it.
  bool addCapture(XFile file) {
    if (atMax) return false;
    captures.add(file);
    viewingIndex = captures.length - 1;
    hintDismissed = true;
    return true;
  }

  /// Leave review and return to the live camera.
  void returnToCamera() {
    viewingIndex = null;
  }

  /// Drop the photo under review and return to the live camera.
  void retakeCurrent() {
    final i = viewingIndex;
    if (i == null || i < 0 || i >= captures.length) return;
    captures.removeAt(i);
    viewingIndex = null;
  }

  void openStripItem(int index) {
    if (index < 0 || index >= captures.length) return;
    viewingIndex = index;
  }

  void setViewingIndex(int index) {
    if (index < 0 || index >= captures.length) return;
    viewingIndex = index;
  }

  bool removeStripItem(int index) {
    if (index < 0 || index >= captures.length) return false;
    captures.removeAt(index);
    if (captures.isEmpty) {
      viewingIndex = null;
      return true;
    }
    final v = viewingIndex;
    if (v == null) return true;
    if (v > index) {
      viewingIndex = v - 1;
    } else if (v >= captures.length) {
      viewingIndex = captures.length - 1;
    }
    return true;
  }

  List<XFile> takeAll() => List<XFile>.from(captures);

  void clear() {
    captures.clear();
    viewingIndex = null;
  }
}
