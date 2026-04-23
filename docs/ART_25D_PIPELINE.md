# Ooze Tactics 2.5D Art Pipeline

## Direction Lock
- Theme: cave / underground + living slime growth.
- Palette: keep existing slime team tints and role colors; improve via lighting, emission, and material response.
- Presentation: 2.5D tactical board with depth, shadows, and angled camera.

## Runtime Layers
- `scenes/Main.tscn`
  - `CanvasLayer/UI/BoardRegion/World3DHost` (`SubViewportContainer`)
  - `World3DViewport` (`SubViewport`)
  - `World3DRoot` (`World3DRenderer`)
- `scripts/ui/World3DRenderer.gd`
  - Builds cave terrain and cached dynamic world layers.
  - Renders ownership as region-first ooze surfaces (owner mask + single surface mesh).
  - Uses MultiMesh for repeated markers/structures to keep draw calls down.
  - Owns camera, cave lighting, glow accents, and world-space highlights.

## Camera Controls
- `LMB + drag`: orbit around board pivot.
- `Shift/Ctrl + LMB + drag`: pan.
- `Mouse wheel`: zoom in/out (clamped).
- `Q / E`: tilt up/down.
- Camera motion is smoothed and constrained to avoid flips.

## Folder Structure
- `scripts/ui/World3DRenderer.gd`
  - Core 2.5D world builder and camera.
- `scripts/ui/BoardRenderer.gd`
  - Palette/tint source for team + role identity and UI icon generation.
- `assets/atlas/`
  - Existing icon/overlay textures used as readable world-space role markers.
- `assets/shaders/`
  - Optional future shader expansion for slime surface wobble and cave moisture.

## Naming Conventions
- World markers and helper meshes:
  - `TerrainRoot`, `SlimeRoot`, `AccentRoot`, `MarkerRoot`
- Role overlays:
  - Reuse atlas keys `slime_overlay_<role>`
- New art materials:
  - `rock_*`, `slime_*`, `marker_*`, `resource_*`, `door_*`

## Adding New Tile/Slime Variants
1. Add role icon variant to atlas (if needed) with `slime_overlay_<role_or_variant>`.
2. Add/adjust role tint in `BoardRenderer.gd` (`_overlay_role_tint`).
3. Extend `World3DRenderer.gd`:
   - material blend logic in `_slime_block_material`
   - icon selection in `_icon_texture` / `_add_role_icon`
   - optional glow in `_add_role_glow`
4. Keep hue family aligned to existing team tint + role tint identity.

## Extending Palette Safely
- Keep team hue anchors unchanged.
- Only adjust:
  - value (brightness)
  - emission intensity
  - roughness/clearcoat
- Avoid replacing core hue families for player/ally/enemy or role channels.

## Solo-Dev Friendly Workflow
1. Tune shape/readability in `World3DRenderer.gd` first (cheap, immediate).
2. Tune material response (roughness/emission/clearcoat) for cave moisture + slime.
3. Use atlas icons as high-contrast functional symbols in world-space.
4. Only add new textures when a silhouette/material tweak cannot solve readability.

## Future Upgrades (compatible with current setup)
- Add slime normal/emission shader animation on block top surfaces.
- Add instanced cave props (stalagmites, pooled ooze, crystal clusters).
- Add subtle fog volume in cave centerline for depth separation.
