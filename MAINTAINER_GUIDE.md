---
yaiml: 0.2
role: maintainer
title: ooze-tactics Maintainer Guide
purpose: Current setup, validation, diagnostics, and YAIML maintenance for ooze-tactics.
belongs-here: Godot commands, test procedure, manual QA, important files, danger files, troubleshooting.
not-here: product direction, durable architecture, complete history.
durability: current-only; remove dead commands quickly.
read-with: SOT; Architecture.
budget: About 1000 words; a working target, subject to evidence and retention needs.
update-when: Godot version, test commands, export flow, capture tooling, or release procedure changes.
last-verified: not established; claims not rechecked in this refresh.
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

Provide the YAIML reference from the human prompt, workspace context, or a team-approved source at run time. Do not commit machine-specific reference paths, local drive names, user profile paths, `file://` URIs, localhost URLs, private workspace URLs, secrets, private transcripts, or raw sensitive logs into versioned project memory.

Phrases such as "update YAIML", "updated YAIML", "check new YAIML", "refresh YAIML", or "run a YAIML update" mean convention refresh, not an ordinary project-memory rewrite. For this repository, compare local YAIML scaffolding against the provided reference and update only compatible prompts, templates, discovery hints, agent-instruction pointers, or YAIML-maintenance guidance. Preserve project memory and the existing discovery layout unless a human explicitly authorizes a layout migration.

Phrases such as "clean up YAIML", "compress YAIML", "compact project memory", "prune project memory", or "prune SoT" mean to remove stale or repetitive memory while preserving current truth, evidence, human direction, decisions, unresolved conflicts, and uncertainty. Do not pad documents to meet budgets or delete necessary governed knowledge just to reduce word count.

This repository does not need local YAIML prompt or template copies unless it already keeps them for a concrete workflow. Do not add `prompts/` or `templates/` just because the reference has them. Preserve project-specific SoT, Architecture, Maintainer Guide, risks, commands, naming, and supporting documents unless the reference changes how future agents should maintain YAIML here.
