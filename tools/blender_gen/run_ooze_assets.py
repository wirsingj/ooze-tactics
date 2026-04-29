"""Headless Blender entrypoint for only the role-readable ooze growth assets.

Usage (from repo root):
    blender -b --python tools/blender_gen/run_ooze_assets.py
"""

from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


THIS_FILE = Path(__file__).resolve()
BLENDER_GEN_DIR = THIS_FILE.parent
REPO_ROOT = THIS_FILE.parents[2]
SCRIPTS_DIR = BLENDER_GEN_DIR / "scripts"

if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from ooze_production_assets import ASSET_NOTES, build_and_export_ooze_assets  # noqa: E402


OOZE_ASSET_NAMES = [
    "basic_tile",
    "core_growth",
    "melee_growth",
    "ranged_growth",
    "defense_growth",
    "gather_growth",
]


def _as_repo_relative(path: Path) -> str:
    return str(path.relative_to(REPO_ROOT)).replace("\\", "/")


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def _look_at(obj: bpy.types.Object, target: Vector) -> None:
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def _bounds_for(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    mins = Vector((9999.0, 9999.0, 9999.0))
    maxs = Vector((-9999.0, -9999.0, -9999.0))
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            mins.x = min(mins.x, world.x)
            mins.y = min(mins.y, world.y)
            mins.z = min(mins.z, world.z)
            maxs.x = max(maxs.x, world.x)
            maxs.y = max(maxs.y, world.y)
            maxs.z = max(maxs.z, world.z)
    return mins, maxs


def _place_imported_asset(glb_path: Path, name: str, location: Vector) -> None:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(glb_path))
    imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    meshes = [obj for obj in imported if obj.type == "MESH"]
    if not meshes:
        return
    for obj in meshes:
        obj.data.transform(obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        obj.parent = None
    for obj in imported:
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    mins, maxs = _bounds_for(meshes)
    center = (mins + maxs) * 0.5
    offset = location - Vector((center.x, center.y, mins.z))
    for obj in meshes:
        obj.location += offset


def render_contact_sheet(export_dir: Path, output_path: Path) -> Path:
    _clear_scene()
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.color = (0.015, 0.015, 0.017)

    positions = [
        Vector((-2.80, 1.70, 0.0)),
        Vector((0.00, 1.70, 0.0)),
        Vector((2.80, 1.70, 0.0)),
        Vector((-2.80, -1.70, 0.0)),
        Vector((0.00, -1.70, 0.0)),
        Vector((2.80, -1.70, 0.0)),
    ]
    for asset_name, location in zip(OOZE_ASSET_NAMES, positions):
        _place_imported_asset(export_dir / f"{asset_name}.glb", asset_name, location)

    bpy.ops.object.light_add(type="AREA", location=(0.0, -4.0, 5.2))
    key = bpy.context.object
    key.name = "ContactSheetKey"
    key.data.energy = 620.0
    key.data.size = 5.0
    _look_at(key, Vector((0.0, 0.0, 0.45)))

    bpy.ops.object.light_add(type="POINT", location=(-3.0, 2.5, 2.2))
    fill = bpy.context.object
    fill.name = "ContactSheetFill"
    fill.data.energy = 85.0
    fill.data.shadow_soft_size = 4.0

    bpy.ops.object.camera_add(location=(0.0, -4.8, 7.4))
    camera = bpy.context.object
    _look_at(camera, Vector((0.0, 0.0, 0.42)))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 7.8
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        pass
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1000
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(output_path)
    bpy.ops.render.render(write_still=True)
    return output_path


def main() -> int:
    export_dir = REPO_ROOT / "assets" / "meshes" / "generated"
    output_dir = BLENDER_GEN_DIR / "output"
    output_dir.mkdir(parents=True, exist_ok=True)

    exported_paths = build_and_export_ooze_assets(export_dir)
    contact_sheet_path = output_dir / "ooze_role_contact_sheet.png"
    render_contact_sheet(export_dir, contact_sheet_path)

    manifest = {
        "repo_root": str(REPO_ROOT),
        "export_dir": _as_repo_relative(export_dir),
        "assets": [_as_repo_relative(path) for path in exported_paths],
        "contact_sheet": _as_repo_relative(contact_sheet_path),
        "replacement_map": {
            path.name: ASSET_NOTES[path.name]
            for path in exported_paths
            if path.name in ASSET_NOTES
        },
    }

    manifest_path = output_dir / "ooze_export_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print("[blender_gen] Ooze export complete")
    for path in exported_paths:
        print(f"[blender_gen] - {_as_repo_relative(path)}")
    print(f"[blender_gen] Contact sheet: {_as_repo_relative(contact_sheet_path)}")
    print(f"[blender_gen] Manifest: {_as_repo_relative(manifest_path)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception:  # pragma: no cover
        print("[blender_gen] Fatal error")
        print(traceback.format_exc())
        raise SystemExit(1)
