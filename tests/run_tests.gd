extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	_test_determinism()
	_test_economy_math()
	_test_victory_conditions()
	_test_combat_resolution()
	_test_stall_loss()
	_test_blob_growth_rule()
	_test_support_placement_rule()
	_test_support_and_stability()
	_test_defense_guard_identity()
	_test_enemy_ai_frontline_pressure()
	_test_enemy_ai_conversion_cooldown()
	_test_enemy_ai_no_duplicate_actions()

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
	_assert(String(out["status"]) == "victory", "Door-touch victory should trigger")

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

func _test_enemy_ai_frontline_pressure() -> void:
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

	var ai: EnemyAI = EnemyAI.new()
	var actions: Array = ai.choose_actions(state, 2, 1)

	var has_frontline_investment: bool = false
	for action in actions:
		if _is_frontline_action(state, 2, action):
			has_frontline_investment = true
			break

	_assert(has_frontline_investment, "Enemy AI should make at least one frontline action when possible")

func _test_enemy_ai_conversion_cooldown() -> void:
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

	var ai: EnemyAI = EnemyAI.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	for action in actions:
		if String(action.get("type", "")) != "convert_tile":
			continue
		_assert(
			int(action.get("block_id", -1)) != enemy_front,
			"Enemy AI should not reconvert a tile inside conversion cooldown window"
		)

func _test_enemy_ai_no_duplicate_actions() -> void:
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

	var ai: EnemyAI = EnemyAI.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	var seen_targets: Dictionary = {}
	var seen_blocks: Dictionary = {}

	for action in actions:
		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			var key: String = "%s" % [action.get("target", Vector2i(-1, -1))]
			_assert(not seen_targets.has(key), "Enemy AI should not place on the same tile twice in one turn")
			seen_targets[key] = true
		elif kind == "convert_tile":
			var block_id: int = int(action.get("block_id", -1))
			_assert(not seen_blocks.has(block_id), "Enemy AI should not convert the same block twice in one turn")
			seen_blocks[block_id] = true

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
	return "|".join(out)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
