# 3D Stabilization Manual Validation Checklist

## Startup / Visibility
1. Launch a fresh match from main menu.
2. Confirm board is immediately readable (ground, slime, blockers, units visible) without zooming in.
3. Confirm no black-screen or outside-shell startup view.

## Camera Controls
1. Orbit with left-drag: rotation should be smooth and constrained.
2. Pan with Shift/Control + left-drag: board should translate predictably.
3. Zoom with wheel up/down: no sudden jumps or clipping.
4. Release mouse after drag: no unwanted click action should trigger.

## Persistence Across Gameplay
1. End turn 5+ times at x1 speed while moving camera between turns.
2. Repeat at x4 speed.
3. Repeat at x8 speed.
4. Confirm camera pose persists (no snap/recenter/default reset).

## Hover/Queue Preview Stability
1. Hover tiles and watch ghost markers.
2. Queue multiple actions and confirm queued ghost markers persist.
3. Verify invalid preview shows red feedback and does not alter camera.

## Readability Baseline
1. At default camera, confirm ownership colors are distinct.
2. Confirm blockers and special role structures are still identifiable.
3. Confirm environment stays visually secondary to the board.

## Regression Fail Conditions
- Camera resets on turn advance.
- Camera recenters during normal input.
- Board appears nearly black from default view.
- Controls feel inconsistent between x1/x4/x8.
