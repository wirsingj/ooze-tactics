extends SceneTree

const DEFAULT_CONFIG_PATH: String = "res://tools/ai_tuner_config.json"
const DEFAULT_OUTPUT_DIR: String = "user://ai_tuner_output"
const ROLE_TYPES: Array[String] = ["basic", "melee", "ranged", "defense", "gather"]
const PHASE_CHECKPOINT_DEFAULTS: Array = [15, 50, 100]
const MIN_EXPAND_ADJACENT: int = 1
const MAX_DISTANCE_SENTINEL: int = 999999

var _args: Dictionary = {}

func _init() -> void:
	var exit_code: int = _run()
	quit(exit_code)

func _run() -> int:
	_args = _parse_cli_args()
	if bool(_args.get("help", false)):
		_print_usage()
		return 0

	var config_path: String = String(_args.get("config", DEFAULT_CONFIG_PATH))
	var config: Dictionary = _load_config(config_path)
	if config.is_empty():
		printerr("AI tuner: failed to load config at %s" % config_path)
		return 1

	_apply_cli_overrides(config)
	var run_result: Dictionary = _run_tuning(config)
	if bool(run_result.get("ok", false)):
		print(_build_terminal_summary(run_result))
		return 0
	printerr("AI tuner failed: %s" % String(run_result.get("error", "unknown error")))
	return 1

func _print_usage() -> void:
	print("Ooze Tactics AI Tuner")
	print("Usage:")
	print("  godot --headless --path <repo> -s res://tools/ai_tuner.gd -- --config=res://tools/ai_tuner_config.json")
	print("Optional flags:")
	print("  --runs=<int>                 Override scenario runs-per-seed")
	print("  --max-candidates=<int>       Cap total candidate sets")
	print("  --random-iters=<int>         Override random candidate count")
	print("  --output-dir=<path>          Output directory (res:// or absolute)")
	print("  --help")

func _parse_cli_args() -> Dictionary:
	var parsed: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for token in args:
		var arg: String = String(token)
		if arg == "--help" or arg == "-h":
			parsed["help"] = true
			continue
		if not arg.begins_with("--"):
			continue
		var eq: int = arg.find("=")
		if eq < 0:
			parsed[arg.substr(2, arg.length() - 2)] = true
			continue
		var key: String = arg.substr(2, eq - 2)
		var value: String = arg.substr(eq + 1, arg.length() - (eq + 1))
		parsed[key] = value
	return parsed

func _load_config(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}

func _apply_cli_overrides(config: Dictionary) -> void:
	if _args.has("runs"):
		config["runs_per_seed"] = maxi(1, int(_args["runs"]))
	if _args.has("output-dir"):
		config["output_dir"] = String(_args["output-dir"])

	if not config.has("search"):
		config["search"] = {}
	var search: Dictionary = config["search"]
	if _args.has("max-candidates"):
		search["max_total_candidates"] = maxi(1, int(_args["max-candidates"]))
	if _args.has("random-iters"):
		search["random_iterations"] = maxi(0, int(_args["random-iters"]))
	config["search"] = search

func _run_tuning(config: Dictionary) -> Dictionary:
	var room_templates: Array = _load_room_templates()
	if room_templates.is_empty():
		return {"ok": false, "error": "room template list is empty"}

	var checkpoints: Array = _checkpoint_list_from_config(config)
	var scenarios: Array = _normalized_scenarios(config)
	if scenarios.is_empty():
		return {"ok": false, "error": "no scenarios configured"}

	var candidates: Array = _build_candidates(config)
	if candidates.is_empty():
		return {"ok": false, "error": "no candidates generated"}
	var workload: Dictionary = _estimate_workload(candidates, scenarios, checkpoints)
	print(
		"Planned workload: %d candidates, %d simulations, estimated %d actor-turns." % [
			int(workload.get("candidate_count", 0)),
			int(workload.get("simulation_count", 0)),
			int(workload.get("estimated_actor_turns", 0)),
		]
	)

	var candidate_results: Array = []
	for candidate in candidates:
		var eval: Dictionary = _evaluate_candidate(candidate, scenarios, checkpoints, room_templates)
		candidate_results.append(eval)
		print("Candidate %s -> score %.2f" % [String(eval.get("id", "?")), float(eval.get("score", 0.0))])

	candidate_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", -999999.0)) > float(b.get("score", -999999.0))
	)

	var top_n: int = maxi(1, int(config.get("top_n", 5)))
	var baseline: Dictionary = _find_candidate_result(candidate_results, "baseline")
	var top_candidates: Array = candidate_results.slice(0, mini(top_n, candidate_results.size()))
	var recommendations: Array = _build_recommendations(baseline, top_candidates)

	var report: Dictionary = {
		"ok": true,
		"generated_at": Time.get_datetime_string_from_system(),
		"config_used": config,
		"checkpoints": checkpoints,
		"workload": workload,
		"scenario_count": scenarios.size(),
		"candidate_count": candidate_results.size(),
		"baseline": baseline,
		"top_candidates": top_candidates,
		"all_candidates": candidate_results,
		"recommendations": recommendations,
	}

	var output_dir: String = String(config.get("output_dir", DEFAULT_OUTPUT_DIR))
	var saved_paths: Dictionary = _write_reports(output_dir, report)
	report["output"] = saved_paths
	return report

func _load_room_templates() -> Array:
	var file: FileAccess = FileAccess.open("res://data/rooms/templates.json", FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		return (parsed as Array).duplicate(true)
	return []

func _checkpoint_list_from_config(config: Dictionary) -> Array:
	var raw: Array = config.get("checkpoints", PHASE_CHECKPOINT_DEFAULTS)
	var out: Array = []
	for item in raw:
		var turn: int = maxi(1, int(item))
		if not out.has(turn):
			out.append(turn)
	out.sort()
	return out

func _max_checkpoint_turn(checkpoints: Array) -> int:
	var max_turn: int = 0
	for checkpoint in checkpoints:
		max_turn = maxi(max_turn, int(checkpoint))
	return max_turn

func _normalized_scenarios(config: Dictionary) -> Array:
	var input_scenarios: Array = config.get("scenarios", [])
	var out: Array = []
	for i in range(input_scenarios.size()):
		var src: Dictionary = input_scenarios[i]
		var scenario: Dictionary = {
			"name": String(src.get("name", "scenario_%d" % i)),
			"level_index": maxi(1, int(src.get("level_index", 3))),
			"player_team_size": clampi(int(src.get("player_team_size", 2)), 1, 4),
			"enemy_team_size": clampi(int(src.get("enemy_team_size", 2)), 1, 4),
			"turn_limit": maxi(0, int(src.get("turn_limit", 100))),
			"door_hp": maxi(1, int(src.get("door_hp", 32))),
			"runs_per_seed": maxi(1, int(src.get("runs_per_seed", int(config.get("runs_per_seed", 2))))),
			"seeds": src.get("seeds", [1337, 2024]),
			"template_ids": src.get("template_ids", []),
			"enemies_allied": bool(src.get("enemies_allied", true)),
			"stop_at_last_checkpoint": bool(src.get("stop_at_last_checkpoint", true)),
			"outcome_check_interval": maxi(1, int(src.get("outcome_check_interval", 8))),
		}
		out.append(scenario)
	return out

func _estimate_workload(candidates: Array, scenarios: Array, checkpoints: Array) -> Dictionary:
	var simulation_count: int = 0
	var actor_turns: int = 0
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		var seeds: Array = scenario.get("seeds", [1337])
		var runs_per_seed: int = maxi(1, int(scenario.get("runs_per_seed", 1)))
		var runs_for_scenario: int = seeds.size() * runs_per_seed
		var step_cap: int = _scenario_step_cap(scenario, checkpoints)
		simulation_count += runs_for_scenario * candidates.size()
		actor_turns += runs_for_scenario * step_cap * candidates.size()
	return {
		"candidate_count": candidates.size(),
		"simulation_count": simulation_count,
		"estimated_actor_turns": actor_turns,
	}

func _scenario_step_cap(scenario: Dictionary, checkpoints: Array) -> int:
	var max_checkpoint_turn: int = _max_checkpoint_turn(checkpoints)
	var stop_at_last_checkpoint: bool = bool(scenario.get("stop_at_last_checkpoint", true))
	var scenario_turn_limit: int = maxi(0, int(scenario.get("turn_limit", 100)))
	var sim_turn_cap: int = scenario_turn_limit
	if stop_at_last_checkpoint and max_checkpoint_turn > 0:
		if sim_turn_cap <= 0:
			sim_turn_cap = max_checkpoint_turn
		else:
			sim_turn_cap = mini(sim_turn_cap, max_checkpoint_turn)
	if sim_turn_cap <= 0:
		sim_turn_cap = maxi(40, max_checkpoint_turn)
	return sim_turn_cap

func _build_candidates(config: Dictionary) -> Array:
	var candidates: Array = []
	var search: Dictionary = config.get("search", {})
	var fixed: Dictionary = config.get("fixed_overrides", {})
	var max_total: int = maxi(1, int(search.get("max_total_candidates", 48)))

	var baseline: Dictionary = {
		"id": "baseline",
		"label": "Baseline",
		"overrides": fixed.duplicate(true),
	}
	candidates.append(baseline)

	var grid_parameters: Dictionary = search.get("grid_parameters", {})
	var grid_candidates: Array = _build_grid_candidates(grid_parameters, int(search.get("max_grid_candidates", 24)))
	for c in grid_candidates:
		var merged: Dictionary = fixed.duplicate(true)
		merged.merge(c, true)
		candidates.append({
			"id": "grid_%d" % candidates.size(),
			"label": "Grid %d" % candidates.size(),
			"overrides": merged,
		})
		if candidates.size() >= max_total:
			return candidates

	var random_parameters: Dictionary = search.get("random_parameters", {})
	var random_seed: int = int(search.get("random_seed", 1337))
	var random_iterations: int = maxi(0, int(search.get("random_iterations", 16)))
	var random_candidates: Array = _build_random_candidates(random_parameters, random_iterations, random_seed)
	for c in random_candidates:
		var merged_random: Dictionary = fixed.duplicate(true)
		merged_random.merge(c, true)
		candidates.append({
			"id": "rand_%d" % candidates.size(),
			"label": "Random %d" % candidates.size(),
			"overrides": merged_random,
		})
		if candidates.size() >= max_total:
			return candidates

	return _dedupe_candidates(candidates)

func _build_grid_candidates(grid_parameters: Dictionary, max_grid_candidates: int) -> Array:
	var keys: Array = grid_parameters.keys()
	if keys.is_empty():
		return []
	keys.sort()

	var value_lists: Array = []
	for key_variant in keys:
		var key: String = String(key_variant)
		var values: Array = grid_parameters.get(key, [])
		if values.is_empty():
			continue
		value_lists.append({"key": key, "values": values})
	if value_lists.is_empty():
		return []

	var total_combinations: int = 1
	for entry in value_lists:
		total_combinations *= maxi(1, int((entry as Dictionary).get("values", []).size()))
	if total_combinations <= 0:
		return []

	var capped: int = maxi(1, max_grid_candidates)
	var step: int = maxi(1, int(ceil(float(total_combinations) / float(capped))))
	var out: Array = []
	for combo_index in range(0, total_combinations):
		if combo_index % step != 0:
			continue
		var candidate: Dictionary = {}
		var cursor: int = combo_index
		for entry in value_lists:
			var item: Dictionary = entry
			var vals: Array = item.get("values", [])
			var size: int = maxi(1, vals.size())
			var idx: int = cursor % size
			cursor = int(cursor / size)
			candidate[String(item.get("key", ""))] = vals[idx]
		out.append(candidate)
		if out.size() >= capped:
			break
	return out

func _build_random_candidates(random_parameters: Dictionary, iterations: int, random_seed: int) -> Array:
	if random_parameters.is_empty() or iterations <= 0:
		return []
	var keys: Array = random_parameters.keys()
	keys.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = random_seed
	var out: Array = []
	for _i in range(iterations):
		var candidate: Dictionary = {}
		for key_variant in keys:
			var key: String = String(key_variant)
			var spec: Dictionary = random_parameters.get(key, {})
			if spec.has("choices"):
				var choices: Array = spec.get("choices", [])
				if not choices.is_empty():
					candidate[key] = choices[rng.randi_range(0, choices.size() - 1)]
				continue
			var min_v: float = float(spec.get("min", 0.0))
			var max_v: float = float(spec.get("max", min_v))
			var step: float = float(spec.get("step", 1.0))
			var is_float: bool = bool(spec.get("float", false))
			if is_float:
				var samples: int = maxi(1, int(round((max_v - min_v) / maxf(step, 0.0001))))
				var idx: int = rng.randi_range(0, samples)
				candidate[key] = min_v + float(idx) * step
			else:
				var min_i: int = int(round(min_v))
				var max_i: int = int(round(max_v))
				var step_i: int = maxi(1, int(round(step)))
				var count: int = maxi(1, int(floor(float(max_i - min_i) / float(step_i))))
				var choice_i: int = rng.randi_range(0, count)
				candidate[key] = min_i + choice_i * step_i
		out.append(candidate)
	return out

func _dedupe_candidates(candidates: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for candidate in candidates:
		var overrides: Dictionary = (candidate as Dictionary).get("overrides", {})
		var signature: String = _candidate_signature(overrides)
		if seen.has(signature):
			continue
		seen[signature] = true
		out.append(candidate)
	return out

func _candidate_signature(overrides: Dictionary) -> String:
	var keys: Array = overrides.keys()
	keys.sort()
	var parts: Array[String] = []
	for key_variant in keys:
		var key: String = String(key_variant)
		parts.append("%s=%s" % [key, str(overrides[key])])
	return "|".join(parts)

func _evaluate_candidate(candidate: Dictionary, scenarios: Array, checkpoints: Array, room_templates: Array) -> Dictionary:
	var per_run: Array = []
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		var scenario_templates: Array = _select_templates_for_scenario(room_templates, scenario)
		if scenario_templates.is_empty():
			scenario_templates = room_templates
		var seeds: Array = scenario.get("seeds", [1337])
		var runs_per_seed: int = maxi(1, int(scenario.get("runs_per_seed", 1)))
		for seed_variant in seeds:
			var base_seed: int = int(seed_variant)
			for run_offset in range(runs_per_seed):
				var run_seed: int = base_seed + run_offset * 1013
				var run_result: Dictionary = _run_single_simulation(candidate, scenario, run_seed, checkpoints, scenario_templates)
				per_run.append(run_result)
	var aggregate: Dictionary = _aggregate_candidate_runs(per_run, checkpoints)
	return {
		"id": String(candidate.get("id", "candidate")),
		"label": String(candidate.get("label", "candidate")),
		"overrides": (candidate.get("overrides", {}) as Dictionary).duplicate(true),
		"score": float(aggregate.get("score", 0.0)),
		"score_by_category": aggregate.get("score_by_category", {}),
		"score_by_checkpoint": aggregate.get("score_by_checkpoint", {}),
		"pathology_counts": aggregate.get("pathology_counts", {}),
		"runs": per_run,
	}

func _run_single_simulation(candidate: Dictionary, scenario: Dictionary, run_seed: int, checkpoints: Array, templates: Array) -> Dictionary:
	var generator: LevelGenerator = LevelGenerator.new()
	var level_options: Dictionary = {
		"player_cluster_count": 0,
		"ally_ai_count": int(scenario.get("player_team_size", 2)),
		"enemy_cluster_count": int(scenario.get("enemy_team_size", 2)),
		"player_start_energy": 0,
		"ally_start_energy": 12,
		"enemy_start_energy": 12,
		"enemies_allied": bool(scenario.get("enemies_allied", true)),
		"dev_player_immortal": false,
		"dev_spectator_mode": true,
		"turn_limit": maxi(0, int(scenario.get("turn_limit", 100))),
		"door_hp": maxi(1, int(scenario.get("door_hp", 32))),
	}
	var state: GameState = generator.build_level(
		int(scenario.get("level_index", 3)),
		run_seed,
		templates,
		[],
		level_options
	)
	state.spectator_mode = true

	var ai: OozeAI = OozeAI.new()
	ai.clear_tuning()
	ai.set_tuning(candidate.get("overrides", {}))

	var tick: TickSystem = TickSystem.new()
	var director: LevelDirector = LevelDirector.new()
	var cycle: Dictionary = _new_actor_cycle(state)
	var tracker: Dictionary = _new_tracker(state)
	var checkpoint_scores: Dictionary = {}
	var checkpoint_cursor: int = 0
	var checkpoint_list: Array = checkpoints.duplicate()

	var outcome: Dictionary = {"status": "ongoing"}
	var stop_at_last_checkpoint: bool = bool(scenario.get("stop_at_last_checkpoint", true))
	var sim_turn_cap: int = _scenario_step_cap(scenario, checkpoint_list)
	var safety_turn_cap: int = maxi(40, sim_turn_cap + 4)
	var outcome_check_interval: int = maxi(1, int(scenario.get("outcome_check_interval", 8)))
	var steps_since_outcome_check: int = 0
	while state.turn_index < safety_turn_cap:
		var owner: int = _next_actor_owner(state, cycle)
		if owner <= 0:
			break
		var actions: Array = ai.choose_actions(state, owner, MIN_EXPAND_ADJACENT)
		if actions.is_empty():
			actions = [{"type": "pass", "owner": owner}]

		var next_state: GameState = tick.step(state, actions)
		var report: Dictionary = next_state.last_resolution_report
		_track_turn(tracker, state, next_state, report, owner)
		state = next_state
		_advance_actor_cycle(state, cycle)
		steps_since_outcome_check += 1

		var captured_checkpoint: bool = false
		while checkpoint_cursor < checkpoint_list.size() and state.turn_index >= int(checkpoint_list[checkpoint_cursor]):
			var turn_key: String = str(int(checkpoint_list[checkpoint_cursor]))
			checkpoint_scores[turn_key] = _score_state(state, tracker, int(checkpoint_list[checkpoint_cursor]))
			checkpoint_cursor += 1
			captured_checkpoint = true

		if stop_at_last_checkpoint and checkpoint_cursor >= checkpoint_list.size():
			break

		if captured_checkpoint or steps_since_outcome_check >= outcome_check_interval:
			outcome = director.check_victory_or_loss(state)
			steps_since_outcome_check = 0
			if String(outcome.get("status", "ongoing")) != "ongoing":
				break

	if String(outcome.get("status", "ongoing")) == "ongoing":
		outcome = director.check_victory_or_loss(state)

	while checkpoint_cursor < checkpoint_list.size():
		var missing_turn: int = int(checkpoint_list[checkpoint_cursor])
		checkpoint_scores[str(missing_turn)] = _score_state(state, tracker, missing_turn)
		checkpoint_cursor += 1

	return {
		"scenario": String(scenario.get("name", "")),
		"seed": run_seed,
		"final_turn": state.turn_index,
		"outcome": outcome,
		"checkpoints": checkpoint_scores,
	}

func _select_templates_for_scenario(room_templates: Array, scenario: Dictionary) -> Array:
	var wanted: Array = scenario.get("template_ids", [])
	if wanted.is_empty():
		return room_templates.duplicate(true)
	var wanted_set: Dictionary = {}
	for id_variant in wanted:
		wanted_set[String(id_variant)] = true
	var out: Array = []
	for template_variant in room_templates:
		var room: Dictionary = template_variant
		var template_id: String = String(room.get("id", ""))
		if wanted_set.has(template_id):
			out.append(room.duplicate(true))
	return out

func _aggregate_candidate_runs(per_run: Array, checkpoints: Array) -> Dictionary:
	if per_run.is_empty():
		return {"score": 0.0, "score_by_category": {}, "score_by_checkpoint": {}, "pathology_counts": {}}

	var total_score: float = 0.0
	var total_samples: int = 0
	var category_sums: Dictionary = {}
	var checkpoint_sums: Dictionary = {}
	var pathology_sums: Dictionary = {}

	for run_variant in per_run:
		var run: Dictionary = run_variant
		var checkpoint_scores: Dictionary = run.get("checkpoints", {})
		for cp in checkpoints:
			var key: String = str(int(cp))
			if not checkpoint_scores.has(key):
				continue
			var snapshot: Dictionary = checkpoint_scores[key]
			var score: float = float(snapshot.get("total_score", 0.0))
			total_score += score
			total_samples += 1
			checkpoint_sums[key] = float(checkpoint_sums.get(key, 0.0)) + score

			var categories: Dictionary = snapshot.get("category_scores", {})
			for category_key in categories.keys():
				var cat: String = String(category_key)
				category_sums[cat] = float(category_sums.get(cat, 0.0)) + float(categories[cat])

			var pathologies: Dictionary = snapshot.get("pathology", {})
			for pathology_key in pathologies.keys():
				var pathology: String = String(pathology_key)
				pathology_sums[pathology] = float(pathology_sums.get(pathology, 0.0)) + float(pathologies[pathology])

	var score_by_category: Dictionary = {}
	for category_key in category_sums.keys():
		score_by_category[String(category_key)] = float(category_sums[category_key]) / maxf(1.0, float(total_samples))

	var score_by_checkpoint: Dictionary = {}
	for checkpoint_key in checkpoint_sums.keys():
		var cp_value: int = int(checkpoint_key)
		var divisor: int = 0
		for run_variant in per_run:
			var run: Dictionary = run_variant
			if (run.get("checkpoints", {}) as Dictionary).has(str(cp_value)):
				divisor += 1
		score_by_checkpoint[String(checkpoint_key)] = float(checkpoint_sums[checkpoint_key]) / maxf(1.0, float(divisor))

	var pathology_counts: Dictionary = {}
	for pathology_key in pathology_sums.keys():
		pathology_counts[String(pathology_key)] = float(pathology_sums[pathology_key]) / maxf(1.0, float(total_samples))

	return {
		"score": total_score / maxf(1.0, float(total_samples)),
		"score_by_category": score_by_category,
		"score_by_checkpoint": score_by_checkpoint,
		"pathology_counts": pathology_counts,
	}

func _new_actor_cycle(state: GameState) -> Dictionary:
	return {
		"order": [],
		"index": 0,
		"round_index": 0,
		"run_seed": int(state.run_seed),
		"level_index": int(state.level_index),
	}

func _next_actor_owner(state: GameState, cycle: Dictionary) -> int:
	for _attempt in range(0, 2):
		if (cycle.get("order", []) as Array).is_empty():
			_start_new_actor_round(state, cycle)
			if (cycle.get("order", []) as Array).is_empty():
				return -1
		var order: Array = cycle.get("order", [])
		var idx: int = int(cycle.get("index", 0))
		while idx < order.size():
			var owner_id: int = int(order[idx])
			if _is_owner_valid_actor(state, owner_id):
				cycle["index"] = idx
				return owner_id
			idx += 1
		_start_new_actor_round(state, cycle)
	return -1

func _advance_actor_cycle(state: GameState, cycle: Dictionary) -> void:
	var idx: int = int(cycle.get("index", 0)) + 1
	var order: Array = cycle.get("order", [])
	if idx >= order.size():
		_start_new_actor_round(state, cycle)
		return
	cycle["index"] = idx

func _start_new_actor_round(state: GameState, cycle: Dictionary) -> void:
	var owners: Array = _build_actor_cycle_order(state)
	if owners.is_empty():
		cycle["order"] = []
		cycle["index"] = 0
		return
	var round_index: int = int(cycle.get("round_index", 0))
	var round_seed: int = int(state.run_seed) + int(state.level_index * 4099) + int(round_index * 7919)
	cycle["order"] = _shuffle_owner_order(owners, round_seed)
	cycle["index"] = 0
	cycle["round_index"] = round_index + 1

func _build_actor_cycle_order(state: GameState) -> Array:
	var owners: Array = []
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID:
			continue
		if not _is_owner_valid_actor(state, owner_id):
			continue
		owners.append(owner_id)
	owners.sort_custom(func(a: int, b: int) -> bool:
		var ta: int = state.get_owner_team(a)
		var tb: int = state.get_owner_team(b)
		if ta != tb:
			return ta < tb
		return a < b
	)
	return owners

func _shuffle_owner_order(owners: Array, seed_value: int) -> Array:
	var shuffled: Array = owners.duplicate()
	if shuffled.size() <= 1:
		return shuffled
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	return shuffled

func _is_owner_valid_actor(state: GameState, owner_id: int) -> bool:
	if not state.players.has(owner_id):
		return false
	if not bool(state.players[owner_id].get("alive", true)):
		return false
	if not bool(state.players[owner_id].get("ai_controlled", true)):
		return false
	return _owner_has_blocks(state, owner_id)

func _owner_has_blocks(state: GameState, owner_id: int) -> bool:
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		if int(block.get("owner", -1)) == owner_id:
			return true
	return false

func _new_tracker(state: GameState) -> Dictionary:
	return {
		"initial_state": state.copy_state(),
		"actions_applied": 0,
		"actions_failed": 0,
		"pass_actions": 0,
		"avg_energy_accum": 0.0,
		"energy_samples": 0,
	}

func _track_turn(tracker: Dictionary, _prior_state: GameState, next_state: GameState, report: Dictionary, _owner: int) -> void:
	var applied_actions: Array = report.get("applied_actions", [])
	var failed_actions: Array = report.get("failed_actions", [])
	tracker["actions_applied"] = int(tracker.get("actions_applied", 0)) + applied_actions.size()
	tracker["actions_failed"] = int(tracker.get("actions_failed", 0)) + failed_actions.size()
	for action_variant in applied_actions:
		var action: Dictionary = action_variant
		if String(action.get("type", "")) == "pass":
			tracker["pass_actions"] = int(tracker.get("pass_actions", 0)) + 1

	var avg_energy: float = _average_ai_energy(next_state)
	tracker["avg_energy_accum"] = float(tracker.get("avg_energy_accum", 0.0)) + avg_energy
	tracker["energy_samples"] = int(tracker.get("energy_samples", 0)) + 1

func _score_state(state: GameState, tracker: Dictionary, checkpoint_turn: int) -> Dictionary:
	var metrics: Dictionary = _collect_metrics(state, tracker, checkpoint_turn)
	var category_scores: Dictionary = _category_scores(metrics, checkpoint_turn)
	var total_score: float = _weighted_total_score(category_scores)
	return {
		"turn": checkpoint_turn,
		"metrics": metrics,
		"category_scores": category_scores,
		"total_score": total_score,
		"pathology": metrics.get("pathology", {}),
	}

func _collect_metrics(state: GameState, tracker: Dictionary, checkpoint_turn: int) -> Dictionary:
	var ai_owners: Array = _ai_owner_ids(state)
	var ai_owner_set: Dictionary = {}
	for owner_variant in ai_owners:
		ai_owner_set[int(owner_variant)] = true

	var type_counts: Dictionary = {"basic": 0, "melee": 0, "ranged": 0, "defense": 0, "gather": 0}
	var frontline_counts: Dictionary = {"basic": 0, "melee": 0, "ranged": 0, "defense": 0, "gather": 0}
	var tier_counts: Dictionary = {"1": 0, "2": 0, "3": 0}
	var total_tiles: int = 0
	var specialized_tiles: int = 0
	var low_support_tiles: int = 0
	var supported_tiles: int = 0
	var backline_specialized: int = 0
	var resource_gather_tiles: int = 0
	var frontline_gather_tiles: int = 0
	var exposed_ranged_tiles: int = 0

	var position_owner_index: Dictionary = {}
	var hostile_positions_by_owner: Dictionary = {}
	var resource_tiles: Dictionary = {}
	for node_variant in state.resource_nodes:
		var node: Dictionary = node_variant
		var node_pos: Vector2i = node.get("pos", Vector2i(-1, -1))
		resource_tiles[_tile_key(node_pos)] = true

	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		position_owner_index[_tile_key(pos)] = int(block.get("owner", -1))

	for owner_variant in ai_owners:
		var owner_id: int = int(owner_variant)
		var hostile_positions: Array = []
		for block_variant in state.blocks.values():
			var block: Dictionary = block_variant
			var other_owner: int = int(block.get("owner", 0))
			if other_owner == owner_id:
				continue
			if not state.are_hostile(owner_id, other_owner):
				continue
			hostile_positions.append(block.get("pos", Vector2i(-1, -1)))
		hostile_positions_by_owner[owner_id] = hostile_positions

	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var owner: int = int(block.get("owner", 0))
		if not ai_owner_set.has(owner):
			continue
		total_tiles += 1
		var tile_type: String = String(block.get("tile_type", "basic"))
		type_counts[tile_type] = int(type_counts.get(tile_type, 0)) + 1
		var tier: int = int(block.get("upgrade_tier", 0))
		if tile_type != "basic":
			specialized_tiles += 1
			tier_counts[str(clampi(tier, 1, 3))] = int(tier_counts.get(str(clampi(tier, 1, 3)), 0)) + 1

		var pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		var nearest_enemy_dist: int = _nearest_distance_to_positions(pos, hostile_positions_by_owner.get(owner, []))
		var ally_adjacent: int = _adjacent_allied_count_from_index(owner, pos, position_owner_index)
		if ally_adjacent <= 1:
			low_support_tiles += 1
		if ally_adjacent >= 2:
			supported_tiles += 1

		if nearest_enemy_dist <= 2:
			frontline_counts[tile_type] = int(frontline_counts.get(tile_type, 0)) + 1
		if tile_type != "basic" and nearest_enemy_dist >= 6:
			backline_specialized += 1
		if tile_type == "gather":
			if resource_tiles.has(_tile_key(pos)):
				resource_gather_tiles += 1
			if nearest_enemy_dist <= 3:
				frontline_gather_tiles += 1
		if tile_type == "ranged" and nearest_enemy_dist <= 2:
			exposed_ranged_tiles += 1

	var objective: Dictionary = _objective_metrics(state, tracker.get("initial_state", state))
	var pass_rate: float = float(tracker.get("pass_actions", 0)) / maxf(1.0, float(tracker.get("actions_applied", 0)))
	var fail_rate: float = float(tracker.get("actions_failed", 0)) / maxf(1.0, float(tracker.get("actions_applied", 0) + tracker.get("actions_failed", 0)))
	var avg_energy: float = float(tracker.get("avg_energy_accum", 0.0)) / maxf(1.0, float(tracker.get("energy_samples", 0)))

	return {
		"turn": checkpoint_turn,
		"total_tiles": total_tiles,
		"type_counts": type_counts,
		"frontline_counts": frontline_counts,
		"tier_counts": tier_counts,
		"specialized_ratio": float(specialized_tiles) / maxf(1.0, float(total_tiles)),
		"backline_specialized_ratio": float(backline_specialized) / maxf(1.0, float(maxi(1, specialized_tiles))),
		"low_support_ratio": float(low_support_tiles) / maxf(1.0, float(total_tiles)),
		"supported_ratio": float(supported_tiles) / maxf(1.0, float(total_tiles)),
		"resource_gather_tiles": resource_gather_tiles,
		"frontline_gather_tiles": frontline_gather_tiles,
		"exposed_ranged_tiles": exposed_ranged_tiles,
		"pass_rate": pass_rate,
		"fail_rate": fail_rate,
		"avg_energy": avg_energy,
		"objective": objective,
		"pathology": {
			"frontline_gather": frontline_gather_tiles,
			"exposed_ranged": exposed_ranged_tiles,
			"backline_specialized": backline_specialized,
			"high_fail_rate": 1 if fail_rate > 0.22 else 0,
		},
	}

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _nearest_distance_to_positions(origin: Vector2i, positions: Array) -> int:
	if positions.is_empty():
		return MAX_DISTANCE_SENTINEL
	var best: int = MAX_DISTANCE_SENTINEL
	for point_variant in positions:
		var point: Vector2i = point_variant
		var dist: int = abs(origin.x - point.x) + abs(origin.y - point.y)
		best = mini(best, dist)
	return best

func _adjacent_allied_count_from_index(owner_id: int, tile: Vector2i, position_owner_index: Dictionary) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var owner: int = int(position_owner_index.get(_tile_key(tile + step), -1))
		if owner == owner_id:
			count += 1
	return count

func _category_scores(metrics: Dictionary, checkpoint_turn: int) -> Dictionary:
	var type_counts: Dictionary = metrics.get("type_counts", {})
	var total_tiles: float = maxf(1.0, float(metrics.get("total_tiles", 0)))
	var ratios: Dictionary = {}
	for role in ROLE_TYPES:
		ratios[role] = float(type_counts.get(role, 0)) / total_tiles

	var role_targets: Dictionary = {"basic": 0.34, "melee": 0.20, "ranged": 0.18, "defense": 0.16, "gather": 0.12}
	var role_deviation: float = 0.0
	for role in ROLE_TYPES:
		role_deviation += absf(float(ratios.get(role, 0.0)) - float(role_targets.get(role, 0.0)))
	var role_balance: float = clampf(100.0 - role_deviation * 140.0, 0.0, 100.0)
	role_balance -= maxf(0.0, (float(ratios.get("ranged", 0.0)) - 0.34) * 220.0)
	role_balance -= maxf(0.0, (float(ratios.get("defense", 0.0)) - 0.30) * 180.0)
	role_balance = clampf(role_balance, 0.0, 100.0)

	var specialized_ratio: float = float(metrics.get("specialized_ratio", 0.0))
	var target_specialized: float = 0.30
	if checkpoint_turn >= 50:
		target_specialized = 0.40
	if checkpoint_turn >= 100:
		target_specialized = 0.46
	var specialization_quality: float = 100.0 - absf(specialized_ratio - target_specialized) * 180.0
	specialization_quality -= float(metrics.get("backline_specialized_ratio", 0.0)) * 60.0
	var tier_counts: Dictionary = metrics.get("tier_counts", {})
	var deep_tier_ratio: float = (float(tier_counts.get("2", 0)) + float(tier_counts.get("3", 0))) / maxf(1.0, float(tier_counts.get("1", 0)) + float(tier_counts.get("2", 0)) + float(tier_counts.get("3", 0)))
	specialization_quality += deep_tier_ratio * 16.0
	specialization_quality = clampf(specialization_quality, 0.0, 100.0)

	var objective: Dictionary = metrics.get("objective", {})
	var objective_progress: float = 40.0
	objective_progress += float(objective.get("resource_progress", 0.0)) * 22.0
	objective_progress += float(objective.get("military_progress", 0.0)) * 22.0
	objective_progress += float(objective.get("resource_control", 0.0)) * 16.0
	objective_progress = clampf(objective_progress, 0.0, 100.0)

	var economy: float = 100.0
	var avg_energy: float = float(metrics.get("avg_energy", 0.0))
	if avg_energy > 30.0:
		economy -= (avg_energy - 30.0) * 1.7
	if avg_energy < 4.0:
		economy -= (4.0 - avg_energy) * 7.0
	economy -= float(metrics.get("pass_rate", 0.0)) * 95.0
	economy -= float(metrics.get("fail_rate", 0.0)) * 120.0
	economy += minf(14.0, float(metrics.get("resource_gather_tiles", 0)) * 4.0)
	economy = clampf(economy, 0.0, 100.0)

	var board_shape: float = 52.0
	board_shape += float(metrics.get("supported_ratio", 0.0)) * 48.0
	board_shape -= float(metrics.get("low_support_ratio", 0.0)) * 38.0
	board_shape = clampf(board_shape, 0.0, 100.0)

	var anti_pathology: float = 100.0
	anti_pathology -= float(metrics.get("frontline_gather_tiles", 0)) * 18.0
	anti_pathology -= float(metrics.get("exposed_ranged_tiles", 0)) * 9.0
	anti_pathology -= float(metrics.get("backline_specialized_ratio", 0.0)) * 42.0
	anti_pathology = clampf(anti_pathology, 0.0, 100.0)

	return {
		"role_balance": role_balance,
		"specialization_quality": specialization_quality,
		"objective_progress": objective_progress,
		"economy": economy,
		"board_shape": board_shape,
		"anti_pathology": anti_pathology,
	}

func _weighted_total_score(category_scores: Dictionary) -> float:
	var weights: Dictionary = {
		"role_balance": 0.22,
		"specialization_quality": 0.19,
		"objective_progress": 0.22,
		"economy": 0.14,
		"board_shape": 0.13,
		"anti_pathology": 0.10,
	}
	var total: float = 0.0
	for category_key in weights.keys():
		var key: String = String(category_key)
		var w: float = float(weights[key])
		total += float(category_scores.get(key, 0.0)) * w
	return clampf(total, 0.0, 100.0)

func _objective_metrics(state: GameState, initial_state: GameState) -> Dictionary:
	var ai_owners: Array = _ai_owner_ids(state)
	var resource_delta_accum: float = 0.0
	var military_delta_accum: float = 0.0
	var sample_count: int = 0
	var control_count: int = 0

	for owner_variant in ai_owners:
		var owner_id: int = int(owner_variant)
		var now_dist_resource: int = _owner_distance_to_nearest_open_resource(state, owner_id)
		var init_dist_resource: int = _owner_distance_to_nearest_open_resource(initial_state, owner_id)
		var now_dist_military: int = _owner_distance_to_military_objective(state, owner_id)
		var init_dist_military: int = _owner_distance_to_military_objective(initial_state, owner_id)

		resource_delta_accum += _distance_progress_score(init_dist_resource, now_dist_resource)
		military_delta_accum += _distance_progress_score(init_dist_military, now_dist_military)
		control_count += _owner_resource_control_count(state, owner_id)
		sample_count += 1

	return {
		"resource_progress": resource_delta_accum / maxf(1.0, float(sample_count)),
		"military_progress": military_delta_accum / maxf(1.0, float(sample_count)),
		"resource_control": float(control_count) / maxf(1.0, float(sample_count * 2)),
	}

func _distance_progress_score(before: int, after: int) -> float:
	if before >= MAX_DISTANCE_SENTINEL and after >= MAX_DISTANCE_SENTINEL:
		return 0.0
	if before >= MAX_DISTANCE_SENTINEL:
		return 0.0
	if after >= MAX_DISTANCE_SENTINEL:
		return -1.0
	return clampf(float(before - after) / 8.0, -1.0, 1.0)

func _ai_owner_ids(state: GameState) -> Array:
	var out: Array = []
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID:
			continue
		if not bool(state.players[owner_id].get("ai_controlled", true)):
			continue
		if not _owner_has_blocks(state, owner_id):
			continue
		out.append(owner_id)
	return out

func _average_ai_energy(state: GameState) -> float:
	var total: float = 0.0
	var count: int = 0
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID:
			continue
		if not bool(state.players[owner_id].get("ai_controlled", true)):
			continue
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if not _owner_has_blocks(state, owner_id):
			continue
		total += float(state.players.get(owner_id, {}).get("nutrients", 0))
		count += 1
	if count <= 0:
		return 0.0
	return total / float(count)

func _owner_resource_control_count(state: GameState, owner_id: int) -> int:
	var total: int = 0
	var position_owner_index: Dictionary = {}
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		position_owner_index[_tile_key(pos)] = int(block.get("owner", -1))
	for node_variant in state.resource_nodes:
		var node: Dictionary = node_variant
		var tile: Vector2i = node.get("pos", Vector2i(-1, -1))
		if int(position_owner_index.get(_tile_key(tile), -1)) == owner_id:
			total += 1
	return total

func _owner_distance_to_nearest_open_resource(state: GameState, owner_id: int) -> int:
	var resources: Array = []
	for node_variant in state.resource_nodes:
		var node: Dictionary = node_variant
		if bool(node.get("consumed", false)):
			continue
		resources.append(node.get("pos", Vector2i(-1, -1)))
	return _owner_distance_to_targets(state, owner_id, resources)

func _owner_distance_to_military_objective(state: GameState, owner_id: int) -> int:
	var targets: Array = []
	if state.door_hp > 0 and state.are_hostile(owner_id, GameState.PLAYER_ID):
		targets.append(state.door_tile)
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		if not bool(block.get("is_heart", false)):
			continue
		var other_owner: int = int(block.get("owner", 0))
		if not state.are_hostile(owner_id, other_owner):
			continue
		targets.append(block.get("pos", Vector2i(-1, -1)))
	return _owner_distance_to_targets(state, owner_id, targets)

func _owner_distance_to_targets(state: GameState, owner_id: int, targets: Array) -> int:
	if targets.is_empty():
		return MAX_DISTANCE_SENTINEL
	var best: int = MAX_DISTANCE_SENTINEL
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		if int(block.get("owner", -1)) != owner_id:
			continue
		var pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		for target_variant in targets:
			var target: Vector2i = target_variant
			var dist: int = abs(pos.x - target.x) + abs(pos.y - target.y)
			best = mini(best, dist)
	return best

func _find_candidate_result(results: Array, candidate_id: String) -> Dictionary:
	for item_variant in results:
		var item: Dictionary = item_variant
		if String(item.get("id", "")) == candidate_id:
			return item
	return {}

func _build_recommendations(baseline: Dictionary, top_candidates: Array) -> Array:
	var recommendations: Array = []
	if top_candidates.is_empty():
		return recommendations
	var best: Dictionary = top_candidates[0]
	var baseline_score: float = float(baseline.get("score", 0.0))
	var best_score: float = float(best.get("score", 0.0))
	var delta: float = best_score - baseline_score
	if absf(delta) < 0.1:
		recommendations.append("Best candidate is effectively tied with baseline; keep current constants and collect more scenarios.")
		return recommendations
	if delta > 0.0:
		recommendations.append("Best candidate improves overall score by %.2f points over baseline." % delta)
	else:
		recommendations.append("No candidate beat baseline (best delta %.2f); tune search ranges before applying any changes." % delta)

	var best_overrides: Dictionary = best.get("overrides", {})
	if not best_overrides.is_empty():
		var keys: Array = best_overrides.keys()
		keys.sort()
		for key_variant in keys:
			var key: String = String(key_variant)
			recommendations.append("Candidate suggests `%s = %s`." % [key, str(best_overrides[key])])

	var baseline_categories: Dictionary = baseline.get("score_by_category", {})
	var best_categories: Dictionary = best.get("score_by_category", {})
	var category_deltas: Array = []
	for category_key in best_categories.keys():
		var category: String = String(category_key)
		var cat_delta: float = float(best_categories[category]) - float(baseline_categories.get(category, 0.0))
		category_deltas.append({"category": category, "delta": cat_delta})
	category_deltas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf(float(a.get("delta", 0.0))) > absf(float(b.get("delta", 0.0)))
	)
	for i in range(mini(3, category_deltas.size())):
		var row: Dictionary = category_deltas[i]
		recommendations.append(
			"%s changed by %.2f points." % [String(row.get("category", "")), float(row.get("delta", 0.0))]
		)
	return recommendations

func _write_reports(output_dir: String, report: Dictionary) -> Dictionary:
	var root_path: String = output_dir
	if root_path.is_empty():
		root_path = DEFAULT_OUTPUT_DIR
	var absolute_dir: String = ProjectSettings.globalize_path(root_path)
	DirAccess.make_dir_recursive_absolute(absolute_dir)

	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var json_path: String = root_path.path_join("ai_tuner_%s.json" % stamp)
	var txt_path: String = root_path.path_join("ai_tuner_%s.txt" % stamp)

	var serialized: String = JSON.stringify(report, "\t")
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(serialized)

	var text_file: FileAccess = FileAccess.open(txt_path, FileAccess.WRITE)
	if text_file != null:
		text_file.store_string(_build_readable_report(report))

	return {"json": json_path, "text": txt_path}

func _build_readable_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("OOZE AI TUNER REPORT")
	lines.append("Generated: %s" % String(report.get("generated_at", "")))
	lines.append("Candidates: %d | Scenarios: %d" % [int(report.get("candidate_count", 0)), int(report.get("scenario_count", 0))])
	lines.append("")
	var top_candidates: Array = report.get("top_candidates", [])
	for i in range(top_candidates.size()):
		var candidate: Dictionary = top_candidates[i]
		lines.append("%d. %s (score %.2f)" % [i + 1, String(candidate.get("id", "")), float(candidate.get("score", 0.0))])
		lines.append("   overrides: %s" % JSON.stringify(candidate.get("overrides", {})))
		lines.append("   categories: %s" % JSON.stringify(candidate.get("score_by_category", {})))
		lines.append("   checkpoints: %s" % JSON.stringify(candidate.get("score_by_checkpoint", {})))
		lines.append("")
	var recommendations: Array = report.get("recommendations", [])
	if not recommendations.is_empty():
		lines.append("Recommendations:")
		for rec_variant in recommendations:
			lines.append("- %s" % String(rec_variant))
	return "\n".join(lines)

func _build_terminal_summary(run_result: Dictionary) -> String:
	var lines: Array[String] = []
	var output: Dictionary = run_result.get("output", {})
	lines.append("AI tuning completed.")
	lines.append("Candidates evaluated: %d" % int(run_result.get("candidate_count", 0)))
	var top_candidates: Array = run_result.get("top_candidates", [])
	for i in range(mini(3, top_candidates.size())):
		var item: Dictionary = top_candidates[i]
		lines.append("%d) %s  score=%.2f" % [i + 1, String(item.get("id", "")), float(item.get("score", 0.0))])
	if not output.is_empty():
		lines.append("JSON: %s" % String(output.get("json", "")))
		lines.append("Text: %s" % String(output.get("text", "")))
	return "\n".join(lines)
