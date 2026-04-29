"""Deterministic Blender bpy asset generators for Ooze Tactics cave kit.

Run via:
    blender -b --python tools/blender_gen/run_all.py
"""

from __future__ import annotations

from math import cos, pi, radians, sin, sqrt
from pathlib import Path
from typing import Callable, Iterable

import bpy
from mathutils import Vector


ASSET_REPLACEMENT_MAP: dict[str, str] = {
    "floor_tile_cobbled_A.glb": "Primary ancient cobbled dungeon floor tile.",
    "floor_tile_cobbled_B.glb": "Secondary cracked cobbled dungeon floor tile.",
    "floor_tile_cobbled_C.glb": "Tertiary worn cobbled dungeon floor tile.",
    "outer_wall_stone_A.glb": "Primary modular outer dungeon boundary wall.",
    "outer_wall_stone_B.glb": "Secondary modular outer dungeon boundary wall.",
    "inner_wall_stone_A.glb": "Inner gameplay wall tile as ancient masonry.",
    "inner_wall_stone_B.glb": "Variant inner gameplay wall tile as broken masonry.",
    "door_arch_dungeon.glb": "Large old dungeon door arch objective.",
    "rubble_blocker_A.glb": "Collapsed masonry blocker variant.",
    "rubble_blocker_B.glb": "Low broken wall and rubble blocker variant.",
    "pillar_ruin_A.glb": "Ruined pillar blocker variant.",
    "core_growth.glb": "Organic heart/core ooze growth that anchors faction territory.",
    "basic_tile.glb": "Continuous low-profile base ooze tile expression.",
    "melee_growth.glb": "Directional tendril ooze growth for melee-specialized tiles.",
    "ranged_growth.glb": "Stalk-and-bulb ooze growth for ranged-specialized tiles.",
    "defense_growth.glb": "Layered low-profile ooze mound for defense-specialized tiles.",
    "gather_growth.glb": "Clustered ooze nodules for gather-specialized tiles.",
}


# Deterministic recipe parameters (shape first, detail second).
# Cave-kit cohesion pass:
# - shared matte stone color family across floors, blockers, and outer walls
# - low-frequency fractured planes instead of micro pebble noise
# - low skirts and broad feet to embed walls into the floor plane
STONE_FAMILY_DARK = (0.19, 0.18, 0.17, 1.0)
STONE_FAMILY_MID = (0.21, 0.20, 0.19, 1.0)
STONE_FAMILY_COOL = (0.20, 0.20, 0.20, 1.0)

OUTER_CAVE_WALL_A_RECIPE = {
    "material": {"base_color": STONE_FAMILY_DARK, "roughness": 0.94, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, -0.02, 0.12), "scale": (2.02, 0.92, 0.20), "rotation_deg": (0.0, 0.0, -3.0)},
        {"location": (-0.82, -0.12, 0.26), "scale": (0.82, 1.06, 0.26), "rotation_deg": (2.0, -2.0, 10.0)},
        {"location": (0.84, 0.04, 0.28), "scale": (0.86, 1.00, 0.25), "rotation_deg": (-1.0, 3.0, -8.0)},
        {"location": (-0.92, 0.16, 0.82), "scale": (0.70, 0.70, 0.92), "rotation_deg": (4.0, -7.0, 8.0)},
        {"location": (-0.22, 0.18, 1.04), "scale": (0.94, 0.62, 1.12), "rotation_deg": (3.0, 5.0, -5.0)},
        {"location": (0.64, 0.10, 0.86), "scale": (0.78, 0.70, 0.96), "rotation_deg": (4.0, -3.0, 7.0)},
        {"location": (0.06, 0.38, 1.34), "scale": (1.30, 0.36, 0.42), "rotation_deg": (5.0, 0.0, 4.0)},
        {"location": (-0.30, -0.54, 0.46), "scale": (1.18, 0.18, 0.18), "rotation_deg": (0.0, 0.0, 1.0)},
    ],
    "boulders": [
        {"location": (-0.54, 0.28, 1.48), "radius": 0.28, "scale": (1.22, 0.72, 0.88)},
        {"location": (0.52, 0.22, 1.38), "radius": 0.26, "scale": (1.16, 0.70, 0.92)},
    ],
    "finish": {
        "voxel_size": 0.070,
        "displace_strength": 0.052,
        "noise_scale": 1.18,
        "noise_depth": 2,
        "smooth_factor": 0.16,
        "smooth_iterations": 3,
        "decimate_ratio": 0.955,
        "bevel_width": 0.020,
    },
}

OUTER_CAVE_WALL_B_RECIPE = {
    "material": {"base_color": STONE_FAMILY_DARK, "roughness": 0.94, "metallic": 0.0},
    "chunks": [
        {"location": (0.02, 0.00, 0.12), "scale": (2.08, 0.96, 0.20), "rotation_deg": (0.0, 0.0, 3.5)},
        {"location": (-0.94, 0.02, 0.28), "scale": (0.74, 0.96, 0.24), "rotation_deg": (1.0, -3.0, 12.0)},
        {"location": (0.76, -0.10, 0.28), "scale": (0.96, 1.10, 0.24), "rotation_deg": (-2.0, 4.0, -6.0)},
        {"location": (-0.70, 0.18, 0.74), "scale": (0.82, 0.74, 0.84), "rotation_deg": (4.0, -5.0, 12.0)},
        {"location": (0.08, 0.20, 1.00), "scale": (0.98, 0.62, 1.04), "rotation_deg": (3.0, 6.0, -7.0)},
        {"location": (0.88, 0.08, 0.90), "scale": (0.66, 0.76, 0.94), "rotation_deg": (3.0, 4.0, -10.0)},
        {"location": (0.12, 0.42, 1.36), "scale": (1.42, 0.34, 0.40), "rotation_deg": (5.0, 0.0, -5.0)},
        {"location": (0.44, -0.56, 0.44), "scale": (1.02, 0.18, 0.17), "rotation_deg": (0.0, 0.0, -4.0)},
    ],
    "boulders": [
        {"location": (-0.22, 0.26, 1.46), "radius": 0.27, "scale": (1.10, 0.72, 0.96)},
        {"location": (0.84, 0.18, 1.30), "radius": 0.24, "scale": (1.20, 0.70, 0.88)},
    ],
    "finish": {
        "voxel_size": 0.070,
        "displace_strength": 0.054,
        "noise_scale": 1.20,
        "noise_depth": 2,
        "smooth_factor": 0.16,
        "smooth_iterations": 3,
        "decimate_ratio": 0.955,
        "bevel_width": 0.020,
    },
}

OUTER_CAVE_WALL_C_RECIPE = {
    "material": {"base_color": STONE_FAMILY_DARK, "roughness": 0.95, "metallic": 0.0},
    "chunks": [
        {"location": (-0.02, -0.04, 0.10), "scale": (2.18, 1.04, 0.22), "rotation_deg": (0.0, 0.0, -1.0)},
        {"location": (-0.90, -0.12, 0.34), "scale": (0.86, 0.88, 0.34), "rotation_deg": (5.0, -8.0, 13.0)},
        {"location": (0.80, 0.08, 0.36), "scale": (1.04, 0.80, 0.30), "rotation_deg": (-4.0, 7.0, -9.0)},
        {"location": (-0.54, 0.18, 0.90), "scale": (0.96, 0.64, 1.04), "rotation_deg": (7.0, -5.0, 9.0)},
        {"location": (0.34, 0.16, 1.08), "scale": (0.90, 0.58, 1.18), "rotation_deg": (5.0, 5.0, -8.0)},
        {"location": (1.00, 0.04, 0.82), "scale": (0.54, 0.56, 0.82), "rotation_deg": (7.0, -2.0, -12.0)},
        {"location": (-0.10, 0.42, 1.44), "scale": (1.56, 0.32, 0.42), "rotation_deg": (7.0, 0.0, 2.0)},
        {"location": (-0.62, -0.58, 0.46), "scale": (1.10, 0.18, 0.18), "rotation_deg": (0.0, 0.0, 7.0)},
        {"location": (0.66, -0.56, 0.38), "scale": (0.88, 0.16, 0.16), "rotation_deg": (0.0, 0.0, -5.0)},
    ],
    "boulders": [
        {"location": (-0.76, 0.14, 1.34), "radius": 0.25, "scale": (1.25, 0.70, 0.95)},
        {"location": (0.20, 0.28, 1.52), "radius": 0.27, "scale": (1.18, 0.68, 0.90)},
        {"location": (0.82, 0.14, 1.18), "radius": 0.22, "scale": (1.14, 0.72, 0.92)},
    ],
    "finish": {
        "voxel_size": 0.066,
        "displace_strength": 0.058,
        "noise_scale": 1.08,
        "noise_depth": 2,
        "smooth_factor": 0.14,
        "smooth_iterations": 2,
        "decimate_ratio": 0.950,
        "bevel_width": 0.018,
    },
}

INNER_WALL_BLOCKER_A_RECIPE = {
    "material": {"base_color": STONE_FAMILY_MID, "roughness": 0.93, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, 0.00, 0.10), "scale": (1.10, 0.86, 0.18), "rotation_deg": (0.0, 0.0, -3.0)},
        {"location": (-0.48, 0.08, 0.42), "scale": (0.58, 0.58, 0.60), "rotation_deg": (3.0, -4.0, 12.0)},
        {"location": (0.02, -0.02, 0.56), "scale": (0.74, 0.62, 0.76), "rotation_deg": (2.0, 5.0, -7.0)},
        {"location": (0.52, -0.06, 0.44), "scale": (0.54, 0.58, 0.62), "rotation_deg": (2.0, 5.0, -12.0)},
        {"location": (-0.08, 0.34, 0.26), "scale": (0.92, 0.18, 0.18), "rotation_deg": (0.0, 0.0, 5.0)},
        {"location": (0.10, -0.38, 0.24), "scale": (0.74, 0.16, 0.16), "rotation_deg": (0.0, 0.0, -4.0)},
    ],
    "boulders": [
        {"location": (-0.18, 0.10, 0.88), "radius": 0.18, "scale": (1.16, 0.76, 0.92)},
        {"location": (0.34, -0.02, 0.78), "radius": 0.15, "scale": (1.12, 0.74, 0.94)},
    ],
    "finish": {
        "voxel_size": 0.060,
        "displace_strength": 0.044,
        "noise_scale": 1.05,
        "noise_depth": 2,
        "smooth_factor": 0.14,
        "smooth_iterations": 3,
        "decimate_ratio": 0.958,
        "bevel_width": 0.018,
    },
}

INNER_WALL_BLOCKER_B_RECIPE = {
    "material": {"base_color": STONE_FAMILY_MID, "roughness": 0.94, "metallic": 0.0},
    "chunks": [
        {"location": (-0.02, 0.00, 0.10), "scale": (1.16, 0.94, 0.18), "rotation_deg": (0.0, 0.0, 2.0)},
        {"location": (-0.42, -0.08, 0.44), "scale": (0.64, 0.58, 0.64), "rotation_deg": (4.0, -6.0, 9.0)},
        {"location": (0.18, 0.06, 0.58), "scale": (0.80, 0.58, 0.78), "rotation_deg": (5.0, 4.0, -8.0)},
        {"location": (0.54, 0.02, 0.38), "scale": (0.48, 0.54, 0.50), "rotation_deg": (3.0, 3.0, -13.0)},
        {"location": (-0.10, 0.38, 0.24), "scale": (0.88, 0.16, 0.15), "rotation_deg": (0.0, 0.0, 2.0)},
        {"location": (0.16, -0.40, 0.24), "scale": (0.82, 0.16, 0.14), "rotation_deg": (0.0, 0.0, -7.0)},
    ],
    "boulders": [
        {"location": (-0.32, -0.08, 0.84), "radius": 0.17, "scale": (1.18, 0.72, 0.88)},
        {"location": (0.30, 0.08, 0.88), "radius": 0.18, "scale": (1.08, 0.76, 0.98)},
    ],
    "finish": {
        "voxel_size": 0.058,
        "displace_strength": 0.046,
        "noise_scale": 0.98,
        "noise_depth": 2,
        "smooth_factor": 0.13,
        "smooth_iterations": 2,
        "decimate_ratio": 0.956,
        "bevel_width": 0.018,
    },
}

FLOOR_TILE_ROCK_A_RECIPE = {
    "material": {"base_color": STONE_FAMILY_MID, "roughness": 0.95, "metallic": 0.0},
    "floor_mesh": {"seed": 17, "size": 1.12, "thickness": 0.070, "subdivisions": 30, "groove_bias": 0.00},
    "finish": {
        "voxel_size": 0.020,
        "displace_strength": 0.004,
        "noise_scale": 1.70,
        "noise_depth": 1,
        "smooth_factor": 0.04,
        "smooth_iterations": 1,
        "decimate_ratio": 0.985,
        "bevel_width": 0.006,
    },
}

FLOOR_TILE_ROCK_B_RECIPE = {
    "material": {"base_color": STONE_FAMILY_COOL, "roughness": 0.95, "metallic": 0.0},
    "floor_mesh": {"seed": 31, "size": 1.12, "thickness": 0.070, "subdivisions": 30, "groove_bias": 0.17},
    "finish": {
        "voxel_size": 0.020,
        "displace_strength": 0.004,
        "noise_scale": 1.65,
        "noise_depth": 1,
        "smooth_factor": 0.04,
        "smooth_iterations": 1,
        "decimate_ratio": 0.985,
        "bevel_width": 0.006,
    },
}

FLOOR_TILE_ROCK_C_RECIPE = {
    "material": {"base_color": STONE_FAMILY_MID, "roughness": 0.96, "metallic": 0.0},
    "floor_mesh": {"seed": 47, "size": 1.12, "thickness": 0.070, "subdivisions": 30, "groove_bias": -0.14},
    "finish": {
        "voxel_size": 0.020,
        "displace_strength": 0.004,
        "noise_scale": 1.75,
        "noise_depth": 1,
        "smooth_factor": 0.04,
        "smooth_iterations": 1,
        "decimate_ratio": 0.985,
        "bevel_width": 0.006,
    },
}

CAVE_CORNER_TRANSITION_A_RECIPE = {
    "material": {"base_color": STONE_FAMILY_DARK, "roughness": 0.94, "metallic": 0.0},
    "chunks": [
        {"location": (-0.16, -0.16, 0.10), "scale": (1.12, 1.10, 0.18), "rotation_deg": (0.0, 0.0, -14.0)},
        {"location": (-0.76, 0.16, 0.30), "scale": (0.74, 0.84, 0.26), "rotation_deg": (2.0, -2.0, 10.0)},
        {"location": (0.18, -0.76, 0.30), "scale": (0.82, 0.70, 0.26), "rotation_deg": (2.0, 3.0, -16.0)},
        {"location": (-0.70, 0.30, 0.82), "scale": (0.70, 0.66, 0.92), "rotation_deg": (4.0, -4.0, 12.0)},
        {"location": (-0.04, 0.22, 1.00), "scale": (0.84, 0.60, 1.06), "rotation_deg": (4.0, 4.0, -6.0)},
        {"location": (0.34, -0.48, 0.88), "scale": (0.66, 0.68, 0.96), "rotation_deg": (4.0, 3.0, -14.0)},
        {"location": (0.42, -1.02, 0.70), "scale": (0.54, 0.70, 0.76), "rotation_deg": (4.0, -3.0, -18.0)},
        {"location": (-0.46, -0.46, 0.38), "scale": (0.22, 1.18, 0.18), "rotation_deg": (0.0, 0.0, 42.0)},
    ],
    "boulders": [
        {"location": (-0.36, 0.24, 1.34), "radius": 0.24, "scale": (1.12, 0.72, 0.92)},
        {"location": (0.48, -0.50, 1.10), "radius": 0.22, "scale": (1.06, 0.74, 1.02)},
    ],
    "finish": {
        "voxel_size": 0.068,
        "displace_strength": 0.050,
        "noise_scale": 1.16,
        "noise_depth": 2,
        "smooth_factor": 0.15,
        "smooth_iterations": 3,
        "decimate_ratio": 0.956,
        "bevel_width": 0.020,
    },
}

CAVE_CORNER_TRANSITION_B_RECIPE = {
    "material": {"base_color": STONE_FAMILY_DARK, "roughness": 0.95, "metallic": 0.0},
    "chunks": [
        {"location": (-0.18, -0.18, 0.10), "scale": (1.22, 1.16, 0.18), "rotation_deg": (0.0, 0.0, -8.0)},
        {"location": (-0.86, 0.08, 0.30), "scale": (0.82, 0.92, 0.28), "rotation_deg": (3.0, -3.0, 7.0)},
        {"location": (0.10, -0.86, 0.30), "scale": (0.90, 0.76, 0.28), "rotation_deg": (3.0, 3.0, -10.0)},
        {"location": (-0.72, 0.24, 0.86), "scale": (0.78, 0.64, 0.98), "rotation_deg": (6.0, -5.0, 10.0)},
        {"location": (0.00, 0.20, 1.04), "scale": (0.92, 0.56, 1.08), "rotation_deg": (5.0, 4.0, -5.0)},
        {"location": (0.38, -0.52, 0.88), "scale": (0.72, 0.64, 0.94), "rotation_deg": (5.0, 3.0, -12.0)},
        {"location": (-0.42, -0.44, 0.34), "scale": (0.28, 1.26, 0.17), "rotation_deg": (0.0, 0.0, 38.0)},
        {"location": (0.46, -1.04, 0.52), "scale": (0.58, 0.62, 0.58), "rotation_deg": (4.0, -3.0, -16.0)},
    ],
    "boulders": [
        {"location": (-0.40, 0.18, 1.34), "radius": 0.25, "scale": (1.08, 0.70, 0.92)},
        {"location": (0.46, -0.48, 1.10), "radius": 0.22, "scale": (1.08, 0.72, 0.98)},
    ],
    "finish": {
        "voxel_size": 0.066,
        "displace_strength": 0.052,
        "noise_scale": 1.08,
        "noise_depth": 2,
        "smooth_factor": 0.14,
        "smooth_iterations": 2,
        "decimate_ratio": 0.954,
        "bevel_width": 0.018,
    },
}

DUNGEON_STONE_DARK = (0.22, 0.20, 0.18, 1.0)
DUNGEON_STONE_MID = (0.32, 0.30, 0.27, 1.0)
DUNGEON_STONE_COOL = (0.28, 0.29, 0.29, 1.0)

FLOOR_TILE_COBBLED_A_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.94, "metallic": 0.0},
    "floor_mesh": {"seed": 101, "size": 1.04, "thickness": 0.060, "subdivisions": 26, "groove_bias": 0.00},
    "finish": {"voxel_size": 0.018, "displace_strength": 0.003, "noise_scale": 1.60, "noise_depth": 1, "smooth_factor": 0.03, "smooth_iterations": 1, "decimate_ratio": 0.990, "bevel_width": 0.005},
}

FLOOR_TILE_COBBLED_B_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_COOL, "roughness": 0.95, "metallic": 0.0},
    "floor_mesh": {"seed": 127, "size": 1.04, "thickness": 0.060, "subdivisions": 26, "groove_bias": 0.22},
    "finish": {"voxel_size": 0.018, "displace_strength": 0.003, "noise_scale": 1.55, "noise_depth": 1, "smooth_factor": 0.03, "smooth_iterations": 1, "decimate_ratio": 0.990, "bevel_width": 0.005},
}

FLOOR_TILE_COBBLED_C_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.96, "metallic": 0.0},
    "floor_mesh": {"seed": 149, "size": 1.04, "thickness": 0.058, "subdivisions": 26, "groove_bias": -0.18},
    "finish": {"voxel_size": 0.018, "displace_strength": 0.003, "noise_scale": 1.70, "noise_depth": 1, "smooth_factor": 0.03, "smooth_iterations": 1, "decimate_ratio": 0.990, "bevel_width": 0.005},
}

OUTER_WALL_STONE_A_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_DARK, "roughness": 0.92, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, -0.02, 0.12), "scale": (2.10, 0.56, 0.22), "rotation_deg": (0.0, 0.0, 0.0)},
        {"location": (-0.72, -0.02, 0.46), "scale": (0.66, 0.50, 0.26), "rotation_deg": (0.0, 0.0, 1.0)},
        {"location": (0.00, -0.03, 0.46), "scale": (0.70, 0.50, 0.26), "rotation_deg": (0.0, 0.0, -1.0)},
        {"location": (0.74, -0.02, 0.46), "scale": (0.64, 0.50, 0.26), "rotation_deg": (0.0, 0.0, 1.5)},
        {"location": (-0.38, -0.04, 0.82), "scale": (0.86, 0.52, 0.28), "rotation_deg": (0.0, 0.0, -1.5)},
        {"location": (0.48, -0.03, 0.82), "scale": (0.82, 0.52, 0.28), "rotation_deg": (0.0, 0.0, 1.0)},
        {"location": (-0.78, -0.04, 1.18), "scale": (0.62, 0.50, 0.28), "rotation_deg": (0.0, 0.0, 2.0)},
        {"location": (0.00, -0.04, 1.18), "scale": (0.70, 0.50, 0.28), "rotation_deg": (0.0, 0.0, -1.0)},
        {"location": (0.76, -0.04, 1.18), "scale": (0.62, 0.50, 0.28), "rotation_deg": (0.0, 0.0, -2.0)},
        {"location": (0.00, -0.06, 1.52), "scale": (1.92, 0.54, 0.20), "rotation_deg": (0.0, 0.0, 0.0)},
    ],
    "finish": {"voxel_size": 0.032, "displace_strength": 0.018, "noise_scale": 1.10, "noise_depth": 1, "smooth_factor": 0.04, "smooth_iterations": 1, "decimate_ratio": 0.976, "bevel_width": 0.014},
}

OUTER_WALL_STONE_B_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_DARK, "roughness": 0.93, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, -0.02, 0.12), "scale": (2.04, 0.58, 0.22), "rotation_deg": (0.0, 0.0, 0.0)},
        {"location": (-0.94, -0.02, 0.48), "scale": (0.42, 0.50, 0.27), "rotation_deg": (0.0, 0.0, 2.0)},
        {"location": (-0.34, -0.03, 0.48), "scale": (0.72, 0.50, 0.27), "rotation_deg": (0.0, 0.0, -1.0)},
        {"location": (0.42, -0.02, 0.48), "scale": (0.66, 0.50, 0.27), "rotation_deg": (0.0, 0.0, 1.0)},
        {"location": (0.98, -0.02, 0.48), "scale": (0.34, 0.50, 0.22), "rotation_deg": (0.0, 0.0, -4.0)},
        {"location": (-0.62, -0.04, 0.86), "scale": (0.70, 0.52, 0.28), "rotation_deg": (0.0, 0.0, 1.0)},
        {"location": (0.18, -0.04, 0.86), "scale": (0.78, 0.52, 0.28), "rotation_deg": (0.0, 0.0, -2.0)},
        {"location": (0.86, -0.06, 0.82), "scale": (0.36, 0.50, 0.22), "rotation_deg": (0.0, 0.0, 6.0)},
        {"location": (-0.28, -0.04, 1.20), "scale": (0.82, 0.50, 0.28), "rotation_deg": (0.0, 0.0, 1.5)},
        {"location": (0.62, -0.04, 1.20), "scale": (0.72, 0.50, 0.28), "rotation_deg": (0.0, 0.0, -1.5)},
        {"location": (0.00, -0.06, 1.52), "scale": (1.78, 0.54, 0.20), "rotation_deg": (0.0, 0.0, -1.0)},
    ],
    "finish": {"voxel_size": 0.032, "displace_strength": 0.018, "noise_scale": 1.08, "noise_depth": 1, "smooth_factor": 0.04, "smooth_iterations": 1, "decimate_ratio": 0.976, "bevel_width": 0.014},
}

INNER_WALL_STONE_A_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.93, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, 0.00, 0.10), "scale": (1.02, 0.76, 0.18), "rotation_deg": (0.0, 0.0, 0.0)},
        {"location": (-0.36, 0.00, 0.40), "scale": (0.50, 0.60, 0.24), "rotation_deg": (0.0, 0.0, 1.5)},
        {"location": (0.22, 0.00, 0.40), "scale": (0.58, 0.60, 0.24), "rotation_deg": (0.0, 0.0, -1.0)},
        {"location": (-0.10, 0.00, 0.72), "scale": (0.68, 0.58, 0.24), "rotation_deg": (0.0, 0.0, 1.0)},
        {"location": (0.52, 0.00, 0.68), "scale": (0.26, 0.56, 0.20), "rotation_deg": (0.0, 0.0, -7.0)},
    ],
    "finish": {"voxel_size": 0.030, "displace_strength": 0.014, "noise_scale": 1.00, "noise_depth": 1, "smooth_factor": 0.035, "smooth_iterations": 1, "decimate_ratio": 0.976, "bevel_width": 0.012},
}

INNER_WALL_STONE_B_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.94, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, 0.00, 0.10), "scale": (1.08, 0.78, 0.18), "rotation_deg": (0.0, 0.0, -1.0)},
        {"location": (-0.42, 0.02, 0.38), "scale": (0.42, 0.58, 0.22), "rotation_deg": (0.0, 0.0, 3.0)},
        {"location": (0.05, -0.01, 0.42), "scale": (0.46, 0.58, 0.26), "rotation_deg": (0.0, 0.0, -2.0)},
        {"location": (0.46, 0.00, 0.36), "scale": (0.36, 0.56, 0.20), "rotation_deg": (0.0, 0.0, -8.0)},
        {"location": (-0.08, 0.00, 0.70), "scale": (0.54, 0.54, 0.20), "rotation_deg": (0.0, 0.0, 2.0)},
    ],
    "finish": {"voxel_size": 0.030, "displace_strength": 0.014, "noise_scale": 1.04, "noise_depth": 1, "smooth_factor": 0.035, "smooth_iterations": 1, "decimate_ratio": 0.976, "bevel_width": 0.012},
}

RUBBLE_BLOCKER_A_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.95, "metallic": 0.0},
    "chunks": [
        {"location": (-0.28, 0.10, 0.14), "scale": (0.48, 0.34, 0.16), "rotation_deg": (0.0, 0.0, 12.0)},
        {"location": (0.20, -0.08, 0.16), "scale": (0.54, 0.36, 0.18), "rotation_deg": (0.0, 0.0, -10.0)},
        {"location": (-0.02, 0.02, 0.38), "scale": (0.34, 0.30, 0.28), "rotation_deg": (5.0, -6.0, 18.0)},
        {"location": (0.40, 0.14, 0.34), "scale": (0.24, 0.26, 0.22), "rotation_deg": (8.0, 6.0, -20.0)},
        {"location": (-0.46, -0.14, 0.32), "scale": (0.24, 0.24, 0.20), "rotation_deg": (7.0, -4.0, 22.0)},
    ],
    "finish": {"voxel_size": 0.026, "displace_strength": 0.016, "noise_scale": 0.86, "noise_depth": 1, "smooth_factor": 0.025, "smooth_iterations": 1, "decimate_ratio": 0.970, "bevel_width": 0.010},
}

RUBBLE_BLOCKER_B_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.95, "metallic": 0.0},
    "chunks": [
        {"location": (-0.34, 0.00, 0.14), "scale": (0.42, 0.38, 0.16), "rotation_deg": (0.0, 0.0, -8.0)},
        {"location": (0.18, 0.02, 0.18), "scale": (0.56, 0.34, 0.18), "rotation_deg": (0.0, 0.0, 9.0)},
        {"location": (0.04, -0.08, 0.42), "scale": (0.44, 0.26, 0.26), "rotation_deg": (8.0, 0.0, -11.0)},
        {"location": (-0.46, 0.12, 0.34), "scale": (0.22, 0.24, 0.22), "rotation_deg": (3.0, -5.0, 18.0)},
        {"location": (0.48, -0.12, 0.32), "scale": (0.22, 0.22, 0.20), "rotation_deg": (5.0, 6.0, -16.0)},
    ],
    "finish": {"voxel_size": 0.026, "displace_strength": 0.016, "noise_scale": 0.90, "noise_depth": 1, "smooth_factor": 0.025, "smooth_iterations": 1, "decimate_ratio": 0.970, "bevel_width": 0.010},
}

PILLAR_RUIN_A_RECIPE = {
    "material": {"base_color": DUNGEON_STONE_MID, "roughness": 0.93, "metallic": 0.0},
    "chunks": [
        {"location": (0.00, 0.00, 0.10), "scale": (0.68, 0.68, 0.18), "rotation_deg": (0.0, 0.0, 0.0)},
        {"location": (0.00, 0.00, 0.48), "scale": (0.36, 0.36, 0.44), "rotation_deg": (0.0, 0.0, 4.0)},
        {"location": (0.02, -0.02, 0.90), "scale": (0.32, 0.34, 0.34), "rotation_deg": (4.0, -2.0, -7.0)},
        {"location": (-0.18, 0.24, 0.24), "scale": (0.22, 0.22, 0.14), "rotation_deg": (0.0, 0.0, 18.0)},
        {"location": (0.28, -0.22, 0.20), "scale": (0.24, 0.20, 0.12), "rotation_deg": (0.0, 0.0, -18.0)},
    ],
    "finish": {"voxel_size": 0.028, "displace_strength": 0.012, "noise_scale": 0.96, "noise_depth": 1, "smooth_factor": 0.025, "smooth_iterations": 1, "decimate_ratio": 0.976, "bevel_width": 0.012},
}

DOOR_ARCH_DUNGEON_RECIPE = {
    "material": {"base_color": (0.20, 0.17, 0.13, 1.0), "roughness": 0.86, "metallic": 0.02},
    "chunks": [
        {"location": (-0.82, 0.00, 0.74), "scale": (0.28, 0.42, 0.74), "rotation_deg": (0.0, 0.0, 1.5)},
        {"location": (0.82, 0.00, 0.74), "scale": (0.28, 0.42, 0.74), "rotation_deg": (0.0, 0.0, -1.5)},
        {"location": (0.00, 0.00, 1.48), "scale": (1.20, 0.44, 0.24), "rotation_deg": (0.0, 0.0, 0.0)},
        {"location": (-0.46, 0.02, 1.30), "scale": (0.42, 0.40, 0.22), "rotation_deg": (0.0, 0.0, 10.0)},
        {"location": (0.46, 0.02, 1.30), "scale": (0.42, 0.40, 0.22), "rotation_deg": (0.0, 0.0, -10.0)},
        {"location": (0.00, -0.20, 0.64), "scale": (0.98, 0.16, 0.58), "rotation_deg": (0.0, 0.0, 0.0)},
    ],
    "finish": {"voxel_size": 0.030, "displace_strength": 0.012, "noise_scale": 0.92, "noise_depth": 1, "smooth_factor": 0.025, "smooth_iterations": 1, "decimate_ratio": 0.976, "bevel_width": 0.012},
}

OOZE_MATERIAL = {
    "base_color": (0.22, 0.46, 0.18, 1.0),
    "roughness": 0.30,
    "metallic": 0.0,
    "specular": 0.66,
    "clearcoat": 0.34,
    "subsurface": 0.06,
    "emission": (0.05, 0.12, 0.04, 1.0),
}

OOZE_FINISH = {
    "voxel_size": 0.020,
    "displace_strength": 0.002,
    "noise_scale": 0.52,
    "noise_depth": 1,
    "smooth_factor": 0.18,
    "smooth_iterations": 3,
    "subdiv_levels": 0,
    "decimate_ratio": 0.996,
}

CORE_GROWTH_RECIPE = {
    "role_note": "largest objective mass: oversized central organ, readable crown, and heavy root lobes",
    "material": OOZE_MATERIAL,
    "base": {"radius": 0.98, "height": 0.082, "rings": 8, "segments": 96, "edge_amp": 0.030, "seed": 11},
    "metaballs": [
        {"location": (0.00, 0.00, 0.38), "radius": 0.56},
        {"location": (0.00, 0.02, 0.82), "radius": 0.48},
        {"location": (-0.08, 0.00, 1.20), "radius": 0.34},
        {"location": (0.26, -0.14, 0.82), "radius": 0.30},
        {"location": (-0.34, 0.20, 0.72), "radius": 0.30},
        {"location": (-0.54, -0.34, 0.26), "radius": 0.27},
        {"location": (0.56, 0.30, 0.25), "radius": 0.26},
        {"location": (0.02, -0.66, 0.20), "radius": 0.25},
        {"location": (-0.68, 0.42, 0.13), "radius": 0.18},
        {"location": (0.76, -0.28, 0.13), "radius": 0.17},
    ],
    "tubes": [
        {"radius": 0.130, "points": [(-0.18, -0.06, 0.15), (-0.56, -0.42, 0.13), (-0.94, -0.60, 0.07)]},
        {"radius": 0.120, "points": [(0.18, 0.04, 0.15), (0.60, 0.36, 0.13), (0.94, 0.58, 0.07)]},
        {"radius": 0.104, "points": [(-0.12, 0.14, 0.17), (-0.44, 0.66, 0.20), (-0.58, 0.94, 0.16)]},
        {"radius": 0.098, "points": [(0.16, -0.12, 0.18), (0.56, -0.62, 0.22), (0.80, -0.94, 0.16)]},
    ],
    "metaball_settings": {"resolution": 0.048, "render_resolution": 0.024, "threshold": 0.62},
    "finish": {**OOZE_FINISH, "voxel_size": 0.018, "smooth_factor": 0.12, "smooth_iterations": 2},
}

BASIC_TILE_RECIPE = {
    "role_note": "almost flat readable puddle: no large vertical features, no busy noise",
    "material": OOZE_MATERIAL,
    "base": {"radius": 0.72, "height": 0.026, "rings": 5, "segments": 72, "edge_amp": 0.012, "seed": 23},
    "metaballs": [
        {"location": (-0.24, 0.10, 0.040), "radius": 0.026},
        {"location": (0.24, -0.14, 0.038), "radius": 0.022},
    ],
    "tubes": [
        {"radius": 0.007, "points": [(-0.34, -0.02, 0.032), (-0.10, 0.02, 0.034), (0.12, 0.00, 0.032)]},
    ],
    "metaball_settings": {"resolution": 0.080, "render_resolution": 0.048, "threshold": 0.72},
    "finish": {**OOZE_FINISH, "voxel_size": 0.028, "displace_strength": 0.0005, "smooth_factor": 0.08, "smooth_iterations": 1},
}

MELEE_GROWTH_RECIPE = {
    "role_note": "directional claw/tendril tile: long lateral grabbing arms readable from gameplay camera",
    "material": OOZE_MATERIAL,
    "base": {
        "radius": 0.66,
        "height": 0.060,
        "rings": 6,
        "segments": 96,
        "edge_amp": 0.010,
        "seed": 37,
        "lobes": [
            {"angle_deg": 90.0, "width_deg": 30.0, "amount": 0.92, "power": 1.35},
            {"angle_deg": 48.0, "width_deg": 26.0, "amount": 0.54, "power": 1.45},
            {"angle_deg": 132.0, "width_deg": 26.0, "amount": 0.54, "power": 1.45},
        ],
    },
    "metaballs": [],
    "tubes": [],
    "metaball_settings": {"resolution": 0.050, "render_resolution": 0.026, "threshold": 0.60},
    "finish": {**OOZE_FINISH, "voxel_size": 0.024, "displace_strength": 0.0008, "smooth_factor": 0.08, "smooth_iterations": 1},
}

RANGED_GROWTH_RECIPE = {
    "role_note": "tall spitter: single vertical stalk with one unmistakable bulb/nozzle",
    "material": OOZE_MATERIAL,
    "base": {"radius": 0.64, "height": 0.052, "rings": 7, "segments": 88, "edge_amp": 0.026, "seed": 41},
    "metaballs": [
        {"location": (0.00, 0.00, 0.20), "radius": 0.13},
        {"location": (0.01, 0.02, 0.50), "radius": 0.12},
        {"location": (0.03, 0.03, 0.82), "radius": 0.11},
        {"location": (0.05, 0.04, 1.20), "radius": 0.10},
        {"location": (0.08, 0.06, 1.64), "radius": 0.32},
        {"location": (0.24, 0.14, 1.66), "radius": 0.22},
        {"location": (0.52, 0.32, 1.64), "radius": 0.085},
    ],
    "tubes": [
        {"radius": 0.062, "points": [(0.00, 0.00, 0.09), (0.01, 0.03, 0.56), (0.04, 0.05, 1.02), (0.08, 0.06, 1.44)]},
        {"radius": 0.056, "points": [(0.24, 0.15, 1.64), (0.44, 0.30, 1.64), (0.64, 0.46, 1.58)]},
        {"radius": 0.022, "points": [(-0.36, 0.04, 0.06), (-0.46, 0.22, 0.16), (-0.44, 0.38, 0.20)]},
        {"radius": 0.020, "points": [(0.34, -0.08, 0.06), (0.46, 0.08, 0.14), (0.50, 0.24, 0.18)]},
    ],
    "metaball_settings": {"resolution": 0.052, "render_resolution": 0.028, "threshold": 0.69},
    "finish": {**OOZE_FINISH, "voxel_size": 0.018, "smooth_factor": 0.14, "smooth_iterations": 2},
}

DEFENSE_GROWTH_RECIPE = {
    "role_note": "low armored shell: squat wide shield plates, never tall",
    "material": OOZE_MATERIAL,
    "base": {
        "radius": 0.88,
        "height": 0.050,
        "rings": 7,
        "segments": 96,
        "edge_amp": 0.016,
        "seed": 53,
        "lobes": [
            {"angle_deg": 180.0, "width_deg": 40.0, "amount": 0.26, "power": 1.8},
            {"angle_deg": 0.0, "width_deg": 40.0, "amount": 0.26, "power": 1.8},
        ],
    },
    "metaballs": [
        {"location": (0.00, -0.08, 0.12), "radius": 0.42},
        {"location": (-0.42, -0.02, 0.10), "radius": 0.30},
        {"location": (0.42, -0.02, 0.10), "radius": 0.30},
        {"location": (0.00, 0.30, 0.09), "radius": 0.28},
    ],
    "tubes": [
        {"radius": 0.170, "points": [(-0.94, -0.40, 0.14), (-0.42, -0.58, 0.22), (0.42, -0.56, 0.22), (0.96, -0.38, 0.14)]},
        {"radius": 0.150, "points": [(-1.02, -0.04, 0.14), (-0.48, -0.14, 0.30), (0.48, -0.12, 0.30), (1.02, -0.02, 0.14)]},
        {"radius": 0.128, "points": [(-0.88, 0.32, 0.13), (-0.32, 0.18, 0.28), (0.38, 0.22, 0.26), (0.90, 0.40, 0.13)]},
        {"radius": 0.090, "points": [(-0.74, 0.64, 0.10), (-0.20, 0.50, 0.18), (0.28, 0.54, 0.17), (0.76, 0.70, 0.10)]},
    ],
    "metaball_settings": {"resolution": 0.064, "render_resolution": 0.034, "threshold": 0.36},
    "finish": {**OOZE_FINISH, "voxel_size": 0.020, "displace_strength": 0.001, "smooth_factor": 0.12, "smooth_iterations": 2},
}

GATHER_GROWTH_RECIPE = {
    "role_note": "resource collector: compact bouquet of rounded pods, clearly clustered",
    "material": OOZE_MATERIAL,
    "base": {"radius": 0.70, "height": 0.052, "rings": 7, "segments": 84, "edge_amp": 0.018, "seed": 67},
    "metaballs": [
        {"location": (0.00, 0.00, 0.26), "radius": 0.26},
        {"location": (-0.26, -0.16, 0.38), "radius": 0.20},
        {"location": (0.28, -0.14, 0.36), "radius": 0.19},
        {"location": (-0.14, 0.24, 0.48), "radius": 0.18},
        {"location": (0.22, 0.22, 0.56), "radius": 0.16},
        {"location": (-0.38, 0.08, 0.28), "radius": 0.13},
        {"location": (0.40, 0.06, 0.30), "radius": 0.12},
        {"location": (-0.02, 0.38, 0.72), "radius": 0.11},
    ],
    "tubes": [
        {"radius": 0.036, "points": [(-0.28, -0.14, 0.10), (-0.30, -0.17, 0.26), (-0.30, -0.18, 0.36)]},
        {"radius": 0.034, "points": [(0.30, -0.08, 0.10), (0.32, -0.12, 0.24), (0.30, -0.14, 0.34)]},
        {"radius": 0.030, "points": [(-0.10, 0.24, 0.10), (-0.16, 0.28, 0.30), (-0.18, 0.28, 0.46)]},
        {"radius": 0.028, "points": [(0.20, 0.22, 0.10), (0.24, 0.28, 0.36), (0.24, 0.26, 0.54)]},
    ],
    "metaball_settings": {"resolution": 0.058, "render_resolution": 0.030, "threshold": 0.69},
    "finish": {**OOZE_FINISH, "voxel_size": 0.019, "smooth_factor": 0.14, "smooth_iterations": 2},
}


_MATERIAL_CACHE: dict[str, bpy.types.Material] = {}


def _make_material(
    name: str,
    base_color: tuple[float, float, float, float],
    roughness: float,
    metallic: float,
) -> bpy.types.Material:
    cached = _MATERIAL_CACHE.get(name)
    if cached is not None:
        return cached
    material = bpy.data.materials.new(name=name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.30
    _MATERIAL_CACHE[name] = material
    return material

def _make_ooze_material(name: str, material_recipe: dict) -> bpy.types.Material:
    cached = _MATERIAL_CACHE.get(name)
    if cached is not None:
        return cached
    material = bpy.data.materials.new(name=name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = tuple(material_recipe["base_color"])
        bsdf.inputs["Roughness"].default_value = float(material_recipe.get("roughness", 0.34))
        bsdf.inputs["Metallic"].default_value = float(material_recipe.get("metallic", 0.0))
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = float(material_recipe.get("specular", 0.56))
        if "Clearcoat" in bsdf.inputs:
            bsdf.inputs["Clearcoat"].default_value = float(material_recipe.get("clearcoat", 0.22))
        if "Clearcoat Roughness" in bsdf.inputs:
            bsdf.inputs["Clearcoat Roughness"].default_value = 0.26
        if "Subsurface Weight" in bsdf.inputs:
            bsdf.inputs["Subsurface Weight"].default_value = float(material_recipe.get("subsurface", 0.05))
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = tuple(material_recipe.get("emission", (0.05, 0.12, 0.05, 1.0)))
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 0.22
    _MATERIAL_CACHE[name] = material
    return material


def _assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    if obj.type != "MESH" or obj.data is None:
        return
    if len(obj.data.materials) == 0:
        obj.data.materials.append(material)
    else:
        obj.data.materials[0] = material


def reset_scene() -> None:
    _MATERIAL_CACHE.clear()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.textures):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)


def _deselect_all() -> None:
    bpy.ops.object.select_all(action="DESELECT")


def _activate(obj: bpy.types.Object) -> None:
    _deselect_all()
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _apply_modifier(obj: bpy.types.Object, modifier_name: str) -> None:
    _activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier_name)


def _join_objects(name: str, objects: Iterable[bpy.types.Object]) -> bpy.types.Object:
    parts = list(objects)
    if not parts:
        raise RuntimeError(f"No objects to join for {name}")
    if len(parts) == 1:
        parts[0].name = name
        return parts[0]
    _deselect_all()
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def _set_smooth(obj: bpy.types.Object) -> None:
    if obj.type != "MESH" or obj.data is None:
        return
    for poly in obj.data.polygons:
        poly.use_smooth = True


def _center_mesh_to_ground(obj: bpy.types.Object) -> None:
    if obj.type != "MESH" or obj.data is None:
        return
    mesh = obj.data
    if not mesh.vertices:
        return
    min_x = min(v.co.x for v in mesh.vertices)
    max_x = max(v.co.x for v in mesh.vertices)
    min_y = min(v.co.y for v in mesh.vertices)
    max_y = max(v.co.y for v in mesh.vertices)
    min_z = min(v.co.z for v in mesh.vertices)
    offset = Vector((-(min_x + max_x) * 0.5, -(min_y + max_y) * 0.5, -min_z))
    for vert in mesh.vertices:
        vert.co += offset
    mesh.update()


def _finalize_mesh(obj: bpy.types.Object, name: str) -> bpy.types.Object:
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    _center_mesh_to_ground(obj)
    _activate(obj)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    _set_smooth(obj)
    obj.name = name
    if obj.type == "MESH" and obj.data is not None:
        obj.data.name = f"{name}_mesh"
    return obj


def _export_glb(obj: bpy.types.Object, output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    _activate(obj)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
    )
    return output_path


def _create_cube(location: tuple[float, float, float], scale: tuple[float, float, float], rotation_deg: tuple[float, float, float]) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=location,
        rotation=tuple(radians(v) for v in rotation_deg),
    )
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def _create_boulder(location: tuple[float, float, float], radius: float, scale: tuple[float, float, float]) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.scale = scale
    return obj


def _floor_hash(seed: int, x: int, y: int) -> float:
    value = sin(float(seed) * 12.9898 + float(x) * 78.233 + float(y) * 37.719) * 43758.5453
    return value - int(value)


def _floor_noise(seed: int, x: float, y: float) -> float:
    ix = int(x)
    iy = int(y)
    fx = x - float(ix)
    fy = y - float(iy)
    a = _floor_hash(seed, ix, iy)
    b = _floor_hash(seed, ix + 1, iy)
    c = _floor_hash(seed, ix, iy + 1)
    d = _floor_hash(seed, ix + 1, iy + 1)
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    return (a * (1.0 - ux) + b * ux) * (1.0 - uy) + (c * (1.0 - ux) + d * ux) * uy


def _distance_to_line(px: float, py: float, angle: float, offset: float) -> float:
    return abs(cos(angle) * px + sin(angle) * py - offset)


def _create_floor_tile_mesh(asset_name: str, recipe: dict) -> bpy.types.Object:
    floor: dict = recipe["floor_mesh"]
    seed: int = int(floor.get("seed", 1))
    size: float = float(floor.get("size", 1.12))
    half: float = size * 0.5
    thickness: float = float(floor.get("thickness", 0.07))
    subdivisions: int = int(floor.get("subdivisions", 28))
    groove_bias: float = float(floor.get("groove_bias", 0.0))
    grooves: list[tuple[float, float, float]] = [
        (radians(24.0 + groove_bias * 18.0), -0.24, 0.014),
        (radians(-36.0 + groove_bias * 12.0), 0.08, 0.017),
        (radians(78.0 - groove_bias * 16.0), 0.26, 0.012),
        (radians(-4.0 + groove_bias * 10.0), -0.38, 0.010),
    ]

    verts: list[tuple[float, float, float]] = []
    normals: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    for y in range(subdivisions + 1):
        fy = float(y) / float(subdivisions)
        py = -half + fy * size
        for x in range(subdivisions + 1):
            fx = float(x) / float(subdivisions)
            px = -half + fx * size
            edge_t = min(fx, fy, 1.0 - fx, 1.0 - fy)
            center_t = 1.0 - min(1.0, sqrt(px * px + py * py) / max(0.001, half))
            broad = _floor_noise(seed, fx * 3.0 + 2.3, fy * 3.0 + 4.1) - 0.5
            fine = _floor_noise(seed + 41, fx * 8.0 + 1.2, fy * 8.0 + 0.7) - 0.5
            z = thickness + broad * 0.020 + fine * 0.004 + center_t * 0.008
            for angle, offset, depth in grooves:
                dist = _distance_to_line(px, py, angle, offset)
                groove_width = 0.024 + abs(groove_bias) * 0.004
                if dist < groove_width:
                    z -= depth * (1.0 - dist / groove_width)
            if edge_t < 0.10:
                z -= (0.10 - edge_t) * 0.045
            verts.append((px, py, max(0.010, z)))
            normals.append((0.0, 0.0, 1.0))
            uvs.append((fx, fy))

    bottom_start = len(verts)
    for y in range(subdivisions + 1):
        fy = float(y) / float(subdivisions)
        py = -half + fy * size
        for x in range(subdivisions + 1):
            fx = float(x) / float(subdivisions)
            px = -half + fx * size
            verts.append((px, py, 0.0))
            normals.append((0.0, 0.0, -1.0))
            uvs.append((fx, fy))

    faces: list[tuple[int, ...]] = []
    stride = subdivisions + 1
    for y in range(subdivisions):
        for x in range(subdivisions):
            i0 = y * stride + x
            i1 = i0 + 1
            i2 = i0 + stride
            i3 = i2 + 1
            faces.append((i0, i2, i3, i1))
            b0 = bottom_start + i0
            b1 = bottom_start + i1
            b2 = bottom_start + i2
            b3 = bottom_start + i3
            faces.append((b0, b1, b3, b2))

    for i in range(subdivisions):
        # South, north, west, east skirt faces.
        faces.append((i, i + 1, bottom_start + i + 1, bottom_start + i))
        top_a = subdivisions * stride + i
        faces.append((top_a + 1, top_a, bottom_start + top_a, bottom_start + top_a + 1))
        left_a = i * stride
        faces.append((left_a + stride, left_a, bottom_start + left_a, bottom_start + left_a + stride))
        right_a = i * stride + subdivisions
        faces.append((right_a, right_a + stride, bottom_start + right_a + stride, bottom_start + right_a))

    mesh = bpy.data.meshes.new(f"{asset_name}_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(asset_name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _ooze_edge_scale(angle: float, seed: int, amp: float) -> float:
    return 1.0 + amp * (
        0.55 * sin(angle * 5.0 + seed * 0.37)
        + 0.32 * sin(angle * 9.0 + seed * 0.71)
        + 0.18 * cos(angle * 13.0 + seed * 0.19)
    )


def _angle_delta(a: float, b: float) -> float:
    delta = (a - b + pi) % (pi * 2.0) - pi
    return abs(delta)


def _ooze_lobe_scale(angle: float, lobes: list[dict]) -> float:
    scale = 1.0
    for lobe in lobes:
        target = radians(float(lobe["angle_deg"]))
        width = max(0.05, radians(float(lobe.get("width_deg", 34.0))))
        amount = float(lobe.get("amount", 0.45))
        delta = _angle_delta(angle, target)
        if delta > width:
            continue
        t = 1.0 - (delta / width)
        scale += amount * (t ** float(lobe.get("power", 2.0)))
    return scale


def _create_ooze_puddle_mesh(asset_name: str, recipe: dict) -> bpy.types.Object:
    base: dict = recipe.get("base", {})
    radius: float = float(base.get("radius", 0.80))
    height: float = float(base.get("height", 0.08))
    rings: int = int(base.get("rings", 8))
    segments: int = int(base.get("segments", 96))
    edge_amp: float = float(base.get("edge_amp", 0.05))
    seed: int = int(base.get("seed", 1))
    lobes: list[dict] = list(base.get("lobes", []))

    verts: list[tuple[float, float, float]] = [(0.0, 0.0, height)]
    ring_indices: list[list[int]] = []
    edge_scales: list[float] = []
    for i in range(segments):
        angle = (float(i) / float(segments)) * pi * 2.0
        edge_scales.append(_ooze_edge_scale(angle, seed, edge_amp) * _ooze_lobe_scale(angle, lobes))

    for ring in range(1, rings + 1):
        t = float(ring) / float(rings)
        ring_row: list[int] = []
        for i in range(segments):
            angle = (float(i) / float(segments)) * pi * 2.0
            edge_scale = 1.0 + (edge_scales[i] - 1.0) * (t ** 1.8)
            radial = radius * t * edge_scale
            x = cos(angle) * radial
            y = sin(angle) * radial
            ripple = 0.009 * sin(angle * 7.0 + seed * 0.23) * (1.0 - t) + 0.006 * cos(angle * 11.0 + seed * 0.11) * t
            z = max(0.006, height * ((1.0 - t) ** 1.65) + ripple)
            ring_row.append(len(verts))
            verts.append((x, y, z))
        ring_indices.append(ring_row)

    bottom_center = len(verts)
    verts.append((0.0, 0.0, -0.018))
    bottom_edge: list[int] = []
    outer = ring_indices[-1]
    for i in range(segments):
        x, y, _z = verts[outer[i]]
        bottom_edge.append(len(verts))
        verts.append((x * 0.985, y * 0.985, -0.020))

    faces: list[tuple[int, ...]] = []
    first_ring = ring_indices[0]
    for i in range(segments):
        faces.append((0, first_ring[i], first_ring[(i + 1) % segments]))
    for r in range(len(ring_indices) - 1):
        inner = ring_indices[r]
        outer_ring = ring_indices[r + 1]
        for i in range(segments):
            faces.append((inner[i], outer_ring[i], outer_ring[(i + 1) % segments], inner[(i + 1) % segments]))
    for i in range(segments):
        faces.append((outer[i], bottom_edge[i], bottom_edge[(i + 1) % segments], outer[(i + 1) % segments]))
        faces.append((bottom_center, bottom_edge[(i + 1) % segments], bottom_edge[i]))

    mesh = bpy.data.meshes.new(f"{asset_name}_puddle_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(f"{asset_name}_puddle", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def _create_tube_curve(name: str, points: list[tuple[float, float, float]], radius: float) -> bpy.types.Object:
    curve = bpy.data.curves.new(name=name, type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 16
    curve.bevel_depth = radius
    curve.bevel_resolution = 5
    curve.twist_smooth = 8
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for idx, point in enumerate(points):
        bp = spline.bezier_points[idx]
        bp.co = Vector(point)
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return obj


def _convert_to_mesh(obj: bpy.types.Object) -> bpy.types.Object:
    _activate(obj)
    bpy.ops.object.convert(target="MESH")
    converted = bpy.context.active_object
    _set_smooth(converted)
    return converted

def _create_ooze_metaball_mesh(asset_name: str, recipe: dict) -> bpy.types.Object:
    if not recipe.get("metaballs", []):
        raise RuntimeError(f"No metaballs configured for {asset_name}")
    mb_data = bpy.data.metaballs.new(name=f"{asset_name}_mb")
    settings: dict = recipe.get("metaball_settings", {})
    mb_data.resolution = float(settings.get("resolution", 0.075))
    mb_data.render_resolution = float(settings.get("render_resolution", 0.040))
    if hasattr(mb_data, "threshold"):
        mb_data.threshold = float(settings.get("threshold", 0.64))
    mb_obj = bpy.data.objects.new(f"{asset_name}_mb_obj", mb_data)
    bpy.context.collection.objects.link(mb_obj)
    for blob in recipe["metaballs"]:
        element = mb_data.elements.new(type="BALL")
        element.co = Vector(tuple(blob["location"]))
        element.radius = float(blob["radius"])
        if "stiffness" in blob:
            element.stiffness = float(blob["stiffness"])
    return _convert_to_mesh(mb_obj)


def _apply_rock_finish(obj: bpy.types.Object, name: str, finish: dict) -> None:
    remesh = obj.modifiers.new(name="Remesh", type="REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = float(finish["voxel_size"])
    remesh.use_smooth_shade = True
    _apply_modifier(obj, remesh.name)

    texture = bpy.data.textures.new(name=f"{name}_noise", type="CLOUDS")
    texture.noise_scale = float(finish["noise_scale"])
    texture.noise_depth = int(finish["noise_depth"])

    displace = obj.modifiers.new(name="Displace", type="DISPLACE")
    displace.texture = texture
    displace.strength = float(finish["displace_strength"])
    displace.mid_level = 0.5
    _apply_modifier(obj, displace.name)

    smooth_factor: float = float(finish.get("smooth_factor", 0.0))
    smooth_iterations: int = int(finish.get("smooth_iterations", 0))
    if smooth_factor > 0.0 and smooth_iterations > 0:
        smooth = obj.modifiers.new(name="Smooth", type="SMOOTH")
        smooth.factor = smooth_factor
        smooth.iterations = smooth_iterations
        _apply_modifier(obj, smooth.name)

    decimate = obj.modifiers.new(name="Decimate", type="DECIMATE")
    decimate.ratio = float(finish["decimate_ratio"])
    _apply_modifier(obj, decimate.name)

    bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
    bevel.width = float(finish["bevel_width"])
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = radians(36.0)
    bevel.profile = 0.70
    _apply_modifier(obj, bevel.name)

def _apply_ooze_finish(obj: bpy.types.Object, name: str, finish: dict) -> None:
    remesh = obj.modifiers.new(name="Remesh", type="REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = float(finish["voxel_size"])
    remesh.use_smooth_shade = True
    _apply_modifier(obj, remesh.name)

    texture = bpy.data.textures.new(name=f"{name}_ooze_noise", type="CLOUDS")
    texture.noise_scale = float(finish["noise_scale"])
    texture.noise_depth = int(finish["noise_depth"])
    displace = obj.modifiers.new(name="Displace", type="DISPLACE")
    displace.texture = texture
    displace.strength = float(finish["displace_strength"])
    displace.mid_level = 0.5
    _apply_modifier(obj, displace.name)

    smooth = obj.modifiers.new(name="Smooth", type="SMOOTH")
    smooth.factor = float(finish["smooth_factor"])
    smooth.iterations = int(finish["smooth_iterations"])
    _apply_modifier(obj, smooth.name)

    subdiv_levels: int = int(finish.get("subdiv_levels", 0))
    if subdiv_levels > 0:
        subdiv = obj.modifiers.new(name="Subdiv", type="SUBSURF")
        subdiv.levels = subdiv_levels
        subdiv.render_levels = subdiv_levels
        subdiv.subdivision_type = "CATMULL_CLARK"
        _apply_modifier(obj, subdiv.name)

    decimate = obj.modifiers.new(name="Decimate", type="DECIMATE")
    decimate.ratio = float(finish["decimate_ratio"])
    _apply_modifier(obj, decimate.name)


def _build_from_recipe(asset_name: str, recipe: dict, material_name: str) -> bpy.types.Object:
    reset_scene()
    parts: list[bpy.types.Object] = []
    if "floor_mesh" in recipe:
        parts.append(_create_floor_tile_mesh(asset_name, recipe))
    else:
        for chunk in recipe["chunks"]:
            parts.append(
                _create_cube(
                    location=tuple(chunk["location"]),
                    scale=tuple(chunk["scale"]),
                    rotation_deg=tuple(chunk["rotation_deg"]),
                )
            )
        for boulder in recipe.get("boulders", []):
            parts.append(
                _create_boulder(
                    location=tuple(boulder["location"]),
                    radius=float(boulder["radius"]),
                    scale=tuple(boulder["scale"]),
                )
            )

    joined = _join_objects(asset_name, parts)
    _apply_rock_finish(joined, asset_name, recipe["finish"])
    material = _make_material(
        name=material_name,
        base_color=tuple(recipe["material"]["base_color"]),
        roughness=float(recipe["material"]["roughness"]),
        metallic=float(recipe["material"]["metallic"]),
    )
    _assign_material(joined, material)
    return _finalize_mesh(joined, asset_name)

def _build_ooze_growth_from_recipe(asset_name: str, recipe: dict, material_name: str) -> bpy.types.Object:
    reset_scene()
    parts: list[bpy.types.Object] = [_create_ooze_puddle_mesh(asset_name, recipe)]
    if recipe.get("metaballs", []):
        parts.append(_create_ooze_metaball_mesh(asset_name, recipe))
    for idx, tube in enumerate(recipe.get("tubes", [])):
        curve = _create_tube_curve(
            f"{asset_name}_tube_{idx}",
            [tuple(point) for point in tube["points"]],
            float(tube["radius"]),
        )
        parts.append(_convert_to_mesh(curve))
    joined = _join_objects(asset_name, parts)
    _apply_ooze_finish(joined, asset_name, recipe["finish"])
    material = _make_ooze_material(material_name, recipe["material"])
    _assign_material(joined, material)
    return _finalize_mesh(joined, asset_name)


def _build_outer_cave_wall_a() -> bpy.types.Object:
    return _build_from_recipe("outer_cave_wall_A", OUTER_CAVE_WALL_A_RECIPE, "mat_outer_cave_wall_a")


def _build_outer_cave_wall_b() -> bpy.types.Object:
    return _build_from_recipe("outer_cave_wall_B", OUTER_CAVE_WALL_B_RECIPE, "mat_outer_cave_wall_b")


def _build_outer_cave_wall_c() -> bpy.types.Object:
    return _build_from_recipe("outer_cave_wall_C", OUTER_CAVE_WALL_C_RECIPE, "mat_outer_cave_wall_c")


def _build_inner_wall_blocker_a() -> bpy.types.Object:
    return _build_from_recipe("inner_wall_blocker_A", INNER_WALL_BLOCKER_A_RECIPE, "mat_inner_wall_blocker_a")


def _build_inner_wall_blocker_b() -> bpy.types.Object:
    return _build_from_recipe("inner_wall_blocker_B", INNER_WALL_BLOCKER_B_RECIPE, "mat_inner_wall_blocker_b")


def _build_floor_tile_rock_a() -> bpy.types.Object:
    return _build_from_recipe("floor_tile_rock_A", FLOOR_TILE_ROCK_A_RECIPE, "mat_floor_tile_rock_a")


def _build_floor_tile_rock_b() -> bpy.types.Object:
    return _build_from_recipe("floor_tile_rock_B", FLOOR_TILE_ROCK_B_RECIPE, "mat_floor_tile_rock_b")


def _build_floor_tile_rock_c() -> bpy.types.Object:
    return _build_from_recipe("floor_tile_rock_C", FLOOR_TILE_ROCK_C_RECIPE, "mat_floor_tile_rock_c")


def _build_cave_corner_transition_a() -> bpy.types.Object:
    return _build_from_recipe("cave_corner_transition_A", CAVE_CORNER_TRANSITION_A_RECIPE, "mat_cave_corner_transition_a")


def _build_cave_corner_transition_b() -> bpy.types.Object:
    return _build_from_recipe("cave_corner_transition_B", CAVE_CORNER_TRANSITION_B_RECIPE, "mat_cave_corner_transition_b")


def _build_floor_tile_cobbled_a() -> bpy.types.Object:
    return _build_from_recipe("floor_tile_cobbled_A", FLOOR_TILE_COBBLED_A_RECIPE, "mat_floor_tile_cobbled_a")


def _build_floor_tile_cobbled_b() -> bpy.types.Object:
    return _build_from_recipe("floor_tile_cobbled_B", FLOOR_TILE_COBBLED_B_RECIPE, "mat_floor_tile_cobbled_b")


def _build_floor_tile_cobbled_c() -> bpy.types.Object:
    return _build_from_recipe("floor_tile_cobbled_C", FLOOR_TILE_COBBLED_C_RECIPE, "mat_floor_tile_cobbled_c")


def _build_outer_wall_stone_a() -> bpy.types.Object:
    return _build_from_recipe("outer_wall_stone_A", OUTER_WALL_STONE_A_RECIPE, "mat_outer_wall_stone_a")


def _build_outer_wall_stone_b() -> bpy.types.Object:
    return _build_from_recipe("outer_wall_stone_B", OUTER_WALL_STONE_B_RECIPE, "mat_outer_wall_stone_b")


def _build_inner_wall_stone_a() -> bpy.types.Object:
    return _build_from_recipe("inner_wall_stone_A", INNER_WALL_STONE_A_RECIPE, "mat_inner_wall_stone_a")


def _build_inner_wall_stone_b() -> bpy.types.Object:
    return _build_from_recipe("inner_wall_stone_B", INNER_WALL_STONE_B_RECIPE, "mat_inner_wall_stone_b")


def _build_door_arch_dungeon() -> bpy.types.Object:
    return _build_from_recipe("door_arch_dungeon", DOOR_ARCH_DUNGEON_RECIPE, "mat_door_arch_dungeon")


def _build_rubble_blocker_a() -> bpy.types.Object:
    return _build_from_recipe("rubble_blocker_A", RUBBLE_BLOCKER_A_RECIPE, "mat_rubble_blocker_a")


def _build_rubble_blocker_b() -> bpy.types.Object:
    return _build_from_recipe("rubble_blocker_B", RUBBLE_BLOCKER_B_RECIPE, "mat_rubble_blocker_b")


def _build_pillar_ruin_a() -> bpy.types.Object:
    return _build_from_recipe("pillar_ruin_A", PILLAR_RUIN_A_RECIPE, "mat_pillar_ruin_a")


def _build_core_growth() -> bpy.types.Object:
    return _build_ooze_growth_from_recipe("core_growth", CORE_GROWTH_RECIPE, "mat_core_growth")

def _build_basic_tile() -> bpy.types.Object:
    return _build_ooze_growth_from_recipe("basic_tile", BASIC_TILE_RECIPE, "mat_basic_tile")

def _build_melee_growth() -> bpy.types.Object:
    return _build_ooze_growth_from_recipe("melee_growth", MELEE_GROWTH_RECIPE, "mat_melee_growth")

def _build_ranged_growth() -> bpy.types.Object:
    return _build_ooze_growth_from_recipe("ranged_growth", RANGED_GROWTH_RECIPE, "mat_ranged_growth")

def _build_defense_growth() -> bpy.types.Object:
    return _build_ooze_growth_from_recipe("defense_growth", DEFENSE_GROWTH_RECIPE, "mat_defense_growth")

def _build_gather_growth() -> bpy.types.Object:
    return _build_ooze_growth_from_recipe("gather_growth", GATHER_GROWTH_RECIPE, "mat_gather_growth")


CAVE_ASSET_BUILDERS: list[tuple[str, Callable[[], bpy.types.Object]]] = [
    ("floor_tile_cobbled_A", _build_floor_tile_cobbled_a),
    ("floor_tile_cobbled_B", _build_floor_tile_cobbled_b),
    ("floor_tile_cobbled_C", _build_floor_tile_cobbled_c),
    ("outer_wall_stone_A", _build_outer_wall_stone_a),
    ("outer_wall_stone_B", _build_outer_wall_stone_b),
    ("inner_wall_stone_A", _build_inner_wall_stone_a),
    ("inner_wall_stone_B", _build_inner_wall_stone_b),
    ("door_arch_dungeon", _build_door_arch_dungeon),
    ("rubble_blocker_A", _build_rubble_blocker_a),
    ("rubble_blocker_B", _build_rubble_blocker_b),
    ("pillar_ruin_A", _build_pillar_ruin_a),
]

ASSET_BUILDERS: list[tuple[str, Callable[[], bpy.types.Object]]] = [
    *CAVE_ASSET_BUILDERS,
    ("core_growth", _build_core_growth),
    ("basic_tile", _build_basic_tile),
    ("melee_growth", _build_melee_growth),
    ("ranged_growth", _build_ranged_growth),
    ("defense_growth", _build_defense_growth),
    ("gather_growth", _build_gather_growth),
]

OOZE_ASSET_BUILDERS: list[tuple[str, Callable[[], bpy.types.Object]]] = [
    ("basic_tile", _build_basic_tile),
    ("core_growth", _build_core_growth),
    ("melee_growth", _build_melee_growth),
    ("ranged_growth", _build_ranged_growth),
    ("defense_growth", _build_defense_growth),
    ("gather_growth", _build_gather_growth),
]


def build_and_export_all(export_dir: Path) -> list[Path]:
    exported: list[Path] = []
    for asset_name, builder in CAVE_ASSET_BUILDERS:
        obj = builder()
        glb_path = export_dir / f"{asset_name}.glb"
        exported.append(_export_glb(obj, glb_path))
    return exported


def build_and_export_ooze_assets(export_dir: Path) -> list[Path]:
    exported: list[Path] = []
    for asset_name, builder in OOZE_ASSET_BUILDERS:
        obj = builder()
        glb_path = export_dir / f"{asset_name}.glb"
        exported.append(_export_glb(obj, glb_path))
    return exported
