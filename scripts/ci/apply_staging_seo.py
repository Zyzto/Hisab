#!/usr/bin/env python3
"""Mark a staged web build as non-indexable when HISAB_ENV=staging.

Production keeps the committed robots.txt / sitemap and is unchanged.
Staging must never appear in search results, even if a crawler finds
test.hisab.shenepoy.com through a link.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROBOTS = """User-agent: *
Disallow: /
"""

META = '<meta name="robots" content="noindex, nofollow">'
HTML_ATTR = 'data-hisab-env="staging"'
RIBBON_STYLE = """<style id="hisab-staging-ribbon">
html[data-hisab-env="staging"] body::before {
  content: "TEST";
  position: fixed;
  top: 22px;
  right: -34px;
  z-index: 2147483647;
  transform: rotate(45deg);
  background: #b71c1c;
  color: #fff;
  font: 700 10px/1 sans-serif;
  letter-spacing: 0.08em;
  padding: 6px 40px;
  pointer-events: none;
}
</style>
"""


def _insert_after_open_tag(text: str, tag: str, snippet: str) -> str:
    start = text.lower().find(f"<{tag}")
    if start < 0:
        return text
    end = text.find(">", start)
    if end < 0:
        return text
    return text[: end + 1] + snippet + text[end + 1 :]


def _inject_html(text: str) -> str:
    if 'name="robots"' not in text:
        text = _insert_after_open_tag(text, "head", f"\n  {META}")
    if HTML_ATTR not in text:
        lower = text.lower()
        start = lower.find("<html")
        if start >= 0:
            end = text.find(">", start)
            if end > start:
                text = text[:end] + f" {HTML_ATTR}" + text[end:]
    if 'id="hisab-staging-ribbon"' not in text and "</head>" in text:
        text = text.replace("</head>", f"{RIBBON_STYLE}</head>", 1)
    return text


def _patch_firebase(path: Path) -> None:
    cfg = json.loads(path.read_text())
    hosting = cfg.get("hosting")
    if not isinstance(hosting, dict):
        return
    for rule in hosting.get("headers") or []:
        headers = rule.get("headers")
        if not isinstance(headers, list):
            continue
        keys = {
            h.get("key") for h in headers if isinstance(h, dict)
        }
        if "X-Robots-Tag" in keys:
            continue
        headers.append(
            {"key": "X-Robots-Tag", "value": "noindex, nofollow"},
        )
    path.write_text(json.dumps(cfg, indent=4) + "\n")


def apply(root: Path) -> None:
    web = root / "build" / "web"
    if not web.is_dir():
        print("apply_staging_seo: build/web missing; skip", file=sys.stderr)
        return

    (web / "robots.txt").write_text(ROBOTS)
    sitemap = web / "sitemap.xml"
    if sitemap.exists():
        sitemap.unlink()

    for html in web.rglob("*.html"):
        updated = _inject_html(html.read_text(encoding="utf-8"))
        # The Flutter shell already has the in-app TEST banner.
        if html.name == "index.html" and "hisab-boot-splash" in updated:
            updated = updated.replace(RIBBON_STYLE, "")
        html.write_text(updated)

    # Never mutate the committed firebase.json. The patched copy lives next
    # to the web bundle so a local staging build cannot noindex production
    # if someone commits the working tree.
    src = root / "firebase.json"
    dest = root / "build" / "firebase.json"
    if src.is_file():
        dest.write_text(src.read_text(encoding="utf-8"), encoding="utf-8")
        _patch_firebase(dest)

    print("apply_staging_seo: robots Disallow:/, no sitemap, noindex headers")


def _selftest() -> None:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        web = root / "build" / "web"
        web.mkdir(parents=True)
        (web / "robots.txt").write_text("User-agent: *\nAllow: /\n")
        (web / "sitemap.xml").write_text("<urlset></urlset>\n")
        (web / "index.html").write_text(
            "<html lang='en'><head></head><body>"
            "<div id='hisab-boot-splash'></div></body></html>\n"
        )
        (web / "privacy").mkdir()
        (web / "privacy" / "index.html").write_text(
            "<html><head></head><body><h1>Privacy</h1></body></html>\n"
        )
        original = {
            "hosting": {
                "headers": [
                    {
                        "source": "**",
                        "headers": [
                            {"key": "Cache-Control", "value": "no-cache"}
                        ],
                    }
                ]
            }
        }
        (root / "firebase.json").write_text(json.dumps(original))
        apply(root)
        robots = (web / "robots.txt").read_text()
        assert "Disallow: /" in robots, robots
        assert not (web / "sitemap.xml").exists()
        shell = (web / "index.html").read_text()
        assert "noindex" in shell
        assert "hisab-staging-ribbon" not in shell
        privacy = (web / "privacy" / "index.html").read_text()
        assert "noindex" in privacy
        assert "hisab-staging-ribbon" in privacy
        committed = json.loads((root / "firebase.json").read_text())
        committed_keys = [
            h["key"] for h in committed["hosting"]["headers"][0]["headers"]
        ]
        assert "X-Robots-Tag" not in committed_keys
        cfg = json.loads((root / "build" / "firebase.json").read_text())
        keys = [h["key"] for h in cfg["hosting"]["headers"][0]["headers"]]
        assert "X-Robots-Tag" in keys
    print("apply_staging_seo: selftest ok")


def main() -> int:
    if "--selftest" in sys.argv:
        _selftest()
        return 0
    env = os.environ.get("HISAB_ENV", "").strip().lower()
    if env != "staging":
        return 0
    root = Path(os.environ.get("HISAB_APP_DIR") or Path.cwd()).resolve()
    apply(root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
