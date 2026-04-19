extends RefCounted
class_name Combat

# Combat applies staged placements/conversions, then resolves passive damage.
# Order is deterministic so previews and outcomes stay stable.

const TILE_RULES: Dictionary = {
	"basic": {"max_hp": 9, "defense": 0, "damage": 0, "range": 1, "cost": 1},
	"gather": {"max_hp": 8, "defense": 0, "damage": 0, "range": 1, "cost": 4},
	"defense": {"max_hp": 18, "defense": 3, "damage": 0, "range": 1, "cost": 3},
	"melee": {"max_hp": 10, "defense": 0, "damage": 2, "range": 1, "cost": 3},
	"ranged": {"max_hp": 8, "defense": 0, "damage": 2, "range": 4, "cost": 3},
}

const SUPPORT_RADIUS: int = 2
const SUPPORT_DIVISOR: int = 3
const SUPPORT_MAX_BONUS: int = 3
const DEFENSE_GUARD_MAX: int = 2
const DEFENSE_GUARD_PER_ADJACENT: int = 1
const STABILITY_FRAGILE_AGE: int = 0
const STABILITY_REINFORCED_AGE: int = 2

static func conversion_energy_delta(from_type: String, to_type: String) -> int:
	if from_type == to_type:
		return 0
	if to_type == "basic":
		return 0
	if from_type == "basic":
		return int(TILE_RULES[to_type]["cost"])
	return 2

func resolve(actions: Array, state: GameState) -> Array[String]:
	var report: Dictionary = resolve_with_report(actions, state)
	return report.get("log", [])

func resolve_with_report(actions: Array, state: GameState) -> Dictionary:
	var report: Dictionary = _apply_staged_actions(actions, state, true)
	var log: Array[String] = report.get("log", [])

	_resolve_melee_damage(state, log)
	_resolve_ranged_damage(state, log)

	var removed: Array[int] = state.remove_dead_blocks()
	for block_id in removed:
		log.append("Block %d dissolved" % block_id)

	report["log"] = log
	return report

func preview_resolution(state: GameState, actions: Array) -> Dictionary:
	var preview_state: GameState = state.copy_state()
	return _apply_staged_actions(actions, preview_state, false)

func _apply_staged_actions(actions: Array, state: GameState, log_failures: bool) -> Dictionary:
	var ordered: Array = _order_actions(actions)
	var log: Array[String] = []
	var applied_actions: Array = []
	var failed_actions: Array = []
	var results_by_preview_id: Dictionary = {}

	for action in ordered:
		var kind: String = String(action.get("type", "pass"))
		var result: Dictionary = {"applied": false, "reason": "unsupported action"}
		match kind:
			"place_tile":
				result = _apply_place_tile(action, state, log, log_failures)
			"convert_tile":
				result = _apply_convert_tile(action, state, log, log_failures)
			"pass":
				result = {"applied": true}
			_:
				result = {"applied": false, "reason": "unsupported action"}

		var public_action: Dictionary = _public_action_copy(action)
		if bool(result.get("applied", false)):
			applied_actions.append(public_action)
		else:
			var failed: Dictionary = public_action.duplicate(true)
			failed["reason"] = String(result.get("reason", "failed"))
			failed_actions.append(failed)

		var preview_id: String = String(action.get("_preview_id", ""))
		if not preview_id.is_empty():
			results_by_preview_id[preview_id] = {
				"applied": bool(result.get("applied", false)),
				"reason": String(result.get("reason", "")),
			}

	return {
		"ordered_actions": _strip_internal_keys_from_actions(ordered),
		"applied_actions": applied_actions,
		"failed_actions": failed_actions,
		"results_by_preview_id": results_by_preview_id,
		"log": log,
	}

func _sort_actions(a: Dictionary, b: Dictionary) -> bool:
	var weights: Dictionary = {"convert_tile": 0, "place_tile": 1, "pass": 2}
	var type_weight_a: int = int(weights.get(String(a.get("type", "pass")), 99))
	var type_weight_b: int = int(weights.get(String(b.get("type", "pass")), 99))
	if type_weight_a != type_weight_b:
		return type_weight_a < type_weight_b

	var owner_a: int = int(a.get("owner", 999999))
	var owner_b: int = int(b.get("owner", 999999))
	var owner_priority_a: int = _owner_priority(owner_a)
	var owner_priority_b: int = _owner_priority(owner_b)
	if owner_priority_a != owner_priority_b:
		return owner_priority_a < owner_priority_b

	if owner_a != owner_b:
		return owner_a < owner_b

	return int(a.get("_order_index", 0)) < int(b.get("_order_index", 0))

func _order_actions(actions: Array) -> Array:
	var ordered: Array = []
	for i in range(actions.size()):
		var action: Dictionary = actions[i].duplicate(true)
		action["_order_index"] = i
		ordered.append(action)
	ordered.sort_custom(Callable(self, "_sort_actions"))
	return ordered

func _owner_priority(owner_id: int) -> int:
	return 0 if owner_id == GameState.PLAYER_ID else 1

func validate_place_action(action: Dictionary, state: GameState) -> Dictionary:
	var owner: int = int(action.get("owner", 0))
	var tile_type: String = String(action.get("tile_type", "basic"))
	if not TILE_RULES.has(tile_type):
		return {"ok": false, "reason": "unknown tile type"}

	var pos: Vector2i = action.get("target", Vector2i(-1, -1))
	var min_adjacent: int = int(action.get("min_adjacent", 2))
	var cost: int = int(action.get("cost", int(TILE_RULES[tile_type]["cost"])))

	if not state.players.has(owner):
		return {"ok": false, "reason": "unknown owner"}
	if pos == state.door_tile:
		return {"ok": false, "reason": "exit tile"}
	if not state.is_empty_ground(pos):
		return {"ok": false, "reason": "not empty"}
	var growth_check: Dictionary = state.evaluate_growth_target(owner, pos, min_adjacent, {})
	if not bool(growth_check.get("ok", false)):
		return growth_check
	if int(state.players[owner]["nutrients"]) < cost:
		return {"ok": false, "reason": "insufficient energy"}

	return {"ok": true}

func _apply_place_tile(action: Dictionary, state: GameState, log: Array[String], log_failures: bool) -> Dictionary:
	var check: Dictionary = validate_place_action(action, state)
	if not bool(check.get("ok", false)):
		var reason: String = String(check.get("reason", "invalid placement"))
		if log_failures:
			log.append("Action failed (place): %s" % reason)
		return {"applied": false, "reason": reason}

	var owner: int = int(action.get("owner", 0))
	var tile_type: String = String(action.get("tile_type", "basic"))
	var pos: Vector2i = action.get("target", Vector2i(-1, -1))
	var cost: int = int(action.get("cost", int(TILE_RULES[tile_type]["cost"])))

	state.players[owner]["nutrients"] = int(state.players[owner]["nutrients"]) - cost
	var block_id: int = state.spawn_block(owner, pos, false, int(TILE_RULES[tile_type]["max_hp"]), tile_type)
	var block: Dictionary = state.blocks[block_id]
	_apply_tile_stats(block, tile_type)
	_refresh_gather_bonus(state, block)
	state.blocks[block_id] = block

	log.append("Owner %d placed %s at (%d,%d)" % [owner, tile_type, pos.x, pos.y])
	return {"applied": true}

func validate_convert_action(action: Dictionary, state: GameState) -> Dictionary:
	var owner: int = int(action.get("owner", 0))
	var block_id: int = int(action.get("block_id", -1))
	var to_type: String = String(action.get("to_type", "basic"))
	if not TILE_RULES.has(to_type):
		return {"ok": false, "reason": "unknown tile type"}

	if not state.players.has(owner):
		return {"ok": false, "reason": "unknown owner"}
	if not state.blocks.has(block_id):
		return {"ok": false, "reason": "missing block"}

	var block: Dictionary = state.blocks[block_id]
	if int(block["owner"]) != owner:
		return {"ok": false, "reason": "not owned"}

	var from_type: String = String(block.get("tile_type", "basic"))
	if from_type == to_type:
		return {"ok": false, "reason": "already target type"}

	var energy_delta: int = int(action.get("energy_delta", conversion_energy_delta(from_type, to_type)))
	if energy_delta > 0 and int(state.players[owner]["nutrients"]) < energy_delta:
		return {"ok": false, "reason": "insufficient energy"}

	return {"ok": true}

func _apply_convert_tile(action: Dictionary, state: GameState, log: Array[String], log_failures: bool) -> Dictionary:
	var check: Dictionary = validate_convert_action(action, state)
	if not bool(check.get("ok", false)):
		var reason: String = String(check.get("reason", "invalid conversion"))
		if log_failures:
			log.append("Action failed (convert): %s" % reason)
		return {"applied": false, "reason": reason}

	var owner: int = int(action.get("owner", 0))
	var block_id: int = int(action.get("block_id", -1))
	var to_type: String = String(action.get("to_type", "basic"))
	var block: Dictionary = state.blocks[block_id]
	var from_type: String = String(block.get("tile_type", "basic"))
	var energy_delta: int = int(action.get("energy_delta", conversion_energy_delta(from_type, to_type)))

	state.players[owner]["nutrients"] = int(state.players[owner]["nutrients"]) - energy_delta
	block["tile_type"] = to_type
	block["last_converted_turn"] = state.turn_index
	_apply_tile_stats(block, to_type)

	var new_max_hp: int = int(TILE_RULES[to_type]["max_hp"])
	block["max_hp"] = new_max_hp
	block["hp"] = mini(int(block["hp"]), new_max_hp)
	if int(block["hp"]) <= 0:
		block["hp"] = new_max_hp

	_refresh_gather_bonus(state, block)
	state.blocks[block_id] = block
	log.append("Owner %d converted block %d: %s -> %s" % [owner, block_id, from_type, to_type])
	return {"applied": true}

func _apply_tile_stats(block: Dictionary, tile_type: String) -> void:
	var rules: Dictionary = TILE_RULES[tile_type]
	block["defense"] = int(rules["defense"])
	block["damage"] = int(rules["damage"])
	block["range"] = int(rules["range"])
	if tile_type != "gather":
		block["gather_bonus"] = 0

func _refresh_gather_bonus(state: GameState, block: Dictionary) -> void:
	block["gather_bonus"] = 0
	if String(block.get("tile_type", "basic")) != "gather":
		return

	var node: Dictionary = state.get_resource_node_at(block["pos"])
	if node.is_empty():
		return
	if bool(node.get("consumed", false)):
		block["gather_bonus"] = Economy.GATHER_RESOURCE_BONUS

func _resolve_melee_damage(state: GameState, log: Array[String]) -> void:
	var pending_damage: Dictionary = {}

	for block in state.blocks.values():
		var owner: int = int(block["owner"])
		var block_id: int = int(block["id"])
		if String(block.get("tile_type", "basic")) != "melee":
			continue

		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target: Dictionary = state.get_block_at(block["pos"] + step)
			if target.is_empty() or int(target["owner"]) == owner:
				continue
			var target_id: int = int(target["id"])
			var melee_damage: int = _modified_damage(state, owner, int(block.get("damage", 2)))
			pending_damage[target_id] = int(pending_damage.get(target_id, 0)) + melee_damage
			log.append("Melee block %d struck %d" % [block_id, target_id])

	_apply_damage_batch(state, pending_damage)

func _resolve_ranged_damage(state: GameState, log: Array[String]) -> void:
	var pending_damage: Dictionary = {}

	for block in state.blocks.values():
		var owner: int = int(block["owner"])
		var block_id: int = int(block["id"])
		if String(block.get("tile_type", "basic")) != "ranged":
			continue

		var target_id: int = _nearest_enemy_block_id(state, owner, block["pos"], int(block.get("range", 4)))
		if target_id <= 0:
			continue
		var ranged_damage: int = _modified_damage(state, owner, int(block.get("damage", 2)))
		pending_damage[target_id] = int(pending_damage.get(target_id, 0)) + ranged_damage
		log.append("Ranged block %d shot %d" % [block_id, target_id])

	_apply_damage_batch(state, pending_damage)

func _apply_damage_batch(state: GameState, pending_damage: Dictionary) -> void:
	for target_id in pending_damage.keys():
		if not state.blocks.has(target_id):
			continue
		var target: Dictionary = state.blocks[target_id]
		var raw: int = int(pending_damage[target_id])
		var owner: int = int(target["owner"])
		var support_count: int = state.count_owned_within_manhattan(owner, target["pos"], SUPPORT_RADIUS)
		var support_bonus: int = mini(SUPPORT_MAX_BONUS, int(support_count / SUPPORT_DIVISOR))
		var stability_bonus: int = _stability_defense_bonus(int(target.get("age", 0)))
		var guard_bonus: int = _adjacent_defense_guard_bonus(state, int(target["id"]))
		var effective_defense: int = int(target.get("defense", 0)) + support_bonus + stability_bonus + guard_bonus
		var reduced: int = maxi(1, raw - effective_defense)
		target["hp"] = int(target["hp"]) - reduced
		state.blocks[target_id] = target

func _nearest_enemy_block_id(state: GameState, owner_id: int, origin: Vector2i, max_range: int) -> int:
	var best_id: int = -1
	var best_dist: int = 999999
	for block in state.blocks.values():
		if int(block["owner"]) == owner_id:
			continue
		var block_pos: Vector2i = block["pos"]
		var dist: int = absi(origin.x - block_pos.x) + absi(origin.y - block_pos.y)
		if dist <= max_range and dist < best_dist:
			best_dist = dist
			best_id = int(block["id"])
	return best_id

func _modified_damage(state: GameState, owner: int, base_damage: int) -> int:
	if owner != GameState.PLAYER_ID:
		return base_damage
	var multiplier: float = float(state.card_modifiers.get("base_damage_mult", 1.0))
	return maxi(1, int(round(base_damage * multiplier)))

func _stability_defense_bonus(age: int) -> int:
	if age <= STABILITY_FRAGILE_AGE:
		return -1
	if age >= STABILITY_REINFORCED_AGE:
		return 1
	return 0

func _adjacent_defense_guard_bonus(state: GameState, target_id: int) -> int:
	if not state.blocks.has(target_id):
		return 0
	var target: Dictionary = state.blocks[target_id]
	var owner: int = int(target["owner"])
	var pos: Vector2i = target["pos"]
	var guards: int = 0

	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Dictionary = state.get_block_at(pos + step)
		if neighbor.is_empty():
			continue
		if int(neighbor["owner"]) != owner:
			continue
		if String(neighbor.get("tile_type", "basic")) != "defense":
			continue
		guards += DEFENSE_GUARD_PER_ADJACENT

	return mini(DEFENSE_GUARD_MAX, guards)

func _public_action_copy(action: Dictionary) -> Dictionary:
	var out: Dictionary = action.duplicate(true)
	out.erase("_order_index")
	return out

func _strip_internal_keys_from_actions(actions: Array) -> Array:
	var out: Array = []
	for action in actions:
		out.append(_public_action_copy(action))
	return out
