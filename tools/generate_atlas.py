from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw, ImageFilter

TILE = 32
COLS = 16
BASE_VARIANTS = 3
# Higher supersample improves edge smoothness and pooled silhouette quality
# without changing runtime grid alignment or atlas contracts.
AUTOTILE_SCALE = 8
AUTOTILE_SIZE = TILE * AUTOTILE_SCALE
RESAMPLE_LANCZOS = Image.Resampling.LANCZOS if hasattr(Image, "Resampling") else Image.LANCZOS

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

    # Build topology at high resolution, then downsample for smooth curves.
    alpha_hr = Image.new("L", (AUTOTILE_SIZE, AUTOTILE_SIZE), 255)
    d = ImageDraw.Draw(alpha_hr)

    # Slightly thicker pooled mass and stronger connectors.
    side_inset: int = 4 * AUTOTILE_SCALE + (frame % 2)
    side_radius: int = 7 * AUTOTILE_SCALE
    transition: int = 4 * AUTOTILE_SCALE
    corner_radius: int = 10 * AUTOTILE_SCALE
    goop: int = 2 * AUTOTILE_SCALE + (frame % 2)

    def carve_top() -> None:
        x0 = 0 if not w else transition
        x1 = AUTOTILE_SIZE if not e else AUTOTILE_SIZE - transition
        d.rectangle((x0, 0, x1, side_inset), fill=0)
        d.rounded_rectangle((x0, 0, x1, side_inset * 2), radius=side_radius, fill=0)

    def carve_bottom() -> None:
        x0 = 0 if not w else transition
        x1 = AUTOTILE_SIZE if not e else AUTOTILE_SIZE - transition
        d.rectangle((x0, AUTOTILE_SIZE - side_inset, x1, AUTOTILE_SIZE), fill=0)
        d.rounded_rectangle((x0, AUTOTILE_SIZE - side_inset * 2, x1, AUTOTILE_SIZE), radius=side_radius, fill=0)

    def carve_left() -> None:
        y0 = 0 if not n else transition
        y1 = AUTOTILE_SIZE if not s else AUTOTILE_SIZE - transition
        d.rectangle((0, y0, side_inset, y1), fill=0)
        d.rounded_rectangle((0, y0, side_inset * 2, y1), radius=side_radius, fill=0)

    def carve_right() -> None:
        y0 = 0 if not n else transition
        y1 = AUTOTILE_SIZE if not s else AUTOTILE_SIZE - transition
        d.rectangle((AUTOTILE_SIZE - side_inset, y0, AUTOTILE_SIZE, y1), fill=0)
        d.rounded_rectangle((AUTOTILE_SIZE - side_inset * 2, y0, AUTOTILE_SIZE, y1), radius=side_radius, fill=0)

    if not n:
        carve_top()
    if not s:
        carve_bottom()
    if not w:
        carve_left()
    if not e:
        carve_right()

    # Outer (convex) corners.
    if not n and not w:
        d.pieslice((0, 0, corner_radius * 2, corner_radius * 2), 180, 270, fill=0)
    if not n and not e:
        d.pieslice((AUTOTILE_SIZE - corner_radius * 2, 0, AUTOTILE_SIZE, corner_radius * 2), 270, 360, fill=0)
    if not s and not e:
        d.pieslice((AUTOTILE_SIZE - corner_radius * 2, AUTOTILE_SIZE - corner_radius * 2, AUTOTILE_SIZE, AUTOTILE_SIZE), 0, 90, fill=0)
    if not s and not w:
        d.pieslice((0, AUTOTILE_SIZE - corner_radius * 2, corner_radius * 2, AUTOTILE_SIZE), 90, 180, fill=0)

    # Inner (concave transition) corners where exposed sides meet connected sides.
    if not n and w:
        d.ellipse((0, 0, transition * 2, transition * 2), fill=255)
    if not n and e:
        d.ellipse((AUTOTILE_SIZE - transition * 2, 0, AUTOTILE_SIZE, transition * 2), fill=255)
    if not s and w:
        d.ellipse((0, AUTOTILE_SIZE - transition * 2, transition * 2, AUTOTILE_SIZE), fill=255)
    if not s and e:
        d.ellipse((AUTOTILE_SIZE - transition * 2, AUTOTILE_SIZE - transition * 2, AUTOTILE_SIZE, AUTOTILE_SIZE), fill=255)

    # Slight goopy protrusions only on exposed boundaries.
    if not n:
        d.ellipse((AUTOTILE_SIZE // 2 - side_radius // 2, 0, AUTOTILE_SIZE // 2 + side_radius // 2, goop * 2), fill=0)
    if not s:
        d.ellipse((AUTOTILE_SIZE // 2 - side_radius // 2, AUTOTILE_SIZE - goop * 2, AUTOTILE_SIZE // 2 + side_radius // 2, AUTOTILE_SIZE), fill=0)
    if not w:
        d.ellipse((0, AUTOTILE_SIZE // 2 - side_radius // 2, goop * 2, AUTOTILE_SIZE // 2 + side_radius // 2), fill=0)
    if not e:
        d.ellipse((AUTOTILE_SIZE - goop * 2, AUTOTILE_SIZE // 2 - side_radius // 2, AUTOTILE_SIZE, AUTOTILE_SIZE // 2 + side_radius // 2), fill=0)

    alpha_hr = alpha_hr.filter(ImageFilter.GaussianBlur(radius=1.5))
    alpha = alpha_hr.resize((TILE, TILE), resample=RESAMPLE_LANCZOS)
    ap = alpha.load()

    for y in range(TILE):
        for x in range(TILE):
            a = ap[x, y]
            if a < 16:
                ap[x, y] = 0
            elif a < 248:
                ap[x, y] = min(255, a + 20)

    # Force connected borders to remain fully sealed to prevent seams/gaps.
    if n:
        for x in range(TILE):
            ap[x, 0] = 255
            ap[x, 1] = max(ap[x, 1], 250)
            ap[x, 2] = max(ap[x, 2], 242)
    if s:
        for x in range(TILE):
            ap[x, TILE - 1] = 255
            ap[x, TILE - 2] = max(ap[x, TILE - 2], 250)
            ap[x, TILE - 3] = max(ap[x, TILE - 3], 242)
    if w:
        for y in range(TILE):
            ap[0, y] = 255
            ap[1, y] = max(ap[1, y], 250)
            ap[2, y] = max(ap[2, y], 242)
    if e:
        for y in range(TILE):
            ap[TILE - 1, y] = 255
            ap[TILE - 2, y] = max(ap[TILE - 2, y], 250)
            ap[TILE - 3, y] = max(ap[TILE - 3, y], 242)

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


def colorize_blob(alpha: Image.Image, frame: int, mask: int, variant: int) -> Image.Image:
    base = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = base.load()
    ap = alpha.load()
    variant_phase = float(variant) * 1.21
    phase = float(frame) * 0.64 + variant_phase
    tau = 2.0 * math.pi
    n = (mask & 1) != 0
    e = (mask & 2) != 0
    s = (mask & 4) != 0
    w = (mask & 8) != 0

    for y in range(TILE):
        for x in range(TILE):
            a = ap[x, y]
            if a == 0:
                continue
            # Exposed-edge shading follows connectivity mask, but interior shading
            # stays pooled and directional (not per-tile radial bubble lighting).
            dist_top = float(y)
            dist_right = float(TILE - 1 - x)
            dist_bottom = float(TILE - 1 - y)
            dist_left = float(x)

            exposed = 0.0
            if not n:
                exposed = max(exposed, max(0.0, 1.0 - dist_top / 6.0))
            if not e:
                exposed = max(exposed, max(0.0, 1.0 - dist_right / 6.0))
            if not s:
                exposed = max(exposed, max(0.0, 1.0 - dist_bottom / 6.0))
            if not w:
                exposed = max(exposed, max(0.0, 1.0 - dist_left / 6.0))

            # Slightly reinforce convex corner darkening.
            corner_exposed = 0.0
            if not n and not w:
                corner_exposed = max(corner_exposed, max(0.0, 1.0 - max(dist_top, dist_left) / 7.0))
            if not n and not e:
                corner_exposed = max(corner_exposed, max(0.0, 1.0 - max(dist_top, dist_right) / 7.0))
            if not s and not e:
                corner_exposed = max(corner_exposed, max(0.0, 1.0 - max(dist_bottom, dist_right) / 7.0))
            if not s and not w:
                corner_exposed = max(corner_exposed, max(0.0, 1.0 - max(dist_bottom, dist_left) / 7.0))

            edge_strength = max(exposed, corner_exposed)
            edge_dist: float = float(_distance_to_transparent(ap, x, y, max_r=6))
            interior_factor: float = min(1.0, edge_dist / 6.0)
            u = float(x) / float(TILE - 1)
            v = float(y) / float(TILE - 1)
            directional = (1.0 - (0.68 * u + 0.90 * v)) * 15.0
            # Low-frequency surface detail that tiles seamlessly.
            wave_a = math.sin((u + v) * tau + phase * 0.60)
            wave_b = math.sin((u * 1.90 - v * 1.25) * tau - phase * 0.46)
            wave_c = math.sin((u * 1.25 + v * 2.10) * tau + phase * 0.38)
            pooled_surface = (wave_a * 1.6 + wave_b * 1.3 + wave_c * 1.1) * (0.24 + interior_factor * 0.76)
            # Sparse "snap" pits add life without noisy micro texture.
            snap_field = math.sin((u * 3.1 + v * 2.3) * tau + phase * 0.52) + math.sin((u * 2.2 - v * 2.9) * tau - phase * 0.40)
            snap_drop = 0.0
            if snap_field > 1.45 and interior_factor > 0.28:
                snap_drop = 2.4 + interior_factor * 1.8

            interior_lift = 16.0 * interior_factor
            edge_drop = edge_strength * 22.0
            rim_drop = max(0.0, edge_strength - 0.14) * 28.0
            pulse = [-1.0, 0.0, 1.0][frame] * (0.25 + interior_factor * 0.75)
            l = int(136.0 + interior_lift + directional + pooled_surface + pulse - edge_drop - rim_drop - snap_drop)
            px[x, y] = (clamp_channel(l), clamp_channel(l), clamp_channel(l), a)

    # Keep pooled softness but avoid a flat washout.
    base = base.filter(ImageFilter.GaussianBlur(radius=0.16))
    return base


def make_base_slime(mask: int, frame: int, variant: int) -> Image.Image:
    alpha = build_blob_alpha(mask, frame)
    return colorize_blob(alpha, frame, mask, variant)


def make_overlay(tile_type: str, infused: bool = False) -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    if tile_type == "basic":
        d.ellipse((9, 11, 20, 21), fill=(220, 220, 220, 34))
        d.ellipse((13, 9, 19, 15), fill=(244, 244, 244, 28))

    elif tile_type == "gather":
        d.ellipse((7, 8, 25, 25), fill=(88, 88, 88, 58))
        d.polygon([(16, 8), (22, 15), (16, 24), (10, 15)], fill=(246, 246, 246, 168))
        d.polygon([(9, 17), (13, 22), (9, 26), (5, 22)], fill=(232, 232, 232, 146))
        d.polygon([(23, 15), (27, 19), (23, 23), (19, 19)], fill=(236, 236, 236, 152))
        d.line((11, 15, 21, 15), fill=(58, 58, 58, 104), width=1)
        if infused:
            d.ellipse((12, 3, 20, 10), fill=(255, 255, 255, 98))
            d.ellipse((3, 14, 9, 19), fill=(255, 255, 255, 78))
            d.ellipse((23, 20, 29, 25), fill=(255, 255, 255, 78))

    elif tile_type == "defense":
        d.ellipse((6, 8, 26, 25), fill=(68, 68, 68, 68))
        d.rounded_rectangle((7, 9, 25, 24), radius=6, fill=(196, 196, 196, 140))
        d.rounded_rectangle((9, 11, 23, 22), radius=5, outline=(248, 248, 248, 104), width=1)
        d.line((10, 14, 22, 14), fill=(244, 244, 244, 96), width=1)
        d.line((10, 18, 22, 18), fill=(232, 232, 232, 80), width=1)
        d.rounded_rectangle((7, 9, 25, 24), radius=6, outline=(64, 64, 64, 120), width=1)

    elif tile_type == "melee":
        d.ellipse((7, 11, 25, 26), fill=(70, 70, 70, 60))
        d.polygon([(9, 24), (13, 10), (16, 23)], fill=(238, 238, 238, 142))
        d.polygon([(14, 23), (17, 7), (20, 22)], fill=(246, 246, 246, 150))
        d.polygon([(18, 24), (22, 10), (25, 23)], fill=(230, 230, 230, 136))
        d.line((12, 20, 22, 12), fill=(66, 66, 66, 98), width=1)

    elif tile_type == "ranged":
        d.ellipse((6, 6, 26, 26), fill=(94, 94, 94, 56))
        d.ellipse((8, 8, 24, 24), fill=(210, 210, 210, 110))
        d.ellipse((10, 10, 22, 22), fill=(236, 236, 236, 124))
        d.ellipse((13, 13, 19, 19), fill=(255, 255, 255, 154))
        d.rectangle((22, 13, 28, 19), fill=(218, 218, 218, 114))
        d.ellipse((11, 11, 21, 21), outline=(255, 255, 255, 82), width=1)
        d.ellipse((4, 4, 28, 28), outline=(255, 255, 255, 44), width=1)

    # Keep overlays embedded, but sharper than before for gameplay readability.
    im = im.filter(ImageFilter.GaussianBlur(radius=0.24))
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
    px = im.load()
    d = ImageDraw.Draw(im)

    # Darkened cave-derived slab with a clean center for stylebox stretching.
    for y in range(TILE):
        for x in range(TILE):
            t = y / float(TILE - 1)
            cave = ((x // 7) * 5 + (y // 7) * 7 + ((x + y) // 9) * 3) % 7 - 3
            edge_dist = min(x, y, TILE - 1 - x, TILE - 1 - y)
            edge_shade = max(0.0, 1.0 - edge_dist / 8.5)
            slab_r = 27 + int(8 * t) + cave - int(edge_shade * 2.0)
            slab_g = 22 + int(6 * t) + cave - int(edge_shade * 2.0)
            slab_b = 18 + int(5 * t) + cave - int(edge_shade * 2.0)
            px[x, y] = (clamp_channel(slab_r), clamp_channel(slab_g), clamp_channel(slab_b), 255)

    # Strong carved frame with directional lighting.
    d.rounded_rectangle((0, 0, 31, 31), radius=4, outline=(188, 152, 98, 255), width=3)
    d.rounded_rectangle((2, 2, 29, 29), radius=3, outline=(74, 54, 34, 228), width=2)
    d.rounded_rectangle((4, 4, 27, 27), radius=2, outline=(20, 14, 10, 184), width=1)
    d.line((4, 4, 27, 4), fill=(198, 164, 112, 118), width=1)
    d.line((4, 5, 27, 5), fill=(154, 122, 84, 92), width=1)
    d.line((4, 27, 27, 27), fill=(8, 6, 4, 172), width=1)
    d.line((5, 26, 26, 26), fill=(14, 10, 7, 122), width=1)
    d.line((27, 4, 27, 27), fill=(8, 6, 4, 160), width=1)

    # In-panel shadow cue so panels feel layered over world.
    d.rectangle((6, 22, 29, 29), fill=(0, 0, 0, 26))
    d.rectangle((22, 6, 29, 29), fill=(0, 0, 0, 20))

    # Minimal slime influence on edges only.
    d.ellipse((2, 24, 8, 30), fill=(86, 168, 132, 36))
    d.ellipse((23, 2, 29, 8), fill=(152, 84, 104, 24))
    return im


def make_ui_button(base: Tuple[int, int, int, int], accent: Tuple[int, int, int, int], state: str = "normal") -> Image.Image:
    im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = im.load()
    d = ImageDraw.Draw(im)

    # Stone tile button with controlled tint contribution.
    lift = 0
    if state == "hover":
        lift = 6
    elif state == "pressed":
        lift = -8

    tint_mix = 0.22
    for y in range(TILE):
        for x in range(TILE):
            t = y / float(TILE - 1)
            edge_dist = min(x, y, TILE - 1 - x, TILE - 1 - y)
            edge_shade = max(0.0, 1.0 - edge_dist / 7.0)
            stone_r = 40 + int(8 * t - edge_shade * 2.0) + lift
            stone_g = 34 + int(7 * t - edge_shade * 2.0) + lift
            stone_b = 28 + int(6 * t - edge_shade * 2.0) + lift
            rr = int(stone_r * (1.0 - tint_mix) + base[0] * tint_mix)
            gg = int(stone_g * (1.0 - tint_mix) + base[1] * tint_mix)
            bb = int(stone_b * (1.0 - tint_mix) + base[2] * tint_mix)
            px[x, y] = (clamp_channel(rr), clamp_channel(gg), clamp_channel(bb), 255)

    # Frame and depth: normal=embedded, hover=raised, pressed=deeper inset.
    d.rounded_rectangle((0, 0, 31, 31), radius=5, outline=accent, width=2)
    d.rounded_rectangle((2, 2, 29, 29), radius=4, outline=(68, 50, 32, 228), width=1)
    d.rounded_rectangle((4, 4, 27, 27), radius=3, outline=(18, 13, 9, 170), width=1)
    if state == "hover":
        d.line((5, 5, 26, 5), fill=(206, 172, 122, 126), width=1)
        d.line((5, 6, 26, 6), fill=(166, 132, 92, 98), width=1)
        d.line((6, 26, 25, 26), fill=(6, 5, 4, 110), width=1)
        d.rectangle((7, 9, 24, 23), outline=(18, 12, 8, 62), width=1)
    elif state == "pressed":
        d.line((5, 5, 26, 5), fill=(86, 68, 48, 78), width=1)
        d.line((6, 26, 25, 26), fill=(0, 0, 0, 184), width=1)
        d.line((6, 25, 25, 25), fill=(4, 3, 3, 152), width=1)
        d.rectangle((7, 10, 24, 24), outline=(8, 6, 5, 118), width=1)
    else:
        d.line((5, 6, 26, 6), fill=(146, 116, 80, 80), width=1)
        d.line((6, 25, 25, 25), fill=(8, 6, 5, 144), width=1)
        d.rectangle((7, 9, 24, 23), outline=(14, 10, 8, 84), width=1)
        d.rectangle((7, 10, 24, 24), fill=(0, 0, 0, 10))

    # Minimal cave/slime character without center-line artifacts.
    d.ellipse((3, 25, 8, 30), fill=(90, 176, 138, 34))
    d.ellipse((24, 3, 29, 8), fill=(154, 82, 102, 26))
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
        for variant in range(BASE_VARIANTS):
            sprites.append((f"slime_base_neutral_m{mask:02d}_v{variant}_f{frame}", make_base_slime(mask, frame, variant)))
        # Compatibility key for older renderers/scenes.
        sprites.append((f"slime_base_neutral_m{mask:02d}_f{frame}", make_base_slime(mask, frame, 0)))

for tile_type in ["basic", "gather", "defense", "melee", "ranged"]:
    sprites.append((f"slime_overlay_{tile_type}", make_overlay(tile_type, infused=False)))
sprites.append(("slime_overlay_gather_infused", make_overlay("gather", infused=True)))

sprites.append(("ui_panel_tile", make_ui_panel()))
sprites.append(("ui_button_tile", make_ui_button((34, 88, 112, 255), (206, 174, 98, 255), "normal")))
sprites.append(("ui_button_hover_tile", make_ui_button((34, 88, 112, 255), (206, 174, 98, 255), "hover")))
sprites.append(("ui_button_pressed_tile", make_ui_button((34, 88, 112, 255), (206, 174, 98, 255), "pressed")))
sprites.append(("ui_button_selected", make_ui_button((46, 126, 102, 255), (220, 210, 118, 255), "hover")))
sprites.append(("ui_button_endturn", make_ui_button((138, 42, 36, 255), (230, 196, 108, 255), "normal")))
sprites.append(("ui_button_endturn_hover", make_ui_button((138, 42, 36, 255), (230, 196, 108, 255), "hover")))
sprites.append(("ui_button_endturn_pressed", make_ui_button((138, 42, 36, 255), (230, 196, 108, 255), "pressed")))

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
