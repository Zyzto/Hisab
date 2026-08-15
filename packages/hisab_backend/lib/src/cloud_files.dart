import 'dart:typed_data';

/// Binary uploads.
///
/// Both methods return a URL that must be fetchable by every member of the
/// owning group, and both return null on failure rather than throwing: an
/// image that fails to upload degrades the expense, it does not invalidate it.
abstract interface class CloudFiles {
  /// Stores a receipt or expense photo and returns its URL.
  ///
  /// [fileExt] is one of `jpg`, `png`, `webp`. Implementations should key the
  /// object by group and expense so deleting a group can delete its images.
  Future<String?> uploadExpenseImage(
    Uint8List bytes, {
    required String groupId,
    required String expenseId,
    required String fileExt,
  });

  /// Stores a PNG screenshot attached to a feedback report and returns its URL.
  Future<String?> uploadFeedbackScreenshot(Uint8List pngBytes);
}
