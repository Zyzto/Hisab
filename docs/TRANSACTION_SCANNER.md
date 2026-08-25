# Transaction Scanner (Android)

<!-- markdownlint-disable MD060 -->

Opt-in **Android** feature (`scannerAvailable`): reads bank/payment **notification** text, parses on-device into **drafts**, and on confirm creates an expense (or income) in a **personal or shared** group. Disabled by default. No UI on iOS/web (`NotificationBridge` no-ops). Home shows a pending-draft badge on the destination group card.

Gate: `lib/features/transaction_scanner/providers/scanner_providers.dart`. `App` watches `scannerControllerProvider` when available (`lib/app.dart`).

**Not SMS.** There is no `READ_SMS` / inbox access. Bank SMS is captured only if the SMS or bank app posts a status-bar notification.

## User flows

1. **Setup** — Settings → Transaction Scanner → wizard: privacy → Notification Listener → pick apps → teach fields on a sample → default destination → categories/AI → done.
2. **Configure** — Hub: apps, history, patterns (advanced regex), reconfigure.
3. **Capture** — Native listener queues matching notifications → Flutter flush → `draft_transactions` + `scanner_notification_log`.
4. **Review** — Pending list/detail: visual annotator, destination, category; confirm, dismiss, or Confirm All (confidence ≥ 0.7).
5. **Confirm** — `ScannerController.confirmDraft` creates expense/income via `expenseRepository`. Shared groups: current user paid, equal split.
6. **History** — Per-app / global log of added, ignored (OTP, no amount, dismissed, duplicate), and pending.

## Android native

| Piece | Path |
|-------|------|
| Listener | `android/app/src/main/kotlin/com/shenepoy/hisab/TransactionNotificationListener.kt` |
| Bridge | `android/.../NotificationBridge.kt` (`NotificationDbHelper` in listener file) |
| Register | `MainActivity.configureFlutterEngine` → `NotificationBridge.register` |
| Manifest | `TransactionNotificationListener` + `BIND_NOTIFICATION_LISTENER_SERVICE`; launcher `<queries>` for app picker |

- Channels: MethodChannel `com.shenepoy.hisab/scanner`, EventChannel `com.shenepoy.hisab/scanner_events`.
- Native prefs `scanner_prefs` (`scanner_enabled`, sender set, `scanner_require_senders`); queue DB `scanner_notifications.db`.
- Pre-filter: disabled → ignore; after completed setup, empty whitelist captures nothing; otherwise non-empty whitelist = listed packages only. Body needs a digit.
- Flutter: `lib/features/transaction_scanner/services/notification_bridge.dart`.

## Local schema (not synced)

- `draft_transactions` — amount, currency, merchant, `place_name`, `field_spans_json`, dates, raw text, sender, status, confidence, `created_expense_id`, `personal_group_id` (any destination group).
- `scanner_sender_rules` — package, label, optional `target_group_id`.
- `scanner_patterns` — built-in + taught/custom regex. Built-in names are translation keys.
- `scanner_category_rules` — learned merchant → category.
- `scanner_notification_log` — every watched-app capture and outcome (90-day retention).

## Parsing

1. Skip OTP/verification (`ParseSkipReason.otp`) — logged, no draft.
2. Enabled patterns then generic heuristics (default currency **SAR**; refunds → negative → income).
3. Local category keywords + learned rules; optional Nano/cloud AI if `scanner_ai_mode` is not `off`.
4. Duplicates within 60s → `duplicate` + log.

Confirm destination: sender override → draft → `scanner_default_group_id` → first personal group. Payer = current user's participant.

## Settings

`scanner_enabled`, `scanner_categorize_enabled`, `scanner_ai_mode` (`off` / `nano` / `cloud`), hidden `scanner_default_group_id` and `scanner_setup_completed`.

## Privacy

Drafts, history, and raw notification text stay on-device and are **not** synced. Confirmed expenses use the normal expense sync path. Cloud AI (opt-in) sends notification text to the configured Receipt AI provider.

User-facing UI: `scanner_*` in `en.json` / `ar.json`. Disclosure: `privacy_policy_permissions_body` and `web/privacy/index.html`.
