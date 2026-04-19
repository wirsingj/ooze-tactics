extends RefCounted
class_name TurnResolver

# Thin orchestration wrapper around TickSystem to keep scene controller lean.

var tick_system: TickSystem = TickSystem.new()

func resolve_turn(
	state: GameState,
	player_actions: Array,
	enemy_actions: Array,
	min_expand_adjacent: int,
	basic_tile_cost: int
) -> Dictionary:
	tick_system.min_expand_adjacent = min_expand_adjacent
	tick_system.basic_tile_cost = basic_tile_cost

	var all_actions: Array = player_actions.duplicate(true)
	all_actions.append_array(enemy_actions)

	var next_state: GameState = tick_system.step(state, all_actions)
	var report: Dictionary = next_state.last_resolution_report
	var applied_enemy_actions: Array = []
	var failed_enemy_actions: Array = []

	for action in report.get("applied_actions", []):
		if int(action.get("owner", 0)) == GameState.PLAYER_ID:
			continue
		applied_enemy_actions.append(action)

	for failed in report.get("failed_actions", []):
		if int(failed.get("owner", 0)) == GameState.PLAYER_ID:
			continue
		failed_enemy_actions.append(failed)

	return {
		"state": next_state,
		"report": report,
		"applied_enemy_actions": applied_enemy_actions,
		"failed_enemy_actions": failed_enemy_actions,
	}
