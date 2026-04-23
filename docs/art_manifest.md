# Ooze Tactics Art Manifest (Asset-Driven Pivot)

This document tracks externally sourced assets integrated into the LIVE gameplay renderer path (`World3DRenderer`) during the asset-source correction pass.

## Sources

- Kenney Mini Dungeon
  - URL: https://kenney.nl/assets/mini-dungeon
  - Local pack: `assets/vendor/kenney/mini-dungeon/`
  - License: CC0 (see `assets/vendor/kenney/mini-dungeon/extracted/License.txt`)
- Kenney Roguelike Caves & Dungeons
  - URL: https://kenney.nl/assets/roguelike-caves-dungeons
  - Local pack: `assets/vendor/kenney/roguelike-caves-dungeons/`
  - License: CC0 (see `assets/vendor/kenney/roguelike-caves-dungeons/extracted/License.txt`)
  - Note: this pack is 2D spritesheet content; staged for reference, not used for 3D runtime geometry.
- Quaternius Modular Dungeons
  - URL: https://quaternius.com/packs/modulardungeon.html
  - Local pack: `assets/vendor/quaternius/modular-dungeons/`
  - License: CC0 (pack page license field)

## Runtime Mapping (LIVE Renderer)

| Runtime key | Source pack | Original source file | Runtime file | In-game usage |
|---|---|---|---|---|
| `blocker_wall` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/stones.glb` | `assets/meshes/imported/kenney_blocker_stones.glb` | Tactical blocker geometry (chokepoints) |
| `cave_wall` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/wall.glb` | `assets/meshes/imported/kenney_cave_wall.glb` | Chamber enclosure/perimeter wall segments |
| `door_arch` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/gate.glb` | `assets/meshes/imported/kenney_door_gate.glb` | Cave door / arch structures (objective framing) |
| `node_base` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/column.glb` | `assets/meshes/imported/kenney_node_column.glb` | Node/heart pedestal base |
| `heart_crystal` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/shield-round.glb` | `assets/meshes/imported/kenney_heart_core.glb` | Heart/core visual structure |
| `board_edge_trim` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/wall-half.glb` | `assets/meshes/imported/kenney_board_edge_trim.glb` | Terrain edge / board framing trim |
| `prop_gem` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/coin.glb` | `assets/meshes/imported/kenney_prop_coin.glb` | Gem pickup proxy |
| `prop_scroll` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/chest.glb` | `assets/meshes/imported/kenney_prop_chest.glb` | Scroll pickup proxy |
| `prop_rat` | Kenney Mini Dungeon | `assets/vendor/kenney/mini-dungeon/extracted/Models/GLB format/rocks.glb` | `assets/meshes/imported/kenney_prop_rocks.glb` | Rat/creature marker proxy |

## Staged Secondary Quaternius Structural Candidates

- `assets/meshes/imported/quaternius_blocker_wall.fbx`
- `assets/meshes/imported/quaternius_cave_wall.fbx`
- `assets/meshes/imported/quaternius_door_arch.fbx`
- `assets/meshes/imported/quaternius_node_base.fbx`
- `assets/meshes/imported/quaternius_heart_core.fbx`
- `assets/meshes/imported/quaternius_board_edge_trim.fbx`

## Notes

- Geometry replacement was applied only to the LIVE gameplay renderer path (`scripts/ui/World3DRenderer.gd`).
- Because direct `.glb/.fbx` loading is not guaranteed in this runtime context, live loading now includes a GLTF runtime fallback path for `.glb` files.
- Tile logic, pathing, and gameplay systems were intentionally not modified.
- Primitive fallback paths remain in place and trigger only when a mapped asset is missing.
