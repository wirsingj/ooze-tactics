"""Role-first generated ooze assets for Ooze Tactics.

The previous ooze kit leaned on metaballs and many small blob accents. This
module intentionally builds stronger silhouettes from deterministic mesh parts:
raised puddle rims, tapered tendrils, organ mounds, shells, stalks, and grouped
pods.  It exports the same GLB filenames used by the Godot manifest.
"""

from __future__ import annotations

from dataclasses import dataclass
from math import atan2, cos, pi, radians, sin, sqrt
from pathlib import Path
from typing import Iterable

import bpy
from mathutils import Vector


OOZE_ASSET_NAMES = [
    "basic_tile",
    "core_growth",
    "melee_growth",
    "ranged_growth",
    "defense_growth",
    "gather_growth",
]

ASSET_NOTES = {
    "basic_tile.glb": "Low spreading acid puddle with raised lip and a few crawling feeder tendrils.",
    "core_growth.glb": "Dominant living heart organ with swollen lobes, rooted veins, and a clear crown silhouette.",
    "melee_growth.glb": "Directional grabbing tendrils with hooked claw tips and aggressive forward reach.",
    "ranged_growth.glb": "Arched spitter stalk with acid sac, forward nozzle, and planted roots.",
    "defense_growth.glb": "Low wide hardened shell bunker with layered crust ridges.",
    "gather_growth.glb": "Collector node with sensory feelers and low siphon pods.",
}


@dataclass(frozen=True)
class PuddleSpec:
    radius_x: float
    radius_y: float
    center_height: float
    rim_height: float
    rings: int = 7
    segments: int = 96
    seed: int = 1
    rim_width: float = 0.22
    asymmetry: float = 0.04
    forward_lobe: float = 0.0


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.textures):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)


def _activate(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def _set_smooth(obj: bpy.types.Object) -> None:
    if obj.type != "MESH" or obj.data is None:
        return
    for poly in obj.data.polygons:
        poly.use_smooth = True


def _apply_modifier(obj: bpy.types.Object, modifier_name: str) -> None:
    _activate(obj)
    bpy.ops.object.modifier_apply(modifier=modifier_name)


def _assign_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    if obj.type == "MESH" and obj.data is not None:
        obj.data.materials.clear()
        obj.data.materials.append(material)


def _join_objects(name: str, objects: Iterable[bpy.types.Object]) -> bpy.types.Object:
    parts = [obj for obj in objects if obj is not None]
    if not parts:
        raise RuntimeError(f"No parts supplied for {name}")
    if len(parts) == 1:
        parts[0].name = name
        return parts[0]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def _center_to_ground(obj: bpy.types.Object) -> None:
    if obj.type != "MESH" or obj.data is None:
        return
    verts = obj.data.vertices
    if not verts:
        return
    min_x = min(v.co.x for v in verts)
    max_x = max(v.co.x for v in verts)
    min_y = min(v.co.y for v in verts)
    max_y = max(v.co.y for v in verts)
    min_z = min(v.co.z for v in verts)
    offset = Vector((-(min_x + max_x) * 0.5, -(min_y + max_y) * 0.5, -min_z))
    for vert in verts:
        vert.co += offset
    obj.data.update()


def _finalize(obj: bpy.types.Object, name: str, material: bpy.types.Material) -> bpy.types.Object:
    _activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    _center_to_ground(obj)
    _set_smooth(obj)
    _assign_material(obj, material)
    weighted = obj.modifiers.new(name="WeightedNormals", type="WEIGHTED_NORMAL")
    weighted.keep_sharp = True
    _apply_modifier(obj, weighted.name)
    obj.name = name
    if obj.type == "MESH" and obj.data is not None:
        obj.data.name = f"{name}_mesh"
    return obj


def make_ooze_material() -> bpy.types.Material:
    material = bpy.data.materials.new("mat_acid_ooze_shared")
    material.use_nodes = True
    material.diffuse_color = (0.07, 0.46, 0.12, 1.0)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (0.05, 0.38, 0.10, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.46
        bsdf.inputs["Metallic"].default_value = 0.0
        if "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = 1.0
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.58
        if "Coat Weight" in bsdf.inputs:
            bsdf.inputs["Coat Weight"].default_value = 0.22
        elif "Clearcoat" in bsdf.inputs:
            bsdf.inputs["Clearcoat"].default_value = 0.22
        if "Coat Roughness" in bsdf.inputs:
            bsdf.inputs["Coat Roughness"].default_value = 0.32
        elif "Clearcoat Roughness" in bsdf.inputs:
            bsdf.inputs["Clearcoat Roughness"].default_value = 0.32
        if "Subsurface Weight" in bsdf.inputs:
            bsdf.inputs["Subsurface Weight"].default_value = 0.04
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (0.02, 0.16, 0.03, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 0.08
    return material


def _edge_variation(angle: float, spec: PuddleSpec) -> float:
    seed = float(spec.seed)
    ripple = (
        sin(angle * 3.0 + seed * 0.33) * 0.55
        + sin(angle * 5.0 + seed * 0.57) * 0.30
        + cos(angle * 7.0 + seed * 0.21) * 0.15
    )
    forward = max(0.0, cos(angle - pi * 0.5)) ** 2.0
    return 1.0 + spec.asymmetry * ripple + spec.forward_lobe * forward


def create_puddle(name: str, spec: PuddleSpec) -> bpy.types.Object:
    verts: list[tuple[float, float, float]] = [(0.0, 0.0, spec.center_height)]
    faces: list[tuple[int, ...]] = []
    ring_indices: list[list[int]] = []

    for ring in range(1, spec.rings + 1):
        t = float(ring) / float(spec.rings)
        row: list[int] = []
        for i in range(spec.segments):
            angle = (float(i) / float(spec.segments)) * pi * 2.0
            edge = _edge_variation(angle, spec)
            x = cos(angle) * spec.radius_x * t * edge
            y = sin(angle) * spec.radius_y * t * edge
            body = spec.center_height * ((1.0 - t) ** 1.9)
            rim_t = max(0.0, (t - (1.0 - spec.rim_width)) / max(0.001, spec.rim_width))
            rim = spec.rim_height * sin(rim_t * pi)
            broad = sin(angle * 2.0 + spec.seed * 0.17) * 0.006 * (1.0 - t)
            z = max(0.006, body + rim + broad)
            row.append(len(verts))
            verts.append((x, y, z))
        ring_indices.append(row)

    bottom_center = len(verts)
    verts.append((0.0, 0.0, -0.025))
    bottom: list[int] = []
    for idx in ring_indices[-1]:
        x, y, _z = verts[idx]
        bottom.append(len(verts))
        verts.append((x * 0.985, y * 0.985, -0.025))

    first = ring_indices[0]
    for i in range(spec.segments):
        faces.append((0, first[i], first[(i + 1) % spec.segments]))
    for r in range(len(ring_indices) - 1):
        inner = ring_indices[r]
        outer = ring_indices[r + 1]
        for i in range(spec.segments):
            faces.append((inner[i], outer[i], outer[(i + 1) % spec.segments], inner[(i + 1) % spec.segments]))
    outer = ring_indices[-1]
    for i in range(spec.segments):
        faces.append((outer[i], bottom[i], bottom[(i + 1) % spec.segments], outer[(i + 1) % spec.segments]))
        faces.append((bottom_center, bottom[(i + 1) % spec.segments], bottom[i]))

    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    _set_smooth(obj)
    return obj


def create_ellipsoid(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], segments: int = 32) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=max(8, segments // 2), radius=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    _set_smooth(obj)
    return obj


def create_flattened_dome(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float]) -> bpy.types.Object:
    obj = create_ellipsoid(name, loc, scale, 40)
    # Keep the underside from becoming a visible ball. The asset sits into the puddle.
    for vert in obj.data.vertices:
        if vert.co.z < -0.08:
            vert.co.z = -0.08
    obj.data.update()
    return obj


def create_contact_shadow_disc(name: str, radius_x: float, radius_y: float, z: float = -0.018) -> bpy.types.Object:
    """A very low, darkened geometry skirt that grounds the asset in Godot lighting."""

    verts: list[tuple[float, float, float]] = [(0.0, 0.0, z)]
    faces: list[tuple[int, ...]] = []
    segments = 72
    for i in range(segments):
        angle = (float(i) / float(segments)) * pi * 2.0
        wobble = 1.0 + 0.025 * sin(angle * 3.0) + 0.018 * cos(angle * 5.0)
        verts.append((cos(angle) * radius_x * wobble, sin(angle) * radius_y * wobble, z))
    for i in range(segments):
        faces.append((0, i + 1, ((i + 1) % segments) + 1))
    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def create_heart_mound(
    name: str,
    loc: tuple[float, float, float],
    scale: tuple[float, float, float],
    segments: int = 56,
    layers: int = 18,
) -> bpy.types.Object:
    """Build one unsettling heart-like mass without stacking round blobs."""

    base = Vector(loc)
    sx, sy, sz = scale
    verts: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []

    for layer in range(layers + 1):
        t = float(layer) / float(layers)
        row_z = base.z + sz * t
        # Broad planted base, swollen middle, pinched top.
        body_profile = 0.24 + 0.92 * (sin(t * pi) ** 0.58) * (1.0 - t * 0.16)
        if t < 0.18:
            body_profile = 0.46 + t * 2.0
        for i in range(segments):
            angle = (float(i) / float(segments)) * pi * 2.0
            # Top/down silhouette asymmetry: not a sphere, not a stack.
            lobe = 1.0
            lobe += 0.12 * max(0.0, cos(angle - radians(25.0))) ** 2.0
            lobe += 0.10 * max(0.0, cos(angle - radians(155.0))) ** 2.0
            lobe -= 0.07 * max(0.0, cos(angle - radians(-92.0))) ** 2.0

            # A shallow front cleft suggests acid-heart anatomy from camera distance.
            cleft_center = -pi * 0.5
            cleft_width = 0.34
            cleft_delta = abs((angle - cleft_center + pi) % (pi * 2.0) - pi)
            cleft = max(0.0, 1.0 - cleft_delta / cleft_width) ** 2.0
            cleft_strength = 0.20 * cleft * (0.30 + 0.70 * t)

            r = body_profile * lobe * (1.0 - cleft_strength)
            wobble = 1.0 + 0.025 * sin(angle * 3.0 + t * 4.0) + 0.018 * cos(angle * 5.0 - t * 2.2)
            x = base.x + cos(angle) * sx * r * wobble
            y = base.y + sin(angle) * sy * r * wobble
            # Slight lean and back hunch so it feels alive rather than symmetrical.
            x += sx * 0.05 * sin(t * pi) * sin(angle + 0.6)
            y += sy * 0.07 * (t ** 1.4)
            verts.append((x, y, row_z))

    top_center = len(verts)
    verts.append((base.x + sx * 0.03, base.y + sy * 0.08, base.z + sz * 1.04))
    bottom_center = len(verts)
    verts.append((base.x, base.y, base.z - 0.035))

    for layer in range(layers):
        row = layer * segments
        next_row = (layer + 1) * segments
        for i in range(segments):
            faces.append((row + i, next_row + i, next_row + ((i + 1) % segments), row + ((i + 1) % segments)))
    top_row = layers * segments
    for i in range(segments):
        faces.append((top_center, top_row + i, top_row + ((i + 1) % segments)))
        faces.append((bottom_center, (i + 1) % segments, i))

    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    _set_smooth(obj)
    return obj


def create_tapered_tube(
    name: str,
    points: list[tuple[float, float, float]],
    radii: list[float],
    segments: int = 18,
) -> bpy.types.Object:
    if len(points) < 2 or len(points) != len(radii):
        raise ValueError("Tapered tube needs matching points/radii")
    verts: list[tuple[float, float, float]] = []
    faces: list[tuple[int, ...]] = []
    point_vecs = [Vector(p) for p in points]
    for idx, point in enumerate(point_vecs):
        if idx == 0:
            tangent = point_vecs[1] - point
        elif idx == len(point_vecs) - 1:
            tangent = point - point_vecs[idx - 1]
        else:
            tangent = point_vecs[idx + 1] - point_vecs[idx - 1]
        if tangent.length < 0.0001:
            tangent = Vector((0.0, 1.0, 0.0))
        tangent.normalize()
        side = Vector((-tangent.y, tangent.x, 0.0))
        if side.length < 0.001:
            side = Vector((1.0, 0.0, 0.0))
        side.normalize()
        up = tangent.cross(side)
        if up.length < 0.001:
            up = Vector((0.0, 0.0, 1.0))
        up.normalize()
        for i in range(segments):
            angle = (float(i) / float(segments)) * pi * 2.0
            ring_vec = side * cos(angle) + up * sin(angle)
            p = point + ring_vec * radii[idx]
            verts.append((p.x, p.y, p.z))

    for idx in range(len(points) - 1):
        base = idx * segments
        next_base = (idx + 1) * segments
        for i in range(segments):
            faces.append((base + i, next_base + i, next_base + ((i + 1) % segments), base + ((i + 1) % segments)))
    start_center = len(verts)
    verts.append(tuple(point_vecs[0]))
    end_center = len(verts)
    verts.append(tuple(point_vecs[-1]))
    for i in range(segments):
        faces.append((start_center, (i + 1) % segments, i))
        end_a = (len(points) - 1) * segments + i
        end_b = (len(points) - 1) * segments + ((i + 1) % segments)
        faces.append((end_center, end_a, end_b))

    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    _set_smooth(obj)
    return obj


def create_ridge_arc(name: str, radius: float, y: float, z: float, width_deg: float, thickness: float, height: float) -> bpy.types.Object:
    half = radians(width_deg) * 0.5
    points: list[tuple[float, float, float]] = []
    radii: list[float] = []
    steps = 9
    for i in range(steps):
        t = float(i) / float(steps - 1)
        angle = pi * 0.5 - half + t * half * 2.0
        points.append((cos(angle) * radius, y + sin(angle) * radius * 0.34, z + sin(t * pi) * height))
        radii.append(thickness * (0.90 + 0.20 * sin(t * pi)))
    return create_tapered_tube(name, points, radii, 18)


def _add_subtle_finish(obj: bpy.types.Object, strength: float = 0.003) -> None:
    texture = bpy.data.textures.new(name=f"{obj.name}_broad_wet_unevenness", type="VORONOI")
    texture.noise_scale = 1.15
    texture.intensity = 0.18
    displace = obj.modifiers.new(name="BroadWetUnevenness", type="DISPLACE")
    displace.texture = texture
    displace.strength = strength
    displace.mid_level = 0.58
    _apply_modifier(obj, displace.name)
    smooth = obj.modifiers.new(name="SculptSmoothing", type="SMOOTH")
    smooth.factor = 0.12
    smooth.iterations = 2
    _apply_modifier(obj, smooth.name)


def _export(obj: bpy.types.Object, output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    _activate(obj)
    bpy.ops.export_scene.gltf(filepath=str(output_path), export_format="GLB", use_selection=True, export_apply=True)
    return output_path


def build_basic_tile(material: bpy.types.Material) -> bpy.types.Object:
    parts = [
        create_contact_shadow_disc("basic_ground_shadow", 0.76, 0.66),
        create_puddle("basic_puddle", PuddleSpec(0.74, 0.64, 0.038, 0.050, seed=12, asymmetry=0.040, forward_lobe=0.08)),
        create_tapered_tube("basic_feeler_forward", [(0.02, 0.18, 0.045), (0.18, 0.48, 0.042), (0.38, 0.70, 0.028)], [0.050, 0.036, 0.018], 12),
        create_tapered_tube("basic_feeler_left", [(-0.12, 0.02, 0.040), (-0.42, -0.12, 0.032), (-0.62, -0.24, 0.020)], [0.046, 0.032, 0.016], 12),
        create_ellipsoid("basic_slow_bubble", (-0.18, 0.12, 0.070), (0.070, 0.058, 0.042), 18),
    ]
    obj = _join_objects("basic_tile", parts)
    _add_subtle_finish(obj, 0.0012)
    return _finalize(obj, "basic_tile", material)


def build_core_growth(material: bpy.types.Material) -> bpy.types.Object:
    parts = [
        create_contact_shadow_disc("core_ground_shadow", 1.10, 0.98),
        create_puddle("core_base", PuddleSpec(1.08, 0.94, 0.090, 0.095, rings=8, seed=22, asymmetry=0.055)),
        create_heart_mound("core_heart_mass", (0.00, -0.02, 0.14), (0.54, 0.44, 0.98), 64, 22),
        create_tapered_tube("core_crown_spine_l", [(-0.16, 0.02, 0.72), (-0.22, 0.04, 1.02), (-0.24, 0.02, 1.22)], [0.055, 0.040, 0.018], 12),
        create_tapered_tube("core_crown_spine_r", [(0.16, 0.04, 0.70), (0.24, 0.08, 0.98), (0.28, 0.08, 1.16)], [0.052, 0.038, 0.018], 12),
        create_tapered_tube("core_front_root_lobe", [(0.00, -0.16, 0.16), (-0.06, -0.52, 0.13), (-0.22, -0.92, 0.07)], [0.22, 0.17, 0.070], 22),
        create_tapered_tube("core_left_root_lobe", [(-0.10, 0.02, 0.15), (-0.48, 0.22, 0.13), (-0.92, 0.34, 0.065)], [0.18, 0.130, 0.062], 20),
        create_tapered_tube("core_right_root_lobe", [(0.10, 0.02, 0.15), (0.52, 0.24, 0.13), (0.96, 0.40, 0.065)], [0.18, 0.130, 0.062], 20),
        create_tapered_tube("core_rear_root_lobe", [(0.02, 0.12, 0.15), (0.16, 0.52, 0.12), (0.24, 0.86, 0.07)], [0.145, 0.110, 0.060], 18),
        create_ellipsoid("core_front_root_cap", (-0.18, -0.86, 0.08), (0.105, 0.065, 0.040), 18),
        create_ellipsoid("core_left_root_cap", (-0.86, 0.30, 0.07), (0.092, 0.058, 0.036), 18),
        create_ellipsoid("core_right_root_cap", (0.90, 0.38, 0.07), (0.092, 0.058, 0.036), 18),
        create_ellipsoid("core_rear_root_cap", (0.24, 0.86, 0.07), (0.078, 0.052, 0.034), 16),
    ]
    obj = _join_objects("core_growth", parts)
    _add_subtle_finish(obj, 0.0022)
    return _finalize(obj, "core_growth", material)


def build_melee_growth(material: bpy.types.Material) -> bpy.types.Object:
    parts = [
        create_contact_shadow_disc("melee_ground_shadow", 0.94, 0.78),
        create_puddle("melee_base", PuddleSpec(0.90, 0.66, 0.064, 0.065, seed=33, asymmetry=0.045, forward_lobe=0.44)),
        create_flattened_dome("melee_anchor", (0.0, 0.02, 0.18), (0.30, 0.22, 0.17)),
        create_tapered_tube("melee_center_grabber", [(0.0, 0.04, 0.13), (0.00, 0.48, 0.22), (-0.04, 0.86, 0.18), (-0.24, 1.12, 0.08)], [0.165, 0.134, 0.086, 0.036], 18),
        create_tapered_tube("melee_center_inner_hook", [(-0.07, 0.86, 0.15), (0.06, 1.05, 0.11), (0.24, 1.08, 0.064)], [0.055, 0.040, 0.020], 12),
        create_tapered_tube("melee_left_hook", [(-0.08, 0.02, 0.12), (-0.42, 0.34, 0.20), (-0.74, 0.66, 0.14), (-0.96, 0.88, 0.070)], [0.150, 0.120, 0.080, 0.034], 18),
        create_tapered_tube("melee_left_inner_hook", [(-0.62, 0.58, 0.13), (-0.78, 0.62, 0.11), (-0.92, 0.56, 0.080)], [0.066, 0.050, 0.030], 16),
        create_tapered_tube("melee_right_hook", [(0.10, 0.00, 0.12), (0.42, 0.30, 0.20), (0.76, 0.58, 0.14), (1.04, 0.72, 0.070)], [0.150, 0.120, 0.080, 0.034], 18),
        create_tapered_tube("melee_right_inner_hook", [(0.66, 0.54, 0.13), (0.80, 0.54, 0.11), (0.94, 0.44, 0.080)], [0.066, 0.050, 0.030], 16),
        create_tapered_tube("melee_claw_center", [(-0.24, 1.12, 0.08), (-0.34, 1.20, 0.058)], [0.040, 0.010], 10),
        create_tapered_tube("melee_claw_l", [(-0.96, 0.88, 0.070), (-1.08, 0.94, 0.046)], [0.038, 0.010], 10),
        create_tapered_tube("melee_claw_r", [(1.04, 0.72, 0.070), (1.18, 0.74, 0.046)], [0.038, 0.010], 10),
    ]
    obj = _join_objects("melee_growth", parts)
    _add_subtle_finish(obj, 0.0017)
    return _finalize(obj, "melee_growth", material)


def build_ranged_growth(material: bpy.types.Material) -> bpy.types.Object:
    parts = [
        create_contact_shadow_disc("ranged_ground_shadow", 0.70, 0.66),
        create_puddle("ranged_base", PuddleSpec(0.66, 0.60, 0.062, 0.060, seed=44, asymmetry=0.035)),
        create_tapered_tube("ranged_arch_stalk", [(0.00, 0.00, 0.09), (0.02, 0.03, 0.50), (0.12, 0.18, 0.96), (0.24, 0.36, 1.26)], [0.130, 0.116, 0.088, 0.060], 22),
        create_ellipsoid("ranged_acid_sac", (0.30, 0.42, 1.38), (0.32, 0.25, 0.26), 36),
        create_tapered_tube("ranged_forward_nozzle", [(0.50, 0.56, 1.36), (0.74, 0.72, 1.31), (0.92, 0.80, 1.22)], [0.090, 0.062, 0.030], 16),
        create_tapered_tube("ranged_nozzle_lip_upper", [(0.88, 0.78, 1.25), (1.02, 0.84, 1.30)], [0.026, 0.010], 10),
        create_tapered_tube("ranged_nozzle_lip_lower", [(0.88, 0.78, 1.18), (1.02, 0.84, 1.14)], [0.026, 0.010], 10),
        create_tapered_tube("ranged_root_left", [(-0.06, 0.00, 0.08), (-0.32, -0.18, 0.10), (-0.54, -0.26, 0.06)], [0.075, 0.055, 0.030], 16),
        create_tapered_tube("ranged_root_right", [(0.08, 0.00, 0.08), (0.34, -0.12, 0.10), (0.56, -0.18, 0.06)], [0.075, 0.055, 0.030], 16),
        create_ellipsoid("ranged_root_cap_l", (-0.54, -0.26, 0.06), (0.050, 0.036, 0.026), 14),
        create_ellipsoid("ranged_root_cap_r", (0.56, -0.18, 0.06), (0.050, 0.036, 0.026), 14),
    ]
    obj = _join_objects("ranged_growth", parts)
    _add_subtle_finish(obj, 0.0015)
    return _finalize(obj, "ranged_growth", material)


def build_defense_growth(material: bpy.types.Material) -> bpy.types.Object:
    parts = [
        create_contact_shadow_disc("defense_ground_shadow", 0.96, 0.78),
        create_puddle("defense_base", PuddleSpec(0.92, 0.74, 0.055, 0.058, seed=55, asymmetry=0.025)),
        create_flattened_dome("defense_low_dome", (0.00, 0.00, 0.22), (0.54, 0.42, 0.22)),
        create_ridge_arc("defense_front_plate", 0.90, -0.24, 0.22, 118.0, 0.112, 0.12),
        create_ridge_arc("defense_mid_plate", 0.74, 0.01, 0.34, 118.0, 0.096, 0.10),
        create_ridge_arc("defense_rear_plate", 0.58, 0.24, 0.42, 106.0, 0.078, 0.08),
        create_tapered_tube("defense_left_crust_spur", [(-0.76, -0.22, 0.12), (-0.84, 0.10, 0.16), (-0.72, 0.40, 0.10)], [0.070, 0.060, 0.030], 12),
        create_tapered_tube("defense_right_crust_spur", [(0.76, -0.22, 0.12), (0.84, 0.10, 0.16), (0.72, 0.40, 0.10)], [0.070, 0.060, 0.030], 12),
    ]
    obj = _join_objects("defense_growth", parts)
    _add_subtle_finish(obj, 0.0014)
    return _finalize(obj, "defense_growth", material)


def build_gather_growth(material: bpy.types.Material) -> bpy.types.Object:
    pod_specs = [
        ("gather_pod_center", (0.00, 0.00, 0.26), (0.20, 0.18, 0.22)),
        ("gather_pod_l", (-0.25, -0.10, 0.23), (0.13, 0.12, 0.15)),
        ("gather_pod_r", (0.26, -0.08, 0.23), (0.13, 0.12, 0.15)),
        ("gather_pod_back_l", (-0.18, 0.20, 0.27), (0.11, 0.10, 0.15)),
        ("gather_pod_back_r", (0.18, 0.21, 0.28), (0.11, 0.10, 0.15)),
    ]
    parts = [
        create_contact_shadow_disc("gather_ground_shadow", 0.82, 0.72),
        create_puddle("gather_base", PuddleSpec(0.78, 0.68, 0.060, 0.060, seed=66, asymmetry=0.035)),
    ]
    for name, loc, scale in pod_specs:
        parts.append(create_ellipsoid(name, loc, scale, 30))
        parts.append(create_tapered_tube(f"{name}_neck", [(loc[0] * 0.55, loc[1] * 0.55, 0.08), (loc[0], loc[1], max(0.12, loc[2] - scale[2] * 0.72))], [0.050, 0.034], 14))
    for idx, angle in enumerate([-118.0, -62.0, -18.0, 34.0, 82.0, 128.0]):
        rad = radians(angle)
        start = (cos(rad) * 0.20, sin(rad) * 0.18, 0.10)
        mid = (cos(rad) * 0.48, sin(rad) * 0.42, 0.12)
        end = (cos(rad) * 0.72, sin(rad) * 0.62, 0.065)
        parts.append(create_tapered_tube(f"gather_sensor_feeler_{idx}", [start, mid, end], [0.044, 0.030, 0.012], 10))
    obj = _join_objects("gather_growth", parts)
    _add_subtle_finish(obj, 0.0018)
    return _finalize(obj, "gather_growth", material)


BUILDERS = {
    "basic_tile": build_basic_tile,
    "core_growth": build_core_growth,
    "melee_growth": build_melee_growth,
    "ranged_growth": build_ranged_growth,
    "defense_growth": build_defense_growth,
    "gather_growth": build_gather_growth,
}


def build_asset(asset_name: str) -> bpy.types.Object:
    if asset_name not in BUILDERS:
        raise KeyError(f"Unknown ooze asset: {asset_name}")
    reset_scene()
    material = make_ooze_material()
    return BUILDERS[asset_name](material)


def build_and_export_ooze_assets(export_dir: Path) -> list[Path]:
    exported: list[Path] = []
    for asset_name in OOZE_ASSET_NAMES:
        obj = build_asset(asset_name)
        exported.append(_export(obj, export_dir / f"{asset_name}.glb"))
    return exported
