---
yaiml: 0.2
role: sot
title: ooze-tactics SOT
purpose: Current engineering state, direction, risks, and priorities for ooze-tactics.
belongs-here: game identity, verified capabilities, Steam readiness, active risks, validation state, next steps.
not-here: durable architecture, command reference, complete history.
durability: volatile; synthesize and prune aggressively.
read-with: Architecture; Maintainer Guide.
budget: About 800 words; a working target, subject to evidence and retention needs.
update-when: gameplay state, visual direction, Steam readiness, tests, risks, or priorities change.
last-verified: 2026-10-17 for the checks scoped in the Maintainer Guide; unrelated claims retain prior evidence limits.
agent-guidance: Preserve the distinction between stable 2D gameplay truth and evolving 3D presentation.
evidence-guidance: Separate declared direction from verified behavior; preserve uncertainty and unresolved conflicts.
---

# ooze-tactics SOT

Updated: 2026-10-03

## Identity

ooze-tactics is a Godot 4.5 turn-based colony strategy prototype. The owner wants wide fronts, territorial resource competition, useful Melee/Defense, front orders, and intelligent group specialization. The implemented Territory War prototype interprets the requested 100-fold map increase as tile area; its tuning is provisional.

The owner wants AA-quality production and approved using the connected-colony pixel-art kit in gameplay. Living Colony is the new 2.5D presentation: continuous tissue, functional organs, subtle motion, and reaching edges. Blue/green allies and red/purple enemies use in-engine palette shifts. [Visual direction](docs/visual/graphics_goal_v1.md) owns assets, gameplay evidence, and remaining acceptance. New settings default to Colony; saved legacy choices remain selectable. Existing atlases and mesh art are not the production target.

## Current Runtime Flow

Verified from the project entry scene, controller, and RunFlow source:

1. `MainMenu` is the startup scene.
2. `Territory War` opens a 260×160 Living Colony battlefield: human plus ally versus two enemies, persistent supplied wells, front orders, group selection, and symmetric team objectives.
3. `Start` and `Dev Start` retain the smaller campaign in `Main.tscn`.
4. Campaign outcomes go to `RunResult`; Territory War ends in its own scene.

Normal progression has five curated levels: Awakening (`1v1`), Narrow Halls (`1v1`), Forked Vault (`1v2`), Starving Gallery (`1v2`), and The Sealed Heart (`1v1`). Dev spectator team sizing is separate.

## Steam Readiness

The prototype is not ready for a Steam-demo signoff. Campaign opening, queue, reward, evaluator-contract, and rendering repairs are implemented locally. Opponent strength, complete tactical feedback, visual acceptance, packaging, and release validation remain outstanding. [RISK_REVIEW.md](RISK_REVIEW.md) owns detailed findings and evidence.

## Validation State

- On 2026-10-17, the full headless runner and focused Colony, Pressure and Territory checks passed on Godot 4.6.2; the real-renderer colony surface check also passed. Other evidence below retains its prior scope.
- The tuner passes syntax checking; no training or baseline promotion was performed. The Blender kit generated and imported successfully; its studio render was inspected.
- Campaign enemies have increased ordinary budgets and bounded two-tick combat planning. Focused ranged retaliation passes; six equal-budget, side-swapped 2v2 matches against one frozen heuristic produce four wins, including two deadline defenses. Finishing attacks and human difficulty remain unproven; Risk Review owns metrics, rejected actions, timing, and evaluation limits.
- Living Colony displays connected tissue, organs, actual attacks, damage/dissolution, and previews. Colony checks, rendered shared-corner/terrain tests, and three mode startup checks pass. A reproduced terrain draw-call bottleneck is repaired and GPU-profiled; Risk Review scopes throughput evidence. Complete campaign and cross-device acceptance remain unverified.
- Territory checks cover supply, farm links, farm-first openings, weighted expeditions, score-aware global/micro choices, role counters, and symmetric outcomes. The seed-1337 all-AI run ends at turn 40 on resource control (102–99, zero rejected actions); the prior policy was ongoing at 81–65. This single fixed-map result does not establish balance or human difficulty.

## Active Risks

- Training still differs from campaign cadence and starting conditions; candidate evaluation and promotion do not establish stronger opponents.
- 3D shows placement/intent rings and actual damage/dissolution labels; attack paths, impacts, and conversion feedback remain incomplete. Candidate meshes still look glossy and toy-like at gameplay scale; rebuild performance is unvalidated after repairs.
- Territory War implements supply, linked-well income, and role counters separately from campaign rules. Its AI now builds local farms, assigns one ally a smaller center expedition, and adjusts contact posture to the score race. The fixed run takes up to 5.19 seconds per late turn; multi-seed validation, human play, speed, and opponent variety remain open. SpriteWrite has no delivery adapter into this game.
- Steam-facing UX, saves, settings, export, store assets, and exact shipped-license review remain incomplete.

## Next Steps

Remaining recovery priorities:

1. Play Territory War with the owner: validate front orders, intelligent group assignment, resource competition, role counters, and match pacing.
2. Develop multi-front opponents and varied maps; measure against independent policies and human play. Keep legacy tuner parity unresolved until repaired.
3. Refine strategic overview, crowded fronts, organ readability, environment/UI art, and authored combat animation; profile actual rendering and turn costs.
4. Build progression around accepted strategic play, then complete export and Steam-facing work.
