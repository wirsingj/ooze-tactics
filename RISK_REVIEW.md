---
yaiml: 0.2
role: risk-review
title: Ooze Tactics Gameplay and Presentation Review
purpose: Active graphics, AI, rules, and acceptance failures governing recovery work.
belongs-here: Reproduced defects, consequential design uncertainties, evidence limits, recovery gates.
not-here: Session history, raw logs, professional assurances, approved implementation changes.
durability: Active-risk focused; replace findings as fixes are verified and retain useful constraints.
budget: About 2500 words; keep one detailed home for current findings.
read-with: SoT; Architecture; Maintainer Guide.
update-when: Findings are reproduced, repaired, accepted, or superseded by approved design.
last-verified: 2026-10-03 full core suite, focused Territory checks, and a fixed-seed 40-turn match after farm and hierarchy changes; earlier campaign checks retain their own scope below.
agent-guidance: Distinguish observed defects from design choices and balance hypotheses; preserve human direction and uncertainty.
---

# Ooze Tactics Gameplay and Presentation Review

The owner rejects the old graphics, AI behavior, and balance and wants AA-quality production centered on wide fronts and resource competition. Territory War implements the first strategic prototype; the smaller campaign remains available. The approved connected-colony kit serves both; [visual direction](docs/visual/graphics_goal_v1.md) owns presentation evidence. Repairs restore campaign actions, income recovery, queue contracts, and combat feedback. Training cadence, varied opponents, and demonstrated fun remain unresolved.

P1 means a foundation blocking credible gameplay or evaluation; P2 means a consequential defect or decision needed for recovery. These priorities describe this audit, not measured commercial readiness.

## Evidence and limits

The full [core/recovery suite](tests/run_tests.gd) and [focused Territory checks](tests/test_territory.gd) pass on Godot 4.6.2 with the current uncommitted farm-policy code. Territory fixtures cover linked-well income, farm-first openings, weighted expeditions, supply cuts, role counters, bounded assignments, and team outcomes. Earlier pressure, Colony/render, tuner/3D syntax, and Blender checks retain their own scope. None establish balance or art acceptance.

[Headless 2v2 results](docs/validation/pressure_2v2.json) compare the current planner against the frozen pre-search repaired heuristic at seeds 1337, 2026, and 45678, swapping sides. Each colony starts with 14 energy, four income, and three actions. The candidate wins 4/6: two heart-objective wins and two deadline defenses; its two losses also reach the deadline. Normal campaign rules end on the human owner's heart loss even if its ally survives, so this is not symmetric team elimination. Reported HP loss includes collapse removals. Combined queues produce 3-37 rejected actions per match, mostly occupied targets; attribution and allied reservation need investigation. Maximum individual decisions range from 566-1038 ms on this desktop. One frozen opponent and reused seeds do not establish held-out strength or human difficulty; source hashes identify the evaluated policy and fixture.

Computer-use checks used normal Level 1 at 1600x900 on Windows, Godot 4.6.2 GL Compatibility, RTX 3090; UI-run seeds were not recorded. Six repaired 2D turns showed Gather, Melee, and expansion but weak pressure. A seven-turn 3D victory before the income floor took no player damage, paid the six-energy heart reward, and opened evolution selection. The latest build was played for eight 3D turns: a melee counterattack dealt two player HP, the enemy recovered income after losing Gather and resumed growth, and damage/dissolution labels were visible. It still fed new Basic tiles into ranged fire. This is bounded functional evidence, not a same-seed comparison or difficulty acceptance. The runtime log had no errors. Full campaign, representative human play, training, holdout tournament, and cross-device/performance validation remain unrun.

Current captures: [damage feedback](docs/validation/recovery_playtest_3d_feedback.jpg) and [counterattack/dissolution](docs/validation/recovery_playtest_3d_dissolution.jpg). Older [3D start](docs/validation/recovery_audit_3d_start.png), [2D start](docs/validation/recovery_audit_2d_start.png), and [spectator](docs/validation/recovery_audit_3d_encounter.png) images predate repairs; seeded starts use 1337, while the spectator fixture has asymmetric dev budgets and suppressed pauses. They do not establish current difficulty or pacing. The original visual benchmark referenced in [graphics_goal_v1.md](docs/visual/graphics_goal_v1.md) is unavailable; its written direction remains relevant.

## Territory War: implemented foundation, unaccepted balance

The owner selected front orders plus intelligent group specialization. [Architecture](ARCHITECTURE.md#core-rules) owns the new rules. Focused territory tests pass for permanent resource income, supply cuts, shield interception/per-projectile armor, exposed-target damage, melee breaching, rock blocking, selection bounds/affordability, preserved organs, and symmetric team outcomes. Automated mouse events exercise menu launch, board drag, and role-button assignment; preview and End Turn resolve legally. The [turn-15 full-map capture](docs/validation/territory_front_v3_overview.png) at 1500×864 shows broad connected colonies and 14–14 control; this fixed AI state is not human-play acceptance.

[Fixed-map all-AI run](docs/validation/territory_war.json) uses seed 1337 and ends on resource control at turn 40: rival score 102–99, 17,784 tiles, zero rejected actions, and a 5.19-second slowest turn. Previous run remained ongoing at turn 40 (81–65 control; 16,710 tiles). Faster contest is suggested on one seed; balance and human difficulty remain unproven.

Territory AI now has three explicit levels: micro contact selects local organs, macro builds linked rear farms and reserves a single quarter-budget center expedition for one AI ally, and global control pressure shifts the appetite for attack or defense. The one-run scoring lead is narrow; multis-seed balance, human strategic play, adaptation to queued human orders, late-game speed, progression, saves, upgrade/retasking controls, and fog of war remain absent or unverified.

## Retained campaign and rules

### Implemented campaign and queue contracts

[RunFlow](scripts/systems/RunFlow.gd) gives Level 1 enemies four starting tiles and Levels 2-4 four or five; Level 5 retains its existing territory. Recovery tests cover all 21 enemy openings across five levels at seeds 1337, 2026, and 45678: each has legal expansion, successfully applies chosen actions, and retains positive income without Gather. Revised budgets are described below; full campaign balance remains unverified.

The regression was introduced by campaign setup in commit `8234611`: one-tile starts could not meet pre-existing growth-support requirements. Changing only starting territory restored Gather, Melee, and expansion in three-turn comparisons. Rendering mode did not cause the deadlock. Keep actual campaign starts in regression coverage; generic AI fixtures previously missed it. Tactical strength after repair is not established.

[Combat queue reconciliation](scripts/systems/Combat.gd) replays accepted edits, drops dependent actions that become invalid, and recalculates surviving costs against staged state. A removed support placement no longer leaves disconnected growth; canceling the first Gather upgrade reprices the survivor from eleven to ten. Failed replacements retain the original queue order. [GameController](scripts/GameController.gd) enforces the configured five human actions and displays usage; cancellation remains available when full.

Heart-collapse rewards apply once to hostile owners, including a lone last heart; allies do not pay the player. Victory on the displayed final turn is allowed, while player-heart destruction still takes precedence and an unmet deadline remains a loss. Recovery tests exercise these contracts. These repairs do not establish campaign balance.

### Legacy rule decisions requiring explicit acceptance

- [Ranged geometry](scripts/systems/Combat.gd): shots use Manhattan range without a wall test. A target behind a solid wall lost three HP. This may be an intended lob rule, but it must be explained alongside the promise of chokepoint tactics.
- [Defense guard cap](scripts/systems/Combat.gd): default neighboring protection remained 1/1/1 across tiers I/II/III despite stored guard bonuses. Upgrades still improve their own HP/armor; the player can separately raise the cap. Decide which role advantage progression should communicate.
- [Preview scope](scripts/systems/Combat.gd): previews validate application, not projected combat, damage, deaths, or income. The player must mentally combine several hidden modifiers.

### Balance hypotheses needing play evidence

A new Gather costs four for one recurring income plus a body; its first upgrade costs ten for the same income increment, with space/safety as its advantage. There is no upkeep or income cap. The Gather run reward scales with every Gather, unlike the flat one-energy reward. Basic-then-specialization pays an extra two energy compared with direct specialization. These incentives suggest snowballing and weak investment choices; they do not prove a globally dominant strategy. Opening mobility and the human action cap are now enforced, so earlier idle-enemy play cannot establish post-repair difficulty.

Enemy base income across Levels 1-5 is now 3/4/3/3/5, with 2/3/2/3/4 actions; starting energy bonuses were also increased. Player income remains four with five actions. This reduces opening handicaps, but the two-enemy levels and boss need campaign play before accepting the pressure curve. The 2v2 comparison isolates equal budgets instead. The three-turn stall test uses artificial negative energy; normal positive income makes its post-income trigger difficult to reach, so it is not evidence against stagnation.

## AI and training

### Implemented evaluation contracts

[AIEvaluation](scripts/systems/AIEvaluation.gd) supplies the tuner with explicit terminal bonuses: victory 9.25, loss/defeat -8, completed unresolved window -2. Door credit now follows combat's player-team eligibility, and objective/resource distances use wall-aware topology. Recovery fixtures verify these independent contracts, including a sealed wall and enemy/allied door ownership. The tuner parses, but no end-to-end tuning run or promotion was performed.

### P1 Training does not reproduce campaign play

[Normal turns](scripts/GameController.gd) batch player actions and enemy intents into one global tick. [Training](tools/ai_tuner.gd) selects one owner, performs a complete global combat/economy tick, then advances the actor. A four-owner rotation therefore produces roughly four global ticks per owner's action opportunity. It also builds spectator states directly with 12 energy, bypassing campaign starts and the new tactical-search flag. This can optimize different behavior while missing a broken campaign. The separate 2v2 comparison uses correct batching; the tuner itself remains unrepaired.

One candidate policy controls both sides. Aggregated role/economy/shape metrics are useful diagnostics, but the resulting score is not candidate-versus-baseline playing strength. The rubric assigns only 25% to objective progress and rewards a fixed role mix regardless of position. Final evaluation reuses training configuration, may be skipped, and does not gate or roll back prior baseline promotion. The separate evaluation file overlaps all five training seeds and the same three templates, adding one seed. Adaptive workload changes also make initial-versus-final headline scores an unreliable like-for-like comparison.

### P2 Tactical planning and encounter strength remain bounded

[OozeAI](scripts/systems/OozeAI.gd) now includes actual ranged reach in both cached and direct threat calculations, including shots over walls as combat currently permits. Recovery tests compare this threat against real damage at range four.

The heuristic can reserve two income ticks for combat conversion rather than repeatedly buying Basic tiles, and does not wait with zero income. Income estimates now use actual Economy modifiers. The campaign adds a bounded two-tick search over legal bundles and waiting. Its score values firepower and limits future-income credit, correcting a reproduced choice of passive farming over affordable retaliation. A focused fixture now damages the ranged attacker while preserving its own heart; this is not a general counter-strategy guarantee.

The planner is greedy, limited to three searched actions and 38 rollouts, and does not model new opponent orders or coordinated allied reservations. Its actual combat simulations include existing attacks only. The current stalemate signal uses the present position rather than retained progress. See [Architecture](ARCHITECTURE.md) for the search boundary; varied opponents, finishing attacks, team coordination, and responsive thinking time remain acceptance work.

## Graphics and presentation

### P1 Combat feedback and actual-camera acceptance remain incomplete

[3D synchronization](scripts/ui/World3DRenderer.gd) receives legal placement targets and enemy intents; [markers](scripts/ui/world3d/MarkerLayerRenderer.gd) display thin rings with cache invalidation. Combat reports expose HP losses after staged purchases, dissolved tiles, and door damage; floating numbers and dissolution notices were observed in normal play. Tests exclude conversion HP changes from damage and include newly purchased tiles. Attack paths, richer impacts, ordered presentation, and conversion targets remain incomplete.

The controller separates queued-placement success from invalid hover, places the tutorial below the objective, and keeps tile details above the controls. Stale hover clears over GUI/modal surfaces. Layout and rings were checked in normal play. [EnemyFeedback](scripts/systems/EnemyFeedback.gd) excludes passes and reports waiting truthfully. Basic's description no longer claims recurring energy from mass. The 2D red X denotes invalid player hover, not a failed enemy action.

### Candidate geometry and material contracts

[DynamicOozeRenderer](scripts/ui/world3d/DynamicOozeRenderer.gd) generates upward surface normals and fits transformed imported growth bounds to at most 0.82 tile width/depth and 1.10 tile height, grounding and centering the fitted form. Tests inspect actual production GLBs and flat ooze normals. These are rest-pose geometric checks, not proof against animated or projected occlusion.

The runtime manifest selects five original organic Blender meshes with heart, claw, vent, shell, and pod silhouettes. Named skin/shell/lumen surfaces retain distinctions while following faction colors. The [studio render](assets/meshes/organic/role_studio.png) and gameplay checks are candidate evidence, not artistic acceptance. Core, Gather, Melee, and Ranged were seen in play; Defense has automated geometry coverage only. Even with reduced gloss, emission, and heart lighting, the kit looks toy-like against a flat, grid-stepped board. [Blender pipeline](tools/blender_gen/README.md) records regeneration and provenance.

Owner tint follows the shared palette; growth facing selects hostile hearts. Actual-camera captures expose the remaining material, composition, and role-readability weaknesses; owner acceptance is pending.

### Renderer throughput and remaining performance risks

The owner reported ~2 FPS immediately. [Before](docs/validation/territory_render_before.json)/[after](docs/validation/territory_render_after.json) profiles on RTX 3090, Godot 4.6.2 GL, 1600×900, uncapped: intermediate zoom fell from 104,653 draws/frame to 77; idle FPS rose 3.75→1,508, panning 0.86→714. One floor shader and minimap/overlay caching repair the bottlenecks. [Turn 15](docs/validation/territory_render_developed.json), 1,745 tiles, measures 409–538 FPS idle and 196–209 panning. Short fixed-state samples exclude turn-resolution latency and cross-device/full-match acceptance. Headless simulation and screenshots missed this; require rendered camera-motion profiling.

Cave 3D still rebuilds owner layers, masks, markers, and materials despite pooling. Pre-repair desktop measurements: six-block startup 181.6 ms; nine spectator rebuilds with 12–33 blocks averaged 54.4 ms, maximum 62.0; mask carving averaged 24.9 ms. These do not benchmark the new meshes or general FPS; comparable measurement remains pending.

### Asset delivery and visual acceptance are disconnected

SpriteWrite source inspection found editable palette/cell/layer/frame data, anchors and timing, a four-frame melee recipe, and PNG/project/frame-metadata exports. Its UI imports Project JSON; a PNG-to-editable-project import was not found. Its structured format permits direct authoring independently of its AI provider. Ooze has no consuming adapter: [AtlasCatalog](scripts/ui/AtlasCatalog.gd) expects a different sprite dictionary, while live 3D roles consume GLBs. The export path was inspected, not executed here.

[Art manifest](docs/art_manifest.md) describes the retained 3D pipeline. Living Colony directly consumes the generated PNG kit in campaign play, using shared tissue, hue shifts, growth/retreat, and actual attack/damage/dissolution events. Its bottom-left to top-right camera and filled shared corners address owner feedback. It is not a SpriteWrite importer; editable frames, rich attack sequencing, dense occlusion, environment/UI art, and cross-device performance remain open. The art brief owns detailed gameplay and shader evidence.

Layering assertions compare constants, not transformed meshes or visible occlusion. Existing capture helpers lack fixed-seed controls, and the hero helper adds composition, lights, and props. A successful helper or staged hero shot does not establish normal gameplay quality. Require fixed-state, actual-camera captures and human acceptance.

## Proposed recovery gates

1. **Validate strategic play.** Human Territory War matches must demonstrate useful group orders, holding/breaching fronts, contested resources, understandable losses, and competing plans. Agree on pacing and difficulty before extending progression.
2. **Match evaluation to play.** Use actual scenarios, global turn cadence, and terminal stopping. Preserve outcome, hostility, topology, and immediate tactical regressions; legacy tuner parity remains open.
3. **Validate presentation.** Review crowded fronts, selection, enemy borders, attack sequencing, and environment/UI art. Bounded captures and shader checks do not establish complete acceptance.
4. **Demonstrate strength and balance.** Compare independent policies and held-out maps under equivalent workloads, with promotion gates and replayable failures.
5. **Expand accepted play.** Profile turn/rendering costs, build progression, and complete onboarding, settings, saves, export, licensing review, and store assets.

These gates remain pending; implemented repairs above do not constitute artistic or release acceptance. Retain deterministic state/rules, seeded generation, shared validation, topology, action reports, reclaim delay, and static/dynamic rendering boundaries. AA quality remains an ambition requiring successful playtests and production evidence.
