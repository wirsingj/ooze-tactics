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
last-verified: 2026-10-17; current checks and limits are recorded below; unrelated claims retain their prior scope.
agent-guidance: Mark Godot-dependent commands separately from portable file checks.
evidence-guidance: Preserve command outcomes and verification limits; route disputed procedures to human review.
---

# ooze-tactics Maintainer Guide

On 2026-10-17, Windows/Godot 4.6.2 passed the full headless runner plus `test_colony.gd`, `test_pressure.gd` and `test_territory.gd`. `test_colony_surface.gd` passed with the real OpenGL renderer on RTX 3090. These checks do not establish human balance, complete campaign or cross-device acceptance.

## Setup

Open the repository in Godot 4.5 or newer by selecting `project.godot`, then press `F5`.

## Validation

Registered headless test runner:

```powershell
godot --headless --path . -s res://tests/run_tests.gd
```

The runner includes gameplay rules, AI sanity, seeded role-mix smoke, run flow, atlas contract, performance smoke, and `tests/test_recovery.gd` regression groups.

The original 56 calls and twelve recovery groups pass; [Risk Review](RISK_REVIEW.md) owns evidence and limits. Tuner syntax passes with `godot --headless --path . --check-only -s res://tools/ai_tuner.gd`; this is not training or balance acceptance. Default to headless checks. Open windows only for visual inspection and close task-launched windows afterward.

Auxiliary Godot-dependent checks:

```powershell
godot --headless --path . -s res://tools/verify_graphics_mode.gd -- --style 3d
godot --headless --path . -s res://tools/perf_repro_3d.gd -- --turns 20
godot --headless --path . -s res://tools/perf_x8_profile.gd -- --style 3d --turns 100 --speed 8 --seed 1337
```

Capture helpers save viewport PNGs under `tools/visual_compare/` and print paths/hashes. Headless rendering cannot supply these textures. These candidate commands still need end-to-end validation with a display:

```powershell
godot --path . -s res://tools/capture_ooze_compare.gd -- --turns 18 --out res://tools/visual_compare/capture.png
godot --path . -s res://tools/capture_hero_shot.gd -- --turns 22 --out res://tools/visual_compare/steam_hero_shot.png
godot --path . -s res://tools/capture_ooze_lategame.gd -- --turns 36 --out res://tools/visual_compare/live_imported_lategame.png
```

Verify a successful exit and a non-empty saved image, then inspect the image. Neither headless execution nor an unreviewed PNG establishes final visual quality.

For comparisons, fix `run_seed` after starting the run and before loading `Main`, use the actual gameplay camera and include UI, record engine/renderer/revision, and stop at the first terminal outcome. Existing helpers lack a seed option; the hero helper stages extra presentation. The audit used isolated diagnostic scripts, not these commands as acceptance tests. Its current captures are linked from Risk Review.

The AI tuner's training mode can overwrite the baseline. Audit evaluation must disable training or use an isolated baseline copy and bounded workload. Fix evaluator/gameplay disagreements before treating search scores as improvement.

## Manual Review

- Restart to load repairs; select Living Colony (2.5D), Legacy 2D, or Cave 3D in Settings. Saved choices persist; new settings default to Colony.
- Review 3D role readability from gameplay camera screenshots.
- Check dynamic rebuild spikes separately from first-import cost.
- Verify Steam-facing screenshots and UX are not described as final before package/export evidence exists.

Regenerate the current role kit with `blender --background --python tools/blender_gen/scripts/organic_ooze_assets.py`, then import with `godot --headless --path . --editor --import`. See [Blender pipeline](tools/blender_gen/README.md) for provenance and legacy runners. Bounds tests and studio renders do not establish gameplay-camera acceptance.

Run `tests/test_colony.gd`, `tests/test_pressure.gd`, and `tests/test_territory.gd` with `godot --headless --path . -s res://<script>`. `tests/test_colony_surface.gd` requires a display and exits after checking shader pixels. Three renderer-mode startup checks preserve settings.

Run `tools/pressure_2v2.gd` headlessly for six equal-budget, side-swapped matches against the frozen policy; results replace `docs/validation/pressure_2v2.json`. The comparison uses normal campaign terminal rules, not symmetric team elimination. It cannot establish human difficulty.

`tools/territory_check.gd` runs one fixed-map all-AI match headlessly, stops early on victory or caps at 40 turns, and replaces `docs/validation/territory_war.json`. `tools/territory_gameplay_check.gd` checks menu/input/group-order flow headlessly; omit `--headless` and add `-- --capture` for an automatically closing screenshot run.

Run `tools/profile_territory_render.gd` with a display for uncapped frame/draw-call measurements; `-- --turns 15 --capture --overview` saves the developed full-map view. It closes automatically; headless checks cannot establish rendering throughput.

`tools/colony_gameplay_check.gd` opens seed-1337 campaign play; `-- --2v2` selects the comparison fixture, `--capture` saves and exits. The separate `tools/colony_art_preview.gd` study offers cosmetic motion/grayscale controls. [Visual direction](docs/visual/graphics_goal_v1.md) owns evidence and provenance.

## Important Files

- `README.md`: runtime flow, controls, rules snapshot, and test command.
- `STEAM_READINESS_STATUS.md`: current vertical-slice readiness snapshot.
- `scripts/systems/`: core rules and AI systems.
- `scripts/ui/world3d/`: 3D presentation boundary.
- `tests/run_tests.gd`: core automated tests.
- `RISK_REVIEW.md`: active audit findings, evidence limits, and proposed recovery gates.

## YAIML Maintenance

Read and follow [Using YAIML](.yaiml/YAIML_GUIDE.md) and the [skill catalog](.yaiml/skills/INDEX.md). Twelve native entries forward arguments to eleven methods plus a compatibility alias; dormant templates support offline use. Root `AGENTS.md` activates ordinary context and maintenance. Resource/link/native-entry and ShepAIrd discovery checks passed on 2026-10-17. Fresh-session activation and application behavior remain untested by this upgrade.

Source: [YAIML](https://github.com/wirsingj/YAIML), published revision `89c883d9a66dffc3b8671d975f7fa6c46535d676`; 27-resource bundle SHA-256 `3958b3c802cef951147d316c41a48e0aa7ad6c2aa72c84954c3cac003c169e07` (sorted package-relative paths, NUL, Git blob bytes; CRLF/LF differences verified). Pre-upgrade baseline unavailable. Local exceptions: guide, bootstrap, init, refresh and grow preserve stricter source rules; request an identified authorized reference when absent, with no automatic public fallback. Preserve adaptations on refresh; healthy repeats make no edits. No polling, background activity or automatic backlog work.

Preserve the legacy discovery layout and quoted `"0.2"` label, root core files, older starters/coordination copies and their [MIT notice](YAIML_NOTICE.md). Root [YAIML_GUIDE.md](YAIML_GUIDE.md) forwards to current methods. The [current notice](.yaiml/YAIML_NOTICE.md) covers incoming resources, permits commercial/client use with credit, and leaves private [LICENSE.txt](LICENSE.txt) unchanged. Visibility remains unverified; version memory without sensitive content.

[YAIMLACP](.yaiml/YAIMLACP.md) requires scoped affirmative confirmation; no standing approval exists. Earlier native handoffs/results were exercised, but cancellation and enforced cost limits remain unverified. No branch permissions or designated reviewer were found; human review under [AI_USAGE.md](AI_USAGE.md) owns acceptance. Memory grants no commit, push, merge or deployment authority; reconcile target/common ancestor before integration.
