# Stable Visual Baseline v1

Baseline ID: `stable_visual_baseline_v1`
Date locked: 2026-04-21 (checkpoint packaged on 2026-04-22)

## Purpose
This baseline is the protected fallback for 3D gameplay readability and camera stability before any further renderer or shader work.

## Source of Truth
- Snapshot manifest: `baselines/stable_visual_baseline_v1/baseline_manifest.json`
- Snapshot files: `baselines/stable_visual_baseline_v1/source/`
- Restore script: `tools/restore_stable_visual_baseline_v1.ps1`

## Expected Behavior

### Camera behavior
- Camera starts with a stable tactical framing (no startup snap to invalid pose).
- Orbit and pan are smooth and constrained.
- Zoom remains clamped and does not jump.
- Camera pose is preserved across turn resolution and spectator autoplay.
- Drag-release should not trigger unintended click actions.

### Camera baseline values (World3DRenderer)
- `default_yaw = -34deg`
- `default_pitch = 49deg`
- `yaw_min = -128deg`
- `yaw_max = 42deg`
- `pitch_min = 22deg`
- `pitch_max = 74deg`
- `distance_min = 8.0`
- `distance_max = 62.0`

### Lighting/environment baseline values (World3DRenderer)
- Background color: `(0.02, 0.018, 0.016)`
- Ambient color: `(0.42, 0.40, 0.37)`
- Ambient energy: `1.06`
- Brightness: `1.00`
- Contrast: `1.04`
- Saturation: `1.02`
- Fog: disabled
- Key light energy: `1.95`
- Fill light energy: `1.08`
- Fill light range: `88.0`
- Rim light energy: `0.26`

### Ooze visibility requirements
- Ownership pools must be visible at default gameplay camera.
- Ooze should be distinguishable from cave floor and walls.
- Ooze should not collapse to nearly-black or over-bloomed white.

### Readability requirements
- Board boundaries are legible at startup.
- Tactical tiles/ownership/frontline intent remain readable at x1/x4/x8.
- Environment supports board readability instead of overpowering it.

## Validation gate
Use `docs/validation/3d_stabilization_checklist.md` for manual checks.

## Known caveat in this tooling environment
- The project target is Godot 4.5.
- Headless capture under Godot 4.6 in this environment reports shader keyword incompatibility (`CLEARCOAT_GLOSS`), so visual acceptance should be confirmed in the project target runtime.
