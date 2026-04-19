extends RefCounted
class_name EnemyAI

const MAX_ACTIONS: int = 3
const MAX_CONVERSIONS_PER_TURN: int = 2
const CONVERSION_COOLDOWN_TURNS: int = 3

# Enemy uses deterministic, pressure-biased heuristics:
# 1) secure at least one frontline action when possible
# 2) push pressure growth
# 3) take resource opportunities that don't stall pressure
# 4) avoid low-impact backline conversion churn

func choose_actions(state: GameState, owner_id: int, min_adjacent: int) -> Array:
	var actions: Array = []
	if not state.players.has(owner_id):
		return actions

	var energy: int = int(state.players[owner_id]["nutrients"])
	if energy <= 0:
		return actions

	var conversions_used: int = 0
	var frontline_committed: bool = false
	var reserved_place_tiles: Dictionary = {}
	var reserved_convert_blocks: Dictionary = {}

	var initial_frontline: Dictionary = _best_frontline_action(
		state,
		owner_id,
		min_adjacent,
		actions,
		energy,
		conversions_used,
		reserved_place_tiles,
		reserved_convert_blocks
	)
	if not initial_frontline.is_empty():
		var front_action: Dictionary = initial_frontline["action"]
		actions.append(front_action)
		_reserve_action(front_action, reserved_place_tiles, reserved_convert_blocks)
		energy -= _action_energy_cost(front_action)
		if String(front_action.get("type", "")) == "convert_tile":
			conversions_used += 1
		frontline_committed = true

	while actions.size() < MAX_ACTIONS and energy > 0:
		var candidate: Dictionary = {}

		if not frontline_committed:
			candidate = _best_frontline_action(
				state,
				owner_id,
				min_adjacent,
				actions,
				energy,
				conversions_used,
				reserved_place_tiles,
				reserved_convert_blocks
			)
			if not candidate.is_empty():
				frontline_committed = true

		if candidate.is_empty():
			candidate = _best_pressure_growth_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles)

		if candidate.is_empty() and energy >= int(Combat.TILE_RULES["gather"]["cost"]):
			candidate = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles)

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN and frontline_committed:
			candidate = _best_support_conversion_action(state, owner_id, actions, energy, reserved_convert_blocks)

		if candidate.is_empty():
			break

		var action: Dictionary = candidate["action"]
		var cost: int = _action_energy_cost(action)
		if cost > energy:
			break
		actions.append(action)
		_reserve_action(action, reserved_place_tiles, reserved_convert_blocks)
		energy -= cost
		if String(action.get("type", "")) == "convert_tile":
			conversions_used += 1

	return actions

# Frontline-first action selection.
func _best_frontline_action(
	state: GameState,
	owner_id: int,
	min_adjacent: int,
	planned_actions: Array,
	energy: int,
	conversions_used: int,
	reserved_place_tiles: Dictionary,
	reserved_convert_blocks: Dictionary
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -999999

	if conversions_used < MAX_CONVERSIONS_PER_TURN:
		var convert_candidate: Dictionary = _best_frontline_conversion_action(state, owner_id, energy, reserved_convert_blocks)
		if not convert_candidate.is_empty():
			var convert_score: int = int(convert_candidate.get("score", -999999))
			if convert_score > best_score:
				best = convert_candidate
				best_score = convert_score

	var place_candidate: Dictionary = _best_frontline_place_action(
		state,
		owner_id,
		min_adjacent,
		planned_actions,
		energy,
		reserved_place_tiles
	)
	if not place_candidate.is_empty():
		var place_score: int = int(place_candidate.get("score", -999999))
		if place_score > best_score:
			best = place_candidate

	return best

func _best_frontline_conversion_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _is_frontline_tile(state, owner_id, block["pos"]):
			continue
		if not _can_convert_block(state, block):
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		var to_type: String = _desired_frontline_role(state, owner_id, block)
		if from_type == to_type:
			continue

		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = _conversion_score(state, owner_id, block, from_type, to_type, true)
		if score > best_score:
			best_score = score
			best = {
				"score": score,
				"action": {
					"type": "convert_tile",
					"owner": owner_id,
					"block_id": block_id,
					"to_type": to_type,
					"energy_delta": delta,
				}
			}
	return best

func _best_frontline_place_action(
	state: GameState,
	owner_id: int,
	min_adjacent: int,
	planned_actions: Array,
	energy: int,
	reserved_place_tiles: Dictionary
) -> Dictionary:
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_empty_ground(tile):
				continue
			var tile_key: String = _tile_key(tile)
			if planned_tiles.has(tile_key):
				continue
			if reserved_place_tiles.has(tile_key):
				continue
			if not bool(state.evaluate_growth_target(owner_id, tile, min_adjacent, planned_tiles).get("ok", false)):
				continue

			var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, tile)
			var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
			if adjacent_enemy <= 0 and nearest_enemy_dist > 2:
				continue

			var support: int = state.count_owned_within_manhattan(owner_id, tile, 2, planned_tiles)
			var tile_type: String = "basic"
			if adjacent_enemy > 0 and energy >= int(Combat.TILE_RULES["defense"]["cost"]) and support <= 2:
				tile_type = "defense"
			elif adjacent_enemy > 0 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
				tile_type = "melee"
			elif nearest_enemy_dist <= 2 and energy >= int(Combat.TILE_RULES["melee"]["cost"]) and support >= 2:
				tile_type = "melee"

			var cost: int = int(Combat.TILE_RULES[tile_type]["cost"])
			if cost > energy:
				continue

			var score: int = 50
			score += adjacent_enemy * 18
			score += maxi(0, 8 - nearest_enemy_dist) * 5
			score += support * 3
			score += _chokepoint_score(state, tile)
			if support <= 1:
				score -= 8
			if tile_type == "defense":
				score += 4
			elif tile_type == "melee":
				score += 3

			if score > best_score:
				best_score = score
				best = {
					"score": score,
					"action": {
						"type": "place_tile",
						"owner": owner_id,
						"target": tile,
						"tile_type": tile_type,
						"cost": cost,
						"min_adjacent": min_adjacent,
					},
				}
	return best

# General pressure growth (after frontline commitment).
func _best_pressure_growth_action(
	state: GameState,
	owner_id: int,
	min_adjacent: int,
	planned_actions: Array,
	energy: int,
	reserved_place_tiles: Dictionary
) -> Dictionary:
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_empty_ground(tile):
				continue
			var tile_key: String = _tile_key(tile)
			if planned_tiles.has(tile_key):
				continue
			if reserved_place_tiles.has(tile_key):
				continue
			if not bool(state.evaluate_growth_target(owner_id, tile, min_adjacent, planned_tiles).get("ok", false)):
				continue

			var support: int = state.count_owned_within_manhattan(owner_id, tile, 2, planned_tiles)
			var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
			var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, tile)

			var tile_type: String = "basic"
			if adjacent_enemy > 0 and support <= 2 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
				tile_type = "defense"
			elif nearest_enemy_dist <= 2 and support >= 2 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
				tile_type = "melee"
			elif nearest_enemy_dist <= 3 and support >= 3 and energy >= int(Combat.TILE_RULES["ranged"]["cost"]):
				tile_type = "ranged"

			var cost: int = int(Combat.TILE_RULES[tile_type]["cost"])
			if cost > energy:
				continue

			var score: int = 0
			score += maxi(0, 10 - nearest_enemy_dist) * 6
			score += adjacent_enemy * 10
			score += support * 3
			score += _chokepoint_score(state, tile)
			if support <= 1:
				score -= 10
			for node in state.resource_nodes:
				if bool(node.get("consumed", false)):
					continue
				score -= _distance_to_tile(tile, node["pos"])

			if score > best_score:
				best_score = score
				best = {
					"score": score,
					"action": {
						"type": "place_tile",
						"owner": owner_id,
						"target": tile,
						"tile_type": tile_type,
						"cost": cost,
						"min_adjacent": min_adjacent,
					},
				}
	return best

# Resource placement when it can be supported without abandoning pressure.
func _best_resource_place_action(
	state: GameState,
	owner_id: int,
	min_adjacent: int,
	planned_actions: Array,
	energy: int,
	reserved_place_tiles: Dictionary
) -> Dictionary:
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	var gather_cost: int = int(Combat.TILE_RULES["gather"]["cost"])
	if gather_cost > energy:
		return best

	for node in state.resource_nodes:
		if bool(node.get("consumed", false)):
			continue
		var tile: Vector2i = node["pos"]
		if not state.is_empty_ground(tile):
			continue
		var tile_key: String = _tile_key(tile)
		if planned_tiles.has(tile_key):
			continue
		if reserved_place_tiles.has(tile_key):
			continue
		if not bool(state.evaluate_growth_target(owner_id, tile, min_adjacent, planned_tiles).get("ok", false)):
			continue

		var support: int = state.count_owned_within_manhattan(owner_id, tile, 2, planned_tiles)
		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
		var score: int = 10
		score += support * 3
		score += maxi(0, 8 - nearest_enemy_dist) * 2
		if support <= 1:
			score -= 8

		if score > best_score:
			best_score = score
			best = {
				"score": score,
				"action": {
					"type": "place_tile",
					"owner": owner_id,
					"target": tile,
					"tile_type": "gather",
					"cost": gather_cost,
					"min_adjacent": min_adjacent,
				}
			}
	return best

# Low-frequency rear support conversion (mostly ranged) after frontline is established.
func _best_support_conversion_action(
	state: GameState,
	owner_id: int,
	planned_actions: Array,
	energy: int,
	reserved_convert_blocks: Dictionary
) -> Dictionary:
	var _unused_planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if _is_frontline_tile(state, owner_id, block["pos"]):
			continue
		if not _can_convert_block(state, block):
			continue

		var pos: Vector2i = block["pos"]
		var nearest_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		if nearest_dist < 2 or nearest_dist > 3:
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type == "ranged":
			continue
		var to_type: String = "ranged"
		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = _conversion_score(state, owner_id, block, from_type, to_type, false)
		if score <= 0:
			continue
		if score > best_score:
			best_score = score
			best = {
				"score": score,
				"action": {
					"type": "convert_tile",
					"owner": owner_id,
					"block_id": block_id,
					"to_type": to_type,
					"energy_delta": delta,
				}
			}
	return best

func _reserve_action(action: Dictionary, reserved_place_tiles: Dictionary, reserved_convert_blocks: Dictionary) -> void:
	var kind: String = String(action.get("type", "pass"))
	if kind == "place_tile":
		var tile: Vector2i = action.get("target", Vector2i(-1, -1))
		reserved_place_tiles[_tile_key(tile)] = true
	elif kind == "convert_tile":
		var block_id: int = int(action.get("block_id", -1))
		if block_id >= 0:
			reserved_convert_blocks[block_id] = true

# Penalize low-impact backline role churn, reward pressure-positive role shifts.
func _conversion_score(state: GameState, owner_id: int, block: Dictionary, from_type: String, to_type: String, is_frontline_target: bool) -> int:
	var pos: Vector2i = block["pos"]
	var support: int = state.count_owned_within_manhattan(owner_id, pos, 2)
	var pressure: int = _enemy_pressure_score(state, owner_id, pos)
	var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
	var score: int = 0

	score += pressure * 2
	score += support
	score += maxi(0, 8 - nearest_enemy_dist) * 3

	if is_frontline_target:
		score += 20
	if not is_frontline_target and nearest_enemy_dist >= 5:
		score -= 24

	if to_type == "defense":
		score += 6 if is_frontline_target else -8
	elif to_type == "melee":
		score += 5 if is_frontline_target else -6
	elif to_type == "ranged":
		score += 4 if nearest_enemy_dist >= 2 and nearest_enemy_dist <= 3 else -10
	elif to_type == "gather":
		score -= 12

	if from_type in ["defense", "melee"] and to_type in ["defense", "melee"] and not is_frontline_target:
		score -= 14

	return score

func _desired_frontline_role(state: GameState, owner_id: int, block: Dictionary) -> String:
	var pressure: int = _enemy_pressure_score(state, owner_id, block["pos"])
	var support: int = state.count_owned_within_manhattan(owner_id, block["pos"], 2)
	if pressure >= 6 or support <= 2:
		return "defense"
	return "melee"

func _can_convert_block(state: GameState, block: Dictionary) -> bool:
	var last_turn: int = int(block.get("last_converted_turn", -999999))
	return state.turn_index - last_turn >= CONVERSION_COOLDOWN_TURNS

func _is_frontline_tile(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	return _adjacent_enemy_count(state, owner_id, tile) > 0

func _adjacent_enemy_count(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var block: Dictionary = state.get_block_at(tile + step)
		if block.is_empty():
			continue
		if int(block["owner"]) == owner_id:
			continue
		count += 1
	return count

func _planned_tiles_for_owner(actions: Array, owner_id: int) -> Dictionary:
	var out: Dictionary = {}
	for action in actions:
		if int(action.get("owner", 0)) != owner_id:
			continue
		if String(action.get("type", "")) != "place_tile":
			continue
		var tile: Vector2i = action.get("target", Vector2i(-1, -1))
		out[_tile_key(tile)] = true
	return out

func _action_energy_cost(action: Dictionary) -> int:
	var kind: String = String(action.get("type", "pass"))
	if kind == "place_tile":
		return int(action.get("cost", 0))
	if kind == "convert_tile":
		return int(action.get("energy_delta", 0))
	return 0

# Pressure and map-shape helpers.
func _nearest_enemy_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var best: int = 999999
	for enemy in state.blocks.values():
		if int(enemy["owner"]) == owner_id:
			continue
		best = mini(best, _distance_to_tile(tile, enemy["pos"]))
	return best if best < 999999 else 99

func _enemy_pressure_score(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var pressure: int = 0
	for enemy in state.blocks.values():
		if int(enemy["owner"]) == owner_id:
			continue
		var d: int = _distance_to_tile(tile, enemy["pos"])
		pressure += maxi(0, 7 - d)
	return pressure

func _chokepoint_score(state: GameState, tile: Vector2i) -> int:
	var blocked_neighbors: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t: Vector2i = tile + step
		if not state.is_inside(t) or state.is_blocked(t):
			blocked_neighbors += 1
	return blocked_neighbors * 2

func _distance_to_tile(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
