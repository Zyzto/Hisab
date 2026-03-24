# iOS Safari Web Performance

This note explains why Flutter web can feel much slower on iOS Safari than Android and how this repo mitigates it.

## Diagnosis summary

- iOS Safari has known Flutter web performance issues around accessibility semantics and scrolling.
- This app previously enabled semantics globally on web startup via `SemanticsBinding.instance.ensureSemantics()`.
- Enabling semantics globally can significantly degrade scroll/input smoothness on iOS Safari.

## Current project decision

- Default behavior: do **not** force-enable web semantics.
- Accessibility opt-in remains available through build-time define:
  - `--dart-define=ENABLE_WEB_SEMANTICS=true`
- Production web builds default to:
  - `--dart-define=ENABLE_WEB_SEMANTICS=false`

This keeps iOS Safari responsive for most users while still allowing accessibility-targeted builds.

## Renderer strategy (rollout)

- Default release path remains standard `flutter build web` (CanvasKit path).
- Manual release runs can choose WebAssembly mode (`--wasm`) through workflow input `web_build_mode=wasm`.
- Rollout recommendation:
  1. Validate `wasm` on staging and real iOS Safari devices.
  2. Compare startup time, scroll FPS, and interaction latency.
  3. Keep default mode unless `wasm` is consistently better across your supported browsers/devices.

## Verification checklist (iOS Safari)

Use a real iPhone and Safari with production-like build.

- Home:
  - Scroll group list continuously for 10-15 seconds.
  - Open/close group cards and confirm no visible frame stutter spikes.
- Settings:
  - Scroll entire page top-to-bottom multiple times.
  - Toggle a few settings and ensure touch response remains immediate.
- Group detail:
  - Navigate between tabs/sections and scroll long content.
  - Open and close at least one responsive sheet/dialog.
- Analytics page:
  - Switch chart modes and range filters.
  - Scroll while charts are visible and watch for dropped frames.
- Regression compare:
  - Compare with Android Chrome on the same account/data size.
  - If iOS remains poor, test a build with `--wasm` and compare.

## Build examples

Default web build (recommended baseline):

```bash
flutter build web --dart-define=ENABLE_WEB_SEMANTICS=false
```

Accessibility-focused web build:

```bash
flutter build web --dart-define=ENABLE_WEB_SEMANTICS=true
```

Wasm experiment:

```bash
flutter build web --wasm --dart-define=ENABLE_WEB_SEMANTICS=false
```
