# Modal centering and responsive sheet

<!-- markdownlint-disable MD060 -->

This document describes modal/dialog centering on web (tablet and desktop), **click-outside-to-close** behavior, shell vs non-shell centering, and the shared flat-panel sheet design language. For the broader adaptive/responsive plan (breakpoints, SafeArea, large screens), see [ADAPTIVE_RESPONSIVE_PLAN.md](ADAPTIVE_RESPONSIVE_PLAN.md).

## Problems addressed

1. **Centering** – On web tablet/desktop, modals opened from **group**, **invite**, **expense**, or **balance** routes were not centered: they appeared shifted (e.g. to the right with empty space on the left), as if rail padding was being applied when no sidebar was visible. Cause: path/rail logic was sometimes evaluated in the overlay context and reported the wrong route.
2. **Click outside to close** – On desktop web, tapping/clicking outside the modal (on the dimmed barrier) did not close it, because the overlay content is full-size and was absorbing all hit tests; the route’s barrier never received taps.

## Solution overview

1. **Path from caller** – Use the route from the **caller’s** context when opening the sheet (before `showDialog`), so the decision to add rail padding is based on the actual route the user is on.
2. **`centerInFullViewport`** – Optional parameter on `showResponsiveSheet` and `showAppDialog` (default **true**). When `true`, rail padding is never applied; the dialog is always centered in the full viewport. When `false`, the dialog is centered in the content area (e.g. next to the rail on shell routes).
3. **Root navigator size** – Wrapped the router content in `Positioned.fill` in the app builder so the root navigator (and its overlay) gets full viewport size, fixing vertical centering when the overlay previously had loose constraints.
4. **Shared rail logic** – Extracted `_railWidthForDialog()` in `responsive_sheet.dart` so path/rail handling is in one place and both `showResponsiveSheet` and `showAppDialog` use it.
5. **Explicit barrier for click-outside** – On tablet+ the dialog builder returns full-size content (for centering), which would otherwise absorb all taps. A **Stack** is used: underneath, a full-screen `GestureDetector` (when `barrierDismissible` is true) that calls `Navigator.pop` on tap; on top, the centered dialog. Hit testing runs top-down, so taps on the dialog hit the dialog; taps outside hit the barrier and close the modal. On narrow screens, `showModalBottomSheet` is called with `isDismissible: barrierDismissible` so the bottom sheet also closes on barrier tap. Default is **barrierDismissible: true** for all modals (same behavior on mobile and desktop web).

## Adaptive morph (resize)

`showResponsiveSheet` uses a **single** `showGeneralDialog` route. Layout is driven by live `MediaQuery` width:

- **≥ 600** – centered floating panel (optional rail inset when `centerInFullViewport: false`)
- **&lt; 600** – bottom-aligned sheet

Crossing the breakpoint (window shrink/grow on web/desktop) **animates** alignment, width, radius, and chrome (title bar ↔ drag handle) over ~320ms. Callers do not need to close/reopen the sheet.

## Visual language (phone + large)

One composition language; **two layouts**, not two brands:

| Aspect | Rule |
|--------|------|
| Radius | **16** for dialog and phone bottom sheet (matches `AccentSurfaces.flatPanel`) |
| Fill / border | `surfaceContainerLow` + `outlineVariant` @ 0.45 |
| Tablet title bar | Flat, hairline bottom, close icon; **padding inside** `showResponsiveSheet` (16 top / 12 bottom) — do not pad the title bar from call sites |
| Phone drag handle | **One** affordance from `showResponsiveSheet`; sheet bodies must not draw a second pill |
| Option rows | `SheetOptionTile` / `SheetOptionList` (default list padding `16,8,16,8`) or `showOptionPickerSheet` |
| Confirm / text input | `showConfirmSheet` / `showTextInputSheet` with body in `AccentSurfaces.flatPanel` |
| Actions | Primary filled + secondary text; destructive = error-toned; phone Cancel; tablet close/barrier |

Shared APIs: `lib/core/layout/responsive_sheet.dart`, `lib/core/widgets/sheet_helpers.dart`, `lib/core/widgets/sheet_option_tile.dart`.

## Files changed (core)

| File | Role |
|------|------|
| `lib/app.dart` | `Positioned.fill` so root navigator gets full viewport size |
| `lib/core/layout/responsive_sheet.dart` | Adaptive chrome, rail padding, barrier dismiss, flat panel surfaces |
| `lib/core/widgets/sheet_helpers.dart` | `buildSheetShell`, `showConfirmSheet`, `showTextInputSheet`, `showOptionPickerSheet` |
| `lib/core/widgets/sheet_option_tile.dart` | Dense bordered option rows for pickers and action lists |

## Centering contract

### Shell routes → `centerInFullViewport: false`

Opened from **home**, **settings** (incl. nested settings routes), **archived**, debug menu, or services status chip so the dialog sits in the content area next to the permanent desktop sidenav (240px; mid-band temporary drawer reserves 0):

- `home_page.dart` — create chooser, list options
- `settings_page.dart` — language/theme/scheme/color/font pickers, currency/favorites, confirms, delete local/cloud, migration, API key, logs, about, import
- `edit_profile_sheet.dart`, `change_password_sheet.dart`
- `services_status_sheet.dart`
- `debug_menu.dart`
- Transaction scanner confirms/sheets (opened from settings hub)
- `CurrencyHelpers.showPicker(..., centerInFullViewport: false)` from app settings

### Non-shell routes → default `true`

Group, invite, expense, balance, onboarding, auth, permission sheets keep full-viewport centering unless a nested sheet explicitly opts out.

## API

- **`showResponsiveSheet`**
  - `bool centerInFullViewport = true` – When `true` (default), the dialog is centered in the full viewport (no rail padding) on tablet+. When `false`, center in content area (e.g. next to rail on shell routes).
  - `bool showDragHandle = true` – When `true` (default), on narrow screens the bottom sheet shows the Material drag handle at the top; on tablet+ the dialog uses a title bar instead. Pass `showDragHandle: false` to hide the handle for a specific sheet.
  - `bool barrierDismissible = true` – When `true` (default), tapping/clicking outside the modal (on the barrier) closes it on all platforms via an explicit full-screen barrier `GestureDetector`.

- **`showAppDialog`**
  - `bool centerInFullViewport = true` – Same semantics as above for full-screen/custom dialogs (default: full viewport).
  - `bool barrierDismissible = true` – Same click-outside-to-close behavior; explicit barrier used on tablet+.

- **`showConfirmSheet`** / **`showTextInputSheet`** / **`showOptionPickerSheet`**
  - `bool centerInFullViewport = true` – Passed through to `showResponsiveSheet` (default: full viewport).

## Other behavior

- **Drag handle** – Provided by `showResponsiveSheet` on narrow screens (and web bottom sheet). **Sheet content must not draw its own drag handle**; otherwise two handles appear. On tablet+ the dialog uses a title bar instead of a handle.
- **Keyboard (IME)** – The adaptive host pads by `MediaQuery.viewInsets.bottom` (not via `AnimatedContainer` height) so sheets lift with the keyboard without replaying the modal open morph. Phone bottom `SafeArea` is off while the IME is up so the home-indicator inset does not leave a gap above the keyboard. Sheet bodies should not re-apply bottom safe/viewPadding (host owns it).
- **Custom tag editor** – Create/edit category sheets use `TagEditorSheetShell` (`tag_style_fields.dart`): scrollable name + style pickers, sticky one-row footer (dynamic-width preview chip + trailing Cancel/Done, RTL-aware).
- **Services status** – Nests a `DraggableScrollableSheet` inside the responsive sheet; chrome changes must preserve height/drag sizing.
- **Scanner** – Destructive/confirm flows use `showConfirmSheet` / `showResponsiveSheet` (not raw `AlertDialog`).

## Adding new modals

- If the modal is only ever opened from **home** or **settings** (shell routes), pass **`centerInFullViewport: false`** so it is centered in the content area next to the rail.
- If the modal can be opened from **group**, **invite**, **expense**, **balance**, **onboarding**, or any other non–shell route, you can rely on the default (`centerInFullViewport` is `true`).
- Prefer `showConfirmSheet` / `showTextInputSheet` / `showOptionPickerSheet` over ad-hoc `AlertDialog` or dense `ListTile` stacks.
- All modals close when the user taps/clicks outside (barrier) by default; pass `barrierDismissible: false` only when the modal must not be dismissible (e.g. critical progress).
- Do not add a drag handle inside the sheet content; the responsive sheet provides it on narrow screens.
- Prefer `AccentSurfaces.flatPanel` / `panel` for form blocks; avoid nested Material Cards inside sheets.
