extends SceneTree

const SCENARIO = preload("res://tools/ai/PressureScenario.gd")
const PLANNER = preload("res://scripts/systems/TacticalPlanner.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var match_state: GameState = SCENARIO.build(1337)
	var counts := {1:0,2:0}
	for owner in match_state.players:
		counts[match_state.get_owner_team(owner)] += 1
		check(match_state.players[owner].nutrients==14, "Every 2v2 colony starts with ordinary equal energy")
		check(match_state.players[owner].max_actions==3, "Every 2v2 colony has three actions")
		check(Economy.new().compute_income_and_upkeep(match_state).delta[owner]==4, "Every 2v2 colony has four opening income")
	check(counts=={1:2,2:2}, "The fixture really contains two colonies on each team")
	check(not match_state.spectator_mode, "The fixture uses normal batched turns")
	var state := GameState.new()
	state.width = 13
	state.height = 10
	state.turn_limit = 40
	state.spawn_block(1,Vector2i(3,4),true,13)
	var target: int = state.spawn_block(1,Vector2i(5,4),false,9,"ranged")
	state.blocks[target].range = 4
	state.blocks[target].damage = 3
	state.add_owner(2,"Enemy",10)
	state.players[2].max_actions = 3
	state.players[2].income_delta = 2
	state.players[2].tactical_search = true
	for pos in [Vector2i(9,4),Vector2i(8,4),Vector2i(8,5),Vector2i(9,5)]:
		state.spawn_block(2,pos,pos==Vector2i(9,4),13 if pos==Vector2i(9,4) else 9)
	var original: String = var_to_str(state.blocks)+var_to_str(state.players)+str(state.turn_index)
	var ai := OozeAI.new()
	var actions: Array = ai.choose_actions(state,2,1)
	check(actions==ai.choose_actions(state,2,1), "Tactical decisions are deterministic")
	check(original==var_to_str(state.blocks)+var_to_str(state.players)+str(state.turn_index), "Lookahead cannot mutate the live board, money, or clock")
	check(actions.size()<=3, "Tactical decisions respect the real action budget")
	check(Combat.new().preview_resolution(state,actions).failed_actions.is_empty(), "Tactical action bundle is legal under the actual resolver")
	var after: GameState = TickSystem.new().step(state,actions)
	after = TickSystem.new().step(after,[])
	check(not after.blocks.has(target) or int(after.blocks[target].hp)<9, "The enemy must retaliate against the ranged pressure with actual damage")
	check(bool(after.players[2].alive), "Retaliation must preserve the enemy heart in this fixture")
	var planner = PLANNER.new()
	planner.refine(state,2,1,actions)
	check(planner.rollouts>0 and planner.rollouts<=38, "Combat search has a fixed rollout ceiling")
	check(ai._estimated_owner_income(state,2)==4, "Income planning includes the owner's actual modifier")
	state.players[2].income_delta = -2
	check(ai._estimated_owner_income(state,2)==0, "Income planning never invents recovery income")
	for failure in failures:
		printerr(failure)
	print("PRESSURE CHECKS: ", "PASSED" if failures.is_empty() else "FAILED", "; ranged response: ", actions)
	quit(0 if failures.is_empty() else 1)
