---
name: hisab-ui-perf
description: >-
  Optimize Hisab Flutter UI for iOS Safari PWA, Android web, desktop web, and
  native with per-surface budgets (UiPerf). Use when the user mentions PWA lag,
  iPhone/iOS Safari jank, web performance, CanvasKit, scroll stutter, UiPerf,
  cheap shadows, or asks to optimize onboarding/home/shell for mobile web.
---

# Hisab UI / PWA performance

Flutter web is **not one platform**. Gate visual cheap-paths per surface; keep universal wins unconditional.

**Do not start the app** (`never run project`). Prefer code + tests + docs.

## Canonical files

| Role | Path |
|------|------|
| Runtime flags | `lib/core/platform/ui_perf.dart` |
| Pure policy + tests | `lib/core/platform/ui_perf_logic.dart`, `test/core/ui_perf_policy_test.dart` |
| Image decode caps | `lib/core/platform/network_image_decode.dart` |
| Web OS detection | `lib/core/pwa/pwa_capabilities*.dart` (`isPwaIos` / `isPwaAndroid` / `isPwaMobile`) |
| Doc + matrix | `docs/WEB_IOS_SAFARI_PERFORMANCE.md` |
| Boot / Firebase async | `web/index.html`, `web/flutter_bootstrap.js` |
| Semantics default | `lib/main.dart` (`ENABLE_WEB_SEMANTICS=false` in prod) |

## Workflow

```
Perf task:
- [ ] 1. Identify surface(s): iOS web / Android web / desktop web / native
- [ ] 2. Prefer UiPerf gates for visual/motion; never blanket “all web”
- [ ] 3. Apply universal list/rebuild/image wins everywhere
- [ ] 4. Extend UiPerfPolicy + unit test when adding a new flag
- [ ] 5. Update docs/WEB_IOS_SAFARI_PERFORMANCE.md matrix
- [ ] 6. Avoid COOP/COEP in firebase.json (breaks gstatic Firebase)
```

## Platform rules (do not collapse)

| Flag / behavior | iOS web | Android web | Desktop web | Native |
|---|---|---|---|---|
| `preferCheapShadows` | yes | no | no | no |
| `preferInstantShellTabs` | yes | no | no | no |
| `preferFadeOnlyPageTransitions` | yes | no | no | no |
| `preferReducedChromeMotion` | yes | no | no | no |
| `preferCheapListDrag` (home reorder feedback) | yes | no | no | no |
| `preferCheapCharts` (bar/line touch) | yes | yes (mobile) | no | no |
| Slivers / `RepaintBoundary` / `cacheWidth` | yes | yes | yes | yes |
| Lazy `PageView.builder` + keepAlive | yes | yes | yes | yes |
| Semantics forced on | never in prod | never in prod | never in prod | n/a |

Detection: `kIsWeb && isPwaIos` (all iOS browsers are WebKit).

## What to hunt

### High cost on iOS WebKit / XR-class GPUs
- Large / dual `BoxShadow` blur, `Opacity` crossfades painting two trees
- Looping timers that `setState` chrome (theme demos, pulses, hint tickers)
- `PageView(children: [...])` mounting every tab
- Eager `ListView(children:)` / nested `shrinkWrap` scrollables
- Uncapped `Image.network` / `Image.asset` (CanvasKit GPU texture pressure)
- Chart touch tooltips fighting scroll
- `ref.watch` of long-lived services at `App` root (prefer `listenManual`)

### Universal (all platforms)
- `CustomScrollView` + `SliverChildBuilderDelegate` / `SliverReorderableList`
- `PageView.builder` + `AutomaticKeepAliveClientMixin` after first visit
- Lazy-mount heavy shell tabs (e.g. Settings on first open)
- Conditional imports so web never pulls ML Kit / langchain / receipt AI
- Fingerprint-gated web DB polling (already in PowerSync repo layer)

## Patterns to copy

**Gate a shadow**
```dart
boxShadow: UiPerf.preferCheapShadows
    ? [/* tiny blur or null + border */]
    : [/* full dual blur */],
```

**Lazy PageView tab**
```dart
PageView.builder(
  itemCount: n,
  itemBuilder: (_, i) => _KeepAlive(child: tabFor(i)),
);
```

**Decode-sized image**
```dart
final d = NetworkImageDecode.cacheSize(context, logicalWidth: w, logicalHeight: h);
Image.network(url, cacheWidth: d.width, cacheHeight: d.height, ...);
```

**New flag**
1. Add getter on `UiPerfPolicy` (pure)
2. Expose on `UiPerf`
3. Test matrix in `test/core/ui_perf_policy_test.dart`
4. Document row in `docs/WEB_IOS_SAFARI_PERFORMANCE.md`

## Hard no’s

- Do **not** enable production web semantics for “a11y by default” (iOS scroll jank)
- Do **not** set Hosting `COOP`/`COEP` while Firebase loads from gstatic
- Do **not** apply iOS-web cheap polish to native or Android Chrome “because web”
- Do **not** flip release to `--wasm` only from Chromium numbers; A/B on a real iPhone

## Verify (device)

Prefer physical **iPhone XR-class** Home Screen PWA, then Android Chrome PWA, then native:

- Home scroll 10–15s; Home↔Settings; group tabs; analytics scroll; onboarding chrome idle CPU
- Confirm iOS web: instant tabs, light nav shadow, no demo timers thrashing
- Confirm native/Android web: fuller motion/shadows still present where policy says so
