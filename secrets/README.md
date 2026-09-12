# Local secrets (gitignored)

This folder is **gitignored** except this README and `.gitkeep`. Never
`git add -f` anything here — the repository is public.

Nothing in this repository requires a secret to build or run. A default
`flutter run` is local-only. This folder exists only for local signing or
other deliberately untracked development material.

## Signing material

Keystores (`*.jks`, `*.keystore`) and `android/key.properties` are gitignored
wherever they sit. Keep them out of the tree entirely if you can; CI reads them
from a base64 secret via `scripts/ci/decode_keystore.sh`.

Do not place service credentials, user data, or production configuration here.
See [SECURITY.md](../SECURITY.md).
