extends RefCounted
class_name Combat

# Combat applies staged placements/conversions, then resolves passive damage.
# Order is deterministic so previews and outcomes stay stable.

const TILE_RULES: Dictionary = {
	"basic": {"max_hp": 9, "defense": 0, "damage": 0, "range": 1, "cost": 2},
	"gather": {"max_hp": 8, "defense": 0, "damage": 0, "range": 1, "cost": 4},
	"defense": {"max_hp": 18, "defense": 3, "damage": 0, "range": 1, "cost": 4},
	"melee": {"max_hp": 10, "defense": 0, "damage": 3, "range": 1, "cost": 4},
	"ranged": {"max_hp": 7, "defense": 0, "damage": 2, "range": 4, "cost": 5},
}

const SUPPORT_RADIUS: int = 2
const SUPPORT_DIVISOR: int = 3
const SUPPORT_MAX_BONUS: int = 2
const DEFENSE_GUARD_MAX: int = 1
const DEFENSE_GUARD_PER_ADJACENT: int = 1
const STABILITY_FRAGILE_AGE: int = 0
const STABILITY_REINFORCED_AGE: int = 2
const HEART_DEFEAT_BURST_ENERGY: int = 6
const RANGED_SPLASH_RATIO: float = 0.4
const RANGED_SPLASH_MAX: int = 1
const RANGED_CONTACT_DAMAGE_PENALTY: int = 1
const MELEE_BREAK_DEFENSE_BONUS: int = 3
const MELEE_BREAK_FORTIFIED_BONUS: int = 2
const FORTIFIED_SUPPORT_THRESHOLD: int = 5
const UPGRADE_BASE_COST: Dictionary = {
	"melee": 6,
	"ranged": 8,
	"defense": 7,
	"gather": 6,
}
const MAX_UPGRADE_TIER: int = 3
const SPECIALIZATION_TIER: int = 1
const UPGRADE_TIER_II_SURCHARGE: int = 4
const UPGRADE_TIER_III_SURCHARGE: int = 9
const UPGRADE_TYPE_STEP_EVERY: int = 1
const UPGRADE_GLOBAL_STEP_EVERY: int = 3
const MELEE_UPGRADE_DAMAGE_BONUS: int = 1
const MELEE_UPGRADE_BREAK_BONUS: int = 1
const RANGED_UPGRADE_RANGE_BONUS: int = 1
const RANGED_UPGRADE_SPLASH_RADIUS_BONUS: int = 1
const DEFENSE_UPGRADE_DEFENSE_BONUS: int = 1
const DEFENSE_UPGRADE_HP_BONUS: int = 4
const DEFENSE_UPGRADE_GUARD_BONUS: int = 1
const GATHER_UPGRADE_INCOME_BONUS: int = 1

static func conversion_energy_delta(from_type: String, to_type: String, from_tier: int = 0) -> int:
	if from_type == to_type:
		return 0
	if to_type == "basic":
		var role_cost: int = int(TILE_RULES.get(from_type, TILE_RULES["basic"]).get("cost", int(TILE_RULES["basic"]["cost"])))
		var normalized_tier: int = maxi(SPECIALIZATION_TIER, from_tier)
		return -_downgrade_refund(role_cost, normalized_tier)
	if from_type == "basic":
		return int(TILE_RULES[to_type]["cost"])
	return 2

static func _downgrade_refund(role_cost: int, tier: int) -> int:
	# Tier I returns the most, Tier II medium, Tier III lowest.
	if tier <= 1:
		return maxi(1, int(ceili(float(role_cost) * 0.75)))
	if tier == 2:
		return maxi(1, int(ceili(float(role_cost) * 0.5)))
	return maxi(1, int(floor(float(role_cost) / 3.0)))

static func upgrade_energy_cost(
	state: GameState,
	owner_id: int,
	tile_type: String,
	planned_type_count: int = 0,
	planned_total_count: int = 0,
	current_tier: int = SPECIALIZATION_TIER
) -> int:
	if not UPGRADE_BASE_COST.has(tile_type):
		return -1
	var target_tier: int = clampi(current_tier + 1, SPECIALIZATION_TIER + 1, MAX_UPGRADE_TIER)
	var base: int = int(UPGRADE_BASE_COST[tile_type])
	var prior_type: int = state.get_upgrade_count(owner_id, tile_type) + maxi(0, planned_type_count)
	var prior_total: int = state.get_total_upgrade_count(owner_id) + maxi(0, planned_total_count)
	var tier_surcharge: int = UPGRADE_TIER_II_SURCHARGE
	if target_tier >= 3:
		tier_surcharge = UPGRADE_TIER_III_SURCHARGE
	return base + tier_surcharge + int(prior_type / UPGRADE_TYPE_STEP_EVERY) + int(prior_total / UPGRADE_GLOBAL_STEP_EVERY)

func resolve(actions: Array, state: GameState) -> Array[String]:
	var report: Dictionary = resolve_with_report(actions, state)
	return report.get("log", [])

func resolve_with_report(actions: Array, state: GameState, include_log: bool = true, compact_report: bool = false) -> Dictionary:
	var report: Dictionary = _apply_staged_actions(actions, state, include_log, compact_report)
	var resolution_log: Array[String] = report.get("log", [])

	_resolve_melee_damage(state, resolution_log, include_log)
	_resolve_ranged_damage(state, resolution_log, include_log)

	var removed_positions: Array[Vector2i] = []
	for block_id_variant in state.blocks.keys():
		var block_id: int = int(block_id_variant)
		var block: Dictionary = state.blocks[block_id]
		if int(block.get("hp", 0)) > 0:
			continue
		removed_positions.append(block.get("pos", Vector2i(-1, -1)))

	var removed: Array[int] = state.remove_dead_blocks()
	for block_id in removed:
		if include_log:
			resolution_log.append("Block %d dissolved" % block_id)
	for tile in removed_positions:
		state.mark_reclaim_block(tile, 1)

	var defeat_report: Dictionary = _resolve_heart_defeats(state, resolution_log, include_log)
	report["defeated_owners"] = defeat_report.get("defeated_owners", [])
	report["player_heart_burst"] = int(defeat_report.get("player_heart_burst", 0))

	report["log"] = resolution_log
	return report

func preview_resolution(state: GameState, actions: Array) -> Dictionary:
	var preview_state: GameState = state.copy_state()
	return _apply_staged_actions(actions, preview_state, false)

func _apply_staged_actions(actions: Array, state: GameState, include_log: bool, compact_report: bool = false) -> Dictionary:
	var ordered: Array = _order_actions(actions)
	var action_log: Array[String] = []
	var applied_actions: Array = []
	var failed_actions: Array = []
	var results_by_preview_id: Dictionary = {}
	var applied_count: int = 0
	var failed_count: int = 0
	var pass_applied_count: int = 0

	for action in ordered:
		var kind: String = String(action.get("type", "pass"))
		var result: Dictionary = {"applied": false, "reason": "unsupported action"}
		match kind:
			"place_tile":
				result = _apply_place_tile(action, state, action_log, include_log)
			"convert_tile":
				result = _apply_convert_tile(action, state, action_log, include_log)
			"upgrade_tile":
				result = _apply_upgrade_tile(action, state, action_log, include_log)
			"pass":
				result = {"applied": true}
			_:
				result = {"applied": false, "reason": "unsupported action"}

		if bool(result.get("applied", false)):
			applied_count += 1
			if String(action.get("type", "")) == "pass":
				pass_applied_count += 1
			if not compact_report:
				var public_action: Dictionary = _public_action_copy(action)
				applied_actions.append(public_action)
		else:
			failed_count += 1
			if not compact_report:
				var failed: Dictionary = _public_action_copy(action)
				failed["reason"] = String(result.get("reason", "failed"))
				failed_actions.append(failed)

		if not compact_report:
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
		"applied_count": applied_count,
		"failed_count": failed_count,
		"pass_applied_count": pass_applied_count,
		"results_by_preview_id": results_by_preview_id,
		"log": action_log,
	}

func _sort_actions(a: Dictionary, b: Dictionary) -> bool:
	# Deterministic action ordering contract:
	# type priority -> owner priority (player first) -> owner id -> queue index.
	# Preview validation relies on this exact ordering.
	var weights: Dictionary = {"convert_tile": 0, "upgrade_tile": 0, "place_tile": 1, "pass": 2}
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
	# Preserve original queue order as final tie-breaker for stable outcomes.
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
	if pos == state.entrance_tile:
		return {"ok": false, "reason": "entrance tile"}
	if pos == state.door_tile:
		return {"ok": false, "reason": "exit tile"}
	if state.is_reclaim_blocked(pos):
		return {"ok": false, "reason": "cell reforming"}
	if not state.is_empty_ground(pos):
		return {"ok": false, "reason": "not empty"}
	var growth_check: Dictionary = state.evaluate_growth_target(owner, pos, min_adjacent, {})
	if not bool(growth_check.get("ok", false)):
		return growth_check
	if int(state.players[owner]["nutrients"]) < cost:
		return {"ok": false, "reason": "insufficient energy"}

	return {"ok": true}

func _apply_place_tile(action: Dictionary, state: GameState, event_log: Array[String], include_log: bool) -> Dictionary:
	var check: Dictionary = validate_place_action(action, state)
	if not bool(check.get("ok", false)):
		var reason: String = String(check.get("reason", "invalid placement"))
		if include_log:
			event_log.append("Action failed (place): %s" % reason)
		return {"applied": false, "reason": reason}

	var owner: int = int(action.get("owner", 0))
	var tile_type: String = String(action.get("tile_type", "basic"))
	var pos: Vector2i = action.get("target", Vector2i(-1, -1))
	var cost: int = int(action.get("cost", int(TILE_RULES[tile_type]["cost"])))

	state.players[owner]["nutrients"] = int(state.players[owner]["nutrients"]) - cost
	var block_id: int = state.spawn_block(owner, pos, false, int(TILE_RULES[tile_type]["max_hp"]), tile_type)
	var block: Dictionary = state.blocks[block_id]
	block["upgrade_tier"] = _default_upgrade_tier(tile_type)
	_apply_tile_stats(block, tile_type)
	block["max_hp"] = _effective_max_hp(block, tile_type)
	block["hp"] = int(block["max_hp"])
	_refresh_gather_bonus(state, block)
	state.blocks[block_id] = block

	if include_log:
		event_log.append("Owner %d placed %s at (%d,%d)" % [owner, tile_type, pos.x, pos.y])
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
	if from_type != "basic" and to_type != "basic":
		return {"ok": false, "reason": "requires basic tile"}

	var from_tier: int = int(block.get("upgrade_tier", _default_upgrade_tier(from_type)))
	var energy_delta: int = int(action.get("energy_delta", conversion_energy_delta(from_type, to_type, from_tier)))
	if energy_delta > 0 and int(state.players[owner]["nutrients"]) < energy_delta:
		return {"ok": false, "reason": "insufficient energy"}

	return {"ok": true}

func validate_upgrade_action(action: Dictionary, state: GameState) -> Dictionary:
	var owner: int = int(action.get("owner", 0))
	var block_id: int = int(action.get("block_id", -1))
	if not state.players.has(owner):
		return {"ok": false, "reason": "unknown owner"}
	if not state.blocks.has(block_id):
		return {"ok": false, "reason": "missing block"}

	var block: Dictionary = state.blocks[block_id]
	if int(block.get("owner", 0)) != owner:
		return {"ok": false, "reason": "not owned"}
	var tile_type: String = String(block.get("tile_type", "basic"))
	if tile_type == "basic":
		return {"ok": false, "reason": "basic cannot upgrade"}
	if not UPGRADE_BASE_COST.has(tile_type):
		return {"ok": false, "reason": "tile cannot upgrade"}
	var current_tier: int = maxi(SPECIALIZATION_TIER, int(block.get("upgrade_tier", _default_upgrade_tier(tile_type))))
	if current_tier >= MAX_UPGRADE_TIER:
		return {"ok": false, "reason": "max tier reached"}

	var planned_type_count: int = int(action.get("planned_type_count", 0))
	var planned_total_count: int = int(action.get("planned_total_count", 0))
	var cost: int = int(action.get("cost", upgrade_energy_cost(state, owner, tile_type, planned_type_count, planned_total_count, current_tier)))
	if cost <= 0:
		return {"ok": false, "reason": "invalid upgrade cost"}
	if int(state.players[owner]["nutrients"]) < cost:
		return {"ok": false, "reason": "insufficient energy"}
	return {"ok": true}

func _apply_convert_tile(action: Dictionary, state: GameState, event_log: Array[String], include_log: bool) -> Dictionary:
	var check: Dictionary = validate_convert_action(action, state)
	if not bool(check.get("ok", false)):
		var reason: String = String(check.get("reason", "invalid conversion"))
		if include_log:
			event_log.append("Action failed (convert): %s" % reason)
		return {"applied": false, "reason": reason}

	var owner: int = int(action.get("owner", 0))
	var block_id: int = int(action.get("block_id", -1))
	var to_type: String = String(action.get("to_type", "basic"))
	var block: Dictionary = state.blocks[block_id]
	var from_type: String = String(block.get("tile_type", "basic"))
	var from_tier: int = int(block.get("upgrade_tier", _default_upgrade_tier(from_type)))
	var energy_delta: int = int(action.get("energy_delta", conversion_energy_delta(from_type, to_type, from_tier)))

	state.players[owner]["nutrients"] = int(state.players[owner]["nutrients"]) - energy_delta
	block["tile_type"] = to_type
	block["last_converted_turn"] = state.turn_index
	block["upgrade_tier"] = _default_upgrade_tier(to_type)
	_apply_tile_stats(block, to_type)

	var new_max_hp: int = _effective_max_hp(block, to_type)
	block["max_hp"] = new_max_hp
	block["hp"] = mini(int(block["hp"]), new_max_hp)
	if int(block["hp"]) <= 0:
		block["hp"] = new_max_hp

	_refresh_gather_bonus(state, block)
	state.blocks[block_id] = block
	if include_log:
		event_log.append("Owner %d converted block %d: %s -> %s" % [owner, block_id, from_type, to_type])
	return {"applied": true}

func _apply_upgrade_tile(action: Dictionary, state: GameState, event_log: Array[String], include_log: bool) -> Dictionary:
	var check: Dictionary = validate_upgrade_action(action, state)
	if not bool(check.get("ok", false)):
		var reason: String = String(check.get("reason", "invalid upgrade"))
		if include_log:
			event_log.append("Action failed (upgrade): %s" % reason)
		return {"applied": false, "reason": reason}

	var owner: int = int(action.get("owner", 0))
	var block_id: int = int(action.get("block_id", -1))
	var block: Dictionary = state.blocks[block_id]
	var tile_type: String = String(block.get("tile_type", "basic"))
	var current_tier: int = maxi(SPECIALIZATION_TIER, int(block.get("upgrade_tier", _default_upgrade_tier(tile_type))))
	var planned_type_count: int = int(action.get("planned_type_count", 0))
	var planned_total_count: int = int(action.get("planned_total_count", 0))
	var cost: int = int(action.get("cost", upgrade_energy_cost(state, owner, tile_type, planned_type_count, planned_total_count, current_tier)))

	state.players[owner]["nutrients"] = int(state.players[owner]["nutrients"]) - cost
	var old_max_hp: int = int(block.get("max_hp", int(TILE_RULES[tile_type]["max_hp"])))
	block["upgrade_tier"] = mini(MAX_UPGRADE_TIER, current_tier + 1)
	_apply_tile_stats(block, tile_type)
	var new_max_hp: int = _effective_max_hp(block, tile_type)
	block["max_hp"] = new_max_hp
	block["hp"] = mini(new_max_hp, int(block.get("hp", new_max_hp)) + maxi(0, new_max_hp - old_max_hp))
	if int(block["hp"]) <= 0:
		block["hp"] = new_max_hp

	_refresh_gather_bonus(state, block)
	state.blocks[block_id] = block
	state.register_tile_upgrade(owner, tile_type)
	if include_log:
		event_log.append("Owner %d upgraded block %d (%s) to tier %d for %d energy" % [owner, block_id, tile_type, int(block["upgrade_tier"]), cost])
	return {"applied": true}

func _apply_tile_stats(block: Dictionary, tile_type: String) -> void:
	var rules: Dictionary = TILE_RULES[tile_type]
	var tier_bonus_steps: int = _upgrade_bonus_steps(tile_type, int(block.get("upgrade_tier", 0)))
	var defense_value: int = int(rules["defense"])
	var damage_value: int = int(rules["damage"])
	var range_value: int = int(rules["range"])
	var melee_break_bonus: int = 0
	var ranged_splash_bonus: int = 0
	var defense_guard_bonus: int = 0
	var gather_upgrade_bonus: int = 0

	if tier_bonus_steps > 0:
		match tile_type:
			"melee":
				damage_value += MELEE_UPGRADE_DAMAGE_BONUS * tier_bonus_steps
				melee_break_bonus = MELEE_UPGRADE_BREAK_BONUS * tier_bonus_steps
			"ranged":
				range_value += RANGED_UPGRADE_RANGE_BONUS * tier_bonus_steps
				ranged_splash_bonus = RANGED_UPGRADE_SPLASH_RADIUS_BONUS * tier_bonus_steps
			"defense":
				defense_value += DEFENSE_UPGRADE_DEFENSE_BONUS * tier_bonus_steps
				defense_guard_bonus = DEFENSE_UPGRADE_GUARD_BONUS * tier_bonus_steps
			"gather":
				gather_upgrade_bonus = GATHER_UPGRADE_INCOME_BONUS * tier_bonus_steps
			_:
				pass

	block["defense"] = defense_value
	block["damage"] = damage_value
	block["range"] = range_value
	block["melee_break_bonus"] = melee_break_bonus
	block["ranged_splash_bonus"] = ranged_splash_bonus
	block["defense_guard_bonus"] = defense_guard_bonus
	block["gather_upgrade_bonus"] = gather_upgrade_bonus
	if tile_type != "gather":
		block["gather_bonus"] = 0

func _effective_max_hp(block: Dictionary, tile_type: String) -> int:
	var max_hp: int = int(TILE_RULES[tile_type]["max_hp"])
	var tier_bonus_steps: int = _upgrade_bonus_steps(tile_type, int(block.get("upgrade_tier", 0)))
	if tile_type == "defense" and tier_bonus_steps > 0:
		max_hp += DEFENSE_UPGRADE_HP_BONUS * tier_bonus_steps
	if bool(block.get("is_heart", false)):
		max_hp += GameState.HEART_TILE_HP_BONUS
	return max_hp

func _default_upgrade_tier(tile_type: String) -> int:
	return 0 if tile_type == "basic" else SPECIALIZATION_TIER

func _upgrade_bonus_steps(tile_type: String, tier: int) -> int:
	if tile_type == "basic":
		return 0
	var normalized_tier: int = maxi(SPECIALIZATION_TIER, tier)
	return maxi(0, normalized_tier - SPECIALIZATION_TIER)

func _refresh_gather_bonus(state: GameState, block: Dictionary) -> void:
	block["gather_bonus"] = 0
	if String(block.get("tile_type", "basic")) != "gather":
		return

	var node: Dictionary = state.get_resource_node_at(block["pos"])
	if node.is_empty():
		return
	if bool(node.get("consumed", false)):
		block["gather_bonus"] = Economy.GATHER_RESOURCE_BONUS

func _resolve_melee_damage(state: GameState, event_log: Array[String], include_log: bool = true) -> void:
	var pending_damage: Dictionary = {}

	for block in state.blocks.values():
		var owner: int = int(block["owner"])
		var block_id: int = int(block["id"])
		if String(block.get("tile_type", "basic")) != "melee":
			continue

		var melee_base: int = int(block.get("damage", 3))
		if owner == GameState.PLAYER_ID:
			melee_base += int(state.card_modifiers.get("melee_damage_bonus", 0))

		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var target_pos: Vector2i = block["pos"] + step
			if target_pos == state.door_tile and _can_damage_door(state, owner) and state.door_hp > 0:
				var door_hit: int = _modified_damage(state, owner, melee_base)
				state.door_hp = maxi(0, state.door_hp - door_hit)
				if include_log:
					event_log.append("Melee block %d hit door for %d" % [block_id, door_hit])
				continue

			var target: Dictionary = state.get_block_at(target_pos)
			if target.is_empty():
				continue
			if not state.are_hostile(owner, int(target["owner"])):
				continue
			var target_id: int = int(target["id"])
			var base_damage: int = _modified_damage(state, owner, melee_base)
			var melee_damage: int = base_damage + _melee_breaker_bonus(state, target) + int(block.get("melee_break_bonus", 0))
			pending_damage[target_id] = int(pending_damage.get(target_id, 0)) + melee_damage
			if include_log:
				event_log.append("Melee block %d struck %d" % [block_id, target_id])

	_apply_damage_batch(state, pending_damage)

func _resolve_ranged_damage(state: GameState, event_log: Array[String], include_log: bool = true) -> void:
	var pending_damage: Dictionary = {}

	for block in state.blocks.values():
		var owner: int = int(block["owner"])
		var block_id: int = int(block["id"])
		if String(block.get("tile_type", "basic")) != "ranged":
			continue

		var target_info: Dictionary = _nearest_ranged_target(state, owner, block["pos"], int(block.get("range", 4)))
		if target_info.is_empty():
			continue
		var ranged_damage: int = _modified_damage(state, owner, int(block.get("damage", 2)))
		var in_direct_contact: bool = _has_adjacent_hostile(state, owner, block["pos"])
		if in_direct_contact:
			ranged_damage = maxi(1, ranged_damage - RANGED_CONTACT_DAMAGE_PENALTY)
		if String(target_info.get("kind", "")) == "door":
			state.door_hp = maxi(0, state.door_hp - ranged_damage)
			if include_log:
				event_log.append("Ranged block %d shot door for %d" % [block_id, ranged_damage])
			continue

		var target_id: int = int(target_info.get("id", -1))
		if target_id <= 0:
			continue
		pending_damage[target_id] = int(pending_damage.get(target_id, 0)) + ranged_damage
		if include_log:
			event_log.append("Ranged block %d shot %d" % [block_id, target_id])
		if not in_direct_contact:
			_apply_ranged_splash(
				state,
				owner,
				target_id,
				ranged_damage,
				pending_damage,
				event_log,
				block_id,
				int(block.get("ranged_splash_bonus", 0)),
				include_log
			)

	_apply_damage_batch(state, pending_damage)

func _apply_damage_batch(state: GameState, pending_damage: Dictionary) -> void:
	for target_id in pending_damage.keys():
		if not state.blocks.has(target_id):
			continue
		var target: Dictionary = state.blocks[target_id]
		var raw: int = int(pending_damage[target_id])
		var owner: int = int(target["owner"])
		if owner == GameState.PLAYER_ID and state.dev_player_immortal:
			target["hp"] = int(target["max_hp"])
			state.blocks[target_id] = target
			continue
		var support_count: int = state.count_owned_within_manhattan(owner, target["pos"], SUPPORT_RADIUS)
		var support_cap: int = SUPPORT_MAX_BONUS
		if owner == GameState.PLAYER_ID:
			support_cap += int(state.card_modifiers.get("support_bonus_cap_bonus", 0))
		support_cap = maxi(0, support_cap)
		var support_bonus: int = mini(support_cap, int(support_count / SUPPORT_DIVISOR))
		var stability_bonus: int = _stability_defense_bonus(int(target.get("age", 0)))
		var guard_bonus: int = _adjacent_defense_guard_bonus(state, int(target["id"]))
		var effective_defense: int = int(target.get("defense", 0)) + support_bonus + stability_bonus + guard_bonus
		var reduced: int = maxi(1, raw - effective_defense)
		target["hp"] = int(target["hp"]) - reduced
		state.blocks[target_id] = target

func _nearest_ranged_target(state: GameState, owner_id: int, origin: Vector2i, max_range: int) -> Dictionary:
	var best_kind: String = ""
	var best_id: int = -1
	var best_dist: int = 999999

	for block in state.blocks.values():
		var target_owner: int = int(block["owner"])
		if not state.are_hostile(owner_id, target_owner):
			continue
		var block_pos: Vector2i = block["pos"]
		var dist: int = absi(origin.x - block_pos.x) + absi(origin.y - block_pos.y)
		if dist > max_range:
			continue
		if dist < best_dist or (dist == best_dist and best_kind == "door"):
			best_dist = dist
			best_kind = "block"
			best_id = int(block["id"])

	if _can_damage_door(state, owner_id) and state.door_hp > 0:
		var door_dist: int = absi(origin.x - state.door_tile.x) + absi(origin.y - state.door_tile.y)
		if door_dist <= max_range and door_dist < best_dist:
			best_dist = door_dist
			best_kind = "door"
			best_id = -1

	if best_kind.is_empty():
		return {}
	return {
		"kind": best_kind,
		"id": best_id,
		"distance": best_dist,
	}

func _apply_ranged_splash(
	state: GameState,
	owner: int,
	primary_target_id: int,
	primary_damage: int,
	pending_damage: Dictionary,
	event_log: Array[String],
	source_id: int,
	splash_radius_bonus: int,
	include_log: bool = true
) -> void:
	if not state.blocks.has(primary_target_id):
		return
	var target_pos: Vector2i = state.blocks[primary_target_id]["pos"]
	var splash_damage: int = mini(RANGED_SPLASH_MAX, maxi(1, int(round(primary_damage * RANGED_SPLASH_RATIO))))
	if splash_damage <= 0:
		return

	var splash_radius: int = 1 + maxi(0, splash_radius_bonus)
	if owner == GameState.PLAYER_ID:
		splash_radius += maxi(0, int(state.card_modifiers.get("ranged_splash_radius_bonus", 0)))
	splash_radius = clampi(splash_radius, 1, 4)

	var seen_targets: Dictionary = {}
	for y in range(target_pos.y - splash_radius, target_pos.y + splash_radius + 1):
		for x in range(target_pos.x - splash_radius, target_pos.x + splash_radius + 1):
			var candidate: Vector2i = Vector2i(x, y)
			var distance: int = absi(candidate.x - target_pos.x) + absi(candidate.y - target_pos.y)
			if distance <= 0 or distance > splash_radius:
				continue
			var splash_target: Dictionary = state.get_block_at(candidate)
			if splash_target.is_empty():
				continue
			if not state.are_hostile(owner, int(splash_target["owner"])):
				continue
			var splash_id: int = int(splash_target["id"])
			if splash_id == primary_target_id:
				continue
			if seen_targets.has(splash_id):
				continue
			seen_targets[splash_id] = true
			pending_damage[splash_id] = int(pending_damage.get(splash_id, 0)) + splash_damage
			if include_log:
				event_log.append("Ranged block %d splashed %d" % [source_id, splash_id])

func _has_adjacent_hostile(state: GameState, owner_id: int, pos: Vector2i) -> bool:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var target: Dictionary = state.get_block_at(pos + step)
		if target.is_empty():
			continue
		if state.are_hostile(owner_id, int(target["owner"])):
			return true
	return false

func _resolve_heart_defeats(state: GameState, event_log: Array[String], include_log: bool = true) -> Dictionary:
	var defeated_owners: Array = []

	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if state.get_owner_blocks(owner_id).is_empty():
			state.players[owner_id]["alive"] = false
			continue
		if state.count_heart_tiles(owner_id) > 0:
			continue
		defeated_owners.append(owner_id)

	var player_burst_total: int = 0
	for owner_id in defeated_owners:
		var owner_blocks: Array = state.get_owner_blocks(owner_id)
		for block in owner_blocks:
			state.mark_reclaim_block(block["pos"], 1)
			state.remove_block(int(block["id"]))

		state.players[owner_id]["alive"] = false
		state.players[owner_id]["nutrients"] = 0
		if include_log:
			event_log.append("Owner %d defeated (all heart tiles destroyed)" % owner_id)

		if owner_id != GameState.PLAYER_ID and state.players.has(GameState.PLAYER_ID):
			state.players[GameState.PLAYER_ID]["nutrients"] = int(state.players[GameState.PLAYER_ID]["nutrients"]) + HEART_DEFEAT_BURST_ENERGY
			player_burst_total += HEART_DEFEAT_BURST_ENERGY

	if include_log and player_burst_total > 0:
		event_log.append("Player gained %d energy from heart collapse" % player_burst_total)

	return {
		"defeated_owners": defeated_owners,
		"player_heart_burst": player_burst_total,
	}

func _modified_damage(state: GameState, owner: int, base_damage: int) -> int:
	if owner != GameState.PLAYER_ID:
		return base_damage
	# Run upgrade hook: optional global damage multiplier for player actions.
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
		guards += DEFENSE_GUARD_PER_ADJACENT + int(neighbor.get("defense_guard_bonus", 0))

	var guard_cap: int = DEFENSE_GUARD_MAX
	if owner == GameState.PLAYER_ID:
		guard_cap += int(state.card_modifiers.get("defense_guard_cap_bonus", 0))
	guard_cap = maxi(0, guard_cap)
	return mini(guard_cap, guards)

func _melee_breaker_bonus(state: GameState, target: Dictionary) -> int:
	var bonus: int = 0
	if String(target.get("tile_type", "basic")) == "defense":
		bonus += MELEE_BREAK_DEFENSE_BONUS
	var owner: int = int(target.get("owner", 0))
	var support: int = state.count_owned_within_manhattan(owner, target["pos"], SUPPORT_RADIUS)
	if support >= FORTIFIED_SUPPORT_THRESHOLD or int(target.get("age", 0)) >= STABILITY_REINFORCED_AGE:
		bonus += MELEE_BREAK_FORTIFIED_BONUS
	return bonus

func _can_damage_door(state: GameState, owner_id: int) -> bool:
	return not state.are_hostile(owner_id, GameState.PLAYER_ID)

func _public_action_copy(action: Dictionary) -> Dictionary:
	var out: Dictionary = action.duplicate(true)
	out.erase("_order_index")
	return out

func _strip_internal_keys_from_actions(actions: Array) -> Array:
	var out: Array = []
	for action in actions:
		out.append(_public_action_copy(action))
	return out
