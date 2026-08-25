import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../domain/draft_transaction.dart';
import '../domain/field_span.dart';
import '../domain/scanner_category_rule.dart';
import '../domain/scanner_notification_log.dart';
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

  Future<DraftTransaction?> getDraftById(String id) async {
    final row = await db.getOptional(
      'SELECT * FROM draft_transactions WHERE id = ?',
      [id],
    );
    if (row == null) return null;
    return _rowToDraft(row);
  }

  Future<int> getPendingCount() async {
    final result = await db.get(
      "SELECT COUNT(*) as cnt FROM draft_transactions WHERE status = 'pending'",
    );
    return (result['cnt'] as num).toInt();
  }

  Future<Map<String, int>> getPendingCountByGroup() async {
    final rows = await db.getAll(
      "SELECT personal_group_id, COUNT(*) as cnt FROM draft_transactions WHERE status = 'pending' GROUP BY personal_group_id",
    );
    final out = <String, int>{};
    for (final row in rows) {
      final id = (row['personal_group_id'] as String?) ?? '';
      out[id] = (row['cnt'] as num).toInt();
    }
    return out;
  }

  Future<DraftTransaction> insertDraft(DraftTransaction draft) async {
    final id = draft.id.isEmpty ? _uuid.v4() : draft.id;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''INSERT INTO draft_transactions
         (id, personal_group_id, amount_cents, currency_code, card_last_four,
          merchant_name, merchant_category, place_name, field_spans_json,
          transaction_date, captured_at,
          latitude, longitude, raw_notification_text, sender_package,
          sender_title, status, matched_pattern_id, confidence,
          created_expense_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        draft.targetGroupId,
        draft.amountCents,
        draft.currencyCode,
        draft.cardLastFour,
        draft.merchantName,
        draft.merchantCategory,
        draft.placeName,
        FieldSpan.encode(draft.fieldSpans),
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

  Future<void> updateDraft(DraftTransaction draft) async {
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''UPDATE draft_transactions
         SET personal_group_id = ?, amount_cents = ?, currency_code = ?,
             card_last_four = ?, merchant_name = ?, merchant_category = ?,
             place_name = ?, field_spans_json = ?, transaction_date = ?,
             status = ?, confidence = ?, updated_at = ?
         WHERE id = ?''',
      [
        draft.targetGroupId,
        draft.amountCents,
        draft.currencyCode,
        draft.cardLastFour,
        draft.merchantName,
        draft.merchantCategory,
        draft.placeName,
        FieldSpan.encode(draft.fieldSpans),
        draft.transactionDate.toIso8601String(),
        draft.status.name,
        draft.confidence,
        now,
        draft.id,
      ],
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
    await db.execute(
      'DELETE FROM scanner_notification_log WHERE updated_at < ?',
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
    final existing = await db.getOptional(
      'SELECT * FROM scanner_sender_rules WHERE package_name = ? LIMIT 1',
      [rule.packageName],
    );
    final id = existing != null
        ? existing['id'] as String
        : (rule.id.isEmpty ? _uuid.v4() : rule.id);
    final createdAt = existing != null
        ? existing['created_at']
        : rule.createdAt.toIso8601String();
    final existingCount = (existing?['match_count'] as num?)?.toInt() ?? 0;
    final matchCount = rule.matchCount > existingCount
        ? rule.matchCount
        : existingCount;
    final label = rule.senderLabel ?? existing?['sender_label'] as String?;
    final targetGroupId =
        rule.targetGroupId ?? existing?['target_group_id'] as String?;
    if (existing != null) {
      await db.execute(
        'DELETE FROM scanner_sender_rules WHERE package_name = ? AND id != ?',
        [rule.packageName, id],
      );
    }
    await db.execute(
      '''INSERT OR REPLACE INTO scanner_sender_rules
         (id, package_name, sender_label, sender_number, target_group_id,
          enabled, match_count, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        rule.packageName,
        label,
        rule.senderNumber ?? existing?['sender_number'],
        targetGroupId,
        rule.enabled ? 1 : 0,
        matchCount,
        createdAt,
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
        pattern.createdAt.toIso8601String(),
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

  // ── Category rules ──

  Future<List<ScannerCategoryRule>> getCategoryRules() async {
    final rows = await db.getAll(
      'SELECT * FROM scanner_category_rules ORDER BY hit_count DESC',
    );
    return rows.map(categoryRuleFromRow).toList();
  }

  Future<void> upsertCategoryRule(ScannerCategoryRule rule) async {
    final id = rule.id.isEmpty ? _uuid.v4() : rule.id;
    await db.execute(
      '''INSERT OR REPLACE INTO scanner_category_rules
         (id, merchant_pattern, category_id, source, hit_count, created_at)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        id,
        rule.merchantPattern,
        rule.categoryId,
        rule.source.name,
        rule.hitCount,
        rule.createdAt.toIso8601String(),
      ],
    );
  }

  Future<void> incrementCategoryHit(String id) async {
    await db.execute(
      'UPDATE scanner_category_rules SET hit_count = hit_count + 1 WHERE id = ?',
      [id],
    );
  }

  // ── Notification log ──

  Future<List<ScannerNotificationLog>> getNotificationLog({
    String? packageName,
    ScannerLogOutcome? outcome,
    int limit = 200,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (packageName != null && packageName.isNotEmpty) {
      clauses.add('sender_package = ?');
      args.add(packageName);
    }
    if (outcome != null) {
      if (outcome == ScannerLogOutcome.dismissed) {
        // "Ignored" chip includes all ignored outcomes.
      }
      clauses.add('outcome = ?');
      args.add(outcome.storageName);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    args.add(limit);
    final rows = await db.getAll(
      'SELECT * FROM scanner_notification_log $where ORDER BY captured_at DESC LIMIT ?',
      args,
    );
    return rows.map(notificationLogFromRow).toList();
  }

  Future<List<ScannerNotificationLog>> getIgnoredLogs({
    String? packageName,
    int limit = 200,
  }) async {
    final args = <Object?>[];
    var where =
        "WHERE outcome IN ('dismissed','ignored_otp','ignored_no_amount','ignored_duplicate','ignored_filter')";
    if (packageName != null && packageName.isNotEmpty) {
      where += ' AND sender_package = ?';
      args.add(packageName);
    }
    args.add(limit);
    final rows = await db.getAll(
      'SELECT * FROM scanner_notification_log $where ORDER BY captured_at DESC LIMIT ?',
      args,
    );
    return rows.map(notificationLogFromRow).toList();
  }

  Future<({int added, int ignored, int pending})> getLogSummary({
    Duration window = const Duration(hours: 24),
  }) async {
    final cutoff = DateTime.now().subtract(window).toIso8601String();
    final added = await db.get(
      "SELECT COUNT(*) as cnt FROM scanner_notification_log WHERE outcome = 'added' AND captured_at >= ?",
      [cutoff],
    );
    final ignored = await db.get(
      "SELECT COUNT(*) as cnt FROM scanner_notification_log WHERE outcome IN ('dismissed','ignored_otp','ignored_no_amount','ignored_duplicate','ignored_filter') AND captured_at >= ?",
      [cutoff],
    );
    final pending = await db.get(
      "SELECT COUNT(*) as cnt FROM scanner_notification_log WHERE outcome = 'pending' AND captured_at >= ?",
      [cutoff],
    );
    return (
      added: (added['cnt'] as num).toInt(),
      ignored: (ignored['cnt'] as num).toInt(),
      pending: (pending['cnt'] as num).toInt(),
    );
  }

  Future<bool> hasNotificationLog({
    required String senderPackage,
    required DateTime postedAt,
    required String rawText,
  }) async {
    final row = await db.getOptional(
      '''SELECT id FROM scanner_notification_log
         WHERE sender_package = ? AND posted_at = ? AND raw_text = ?
         LIMIT 1''',
      [senderPackage, postedAt.toIso8601String(), rawText],
    );
    return row != null;
  }

  Future<ScannerNotificationLog> insertLog(ScannerNotificationLog log) async {
    final id = log.id.isEmpty ? _uuid.v4() : log.id;
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''INSERT INTO scanner_notification_log
         (id, sender_package, sender_title, raw_text, posted_at, captured_at,
          outcome, reason, amount_cents, currency_code, merchant_name, place_name,
          draft_id, created_expense_id, target_group_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        log.senderPackage,
        log.senderTitle,
        log.rawText,
        log.postedAt.toIso8601String(),
        log.capturedAt.toIso8601String(),
        log.outcome.storageName,
        log.reason,
        log.amountCents,
        log.currencyCode,
        log.merchantName,
        log.placeName,
        log.draftId,
        log.createdExpenseId,
        log.targetGroupId,
        now,
        now,
      ],
    );
    return log.copyWith(updatedAt: DateTime.parse(now));
  }

  Future<void> updateLog(ScannerNotificationLog log) async {
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''UPDATE scanner_notification_log
         SET outcome = ?, reason = ?, draft_id = ?, created_expense_id = ?,
             target_group_id = ?, updated_at = ?
         WHERE id = ?''',
      [
        log.outcome.storageName,
        log.reason,
        log.draftId,
        log.createdExpenseId,
        log.targetGroupId,
        now,
        log.id,
      ],
    );
  }

  Future<void> updateLogOutcomeForDraft(
    String draftId,
    ScannerLogOutcome outcome, {
    String? createdExpenseId,
    String? targetGroupId,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.execute(
      '''UPDATE scanner_notification_log
         SET outcome = ?, created_expense_id = COALESCE(?, created_expense_id),
             target_group_id = COALESCE(?, target_group_id), updated_at = ?
         WHERE draft_id = ?''',
      [outcome.storageName, createdExpenseId, targetGroupId, now, draftId],
    );
  }
}
