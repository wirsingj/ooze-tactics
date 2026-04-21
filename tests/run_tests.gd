extends SceneTree

const OOZE_AI_SCRIPT: GDScript = preload("res://scripts/systems/OozeAI.gd")

var failures: Array[String] = []

func _init() -> void:
	_test_determinism()
	_test_economy_math()
	_test_victory_conditions()
	_test_combat_resolution()
	_test_stall_loss()
	_test_blob_growth_rule()
	_test_support_placement_rule()
	_test_corridor_support_relaxation()
	_test_support_and_stability()
	_test_defense_guard_identity()
	_test_ranged_contact_penalty_and_splash_role()
	_test_ooze_ai_frontline_pressure()
	_test_ooze_ai_engaged_upgrade_commitment()
	_test_ooze_ai_avoids_ranged_saturation()
	_test_ooze_ai_objective_upgrade_when_not_engaged()
	_test_ooze_ai_progression_upgrade_when_far()
	_test_ooze_ai_conversion_cooldown()
	_test_ooze_ai_no_duplicate_actions()
	_test_ooze_ai_safe_phase_reduces_melee_spread()
	_test_ooze_ai_safe_phase_uses_gather_on_rear_resources()
	_test_ooze_ai_engaged_safe_backline_gather_conversion_allowed()
	_test_ooze_ai_approaching_phase_allows_safe_backline_gather()
	_test_ooze_ai_frontline_defense_density_brake()
	_test_ooze_ai_safe_backline_downgrade()
	_test_enemy_alignment_no_friendly_fire()
	_test_enemy_alignment_dev_mode_hostility()
	_test_team_color_uniqueness_for_active_owners()
	_test_ooze_ai_side_swap_fairness_smoke()
	_test_true_2v2_team_setup()
	_test_heart_defeat_collapse_and_burst()
	_test_dev_immortal_blocks_damage()
	_test_door_damage_victory_condition()
	_test_turn_limit_loss_condition()
	_test_reclaim_delay_blocks_immediate_rebuild()
	_test_non_basic_conversion_rejected()
	_test_ooze_ai_converts_only_basic()
	_test_specialization_tier_progression_and_cap()
	_test_downgrade_refund_scales_by_tier()
	_test_spectator_stall_ignored()
	_test_spectator_team_loss_condition()
	_test_dev_spectator_disables_turn_limit()
	_test_runflow_upgrade_draw_determinism()
	_test_upgrade_modifiers_affect_combat_economy_and_placement()
	_test_preview_truth_mixed_conflict_and_reclaim()
	_test_team_and_door_policy_matrix()
	_test_spectator_round_order_determinism()
	_test_player_queue_basic_toggle_and_requeue()
	_test_atlas_sprite_contract()
	_test_turn_performance_smoke()

	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		quit(1)

func _test_determinism() -> void:
	var tick: TickSystem = TickSystem.new()
	var a: GameState = _seed_test_state()
	var b: GameState = _seed_test_state()

	for _i in range(5):
		var actions: Array = [
			{"type": "place_tile", "owner": 1, "target": Vector2i(1, 2), "tile_type": "basic", "cost": 1, "min_adjacent": 2},
			{"type": "convert_tile", "owner": 1, "block_id": 2, "to_type": "melee", "energy_delta": 2}
		]
		a = tick.step(a, actions)
		b = tick.step(b, actions)

	_assert(_snapshot(a) == _snapshot(b), "Determinism failed for identical states/actions")

func _test_economy_math() -> void:
	var state: GameState = GameState.new()
	state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	var gather_id: int = state.spawn_block(1, Vector2i(2, 1), false, 8, "gather")
	state.blocks[gather_id]["gather_bonus"] = Economy.GATHER_RESOURCE_BONUS
	state.resource_nodes = [{"pos": Vector2i(2, 1), "kind": "gem", "consumed": true}]

	var eco: Economy = Economy.new()
	var report: Dictionary = eco.compute_income_and_upkeep(state)
	_assert(int(report["income"][1]) == 4, "Expected base(2)+gather(1)+bonus(1)=4 income")

func _test_victory_conditions() -> void:
	var director: LevelDirector = LevelDirector.new()
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 6
	state.door_tile = Vector2i(4, 2)
	state.spawn_block(1, Vector2i(3, 2), true, 20, "basic")
	var out: Dictionary = director.check_victory_or_loss(state)
	_assert(String(out["status"]) == "victory", "No alive enemies should count as victory")

func _test_combat_resolution() -> void:
	var state: GameState = GameState.new()
	state.spawn_block(1, Vector2i(1, 1), true, 20, "basic")
	var melee_id: int = state.spawn_block(1, Vector2i(2, 1), false, 10, "melee")
	state.blocks[melee_id]["damage"] = 3

	state.add_owner(2, "Enemy", 10)
	var enemy_id: int = state.spawn_block(2, Vector2i(3, 1), true, 10, "basic")

	var combat: Combat = Combat.new()
	var _log: Array[String] = combat.resolve([], state)
	_assert(int(state.blocks[enemy_id]["hp"]) < 10, "Melee tile should damage adjacent enemy")

func _test_stall_loss() -> void:
	var state: GameState = GameState.new()
	state.width = 4
	state.height = 4
	state.set_walls([[0,0],[0,1],[0,2],[0,3],[1,0],[1,2],[1,3],[2,0],[2,1],[2,2],[2,3],[3,0],[3,1],[3,2],[3,3]])
	state.spawn_block(1, Vector2i(1, 1), true, 20, "basic")
	state.add_owner(2, "Enemy", 5)
	state.spawn_block(2, Vector2i(0, 0), true, 8, "basic")
	state.players[1]["nutrients"] = -3
	state.stall_counter = 2

	var tick: TickSystem = TickSystem.new()
	var next: GameState = tick.step(state, [])
	var result: Dictionary = LevelDirector.new().check_victory_or_loss(next)
	_assert(String(result["status"]) == "loss", "Third stalled tick should fail run")

func _test_blob_growth_rule() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 6
	state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	state.spawn_block(1, Vector2i(2, 1), false, 8, "basic")
	state.players[1]["nutrients"] = 10

	var combat: Combat = Combat.new()
	var before: int = state.blocks.size()
	combat.resolve([
		{"type": "place_tile", "owner": 1, "target": Vector2i(3, 1), "tile_type": "basic", "cost": 1, "min_adjacent": 2}
	], state)
	_assert(state.blocks.size() == before, "Tile with only one adjacent ally should be rejected")

func _test_support_placement_rule() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	state.spawn_block(1, Vector2i(2, 1), false, 8, "basic")
	state.spawn_block(1, Vector2i(1, 2), false, 8, "basic")
	state.spawn_block(1, Vector2i(2, 2), false, 8, "basic")

	_assert(
		state.has_any_legal_action(1, 1, 1),
		"2x2 start should always have at least one legal growth action"
	)

	var combat: Combat = Combat.new()
	var before: int = state.blocks.size()
	var unsupported_check: Dictionary = state.evaluate_growth_target(1, Vector2i(4, 1), 1, {"3,1": true})
	_assert(
		String(unsupported_check.get("reason", "")).begins_with("needs more support"),
		"Insufficient local support should report 'needs more support'"
	)

	combat.resolve([
		{
			"type": "place_tile",
			"owner": 1,
			"target": Vector2i(3, 1),
			"tile_type": "basic",
			"cost": 1,
			"min_adjacent": 1
		},
		{
			"type": "place_tile",
			"owner": 1,
			"target": Vector2i(4, 1),
			"tile_type": "basic",
			"cost": 1,
			"min_adjacent": 1
		}
	], state)

	_assert(
		state.blocks.size() == before + 1,
		"Thin extension without enough local support should be rejected"
	)

func _test_corridor_support_relaxation() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.set_walls([[2, 3], [4, 3]])
	state.spawn_block(1, Vector2i(3, 2), true, 8, "basic")
	state.spawn_block(1, Vector2i(3, 1), false, 8, "basic")

	var corridor_tile: Vector2i = Vector2i(3, 3)
	_assert(state.is_narrow_corridor_tile(corridor_tile), "Corridor tile should be detected when 2+ sides are impassable")
	_assert(
		state.support_required_for_tile(corridor_tile) == GameState.MIN_SUPPORT_FOR_PLACEMENT - GameState.CORRIDOR_SUPPORT_DISCOUNT,
		"Corridor support threshold should be reduced by one"
	)

	var validator: ActionValidator = ActionValidator.new()
	var plan: Dictionary = validator.build_owner_plan(state, [], 1)
	var queue_check: Dictionary = validator.validate_place_target(state, 1, corridor_tile, "basic", 1, 1, plan)
	_assert(bool(queue_check.get("ok", false)), "Queue validation should allow corridor growth with reduced support threshold")

	var combat: Combat = Combat.new()
	var before: int = state.blocks.size()
	combat.resolve([{
		"type": "place_tile",
		"owner": 1,
		"target": corridor_tile,
		"tile_type": "basic",
		"cost": 1,
		"min_adjacent": 1
	}], state)
	_assert(state.blocks.size() == before + 1, "Final resolution should apply valid corridor growth")

	var open_state: GameState = GameState.new()
	open_state.width = 10
	open_state.height = 8
	open_state.players[1]["nutrients"] = 20
	open_state.spawn_block(1, Vector2i(6, 2), true, 8, "basic")
	open_state.spawn_block(1, Vector2i(6, 1), false, 8, "basic")

	var open_tile: Vector2i = Vector2i(6, 3)
	_assert(not open_state.is_narrow_corridor_tile(open_tile), "Open tile should not be treated as a corridor")
	var open_check: Dictionary = open_state.evaluate_growth_target(1, open_tile, 1, {})
	_assert(not bool(open_check.get("ok", false)), "Open-area growth should keep full support requirement")
	_assert(
		String(open_check.get("reason", "")).begins_with("needs more support"),
		"Open-area rejection should still use support failure reason"
	)

func _test_support_and_stability() -> void:
	var state_a: GameState = GameState.new()
	state_a.width = 8
	state_a.height = 8
	state_a.add_owner(2, "Enemy", 10)
	var core_a: int = state_a.spawn_block(1, Vector2i(2, 2), true, 9, "basic")
	state_a.blocks[core_a]["age"] = 0
	var attacker_a: int = state_a.spawn_block(2, Vector2i(3, 2), true, 10, "melee")
	state_a.blocks[attacker_a]["damage"] = 2
	var hp_before_a: int = int(state_a.blocks[core_a]["hp"])
	Combat.new().resolve([], state_a)
	var hp_after_a: int = int(state_a.blocks[core_a]["hp"])

	var state_b: GameState = GameState.new()
	state_b.width = 8
	state_b.height = 8
	state_b.add_owner(2, "Enemy", 10)
	var core_b: int = state_b.spawn_block(1, Vector2i(2, 2), true, 9, "basic")
	state_b.blocks[core_b]["age"] = 2
	state_b.spawn_block(1, Vector2i(1, 2), false, 9, "basic")
	state_b.spawn_block(1, Vector2i(2, 1), false, 9, "basic")
	state_b.spawn_block(1, Vector2i(1, 1), false, 9, "basic")
	var attacker_b: int = state_b.spawn_block(2, Vector2i(3, 2), true, 10, "melee")
	state_b.blocks[attacker_b]["damage"] = 2
	var hp_before_b: int = int(state_b.blocks[core_b]["hp"])
	Combat.new().resolve([], state_b)
	var hp_after_b: int = int(state_b.blocks[core_b]["hp"])

	var damage_a: int = hp_before_a - hp_after_a
	var damage_b: int = hp_before_b - hp_after_b
	_assert(damage_b < damage_a, "Supported reinforced tiles should take less damage than fragile unsupported tiles")

func _test_defense_guard_identity() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.add_owner(2, "Enemy", 10)

	var defended_id: int = state.spawn_block(1, Vector2i(2, 2), true, 9, "basic")
	state.blocks[defended_id]["age"] = 1
	var defender_id: int = state.spawn_block(1, Vector2i(2, 3), false, 18, "defense")
	state.blocks[defender_id]["tile_type"] = "defense"
	state.blocks[defender_id]["defense"] = int(Combat.TILE_RULES["defense"]["defense"])
	state.blocks[defender_id]["age"] = 1
	var attacker: int = state.spawn_block(2, Vector2i(3, 2), true, 10, "melee")
	state.blocks[attacker]["damage"] = 2

	var hp_before_defended: int = int(state.blocks[defended_id]["hp"])
	Combat.new().resolve([], state)
	var hp_after_defended: int = int(state.blocks[defended_id]["hp"])
	var guarded_damage: int = hp_before_defended - hp_after_defended

	var state_no_guard: GameState = GameState.new()
	state_no_guard.width = 8
	state_no_guard.height = 8
	state_no_guard.add_owner(2, "Enemy", 10)
	var target_id: int = state_no_guard.spawn_block(1, Vector2i(2, 2), true, 9, "basic")
	state_no_guard.blocks[target_id]["age"] = 1
	var attacker_2: int = state_no_guard.spawn_block(2, Vector2i(3, 2), true, 10, "melee")
	state_no_guard.blocks[attacker_2]["damage"] = 2
	var hp_before_plain: int = int(state_no_guard.blocks[target_id]["hp"])
	Combat.new().resolve([], state_no_guard)
	var hp_after_plain: int = int(state_no_guard.blocks[target_id]["hp"])
	var plain_damage: int = hp_before_plain - hp_after_plain

	_assert(guarded_damage < plain_damage, "Adjacent defense tile should guard allied frontline tiles")

func _test_ranged_contact_penalty_and_splash_role() -> void:
	var contact_state: GameState = GameState.new()
	contact_state.width = 10
	contact_state.height = 8
	contact_state.add_owner(2, "Enemy", 10)
	var contact_ranged: int = contact_state.spawn_block(1, Vector2i(3, 3), true, int(Combat.TILE_RULES["ranged"]["max_hp"]), "ranged")
	_set_ranged_stats(contact_state, contact_ranged)
	var contact_primary: int = contact_state.spawn_block(2, Vector2i(4, 3), true, 9, "basic")
	var contact_neighbor: int = contact_state.spawn_block(2, Vector2i(4, 4), false, 9, "basic")
	var contact_primary_before: int = int(contact_state.blocks[contact_primary]["hp"])
	var contact_neighbor_before: int = int(contact_state.blocks[contact_neighbor]["hp"])
	Combat.new().resolve([], contact_state)
	var contact_primary_after: int = int(contact_state.blocks[contact_primary]["hp"])
	var contact_neighbor_after: int = int(contact_state.blocks[contact_neighbor]["hp"])
	_assert(contact_primary_after < contact_primary_before, "Ranged should still deal direct damage while in contact")
	_assert(contact_neighbor_after == contact_neighbor_before, "Ranged splash should be disabled while shooter is in direct contact")

	var backline_state: GameState = GameState.new()
	backline_state.width = 12
	backline_state.height = 8
	backline_state.add_owner(2, "Enemy", 10)
	var backline_ranged: int = backline_state.spawn_block(1, Vector2i(2, 3), true, int(Combat.TILE_RULES["ranged"]["max_hp"]), "ranged")
	_set_ranged_stats(backline_state, backline_ranged)
	var backline_primary: int = backline_state.spawn_block(2, Vector2i(5, 3), true, 9, "basic")
	var backline_neighbor: int = backline_state.spawn_block(2, Vector2i(5, 4), false, 9, "basic")
	var backline_primary_before: int = int(backline_state.blocks[backline_primary]["hp"])
	var backline_neighbor_before: int = int(backline_state.blocks[backline_neighbor]["hp"])
	Combat.new().resolve([], backline_state)
	var backline_primary_after: int = int(backline_state.blocks[backline_primary]["hp"])
	var backline_neighbor_after: int = int(backline_state.blocks[backline_neighbor]["hp"])
	_assert(backline_primary_after < backline_primary_before, "Backline ranged should damage primary target")
	_assert(backline_neighbor_after < backline_neighbor_before, "Backline ranged should still apply splash pressure")

func _test_ooze_ai_frontline_pressure() -> void:
	var state: GameState = GameState.new()
	state.width = 12
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(3, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(4, 4), false, 9, "basic")

	state.add_owner(2, "Enemy", 20)
	state.spawn_block(2, Vector2i(7, 4), true, 9, "basic")
	state.spawn_block(2, Vector2i(6, 4), false, 9, "basic")
	state.spawn_block(2, Vector2i(6, 3), false, 9, "basic")

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)

	var has_frontline_investment: bool = false
	for action in actions:
		if _is_frontline_action(state, 2, action):
			has_frontline_investment = true
			break

	_assert(has_frontline_investment, "Ooze AI should make at least one frontline action when possible")

func _test_ooze_ai_engaged_upgrade_commitment() -> void:
	var state: GameState = GameState.new()
	state.width = 14
	state.height = 9
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(5, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(4, 4), false, 9, "basic")
	state.spawn_block(1, Vector2i(4, 3), false, 9, "basic")

	state.add_owner(2, "Enemy", 30)
	var enemy_core: int = state.spawn_block(2, Vector2i(8, 4), true, 9, "basic")
	var enemy_frontline: int = state.spawn_block(2, Vector2i(6, 4), false, 9, "basic")
	var enemy_second_line: int = state.spawn_block(2, Vector2i(7, 4), false, 9, "basic")
	state.blocks[enemy_core]["last_converted_turn"] = -999999
	state.blocks[enemy_frontline]["last_converted_turn"] = -999999
	state.blocks[enemy_second_line]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	_assert(actions.size() > 0, "Engaged enemy should produce actions")

	var first_kind: String = String(actions[0].get("type", ""))
	_assert(first_kind == "convert_tile", "Engaged AI should prioritize conversion/upgrade before spread")

	var has_frontline_upgrade: bool = false
	var has_second_line_ranged: bool = false
	for action in actions:
		if String(action.get("type", "")) != "convert_tile":
			continue
		var block_id: int = int(action.get("block_id", -1))
		if block_id < 0 or not state.blocks.has(block_id):
			continue
		var tile: Vector2i = state.blocks[block_id]["pos"]
		if ai._is_frontline_tile(state, 2, tile):
			has_frontline_upgrade = true
		if ai._is_second_line_tile(state, 2, tile) and String(action.get("to_type", "")) == "ranged":
			has_second_line_ranged = true

	_assert(has_frontline_upgrade, "Engaged AI should commit at least one frontline upgrade when affordable")
	_assert(has_second_line_ranged, "Engaged AI should prefer second-line ranged support upgrades")

func _test_ooze_ai_avoids_ranged_saturation() -> void:
	var state: GameState = GameState.new()
	state.width = 16
	state.height = 10
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(5, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(5, 5), false, 9, "basic")
	state.spawn_block(1, Vector2i(6, 4), false, 9, "basic")

	state.add_owner(2, "Enemy", 40)
	var frontline_basic: int = state.spawn_block(2, Vector2i(7, 4), true, 9, "basic")
	var second_line_basic: int = state.spawn_block(2, Vector2i(8, 4), false, 9, "basic")
	state.blocks[frontline_basic]["last_converted_turn"] = -999999
	state.blocks[second_line_basic]["last_converted_turn"] = -999999
	var ranged_tiles: Array[Vector2i] = [
		Vector2i(9, 3), Vector2i(9, 4), Vector2i(9, 5),
		Vector2i(10, 3), Vector2i(10, 4), Vector2i(10, 5),
	]
	for tile in ranged_tiles:
		state.spawn_block(2, tile, false, int(Combat.TILE_RULES["ranged"]["max_hp"]), "ranged")

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var has_non_ranged_upgrade: bool = false
	for action in actions:
		if String(action.get("type", "")) != "convert_tile":
			continue
		var to_type: String = String(action.get("to_type", ""))
		_assert(to_type != "ranged", "AI should avoid adding more ranged while already ranged-saturated")
		if to_type == "defense" or to_type == "melee":
			has_non_ranged_upgrade = true
	_assert(has_non_ranged_upgrade, "AI should still commit meaningful non-ranged upgrades when saturated")

func _test_ooze_ai_objective_upgrade_when_not_engaged() -> void:
	var state: GameState = GameState.new()
	state.width = 18
	state.height = 9
	state.door_tile = Vector2i(16, 4)
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(4, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(3, 4), false, 9, "basic")

	state.add_owner(2, "Enemy", 30, GameState.TEAM_ENEMY, true)
	var enemy_core: int = state.spawn_block(2, Vector2i(11, 4), true, 9, "basic")
	state.blocks[enemy_core]["last_converted_turn"] = -999999
	var enemy_backline: int = state.spawn_block(2, Vector2i(12, 4), false, 9, "basic")
	state.blocks[enemy_backline]["last_converted_turn"] = -999999
	var enemy_backline_2: int = state.spawn_block(2, Vector2i(12, 3), false, 9, "basic")
	state.blocks[enemy_backline_2]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var has_upgrade: bool = false
	for action in actions:
		if String(action.get("type", "")) == "convert_tile":
			has_upgrade = true
			break
	_assert(has_upgrade, "Non-engaged AI should still perform objective-facing upgrades instead of only basic spread")

func _test_ooze_ai_progression_upgrade_when_far() -> void:
	var state: GameState = GameState.new()
	state.width = 34
	state.height = 12
	state.door_tile = Vector2i(31, 6)
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(2, 6), true, 9, "basic")
	state.spawn_block(1, Vector2i(3, 6), false, 9, "basic")

	state.add_owner(2, "Enemy", 30, GameState.TEAM_ENEMY, true)
	var enemy_core: int = state.spawn_block(2, Vector2i(28, 6), true, 9, "basic")
	var edge_a: int = state.spawn_block(2, Vector2i(27, 6), false, 9, "basic")
	var edge_b: int = state.spawn_block(2, Vector2i(28, 5), false, 9, "basic")
	var edge_c: int = state.spawn_block(2, Vector2i(28, 7), false, 9, "basic")
	state.blocks[enemy_core]["last_converted_turn"] = -999999
	state.blocks[edge_a]["last_converted_turn"] = -999999
	state.blocks[edge_b]["last_converted_turn"] = -999999
	state.blocks[edge_c]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var has_progress_plan: bool = false
	for action in actions:
		var kind: String = String(action.get("type", ""))
		if kind == "convert_tile":
			has_progress_plan = true
			break
		if kind == "place_tile":
			var tile_type: String = String(action.get("tile_type", "basic"))
			if tile_type != "gather":
				has_progress_plan = true
				break
	_assert(has_progress_plan, "Far non-engaged AI should still include objective-pressure actions, not only passive economy")

func _test_ooze_ai_conversion_cooldown() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(3, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(4, 4), false, 9, "basic")

	state.add_owner(2, "Enemy", 20)
	state.turn_index = 10
	var enemy_core: int = state.spawn_block(2, Vector2i(6, 4), true, 9, "basic")
	var enemy_front: int = state.spawn_block(2, Vector2i(5, 4), false, 9, "basic")
	state.blocks[enemy_front]["last_converted_turn"] = 9
	state.blocks[enemy_core]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	for action in actions:
		if String(action.get("type", "")) != "convert_tile":
			continue
		_assert(
			int(action.get("block_id", -1)) != enemy_front,
			"Ooze AI should not reconvert a tile inside conversion cooldown window"
		)

func _test_ooze_ai_no_duplicate_actions() -> void:
	var state: GameState = GameState.new()
	state.width = 14
	state.height = 10
	state.players[1]["nutrients"] = 30
	state.spawn_block(1, Vector2i(4, 5), true, 9, "basic")
	state.spawn_block(1, Vector2i(5, 5), false, 9, "basic")
	state.spawn_block(1, Vector2i(6, 5), false, 9, "basic")

	state.add_owner(2, "Enemy", 30)
	state.spawn_block(2, Vector2i(9, 5), true, 9, "basic")
	state.spawn_block(2, Vector2i(8, 5), false, 9, "basic")
	state.spawn_block(2, Vector2i(8, 4), false, 9, "basic")
	state.spawn_block(2, Vector2i(8, 6), false, 9, "basic")

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var seen_targets: Dictionary = {}
	var seen_blocks: Dictionary = {}

	for action in actions:
		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			var key: String = "%s" % [action.get("target", Vector2i(-1, -1))]
			_assert(not seen_targets.has(key), "Ooze AI should not place on the same tile twice in one turn")
			seen_targets[key] = true
		elif kind == "convert_tile":
			var block_id: int = int(action.get("block_id", -1))
			_assert(not seen_blocks.has(block_id), "Ooze AI should not convert the same block twice in one turn")
			seen_blocks[block_id] = true

func _test_ooze_ai_safe_phase_reduces_melee_spread() -> void:
	var state: GameState = GameState.new()
	state.width = 24
	state.height = 10
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(2, 5), true, 9, "basic")
	state.spawn_block(1, Vector2i(3, 5), false, 9, "basic")

	state.add_owner(2, "Enemy", 16)
	state.spawn_block(2, Vector2i(20, 5), true, 9, "basic")
	state.spawn_block(2, Vector2i(19, 5), false, 9, "basic")
	state.spawn_block(2, Vector2i(19, 4), false, 9, "basic")
	state.resource_nodes = [{"pos": Vector2i(18, 5), "kind": "gem", "consumed": false}]

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var melee_count: int = 0
	var has_growth: bool = false
	for action in actions:
		var kind: String = String(action.get("type", ""))
		if kind == "place_tile":
			var tile_type: String = String(action.get("tile_type", "basic"))
			if tile_type == "melee":
				melee_count += 1
			if tile_type == "basic" or tile_type == "gather":
				has_growth = true
		elif kind == "convert_tile":
			if String(action.get("to_type", "")) == "melee":
				melee_count += 1
	_assert(melee_count == 0, "Safe expansion should not default into early melee investment")
	_assert(has_growth, "Safe expansion should still produce basic/gather growth actions")

func _test_ooze_ai_safe_phase_uses_gather_on_rear_resources() -> void:
	var state: GameState = GameState.new()
	state.width = 20
	state.height = 10
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(2, 5), true, 9, "basic")
	state.spawn_block(1, Vector2i(3, 5), false, 9, "basic")

	state.add_owner(2, "Enemy", 16)
	state.spawn_block(2, Vector2i(16, 5), true, 9, "basic")
	state.spawn_block(2, Vector2i(15, 5), false, 9, "basic")
	state.spawn_block(2, Vector2i(15, 4), false, 9, "basic")
	state.resource_nodes = [
		{"pos": Vector2i(14, 5), "kind": "gem", "consumed": false},
		{"pos": Vector2i(14, 4), "kind": "gem", "consumed": false}
	]

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var has_gather: bool = false
	for action in actions:
		if String(action.get("type", "")) == "place_tile" and String(action.get("tile_type", "")) == "gather":
			has_gather = true
			break
		if String(action.get("type", "")) == "convert_tile" and String(action.get("to_type", "")) == "gather":
			has_gather = true
			break
	_assert(has_gather, "Safe rear resource zones should produce at least one gather-focused AI action")

func _test_ooze_ai_engaged_safe_backline_gather_conversion_allowed() -> void:
	var state: GameState = GameState.new()
	state.width = 24
	state.height = 10
	state.players[2] = {"name": "Enemy", "nutrients": 20, "alive": true, "ai_controlled": true, "is_player": false}
	state.players[2]["team"] = GameState.TEAM_ENEMY
	state.players[1]["nutrients"] = 20

	# Enemy (owner 2) is engaged on the frontline near x=13/12...
	state.spawn_block(2, Vector2i(16, 5), true, 9, "basic")
	state.spawn_block(2, Vector2i(15, 5), false, 9, "basic")
	state.spawn_block(2, Vector2i(14, 5), false, 9, "basic")
	state.spawn_block(2, Vector2i(13, 5), false, 9, "basic")

	# ...while also owning a safe backline basic tile on an open resource.
	var backline_resource_tile: Vector2i = Vector2i(18, 5)
	var backline_basic: int = state.spawn_block(2, backline_resource_tile, false, 9, "basic")
	state.spawn_block(2, Vector2i(18, 4), false, 9, "basic")
	state.spawn_block(2, Vector2i(17, 5), false, 9, "basic")

	state.spawn_block(1, Vector2i(12, 5), true, 9, "basic")
	state.spawn_block(1, Vector2i(11, 5), false, 9, "basic")
	state.spawn_block(1, Vector2i(11, 4), false, 9, "basic")

	state.resource_nodes = [
		{"pos": backline_resource_tile, "kind": "gem", "consumed": false}
	]

	var ai = OOZE_AI_SCRIPT.new()
	var nearest_enemy_dist: int = ai._nearest_enemy_distance(state, 2, backline_resource_tile)
	var prefers_conversion: bool = ai._should_prefer_gather_conversion(
		state,
		2,
		backline_resource_tile,
		nearest_enemy_dist,
		true
	)
	_assert(
		prefers_conversion,
		"Engaged AI should still allow safe backline gather conversion on open resources when local tile is low-threat"
	)
	_assert(int(state.blocks[backline_basic]["owner"]) == 2, "Sanity check: backline resource tile should be owned by AI under test")

func _test_ooze_ai_approaching_phase_allows_safe_backline_gather() -> void:
	var state: GameState = GameState.new()
	state.width = 24
	state.height = 10
	state.players[1]["nutrients"] = 20
	state.players[2] = {"name": "Enemy", "nutrients": 20, "alive": true, "ai_controlled": true, "is_player": false, "team": GameState.TEAM_ENEMY}

	# Build a lane with contact at x=10/9 so owner 2 is engaged, but keep a deep backline tile at x=13.
	state.spawn_block(2, Vector2i(10, 5), true, 9, "basic")
	state.spawn_block(2, Vector2i(11, 5), false, 9, "basic")
	state.spawn_block(2, Vector2i(12, 5), false, 9, "basic")
	state.spawn_block(1, Vector2i(9, 5), true, 9, "basic")
	state.spawn_block(1, Vector2i(8, 5), false, 9, "basic")

	var ai = OOZE_AI_SCRIPT.new()
	var candidate_tile: Vector2i = Vector2i(13, 5)
	var nearest_enemy_dist: int = ai._nearest_enemy_distance(state, 2, candidate_tile)
	var phase: int = ai._local_threat_phase(state, 2, candidate_tile, nearest_enemy_dist, ai._adjacent_enemy_count(state, 2, candidate_tile))
	_assert(phase == ai.PHASE_APPROACHING_CONTACT, "Backline tile in this setup should be classified as APPROACHING_CONTACT")
	_assert(
		ai._is_gather_position_allowed(state, 2, candidate_tile, nearest_enemy_dist, phase),
		"APPROACHING_CONTACT should allow gather on safe deep-backline tiles"
	)

func _test_ooze_ai_frontline_defense_density_brake() -> void:
	var state: GameState = GameState.new()
	state.width = 14
	state.height = 9
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(5, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(6, 4), false, 9, "basic")
	state.spawn_block(1, Vector2i(6, 3), false, 9, "basic")

	state.add_owner(2, "Enemy", 32)
	state.spawn_block(2, Vector2i(9, 4), true, 9, "basic")
	var frontline_a: int = state.spawn_block(2, Vector2i(8, 4), false, 9, "basic")
	var frontline_b: int = state.spawn_block(2, Vector2i(8, 3), false, 9, "basic")
	var dense_def_a: int = state.spawn_block(2, Vector2i(9, 3), false, int(Combat.TILE_RULES["defense"]["max_hp"]), "defense")
	var dense_def_b: int = state.spawn_block(2, Vector2i(9, 5), false, int(Combat.TILE_RULES["defense"]["max_hp"]), "defense")
	state.blocks[frontline_a]["last_converted_turn"] = -999999
	state.blocks[frontline_b]["last_converted_turn"] = -999999
	state.blocks[dense_def_a]["last_converted_turn"] = -999999
	state.blocks[dense_def_b]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var defense_actions: int = 0
	var has_non_defense_combat: bool = false
	for action in actions:
		var kind: String = String(action.get("type", ""))
		if kind == "place_tile":
			var tile_type: String = String(action.get("tile_type", "basic"))
			if tile_type == "defense":
				defense_actions += 1
			if tile_type == "melee" or tile_type == "ranged":
				has_non_defense_combat = true
		elif kind == "convert_tile":
			var to_type: String = String(action.get("to_type", "basic"))
			if to_type == "defense":
				defense_actions += 1
			if to_type == "melee" or to_type == "ranged":
				has_non_defense_combat = true
	_assert(defense_actions <= 1, "Active fronts should not stack defense actions when local lane already has holders")
	_assert(has_non_defense_combat, "Active fronts should keep melee/ranged pressure roles available")

func _test_enemy_alignment_no_friendly_fire() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.players[1]["nutrients"] = 10
	var player_core: int = state.spawn_block(1, Vector2i(1, 1), true, 9, "basic")
	state.blocks[player_core]["is_heart"] = true

	state.add_owner(2, "Enemy A", 10)
	state.add_owner(3, "Enemy B", 10)
	var enemy_a: int = state.spawn_block(2, Vector2i(3, 3), true, 9, "melee")
	state.blocks[enemy_a]["tile_type"] = "melee"
	state.blocks[enemy_a]["damage"] = 3
	state.blocks[enemy_a]["is_heart"] = true
	var enemy_b: int = state.spawn_block(3, Vector2i(4, 3), true, 9, "basic")
	state.blocks[enemy_b]["is_heart"] = true

	var hp_before_b: int = int(state.blocks[enemy_b]["hp"])
	Combat.new().resolve([], state)
	var hp_after_b: int = int(state.blocks[enemy_b]["hp"])

	_assert(hp_before_b == hp_after_b, "Enemy owners should be allied and not damage each other")

func _test_enemy_alignment_dev_mode_hostility() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.enemies_allied = false
	state.add_owner(2, "Enemy A", 10)
	state.add_owner(3, "Enemy B", 10)

	var enemy_a: int = state.spawn_block(2, Vector2i(3, 3), true, 9, "melee")
	state.blocks[enemy_a]["tile_type"] = "melee"
	state.blocks[enemy_a]["damage"] = 3
	var enemy_b: int = state.spawn_block(3, Vector2i(4, 3), true, 9, "basic")

	var hp_before_b: int = int(state.blocks[enemy_b]["hp"])
	Combat.new().resolve([], state)
	var hp_after_b: int = int(state.blocks[enemy_b]["hp"])

	_assert(hp_after_b < hp_before_b, "When enemies are not allied, enemy factions should be hostile")

func _test_true_2v2_team_setup() -> void:
	var generator: LevelGenerator = LevelGenerator.new()
	var room_templates: Array = [
		{
			"id": "tiny",
			"width": 20,
			"height": 14,
			"player_seed": [3, 7],
			"door": [17, 7],
			"walls": [],
			"resource_nodes": [],
			"enemies": [{"owner": 2, "seed": [14, 5]}, {"owner": 3, "seed": [14, 9]}]
		}
	]
	var state: GameState = generator.build_level(2, 1234, room_templates, [], {
		"player_cluster_count": 1,
		"ally_ai_count": 1,
		"enemy_cluster_count": 2,
		"player_start_energy": 12,
		"ally_start_energy": 12,
		"enemy_start_energy": 10,
		"enemies_allied": true,
		"turn_limit": 50,
		"door_hp": 30,
	})

	var ally_owner: int = -1
	var enemy_owners: Array[int] = []
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID:
			continue
		var team: int = int(state.players[owner_id]["team"])
		if team == GameState.TEAM_PLAYER:
			ally_owner = owner_id
		else:
			enemy_owners.append(owner_id)

	_assert(ally_owner > 0, "Level 2 should include a separate allied AI owner on the player team")
	_assert(enemy_owners.size() == 2, "Level 2 should include two enemy owners")
	_assert(not state.are_hostile(GameState.PLAYER_ID, ally_owner), "Player and allied AI should not be hostile")
	_assert(state.are_hostile(GameState.PLAYER_ID, enemy_owners[0]), "Player should be hostile to enemy team")
	_assert(not state.are_hostile(enemy_owners[0], enemy_owners[1]), "Enemy owners should be allied with each other in normal mode")

func _test_heart_defeat_collapse_and_burst() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.players[1]["nutrients"] = 5

	var player_core: int = state.spawn_block(1, Vector2i(1, 1), true, 9, "basic")
	state.blocks[player_core]["is_heart"] = true
	var striker: int = state.spawn_block(1, Vector2i(2, 3), false, 10, "melee")
	state.blocks[striker]["tile_type"] = "melee"
	state.blocks[striker]["damage"] = 4

	state.add_owner(2, "Enemy", 10)
	var enemy_heart: int = state.spawn_block(2, Vector2i(3, 3), true, 5, "basic")
	state.blocks[enemy_heart]["is_heart"] = true
	state.blocks[enemy_heart]["hp"] = 1
	var enemy_extra: int = state.spawn_block(2, Vector2i(3, 4), false, 9, "basic")
	state.blocks[enemy_extra]["is_heart"] = false

	var energy_before: int = int(state.players[1]["nutrients"])
	Combat.new().resolve([], state)

	_assert(state.get_owner_blocks(2).is_empty(), "All tiles of defeated owner should collapse when hearts are gone")
	_assert(
		int(state.players[1]["nutrients"]) == energy_before + Combat.HEART_DEFEAT_BURST_ENERGY,
		"Player should receive burst energy when defeating an enemy heart cluster"
	)

func _test_door_damage_victory_condition() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.turn_limit = 50
	state.door_tile = Vector2i(5, 4)
	state.door_max_hp = 6
	state.door_hp = 2
	var shooter: int = state.spawn_block(1, Vector2i(3, 4), true, 8, "ranged")
	state.blocks[shooter]["tile_type"] = "ranged"
	state.blocks[shooter]["damage"] = 2
	state.blocks[shooter]["range"] = 4

	Combat.new().resolve([], state)
	var out: Dictionary = LevelDirector.new().check_victory_or_loss(state)
	_assert(state.door_hp <= 0, "Ranged player tile should damage the door objective")
	_assert(String(out["status"]) == "victory", "Destroying the door should trigger victory")

func _test_dev_immortal_blocks_damage() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.dev_player_immortal = true
	state.add_owner(2, "Enemy", 10)
	var player_id: int = state.spawn_block(1, Vector2i(3, 3), true, 9, "basic")
	var enemy_melee: int = state.spawn_block(2, Vector2i(4, 3), true, 10, "melee")
	state.blocks[enemy_melee]["tile_type"] = "melee"
	state.blocks[enemy_melee]["damage"] = 6

	var hp_before: int = int(state.blocks[player_id]["hp"])
	Combat.new().resolve([], state)
	var hp_after: int = int(state.blocks[player_id]["hp"])
	_assert(hp_after == hp_before, "Dev immortal mode should prevent player block damage")

func _test_turn_limit_loss_condition() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.turn_limit = 10
	state.turn_index = 10
	state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	state.add_owner(2, "Enemy", 5)
	var enemy_heart: int = state.spawn_block(2, Vector2i(6, 6), true, 8, "basic")
	state.blocks[enemy_heart]["is_heart"] = true

	var out: Dictionary = LevelDirector.new().check_victory_or_loss(state)
	_assert(String(out["status"]) == "loss", "Turn limit should trigger a loss when reached")

func _test_reclaim_delay_blocks_immediate_rebuild() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(1, 2), true, 9, "basic")
	var ally_a: int = state.spawn_block(1, Vector2i(2, 2), false, 10, "melee")
	state.blocks[ally_a]["tile_type"] = "melee"
	state.blocks[ally_a]["damage"] = 5
	state.spawn_block(1, Vector2i(1, 1), false, 9, "basic")
	state.spawn_block(1, Vector2i(1, 3), false, 9, "basic")
	state.spawn_block(1, Vector2i(2, 1), false, 9, "basic")

	state.add_owner(2, "Enemy", 10)
	var enemy_id: int = state.spawn_block(2, Vector2i(3, 2), true, 9, "basic")
	state.blocks[enemy_id]["hp"] = 1
	state.blocks[enemy_id]["is_heart"] = false

	var tick: TickSystem = TickSystem.new()
	var after_kill: GameState = tick.step(state, [])
	var rebuild_tile: Vector2i = Vector2i(3, 2)
	_assert(after_kill.is_reclaim_blocked(rebuild_tile), "Destroyed tiles should be reclaim-blocked for one turn")

	var place_action: Array = [{
		"type": "place_tile",
		"owner": 1,
		"target": rebuild_tile,
		"tile_type": "basic",
		"cost": 1,
		"min_adjacent": 1
	}]

	var blocked_turn: GameState = tick.step(after_kill, place_action)
	_assert(blocked_turn.get_block_at(rebuild_tile).is_empty(), "Immediate rebuild should be blocked by reclaim delay")

	var reopened_turn: GameState = tick.step(blocked_turn, place_action)
	var rebuilt: Dictionary = reopened_turn.get_block_at(rebuild_tile)
	_assert(not rebuilt.is_empty() and int(rebuilt.get("owner", 0)) == 1, "Reclaim tile should reopen after one full turn")

func _test_non_basic_conversion_rejected() -> void:
	var state: GameState = GameState.new()
	state.width = 8
	state.height = 8
	state.players[1]["nutrients"] = 20
	var block_id: int = state.spawn_block(1, Vector2i(2, 2), true, 10, "melee")
	state.blocks[block_id]["tile_type"] = "melee"
	state.blocks[block_id]["damage"] = int(Combat.TILE_RULES["melee"]["damage"])
	state.blocks[block_id]["defense"] = int(Combat.TILE_RULES["melee"]["defense"])

	var action: Dictionary = {
		"type": "convert_tile",
		"owner": 1,
		"block_id": block_id,
		"to_type": "ranged",
		"energy_delta": Combat.conversion_energy_delta("melee", "ranged"),
	}
	var combat_check: Dictionary = Combat.new().validate_convert_action(action, state)
	_assert(not bool(combat_check.get("ok", false)), "Non-basic to non-basic conversion should be rejected in Combat validation")
	_assert(String(combat_check.get("reason", "")) == "requires basic tile", "Combat rejection reason should explain basic-only conversion")

	var validator: ActionValidator = ActionValidator.new()
	var plan: Dictionary = validator.build_owner_plan(state, [], 1)
	var target_block: Dictionary = state.blocks[block_id]
	var queue_check: Dictionary = validator.validate_convert_target(state, 1, target_block, "ranged", plan)
	_assert(not bool(queue_check.get("ok", false)), "Queue validation should reject non-basic to non-basic conversion")
	_assert(String(queue_check.get("reason", "")) == "requires basic tile", "Queue rejection reason should explain basic-only conversion")

func _test_ooze_ai_converts_only_basic() -> void:
	var state: GameState = GameState.new()
	state.width = 12
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(3, 4), true, 9, "basic")
	state.spawn_block(1, Vector2i(4, 4), false, 9, "basic")

	state.add_owner(2, "Enemy", 30)
	var core_id: int = state.spawn_block(2, Vector2i(7, 4), true, 9, "basic")
	var frontline_basic: int = state.spawn_block(2, Vector2i(6, 4), false, 9, "basic")
	var non_basic: int = state.spawn_block(2, Vector2i(7, 3), false, 10, "melee")
	state.blocks[non_basic]["tile_type"] = "melee"
	state.blocks[non_basic]["damage"] = int(Combat.TILE_RULES["melee"]["damage"])
	state.blocks[non_basic]["defense"] = int(Combat.TILE_RULES["melee"]["defense"])
	state.blocks[non_basic]["last_converted_turn"] = -999999
	state.blocks[core_id]["last_converted_turn"] = -999999
	state.blocks[frontline_basic]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	for action in actions:
		if String(action.get("type", "")) != "convert_tile":
			continue
		var action_block_id: int = int(action.get("block_id", -1))
		_assert(state.blocks.has(action_block_id), "AI conversion target block should exist")
		var to_type: String = String(action.get("to_type", "basic"))
		var from_type: String = String(state.blocks[action_block_id].get("tile_type", "basic"))
		if to_type == "basic":
			_assert(int(state.blocks[action_block_id].get("upgrade_tier", 0)) > 0, "AI downgrade should only target upgraded tiles")
		else:
			_assert(from_type == "basic", "AI role conversion should start from basic tiles")

func _test_specialization_tier_progression_and_cap() -> void:
	var state: GameState = GameState.new()
	state.players[1]["nutrients"] = 100
	var block_id: int = state.spawn_block(1, Vector2i(3, 3), true, 9, "basic")
	var combat: Combat = Combat.new()

	var specialize_action: Dictionary = {
		"type": "convert_tile",
		"owner": 1,
		"block_id": block_id,
		"to_type": "melee",
		"energy_delta": Combat.conversion_energy_delta("basic", "melee", 0),
	}
	combat.resolve_with_report([specialize_action], state)
	_assert(String(state.blocks[block_id].get("tile_type", "basic")) == "melee", "Specialization should convert basic tiles into the selected role")
	_assert(int(state.blocks[block_id].get("upgrade_tier", 0)) == Combat.SPECIALIZATION_TIER, "Basic-to-role conversion should create Tier I")

	var cost_tier_ii: int = Combat.upgrade_energy_cost(
		state,
		1,
		"melee",
		0,
		0,
		int(state.blocks[block_id].get("upgrade_tier", Combat.SPECIALIZATION_TIER))
	)
	var upgrade_to_tier_ii: Dictionary = {
		"type": "upgrade_tile",
		"owner": 1,
		"block_id": block_id,
		"tile_type": "melee",
		"cost": cost_tier_ii,
		"planned_type_count": 0,
		"planned_total_count": 0,
	}
	combat.resolve_with_report([upgrade_to_tier_ii], state)
	_assert(int(state.blocks[block_id].get("upgrade_tier", 0)) == 2, "First upgrade action should move specialized tiles to Tier II")
	var damage_tier_ii: int = int(state.blocks[block_id].get("damage", int(Combat.TILE_RULES["melee"]["damage"])))

	var cost_tier_iii: int = Combat.upgrade_energy_cost(
		state,
		1,
		"melee",
		0,
		0,
		int(state.blocks[block_id].get("upgrade_tier", 2))
	)
	_assert(cost_tier_iii > cost_tier_ii, "Tier III upgrade should cost more than Tier II")
	var upgrade_to_tier_iii: Dictionary = {
		"type": "upgrade_tile",
		"owner": 1,
		"block_id": block_id,
		"tile_type": "melee",
		"cost": cost_tier_iii,
		"planned_type_count": 0,
		"planned_total_count": 0,
	}
	combat.resolve_with_report([upgrade_to_tier_iii], state)
	_assert(int(state.blocks[block_id].get("upgrade_tier", 0)) == 3, "Second upgrade action should move specialized tiles to Tier III")
	var damage_tier_iii: int = int(state.blocks[block_id].get("damage", int(Combat.TILE_RULES["melee"]["damage"])))
	_assert(damage_tier_iii > damage_tier_ii, "Higher tiers should improve combat effectiveness incrementally")

	var blocked_upgrade: Dictionary = combat.validate_upgrade_action(
		{
			"type": "upgrade_tile",
			"owner": 1,
			"block_id": block_id,
			"tile_type": "melee",
			"cost": 1,
		},
		state
	)
	_assert(not bool(blocked_upgrade.get("ok", false)), "Tier III tiles should reject additional upgrades")
	_assert(String(blocked_upgrade.get("reason", "")) == "max tier reached", "Upgrade rejection reason should explain max tier cap")

func _test_downgrade_refund_scales_by_tier() -> void:
	var refund_tier_i: int = -Combat.conversion_energy_delta("defense", "basic", 1)
	var refund_tier_ii: int = -Combat.conversion_energy_delta("defense", "basic", 2)
	var refund_tier_iii: int = -Combat.conversion_energy_delta("defense", "basic", 3)
	_assert(refund_tier_i > refund_tier_ii and refund_tier_ii > refund_tier_iii, "Downgrade refunds should decrease as specialization tier increases")

	var state: GameState = GameState.new()
	state.players[1]["nutrients"] = 0
	var block_id: int = state.spawn_block(1, Vector2i(4, 4), true, int(Combat.TILE_RULES["defense"]["max_hp"]), "defense")
	state.blocks[block_id]["upgrade_tier"] = 3
	var combat: Combat = Combat.new()
	var expected_refund: int = -Combat.conversion_energy_delta("defense", "basic", 3)
	var downgrade_action: Dictionary = {
		"type": "convert_tile",
		"owner": 1,
		"block_id": block_id,
		"to_type": "basic",
		"energy_delta": Combat.conversion_energy_delta("defense", "basic", 3),
	}
	combat.resolve_with_report([downgrade_action], state)
	_assert(int(state.players[1]["nutrients"]) == expected_refund, "Downgrading should grant the tier-scaled partial refund")
	_assert(String(state.blocks[block_id].get("tile_type", "")) == "basic", "Downgrade should return the tile to basic")
	_assert(int(state.blocks[block_id].get("upgrade_tier", -1)) == 0, "Downgrade should reset specialization tier to zero")

func _test_ooze_ai_safe_backline_downgrade() -> void:
	var state: GameState = GameState.new()
	state.width = 18
	state.height = 10
	state.turn_index = 9
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(2, 5), true, 9, "basic")
	state.spawn_block(1, Vector2i(3, 5), false, 9, "basic")

	state.add_owner(2, "Enemy", 1)
	var enemy_core: int = state.spawn_block(2, Vector2i(13, 5), true, 9, "basic")
	var enemy_backline: int = state.spawn_block(2, Vector2i(12, 5), false, 9, "basic")
	var upgraded_anchor: int = state.spawn_block(2, Vector2i(12, 4), false, 18, "defense")
	state.blocks[enemy_core]["last_converted_turn"] = -999999
	state.blocks[enemy_backline]["last_converted_turn"] = -999999
	state.blocks[upgraded_anchor]["upgrade_tier"] = 1
	state.blocks[upgraded_anchor]["last_converted_turn"] = -999999

	var ai = OOZE_AI_SCRIPT.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var has_safe_downgrade: bool = false
	for action in actions:
		if String(action.get("type", "")) != "convert_tile":
			continue
		if String(action.get("to_type", "")) != "basic":
			continue
		if int(action.get("block_id", -1)) != upgraded_anchor:
			continue
		_assert(int(action.get("energy_delta", 0)) < 0, "Safe downgrade should grant a small refund")
		has_safe_downgrade = true
		break
	_assert(has_safe_downgrade, "Low-threat backline upgraded tiles should be considered for conservative downgrade refunds")

func _test_team_color_uniqueness_for_active_owners() -> void:
	var state: GameState = GameState.new()
	state.players[1]["alive"] = true
	state.spawn_block(1, Vector2i(1, 1), true, 9, "basic")

	state.add_owner(2, "Enemy A", 10, GameState.TEAM_ENEMY, true)
	state.add_owner(50, "Enemy B", 10, GameState.TEAM_ENEMY, true)
	state.add_owner(77, "Enemy C", 10, GameState.TEAM_ENEMY, true)
	state.spawn_block(2, Vector2i(4, 3), true, 9, "basic")
	state.spawn_block(50, Vector2i(6, 3), true, 9, "basic")
	state.spawn_block(77, Vector2i(8, 3), true, 9, "basic")

	var renderer: BoardRenderer = BoardRenderer.new()
	var seen: Dictionary = {}
	for owner_id in [2, 50, 77]:
		var tint: Color = renderer.owner_tint_for_ui(state, owner_id)
		var key: String = _color_key(tint)
		_assert(not seen.has(key), "Active enemy owners should use unique colors while palette entries remain available")
		seen[key] = true

func _test_ooze_ai_side_swap_fairness_smoke() -> void:
	var rounds: int = 6
	var left_setup: Dictionary = _simulate_side_swap_case(true, rounds)
	var right_setup: Dictionary = _simulate_side_swap_case(false, rounds)

	var owner2_left: Dictionary = left_setup.get("owner_2", {})
	var owner2_right: Dictionary = right_setup.get("owner_2", {})
	var owner3_left: Dictionary = left_setup.get("owner_3", {})
	var owner3_right: Dictionary = right_setup.get("owner_3", {})

	_assert(
		absi(int(owner2_left.get("blocks", 0)) - int(owner2_right.get("blocks", 0))) <= 2,
		"Owner-2 performance should stay close after side swap (blocks)"
	)
	_assert(
		absi(int(owner3_left.get("blocks", 0)) - int(owner3_right.get("blocks", 0))) <= 2,
		"Owner-3 performance should stay close after side swap (blocks)"
	)
	_assert(
		absi(int(owner2_left.get("hp", 0)) - int(owner2_right.get("hp", 0))) <= 14,
		"Owner-2 performance should stay close after side swap (hp)"
	)
	_assert(
		absi(int(owner3_left.get("hp", 0)) - int(owner3_right.get("hp", 0))) <= 14,
		"Owner-3 performance should stay close after side swap (hp)"
	)

	var side_adv_left: int = int(left_setup.get("left_hp", 0)) - int(left_setup.get("right_hp", 0))
	var side_adv_right: int = int(right_setup.get("left_hp", 0)) - int(right_setup.get("right_hp", 0))
	_assert(
		side_adv_left * side_adv_right <= 0 or (absi(side_adv_left) <= 10 and absi(side_adv_right) <= 10),
		"Side-swap smoke check should not show strong same-side hp advantage in both mirrored runs"
	)

func _simulate_side_swap_case(owner_2_on_left: bool, rounds: int) -> Dictionary:
	var state: GameState = _build_side_swap_state(owner_2_on_left)
	var tick: TickSystem = TickSystem.new()
	var ai = OOZE_AI_SCRIPT.new()
	var left_owner: int = 2 if owner_2_on_left else 3
	var right_owner: int = 3 if owner_2_on_left else 2

	for _turn in range(rounds):
		var actions: Array = []
		for owner_id in [2, 3]:
			var owner_blocks: Array = state.get_owner_blocks(owner_id)
			if owner_blocks.is_empty():
				continue
			if not bool(state.players.get(owner_id, {}).get("alive", true)):
				continue
			var owner_actions: Array = ai.choose_actions(state, owner_id, 1)
			if owner_actions.is_empty():
				owner_actions = [{"type": "pass", "owner": owner_id}]
			actions.append_array(owner_actions)
		state = tick.step(state, actions)

	var owner_2: Dictionary = _owner_summary(state, 2)
	var owner_3: Dictionary = _owner_summary(state, 3)
	return {
		"owner_2": owner_2,
		"owner_3": owner_3,
		"left_hp": int(_owner_summary(state, left_owner).get("hp", 0)),
		"right_hp": int(_owner_summary(state, right_owner).get("hp", 0)),
	}

func _build_side_swap_state(owner_2_on_left: bool) -> GameState:
	var state: GameState = GameState.new()
	state.width = 16
	state.height = 9
	state.turn_limit = 0
	state.enemies_allied = false
	state.door_tile = Vector2i(8, 4)
	state.door_hp = 0
	state.door_max_hp = 0
	state.players[1]["alive"] = false
	state.players[1]["ai_controlled"] = false

	state.add_owner(2, "Enemy A", 30, GameState.TEAM_ENEMY, true)
	state.add_owner(3, "Enemy B", 30, GameState.TEAM_ENEMY, true)

	var left_owner: int = 2 if owner_2_on_left else 3
	var right_owner: int = 3 if owner_2_on_left else 2

	var left_core: int = state.spawn_block(left_owner, Vector2i(3, 4), true, 12, "basic")
	var right_core: int = state.spawn_block(right_owner, Vector2i(12, 4), true, 12, "basic")
	state.blocks[left_core]["is_heart"] = true
	state.blocks[right_core]["is_heart"] = true

	for pos in [Vector2i(4, 4), Vector2i(3, 3), Vector2i(3, 5), Vector2i(4, 3), Vector2i(4, 5)]:
		state.spawn_block(left_owner, pos, false, 9, "basic")
	for pos in [Vector2i(11, 4), Vector2i(12, 3), Vector2i(12, 5), Vector2i(11, 3), Vector2i(11, 5)]:
		state.spawn_block(right_owner, pos, false, 9, "basic")

	state.resource_nodes = [
		{"pos": Vector2i(6, 2), "kind": "gem", "consumed": false},
		{"pos": Vector2i(9, 2), "kind": "gem", "consumed": false},
		{"pos": Vector2i(6, 6), "kind": "rat", "consumed": false},
		{"pos": Vector2i(9, 6), "kind": "rat", "consumed": false},
	]
	return state

func _owner_summary(state: GameState, owner_id: int) -> Dictionary:
	var blocks: Array = state.get_owner_blocks(owner_id)
	var total_hp: int = 0
	for block in blocks:
		total_hp += int(block.get("hp", 0))
	return {
		"blocks": blocks.size(),
		"hp": total_hp,
		"energy": int(state.players.get(owner_id, {}).get("nutrients", 0)),
	}

func _test_spectator_stall_ignored() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.spectator_mode = true
	state.turn_limit = 0
	state.players[1]["alive"] = false
	state.players[1]["nutrients"] = 0

	state.add_owner(50, "Ally", 10, GameState.TEAM_PLAYER, true)
	var ally_heart: int = state.spawn_block(50, Vector2i(1, 1), true, 9, "basic")
	state.blocks[ally_heart]["is_heart"] = true

	state.add_owner(2, "Enemy", 10, GameState.TEAM_ENEMY, true)
	var enemy_heart: int = state.spawn_block(2, Vector2i(8, 6), true, 9, "basic")
	state.blocks[enemy_heart]["is_heart"] = true

	var tick: TickSystem = TickSystem.new()
	var next: GameState = tick.step(state, [])
	_assert(next.stall_counter == 0, "Spectator mode should never accumulate player stall-lock")

func _test_spectator_team_loss_condition() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.spectator_mode = true
	state.turn_limit = 0
	state.players[1]["alive"] = false

	state.add_owner(50, "Ally", 10, GameState.TEAM_PLAYER, true)
	var ally_heart: int = state.spawn_block(50, Vector2i(2, 2), true, 9, "basic")
	state.blocks[ally_heart]["is_heart"] = true

	state.add_owner(2, "Enemy", 10, GameState.TEAM_ENEMY, true)
	var enemy_heart: int = state.spawn_block(2, Vector2i(8, 5), true, 9, "basic")
	state.blocks[enemy_heart]["is_heart"] = true

	var director: LevelDirector = LevelDirector.new()
	var ongoing: Dictionary = director.check_victory_or_loss(state)
	_assert(String(ongoing.get("status", "")) == "ongoing", "Spectator mode should continue while allied team still has hearts")

	state.blocks.erase(ally_heart)
	state.players[50]["alive"] = false
	var loss: Dictionary = director.check_victory_or_loss(state)
	_assert(String(loss.get("status", "")) == "loss", "Spectator mode should lose when all player-team hearts are gone")
	_assert(String(loss.get("reason", "")) == "all_player_team_hearts_destroyed", "Spectator defeat reason should report allied heart wipe")

func _test_dev_spectator_disables_turn_limit() -> void:
	var run_flow_script: GDScript = preload("res://scripts/systems/RunFlow.gd")
	var run_flow: Node = run_flow_script.new()
	run_flow.begin_dev_run(2, 2, false, true)
	var options: Dictionary = run_flow.build_level_options()
	_assert(int(options.get("turn_limit", -1)) == 0, "Dev spectator mode should disable turn limit for long-form AI observation")
	run_flow.free()

func _test_runflow_upgrade_draw_determinism() -> void:
	var run_flow_script: GDScript = preload("res://scripts/systems/RunFlow.gd")
	var run_a = run_flow_script.new()
	var run_b = run_flow_script.new()
	run_a.begin_run()
	run_b.begin_run()
	run_a.run_seed = 81234
	run_b.run_seed = 81234
	run_a.current_level = 2
	run_b.current_level = 2

	var choices_a: Array = run_a.draw_upgrade_choices(3)
	var choices_b: Array = run_b.draw_upgrade_choices(3)
	_assert(choices_a.size() == 3 and choices_b.size() == 3, "Upgrade draw should produce 3 choices")
	var ids_a: Array = []
	var ids_b: Array = []
	for choice in choices_a:
		ids_a.append(String((choice as Dictionary).get("id", "")))
	for choice in choices_b:
		ids_b.append(String((choice as Dictionary).get("id", "")))
	_assert(ids_a == ids_b, "Upgrade draw must be deterministic for matching seed/level")

	var pick_id: String = ids_a[0]
	var apply_a: Dictionary = run_a.apply_upgrade_choice(pick_id)
	var apply_b: Dictionary = run_b.apply_upgrade_choice(pick_id)
	_assert(bool(apply_a.get("ok", false)) and bool(apply_b.get("ok", false)), "Applying a drawn upgrade should succeed")
	_assert(run_a.get_run_modifiers() == run_b.get_run_modifiers(), "Upgrade application should remain deterministic across identical runs")
	run_a.free()
	run_b.free()

func _test_upgrade_modifiers_affect_combat_economy_and_placement() -> void:
	var placement_state: GameState = GameState.new()
	placement_state.width = 10
	placement_state.height = 8
	placement_state.players[1]["nutrients"] = 20
	placement_state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	placement_state.spawn_block(1, Vector2i(1, 2), false, 8, "basic")
	var target: Vector2i = Vector2i(2, 1)
	var blocked_check: Dictionary = placement_state.evaluate_growth_target(1, target, 1, {})
	_assert(not bool(blocked_check.get("ok", false)), "Without upgrade, low-support placement should be rejected")
	placement_state.card_modifiers["placement_support_delta"] = -1
	var allowed_check: Dictionary = placement_state.evaluate_growth_target(1, target, 1, {})
	_assert(bool(allowed_check.get("ok", false)), "Placement support upgrade should reduce required local support")

	var econ_state: GameState = GameState.new()
	econ_state.width = 8
	econ_state.height = 8
	econ_state.players[1]["nutrients"] = 8
	econ_state.card_modifiers = {"income_flat": 1, "gather_income_bonus": 1}
	econ_state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	var gather_id: int = econ_state.spawn_block(1, Vector2i(2, 1), false, 8, "gather")
	econ_state.blocks[gather_id]["gather_bonus"] = Economy.GATHER_RESOURCE_BONUS
	econ_state.resource_nodes = [{"pos": Vector2i(2, 1), "kind": "gem", "consumed": true, "captured_turn": 0}]
	econ_state.turn_index = 1
	var eco_report: Dictionary = Economy.new().compute_income_and_upkeep(econ_state)
	_assert(int(eco_report["income"][1]) == 6, "Income and gather upgrades should apply to player economy")

	var base_combat_state: GameState = GameState.new()
	base_combat_state.width = 8
	base_combat_state.height = 8
	base_combat_state.add_owner(2, "Enemy", 10)
	var melee_base_id: int = base_combat_state.spawn_block(1, Vector2i(2, 2), true, 10, "melee")
	base_combat_state.blocks[melee_base_id]["damage"] = int(Combat.TILE_RULES["melee"]["damage"])
	var enemy_base_id: int = base_combat_state.spawn_block(2, Vector2i(3, 2), true, 10, "basic")
	Combat.new().resolve([], base_combat_state)
	var hp_without_upgrade: int = int(base_combat_state.blocks[enemy_base_id]["hp"])

	var boosted_combat_state: GameState = GameState.new()
	boosted_combat_state.width = 8
	boosted_combat_state.height = 8
	boosted_combat_state.add_owner(2, "Enemy", 10)
	boosted_combat_state.card_modifiers = {"melee_damage_bonus": 1}
	var melee_boost_id: int = boosted_combat_state.spawn_block(1, Vector2i(2, 2), true, 10, "melee")
	boosted_combat_state.blocks[melee_boost_id]["damage"] = int(Combat.TILE_RULES["melee"]["damage"])
	var enemy_boost_id: int = boosted_combat_state.spawn_block(2, Vector2i(3, 2), true, 10, "basic")
	Combat.new().resolve([], boosted_combat_state)
	var hp_with_upgrade: int = int(boosted_combat_state.blocks[enemy_boost_id]["hp"])

	_assert(hp_with_upgrade < hp_without_upgrade, "Melee damage upgrade should increase player combat pressure")

func _test_preview_truth_mixed_conflict_and_reclaim() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.players[1]["nutrients"] = 20

	for tile in [
		Vector2i(2, 3), Vector2i(3, 3), Vector2i(3, 2),
		Vector2i(3, 4), Vector2i(2, 2), Vector2i(2, 4)
	]:
		state.spawn_block(1, tile, tile == Vector2i(2, 3), 9, "basic")

	state.add_owner(2, "Enemy", 20, GameState.TEAM_ENEMY, true)
	for tile in [
		Vector2i(6, 3), Vector2i(5, 3), Vector2i(5, 2),
		Vector2i(5, 4), Vector2i(6, 2), Vector2i(6, 4)
	]:
		state.spawn_block(2, tile, tile == Vector2i(6, 3), 9, "basic")

	var reclaim_tile: Vector2i = Vector2i(4, 5)
	state.mark_reclaim_block(reclaim_tile, 1)

	var validator: ActionValidator = ActionValidator.new()
	var plan: Dictionary = validator.build_owner_plan(state, [], 1)
	var reclaim_check: Dictionary = validator.validate_place_target(state, 1, reclaim_tile, "basic", 1, 1, plan)
	_assert(not bool(reclaim_check.get("ok", false)), "Reclaim-blocked tile should be invalid in preview/queue validation")
	_assert(String(reclaim_check.get("reason", "")) == "cell reforming", "Reclaim-blocked reason should be explicit")

	var conflict_tile: Vector2i = Vector2i(4, 3)
	var player_action: Dictionary = {
		"type": "place_tile",
		"owner": 1,
		"target": conflict_tile,
		"tile_type": "basic",
		"cost": 1,
		"min_adjacent": 1,
		"_preview_id": "player_conflict_probe",
	}
	var enemy_action: Dictionary = {
		"type": "place_tile",
		"owner": 2,
		"target": conflict_tile,
		"tile_type": "basic",
		"cost": 1,
		"min_adjacent": 1,
		"_preview_id": "enemy_conflict_probe",
	}

	var predict: Dictionary = validator.predict_candidate_application(state, [], [enemy_action], player_action)
	_assert(bool(predict.get("ok", false)), "Preview should keep player action valid if deterministic ordering applies it")

	var resolver: TurnResolver = TurnResolver.new()
	var turn: Dictionary = resolver.resolve_turn(state, [player_action], [enemy_action], 1, 1)
	var next: GameState = turn.get("state", state)
	var placed: Dictionary = next.get_block_at(conflict_tile)
	_assert(not placed.is_empty() and int(placed.get("owner", 0)) == 1, "Resolved state should match preview: player action applies on conflict tile")

	var enemy_failed: Array = turn.get("failed_enemy_actions", [])
	_assert(enemy_failed.size() == 1, "Conflicting enemy action should fail if player place was preview-valid")
	_assert(String(enemy_failed[0].get("reason", "")) == "not empty", "Enemy conflict failure reason should be truthful")

func _test_team_and_door_policy_matrix() -> void:
	var state: GameState = GameState.new()
	state.add_owner(50, "Ally", 10, GameState.TEAM_PLAYER, true)
	state.add_owner(2, "Enemy A", 10, GameState.TEAM_ENEMY, true)
	state.add_owner(3, "Enemy B", 10, GameState.TEAM_ENEMY, true)

	_assert(not state.are_hostile(1, 50), "Player and allied team owners should not be hostile")
	_assert(state.are_hostile(1, 2), "Player and enemy team owners should be hostile")
	_assert(not state.are_hostile(2, 3), "Enemy owners should be allied when enemies_allied is true")

	state.enemies_allied = false
	_assert(state.are_hostile(2, 3), "Enemy owners should become hostile when enemies_allied is false")
	state.spectator_mode = true
	_assert(not state.are_hostile(1, 50), "Spectator mode should not alter player-team alliance")
	_assert(state.are_hostile(1, 2), "Spectator mode should not alter cross-team hostility")

	var door_player: GameState = GameState.new()
	door_player.width = 10
	door_player.height = 8
	door_player.door_tile = Vector2i(5, 2)
	door_player.door_max_hp = 5
	door_player.door_hp = 3
	var p_id: int = door_player.spawn_block(1, Vector2i(2, 2), true, 8, "ranged")
	_set_ranged_stats(door_player, p_id)
	Combat.new().resolve([], door_player)
	_assert(door_player.door_hp < 3, "Player tiles should be able to damage the door")

	var door_ally: GameState = GameState.new()
	door_ally.width = 10
	door_ally.height = 8
	door_ally.door_tile = Vector2i(5, 2)
	door_ally.door_max_hp = 5
	door_ally.door_hp = 3
	door_ally.add_owner(50, "Ally", 10, GameState.TEAM_PLAYER, true)
	var a_id: int = door_ally.spawn_block(50, Vector2i(2, 2), true, 8, "ranged")
	_set_ranged_stats(door_ally, a_id)
	Combat.new().resolve([], door_ally)
	_assert(door_ally.door_hp < 3, "Player-team allies should be able to damage the door")

	var door_enemy: GameState = GameState.new()
	door_enemy.width = 10
	door_enemy.height = 8
	door_enemy.door_tile = Vector2i(5, 2)
	door_enemy.door_max_hp = 5
	door_enemy.door_hp = 3
	door_enemy.add_owner(2, "Enemy", 10, GameState.TEAM_ENEMY, true)
	var e_id: int = door_enemy.spawn_block(2, Vector2i(2, 2), true, 8, "ranged")
	_set_ranged_stats(door_enemy, e_id)
	Combat.new().resolve([], door_enemy)
	_assert(door_enemy.door_hp == 3, "Hostile enemy team should not damage the door objective")

func _test_spectator_round_order_determinism() -> void:
	var state: GameState = GameState.new()
	state.spectator_mode = true
	state.run_seed = 4242
	state.level_index = 2
	state.players[1]["alive"] = false
	state.players[1]["ai_controlled"] = false

	state.add_owner(2, "Enemy A", 10, GameState.TEAM_ENEMY, true)
	state.add_owner(3, "Enemy B", 10, GameState.TEAM_ENEMY, true)
	state.add_owner(50, "Ally", 10, GameState.TEAM_PLAYER, true)
	state.spawn_block(2, Vector2i(7, 2), true, 8, "basic")
	state.spawn_block(3, Vector2i(7, 4), true, 8, "basic")
	state.spawn_block(50, Vector2i(2, 3), true, 8, "basic")

	var controller_script: GDScript = load("res://scripts/GameController.gd")
	var controller_a: Node2D = controller_script.new()
	var controller_b: Node2D = controller_script.new()
	controller_a.state = state.copy_state()
	controller_b.state = state.copy_state()
	controller_a.actor_round_index = 0
	controller_b.actor_round_index = 0

	controller_a._start_new_actor_round()
	controller_b._start_new_actor_round()
	var order_a: Array = controller_a.actor_cycle_order.duplicate()
	var order_b: Array = controller_b.actor_cycle_order.duplicate()
	_assert(order_a == order_b, "Spectator round order should be reproducible for identical seed/state")

	var expected_actor_count: int = 3
	_assert(order_a.size() == expected_actor_count, "Each alive AI owner should appear exactly once in spectator round order")
	var unique: Dictionary = {}
	for owner in order_a:
		unique[int(owner)] = true
	_assert(unique.size() == expected_actor_count, "Spectator round order should not duplicate owners within a round")

	controller_a.actor_cycle_order = order_a.duplicate()
	controller_a.actor_cycle_index = 0
	controller_a.active_owner_id = int(order_a[0])
	var seen: Dictionary = {int(controller_a.active_owner_id): true}
	for _i in range(order_a.size() - 1):
		controller_a._advance_active_actor()
		seen[int(controller_a.active_owner_id)] = true
	_assert(seen.size() == expected_actor_count, "Each alive AI should act once before spectator round wraps")
	controller_a.free()
	controller_b.free()

func _test_player_queue_basic_toggle_and_requeue() -> void:
	var controller_script: GDScript = load("res://scripts/GameController.gd")
	var controller: Node2D = controller_script.new()
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	state.spawn_block(1, Vector2i(2, 1), false, 8, "basic")
	state.spawn_block(1, Vector2i(1, 2), false, 8, "basic")
	state.spawn_block(1, Vector2i(2, 2), false, 8, "basic")
	controller.state = state

	var target: Vector2i = Vector2i(3, 1)
	var add_1: Dictionary = controller._queue_place_action(target, "basic")
	_assert(bool(add_1.get("ok", false)), "Initial basic queue should succeed")
	_assert(controller.queued_actions.size() == 1, "Initial basic queue should add one action")

	var remove_toggle: Dictionary = controller._queue_place_action(target, "basic")
	_assert(bool(remove_toggle.get("ok", false)), "Second click should toggle-remove queued basic placement")
	_assert(controller.queued_actions.size() == 0, "Toggle remove should clear queued basic placement")

	var add_2: Dictionary = controller._queue_place_action(target, "basic")
	_assert(bool(add_2.get("ok", false)), "Basic tile should be queueable again after de-queue")
	_assert(controller.queued_actions.size() == 1, "Re-queue after remove should restore one action")

	# Simulate stale duplicate queue state and ensure one click clears all actions
	# for that tile so placement does not get stuck in an already-queued state.
	controller.queued_actions.append(controller._build_place_candidate(target, "basic"))
	controller.queued_actions.append(controller._build_place_candidate(target, "basic"))
	var remove_dup: Dictionary = controller._queue_place_action(target, "basic")
	_assert(bool(remove_dup.get("ok", false)), "Toggle remove should handle duplicate stale queued placements safely")
	_assert(controller.queued_actions.size() == 0, "Toggle remove should clear all same-tile queued placements")

	# Replacement attempts that fail validation should restore previous queued action.
	var add_restore_seed: Dictionary = controller._queue_place_action(target, "basic")
	_assert(bool(add_restore_seed.get("ok", false)), "Seed placement for restore scenario should queue")
	state.players[1]["nutrients"] = 1
	var failed_swap: Dictionary = controller._queue_place_action(target, "gather")
	_assert(not bool(failed_swap.get("ok", false)), "Invalid replacement should fail")
	_assert(controller.queued_actions.size() == 1, "Failed replacement should restore existing queued placement")
	_assert(String(controller.queued_actions[0].get("tile_type", "")) == "basic", "Restored action should remain original basic placement")
	controller.free()

func _test_atlas_sprite_contract() -> void:
	var file: FileAccess = FileAccess.open("res://assets/atlas/atlas.json", FileAccess.READ)
	_assert(file != null, "Atlas metadata file should exist")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_assert(typeof(parsed) == TYPE_DICTIONARY, "Atlas metadata must parse into dictionary")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var sprites: Dictionary = parsed.get("sprites", {})
	_assert(typeof(sprites) == TYPE_DICTIONARY, "Atlas metadata should contain sprite dictionary")
	if typeof(sprites) != TYPE_DICTIONARY:
		return

	for mask in range(16):
		for variant in range(3):
			for frame in range(3):
				var key: String = "slime_base_neutral_m%02d_v%d_f%d" % [mask, variant, frame]
				_assert(sprites.has(key), "Missing base slime sprite key: %s" % key)

	for overlay in [
		"slime_overlay_basic",
		"slime_overlay_gather",
		"slime_overlay_defense",
		"slime_overlay_melee",
		"slime_overlay_ranged",
		"slime_overlay_gather_infused",
	]:
		_assert(sprites.has(overlay), "Missing overlay sprite key: %s" % overlay)

	for ui_key in [
		"ui_panel_tile",
		"ui_button_tile",
		"ui_button_hover_tile",
		"ui_button_pressed_tile",
		"ui_button_selected",
		"ui_button_endturn",
		"ui_button_endturn_hover",
		"ui_button_endturn_pressed",
		"ui_icon_basic",
		"ui_icon_melee",
		"ui_icon_ranged",
		"ui_icon_gather",
		"ui_icon_defense",
	]:
		_assert(sprites.has(ui_key), "Missing UI sprite key: %s" % ui_key)

func _test_turn_performance_smoke() -> void:
	var state: GameState = GameState.new()
	state.width = 30
	state.height = 20
	state.players[1]["nutrients"] = 200
	state.add_owner(2, "Enemy", 200, GameState.TEAM_ENEMY, true)

	for y in range(2, state.height - 2):
		for x in range(2, state.width - 2):
			if (x + y) % 3 != 0:
				continue
			var owner: int = 1 if x < int(state.width / 2) else 2
			state.spawn_block(owner, Vector2i(x, y), false, 9, "basic")

	var tick: TickSystem = TickSystem.new()
	var actions: Array = []
	for x in range(3, 9):
		actions.append({
			"type": "place_tile",
			"owner": 1,
			"target": Vector2i(x, 2),
			"tile_type": "basic",
			"cost": 1,
			"min_adjacent": 1
		})

	var start_ms: int = Time.get_ticks_msec()
	var _next: GameState = tick.step(state, actions)
	var elapsed: int = Time.get_ticks_msec() - start_ms
	_assert(elapsed < 2500, "Turn performance smoke exceeded 2500ms (%dms)" % elapsed)

func _seed_test_state() -> GameState:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 8
	state.players[1]["nutrients"] = 20
	state.spawn_block(1, Vector2i(1, 1), true, 8, "basic")
	state.spawn_block(1, Vector2i(2, 1), false, 8, "basic")
	state.spawn_block(1, Vector2i(2, 2), false, 8, "basic")

	state.add_owner(2, "Enemy", 20)
	state.spawn_block(2, Vector2i(7, 5), true, 8, "basic")
	return state

func _set_ranged_stats(state: GameState, block_id: int) -> void:
	if not state.blocks.has(block_id):
		return
	state.blocks[block_id]["tile_type"] = "ranged"
	state.blocks[block_id]["damage"] = int(Combat.TILE_RULES["ranged"]["damage"])
	state.blocks[block_id]["range"] = int(Combat.TILE_RULES["ranged"]["range"])

func _is_frontline_action(state: GameState, owner_id: int, action: Dictionary) -> bool:
	var kind: String = String(action.get("type", "pass"))
	if kind == "place_tile":
		var tile: Vector2i = action.get("target", Vector2i(-1, -1))
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Dictionary = state.get_block_at(tile + step)
			if neighbor.is_empty():
				continue
			if int(neighbor["owner"]) != owner_id:
				return true
		return false

	if kind == "convert_tile":
		var block_id: int = int(action.get("block_id", -1))
		if not state.blocks.has(block_id):
			return false
		var pos: Vector2i = state.blocks[block_id]["pos"]
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor_2: Dictionary = state.get_block_at(pos + step)
			if neighbor_2.is_empty():
				continue
			if int(neighbor_2["owner"]) != owner_id:
				return true
		return false

	return false

func _snapshot(state: GameState) -> String:
	var out: Array = []
	out.append(str(state.turn_index))
	out.append(str(state.players))
	out.append(str(state.blocks))
	out.append(str(state.resource_nodes))
	out.append(str(state.reclaim_timers))
	return "|".join(out)

func _color_key(c: Color) -> String:
	return "%.4f|%.4f|%.4f|%.4f" % [c.r, c.g, c.b, c.a]

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


