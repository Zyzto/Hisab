# Release setup (FOSS build)

<!-- markdownlint-disable MD031 MD040 MD060 -->

This is the manual setup behind `.github/workflows/release.yml`, the pipeline
that ships the **FOSS** variant of Hisab from this repository. It does exactly
two things: build signed per-ABI APKs from a tree with no backend, and attach
them to a draft GitHub Release.

It has no Play Store upload, no Firebase deploy, and no production credentials.
The cloud build is produced by a separate private pipeline that attaches its
artifacts to the same release; nothing here can reach it.

If you forked Hisab and run your own backend, this is also the pipeline to copy
— you would add your own defines and signing to it.

---

## 1. Prerequisites

- A fork or clone of this repository on GitHub.
- `keytool` (ships with the JDK).

That is all. There is no account to create, because there is no service to
deploy to.

---

## 2. Generate an Android release keystore

Run once, locally. **Keep the `.jks` safe** — Android identifies an app by its
signature, so losing it means users cannot upgrade in place and must uninstall
first.

```bash
keytool -genkeypair \
  -v \
  -keystore foss-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias hisab-foss \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

Fill in the name and organisation prompts; they end up in the certificate but
are not shown to users.

| Value | What to remember |
|-------|-----------------|
| File  | `foss-keystore.jks` |
| Alias | `hisab-foss` |
| Store password | The `-storepass` value |
| Key password   | The `-keypass` value |

> Never commit the keystore or its passwords. `android/.gitignore` already
> excludes `*.jks` and `key.properties`, and `scripts/verify_security.sh`
> fails the build if one is tracked.

---

## 3. Base64-encode the keystore

GitHub secrets hold text only.

```bash
base64 -w 0 foss-keystore.jks     # Linux
base64 -i foss-keystore.jks | tr -d '\n'   # macOS
```

The output is the value for `FOSS_KEYSTORE_BASE64`. In CI,
`scripts/ci/decode_keystore.sh` turns it back into a keystore and writes
`android/key.properties`.

---

## 4. Add the secrets

**Settings → Secrets and variables → Actions → New repository secret.**

| Secret name | Value |
|-------------|-------|
| `FOSS_KEYSTORE_BASE64` | Output from step 3 |
| `FOSS_KEYSTORE_PASSWORD` | Store password from step 2 |
| `FOSS_KEY_ALIAS` | Key alias, e.g. `hisab-foss` |
| `FOSS_KEY_PASSWORD` | Key password from step 2 |

Four secrets, all signing material, none of which grants access to anything but
the ability to sign an APK with this identity. If the workflow runs without
them, the build falls back to debug signing and produces an APK that is fine
for testing and unsuitable for distribution.

---

## 5. Cut a release

1. Bump the version in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

The format is `MARKETING_VERSION+BUILD_NUMBER`. Increment the build number on
every release; Android refuses to install a build whose version code did not
increase.

2. Commit, tag, push:

```bash
git add pubspec.yaml
git commit -m "Bump version to 1.0.0+1"
git push
git tag v1.0.0
git push origin v1.0.0
```

3. Watch the **Actions** tab.

### What the workflow does

| Job | What it gates |
|-----|----------------|
| `checks` | `scripts/run_release_checks.sh` (secret scan, infra checks), `scripts/ci/assert_offline_only.sh` (no backend dependency crept in), then `flutter test` |
| `build-foss` | `scripts/ci/build_android.sh foss` — per-ABI release APKs, obfuscated, with symbols uploaded as an artifact |
| `github-release` | On `v*` tags only: creates a **draft** release with the three APKs attached |

The release is a draft on purpose. The private cloud pipeline attaches its own
artifacts to the same release afterwards, and publishing early would show users
a release offering only one of the two builds.

### Local preflight

```bash
bash ./scripts/run_release_checks.sh
bash ./scripts/ci/assert_offline_only.sh
flutter test
```

Install the push-time secret scan once per clone:

```bash
bash ./scripts/install_git_hooks.sh
```

The full agent-driven gate is in
[`.cursor/skills/hisab-release-checks/SKILL.md`](../.cursor/skills/hisab-release-checks/SKILL.md).

---

## 6. Building locally

```bash
flutter build apk --release --flavor foss --split-per-abi \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --tree-shake-icons
```

Or just `bash scripts/ci/build_android.sh foss`, which is the same command CI
runs, so a local failure is a real failure rather than an environment
difference.

To sign locally, create `android/key.properties` (gitignored):

```properties
storeFile=/absolute/path/to/foss-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=hisab-foss
keyPassword=YOUR_KEY_PASSWORD
```

Without it, release builds fall back to debug signing.

### Flutter version

`.flutter-version` is the single source of truth. Every workflow reads it, so
upgrading Flutter is a one-line change rather than a hunt through YAML.

### `pubspec_overrides.yaml`

Used to swap in a backend implementation locally; see
[SELF_HOSTING.md](SELF_HOSTING.md). `dart pub` ignores it in git, so it never
affects a release build made from a clean checkout.

---

## 7. App size and update load

Release Android builds use R8 minify plus resource shrinking, `resConfigs`
limited to `en`/`ar`, Dart `--obfuscate` with `--split-debug-info`, and
`--tree-shake-icons`. GitHub Release APKs are `--split-per-abi` rather than one
fat APK. Symbol maps are uploaded as the `foss-symbols` artifact — keep them,
because without them a crash stack from a release build is unreadable.

**Biggest asset win:** the onboarding parallax under `assets/images/parallax/`
is hybrid WebP (lossy q85 for opaque `bg*`, lossless for alpha layers), about
**18.4 MB → ~8.2 MB** in the package. Tessdata stays bundled for offline OCR
(~5.5 MB raw ≈ **~2.7 MB** packaged), which is the price of the scanner working
with no network.

Measure a change for real:

```bash
flutter build appbundle --analyze-size --flavor foss \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --tree-shake-icons
```

Open the generated `*-code-size-analysis_*.json` in DevTools → App size. Smoke
test after any size-focused change: onboarding meadow plus one local receipt
OCR scan.
