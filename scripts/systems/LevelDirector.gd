extends RefCounted
class_name LevelDirector

func check_victory_or_loss(state: GameState) -> Dictionary:
    if not state.spectator_mode and state.count_heart_tiles(GameState.PLAYER_ID) <= 0:
        return {"status": "loss", "reason": "all_player_hearts_destroyed"}
    if state.spectator_mode and _all_team_hearts_destroyed(state, GameState.TEAM_PLAYER):
        return {"status": "loss", "reason": "all_player_team_hearts_destroyed"}

    if state.turn_limit > 0 and state.turn_index >= state.turn_limit:
        return {"status": "loss", "reason": "turn_limit"}

    if state.door_hp <= 0:
        return {"status": "victory", "reason": "door_destroyed"}

    if _all_hostile_hearts_destroyed(state):
        return {"status": "victory", "reason": "all_enemy_hearts_destroyed"}

    if not state.spectator_mode and state.stall_counter >= 3:
        return {"status": "loss", "reason": "stall_lock"}

    return {"status": "ongoing"}

func _all_hostile_hearts_destroyed(state: GameState) -> bool:
    for owner_id_variant in state.players.keys():
        var owner_id: int = int(owner_id_variant)
        if owner_id == GameState.PLAYER_ID:
            continue
        if not bool(state.players[owner_id].get("alive", true)):
            continue
        if not state.are_hostile(GameState.PLAYER_ID, owner_id):
            continue
        if state.count_heart_tiles(owner_id) > 0:
            return false
    return true

func _all_team_hearts_destroyed(state: GameState, team_id: int) -> bool:
    var any_team_owner: bool = false
    for owner_id_variant in state.players.keys():
        var owner_id: int = int(owner_id_variant)
        if state.get_owner_team(owner_id) != team_id:
            continue
        any_team_owner = true
        if state.count_heart_tiles(owner_id) > 0:
            return false
    return any_team_owner


