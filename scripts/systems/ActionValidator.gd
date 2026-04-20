extends RefCounted
class_name ActionValidator

# Shared queue-time validation so hover/queue checks are consistent and explicit.

var _combat: Combat = Combat.new()

func build_owner_plan(state: GameState, queued_actions: Array, owner_id: int) -> Dictionary:
	var planned_tiles: Dictionary = {}
	var planned_upgrade_counts: Dictionary = {}
	var planned_upgrade_total: int = 0
	for block in state.get_owner_blocks(owner_id):
		planned_tiles[_tile_key(block["pos"])] = true

	var remaining_energy: int = 0
	if state.players.has(owner_id):
		remaining_energy = int(state.players[owner_id]["nutrients"])

	for action in queued_actions:
		if int(action.get("owner", 0)) != owner_id:
			continue

		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			remaining_energy -= int(action.get("cost", 0))
			planned_tiles[_tile_key(action.get("target", Vector2i(-1, -1)))] = true
		elif kind == "convert_tile":
			remaining_energy -= int(action.get("energy_delta", 0))
		elif kind == "upgrade_tile":
			remaining_energy -= int(action.get("cost", 0))
			var upgrade_type: String = String(action.get("tile_type", "basic"))
			if upgrade_type != "basic":
				planned_upgrade_counts[upgrade_type] = int(planned_upgrade_counts.get(upgrade_type, 0)) + 1
				planned_upgrade_total += 1

	return {
		"planned_tiles": planned_tiles,
		"remaining_energy": remaining_energy,
		"planned_upgrade_counts": planned_upgrade_counts,
		"planned_upgrade_total": planned_upgrade_total,
	}

func validate_place_target(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	tile_type: String,
	min_adjacent: int,
	cost: int,
	plan: Dictionary
) -> Dictionary:
	if not Combat.TILE_RULES.has(tile_type):
		return {"ok": false, "reason": "unknown tile type"}
	if not state.is_inside(tile):
		return {"ok": false, "reason": "out of bounds"}
	if state.is_blocked(tile):
		return {"ok": false, "reason": "blocked cave wall"}
	if state.is_reclaim_blocked(tile):
		return {"ok": false, "reason": "cell reforming"}
	if tile == state.entrance_tile:
		return {"ok": false, "reason": "entrance tile"}
	if tile == state.door_tile:
		return {"ok": false, "reason": "exit tile"}
	if not state.get_block_at(tile).is_empty():
		return {"ok": false, "reason": "not empty"}

	var tile_key: String = _tile_key(tile)
	if plan.get("planned_tiles", {}).has(tile_key):
		return {"ok": false, "reason": "already queued"}

	var remaining_energy: int = int(plan.get("remaining_energy", 0))
	if remaining_energy < cost:
		return {"ok": false, "reason": "insufficient energy"}

	var planned_tiles: Dictionary = plan.get("planned_tiles", {})
	return state.evaluate_growth_target(owner_id, tile, min_adjacent, planned_tiles)

func validate_convert_target(
	_state: GameState,
	owner_id: int,
	block: Dictionary,
	to_type: String,
	plan: Dictionary
) -> Dictionary:
	if not Combat.TILE_RULES.has(to_type):
		return {"ok": false, "reason": "unknown tile type"}
	if int(block.get("owner", 0)) != owner_id:
		return {"ok": false, "reason": "not owned"}

	var from_type: String = String(block.get("tile_type", "basic"))
	if from_type == to_type:
		return {"ok": false, "reason": "already %s" % to_type}
	if from_type != "basic" and to_type != "basic":
		return {"ok": false, "reason": "requires basic tile"}

	var from_tier: int = int(block.get("upgrade_tier", 0))
	var delta: int = Combat.conversion_energy_delta(from_type, to_type, from_tier)
	if delta > 0 and int(plan.get("remaining_energy", 0)) < delta:
		return {"ok": false, "reason": "insufficient energy"}

	return {"ok": true}

func validate_upgrade_target(
	state: GameState,
	owner_id: int,
	block: Dictionary,
	plan: Dictionary
) -> Dictionary:
	if int(block.get("owner", 0)) != owner_id:
		return {"ok": false, "reason": "not owned"}

	var tile_type: String = String(block.get("tile_type", "basic"))
	if tile_type == "basic":
		return {"ok": false, "reason": "basic cannot upgrade"}
	if not Combat.UPGRADE_BASE_COST.has(tile_type):
		return {"ok": false, "reason": "tile cannot upgrade"}
	var current_tier: int = maxi(Combat.SPECIALIZATION_TIER, int(block.get("upgrade_tier", Combat.SPECIALIZATION_TIER)))
	if current_tier >= Combat.MAX_UPGRADE_TIER:
		return {"ok": false, "reason": "max tier reached"}

	var planned_type_count: int = int(plan.get("planned_upgrade_counts", {}).get(tile_type, 0))
	var planned_total_count: int = int(plan.get("planned_upgrade_total", 0))
	var cost: int = Combat.upgrade_energy_cost(state, owner_id, tile_type, planned_type_count, planned_total_count, current_tier)
	if cost <= 0:
		return {"ok": false, "reason": "invalid upgrade cost"}
	if int(plan.get("remaining_energy", 0)) < cost:
		return {"ok": false, "reason": "insufficient energy"}
	return {"ok": true, "cost": cost}

func predict_candidate_application(
	state: GameState,
	player_actions: Array,
	enemy_actions: Array,
	candidate_action: Dictionary
) -> Dictionary:
	# Source of truth for hover/queue promises:
	# run the same staged-action ordering rules Combat uses at resolution time.
	var player_preview_actions: Array = player_actions.duplicate(true)
	player_preview_actions.append(candidate_action)

	var all_actions: Array = player_preview_actions.duplicate(true)
	all_actions.append_array(enemy_actions)

	var report: Dictionary = _combat.preview_resolution(state, all_actions)
	var preview_id: String = String(candidate_action.get("_preview_id", ""))
	if preview_id.is_empty():
		return {"ok": true}

	var results_by_id: Dictionary = report.get("results_by_preview_id", {})
	if not results_by_id.has(preview_id):
		return {"ok": false, "reason": "conflict in turn resolution"}

	var result: Dictionary = results_by_id[preview_id]
	if bool(result.get("applied", false)):
		return {"ok": true}
	return {"ok": false, "reason": String(result.get("reason", "conflict in turn resolution"))}

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
