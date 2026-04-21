extends RefCounted
class_name OozeAI

const BASELINE_TUNING_PATH: String = "res://config/ooze_ai_baseline.json"
const BASELINE_TUNABLE_KEYS: Array[String] = [
	"engaged_upgrade_energy_threshold",
	"non_engaged_upgrade_energy_threshold",
	"max_tile_upgrades_per_turn",
	"tile_upgrade_min_score",
	"upgrade_priority_margin",
	"resource_objective_max_distance",
	"resource_objective_step_weight",
	"resource_safe_phase_bonus",
	"resource_approaching_phase_bonus",
	"resource_low_threat_bonus",
	"resource_node_hold_bonus",
	"resource_gather_focus_bonus",
	"resource_near_threat_penalty",
	"ranged_saturation_min_tiles",
	"ranged_saturation_soft_cap",
	"ranged_saturation_hard_cap",
	"ranged_saturation_max_penalty",
	"specialization_min_tiles",
	"specialization_soft_cap",
	"specialization_hard_cap",
	"specialization_max_penalty",
	"specialization_local_radius",
	"specialization_local_soft_limit",
	"specialization_local_cluster_penalty",
	"specialization_adjacent_penalty",
	"specialization_safe_phase_penalty",
	"specialization_backline_blanket_penalty",
	"specialization_path_penalty",
	"defense_nearby_soft_limit",
	"defense_local_ratio_soft_cap",
	"defense_local_ratio_hard_cap",
	"gather_conversion_resource_max_dist",
	"gather_safe_min_enemy_distance",
	"objective_upgrade_distance_max",
	"objective_upgrade_enemy_distance_max",
	"objective_progress_weight",
	"objective_backfill_penalty",
	"flank_pressure_bonus",
	"flank_stalemate_break_bonus",
	"basic_claim_opening_bonus",
	"basic_claim_goal_bonus",
	"basic_claim_frontline_bonus",
	"ranged_frontline_penalty",
	"ranged_backline_penalty",
]

const MAX_ACTIONS: int = 3
const MAX_CONVERSIONS_PER_TURN: int = 2
const CONVERSION_COOLDOWN_TURNS: int = 2
const FRONTLINE_FOLLOWUP_SCORE_THRESHOLD: int = 74
const ENGAGED_MIN_UPGRADES_PER_TURN: int = 1
const NON_ENGAGED_MIN_UPGRADES_PER_TURN: int = 0
const ENGAGED_BASIC_EXPANSION_PENALTY: int = 22
const SECOND_LINE_RANGED_MIN_DIST: int = 2
const SECOND_LINE_RANGED_MAX_DIST: int = 5
const MAX_TILE_UPGRADES_PER_TURN: int = 2
const ENGAGED_UPGRADE_ENERGY_THRESHOLD: int = 16
const NON_ENGAGED_UPGRADE_ENERGY_THRESHOLD: int = 18
const PRE_ENGAGE_OBJECTIVE_UPGRADE_ENERGY_THRESHOLD: int = 16
const TILE_UPGRADE_MIN_SCORE: int = 66
const TILE_UPGRADE_SURPLUS_RESERVE: int = 6
const EARLY_ECON_TURN_WINDOW: int = 6
const EARLY_ECON_INCOME_THRESHOLD: int = 6
const EARLY_GATHER_TARGET: int = 2
const MID_ECON_INCOME_THRESHOLD: int = 7
const MID_ECON_ENERGY_LOW_THRESHOLD: int = 6
const MID_GATHER_TARGET: int = 3
const THREAT_SPIKE_THRESHOLD: int = 12
const THREAT_SCAN_RADIUS: int = 2
const RANGED_SATURATION_SOFT_CAP: float = 0.34
const RANGED_SATURATION_HARD_CAP: float = 0.52
const RANGED_SATURATION_MIN_TILES: int = 8
const RANGED_SATURATION_MAX_PENALTY: int = 36
const RANGED_FRONTLINE_PENALTY: int = 28
const RANGED_BACKLINE_PENALTY: int = 14
const DOOR_ADVANCE_WEIGHT: int = 12
const DOOR_DEFEND_WEIGHT: int = 4
const CHOKEPOINT_WEIGHT: int = 4
const HEART_OBJECTIVE_WEIGHT: int = 20
const RESOURCE_OBJECTIVE_MAX_DISTANCE: int = 9
const RESOURCE_OBJECTIVE_STEP_WEIGHT: int = 4
const RESOURCE_SAFE_PHASE_BONUS: int = 10
const RESOURCE_APPROACHING_PHASE_BONUS: int = 4
const RESOURCE_NODE_HOLD_BONUS: int = 14
const RESOURCE_GATHER_FOCUS_BONUS: int = 12
const RESOURCE_LOW_THREAT_BONUS: int = 6
const RESOURCE_NEAR_THREAT_PENALTY: int = 10
const OBJECTIVE_UPGRADE_DISTANCE_MAX: int = 14
const OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX: int = 10
const OBJECTIVE_PROGRESS_WEIGHT: int = 22
const OBJECTIVE_BACKFILL_PENALTY: int = 32
const FLANK_PRESSURE_BONUS: int = 14
const FLANK_STALEMATE_BREAK_BONUS: int = 10
const BASIC_CLAIM_OPENING_BONUS: int = 12
const BASIC_CLAIM_GOAL_BONUS: int = 10
const BASIC_CLAIM_FRONTLINE_BONUS: int = 14
const LOW_THREAT_MIN_ENEMY_DISTANCE: int = 5
const LOW_THREAT_MAX_LOCAL_SCORE: int = 6
const GATHER_CONVERSION_RESOURCE_MAX_DIST: int = 2
const GATHER_SAFE_MIN_ENEMY_DISTANCE: int = 4
const SAFE_DOWNGRADE_MIN_TURN: int = 6
const SAFE_DOWNGRADE_MIN_ENEMY_DISTANCE: int = 6
const SAFE_DOWNGRADE_MAX_THREAT: int = 4
const SAFE_DOWNGRADE_MIN_SCORE: int = 22
const PHASE_SAFE_EXPANSION: int = 0
const PHASE_APPROACHING_CONTACT: int = 1
const PHASE_ACTIVE_FRONTLINE: int = 2
const PHASE_ACTIVE_FRONTLINE_MAX_ENEMY_DISTANCE: int = 2
const PHASE_APPROACHING_CONTACT_MAX_ENEMY_DISTANCE: int = 4
const PHASE_APPROACHING_LOCAL_THREAT_MIN: int = 6
const DEFENSE_DENSITY_RADIUS: int = 2
const DEFENSE_NEARBY_SOFT_LIMIT: int = 2
const DEFENSE_LOCAL_RATIO_SOFT_CAP: float = 0.40
const DEFENSE_LOCAL_RATIO_HARD_CAP: float = 0.55
const ROLE_POSITION_BLOCK_SCORE: int = -10000000
const RANGED_CHAIN_ADJACENT_PENALTY: int = 9
const RANGED_CHAIN_CLUSTER_PENALTY: int = 5
const RANGED_EXPOSED_PENALTY: int = 28
const RANGED_SAFE_EXPANSION_PENALTY: int = 34
const RANGED_APPROACHING_PHASE_PENALTY: int = 12
const RANGED_LOCAL_RATIO_SOFT_CAP: float = 0.34
const RANGED_LOCAL_RATIO_HARD_CAP: float = 0.50
const RANGED_LOCAL_RATIO_SOFT_PENALTY: int = 12
const RANGED_LOCAL_RATIO_HARD_PENALTY: int = 24
const RANGED_NO_FRONTLINE_PENALTY: int = 20
const SPECIALIZATION_SOFT_CAP: float = 0.45
const SPECIALIZATION_HARD_CAP: float = 0.62
const SPECIALIZATION_MAX_PENALTY: int = 30
const SPECIALIZATION_MIN_TILES: int = 9
const SPECIALIZATION_LOCAL_RADIUS: int = 2
const SPECIALIZATION_LOCAL_SOFT_LIMIT: int = 3
const SPECIALIZATION_LOCAL_CLUSTER_PENALTY: int = 5
const SPECIALIZATION_ADJACENT_PENALTY: int = 3
const SPECIALIZATION_SAFE_PHASE_PENALTY: int = 14
const SPECIALIZATION_BACKLINE_BLANKET_PENALTY: int = 12
const SPECIALIZATION_PATH_PENALTY: int = 12
const UPGRADE_PRIORITY_MARGIN: int = 10
const STRATEGY_MAIN_PUSH: String = "MAIN_PUSH"
const STRATEGY_HEART_DEFENSE: String = "HEART_DEFENSE"
const STRATEGY_RESOURCE_CONTEST: String = "RESOURCE_CONTEST"
const STRATEGY_FLANK_PRESSURE: String = "FLANK_PRESSURE"
const STRATEGY_BREAKOUT: String = "BREAKOUT"
const STRATEGY_STALEMATE_BREAK: String = "STALEMATE_BREAK"
const STRATEGY_SUPPORT_ALLY_LANE: String = "SUPPORT_ALLY_LANE"
const STRATEGY_CONSOLIDATE_ADVANTAGE: String = "CONSOLIDATE_ADVANTAGE"
const STRATEGY_RECOVER_ECONOMY: String = "RECOVER_ECONOMY"

const TUNING_SCHEMA: Dictionary = {
	"engaged_upgrade_energy_threshold": {"type": "int", "min": 8, "max": 40, "default": ENGAGED_UPGRADE_ENERGY_THRESHOLD},
	"non_engaged_upgrade_energy_threshold": {"type": "int", "min": 8, "max": 40, "default": NON_ENGAGED_UPGRADE_ENERGY_THRESHOLD},
	"max_tile_upgrades_per_turn": {"type": "int", "min": 0, "max": 6, "default": MAX_TILE_UPGRADES_PER_TURN},
	"tile_upgrade_min_score": {"type": "int", "min": 0, "max": 140, "default": TILE_UPGRADE_MIN_SCORE},
	"upgrade_priority_margin": {"type": "int", "min": 0, "max": 40, "default": UPGRADE_PRIORITY_MARGIN},
	"resource_objective_max_distance": {"type": "int", "min": 1, "max": 20, "default": RESOURCE_OBJECTIVE_MAX_DISTANCE},
	"resource_objective_step_weight": {"type": "int", "min": 0, "max": 12, "default": RESOURCE_OBJECTIVE_STEP_WEIGHT},
	"resource_safe_phase_bonus": {"type": "int", "min": 0, "max": 30, "default": RESOURCE_SAFE_PHASE_BONUS},
	"resource_approaching_phase_bonus": {"type": "int", "min": 0, "max": 20, "default": RESOURCE_APPROACHING_PHASE_BONUS},
	"resource_low_threat_bonus": {"type": "int", "min": 0, "max": 20, "default": RESOURCE_LOW_THREAT_BONUS},
	"resource_node_hold_bonus": {"type": "int", "min": 0, "max": 30, "default": RESOURCE_NODE_HOLD_BONUS},
	"resource_gather_focus_bonus": {"type": "int", "min": 0, "max": 30, "default": RESOURCE_GATHER_FOCUS_BONUS},
	"resource_near_threat_penalty": {"type": "int", "min": 0, "max": 30, "default": RESOURCE_NEAR_THREAT_PENALTY},
	"ranged_saturation_min_tiles": {"type": "int", "min": 1, "max": 30, "default": RANGED_SATURATION_MIN_TILES},
	"ranged_saturation_soft_cap": {"type": "float", "min": 0.10, "max": 0.90, "default": RANGED_SATURATION_SOFT_CAP},
	"ranged_saturation_hard_cap": {"type": "float", "min": 0.10, "max": 0.95, "default": RANGED_SATURATION_HARD_CAP},
	"ranged_saturation_max_penalty": {"type": "int", "min": 0, "max": 80, "default": RANGED_SATURATION_MAX_PENALTY},
	"specialization_min_tiles": {"type": "int", "min": 1, "max": 40, "default": SPECIALIZATION_MIN_TILES},
	"specialization_soft_cap": {"type": "float", "min": 0.10, "max": 0.95, "default": SPECIALIZATION_SOFT_CAP},
	"specialization_hard_cap": {"type": "float", "min": 0.10, "max": 0.99, "default": SPECIALIZATION_HARD_CAP},
	"specialization_max_penalty": {"type": "int", "min": 0, "max": 80, "default": SPECIALIZATION_MAX_PENALTY},
	"specialization_local_radius": {"type": "int", "min": 1, "max": 6, "default": SPECIALIZATION_LOCAL_RADIUS},
	"specialization_local_soft_limit": {"type": "int", "min": 0, "max": 12, "default": SPECIALIZATION_LOCAL_SOFT_LIMIT},
	"specialization_local_cluster_penalty": {"type": "int", "min": 0, "max": 20, "default": SPECIALIZATION_LOCAL_CLUSTER_PENALTY},
	"specialization_adjacent_penalty": {"type": "int", "min": 0, "max": 20, "default": SPECIALIZATION_ADJACENT_PENALTY},
	"specialization_safe_phase_penalty": {"type": "int", "min": 0, "max": 40, "default": SPECIALIZATION_SAFE_PHASE_PENALTY},
	"specialization_backline_blanket_penalty": {"type": "int", "min": 0, "max": 40, "default": SPECIALIZATION_BACKLINE_BLANKET_PENALTY},
	"specialization_path_penalty": {"type": "int", "min": 0, "max": 40, "default": SPECIALIZATION_PATH_PENALTY},
	"defense_nearby_soft_limit": {"type": "int", "min": 0, "max": 8, "default": DEFENSE_NEARBY_SOFT_LIMIT},
	"defense_local_ratio_soft_cap": {"type": "float", "min": 0.10, "max": 0.90, "default": DEFENSE_LOCAL_RATIO_SOFT_CAP},
	"defense_local_ratio_hard_cap": {"type": "float", "min": 0.10, "max": 0.95, "default": DEFENSE_LOCAL_RATIO_HARD_CAP},
	"gather_conversion_resource_max_dist": {"type": "int", "min": 0, "max": 6, "default": GATHER_CONVERSION_RESOURCE_MAX_DIST},
	"gather_safe_min_enemy_distance": {"type": "int", "min": 0, "max": 10, "default": GATHER_SAFE_MIN_ENEMY_DISTANCE},
	"objective_upgrade_distance_max": {"type": "int", "min": 1, "max": 24, "default": OBJECTIVE_UPGRADE_DISTANCE_MAX},
	"objective_upgrade_enemy_distance_max": {"type": "int", "min": 1, "max": 20, "default": OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX},
	"objective_progress_weight": {"type": "int", "min": 0, "max": 60, "default": OBJECTIVE_PROGRESS_WEIGHT},
	"objective_backfill_penalty": {"type": "int", "min": 0, "max": 80, "default": OBJECTIVE_BACKFILL_PENALTY},
	"flank_pressure_bonus": {"type": "int", "min": 0, "max": 40, "default": FLANK_PRESSURE_BONUS},
	"flank_stalemate_break_bonus": {"type": "int", "min": 0, "max": 40, "default": FLANK_STALEMATE_BREAK_BONUS},
	"basic_claim_opening_bonus": {"type": "int", "min": 0, "max": 40, "default": BASIC_CLAIM_OPENING_BONUS},
	"basic_claim_goal_bonus": {"type": "int", "min": 0, "max": 40, "default": BASIC_CLAIM_GOAL_BONUS},
	"basic_claim_frontline_bonus": {"type": "int", "min": 0, "max": 50, "default": BASIC_CLAIM_FRONTLINE_BONUS},
	"ranged_frontline_penalty": {"type": "int", "min": 0, "max": 80, "default": RANGED_FRONTLINE_PENALTY},
	"ranged_backline_penalty": {"type": "int", "min": 0, "max": 60, "default": RANGED_BACKLINE_PENALTY},
}

var _session_override: Dictionary = {}
var _runtime_modifier: Dictionary = {}
static var _baseline_config: Dictionary = {}
static var _baseline_config_loaded: bool = false
var _profiling_enabled: bool = false
var _profile_totals_usec: Dictionary = {}
var _profile_counts: Dictionary = {}
var _profile_turns: int = 0
var _decision_objective_cache: Dictionary = {}
var _active_strategy_intent: String = STRATEGY_MAIN_PUSH
var _active_strategy_bias: Dictionary = {}
var _active_strategy_context: Dictionary = {}

# Enemy uses deterministic, pressure-biased heuristics:
# 1) secure at least one frontline action when possible
# 2) push pressure growth
# 3) take resource opportunities that don't stall pressure
# 4) avoid low-impact backline conversion churn

func clear_tuning() -> void:
	_session_override.clear()
	_runtime_modifier.clear()

func set_tuning(overrides: Dictionary) -> void:
	set_session_override(overrides)

func set_session_override(overrides: Dictionary) -> void:
	_session_override = _sanitize_tuning_layer(overrides, "session_override")

func clear_session_override() -> void:
	_session_override.clear()

func set_runtime_modifier(modifiers: Dictionary) -> void:
	_runtime_modifier = _sanitize_tuning_layer(modifiers, "runtime_modifier")

func clear_runtime_modifier() -> void:
	_runtime_modifier.clear()

func get_effective_tuning_snapshot() -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = BASELINE_TUNABLE_KEYS.duplicate()
	keys.sort()
	for key_variant in keys:
		var key: String = String(key_variant)
		var schema: Dictionary = TUNING_SCHEMA.get(key, {})
		var fallback_value: Variant = schema.get("default", null)
		var resolved: Dictionary = _resolve_tuning_value(key, fallback_value)
		out[key] = {
			"value": resolved.get("value", fallback_value),
			"source": String(resolved.get("source", "fallback")),
		}
	return out

func get_effective_tuning_lines(only_non_fallback: bool = false) -> Array[String]:
	var lines: Array[String] = []
	var snapshot: Dictionary = get_effective_tuning_snapshot()
	var keys: Array = snapshot.keys()
	keys.sort()
	for key_variant in keys:
		var key: String = String(key_variant)
		var row: Dictionary = snapshot.get(key, {})
		var source: String = String(row.get("source", "fallback"))
		if only_non_fallback and source == "fallback":
			continue
		lines.append("%s = %s (%s)" % [key, str(row.get("value", null)), source])
	return lines

func print_effective_tuning_snapshot(only_non_fallback: bool = true) -> void:
	for line in get_effective_tuning_lines(only_non_fallback):
		print(line)

func set_profiling_enabled(enabled: bool) -> void:
	_profiling_enabled = enabled
	if enabled:
		reset_profiling()

func reset_profiling() -> void:
	_profile_totals_usec.clear()
	_profile_counts.clear()
	_profile_turns = 0

func get_profiling_snapshot() -> Dictionary:
	var totals_usec: Dictionary = _profile_totals_usec.duplicate(true)
	var totals_seconds: Dictionary = {}
	for key_variant in totals_usec.keys():
		var key: String = String(key_variant)
		totals_seconds[key] = float(totals_usec[key]) / 1000000.0
	var choose_total_usec: float = float(totals_usec.get("choose_total", 0.0))
	return {
		"enabled": _profiling_enabled,
		"turns": _profile_turns,
		"totals_usec": totals_usec,
		"totals_seconds": totals_seconds,
		"counts": _profile_counts.duplicate(true),
		"choose_total_usec": choose_total_usec,
		"avg_choose_usec_per_turn": choose_total_usec / maxf(1.0, float(_profile_turns)),
		"active_strategy_intent": _active_strategy_intent,
		"active_strategy_context": _active_strategy_context.duplicate(true),
	}

func _prof_begin() -> int:
	if not _profiling_enabled:
		return 0
	return Time.get_ticks_usec()

func _prof_end(category: String, started_usec: int) -> void:
	if not _profiling_enabled or started_usec <= 0:
		return
	var elapsed: int = maxi(0, Time.get_ticks_usec() - started_usec)
	_profile_totals_usec[category] = float(_profile_totals_usec.get(category, 0.0)) + float(elapsed)
	_profile_counts[category] = int(_profile_counts.get(category, 0)) + 1

func _prof_add_count(counter_key: String, amount: int = 1) -> void:
	if not _profiling_enabled:
		return
	_profile_counts[counter_key] = int(_profile_counts.get(counter_key, 0)) + amount

func _strategy_bias_int(key: String) -> int:
	return int(_active_strategy_bias.get(key, 0))

func _strategy_tile_bonus(state: GameState, owner_id: int, tile: Vector2i, phase: int, zone: String, tile_type: String) -> int:
	var bonus: int = 0
	var front_push_bonus: int = _strategy_bias_int("front_push_bonus")
	if front_push_bonus > 0:
		if zone == "frontline" or phase == PHASE_ACTIVE_FRONTLINE:
			bonus += front_push_bonus
		elif phase == PHASE_APPROACHING_CONTACT:
			bonus += int(round(float(front_push_bonus) * 0.6))
	var heart_defense_bonus: int = _strategy_heart_defense_bonus(state, owner_id, tile, phase)
	bonus += heart_defense_bonus
	if _strategy_bias_int("breakout_bonus") > 0 and tile_type == "basic":
		var open_neighbors: int = _adjacent_open_ground_count(state, tile)
		if open_neighbors >= 2 and zone != "backline":
			bonus += int(round(float(_strategy_bias_int("breakout_bonus")) * 0.5))
	return bonus

func _strategy_heart_defense_bonus(state: GameState, owner_id: int, tile: Vector2i, phase: int) -> int:
	var weight: int = _strategy_bias_int("heart_defense_bonus")
	if weight <= 0:
		return 0
	var heart_dist: int = _nearest_allied_heart_distance(state, owner_id, tile)
	if heart_dist >= 99:
		return 0
	var bonus: int = maxi(0, 8 - heart_dist) * weight / 4
	if phase == PHASE_SAFE_EXPANSION and heart_dist >= 5:
		bonus -= int(round(float(weight) * 0.35))
	return bonus

func _nearest_allied_heart_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	if _decision_cache_matches(state, owner_id):
		var allied_map: Dictionary = _decision_objective_cache.get("allied_heart_distance_map", {})
		if allied_map.has(tile):
			return int(allied_map.get(tile, 99))
	var best: int = 999999
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		if not bool(block.get("is_heart", false)):
			continue
		var other_owner: int = int(block.get("owner", 0))
		if other_owner != owner_id and state.are_hostile(owner_id, other_owner):
			continue
		best = mini(best, _distance_to_tile(tile, block.get("pos", Vector2i(-1, -1))))
	return best if best < 999999 else 99

func _compute_strategy_profile(state: GameState, owner_id: int) -> Dictionary:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	var allied_hp: int = 0
	var hostile_hp: int = 0
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var block_owner: int = int(block.get("owner", 0))
		var hp: int = int(block.get("hp", 0))
		if block_owner == owner_id:
			allied_hp += hp
		elif state.are_hostile(owner_id, block_owner):
			hostile_hp += hp
	var engaged: bool = _is_owner_engaged(state, owner_id)
	var low_threat: bool = _is_owner_low_threat(state, owner_id)
	var income: int = _estimated_owner_income(state, owner_id)
	var gather_count: int = _count_gather_tiles(state, owner_id)
	var energy: int = int(state.players.get(owner_id, {}).get("nutrients", 0))
	var stall_level: int = _owner_frontline_stall_level(state, owner_id)
	var objective_dist: int = _owner_objective_frontier_distance(state, owner_id)
	var expansion_frontier: int = 0
	var ally_touch_count: int = 0
	var heart_threat_level: int = 0
	for block in owner_blocks:
		var pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _adjacent_open_ground_count(state, pos) > 0:
			expansion_frontier += 1
		ally_touch_count += _adjacent_nonhostile_ally_count(state, owner_id, pos)
		if bool(block.get("is_heart", false)):
			heart_threat_level = maxi(heart_threat_level, maxi(0, 6 - _nearest_enemy_distance(state, owner_id, pos)))
	var avg_ally_touches: float = 0.0
	if not owner_blocks.is_empty():
		avg_ally_touches = float(ally_touch_count) / float(owner_blocks.size())
	var boxed: bool = owner_blocks.size() >= 8 and expansion_frontier <= maxi(2, int(round(float(owner_blocks.size()) * 0.14)))
	var economy_stressed: bool = income < MID_ECON_INCOME_THRESHOLD and energy <= MID_ECON_ENERGY_LOW_THRESHOLD + 4
	var resource_need: bool = gather_count < MID_GATHER_TARGET and (low_threat or economy_stressed)
	var hp_advantage: bool = allied_hp > 0 and hostile_hp > 0 and float(allied_hp) >= float(hostile_hp) * 1.20

	var intent: String = STRATEGY_MAIN_PUSH
	if heart_threat_level >= 3:
		intent = STRATEGY_HEART_DEFENSE
	elif economy_stressed and resource_need:
		intent = STRATEGY_RECOVER_ECONOMY
	elif stall_level >= 2 and boxed:
		intent = STRATEGY_BREAKOUT
	elif stall_level >= 2:
		intent = STRATEGY_STALEMATE_BREAK
	elif avg_ally_touches >= 0.35 and engaged:
		intent = STRATEGY_SUPPORT_ALLY_LANE
	elif resource_need and objective_dist >= 5:
		intent = STRATEGY_RESOURCE_CONTEST
	elif hp_advantage and engaged:
		intent = STRATEGY_CONSOLIDATE_ADVANTAGE
	elif stall_level >= 1 and engaged:
		intent = STRATEGY_FLANK_PRESSURE

	var bias: Dictionary = {
		"heart_defense_bonus": 0,
		"resource_focus_bonus": 0,
		"flank_bonus": 0,
		"opening_claim_bonus": 0,
		"breakout_bonus": 0,
		"ally_block_penalty_bonus": 0,
		"specialization_penalty_bonus": 0,
		"defense_extra_penalty": 0,
		"front_push_bonus": 0,
		"gather_drive_bonus": 0,
	}
	match intent:
		STRATEGY_HEART_DEFENSE:
			bias["heart_defense_bonus"] = 16
			bias["resource_focus_bonus"] = -8
			bias["flank_bonus"] = -10
			bias["opening_claim_bonus"] = 6
			bias["front_push_bonus"] = 6
		STRATEGY_RESOURCE_CONTEST:
			bias["resource_focus_bonus"] = 14
			bias["gather_drive_bonus"] = 12
			bias["flank_bonus"] = -4
			bias["specialization_penalty_bonus"] = 6
		STRATEGY_FLANK_PRESSURE:
			bias["flank_bonus"] = 14
			bias["opening_claim_bonus"] = 8
			bias["front_push_bonus"] = 5
		STRATEGY_BREAKOUT:
			bias["breakout_bonus"] = 16
			bias["opening_claim_bonus"] = 14
			bias["flank_bonus"] = 8
			bias["specialization_penalty_bonus"] = 10
			bias["defense_extra_penalty"] = 8
			bias["ally_block_penalty_bonus"] = 2
		STRATEGY_STALEMATE_BREAK:
			bias["flank_bonus"] = 10
			bias["opening_claim_bonus"] = 12
			bias["defense_extra_penalty"] = 8
		STRATEGY_SUPPORT_ALLY_LANE:
			bias["ally_block_penalty_bonus"] = 6
			bias["breakout_bonus"] = 6
			bias["opening_claim_bonus"] = 6
		STRATEGY_CONSOLIDATE_ADVANTAGE:
			bias["front_push_bonus"] = 12
			bias["opening_claim_bonus"] = 8
			bias["resource_focus_bonus"] = -4
		STRATEGY_RECOVER_ECONOMY:
			bias["resource_focus_bonus"] = 16
			bias["gather_drive_bonus"] = 14
			bias["specialization_penalty_bonus"] = 8
			bias["front_push_bonus"] = -4
		_:
			bias["front_push_bonus"] = 5

	return {
		"intent": intent,
		"bias": bias,
		"context": {
			"engaged": engaged,
			"low_threat": low_threat,
			"income": income,
			"gather_count": gather_count,
			"stall_level": stall_level,
			"objective_dist": objective_dist,
			"boxed": boxed,
			"avg_ally_touches": avg_ally_touches,
			"heart_threat_level": heart_threat_level,
			"resource_need": resource_need,
			"hp_advantage": hp_advantage,
		},
	}

func _decision_cache_matches(state: GameState, owner_id: int) -> bool:
	return (
		int(_decision_objective_cache.get("state_id", -1)) == state.get_instance_id()
		and int(_decision_objective_cache.get("turn", -1)) == state.turn_index
		and int(_decision_objective_cache.get("owner", -1)) == owner_id
	)

func _nearest_distance_to_positions(tile: Vector2i, positions: Array) -> int:
	if positions.is_empty():
		return 99
	var best: int = 999999
	for pos_variant in positions:
		var pos: Vector2i = pos_variant
		best = mini(best, _distance_to_tile(tile, pos))
	return best if best < 999999 else 99

func _build_distance_map_to_positions(state: GameState, positions: Array) -> Dictionary:
	var out: Dictionary = {}
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			out[tile] = _nearest_distance_to_positions(tile, positions)
	return out

func _rebuild_decision_objective_cache(state: GameState, owner_id: int) -> void:
	var hostile_heart_positions: Array = []
	var allied_heart_positions: Array = []
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		if bool(block.get("is_heart", false)):
			var heart_owner: int = int(block.get("owner", 0))
			if state.are_hostile(owner_id, heart_owner):
				hostile_heart_positions.append(block.get("pos", Vector2i(-1, -1)))
			else:
				allied_heart_positions.append(block.get("pos", Vector2i(-1, -1)))

	var open_resource_positions: Array = []
	for node_variant in state.resource_nodes:
		var node: Dictionary = node_variant
		if bool(node.get("consumed", false)):
			continue
		open_resource_positions.append(node.get("pos", Vector2i(-1, -1)))

	var heart_distance_map: Dictionary = _build_distance_map_to_positions(state, hostile_heart_positions)
	var allied_heart_distance_map: Dictionary = _build_distance_map_to_positions(state, allied_heart_positions)
	var resource_distance_map: Dictionary = _build_distance_map_to_positions(state, open_resource_positions)

	var door_relevant: bool = _can_attack_door(state, owner_id) and state.door_hp > 0
	var primary_objective_distance_map: Dictionary = {}
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			var heart_dist: int = int(heart_distance_map.get(tile, 99))
			if door_relevant:
				primary_objective_distance_map[tile] = mini(heart_dist, _distance_to_tile(tile, state.door_tile))
			else:
				primary_objective_distance_map[tile] = heart_dist

	var frontier_distance: int = 99
	for block in state.get_owner_blocks(owner_id):
		var block_pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		frontier_distance = mini(frontier_distance, int(primary_objective_distance_map.get(block_pos, 99)))

	_decision_objective_cache = {
		"state_id": state.get_instance_id(),
		"turn": state.turn_index,
		"owner": owner_id,
		"hostile_heart_positions": hostile_heart_positions,
		"allied_heart_positions": allied_heart_positions,
		"open_resource_positions": open_resource_positions,
		"heart_distance_map": heart_distance_map,
		"allied_heart_distance_map": allied_heart_distance_map,
		"resource_distance_map": resource_distance_map,
		"primary_objective_distance_map": primary_objective_distance_map,
		"objective_frontier_distance": frontier_distance,
	}

static func reload_baseline_tuning() -> void:
	_baseline_config_loaded = false
	_baseline_config.clear()

static func _baseline_config_values() -> Dictionary:
	if _baseline_config_loaded:
		return _baseline_config
	_baseline_config_loaded = true
	_baseline_config.clear()

	var file: FileAccess = FileAccess.open(BASELINE_TUNING_PATH, FileAccess.READ)
	if file == null:
		return _baseline_config
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		printerr("OozeAI baseline tuning ignored: malformed JSON at %s" % BASELINE_TUNING_PATH)
		return _baseline_config

	var flattened: Dictionary = {}
	_collect_baseline_tunable_values(parsed as Dictionary, flattened)
	_baseline_config = _sanitize_tuning_layer(flattened, "baseline_config")
	return _baseline_config

static func _collect_baseline_tunable_values(source: Dictionary, out: Dictionary) -> void:
	for key_variant in source.keys():
		var value: Variant = source[key_variant]
		if value is Dictionary:
			_collect_baseline_tunable_values(value as Dictionary, out)
			continue
		var key: String = String(key_variant)
		var value_type: int = typeof(value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT:
			out[key] = value

func _tp_int(key: String, fallback: int) -> int:
	var resolved: Dictionary = _resolve_tuning_value(key, fallback)
	return int(resolved.get("value", fallback))

func _tp_float(key: String, fallback: float) -> float:
	var resolved: Dictionary = _resolve_tuning_value(key, fallback)
	return float(resolved.get("value", fallback))

func _resolve_tuning_value(key: String, fallback: Variant) -> Dictionary:
	var schema: Dictionary = TUNING_SCHEMA.get(key, {})
	var default_value: Variant = schema.get("default", fallback)
	var fallback_value: Variant = fallback if fallback != null else default_value
	var sanitized_fallback: Dictionary = _sanitize_tuning_value(key, fallback_value, "fallback")
	if bool(sanitized_fallback.get("ok", false)):
		fallback_value = sanitized_fallback.get("value", fallback_value)

	if _runtime_modifier.has(key):
		return {"value": _runtime_modifier[key], "source": "runtime_modifier"}
	if _session_override.has(key):
		return {"value": _session_override[key], "source": "session_override"}
	var baseline: Dictionary = _baseline_config_values()
	if baseline.has(key):
		return {"value": baseline[key], "source": "baseline_config"}
	return {"value": fallback_value, "source": "fallback"}

static func _sanitize_tuning_layer(source: Dictionary, layer_name: String) -> Dictionary:
	var out: Dictionary = {}
	for key_variant in source.keys():
		var key: String = String(key_variant)
		if not TUNING_SCHEMA.has(key):
			print("OozeAI tuning ignored unknown key `%s` in %s." % [key, layer_name])
			continue
		var result: Dictionary = _sanitize_tuning_value(key, source[key_variant], layer_name)
		if not bool(result.get("ok", false)):
			continue
		out[key] = result.get("value", null)
	return out

static func _sanitize_tuning_value(key: String, value: Variant, layer_name: String) -> Dictionary:
	if not TUNING_SCHEMA.has(key):
		return {"ok": false}
	var schema: Dictionary = TUNING_SCHEMA[key]
	var expected_type: String = String(schema.get("type", "float"))
	var value_type: int = typeof(value)
	if value_type != TYPE_INT and value_type != TYPE_FLOAT:
		print("OozeAI tuning ignored non-numeric `%s` from %s." % [key, layer_name])
		return {"ok": false}
	if expected_type == "int":
		var parsed_int: int = int(round(float(value)))
		var min_int: int = int(schema.get("min", parsed_int))
		var max_int: int = int(schema.get("max", parsed_int))
		var clamped_int: int = clampi(parsed_int, min_int, max_int)
		if clamped_int != parsed_int:
			print("OozeAI tuning clamped `%s` from %s (%d -> %d)." % [key, layer_name, parsed_int, clamped_int])
		return {"ok": true, "value": clamped_int}
	var parsed_float: float = float(value)
	var min_float: float = float(schema.get("min", parsed_float))
	var max_float: float = float(schema.get("max", parsed_float))
	var clamped_float: float = clampf(parsed_float, min_float, max_float)
	if absf(clamped_float - parsed_float) > 0.000001:
		print("OozeAI tuning clamped `%s` from %s (%.4f -> %.4f)." % [key, layer_name, parsed_float, clamped_float])
	return {"ok": true, "value": clamped_float}

func choose_actions(state: GameState, owner_id: int, min_adjacent: int) -> Array:
	var choose_total_start_usec: int = _prof_begin()
	var actions: Array = []
	if not state.players.has(owner_id):
		_prof_end("choose_total", choose_total_start_usec)
		return actions

	var energy: int = int(state.players[owner_id]["nutrients"])
	if energy <= 0:
		_prof_end("choose_total", choose_total_start_usec)
		return actions

	if _profiling_enabled:
		_profile_turns += 1

	var objective_cache_start: int = _prof_begin()
	_rebuild_decision_objective_cache(state, owner_id)
	_prof_end("objective_distance_calculations", objective_cache_start)
	var strategy_start: int = _prof_begin()
	var strategy_profile: Dictionary = _compute_strategy_profile(state, owner_id)
	_active_strategy_intent = String(strategy_profile.get("intent", STRATEGY_MAIN_PUSH))
	_active_strategy_bias = strategy_profile.get("bias", {}).duplicate(true)
	_active_strategy_context = strategy_profile.get("context", {}).duplicate(true)
	_prof_end("strategy_evaluation", strategy_start)
	_prof_add_count("strategy_intent_%s" % _active_strategy_intent)

	var conversions_used: int = 0
	var frontline_committed: bool = false
	var frontline_upgraded: bool = false
	var second_line_support_upgraded: bool = false
	var upgrades_committed: int = 0
	var tile_upgrades_used: int = 0
	var reserved_place_tiles: Dictionary = {}
	var reserved_convert_blocks: Dictionary = {}
	var engaged: bool = bool(_active_strategy_context.get("engaged", _is_owner_engaged(state, owner_id)))
	var desired_upgrade_count: int = 0
	var low_threat: bool = bool(_active_strategy_context.get("low_threat", _is_owner_low_threat(state, owner_id)))
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

		var midgame_gather_candidate: Dictionary = {}
		if _should_seek_midgame_gather(state, owner_id, energy, engaged):
			midgame_gather_candidate = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, true)
			if midgame_gather_candidate.is_empty():
				midgame_gather_candidate = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, false)
			if _should_prefer_midgame_gather_candidate(
				candidate,
				midgame_gather_candidate,
				state,
				owner_id,
				engaged,
				frontline_committed
			):
				candidate = midgame_gather_candidate

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN and frontline_committed:
			candidate = _best_support_conversion_action(state, owner_id, actions, energy, reserved_convert_blocks)

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN:
			candidate = _best_heart_pressure_conversion_action(state, owner_id, energy, reserved_convert_blocks)

		var engaged_upgrade_energy_threshold: int = _tp_int("engaged_upgrade_energy_threshold", ENGAGED_UPGRADE_ENERGY_THRESHOLD)
		var non_engaged_upgrade_energy_threshold: int = _tp_int("non_engaged_upgrade_energy_threshold", NON_ENGAGED_UPGRADE_ENERGY_THRESHOLD)
		var upgrade_energy_threshold: int = engaged_upgrade_energy_threshold if engaged else non_engaged_upgrade_energy_threshold
		var max_tile_upgrades_per_turn: int = maxi(0, _tp_int("max_tile_upgrades_per_turn", MAX_TILE_UPGRADES_PER_TURN))
		if tile_upgrades_used < max_tile_upgrades_per_turn and energy >= upgrade_energy_threshold:
			var prefer_frontline_upgrade: bool = engaged
			var tile_upgrade_candidate: Dictionary = _best_tile_upgrade_action(state, owner_id, energy, reserved_convert_blocks, prefer_frontline_upgrade)
			if _should_prefer_tile_upgrade_candidate(candidate, tile_upgrade_candidate, engaged):
				candidate = tile_upgrade_candidate

		if candidate.is_empty() and energy >= int(Combat.TILE_RULES["gather"]["cost"]):
			candidate = _best_resource_place_action(state, owner_id, min_adjacent, actions, energy, reserved_place_tiles, false)

		if candidate.is_empty() and conversions_used < MAX_CONVERSIONS_PER_TURN:
			candidate = _best_safe_backline_downgrade_action(
				state,
				owner_id,
				energy,
				reserved_convert_blocks,
				engaged,
				low_threat
			)

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
			if _is_upgrade_conversion_action(action):
				upgrades_committed += 1
				if _is_frontline_conversion(state, owner_id, action):
					frontline_upgraded = true
				elif _is_second_line_conversion(state, owner_id, action):
					second_line_support_upgraded = true
		elif String(action.get("type", "")) == "upgrade_tile":
			tile_upgrades_used += 1

	_prof_end("choose_total", choose_total_start_usec)
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
	var t_start: int = _prof_begin()
	var best: Dictionary = {}
	var best_score: int = -999999
	var objective_upgrade_distance_max: int = _tp_int("objective_upgrade_distance_max", OBJECTIVE_UPGRADE_DISTANCE_MAX)
	var objective_upgrade_enemy_distance_max: int = _tp_int("objective_upgrade_enemy_distance_max", OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX)
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
		if heart_dist > objective_upgrade_distance_max or enemy_dist > objective_upgrade_enemy_distance_max:
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
	_prof_end("conversion_scoring", t_start)
	return best

func _best_frontline_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	return _best_frontline_conversion_action(state, owner_id, energy, reserved_convert_blocks)

func _best_second_line_ranged_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var t_start: int = _prof_begin()
	if _is_ranged_hard_capped(state, owner_id):
		_prof_end("upgrade_scoring", t_start)
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
		if not _is_ranged_position_allowed(state, owner_id, pos):
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

		var support: int = _count_owned_support(state, owner_id, pos, 2)
		var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, pos)
		var phase: int = _local_threat_phase(state, owner_id, pos, dist, adjacent_enemy)
		var score: int = 64
		score += support * 2
		score += maxi(0, 8 - dist) * 4
		score += _chokepoint_score(state, pos) * (CHOKEPOINT_WEIGHT + 2)
		score += _door_objective_score(state, owner_id, pos)
		score += _heart_objective_score(state, owner_id, pos)
		score += _zone_role_score("second_line", "ranged")
		score -= _ranged_saturation_penalty(state, owner_id)
		score -= _ranged_position_penalty(state, owner_id, pos, "second_line", phase)
		score -= _specialization_spread_penalty(state, owner_id, pos, "ranged", phase, "second_line", dist, support)
		score += _ranged_preferred_depth_bonus(state, owner_id, pos)
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
	_prof_end("upgrade_scoring", t_start)
	return best

func _best_objective_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var t_start: int = _prof_begin()
	var best: Dictionary = {}
	var best_score: int = -999999
	var objective_upgrade_distance_max: int = _tp_int("objective_upgrade_distance_max", OBJECTIVE_UPGRADE_DISTANCE_MAX)
	var objective_upgrade_enemy_distance_max: int = _tp_int("objective_upgrade_enemy_distance_max", OBJECTIVE_UPGRADE_ENEMY_DISTANCE_MAX)
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
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
		if objective_dist > objective_upgrade_distance_max and nearest_enemy_dist > objective_upgrade_enemy_distance_max:
			continue

		var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, pos)
		var support: int = _count_owned_support(state, owner_id, pos, 2)
		var phase: int = _local_threat_phase(state, owner_id, pos, nearest_enemy_dist, adjacent_enemy)
		var zone: String = _tile_zone(state, owner_id, pos)
		var to_type: String = "melee"
		if phase == PHASE_SAFE_EXPANSION:
			if _should_prefer_gather_conversion(state, owner_id, pos, nearest_enemy_dist, false):
				to_type = "gather"
			elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and support >= 2 and _distance_to_nearest_owned_frontline(state, owner_id, pos) <= 2:
				to_type = "ranged"
			elif door_relevant and door_dist <= 4 and objective_dist <= 5 and support >= 3:
				to_type = "melee"
			elif support >= 2 and objective_dist <= objective_upgrade_distance_max:
				to_type = "melee"
			else:
				continue
		elif phase == PHASE_APPROACHING_CONTACT:
			if _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
				to_type = "ranged"
			elif _should_prefer_gather_conversion(state, owner_id, pos, nearest_enemy_dist, false):
				to_type = "gather"
			elif nearest_enemy_dist <= 3 and support >= 2:
				to_type = "melee"
			elif _local_threat_score(state, owner_id, pos) >= THREAT_SPIKE_THRESHOLD and _defense_density_penalty(state, owner_id, pos, phase) < 26:
				to_type = "defense"
			else:
				to_type = "melee"
		else:
			if _is_frontline_tile(state, owner_id, pos):
				to_type = _desired_frontline_role(state, owner_id, block)
			elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
				to_type = "ranged"
			elif _local_threat_score(state, owner_id, pos) >= THREAT_SPIKE_THRESHOLD and _defense_density_penalty(state, owner_id, pos, phase) < 30:
				to_type = "defense"
			else:
				to_type = "melee"

		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = 28
		score += _heart_objective_score(state, owner_id, pos)
		score += _door_objective_score(state, owner_id, pos)
		score += _resource_objective_score(state, owner_id, pos, phase, to_type)
		score += maxi(0, objective_upgrade_distance_max - objective_dist) * 2
		score += maxi(0, objective_upgrade_enemy_distance_max - nearest_enemy_dist)
		score += _zone_role_score(zone, to_type)
		match phase:
			PHASE_SAFE_EXPANSION:
				if to_type == "melee":
					score -= 18
				elif to_type == "defense":
					score -= 24
				elif to_type == "gather":
					score += 12
			PHASE_APPROACHING_CONTACT:
				if to_type == "melee":
					score += 5
				elif to_type == "defense":
					score -= 4
				elif to_type == "ranged":
					score += 4
			PHASE_ACTIVE_FRONTLINE:
				if to_type == "melee":
					score += 10
				elif to_type == "defense":
					score += 5
		if to_type == "melee" or to_type == "defense":
			score += 8
		elif to_type == "ranged":
			score += 6
			score -= _ranged_saturation_penalty(state, owner_id)
			score -= _ranged_position_penalty(state, owner_id, pos, zone, phase)
		elif to_type == "gather":
			var income_gap: int = maxi(0, MID_ECON_INCOME_THRESHOLD - _estimated_owner_income(state, owner_id))
			var resource_dist: int = _nearest_open_resource_distance(state, pos)
			score += 16 + income_gap * 4
			if resource_dist <= gather_conversion_resource_max_dist:
				score += (gather_conversion_resource_max_dist - resource_dist + 1) * 6
			if objective_dist <= 5:
				score -= 10
		if to_type == "defense":
			score -= _defense_density_penalty(state, owner_id, pos, phase)
		score -= _specialization_spread_penalty(state, owner_id, pos, to_type, phase, zone, nearest_enemy_dist, support)

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
	_prof_end("upgrade_scoring", t_start)
	return best

func _best_progression_upgrade_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var t_start: int = _prof_begin()
	var best: Dictionary = {}
	var best_score: int = -999999
	var objective_upgrade_distance_max: int = _tp_int("objective_upgrade_distance_max", OBJECTIVE_UPGRADE_DISTANCE_MAX)
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
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
		var support: int = _count_owned_support(state, owner_id, pos, 2)
		var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, pos)
		var phase: int = _local_threat_phase(state, owner_id, pos, nearest_enemy_dist, adjacent_enemy)

		var to_type: String = "melee"
		if phase == PHASE_SAFE_EXPANSION:
			if _should_prefer_gather_conversion(state, owner_id, pos, nearest_enemy_dist, false):
				to_type = "gather"
			elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and support >= 2 and _distance_to_nearest_owned_frontline(state, owner_id, pos) <= 2:
				to_type = "ranged"
			elif door_relevant and door_dist <= 4 and support >= 3:
				to_type = "melee"
			elif support >= 2 and objective_dist <= objective_upgrade_distance_max:
				to_type = "melee"
			else:
				continue
		elif phase == PHASE_APPROACHING_CONTACT:
			if _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
				to_type = "ranged"
			elif nearest_enemy_dist <= 3 and support >= 2:
				to_type = "melee"
			elif _local_threat_score(state, owner_id, pos) >= THREAT_SPIKE_THRESHOLD and _defense_density_penalty(state, owner_id, pos, phase) < 26:
				to_type = "defense"
			elif _should_prefer_gather_conversion(state, owner_id, pos, nearest_enemy_dist, false):
				to_type = "gather"
			else:
				to_type = "melee"
		else:
			if _is_frontline_tile(state, owner_id, pos) or nearest_enemy_dist <= 3:
				to_type = "melee"
			elif _local_threat_score(state, owner_id, pos) >= THREAT_SPIKE_THRESHOLD and _defense_density_penalty(state, owner_id, pos, phase) < 30:
				to_type = "defense"
			elif _is_second_line_tile(state, owner_id, pos) and not _is_ranged_hard_capped(state, owner_id) and _chokepoint_score(state, pos) >= 2:
				to_type = "ranged"
			elif _should_prefer_gather_conversion(state, owner_id, pos, nearest_enemy_dist, false):
				to_type = "gather"
			else:
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
		score += _resource_objective_score(state, owner_id, pos, phase, to_type)
		score += _zone_role_score(zone, to_type)
		match phase:
			PHASE_SAFE_EXPANSION:
				if to_type == "melee":
					score -= 20
				elif to_type == "defense":
					score -= 24
				elif to_type == "gather":
					score += 14
			PHASE_APPROACHING_CONTACT:
				if to_type == "melee":
					score += 6
				elif to_type == "defense":
					score -= 4
				elif to_type == "ranged":
					score += 4
			PHASE_ACTIVE_FRONTLINE:
				if to_type == "melee":
					score += 10
				elif to_type == "defense":
					score += 5
		if to_type == "ranged":
			score -= _ranged_saturation_penalty(state, owner_id)
			score -= _ranged_position_penalty(state, owner_id, pos, zone, phase)
		elif to_type == "gather":
			var income_gap: int = maxi(0, MID_ECON_INCOME_THRESHOLD - _estimated_owner_income(state, owner_id))
			var resource_dist: int = _nearest_open_resource_distance(state, pos)
			score += 14 + income_gap * 5
			if resource_dist <= gather_conversion_resource_max_dist:
				score += (gather_conversion_resource_max_dist - resource_dist + 1) * 5
		if to_type == "defense":
			score -= _defense_density_penalty(state, owner_id, pos, phase)
		score -= _specialization_spread_penalty(state, owner_id, pos, to_type, phase, zone, nearest_enemy_dist, support)
		if zone == "backline" and to_type == "melee":
			score -= 14
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
	_prof_end("upgrade_scoring", t_start)
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
	var t_start: int = _prof_begin()
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
			var phase: int = _local_threat_phase(state, owner_id, block["pos"], _nearest_enemy_distance(state, owner_id, block["pos"]), _adjacent_enemy_count(state, owner_id, block["pos"]))
			if phase == PHASE_SAFE_EXPANSION:
				continue
			var density_penalty: int = _defense_density_penalty(state, owner_id, block["pos"], phase)
			if density_penalty >= 34:
				continue
			var score: int = 90 + threat * 3 + _door_objective_score(state, owner_id, block["pos"])
			score += _heart_objective_score(state, owner_id, block["pos"])
			score -= density_penalty
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
			if not _growth_target_ok(state, owner_id, tile, min_adjacent, planned_tiles):
				continue
			var cost: int = int(Combat.TILE_RULES["defense"]["cost"])
			if cost > energy:
				continue
			var phase: int = _local_threat_phase(state, owner_id, tile, _nearest_enemy_distance(state, owner_id, tile), _adjacent_enemy_count(state, owner_id, tile))
			if phase == PHASE_SAFE_EXPANSION:
				continue
			var density_penalty: int = _defense_density_penalty(state, owner_id, tile, phase)
			if density_penalty >= 34:
				continue
			var zone_score: int = 0
			if _is_frontline_tile(state, owner_id, tile):
				zone_score = 12
			elif _is_second_line_tile(state, owner_id, tile):
				zone_score = 5
			var score: int = 70 + threat_score * 2 + zone_score + _door_objective_score(state, owner_id, tile)
			score += _heart_objective_score(state, owner_id, tile)
			score -= density_penalty
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

	_prof_end("conversion_scoring", t_start)
	return best

func _best_frontline_conversion_action(state: GameState, owner_id: int, energy: int, reserved_convert_blocks: Dictionary) -> Dictionary:
	var t_start: int = _prof_begin()
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
	var t_start: int = _prof_begin()
	var scan_start: int = _prof_begin()
	var scanned_tiles: int = 0
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var baseline_objective_dist: int = _owner_objective_frontier_distance(state, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	for y in range(state.height):
		for x in range(state.width):
			scanned_tiles += 1
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_empty_ground(tile):
				continue
			var tile_key: String = _tile_key(tile)
			if planned_tiles.has(tile_key):
				continue
			if reserved_place_tiles.has(tile_key):
				continue
			if not _growth_target_ok(state, owner_id, tile, min_adjacent, planned_tiles):
				continue

			var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, tile)
			var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
			if adjacent_enemy <= 0 and nearest_enemy_dist > 2:
				continue

			var support: int = _count_owned_support(state, owner_id, tile, 2, planned_tiles)
			var zone: String = _tile_zone(state, owner_id, tile)
			var phase: int = _local_threat_phase(state, owner_id, tile, nearest_enemy_dist, adjacent_enemy)
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
			score += _resource_objective_score(state, owner_id, tile, phase, tile_type)
			score += _strategy_tile_bonus(state, owner_id, tile, phase, zone, tile_type)
			score += _objective_progress_delta_score(state, owner_id, tile, baseline_objective_dist, false)
			score += _zone_role_score(zone, tile_type)
			score += _flank_pressure_bonus_score(
				state,
				owner_id,
				tile,
				zone,
				phase,
				support,
				nearest_enemy_dist,
				adjacent_enemy,
				baseline_objective_dist
			)
			if tile_type == "basic":
				score += _basic_claim_opening_score(
					state,
					owner_id,
					tile,
					zone,
					phase,
					support,
					nearest_enemy_dist,
					adjacent_enemy,
					baseline_objective_dist
				)
			if support <= 1:
				score -= 8
			if tile_type == "defense":
				score += 8
				score -= _defense_density_penalty(state, owner_id, tile, phase)
			elif tile_type == "ranged":
				score -= _ranged_position_penalty(state, owner_id, tile, zone, phase)
			elif tile_type == "melee":
				if phase == PHASE_ACTIVE_FRONTLINE:
					score += 18
				elif phase == PHASE_APPROACHING_CONTACT:
					score += 10
				elif adjacent_enemy > 0 or nearest_enemy_dist <= 2:
					score += 14
				else:
					score -= 18
			if tile_type != "basic":
				score -= _specialization_spread_penalty(state, owner_id, tile, tile_type, phase, zone, nearest_enemy_dist, support)

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
	_prof_end("full_board_scan", scan_start)
	_prof_add_count("full_board_tiles_scanned", scanned_tiles)
	_prof_end("placement_scoring", t_start)
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
	var t_start: int = _prof_begin()
	var scan_start: int = _prof_begin()
	var scanned_tiles: int = 0
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var baseline_objective_dist: int = _owner_objective_frontier_distance(state, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	for y in range(state.height):
		for x in range(state.width):
			scanned_tiles += 1
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_empty_ground(tile):
				continue
			var tile_key: String = _tile_key(tile)
			if planned_tiles.has(tile_key):
				continue
			if reserved_place_tiles.has(tile_key):
				continue
			if not _growth_target_ok(state, owner_id, tile, min_adjacent, planned_tiles):
				continue

			var support: int = _count_owned_support(state, owner_id, tile, 2, planned_tiles)
			var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
			var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, tile)
			var zone: String = _tile_zone(state, owner_id, tile)
			var phase: int = _local_threat_phase(state, owner_id, tile, nearest_enemy_dist, adjacent_enemy)

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
			score += _resource_objective_score(state, owner_id, tile, phase, tile_type)
			score += _strategy_tile_bonus(state, owner_id, tile, phase, zone, tile_type)
			score += _objective_progress_delta_score(state, owner_id, tile, baseline_objective_dist, not engaged)
			score += _zone_role_score(zone, tile_type)
			score += _flank_pressure_bonus_score(
				state,
				owner_id,
				tile,
				zone,
				phase,
				support,
				nearest_enemy_dist,
				adjacent_enemy,
				baseline_objective_dist
			)
			if tile_type == "basic":
				score += _basic_claim_opening_score(
					state,
					owner_id,
					tile,
					zone,
					phase,
					support,
					nearest_enemy_dist,
					adjacent_enemy,
					baseline_objective_dist
				)
			if engaged and tile_type == "basic" and zone != "frontline":
				score -= ENGAGED_BASIC_EXPANSION_PENALTY
			if phase == PHASE_SAFE_EXPANSION and tile_type == "basic":
				score += 10
			if phase == PHASE_SAFE_EXPANSION and tile_type == "gather":
				score += 16
			if tile_type == "defense":
				score -= _defense_density_penalty(state, owner_id, tile, phase)
			if _is_second_line_tile(state, owner_id, tile) and tile_type == "ranged":
				score += 10
			if tile_type == "ranged":
				score -= _ranged_position_penalty(state, owner_id, tile, zone, phase)
			if phase == PHASE_ACTIVE_FRONTLINE and tile_type == "melee" and adjacent_enemy > 0 and support >= 2:
				score += 16
			if phase == PHASE_SAFE_EXPANSION and tile_type == "melee":
				score -= 24
			elif zone == "backline" and tile_type == "melee":
				score -= 14
			if tile_type != "basic":
				score -= _specialization_spread_penalty(state, owner_id, tile, tile_type, phase, zone, nearest_enemy_dist, support)
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
	_prof_end("full_board_scan", scan_start)
	_prof_add_count("full_board_tiles_scanned", scanned_tiles)
	_prof_end("placement_scoring", t_start)
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
	var t_start: int = _prof_begin()
	var planned_tiles: Dictionary = _planned_tiles_for_owner(planned_actions, owner_id)
	var best: Dictionary = {}
	var best_score: int = -999999
	var gather_cost: int = int(Combat.TILE_RULES["gather"]["cost"])
	if gather_cost > energy:
		_prof_end("placement_scoring", t_start)
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
		if not _growth_target_ok(state, owner_id, tile, min_adjacent, planned_tiles):
			continue

		var zone: String = _tile_zone(state, owner_id, tile)
		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
		var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, tile)
		var phase: int = _local_threat_phase(state, owner_id, tile, nearest_enemy_dist, adjacent_enemy)
		if not _is_gather_position_allowed(state, owner_id, tile, nearest_enemy_dist, phase):
			continue
		if avoid_high_pressure_zones:
			if phase != PHASE_SAFE_EXPANSION:
				continue

		var support: int = _count_owned_support(state, owner_id, tile, 2, planned_tiles)
		var score: int = 16
		score += support * 3
		score += mini(6, maxi(0, nearest_enemy_dist - 2))
		score += int(round(_door_objective_score(state, owner_id, tile) * 0.15))
		score += int(round(_heart_objective_score(state, owner_id, tile) * 0.2))
		score += _chokepoint_score(state, tile) * 2
		var income_gap: int = maxi(0, MID_ECON_INCOME_THRESHOLD - _estimated_owner_income(state, owner_id))
		score += income_gap * 4
		if support <= 1:
			score -= 8
		if zone == "backline":
			score += 20
		elif zone == "second_line":
			score -= 20
		else:
			score -= 38
		var local_threat: int = _local_threat_score(state, owner_id, tile)
		if local_threat >= THREAT_SPIKE_THRESHOLD:
			score -= 24
		if phase == PHASE_SAFE_EXPANSION:
			score += 22
		elif phase == PHASE_APPROACHING_CONTACT:
			score += 2
		else:
			score -= 26
		score += _strategy_bias_int("gather_drive_bonus")

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
	_prof_end("placement_scoring", t_start)
	return best

# Low-frequency rear support conversion (mostly ranged) after frontline is established.
func _best_support_conversion_action(
	state: GameState,
	owner_id: int,
	_planned_actions: Array,
	energy: int,
	reserved_convert_blocks: Dictionary
) -> Dictionary:
	var t_start: int = _prof_begin()
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
		var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, pos)
		var phase: int = _local_threat_phase(state, owner_id, pos, nearest_dist, adjacent_enemy)
		if phase == PHASE_SAFE_EXPANSION:
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type == "ranged":
			continue
		var to_type: String = "ranged"
		if _is_ranged_hard_capped(state, owner_id):
			to_type = "melee" if phase != PHASE_APPROACHING_CONTACT and _count_owned_support(state, owner_id, pos, 2) >= 2 else "defense"
		elif nearest_dist <= 2 and _count_owned_support(state, owner_id, pos, 2) >= 3:
			to_type = "melee"
		var delta: int = Combat.conversion_energy_delta(from_type, to_type)
		if delta > energy:
			continue

		var score: int = _conversion_score(state, owner_id, block, from_type, to_type, false)
		if _is_second_line_tile(state, owner_id, pos):
			score += 12
		if to_type == "melee" and nearest_dist <= 2:
			score += 10
		if to_type == "defense":
			score -= _defense_density_penalty(state, owner_id, pos, phase)
			if phase == PHASE_APPROACHING_CONTACT:
				score -= 10
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
	_prof_end("conversion_scoring", t_start)
	return best

func _best_safe_backline_downgrade_action(
	state: GameState,
	owner_id: int,
	energy: int,
	reserved_convert_blocks: Dictionary,
	engaged: bool,
	low_threat: bool
) -> Dictionary:
	var t_start: int = _prof_begin()
	if engaged or not low_threat:
		_prof_end("conversion_scoring", t_start)
		return {}
	if state.turn_index < SAFE_DOWNGRADE_MIN_TURN:
		_prof_end("conversion_scoring", t_start)
		return {}

	var basic_cost: int = int(Combat.TILE_RULES["basic"]["cost"])
	var gather_cost: int = int(Combat.TILE_RULES["gather"]["cost"])
	var income_gap: int = maxi(0, MID_ECON_INCOME_THRESHOLD - _estimated_owner_income(state, owner_id))
	var wants_econ_boost: bool = _count_gather_tiles(state, owner_id) < MID_GATHER_TARGET and income_gap > 0
	var target_energy: int = basic_cost
	if wants_econ_boost:
		target_energy = gather_cost
	if energy >= target_energy:
		_prof_end("conversion_scoring", t_start)
		return {}

	var best: Dictionary = {}
	var best_score: int = -999999
	for block in state.get_owner_blocks(owner_id):
		if bool(block.get("core", false)):
			continue
		if bool(block.get("is_heart", false)):
			continue
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue

		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type == "basic" or from_type == "gather":
			continue
		var from_tier: int = int(block.get("upgrade_tier", 0))
		if from_tier <= 0:
			continue
		var downgrade_delta: int = Combat.conversion_energy_delta(from_type, "basic", from_tier)
		var downgrade_refund: int = -downgrade_delta
		if downgrade_refund <= 0:
			continue
		if energy + downgrade_refund < target_energy:
			continue

		var last_turn: int = int(block.get("last_converted_turn", -999999))
		if state.turn_index - last_turn < CONVERSION_COOLDOWN_TURNS:
			continue

		var pos: Vector2i = block["pos"]
		if _is_frontline_tile(state, owner_id, pos):
			continue
		if _is_second_line_tile(state, owner_id, pos):
			continue
		if _is_near_front_tile(state, owner_id, pos):
			continue
		if _has_adjacent_allied_heart(state, owner_id, pos):
			continue

		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		if nearest_enemy_dist < SAFE_DOWNGRADE_MIN_ENEMY_DISTANCE:
			continue
		var local_threat: int = _local_threat_score(state, owner_id, pos)
		if local_threat > SAFE_DOWNGRADE_MAX_THREAT:
			continue

		var choke: int = _chokepoint_score(state, pos)
		if choke >= 6:
			continue

		var support: int = _count_owned_support(state, owner_id, pos, 2)
		var objective_dist: int = _primary_objective_distance(state, owner_id, pos)
		var score: int = 18
		score += nearest_enemy_dist * 2
		score += support
		score -= local_threat * 2
		score -= choke * 2
		if objective_dist <= 6:
			score -= (7 - objective_dist) * 6
		if from_type == "ranged":
			score -= 6
		elif from_type == "defense":
			score -= 4

		if score < SAFE_DOWNGRADE_MIN_SCORE:
			continue
		if score > best_score:
			best_score = score
			best = {
				"score": score,
				"action": {
					"type": "convert_tile",
					"owner": owner_id,
					"block_id": block_id,
					"to_type": "basic",
					"energy_delta": downgrade_delta,
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
	var t_start: int = _prof_begin()
	var best: Dictionary = {}
	var best_score: int = -999999
	var objective_baseline_dist: int = _owner_objective_frontier_distance(state, owner_id)
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	for block in state.get_owner_blocks(owner_id):
		var block_id: int = int(block["id"])
		if reserved_convert_blocks.has(block_id):
			continue
		if not _can_upgrade_block(block):
			continue

		var tile_type: String = String(block.get("tile_type", "basic"))
		var current_tier: int = maxi(Combat.SPECIALIZATION_TIER, int(block.get("upgrade_tier", Combat.SPECIALIZATION_TIER)))
		var cost: int = Combat.upgrade_energy_cost(state, owner_id, tile_type, 0, 0, current_tier)
		if cost <= 0 or cost > energy:
			continue

		var pos: Vector2i = block["pos"]
		var support: int = _count_owned_support(state, owner_id, pos, 2)
		var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
		var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, pos)
		var phase: int = _local_threat_phase(state, owner_id, pos, nearest_enemy_dist, adjacent_enemy)
		var zone: String = _tile_zone(state, owner_id, pos)
		var choke: int = _chokepoint_score(state, pos)
		var frontline_depth: int = _distance_to_nearest_owned_frontline(state, owner_id, pos)
		var objective_dist: int = _primary_objective_distance(state, owner_id, pos)

		if tile_type == "defense" and zone == "backline" and choke < 4 and phase == PHASE_SAFE_EXPANSION:
			continue
		if tile_type == "melee" and zone == "backline" and nearest_enemy_dist > 4:
			continue
		if tile_type == "ranged":
			if zone == "frontline":
				continue
			if not _is_ranged_position_allowed(state, owner_id, pos):
				continue
		if tile_type == "gather" and zone != "backline":
			continue
		if tile_type == "gather" and int(block.get("gather_bonus", 0)) <= 0:
			continue

		var must_keep_reserve: int = int(Combat.TILE_RULES["basic"]["cost"]) + maxi(2, TILE_UPGRADE_SURPLUS_RESERVE - 2)
		if energy - cost < must_keep_reserve:
			continue

		var objective_delta_score: int = _objective_progress_delta_score(state, owner_id, pos, objective_baseline_dist, false)
		var score: int = 0
		match tile_type:
			"defense":
				score = 78 if zone == "frontline" else (46 if choke >= 4 else 20)
			"melee":
				score = 74 if zone == "frontline" else (42 if nearest_enemy_dist <= 3 else 18)
			"ranged":
				score = 72 if zone == "second_line" else (56 if zone == "backline" else 8)
			"gather":
				score = 54 if zone == "backline" else 20
			_:
				score = 0

		var tier_step: int = current_tier - Combat.SPECIALIZATION_TIER + 1
		score += tier_step * 16
		if prefer_frontline and zone == "frontline":
			score += 12
		if zone == "frontline" and tile_type == "ranged":
			score -= 22
		score += _upgrade_focus_bonus(
			state,
			owner_id,
			pos,
			tile_type,
			phase,
			zone,
			support,
			nearest_enemy_dist,
			adjacent_enemy,
			choke,
			frontline_depth
		)
		score += _door_objective_score(state, owner_id, pos)
		score += int(round(_heart_objective_score(state, owner_id, pos) * 0.85))
		score += support * 2
		score += maxi(0, 8 - nearest_enemy_dist) * 2
		if tile_type == "gather":
			var income_gap: int = maxi(0, MID_ECON_INCOME_THRESHOLD - _estimated_owner_income(state, owner_id))
			score += income_gap * 6
			var resource_dist: int = _nearest_open_resource_distance(state, pos)
			if resource_dist <= gather_conversion_resource_max_dist:
				score += 16 + (gather_conversion_resource_max_dist - resource_dist + 1) * 4
		if tile_type == "defense":
			score += choke * 2
		if tile_type == "ranged":
			score += _ranged_preferred_depth_bonus(state, owner_id, pos)
			if frontline_depth > 3:
				score -= 14
		if tile_type == "melee" and (adjacent_enemy > 0 or nearest_enemy_dist <= 2):
			score += 12
		if phase == PHASE_SAFE_EXPANSION and objective_dist > 8 and tile_type in ["defense", "ranged"]:
			score -= 12
		score += objective_delta_score
		score -= cost * 3

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
	var tile_upgrade_min_score: int = _tp_int("tile_upgrade_min_score", TILE_UPGRADE_MIN_SCORE)
	if best_score < tile_upgrade_min_score:
		_prof_end("upgrade_scoring", t_start)
		return {}
	_prof_end("upgrade_scoring", t_start)
	return best

func _should_prefer_tile_upgrade_candidate(current_candidate: Dictionary, tile_upgrade_candidate: Dictionary, engaged: bool) -> bool:
	if tile_upgrade_candidate.is_empty():
		return false
	if current_candidate.is_empty():
		return true

	var upgrade_score: int = int(tile_upgrade_candidate.get("score", -999999))
	var current_score: int = int(current_candidate.get("score", -999999))
	var current_action: Dictionary = current_candidate.get("action", {})
	var kind: String = String(current_action.get("type", "pass"))
	if kind == "convert_tile":
		var to_type: String = String(current_action.get("to_type", "basic"))
		var priority_margin: int = _tp_int("upgrade_priority_margin", UPGRADE_PRIORITY_MARGIN)
		if engaged and to_type == "defense":
			return upgrade_score >= current_score + priority_margin + 10
		return upgrade_score >= current_score + priority_margin - 2
	if kind == "place_tile":
		var place_priority_margin: int = _tp_int("upgrade_priority_margin", UPGRADE_PRIORITY_MARGIN)
		var placed_type: String = String(current_action.get("tile_type", "basic"))
		if placed_type == "basic":
			return upgrade_score >= current_score + place_priority_margin - 4
		return upgrade_score >= current_score + place_priority_margin
	return upgrade_score > current_score

func _upgrade_focus_bonus(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	tile_type: String,
	phase: int,
	zone: String,
	support: int,
	nearest_enemy_dist: int,
	adjacent_enemy: int,
	choke: int,
	frontline_depth: int
) -> int:
	var bonus: int = 0
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	var objective_dist: int = _primary_objective_distance(state, owner_id, tile)
	if objective_dist <= 4:
		bonus += 28
	elif objective_dist <= 7:
		bonus += 18
	elif objective_dist <= 10:
		bonus += 10

	var resource_dist: int = _nearest_open_resource_distance(state, tile)
	if resource_dist <= gather_conversion_resource_max_dist:
		if tile_type == "gather":
			bonus += 20
		else:
			bonus += 12
	elif resource_dist <= 5:
		bonus += 4

	if zone == "frontline" or phase == PHASE_ACTIVE_FRONTLINE:
		bonus += 8
	if support >= 3:
		bonus += 6

	match tile_type:
		"defense":
			if choke >= 4:
				bonus += 14
		"ranged":
			if _has_friendly_screen_toward_nearest_enemy(state, owner_id, tile):
				bonus += 10
			else:
				bonus -= 12
			if frontline_depth >= 1 and frontline_depth <= 2:
				bonus += 8
		"melee":
			if adjacent_enemy > 0 or nearest_enemy_dist <= 3:
				bonus += 12
		_:
			pass
	return bonus

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
	if _is_owner_low_threat(state, owner_id) and income <= MID_ECON_INCOME_THRESHOLD + 1:
		return true
	if income < MID_ECON_INCOME_THRESHOLD:
		return true
	if energy <= MID_ECON_ENERGY_LOW_THRESHOLD:
		return true
	if engaged and income >= MID_ECON_INCOME_THRESHOLD:
		return false
	return false

func _should_prefer_midgame_gather_candidate(
	existing_candidate: Dictionary,
	gather_candidate: Dictionary,
	state: GameState,
	owner_id: int,
	engaged: bool,
	frontline_committed: bool
) -> bool:
	if gather_candidate.is_empty():
		return false
	if existing_candidate.is_empty():
		return true

	var income: int = _estimated_owner_income(state, owner_id)
	var energy: int = int(state.players.get(owner_id, {}).get("nutrients", 0))
	var economy_stressed: bool = income < MID_ECON_INCOME_THRESHOLD or energy <= MID_ECON_ENERGY_LOW_THRESHOLD + 2
	if not economy_stressed:
		return false

	var existing_action: Dictionary = existing_candidate.get("action", {})
	var existing_kind: String = String(existing_action.get("type", ""))
	if existing_kind == "upgrade_tile":
		return false
	if engaged and not frontline_committed and (existing_kind == "place_tile" or existing_kind == "convert_tile"):
		return false

	var existing_role: String = ""
	if existing_kind == "place_tile":
		existing_role = String(existing_action.get("tile_type", "basic"))
	elif existing_kind == "convert_tile":
		existing_role = String(existing_action.get("to_type", "basic"))
	if existing_role == "melee" or existing_role == "defense":
		return false

	var gather_score: int = int(gather_candidate.get("score", -999999))
	var existing_score: int = int(existing_candidate.get("score", -999999))
	return gather_score >= existing_score - 5

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

func _is_owner_low_threat(state: GameState, owner_id: int) -> bool:
	for block in state.get_owner_blocks(owner_id):
		if _local_threat_phase(state, owner_id, block["pos"]) != PHASE_SAFE_EXPANSION:
			return false
	return true

func _should_prefer_gather_conversion(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	nearest_enemy_dist: int,
	engaged: bool
) -> bool:
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	var phase: int = _local_threat_phase(state, owner_id, tile, nearest_enemy_dist, _adjacent_enemy_count(state, owner_id, tile))
	if engaged and phase != PHASE_SAFE_EXPANSION:
		return false
	if not _is_gather_position_allowed(state, owner_id, tile, nearest_enemy_dist, phase):
		return false
	if _count_gather_tiles(state, owner_id) >= MID_GATHER_TARGET:
		return false
	if _nearest_open_resource_distance(state, tile) > gather_conversion_resource_max_dist:
		return false
	return true

func _is_upgrade_conversion_action(action: Dictionary) -> bool:
	if String(action.get("type", "")) != "convert_tile":
		return false
	return String(action.get("to_type", "basic")) != "basic"

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
		var tier_ii_cost: int = int(Combat.UPGRADE_BASE_COST[role]) + int(Combat.UPGRADE_TIER_II_SURCHARGE)
		cheapest_tile_upgrade = mini(cheapest_tile_upgrade, tier_ii_cost)
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

func _is_gather_position_allowed(state: GameState, owner_id: int, tile: Vector2i, nearest_enemy_dist: int, phase: int) -> bool:
	var gather_safe_min_enemy_distance: int = _tp_int("gather_safe_min_enemy_distance", GATHER_SAFE_MIN_ENEMY_DISTANCE)
	if phase == PHASE_ACTIVE_FRONTLINE:
		return false
	if phase != PHASE_SAFE_EXPANSION and phase != PHASE_APPROACHING_CONTACT:
		return false
	if phase == PHASE_SAFE_EXPANSION and nearest_enemy_dist < gather_safe_min_enemy_distance:
		return false
	if phase == PHASE_APPROACHING_CONTACT:
		var approaching_min_enemy_distance: int = maxi(3, gather_safe_min_enemy_distance - 1)
		if nearest_enemy_dist < approaching_min_enemy_distance:
			return false
		if _local_threat_score(state, owner_id, tile) > LOW_THREAT_MAX_LOCAL_SCORE:
			return false
	if nearest_enemy_dist < 3:
		return false
	if _is_near_front_tile(state, owner_id, tile):
		return false
	return _tile_zone(state, owner_id, tile) == "backline"

func _is_ranged_position_allowed(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	if _is_frontline_tile(state, owner_id, tile):
		return false
	return _has_friendly_screen_toward_nearest_enemy(state, owner_id, tile)

func _ranged_position_penalty(state: GameState, owner_id: int, tile: Vector2i, zone: String, phase: int = PHASE_ACTIVE_FRONTLINE) -> int:
	var adjacent_ranged: int = _adjacent_owned_type_count(state, owner_id, tile, "ranged")
	var nearby_ranged: int = _owned_type_count_within_manhattan(state, owner_id, tile, 2, "ranged")
	var penalty: int = adjacent_ranged * RANGED_CHAIN_ADJACENT_PENALTY
	penalty += maxi(0, nearby_ranged - 2) * RANGED_CHAIN_CLUSTER_PENALTY
	if not _has_friendly_screen_toward_nearest_enemy(state, owner_id, tile):
		penalty += RANGED_EXPOSED_PENALTY + adjacent_ranged * 6
	if zone == "backline":
		penalty += 10
	var nearby_owned: int = maxi(1, _count_owned_support(state, owner_id, tile, 2))
	var local_ratio: float = float(nearby_ranged) / float(nearby_owned)
	if local_ratio >= RANGED_LOCAL_RATIO_HARD_CAP:
		penalty += RANGED_LOCAL_RATIO_HARD_PENALTY
	elif local_ratio >= RANGED_LOCAL_RATIO_SOFT_CAP:
		penalty += RANGED_LOCAL_RATIO_SOFT_PENALTY
	var frontline_depth: int = _distance_to_nearest_owned_frontline(state, owner_id, tile)
	if frontline_depth > 3:
		penalty += RANGED_NO_FRONTLINE_PENALTY + mini(12, maxi(0, frontline_depth - 4) * 4)
	if phase == PHASE_SAFE_EXPANSION:
		penalty += RANGED_SAFE_EXPANSION_PENALTY
	elif phase == PHASE_APPROACHING_CONTACT:
		penalty += RANGED_APPROACHING_PHASE_PENALTY
	return penalty

func _ranged_preferred_depth_bonus(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var depth: int = _distance_to_nearest_owned_frontline(state, owner_id, tile)
	if depth >= 1 and depth <= 2:
		return 12
	if depth == 3:
		return 4
	if depth > 3:
		return -8
	return 0

func _distance_to_nearest_owned_frontline(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var best: int = 99
	for block in state.get_owner_blocks(owner_id):
		var pos: Vector2i = block["pos"]
		if not _is_frontline_tile(state, owner_id, pos):
			continue
		best = mini(best, _distance_to_tile(tile, pos))
	return best

func _has_friendly_screen_toward_nearest_enemy(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	var enemy_tile: Vector2i = _nearest_hostile_tile(state, owner_id, tile)
	if enemy_tile == Vector2i(-1, -1):
		return true
	var step: Vector2i = _step_toward_tile(tile, enemy_tile)
	if step == Vector2i.ZERO:
		return true
	var screen_block: Dictionary = state.get_block_at(tile + step)
	if screen_block.is_empty():
		return false
	return int(screen_block.get("owner", 0)) == owner_id

func _nearest_hostile_tile(state: GameState, owner_id: int, tile: Vector2i) -> Vector2i:
	var best_dist: int = 999999
	var best_tile: Vector2i = Vector2i(-1, -1)
	var block_ids: Array = state.blocks.keys()
	block_ids.sort()
	for block_id_variant in block_ids:
		var block_id: int = int(block_id_variant)
		if not state.blocks.has(block_id):
			continue
		var block: Dictionary = state.blocks[block_id]
		if not state.are_hostile(owner_id, int(block.get("owner", 0))):
			continue
		var enemy_tile: Vector2i = block["pos"]
		var dist: int = _distance_to_tile(tile, enemy_tile)
		if dist < best_dist:
			best_dist = dist
			best_tile = enemy_tile
			continue
		if dist != best_dist or best_tile == Vector2i(-1, -1):
			continue
		if enemy_tile.y < best_tile.y:
			best_tile = enemy_tile
		elif enemy_tile.y == best_tile.y and enemy_tile.x < best_tile.x:
			best_tile = enemy_tile
	return best_tile

func _step_toward_tile(from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var dx: int = to_tile.x - from_tile.x
	var dy: int = to_tile.y - from_tile.y
	if dx == 0 and dy == 0:
		return Vector2i.ZERO
	if absi(dx) >= absi(dy):
		if dx != 0:
			return Vector2i(signi(dx), 0)
		return Vector2i(0, signi(dy))
	return Vector2i(0, signi(dy))

func _local_threat_phase(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	nearest_enemy_dist: int = -1,
	adjacent_enemy: int = -1
) -> int:
	var nearest_dist: int = nearest_enemy_dist if nearest_enemy_dist >= 0 else _nearest_enemy_distance(state, owner_id, tile)
	var adjacent: int = adjacent_enemy if adjacent_enemy >= 0 else _adjacent_enemy_count(state, owner_id, tile)
	var local_threat: int = _local_threat_score(state, owner_id, tile)
	if adjacent > 0 or nearest_dist <= PHASE_ACTIVE_FRONTLINE_MAX_ENEMY_DISTANCE or local_threat >= THREAT_SPIKE_THRESHOLD:
		return PHASE_ACTIVE_FRONTLINE
	if nearest_dist <= PHASE_APPROACHING_CONTACT_MAX_ENEMY_DISTANCE or local_threat >= PHASE_APPROACHING_LOCAL_THREAT_MIN:
		return PHASE_APPROACHING_CONTACT
	return PHASE_SAFE_EXPANSION

func _owned_type_count_within_manhattan(state: GameState, owner_id: int, tile: Vector2i, radius: int, tile_type: String) -> int:
	var total: int = 0
	for block in state.get_owner_blocks(owner_id):
		if String(block.get("tile_type", "basic")) != tile_type:
			continue
		if _distance_to_tile(tile, block["pos"]) <= radius:
			total += 1
	return total

func _adjacent_owned_type_count(state: GameState, owner_id: int, tile: Vector2i, tile_type: String) -> int:
	var total: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var block: Dictionary = state.get_block_at(tile + step)
		if block.is_empty():
			continue
		if int(block.get("owner", 0)) != owner_id:
			continue
		if String(block.get("tile_type", "basic")) != tile_type:
			continue
		total += 1
	return total

func _defense_density_penalty(state: GameState, owner_id: int, tile: Vector2i, phase: int) -> int:
	var defense_nearby_soft_limit: int = _tp_int("defense_nearby_soft_limit", DEFENSE_NEARBY_SOFT_LIMIT)
	var defense_local_ratio_hard_cap: float = _tp_float("defense_local_ratio_hard_cap", DEFENSE_LOCAL_RATIO_HARD_CAP)
	var defense_local_ratio_soft_cap: float = _tp_float("defense_local_ratio_soft_cap", DEFENSE_LOCAL_RATIO_SOFT_CAP)
	var nearby_defense: int = _owned_type_count_within_manhattan(state, owner_id, tile, DEFENSE_DENSITY_RADIUS, "defense")
	var adjacent_defense: int = _adjacent_owned_type_count(state, owner_id, tile, "defense")
	var nearby_owned: int = maxi(1, _count_owned_support(state, owner_id, tile, DEFENSE_DENSITY_RADIUS))
	var defense_ratio: float = float(nearby_defense) / float(nearby_owned)

	var penalty: int = 0
	penalty += adjacent_defense * 9
	penalty += maxi(0, nearby_defense - defense_nearby_soft_limit) * 5
	if defense_ratio >= defense_local_ratio_hard_cap:
		penalty += 18
	elif defense_ratio >= defense_local_ratio_soft_cap:
		penalty += 8

	match phase:
		PHASE_SAFE_EXPANSION:
			penalty += 22
		PHASE_APPROACHING_CONTACT:
			penalty += 10
		PHASE_ACTIVE_FRONTLINE:
			penalty += 4
	penalty += _strategy_bias_int("defense_extra_penalty")
	return penalty

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
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	var local_threat: int = _local_threat_score(state, owner_id, tile)
	var phase: int = _local_threat_phase(state, owner_id, tile, nearest_enemy_dist, adjacent_enemy)
	var gather_cost: int = int(Combat.TILE_RULES["gather"]["cost"])
	var gather_count: int = _count_gather_tiles(state, owner_id)
	var resource_dist: int = _nearest_open_resource_distance(state, tile)
	var gather_ready: bool = gather_count < MID_GATHER_TARGET and energy >= gather_cost
	var defense_penalty: int = _defense_density_penalty(state, owner_id, tile, phase)
	var choke_score: int = _chokepoint_score(state, tile)
	var ranged_penalty: int = _ranged_position_penalty(state, owner_id, tile, zone, phase)

	if phase == PHASE_SAFE_EXPANSION:
		if zone == "backline" and gather_ready and resource_dist <= gather_conversion_resource_max_dist and support >= 2 and _is_gather_position_allowed(state, owner_id, tile, nearest_enemy_dist, phase):
			return "gather"
		return "basic"

	if phase == PHASE_APPROACHING_CONTACT:
		if zone == "backline" and gather_ready and resource_dist <= gather_conversion_resource_max_dist and local_threat <= LOW_THREAT_MAX_LOCAL_SCORE and _is_gather_position_allowed(state, owner_id, tile, nearest_enemy_dist, phase):
			return "gather"
		if zone == "frontline":
			if local_threat >= THREAT_SPIKE_THRESHOLD + 2 and defense_penalty < 24 and support <= 2 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
				return "defense"
			if energy >= int(Combat.TILE_RULES["melee"]["cost"]):
				return "melee"
			return "basic"
		if zone == "second_line":
			if support >= 2 and choke_score >= 2 and not _is_ranged_hard_capped(state, owner_id) and energy >= int(Combat.TILE_RULES["ranged"]["cost"]) and _is_ranged_position_allowed(state, owner_id, tile) and ranged_penalty < 36:
				return "ranged"
			if nearest_enemy_dist <= 3 and support >= 2 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
				return "melee"
			if local_threat >= THREAT_SPIKE_THRESHOLD and defense_penalty < 26 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
				return "defense"
			return "basic"

	if zone == "frontline":
		if local_threat >= THREAT_SPIKE_THRESHOLD + 2 and defense_penalty < 30 and support <= 2 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
		if energy >= int(Combat.TILE_RULES["melee"]["cost"]):
			return "melee"
	if zone == "second_line":
		if support >= 2 and choke_score >= 2 and not _is_ranged_hard_capped(state, owner_id) and energy >= int(Combat.TILE_RULES["ranged"]["cost"]) and _is_ranged_position_allowed(state, owner_id, tile) and ranged_penalty < 36:
			return "ranged"
		if nearest_enemy_dist <= 3 and support >= 2 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
			return "melee"
		if local_threat >= THREAT_SPIKE_THRESHOLD + 2 and defense_penalty < 30 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
	if zone == "backline":
		if gather_ready and resource_dist <= gather_conversion_resource_max_dist and local_threat <= LOW_THREAT_MAX_LOCAL_SCORE and _is_gather_position_allowed(state, owner_id, tile, nearest_enemy_dist, phase):
			return "gather"
		if nearest_enemy_dist <= 3 and support >= 3 and not _is_ranged_hard_capped(state, owner_id) and energy >= int(Combat.TILE_RULES["ranged"]["cost"]) and _is_ranged_position_allowed(state, owner_id, tile) and ranged_penalty < 34:
			return "ranged"
		if adjacent_enemy > 0 and defense_penalty < 24 and energy >= int(Combat.TILE_RULES["defense"]["cost"]):
			return "defense"
	if nearest_enemy_dist <= 2 and support >= 2 and energy >= int(Combat.TILE_RULES["melee"]["cost"]):
		return "melee"
	return "basic"

func _zone_role_score(zone: String, tile_type: String) -> int:
	if zone == "frontline":
		if tile_type == "defense":
			return 16
		if tile_type == "melee":
			return 22
		if tile_type == "ranged":
			return -18
	if zone == "second_line":
		if tile_type == "ranged":
			return 24
		if tile_type == "defense":
			return -2
		if tile_type == "melee":
			return 6
	if zone == "backline":
		if tile_type == "ranged":
			return -6
		if tile_type == "gather":
			return 16
		if tile_type == "defense":
			return -16
		if tile_type == "melee":
			return -18
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

func _resource_objective_score(state: GameState, owner_id: int, tile: Vector2i, phase: int, tile_type: String = "basic") -> int:
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	var best_dist: int = 999999
	var on_open_resource: bool = false
	for node in state.resource_nodes:
		if bool(node.get("consumed", false)):
			continue
		var resource_tile: Vector2i = node.get("pos", Vector2i(-1, -1))
		if not state.is_inside(resource_tile):
			continue
		var dist: int = _distance_to_tile(tile, resource_tile)
		best_dist = mini(best_dist, dist)
		if dist == 0:
			on_open_resource = true
	if best_dist >= 999999:
		return 0

	var max_dist: int = _tp_int("resource_objective_max_distance", RESOURCE_OBJECTIVE_MAX_DISTANCE)
	var step_weight: int = _tp_int("resource_objective_step_weight", RESOURCE_OBJECTIVE_STEP_WEIGHT)
	var score: int = maxi(0, max_dist - best_dist + 1) * step_weight
	match phase:
		PHASE_SAFE_EXPANSION:
			score += _tp_int("resource_safe_phase_bonus", RESOURCE_SAFE_PHASE_BONUS)
		PHASE_APPROACHING_CONTACT:
			score += _tp_int("resource_approaching_phase_bonus", RESOURCE_APPROACHING_PHASE_BONUS)
		_:
			pass
	if best_dist <= 1 and phase != PHASE_ACTIVE_FRONTLINE:
		score += _tp_int("resource_low_threat_bonus", RESOURCE_LOW_THREAT_BONUS)
	if on_open_resource:
		score += _tp_int("resource_node_hold_bonus", RESOURCE_NODE_HOLD_BONUS)
	if tile_type == "gather" and best_dist <= gather_conversion_resource_max_dist:
		score += _tp_int("resource_gather_focus_bonus", RESOURCE_GATHER_FOCUS_BONUS)

	var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, tile)
	if nearest_enemy_dist <= 2 and phase != PHASE_ACTIVE_FRONTLINE:
		score -= _tp_int("resource_near_threat_penalty", RESOURCE_NEAR_THREAT_PENALTY)
	score += _strategy_bias_int("resource_focus_bonus")
	if tile_type == "gather":
		score += _strategy_bias_int("gather_drive_bonus")
	return maxi(0, score)

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
		var enemy_support: int = _count_owned_support(state, enemy_owner, enemy_pos, 2)
		if enemy_support >= 5:
			weight += 2
		weight += maxi(0, THREAT_SCAN_RADIUS + 1 - dist)
		threat += weight
	return threat

# Penalize low-impact backline role churn, reward pressure-positive role shifts.
func _conversion_score(state: GameState, owner_id: int, block: Dictionary, from_type: String, to_type: String, is_frontline_target: bool) -> int:
	var t_start: int = _prof_begin()
	var ranged_frontline_penalty: int = _tp_int("ranged_frontline_penalty", RANGED_FRONTLINE_PENALTY)
	var ranged_backline_penalty: int = _tp_int("ranged_backline_penalty", RANGED_BACKLINE_PENALTY)
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	var pos: Vector2i = block["pos"]
	var support: int = _count_owned_support(state, owner_id, pos, 2)
	var pressure: int = _enemy_pressure_score(state, owner_id, pos)
	var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, pos)
	var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, pos)
	var zone: String = _tile_zone(state, owner_id, pos)
	var phase: int = _local_threat_phase(state, owner_id, pos, nearest_enemy_dist, adjacent_enemy)
	var score: int = 0

	score += pressure * 2
	score += support
	score += maxi(0, 8 - nearest_enemy_dist) * 3
	score += _door_objective_score(state, owner_id, pos)
	score += _heart_objective_score(state, owner_id, pos)
	score += _resource_objective_score(state, owner_id, pos, phase, to_type)
	score += _strategy_tile_bonus(state, owner_id, pos, phase, zone, to_type)
	score += _zone_role_score(zone, to_type)
	score += int(round(
		float(_flank_pressure_bonus_score(
			state,
			owner_id,
			pos,
			zone,
			phase,
			support,
			nearest_enemy_dist,
			adjacent_enemy,
			_owner_objective_frontier_distance(state, owner_id)
		)) * 0.6
	))

	if is_frontline_target:
		score += 20
	if not is_frontline_target and nearest_enemy_dist >= 5:
		score -= 30

	if to_type == "defense":
		if phase == PHASE_SAFE_EXPANSION:
			_prof_end("conversion_scoring", t_start)
			return ROLE_POSITION_BLOCK_SCORE
		score += 6 if is_frontline_target else -8
		score -= _defense_density_penalty(state, owner_id, pos, phase)
		if phase == PHASE_SAFE_EXPANSION:
			score -= 22
		elif phase == PHASE_APPROACHING_CONTACT:
			score -= 6
	elif to_type == "melee":
		score += 5 if is_frontline_target else -6
		if phase == PHASE_SAFE_EXPANSION and not is_frontline_target:
			score -= 16
		elif phase == PHASE_APPROACHING_CONTACT:
			score += 4
		elif phase == PHASE_ACTIVE_FRONTLINE:
			score += 8
	elif to_type == "ranged":
		if not _is_ranged_position_allowed(state, owner_id, pos):
			_prof_end("conversion_scoring", t_start)
			return ROLE_POSITION_BLOCK_SCORE
		score += 10 if nearest_enemy_dist >= 2 and nearest_enemy_dist <= 4 else -12
		score -= _ranged_saturation_penalty(state, owner_id)
		score -= _ranged_position_penalty(state, owner_id, pos, zone, phase)
		score += _ranged_preferred_depth_bonus(state, owner_id, pos)
		var choke: int = _chokepoint_score(state, pos)
		if zone == "second_line" and choke >= 2:
			score += 10
		if is_frontline_target or nearest_enemy_dist <= 1:
			score -= ranged_frontline_penalty
		elif zone == "backline":
			score -= ranged_backline_penalty
	elif to_type == "gather":
		if not _is_gather_position_allowed(state, owner_id, pos, nearest_enemy_dist, phase):
			_prof_end("conversion_scoring", t_start)
			return ROLE_POSITION_BLOCK_SCORE
		score -= 12
		if phase == PHASE_SAFE_EXPANSION:
			score += 24
		if _nearest_open_resource_distance(state, pos) <= gather_conversion_resource_max_dist:
			score += 12

	if from_type in ["defense", "melee"] and to_type in ["defense", "melee"] and not is_frontline_target:
		score -= 14
	if from_type == "basic" and to_type != "basic":
		score -= _specialization_spread_penalty(state, owner_id, pos, to_type, phase, zone, nearest_enemy_dist, support)

	_prof_end("conversion_scoring", t_start)
	return score

func _is_ranged_hard_capped(state: GameState, owner_id: int) -> bool:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	var total_tiles: int = owner_blocks.size()
	var min_tiles: int = _tp_int("ranged_saturation_min_tiles", RANGED_SATURATION_MIN_TILES)
	if total_tiles < min_tiles:
		return false
	var hard_cap: float = _tp_float("ranged_saturation_hard_cap", RANGED_SATURATION_HARD_CAP)
	return _owner_type_ratio(owner_blocks, "ranged") >= hard_cap

func _ranged_saturation_penalty(state: GameState, owner_id: int) -> int:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	var total_tiles: int = owner_blocks.size()
	var min_tiles: int = _tp_int("ranged_saturation_min_tiles", RANGED_SATURATION_MIN_TILES)
	if total_tiles < min_tiles:
		return 0
	var ratio: float = _owner_type_ratio(owner_blocks, "ranged")
	var soft_cap: float = _tp_float("ranged_saturation_soft_cap", RANGED_SATURATION_SOFT_CAP)
	var hard_cap: float = _tp_float("ranged_saturation_hard_cap", RANGED_SATURATION_HARD_CAP)
	if ratio <= soft_cap:
		return 0
	var band: float = maxf(0.0001, hard_cap - soft_cap)
	var t: float = clampf((ratio - soft_cap) / band, 0.0, 1.0)
	var max_penalty: int = _tp_int("ranged_saturation_max_penalty", RANGED_SATURATION_MAX_PENALTY)
	return int(round(float(max_penalty) * t))

func _owner_type_ratio(owner_blocks: Array, tile_type: String) -> float:
	if owner_blocks.is_empty():
		return 0.0
	var matches: int = 0
	for block in owner_blocks:
		if String(block.get("tile_type", "basic")) == tile_type:
			matches += 1
	return float(matches) / float(owner_blocks.size())

func _is_specialized_tile_type(tile_type: String) -> bool:
	return tile_type != "basic"

func _owner_specialization_ratio(owner_blocks: Array) -> float:
	if owner_blocks.is_empty():
		return 0.0
	var specialized: int = 0
	for block in owner_blocks:
		if _is_specialized_tile_type(String(block.get("tile_type", "basic"))):
			specialized += 1
	return float(specialized) / float(owner_blocks.size())

func _specialization_saturation_penalty(state: GameState, owner_id: int) -> int:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	var total_tiles: int = owner_blocks.size()
	var min_tiles: int = _tp_int("specialization_min_tiles", SPECIALIZATION_MIN_TILES)
	if total_tiles < min_tiles:
		return 0
	var ratio: float = _owner_specialization_ratio(owner_blocks)
	var soft_cap: float = _tp_float("specialization_soft_cap", SPECIALIZATION_SOFT_CAP)
	var hard_cap: float = _tp_float("specialization_hard_cap", SPECIALIZATION_HARD_CAP)
	if ratio <= soft_cap:
		return 0
	var band: float = maxf(0.0001, hard_cap - soft_cap)
	var t: float = clampf((ratio - soft_cap) / band, 0.0, 1.0)
	var max_penalty: int = _tp_int("specialization_max_penalty", SPECIALIZATION_MAX_PENALTY)
	return int(round(float(max_penalty) * t))

func _owned_specialized_count_within_manhattan(state: GameState, owner_id: int, tile: Vector2i, radius: int) -> int:
	var total: int = 0
	for block in state.get_owner_blocks(owner_id):
		var tile_type: String = String(block.get("tile_type", "basic"))
		if not _is_specialized_tile_type(tile_type):
			continue
		if _distance_to_tile(tile, block["pos"]) <= radius:
			total += 1
	return total

func _adjacent_owned_specialized_count(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var total: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var block: Dictionary = state.get_block_at(tile + step)
		if block.is_empty():
			continue
		if int(block.get("owner", 0)) != owner_id:
			continue
		if not _is_specialized_tile_type(String(block.get("tile_type", "basic"))):
			continue
		total += 1
	return total

func _specialization_spread_penalty(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	tile_type: String,
	phase: int,
	zone: String,
	nearest_enemy_dist: int,
	support: int
) -> int:
	if not _is_specialized_tile_type(tile_type):
		return 0

	var penalty: int = _specialization_saturation_penalty(state, owner_id)
	var local_radius: int = _tp_int("specialization_local_radius", SPECIALIZATION_LOCAL_RADIUS)
	var nearby_specialized: int = _owned_specialized_count_within_manhattan(state, owner_id, tile, local_radius)
	var adjacent_specialized: int = _adjacent_owned_specialized_count(state, owner_id, tile)
	var local_soft_limit: int = _tp_int("specialization_local_soft_limit", SPECIALIZATION_LOCAL_SOFT_LIMIT)
	var local_cluster_penalty: int = _tp_int("specialization_local_cluster_penalty", SPECIALIZATION_LOCAL_CLUSTER_PENALTY)
	var adjacent_penalty: int = _tp_int("specialization_adjacent_penalty", SPECIALIZATION_ADJACENT_PENALTY)
	penalty += maxi(0, nearby_specialized - local_soft_limit) * local_cluster_penalty
	penalty += adjacent_specialized * adjacent_penalty
	if phase == PHASE_SAFE_EXPANSION:
		penalty += _tp_int("specialization_safe_phase_penalty", SPECIALIZATION_SAFE_PHASE_PENALTY)
	if zone == "backline" and nearest_enemy_dist >= LOW_THREAT_MIN_ENEMY_DISTANCE:
		penalty += _tp_int("specialization_backline_blanket_penalty", SPECIALIZATION_BACKLINE_BLANKET_PENALTY)
	if zone != "frontline" and nearest_enemy_dist >= PHASE_APPROACHING_CONTACT_MAX_ENEMY_DISTANCE + 1 and support <= 2:
		penalty += _tp_int("specialization_path_penalty", SPECIALIZATION_PATH_PENALTY)
	penalty += _strategy_bias_int("specialization_penalty_bonus")

	var objective_dist: int = _primary_objective_distance(state, owner_id, tile)
	if objective_dist <= 5:
		penalty -= 18
	elif objective_dist <= 8:
		penalty -= 10
	var gather_conversion_resource_max_dist: int = _tp_int("gather_conversion_resource_max_dist", GATHER_CONVERSION_RESOURCE_MAX_DIST)
	if _nearest_open_resource_distance(state, tile) <= gather_conversion_resource_max_dist and tile_type == "gather":
		penalty -= 14
	if zone == "frontline" or phase == PHASE_ACTIVE_FRONTLINE:
		penalty -= 12
	return maxi(0, penalty)

func _desired_frontline_role(state: GameState, owner_id: int, block: Dictionary) -> String:
	var pressure: int = _enemy_pressure_score(state, owner_id, block["pos"])
	var support: int = _count_owned_support(state, owner_id, block["pos"], 2)
	var adjacent_enemy: int = _adjacent_enemy_count(state, owner_id, block["pos"])
	var nearest_enemy_dist: int = _nearest_enemy_distance(state, owner_id, block["pos"])
	var threat: int = _local_threat_score(state, owner_id, block["pos"])
	var phase: int = _local_threat_phase(state, owner_id, block["pos"], nearest_enemy_dist, adjacent_enemy)
	var defense_penalty: int = _defense_density_penalty(state, owner_id, block["pos"], phase)
	if phase == PHASE_SAFE_EXPANSION:
		return "melee"
	if phase == PHASE_APPROACHING_CONTACT:
		if threat >= THREAT_SPIKE_THRESHOLD and support <= 2 and defense_penalty < 24:
			return "defense"
		return "melee"
	if threat >= THREAT_SPIKE_THRESHOLD + 4 and support <= 2 and defense_penalty < 30:
		return "defense"
	if support <= 1 and defense_penalty < 28:
		return "defense"
	if pressure >= 10 and support <= 2 and defense_penalty < 30:
		return "defense"
	if adjacent_enemy >= 2 and support >= 2:
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
	var tier: int = maxi(Combat.SPECIALIZATION_TIER, int(block.get("upgrade_tier", Combat.SPECIALIZATION_TIER)))
	return tier < Combat.MAX_UPGRADE_TIER

func _is_frontline_tile(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	return _adjacent_enemy_count(state, owner_id, tile) > 0

func _adjacent_enemy_count(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var t_start: int = _prof_begin()
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var block: Dictionary = state.get_block_at(tile + step)
		if block.is_empty():
			continue
		if not state.are_hostile(owner_id, int(block["owner"])):
			continue
		count += 1
	_prof_end("enemy_proximity_calculations", t_start)
	_prof_add_count("enemy_proximity_calls")
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

func _growth_target_ok(state: GameState, owner_id: int, tile: Vector2i, min_adjacent: int, planned_tiles: Dictionary) -> bool:
	var t_start: int = _prof_begin()
	var ok: bool = bool(state.evaluate_growth_target(owner_id, tile, min_adjacent, planned_tiles).get("ok", false))
	_prof_end("candidate_generation", t_start)
	return ok

func _count_owned_support(state: GameState, owner_id: int, tile: Vector2i, radius: int, planned_tiles: Dictionary = {}) -> int:
	var t_start: int = _prof_begin()
	var count: int = state.count_owned_within_manhattan(owner_id, tile, radius, planned_tiles)
	_prof_end("support_calculations", t_start)
	_prof_add_count("support_calculation_calls")
	return count

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
	var t_start: int = _prof_begin()
	var best: int = 999999
	for enemy in state.blocks.values():
		if not state.are_hostile(owner_id, int(enemy["owner"])):
			continue
		best = mini(best, _distance_to_tile(tile, enemy["pos"]))
	_prof_end("enemy_proximity_calculations", t_start)
	_prof_add_count("enemy_proximity_calls")
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
	var t_start: int = _prof_begin()
	if _decision_cache_matches(state,  int(_decision_objective_cache.get("owner", 0))):
		var resource_distance_map: Dictionary = _decision_objective_cache.get("resource_distance_map", {})
		if resource_distance_map.has(tile):
			var cached_dist: int = int(resource_distance_map.get(tile, 99))
			_prof_end("objective_distance_calculations", t_start)
			_prof_add_count("objective_distance_calls")
			return cached_dist
	var best: int = 999999
	for node in state.resource_nodes:
		if bool(node.get("consumed", false)):
			continue
		best = mini(best, _distance_to_tile(tile, node["pos"]))
	_prof_end("objective_distance_calculations", t_start)
	_prof_add_count("objective_distance_calls")
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
	var t_start: int = _prof_begin()
	var objective_progress_weight: int = _tp_int("objective_progress_weight", OBJECTIVE_PROGRESS_WEIGHT)
	var objective_backfill_penalty: int = _tp_int("objective_backfill_penalty", OBJECTIVE_BACKFILL_PENALTY)
	if baseline_dist >= 99:
		_prof_end("objective_distance_calculations", t_start)
		_prof_add_count("objective_distance_calls")
		return 0
	var candidate_dist: int = _primary_objective_distance(state, owner_id, tile)
	if candidate_dist >= 99:
		_prof_end("objective_distance_calculations", t_start)
		_prof_add_count("objective_distance_calls")
		return 0
	var delta: int = baseline_dist - candidate_dist
	var score: int = delta * objective_progress_weight
	if delta <= 0:
		score -= objective_backfill_penalty
		if stricter_backfill_penalty:
			score -= 10
	_prof_end("objective_distance_calculations", t_start)
	_prof_add_count("objective_distance_calls")
	return score

func _flank_pressure_bonus_score(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	zone: String,
	phase: int,
	support: int,
	nearest_enemy_dist: int,
	adjacent_enemy: int,
	baseline_objective_dist: int
) -> int:
	var t_start: int = _prof_begin()
	var flank_pressure_bonus: int = _tp_int("flank_pressure_bonus", FLANK_PRESSURE_BONUS)
	var flank_stalemate_break_bonus: int = _tp_int("flank_stalemate_break_bonus", FLANK_STALEMATE_BREAK_BONUS)
	var objective_delta: int = _objective_progress_delta_score(state, owner_id, tile, baseline_objective_dist, false)
	var directional_pressure: int = _hostile_directional_presence(state, owner_id, tile, 3)
	var nearby_specialists: int = _nearby_hostile_specialist_count(state, owner_id, tile, 4)
	var open_neighbors: int = _adjacent_open_ground_count(state, tile)
	var stall_level: int = _owner_frontline_stall_level(state, owner_id)
	var score: int = 0

	var flank_window: bool = nearest_enemy_dist >= 2 and nearest_enemy_dist <= 6 and support >= 2
	if zone != "frontline" and flank_window and directional_pressure >= 2:
		score += flank_pressure_bonus
		score += directional_pressure * 3
		score += nearby_specialists * 2
		score += mini(10, open_neighbors * 2)
		if objective_delta > 0:
			score += mini(16, int(round(float(objective_delta) * 0.34)))
	elif zone != "frontline" and flank_window and directional_pressure >= 1 and objective_delta > 0:
		score += int(round(float(flank_pressure_bonus) * 0.55))
		score += mini(8, int(round(float(objective_delta) * 0.24)))

	if stall_level > 0 and zone != "frontline" and flank_window and directional_pressure >= 1:
		score += flank_stalemate_break_bonus * stall_level
	score += _strategy_bias_int("flank_bonus")
	if _strategy_bias_int("breakout_bonus") > 0 and zone != "frontline" and open_neighbors >= 2:
		score += int(round(float(_strategy_bias_int("breakout_bonus")) * 0.5))
	if adjacent_enemy > 0:
		# Direct-contact tiles are frontline pressure points, not flanking lanes.
		score -= maxi(6, int(round(float(flank_pressure_bonus) * 0.4)))
	if support <= 1:
		score -= 18
	if objective_delta <= 0 and directional_pressure <= 1:
		score -= 6
	if phase == PHASE_SAFE_EXPANSION and nearest_enemy_dist >= 7 and objective_delta <= 0:
		score -= 6
	if zone == "backline" and nearest_enemy_dist >= 7:
		score -= 10
	if open_neighbors >= 3 and support <= 2 and nearest_enemy_dist > 3:
		score -= 8
	var ally_penalty_scale: int = 6 + _strategy_bias_int("ally_block_penalty_bonus")
	score -= _adjacent_nonhostile_ally_count(state, owner_id, tile) * ally_penalty_scale
	_prof_end("flank_opening_ally_scoring", t_start)
	_prof_add_count("flank_opening_ally_calls")
	return score

func _basic_claim_opening_score(
	state: GameState,
	owner_id: int,
	tile: Vector2i,
	zone: String,
	phase: int,
	support: int,
	nearest_enemy_dist: int,
	adjacent_enemy: int,
	baseline_objective_dist: int
) -> int:
	var t_start: int = _prof_begin()
	var opening_bonus: int = _tp_int("basic_claim_opening_bonus", BASIC_CLAIM_OPENING_BONUS)
	var goal_bonus: int = _tp_int("basic_claim_goal_bonus", BASIC_CLAIM_GOAL_BONUS)
	var frontline_bonus: int = _tp_int("basic_claim_frontline_bonus", BASIC_CLAIM_FRONTLINE_BONUS)
	var objective_delta: int = _objective_progress_delta_score(state, owner_id, tile, baseline_objective_dist, true)
	var directional_pressure: int = _hostile_directional_presence(state, owner_id, tile, 3)
	var open_neighbors: int = _adjacent_open_ground_count(state, tile)
	var contested: bool = adjacent_enemy > 0 or nearest_enemy_dist <= 3
	var score: int = 0

	if contested:
		score += frontline_bonus
		score += directional_pressure * 3
		if phase == PHASE_ACTIVE_FRONTLINE:
			score += 6
	if open_neighbors >= 2 and (contested or objective_delta > 0 or zone == "second_line"):
		score += opening_bonus + (open_neighbors - 2) * 2
	if objective_delta > 0:
		score += mini(goal_bonus, int(round(float(objective_delta) * 0.40)))
		score += int(round(float(_door_objective_score(state, owner_id, tile) + _heart_objective_score(state, owner_id, tile)) * 0.08))
	if support >= 3:
		score += 4
	if support <= 1:
		score -= 14
		if open_neighbors >= 3:
			score -= 10
	if zone == "backline" and not contested and objective_delta <= 0:
		score -= opening_bonus
	if phase == PHASE_SAFE_EXPANSION and zone == "backline" and nearest_enemy_dist >= 7:
		score -= 6
	score += _strategy_bias_int("opening_claim_bonus")
	if _strategy_bias_int("breakout_bonus") > 0 and open_neighbors >= 2 and zone != "backline":
		score += int(round(float(_strategy_bias_int("breakout_bonus")) * 0.4))
	var ally_penalty_scale: int = 6 + _strategy_bias_int("ally_block_penalty_bonus")
	score -= _adjacent_nonhostile_ally_count(state, owner_id, tile) * ally_penalty_scale
	_prof_end("flank_opening_ally_scoring", t_start)
	_prof_add_count("flank_opening_ally_calls")
	return score

func _owner_frontline_stall_level(state: GameState, owner_id: int) -> int:
	var owner_blocks: Array = state.get_owner_blocks(owner_id)
	if owner_blocks.is_empty():
		return 0
	var frontline_tiles: int = 0
	for block in owner_blocks:
		if _is_frontline_tile(state, owner_id, block["pos"]):
			frontline_tiles += 1
	var objective_dist: int = _owner_objective_frontier_distance(state, owner_id)
	if objective_dist <= 3:
		return 0
	if frontline_tiles >= 6 and objective_dist >= 6:
		return 2
	if frontline_tiles >= 4 and objective_dist >= 4:
		return 1
	return 0

func _hostile_directional_presence(state: GameState, owner_id: int, tile: Vector2i, max_distance: int) -> int:
	var directions_with_hostile: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		for d in range(1, max_distance + 1):
			var check_tile: Vector2i = tile + step * d
			if not state.is_inside(check_tile):
				break
			if state.is_blocked(check_tile):
				break
			var block: Dictionary = state.get_block_at(check_tile)
			if block.is_empty():
				continue
			if state.are_hostile(owner_id, int(block.get("owner", 0))):
				directions_with_hostile += 1
			break
	return directions_with_hostile

func _nearby_hostile_specialist_count(state: GameState, owner_id: int, tile: Vector2i, radius: int) -> int:
	var count: int = 0
	for block in state.blocks.values():
		var other_owner: int = int(block.get("owner", 0))
		if not state.are_hostile(owner_id, other_owner):
			continue
		if _distance_to_tile(tile, block["pos"]) > radius:
			continue
		if bool(block.get("is_heart", false)):
			count += 2
			continue
		if String(block.get("tile_type", "basic")) != "basic":
			count += 1
	return count

func _adjacent_nonhostile_ally_count(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var t_start: int = _prof_begin()
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Dictionary = state.get_block_at(tile + step)
		if neighbor.is_empty():
			continue
		var other_owner: int = int(neighbor.get("owner", 0))
		if other_owner == owner_id:
			continue
		if state.are_hostile(owner_id, other_owner):
			continue
		count += 1
	_prof_end("flank_opening_ally_scoring", t_start)
	_prof_add_count("flank_opening_ally_calls")
	return count

func _owner_objective_frontier_distance(state: GameState, owner_id: int) -> int:
	var t_start: int = _prof_begin()
	if _decision_cache_matches(state, owner_id):
		var cached_frontier: int = int(_decision_objective_cache.get("objective_frontier_distance", 99))
		_prof_end("objective_distance_calculations", t_start)
		_prof_add_count("objective_distance_calls")
		return cached_frontier
	var best: int = 999999
	for block in state.get_owner_blocks(owner_id):
		best = mini(best, _primary_objective_distance(state, owner_id, block["pos"]))
	_prof_end("objective_distance_calculations", t_start)
	_prof_add_count("objective_distance_calls")
	return best if best < 999999 else 99

func _primary_objective_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var t_start: int = _prof_begin()
	if _decision_cache_matches(state, owner_id):
		var primary_distance_map: Dictionary = _decision_objective_cache.get("primary_objective_distance_map", {})
		if primary_distance_map.has(tile):
			var cached_primary_dist: int = int(primary_distance_map.get(tile, 99))
			_prof_end("objective_distance_calculations", t_start)
			_prof_add_count("objective_distance_calls")
			return cached_primary_dist
	var heart_dist: int = _nearest_hostile_heart_distance(state, owner_id, tile)
	if _can_attack_door(state, owner_id) and state.door_hp > 0:
		var door_dist: int = _distance_to_tile(tile, state.door_tile)
		_prof_end("objective_distance_calculations", t_start)
		_prof_add_count("objective_distance_calls")
		return mini(heart_dist, door_dist)
	_prof_end("objective_distance_calculations", t_start)
	_prof_add_count("objective_distance_calls")
	return heart_dist

func _nearest_hostile_heart_distance(state: GameState, owner_id: int, tile: Vector2i) -> int:
	var t_start: int = _prof_begin()
	if _decision_cache_matches(state, owner_id):
		var heart_distance_map: Dictionary = _decision_objective_cache.get("heart_distance_map", {})
		if heart_distance_map.has(tile):
			var cached_heart_dist: int = int(heart_distance_map.get(tile, 99))
			_prof_end("objective_distance_calculations", t_start)
			_prof_add_count("objective_distance_calls")
			return cached_heart_dist
	var best: int = 999999
	for block in state.blocks.values():
		if not bool(block.get("is_heart", false)):
			continue
		if not state.are_hostile(owner_id, int(block["owner"])):
			continue
		best = mini(best, _distance_to_tile(tile, block["pos"]))
	_prof_end("objective_distance_calculations", t_start)
	_prof_add_count("objective_distance_calls")
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

func _has_adjacent_allied_heart(state: GameState, owner_id: int, tile: Vector2i) -> bool:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var target: Dictionary = state.get_block_at(tile + step)
		if target.is_empty():
			continue
		if not bool(target.get("is_heart", false)):
			continue
		var target_owner: int = int(target.get("owner", 0))
		if target_owner == owner_id:
			return true
		if not state.are_hostile(owner_id, target_owner):
			return true
	return false

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

