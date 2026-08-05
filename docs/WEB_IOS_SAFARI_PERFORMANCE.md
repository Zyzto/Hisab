# iOS Safari / PWA Performance

Flutter web is **not one platform**. iOS WebKit (Safari + every iOS browser + Home Screen PWAs), Android Chrome, desktop browsers, and native iOS/Android each need different budgets. Policy lives in [`lib/core/platform/ui_perf.dart`](../lib/core/platform/ui_perf.dart) (`UiPerf`).

## Research snapshot (2025–2026)

Sources: [Flutter Wasm docs](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter renderers](https://docs.flutter.dev/platform-integration/web/renderers), Flutter issues [#176327](https://github.com/flutter/flutter/issues/176327) / [#179784](https://github.com/flutter/flutter/issues/179784) / [#178524](https://github.com/flutter/flutter/issues/178524) / [#187660](https://github.com/flutter/flutter/issues/187660) / [#188796](https://github.com/flutter/flutter/issues/188796), WebKit blur/compositor guidance.

| Finding | Implication for Hisab |
|---|---|
| Global `ensureSemantics()` causes severe iOS WebKit scroll jank | Keep `ENABLE_WEB_SEMANTICS=false` in production |
| CanvasKit is still the practical default on many iOS Safari builds; Skwasm/`--wasm` is Chromium-strong and Safari readiness is gated (WasmGC + presentation bugs; `skwasm_heavy` often required) | Keep default CanvasKit release; A/B `--wasm` on real iPhones only |
| CanvasKit + network images can leak GPU memory on iOS WebKit | Prefer local/cached images; avoid thrashing network image lists on iOS web |
| Large blur / dual shadows / backdrop-filter are top mobile scroll killers | Cheap shadows **only on iOS web** |
| Opacity crossfades that paint two full trees burn XR-class GPUs | Instant shell tabs **only on iOS web** |
| Chart touch layers fight finger scroll on coarse pointers | Disable fl_chart touch on **mobile web** (iOS + Android browsers) |
| Async/deferred third-party JS improves INP / first paint | Firebase SDK loads async before Flutter bootstrap (all web) |
| OPFS needs COOP/COEP; breaks cross-origin Firebase CDN | Do **not** enable isolation headers in Hosting while using gstatic Firebase |

## Platform matrix

| Optimization | iOS web | Android web | Desktop web | Native iOS | Native Android |
|---|---|---|---|---|---|
| Cheap nav / segment shadows | yes (`UiPerf`) | no | no | no | no |
| Instant Home↔Settings (no Opacity crossfade) | yes | no | no | no | no |
| Instant group-detail tab switch | yes | no | no | no | no |
| Fade-only page transitions (GoRouter `appFadeSlidePage` + Material `PageTransitionsTheme`) | yes | no | no | no | no |
| Disable chart touch tooltips (bar/line) | yes | yes (mobile) | no | no | no |
| Skip legend `Opacity` / progress tweens | yes | yes (mobile) | no | no | no |
| Onboarding: no chrome demo timers / lazy steps | yes | no | no | no | no |
| Cheap home list drag feedback (no dual-blur / Opacity) | yes (`UiPerf`) | no | no | no | no |
| Network image decode caps (`cacheWidth`) | capped 1280px | display×DPR | display×DPR | display×DPR | display×DPR |
| Sliver home group list + `RepaintBoundary` | yes | yes | yes | yes | yes |
| Lazy group-detail `PageView.builder` + keepAlive | yes | yes | yes | yes | yes |
| App root `listenManual` for sync/scanner | yes | yes | yes | yes | yes |
| Async Firebase boot | yes | yes | yes | n/a | n/a |
| Semantics off by default | yes (critical) | yes | yes | n/a (native a11y) | n/a |
| Full floating-nav blur shadows | no | yes | yes | yes | yes |
| Shell tab crossfade | no | yes | yes | yes | yes |

Detection for web OS uses the existing PWA UA helpers (`isPwaIos` / `isPwaAndroid` / `isPwaMobile` in `lib/core/pwa/`).

### Done in follow-ups

- Profile page: `CustomScrollView` section slivers + lazy activity/group lists
- Home reorder: custom `HomeReorderableGroupsSliver` (long-press drag + insert line; no nested `shrinkWrap`)
- Settings lazy-mount in shell (created on first visit)
- Receipt scan AI: web stub export (no Tesseract/Vision / Nano / cloud scan on web); Settings → Receipt / AI hidden on web; photos attach/upload still work

## Current project decisions

- Default: do **not** force-enable web semantics (`ENABLE_WEB_SEMANTICS=false`).
- Accessibility builds may pass `--dart-define=ENABLE_WEB_SEMANTICS=true` (expect iOS scroll cost).
- Web SQLite change detection: **1.5s poll**, fingerprint-gated (avoids rebuild ticks during Safari scroll).
- Visual / interaction cheap-paths: gated by `UiPerf` per surface above.

## Renderer strategy (rollout)

- Default release: `flutter build web` → **CanvasKit**.
- Optional workflow input `web_build_mode=wasm` for staging A/B.
- On iOS, expect JS/CanvasKit fallback until Flutter’s Safari Skwasm path is production-ready; do not flip production to wasm-only based on Chromium numbers alone.
- Validate on a real iPhone XR (or similar) before promoting wasm.

## OPFS headers (not enabled in Hosting)

Local experiment only:

```bash
flutter run -d chrome \
  --web-header "Cross-Origin-Opener-Policy=same-origin" \
  --web-header "Cross-Origin-Embedder-Policy=require-corp"
```

## Verification checklist

Prefer a physical **iPhone XR-class** device + Home Screen PWA, then compare Android Chrome PWA and native builds.

- **iOS web:** Home scroll 10–15s; Home↔Settings feels instant; nav has light border (not soft blur); analytics scrolls without tooltip fights; page pushes are fade-only.
- **Android web:** Home↔Settings still crossfades; nav keeps soft shadow; chart tooltips off on phone.
- **Native:** Full motion + shadows unchanged; home list still uses slivers.

## Build examples

```bash
# Production baseline
flutter build web --dart-define=ENABLE_WEB_SEMANTICS=false

# Accessibility-targeted (slower on iOS Safari)
flutter build web --dart-define=ENABLE_WEB_SEMANTICS=true

# Staging Wasm experiment (still falls back to CanvasKit where Skwasm is unsafe)
flutter build web --wasm --dart-define=ENABLE_WEB_SEMANTICS=false
```
