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
last-verified: not established; claims not rechecked in this refresh.
agent-guidance: Keep shared layout/gameplay truth separate from 3D presentation work.
---

# ooze-tactics Architecture

## Components

- `project.godot`: Godot project definition.
- `scenes/MainMenu.tscn`, `scenes/Main.tscn`, `scenes/visual/VerticalSliceBoard.tscn`: main runtime and visual scenes.
- `scripts/systems/`: game rules, economy, combat, AI, run flow, level generation, topology, and action validation.
- `scripts/ui/`: menu, board rendering, settings, run result, atlas and 3D rendering layers.
- `scripts/ui/world3d/`: static environment, lighting, assets, marker, and dynamic ooze rendering.
- `tests/run_tests.gd`: headless test runner.
- `docs/` and `baselines/`: art pipeline, visual goals, and validation baselines.

## Core Rules

Placement requires empty valid tiles, cardinal connection to owned blob, and local support. Reclaim delay blocks immediate rebuilds on recently destroyed cells. Roles include defense, melee, ranged, gather, basic, and core.

## Invariants

- 2D gameplay remains the stable rules truth.
- 3D mode should share layout truth rather than fork gameplay semantics.
- Visual capture quality must not substitute for balance data.
- Steam-readiness claims should stay tied to actual package/export and screenshot evidence.

## Danger Zones

- Regressing stable 2D gameplay while improving 3D presentation.
- Letting role visuals become unreadable from gameplay camera distance.
- Treating headless/dummy capture as proof of final visual output.
- Making Steam-demo claims before packaging, onboarding, settings, screenshots, and licensing review are ready.
