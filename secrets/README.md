# Local secrets (gitignored)

This folder is **gitignored** except this README and `.gitkeep`. Never
`git add -f` anything here — the repository is public.

Nothing in this repository requires a secret to build or run. A default
`flutter run` is local-only and has no backend to authenticate against. This
folder exists for the cases where you attach one.

## Android Firebase config

```text
android/app/src/cloud/google-services.json
```

Lives in the `cloud` source set, so it only affects `--flavor cloud` builds and
the `foss` build never looks for it. It is the Firebase app config
(`project_info` / `client`), not a service account, but it is still gitignored.

## Signing material

Keystores (`*.jks`, `*.keystore`) and `android/key.properties` are gitignored
wherever they sit. Keep them out of the tree entirely if you can; CI reads them
from a base64 secret via `scripts/ci/decode_keystore.sh`.

## Backend credentials

Anything your backend needs — service-account JSON, server keys, database
passwords — belongs to that backend's own repository and deployment, not here.
See [SECURITY.md](../SECURITY.md) and [docs/SELF_HOSTING.md](../docs/SELF_HOSTING.md).
