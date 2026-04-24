# Ooze Tactics 3D Art Manifest

## Canonical Runtime Source

All `World3DRenderer` asset paths now come from one canonical manifest:

- `data/world3d_asset_manifest.json`

Renderer behavior:

- geometry paths are resolved from `geometry.*.path`
- texture paths are resolved from `textures.*.path`
- per-asset normalization transforms are resolved from `geometry.*.normalize`

No runtime geometry/texture path strings are hardcoded in `scripts/ui/World3DRenderer.gd`.

## Runtime Geometry Mapping

| Runtime key | Manifest path | Source kind | In-game usage |
|---|---|---|---|
| `blocker_wall` | `assets/meshes/generated/blocker_cluster.glb` | generated | Tactical blockers / chokepoints |
| `cave_wall` | `assets/meshes/generated/cave_wall_segment.glb` | generated | Cave perimeter wall segment |
| `cave_corner` | `assets/meshes/generated/cave_wall_corner.glb` | generated | Cave corner wall segment |
| `door_arch` | `assets/meshes/imported/kenney_door_gate.glb` | imported | Dungeon door objective arch |
| `floor_tile_rock` | `assets/meshes/generated/floor_tile_rock.glb` | generated | Cave floor tile variation |
| `node_base` | `assets/meshes/generated/node_base.glb` | generated | Node/core pedestal |
| `heart_crystal` | `assets/meshes/generated/crystal_hero.glb` | generated | Heart/core visual |
| `role_crystal` | `assets/meshes/generated/crystal_small.glb` | generated | Role marker crystal |
| `board_edge_trim` | `assets/meshes/imported/kenney_board_edge_trim.glb` | imported | Board edge framing |
| `prop_gem` | `assets/meshes/imported/kenney_prop_coin.glb` | imported | Gem resource marker |
| `prop_scroll` | `assets/meshes/imported/kenney_prop_chest.glb` | imported | Scroll resource marker |
| `prop_rat` | `assets/meshes/imported/kenney_prop_rocks.glb` | imported | Rat/resource marker proxy |

## Runtime Texture Mapping

| Texture key | Manifest path | Source kind |
|---|---|---|
| `stone_albedo` | `assets/world3d/generated/stone_albedo.png` | generated |
| `stone_roughness` | `assets/world3d/generated/stone_roughness.png` | generated |
| `stone_normal` | `assets/world3d/generated/stone_normal.png` | generated |
| `slime_detail` | `assets/world3d/generated/slime_detail.png` | generated |

## Source Packs

- Kenney Mini Dungeon
  - URL: https://kenney.nl/assets/mini-dungeon
  - Local pack: `assets/vendor/kenney/mini-dungeon/`
  - License: CC0 (`assets/vendor/kenney/mini-dungeon/extracted/License.txt`)
- Kenney Roguelike Caves & Dungeons
  - URL: https://kenney.nl/assets/roguelike-caves-dungeons
  - Local pack: `assets/vendor/kenney/roguelike-caves-dungeons/`
  - License: CC0 (`assets/vendor/kenney/roguelike-caves-dungeons/extracted/License.txt`)
  - Note: currently staged reference content (2D pack), not direct 3D runtime geometry.
- Quaternius Modular Dungeons
  - URL: https://quaternius.com/packs/modulardungeon.html
  - Local pack: `assets/vendor/quaternius/modular-dungeons/`
  - License: CC0

## Notes

- Mixed generated/imported assets are explicitly declared per entry in the manifest via `source_kind`.
- Any runtime asset-path change must update `data/world3d_asset_manifest.json` first, then this doc.
