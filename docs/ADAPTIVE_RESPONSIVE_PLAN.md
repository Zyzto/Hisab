# Adaptive and Responsive Design Plan (Hisab)

This plan is based on the [Flutter Adaptive and Responsive Design](https://docs.flutter.dev/ui/adaptive-responsive) documentation. It maps each doc section to the current Hisab codebase and lists concrete changes.

**References:** [Overview](https://docs.flutter.dev/ui/adaptive-responsive) · [General approach](https://docs.flutter.dev/ui/adaptive-responsive/general) · [SafeArea & MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery) · [Large screens](https://docs.flutter.dev/ui/adaptive-responsive/large-screens) · [User input](https://docs.flutter.dev/ui/adaptive-responsive/input) · [Best practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices) · [Capabilities & policies](https://docs.flutter.dev/ui/adaptive-responsive/capabilities) · [More info](https://docs.flutter.dev/ui/adaptive-responsive/more-info)

---

## 1. General approach (Abstract → Measure → Branch)

### Current state

- **Abstract:** Navigation is already abstracted: `MainScaffold` switches between `FloatingNavBar` (bottom) and `NavigationRail` by width; destinations are shared (groups, settings). Sheets use `showResponsiveSheet` (bottom sheet vs centered dialog by width).
- **Measure:** `LayoutBreakpoints` uses **`MediaQuery.sizeOf(context).width`** only (window size). No `LayoutBuilder` where local constraints matter.
- **Branch:** Breakpoints align with [Material 3](https://m3.material.io/foundations/layout/applying-layout/window-size-classes): tablet ≥600px, desktop ≥840px; content max width 600/720.

### Planned changes

| Priority | Change | Where | Notes |
|----------|--------|--------|------|
| Low | Prefer **`MediaQuery.sizeOf(context)`** everywhere (already used in `LayoutBreakpoints`); avoid `MediaQuery.of(context).size` for consistency. | Any new code | Doc recommends `sizeOf` for window size; existing usage is fine. |
| Low | Where a widget’s layout should depend on **its allocated space** (e.g. a card that switches to compact when narrow), add **`LayoutBuilder`** and branch on `constraints.maxWidth` instead of window size. | Per-widget if needed | Not required for current shell/content; useful for future list/grid items. |

---

## 2. SafeArea & MediaQuery

### Current state

- **SafeArea:** Used in many places: scaffold bodies (e.g. `main.dart`, `app.dart`), sheets (`sheet_helpers.dart`, onboarding, settings, group create, invite, expense form, etc.), `FloatingNavBar`, `ConnectionBanner`, debug menu. Doc recommends wrapping scaffold **body** (not whole scaffold); current usage is mixed (some body, some full screen).
- **MediaQuery:** Used for padding (safe area, view insets), size (max heights for dialogs/sheets), 24h format, and breakpoints. No nesting issues observed with SafeArea.

### Planned changes

| Priority | Change | Where | Notes |
|----------|--------|--------|------|
| Low | Standardize: prefer **SafeArea around scaffold body** where content must avoid notches/system UI; avoid wrapping entire Scaffold so AppBar can extend under status bar if desired. | `main.dart`, `app.dart`, feature scaffolds | Doc: “wrap the body of a Scaffold”; current pattern is already reasonable. |
| Low | When adding new full-screen routes, ensure body (or the scrollable content) is inside SafeArea so content isn’t clipped by notches/cutouts. | New pages | Already done for existing pages. |

---

## 3. Large screens (layout, GridView, foldables)

### Current state

- **Content width:** `ConstrainedContent` + `LayoutBreakpoints` limit body width (600/720) and center; no full-width text/boxes on large screens. Aligns with “don’t gobble horizontal space.”
- **App bar:** **ContentAlignedAppBar** places the title in the same horizontal band as the body (via `contentBandMetrics`); used on all pages with constrained body so the title scales with content. See `lib/core/layout/content_aligned_app_bar.dart` and CODEBASE “Layout (core/layout)”.
- **Lists:** Home uses **`ListView`** / **`ReorderableListView`**; no **`GridView`** on large screens. Doc and [Android large screen guidelines](https://developer.android.com/docs/quality-guidelines/large-screen-app-quality) suggest considering grid layouts so items don’t stretch to full width.
- **Orientation:** No explicit orientation lock found in codebase; good for foldables and multi-window.
- **Foldables:** No use of **Display** API; doc says use physical display size only when supporting foldables with orientation lock. Not required unless we lock orientation.

### Planned changes

| Priority | Change | Where | Notes |
|----------|--------|--------|------|
| Medium | **Consider `GridView` (or grid-like layout) for home groups list** on tablet/desktop so cards don’t span full content width; keep list on narrow. Use same breakpoints (e.g. `LayoutBreakpoints.isTabletOrWider`) and `SliverGridDelegateWithMaxCrossAxisExtent` or fixed count. | `lib/features/home/pages/home_page.dart` | Doc: “ListView → GridView” for large screens; improves large-screen quality. |
| Low | If we ever lock orientation (not recommended), use **Display** API for physical dimensions on foldables instead of MediaQuery in that path. | N/A unless orientation lock added | Doc: foldables + portrait lock can letterbox; prefer supporting all orientations. |

---

## 4. User input & accessibility (keyboard, mouse, shortcuts)

### Current state

- **Scroll:** ListView/ScrollView used; scroll wheel works by default. No custom scroll-only widgets that would need `Listener` for `PointerScrollEvent`.
- **Focus:** Some `FocusNode` / `FocusManager.instance.primaryFocus` (e.g. back dismiss, expense form). No app-wide **Shortcuts** or **FocusTraversalGroup**; no **FocusableActionDetector** for custom controls.
- **Keyboard shortcuts:** None defined (no `Shortcuts` / `Actions` / `HardwareKeyboard` handlers).
- **Mouse:** Material buttons get default cursor/focus; no **MouseRegion** for custom widgets. No explicit cursor for custom tappable areas.
- **VisualDensity:** Used locally (e.g. `VisualDensity.compact` in group create, expense split, group settings); not set at theme level for touch vs pointer.

### Planned changes

| Priority | Change | Where | Notes |
|----------|--------|--------|------|
| Medium | Add **keyboard shortcuts** for main actions (e.g. new expense, new group, refresh, navigate home/settings) using **`Shortcuts`** + **`Actions`** in the shell or app root; ensure focus is on a widget that can receive them (or use scoped Focus). | `MainScaffold` or `App` / router builder | Doc: “keyboard accelerators” for desktop/web; improves accessibility and power users. |
| Medium | Add **tab traversal**: ensure all interactive elements are focusable; use **FocusTraversalGroup** for forms (e.g. expense form, group create) so Tab order is logical. | Expense form, group create, settings forms | Doc: “tab traversal and focus”; critical for keyboard and assistive tech. |
| Low | For **custom tappable widgets** (e.g. group cards, custom buttons), add **MouseRegion** with `cursor: SystemMouseCursors.click` and ensure focus/hover states where appropriate. | e.g. `GroupCard`, any custom gesture-only UI | Doc: “Mouse enter, exit, and hover”; Material buttons already handle this. |
| Low | Consider **theme-level VisualDensity** (e.g. less dense on desktop/mouse) so hit areas and density adapt; keep touch-first. | `app_theme.dart` or theme provider | Doc: “Visual density”; optional polish. |

---

## 5. Best practices

### Current state

- **Break down widgets:** Many feature pages are large (e.g. `settings_page.dart`, `expense_form_page.dart`); could be split further for readability and const reuse.
- **Don’t lock orientation:** No lock found; good.
- **Avoid orientation-based layouts:** No `OrientationBuilder` or `MediaQuery.orientation` for layout branching; we use width only. Good.
- **Don’t gobble horizontal space:** `ConstrainedContent` and max widths used; good.
- **Avoid device-type checks for layout:** We use **width** (MediaQuery) for rail vs bottom nav and sheet vs dialog. **`kIsWeb`** is used for: scrollbars, DB path, PWA banner, invite flow, receipt long-press, logging. Doc says avoid “phone vs tablet” for layout; we don’t use device type for layout. `kIsWeb` is used for capabilities (e.g. no file path, different storage), which is acceptable but could be moved to a Capability (see below).
- **Restore list state:** No **PageStorageKey** on home list or other scrollables; rotation/resize may lose scroll position.
- **Save app state:** No explicit handling; rely on framework and plugins. Doc suggests verifying plugins support large screens and fold/unfold.

### Planned changes

| Priority | Change | Where | Notes |
|----------|--------|--------|------|
| Medium | Add **PageStorageKey** to main scrollables (e.g. home `ListView`/`ReorderableListView`, settings `ListView`, group detail content) so scroll position is restored on orientation or window size change. | `home_page.dart`, `settings_page.dart`, `group_detail_page.dart` | Doc: “Restore List state”; Wonderous example. |
| Low | Continue **refactoring** large pages into smaller widgets for readability and const reuse; no layout change required. | `settings_page.dart`, `expense_form_page.dart`, etc. | Doc: “Break down your widgets.” |
| Low | Keep **no orientation lock**; if a product requirement forces portrait, use Display API for foldables and document the exception. | N/A | Doc: “Don’t lock the orientation.” |

---

## 6. Capabilities & policies

### Current state

- **Platform checks:** **`kIsWeb`** and **`Platform.isAndroid`** (e.g. image picker init) used directly in feature and core code. Doc recommends **Capability** and **Policy** classes so behavior is named (e.g. “can use file paths”) and testable/mockable.
- No central **Policy** or **Capability** classes; logic is scattered.

### Planned changes

| Priority | Change | Where | Notes |
|----------|--------|--------|------|
| Low | Introduce a **Capability** (e.g. `hasFilePaths`, `hasPersistentLocalStorage`) and optionally a **Policy** for “show purchase link” / “use web-only logging” style decisions. Replace direct `kIsWeb` / `Platform` checks in layout or business logic with calls to these classes so tests can mock and intent is clear. | New: e.g. `lib/core/capabilities.dart`; then refactor `main.dart`, `powersync_repository.dart`, `theme_providers.dart`, etc. | Doc: “Capabilities” vs “Policies”; name methods by intent, not device. |
| Low | Keep **platform checks** only where truly required (e.g. platform channel, plugin init); move “should we show X” and “can we do Y” into Policy/Capability. | As above | Reduces coupling to Platform/kIsWeb. |

---

## 7. Main widgets summary (current vs planned)

| Widget / area | Current | After plan (main items) |
|---------------|---------|--------------------------|
| **LayoutBreakpoints** | MediaQuery.sizeOf, width-only, 600/840 | No change; already correct. |
| **ConstrainedContent** | Centers + max width; infers rail from constraints | No change. |
| **MainScaffold** | Rail vs bottom nav by width; IndexedStack for home/settings | Optional: wrap with Shortcuts/Actions for app-level shortcuts. |
| **Home page** | ListView / ReorderableListView | Consider GridView on tablet+; add PageStorageKey to list(s). |
| **Settings page** | ListView in ConstrainedContent | Add PageStorageKey. |
| **Sheets / dialogs** | SafeArea, MediaQuery for max height | Keep; optional VisualDensity at theme. |
| **Forms (expense, group create)** | Focus used locally | FocusTraversalGroup; optional Shortcuts for Save/Cancel. |
| **Custom cards / buttons** | GestureDetector / InkWell | MouseRegion + cursor where not covered by Material. |
| **Platform / web** | kIsWeb, Platform in many places | Optional: Capability/Policy classes for testability and clarity. |

---

## 8. Suggested implementation order

1. **High impact, low risk:** PageStorageKey on main lists (home, settings, group detail).
2. **High impact, medium effort:** Keyboard shortcuts (Shortcuts + Actions) for primary actions; FocusTraversalGroup on key forms.
3. **Medium impact:** GridView (or grid layout) for home on tablet+.
4. **Polish:** MouseRegion/cursor on custom widgets; theme VisualDensity; refactor large pages.
5. **Structural:** Capability/Policy classes and replace direct Platform/kIsWeb where it improves clarity and testing.

---

*This plan is a living document; update it as changes are implemented or requirements evolve.*
