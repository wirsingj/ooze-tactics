---
yaiml: 0.2
role: architecture
title: ooze-tactics Architecture
purpose: Durable system shape, boundaries, gameplay systems, and visual pipeline for ooze-tactics.
belongs-here: components, game loop, rules, rendering boundary, test surfaces, invariants, danger zones.
not-here: volatile priorities, command reference, full work history.
durability: stable; update when systems, scenes, rendering pipeline, or validation shape changes.
read-with: SOT; Maintainer Guide.
budget: About 1000 words; a working target, subject to evidence and retention needs.
update-when: gameplay rules, Godot scenes, rendering architecture, AI, or export flow changes.
last-verified: 2026-10-03 source boundaries inspected and bounded runtime probes executed; acceptance gaps are in Risk Review.
agent-guidance: Keep shared layout/gameplay truth separate from 3D presentation work.
evidence-guidance: Distinguish intended boundaries from inspected implementation; preserve uncertain or disputed design decisions.
---

# ooze-tactics Architecture

## Components

- `project.godot`: Godot project definition.
- `scenes/MainMenu.tscn`, `scenes/Main.tscn`, `scenes/visual/VerticalSliceBoard.tscn`: main runtime and visual scenes.
- `scripts/systems/`: game rules, economy, combat, AI, run flow, level generation, topology, and action validation.
- `scripts/ui/`: menu, board rendering, settings, run result, atlas and 3D rendering layers.
- `scripts/ui/world3d/`: static environment, lighting, assets, marker, and dynamic ooze rendering.
- `tests/run_tests.gd`: headless runner including `tests/test_recovery.gd` regression groups.
- `tools/ai_tuner.gd` and `config/ooze_ai_baseline.json`: candidate scoring/search and deployed-in-checkout heuristic settings; training success is not opponent-strength evidence.
- `docs/` and `baselines/`: art pipeline, visual goals, and validation baselines.

## Turn And Presentation Boundaries

Campaign gameplay batches the human queue and AI intents through `TurnResolver` into one global `TickSystem` combat/economy step. Spectator and tuner paths step one acting owner at a time while still ticking the global simulation. The tuner builds its own scenario options rather than the five-level `RunFlow` campaign; parity remains unresolved.

`TerritoryWar.tscn` and `TerritoryController` provide strategic 2v2 through `TerritoryScenario`, `TerritoryOrders`, `TerritoryAI`, and `TerritoryTurn`. `GameState.territory_mode` selects explicit rules inside shared Combat/Economy/LevelDirector; copying preserves it and team scores. Orders expand on copied state, then all owners resolve once through TickSystem. The 260×160 map has three routes through two rock ridges. Colony provides overview and a state-refreshed minimap. AI uses micro contact signals to choose organs, macro farm/front planning to reserve allied sites and grow linked wells, and global score pressure to choose assault or defense; it does not see queued human orders.

Campaign AI enables `TacticalPlanner` through the per-owner `tactical_search` flag. Near hostile tissue it compares the heuristic bundle, waiting, and up to three greedily selected actions using at most 38 two-tick simulations. These use actual combat/economy on copied visible state, never queued human orders. Shortlisting uses wall-aware heart distance; evaluation values survival, firepower, treasury, and progress. It does not simulate new opponent orders. Generic fixtures and the tuner default to the heuristic path. The separate `pressure_2v2.gd` comparison batches all four owners once per global turn against a frozen reference; it does not repair tuner parity.

All three renderers receive legal growth targets and enemy intents. Noncompact combat reports snapshot HP after purchases and expose actual damage, dissolution, and door damage. They also record melee/ranged source-target decisions at resolution, including door attacks; compact training omits presentation events without changing combat. Colony displays attack paths and impact cues; legacy 3D consumes damage labels. Ordered attack sequencing remains incomplete. SpriteWrite's frame export has no delivery adapter. See [Risk Review](RISK_REVIEW.md).

`Combat.reconcile_owner_queue` replays staged actions, recalculates owner costs, and removes invalid dependencies after successful controller queue edits. Human limits use owner configuration. `AIEvaluation` supplies outcome, door eligibility, and wall-aware distance contracts to the tuner; this does not unify turn cadence.

The runtime manifest selects five original Blender-generated organic role meshes. `DynamicOozeRenderer` fits transformed imported bounds to tile footprints and preserves named skin/shell/lumen surfaces while applying owner colors. Basic territory and resource visuals remain procedural. [Art manifest](docs/art_manifest.md) and [Blender pipeline](tools/blender_gen/README.md) own asset mapping and regeneration.

`ColonyRenderer` is a clipped Control consuming GameState. `ColonyArt` caches five PNG organs and display bounds from `assets/art/colony-v1/`; source pixels remain unchanged. A board-sized data texture encodes owner, growth, hue, and traversable floor. `colony_floor.gdshader` draws terrain in one pass; idle overlays retain draw commands. `colony_board.gdshader` fills same-owner cardinal joins and shared corners while masking walls/foreign cells; it has no preview-array tile limit. Cosmetic growth/loss and rooted deformation never alter simulation. Projection, depth sorting, shader coordinates, and inverse picking share a bottom-left to top-right advance; zoom/pan survive turn syncs. Organ nodes persist by block ID. New installations default to `colony`; Settings retains explicit legacy choices. The fixed `tools/colony_art_preview.gd` remains a separate study. [Visual direction](docs/visual/graphics_goal_v1.md) owns evidence and remaining acceptance.

## Core Rules

Placement requires empty valid tiles, cardinal connection to owned blob, and local support. Reclaim delay blocks immediate rebuilds on recently destroyed cells. Roles include defense, melee, ranged, gather, basic, and core.

Territory War gives three orders and a 180-tile tissue budget divided among growth fronts (four supported waves; tissue is free). Weighted orders allocate the budget proportionally. Each secured nonhome well earns its controller +2 income per nearby secured allied well within 60 Manhattan tiles. With a linked farm pair and an unreserved central well, one AI scout sends 25% of its allowance toward the center while 75% extends the farm front. A region order assigns up to six organs, converting supplied Basic tissue and preserving organs. Organs cost four energy, Ranged five; previews use staged application. Cardinal same-owner tissue supplies from hearts. Base income is eight, each supplied well adds ten, Gather on it adds six; offsite Gather does nothing. Nonhome wells score once each turn; win at 100 control with a lead or by destroying both rival hearts. Melee reaches two cardinal tiles and breaks armor; Ranged reaches eight through clear shots and is suppressed by adjacent enemies. Rocks and hostile Defense block fire; ranged armor applies per shot. Campaign rules are separate.

## Invariants

- Shared state and simulation own gameplay semantics; the reference 2D presentation is not proof of rule correctness or balance.
- 3D mode should share layout truth rather than fork gameplay semantics.
- Visual capture quality must not substitute for balance data.
- Steam-readiness claims should stay tied to actual package/export and screenshot evidence.

## Danger Zones

- Regressing stable 2D gameplay while improving 3D presentation.
- Letting role visuals become unreadable from gameplay camera distance.
- Treating headless/dummy capture as proof of final visual output.
- Promoting tuner scores without campaign parity, independent opponents, and comparable validation workloads.
- Making Steam-demo claims before packaging, onboarding, settings, screenshots, and licensing review are ready.
