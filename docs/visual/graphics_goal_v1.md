# Ooze Tactics Graphics Goal (v1)

Status: Owner-approved kit integrated into Living Colony campaign and Territory War; further gameplay polish and shipping acceptance pending.
Direction reviewed: 2026-10-03

The owner approved using the heart and connected-colony kit in gameplay. Develop this 2.5D pixel-art direction from the living tissue upward. Current top-down atlases and the 3D mesh kit are not the new art target. The campaign camera advances bottom-left to top-right. Allies use blue/green and enemies red/purple, shifted in-engine from shared source sprites rather than separately generated faction images. Blender remains optional; the older cave reference does not lock implementation.

## Living Colony Requirement

Owner requirement: every tile role has personality appropriate to its function, friendly tiles blend continuously, motion is subtle, and the outer edge feels like ooze reaching. This is the core theme in any presentation. Roles emerge from shared living tissue; ownership, tile selection, and attack reach must remain readable.

Proposed role expression, subject to visual review:

| Role | Shape and motion |
|---|---|
| Basic | Low connective flesh; exploratory edge tendrils and slow surface flow. |
| Core | Protected organ; a calm heartbeat visibly related to the colony's rhythm. |
| Melee | Tense muscular lobe; coil, lash, impact, and recoil. |
| Ranged | Pressure sac; swell, aim, spit, and deflate. |
| Defense | Broad thick membrane; brace toward pressure and compress on impact. |
| Gather | Feeding fronds and vesicles; draw inward and pulse on income. |

Friendly joins must hide tile seams across corners and bridges; hostile frontiers stay distinct. Border tendrils probe subtly, extend on actual growth, and retreat or rupture on loss. Adjacent animation must preserve connections rather than bob each tile independently. Cosmetic flow is separate from Territory War's explicit heart-to-site supply rules. The first moving test must show joining, reaching, specialization, attack, and dissolution in one patch at gameplay scale.

## Current Art Kit And Gameplay

The [connected colony](concepts/ooze-colony-study-v1.png) and [heart](concepts/ooze-heart-study-v1.png) are the approved style references. Approval covers direction, not shipping acceptance. Their [colony](concepts/ooze-colony-study-v1.prompt.txt) and [heart](concepts/ooze-heart-study-v1.prompt.txt) provenance records retain generation details.

`assets/art/colony-v1/` contains five separate transparent organ sources (`core`, `melee`, `ranged`, `defense`, `gather`) and an opaque `tissue` material. [Provenance and exact prompts](../../assets/art/colony-v1/provenance.json) identify the built-in OpenAI image tool and shared reference. Source PNGs remain unchanged; Basic territory uses the shared material rather than a separate creature sprite. No faction duplicates exist.

[Godot art preview](../../tools/colony_art_preview.gd) displays four colonies and a role strip. A palette shader changes teal tissue hue while preserving amber innards. Alpha thresholding suppresses generated halos at display time. A separate territory shader joins a fixed tile fixture with a continuous surface and probing edges; organs have subtle rooted deformation, plus an illustrative role pulse. Reach/retreat and grayscale controls support inspection. These are cosmetic motions, not authored animation frames or resolved attacks.

[Captured preview](../validation/colony_art_preview_v1.png) and computer-use inspection on Godot 4.6.2 GL Compatibility at 1600x900 verified all roles, four palettes, reach/retreat, role-pulse interaction, and grayscale/restoration. Source role heights in the fixture are 80-128 screen pixels; grayscale silhouettes remain distinguishable. The preview log had no runtime errors; this study alone does not establish gameplay quality.

Living Colony now consumes the kit in normal play: connected growth/retreat, specialization, actual melee/ranged attack paths, damage/dissolution, placement previews, and camera picking. Six manually played Level 1 turns at seed 1337 showed all five organs, enemy development, and dissolution; the match was not completed. [Gameplay start](../validation/colony_gameplay_v1.png) and [combat](../validation/colony_gameplay_combat_v1.jpg) predate the camera rotation and corner repair. Their runtime log had no errors. Subsequent 2v2 opening inspection verified the rotated composition and four colonies; it did not reach combat manually. Production-shader pixel checks pass for filled four-tile corners, isolated/diagonal separation, and wall/foreign borders at two animation times. Picking, zoom/pan, ownership, growth/loss, and unchanged simulation checks pass headlessly.

Territory War reuses this art across 260×160 tiles with repeating tissue detail, one GPU floor pass, selection overlays, and a cached clickable minimap. [First-turn capture](../validation/territory_gameplay_v1.png) was inspected on Godot 4.6.2 GL Compatibility at 1600×900 after automated menu, drag-selection, role-button, and End Turn inputs. [Opening](../validation/territory_render_after.png) and [turn-15](../validation/territory_render_developed.png) captures verify the optimized terrain's rendered appearance. Production-shader checks distinguish rock, ground, and board bounds at two scales. Helpers exit automatically. These are bounded visual checks; [Risk Review](../../RISK_REVIEW.md) owns measured rendering throughput and simulation scope, not human match acceptance.

## Next Art Acceptance Gate

Refine wide fronts, overview readability, friendly/hostile borders, motion continuity, occlusion, and group selection at actual play size. Selection targets ground diamonds, not visible organ bodies. The sparse board and prototype/legacy interfaces need coherent art. Attacks use procedural paths and rooted deformation; authored anticipation, impact, and dissolution frames remain open. Dense-map material repetition and cross-device performance are unvalidated. Maintain consistent pixel density and lighting. SpriteWrite remains optional for editable frames; its delivery gaps are in [Risk Review](../../RISK_REVIEW.md).

## Primary Reference
- Reference image provided in chat on 2026-04-21 ("spectator cave ooze" target).
- This image is the style benchmark for scene mood, slime material quality, readability hierarchy, and UI integration.
- The original image is unavailable in the inspected repository; use the written characteristics without claiming a direct image comparison.

## Retained Visual Goals

1. **Readable tactical gameplay first**
- Board state readable at default gameplay camera.
- Ownership, blockers, units, role identity, and frontlines legible at a glance.
- Environment supports readability; does not overpower board information.

2. **Cave fantasy presentation**
- Dark cave environment with wet stone floor/walls.
- Localized warm/cool accent lights.
- Strong depth, composition, and spatial framing around the board.

3. **Slime as hero material**
- Cohesive living territory with visible volume; exact surface treatment is under review.
- Strong faction color separation with controlled glow.
- Subtle life/motion (bubbling, pulse, shimmer) without visual noise.

4. **Structure/role readability**
- Distinct silhouettes per role (basic/melee/ranged/defense/gather).
- Readable at gameplay zoom, not tiny icon-only differentiation.
- Clear separation from slime and ground through shape/material contrast.

5. **Premium UI coherence**
- UI framing follows the chosen art direction while preserving tactical clarity.
- High contrast text and panel hierarchy.
- UI style integrated with cave/slime visual language.

6. **Performance-safe implementation**
- Preserve smooth gameplay and high simulation speed modes.
- Favor instancing/material reuse/shader tuning over heavy node churn.
- No visual feature that regresses playability or camera/input stability.

## Stabilization Gate (must remain true)
Before any visual upgrade is accepted, all must pass:
- Camera and picking stable for the chosen presentation; retained orbit/pan/zoom must not snap on turns.
- Startup view readable with no dark/black scene regression.
- x1/x4/x8 modes remain responsive.
- No gameplay logic/input regressions caused by visual code.

## Implementation Rule
- Use this reference as **strong direction**, not literal 1:1 reproduction.
- Prioritize clarity, cohesion, and performance over raw detail density.
