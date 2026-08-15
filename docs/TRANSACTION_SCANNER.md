# Transaction Scanner (Android)

<!-- markdownlint-disable MD060 -->

Opt-in **Android** feature (`scannerAvailable`): reads bank/payment **notification** text, parses on-device into **drafts**, and on confirm creates an expense (or income) in a **personal** group. Disabled by default. No UI on iOS/web (`NotificationBridge` no-ops). Home shows a pending-draft badge on personal group cards.

Gate: `lib/features/transaction_scanner/providers/scanner_providers.dart`. `App` watches `scannerControllerProvider` when available (`lib/app.dart`).

## User flows

1. **Setup** — Settings → Transaction Scanner → hub / setup wizard: explain privacy → open system **Notification Listener** settings → enable `scanner_enabled` when granted.
2. **Configure** — Hub: sender whitelist (Android package names), extraction patterns (built-in + custom regex).
3. **Capture** — Native listener queues matching notifications → Flutter flush → `draft_transactions`.
4. **Review** — Pending list/detail: edit merchant/amount; confirm, dismiss, or Confirm All (confidence ≥ 0.7).
5. **Confirm** — `ScannerController.confirmDraft` creates expense/income via `expenseRepository` and sets `created_expense_id`.

## Android native

| Piece | Path |
|-------|------|
| Listener | `android/app/src/main/kotlin/com/shenepoy/hisab/TransactionNotificationListener.kt` |
| Bridge | `android/.../NotificationBridge.kt` (`NotificationDbHelper` in listener file) |
| Register | `MainActivity.configureFlutterEngine` → `NotificationBridge.register` |
| Manifest | `TransactionNotificationListener` + `BIND_NOTIFICATION_LISTENER_SERVICE` |

- Channels: MethodChannel `com.shenepoy.hisab/scanner`, EventChannel `com.shenepoy.hisab/scanner_events`.
- Native prefs `scanner_prefs` (`scanner_enabled`, sender set); queue DB `scanner_notifications.db` / `captured_notifications` until Flutter flushes.
- Pre-filter: disabled → ignore; non-empty whitelist → listed packages only; body needs a digit. Empty whitelist = all apps (digit filter still applies). Access is system Notification Listener settings, not a normal runtime permission.
- Flutter: `lib/features/transaction_scanner/services/notification_bridge.dart`.

## Code locations

| Area | Path |
|------|------|
| Feature | `lib/features/transaction_scanner/` — `pages/`, `providers/scanner_providers.dart` (`ScannerController`), `repository/scanner_repository.dart`, `services/` (parser, duplicate detector, bridge), `domain/` |
| Schema | `lib/core/database/powersync_schema.dart` — local-only tables below (never synced) |
| Settings UI | `settings_definitions.dart` (`scannerSection`, `scanner_enabled`); `settings_page.dart` (Android section → hub) |

**Navigation:** No GoRouter routes; Settings/hub use `Navigator.push` + `MaterialPageRoute`.

## Local schema (not synced)

### `draft_transactions`

Amount, currency, card last four, merchant, dates, raw notification text, sender package/title, `status` (`pending` / `confirmed` / `dismissed` / `duplicate`), `matched_pattern_id`, `confidence`, `created_expense_id`, timestamps; optional `personal_group_id`.

### `scanner_sender_rules`

Package name, label, optional sender number, enabled, match count. Pushed to native via `NotificationBridge.setSenders`.

### `scanner_patterns`

Name, sender match, amount/currency/card/merchant/date regexes (+ date format), `is_built_in`, enabled, success count. Built-ins seeded once: `builtin_bank_en_1`, `builtin_bank_ar_1`, `builtin_amount_generic`. Built-in `name` values are **translation keys** (`scanner_pattern_bank_en`, `scanner_pattern_bank_ar`, `scanner_pattern_generic_amount`); UI displays them with `scannerPatternDisplayName()` (`lib/features/transaction_scanner/utils/scanner_pattern_labels.dart`), which also maps legacy English names for older local DBs.

## Parsing and duplicates

1. Skip OTP/verification-like text (`TransactionParser`).
2. Try enabled patterns in order; first valid amount wins; else generic heuristics (default currency **SAR**; refund keywords → negative amount → income on confirm).
3. `DuplicateDetector`: same package + amount + currency within **60s** → `duplicate` (hidden from pending).
4. Confirm uses draft `personalGroupId` or the first personal group; payer = first participant. Negative `amountCents` → `TransactionType.income`.

## Settings

`scanner_enabled` (default `false`): Settings → Transaction Scanner toggle; syncs to native. Entry also opens **Pending Transactions** → `ScannerHubPage`.

## Privacy and copy

- Drafts/raw notification text are on-device and **not** synced; confirmed expenses use the normal expense sync path.
- User-facing UI: `scanner_*` (plus pattern name keys above) in `assets/translations/en.json` / `ar.json`. Conventions: [I18N.md](I18N.md).
- Disclosure: `privacy_policy_permissions_body` (en + ar) and `web/privacy/index.html` — keep in sync per [PLAY_CONSOLE_DECLARATIONS.md](PLAY_CONSOLE_DECLARATIONS.md) §1. Form answers: same doc §6.

## Related docs

- [PERSONAL_FEATURE.md](PERSONAL_FEATURE.md) — personal groups (confirm target)
- [CODEBASE.md](CODEBASE.md) — overview pointers
- [I18N.md](I18N.md) — localization conventions and key groups
- [PLAY_CONSOLE_DECLARATIONS.md](PLAY_CONSOLE_DECLARATIONS.md) — privacy sync + Data safety
