extends RefCounted
class_name EnemyAI

const MAX_ACTIONS: int = 3
const MAX_CONVERSIONS_PER_TURN: int = 2
const CONVERSION_COOLDOWN_TURNS: int = 2
const FRONTLINE_FOLLOWUP_SCORE_THRESHOLD: int = 74
const ENGAGED_MIN_UPGRADES_PER_TURN: int = 1
const NON_ENGAGED_MIN_UPGRADES_PER_TURN: int = 0
const ENGAGED_BASIC_EXPANSION_PENALTY: int = 22
const SECOND_LINE_RANGED_MIN_DIST: int = 2
const SECOND_LINE_RANGED_MAX_DIST: int = 5
const MAX_TILE_UPGRADES_PER_TURN: int = 1
const ENGAGED_UPGRADE_ENERGY_THRESHOLD: int = 16
const NON_ENGAGED_UPGRADE_ENERGY_THRESHOLD: int = 22
const PRE_ENGAGE_OBJECTIVE_UPGRADE_ENERGY_THRESHOLD: int = 16
const TILE_UPGRADE_MIN_SCORE: int = 74
const TILE_UPGRADE_SURPLUS_RESERVE: int = 6
const EARLY_ECON_TURN_WINDOW: int = 6
const EARLY_ECON_INCOME_THRESHOLD: int = 6
const EARLY_GATHER_TARGET: int = 2
const MID_ECON_INCOME_THRESHOLD: int = 7
const MID_ECON_ENERGY_LOW_THRESHOLD: int = 6
const MID_GATHER_TARGET: int = 3
const THREAT_SPIKE_THRESHOLD: int = 12
const THREAT_SCAN_RADIUS: int = 2
const RANGED_SATURATION_SOFT_CAP: float = 0.35
const RANGED_SATURATION_HARD_CAP: float = 0.52
const RANGED_SATURATION_MIN_TILES: int = 8
const RANGED_SATURATION_MAX_PENALTY: int = 36
const RANGED_FRONTLINE_PENALTY: int = 28
const RANGED_BACKLINE_PENALTY: int = 14
const DOOR_ADVANCE_WEIGHT: int = 12
const DOOR_DEFEND_WEIGHT: int = 4
const CHOKEPOINT_WEIGHT: int = 4
const HEART_OBJECTIVE_WEIGHT: int = 20
const OBJECTIVE_UPGRADE_DISTANCE_MAX: int = 14
const OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX: int = 10
const OBJECTIVE_PROGRESS_WEIGHT: int = 22
const OBJECTIVE_BACKFILL_PENALTY: int = 32

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
	var frontline_upgraded: bool = false
	var second_line_support_upgraded: bool = false
	var upgrades_committed: int = 0
	var tile_upgrades_used: int = 0
	var reserved_place_tiles: Dictionary = {}
	var reserved_convert_blocks: Dictionary = {}
	var engaged: bool = _is_owner_engaged(state, owner_id)
	var desired_upgrade_count: int = 0
	if engaged and _can_afford_any_upgrade(energy):
		desired_upgrade_count = ENGAGED_MIN_UPGRADES_PER_TURN
	elif _can_afford_any_upgrade(energy):
		desired_upgrade_count = NON_ENGAGED_MIN_UPGRADES_PER_TURN
	var can_upgrade_this_turn: bool = _has_viable_engagement_upgrade(state, owner_id, energy, reserved_convert_blocks)

	if engaged:
		var forced_frontline_upgrade: Dictionary = _best_frontline_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
		if not forced_frontline_upgrade.is_empty():
			var upgrade_action: Dictionary = forced_frontline_upgrade["action"]
			actions.append(upgrade_action)
			_reserve_action(upgrade_action, reserved_place_tiles, reserved_convert_blocks)
			energy -= _action_energy_cost(upgrade_action)
			conversions_used += 1
			frontline_committed = true
			frontline_upgraded = true
			upgrades_committed += 1

		if actions.size() < MAX_ACTIONS and conversions_used < MAX_CONVERSIONS_PER_TURN:
			var second_line_upgrade: Dictionary = _best_second_line_ranged_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if not second_line_upgrade.is_empty():
				var support_action: Dictionary = second_line_upgrade["action"]
				actions.append(support_action)
				_reserve_action(support_action, reserved_place_tiles, reserved_convert_blocks)
				energy -= _action_energy_cost(support_action)
				conversions_used += 1
				second_line_support_upgraded = true
				upgrades_committed += 1

	elif conversions_used < MAX_CONVERSIONS_PER_TURN and energy >= PRE_ENGAGE_OBJECTIVE_UPGRADE_ENERGY_THRESHOLD:
		# Even before contact, commit one objective-facing upgrade when possible.
		var early_objective_upgrade: Dictionary = _best_objective_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
		if not early_objective_upgrade.is_empty():
			var early_action: Dictionary = early_objective_upgrade["action"]
			actions.append(early_action)
			_reserve_action(early_action, reserved_place_tiles, reserved_convert_blocks)
			energy -= _action_energy_cost(early_action)
			conversions_used += 1
			upgrades_committed += 1

	if not engaged and upgrades_committed < desired_upgrade_count and conversions_used < MAX_CONVERSIONS_PER_TURN:
		var forced_progress_upgrade: Dictionary = _best_objective_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
		if forced_progress_upgrade.is_empty():
			forced_progress_upgrade = _best_progression_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
		if not forced_progress_upgrade.is_empty():
			var progress_action: Dictionary = forced_progress_upgrade["action"]
			actions.append(progress_action)
			_reserve_action(progress_action, reserved_place_tiles, reserved_convert_blocks)
			energy -= _action_energy_cost(progress_action)
			conversions_used += 1
			upgrades_committed += 1

	if _should_prioritize_early_economy(state, owner_id):
		var gather_goal: int = maxi(0, EARLY_GATHER_TARGET - _count_gather_tiles(state, owner_id))
		while gather_goal > 0 and actions.size() < MAX_ACTIONS and energy >= int(Combat.TILE_RULES["gather"]["cost"]):
			var gather_candidate: Dictionary = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, true)
			if gather_candidate.is_empty():
				break
			var gather_action: Dictionary = gather_candidate["action"]
			actions.append(gather_action)
			_reserve_action(gather_action, reserved_place_tiles, reserved_convert_blocks)
			energy -= _action_energy_cost(gather_action)
			gather_goal -= 1

	while actions.size() < MAX_ACTIONS and energy > 0:
		var candidate: Dictionary = {}

		if not engaged and desired_upgrade_count > 0 and upgrades_committed < desired_upgrade_count and conversions_used < MAX_CONVERSIONS_PER_TURN:
			var required_progress_upgrade: Dictionary = _best_objective_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if required_progress_upgrade.is_empty():
				required_progress_upgrade = _best_progression_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if not required_progress_upgrade.is_empty():
				candidate = required_progress_upgrade

		if engaged and can_upgrade_this_turn and upgrades_committed < ENGAGED_MIN_UPGRADES_PER_TURN and conversions_used < MAX_CONVERSIONS_PER_TURN:
			var required_upgrade: Dictionary = _best_frontline_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if required_upgrade.is_empty():
				required_upgrade = _best_second_line_ranged_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if not required_upgrade.is_empty():
				candidate = required_upgrade
				upgrades_committed += 1

		if candidate.is_empty() and engaged and not frontline_upgraded and conversions_used < MAX_CONVERSIONS_PER_TURN:
			var mandatory_upgrade: Dictionary = _best_frontline_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if not mandatory_upgrade.is_empty():
				candidate = mandatory_upgrade
				frontline_upgraded = true

		if candidate.is_empty() and engaged and not second_line_support_upgraded and conversions_used < MAX_CONVERSIONS_PER_TURN:
			var second_line_support: Dictionary = _best_second_line_ranged_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if not second_line_support.is_empty():
				candidate = second_line_support
				second_line_support_upgraded = true

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN:
			var objective_upgrade: Dictionary = _best_objective_upgrade_action(state, owner_id, energy, reserved_convert_blocks)
			if not objective_upgrade.is_empty():
				candidate = objective_upgrade

		if candidate.is_empty():
			var threat_response: Dictionary = _best_threat_response_action(
				state,
				owner_id,
				min_adjacent,
				actions,
				energy,
				conversions_used,
				reserved_place_tiles,
				reserved_convert_blocks
			)
			if not threat_response.is_empty():
				candidate = threat_response

		var frontline_candidate: Dictionary = _best_frontline_action(
			state,
			owner_id,
			min_adjacent,
			actions,
			energy,
			conversions_used,
			reserved_place_tiles,
			reserved_convert_blocks
		)
		if candidate.is_empty() and not frontline_candidate.is_empty():
			var frontline_score: int = int(frontline_candidate.get("score", -999999))
			if not frontline_committed or frontline_score >= FRONTLINE_FOLLOWUP_SCORE_THRESHOLD:
				candidate = frontline_candidate
				frontline_committed = true

		if candidate.is_empty():
			candidate = _best_pressure_growth_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, engaged)

		if candidate.is_empty() and _should_seek_midgame_gather(state, owner_id, energy, engaged):
			candidate = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, true)

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN and frontline_committed:
			candidate = _best_support_conversion_action(state, owner_id, actions, energy, reserved_convert_blocks)

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN:
			candidate = _best_heart_pressure_conversion_action(state, owner_id, energy, reserved_convert_blocks)

		var upgrade_energy_threshold: int = ENGAGED_UPGRADE_ENERGY_THRESHOLD if engaged else NON_ENGAGED_UPGRADE_ENERGY_THRESHOLD
		if candidate.is_empty() and tile_upgrades_used < MAX_TILE_UPGRADES_PER_TURN and energy >= upgrade_energy_threshold:
			var prefer_frontline_upgrade: bool = engaged
			var tile_upgrade_candidate: Dictionary = _best_tile_upgrade_action(state, owner_id, energy, reserved_convert_blocks, prefer_frontline_upgrade)
			if not tile_upgrade_candidate.is_empty():
				candidate = tile_upgrade_candidate

		if candidate.is_empty() and energy >= int(Combat.TILE_RULES["gather"]["cost"]):
			candidate = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, false)

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
			upgrades_committed += 1
			if _is_frontline_conversion(state, owner_id, action):
				frontline_upgraded = true
			elif _is_second_line_conversion(state, owner_id, action):
				second_line_support_upgraded = true
		elif String(action.get("type", "")) == "upgrade_tile":
			tile_upgrades_used += 1

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

func _best_heart_pressure_conversion_action(
	state: GameState,
	owner_id: int,
	energy: int,
	reserved_convert_blocks: Dictionary
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _can_convert_block(state, block):
			continue

		var pos: Vector2i = block["pos"]
		var heart_dist: int = _nearest_hostile_heart_distance(state, owner_id, pos)
		var enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		if heart_dist > OBJECTIVE_UPGRADE_DISTANCE_MAX or enemy_dist > OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX:
			continue

		var to_type: String = "melee"
		if heart_dist <= 2 or _is_frontline_tile(state, owner_id, pos):
			to_type = "melee"
		elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
			to_type = "ranged"
		elif _local_threat_score(state, owner_id, pos) >= THREAT_SPIKE_THRESHOLD:
			to_type = "defense"

		var from_type: String = String(block.get("tile_type", "basic"))
		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = _conversion_score(state, owner_id, block, from_type, to_type, _is_frontline_tile(state, owner_id, pos))
		score += 12
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

func _best_frontline_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	return _best_frontline_conversion_action(state, owner_id, energy, reserved_convert_blocks)

func _best_second_line_ranged_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	if _is_ranged_hard_capped(state, owner_id):
		return {}
	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _can_convert_block(state, block):
			continue

		var pos: Vector2i = block["pos"]
		if _is_frontline_tile(state, owner_id, pos):
			continue
		if not _is_near_front_tile(state, owner_id, pos):
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type == "ranged":
			continue
		var delta: int = Combat.conversion_energy_delta(from_type, "ranged")
		if delta > energy:
			continue

		var dist: int = _nearest_enemy_distance(state, owner_id, pos)
		if dist < SECOND_LINE_RANGED_MIN_DIST or dist > SECOND_LINE_RANGED_MAX_DIST:
			continue

		var support: int = state.count_owned_within_manhattan(owner_id, pos, 2)
		var score: int = 64
		score += support * 2
		score += maxi(0, 8 - dist) * 4
		score += _chokepoint_score(state, pos) * (CHOKEPOINT_WEIGHT + 2)
		score += _door_objective_score(state, owner_id, pos)
		score += _heart_objective_score(state, owner_id, pos)
		score += _zone_role_score("second_line", "ranged")
		score -= _ranged_saturation_penalty(state, owner_id)
		if score > best_score:
			best_score = score
			best = {
				"score": score,
				"action": {
					"type": "convert_tile",
					"owner": owner_id,
					"block_id": block_id,
					"to_type": "ranged",
					"energy_delta": delta,
				}
			}
	return best

func _best_objective_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _can_convert_block(state, block):
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type != "basic":
			continue

		var pos: Vector2i = block["pos"]
		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		var heart_dist: int = _nearest_hostile_heart_distance(state, owner_id, pos)
		var door_dist: int = _distance_to_tile(pos, state.door_tile)
		var door_relevant: bool = _can_attack_door(state, owner_id) and state.door_hp > 0

		var objective_dist: int = heart_dist
		if door_relevant:
			objective_dist = mini(objective_dist, door_dist)
		if objective_dist > OBJECTIVE_UPGRADE_DISTANCE_MAX and nearest_enemy_dist > OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX:
			continue

		var to_type: String = "melee"
		if _is_frontline_tile(state, owner_id, pos):
			to_type = _desired_frontline_role(state, owner_id, block)
		elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
			to_type = "ranged"
		elif nearest_enemy_dist <= 3:
			to_type = "melee"
		elif _local_threat_score(state, owner_id, pos) >= THREAT_SPIKE_THRESHOLD:
			to_type = "defense"
		elif door_relevant and door_dist <= 5:
			to_type = "melee"

		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = 28
		score += _heart_objective_score(state, owner_id, pos)
		score += _door_objective_score(state, owner_id, pos)
		score += maxi(0, OBJECTIVE_UPGRADE_DISTANCE_MAX - objective_dist) * 2
		score += maxi(0, OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX - nearest_enemy_dist)
		score += _zone_role_score(_tile_zone(state, owner_id, pos), to_type)
		if to_type == "melee" or to_type == "defense":
			score += 8
		elif to_type == "ranged":
			score += 6
			score -= _ranged_saturation_penalty(state, owner_id)

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

func _best_progression_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _can_convert_block(state, block):
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type != "basic":
			continue

		var pos: Vector2i = block["pos"]
		var frontier_open: int = _adjacent_open_ground_count(state, pos)
		if frontier_open <= 0:
			continue

		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		var heart_dist: int = _nearest_hostile_heart_distance(state, owner_id, pos)
		var door_dist: int = _distance_to_tile(pos, state.door_tile)
		var door_relevant: bool = _can_attack_door(state, owner_id) and state.door_hp > 0
		var objective_dist: int = heart_dist
		if door_relevant:
			objective_dist = mini(objective_dist, door_dist)

		var zone: String = _tile_zone(state, owner_id, pos)
		var support: int = state.count_owned_within_manhattan(owner_id, pos, 2)

		var to_type: String = "melee"
		if _is_frontline_tile(state, owner_id, pos) or nearest_enemy_dist <= 3:
			to_type = "melee"
		elif support <= 2:
			to_type = "defense"
		elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
			to_type = "ranged"
		elif door_relevant and door_dist <= 6:
			to_type = "melee"

		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = 20
		score += frontier_open * 5
		score += maxi(0, 20 - objective_dist) * 2
		score += maxi(0, 12 - nearest_enemy_dist) * 2
		score += int(round(_heart_objective_score(state, owner_id, pos) * 0.5))
		score += int(round(_door_objective_score(state, owner_id, pos) * 0.5))
		score += _zone_role_score(zone, to_type)
		if to_type == "ranged":
			score -= _ranged_saturation_penalty(state, owner_id)
		if zone == "backline" and to_type == "melee":
			score -= 6
		if support <= 1:
			score -= 6

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

func _best_threat_response_action(
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
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)

	if conversions_used < MAX_CONVERSIONS_PER_TURN:
		for block in state.get_owner_blocks(owner_id):
			if bool(block.get("core", false)):
				continue
			var block_id: int = int(block["id"])
			if reserved_convert_blocks.has(block_id):
				continue
			if not _can_convert_block(state, block):
				continue
			if not _is_frontline_tile(state, owner_id, block["pos"]):
				continue
			var threat: int = _local_threat_score(state, owner_id, block["pos"])
			if threat < THREAT_SPIKE_THRESHOLD:
				continue
			var from_type: String = String(block.get("tile_type", "basic"))
			if from_type == "defense":
				continue
			var delta: int = Combat.conversion_energy_delta(from_type, "defense")
			if delta > energy:
				continue
			var score: int = 90 + threat * 3 + _door_objective_score(state, owner_id, block["pos"])
			score += _heart_objective_score(state, owner_id, block["pos"])
			if score > best_score:
				best_score = score
				best = {
					"score": score,
					"action": {
						"type": "convert_tile",
						"owner": owner_id,
						"block_id": block_id,
						"to_type": "defense",
						"energy_delta": delta,
					}
				}

	for block in state.get_owner_blocks(owner_id):
		var anchor: Vector2i = block["pos"]
		var threat_score: int = _local_threat_score(state, owner_id, anchor)
		if threat_score < THREAT_SPIKE_THRESHOLD:
			continue
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var tile: Vector2i = anchor + step
			if not state.is_empty_ground(tile):
				continue
			var tile_key: String = _tile_key(tile)
			if planned_tiles.has(tile_key) or reserved_place_tiles.has(tile_key):
				continue
			if not bool(state.evaluate_growth_target(owner_id, tile, min_adjacent, planned_tiles).get("ok", false)):
				continue
			var cost: int = int(Combat.TILE_RULES["defense"]["cost"])
			if cost > energy:
				continue
			var zone_score: int = 0
			if _is_frontline_tile(state, owner_id, tile):
				zone_score = 12
			elif _is_second_line_tile(state, owner_id, tile):
				zone_score = 5
			var score: int = 70 + threat_score * 2 + zone_score + _door_objective_score(state, owner_id, tile)
			score += _heart_objective_score(state, owner_id, tile)
			if score > best_score:
				best_score = score
				best = {
					"score": score,
					"action": {
						"type": "place_tile",
						"owner": owner_id,
						"target": tile,
						"tile_type": "defense",
						"cost": cost,
						"min_adjacent": min_adjacent,
					}
				}

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
	var baseline_objective_dist: int = _owner_objective_frontier_distance(state, owner_id)
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
			var zone: String = _tile_zone(state, owner_id, tile)
			var tile_type: String = _preferred_place_type_for_zone(state, owner_id, tile, zone, adjacent_enemy, nearest_enemy_dist, support, energy)

			var cost: int = int(Combat.TILE_RULES[tile_type]["cost"])
			if cost > energy:
				continue

			var score: int = 50
			score += adjacent_enemy * 24
			score += maxi(0, 8 - nearest_enemy_dist) * 5
			score += support * 3
			score += _chokepoint_score(state, tile) * CHOKEPOINT_WEIGHT
			score += _door_objective_score(state, owner_id, tile)
			score += _heart_objective_score(state, owner_id, tile)
			score += _objective_progress_delta_score(state, owner_id, tile, baseline_objective_dist, false)
			score += _zone_role_score(zone, tile_type)
			if support <= 1:
				score -= 8
			if tile_type == "defense":
				score += 8
			elif tile_type == "melee":
				score += 10

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
	reserved_place_tiles: Dictionary,
	engaged: bool
) -> Dictionary:
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var baseline_objective_dist: int = _owner_objective_frontier_distance(state, owner_id)
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
			var zone: String = _tile_zone(state, owner_id, tile)

			var tile_type: String = _preferred_place_type_for_zone(state, owner_id, tile, zone, adjacent_enemy, nearest_enemy_dist, support, energy)

			var cost: int = int(Combat.TILE_RULES[tile_type]["cost"])
			if cost > energy:
				continue

			var score: int = 0
			score += maxi(0, 12 - nearest_enemy_dist) * 7
			score += adjacent_enemy * 14
			score += support * 3
			score += _chokepoint_score(state, tile) * CHOKEPOINT_WEIGHT
			score += _door_objective_score(state, owner_id, tile)
			score += _heart_objective_score(state, owner_id, tile)
			score += _objective_progress_delta_score(state, owner_id, tile, baseline_objective_dist, not engaged)
			score += _zone_role_score(zone, tile_type)
			if engaged and tile_type == "basic" and zone != "frontline":
				score -= ENGAGED_BASIC_EXPANSION_PENALTY
			if _is_second_line_tile(state, owner_id, tile) and tile_type == "ranged":
				score += 18
			if support <= 1:
				score -= 14

			var resource_dist: int = _nearest_open_resource_distance(state, tile)
			if resource_dist <= 6:
				score += maxi(0, 6 - resource_dist) * 2

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
	reserved_place_tiles: Dictionary,
	avoid_high_pressure_zones: bool
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

		var zone: String = _tile_zone(state, owner_id, tile)
		if avoid_high_pressure_zones:
			if zone == "frontline" or zone == "second_line":
				continue
			if _local_threat_score(state, owner_id, tile) >= THREAT_SPIKE_THRESHOLD:
				continue

		var support: int = state.count_owned_within_manhattan(owner_id, tile, 2, planned_tiles)
		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
		var score: int = 16
		score += support * 3
		score += maxi(0, 8 - nearest_enemy_dist)
		score += int(round(_door_objective_score(state, owner_id, tile) * 0.15))
		score += int(round(_heart_objective_score(state, owner_id, tile) * 0.2))
		score += _chokepoint_score(state, tile) * 2
		if support <= 1:
			score -= 8
		if zone == "backline":
			score += 16
		elif zone == "second_line":
			score -= 10
		else:
			score -= 24
		if _local_threat_score(state, owner_id, tile) >= THREAT_SPIKE_THRESHOLD:
			score -= 20

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
	_planned_actions: Array,
	energy: int,
	reserved_convert_blocks: Dictionary
) -> Dictionary:
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
		if nearest_dist < 2 or nearest_dist > 4:
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type == "ranged":
			continue
		var to_type: String = "ranged"
		if _is_ranged_hard_capped(state, owner_id):
			to_type = "defense"
		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = _conversion_score(state, owner_id, block, from_type, to_type, false)
		if _is_second_line_tile(state, owner_id, pos):
			score += 12
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

func _best_tile_upgrade_action(
	state: GameState,
	owner_id: int,
	energy: int,
	reserved_convert_blocks: Dictionary,
	prefer_frontline: bool
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -999999
	var objective_baseline_dist: int = _owner_objective_frontier_distance(state, owner_id)
	for block in state.get_owner_blocks(owner_id):
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _can_upgrade_block(block):
			continue

		var tile_type: String = String(block.get("tile_type", "basic"))
		var cost: int = Combat.upgrade_energy_cost(state, owner_id, tile_type)
		if cost <= 0 or cost > energy:
			continue

		var pos: Vector2i = block["pos"]
		var zone: String = _tile_zone(state, owner_id, pos)
		if tile_type in ["defense", "melee"] and zone != "frontline":
			continue
		if tile_type == "ranged" and zone != "second_line":
			continue
		if tile_type == "gather" and zone != "backline":
			continue
		if tile_type == "gather" and int(block.get("gather_bonus", 0)) <= 0:
			continue

		var must_keep_reserve: int = int(Combat.TILE_RULES["basic"]["cost"]) + TILE_UPGRADE_SURPLUS_RESERVE
		if energy - cost < must_keep_reserve:
			continue

		var support: int = state.count_owned_within_manhattan(owner_id, pos, 2)
		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		var objective_delta_score: int = _objective_progress_delta_score(state, owner_id, pos, objective_baseline_dist, false)
		var score: int = 0
		match tile_type:
			"defense":
				score = 84 if zone == "frontline" else 38
			"melee":
				score = 80 if zone == "frontline" else 34
			"ranged":
				score = 74 if zone == "second_line" else (24 if zone == "backline" else 4)
			"gather":
				score = 46 if zone == "backline" else 18
			_:
				score = 0

		if prefer_frontline and zone == "frontline":
			score += 12
		if zone == "frontline" and tile_type == "ranged":
			score -= 18
		score += _door_objective_score(state, owner_id, pos)
		score += int(round(_heart_objective_score(state, owner_id, pos) * 0.8))
		score += support * 2
		score += maxi(0, 8 - nearest_enemy_dist) * 2
		if tile_type == "gather":
			var income_gap: int = maxi(0, MID_ECON_INCOME_THRESHOLD - _estimated_owner_income(state, owner_id))
			score += income_gap * 6
		score += objective_delta_score
		score -= cost * 5

		if score > best_score:
			best_score = score
			best = {
				"score": score,
				"action": {
					"type": "upgrade_tile",
					"owner": owner_id,
					"block_id": block_id,
					"tile_type": tile_type,
					"cost": cost,
					"planned_type_count": 0,
					"planned_total_count": 0,
				}
			}
	if best_score < TILE_UPGRADE_MIN_SCORE:
		return {}
	return best

func _reserve_action(action: Dictionary, reserved_place_tiles: Dictionary, reserved_convert_blocks: Dictionary) -> void:
	var kind: String = String(action.get("type", "pass"))
	if kind == "place_tile":
		var tile: Vector2i = action.get("target", Vector2i(-1, -1))
		reserved_place_tiles[_tile_key(tile)] = true
	elif kind == "convert_tile" or kind == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if block_id >= 0:
			reserved_convert_blocks[block_id] = true

func _should_prioritize_early_economy(state: GameState, owner_id: int) -> bool:
	if state.turn_index <= EARLY_ECON_TURN_WINDOW:
		return true
	return _estimated_owner_income(state, owner_id) < EARLY_ECON_INCOME_THRESHOLD

func _should_seek_midgame_gather(state: GameState, owner_id: int, energy: int, engaged: bool) -> bool:
	if _count_gather_tiles(state, owner_id) >= MID_GATHER_TARGET:
		return false
	var income: int = _estimated_owner_income(state, owner_id)
	if income < MID_ECON_INCOME_THRESHOLD:
		return true
	if energy <= MID_ECON_ENERGY_LOW_THRESHOLD:
		return true
	if engaged and income >= MID_ECON_INCOME_THRESHOLD:
		return false
	return false

func _estimated_owner_income(state: GameState, owner_id: int) -> int:
	var base_income: int = 2 if state.get_owner_blocks(owner_id).size() > 0 else 0
	var gather_income: int = 0
	for block in state.get_owner_blocks(owner_id):
		if String(block.get("tile_type", "basic")) == "gather":
			gather_income += 1 + int(block.get("gather_bonus", 0)) + int(block.get("gather_upgrade_bonus", 0))
	return base_income + gather_income

func _count_gather_tiles(state: GameState, owner_id: int) -> int:
	var total: int = 0
	for block in state.get_owner_blocks(owner_id):
		if String(block.get("tile_type", "basic")) == "gather":
			total += 1
	return total

func _is_frontline_conversion(state: GameState, owner_id: int, action: Dictionary) -> bool:
	if String(action.get("type", "")) != "convert_tile":
		return false
	var block_id: int = int(action.get("block_id", -1))
	if block_id < 0 or not state.blocks.has(block_id):
		return false
	return _is_frontline_tile(state, owner_id, state.blocks[block_id]["pos"])

func _is_second_line_conversion(state: GameState, owner_id: int, action: Dictionary) -> bool:
	if String(action.get("type", "")) != "convert_tile":
		return false
	var block_id: int = int(action.get("block_id", -1))
	if block_id < 0 or not state.blocks.has(block_id):
		return false
	return _is_second_line_tile(state, owner_id, state.blocks[block_id]["pos"])

func _is_owner_engaged(state: GameState, owner_id: int) -> bool:
	for block in state.get_owner_blocks(owner_id):
		if _is_frontline_tile(state, owner_id, block["pos"]):
			return true
	return false

func _can_afford_any_upgrade(energy: int) -> bool:
	var cheapest_conversion: int = mini(
		int(Combat.TILE_RULES["melee"]["cost"]),
		mini(int(Combat.TILE_RULES["ranged"]["cost"]), mini(int(Combat.TILE_RULES["defense"]["cost"]), int(Combat.TILE_RULES["gather"]["cost"])))
	)
	var cheapest_tile_upgrade: int = 999999
	for role in Combat.UPGRADE_BASE_COST.keys():
		cheapest_tile_upgrade = mini(cheapest_tile_upgrade, int(Combat.UPGRADE_BASE_COST[role]))
	var cheapest: int = mini(cheapest_conversion, cheapest_tile_upgrade)
	return energy >= cheapest

func _has_viable_engagement_upgrade(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> bool:
	if _best_frontline_upgrade_action(state, owner_id, energy, reserved_convert_blocks).is_empty():
		return not _best_second_line_ranged_upgrade_action(state, owner_id, energy, reserved_convert_blocks).is_empty()
	return true

func _tile_zone(state: GameState, owner_id: int, tile: Vector2i) -> String:
	if _is_frontline_tile(state, owner_id, tile):
		return "frontline"
	if _is_second_line_tile(state, owner_id, tile):
		return "second_line"
	return "backline"

func _preferred_place_type_for_zone(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	zone: String,
	adjacent_enemy: int,
	nearest_enemy_dist: int,
	support: int,
	energy: int
) -> String:
	if zone == "frontline":
		if _local_threat_score(state, owner_id, tile) >= THREAT_SPIKE_THRESHOLD and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
		if support <= 2 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
		if energy >= int(Combat.TILE_RULES["melee"]["cost"]):
			return "melee"
	if zone == "second_line":
		var choke_score: int = _chokepoint_score(state, tile)
		if support >= 2 and choke_score >= 2 and not _is_ranged_hard_capped(state, owner_id) and energy >= int(Combat.TILE_RULES["ranged"]["cost"]):
			return "ranged"
		if support >= 3 and not _is_ranged_hard_capped(state, owner_id) and energy >= int(Combat.TILE_RULES["ranged"]["cost"]):
			return "ranged"
		if adjacent_enemy > 0 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
		if nearest_enemy_dist <= 3 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
			return "melee"
	if zone == "backline":
		if nearest_enemy_dist <= 3 and support >= 3 and not _is_ranged_hard_capped(state, owner_id) and energy >= int(Combat.TILE_RULES["ranged"]["cost"]):
			return "ranged"
		if adjacent_enemy > 0 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
	if nearest_enemy_dist <= 2 and support >= 2 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
		return "melee"
	return "basic"

func _zone_role_score(zone: String, tile_type: String) -> int:
	if zone == "frontline":
		if tile_type == "defense":
			return 22
		if tile_type == "melee":
			return 18
		if tile_type == "ranged":
			return -18
	if zone == "second_line":
		if tile_type == "ranged":
			return 24
		if tile_type == "defense":
			return 6
		if tile_type == "melee":
			return -6
	if zone == "backline":
		if tile_type == "ranged":
			return -6
		if tile_type == "gather":
			return 12
		if tile_type == "defense":
			return -8
		if tile_type == "melee":
			return -12
	return 0

func _door_objective_score(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var dist: int = _distance_to_tile(tile, state.door_tile)
	var base: int = maxi(0, 10 - dist)
	if _can_attack_door(state, owner_id):
		return base * DOOR_ADVANCE_WEIGHT

	var enemy_near_door: int = _hostile_near_door_count(state, owner_id, 5)
	if enemy_near_door <= 0:
		return 0
	return base * DOOR_DEFEND_WEIGHT + enemy_near_door * 6

func _hostile_near_door_count(state: GameState, owner_id: int, radius: int) -> int:
	var count: int = 0
	for block in state.blocks.values():
		if not state.are_hostile(owner_id, int(block["owner"])):
			continue
		if _distance_to_tile(state.door_tile, block["pos"]) <= radius:
			count += 1
	return count

func _adjacent_open_ground_count(state: GameState, tile: Vector2i) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t: Vector2i = tile + step
		if state.is_empty_ground(t):
			count += 1
	return count

func _local_threat_score(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var threat: int = 0
	for enemy in state.blocks.values():
		var enemy_owner: int = int(enemy["owner"])
		if not state.are_hostile(owner_id, enemy_owner):
			continue
		var enemy_pos: Vector2i = enemy["pos"]
		var dist: int = _distance_to_tile(tile, enemy_pos)
		if dist > THREAT_SCAN_RADIUS:
			continue
		var weight: int = 2
		var enemy_type: String = String(enemy.get("tile_type", "basic"))
		if enemy_type == "melee":
			weight += 4
		elif enemy_type == "ranged":
			weight += 2
		elif enemy_type == "defense":
			weight += 3
		var enemy_support: int = state.count_owned_within_manhattan(enemy_owner, enemy_pos, 2)
		if enemy_support >= 5:
			weight += 2
		weight += maxi(0, THREAT_SCAN_RADIUS + 1 - dist)
		threat += weight
	return threat

# Penalize low-impact backline role churn, reward pressure-positive role shifts.
func _conversion_score(state: GameState, owner_id: int, block: Dictionary, from_type: String, to_type: String, is_frontline_target: bool) -> int:
	var pos: Vector2i = block["pos"]
	var support: int = state.count_owned_within_manhattan(owner_id, pos, 2)
	var pressure: int = _enemy_pressure_score(state, owner_id, pos)
	var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
	var zone: String = _tile_zone(state, owner_id, pos)
	var score: int = 0

	score += pressure * 2
	score += support
	score += maxi(0, 8 - nearest_enemy_dist) * 3
	score += _door_objective_score(state, owner_id, pos)
	score += _heart_objective_score(state, owner_id, pos)
	score += _zone_role_score(zone, to_type)

	if is_frontline_target:
		score += 20
	if not is_frontline_target and nearest_enemy_dist >= 5:
		score -= 30

	if to_type == "defense":
		score += 6 if is_frontline_target else -8
	elif to_type == "melee":
		score += 5 if is_frontline_target else -6
	elif to_type == "ranged":
		score += 10 if nearest_enemy_dist >= 2 and nearest_enemy_dist <= 4 else -12
		score -= _ranged_saturation_penalty(state, owner_id)
		var choke: int = _chokepoint_score(state, pos)
		if zone == "second_line" and choke >= 2:
			score += 10
		if is_frontline_target or nearest_enemy_dist <= 1:
			score -= RANGED_FRONTLINE_PENALTY
		elif zone == "backline":
			score -= RANGED_BACKLINE_PENALTY
	elif to_type == "gather":
		score -= 12

	if from_type in ["defense", "melee"] and to_type in ["defense", "melee"] and not is_frontline_target:
		score -= 14

	return score

func _is_ranged_hard_capped(state: GameState, owner_id: int) -> bool:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	var total_tiles: int = owner_blocks.size()
	if total_tiles < RANGED_SATURATION_MIN_TILES:
		return false
	return _owner_type_ratio(owner_blocks, "ranged") >= RANGED_SATURATION_HARD_CAP

func _ranged_saturation_penalty(state: GameState, owner_id: int) -> int:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	var total_tiles: int = owner_blocks.size()
	if total_tiles < RANGED_SATURATION_MIN_TILES:
		return 0
	var ratio: float = _owner_type_ratio(owner_blocks, "ranged")
	if ratio <= RANGED_SATURATION_SOFT_CAP:
		return 0
	var band: float = maxf(0.0001, RANGED_SATURATION_HARD_CAP - RANGED_SATURATION_SOFT_CAP)
	var t: float = clampf((ratio - RANGED_SATURATION_SOFT_CAP) / band, 0.0, 1.0)
	return int(round(float(RANGED_SATURATION_MAX_PENALTY) * t))

func _owner_type_ratio(owner_blocks: Array, tile_type: String) -> float:
	if owner_blocks.is_empty():
		return 0.0
	var matches: int = 0
	for block in owner_blocks:
		if String(block.get("tile_type", "basic")) == tile_type:
			matches += 1
	return float(matches) / float(owner_blocks.size())

func _desired_frontline_role(state: GameState, owner_id: int, block: Dictionary) -> String:
	var pressure: int = _enemy_pressure_score(state, owner_id, block["pos"])
	var support: int = state.count_owned_within_manhattan(owner_id, block["pos"], 2)
	var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, block["pos"])
	var threat: int = _local_threat_score(state, owner_id, block["pos"])
	if pressure >= 6 or support <= 2:
		return "defense"
	if threat >= THREAT_SPIKE_THRESHOLD:
		return "defense"
	if adjacent_enemy >= 2 and support >= 3:
		return "melee"
	return "melee"

func _can_convert_block(state: GameState, block: Dictionary) -> bool:
	if String(block.get("tile_type", "basic")) != "basic":
		return false
	var last_turn: int = int(block.get("last_converted_turn", -999999))
	return state.turn_index - last_turn >= CONVERSION_COOLDOWN_TURNS

func _can_upgrade_block(block: Dictionary) -> bool:
	var tile_type: String = String(block.get("tile_type", "basic"))
	if tile_type == "basic":
		return false
	if not Combat.UPGRADE_BASE_COST.has(tile_type):
		return false
	return int(block.get("upgrade_tier", 0)) < 1

func _is_frontline_tile(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	return _adjacent_enemy_count(state, owner_id, tile) > 0

func _adjacent_enemy_count(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var block: Dictionary = state.get_block_at(tile + step)
		if block.is_empty():
			continue
		if not state.are_hostile(owner_id, int(block["owner"])):
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
	if kind == "upgrade_tile":
		return int(action.get("cost", 0))
	return 0

# Pressure and map-shape helpers.
func _nearest_enemy_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var best: int = 999999
	for enemy in state.blocks.values():
		if not state.are_hostile(owner_id, int(enemy["owner"])):
			continue
		best = mini(best, _distance_to_tile(tile, enemy["pos"]))
	return best if best < 999999 else 99

func _enemy_pressure_score(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var pressure: int = 0
	for enemy in state.blocks.values():
		if not state.are_hostile(owner_id, int(enemy["owner"])):
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

func _nearest_open_resource_distance(state: GameState, tile: Vector2i) -> int:
	var best: int = 999999
	for node in state.resource_nodes:
		if bool(node.get("consumed", false)):
			continue
		best = mini(best, _distance_to_tile(tile, node["pos"]))
	return best if best < 999999 else 99

func _is_second_line_tile(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	if _is_frontline_tile(state, owner_id, tile):
		return false
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Dictionary = state.get_block_at(tile + step)
		if neighbor.is_empty():
			continue
		if int(neighbor["owner"]) != owner_id:
			continue
		if _is_frontline_tile(state, owner_id, neighbor["pos"]):
			return true
	return false

func _is_near_front_tile(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	if _is_frontline_tile(state, owner_id, tile):
		return true
	return _is_second_line_tile(state, owner_id, tile)

func _distance_to_tile(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _can_attack_door(state: GameState, owner_id: int) -> bool:
	return not state.are_hostile(owner_id, GameState.PLAYER_ID)

func _heart_objective_score(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var nearest_heart_dist: int = _nearest_hostile_heart_distance(state, owner_id, tile)
	if nearest_heart_dist >= 99:
		return 0
	var score: int = maxi(0, 12 - nearest_heart_dist) * HEART_OBJECTIVE_WEIGHT
	score += _adjacent_hostile_heart_count(state, owner_id, tile) * 24
	return score

func _objective_progress_delta_score(state: GameState, owner_id: int, tile: Vector2i, baseline_dist: int, stricter_backfill_penalty: bool) -> int:
	if baseline_dist >= 99:
		return 0
	var candidate_dist: int = _primary_objective_distance(state, owner_id, tile)
	if candidate_dist >= 99:
		return 0
	var delta: int = baseline_dist - candidate_dist
	var score: int = delta * OBJECTIVE_PROGRESS_WEIGHT
	if delta <= 0:
		score -= OBJECTIVE_BACKFILL_PENALTY
		if stricter_backfill_penalty:
			score -= 10
	return score

func _owner_objective_frontier_distance(state: GameState, owner_id: int) -> int:
	var best: int = 999999
	for block in state.get_owner_blocks(owner_id):
		best = mini(best, _primary_objective_distance(state, owner_id, block["pos"]))
	return best if best < 999999 else 99

func _primary_objective_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var heart_dist: int = _nearest_hostile_heart_distance(state, owner_id, tile)
	if _can_attack_door(state, owner_id) and state.door_hp > 0:
		var door_dist: int = _distance_to_tile(tile, state.door_tile)
		return mini(heart_dist, door_dist)
	return heart_dist

func _nearest_hostile_heart_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var best: int = 999999
	for block in state.blocks.values():
		if not bool(block.get("is_heart", false)):
			continue
		if not state.are_hostile(owner_id, int(block["owner"])):
			continue
		best = mini(best, _distance_to_tile(tile, block["pos"]))
	return best if best < 999999 else 99

func _adjacent_hostile_heart_count(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var target: Dictionary = state.get_block_at(tile + step)
		if target.is_empty():
			continue
		if not bool(target.get("is_heart", false)):
			continue
		if not state.are_hostile(owner_id, int(target["owner"])):
			continue
		count += 1
	return count

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
