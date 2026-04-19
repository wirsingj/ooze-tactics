extends RefCounted
class_name LevelDirector

func check_victory_or_loss(state: GameState) -> Dictionary:
    var player_core = state.get_core(GameState.PLAYER_ID)
    if player_core.is_empty():
        return {"status": "loss", "reason": "core_destroyed"}

    if _player_touches_door(state):
        return {"status": "victory", "reason": "door_contact"}

    if _all_enemies_dead(state):
        return {"status": "victory", "reason": "all_enemies_dead"}

    if state.stall_counter >= 3:
        return {"status": "loss", "reason": "stall_lock"}

    return {"status": "ongoing"}

func _all_enemies_dead(state: GameState) -> bool:
    for block in state.blocks.values():
        if int(block["owner"]) != GameState.PLAYER_ID:
            return false
    return true

func _player_touches_door(state: GameState) -> bool:
    var d: Vector2i = state.door_tile
    for block in state.get_owner_blocks(GameState.PLAYER_ID):
        if _adjacent_or_same(block["pos"], d):
            return true
    return false

func _adjacent_or_same(a: Vector2i, b: Vector2i) -> bool:
    return absi(a.x - b.x) + absi(a.y - b.y) <= 1


