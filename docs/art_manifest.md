# Ooze Tactics 3D Art Manifest

## Canonical Runtime Source

All `World3DRenderer` asset paths now come from one canonical manifest:

- `data/world3d_asset_manifest.json`

Renderer behavior:

- geometry paths are resolved from `geometry.*.path`
- texture paths are resolved from `textures.*.path`
- per-asset normalization transforms are resolved from `geometry.*.normalize`

No runtime geometry/texture path strings are hardcoded in `scripts/ui/World3DRenderer.gd`.

## Manifest Geometry Mapping

Catalog presence alone does not prove a live consumer. Five organic growth roles are instantiated above procedural territory; Basic/resource geometry is built by the renderer.

| Runtime key | Manifest path | Variant paths | Source kind | In-game usage |
|---|---|---|---|---|
| `blocker_wall` | `assets/meshes/generated/inner_wall_stone_A.glb` | `assets/meshes/generated/inner_wall_stone_B.glb` | generated | Tactical blockers / chokepoints |
| `cave_wall` | `assets/meshes/generated/outer_wall_stone_A.glb` | `assets/meshes/generated/outer_wall_stone_B.glb` | generated | Cave perimeter wall segment (deterministic A/B runtime mix) |
| `cave_corner` | `assets/meshes/generated/outer_wall_stone_B.glb` | `assets/meshes/generated/outer_wall_stone_A.glb` | generated | Cave corner transition segment |
| `door_arch` | `assets/meshes/generated/door_arch_dungeon.glb` | - | generated | Dungeon door objective arch |
| `floor_tile_rock` | `assets/meshes/generated/floor_tile_cobbled_A.glb` | `assets/meshes/generated/floor_tile_cobbled_B.glb` | generated | Cave floor tile variation (deterministic A/B runtime mix) |
| `core_growth` | `assets/meshes/organic/core_growth.glb` | - | generated | Core/heart ooze growth asset placed on living ooze territory |
| `basic_tile` | `assets/meshes/generated/basic_tile.glb` | - | generated | Retained catalog entry; current Basic/resource visuals are procedural |
| `melee_growth` | `assets/meshes/organic/melee_growth.glb` | - | generated | Melee ooze tendril growth asset |
| `ranged_growth` | `assets/meshes/organic/ranged_growth.glb` | - | generated | Organic vent/sac role growth |
| `defense_growth` | `assets/meshes/organic/defense_growth.glb` | - | generated | Organic layered carapace role growth |
| `gather_growth` | `assets/meshes/organic/gather_growth.glb` | - | generated | Gather ooze nodule cluster growth asset |
| `node_base` | `assets/meshes/generated/node_base.glb` | - | generated | Retained catalog entry; current Basic/resource visuals are procedural |
| `heart_crystal` | `assets/meshes/generated/crystal_hero.glb` | - | generated | Retained catalog entry; current Basic/resource visuals are procedural |
| `role_crystal` | `assets/meshes/generated/crystal_small.glb` | - | generated | Retained catalog entry; current Basic/resource visuals are procedural |
| `board_edge_trim` | `assets/meshes/imported/kenney_board_edge_trim.glb` | - | imported | Board edge framing |
| `prop_gem` | `assets/meshes/imported/kenney_prop_coin.glb` | - | imported | Retained catalog entry; current Basic/resource visuals are procedural |
| `prop_scroll` | `assets/meshes/imported/kenney_prop_chest.glb` | - | imported | Retained catalog entry; current Basic/resource visuals are procedural |
| `prop_rat` | `assets/meshes/imported/kenney_prop_rocks.glb` | - | imported | Retained catalog entry; current Basic/resource visuals are procedural |

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
- Where `geometry.*.variants` is present, `World3DRenderer` chooses variants deterministically from transform position and asset key.
- Five live growth roles use the original organic Blender kit; see [generation and provenance](../tools/blender_gen/README.md). Runtime fitting constrains imported bounds, and named skin/shell/lumen surfaces preserve material contrast while following owner colors. The studio render and geometric tests do not establish gameplay-camera acceptance.
- Any runtime asset-path change must update `data/world3d_asset_manifest.json` first, then this doc.
