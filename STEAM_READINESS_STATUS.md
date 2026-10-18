# Ooze Tactics Steam Readiness Status

Status date: 2026-10-03

This is a production-readiness snapshot, not a shipping signoff. Implemented repairs and remaining campaign, AI-evaluation, and 3D-readability risks are detailed in [RISK_REVIEW.md](RISK_REVIEW.md); they take priority over store presentation.

## Implemented Foundations

- Shared simulation supports Living Colony 2.5D, legacy 2D, and cave 3D, with repaired opening, queue, action-limit, reward, and deadline contracts.
- Territory War adds a 260×160 strategic 2v2 prototype with front orders, intelligent group specialization, persistent supplied wells, and new role counters. Focused rules/input tests and one fixed-map all-AI match pass; human strategic acceptance remains pending.
- 3D mode can run the core tactics loop and uses the shared layout truth.
- Static dungeon floors, walls, blockers, doors, and lighting render in fresh gameplay captures; art acceptance remains outstanding.
- Dynamic ooze rendering is split from static environment and markers.
- Wall-blocking and layering checks exist; constant-based layering checks do not prove visible correctness.
- Five original organic Blender role meshes are selected by the runtime manifest; Basic territory remains procedural. This candidate kit has no manual gameplay-camera acceptance.
- The owner-approved pixel-art kit is integrated into campaign play: shared tissue with filled corners, five organ sources, in-engine faction colors, diagonal advance, and actual combat feedback. Shipping acceptance remains pending.
- Existing automated gameplay tests cover economy, combat, placement, AI sanity, seeded AI role-mix smoke, wall blocking, teams, upgrades, and performance smoke.
- All 56 original calls and twelve recovery groups pass after repairs; tuner/renderer syntax and asset import pass. Bounded repaired Level 1 play and new combat-feedback captures are recorded in Risk Review.

## Not Yet Steam-Demo Ready

- Legal openings, income recovery, and a focused ranged counterattack pass checks. Increased enemy budgets and bounded combat search have seeded 2v2 comparison coverage; human difficulty and pacing remain unaccepted.
- The evaluator's outcome, door, and topology contracts are repaired; spectator timing/options and weak promotion gates still prevent playing-strength claims.
- 3D has placement/intent rings and observed damage/dissolution labels; attack paths, rich impacts, and conversion targets remain missing.
- Normals, rest-pose bounds, owner colors, materials, and panel layout are repaired. Manual gameplay-camera review still shows a glossy, toy-like kit below the intended quality bar.
- Pre-repair captures showed dynamic rebuild spikes; performance of the new kit is unmeasured.
- Comparable capture tooling still needs fixed seeds, actual gameplay camera/UI, terminal stopping, and human review; see the Maintainer Guide.
- Steam-facing UX, onboarding, settings, save behavior, and trailer/screenshot composition are not final.
- AI balance should be reviewed through longer seeded simulations before public demo claims.

## Remaining Blockers

1. Validate Territory War fronts, group orders, resource competition, and pacing with human play.
2. Tune the new role counters and supply economy through competing strategies; retained campaign rules remain separately scoped.
3. Align evaluator timing, starting conditions, opponents, and promotion gates with gameplay.
4. Complete attack/conversion feedback and validate legibility in crowded encounters.
5. Refine the integrated pixel-art presentation through crowded encounters, authored animation, environment/UI art, and human readability checks.
6. Reduce measured dynamic rebuild costs without regressing camera/input or shared layout truth.
7. Validate opponents against frozen alternatives and held-out situations, then tune roles/economy with human play.
8. Finish understandable onboarding and release-grade settings/save behavior.
9. Package/export a Windows candidate and smoke test from a clean folder.
10. Complete store assets and exact shipped-asset licensing/attribution review after gameplay acceptance.

Current priorities and evidence gates are owned by [SOT.md](SOT.md) and [RISK_REVIEW.md](RISK_REVIEW.md). Remaining blockers are not covered by the completed repair tests.

## Known Visual Weaknesses

Living Colony has sparse environment art and prototype/legacy interfaces; dense fronts, strategic overview readability, organ-body selection, and authored attack frames remain open. The following weaknesses describe retained cave 3D:

- Role assets retain a smooth, glossy toy-like feel in normal gameplay despite material and lighting adjustments.
- Static bounds are constrained, but animated/projected overlap and late-game crowding need actual-camera review.
- The territory pool shape is readable, but the board-scale silhouette is still grid-stepped by design.
- Upgrade tiers are visible mostly by scale/material intensity; they may need a clearer but restrained indicator later.
- Contact shadows/grounding are improved through form and material, but not yet a dedicated shadow decal system.

## Known Performance Risks

Colony's terrain bottleneck is repaired using one GPU floor pass, cached minimap pixels, and retained idle overlays. Desktop GPU profiles cover opening and turn-15 states; [Risk Review](RISK_REVIEW.md) records scope. Cross-device rendering and synchronous turn latency remain open. The following rebuild risks describe cave 3D:

- Dynamic rebuilds are stamp-gated, but block/resource changes still rebuild the dynamic root.
- Pre-repair bounded captures showed expensive startup and per-change rebuilds; Risk Review records measurements and limits. They do not benchmark the new kit.
- Growth asset pooling is working, but imported GLB instances still cost memory and node traversal.
- Material caches can grow as owner colors evolve; color-key bucketing now reduces overly granular material variants.
- MultiMesh batching is already used for repeated shell/detail/tile masses, but growth GLBs remain individual pooled nodes for role identity.

## Known Gameplay / Balance Risks

- AI ranged spam has dedicated penalties and short smoke coverage; evaluator parity and post-repair campaign play must precede broader tuning claims.
- Defense and gather role timing can swing matches if economy and chokepoint layouts align too strongly.
- Upgrade pacing may need escalation tuning once repeated-upgrade strategies are tested in longer runs.
- Spectator/AI-vs-AI behavior can look convincing before it is truly balanced; capture quality should not substitute for balance data.

## Screenshots To Capture Next

- Early player ooze entering the dungeon from the first chamber.
- Mid-game clash at a wall/chokepoint with melee, defense, and ranged roles visible.
- Late-game infestation with the core heart, gather pods, and rival ooze in frame.
- Close gameplay-camera crop of each role identity: basic, core, melee, ranged, defense, gather.
- UI-inclusive screenshot showing readable tactical controls without clutter.
- Clean 2D screenshot proving the stable gameplay truth still looks coherent.
