---
yaiml: 0.2
role: sot
title: ooze-tactics SOT
purpose: Current engineering state, direction, risks, and priorities for ooze-tactics.
belongs-here: game identity, verified capabilities, Steam readiness, active risks, validation state, next steps.
not-here: durable architecture, command reference, complete history.
durability: volatile; synthesize and prune aggressively.
read-with: Architecture; Maintainer Guide.
update-when: gameplay state, visual direction, Steam readiness, tests, risks, or priorities change.
agent-guidance: Preserve the distinction between stable 2D gameplay truth and evolving 3D presentation.
---

# ooze-tactics SOT

Updated: 2026-07-15

## Identity

ooze-tactics is a Godot 4.5 turn-based tile tactics prototype where slime factions expand, specialize tiles, and fight over heart and door objectives.

## Current Runtime Flow

Verified from README:

1. `MainMenu` is the startup scene.
2. Normal runs or dev-start configuration enter the game scene.
3. `Main.tscn` runs level logic.
4. Outcomes go to `RunResult`, then next level or menu.

Current level progression is `1v1`, then `2v2`, then `1v3`.

## Steam Readiness

The current readiness snapshot says the vertical slice is not a shipping signoff. Stable gameplay truth remains the 2D mode, while 3D mode can run the core tactics loop and is undergoing visual/performance readiness work.

## Active Risks

- Visual identity still needs directed screenshot review against the desired premium tactics bar.
- 3D dynamic rebuilds have visible performance spikes during capture runs.
- Capture tooling needs a documented visible-render path.
- Steam-facing onboarding, settings, saves, trailer, screenshots, and packaging are not final.
- Longer seeded AI balance sweeps are still needed.

## Next Steps

- Capture curated 3D screenshots.
- Profile dynamic rebuild cost.
- Add or use a visual review scene for role readability.
- Tune AI with seeded runs after the visual pass.
- Create and smoke test a first Windows export candidate.
