extends RefCounted

# Explicit test match: 2v2, equal ordinary budgets, normal batched turns.
static func build(seed_value: int) -> GameState:
	var flow: Node = load("res://scripts/systems/RunFlow.gd").new()
	flow.current_level = 3
	var options: Dictionary = flow.build_level_options()
	options.merge({"ally_ai_count":1,"enemy_cluster_count":2,"player_cluster_count":1,
		"player_start_energy":14,"ally_start_energy":14,"enemy_start_energy":14,
		"player_income_delta":2,"ally_income_delta":2,"enemy_income_delta":2,
		"player_max_actions":3,"ally_max_actions":3,"enemy_max_actions":3,
		"player_heart_max":1,"ally_heart_max":1,"enemy_heart_max":1,
		"player_cluster_size_min":5,"player_cluster_size_max":5,
		"ally_cluster_size_min":5,"ally_cluster_size_max":5,
		"enemy_cluster_size_min":5,"enemy_cluster_size_max":5,
		"turn_limit":30,"dev_player_immortal":false,"dev_spectator_mode":false},true)
	var templates: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms/templates.json"))
	var state: GameState = LevelGenerator.new().build_level(3,seed_value,templates,[],options)
	flow.free()
	return state
