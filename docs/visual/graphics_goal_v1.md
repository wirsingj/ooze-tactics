# Ooze Tactics Graphics Goal (v1)

Status: Canonical visual target for all future art/polish passes.
Date locked: 2026-04-21

## Primary Reference
- Reference image provided in chat on 2026-04-21 ("spectator cave ooze" target).
- This image is the style benchmark for scene mood, slime material quality, readability hierarchy, and UI integration.

## Non-Negotiable Target Characteristics

1. **Readable tactical gameplay first**
- Board state readable at default gameplay camera.
- Ownership, blockers, units, role identity, and frontlines legible at a glance.
- Environment supports readability; does not overpower board information.

2. **Cave fantasy presentation**
- Dark cave environment with wet stone floor/walls.
- Localized warm/cool accent lights.
- Strong depth, composition, and spatial framing around the board.

3. **Slime as hero material**
- Thick, glossy pooled territory (not flat tint overlays).
- Strong faction color separation with controlled glow.
- Subtle life/motion (bubbling, pulse, shimmer) without visual noise.

4. **Structure/role readability**
- Distinct 3D silhouettes per role (basic/melee/ranged/defense/gather).
- Readable at gameplay zoom, not tiny icon-only differentiation.
- Clear separation from slime and ground through shape/material contrast.

5. **Premium UI coherence**
- Existing UI framing preserved and polished.
- High contrast text and panel hierarchy.
- UI style integrated with cave/slime visual language.

6. **Performance-safe implementation**
- Preserve smooth gameplay and high simulation speed modes.
- Favor instancing/material reuse/shader tuning over heavy node churn.
- No visual feature that regresses playability or camera/input stability.

## Stabilization Gate (must remain true)
Before any visual upgrade is accepted, all must pass:
- Camera controls stable (orbit/pan/zoom), no turn-based snapping.
- Startup view readable with no dark/black scene regression.
- x1/x4/x8 modes remain responsive.
- No gameplay logic/input regressions caused by visual code.

## Implementation Rule
- Use this reference as **strong direction**, not literal 1:1 reproduction.
- Prioritize clarity, cohesion, and performance over raw detail density.
