#!/usr/bin/env python3
"""Draws the DMG window background: scripts/dmg/background.tiff.

A pixel night sky over a wooden shelf. The icons sit on the shelf, whose
mid-tone keeps Finder's labels readable in both light mode (black text) and
dark mode (white text).

Layout constants must match scripts/dmg/settings.py. Needs Pillow; run via
scripts/make-dmg.sh's venv:  .venv/bin/python scripts/make-dmg-background.py
"""
import pathlib
import random
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "scripts" / "dmg" / "background.tiff"
SLEEP_SPRITE = ROOT / "Resources" / "Sprites" / "sleep.png"

W, H = 640, 520          # art size in points; taller than the window so the
                         # shelf keeps going if Finder shows extra bars
CONTENT_BOTTOM = 400     # everything that matters sits above this line
SHELF_TOP = 236          # icons sit on this line
ICON_Y = 190             # centre of the top row of icons
UNIT = 4                 # one "pixel" of the pixel art, in points

NIGHT = (28, 33, 64)
NIGHT_BANDS = [(33, 40, 76), (39, 47, 88), (46, 55, 100)]
STAR = (246, 239, 226)
TWINKLE = (255, 216, 107)
MOON = (255, 231, 163)
SHELF = (125, 111, 98)
SHELF_LIP = (160, 140, 118)
SHELF_SHADOW = (98, 86, 76)
SEAM = (110, 97, 86)
ARROW = (240, 145, 74)
ARROW_SHADOW = (166, 92, 44)
TITLE = (246, 239, 226)
SUBTITLE = (184, 190, 218)
INK = (59, 42, 32)
CUP = (251, 247, 240)
CREMA = (226, 190, 140)

FONT = "/System/Library/Fonts/SFCompactRounded.ttf"

MUG = [
    "..#########....",
    "..#ccccccc#....",
    "..#mmmmmmm####.",
    "..#mmmmmmm#..#.",
    "..#mmmmmmm#..#.",
    "..#mmmmmmm####.",
    "...#mmmmm#.....",
    "#############..",
    ".###########...",
]

MOON_SHAPE = [
    "...####..",
    ".######..",
    "####.....",
    "###......",
    "###......",
    "####.....",
    ".######..",
    "...####..",
]


def font(size: float, weight: str, s: int) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(FONT, int(size * s))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        print(f"warning: {FONT} has no '{weight}' weight; using its default")
    return f


def draw(s: int) -> Image.Image:
    """Renders the background at scale s (1 or 2)."""
    img = Image.new("RGB", (W * s, H * s), NIGHT)
    d = ImageDraw.Draw(img)
    u = UNIT * s

    def block(ux: float, uy: float, w: float = 1, h: float = 1, color=STAR):
        d.rectangle([ux * u, uy * u, (ux + w) * u - 1, (uy + h) * u - 1], fill=color)

    # Sky gets a little lighter towards the horizon, in hard pixel steps.
    horizon = SHELF_TOP // UNIT
    for i, color in enumerate(NIGHT_BANDS):
        top = horizon - (len(NIGHT_BANDS) - i) * 4
        block(0, top, W // UNIT, horizon - top, color)

    # Stars, kept clear of the title and the icon row.
    rng = random.Random(7)
    placed = 0
    while placed < 46:
        ux, uy = rng.randrange(1, W // UNIT - 1), rng.randrange(1, horizon - 2)
        x, y = ux * UNIT, uy * UNIT
        if 150 < x < 490 and y < 104:
            continue
        if abs(y - ICON_Y) < 60 and (abs(x - 180) < 64 or abs(x - 460) < 64 or abs(x - 320) < 56):
            continue
        if x > 520 and y < 110:   # the moon's patch
            continue
        if rng.random() < 0.12:
            block(ux, uy - 1, 1, 3, TWINKLE)
            block(ux - 1, uy, 3, 1, TWINKLE)
        else:
            block(ux, uy, 1, 1, STAR if rng.random() < 0.7 else SUBTITLE)
        placed += 1

    # Moon.
    mx, my = 140, 6
    for r, row in enumerate(MOON_SHAPE):
        for c, ch in enumerate(row):
            if ch == "#":
                block(mx + c, my + r, 1, 1, MOON)

    # Title.
    title_font = font(34, "Bold", s)
    sub_font = font(15, "Medium", s)
    d.text((W * s / 2, 30 * s), "Cappy", font=title_font, fill=TITLE, anchor="mt")
    d.text((W * s / 2, 76 * s), "Drag the cat into Applications", font=sub_font, fill=SUBTITLE, anchor="mt")

    # Pixel arrow between the two icons.
    cy = ICON_Y // UNIT
    x0, x1 = 286 // UNIT, 356 // UNIT
    head = 5
    for color, dy in ((ARROW_SHADOW, 1), (ARROW, 0)):
        block(x0, cy - 1 + dy, x1 - x0 - head, 2, color)
        for i in range(head):
            block(x1 - head + i, cy - head + i + dy, 1, 2 * (head - i), color)

    # Shelf.
    top = SHELF_TOP // UNIT
    block(0, top, W // UNIT, (H - SHELF_TOP) // UNIT + 1, SHELF)
    block(0, top, W // UNIT, 1, SHELF_LIP)
    block(0, top + 1, W // UNIT, 1, SHELF_SHADOW)
    # Long floorboards with a few knots of grain.
    for row in range(top + 12, H // UNIT, 12):
        block(0, row, W // UNIT, 1, SEAM)
    grain = random.Random(3)
    for _ in range(18):
        gx = grain.randrange(2, W // UNIT - 6)
        gy = grain.randrange(top + 3, H // UNIT - 2)
        if (gy - top) % 12 in (0, 11):
            continue
        block(gx, gy, grain.choice((3, 4, 5)), 1, SEAM)

    # A sleeping cat in the corner, since he's not needed till launch.
    sprite = Image.open(SLEEP_SPRITE).convert("RGBA").crop((0, 0, 32, 24))
    sprite = sprite.crop(sprite.getbbox())
    scale = 3 * s
    sprite = sprite.resize((sprite.width * scale, sprite.height * scale), Image.NEAREST)
    cat_x, cat_bottom = 34 * s, (CONTENT_BOTTOM - 4) * s
    img.paste(sprite, (cat_x, cat_bottom - sprite.height), sprite)
    zz = font(13, "Bold", s)
    d.text((cat_x + sprite.width - 6 * s, cat_bottom - sprite.height - 20 * s), "z", font=zz, fill=STAR)
    d.text((cat_x + sprite.width + 4 * s, cat_bottom - sprite.height - 32 * s), "z", font=zz, fill=STAR)

    # And a cappuccino on the other side.
    gx, gy = (W - 92) // UNIT, (CONTENT_BOTTOM - 40) // UNIT
    colors = {"#": INK, "m": CUP, "c": CREMA}
    for r, row in enumerate(MUG):
        for c, ch in enumerate(row):
            if ch in colors:
                block(gx + c, gy + r, 1, 1, colors[ch])
    for sx, sy in ((4, -2), (5, -3), (4, -4), (7, -2), (8, -3), (7, -4), (8, -5)):
        block(gx + sx, gy + sy, 1, 1, STAR)

    return img


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        one, two = pathlib.Path(tmp) / "bg.png", pathlib.Path(tmp) / "bg@2x.png"
        draw(1).save(one)
        draw(2).save(two)
        subprocess.run(["tiffutil", "-cathidpicheck", str(one), str(two), "-out", str(OUT)],
                       check=True, capture_output=True)
        draw(2).save(ROOT / "scripts" / "dmg" / "background-preview.png")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
