extends SceneTree

const SCENARIO = preload("res://tools/ai/PressureScenario.gd")
# Frozen repaired heuristic from the working tree before tactical search,
# 2026-10-03; only its global class declaration was removed for dynamic loading.
const REFERENCE = "res://baselines/ai/pressure_reference_v1.gd.txt"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var frozen := GDScript.new()
	frozen.source_code = FileAccess.get_file_as_string(REFERENCE)
	if frozen.reload()!=OK:
		quit(1)
		return
	var results: Array = []
	for seed_value in [1337,2026,45678]:
		for candidate_team in [GameState.TEAM_PLAYER,GameState.TEAM_ENEMY]:
			var state: GameState = SCENARIO.build(seed_value)
			var old_ai: RefCounted = frozen.new()
			var new_ai := OozeAI.new()
			var damages := {1:0,2:0}
			var actions_count := {1:0,2:0}
			var failed: int = 0
			var failure_reasons: Dictionary = {}
			var elapsed_ms: int = 0
			var decision_max_ms: int = 0
			var outcome: Dictionary = {"status":"ongoing"}
			while state.turn_index<30:
				var all_actions: Array = []
				var owners: Array = state.players.keys()
				owners.sort()
				for owner in owners:
					if not state.players[owner].alive:
						continue
					var started: int = Time.get_ticks_msec()
					var team: int = state.get_owner_team(owner)
					state.players[owner].tactical_search = team==candidate_team
					var ai: RefCounted = new_ai if team==candidate_team else old_ai
					var chosen: Array = ai.choose_actions(state,owner,1)
					var duration: int = Time.get_ticks_msec()-started
					elapsed_ms += duration
					decision_max_ms = maxi(decision_max_ms,duration)
					if chosen.size()>int(state.players[owner].max_actions):
						failures.append("Action cap exceeded")
					actions_count[team] += chosen.size()
					all_actions.append_array(chosen)
				state = TickSystem.new().step(state,all_actions)
				failed += state.last_resolution_report.failed_actions.size()
				for rejection in state.last_resolution_report.failed_actions:
					var reason: String = str(rejection.get("reason","unknown"))
					failure_reasons[reason] = int(failure_reasons.get(reason,0))+1
				for event in state.last_resolution_report.get("combat_events",[]):
					if event.has("owner"):
						damages[state.get_owner_team(event.owner)] += int(event.amount)
				outcome = LevelDirector.new().check_victory_or_loss(state)
				if outcome.status!="ongoing":
					break
				await process_frame
			var hearts: Dictionary = {1:0,2:0}
			for block in state.blocks.values():
				if block.core:
					hearts[state.get_owner_team(block.owner)] += 1
			var winner: int = GameState.TEAM_PLAYER if outcome.status=="victory" else (GameState.TEAM_ENEMY if outcome.status=="loss" else 0)
			var row: Dictionary = {"seed":seed_value,"candidate_team":candidate_team,"turns":state.turn_index,
				"outcome":outcome,"winning_team":winner,"remaining_hearts":hearts,"hp_lost_including_collapse":damages,"actions":actions_count,"failed_actions":failed,"failure_reasons":failure_reasons,
				"decision_total_ms":elapsed_ms,"decision_max_ms":decision_max_ms}
			results.append(row)
			print(JSON.stringify(row))
	var record: Dictionary = {"scenario":"2v2 equal budgets; 14 energy, 4 income, 3 actions each; normal global turn batching",
		"reference_sha256":FileAccess.get_sha256(REFERENCE),"engine":Engine.get_version_info().string,
		"candidate_sha256":FileAccess.get_sha256("res://scripts/systems/OozeAI.gd"),"planner_sha256":FileAccess.get_sha256("res://scripts/systems/TacticalPlanner.gd"),"scenario_sha256":FileAccess.get_sha256("res://tools/ai/PressureScenario.gd"),
		"limits":"Six side-swapped seeded matches against one frozen heuristic; not human difficulty or broad holdout validation. Normal campaign objectives are asymmetric: the player team's deadline and human-owner heart loss can end play while its ally survives. HP loss includes heart-collapse removal, not only direct attack damage.",
		"matches":results,"failures":failures}
	FileAccess.open("res://docs/validation/pressure_2v2.json",FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	quit(0 if failures.is_empty() else 1)
