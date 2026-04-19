# ooze-tactics (Godot 4.5 MVP)

This project is a turn-based, tile-strategy slime roguelite.

Current focus:
- Neutral cave maps (mostly unclaimed at start)
- Blob-constrained expansion (adjacent ownership + local support threshold)
- Staged turn actions with ghost previews
- Tile types: `basic`, `gather`, `defense`, `melee`, `ranged`
- Player/enemy sprite-atlas rendering with slime-only animation
- Framed pixel-style top/bottom UI panels

## Run in Godot
1. Open Godot 4.5.
2. Click **Import** and select:
   - `C:\Users\wirsi\OneDrive\Desktop\Codex\slimegame\project.godot`
3. Open the project and press **F5**.

## Controls
- Select tile type in the bottom panel.
- Left-click empty tile: queue placement.
- Left-click owned tile: queue conversion.
- Right-click tile: remove queued action for that tile.
- **End Turn**: commit queued player actions and resolve enemy turn.
- **Skip**: no player actions this turn.

## Placement Rule (Current)
- Target must be empty, not a wall, and not the exit tile.
- Target must have at least 1 cardinal adjacent owned tile.
- Target must meet local support requirement in Manhattan radius 2:
  - `support >= GameState.MIN_SUPPORT_FOR_PLACEMENT`
  - default currently `3`

## Export (Windows)
1. In Godot: **Project -> Export...**
2. Install export templates if prompted.
3. Add **Windows Desktop** preset.
4. Choose output path (for example `build\CaveSlime.exe`).
5. Click **Export Project**.

## Automated Tests
If Godot CLI is installed and available in `PATH`:

```powershell
godot4 --headless --script res://tests/run_tests.gd
```

