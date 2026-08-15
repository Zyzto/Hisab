# Security and secrets

This repository is **public**, and it has no production credentials in it by
design. There is no backend here, so there is nothing here to hold a
service-role key, a database password, or an admin token. Treat every commit as
visible to the world, because it is.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Email the maintainer
at the address on the [GitHub profile](https://github.com/Zyzto), or use
GitHub's private vulnerability reporting on this repository. Include the
version or commit, the platform, and the smallest reproduction you have.

If the issue is in the hosted service rather than the client, say so — it is a
separate system and gets fixed separately.

## Safe to commit

- Source, docs and scripts that *name* secrets — never their values
- `*_example.json` / `*.env.example` templates with placeholders
- Anything already public in a shipped build

## Never commit

- Firebase service-account JSON or any private key material
- Filled define files with real keys or project URLs
- OAuth client secrets, SMTP or API tokens, real `.env*` values
- Signing keystores or their passwords
- Production dumps or real user exports

**Gitignored paths — do not `git add -f`:**

| Path | Why |
|------|-----|
| `dart_defines*.json` | Backend URLs and keys |
| `secrets/**` (except `README.md` / `.gitkeep`) | Service-account JSON, etc. |
| `android/app/src/cloud/google-services.json` | Firebase Android config for the cloud build |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS |
| `**/fcm-service-account*.json` | Firebase Admin private key |
| `*.jks` / `*.keystore` / `key.properties` | Android signing material |

## A note on client-side "secrets"

Everything passed to a Flutter build with `--dart-define` ends up inside the
compiled binary or JavaScript bundle. It is not secret; it is merely
inconvenient to read. A public API key that is safe to expose — because the
server enforces authorization regardless — is fine. A key that grants
privileges on its own is not, and no amount of build-time injection changes
that. If your backend has an admin credential, it belongs on your server.

## Where secrets live

| Context | Store in |
|---------|----------|
| Local dev | Env vars or untracked files (table above) |
| Public CI | GitHub Actions secrets on this repository — only the FOSS signing keystore |
| Backend / cloud build | The private backend repository's own Actions environments |

The public release pipeline signs the FOSS APK and does nothing else. It has no
access to production Firebase, to the backend, or to the Play upload key.

## Release checks

Before opening a PR, or before a release:

```bash
bash ./scripts/run_release_checks.sh
```

Runs:

| Script | What it gates |
|--------|----------------|
| [`scripts/verify_security.sh`](scripts/verify_security.sh) | No tracked secret paths; no PEM/JWT/API-key/token literals; Firebase web placeholders left as placeholders |
| [`scripts/verify_infra.sh`](scripts/verify_infra.sh) | Firebase Hosting config, web shell assets, version and toolchain pins, Android variants, legal pages |

CI runs the same checks on every push and on tag releases. Agent workflow:
[`.cursor/skills/hisab-release-checks/SKILL.md`](.cursor/skills/hisab-release-checks/SKILL.md).

## Before push (secret scan)

Pushes are blocked if the commit tree contains sensitive material.

1. **Install git hooks once per clone** (sets `core.hooksPath=.githooks`):

```bash
bash ./scripts/install_git_hooks.sh
```

2. **`.githooks/pre-push`** runs `HISAB_SCAN_TREE=<sha> ./scripts/verify_security.sh` for every ref being pushed.

3. **Cursor agent pushes** are also gated by [`.cursor/hooks.json`](.cursor/hooks.json) (`beforeShellExecution` → `block-push-if-secrets.sh`).

Bypass only when you intentionally must, and never for real secrets:

```bash
git push --no-verify
```

## If something leaks

Rotate the credential immediately, then remove it from git history. Rotation
first — history rewriting is slow and a leaked key is exploitable the whole
time you are doing it.
