extends RefCounted
class_name TickSystem

# Deterministic turn pipeline:
# 1) apply staged actions, 2) resolve passive combat,
# 3) claim resources + income, 4) stall/outcome checks.

var economy: Economy = Economy.new()
var combat: Combat = Combat.new()
var director: LevelDirector = LevelDirector.new()

var min_expand_adjacent: int = 1
var basic_tile_cost: int = int(Combat.TILE_RULES["basic"]["cost"])

func step(state: GameState, queued_actions: Array) -> GameState:
	var next: GameState = state.copy_state()
	next.turn_index += 1

	var resolution: Dictionary = combat.resolve_with_report(queued_actions, next)
	var turn_log: Array[String] = resolution.get("log", [])
	next.last_resolution_report = resolution

	var bursts: Dictionary = economy.claim_resource_bursts(next)
	var eco_report: Dictionary = economy.compute_income_and_upkeep(next)
	economy.apply_income_and_upkeep(next, eco_report, bursts)
	turn_log.append("Economy settled")
	_advance_tile_ages(next)
	turn_log.append("Stability advanced")
	next.tick_reclaim_blocks()
	turn_log.append("Reclaim settled")

	_update_stall_counter(next)

	var outcome: Dictionary = director.check_victory_or_loss(next)
	turn_log.append("Outcome: %s" % String(outcome["status"]))
	if outcome.has("reason"):
		turn_log.append("Reason: %s" % String(outcome["reason"]))

	next.last_log = turn_log
	return next

func step_fast_for_trainer(state: GameState, queued_actions: Array) -> GameState:
	# Trainer-only deterministic fast path:
	# keeps all gameplay resolution identical while skipping per-turn log string work.
	var next: GameState = state.copy_state()
	next.turn_index += 1

	var resolution: Dictionary = combat.resolve_with_report(queued_actions, next, false, true)
	next.last_resolution_report = resolution

	var bursts: Dictionary = economy.claim_resource_bursts(next)
	var eco_report: Dictionary = economy.compute_income_and_upkeep(next)
	economy.apply_income_and_upkeep(next, eco_report, bursts)
	_advance_tile_ages(next)
	next.tick_reclaim_blocks()

	_update_stall_counter(next)
	next.last_log = []
	return next

func step_in_place_fast_for_trainer(state: GameState, queued_actions: Array) -> GameState:
	# Trainer-only deterministic fast path without per-turn state cloning.
	state.turn_index += 1

	var resolution: Dictionary = combat.resolve_with_report(queued_actions, state, false, true)
	state.last_resolution_report = resolution

	var bursts: Dictionary = economy.claim_resource_bursts(state)
	var eco_report: Dictionary = economy.compute_income_and_upkeep(state)
	economy.apply_income_and_upkeep(state, eco_report, bursts)
	_advance_tile_ages(state)
	state.tick_reclaim_blocks()

	_update_stall_counter(state)
	state.last_log = []
	return state

func _update_stall_counter(state: GameState) -> void:
	if bool(state.spectator_mode):
		state.stall_counter = 0
		return
	if not bool(state.players.get(GameState.PLAYER_ID, {}).get("alive", true)):
		state.stall_counter = 0
		return

	var energy: int = int(state.players[GameState.PLAYER_ID]["nutrients"])
	var can_act: bool = state.has_any_legal_action(GameState.PLAYER_ID, min_expand_adjacent, basic_tile_cost)
	if energy <= 0 and not can_act:
		state.stall_counter += 1
	else:
		state.stall_counter = 0

func _advance_tile_ages(state: GameState) -> void:
	for block_id in state.blocks.keys():
		var block: Dictionary = state.blocks[block_id]
		block["age"] = int(block.get("age", 0)) + 1
		state.blocks[block_id] = block
