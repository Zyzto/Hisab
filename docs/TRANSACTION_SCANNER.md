# Local transaction scanner

The optional Android transaction scanner reads notification text only after
the user enables it and grants Android notification access. It parses text on
the device into drafts. Nothing is transmitted by the scanner.

## Flow

1. Enable the scanner in Settings.
2. Choose sender applications and a destination group.
3. Review local drafts and correct fields when needed.
4. Confirm or dismiss a draft.
5. Confirmed drafts become normal local expenses or income records.

The native listener is in
android/app/src/main/kotlin/com/shenepoy/hisab/TransactionNotificationListener.kt.
The Flutter bridge is in
lib/features/transaction_scanner/services/notification_bridge.dart.

## Local records

- draft_transactions stores pending transaction fields and review state.
- scanner_sender_rules stores sender filters and destinations.
- scanner_category_rules stores local learned category rules.
- scanner_notification_log stores local capture outcomes.

These tables are local and remain available for backup and restore.

## Parsing

The deterministic parser ignores one-time-password messages, recognizes
amounts and currencies, detects refunds, and applies local category rules.
Duplicates within the configured time window are marked instead of creating a
second expense. There is no model download or remote classifier.

## Privacy

Notification text can contain sensitive financial information. Keep the
scanner disabled unless needed, review drafts before confirming them, and use
Android settings to revoke notification access.
