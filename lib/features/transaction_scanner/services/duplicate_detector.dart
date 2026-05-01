import '../domain/draft_transaction.dart';

/// Detects duplicate transactions within a time window.
class DuplicateDetector {
  DuplicateDetector._();

  /// Default window: same sender + same amount within 60 seconds.
  static const _dedupeWindowSeconds = 60;

  /// Returns `true` if [candidate] is likely a duplicate of any item in [existing].
  static bool isDuplicate(
    DraftTransaction candidate,
    List<DraftTransaction> existing,
  ) {
    for (final e in existing) {
      if (e.status == DraftStatus.duplicate) continue;
      if (e.senderPackage != candidate.senderPackage) continue;
      if (e.amountCents != candidate.amountCents) continue;
      if (e.currencyCode != candidate.currencyCode) continue;

      final diff =
          candidate.capturedAt.difference(e.capturedAt).inSeconds.abs();
      if (diff <= _dedupeWindowSeconds) return true;
    }
    return false;
  }
}
