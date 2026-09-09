# ooze-tactics (Godot 4.5 Prototype)

Turn-based tile tactics where slime factions expand, specialize tiles, and fight over heart/door objectives.

## AI Usage

This project is maintained with AI-assisted development. See [AI_USAGE.md](AI_USAGE.md) for the disclosure and provenance expectations.

## Current Runtime Flow
1. `MainMenu` (`res://scenes/MainMenu.tscn`) is the startup scene.
2. Choose:
   - `Start` for normal run flow.
   - `Dev Start` for dev config (team sizes, immortal toggle, spectator toggle).
3. Game scene (`res://scenes/Main.tscn`) runs level logic.
4. Outcomes go to `RunResult`, then next level or menu.

## Level Progression (Current)
- Level 1: `1v1`
- Level 2: `2v2` (player + allied AI vs two allied enemies)
- Level 3: `1v3`

## Win / Loss (Current)
- Victory:
  - destroy all hostile heart tiles, or
  - destroy the door.
- Loss:
  - all player heart tiles destroyed (non-spectator), or
  - all player-team hearts destroyed (spectator), or
  - turn limit reached (normal runs), or
  - 3-turn stall lock (non-spectator only).

## Controls (Gameplay Scene)
- Select tile type buttons: `Basic`, `Melee`, `Ranged`, `Gather`, `Defense`.
- Left click empty tile: queue placement.
- Left click owned tile: queue conversion.
- Right click tile: remove queued action on that tile.
- `End Turn`: commit queued actions and resolve turn.
- `Clear Queue`: remove staged actions.
- `Menu`: return-to-menu confirmation panel.

## Spectator / Dev Notes
- Spectator mode removes player control and runs AI vs AI.
- Spectator uses deterministic per-round randomized actor order (seed-based).
- Dev mode supports heart-click elimination for fast testing.

## Core Rules Snapshot
- Placement requires:
  - empty valid tile,
  - cardinal connection to owned blob,
  - minimum local support in Manhattan radius 2.
- Reclaim delay blocks immediate rebuild on recently destroyed cells.
- Roles:
  - `Defense` holds,
  - `Melee` breaks,
  - `Ranged` pressures from behind (with splash),
  - `Gather` is economic investment.

## Run in Godot
1. Open Godot 4.5+.
2. Import this folder by selecting this repository's `project.godot`.
3. Press `F5`.

## Tests
Headless test runner:

```powershell
godot --headless --path . -s res://tests/run_tests.gd
```

All core tests are currently in `tests/run_tests.gd`, including gameplay rules, AI sanity, seeded AI role-mix smoke, run flow, atlas contract, and performance smoke coverage.
