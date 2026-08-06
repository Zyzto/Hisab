import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/draft_transaction.dart';
import '../domain/scanner_pattern.dart';
import '../domain/sender_rule.dart';
import 'scanner_row_mappers.dart';

const _uuid = Uuid();

/// Local-only repository for the transaction scanner feature.
class ScannerRepository {
  final PowerSyncDatabase db;

  ScannerRepository(this.db);

  // ── Draft Transactions ──

  DraftTransaction _rowToDraft(Map<String, dynamic> row) =>
      draftTransactionFromRow(row);

  Future<List<DraftTransaction>> getPendingDrafts() async {
    final rows = await db.getAll(
      "SELECT * FROM draft_transactions WHERE status = 'pending' ORDER BY captured_at DESC",
    );
    return rows.map(_rowToDraft).toList();
  }

  Future<List<DraftTransaction>> getRecentDrafts({int limit = 200}) async {
    final rows = await db.getAll(
      'SELECT * FROM draft_transactions ORDER BY captured_at DESC LIMIT ?',
      [limit],
    );
    return rows.map(_rowToDraft).toList();
  }

  Future<int> getPendingCount() async {
    final result = await db.get(
      "SELECT COUNT(*) as cnt FROM draft_transactions WHERE status = 'pending'",
    );
    return (result['cnt'] as num).toInt();
  }

  Future<DraftTransaction> insertDraft(DraftTransaction draft) async {
    final id = draft.id.isEmpty ? _uuid.v4() : draft.id;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''INSERT INTO draft_transactions
         (id, personal_group_id, amount_cents, currency_code, card_last_four,
          merchant_name, merchant_category, transaction_date, captured_at,
          latitude, longitude, raw_notification_text, sender_package,
          sender_title, status, matched_pattern_id, confidence,
          created_expense_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        draft.personalGroupId,
        draft.amountCents,
        draft.currencyCode,
        draft.cardLastFour,
        draft.merchantName,
        draft.merchantCategory,
        draft.transactionDate.toIso8601String(),
        draft.capturedAt.toIso8601String(),
        draft.latitude,
        draft.longitude,
        draft.rawNotificationText,
        draft.senderPackage,
        draft.senderTitle,
        draft.status.name,
        draft.matchedPatternId,
        draft.confidence,
        draft.createdExpenseId,
        now,
        now,
      ],
    );
    return draft.copyWith(
      id: id,
      createdAt: DateTime.parse(now),
      updatedAt: DateTime.parse(now),
    );
  }

  Future<void> updateDraftStatus(
    String id,
    DraftStatus status, {
    String? createdExpenseId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''UPDATE draft_transactions
         SET status = ?, created_expense_id = COALESCE(?, created_expense_id), updated_at = ?
         WHERE id = ?''',
      [status.name, createdExpenseId, now, id],
    );
  }

  Future<void> deleteDraft(String id) async {
    await db.execute('DELETE FROM draft_transactions WHERE id = ?', [id]);
  }

  Future<void> deleteOldDismissed({int retentionDays = 90}) async {
    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .toIso8601String();
    await db.execute(
      "DELETE FROM draft_transactions WHERE status IN ('dismissed', 'duplicate') AND updated_at < ?",
      [cutoff],
    );
  }

  // ── Sender Rules ──

  SenderRule _rowToRule(Map<String, dynamic> row) => senderRuleFromRow(row);

  Future<List<SenderRule>> getSenderRules() async {
    final rows = await db.getAll(
      'SELECT * FROM scanner_sender_rules ORDER BY match_count DESC',
    );
    return rows.map(_rowToRule).toList();
  }

  Future<List<SenderRule>> getEnabledSenderRules() async {
    final rows = await db.getAll(
      'SELECT * FROM scanner_sender_rules WHERE enabled = 1',
    );
    return rows.map(_rowToRule).toList();
  }

  Future<void> upsertSenderRule(SenderRule rule) async {
    final id = rule.id.isEmpty ? _uuid.v4() : rule.id;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''INSERT OR REPLACE INTO scanner_sender_rules
         (id, package_name, sender_label, sender_number, enabled, match_count, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        rule.packageName,
        rule.senderLabel,
        rule.senderNumber,
        rule.enabled ? 1 : 0,
        rule.matchCount,
        now,
      ],
    );
  }

  Future<void> deleteSenderRule(String id) async {
    await db.execute('DELETE FROM scanner_sender_rules WHERE id = ?', [id]);
  }

  Future<void> incrementSenderMatchCount(String packageName) async {
    await db.execute(
      'UPDATE scanner_sender_rules SET match_count = match_count + 1 WHERE package_name = ?',
      [packageName],
    );
  }

  // ── Scanner Patterns ──

  ScannerPattern _rowToPattern(Map<String, dynamic> row) =>
      scannerPatternFromRow(row);

  Future<List<ScannerPattern>> getPatterns() async {
    final rows = await db.getAll(
      'SELECT * FROM scanner_patterns ORDER BY success_count DESC',
    );
    return rows.map(_rowToPattern).toList();
  }

  Future<List<ScannerPattern>> getEnabledPatterns() async {
    final rows = await db.getAll(
      'SELECT * FROM scanner_patterns WHERE enabled = 1',
    );
    return rows.map(_rowToPattern).toList();
  }

  Future<void> upsertPattern(ScannerPattern pattern) async {
    final id = pattern.id.isEmpty ? _uuid.v4() : pattern.id;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''INSERT OR REPLACE INTO scanner_patterns
         (id, name, sender_match, amount_regex, currency_regex, card_regex,
          merchant_regex, date_regex, date_format, is_built_in, enabled,
          success_count, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        pattern.name,
        pattern.senderMatch,
        pattern.amountRegex,
        pattern.currencyRegex,
        pattern.cardRegex,
        pattern.merchantRegex,
        pattern.dateRegex,
        pattern.dateFormat,
        pattern.isBuiltIn ? 1 : 0,
        pattern.enabled ? 1 : 0,
        pattern.successCount,
        now,
      ],
    );
  }

  Future<void> deletePattern(String id) async {
    await db.execute('DELETE FROM scanner_patterns WHERE id = ?', [id]);
  }

  Future<void> incrementPatternSuccess(String id) async {
    await db.execute(
      'UPDATE scanner_patterns SET success_count = success_count + 1 WHERE id = ?',
      [id],
    );
  }
}
