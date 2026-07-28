# Local secrets (gitignored)

This folder is **gitignored** except this README and `.gitkeep`. Never `git add -f` anything here — the repo is public.

## Android app config (not this folder)

```text
android/app/google-services.json
```

Firebase Android app config (`project_info` / `client`) — **not** a service account. Also gitignored.

## Edge → FCM service account (this folder)

Download a **service account key** (JSON with `type: service_account`, `private_key`, `client_email`, `project_id`) and save as:

```text
secrets/fcm-service-account.test.json
```

Firebase Console → Project settings → Service accounts → Generate new private key  
(or Google Cloud IAM → Service accounts → Keys).

Then:

```bash
./scripts/local_test_env.sh reload-secrets
```

That writes `supabase/.env` (also gitignored). Prefer keeping the private key **only** in this JSON file.

See [docs/LOCAL_TEST_ENV.md](../docs/LOCAL_TEST_ENV.md#testing-firebase-fcm) and [SECURITY.md](../SECURITY.md).
