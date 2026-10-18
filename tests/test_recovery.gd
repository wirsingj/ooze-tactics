extends RefCounted

const EVALUATION = preload("res://scripts/systems/AIEvaluation.gd")
const CONTROLLER = preload("res://scripts/GameController.gd")
const DYNAMIC = preload("res://scripts/ui/world3d/DynamicOozeRenderer.gd")
const MARKERS = preload("res://scripts/ui/world3d/MarkerLayerRenderer.gd")
const ASSETS = preload("res://scripts/ui/world3d/World3DAssets.gd")

class FlatGround:
	extends RefCounted
	func _sample_ground_height_at_local(_x: float, _z: float, _w: float, _h: float) -> float:
		return 0.0

var failures: Array[String] = []

func run() -> Array[String]:
	_campaign_openings()
	_queue_dependencies_and_prices()
	_action_budget_and_hover()
	_heart_rewards()
	_feedback()
	_final_turn()
	_evaluation_contract()
	_ranged_threat()
	_combat_saving()
	_combat_feedback_events()
	_render_geometry()
	_markers()
	print("Recovery checks: 12 groups completed")
	return failures

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("Recovery: " + message)

func _campaign_openings() -> void:
	var flow: Node = load("res://scripts/systems/RunFlow.gd").new()
	var templates: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/templates.json"))
	for seed_value in [1337, 2026, 45678]:
		flow.run_seed = seed_value
		for level in range(1, 6):
			flow.current_level = level
			var state: GameState = LevelGenerator.new().build_level(level, flow.get_level_seed(), templates, [], flow.build_level_options())
			for owner in state.players:
				if not state.are_hostile(1, owner):
					continue
				var income: int = Economy.new().compute_income_and_upkeep(state)["delta"].get(owner, 0)
				_check(income > 0, "Campaign enemies need income to recover after losing Gather tiles")
				var legal: int = 0
				for y in range(state.height):
					for x in range(state.width):
						var tile: Vector2i = Vector2i(x, y)
						if state.is_empty_ground(tile) and state.evaluate_growth_target(owner, tile, 1).get("ok", false):
							legal += 1
				_check(legal > 0, "Campaign level %d seed %d owner %d has no growth opening" % [level, seed_value, owner])
				var actions: Array = OozeAI.new().choose_actions(state, owner, 1)
				_check(not actions.is_empty(), "Campaign level %d seed %d owner %d cannot act" % [level, seed_value, owner])
				var report: Dictionary = Combat.new().preview_resolution(state, actions)
				_check(report["failed_actions"].is_empty(), "Campaign opening AI actions must apply")
	flow.free()

func _queue_state() -> GameState:
	var state: GameState = GameState.new()
	state.width = 12
	state.height = 10
	state.players[1]["nutrients"] = 100
	state.players[1]["max_actions"] = 5
	for tile in [Vector2i(3,3), Vector2i(4,3), Vector2i(3,4), Vector2i(4,4)]:
		state.spawn_block(1, tile, tile == Vector2i(3,3), 9, "basic")
	return state

func _queue_dependencies_and_prices() -> void:
	var controller: Node2D = CONTROLLER.new()
	controller.state = _queue_state()
	for tile in [Vector2i(5,3), Vector2i(5,4), Vector2i(6,3)]:
		_check(controller._queue_place_action(tile, "basic")["ok"], "Dependency fixture must queue")
	controller._remove_player_action_for_tile(Vector2i(5,3))
	_check(controller.queued_actions.size() == 1, "Removing support must prune its dependent growth only")
	_check(controller.queued_actions[0]["target"] == Vector2i(5,4), "Independent growth must survive cancellation")
	_check(Combat.new().preview_resolution(controller.state, controller.queued_actions)["failed_actions"].is_empty(), "Edited queue must still resolve")
	controller.queued_actions.clear()
	var a: int = controller.state.spawn_block(1, Vector2i(2,3), false, 8, "gather")
	var b: int = controller.state.spawn_block(1, Vector2i(2,4), false, 8, "gather")
	controller.state.blocks[a]["upgrade_tier"] = 1
	controller.state.blocks[b]["upgrade_tier"] = 1
	_check(controller._queue_upgrade_action(controller.state.blocks[a])["ok"], "First upgrade queues")
	_check(controller._queue_upgrade_action(controller.state.blocks[b])["ok"], "Second upgrade queues")
	_check(controller.queued_actions[1]["cost"] == 11, "Second Gather upgrade costs eleven before cancellation")
	controller._remove_player_action_for_tile(Vector2i(2,3))
	_check(controller.queued_actions.size() == 1 and controller.queued_actions[0]["cost"] == 10, "Cancellation must reprice remaining upgrade to ten")
	controller.free()

func _action_budget_and_hover() -> void:
	var controller: Node2D = CONTROLLER.new()
	controller.state = _queue_state()
	for tile in [Vector2i(5,3), Vector2i(5,4), Vector2i(6,3), Vector2i(6,4), Vector2i(7,3)]:
		_check(controller._queue_place_action(tile, "basic")["ok"], "Five-action fixture must queue")
	var sixth: Dictionary = controller._queue_place_action(Vector2i(7,4), "basic")
	_check(not sixth["ok"] and sixth["reason"] == "action limit reached", "Configured human budget must reject sixth action")
	controller.hovered_tile = Vector2i(7,3)
	controller._recompute_hover_context()
	_check(controller.hover_invalid_reason.is_empty(), "Accepted queued tile must not display an invalid marker")
	_check(controller._hover_card_text().begins_with("Growth Queued"), "Queued hover must explain success and cancellation")
	_check(controller._queue_place_action(Vector2i(7,3), "basic")["ok"], "A full queue must still allow cancellation")
	_check(controller.queued_actions.size() == 4, "Cancellation frees the action slot")
	controller.free()

func _heart_rewards() -> void:
	for allied in [false, true]:
		var state: GameState = GameState.new()
		state.spawn_block(1, Vector2i(1,1), true, 13)
		state.add_owner(2, "Other", 5, GameState.TEAM_PLAYER if allied else GameState.TEAM_ENEMY)
		state.spawn_block(2, Vector2i(8,8), true, 0)
		var before: int = state.players[1]["nutrients"]
		var report: Dictionary = Combat.new().resolve_with_report([], state)
		var expected: int = 0 if allied else Combat.HEART_DEFEAT_BURST_ENERGY
		_check(report["player_heart_burst"] == expected and state.players[1]["nutrients"] == before + expected, "Lone-heart reward must respect hostility")
		_check(Combat.new().resolve_with_report([], state)["player_heart_burst"] == 0, "Defeated owner cannot pay twice")

func _feedback() -> void:
	var feedback: EnemyFeedback = EnemyFeedback.new()
	_check(feedback.build_turn_line([{"type":"pass"}], []) == "Enemy ooze waits", "Pass must not be reported as growth")
	var mixed: String = feedback.build_turn_line([{"type":"pass"}, {"type":"place_tile"}], [])
	_check(mixed.contains("1/1") and mixed.contains("spread 1"), "Mixed pass/actions count only actual changes")

func _final_turn() -> void:
	var state: GameState = GameState.new()
	state.spawn_block(1, Vector2i(1,1), true, 13)
	state.add_owner(2, "Enemy", 5)
	state.spawn_block(2, Vector2i(8,8), true, 13)
	state.turn_limit = 30
	state.turn_index = 30
	_check(LevelDirector.new().check_victory_or_loss(state)["status"] == "loss", "Unfinished objective at deadline loses")
	state.door_hp = 0
	_check(LevelDirector.new().check_victory_or_loss(state)["status"] == "victory", "Completing objective on final turn wins")
	state.remove_block(1)
	_check(LevelDirector.new().check_victory_or_loss(state)["status"] == "loss", "Losing own heart still wins tie precedence")

func _evaluation_contract() -> void:
	_check(EVALUATION.outcome_bonus("loss", false) < EVALUATION.outcome_bonus("ongoing", true), "Actual loss must score below an unresolved run")
	_check(EVALUATION.outcome_bonus("loss", true) == -8.0, "Loss receives the full penalty")
	_check(EVALUATION.outcome_bonus("victory", true) > 0.0, "Victory earns positive outcome credit")
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 6
	state.spawn_block(1, Vector2i(2,2), true, 13)
	state.add_owner(2, "Enemy", 5)
	state.add_owner(3, "Ally", 5, GameState.TEAM_PLAYER)
	state.door_hp = 12
	var initial: GameState = state.copy_state()
	state.door_hp = 6
	_check(EVALUATION.door_progress(state, initial, 1) == 0.5 and EVALUATION.door_progress(state, initial, 3) == 0.5, "Eligible teams receive door progress")
	_check(EVALUATION.door_progress(state, initial, 2) == 0.0, "Hostile enemy receives no door credit")
	var walls: Array = []
	for y in range(state.height):
		walls.append([4,y])
	state.set_walls(walls)
	_check(EVALUATION.owner_distance(state, 1, [Vector2i(6,2)]) == BoardTopology.UNREACHABLE_DISTANCE, "Evaluation cannot report progress through a sealed wall")

func _ranged_threat() -> void:
	var state: GameState = GameState.new()
	state.width = 10
	state.height = 6
	var heart: int = state.spawn_block(1, Vector2i(2,2), true, 13)
	state.add_owner(2, "Enemy", 5)
	var ranged: int = state.spawn_block(2, Vector2i(6,2), true, 13, "ranged")
	state.blocks[ranged]["range"] = 4
	state.blocks[ranged]["damage"] = 3
	state.set_walls([[4,0],[4,1],[4,2],[4,3],[4,4],[4,5]])
	var ai: OozeAI = OozeAI.new()
	var threat: int = ai._local_threat_score(state, 1, Vector2i(2,2))
	var cached: Dictionary = ai._build_local_threat_map(state, 1)
	_check(threat > 0 and cached.get(Vector2i(2,2), 0) == threat, "Cached and direct threat must see actual range-four attacks over walls")
	_check(ai._local_threat_score(state, 1, Vector2i(0,0)) == 0, "Distant tile remains outside ranged threat")
	Combat.new().resolve([], state)
	_check(state.blocks[heart]["hp"] < 13, "Threat fixture must deal real combat damage")

func _combat_saving() -> void:
	var state: GameState = GameState.new()
	state.width = 12
	state.height = 10
	state.spawn_block(1, Vector2i(2,3), true, 13)
	var target: int = state.spawn_block(1, Vector2i(4,3), false, 9)
	state.add_owner(2, "Enemy", 2)
	state.players[2]["max_actions"] = 1
	state.spawn_block(2, Vector2i(6,4), true, 13)
	state.spawn_block(2, Vector2i(6,3), false, 9)
	state.spawn_block(2, Vector2i(5,3), false, 9)
	var ai: OozeAI = OozeAI.new()
	var actions: Array = ai.choose_actions(state, 2, 1)
	_check(actions.is_empty(), "Cash-poor engaged AI must save for an affordable next-turn combat role")
	var next: GameState = TickSystem.new().step(state, actions)
	actions = ai.choose_actions(next, 2, 1)
	_check(not actions.is_empty(), "Saving must end when the combat role becomes affordable")
	next = TickSystem.new().step(next, actions)
	_check(next.blocks[target]["hp"] < 9, "The saved energy must produce real frontline damage")
	state.players[2]["income_delta"] = -Economy.BASE_TURN_ENERGY
	_check(not ai.choose_actions(state, 2, 1).is_empty(), "Zero-income AI must not wait for money that never arrives")

func _combat_feedback_events() -> void:
	var state: GameState = _queue_state()
	state.add_owner(2, "Enemy", 20)
	var attacker: int = state.spawn_block(2, Vector2i(6,3), false, 10, "melee")
	state.blocks[attacker]["damage"] = 3
	state.spawn_block(2, Vector2i(9,3), true, 13)
	var place: Dictionary = {"type":"place_tile", "owner":1, "target":Vector2i(5,3), "tile_type":"basic", "cost":2, "min_adjacent":1}
	var report: Dictionary = Combat.new().resolve_with_report([place], state)
	var events: Array = report.get("combat_events", [])
	_check(events.size() == 1, "Feedback must include damage to a tile purchased this turn: %s / %s" % [str(events), str(report.get("failed_actions", []))])
	if events.size() == 1:
		_check(events[0]["tile"] == Vector2i(5,3) and events[0]["amount"] == 9 - int(state.get_block_at(Vector2i(5,3))["hp"]), "Damage feedback must match actual HP lost")
	state.blocks[attacker]["hp"] = 0
	report = Combat.new().resolve_with_report([], state)
	var has_dissolved: bool = false
	for event in report.get("combat_events", []):
		if event["tile"] == Vector2i(6,3) and event["kind"] == "dissolved":
			has_dissolved = true
	_check(has_dissolved, "Removed tiles need dissolution feedback")
	var clean: GameState = _queue_state()
	report = Combat.new().resolve_with_report([{"type":"convert_tile", "owner":1, "block_id":2, "to_type":"gather", "energy_delta":4}], clean)
	_check(report.get("combat_events", []).is_empty(), "Conversion HP changes must not appear as combat damage")

func _render_geometry() -> void:
	var renderer: RefCounted = DYNAMIC.new()
	var mesh: ArrayMesh = renderer._build_ooze_surface_mesh(FlatGround.new(), 4.0, 4.0, 0.01)
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for normal in normals:
		_check(normal.dot(Vector3.UP) > 0.99, "Ooze surface normal must face upward on flat ground")
	var assets: RefCounted = ASSETS.new()
	assets.load_manifest("res://data/world3d_asset_manifest.json")
	for role in ["core", "melee", "ranged", "defense", "gather"]:
		var key: String = renderer._growth_asset_key_for_role(role)
		var node: Node3D = assets.instantiate_asset_scene(key)
		_check(node != null, "Production growth asset must load for " + role)
		if node == null:
			continue
		node.transform = assets.normalized_asset_transform(key, Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(2,3,2)), Vector3.ZERO))
		renderer.fit_growth_to_tile(node, Vector3(4,0,5), 1.0, 0.1)
		var bounds: AABB = node.transform * renderer.growth_local_bounds(node)
		_check(maxf(bounds.size.x, bounds.size.z) <= 0.821 and bounds.size.y <= 1.101, "Actual growth bounds exceed tactical footprint for " + role)
		_check(absf(bounds.position.y - 0.1) < 0.001, "Fitted growth must sit on terrain for " + role)
		node.free()

func _markers() -> void:
	var layer: RefCounted = MARKERS.new()
	var root: Node3D = Node3D.new()
	var state: GameState = _queue_state()
	var empty: String = layer.make_marker_stamp(state, Vector2i(-1,-1), Vector2i(-1,-1), {}, [], {}, "")
	var legal: Array = [Vector2i(5,3)]
	var intents: Array = [{"type":"place_tile", "owner":2, "target":Vector2i(8,3), "tile_type":"basic"}]
	var changed: String = layer.make_marker_stamp(state, Vector2i(-1,-1), Vector2i(-1,-1), {}, [], {}, "", legal, intents)
	_check(empty != changed, "Legal moves and enemy intents must invalidate 3D marker cache")
	layer.rebuild_markers(root, state, 1.0, Vector3.ZERO, {}, Vector2i(-1,-1), Vector2i(-1,-1), {}, [], {}, "", legal, intents)
	_check(root.get_child_count() == 2, "3D board must create both legal and enemy-intent markers")
	root.free()
