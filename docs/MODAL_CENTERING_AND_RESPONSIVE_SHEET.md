# Modal centering and responsive sheet

This document describes modal/dialog centering on web (tablet and desktop), **click-outside-to-close** behavior, and how modals behave when opened from shell vs non–shell routes. For the broader adaptive/responsive plan (breakpoints, SafeArea, large screens), see [ADAPTIVE_RESPONSIVE_PLAN.md](ADAPTIVE_RESPONSIVE_PLAN.md).

## Problems addressed

1. **Centering** – On web tablet/desktop, modals opened from **group**, **invite**, **expense**, or **balance** routes were not centered: they appeared shifted (e.g. to the right with empty space on the left), as if rail padding was being applied when no sidebar was visible. Cause: path/rail logic was sometimes evaluated in the overlay context and reported the wrong route.
2. **Click outside to close** – On desktop web, tapping/clicking outside the modal (on the dimmed barrier) did not close it, because the overlay content is full-size and was absorbing all hit tests; the route’s barrier never received taps.

## Solution overview

1. **Path from caller** – Use the route from the **caller’s** context when opening the sheet (before `showDialog`), so the decision to add rail padding is based on the actual route the user is on.
2. **`centerInFullViewport`** – Optional parameter on `showResponsiveSheet` and `showAppDialog` (default **true**). When `true`, rail padding is never applied; the dialog is always centered in the full viewport. When `false`, the dialog is centered in the content area (e.g. next to the rail on shell routes).
3. **Root navigator size** – Wrapped the router content in `Positioned.fill` in the app builder so the root navigator (and its overlay) gets full viewport size, fixing vertical centering when the overlay previously had loose constraints.
4. **Shared rail logic** – Extracted `_railWidthForDialog()` in `responsive_sheet.dart` so path/rail handling is in one place and both `showResponsiveSheet` and `showAppDialog` use it.
5. **Explicit barrier for click-outside** – On tablet+ the dialog builder returns full-size content (for centering), which would otherwise absorb all taps. A **Stack** is used: underneath, a full-screen `GestureDetector` (when `barrierDismissible` is true) that calls `Navigator.pop` on tap; on top, the centered dialog. Hit testing runs top-down, so taps on the dialog hit the dialog; taps outside hit the barrier and close the modal. On narrow screens, `showModalBottomSheet` is called with `isDismissible: barrierDismissible` so the bottom sheet also closes on barrier tap. Default is **barrierDismissible: true** for all modals (same behavior on mobile and desktop web).

## Files changed

### Core

| File | Change |
|------|--------|
| `lib/app.dart` | Wrapped main content in `Positioned.fill(child: innerContent)` so the root navigator receives full viewport size. |
| `lib/core/layout/responsive_sheet.dart` | Added `_railWidthForDialog()`; added `centerInFullViewport` to `showResponsiveSheet` and `showAppDialog`; use caller path and viewport-sized centering with `LayoutBuilder`; **Stack** with full-screen barrier `GestureDetector` (when `barrierDismissible`) so click-outside closes on desktop web; bottom sheet uses `isDismissible: barrierDismissible`; `Dialog` uses `insetPadding: EdgeInsets.zero`. |
| `lib/core/widgets/sheet_helpers.dart` | Added optional `centerInFullViewport` to `showConfirmSheet` and `showTextInputSheet`, passed through to `showResponsiveSheet`. |

### Modals with `centerInFullViewport: true` (non–home/settings)

- **Groups:** `create_invite_sheet.dart`, `invite_management_page.dart` (QR sheet, revoke confirm), `group_detail_page.dart` (merge, change role, archive/delete/kick participant, edit name, add participant), `group_settings_page.dart` (my_budget, change_currency confirm, settlement_method, edit name, change_icon_color, transfer_ownership, share/use_as_personal/archive/hide confirm, delete_group, leave_group).
- **Expenses:** `expense_form_page.dart` (full features tooltip, category, create_new_tag, add_photo, receipt dialog, to, paid_by, split_type), `expense_detail_shell.dart` (delete expense confirm), `date_time_picker_dialog.dart`.
- **Balance:** `record_settlement_sheet.dart`.
- **Onboarding:** `onboarding_page.dart` (language picker).
- **Auth:** `sign_in_sheet.dart`.
- **Permission:** `permission_service.dart` (permission denied sheet).
- **Receipt:** `receipt_image_view_stub.dart`, `receipt_image_view_io.dart` (full-screen receipt dialogs and fallback sheet).
- **Currency:** `currency_helpers.dart` – `CurrencyHelpers.showPicker(..., centerInFullViewport: true)` from group settings / group create; **`centerInFullViewport: false`** from app settings (favorite currencies) so the picker is centered in the content area next to the rail.

### Unchanged (home/settings only)

Modals opened from **home** or **settings** that should stay in the content area (to the right of the navigation rail when the rail is visible) pass **`centerInFullViewport: false`**. Affected call sites remain in `home_page.dart`, `settings_page.dart`, `edit_profile_sheet.dart`, `services_status_sheet.dart`, and `debug_menu.dart`.

## API

- **`showResponsiveSheet`**  
  - `bool centerInFullViewport = true` – When `true` (default), the dialog is centered in the full viewport (no rail padding) on tablet+. When `false`, center in content area (e.g. next to rail on shell routes).  
  - `bool showDragHandle = true` – When `true` (default), on narrow screens the bottom sheet shows the Material drag handle at the top; on tablet+ the dialog uses a title bar instead. Pass `showDragHandle: false` to hide the handle for a specific sheet.  
  - `bool barrierDismissible = true` – When `true` (default), tapping/clicking outside the modal (on the barrier) closes it on all platforms. On tablet+ an explicit full-screen barrier `GestureDetector` is used so the overlay content does not absorb taps; on narrow screens `showModalBottomSheet(..., isDismissible: barrierDismissible)`.

- **`showAppDialog`**  
  - `bool centerInFullViewport = true` – Same semantics as above for full-screen/custom dialogs (default: full viewport).  
  - `bool barrierDismissible = true` – Same click-outside-to-close behavior; explicit barrier used on tablet+.

- **`showConfirmSheet`** / **`showTextInputSheet`**  
  - `bool centerInFullViewport = true` – Passed through to `showResponsiveSheet` (default: full viewport).

## Other behavior

- **Drag handle** – The drag handle is provided by `showResponsiveSheet` on narrow screens (and web bottom sheet). **Sheet content must not draw its own drag handle**; otherwise two handles appear. On tablet+ the dialog uses a title bar instead of a handle.

## Adding new modals

- If the modal is only ever opened from **home** or **settings** (shell routes), pass **`centerInFullViewport: false`** so it is centered in the content area next to the rail.
- If the modal can be opened from **group**, **invite**, **expense**, **balance**, **onboarding**, or any other non–shell route, you can rely on the default (`centerInFullViewport` is `true`).
- All modals close when the user taps/clicks outside (barrier) by default; pass `barrierDismissible: false` only when the modal must not be dismissible (e.g. critical progress).
- Do not add a drag handle inside the sheet content; the responsive sheet provides it on narrow screens.
