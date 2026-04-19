from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFilter

TILE = 32
COLS = 16

ROOT = Path(__file__).resolve().parents[1]
ATLAS_DIR = ROOT / "assets" / "atlas"
ATLAS_PATH = ATLAS_DIR / "atlas.png"
META_PATH = ATLAS_DIR / "atlas.json"


def clamp_channel(v: int) -> int:
    return 0 if v < 0 else 255 if v > 255 else v


def shade(c: Tuple[int, int, int, int], delta: int) -> Tuple[int, int, int, int]:
    return (
        clamp_channel(c[0] + delta),
        clamp_channel(c[1] + delta),
        clamp_channel(c[2] + delta),
        c[3],
    )


ROLE_ICON_TINT = {
    "basic": (86, 204, 164, 255),
    "gather": (132, 226, 162, 255),
    "defense": (64, 158, 144, 255),
    "melee": (58, 144, 166, 255),
    "ranged": (116, 200, 232, 255),
}


def make_ground(variant: int) -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = im.load()
    for y in range(TILE):
        for x in range(TILE):
            coarse = ((x // 6) * 11 + (y // 6) * 13 + variant * 17) % 7 - 3
            base_r = 52 + int(y * 0.16)
            base_g = 39 + int(y * 0.10)
            base_b = 28 + int(y * 0.08)
            r = base_r + coarse
            g = base_g + coarse
            b = base_b + coarse
            if (x * 7 + y * 5 + variant * 9) % 97 == 0:
                r += 6
                g += 4
                b += 3
            px[x, y] = (r, g, b, 255)
    d = ImageDraw.Draw(im)
    for i in range(2):
        xx = (i * 11 + variant * 7) % 26 + 3
        yy = (i * 9 + variant * 4) % 26 + 3
        peb = (74, 56, 40, 126)
        d.rectangle((xx, yy, xx + 1, yy + 1), fill=peb)
    return im


def make_wall(variant: int) -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = im.load()
    for y in range(TILE):
        for x in range(TILE):
            coarse = ((x // 6) * 9 + (y // 6) * 17 + variant * 11) % 7 - 3
            r = 24 + int(y * 0.10) + coarse
            g = 20 + int(y * 0.08) + coarse
            b = 18 + coarse
            px[x, y] = (r, g, b, 255)
    d = ImageDraw.Draw(im)
    for i in range(3):
        xx = (i * 8 + variant * 6) % 24 + 4
        yy = (i * 7 + variant * 4) % 24 + 4
        d.line((xx, yy, xx + 2, yy + 1), fill=(13, 10, 9, 180), width=1)
    return im


def make_door() -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 2, 27, 30), radius=5, fill=(160, 112, 38, 255), outline=(74, 46, 16, 255), width=2)
    d.rectangle((11, 8, 20, 22), fill=(222, 182, 76, 220))
    d.ellipse((20, 14, 23, 17), fill=(82, 50, 20, 255))
    return im


def make_resource_gem() -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(16, 3), (26, 16), (16, 29), (6, 16)], fill=(56, 214, 132, 255), outline=(18, 96, 62, 255))
    d.polygon([(16, 6), (22, 16), (16, 26), (10, 16)], fill=(166, 255, 208, 235), outline=(42, 120, 86, 255))
    return im


def make_resource_rat() -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((6, 14, 24, 24), fill=(148, 132, 106, 255), outline=(82, 68, 52, 255))
    d.ellipse((20, 15, 30, 22), fill=(162, 144, 116, 255), outline=(82, 68, 52, 255))
    d.line((7, 20, 2, 22), fill=(190, 166, 134, 255), width=2)
    d.line((8, 14, 5, 10), fill=(204, 184, 148, 255), width=1)
    return im


def make_resource_consumed() -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line((8, 8, 23, 23), fill=(128, 92, 62, 255), width=3)
    d.line((23, 8, 8, 23), fill=(128, 92, 62, 255), width=3)
    return im


def build_blob_alpha(mask: int, frame: int) -> Image.Image:
    n = (mask & 1) != 0
    e = (mask & 2) != 0
    s = (mask & 4) != 0
    w = (mask & 8) != 0

    alpha = Image.new("L", (TILE, TILE), 0)
    d = ImageDraw.Draw(alpha)

    # Core puddle mass: thicker center to keep connected tiles visually unified.
    d.ellipse((1, 2, 30, 30), fill=255)
    d.rounded_rectangle((2, 4, 29, 29), radius=10, fill=255)
    d.ellipse((5, 6, 26, 27), fill=255)

    if n:
        d.rounded_rectangle((5, 0, 26, 19), radius=8, fill=255)
    if s:
        d.rounded_rectangle((5, 12, 26, 31), radius=8, fill=255)
    if w:
        d.rounded_rectangle((0, 5, 19, 26), radius=8, fill=255)
    if e:
        d.rounded_rectangle((12, 5, 31, 26), radius=8, fill=255)

    if n and w:
        d.ellipse((0, 0, 20, 20), fill=255)
    if n and e:
        d.ellipse((11, 0, 31, 20), fill=255)
    if s and w:
        d.ellipse((0, 11, 20, 31), fill=255)
    if s and e:
        d.ellipse((11, 11, 31, 31), fill=255)

    # Exposed edge goop for outer silhouette irregularity.
    wobble = [-1, 0, 1][frame % 3]
    if not n:
        d.ellipse((7 + wobble, 0, 15 + wobble, 6), fill=255)
        d.ellipse((17 - wobble, 0, 25 - wobble, 6), fill=255)
        d.ellipse((13, 0, 20, 4), fill=255)
    if not s:
        d.ellipse((7 - wobble, 25, 15 - wobble, 31), fill=255)
        d.ellipse((18 + wobble, 25, 26 + wobble, 31), fill=255)
        d.ellipse((12, 27, 20, 31), fill=255)
    if not w:
        d.ellipse((0, 8 - wobble, 6, 15 - wobble), fill=255)
        d.ellipse((0, 18 + wobble, 6, 25 + wobble), fill=255)
        d.ellipse((0, 13, 4, 20), fill=255)
    if not e:
        d.ellipse((25, 8 + wobble, 31, 15 + wobble), fill=255)
        d.ellipse((25, 18 - wobble, 31, 25 - wobble), fill=255)
        d.ellipse((27, 13, 31, 20), fill=255)

    # Keep inner seams smooth by softening alpha transitions.
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=0.75))
    ap = alpha.load()
    for y in range(TILE):
        for x in range(TILE):
            a = ap[x, y]
            if a < 22:
                ap[x, y] = 0
            elif a < 255:
                ap[x, y] = min(255, a + 32)

    return alpha


def _distance_to_transparent(ap, x: int, y: int, max_r: int = 5) -> int:
    for r in range(1, max_r + 1):
        for yy in range(y - r, y + r + 1):
            for xx in range(x - r, x + r + 1):
                if abs(xx - x) != r and abs(yy - y) != r:
                    continue
                if xx < 0 or yy < 0 or xx >= TILE or yy >= TILE:
                    return r
                if ap[xx, yy] == 0:
                    return r
    return max_r + 1


def colorize_blob(alpha: Image.Image, frame: int, mask: int) -> Image.Image:
    base = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = base.load()
    ap = alpha.load()

    cx = 16 + (mask % 3) - 1
    cy = 15 + ((mask // 2) % 3) - 1
    cx2, cy2 = cx - 5, cy - 4
    cx3, cy3 = cx + 6, cy + 5

    for y in range(TILE):
        for x in range(TILE):
            a = ap[x, y]
            if a == 0:
                continue
            d1 = math.dist((x, y), (cx, cy))
            d2 = math.dist((x, y), (cx2, cy2))
            d3 = math.dist((x, y), (cx3, cy3))

            # Volumetric mass: bright center, soft shoulder, dark edge.
            center_lift = max(0.0, 1.0 - d1 / 13.0) * 38.0
            lobe_lift = max(0.0, 1.0 - d2 / 10.0) * 14.0
            lobe_drop = max(0.0, 1.0 - d3 / 10.0) * 12.0

            edge_dist = _distance_to_transparent(ap, x, y, 5)
            edge_drop = max(0, 6 - edge_dist) * 7

            l = int(122 + center_lift + lobe_lift - lobe_drop - edge_drop)
            px[x, y] = (clamp_channel(l), clamp_channel(l), clamp_channel(l), a)

    d = ImageDraw.Draw(base)
    # Subtle bubble sheen; low frequency to avoid tile-noise look.
    shift = [-1, 0, 1][frame]
    d.ellipse((8 + shift, 8, 14 + shift, 13), fill=(255, 255, 255, 52))
    d.ellipse((18 - shift, 14, 23 - shift, 19), fill=(255, 255, 255, 44))
    d.ellipse((12, 18 + shift, 16, 22 + shift), fill=(255, 255, 255, 34))

    # Smooth tiny residual hard transitions.
    base = base.filter(ImageFilter.GaussianBlur(radius=0.35))
    return base


def make_base_slime(mask: int, frame: int) -> Image.Image:
    alpha = build_blob_alpha(mask, frame)
    return colorize_blob(alpha, frame, mask)


def make_overlay(tile_type: str, infused: bool = False) -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    if tile_type == "basic":
        d.ellipse((11, 12, 19, 19), fill=(214, 214, 214, 34))
        d.ellipse((9, 16, 15, 21), fill=(194, 194, 194, 24))

    elif tile_type == "gather":
        d.ellipse((8, 8, 24, 24), fill=(104, 104, 104, 52))
        d.polygon([(16, 8), (21, 14), (16, 23), (11, 14)], fill=(238, 238, 238, 148), outline=(94, 94, 94, 96))
        d.polygon([(9, 16), (12, 20), (9, 24), (6, 20)], fill=(224, 224, 224, 128), outline=(90, 90, 90, 88))
        d.polygon([(23, 13), (26, 16), (23, 20), (20, 16)], fill=(228, 228, 228, 132), outline=(90, 90, 90, 88))
        if infused:
            d.ellipse((13, 3, 19, 8), fill=(255, 255, 255, 90))
            d.ellipse((3, 14, 7, 18), fill=(255, 255, 255, 76))
            d.ellipse((24, 20, 28, 24), fill=(255, 255, 255, 76))

    elif tile_type == "defense":
        d.ellipse((6, 7, 26, 25), fill=(74, 74, 74, 58))
        d.rounded_rectangle((8, 9, 24, 23), radius=6, fill=(182, 182, 182, 122), outline=(86, 86, 86, 104), width=1)
        d.line((10, 13, 22, 13), fill=(238, 238, 238, 84), width=1)
        d.line((10, 18, 22, 18), fill=(236, 236, 236, 72), width=1)

    elif tile_type == "melee":
        d.ellipse((8, 12, 24, 25), fill=(74, 74, 74, 52))
        d.polygon([(10, 23), (13, 10), (16, 22)], fill=(226, 226, 226, 122), outline=(92, 92, 92, 104))
        d.polygon([(14, 22), (17, 8), (20, 21)], fill=(232, 232, 232, 128), outline=(94, 94, 94, 106))
        d.polygon([(18, 23), (21, 11), (24, 22)], fill=(218, 218, 218, 118), outline=(88, 88, 88, 98))

    elif tile_type == "ranged":
        d.ellipse((8, 8, 24, 24), fill=(82, 82, 82, 56))
        d.ellipse((10, 10, 22, 22), fill=(210, 210, 210, 118), outline=(96, 96, 96, 104), width=1)
        d.ellipse((13, 13, 19, 19), fill=(244, 244, 244, 116))
        d.rectangle((22, 14, 27, 18), fill=(190, 190, 190, 96), outline=(88, 88, 88, 90), width=1)

    # Soften icon-like edges and keep overlays embedded in slime mass.
    im = im.filter(ImageFilter.GaussianBlur(radius=0.55))
    return im


def tint_image(source: Image.Image, tint: Tuple[int, int, int, int]) -> Image.Image:
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    src = source.load()
    dst = out.load()
    tr, tg, tb, ta = tint
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            nr = (r * tr) // 255
            ng = (g * tg) // 255
            nb = (b * tb) // 255
            na = (a * ta) // 255
            dst[x, y] = (nr, ng, nb, na)
    return out


def make_ui_panel() -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(TILE):
        t = y / 31.0
        c = (26 + int(10 * t), 38 + int(14 * t), 50 + int(16 * t), 255)
        d.line((0, y, 31, y), fill=c)
    d.rectangle((0, 0, 31, 31), outline=(188, 148, 88, 255), width=2)
    d.rectangle((2, 2, 29, 29), outline=(76, 58, 38, 255), width=1)
    d.rectangle((4, 4, 27, 27), outline=(36, 52, 66, 255), width=1)
    return im


def make_ui_button(base: Tuple[int, int, int, int], accent: Tuple[int, int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(TILE):
        delta = int((y / 31.0) * 12)
        c = shade(base, delta)
        d.line((0, y, 31, y), fill=c)
    d.rectangle((0, 0, 31, 31), outline=accent, width=2)
    d.rectangle((2, 2, 29, 29), outline=shade(base, -34), width=1)
    d.line((4, 5, 27, 5), fill=shade(base, 26), width=1)
    return im


def make_ui_icon(tile_type: str) -> Image.Image:
    base = make_overlay(tile_type)
    base = tint_image(base, ROLE_ICON_TINT.get(tile_type, ROLE_ICON_TINT["basic"]))
    frame = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle((3, 3, 28, 28), radius=4, outline=(198, 168, 102, 255), width=2)
    frame.alpha_composite(base)
    return frame


sprites: List[Tuple[str, Image.Image]] = []

for i in range(6):
    sprites.append((f"ground_{i:02d}", make_ground(i)))
for i in range(3):
    sprites.append((f"wall_{i:02d}", make_wall(i)))
sprites.append(("door_00", make_door()))
sprites.append(("resource_gem_00", make_resource_gem()))
sprites.append(("resource_rat_00", make_resource_rat()))
sprites.append(("resource_consumed_00", make_resource_consumed()))

for frame in range(3):
    for mask in range(16):
        sprites.append((f"slime_base_neutral_m{mask:02d}_f{frame}", make_base_slime(mask, frame)))

for tile_type in ["basic", "gather", "defense", "melee", "ranged"]:
    sprites.append((f"slime_overlay_{tile_type}", make_overlay(tile_type, infused=False)))
sprites.append(("slime_overlay_gather_infused", make_overlay("gather", infused=True)))

sprites.append(("ui_panel_tile", make_ui_panel()))
sprites.append(("ui_button_tile", make_ui_button((34, 88, 112, 255), (206, 174, 98, 255))))
sprites.append(("ui_button_selected", make_ui_button((46, 126, 102, 255), (220, 210, 118, 255))))
sprites.append(("ui_button_endturn", make_ui_button((138, 42, 36, 255), (230, 196, 108, 255))))

for tile_type in ["basic", "melee", "ranged", "gather", "defense"]:
    sprites.append((f"ui_icon_{tile_type}", make_ui_icon(tile_type)))

rows = (len(sprites) + COLS - 1) // COLS
atlas = Image.new("RGBA", (COLS * TILE, rows * TILE), (0, 0, 0, 0))
meta = {
    "tile_size": TILE,
    "atlas_size": [COLS * TILE, rows * TILE],
    "sprites": {},
}

for idx, (name, image) in enumerate(sprites):
    x = (idx % COLS) * TILE
    y = (idx // COLS) * TILE
    atlas.alpha_composite(image, (x, y))
    meta["sprites"][name] = {"x": x, "y": y, "w": TILE, "h": TILE}

ATLAS_DIR.mkdir(parents=True, exist_ok=True)
atlas.save(ATLAS_PATH)
META_PATH.write_text(json.dumps(meta, indent=2), encoding="utf-8")

print(f"Wrote {ATLAS_PATH}")
print(f"Wrote {META_PATH}")
print(f"Sprites: {len(sprites)}")
