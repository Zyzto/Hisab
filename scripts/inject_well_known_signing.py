#!/usr/bin/env python3
"""Fill App/Universal Link well-known files for Firebase Hosting deploy.

Uses:
  - Upload-keystore SHA-256 (from KEYSTORE_* env / decoded .jks)
  - Optional PLAY_APP_SIGNING_SHA256 secret (Play Console app-signing cert)
  - Optional APPLE_TEAM_ID secret

When PLAY_STORE_SERVICE_ACCOUNT_JSON is set, also tries to download a
Play-generated APK and read its signer SHA-256 (app signing key).
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def _colon_sha256(hex_digest: str) -> str:
    h = re.sub(r"[^0-9a-fA-F]", "", hex_digest)
    if len(h) != 64:
        raise ValueError(f"expected 64 hex chars, got {len(h)}: {hex_digest!r}")
    return ":".join(h[i : i + 2].upper() for i in range(0, 64, 2))


def sha_from_keystore(jks: Path, store_pass: str, alias: str, key_pass: str) -> str:
    out = subprocess.check_output(
        [
            "keytool",
            "-list",
            "-v",
            "-keystore",
            str(jks),
            "-storepass",
            store_pass,
            "-alias",
            alias,
            "-keypass",
            key_pass,
        ],
        text=True,
        stderr=subprocess.STDOUT,
    )
    m = re.search(r"SHA256:\s*([0-9A-Fa-f:]+)", out)
    if not m:
        raise RuntimeError("keytool output missing SHA256")
    return _colon_sha256(m.group(1))


def sha_from_apk(apk: Path) -> str:
    apksigner = os.environ.get("APKSIGNER")
    if not apksigner:
        for ver in ("37.0.0", "36.1.0", "36.0.0", "35.0.0"):
            candidate = Path.home() / "Android" / "Sdk" / "build-tools" / ver / "apksigner"
            if candidate.exists():
                apksigner = str(candidate)
                break
    if not apksigner or not Path(apksigner).exists():
        # Ubuntu runners: install via cmdline-tools or use keytool on v1 only.
        raise RuntimeError("apksigner not found; set APKSIGNER")
    out = subprocess.check_output(
        [apksigner, "verify", "--print-certs", str(apk)],
        text=True,
        stderr=subprocess.STDOUT,
    )
    m = re.search(r"Signer #1 certificate SHA-256 digest:\s*([0-9a-fA-F]+)", out)
    if not m:
        raise RuntimeError("apksigner output missing SHA-256 digest")
    return _colon_sha256(m.group(1))


def play_app_signing_sha(package: str, sa_json: str) -> str | None:
    """Best-effort: download a Play-generated APK and read its signer cert."""
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.http import MediaIoBaseDownload
        import io
    except ImportError:
        print("google-api-python-client not installed; skip Play signing lookup", file=sys.stderr)
        return None

    info = json.loads(sa_json)
    creds = service_account.Credentials.from_service_account_info(
        info,
        scopes=["https://www.googleapis.com/auth/androidpublisher"],
    )
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

    edit = service.edits().insert(packageName=package, body={}).execute()
    edit_id = edit["id"]
    try:
        track = (
            service.edits()
            .tracks()
            .get(packageName=package, editId=edit_id, track="internal")
            .execute()
        )
        version_codes: list[int] = []
        for release in track.get("releases", []):
            for vc in release.get("versionCodes", []):
                version_codes.append(int(vc))
        if not version_codes:
            print("No internal-track versionCodes; skip Play signing lookup", file=sys.stderr)
            return None
        version_codes.sort(reverse=True)
        version_code = version_codes[0]
        generated = (
            service.generatedapks()
            .list(packageName=package, versionCode=version_code)
            .execute()
        )
        apks = generated.get("generatedApks", [])
        if not apks:
            print("No generatedApks for latest internal version", file=sys.stderr)
            return None
        # Prefer universal / first downloadable id.
        download_id = None
        for entry in apks:
            if "generatedUniversalApk" in entry:
                download_id = entry["generatedUniversalApk"].get("downloadId")
                break
            split = entry.get("generatedSplitApks") or []
            if split:
                download_id = split[0].get("downloadId")
                break
        if not download_id:
            print("No downloadId on generated APKs", file=sys.stderr)
            return None
        req = service.generatedapks().download(
            packageName=package,
            versionCode=version_code,
            downloadId=download_id,
        )
        buf = io.BytesIO()
        downloader = MediaIoBaseDownload(buf, req)
        done = False
        while not done:
            _, done = downloader.next_chunk()
        with tempfile.NamedTemporaryFile(suffix=".apk", delete=False) as tmp:
            tmp.write(buf.getvalue())
            apk_path = Path(tmp.name)
        try:
            return sha_from_apk(apk_path)
        finally:
            apk_path.unlink(missing_ok=True)
    finally:
        try:
            service.edits().delete(packageName=package, editId=edit_id).execute()
        except Exception:
            pass


def main() -> int:
    root = Path(os.environ.get("GITHUB_WORKSPACE", Path.cwd()))
    assetlinks_path = root / "build" / "web" / ".well-known" / "assetlinks.json"
    aasa_path = root / "build" / "web" / ".well-known" / "apple-app-site-association"
    if not assetlinks_path.is_file():
        print(f"missing {assetlinks_path}", file=sys.stderr)
        return 1

    fingerprints: list[str] = []

    # 1) Upload keystore (release APKs / sideload)
    jks_b64 = os.environ.get("KEYSTORE_BASE64", "").strip()
    store_pass = os.environ.get("KEYSTORE_PASSWORD", "")
    alias = os.environ.get("KEY_ALIAS", "")
    key_pass = os.environ.get("KEY_PASSWORD", "") or store_pass
    if jks_b64 and store_pass and alias:
        import base64

        with tempfile.NamedTemporaryFile(suffix=".jks", delete=False) as tmp:
            tmp.write(base64.b64decode(jks_b64))
            jks_path = Path(tmp.name)
        try:
            fingerprints.append(sha_from_keystore(jks_path, store_pass, alias, key_pass))
            print(f"upload keystore SHA-256: {fingerprints[-1]}")
        finally:
            jks_path.unlink(missing_ok=True)

    # 2) Explicit Play App Signing secret (preferred when set)
    play_secret = os.environ.get("PLAY_APP_SIGNING_SHA256", "").strip()
    if play_secret:
        fingerprints.append(_colon_sha256(play_secret))
        print(f"PLAY_APP_SIGNING_SHA256: {fingerprints[-1]}")

    # 3) Best-effort Play-generated APK signer
    sa = os.environ.get("PLAY_STORE_SERVICE_ACCOUNT_JSON", "").strip()
    if sa and not play_secret:
        try:
            play_sha = play_app_signing_sha("com.shenepoy.hisab", sa)
            if play_sha:
                fingerprints.append(play_sha)
                print(f"Play-generated APK SHA-256: {play_sha}")
        except Exception as e:
            print(f"Play signing lookup failed: {e}", file=sys.stderr)

    # Dedupe preserve order
    seen: set[str] = set()
    unique: list[str] = []
    for fp in fingerprints:
        if fp not in seen:
            seen.add(fp)
            unique.append(fp)

    if not unique:
        print("No release fingerprints resolved; leaving assetlinks as copied", file=sys.stderr)
    else:
        data = json.loads(assetlinks_path.read_text())
        for entry in data:
            target = entry.get("target") or {}
            if target.get("package_name") == "com.shenepoy.hisab":
                target["sha256_cert_fingerprints"] = unique
        assetlinks_path.write_text(json.dumps(data, indent=2) + "\n")
        print(f"Wrote {assetlinks_path} with {len(unique)} fingerprint(s)")

    team = os.environ.get("APPLE_TEAM_ID", "").strip()
    if team and aasa_path.is_file():
        text = aasa_path.read_text()
        text = text.replace("REPLACE_WITH_APPLE_TEAM_ID", team)
        aasa_path.write_text(text)
        print(f"Injected APPLE_TEAM_ID into {aasa_path}")
    elif aasa_path.is_file() and "REPLACE_WITH_APPLE_TEAM_ID" in aasa_path.read_text():
        print(
            "APPLE_TEAM_ID secret not set; apple-app-site-association still has placeholder",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
