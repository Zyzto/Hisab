# Transaction Scanner (Android)

<!-- markdownlint-disable MD060 -->

Opt-in **Android** feature that reads bank/payment **notification** text, parses amount/merchant/etc. on-device, stores **drafts** for review, and on confirm creates an expense (or income) in a **personal** group. Disabled by default. Not available on iOS or web.

## Overview

| Phase | Where | Behavior |
|-------|--------|----------|
| Setup | Settings → Transaction Scanner → hub / setup wizard | Explains privacy; opens system **Notification Listener** settings; enables `scanner_enabled` when granted |
| Configure | Hub → Sender whitelist, Extraction patterns | Optional package whitelist; built-in + custom regex patterns |
| Capture | `TransactionNotificationListener` (native) → Flutter flush | Queues matching notifications; parses → `draft_transactions` |
| Review | Pending drafts list / detail | Confirm, dismiss, edit merchant/amount; Confirm All (confidence ≥ 0.7) |
| Confirm | `ScannerController.confirmDraft` | Creates expense/income via `expenseRepository`; links `created_expense_id` |

Home shows a pending-draft **badge** on **personal** group cards only.

## Platform support

| Platform | Support |
|----------|---------|
| Android | Full feature (`scannerAvailable`) |
| iOS / web / desktop | No UI section; `NotificationBridge` no-ops |

`scannerAvailable` is `!kIsWeb && defaultTargetPlatform == TargetPlatform.android` in `lib/features/transaction_scanner/providers/scanner_providers.dart`. `App` watches `scannerControllerProvider` when available (`lib/app.dart`).

## Android native

| Piece | Path |
|-------|------|
| Listener service | `android/app/src/main/kotlin/com/shenepoy/hisab/TransactionNotificationListener.kt` |
| Bridge + native queue DB | `android/.../NotificationBridge.kt` (also `NotificationDbHelper` in listener file) |
| Registration | `MainActivity.configureFlutterEngine` → `NotificationBridge.register` |
| Manifest | `TransactionNotificationListener` with `BIND_NOTIFICATION_LISTENER_SERVICE` |

- **MethodChannel:** `com.shenepoy.hisab/scanner` — `isListenerEnabled`, `openListenerSettings`, `setEnabled`, `setSenders`, `getPendingNotifications`, `markFlushed`, `clearAll`
- **EventChannel:** `com.shenepoy.hisab/scanner_events`
- **Native prefs** (`scanner_prefs`): `scanner_enabled`, sender package set
- **Native SQLite** (`scanner_notifications.db`): `captured_notifications` until Flutter flushes
- **Pre-filter:** disabled → ignore; non-empty whitelist → only listed packages; body must contain at least one digit
- Empty whitelist = all apps (subject to digit filter). User grants access in system Notification Listener settings (not a normal runtime permission).

Flutter mirror: `lib/features/transaction_scanner/services/notification_bridge.dart`.

## Flutter layout

`lib/features/transaction_scanner/`:

| Area | Files |
|------|--------|
| Pages | `scanner_hub_page`, `scanner_setup_page`, `draft_transactions_page`, `draft_transaction_detail_page`, `sender_rules_page`, `scanner_patterns_page` |
| Providers | `scanner_providers.dart` (`ScannerController`, pending drafts/count, rules, patterns) |
| Repository | `repository/scanner_repository.dart` (local PowerSync DB only) |
| Services | `transaction_parser.dart`, `duplicate_detector.dart`, `notification_bridge.dart` |
| Domain | `draft_transaction.dart`, `sender_rule.dart`, `scanner_pattern.dart` |

**Navigation:** No GoRouter routes. Settings and hub use `Navigator.push` + `MaterialPageRoute`.

## Local schema (not synced)

Defined in `lib/core/database/powersync_schema.dart` under “Transaction scanner (local-only)”. No Supabase tables.

### `draft_transactions`

Amount, currency, card last four, merchant, dates, optional lat/lng (reserved; not filled by current capture path), raw notification text, sender package/title, `status` (`pending` / `confirmed` / `dismissed` / `duplicate`), `matched_pattern_id`, `confidence`, `created_expense_id`, timestamps. Optional `personal_group_id`.

### `scanner_sender_rules`

Package name, label, optional sender number, enabled, match count. Synced to native via `NotificationBridge.setSenders`.

### `scanner_patterns`

Name, sender match (stored/UI; parser currently uses amount/currency/card/merchant/date regexes), regex fields, `is_built_in`, enabled, success count.

Built-in patterns are seeded once by `ScannerController` (`builtin_bank_en_1`, `builtin_bank_ar_1`, `builtin_amount_generic`).

## Parsing and duplicates

1. Skip OTP/verification-like text (`TransactionParser`).
2. Try enabled patterns in order; first valid amount wins; else generic heuristics (default currency **SAR**; refund keywords → negative amount → income on confirm).
3. `DuplicateDetector`: same package + amount + currency within **60s** → status `duplicate` (hidden from pending list).
4. Confirm targets draft’s `personalGroupId` or the first personal group; payer = first participant. Negative `amountCents` → `TransactionType.income`.

## Settings

| Key | Default | UI |
|-----|---------|-----|
| `scanner_enabled` | `false` | Settings → Transaction Scanner toggle (+ syncs native) |
| `scanner_location_enabled` | `false` | Defined in `settings_definitions.dart`; not shown / not wired in capture |
| `scanner_notify_on_capture` | `true` | Same — defined only for now |

Section: `scannerSection` (`settings_definitions.dart`). Entry: enable toggle + **Pending Transactions** → `ScannerHubPage` (`settings_page.dart`, Android only).

## Privacy

- Opt-in; processing and draft storage are on-device.
- Raw notification text stays in local drafts; draft tables are **not** synced. Confirmed expenses follow the normal expense sync path (online mode).
- Disclosure: in-app / web privacy policy **App Permissions** (Notification access / Transaction Scanner) and [PLAY_CONSOLE_DECLARATIONS.md](PLAY_CONSOLE_DECLARATIONS.md).

User-facing copy: `scanner_*` keys in `assets/translations/en.json` and `ar.json`.

## Related docs

- [PERSONAL_FEATURE.md](PERSONAL_FEATURE.md) — confirmed drafts become personal-group expenses
- [CODEBASE.md](CODEBASE.md) — schema, features, settings
- [PLAY_CONSOLE_DECLARATIONS.md](PLAY_CONSOLE_DECLARATIONS.md) — sensitive permissions / Data safety
