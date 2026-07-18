---
yaiml: 0.2
role: maintainer
title: ooze-tactics Maintainer Guide
purpose: Current setup, validation, diagnostics, and YAIML maintenance for ooze-tactics.
belongs-here: Godot commands, test procedure, manual QA, important files, danger files, troubleshooting.
not-here: product direction, durable architecture, complete history.
durability: current-only; remove dead commands quickly.
read-with: SOT; Architecture.
update-when: Godot version, test commands, export flow, capture tooling, or release procedure changes.
agent-guidance: Mark Godot-dependent commands separately from portable file checks.
---

# ooze-tactics Maintainer Guide

## Setup

Open the repository in Godot 4.5 or newer by selecting `project.godot`, then press `F5`.

## Validation

Registered headless test runner:

```powershell
godot --headless --path . -s res://tests/run_tests.gd
```

All core tests are currently in `tests/run_tests.gd`. The suite includes gameplay rules, AI sanity, seeded AI role-mix smoke, run flow, atlas contract, and performance smoke coverage.

Auxiliary Godot-dependent checks:

```powershell
godot --headless --path . -s res://tools/verify_graphics_mode.gd -- --style 3d
godot --headless --path . -s res://tools/perf_repro_3d.gd -- --turns 20
godot --headless --path . -s res://tools/perf_x8_profile.gd -- --style 3d --turns 100 --speed 8 --seed 1337
```

Visible-render capture helpers write PNGs under `tools/visual_compare/` and print absolute paths plus hashes:

```powershell
godot --headless --path . -s res://tools/capture_ooze_compare.gd -- --turns 18 --out res://tools/visual_compare/capture.png
godot --headless --path . -s res://tools/capture_hero_shot.gd -- --turns 22 --out res://tools/visual_compare/steam_hero_shot.png
godot --headless --path . -s res://tools/capture_ooze_lategame.gd -- --turns 36 --out res://tools/visual_compare/live_imported_lategame.png
```

Treat saved capture files as artifacts for manual visual review; headless success only proves the scene/capture path executed and produced a non-empty image.

## Manual Review

- Confirm the stable 2D mode remains coherent.
- Review 3D role readability from gameplay camera screenshots.
- Check dynamic rebuild spikes separately from first-import cost.
- Verify Steam-facing screenshots and UX are not described as final before package/export evidence exists.

## Important Files

- `README.md`: runtime flow, controls, rules snapshot, and test command.
- `STEAM_READINESS_STATUS.md`: current vertical-slice readiness snapshot.
- `scripts/systems/`: core rules and AI systems.
- `scripts/ui/world3d/`: 3D presentation boundary.
- `tests/run_tests.gd`: core automated tests.

## YAIML Maintenance

Phrases such as "update YAIML", "updated YAIML", "check new YAIML", or "run a YAIML update" mean: compare this repository's local YAIML setup against a human-provided, workspace-provided, or team-approved YAIML reference, refresh compatible convention scaffolding, and preserve ooze-tactics-specific project memory.

Do not commit machine-specific YAIML reference paths, local drive names, user profile paths, `file://` URIs, secrets, private chat transcripts, or raw sensitive logs.
