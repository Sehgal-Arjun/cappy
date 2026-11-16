#!/usr/bin/env python3
"""Draws Resources/AppIcon.icns from the idle cat sprite.

Needs Pillow (pip install pillow) and macOS's iconutil. Only rerun this when
the icon should change; the generated .icns is committed.
"""
import pathlib
import subprocess
import tempfile

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPRITE = ROOT / "art" / "icon-cat.png"
OUT = ROOT / "Resources" / "AppIcon.icns"

CANVAS = 1024
TILE = 824              # macOS icon grid: 824px tile centred on 1024
RADIUS = 186
CREAM = (246, 239, 226, 255)
FLOOR = (234, 222, 200, 255)
LINE = (220, 205, 178, 255)


def draw_master() -> Image.Image:
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    off = (CANVAS - TILE) // 2

    tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle([0, 0, TILE - 1, TILE - 1], RADIUS, fill=CREAM)

    # Floor band the cat sits on.
    floor_y = int(TILE * 0.74)
    band = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    ImageDraw.Draw(band).rectangle([0, floor_y, TILE, TILE], fill=FLOOR)
    ImageDraw.Draw(band).rectangle([0, floor_y, TILE, floor_y + 6], fill=LINE)
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, TILE - 1, TILE - 1], RADIUS, fill=255)
    tile.paste(band, (0, 0), Image.composite(band, Image.new("RGBA", band.size), mask))

    # Cat, scaled by a whole number so the pixels stay square.
    cat = Image.open(SPRITE).convert("RGBA")
    cat = cat.crop(cat.getbbox())
    scale = 16
    cat = cat.resize((cat.width * scale, cat.height * scale), Image.NEAREST)
    x = (TILE - cat.width) // 2
    y = floor_y + 3 - cat.height
    tile.alpha_composite(cat, (x, y))

    img.alpha_composite(tile, (off, off))
    return img


def main() -> None:
    master = draw_master()
    with tempfile.TemporaryDirectory() as tmp:
        iconset = pathlib.Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for factor in (1, 2):
                px = size * factor
                name = f"icon_{size}x{size}{'@2x' if factor == 2 else ''}.png"
                # Small sizes: hard pixels read better than a blurry shrink.
                resample = Image.NEAREST if px <= 64 else Image.LANCZOS
                master.resize((px, px), resample).save(iconset / name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(OUT)], check=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
