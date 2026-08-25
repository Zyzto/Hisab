import 'package:powersync/powersync.dart';

import '../../core/receipt/receipt_storage.dart';
import '../transaction_scanner/services/notification_bridge.dart';

/// Wipe local data tables used by Replace import / delete-local.
Future<void> wipeLocalDataTables(PowerSyncDatabase db) async {
  await db.execute('DELETE FROM expenses');
  await db.execute('DELETE FROM expense_tags');
  await db.execute('DELETE FROM participants');
  await db.execute('DELETE FROM group_members');
  await db.execute('DELETE FROM group_invites');
  await db.execute('DELETE FROM groups');
  await db.execute('DELETE FROM pending_writes');
  await db.execute('DELETE FROM local_archived_groups');
  await db.execute('DELETE FROM invite_usages');
  await db.execute('DELETE FROM user_notifications');
  await db.execute('DELETE FROM draft_transactions');
  await db.execute('DELETE FROM scanner_sender_rules');
  await db.execute('DELETE FROM scanner_patterns');
  await db.execute('DELETE FROM scanner_category_rules');
  await db.execute('DELETE FROM scanner_notification_log');
  await clearReceiptAppStorage();
  await NotificationBridge.clearAll();
  await NotificationBridge.setSenders([]);
  await NotificationBridge.setRequireSenders(true);
}
