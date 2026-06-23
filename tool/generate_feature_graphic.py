#!/usr/bin/env python3
"""Generate Cairn's store feature graphic.

Renders ``fastlane/metadata/android/<locale>/images/featureGraphic.png`` --
the 1024x500 banner shown at the top of the F-Droid (and Google Play)
listing. It composites the rendered stone stack from
``assets/icon/icon_foreground.png`` onto a matching teal gradient and sets
the "Cairn" wordmark beside it, so the banner stays visually identical to
the launcher / adaptive icon.

The palette mirrors ``tool/generate_icon.py`` (kept inline so this script
has no cross-module import and lints cleanly on its own).

Run from the project root:

    python3 tool/generate_feature_graphic.py
"""

from __future__ import annotations

from math import hypot
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Output geometry: the size F-Droid and Google Play expect for a feature
# graphic.
WIDTH = 1024
HEIGHT = 500

# Brand palette (mirrors generate_icon.py).
Color = tuple[int, int, int]
BG_INNER: Color = (40, 176, 160)  # bright teal (gradient centre)
BG_EDGE: Color = (0, 82, 71)  # deep teal (gradient corners)
INK: Color = (245, 247, 246)  # near-white wordmark

WORDMARK = "Cairn"

# Project root and the transparent stone stack rendered by generate_icon.py.
_ROOT = Path(__file__).resolve().parent.parent
FOREGROUND = _ROOT / "assets" / "icon" / "icon_foreground.png"

# Candidate bold fonts; the first that exists is used, and the banner
# degrades to art-only (no wordmark) if none are present.
FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
)


def _blend(start: Color, end: Color, frac: float) -> Color:
    """Interpolate two RGB colours at ``frac`` (clamped to 0..1)."""
    frac = max(0.0, min(1.0, frac))
    return (
        round(start[0] + (end[0] - start[0]) * frac),
        round(start[1] + (end[1] - start[1]) * frac),
        round(start[2] + (end[2] - start[2]) * frac),
    )


def _load_font(size: int) -> ImageFont.FreeTypeFont | None:
    """First available bold TrueType font at ``size`` px, or ``None``."""
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return None


def _gradient(center: tuple[float, float]) -> Image.Image:
    """Teal radial gradient: bright at ``center``, deep at the corners."""
    work_w, work_h = 256, 125
    grad = Image.new("RGB", (work_w, work_h))
    pixels = grad.load()
    cx, cy = center[0] * work_w, center[1] * work_h
    corners = ((0, 0), (work_w, 0), (0, work_h), (work_w, work_h))
    max_dist = max(hypot(cx - px, cy - py) for px, py in corners)
    for y in range(work_h):
        for x in range(work_w):
            dist = hypot(cx - x, cy - y)
            pixels[x, y] = _blend(BG_INNER, BG_EDGE, dist / max_dist)
    return grad.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)


def _draw_wordmark(banner: Image.Image, art_right: int) -> None:
    """Centre the "Cairn" wordmark in the field right of the art."""
    font = _load_font(150)
    if font is None:
        return
    draw = ImageDraw.Draw(banner)
    left, top, right, bottom = font.getbbox(WORDMARK)
    region_left = art_right + 48
    x = region_left + ((WIDTH - region_left) - (right - left)) // 2 - left
    y = (HEIGHT - (bottom - top)) // 2 - top
    draw.text((x, y), WORDMARK, font=font, fill=INK)


def build_feature_graphic() -> Image.Image:
    """Compose the banner: gradient + stone stack + wordmark."""
    banner = _gradient((0.27, 0.5)).convert("RGBA")
    stones = Image.open(FOREGROUND).convert("RGBA")
    art = int(HEIGHT * 0.84)
    stones = stones.resize((art, art), Image.Resampling.LANCZOS)
    stone_x = 64
    banner.alpha_composite(stones, (stone_x, (HEIGHT - art) // 2))
    _draw_wordmark(banner, stone_x + art)
    return banner.convert("RGB")


def main() -> None:
    """Render featureGraphic.png into each locale's images/ dir."""
    banner = build_feature_graphic()
    base = _ROOT / "fastlane" / "metadata" / "android"
    for locale in ("en-US", "de-DE"):
        out = base / locale / "images"
        out.mkdir(parents=True, exist_ok=True)
        banner.save(out / "featureGraphic.png")
    print("Wrote featureGraphic.png for en-US and de-DE")


if __name__ == "__main__":
    main()
