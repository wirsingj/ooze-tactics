# Blender Generation Pipeline (Ooze Tactics)

This pipeline generates deterministic Blender mesh kits and exports `.glb` files for Godot.

## Run

From repo root:

```powershell
blender --background --python tools/blender_gen/scripts/organic_ooze_assets.py
```

The current manifest selects five meshes in `assets/meshes/organic/`: core, melee, ranged, defense, and gather growth. The generator also writes `mesh_stats.json` and `role_studio.png`. Import with `godot --headless --path . --editor --import`, run the regression suite, then inspect at the gameplay camera. A studio render is not artistic acceptance.

Provenance: authored with OpenAI Codex (GPT-6 Astra), 2026-10-03, using original deterministic geometry and Blender 5.1.2; no external images or meshes were inputs. Fused bodies are remeshed, geometry validated, and normals recalculated before GLB export. Godot fits bounds and recolors the named `OozeSkin`, `OozeShell`, and `OozeLumen` surfaces while preserving their material distinction.

Legacy generators remain available for the older kit/environment and do not regenerate the current organic roles:

```powershell
blender -b --python tools/blender_gen/run_all.py
blender -b --python tools/blender_gen/run_ooze_assets.py
```

## Legacy Output

- Exported meshes: `assets/meshes/generated/*.glb`
- Export manifest: `tools/blender_gen/output/export_manifest.json`
- Primitive replacement mapping: `tools/blender_gen/output/replacement_map.md`
- Ooze-only export manifest: `tools/blender_gen/output/ooze_export_manifest.json`
- Ooze role contact sheet: `tools/blender_gen/output/ooze_role_contact_sheet.png`

## Legacy Generated Assets

- `outer_cave_wall_A.glb`
- `outer_cave_wall_B.glb`
- `inner_wall_blocker_A.glb`
- `floor_tile_rock_A.glb`
- `floor_tile_rock_B.glb`
- `cave_corner_transition_A.glb`
- `core_growth.glb`
- `basic_tile.glb`
- `melee_growth.glb`
- `ranged_growth.glb`
- `defense_growth.glb`
- `gather_growth.glb`

## Legacy Ooze Kit Direction

The ooze-only runner uses `tools/blender_gen/scripts/ooze_production_assets.py`.
It keeps the manifest-facing filenames stable while replacing prototype sphere/blob
forms with deliberate silhouettes:

- `basic_tile.glb`: low acid puddle, raised lip, only a couple of large bubbles.
- `core_growth.glb`: dominant living heart organ with thick root lobes.
- `melee_growth.glb`: 2-3 forward grabbing tendrils with hooked ends.
- `ranged_growth.glb`: tall stalk with a bulb/nozzle top.
- `defense_growth.glb`: low wide hardened shell/ridge bunker.
- `gather_growth.glb`: compact grouped siphon/digestion pods.

The meshes are generated from authored deterministic mesh primitives: puddle rims,
tapered tubes, organ domes, ridges, and grouped pods. Avoid adding dense random
bubbles/noise; role readability should come from silhouette first.
