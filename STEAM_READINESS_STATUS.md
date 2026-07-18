# Ooze Tactics Steam Readiness Status

Status date: 2026-07-15

This is a production-readiness snapshot for the current vertical slice. It is not a shipping signoff.

## Steam-Demo Ready

- 2D mode remains the stable gameplay truth.
- 3D mode can run the core tactics loop and uses the shared layout truth.
- Static dungeon rendering has readable floors, walls, blockers, doors, and warm dungeon lighting.
- Dynamic ooze rendering is split from static environment and markers.
- Ooze territory respects wall-blocking/render-truth contracts in current capture tools.
- Role-specific generated 3D ooze assets exist for core, melee, ranged, defense, gather, and basic.
- Existing automated gameplay tests cover economy, combat, placement, AI sanity, seeded AI role-mix smoke, wall blocking, teams, upgrades, and performance smoke.

## Not Yet Steam-Demo Ready

- Visual identity is improved but still needs directed screenshot review against the desired "premium tactics" bar.
- 3D performance has visible dynamic rebuild cost spikes during capture runs.
- Capture tooling needs a documented visible-render path; dummy headless capture cannot read viewport textures here.
- Steam-facing UX, onboarding, settings, save behavior, and trailer/screenshot composition are not final.
- AI balance should be reviewed through longer seeded simulations before public demo claims.

## Top 10 Blockers

1. Lock a final role-readability art direction for ooze tiles from gameplay camera screenshots.
2. Reduce dynamic rebuild spikes, especially first-import/rebuild frames.
3. Create a repeatable screenshot capture command/profile for Steam capsule and store screenshots.
4. Add a short playable tutorial or first-run guidance.
5. Add release-grade settings persistence for graphics/audio/input.
6. Confirm 3D mode does not regress 2D mode or shared layout truth.
7. Run longer AI-vs-AI balance sweeps beyond the current smoke coverage to catch ranged/defense/gather overuse.
8. Add minimum Steam page assets: key art direction, capsule, hero screenshots, and short trailer plan.
9. Package/export a Windows build and smoke test from a clean folder.
10. Review third-party asset licenses and attribution for the exact shipped asset set.

## Next 5 Recommended Tasks

1. Capture a curated 3D screenshot set: early spread, mid clash, late infestation, close role lineup, and core-under-threat.
2. Profile dynamic rebuild in a standalone repro and separate first-import cost from steady-state rebuild cost.
3. Add a visual review scene that places one tile of each ooze role side-by-side under gameplay lighting.
4. Tune AI with longer seeded runs after the visual pass, focusing on ranged saturation and gather/defense economy timing.
5. Create a first Windows export candidate and document exact build steps.

## Known Visual Weaknesses

- Some role assets still share a smooth generated-material feel in Blender contact sheets; in-game runtime materials carry most of the final mood.
- Late-game overlap can become visually busy when many specialized growths collide near the center lane.
- The territory pool shape is readable, but the board-scale silhouette is still grid-stepped by design.
- Upgrade tiers are visible mostly by scale/material intensity; they may need a clearer but restrained indicator later.
- Contact shadows/grounding are improved through form and material, but not yet a dedicated shadow decal system.

## Known Performance Risks

- Dynamic rebuilds are stamp-gated, but block/resource changes still rebuild the dynamic root.
- Capture runs show dynamic rebuild averages around roughly 95-105 ms with first-spike frames near 400 ms on the current machine.
- Growth asset pooling is working, but imported GLB instances still cost memory and node traversal.
- Material caches can grow as owner colors evolve; color-key bucketing now reduces overly granular material variants.
- MultiMesh batching is already used for repeated shell/detail/tile masses, but growth GLBs remain individual pooled nodes for role identity.

## Known Gameplay / Balance Risks

- AI ranged spam has dedicated penalties plus short seeded smoke coverage, but longer seeded sweeps are still needed.
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
