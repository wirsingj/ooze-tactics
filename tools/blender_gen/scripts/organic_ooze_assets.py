"""Deterministic organic role kit; run with Blender --background --python FILE.

Exports original meshes to assets/meshes/organic and a studio contact sheet.
Z is up in Blender; the attacking direction is -Y (Godot +Z).
Materials named OozeSkin/Shell/Lumen are recolored by the game without losing
their distinct surface treatments. No downloaded meshes or textures are used.
"""
from pathlib import Path
from math import sin, cos, pi
import json
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/meshes/organic"
OUT.mkdir(parents=True, exist_ok=True)


def material(name, color, roughness, emission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = roughness
    p.inputs["Coat Weight"].default_value = 0.3 if name == "OozeSkin" else 0.08
    p.inputs["Emission Color"].default_value = (*color, 1)
    p.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*color, 1)
    return mat


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def finish(obj, mat):
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def ellipsoid(name, center, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat)


def tube(name, points, radii, mat, open_end=False):
    verts, faces = [], []
    points = [Vector(p) for p in points]
    segments = 12
    for i, p in enumerate(points):
        tangent = (points[min(i + 1, len(points)-1)] - points[max(0, i-1)]).normalized()
        guide = Vector((0, 0, 1)) if abs(tangent.z) < 0.92 else Vector((1, 0, 0))
        u = tangent.cross(guide).normalized()
        v = tangent.cross(u).normalized()
        for j in range(segments):
            a = 2*pi*j/segments
            verts.append(p + radii[i] * (cos(a)*u + sin(a)*v))
    for i in range(len(points)-1):
        for j in range(segments):
            a = i*segments+j
            b = i*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(reversed(range(segments))))
    if not open_end:
        faces.append(tuple((len(points)-1)*segments+j for j in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat)


def fuse(parts, name, mat):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    remesh = obj.modifiers.new("Continuous flesh", "REMESH")
    remesh.mode = "VOXEL"
    remesh.voxel_size = 0.023
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = obj.modifiers.new("Soft tissue", "SMOOTH")
    smooth.factor = 1.1
    smooth.iterations = 4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for vert in obj.data.vertices:
        p = vert.co
        p += vert.normal * (0.003*sin(p.x*31+p.z*9)*sin(p.y*27-p.z*13))
    decimate = obj.modifiers.new("Game mesh", "DECIMATE")
    decimate.ratio = 0.6
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    obj.data.materials.clear()
    return finish(obj, mat)


def role_mesh(role, skin, shell, lumen):
    body = [ellipsoid("Basal tissue", (0,0,0.085), (0.38,0.33,0.11), skin)]
    for i in range(5):
        a = 2*pi*i/5 + 0.2
        body.append(tube("Root", [(0,0,0.10),(cos(a)*0.26,sin(a)*0.23,0.07),
                                  (cos(a)*0.43,sin(a)*0.38,0.025)], [0.12,0.08,0.012], skin))
    details = []
    if role == "core":
        body += [ellipsoid("Heart lobe", (-0.10,0.015,0.30), (0.22,0.25,0.31), skin),
                 ellipsoid("Heart lobe", (0.13,0.04,0.28), (0.19,0.22,0.27), skin)]
        details.append(ellipsoid("Living nucleus", (0,-0.14,0.34), (0.12,0.13,0.15), lumen))
        for side in [-1,1]:
            for i in range(3):
                y = -0.10+i*0.12
                details.append(tube("Heart fold", [(side*0.28,y,0.12),(side*0.27,y,0.28),
                    (side*0.17,y,0.47),(side*0.06,y,0.55-i*0.04)], [0.06,0.065,0.045,0.012], shell))
    elif role == "melee":
        body.append(ellipsoid("Predator mantle", (0,0.035,0.17), (0.30,0.26,0.16), skin))
        for side in [-1,1]:
            body.append(tube("Claw muscle", [(side*0.13,0,0.10),(side*0.26,-0.16,0.19),
                (side*0.28,-0.26,0.28)], [0.11,0.08,0.045], skin))
            details.append(tube("Sickle", [(side*0.26,-0.16,0.18),(side*0.30,-0.28,0.32),
                (side*0.23,-0.40,0.39),(side*0.12,-0.45,0.33)], [0.064,0.057,0.032,0.003], shell))
        for i in range(3):
            plate = ellipsoid("Dorsal plate", (0,0.15-i*0.11,0.28), (0.18-i*0.015,0.065,0.07), shell)
            details.append(plate)
    elif role == "ranged":
        body.append(ellipsoid("Pressure sac", (0,0.08,0.25), (0.26,0.27,0.24), skin))
        body.append(tube("Siphon neck", [(0,0.08,0.20),(0,0.08,0.39),(0,-0.035,0.52),
            (0,-0.20,0.54)], [0.16,0.14,0.12,0.12], skin, True))
        details.append(tube("Acid muzzle", [(0,-0.18,0.54),(0,-0.27,0.52)], [0.125,0.15], shell, True))
        details.append(ellipsoid("Acid throat", (0,-0.217,0.528), (0.095,0.012,0.095), lumen))
        for side in [-1,1]:
            details.append(tube("Sac seam", [(side*0.22,0.16,0.12),(side*0.24,0.12,0.29),
                (side*0.13,0.07,0.43)], [0.018,0.018,0.006], shell))
    elif role == "defense":
        body.append(ellipsoid("Armored body", (0,0,0.16), (0.32,0.28,0.16), skin))
        for i in range(4):
            y = 0.21-i*0.135
            details.append(ellipsoid("Overlapping carapace", (0,y,0.25+0.025*sin(i)),
                (0.34-abs(i-1.5)*0.025,0.11,0.14), shell))
            details.append(tube("Shell ridge", [(-0.25,y,0.30),(0,y-0.015,0.40),(0.25,y,0.30)],
                [0.012,0.018,0.012], skin))
    elif role == "gather":
        for x,y,z,sz in [(-0.17,-0.10,0.22,0.15),(0.16,-0.08,0.23,0.17),(0,0.16,0.26,0.19)]:
            body.append(ellipsoid("Digestion pod", (x,y,z), (sz,sz,sz*1.25), skin))
            details.append(ellipsoid("Pod window", (x,y-0.025,z+sz*0.86), (sz*0.56,sz*0.60,sz*0.46), lumen))
            details.append(tube("Feeding rib", [(x-0.11,y,0.09),(x-0.12,y,z),
                (x-0.065,y,z+sz)], [0.026,0.024,0.012], shell))
    flesh = fuse(body, role+" flesh", skin)
    return [flesh] + details


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    skin = material("OozeSkin", (0.085,0.32,0.22), 0.30)
    shell = material("OozeShell", (0.025,0.050,0.055), 0.43)
    lumen = material("OozeLumen", (0.52,0.84,0.42), 0.25, 0.35)
    kits, metrics = [], {}
    for role in ["core","melee","ranged","defense","gather"]:
        parts = role_mesh(role, skin, shell, lumen)
        bpy.ops.object.select_all(action="DESELECT")
        for part in parts:
            part.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = role+"_growth"
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.data.validate(clean_customdata=True)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        bpy.ops.export_scene.gltf(filepath=str(OUT/(role+"_growth.glb")), export_format="GLB",
                                  use_selection=True, export_apply=True)
        metrics[role] = {"vertices":len(obj.data.vertices),"triangles":sum(len(p.vertices)-2 for p in obj.data.polygons)}
        kits.append(obj)
        obj.hide_render = True
    (OUT/"mesh_stats.json").write_text(json.dumps(metrics,indent=2)+"\n")
    # Studio sheet is an authoring aid; acceptance uses the actual game camera.
    for i,obj in enumerate(kits):
        obj.hide_render = False
        obj.location = ((i-2)*1.15,0,0)
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor = bpy.context.object
    floor.location.z = -0.025
    floor.data.materials.append(material("Studio stone",(0.022,0.029,0.038),0.66))
    for pos,power,size in [((-3,-4,6),700,5),((4,1,4),950,4),((0,3,5),800,3)]:
        bpy.ops.object.light_add(type="AREA",location=pos)
        light=bpy.context.object
        light.data.energy=power
        light.data.shape="DISK"
        light.data.size=size
        light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(1.3,-6.5,5.0))
    camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,0.15))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type="ORTHO"
    camera.data.ortho_scale=6.2
    scene=bpy.context.scene
    scene.camera=camera
    scene.render.engine="CYCLES"
    scene.cycles.samples=32
    scene.cycles.use_denoising=True
    scene.world.color=(0.12,0.12,0.12)
    scene.render.resolution_x=1800
    scene.render.resolution_y=650
    scene.render.resolution_percentage=100
    scene.render.filepath=str(OUT/"role_studio.png")
    bpy.ops.render.render(write_still=True)
    print("ORGANIC_KIT_COMPLETE",json.dumps(metrics))


if __name__ == "__main__":
    main()
