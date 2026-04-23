# Blender Generation Pipeline (Ooze Tactics)

This pipeline generates a small modular stylized cave-board mesh kit in Blender and exports `.glb` files for Godot.

## Run

From repo root:

```powershell
blender -b --python tools/blender_gen/run_all.py
```

## Output

- Exported meshes: `assets/meshes/generated/*.glb`
- Export manifest: `tools/blender_gen/output/export_manifest.json`
- Primitive replacement mapping: `tools/blender_gen/output/replacement_map.md`

## Generated assets

- `crystal_small.glb`
- `crystal_hero.glb`
- `node_base.glb`
- `blocker_wall.glb`
- `cave_wall_segment.glb`
- `cave_door_arch.glb`
- `board_edge_trim.glb`
- `ooze_puddle_a.glb`
- `ooze_puddle_b.glb`
- `ooze_puddle_c.glb`
