extends SceneTree

const DEFAULT_CONFIG_PATH: String = "res://tools/ai_tuner_config.json"
const DEFAULT_OUTPUT_DIR: String = "user://ai_tuner_output"
const BASELINE_TUNING_CONFIG_PATH: String = "res://config/ooze_ai_baseline.json"
const ROLE_TYPES: Array[String] = ["basic", "melee", "ranged", "defense", "gather"]
const CATEGORY_ORDER: Array[String] = [
	"role_balance",
	"specialization_quality",
	"objective_progress",
	"economy",
	"board_shape",
	"anti_pathology",
]
const PHASE_CHECKPOINT_DEFAULTS: Array = [12, 32, 60, 90]
const MIN_EXPAND_ADJACENT: int = 1
const MAX_DISTANCE_SENTINEL: int = 999999
const MIN_TEMPLATE_OPEN_RATIO: float = 0.58
const MAX_TEMPLATE_WALL_RATIO: float = 0.32
const ECONOMY_REGRESSION_GUARDRAIL: float = -6.0
const OBJECTIVE_REGRESSION_GUARDRAIL: float = -5.0
const OUTCOME_VICTORY_BONUS: float = 8.0
const OUTCOME_DEFEAT_PENALTY: float = -8.0
const OUTCOME_UNRESOLVED_PENALTY: float = -2.0
const OUTCOME_FAST_SAMPLE_WEIGHT: float = 0.65
const OUTCOME_SCENARIO_SAMPLE_WEIGHT: float = 1.75
const TRAINING_DEFAULT_TIME_BUDGET_MINUTES: float = 45.0
const TRAINING_DEFAULT_MAX_PASSES: int = 9
const TRAINING_DEFAULT_PLATEAU_PASSES: int = 2
const TRAINING_DEFAULT_MIN_ACCEPT_DELTA: float = 0.20
const TRAINING_DEFAULT_SMALL_ACCEPT_DELTA: float = 0.10
const TRAINING_DEFAULT_CONSISTENT_REQUIRED_PASSES: int = 2
const TRAINING_DEFAULT_EXPLORATORY_MAX_SCORE_DROP: float = 0.06
const TRAINING_DEFAULT_EXPLORATORY_KEY_GAIN: float = 0.30
const TRAINING_DEFAULT_EXPLORATORY_PLATEAU_PASSES: int = 2
const TRAINING_DEFAULT_MAX_ECONOMY_DROP: float = 2.5
const TRAINING_DEFAULT_MAX_OBJECTIVE_DROP: float = 2.0
const TRAINING_DEFAULT_MAX_ROLE_DROP: float = 2.0
const TRAINING_DEFAULT_MAX_SPECIALIZATION_DROP: float = 2.0
const TRAINING_DEFAULT_PASS1_GRID_SCALE: float = 1.6
const TRAINING_DEFAULT_PASS1_RANDOM_SCALE: float = 2.0
const TRAINING_DEFAULT_REFINE_GRID_SCALE: float = 1.0
const TRAINING_DEFAULT_REFINE_RANDOM_SCALE: float = 0.75
const TRAINING_DEFAULT_MIN_RANDOM_ITERS: int = 2
const TRAINING_DEFAULT_MAX_EFFECTIVE_PASSES: int = 4
const TRAINING_DEFAULT_MIN_PASS_MINUTES: float = 3.0
const TRAINING_DEFAULT_MIN_CANDIDATES_PER_PASS: float = 1.0
const TRAINING_DEFAULT_PASS_COUNT_CONSERVATISM: float = 1.5
const TRAINING_DEFAULT_OVERRUN_TOLERANCE_SECONDS: float = 60.0
const TRAINING_DEFAULT_INITIAL_SECONDS_PER_ACTOR_TURN: float = 0.22
const TRAINING_DEFAULT_INITIAL_SECONDS_PER_SIMULATION: float = 4.0
const TRAINING_DEFAULT_FAST_SCENARIO_RATIO: float = 0.75
const TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS: int = 1

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
	var run_result: Dictionary = {}
	var training_enabled: bool = _is_training_enabled(config)
	if training_enabled:
		run_result = _run_training(config)
	else:
		run_result = _run_tuning(config)
	if bool(run_result.get("ok", false)):
		if training_enabled:
			print(_build_training_terminal_summary(run_result))
		else:
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
	print("  --train[=true|false]         Enable multi-pass baseline evolution")
	print("  --time-budget-min=<float>    Training time budget in minutes")
	print("  --time-budget-minutes=<float> Alias for --time-budget-min")
	print("  --max-passes=<int>           Max training passes")
	print("  --plateau-passes=<int>       Stop after this many non-improving passes")
	print("  --baseline-path=<res://...>  Baseline config path to mutate")
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

	if not config.has("training"):
		config["training"] = {}
	var training: Dictionary = config["training"]
	if _args.has("train"):
		training["enabled"] = _arg_bool("train", true)
	if _args.has("time-budget-min"):
		training["time_budget_minutes"] = maxf(1.0, float(_args["time-budget-min"]))
	if _args.has("time-budget-minutes"):
		training["time_budget_minutes"] = maxf(1.0, float(_args["time-budget-minutes"]))
	if _args.has("max-passes"):
		training["max_passes"] = maxi(1, int(_args["max-passes"]))
	if _args.has("plateau-passes"):
		training["plateau_passes"] = maxi(1, int(_args["plateau-passes"]))
	if _args.has("baseline-path"):
		training["baseline_config_path"] = String(_args["baseline-path"])
	config["training"] = training

func _arg_bool(key: String, default_value: bool) -> bool:
	if not _args.has(key):
		return default_value
	var value: Variant = _args[key]
	if value is bool:
		return value
	var text: String = String(value).strip_edges().to_lower()
	if text == "" or text == "1" or text == "true" or text == "yes" or text == "on":
		return true
	if text == "0" or text == "false" or text == "no" or text == "off":
		return false
	return default_value

func _is_training_enabled(config: Dictionary) -> bool:
	if _args.has("train"):
		return _arg_bool("train", true)
	var training: Dictionary = config.get("training", {})
	return bool(training.get("enabled", false))

func _normalized_training_settings(config: Dictionary) -> Dictionary:
	var training: Dictionary = config.get("training", {})
	var acceptance: Dictionary = training.get("acceptance", {})
	var pass_profiles: Dictionary = training.get("pass_profiles", {})
	var scenario_mix: Dictionary = training.get("scenario_mix", {})
	return {
		"time_budget_minutes": maxf(1.0, float(training.get("time_budget_minutes", TRAINING_DEFAULT_TIME_BUDGET_MINUTES))),
		"max_passes": maxi(1, int(training.get("max_passes", TRAINING_DEFAULT_MAX_PASSES))),
		"plateau_passes": maxi(1, int(training.get("plateau_passes", TRAINING_DEFAULT_PLATEAU_PASSES))),
		"min_accept_score_delta": maxf(0.0, float(training.get("min_accept_score_delta", TRAINING_DEFAULT_MIN_ACCEPT_DELTA))),
		"small_accept_score_delta": maxf(0.0, float(acceptance.get("small_accept_score_delta", TRAINING_DEFAULT_SMALL_ACCEPT_DELTA))),
		"consistency_required_passes": maxi(1, int(acceptance.get("consistency_required_passes", TRAINING_DEFAULT_CONSISTENT_REQUIRED_PASSES))),
		"exploratory_max_score_drop": maxf(0.0, float(acceptance.get("exploratory_max_score_drop", TRAINING_DEFAULT_EXPLORATORY_MAX_SCORE_DROP))),
		"exploratory_key_gain": maxf(0.0, float(acceptance.get("exploratory_key_gain", TRAINING_DEFAULT_EXPLORATORY_KEY_GAIN))),
		"exploratory_plateau_passes": maxi(1, int(acceptance.get("exploratory_plateau_passes", TRAINING_DEFAULT_EXPLORATORY_PLATEAU_PASSES))),
		"baseline_config_path": String(training.get("baseline_config_path", BASELINE_TUNING_CONFIG_PATH)),
		"max_effective_passes": maxi(1, int(training.get("max_effective_passes", TRAINING_DEFAULT_MAX_EFFECTIVE_PASSES))),
		"min_pass_minutes": maxf(1.0, float(training.get("min_pass_minutes", TRAINING_DEFAULT_MIN_PASS_MINUTES))),
		"min_candidates_per_pass": maxf(1.0, float(training.get("min_candidates_per_pass", TRAINING_DEFAULT_MIN_CANDIDATES_PER_PASS))),
		"pass_count_conservatism": maxf(1.0, float(training.get("pass_count_conservatism", TRAINING_DEFAULT_PASS_COUNT_CONSERVATISM))),
		"max_economy_drop": float(acceptance.get("max_economy_drop", TRAINING_DEFAULT_MAX_ECONOMY_DROP)),
		"max_objective_drop": float(acceptance.get("max_objective_drop", TRAINING_DEFAULT_MAX_OBJECTIVE_DROP)),
		"max_role_balance_drop": float(acceptance.get("max_role_balance_drop", TRAINING_DEFAULT_MAX_ROLE_DROP)),
		"max_specialization_drop": float(acceptance.get("max_specialization_drop", TRAINING_DEFAULT_MAX_SPECIALIZATION_DROP)),
		"pass1_grid_scale": maxf(0.2, float(pass_profiles.get("pass1_grid_scale", TRAINING_DEFAULT_PASS1_GRID_SCALE))),
		"pass1_random_scale": maxf(0.2, float(pass_profiles.get("pass1_random_scale", TRAINING_DEFAULT_PASS1_RANDOM_SCALE))),
		"refine_grid_scale": maxf(0.2, float(pass_profiles.get("refine_grid_scale", TRAINING_DEFAULT_REFINE_GRID_SCALE))),
		"refine_random_scale": maxf(0.2, float(pass_profiles.get("refine_random_scale", TRAINING_DEFAULT_REFINE_RANDOM_SCALE))),
		"min_random_iterations": maxi(0, int(pass_profiles.get("min_random_iterations", TRAINING_DEFAULT_MIN_RANDOM_ITERS))),
		"overrun_tolerance_seconds": maxf(0.0, float(training.get("overrun_tolerance_seconds", TRAINING_DEFAULT_OVERRUN_TOLERANCE_SECONDS))),
		"initial_seconds_per_actor_turn": maxf(
			0.001,
			float(training.get("initial_seconds_per_actor_turn", TRAINING_DEFAULT_INITIAL_SECONDS_PER_ACTOR_TURN))
		),
		"initial_seconds_per_simulation": maxf(
			0.001,
			float(training.get("initial_seconds_per_simulation", TRAINING_DEFAULT_INITIAL_SECONDS_PER_SIMULATION))
		),
		"fast_scenario_ratio": clampf(
			float(scenario_mix.get("fast_scenario_ratio", TRAINING_DEFAULT_FAST_SCENARIO_RATIO)),
			0.55,
			0.95
		),
		"min_outcome_scenarios": maxi(
			1,
			int(scenario_mix.get("min_outcome_scenarios", TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS))
		),
	}

func _run_training(config: Dictionary) -> Dictionary:
	var settings: Dictionary = _normalized_training_settings(config)
	var time_budget_minutes: float = float(settings.get("time_budget_minutes", TRAINING_DEFAULT_TIME_BUDGET_MINUTES))
	var time_budget_ms: int = int(round(time_budget_minutes * 60.0 * 1000.0))
	var session_start_ms: int = Time.get_ticks_msec()
	var deadline_ms: int = session_start_ms + time_budget_ms
	var max_passes: int = int(settings.get("max_passes", TRAINING_DEFAULT_MAX_PASSES))
	var plateau_pass_limit: int = int(settings.get("plateau_passes", TRAINING_DEFAULT_PLATEAU_PASSES))
	var baseline_path: String = String(settings.get("baseline_config_path", BASELINE_TUNING_CONFIG_PATH))
	var overrun_tolerance_sec: float = float(settings.get("overrun_tolerance_seconds", TRAINING_DEFAULT_OVERRUN_TOLERANCE_SECONDS))

	print(
		"AI trainer multi-pass mode: budget=%.1f min, max_passes=%d, plateau_limit=%d, overrun_tolerance=%.1fs, baseline=%s" % [
			time_budget_minutes,
			max_passes,
			plateau_pass_limit,
			overrun_tolerance_sec,
			baseline_path,
		]
	)

	var pass_reports: Array = []
	var plateau_passes: int = 0
	var stop_reason: String = "max_passes"
	var start_baseline_score: float = 0.0
	var final_baseline_score: float = 0.0
	var passes_run: int = 0
	var baseline_before_training: Dictionary = _extract_flat_numeric_map_from_file(baseline_path)
	var perf: Dictionary = {
		"elapsed_seconds": 0.0,
		"completed_candidates": 0,
		"completed_simulations": 0,
		"completed_actor_turns": 0.0,
		"completed_fast_simulations": 0,
		"completed_outcome_simulations": 0,
		"completed_fast_actor_turns": 0.0,
		"completed_outcome_actor_turns": 0.0,
		"fast_elapsed_seconds": 0.0,
		"outcome_elapsed_seconds": 0.0,
		"seconds_per_candidate": 0.0,
		"seconds_per_simulation": 0.0,
		"seconds_per_actor_turn": 0.0,
		"seconds_per_fast_simulation": 0.0,
		"seconds_per_outcome_simulation": 0.0,
	}
	var acceptance_state: Dictionary = {
		"consistency_table": {},
		"exploratory_used": false,
	}

	var initial_remaining_seconds: float = float(time_budget_ms) / 1000.0
	var effective_pass_count: int = _compute_effective_pass_count(initial_remaining_seconds, settings, max_passes, perf)
	if effective_pass_count <= 0:
		return {"ok": false, "error": "insufficient budget for minimum viable pass duration"}
	var initial_weights: Array = _pass_weight_distribution(effective_pass_count)
	print("Session budget: %.2f min" % (initial_remaining_seconds / 60.0))
	print("Effective passes: %d (max_passes=%d)" % [effective_pass_count, max_passes])
	print("Pass weights: %s" % JSON.stringify(initial_weights))

	for pass_index in range(1, max_passes + 1):
		var now_ms: int = Time.get_ticks_msec()
		if now_ms >= deadline_ms:
			stop_reason = "time_budget"
			break
		var remaining_seconds: float = maxf(0.0, float(deadline_ms - now_ms) / 1000.0)
		var remaining_pass_cap: int = maxi(1, max_passes - pass_index + 1)
		var planned_passes_left: int = maxi(0, effective_pass_count - passes_run)
		if planned_passes_left <= 0:
			stop_reason = "effective_pass_plan_complete"
			break
		var dynamic_effective_passes: int = _compute_effective_pass_count(remaining_seconds, settings, remaining_pass_cap, perf)
		if dynamic_effective_passes <= 0:
			var min_useful_seconds: float = _min_useful_pass_seconds(settings, perf)
			if passes_run == 0 and remaining_seconds + 1.5 >= min_useful_seconds:
				dynamic_effective_passes = 1
				print(
					"Near-threshold budget: forcing a single meaningful pass (remaining %.2f min, min useful %.2f min)." % [
						remaining_seconds / 60.0,
						min_useful_seconds / 60.0,
					]
				)
			else:
				stop_reason = "insufficient_budget_for_min_pass"
				print(
					"Skipping pass %d: remaining budget %.2f min is below minimum useful pass duration %.2f min." % [
						pass_index,
						remaining_seconds / 60.0,
						min_useful_seconds / 60.0,
					]
				)
				break
		if dynamic_effective_passes < planned_passes_left:
			print(
				"Observed throughput adjustment: collapsing planned remaining passes %d -> %d." % [
					planned_passes_left,
					dynamic_effective_passes,
				]
			)
		planned_passes_left = mini(planned_passes_left, dynamic_effective_passes)
		var pass_weights: Array = _pass_weight_distribution(planned_passes_left)
		var allocation_seconds: float = remaining_seconds * float(pass_weights[0])
		print("Pass %d allocation: %.2f min (remaining %.2f min)" % [pass_index, allocation_seconds / 60.0, remaining_seconds / 60.0])

		var pass_config: Dictionary = _pass_config_for_index(
			config,
			settings,
			pass_index,
			perf,
			deadline_ms,
			allocation_seconds,
			planned_passes_left
		)
		for msg_variant in pass_config.get("_budget_adapt_logs", []):
			print(String(msg_variant))
		pass_config.erase("_budget_adapt_logs")

		var budget_context: Dictionary = _build_budget_context(settings, deadline_ms, perf, session_start_ms)
		var pass_plan: Dictionary = _plan_pass_budget(pass_config, budget_context, overrun_tolerance_sec)
		var plan_breakdown: Dictionary = pass_plan.get("estimate_breakdown", {})
		print(
			"Pass %d budget check: remaining=%.2f min, planned=%d candidates, est=%.2f min (fast %.2f + outcome %.2f)." % [
				pass_index,
				remaining_seconds / 60.0,
				int(pass_plan.get("planned_candidates", 0)),
				float(pass_plan.get("estimated_seconds", 0.0)) / 60.0,
				float(plan_breakdown.get("fast_seconds", 0.0)) / 60.0,
				float(plan_breakdown.get("outcome_seconds", 0.0)) / 60.0,
			]
		)
		if not bool(pass_plan.get("allow_start", true)):
			stop_reason = "budget_projected"
			print("Skipping pass %d: %s" % [pass_index, String(pass_plan.get("reason", "budget projection"))])
			break

		OozeAI.reload_baseline_tuning()
		print("")
		print("=== Training Pass %d/%d ===" % [pass_index, effective_pass_count])
		var pass_result: Dictionary = _run_tuning(pass_config, budget_context)
		if not bool(pass_result.get("ok", false)):
			return {
				"ok": false,
				"error": "pass %d failed: %s" % [
					pass_index,
					String(pass_result.get("error", "unknown pass failure")),
				],
			}

		var runtime_stats: Dictionary = pass_result.get("runtime_stats", {})
		_accumulate_runtime_metrics(perf, runtime_stats)
		print(
			"Observed throughput: %.2fs/candidate, %.4fs/actor-turn, fast %.2fs/sim, outcome %.2fs/sim, projected remaining %.2f min" % [
				float(perf.get("seconds_per_candidate", 0.0)),
				float(perf.get("seconds_per_actor_turn", 0.0)),
				float(perf.get("seconds_per_fast_simulation", 0.0)),
				float(perf.get("seconds_per_outcome_simulation", 0.0)),
				maxf(0.0, float(deadline_ms - Time.get_ticks_msec()) / 1000.0) / 60.0,
			]
		)

		var pass_context: Dictionary = {
			"pass_index": pass_index,
			"plateau_passes_before": plateau_passes,
			"allow_exploratory": plateau_passes >= int(settings.get("exploratory_plateau_passes", TRAINING_DEFAULT_EXPLORATORY_PLATEAU_PASSES)),
		}
		var pass_report: Dictionary = _build_training_pass_report(pass_result, settings, pass_index, acceptance_state, pass_context)
		pass_report["runtime_stats"] = runtime_stats
		passes_run += 1
		if pass_index == 1:
			start_baseline_score = float(pass_report.get("baseline_score_before", 0.0))

		var accepted: bool = bool(pass_report.get("accepted", false))
		if accepted:
			var accepted_candidate: Dictionary = pass_report.get("accepted_candidate", {})
			var write_result: Dictionary = _apply_candidate_to_baseline(baseline_path, accepted_candidate)
			if not bool(write_result.get("ok", false)):
				return {
					"ok": false,
					"error": "pass %d baseline write failed: %s" % [
						pass_index,
						String(write_result.get("error", "unknown write failure")),
					],
				}
			pass_report["baseline_update"] = write_result
			final_baseline_score = float(pass_report.get("accepted_score", pass_report.get("baseline_score_before", 0.0)))
			plateau_passes = 0
			OozeAI.reload_baseline_tuning()
		else:
			final_baseline_score = float(pass_report.get("baseline_score_before", 0.0))
			plateau_passes += 1

		pass_reports.append(pass_report)
		print(_format_pass_summary(pass_report))

		if plateau_passes >= plateau_pass_limit:
			stop_reason = "plateau"
			break
		if bool(runtime_stats.get("budget_stop", false)):
			stop_reason = "time_budget"
			break
		if Time.get_ticks_msec() >= deadline_ms:
			stop_reason = "time_budget"
			break

	var elapsed_ms: int = max(Time.get_ticks_msec() - session_start_ms, 0)
	var final_eval: Dictionary = {"ok": false, "skipped": "budget"}
	if Time.get_ticks_msec() < deadline_ms:
		var eval_budget_context: Dictionary = _build_budget_context(settings, deadline_ms, perf, session_start_ms)
		final_eval = _run_baseline_evaluation(config, eval_budget_context)
	if bool(final_eval.get("ok", false)):
		final_baseline_score = float(final_eval.get("baseline", {}).get("score", final_baseline_score))
	elif pass_reports.is_empty():
		return {"ok": false, "error": "training produced no completed passes and final eval failed"}

	var baseline_after_training: Dictionary = _extract_flat_numeric_map_from_file(baseline_path)
	var cumulative_changes: Dictionary = _diff_flat_numeric_maps(
		baseline_before_training,
		baseline_after_training
	)
	var summary: Dictionary = {
		"ok": true,
		"generated_at": Time.get_datetime_string_from_system(),
		"mode": "multi_pass_training",
		"config_used": config,
		"training_settings": settings,
		"effective_pass_count": effective_pass_count,
		"effective_pass_weights": _pass_weight_distribution(effective_pass_count),
		"passes_run": passes_run,
		"stop_reason": stop_reason,
		"elapsed_ms": elapsed_ms,
		"starting_baseline_score": start_baseline_score,
		"final_baseline_score": final_baseline_score,
		"total_improvement": final_baseline_score - start_baseline_score,
		"pass_reports": pass_reports,
		"final_eval": final_eval,
		"baseline_path": baseline_path,
		"final_baseline_snapshot": baseline_after_training,
		"applied_parameter_changes": cumulative_changes,
		"runtime_metrics": perf,
	}

	var output_dir: String = String(config.get("output_dir", DEFAULT_OUTPUT_DIR))
	summary["output"] = _write_training_reports(output_dir, summary)
	return summary

func _pass_config_for_index(
	base_config: Dictionary,
	settings: Dictionary,
	pass_index: int,
	perf: Dictionary,
	deadline_ms: int,
	allocated_seconds: float,
	planned_passes_left: int
) -> Dictionary:
	var out: Dictionary = base_config.duplicate(true)
	var search: Dictionary = out.get("search", {}).duplicate(true)
	var adapt_logs: Array[String] = []
	var is_pass_one: bool = pass_index == 1
	var grid_scale: float = float(settings.get("pass1_grid_scale", TRAINING_DEFAULT_PASS1_GRID_SCALE))
	var random_scale: float = float(settings.get("pass1_random_scale", TRAINING_DEFAULT_PASS1_RANDOM_SCALE))
	if not is_pass_one:
		grid_scale = float(settings.get("refine_grid_scale", TRAINING_DEFAULT_REFINE_GRID_SCALE))
		random_scale = float(settings.get("refine_random_scale", TRAINING_DEFAULT_REFINE_RANDOM_SCALE))
	var min_random_iters: int = int(settings.get("min_random_iterations", TRAINING_DEFAULT_MIN_RANDOM_ITERS))

	search["max_grid_candidates"] = maxi(1, int(round(float(search.get("max_grid_candidates", 2)) * grid_scale)))
	search["random_iterations"] = maxi(
		min_random_iters,
		int(round(float(search.get("random_iterations", 4)) * random_scale))
	)
	search["max_total_candidates"] = maxi(
		2,
		int(round(float(search.get("max_total_candidates", 7)) * maxf(grid_scale, random_scale)))
	)

	var base_seed: int = int(search.get("random_seed", 1337))
	search["random_seed"] = base_seed + pass_index * 9973
	out["search"] = search
	out["output_dir"] = String(base_config.get("output_dir", DEFAULT_OUTPUT_DIR)).path_join("train_pass_%02d" % pass_index)

	var remaining_seconds: float = maxf(0.0, float(deadline_ms - Time.get_ticks_msec()) / 1000.0)
	var target_seconds_this_pass: float = maxf(0.0, allocated_seconds)
	adapt_logs.append("Session budget remaining: %.2f min" % (remaining_seconds / 60.0))
	adapt_logs.append(
		"Allocating ~%.2f min to pass %d based on %d planned pass(es) left." % [
			target_seconds_this_pass / 60.0,
			pass_index,
			planned_passes_left,
		]
	)

	var estimate_context: Dictionary = {
		"observed_seconds_per_candidate": float(perf.get("seconds_per_candidate", 0.0)),
		"observed_seconds_per_simulation": float(perf.get("seconds_per_simulation", 0.0)),
		"observed_seconds_per_actor_turn": float(perf.get("seconds_per_actor_turn", 0.0)),
		"observed_seconds_per_fast_simulation": float(perf.get("seconds_per_fast_simulation", 0.0)),
		"observed_seconds_per_outcome_simulation": float(perf.get("seconds_per_outcome_simulation", 0.0)),
		"initial_seconds_per_actor_turn": float(
			settings.get("initial_seconds_per_actor_turn", TRAINING_DEFAULT_INITIAL_SECONDS_PER_ACTOR_TURN)
		),
		"initial_seconds_per_simulation": float(
			settings.get("initial_seconds_per_simulation", TRAINING_DEFAULT_INITIAL_SECONDS_PER_SIMULATION)
		),
	}
	var reduced_seeds: bool = false
	var reduced_fast_scenarios: bool = false
	var mix_settings: Dictionary = {
		"fast_scenario_ratio": float(settings.get("fast_scenario_ratio", TRAINING_DEFAULT_FAST_SCENARIO_RATIO)),
		"min_outcome_scenarios": int(settings.get("min_outcome_scenarios", TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS)),
	}
	if target_seconds_this_pass <= 0.0:
		adapt_logs.append("No time allocated to pass %d; skipping candidate expansion." % pass_index)
		out["_budget_adapt_logs"] = adapt_logs
		return out
	for shrink_round in range(5):
		var checkpoints: Array = _checkpoint_list_from_config(out)
		var scenarios: Array = _normalized_scenarios(out)
		scenarios = _ensure_outcome_scenario(scenarios)
		scenarios = _apply_scenario_mix_for_candidate(scenarios, mix_settings)
		var candidates: Array = _build_candidates(out)
		var workload: Dictionary = _estimate_workload(candidates, scenarios, checkpoints)
		var estimate_breakdown: Dictionary = _estimate_runtime_breakdown_for_workload(workload, estimate_context)
		var estimated_seconds: float = float(estimate_breakdown.get("total_seconds", 0.0))
		if estimated_seconds <= target_seconds_this_pass * 1.05:
			if shrink_round == 0:
				adapt_logs.append(
					"Pass %d projection %.2f min (fast %.2f + outcome %.2f) fits allocated budget." % [
						pass_index,
						estimated_seconds / 60.0,
						float(estimate_breakdown.get("fast_seconds", 0.0)) / 60.0,
						float(estimate_breakdown.get("outcome_seconds", 0.0)) / 60.0,
					]
				)
			break

		var shrink_scale: float = clampf(target_seconds_this_pass / maxf(1.0, estimated_seconds), 0.25, 0.85)
		var shrink_result: Dictionary = _shrink_search_space(out, shrink_scale, min_random_iters)
		adapt_logs.append(
			"Projected %.2f min exceeds allocation %.2f min; trimming search (total %d->%d, grid %d->%d, random %d->%d)." % [
				estimated_seconds / 60.0,
				target_seconds_this_pass / 60.0,
				int(shrink_result.get("old_total", 0)),
				int(shrink_result.get("new_total", 0)),
				int(shrink_result.get("old_grid", 0)),
				int(shrink_result.get("new_grid", 0)),
				int(shrink_result.get("old_random", 0)),
				int(shrink_result.get("new_random", 0)),
			]
		)
		if not reduced_fast_scenarios:
			var scenario_reductions: int = _trim_fast_scenarios_for_budget(out, int(mix_settings.get("min_outcome_scenarios", TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS)))
			if scenario_reductions > 0:
				adapt_logs.append("Pass %d additional trim: removed %d FAST scenario(s) before touching outcome set." % [pass_index, scenario_reductions])
				reduced_fast_scenarios = true
		if shrink_round >= 2 and not reduced_seeds:
			var seed_reductions: int = _cap_scenarios_for_budget(out, 1, true)
			if seed_reductions <= 0:
				seed_reductions = _cap_scenarios_for_budget(out, 1, false)
			if seed_reductions > 0:
				adapt_logs.append("Pass %d additional trim: seed cap=1 for %d scenario(s)." % [pass_index, seed_reductions])
				reduced_seeds = true

	out["_budget_adapt_logs"] = adapt_logs
	return out

func _compute_effective_pass_count(remaining_seconds: float, settings: Dictionary, remaining_pass_cap: int, perf: Dictionary) -> int:
	var hard_cap: int = mini(
		maxi(1, int(settings.get("max_effective_passes", TRAINING_DEFAULT_MAX_EFFECTIVE_PASSES))),
		maxi(1, remaining_pass_cap)
	)
	var min_pass_seconds: float = _min_useful_pass_seconds(settings, perf)
	if remaining_seconds + 1.5 < min_pass_seconds:
		return 0
	var conservatism: float = maxf(1.0, float(settings.get("pass_count_conservatism", TRAINING_DEFAULT_PASS_COUNT_CONSERVATISM)))
	var conservative_pass_seconds: float = min_pass_seconds * conservatism
	var estimated: int = int(floor(remaining_seconds / maxf(1.0, conservative_pass_seconds)))
	if estimated <= 0:
		estimated = 1
	return clampi(estimated, 1, hard_cap)

func _min_useful_pass_seconds(settings: Dictionary, perf: Dictionary) -> float:
	var min_seconds: float = maxf(60.0, float(settings.get("min_pass_minutes", TRAINING_DEFAULT_MIN_PASS_MINUTES)) * 60.0)
	var observed_seconds_per_candidate: float = float(perf.get("seconds_per_candidate", 0.0))
	if observed_seconds_per_candidate > 0.0:
		var min_candidates: float = maxf(1.0, float(settings.get("min_candidates_per_pass", TRAINING_DEFAULT_MIN_CANDIDATES_PER_PASS)))
		min_seconds = maxf(min_seconds, observed_seconds_per_candidate * min_candidates)
	return min_seconds

func _pass_weight_distribution(pass_count: int) -> Array:
	var count: int = clampi(pass_count, 1, 5)
	var base: Array = [0.40, 0.30, 0.20, 0.10, 0.05]
	var weights: Array = []
	var total: float = 0.0
	for i in range(count):
		var w: float = float(base[i])
		weights.append(w)
		total += w
	if total <= 0.0:
		return [1.0]
	for i in range(weights.size()):
		weights[i] = float(weights[i]) / total
	return weights

func _shrink_search_space(config: Dictionary, scale: float, min_random_iters: int) -> Dictionary:
	var search: Dictionary = config.get("search", {}).duplicate(true)
	var old_total: int = maxi(1, int(search.get("max_total_candidates", 1)))
	var old_grid: int = maxi(0, int(search.get("max_grid_candidates", 0)))
	var old_random: int = maxi(0, int(search.get("random_iterations", 0)))

	var new_total: int = maxi(1, int(floor(float(old_total) * scale)))
	if new_total >= old_total and old_total > 1:
		new_total = old_total - 1
	var slots: int = maxi(0, new_total - 1)

	var new_grid: int = mini(old_grid, int(floor(float(old_grid) * scale)))
	var new_random: int = mini(old_random, int(floor(float(old_random) * scale)))
	if slots <= 0:
		new_grid = 0
		new_random = 0
	else:
		new_random = maxi(0, new_random)
		if old_random > 0:
			new_random = maxi(min_random_iters, new_random)
		if new_grid + new_random > slots:
			new_random = maxi(0, slots - new_grid)
		if new_grid > slots:
			new_grid = slots
			new_random = 0

	search["max_total_candidates"] = new_total
	search["max_grid_candidates"] = new_grid
	search["random_iterations"] = new_random
	config["search"] = search
	return {
		"old_total": old_total,
		"new_total": new_total,
		"old_grid": old_grid,
		"new_grid": new_grid,
		"old_random": old_random,
		"new_random": new_random,
	}

func _cap_scenarios_for_budget(config: Dictionary, seed_cap: int, fast_only: bool = false) -> int:
	if not config.has("scenarios"):
		return 0
	var reduced: int = 0
	var scenarios: Array = config.get("scenarios", [])
	for i in range(scenarios.size()):
		var scenario: Dictionary = scenarios[i]
		if fast_only and _scenario_type(scenario) != "fast":
			continue
		var seeds: Array = scenario.get("seeds", [])
		if seeds.size() > seed_cap:
			scenario["seeds"] = seeds.slice(0, seed_cap)
			reduced += 1
		scenario["runs_per_seed"] = mini(maxi(1, int(scenario.get("runs_per_seed", 1))), 1)
		scenarios[i] = scenario
	config["scenarios"] = scenarios
	return reduced

func _trim_fast_scenarios_for_budget(config: Dictionary, min_outcome_scenarios: int = TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS) -> int:
	if not config.has("scenarios"):
		return 0
	var scenarios: Array = config.get("scenarios", [])
	var fast_indices: Array[int] = []
	var outcome_count: int = 0
	for i in range(scenarios.size()):
		var scenario: Dictionary = scenarios[i]
		if _scenario_type(scenario) == "outcome":
			outcome_count += 1
		else:
			fast_indices.append(i)
	if fast_indices.is_empty() or outcome_count < min_outcome_scenarios:
		return 0
	var remove_index: int = fast_indices[fast_indices.size() - 1]
	scenarios.remove_at(remove_index)
	config["scenarios"] = scenarios
	return 1

func _build_budget_context(settings: Dictionary, deadline_ms: int, perf: Dictionary, session_start_ms: int) -> Dictionary:
	return {
		"enabled": true,
		"deadline_ms": deadline_ms,
		"session_elapsed_seconds": maxf(0.0, float(Time.get_ticks_msec() - session_start_ms) / 1000.0),
		"overrun_tolerance_seconds": float(settings.get("overrun_tolerance_seconds", TRAINING_DEFAULT_OVERRUN_TOLERANCE_SECONDS)),
		"observed_seconds_per_candidate": float(perf.get("seconds_per_candidate", 0.0)),
		"observed_seconds_per_simulation": float(perf.get("seconds_per_simulation", 0.0)),
		"observed_seconds_per_actor_turn": float(perf.get("seconds_per_actor_turn", 0.0)),
		"initial_seconds_per_actor_turn": float(
			settings.get("initial_seconds_per_actor_turn", TRAINING_DEFAULT_INITIAL_SECONDS_PER_ACTOR_TURN)
		),
		"initial_seconds_per_simulation": float(
			settings.get("initial_seconds_per_simulation", TRAINING_DEFAULT_INITIAL_SECONDS_PER_SIMULATION)
		),
	}

func _plan_pass_budget(pass_config: Dictionary, budget_context: Dictionary, overrun_tolerance_sec: float) -> Dictionary:
	var checkpoints: Array = _checkpoint_list_from_config(pass_config)
	var scenarios: Array = _normalized_scenarios(pass_config)
	scenarios = _ensure_outcome_scenario(scenarios)
	var mix_settings: Dictionary = _scenario_mix_settings_from_config(pass_config)
	scenarios = _apply_scenario_mix_for_candidate(scenarios, mix_settings)
	var candidates: Array = _build_candidates(pass_config)
	var workload: Dictionary = _estimate_workload(candidates, scenarios, checkpoints)
	var estimate_breakdown: Dictionary = _estimate_runtime_breakdown_for_workload(workload, budget_context)
	var estimated_seconds: float = float(estimate_breakdown.get("total_seconds", 0.0))
	var remaining_seconds: float = maxf(0.0, float(int(budget_context.get("deadline_ms", Time.get_ticks_msec())) - Time.get_ticks_msec()) / 1000.0)
	var allow_start: bool = true
	var reason: String = "within budget"
	var projected_candidate_seconds: float = _estimated_candidate_seconds(workload, budget_context)
	if bool(budget_context.get("enabled", false)) and projected_candidate_seconds > 0.0:
		if remaining_seconds + overrun_tolerance_sec < projected_candidate_seconds:
			allow_start = false
			reason = "insufficient budget for even one candidate"
	return {
		"allow_start": allow_start,
		"reason": reason,
		"workload": workload,
		"estimate_breakdown": estimate_breakdown,
		"estimated_seconds": estimated_seconds,
		"remaining_seconds": remaining_seconds,
		"planned_candidates": int(workload.get("candidate_count", 0)),
		"planned_simulations": int(workload.get("simulation_count", 0)),
	}

func _estimate_runtime_seconds_for_workload(workload: Dictionary, budget_context: Dictionary) -> float:
	var breakdown: Dictionary = _estimate_runtime_breakdown_for_workload(workload, budget_context)
	return float(breakdown.get("total_seconds", 0.0))

func _estimate_runtime_breakdown_for_workload(workload: Dictionary, budget_context: Dictionary) -> Dictionary:
	var candidate_count: float = maxf(1.0, float(workload.get("candidate_count", 0)))
	var observed_spc: float = float(budget_context.get("observed_seconds_per_candidate", 0.0))
	if observed_spc > 0.0:
		var total_from_candidate: float = observed_spc * candidate_count
		var fast_ratio: float = float(workload.get("fast_simulation_count", 0.0)) / maxf(1.0, float(workload.get("simulation_count", 0)))
		return {
			"fast_seconds": total_from_candidate * fast_ratio,
			"outcome_seconds": total_from_candidate * (1.0 - fast_ratio),
			"total_seconds": total_from_candidate,
		}
	var fast_simulations: float = float(workload.get("fast_simulation_count", 0))
	var outcome_simulations: float = float(workload.get("outcome_simulation_count", 0))
	var fast_actor_turns: float = float(workload.get("fast_actor_turns", 0))
	var outcome_actor_turns: float = float(workload.get("outcome_actor_turns", 0))
	var observed_fast_sps: float = float(budget_context.get("observed_seconds_per_fast_simulation", 0.0))
	var observed_outcome_sps: float = float(budget_context.get("observed_seconds_per_outcome_simulation", 0.0))
	if observed_fast_sps > 0.0 and observed_outcome_sps > 0.0:
		var fast_seconds_by_type: float = observed_fast_sps * fast_simulations
		var outcome_seconds_by_type: float = observed_outcome_sps * outcome_simulations
		return {
			"fast_seconds": fast_seconds_by_type,
			"outcome_seconds": outcome_seconds_by_type,
			"total_seconds": fast_seconds_by_type + outcome_seconds_by_type,
		}
	var observed_sps: float = float(budget_context.get("observed_seconds_per_simulation", 0.0))
	if observed_sps > 0.0:
		var fast_seconds_by_sim: float = observed_sps * fast_simulations
		var outcome_seconds_by_sim: float = observed_sps * outcome_simulations
		return {
			"fast_seconds": fast_seconds_by_sim,
			"outcome_seconds": outcome_seconds_by_sim,
			"total_seconds": fast_seconds_by_sim + outcome_seconds_by_sim,
		}
	var observed_spt: float = float(budget_context.get("observed_seconds_per_actor_turn", 0.0))
	if observed_spt > 0.0:
		var fast_seconds_by_turn: float = observed_spt * fast_actor_turns
		var outcome_seconds_by_turn: float = observed_spt * outcome_actor_turns
		return {
			"fast_seconds": fast_seconds_by_turn,
			"outcome_seconds": outcome_seconds_by_turn,
			"total_seconds": fast_seconds_by_turn + outcome_seconds_by_turn,
		}
	var initial_spt: float = float(
		budget_context.get("initial_seconds_per_actor_turn", TRAINING_DEFAULT_INITIAL_SECONDS_PER_ACTOR_TURN)
	)
	var initial_sps: float = float(
		budget_context.get("initial_seconds_per_simulation", TRAINING_DEFAULT_INITIAL_SECONDS_PER_SIMULATION)
	)
	var fast_seconds_actor: float = fast_actor_turns * initial_spt
	var outcome_seconds_actor: float = outcome_actor_turns * initial_spt
	var fast_seconds_sim: float = fast_simulations * initial_sps
	var outcome_seconds_sim: float = outcome_simulations * initial_sps
	return {
		"fast_seconds": maxf(fast_seconds_actor, fast_seconds_sim),
		"outcome_seconds": maxf(outcome_seconds_actor, outcome_seconds_sim),
		"total_seconds": maxf(fast_seconds_actor, fast_seconds_sim) + maxf(outcome_seconds_actor, outcome_seconds_sim),
	}

func _estimated_candidate_seconds(workload: Dictionary, budget_context: Dictionary) -> float:
	var candidate_count: int = maxi(1, int(workload.get("candidate_count", 1)))
	var per_candidate_workload: Dictionary = {
		"candidate_count": 1,
		"simulation_count": int(round(float(workload.get("simulation_count", 0)) / float(candidate_count))),
		"estimated_actor_turns": int(round(float(workload.get("estimated_actor_turns", 0)) / float(candidate_count))),
		"fast_simulation_count": int(round(float(workload.get("fast_simulation_count", 0)) / float(candidate_count))),
		"outcome_simulation_count": int(round(float(workload.get("outcome_simulation_count", 0)) / float(candidate_count))),
		"fast_actor_turns": int(round(float(workload.get("fast_actor_turns", 0)) / float(candidate_count))),
		"outcome_actor_turns": int(round(float(workload.get("outcome_actor_turns", 0)) / float(candidate_count))),
	}
	return _estimate_runtime_seconds_for_workload(per_candidate_workload, budget_context)

func _accumulate_runtime_metrics(perf: Dictionary, runtime_stats: Dictionary) -> void:
	perf["elapsed_seconds"] = float(perf.get("elapsed_seconds", 0.0)) + float(runtime_stats.get("elapsed_seconds", 0.0))
	perf["completed_candidates"] = int(perf.get("completed_candidates", 0)) + int(runtime_stats.get("evaluated_candidate_count", 0))
	perf["completed_simulations"] = int(perf.get("completed_simulations", 0)) + int(runtime_stats.get("evaluated_simulation_count", 0))
	perf["completed_actor_turns"] = float(perf.get("completed_actor_turns", 0.0)) + float(runtime_stats.get("evaluated_actor_turns", 0.0))
	perf["completed_fast_simulations"] = int(perf.get("completed_fast_simulations", 0)) + int(runtime_stats.get("evaluated_fast_simulation_count", 0))
	perf["completed_outcome_simulations"] = int(perf.get("completed_outcome_simulations", 0)) + int(runtime_stats.get("evaluated_outcome_simulation_count", 0))
	perf["completed_fast_actor_turns"] = float(perf.get("completed_fast_actor_turns", 0.0)) + float(runtime_stats.get("evaluated_fast_actor_turns", 0.0))
	perf["completed_outcome_actor_turns"] = float(perf.get("completed_outcome_actor_turns", 0.0)) + float(runtime_stats.get("evaluated_outcome_actor_turns", 0.0))
	perf["fast_elapsed_seconds"] = float(perf.get("fast_elapsed_seconds", 0.0)) + float(runtime_stats.get("fast_elapsed_seconds", 0.0))
	perf["outcome_elapsed_seconds"] = float(perf.get("outcome_elapsed_seconds", 0.0)) + float(runtime_stats.get("outcome_elapsed_seconds", 0.0))
	var completed_candidates: int = int(perf.get("completed_candidates", 0))
	var completed_simulations: int = int(perf.get("completed_simulations", 0))
	var completed_actor_turns: float = float(perf.get("completed_actor_turns", 0.0))
	var elapsed_seconds: float = float(perf.get("elapsed_seconds", 0.0))
	var completed_fast_simulations: int = int(perf.get("completed_fast_simulations", 0))
	var completed_outcome_simulations: int = int(perf.get("completed_outcome_simulations", 0))
	var fast_elapsed_seconds: float = float(perf.get("fast_elapsed_seconds", 0.0))
	var outcome_elapsed_seconds: float = float(perf.get("outcome_elapsed_seconds", 0.0))
	if completed_candidates > 0:
		perf["seconds_per_candidate"] = elapsed_seconds / float(completed_candidates)
	if completed_simulations > 0:
		perf["seconds_per_simulation"] = elapsed_seconds / float(completed_simulations)
	if completed_actor_turns > 0.0:
		perf["seconds_per_actor_turn"] = elapsed_seconds / completed_actor_turns
	if completed_fast_simulations > 0:
		perf["seconds_per_fast_simulation"] = fast_elapsed_seconds / float(completed_fast_simulations)
	if completed_outcome_simulations > 0:
		perf["seconds_per_outcome_simulation"] = outcome_elapsed_seconds / float(completed_outcome_simulations)

func _run_baseline_evaluation(base_config: Dictionary, budget_context: Dictionary = {}) -> Dictionary:
	var eval_config: Dictionary = base_config.duplicate(true)
	var search: Dictionary = eval_config.get("search", {}).duplicate(true)
	search["max_total_candidates"] = 1
	search["max_grid_candidates"] = 0
	search["random_iterations"] = 0
	eval_config["search"] = search
	eval_config["output_dir"] = String(base_config.get("output_dir", DEFAULT_OUTPUT_DIR)).path_join("final_eval")

	if bool(budget_context.get("enabled", false)):
		var checkpoints: Array = _checkpoint_list_from_config(eval_config)
		var scenarios: Array = _normalized_scenarios(eval_config)
		scenarios = _ensure_outcome_scenario(scenarios)
		var mix_settings: Dictionary = _scenario_mix_settings_from_config(eval_config)
		scenarios = _apply_scenario_mix_for_candidate(scenarios, mix_settings)
		var candidates: Array = _build_candidates(eval_config)
		var workload: Dictionary = _estimate_workload(candidates, scenarios, checkpoints)
		var projected_candidate_seconds: float = _estimated_candidate_seconds(workload, budget_context)
		var remaining_seconds: float = maxf(
			0.0,
			float(int(budget_context.get("deadline_ms", Time.get_ticks_msec())) - Time.get_ticks_msec()) / 1000.0
		)
		var overrun_tolerance: float = float(
			budget_context.get("overrun_tolerance_seconds", TRAINING_DEFAULT_OVERRUN_TOLERANCE_SECONDS)
		)
		if remaining_seconds + overrun_tolerance < projected_candidate_seconds:
			print(
				"Skipping final baseline eval: projected %.2f min exceeds remaining %.2f min (tolerance %.2f min)." % [
					projected_candidate_seconds / 60.0,
					remaining_seconds / 60.0,
					overrun_tolerance / 60.0,
				]
			)
			return {"ok": false, "skipped": "budget", "reason": "insufficient remaining budget for final eval"}

	OozeAI.reload_baseline_tuning()
	return _run_tuning(eval_config, budget_context)

func _build_training_pass_report(
	pass_result: Dictionary,
	settings: Dictionary,
	pass_index: int,
	acceptance_state: Dictionary = {},
	pass_context: Dictionary = {}
) -> Dictionary:
	var baseline: Dictionary = pass_result.get("baseline", {})
	var baseline_score: float = float(baseline.get("score", 0.0))
	var candidates: Array = pass_result.get("all_candidates", [])
	_record_consistency_signals(candidates, baseline, settings, acceptance_state, pass_index)

	var best_candidate: Dictionary = {}
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		if String(candidate.get("id", "")) == "baseline":
			continue
		best_candidate = candidate
		break

	var accepted_candidate: Dictionary = {}
	var accepted_eval: Dictionary = {}
	var rejection_reasons: Array = []
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		if String(candidate.get("id", "")) == "baseline":
			continue
		var decision: Dictionary = _training_candidate_decision(candidate, baseline, settings, acceptance_state, pass_context)
		if bool(decision.get("accepted", false)):
			accepted_candidate = candidate
			accepted_eval = decision
			break
		rejection_reasons.append(
			"%s: %s" % [String(candidate.get("id", "?")), String(decision.get("reason", "rejected"))]
		)

	var report: Dictionary = {
		"pass_index": pass_index,
		"baseline_score_before": baseline_score,
		"baseline_category_scores": baseline.get("score_by_category", {}),
		"best_candidate_id": String(best_candidate.get("id", "none")),
		"best_candidate_score": float(best_candidate.get("score", baseline_score)),
		"best_category_deltas": _category_delta_map(best_candidate, baseline),
		"accepted": not accepted_candidate.is_empty(),
		"accepted_candidate_id": String(accepted_candidate.get("id", "")),
		"accepted_score": float(accepted_candidate.get("score", baseline_score)),
		"accepted_category_deltas": accepted_eval.get("category_deltas", {}),
		"accept_reason": String(accepted_eval.get("reason", "")),
		"rejection_reasons": rejection_reasons,
	}
	if not accepted_candidate.is_empty():
		report["accepted_candidate"] = accepted_candidate
	return report

func _record_consistency_signals(
	candidates: Array,
	baseline: Dictionary,
	settings: Dictionary,
	acceptance_state: Dictionary,
	pass_index: int
) -> void:
	if acceptance_state.is_empty():
		return
	var small_accept_delta: float = float(settings.get("small_accept_score_delta", TRAINING_DEFAULT_SMALL_ACCEPT_DELTA))
	var table: Dictionary = acceptance_state.get("consistency_table", {})
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		if String(candidate.get("id", "")) == "baseline":
			continue
		var score_delta: float = float(candidate.get("score", 0.0)) - float(baseline.get("score", 0.0))
		if score_delta < small_accept_delta:
			continue
		var category_deltas: Dictionary = _category_delta_map(candidate, baseline)
		if not _candidate_major_regression_reason(category_deltas, settings).is_empty():
			continue
		if score_delta > 0.0 and float(category_deltas.get("economy", 0.0)) < 0.0 and float(category_deltas.get("objective_progress", 0.0)) < 0.0:
			continue
		var signature: String = _candidate_signature(candidate.get("overrides", {}))
		var entry: Dictionary = table.get(signature, {"hits": 0, "last_pass": -999, "last_delta": 0.0})
		var last_pass: int = int(entry.get("last_pass", -999))
		var hits: int = int(entry.get("hits", 0))
		if pass_index - last_pass <= 1:
			hits += 1
		else:
			hits = 1
		entry["hits"] = hits
		entry["last_pass"] = pass_index
		entry["last_delta"] = score_delta
		table[signature] = entry
	acceptance_state["consistency_table"] = table

func _consistency_hits_for_signature(acceptance_state: Dictionary, signature: String) -> int:
	if acceptance_state.is_empty():
		return 0
	var table: Dictionary = acceptance_state.get("consistency_table", {})
	var entry: Dictionary = table.get(signature, {})
	return int(entry.get("hits", 0))

func _training_candidate_decision(
	candidate: Dictionary,
	baseline: Dictionary,
	settings: Dictionary,
	acceptance_state: Dictionary = {},
	pass_context: Dictionary = {}
) -> Dictionary:
	var score_delta: float = float(candidate.get("score", 0.0)) - float(baseline.get("score", 0.0))
	var category_deltas: Dictionary = _category_delta_map(candidate, baseline)
	var economy_delta: float = float(category_deltas.get("economy", 0.0))
	var objective_delta: float = float(category_deltas.get("objective_progress", 0.0))
	var regression_reason: String = _candidate_major_regression_reason(category_deltas, settings)
	if not regression_reason.is_empty():
		return {"accepted": false, "reason": regression_reason, "category_deltas": category_deltas}
	if score_delta > 0.0 and economy_delta < 0.0 and objective_delta < 0.0:
		return {"accepted": false, "reason": "rubric-gaming risk (economy+objective both down)", "category_deltas": category_deltas}

	var min_accept_delta: float = float(settings.get("min_accept_score_delta", TRAINING_DEFAULT_MIN_ACCEPT_DELTA))
	if score_delta >= min_accept_delta:
		return {"accepted": true, "reason": "accepted: score threshold met", "category_deltas": category_deltas}

	var small_accept_delta: float = float(settings.get("small_accept_score_delta", TRAINING_DEFAULT_SMALL_ACCEPT_DELTA))
	var signature: String = _candidate_signature(candidate.get("overrides", {}))
	var consistency_hits: int = _consistency_hits_for_signature(acceptance_state, signature)
	var consistency_required: int = int(settings.get("consistency_required_passes", TRAINING_DEFAULT_CONSISTENT_REQUIRED_PASSES))
	if score_delta >= small_accept_delta and consistency_hits >= consistency_required:
		return {
			"accepted": true,
			"reason": "Accepting %s due to consistent improvement across passes (delta %+0.2f, hits %d)." % [
				String(candidate.get("id", "candidate")),
				score_delta,
				consistency_hits,
			],
			"category_deltas": category_deltas,
		}

	var allow_exploratory: bool = bool(pass_context.get("allow_exploratory", false))
	var exploratory_used: bool = bool(acceptance_state.get("exploratory_used", false))
	if allow_exploratory and not exploratory_used:
		var exploratory_max_drop: float = float(settings.get("exploratory_max_score_drop", TRAINING_DEFAULT_EXPLORATORY_MAX_SCORE_DROP))
		var exploratory_key_gain: float = float(settings.get("exploratory_key_gain", TRAINING_DEFAULT_EXPLORATORY_KEY_GAIN))
		var improves_key_objective: bool = objective_delta >= exploratory_key_gain
		var improves_key_economy: bool = economy_delta >= exploratory_key_gain
		if score_delta >= -exploratory_max_drop and (improves_key_objective or improves_key_economy):
			acceptance_state["exploratory_used"] = true
			return {
				"accepted": true,
				"reason": "Exploratory acceptance after plateau (delta %+0.2f, objective %+0.2f, economy %+0.2f)." % [
					score_delta,
					objective_delta,
					economy_delta,
				],
				"category_deltas": category_deltas,
			}

	if score_delta >= small_accept_delta and consistency_hits > 0:
		return {
			"accepted": false,
			"reason": "small gain seen but consistency hits %d/%d" % [consistency_hits, consistency_required],
			"category_deltas": category_deltas,
		}
	return {"accepted": false, "reason": "score improvement below threshold", "category_deltas": category_deltas}

func _candidate_major_regression_reason(category_deltas: Dictionary, settings: Dictionary) -> String:
	var economy_delta: float = float(category_deltas.get("economy", 0.0))
	var objective_delta: float = float(category_deltas.get("objective_progress", 0.0))
	var role_delta: float = float(category_deltas.get("role_balance", 0.0))
	var specialization_delta: float = float(category_deltas.get("specialization_quality", 0.0))
	if economy_delta < -float(settings.get("max_economy_drop", TRAINING_DEFAULT_MAX_ECONOMY_DROP)):
		return "economy regressed too far"
	if objective_delta < -float(settings.get("max_objective_drop", TRAINING_DEFAULT_MAX_OBJECTIVE_DROP)):
		return "objective progress regressed too far"
	if role_delta < -float(settings.get("max_role_balance_drop", TRAINING_DEFAULT_MAX_ROLE_DROP)):
		return "role balance regressed too far"
	if specialization_delta < -float(settings.get("max_specialization_drop", TRAINING_DEFAULT_MAX_SPECIALIZATION_DROP)):
		return "specialization quality regressed too far"
	return ""

func _category_delta_map(candidate: Dictionary, baseline: Dictionary) -> Dictionary:
	if candidate.is_empty() or baseline.is_empty():
		return {}
	var out: Dictionary = {}
	var candidate_scores: Dictionary = candidate.get("score_by_category", {})
	var baseline_scores: Dictionary = baseline.get("score_by_category", {})
	for category in CATEGORY_ORDER:
		out[category] = float(candidate_scores.get(category, 0.0)) - float(baseline_scores.get(category, 0.0))
	return out

func _format_pass_summary(pass_report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(
		"Pass %d: baseline=%.2f best=%s %.2f" % [
			int(pass_report.get("pass_index", 0)),
			float(pass_report.get("baseline_score_before", 0.0)),
			String(pass_report.get("best_candidate_id", "none")),
			float(pass_report.get("best_candidate_score", 0.0)),
		]
	)
	if bool(pass_report.get("accepted", false)):
		lines.append(
			"  accepted=%s score=%.2f" % [
				String(pass_report.get("accepted_candidate_id", "")),
				float(pass_report.get("accepted_score", 0.0)),
			]
		)
		var accept_reason: String = String(pass_report.get("accept_reason", ""))
		if not accept_reason.is_empty():
			lines.append("  reason: %s" % accept_reason)
		var accepted_deltas: Dictionary = pass_report.get("accepted_category_deltas", {})
		lines.append(
			"  deltas role=%+.2f spec=%+.2f obj=%+.2f econ=%+.2f" % [
				float(accepted_deltas.get("role_balance", 0.0)),
				float(accepted_deltas.get("specialization_quality", 0.0)),
				float(accepted_deltas.get("objective_progress", 0.0)),
				float(accepted_deltas.get("economy", 0.0)),
			]
		)
		var baseline_update: Dictionary = pass_report.get("baseline_update", {})
		var updated_keys: Array = baseline_update.get("updated_keys", [])
		if not updated_keys.is_empty():
			lines.append("  applied keys: %s" % ", ".join(updated_keys))
	else:
		lines.append("  accepted=none")
		var reasons: Array = pass_report.get("rejection_reasons", [])
		for i in range(mini(2, reasons.size())):
			lines.append("  reject: %s" % String(reasons[i]))
	return "\n".join(lines)

func _apply_candidate_to_baseline(baseline_path: String, candidate: Dictionary) -> Dictionary:
	if candidate.is_empty():
		return {"ok": false, "error": "accepted candidate is empty"}
	var baseline_tree: Dictionary = _load_config(baseline_path)
	if baseline_tree.is_empty():
		return {"ok": false, "error": "baseline config missing or invalid at %s" % baseline_path}
	var changed_params: Array = candidate.get("changed_params", [])
	if changed_params.is_empty():
		return {"ok": true, "baseline_path": baseline_path, "updated_keys": [], "updated_values": {}}

	var key_paths: Dictionary = {}
	_collect_leaf_key_paths(baseline_tree, [], key_paths)
	var updated_keys: Array = []
	var updated_values: Dictionary = {}
	for row_variant in changed_params:
		var row: Dictionary = row_variant
		var key: String = String(row.get("key", ""))
		if key.is_empty() or not key_paths.has(key):
			continue
		var clamped_value: Variant = _clamp_tunable_value(key, row.get("candidate", null))
		_set_nested_value(baseline_tree, key_paths[key], clamped_value)
		updated_keys.append(key)
		updated_values[key] = clamped_value
	if updated_keys.is_empty():
		return {"ok": false, "error": "candidate had no baseline-mappable parameter changes"}

	var write_result: Dictionary = _write_json_atomic(baseline_path, baseline_tree)
	if not bool(write_result.get("ok", false)):
		return write_result
	return {
		"ok": true,
		"baseline_path": baseline_path,
		"updated_keys": updated_keys,
		"updated_values": updated_values,
	}

func _collect_leaf_key_paths(source: Dictionary, prefix: Array, out: Dictionary) -> void:
	for key_variant in source.keys():
		var key: String = String(key_variant)
		var next_path: Array = prefix.duplicate()
		next_path.append(key)
		var value: Variant = source[key_variant]
		if value is Dictionary:
			_collect_leaf_key_paths(value as Dictionary, next_path, out)
			continue
		var value_type: int = typeof(value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT:
			if not out.has(key):
				out[key] = next_path

func _set_nested_value(tree: Dictionary, path: Array, value: Variant) -> void:
	if path.is_empty():
		return
	var key: String = String(path[0])
	if path.size() == 1:
		tree[key] = value
		return
	var child: Dictionary = {}
	if tree.has(key) and tree[key] is Dictionary:
		child = (tree[key] as Dictionary).duplicate(true)
	var remainder: Array = path.slice(1, path.size())
	_set_nested_value(child, remainder, value)
	tree[key] = child

func _clamp_tunable_value(key: String, value: Variant) -> Variant:
	if not OozeAI.TUNING_SCHEMA.has(key):
		return value
	var schema: Dictionary = OozeAI.TUNING_SCHEMA[key]
	var value_type: String = String(schema.get("type", "float"))
	var min_value: float = float(schema.get("min", 0.0))
	var max_value: float = float(schema.get("max", min_value))
	var fallback: Variant = schema.get("default", value)
	var numeric_value: float = 0.0
	var source_type: int = typeof(value)
	if source_type == TYPE_INT or source_type == TYPE_FLOAT:
		numeric_value = float(value)
	else:
		numeric_value = float(fallback)
	if value_type == "int":
		return clampi(int(round(numeric_value)), int(round(min_value)), int(round(max_value)))
	return clampf(numeric_value, min_value, max_value)

func _write_json_atomic(path: String, data: Dictionary) -> Dictionary:
	var serialized: String = JSON.stringify(data, "\t")
	var parsed_check: Variant = JSON.parse_string(serialized)
	if not (parsed_check is Dictionary):
		return {"ok": false, "error": "serialized baseline failed validation"}

	var absolute_path: String = ProjectSettings.globalize_path(path)
	var temp_path: String = absolute_path + ".tmp"
	var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return {"ok": false, "error": "cannot open temp file for baseline write"}
	temp_file.store_string(serialized)
	temp_file.close()

	if FileAccess.file_exists(absolute_path):
		var remove_error: Error = DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			return {"ok": false, "error": "cannot replace baseline (remove failed: %d)" % int(remove_error)}
	var rename_error: Error = DirAccess.rename_absolute(temp_path, absolute_path)
	if rename_error != OK:
		var fallback_file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
		if fallback_file == null:
			return {"ok": false, "error": "baseline rename failed (%d) and fallback write failed" % int(rename_error)}
		fallback_file.store_string(serialized)
		fallback_file.close()
		DirAccess.remove_absolute(temp_path)
	return {"ok": true, "path": path}

func _extract_flat_numeric_map_from_file(path: String) -> Dictionary:
	var out: Dictionary = {}
	var parsed: Dictionary = _load_config(path)
	if parsed.is_empty():
		return out
	_collect_numeric_leaf_values(parsed, out)
	return out

func _diff_flat_numeric_maps(before: Dictionary, after: Dictionary) -> Dictionary:
	var keys_set: Dictionary = {}
	for key_variant in before.keys():
		keys_set[String(key_variant)] = true
	for key_variant in after.keys():
		keys_set[String(key_variant)] = true
	var keys: Array = keys_set.keys()
	keys.sort()
	var out: Dictionary = {}
	for key_variant in keys:
		var key: String = String(key_variant)
		var before_value: Variant = before.get(key, null)
		var after_value: Variant = after.get(key, null)
		if _param_values_equal(before_value, after_value):
			continue
		var delta: Variant = _param_delta(before_value, after_value)
		out[key] = {"before": before_value, "after": after_value, "delta": delta}
	return out

func _write_training_reports(output_dir: String, report: Dictionary) -> Dictionary:
	var root_path: String = output_dir
	if root_path.is_empty():
		root_path = DEFAULT_OUTPUT_DIR
	var absolute_dir: String = ProjectSettings.globalize_path(root_path)
	DirAccess.make_dir_recursive_absolute(absolute_dir)

	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var json_path: String = root_path.path_join("ai_training_%s.json" % stamp)
	var txt_path: String = root_path.path_join("ai_training_%s.txt" % stamp)
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(report, "\t"))
	var text_file: FileAccess = FileAccess.open(txt_path, FileAccess.WRITE)
	if text_file != null:
		text_file.store_string(_build_training_readable_report(report))
	return {"json": json_path, "text": txt_path}

func _build_training_readable_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("OOZE AI TRAINING REPORT")
	lines.append("Generated: %s" % String(report.get("generated_at", "")))
	lines.append(
		"Passes: %d  Stop: %s  Elapsed: %.2f min" % [
			int(report.get("passes_run", 0)),
			String(report.get("stop_reason", "")),
			float(report.get("elapsed_ms", 0)) / 60000.0,
		]
	)
	lines.append(
		"Score: start=%s final=%s delta=%s" % [
			_format_param_value(report.get("starting_baseline_score", 0.0)),
			_format_param_value(report.get("final_baseline_score", 0.0)),
			_format_param_delta(report.get("total_improvement", 0.0)),
		]
	)
	lines.append("")
	lines.append("PASS SUMMARIES")
	for pass_variant in report.get("pass_reports", []):
		lines.append(_format_pass_summary(pass_variant))
		lines.append("")
	lines.append("APPLIED PARAMETER CHANGES")
	var applied: Dictionary = report.get("applied_parameter_changes", {})
	if applied.is_empty():
		lines.append("  none")
	else:
		var keys: Array = applied.keys()
		keys.sort()
		for key_variant in keys:
			var key: String = String(key_variant)
			var row: Dictionary = applied[key]
			lines.append(
				"  %s = %s (before %s, delta %s)" % [
					key,
					_format_param_value(row.get("after", null)),
					_format_param_value(row.get("before", null)),
					_format_param_delta(row.get("delta", null)),
				]
			)
	lines.append("")
	lines.append("FINAL BASELINE SNAPSHOT")
	var snapshot: Dictionary = report.get("final_baseline_snapshot", {})
	var snapshot_keys: Array = snapshot.keys()
	snapshot_keys.sort()
	for key_variant in snapshot_keys:
		var key: String = String(key_variant)
		lines.append("  %s = %s" % [key, _format_param_value(snapshot.get(key, null))])
	return "\n".join(lines)

func _build_training_terminal_summary(run_result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("AI multi-pass training completed.")
	lines.append(
		"Passes: %d | Stop: %s | Elapsed: %.2f min" % [
			int(run_result.get("passes_run", 0)),
			String(run_result.get("stop_reason", "")),
			float(run_result.get("elapsed_ms", 0)) / 60000.0,
		]
	)
	lines.append(
		"Baseline score %.2f -> %.2f (delta %+0.2f)" % [
			float(run_result.get("starting_baseline_score", 0.0)),
			float(run_result.get("final_baseline_score", 0.0)),
			float(run_result.get("total_improvement", 0.0)),
		]
	)
	var applied: Dictionary = run_result.get("applied_parameter_changes", {})
	lines.append("Parameters changed: %d" % int(applied.size()))
	var output: Dictionary = run_result.get("output", {})
	if not output.is_empty():
		lines.append("JSON: %s" % String(output.get("json", "")))
		lines.append("Text: %s" % String(output.get("text", "")))
	return "\n".join(lines)

func _run_tuning(config: Dictionary, budget_context: Dictionary = {}) -> Dictionary:
	var pass_start_ms: int = Time.get_ticks_msec()
	var loaded_templates: Array = _load_room_templates()
	if loaded_templates.is_empty():
		return {"ok": false, "error": "room template list is empty"}
	var room_templates: Array = _filter_valid_templates(loaded_templates)
	if room_templates.is_empty():
		return {"ok": false, "error": "no valid room templates after validation"}
	if room_templates.size() < loaded_templates.size():
		print(
			"AI tuner: filtered template pool from %d to %d valid templates." % [
				loaded_templates.size(),
				room_templates.size(),
			]
		)

	var checkpoints: Array = _checkpoint_list_from_config(config)
	var checkpoint_weights: Dictionary = _checkpoint_weights_from_config(config, checkpoints)
	var scenarios: Array = _normalized_scenarios(config)
	scenarios = _ensure_outcome_scenario(scenarios)
	var scenario_mix: Dictionary = _scenario_mix_settings_from_config(config)
	scenarios = _apply_scenario_mix_for_candidate(scenarios, scenario_mix)
	if scenarios.is_empty():
		return {"ok": false, "error": "no scenarios configured"}
	var scenario_counts: Dictionary = _scenario_runs_per_candidate(scenarios)
	print(
		"Scenario mix: %d fast runs, %d outcome runs per candidate (fast_ratio=%.2f, min_outcome=%d)." % [
			int(scenario_counts.get("fast_runs", 0)),
			int(scenario_counts.get("outcome_runs", 0)),
			float(scenario_mix.get("fast_scenario_ratio", TRAINING_DEFAULT_FAST_SCENARIO_RATIO)),
			int(scenario_mix.get("min_outcome_scenarios", TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS)),
		]
	)

	var candidates: Array = _build_candidates(config)
	if candidates.is_empty():
		return {"ok": false, "error": "no candidates generated"}
	var planned_candidate_count: int = candidates.size()
	var workload: Dictionary = _estimate_workload(candidates, scenarios, checkpoints)
	var estimated_breakdown: Dictionary = _estimate_runtime_breakdown_for_workload(workload, budget_context)
	var estimated_pass_seconds: float = float(estimated_breakdown.get("total_seconds", 0.0))
	print(
		"Planned workload: %d candidates, %d simulations (fast %d / outcome %d), estimated %d actor-turns (runtime %.2f min)." % [
			int(workload.get("candidate_count", 0)),
			int(workload.get("simulation_count", 0)),
			int(workload.get("fast_simulation_count", 0)),
			int(workload.get("outcome_simulation_count", 0)),
			int(workload.get("estimated_actor_turns", 0)),
			estimated_pass_seconds / 60.0,
		]
	)
	print(
		"Estimated runtime split: fast %.2f min + outcome %.2f min." % [
			float(estimated_breakdown.get("fast_seconds", 0.0)) / 60.0,
			float(estimated_breakdown.get("outcome_seconds", 0.0)) / 60.0,
		]
	)

	var candidate_results: Array = []
	var local_elapsed_seconds: float = 0.0
	var local_fast_elapsed_seconds: float = 0.0
	var local_outcome_elapsed_seconds: float = 0.0
	var local_fast_simulations: int = 0
	var local_outcome_simulations: int = 0
	var local_fast_actor_turns: float = 0.0
	var local_outcome_actor_turns: float = 0.0
	var budget_stop: bool = false
	var budget_stop_reason: String = ""
	var candidate_workload_seconds: float = _estimated_candidate_seconds(workload, budget_context)
	for candidate_index in range(candidates.size()):
		if bool(budget_context.get("enabled", false)) and candidate_index > 0:
			var remaining_seconds: float = maxf(
				0.0,
				float(int(budget_context.get("deadline_ms", Time.get_ticks_msec())) - Time.get_ticks_msec()) / 1000.0
			)
			var projected_candidate_seconds: float = candidate_workload_seconds
			if candidate_results.size() > 0 and local_elapsed_seconds > 0.0:
				projected_candidate_seconds = local_elapsed_seconds / float(candidate_results.size())
			var overrun_tolerance: float = float(
				budget_context.get("overrun_tolerance_seconds", TRAINING_DEFAULT_OVERRUN_TOLERANCE_SECONDS)
			)
			if remaining_seconds + overrun_tolerance < projected_candidate_seconds:
				budget_stop = true
				budget_stop_reason = "Projected %.2f min for next candidate exceeds remaining %.2f min (tolerance %.2f min)." % [
					projected_candidate_seconds / 60.0,
					remaining_seconds / 60.0,
					overrun_tolerance / 60.0,
				]
				print("AI tuner budget stop before candidate %d/%d: %s" % [candidate_index + 1, candidates.size(), budget_stop_reason])
				break

		var candidate: Dictionary = candidates[candidate_index]
		print(
			"Evaluating candidate %s: %d fast scenarios, %d outcome scenario(s)." % [
				String(candidate.get("id", "?")),
				int(scenario_counts.get("fast_runs", 0)),
				int(scenario_counts.get("outcome_runs", 0)),
			]
		)
		var candidate_start_ms: int = Time.get_ticks_msec()
		var eval: Dictionary = _evaluate_candidate(candidate, scenarios, checkpoints, checkpoint_weights, room_templates)
		candidate_results.append(eval)
		var candidate_elapsed_seconds: float = maxf(0.0, float(Time.get_ticks_msec() - candidate_start_ms) / 1000.0)
		local_elapsed_seconds += candidate_elapsed_seconds
		var candidate_runtime: Dictionary = eval.get("runtime_breakdown", {})
		var fast_runtime: Dictionary = candidate_runtime.get("fast", {})
		var outcome_runtime: Dictionary = candidate_runtime.get("outcome", {})
		local_fast_elapsed_seconds += float(fast_runtime.get("elapsed_seconds", 0.0))
		local_outcome_elapsed_seconds += float(outcome_runtime.get("elapsed_seconds", 0.0))
		local_fast_simulations += int(fast_runtime.get("simulations", 0))
		local_outcome_simulations += int(outcome_runtime.get("simulations", 0))
		local_fast_actor_turns += float(fast_runtime.get("actor_turns", 0.0))
		local_outcome_actor_turns += float(outcome_runtime.get("actor_turns", 0.0))
		print("Candidate %s -> score %.2f" % [String(eval.get("id", "?")), float(eval.get("score", 0.0))])
		if bool(budget_context.get("enabled", false)):
			var observed_seconds_per_candidate: float = local_elapsed_seconds / maxf(1.0, float(candidate_results.size()))
			var remaining_candidates: int = maxi(0, planned_candidate_count - candidate_results.size())
			var projected_remaining_seconds: float = observed_seconds_per_candidate * float(remaining_candidates)
			var remaining_seconds_after: float = maxf(
				0.0,
				float(int(budget_context.get("deadline_ms", Time.get_ticks_msec())) - Time.get_ticks_msec()) / 1000.0
			)
			print(
				"Timing: elapsed %.2f min | observed %.2fs/candidate | projected remaining %.2f min | budget remaining %.2f min" % [
					local_elapsed_seconds / 60.0,
					observed_seconds_per_candidate,
					projected_remaining_seconds / 60.0,
					remaining_seconds_after / 60.0,
				]
			)

	if candidate_results.is_empty():
		return {"ok": false, "error": "no candidates evaluated (budget too restrictive)"}

	candidate_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", -999999.0)) > float(b.get("score", -999999.0))
	)

	var baseline_defaults: Dictionary = _load_baseline_tuning_defaults()
	var parameter_keys: Array = _report_parameter_keys(config, baseline_defaults, candidate_results)
	candidate_results = _annotate_candidates_with_params(candidate_results, baseline_defaults, parameter_keys)
	var top_n: int = maxi(1, int(config.get("top_n", 5)))
	var baseline: Dictionary = _find_candidate_result(candidate_results, "baseline")
	var filtered_candidates: Array = _candidate_results_with_guardrails(candidate_results, baseline)
	var top_candidates: Array = filtered_candidates.slice(0, mini(top_n, filtered_candidates.size()))
	if top_candidates.is_empty():
		top_candidates = candidate_results.slice(0, mini(top_n, candidate_results.size()))
	var recommendations: Array = _build_recommendations(baseline, top_candidates)

	var report: Dictionary = {
		"ok": true,
		"generated_at": Time.get_datetime_string_from_system(),
		"config_used": config,
		"checkpoints": checkpoints,
		"checkpoint_weights": checkpoint_weights,
		"scenario_mix": scenario_mix,
		"scenario_runs_per_candidate": scenario_counts,
		"parameter_keys": parameter_keys,
		"baseline_effective_params": baseline.get("effective_params", {}),
		"workload": workload,
		"template_ids": _template_id_list(room_templates),
		"scenario_count": scenarios.size(),
		"candidate_count": candidate_results.size(),
		"planned_candidate_count": planned_candidate_count,
		"baseline": baseline,
		"top_candidates": top_candidates,
		"all_candidates": candidate_results,
		"recommendations": recommendations,
	}
	var runtime_stats: Dictionary = {
		"elapsed_seconds": maxf(0.0, float(Time.get_ticks_msec() - pass_start_ms) / 1000.0),
		"planned_candidate_count": planned_candidate_count,
		"evaluated_candidate_count": candidate_results.size(),
		"planned_simulation_count": int(workload.get("simulation_count", 0)),
		"evaluated_simulation_count": local_fast_simulations + local_outcome_simulations,
		"planned_actor_turns": float(workload.get("estimated_actor_turns", 0)),
		"evaluated_actor_turns": local_fast_actor_turns + local_outcome_actor_turns,
		"planned_fast_simulation_count": int(workload.get("fast_simulation_count", 0)),
		"planned_outcome_simulation_count": int(workload.get("outcome_simulation_count", 0)),
		"evaluated_fast_simulation_count": local_fast_simulations,
		"evaluated_outcome_simulation_count": local_outcome_simulations,
		"planned_fast_actor_turns": float(workload.get("fast_actor_turns", 0)),
		"planned_outcome_actor_turns": float(workload.get("outcome_actor_turns", 0)),
		"evaluated_fast_actor_turns": local_fast_actor_turns,
		"evaluated_outcome_actor_turns": local_outcome_actor_turns,
		"fast_elapsed_seconds": local_fast_elapsed_seconds,
		"outcome_elapsed_seconds": local_outcome_elapsed_seconds,
		"budget_stop": budget_stop,
		"budget_stop_reason": budget_stop_reason,
		"estimated_pass_seconds": estimated_pass_seconds,
	}
	report["runtime_stats"] = runtime_stats
	workload["planned_candidate_count"] = planned_candidate_count
	workload["evaluated_candidate_count"] = candidate_results.size()
	workload["evaluated_simulation_count"] = int(runtime_stats.get("evaluated_simulation_count", 0))
	workload["evaluated_actor_turns"] = float(runtime_stats.get("evaluated_actor_turns", 0.0))
	workload["evaluated_fast_simulation_count"] = int(runtime_stats.get("evaluated_fast_simulation_count", 0))
	workload["evaluated_outcome_simulation_count"] = int(runtime_stats.get("evaluated_outcome_simulation_count", 0))
	workload["evaluated_fast_actor_turns"] = float(runtime_stats.get("evaluated_fast_actor_turns", 0.0))
	workload["evaluated_outcome_actor_turns"] = float(runtime_stats.get("evaluated_outcome_actor_turns", 0.0))
	report["workload"] = workload

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

func _checkpoint_weights_from_config(config: Dictionary, checkpoints: Array) -> Dictionary:
	var raw: Dictionary = config.get("checkpoint_weights", {})
	var out: Dictionary = {}
	var total_weight: float = 0.0
	for checkpoint_variant in checkpoints:
		var checkpoint_turn: int = int(checkpoint_variant)
		var key: String = str(checkpoint_turn)
		var weight: float = _default_checkpoint_weight(checkpoint_turn)
		if raw.has(key):
			weight = maxf(0.01, float(raw[key]))
		elif raw.has(checkpoint_turn):
			weight = maxf(0.01, float(raw[checkpoint_turn]))
		out[key] = weight
		total_weight += weight
	if total_weight <= 0.0:
		for checkpoint_variant in checkpoints:
			out[str(int(checkpoint_variant))] = 1.0
	return out

func _default_checkpoint_weight(checkpoint_turn: int) -> float:
	if checkpoint_turn <= 15:
		return 0.90
	if checkpoint_turn <= 35:
		return 1.25
	if checkpoint_turn <= 60:
		return 1.15
	return 0.90

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
		var stop_at_last_checkpoint: bool = bool(src.get("stop_at_last_checkpoint", true))
		var declared_type: String = String(src.get("scenario_type", "")).strip_edges().to_lower()
		var scenario_type: String = declared_type
		if scenario_type != "fast" and scenario_type != "outcome":
			scenario_type = "fast" if stop_at_last_checkpoint else "outcome"
		if scenario_type == "outcome":
			stop_at_last_checkpoint = false
		elif scenario_type == "fast":
			stop_at_last_checkpoint = true
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
			"stop_at_last_checkpoint": stop_at_last_checkpoint,
			"outcome_check_interval": maxi(1, int(src.get("outcome_check_interval", 8))),
			"scenario_type": scenario_type,
		}
		out.append(scenario)
	return out

func _scenario_mix_settings_from_config(config: Dictionary) -> Dictionary:
	var training: Dictionary = config.get("training", {})
	var scenario_mix: Dictionary = training.get("scenario_mix", {})
	return {
		"fast_scenario_ratio": clampf(
			float(scenario_mix.get("fast_scenario_ratio", TRAINING_DEFAULT_FAST_SCENARIO_RATIO)),
			0.55,
			0.95
		),
		"min_outcome_scenarios": maxi(
			1,
			int(scenario_mix.get("min_outcome_scenarios", TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS))
		),
	}

func _scenario_type(scenario: Dictionary) -> String:
	var t: String = String(scenario.get("scenario_type", "")).strip_edges().to_lower()
	if t == "fast" or t == "outcome":
		return t
	return "fast" if bool(scenario.get("stop_at_last_checkpoint", true)) else "outcome"

func _scenario_runs_per_candidate(scenarios: Array) -> Dictionary:
	var fast_runs: int = 0
	var outcome_runs: int = 0
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		var runs_for_scenario: int = (scenario.get("seeds", [1337]) as Array).size() * maxi(1, int(scenario.get("runs_per_seed", 1)))
		if _scenario_type(scenario) == "outcome":
			outcome_runs += runs_for_scenario
		else:
			fast_runs += runs_for_scenario
	return {
		"fast_runs": fast_runs,
		"outcome_runs": outcome_runs,
		"total_runs": fast_runs + outcome_runs,
	}

func _apply_scenario_mix_for_candidate(scenarios: Array, mix_settings: Dictionary) -> Array:
	if scenarios.is_empty():
		return scenarios
	var fast: Array = []
	var outcome: Array = []
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		if _scenario_type(scenario) == "outcome":
			outcome.append(scenario)
		else:
			fast.append(scenario)
	if outcome.is_empty():
		return scenarios

	var min_outcome: int = mini(outcome.size(), maxi(1, int(mix_settings.get("min_outcome_scenarios", TRAINING_DEFAULT_MIN_OUTCOME_SCENARIOS))))
	var fast_ratio: float = clampf(float(mix_settings.get("fast_scenario_ratio", TRAINING_DEFAULT_FAST_SCENARIO_RATIO)), 0.55, 0.95)
	var outcome_fraction: float = maxf(0.05, 1.0 - fast_ratio)
	var target_outcome: int = maxi(min_outcome, int(round(float(scenarios.size()) * outcome_fraction)))
	target_outcome = clampi(target_outcome, min_outcome, outcome.size())
	var target_fast: int = fast.size()
	if target_outcome > 0:
		target_fast = mini(
			fast.size(),
			maxi(1, int(round(float(target_outcome) * (fast_ratio / outcome_fraction))))
		)
	var selected: Array = []
	var fast_left: int = target_fast
	var outcome_left: int = target_outcome
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		var t: String = _scenario_type(scenario)
		if t == "outcome":
			if outcome_left <= 0:
				continue
			outcome_left -= 1
			selected.append(scenario)
		else:
			if fast_left <= 0:
				continue
			fast_left -= 1
			selected.append(scenario)
	if selected.is_empty():
		return scenarios
	var selected_outcome: int = 0
	for scenario_variant in selected:
		var selected_scenario: Dictionary = scenario_variant
		if _scenario_type(selected_scenario) == "outcome":
			selected_outcome += 1
	if selected_outcome < min_outcome:
		return scenarios
	return selected

func _ensure_outcome_scenario(scenarios: Array) -> Array:
	if scenarios.is_empty():
		return scenarios
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		if _scenario_type(scenario) == "outcome":
			return scenarios

	var added: Dictionary = (scenarios[0] as Dictionary).duplicate(true)
	added["name"] = "%s_outcome" % String(added.get("name", "scenario_0"))
	added["stop_at_last_checkpoint"] = false
	added["scenario_type"] = "outcome"
	added["turn_limit"] = maxi(120, int(added.get("turn_limit", 100)))
	scenarios.append(added)
	print("AI tuner: appended `%s` to guarantee at least one outcome-seeking scenario." % String(added.get("name", "scenario_outcome")))
	return scenarios

func _estimate_workload(candidates: Array, scenarios: Array, checkpoints: Array) -> Dictionary:
	var simulation_count: int = 0
	var actor_turns: int = 0
	var fast_simulation_count: int = 0
	var outcome_simulation_count: int = 0
	var fast_actor_turns: int = 0
	var outcome_actor_turns: int = 0
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		var seeds: Array = scenario.get("seeds", [1337])
		var runs_per_seed: int = maxi(1, int(scenario.get("runs_per_seed", 1)))
		var runs_for_scenario: int = seeds.size() * runs_per_seed
		var step_cap: int = _scenario_step_cap(scenario, checkpoints)
		simulation_count += runs_for_scenario * candidates.size()
		actor_turns += runs_for_scenario * step_cap * candidates.size()
		if _scenario_type(scenario) == "outcome":
			outcome_simulation_count += runs_for_scenario * candidates.size()
			outcome_actor_turns += runs_for_scenario * step_cap * candidates.size()
		else:
			fast_simulation_count += runs_for_scenario * candidates.size()
			fast_actor_turns += runs_for_scenario * step_cap * candidates.size()
	return {
		"candidate_count": candidates.size(),
		"simulation_count": simulation_count,
		"estimated_actor_turns": actor_turns,
		"fast_simulation_count": fast_simulation_count,
		"outcome_simulation_count": outcome_simulation_count,
		"fast_actor_turns": fast_actor_turns,
		"outcome_actor_turns": outcome_actor_turns,
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
		if candidates.size() >= max_total:
			return candidates
		var merged: Dictionary = fixed.duplicate(true)
		merged.merge(c, true)
		candidates.append({
			"id": "grid_%d" % candidates.size(),
			"label": "Grid %d" % candidates.size(),
			"overrides": merged,
		})

	var random_parameters: Dictionary = search.get("random_parameters", {})
	var random_seed: int = int(search.get("random_seed", 1337))
	var random_iterations: int = maxi(0, int(search.get("random_iterations", 16)))
	var random_candidates: Array = _build_random_candidates(random_parameters, random_iterations, random_seed)
	for c in random_candidates:
		if candidates.size() >= max_total:
			return candidates
		var merged_random: Dictionary = fixed.duplicate(true)
		merged_random.merge(c, true)
		candidates.append({
			"id": "rand_%d" % candidates.size(),
			"label": "Random %d" % candidates.size(),
			"overrides": merged_random,
		})

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

func _evaluate_candidate(candidate: Dictionary, scenarios: Array, checkpoints: Array, checkpoint_weights: Dictionary, room_templates: Array) -> Dictionary:
	var per_run: Array = []
	var runtime_breakdown: Dictionary = {
		"fast": {"simulations": 0, "elapsed_seconds": 0.0, "actor_turns": 0.0},
		"outcome": {"simulations": 0, "elapsed_seconds": 0.0, "actor_turns": 0.0},
	}
	for scenario_variant in scenarios:
		var scenario: Dictionary = scenario_variant
		var scenario_type: String = _scenario_type(scenario)
		var scenario_templates: Array = _select_templates_for_scenario(room_templates, scenario)
		if scenario_templates.is_empty():
			print(
				"AI tuner warning: scenario `%s` template_ids %s resolved no templates; falling back to validated pool." % [
					String(scenario.get("name", "scenario")),
					JSON.stringify(scenario.get("template_ids", [])),
				]
			)
			scenario_templates = room_templates
		var seeds: Array = scenario.get("seeds", [1337])
		var runs_per_seed: int = maxi(1, int(scenario.get("runs_per_seed", 1)))
		for seed_variant in seeds:
			var base_seed: int = int(seed_variant)
			for run_offset in range(runs_per_seed):
				var run_seed: int = base_seed + run_offset * 1013
				var run_start_ms: int = Time.get_ticks_msec()
				var run_result: Dictionary = _run_single_simulation(candidate, scenario, run_seed, checkpoints, scenario_templates)
				var run_elapsed_seconds: float = maxf(0.0, float(Time.get_ticks_msec() - run_start_ms) / 1000.0)
				run_result["runtime_seconds"] = run_elapsed_seconds
				run_result["scenario_type"] = scenario_type
				per_run.append(run_result)
				var bucket: Dictionary = runtime_breakdown.get(scenario_type, {"simulations": 0, "elapsed_seconds": 0.0, "actor_turns": 0.0})
				bucket["simulations"] = int(bucket.get("simulations", 0)) + 1
				bucket["elapsed_seconds"] = float(bucket.get("elapsed_seconds", 0.0)) + run_elapsed_seconds
				bucket["actor_turns"] = float(bucket.get("actor_turns", 0.0)) + float(run_result.get("final_turn", 0))
				runtime_breakdown[scenario_type] = bucket
	var aggregate: Dictionary = _aggregate_candidate_runs(per_run, checkpoints, checkpoint_weights)
	return {
		"id": String(candidate.get("id", "candidate")),
		"label": String(candidate.get("label", "candidate")),
		"overrides": (candidate.get("overrides", {}) as Dictionary).duplicate(true),
		"score": float(aggregate.get("score", 0.0)),
		"score_by_category": aggregate.get("score_by_category", {}),
		"score_by_checkpoint": aggregate.get("score_by_checkpoint", {}),
		"pathology_counts": aggregate.get("pathology_counts", {}),
		"runs": per_run,
		"runtime_breakdown": runtime_breakdown,
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
		"scenario_type": _scenario_type(scenario),
		"seed": run_seed,
		"final_turn": state.turn_index,
		"outcome": outcome,
		"final_objective": _objective_metrics(state, tracker.get("initial_state", state)),
		"ran_to_outcome_window": not bool(scenario.get("stop_at_last_checkpoint", true)),
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

func _template_id_list(room_templates: Array) -> Array:
	var ids: Array = []
	for template_variant in room_templates:
		var room: Dictionary = template_variant
		var template_id: String = String(room.get("id", ""))
		if template_id.is_empty():
			continue
		ids.append(template_id)
	return ids

func _filter_valid_templates(room_templates: Array) -> Array:
	var out: Array = []
	for template_variant in room_templates:
		var room: Dictionary = template_variant
		if _is_template_valid_for_tuning(room):
			out.append(room.duplicate(true))
		else:
			print("AI tuner: skipped template `%s` (failed validity checks)." % String(room.get("id", "unknown")))
	return out

func _is_template_valid_for_tuning(room: Dictionary) -> bool:
	var width: int = int(room.get("width", 0))
	var height: int = int(room.get("height", 0))
	if width < 10 or height < 8:
		return false
	var total_tiles: int = width * height
	if total_tiles <= 0:
		return false

	var player_seed: Vector2i = _tile_from_variant(room.get("player_seed", []))
	var door_tile: Vector2i = _tile_from_variant(room.get("door", []))
	if not _is_inside_template(width, height, player_seed):
		return false
	if not _is_inside_template(width, height, door_tile):
		return false

	var blocked: Dictionary = _blocked_tile_set(room.get("walls", []), width, height)
	var wall_ratio: float = float(blocked.size()) / float(total_tiles)
	if wall_ratio > MAX_TEMPLATE_WALL_RATIO:
		return false
	var open_ratio: float = 1.0 - wall_ratio
	if open_ratio < MIN_TEMPLATE_OPEN_RATIO:
		return false

	if blocked.has(_tile_key(player_seed)) or blocked.has(_tile_key(door_tile)):
		return false
	if not _template_has_path(width, height, blocked, player_seed, door_tile):
		return false

	var reachable_resource_count: int = 0
	for node_variant in room.get("resource_nodes", []):
		var node: Array = node_variant
		if node.size() < 2:
			continue
		var resource_tile: Vector2i = Vector2i(int(node[0]), int(node[1]))
		if not _is_inside_template(width, height, resource_tile):
			continue
		if blocked.has(_tile_key(resource_tile)):
			continue
		if _template_has_path(width, height, blocked, player_seed, resource_tile):
			reachable_resource_count += 1
	if reachable_resource_count <= 0:
		return false
	return true

func _tile_from_variant(value: Variant) -> Vector2i:
	if value is Array:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i(-1, -1)

func _blocked_tile_set(walls: Array, width: int, height: int) -> Dictionary:
	var blocked: Dictionary = {}
	for wall_variant in walls:
		var wall_pos: Vector2i = _tile_from_variant(wall_variant)
		if not _is_inside_template(width, height, wall_pos):
			continue
		blocked[_tile_key(wall_pos)] = true
	return blocked

func _is_inside_template(width: int, height: int, tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height

func _template_has_path(width: int, height: int, blocked: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	if start == goal:
		return true
	var queue: Array = [start]
	var visited: Dictionary = {_tile_key(start): true}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_tile: Vector2i = current + step
			if not _is_inside_template(width, height, next_tile):
				continue
			var next_key: String = _tile_key(next_tile)
			if visited.has(next_key):
				continue
			if blocked.has(next_key):
				continue
			if next_tile == goal:
				return true
			visited[next_key] = true
			queue.append(next_tile)
	return false

func _aggregate_candidate_runs(per_run: Array, checkpoints: Array, checkpoint_weights: Dictionary) -> Dictionary:
	if per_run.is_empty():
		return {"score": 0.0, "score_by_category": {}, "score_by_checkpoint": {}, "pathology_counts": {}}

	var total_weighted_score: float = 0.0
	var total_weight: float = 0.0
	var total_samples: int = 0
	var category_sums: Dictionary = {}
	var checkpoint_sums: Dictionary = {}
	var checkpoint_counts: Dictionary = {}
	var pathology_sums: Dictionary = {}
	var outcome_bonus_sum: float = 0.0
	var outcome_samples: float = 0.0

	for run_variant in per_run:
		var run: Dictionary = run_variant
		var outcome_weight: float = OUTCOME_FAST_SAMPLE_WEIGHT
		if String(run.get("scenario_type", "fast")) == "outcome":
			outcome_weight = OUTCOME_SCENARIO_SAMPLE_WEIGHT
		outcome_bonus_sum += _run_outcome_bonus(run) * outcome_weight
		outcome_samples += outcome_weight
		var checkpoint_scores: Dictionary = run.get("checkpoints", {})
		for cp in checkpoints:
			var key: String = str(int(cp))
			if not checkpoint_scores.has(key):
				continue
			var snapshot: Dictionary = checkpoint_scores[key]
			var score: float = float(snapshot.get("total_score", 0.0))
			var sample_weight: float = maxf(0.01, float(checkpoint_weights.get(key, 1.0)))
			total_weighted_score += score * sample_weight
			total_weight += sample_weight
			total_samples += 1
			checkpoint_sums[key] = float(checkpoint_sums.get(key, 0.0)) + score
			checkpoint_counts[key] = int(checkpoint_counts.get(key, 0)) + 1

			var categories: Dictionary = snapshot.get("category_scores", {})
			for category_key in categories.keys():
				var cat: String = String(category_key)
				category_sums[cat] = float(category_sums.get(cat, 0.0)) + float(categories[cat]) * sample_weight

			var pathologies: Dictionary = snapshot.get("pathology", {})
			for pathology_key in pathologies.keys():
				var pathology: String = String(pathology_key)
				pathology_sums[pathology] = float(pathology_sums.get(pathology, 0.0)) + float(pathologies[pathology]) * sample_weight

	var score_by_category: Dictionary = {}
	for category_key in category_sums.keys():
		score_by_category[String(category_key)] = float(category_sums[category_key]) / maxf(1.0, total_weight)

	var score_by_checkpoint: Dictionary = {}
	for checkpoint_key in checkpoint_sums.keys():
		var divisor: int = int(checkpoint_counts.get(checkpoint_key, 0))
		score_by_checkpoint[String(checkpoint_key)] = float(checkpoint_sums[checkpoint_key]) / maxf(1.0, float(divisor))

	var pathology_counts: Dictionary = {}
	for pathology_key in pathology_sums.keys():
		pathology_counts[String(pathology_key)] = float(pathology_sums[pathology_key]) / maxf(1.0, total_weight)

	var base_score: float = total_weighted_score / maxf(1.0, total_weight)
	var outcome_bonus: float = outcome_bonus_sum / maxf(1.0, outcome_samples)
	var final_score: float = clampf(base_score + outcome_bonus, 0.0, 100.0)

	return {
		"score": final_score,
		"outcome_bonus": outcome_bonus,
		"score_by_category": score_by_category,
		"score_by_checkpoint": score_by_checkpoint,
		"pathology_counts": pathology_counts,
	}

func _run_outcome_bonus(run: Dictionary) -> float:
	var outcome: Dictionary = run.get("outcome", {})
	var status: String = String(outcome.get("status", "ongoing"))
	var bonus: float = 0.0
	match status:
		"victory":
			bonus += OUTCOME_VICTORY_BONUS
		"defeat":
			bonus += OUTCOME_DEFEAT_PENALTY
		_:
			if bool(run.get("ran_to_outcome_window", false)):
				bonus += OUTCOME_UNRESOLVED_PENALTY
	var objective: Dictionary = run.get("final_objective", {})
	bonus += float(objective.get("heart_destroy_progress", 0.0)) * 5.0
	bonus += float(objective.get("door_progress", 0.0)) * 3.0
	return bonus

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
	var resource_control: float = float(objective.get("resource_control", 0.0))
	var resource_progress: float = float(objective.get("resource_progress", 0.0))
	var resource_neglect: int = 0
	if checkpoint_turn >= 50 and resource_control <= 0.05 and resource_progress <= 0.0:
		resource_neglect = 1

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
			"resource_neglect": resource_neglect,
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
	if checkpoint_turn >= 90:
		target_specialized = 0.46
	var specialization_quality: float = 100.0 - absf(specialized_ratio - target_specialized) * 180.0
	specialization_quality -= float(metrics.get("backline_specialized_ratio", 0.0)) * 60.0
	var tier_counts: Dictionary = metrics.get("tier_counts", {})
	var tier_total: float = maxf(1.0, float(tier_counts.get("1", 0)) + float(tier_counts.get("2", 0)) + float(tier_counts.get("3", 0)))
	var deep_tier_ratio: float = (float(tier_counts.get("2", 0)) + float(tier_counts.get("3", 0))) / tier_total
	var tier1_share: float = float(tier_counts.get("1", 0)) / tier_total
	specialization_quality += deep_tier_ratio * 24.0
	specialization_quality -= maxf(0.0, tier1_share - 0.74) * 28.0
	specialization_quality = clampf(specialization_quality, 0.0, 100.0)

	var objective: Dictionary = metrics.get("objective", {})
	var objective_progress: float = 36.0
	var resource_progress: float = float(objective.get("resource_progress", 0.0))
	var military_progress: float = float(objective.get("military_progress", 0.0))
	var resource_control: float = float(objective.get("resource_control", 0.0))
	var heart_destroy_progress: float = float(objective.get("heart_destroy_progress", 0.0))
	var door_progress: float = float(objective.get("door_progress", 0.0))
	objective_progress += resource_progress * 30.0
	objective_progress += military_progress * 18.0
	objective_progress += resource_control * 24.0
	objective_progress += heart_destroy_progress * 22.0
	objective_progress += door_progress * 16.0
	if checkpoint_turn >= 50 and resource_control <= 0.05:
		objective_progress -= 12.0
	if resource_progress < -0.10:
		objective_progress -= 6.0
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
	anti_pathology -= float(metrics.get("pathology", {}).get("resource_neglect", 0)) * 10.0
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
		"role_balance": 0.20,
		"specialization_quality": 0.17,
		"objective_progress": 0.25,
		"economy": 0.18,
		"board_shape": 0.10,
		"anti_pathology": 0.10,
	}
	var total: float = 0.0
	for category_key in weights.keys():
		var key: String = String(category_key)
		var w: float = float(weights[key])
		total += float(category_scores.get(key, 0.0)) * w
	var economy: float = float(category_scores.get("economy", 0.0))
	var objective_progress: float = float(category_scores.get("objective_progress", 0.0))
	var anti_pathology: float = float(category_scores.get("anti_pathology", 0.0))
	var guardrail_penalty: float = 0.0
	if economy < 45.0:
		guardrail_penalty += (45.0 - economy) * 0.45
	if objective_progress < 42.0:
		guardrail_penalty += (42.0 - objective_progress) * 0.25
	if anti_pathology < 55.0:
		guardrail_penalty += (55.0 - anti_pathology) * 0.12
	if economy < 45.0 and objective_progress < 45.0:
		guardrail_penalty += 3.0
	return clampf(total - guardrail_penalty, 0.0, 100.0)

func _objective_metrics(state: GameState, initial_state: GameState) -> Dictionary:
	var ai_owners: Array = _ai_owner_ids(state)
	var resource_delta_accum: float = 0.0
	var military_delta_accum: float = 0.0
	var heart_destroy_accum: float = 0.0
	var door_progress_accum: float = 0.0
	var resource_control_accum: float = 0.0
	var sample_count: int = 0
	var resource_node_count: int = _resource_node_count(state)

	for owner_variant in ai_owners:
		var owner_id: int = int(owner_variant)
		var now_dist_resource: int = _owner_distance_to_nearest_open_resource(state, owner_id)
		var init_dist_resource: int = _owner_distance_to_nearest_open_resource(initial_state, owner_id)
		var now_dist_military: int = _owner_distance_to_military_objective(state, owner_id)
		var init_dist_military: int = _owner_distance_to_military_objective(initial_state, owner_id)
		var init_hostile_hearts: int = _owner_hostile_heart_count(initial_state, owner_id)
		var now_hostile_hearts: int = _owner_hostile_heart_count(state, owner_id)

		resource_delta_accum += _distance_progress_score(init_dist_resource, now_dist_resource)
		military_delta_accum += _distance_progress_score(init_dist_military, now_dist_military)
		heart_destroy_accum += _heart_destroy_progress(init_hostile_hearts, now_hostile_hearts)
		door_progress_accum += _owner_door_progress(state, initial_state, owner_id)
		resource_control_accum += _owner_resource_control_ratio(state, owner_id, resource_node_count)
		sample_count += 1

	return {
		"resource_progress": resource_delta_accum / maxf(1.0, float(sample_count)),
		"military_progress": military_delta_accum / maxf(1.0, float(sample_count)),
		"heart_destroy_progress": heart_destroy_accum / maxf(1.0, float(sample_count)),
		"door_progress": door_progress_accum / maxf(1.0, float(sample_count)),
		"resource_control": resource_control_accum / maxf(1.0, float(sample_count)),
	}

func _distance_progress_score(before: int, after: int) -> float:
	if before >= MAX_DISTANCE_SENTINEL and after >= MAX_DISTANCE_SENTINEL:
		return 0.0
	if before >= MAX_DISTANCE_SENTINEL:
		return 0.0
	if after >= MAX_DISTANCE_SENTINEL:
		return 1.0
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

func _resource_node_count(state: GameState) -> int:
	return state.resource_nodes.size()

func _owner_resource_control_ratio(state: GameState, owner_id: int, resource_node_count: int) -> float:
	if resource_node_count <= 0:
		return 0.0
	var controlled: int = 0
	var position_owner_index: Dictionary = {}
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var pos: Vector2i = block.get("pos", Vector2i(-1, -1))
		position_owner_index[_tile_key(pos)] = int(block.get("owner", -1))
	for node_variant in state.resource_nodes:
		var node: Dictionary = node_variant
		if bool(node.get("consumed", false)):
			if int(node.get("consumed_by", -1)) == owner_id:
				controlled += 1
			continue
		var tile: Vector2i = node.get("pos", Vector2i(-1, -1))
		if int(position_owner_index.get(_tile_key(tile), -1)) == owner_id:
			controlled += 1
	return float(controlled) / float(resource_node_count)

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

func _owner_hostile_heart_count(state: GameState, owner_id: int) -> int:
	var total: int = 0
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		if not bool(block.get("is_heart", false)):
			continue
		var other_owner: int = int(block.get("owner", 0))
		if not state.are_hostile(owner_id, other_owner):
			continue
		total += 1
	return total

func _heart_destroy_progress(initial_count: int, current_count: int) -> float:
	if initial_count <= 0:
		return 0.0
	return clampf(float(initial_count - current_count) / float(initial_count), 0.0, 1.0)

func _owner_door_progress(state: GameState, initial_state: GameState, owner_id: int) -> float:
	if not state.are_hostile(owner_id, GameState.PLAYER_ID):
		return 0.0
	var initial_hp: float = maxf(1.0, float(initial_state.door_hp))
	var current_hp: float = clampf(float(state.door_hp), 0.0, initial_hp)
	return clampf((initial_hp - current_hp) / initial_hp, 0.0, 1.0)

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

func _candidate_results_with_guardrails(results: Array, baseline: Dictionary) -> Array:
	if results.is_empty() or baseline.is_empty():
		return results.duplicate(true)
	var baseline_categories: Dictionary = baseline.get("score_by_category", {})
	var baseline_economy: float = float(baseline_categories.get("economy", 0.0))
	var baseline_objective: float = float(baseline_categories.get("objective_progress", 0.0))
	var filtered: Array = []
	for item_variant in results:
		var item: Dictionary = item_variant
		if String(item.get("id", "")) == "baseline":
			filtered.append(item)
			continue
		var categories: Dictionary = item.get("score_by_category", {})
		var economy: float = float(categories.get("economy", 0.0))
		var objective_progress: float = float(categories.get("objective_progress", 0.0))
		var economy_delta: float = economy - baseline_economy
		var objective_delta: float = objective_progress - baseline_objective
		if economy_delta < ECONOMY_REGRESSION_GUARDRAIL:
			continue
		if objective_delta < OBJECTIVE_REGRESSION_GUARDRAIL:
			continue
		filtered.append(item)
	if filtered.size() <= 1:
		return results.duplicate(true)
	filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("score", -999999.0)) > float(b.get("score", -999999.0))
	)
	return filtered

func _load_baseline_tuning_defaults() -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(BASELINE_TUNING_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return out
	_collect_numeric_leaf_values(parsed as Dictionary, out)
	return out

func _collect_numeric_leaf_values(source: Dictionary, out: Dictionary) -> void:
	for key_variant in source.keys():
		var value: Variant = source[key_variant]
		if value is Dictionary:
			_collect_numeric_leaf_values(value as Dictionary, out)
			continue
		var value_type: int = typeof(value)
		if value_type == TYPE_INT or value_type == TYPE_FLOAT:
			out[String(key_variant)] = value

func _report_parameter_keys(config: Dictionary, baseline_defaults: Dictionary, candidate_results: Array) -> Array:
	var key_set: Dictionary = {}
	for key_variant in baseline_defaults.keys():
		key_set[String(key_variant)] = true

	var fixed: Dictionary = config.get("fixed_overrides", {})
	for key_variant in fixed.keys():
		key_set[String(key_variant)] = true

	var search: Dictionary = config.get("search", {})
	var grid_parameters: Dictionary = search.get("grid_parameters", {})
	for key_variant in grid_parameters.keys():
		key_set[String(key_variant)] = true
	var random_parameters: Dictionary = search.get("random_parameters", {})
	for key_variant in random_parameters.keys():
		key_set[String(key_variant)] = true

	for item_variant in candidate_results:
		var item: Dictionary = item_variant
		var overrides: Dictionary = item.get("overrides", {})
		for key_variant in overrides.keys():
			key_set[String(key_variant)] = true

	var keys: Array = key_set.keys()
	keys.sort()
	return keys

func _annotate_candidates_with_params(candidate_results: Array, baseline_defaults: Dictionary, parameter_keys: Array) -> Array:
	var baseline_result: Dictionary = _find_candidate_result(candidate_results, "baseline")
	var baseline_overrides: Dictionary = baseline_result.get("overrides", {})
	var baseline_effective: Dictionary = _effective_param_set(parameter_keys, baseline_defaults, baseline_overrides)

	var out: Array = []
	for item_variant in candidate_results:
		var item: Dictionary = item_variant
		var enriched: Dictionary = item.duplicate(true)
		var overrides: Dictionary = enriched.get("overrides", {})
		var effective_params: Dictionary = _effective_param_set(parameter_keys, baseline_defaults, overrides)
		var diff_vs_baseline: Dictionary = _diff_vs_baseline(parameter_keys, baseline_effective, effective_params)
		enriched["effective_params"] = effective_params
		enriched["diff_vs_baseline"] = diff_vs_baseline
		enriched["changed_params"] = _changed_params(diff_vs_baseline)
		out.append(enriched)
	return out

func _effective_param_set(parameter_keys: Array, baseline_defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key_variant in parameter_keys:
		var key: String = String(key_variant)
		if overrides.has(key):
			out[key] = overrides[key]
		elif baseline_defaults.has(key):
			out[key] = baseline_defaults[key]
		else:
			out[key] = null
	return out

func _diff_vs_baseline(parameter_keys: Array, baseline_effective: Dictionary, effective: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key_variant in parameter_keys:
		var key: String = String(key_variant)
		var baseline_value: Variant = baseline_effective.get(key, null)
		var candidate_value: Variant = effective.get(key, null)
		var changed: bool = not _param_values_equal(baseline_value, candidate_value)
		out[key] = {
			"baseline": baseline_value,
			"candidate": candidate_value,
			"delta": _param_delta(baseline_value, candidate_value),
			"changed": changed,
		}
	return out

func _changed_params(diff_vs_baseline: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = diff_vs_baseline.keys()
	keys.sort()
	for key_variant in keys:
		var key: String = String(key_variant)
		var row: Dictionary = diff_vs_baseline[key]
		if not bool(row.get("changed", false)):
			continue
		out.append({
			"key": key,
			"baseline": row.get("baseline", null),
			"candidate": row.get("candidate", null),
			"delta": row.get("delta", null),
		})
	return out

func _param_values_equal(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return absf(float(a) - float(b)) < 0.000001
	return a == b

func _param_delta(baseline_value: Variant, candidate_value: Variant) -> Variant:
	var tb: int = typeof(baseline_value)
	var tc: int = typeof(candidate_value)
	if (tb == TYPE_INT or tb == TYPE_FLOAT) and (tc == TYPE_INT or tc == TYPE_FLOAT):
		return float(candidate_value) - float(baseline_value)
	return null

func _format_param_value(value: Variant) -> String:
	if value == null:
		return "null"
	var value_type: int = typeof(value)
	if value_type == TYPE_FLOAT:
		var f: float = float(value)
		if absf(f - round(f)) < 0.000001:
			return str(int(round(f)))
		var s: String = String.num(f, 4)
		while s.contains(".") and s.ends_with("0"):
			s = s.substr(0, s.length() - 1)
		if s.ends_with("."):
			s = s.substr(0, s.length() - 1)
		return s
	return str(value)

func _format_param_delta(delta: Variant) -> String:
	if delta == null:
		return "n/a"
	var d: float = float(delta)
	if absf(d) < 0.000001:
		return "0"
	var sign: String = "+" if d > 0.0 else "-"
	var abs_value: float = absf(d)
	var s: String = String.num(abs_value, 4)
	while s.contains(".") and s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return "%s%s" % [sign, s]

func _append_category_lines(lines: Array[String], categories: Dictionary, indent: String = "") -> void:
	for key in CATEGORY_ORDER:
		lines.append("%s%s = %s" % [indent, key, _format_param_value(categories.get(key, 0.0))])

func _append_parameter_lines(
	lines: Array[String],
	parameter_keys: Array,
	effective_params: Dictionary,
	diff_vs_baseline: Dictionary,
	indent: String = "",
	only_changed: bool = false
) -> void:
	var key_width: int = 0
	for key_variant in parameter_keys:
		key_width = maxi(key_width, String(key_variant).length())
	for key_variant in parameter_keys:
		var key: String = String(key_variant)
		var row: Dictionary = diff_vs_baseline.get(
			key,
			{"baseline": null, "candidate": effective_params.get(key, null), "delta": null, "changed": false}
		)
		if only_changed and not bool(row.get("changed", false)):
			continue
		var candidate_value: String = _format_param_value(row.get("candidate", effective_params.get(key, null)))
		var baseline_value: String = _format_param_value(row.get("baseline", null))
		var delta_value: String = _format_param_delta(row.get("delta", null))
		lines.append(
			"%s%-*s = %-8s (baseline %-8s, delta %s)" % [indent, key_width, key, candidate_value, baseline_value, delta_value]
		)

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
	lines.append("Checkpoints: %s" % JSON.stringify(report.get("checkpoints", [])))
	lines.append("")

	var parameter_keys: Array = report.get("parameter_keys", [])
	var baseline: Dictionary = report.get("baseline", {})
	if not baseline.is_empty():
		lines.append("BASELINE")
		lines.append("id=%s  score=%s" % [String(baseline.get("id", "baseline")), _format_param_value(baseline.get("score", 0.0))])
		lines.append("Category Scores:")
		_append_category_lines(lines, baseline.get("score_by_category", {}), "  ")
		lines.append("Parameters (effective):")
		_append_parameter_lines(
			lines,
			parameter_keys,
			baseline.get("effective_params", {}),
			baseline.get("diff_vs_baseline", {}),
			"  ",
			false
		)
		lines.append("")

	var top_candidates: Array = report.get("top_candidates", [])
	lines.append("TOP CANDIDATES")
	for i in range(top_candidates.size()):
		var candidate: Dictionary = top_candidates[i]
		lines.append("%d) %s  score=%s" % [i + 1, String(candidate.get("id", "")), _format_param_value(candidate.get("score", 0.0))])
		lines.append("  Category Scores:")
		_append_category_lines(lines, candidate.get("score_by_category", {}), "    ")
		lines.append("  Changed Parameters vs Baseline:")
		_append_parameter_lines(
			lines,
			parameter_keys,
			candidate.get("effective_params", {}),
			candidate.get("diff_vs_baseline", {}),
			"    ",
			true
		)
		var changed_count: int = int((candidate.get("changed_params", []) as Array).size())
		lines.append("    changed_count = %d / %d" % [changed_count, parameter_keys.size()])
		lines.append("  Effective Parameters (full):")
		_append_parameter_lines(
			lines,
			parameter_keys,
			candidate.get("effective_params", {}),
			candidate.get("diff_vs_baseline", {}),
			"    ",
			false
		)
		lines.append("  Checkpoint Scores: %s" % JSON.stringify(candidate.get("score_by_checkpoint", {})))
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
	var baseline: Dictionary = run_result.get("baseline", {})
	if not baseline.is_empty():
		lines.append("Baseline score: %s" % _format_param_value(baseline.get("score", 0.0)))
	var top_candidates: Array = run_result.get("top_candidates", [])
	for i in range(mini(3, top_candidates.size())):
		var item: Dictionary = top_candidates[i]
		lines.append("%d) %s  score=%s" % [i + 1, String(item.get("id", "")), _format_param_value(item.get("score", 0.0))])
		var changed: Array = item.get("changed_params", [])
		var changed_preview: Array[String] = []
		for idx in range(mini(3, changed.size())):
			var row: Dictionary = changed[idx]
			changed_preview.append(
				"%s=%s (delta %s)" % [
					String(row.get("key", "")),
					_format_param_value(row.get("candidate", null)),
					_format_param_delta(row.get("delta", null)),
				]
			)
		if not changed_preview.is_empty():
			lines.append("   changes: %s" % ", ".join(changed_preview))
	if not output.is_empty():
		lines.append("JSON: %s" % String(output.get("json", "")))
		lines.append("Text: %s" % String(output.get("text", "")))
	return "\n".join(lines)
