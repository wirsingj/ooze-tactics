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

Headless test runner:

```powershell
<path-to-godot-console.exe> --headless --path "<repo-root>" -s res://tests/run_tests.gd
```

All core tests are currently in `tests/run_tests.gd`.

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
