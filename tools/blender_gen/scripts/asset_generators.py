"""Blender bpy asset generators for Ooze Tactics modular cave kit.

Run via:
    blender -b --python tools/blender_gen/run_all.py
"""

from __future__ import annotations

from math import radians
from pathlib import Path
from typing import Callable, Iterable

import bpy
from mathutils import Vector


ASSET_REPLACEMENT_MAP: dict[str, str] = {
    "crystal_small.glb": "Replaces small crystal markers/props generated as Prism/Cylinder meshes in World3DRenderer crystal and role marker paths.",
    "crystal_hero.glb": "Replaces large focal crystal placeholders for heart/nexus/centerpiece nodes.",
    "node_base.glb": "Replaces circular node/pylon base placeholders currently built from primitive cylinders.",
    "blocker_wall.glb": "Replaces blocker cube/sphere/cylinder/prism primitive variants in _rebuild_static_world blocker placement.",
    "cave_wall_segment.glb": "Replaces cave perimeter wall chunks currently built from box primitives in _add_cave_perimeter.",
    "cave_door_arch.glb": "Replaces doorway arch and door framing primitives in _add_cave_doors.",
    "board_edge_trim.glb": "Replaces board frame/edge trim box primitives created in _rebuild_static_world.",
    "ooze_puddle_a.glb": "Replaces procedural/debug ooze puddle primitives for authored ooze zone silhouettes.",
    "ooze_puddle_b.glb": "Replaces procedural/debug ooze puddle primitives for authored ooze zone silhouettes.",
    "ooze_puddle_c.glb": "Replaces procedural/debug ooze puddle primitives for authored ooze zone silhouettes.",
}

_MATERIAL_CACHE: dict[str, bpy.types.Material] = {}


def _make_material(
    name: str,
    base_color: tuple[float, float, float, float],
    roughness: float,
    metallic: float,
    emission_color: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
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
            bsdf.inputs["Specular IOR Level"].default_value = 0.32
        if emission_color is not None:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = emission_color
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength

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
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
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


def _bevel(obj: bpy.types.Object, width: float, segments: int = 2) -> None:
    bevel = obj.modifiers.new(name="Bevel", type="BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = radians(28.0)
    bevel.profile = 0.7
    _apply_modifier(obj, bevel.name)


def _subdivide(obj: bpy.types.Object, levels: int = 1) -> None:
    subdiv = obj.modifiers.new(name="Subdivide", type="SUBSURF")
    subdiv.levels = levels
    subdiv.render_levels = levels
    _apply_modifier(obj, subdiv.name)


def _join_objects(name: str, objects: Iterable[bpy.types.Object]) -> bpy.types.Object:
    object_list = list(objects)
    if not object_list:
        raise RuntimeError(f"No objects to join for {name}")
    if len(object_list) == 1:
        joined = object_list[0]
        joined.name = name
        return joined
    _deselect_all()
    for obj in object_list:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = object_list[0]
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


def _create_cube(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], rotation_deg: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=location,
        rotation=tuple(radians(v) for v in rotation_deg),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return obj


def _create_cylinder(name: str, radius: float, depth: float, location: tuple[float, float, float], vertices: int = 24) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    return obj


def _create_crystal(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], rotation_deg: tuple[float, float, float]) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=6,
        radius1=0.23,
        radius2=0.02,
        depth=1.0,
        location=location,
        rotation=tuple(radians(v) for v in rotation_deg),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    return obj


def _create_ooze_mesh(name: str, points: list[tuple[float, float]], thickness: float) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    verts = [(x, y, 0.0) for x, y in points]
    faces = [list(range(len(points)))]
    mesh.from_pydata(verts, [], faces)
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    _activate(obj)

    solidify = obj.modifiers.new(name="Solidify", type="SOLIDIFY")
    solidify.thickness = thickness
    solidify.offset = 1.0
    _apply_modifier(obj, solidify.name)

    _subdivide(obj, levels=1)
    _bevel(obj, width=0.014, segments=2)

    return obj


def _build_crystal_small() -> bpy.types.Object:
    reset_scene()
    crystal_material = _make_material(
        "mat_crystal_core",
        (0.26, 0.72, 0.95, 1.0),
        roughness=0.18,
        metallic=0.02,
        emission_color=(0.26, 0.72, 0.95, 1.0),
        emission_strength=1.3,
    )
    parts: list[bpy.types.Object] = []

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.34, location=(0.0, 0.0, 0.22))
    base = bpy.context.active_object
    base.name = "CrystalSmall_Base"
    base.scale = (1.12, 0.96, 0.55)
    parts.append(base)

    shards = [
        ((0.00, 0.00, 0.84), (0.78, 0.78, 1.25), (2.0, 0.0, 0.0)),
        ((0.24, 0.06, 0.62), (0.45, 0.45, 0.95), (8.0, 16.0, 12.0)),
        ((-0.20, -0.10, 0.58), (0.42, 0.42, 0.88), (6.0, -14.0, -8.0)),
        ((0.04, -0.23, 0.54), (0.38, 0.38, 0.82), (12.0, 6.0, 32.0)),
    ]
    for idx, (loc, scl, rot) in enumerate(shards):
        parts.append(_create_crystal(f"CrystalSmall_Shard{idx}", loc, scl, rot))

    joined = _join_objects("crystal_small", parts)
    _bevel(joined, width=0.028, segments=2)
    _assign_material(joined, crystal_material)
    return _finalize_mesh(joined, "crystal_small")


def _build_crystal_hero() -> bpy.types.Object:
    reset_scene()
    crystal_material = _make_material(
        "mat_crystal_hero",
        (0.68, 0.38, 0.95, 1.0),
        roughness=0.16,
        metallic=0.03,
        emission_color=(0.68, 0.38, 0.95, 1.0),
        emission_strength=1.7,
    )
    parts: list[bpy.types.Object] = []

    base = _create_cylinder("CrystalHero_Base", radius=0.55, depth=0.38, location=(0.0, 0.0, 0.19), vertices=18)
    parts.append(base)

    ring = _create_cylinder("CrystalHero_Ring", radius=0.84, depth=0.18, location=(0.0, 0.0, 0.09), vertices=24)
    ring.scale = (1.0, 1.0, 0.6)
    parts.append(ring)

    shards = [
        ((0.00, 0.00, 1.62), (0.92, 0.92, 2.15), (1.0, 0.0, 0.0)),
        ((0.42, 0.08, 1.06), (0.56, 0.56, 1.32), (10.0, 16.0, 8.0)),
        ((-0.45, 0.02, 1.00), (0.54, 0.54, 1.24), (8.0, -14.0, -9.0)),
        ((0.05, -0.50, 0.92), (0.50, 0.50, 1.18), (12.0, 5.0, 28.0)),
        ((0.26, 0.42, 0.88), (0.44, 0.44, 0.98), (14.0, 7.0, -32.0)),
        ((-0.28, -0.36, 0.86), (0.42, 0.42, 0.94), (9.0, -7.0, 23.0)),
    ]
    for idx, (loc, scl, rot) in enumerate(shards):
        parts.append(_create_crystal(f"CrystalHero_Shard{idx}", loc, scl, rot))

    joined = _join_objects("crystal_hero", parts)
    _bevel(joined, width=0.036, segments=2)
    _assign_material(joined, crystal_material)
    return _finalize_mesh(joined, "crystal_hero")


def _build_node_base() -> bpy.types.Object:
    reset_scene()
    base_material = _make_material(
        "mat_node_base",
        (0.24, 0.23, 0.21, 1.0),
        roughness=0.72,
        metallic=0.08,
    )
    parts = [
        _create_cylinder("NodeBase_Lower", radius=0.95, depth=0.26, location=(0.0, 0.0, 0.13), vertices=24),
        _create_cylinder("NodeBase_Mid", radius=0.72, depth=0.20, location=(0.0, 0.0, 0.34), vertices=18),
        _create_cylinder("NodeBase_Upper", radius=0.55, depth=0.16, location=(0.0, 0.0, 0.52), vertices=16),
        _create_cylinder("NodeBase_Socket", radius=0.34, depth=0.14, location=(0.0, 0.0, 0.67), vertices=12),
    ]

    joined = _join_objects("node_base", parts)
    _bevel(joined, width=0.044, segments=2)
    _assign_material(joined, base_material)
    return _finalize_mesh(joined, "node_base")


def _build_blocker_wall() -> bpy.types.Object:
    reset_scene()
    stone_material = _make_material(
        "mat_cave_stone",
        (0.21, 0.20, 0.19, 1.0),
        roughness=0.84,
        metallic=0.02,
    )
    parts = [
        _create_cube("Blocker_Main", location=(0.00, 0.00, 0.44), scale=(0.66, 0.40, 0.42), rotation_deg=(4.0, 0.0, 5.0)),
        _create_cube("Blocker_Left", location=(-0.62, 0.06, 0.38), scale=(0.56, 0.36, 0.36), rotation_deg=(0.0, 4.0, -8.0)),
        _create_cube("Blocker_Right", location=(0.62, -0.04, 0.41), scale=(0.58, 0.34, 0.39), rotation_deg=(3.0, -5.0, 9.0)),
        _create_cube("Blocker_Back", location=(0.02, -0.26, 0.34), scale=(0.92, 0.18, 0.30), rotation_deg=(2.0, 0.0, 0.0)),
    ]

    joined = _join_objects("blocker_wall", parts)
    _bevel(joined, width=0.052, segments=2)
    _assign_material(joined, stone_material)
    return _finalize_mesh(joined, "blocker_wall")


def _build_cave_wall_segment() -> bpy.types.Object:
    reset_scene()
    wall_material = _make_material(
        "mat_cave_wall",
        (0.17, 0.17, 0.18, 1.0),
        roughness=0.89,
        metallic=0.0,
    )
    parts = [
        _create_cube("Wall_BackCore", location=(0.00, -0.64, 1.05), scale=(1.95, 0.42, 1.08), rotation_deg=(0.0, 0.0, 0.0)),
        _create_cube("Wall_LeftA", location=(-1.20, -0.20, 1.12), scale=(0.56, 0.56, 1.20), rotation_deg=(0.0, 0.0, 8.0)),
        _create_cube("Wall_LeftB", location=(-0.48, -0.16, 1.05), scale=(0.58, 0.52, 1.08), rotation_deg=(0.0, 0.0, 4.0)),
        _create_cube("Wall_RightA", location=(0.52, -0.18, 1.08), scale=(0.60, 0.52, 1.12), rotation_deg=(0.0, 0.0, -5.0)),
        _create_cube("Wall_RightB", location=(1.22, -0.22, 1.14), scale=(0.58, 0.54, 1.18), rotation_deg=(0.0, 0.0, -9.0)),
        _create_cube("Wall_Cap", location=(0.00, -0.38, 2.06), scale=(1.50, 0.34, 0.30), rotation_deg=(0.0, 0.0, 0.0)),
    ]

    joined = _join_objects("cave_wall_segment", parts)
    _bevel(joined, width=0.064, segments=2)
    _assign_material(joined, wall_material)
    return _finalize_mesh(joined, "cave_wall_segment")


def _build_cave_door_arch() -> bpy.types.Object:
    reset_scene()
    door_material = _make_material(
        "mat_cave_arch",
        (0.19, 0.17, 0.16, 1.0),
        roughness=0.81,
        metallic=0.03,
    )
    parts = [
        _create_cube("Door_LeftPillar", location=(-0.98, 0.00, 1.00), scale=(0.34, 0.48, 1.00), rotation_deg=(0.0, 0.0, 2.0)),
        _create_cube("Door_RightPillar", location=(0.98, 0.00, 1.00), scale=(0.34, 0.48, 1.00), rotation_deg=(0.0, 0.0, -2.0)),
        _create_cube("Door_Header", location=(0.00, 0.00, 2.08), scale=(1.28, 0.50, 0.24), rotation_deg=(0.0, 0.0, 0.0)),
        _create_cube("Door_InnerHeader", location=(0.00, 0.18, 1.86), scale=(0.78, 0.24, 0.18), rotation_deg=(18.0, 0.0, 0.0)),
        _create_cube("Door_ShoulderL", location=(-0.58, 0.02, 1.70), scale=(0.28, 0.44, 0.24), rotation_deg=(12.0, 0.0, 18.0)),
        _create_cube("Door_ShoulderR", location=(0.58, 0.02, 1.70), scale=(0.28, 0.44, 0.24), rotation_deg=(12.0, 0.0, -18.0)),
        _create_cube("Door_BackMass", location=(0.00, -0.34, 1.14), scale=(1.44, 0.28, 1.08), rotation_deg=(0.0, 0.0, 0.0)),
    ]

    joined = _join_objects("cave_door_arch", parts)
    _bevel(joined, width=0.058, segments=2)
    _assign_material(joined, door_material)
    return _finalize_mesh(joined, "cave_door_arch")


def _build_board_edge_trim() -> bpy.types.Object:
    reset_scene()
    trim_material = _make_material(
        "mat_board_trim",
        (0.15, 0.14, 0.13, 1.0),
        roughness=0.68,
        metallic=0.20,
    )
    parts = [
        _create_cube("Trim_Base", location=(0.00, 0.00, 0.15), scale=(1.35, 0.28, 0.15), rotation_deg=(0.0, 0.0, 0.0)),
        _create_cube("Trim_Lip", location=(0.00, 0.04, 0.31), scale=(1.28, 0.17, 0.08), rotation_deg=(0.0, 0.0, 0.0)),
        _create_cube("Trim_Brace", location=(0.00, -0.14, 0.23), scale=(1.24, 0.10, 0.12), rotation_deg=(0.0, 0.0, 0.0)),
        _create_cube("Trim_EndL", location=(-1.33, 0.00, 0.19), scale=(0.11, 0.27, 0.12), rotation_deg=(0.0, 0.0, 0.0)),
        _create_cube("Trim_EndR", location=(1.33, 0.00, 0.19), scale=(0.11, 0.27, 0.12), rotation_deg=(0.0, 0.0, 0.0)),
    ]

    joined = _join_objects("board_edge_trim", parts)
    _bevel(joined, width=0.038, segments=2)
    _assign_material(joined, trim_material)
    return _finalize_mesh(joined, "board_edge_trim")


def _build_ooze_puddle_a() -> bpy.types.Object:
    reset_scene()
    ooze_material = _make_material(
        "mat_ooze_pool",
        (0.09, 0.28, 0.40, 1.0),
        roughness=0.30,
        metallic=0.0,
        emission_color=(0.15, 0.58, 0.80, 1.0),
        emission_strength=0.9,
    )
    points = [
        (-1.05, -0.10),
        (-0.82, 0.34),
        (-0.36, 0.58),
        (0.24, 0.54),
        (0.74, 0.22),
        (0.96, -0.22),
        (0.62, -0.56),
        (0.12, -0.64),
        (-0.46, -0.52),
        (-0.90, -0.34),
    ]
    obj = _create_ooze_mesh("ooze_puddle_a", points, thickness=0.056)
    _assign_material(obj, ooze_material)
    return _finalize_mesh(obj, "ooze_puddle_a")


def _build_ooze_puddle_b() -> bpy.types.Object:
    reset_scene()
    ooze_material = _make_material(
        "mat_ooze_pool",
        (0.09, 0.28, 0.40, 1.0),
        roughness=0.30,
        metallic=0.0,
        emission_color=(0.15, 0.58, 0.80, 1.0),
        emission_strength=0.9,
    )
    points = [
        (-1.20, 0.02),
        (-0.96, 0.36),
        (-0.48, 0.48),
        (0.10, 0.40),
        (0.56, 0.52),
        (0.98, 0.28),
        (1.16, -0.08),
        (0.86, -0.42),
        (0.38, -0.50),
        (-0.12, -0.46),
        (-0.52, -0.66),
        (-0.98, -0.44),
    ]
    obj = _create_ooze_mesh("ooze_puddle_b", points, thickness=0.060)
    _assign_material(obj, ooze_material)
    return _finalize_mesh(obj, "ooze_puddle_b")


def _build_ooze_puddle_c() -> bpy.types.Object:
    reset_scene()
    ooze_material = _make_material(
        "mat_ooze_pool",
        (0.09, 0.28, 0.40, 1.0),
        roughness=0.30,
        metallic=0.0,
        emission_color=(0.15, 0.58, 0.80, 1.0),
        emission_strength=0.9,
    )
    points = [
        (-0.96, 0.14),
        (-0.70, 0.46),
        (-0.26, 0.62),
        (0.26, 0.58),
        (0.62, 0.30),
        (0.90, 0.02),
        (0.72, -0.32),
        (0.24, -0.54),
        (-0.32, -0.56),
        (-0.76, -0.34),
    ]
    obj = _create_ooze_mesh("ooze_puddle_c", points, thickness=0.054)
    _assign_material(obj, ooze_material)
    return _finalize_mesh(obj, "ooze_puddle_c")


ASSET_BUILDERS: list[tuple[str, Callable[[], bpy.types.Object]]] = [
    ("crystal_small", _build_crystal_small),
    ("crystal_hero", _build_crystal_hero),
    ("node_base", _build_node_base),
    ("blocker_wall", _build_blocker_wall),
    ("cave_wall_segment", _build_cave_wall_segment),
    ("cave_door_arch", _build_cave_door_arch),
    ("board_edge_trim", _build_board_edge_trim),
    ("ooze_puddle_a", _build_ooze_puddle_a),
    ("ooze_puddle_b", _build_ooze_puddle_b),
    ("ooze_puddle_c", _build_ooze_puddle_c),
]


def build_and_export_all(export_dir: Path) -> list[Path]:
    exported: list[Path] = []
    for asset_name, builder in ASSET_BUILDERS:
        obj = builder()
        glb_path = export_dir / f"{asset_name}.glb"
        exported.append(_export_glb(obj, glb_path))
    return exported
