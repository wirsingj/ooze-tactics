# ooze-tactics (Godot 4.5 Prototype)

Turn-based colony strategy where slime factions expand, specialize living tissue, and contest territory and resources.

Living Colony brings the approved pixel-art kit into the playable campaign: connected tissue with filled corners, animated organs, faction palette shifts, and combat feedback. Your advance runs from bottom left to top right. See [visual direction](docs/visual/graphics_goal_v1.md) for evidence and remaining polish.

## AI Usage

This project is maintained with AI-assisted development. See [AI_USAGE.md](AI_USAGE.md) for the disclosure and provenance expectations.

## Current Runtime Flow
1. `MainMenu` (`res://scenes/MainMenu.tscn`) is the startup scene.
2. Choose:
   - `Territory War` for the new 260×160 strategic 2v2 prototype.
   - `Start` for the retained smaller campaign.
   - `Dev Start` for dev config (team sizes, immortal toggle, spectator toggle).
3. Territory War uses its own scene and ends there. Campaign level logic uses `Main.tscn`, followed by `RunResult` and next level or menu.

Select `Living Colony (2.5D)`, `Legacy 2D`, or `Cave 3D` in `Settings`. New settings default to Living Colony; existing saved choices are preserved.

## Territory War

The new map has 100 times the tile area of the earlier 26×16 2v2 fixture. You and a blue ally fight red/purple colonies across resource routes. Connect wells to your heart to collect recurring income and control; cutting that connection stops both. Each secured nonhome well adds 2 income per turn for every other secured allied well within 60 Manhattan tiles. Win by reaching 100 control with a lead, or destroying both opposing hearts. Home wells give income, not control points.

- Choose a front type and click a destination. Advance keeps growing supported territory toward it; additional active fronts divide your growth budget. Click a listed front to redirect it, or use `+ Add front` / Shift-click to create another.
- Drag a region, then choose a role to assign up to six organs intelligently. Defense/Melee prefer the front, Ranged favors safer firing positions, and Gather only uses wells. Existing organs are preserved.
- Review highlighted changes and cost, then End Turn. You have three orders per turn.
- Defense intercepts enemy fire; Melee breaks armor at two-tile reach. Ranged reaches eight tiles but cannot shoot through rock or enemy Defense, and stops firing in direct contact.
- Scroll zooms; middle-drag or WASD/right-drag pans. Home/Overview fits the map, and the minimap jumps between fronts. Right-click deselects or undoes the last order.

Territory War always uses Living Colony. This is a playable foundation with automated coverage, not accepted balance or final interface art. [Risk Review](RISK_REVIEW.md#territory-war-implemented-foundation-unaccepted-balance) records validation and limitations.

## Campaign Level Progression
- Level 1: Awakening, `1v1`
- Level 2: Narrow Halls, `1v1`
- Level 3: Forked Vault, `1v2`
- Level 4: Starving Gallery, `1v2`
- Level 5: The Sealed Heart, `1v1` miniboss encounter

The campaign has no allied AI; dev/spectator team sizing is separate. Current failures are documented in [RISK_REVIEW.md](RISK_REVIEW.md). A passing core suite is not a gameplay-readiness signoff.

## Campaign Win / Loss
- Victory:
  - destroy all hostile heart tiles, or
  - destroy the door.
- Loss:
  - all player heart tiles destroyed (non-spectator), or
  - all player-team hearts destroyed (spectator), or
  - turn limit reached without victory (normal runs; the displayed final turn is usable), or
  - 3-turn stall lock (non-spectator only).

## Campaign Controls
- Select tile type buttons: `Basic`, `Melee`, `Ranged`, `Gather`, `Defense`.
- Left click empty tile: queue placement.
- Left click owned tile: queue conversion.
- Right click tile: remove its queued action, remove invalid dependent actions, and reprice the surviving queue.
- `End Turn`: commit queued actions and resolve turn.
- `Clear Queue`: remove staged actions.
- `Menu`: return-to-menu confirmation panel.
- Living Colony camera: scroll to zoom under the pointer, middle-drag to pan, `Home` to fit the board. Select the ground diamond beneath an organ.

Normal turns allow five queued actions, shown by the action counter. Player-heart destruction takes precedence over simultaneous victory.

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

The runner covers gameplay rules, AI sanity, seeded role-mix smoke, run flow, atlas contract, and performance smoke. It also runs `tests/test_recovery.gd` for campaign openings, queue/reward contracts, evaluator agreement, and rendering geometry/markers.

`godot --headless --path . -s res://tools/pressure_2v2.gd` runs equal-budget 2v2 AI comparisons. The [Maintainer Guide](MAINTAINER_GUIDE.md) covers focused tests and the optional playable fixture; normal campaign progression remains unchanged.
