#!/usr/bin/env python3
"""Generate Android debug launcher icons with a clean bottom DEBUG bar."""

from __future__ import annotations

import glob
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "Hisab.png"
OUT_ROOT = ROOT / "android" / "app" / "src" / "debug" / "res"

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _font_path() -> str:
    for pattern in (
        "/nix/store/*-dejavu-fonts*/share/fonts/truetype/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
    ):
        hits = glob.glob(pattern)
        if hits:
            return hits[0]
    raise FileNotFoundError("DejaVuSans-Bold.ttf not found")


def compose_icon(src: Image.Image, size: int, font_path: str) -> Image.Image:
    """Place artwork above a slim DEBUG bar so the wallet isn't clipped."""
    bar_h = max(9, int(size * 0.145))
    art_h = size - bar_h

    # White canvas (matches launcher / adaptive backgrounds).
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))

    # Fit source into the art area (contain), centered.
    src_sq = src.copy()
    src_sq.thumbnail((size, art_h), Image.Resampling.LANCZOS)
    ax = (size - src_sq.width) // 2
    ay = (art_h - src_sq.height) // 2
    canvas.alpha_composite(src_sq, (ax, ay))

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # Slim dark bar + brand-green hairline.
    d.rectangle([0, size - bar_h, size, size], fill=(32, 40, 36, 242))
    accent = max(1, size // 72)
    d.rectangle(
        [0, size - bar_h, size, size - bar_h + accent],
        fill=(122, 176, 102, 255),
    )

    label = "DEBUG"
    target = max(6, int(bar_h * 0.50))
    font = ImageFont.truetype(font_path, size=target)
    spacing = max(1, size // 56)
    chars = list(label)
    widths = []
    for c in chars:
        bb = d.textbbox((0, 0), c, font=font)
        widths.append(bb[2] - bb[0])
    sample = d.textbbox((0, 0), "D", font=font)
    th = sample[3] - sample[1]
    total = sum(widths) + spacing * (len(chars) - 1)
    x = (size - total) // 2
    y = size - bar_h + (bar_h - th) // 2 - sample[1]
    for c, cw in zip(chars, widths):
        d.text((x, y), c, font=font, fill=(250, 252, 248, 255))
        x += cw + spacing

    return Image.alpha_composite(canvas, overlay)


def main() -> None:
    font_path = _font_path()
    src = Image.open(SRC).convert("RGBA")

    preview_dir = ROOT / "tmp"
    preview_dir.mkdir(parents=True, exist_ok=True)
    preview_path = preview_dir / "preview_debug_icon.png"
    compose_icon(src, 512, font_path).save(preview_path)
    print("preview", preview_path)

    for folder, size in SIZES.items():
        out_dir = OUT_ROOT / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        path = out_dir / "ic_launcher.png"
        compose_icon(src, size, font_path).save(path)
        print("wrote", path, size)


if __name__ == "__main__":
    main()
