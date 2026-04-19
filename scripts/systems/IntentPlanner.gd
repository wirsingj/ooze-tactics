extends RefCounted
class_name IntentPlanner

# Shared enemy-intent planner so preview matches executed enemy actions.

func build_enemy_intents(state: GameState, ai: EnemyAI, min_expand_adjacent_by_owner: Dictionary = {}, default_min_expand_adjacent: int = 2) -> Array:
	var intents: Array = []
	if state == null:
		return intents

	for owner_id in state.players.keys():
		var enemy_id: int = int(owner_id)
		if enemy_id == GameState.PLAYER_ID:
			continue
		var min_adjacent: int = default_min_expand_adjacent
		if min_expand_adjacent_by_owner.has(enemy_id):
			min_adjacent = int(min_expand_adjacent_by_owner[enemy_id])
		intents.append_array(ai.choose_actions(state, enemy_id, min_adjacent))

	return intents
