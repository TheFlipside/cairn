#!/usr/bin/env python3
"""Generate Cairn's app icon assets.

Renders two PNGs consumed by `flutter_launcher_icons` (see
`flutter_launcher_icons.yaml`):

* ``assets/icon/icon.png``            -- 1024x1024 full-bleed master
  (teal radial-gradient background + stacked stones), used for iOS and the
  Android legacy/round icons.
* ``assets/icon/icon_foreground.png`` -- 1024x1024 transparent foreground
  (the stones only, sized within the Android adaptive-icon safe zone).
* ``assets/icon/icon_background.png``  -- 1024x1024 adaptive background
  (the bare teal gradient, so Android adaptive icons match the master).

The design is a "cairn": warm-grey stones balanced into a tapering stack, the
project's calm, personal metaphor. Pure Pillow (no SVG rasteriser needed);
stones are supersampled and downscaled for anti-aliasing.

Run from the project root:  ``python3 tool/generate_icon.py``
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# Output geometry.
SIZE = 1024  # final icon edge, in px
SS = 2  # supersampling factor for anti-aliasing
BIG = SIZE * SS

# Palette.
BG_INNER = (40, 176, 160)  # bright teal (gradient centre)
BG_EDGE = (0, 82, 71)  # deep teal (gradient corners)
SHADOW = (0, 40, 35)  # soft ground shadow tint

Color = tuple[int, int, int]
Box = tuple[float, float, float]  # left, top, side (px)

# Stones, bottom-to-top, in design-box coordinates (0..1, y down). Each is a
# flattened ellipse; the gentle horizontal zig-zag reads as a hand-balanced
# stack. Neighbours alternate light/dark warm greys so they stay distinct.
Stone = tuple[float, float, float, float, Color]  # cx, cy, w, h, colour
STONES: list[Stone] = [
    (0.510, 0.795, 0.660, 0.215, (158, 151, 142)),  # bottom (largest)
    (0.460, 0.625, 0.540, 0.195, (206, 200, 191)),
    (0.525, 0.460, 0.420, 0.175, (140, 134, 124)),
    (0.475, 0.305, 0.300, 0.155, (216, 210, 201)),
    (0.500, 0.175, 0.160, 0.115, (170, 163, 153)),  # peak pebble
]


def _lerp(start: Color, end: Color, frac: float) -> Color:
    """Linearly interpolate two RGB colours at ``frac`` (0..1)."""
    return (
        round(start[0] + (end[0] - start[0]) * frac),
        round(start[1] + (end[1] - start[1]) * frac),
        round(start[2] + (end[2] - start[2]) * frac),
    )


def _radial_background() -> Image.Image:
    """Build the teal radial gradient at BIG resolution (centre -> corners)."""
    work = 512
    grad = Image.new("RGB", (work, work), BG_EDGE)
    draw = ImageDraw.Draw(grad)
    centre = work / 2
    max_r = centre * 2**0.5  # reach the corners
    steps = work
    for i in range(steps + 1):
        frac = i / steps
        radius = max_r * (1 - frac)
        lo, hi = centre - radius, centre + radius
        draw.ellipse([lo, lo, hi, hi], fill=_lerp(BG_EDGE, BG_INNER, frac))
    return grad.resize((BIG, BIG), Image.Resampling.LANCZOS)


def _box(side_frac: float) -> Box:
    """Centred square design box: returns (left, top, side) in px."""
    side = side_frac * BIG
    offset = (BIG - side) / 2
    return offset, offset, side


def _ellipse_bbox(stone: Stone, box: Box) -> list[float]:
    left, top, side = box
    cx, cy, w, h, _ = stone
    return [
        left + (cx - w / 2) * side,
        top + (cy - h / 2) * side,
        left + (cx + w / 2) * side,
        top + (cy + h / 2) * side,
    ]


def _draw_stones(box: Box) -> Image.Image:
    """Draw the stones (with soft top highlights) on a transparent layer."""
    stones = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    highlights = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(stones)
    h_draw = ImageDraw.Draw(highlights)
    for stone in STONES:
        cx, cy, w, h, colour = stone
        s_draw.ellipse(_ellipse_bbox(stone, box), fill=colour + (255,))
        # A lighter sheen across the top of each stone (top-lit look).
        sheen = tuple(min(255, c + 34) for c in colour)
        top = (cx, cy - 0.22 * h, 0.70 * w, 0.42 * h, sheen)
        h_draw.ellipse(_ellipse_bbox(top, box), fill=sheen + (110,))
    highlights = highlights.filter(ImageFilter.GaussianBlur(BIG * 0.004))
    stones.alpha_composite(highlights)
    return stones


def _ground_shadow(box: Box) -> Image.Image:
    """Soft elliptical shadow beneath the bottom stone, to ground it."""
    layer = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    shadow = (0.505, 0.930, 0.620, 0.090, SHADOW)
    draw = ImageDraw.Draw(layer)
    draw.ellipse(_ellipse_bbox(shadow, box), fill=SHADOW + (120,))
    return layer.filter(ImageFilter.GaussianBlur(BIG * 0.018))


def build_master() -> Image.Image:
    """The full-bleed icon: gradient + grounded, highlighted stone stack."""
    box = _box(0.80)
    base = _radial_background().convert("RGBA")
    base.alpha_composite(_ground_shadow(box))
    base.alpha_composite(_draw_stones(box))
    return base.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def build_foreground() -> Image.Image:
    """The adaptive foreground: the stones on transparency.

    No shadow is drawn (it would float on a clear background). The stack
    nearly fills the frame; flutter_launcher_icons adds a 16% inset, which
    lands the stones inside the adaptive-icon safe zone (so launcher masks
    never clip them).
    """
    box = _box(1.0)
    layer = _draw_stones(box)
    return layer.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def build_background() -> Image.Image:
    """The adaptive background: the bare teal gradient (no stones).

    Used as the Android adaptive background layer so the gradient matches the
    iOS / legacy master instead of a flat fill.
    """
    return _radial_background().resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def main() -> None:
    """Render the icon PNGs into ``assets/icon/``."""
    out = Path(__file__).resolve().parent.parent / "assets" / "icon"
    out.mkdir(parents=True, exist_ok=True)
    build_master().save(out / "icon.png")
    build_foreground().save(out / "icon_foreground.png")
    build_background().save(out / "icon_background.png")
    print(f"Wrote icon.png, icon_foreground.png, icon_background.png to {out}")


if __name__ == "__main__":
    main()
