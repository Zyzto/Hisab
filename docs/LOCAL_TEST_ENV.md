# Local test environment

<!-- markdownlint-disable MD060 -->

One-command local stack for Hisab: **Supabase** (Auth, Postgres, Storage, Edge Functions) on your machine or LAN. Use a **separate testing Firebase project** only when you need real FCM; everything else stays local.

Script entrypoint: `./scripts/local_test_env.sh` · App defines: `dart_defines_local.json` (generated / gitignored).

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| Flutter SDK ^3.11.0 | `flutter --version` |
| **Podman (rootful)** | `sudo systemctl enable --now podman.socket`; user in `podman` group |
| Supabase CLI | On NixOS: `pkgs.supabase-cli` (not `npx` — dynamic binary fails). Elsewhere: `supabase` or `npx supabase` |
| Chrome + ChromeDriver | Only for web integration tests |
| LAN firewall | Allow TCP **54321** (API) and **8080** (Flutter web / redirects) to devices |

**NixOS Supabase CLI:** add `pkgs.supabase-cli` to `environment.systemPackages`, or the scripts auto-use `nix shell nixpkgs#supabase-cli` when `supabase` is not on `PATH`. Prefer CLI **≥ 2.109**.

**Verified on NixOS:** rootful Podman + CLI 2.109.x → Kong healthy (`curl …/auth/v1/health` → `200`). Rootless fails here with Kong `can't create /home/kong/kong.yml: Permission denied` (see [supabase/cli#3099](https://github.com/supabase/cli/issues/3099) for related history; CLI ≥ 2.13.6 fixed some rootless cases, not this volume write).

`[analytics] enabled = false` in `supabase/config.toml` (syslog log driver breaks Kong on Podman). Edge uses `policy = "per_worker"`. `og-invite-image` may still `503 BOOT_ERROR` locally (heavy esm.sh React/og_edge import); smoke tests warn and continue — invite-redirect covers the invite path. A `volume prune` / `"all" is an invalid volume filter` message is a Podman quirk; ignore if API `54321` responds.

### Podman: rootful (recommended)

```bash
# once
sudo systemctl enable --now podman.socket
# socket should be: srw-rw---- root podman  (mode 660 — not world-writable)

# every shell, or NixOS sessionVariables
export DOCKER_HOST=unix:///run/podman/podman.sock
```

NixOS:

```nix
users.users.zyzto.extraGroups = [ /* ... */ "podman" ];

environment.sessionVariables = {
  DOCKER_HOST = "unix:///run/podman/podman.sock";
};

environment.systemPackages = [ pkgs.supabase-cli /* ... */ ];
```

`local_test_env.sh` prefers `/run/podman/podman.sock` when readable.

### Security (local)

| Choice | Notes |
|--------|--------|
| Rootful socket `660` + `podman` group | Same trust model as Docker’s `docker` group: group members can run containers as root on this machine. Fine on a personal box; don’t share the login. |
| Avoid `SocketMode=0666` | World-writable socket is worse; not needed if you’re in `podman`. |
| Stack binds `0.0.0.0` | LAN peers can hit API/Studio. Restrict firewall when not device-testing; local JWT/keys are shared defaults — never use in prod. |

### Rootless Podman (optional / broken on this host)

Rootless needs real `/etc/subuid` + `/etc/subgid` files (not NixOS `/etc/static` symlinks — `newuidmap` uses `O_NOFOLLOW`). Even with maps fixed, Kong may still fail writing `kong.yml`; use rootful instead.

```nix
users.users.zyzto = {
  subUidRanges = [{ startUid = 100000; count = 65536; }];
  subGidRanges = [{ startGid = 100000; count = 65536; }];
};
environment.etc.subuid.mode = "0644";
environment.etc.subgid.mode = "0644";
```

## Quick start (Podman + LAN)

```bash
# once per machine
sudo systemctl enable --now podman.socket

# every shell (script also auto-detects rootful socket)
export DOCKER_HOST=unix:///run/podman/podman.sock

# Start stack, seed DB, write dart_defines_local.json with LAN IP
./scripts/local_test_env.sh up

# Check LAN host + FCM secret status
./scripts/local_test_env.sh status

# Automated checks (host)
./scripts/local_test_env.sh test-edge
./scripts/local_test_env.sh test

# Run on a physical device or emulator on the same LAN
flutter devices
flutter run --dart-define-from-file=dart_defines_local.json -d <deviceId>

# Or VS Code / Cursor: Hisab (Local Online, Android)

# Stop
./scripts/local_test_env.sh down
```

Overrides:

| Env | Meaning |
|-----|---------|
| `HISAB_LAN_IP=192.168.x.x` | Force IP written into defines / SITE_URL |
| `HISAB_BIND=loopback` | Use `127.0.0.1` only (host web; not for phones) |
| `HISAB_APP_PORT=8080` | Flutter web / SITE_URL port |
| `FCM_SERVICE_ACCOUNT_FILE=...` | Path to testing Firebase service account JSON |

Seeded users: `test-a@hisab.test` / `TestPass123!` and `test-b@hisab.test` / `TestPass123!`.

## Commands

| Command | What it does |
|---------|----------------|
| `up` | Podman/Docker check → patch auth redirects → write `supabase/.env` → `supabase start` → `db reset` → LAN `dart_defines_local.json` |
| `down` | Stop Supabase (+ Firebase Functions emulator if tracked) |
| `status` | LAN host, stack, defines, FCM file presence |
| `reset` | `db reset` + regenerate defines |
| `reload-secrets` | Reload FCM from `secrets/` into `supabase/.env` and restart Supabase |
| `serve-functions` | Optional Firebase **Functions** emulator (invite OG HTML), not FCM |
| `test` / `test-edge` | Automated suites (host) |

### Automated checks

```bash
export DOCKER_HOST=unix:///run/podman/podman.sock

# ChromeDriver matching Google Chrome (NixOS):
#   nix shell nixpkgs#chromedriver -c chromedriver --version
# Or put it on PATH for this shell:
#   export PATH="$(nix build --no-link --print-out-paths nixpkgs#chromedriver)/bin:$PATH"

./scripts/local_test_env.sh test-edge   # Edge HTTP smoke (needs stack up)
./scripts/local_test_env.sh test        # unit + web integration + online + edge
./scripts/run_online_tests.sh web       # multi-user Chrome integration (local Supabase)
```

`test-edge` expects seeded users and a healthy API. If FCM secrets are loaded, `send-notification` asserts the real path (not `dry_run`).

### Multi-user UI freshness (local)

- Home / expense lists: SQLite **streams** (web: fingerprint-gated 1.5s poll — see [WEB_IOS_SAFARI_PERFORMANCE.md](WEB_IOS_SAFARI_PERFORMANCE.md)).
- Group detail / settings / balance / role: also stream-backed so a pull-to-refresh or periodic sync updates open pages.
- Cloud sync: full fetch ~every **5 minutes** while online, debounced on connectivity flaps; pull-to-refresh / sync chip still call `syncNow()`.

## Ports

| Service | Port |
|---------|------|
| Supabase API / Functions | 54321 |
| Postgres | 54322 |
| Studio (host only) | 54323 |
| Inbucket (local email) | 54324 |
| Flutter web / SITE_URL | 8080 |

`dart_defines_local.json` uses your **LAN IP** so phones and emulators can reach the API. Android emulators also rewrite `localhost`/`127.0.0.1` → `10.0.2.2` in the app if you use loopback defines.

---

## Testing Firebase (FCM)

You need a **second Firebase project** for local push testing. Do **not** reuse production (`hisab-c8eb1`).

### Why

- Local Supabase has no real FCM delivery by itself.
- Google does not offer a full local FCM emulator for device push.
- A free Spark **test** project is enough for registration tokens + HTTP v1 sends.

### 1. Create the Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) → **Add project**.
2. Name it e.g. `hisab-test` (or `hisab-dev`).
3. Disable Google Analytics if you do not need it → Create.
4. Stay on the **Spark (free)** plan.

### 2. Register Android app (debug + optional release)

Debug builds use application id **`com.shenepoy.hisab.debug`** (see `android/app/build.gradle.kts` `applicationIdSuffix`).

1. Project Overview → **Add app** → Android.
2. Android package name: `com.shenepoy.hisab.debug` (for `flutter run` debug).
3. Download **`google-services.json`** → place at `android/app/google-services.json` (gitignored).
4. Optionally add a second Android app with package `com.shenepoy.hisab` for release/profile builds and download a combined or matching `google-services.json` that lists both clients (Firebase allows multiple apps; one JSON can contain both).

### 3. Register iOS (if you test on iPhone)

1. Add iOS app with your bundle id.
2. Download **`GoogleService-Info.plist`** → `ios/Runner/GoogleService-Info.plist` (gitignored).
3. Upload an APNs key in Firebase → Project settings → Cloud Messaging (required for real iOS push).

### 4. Register Web (optional)

1. Add Web app.
2. Copy config into `dart_defines_local.json` after `up` (script **preserves** these keys on regenerate):

| Key | From Firebase web config |
|-----|--------------------------|
| `FIREBASE_API_KEY` | `apiKey` |
| `FIREBASE_AUTH_DOMAIN` | `authDomain` |
| `FIREBASE_PROJECT_ID` | `projectId` |
| `FIREBASE_STORAGE_BUCKET` | `storageBucket` |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` |
| `FIREBASE_APP_ID` | `appId` |
| `FCM_VAPID_KEY` | Project settings → Cloud Messaging → Web Push certificates → Key pair |

### 5. Service account for local Edge → FCM

1. Firebase / Google Cloud Console → **IAM & Admin** → **Service accounts** (same GCP project as `hisab-test`).
2. Create or use the Firebase Admin SDK service account.
3. **Keys** → Add key → JSON → download.
4. Save as:

```text
secrets/fcm-service-account.test.json
```

5. Load into local Edge and restart:

```bash
./scripts/local_test_env.sh reload-secrets
./scripts/local_test_env.sh status   # should show FCM secrets loaded
```

When `FCM_PROJECT_ID` / `FCM_SERVICE_ACCOUNT_KEY` are present, `send-notification` sends real FCM (not dry-run).

### 6. Verify push on hardware

Local Docker/Podman **does not** run `pg_net` expense triggers, so create an expense will not auto-call the Edge Function. Use the helper after two devices have registered tokens:

1. Run the app on device A and B with `dart_defines_local.json` + test `google-services.json`.
2. Sign in as `test-a@hisab.test` / `test-b@hisab.test`, turn **Notifications** on, join the same group.
3. Confirm rows in Studio → `device_tokens`.
4. From the host:

```bash
./scripts/local_send_test_notification.sh <group_id> <actor_user_id>
# Actor A UUID: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
# Actor B UUID: bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb
```

Other members (not the actor) should receive a push via the **test** Firebase project.

---

## What is / isn’t covered

| Covered locally | Needs test Firebase |
|-----------------|---------------------|
| Auth (email/password seed users), sync, invites, storage, telemetry Edge | Real push banners on device |
| LAN physical devices + emulators | `google-services.json` / plist from **hisab-test** |
| Edge invite-redirect / og / telemetry | Service account for `send-notification` |
| send-notification dry-run without secrets | — |

Not covered: production Supabase/Firebase, Google/GitHub OAuth on local Auth, automatic DB→push triggers (`pg_net`).

## Related

- [CONFIGURATION.md](CONFIGURATION.md) — dart-define keys
- [EDGE_FUNCTIONS.md](EDGE_FUNCTIONS.md) — deploy Edge Functions to hosted Supabase
- [SUPABASE_SETUP.md](SUPABASE_SETUP.md) — Podman notes + production push pipeline
- [../test/README.md](../test/README.md) — unit / integration runners
