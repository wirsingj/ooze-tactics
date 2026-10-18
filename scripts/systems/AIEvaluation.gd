extends RefCounted

# Pure scoring contracts; these alone do not establish playing strength.
static func outcome_bonus(status: String, completed_window: bool) -> float:
	match status:
		"victory":
			return 9.25
		"loss", "defeat":
			return -8.0
		_:
			return -2.0 if completed_window else 0.0

static func can_damage_door(state: GameState, owner_id: int) -> bool:
	return owner_id == GameState.PLAYER_ID or not state.are_hostile(owner_id, GameState.PLAYER_ID)

static func door_progress(state: GameState, initial_state: GameState, owner_id: int) -> float:
	if not can_damage_door(state, owner_id):
		return 0.0
	return clampf(1.0 - float(state.door_hp) / maxf(1.0, float(initial_state.door_hp)), 0.0, 1.0)

static func owner_distance(state: GameState, owner_id: int, targets: Array) -> int:
	var distances: Dictionary = BoardTopology.distance_map_to_positions(state, targets)
	var best: int = BoardTopology.UNREACHABLE_DISTANCE
	for block in state.get_owner_blocks(owner_id):
		best = mini(best, int(distances.get(block["pos"], BoardTopology.UNREACHABLE_DISTANCE)))
	return best
