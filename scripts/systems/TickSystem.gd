extends RefCounted
class_name TickSystem

# Deterministic turn pipeline:
# 1) apply staged actions, 2) resolve passive combat,
# 3) claim resources + income, 4) stall/outcome checks.

var economy: Economy = Economy.new()
var combat: Combat = Combat.new()
var director: LevelDirector = LevelDirector.new()

var min_expand_adjacent: int = 1
var basic_tile_cost: int = 1

func step(state: GameState, queued_actions: Array) -> GameState:
	var next: GameState = state.copy_state()
	next.turn_index += 1

	var resolution: Dictionary = combat.resolve_with_report(queued_actions, next)
	var log: Array[String] = resolution.get("log", [])
	next.last_resolution_report = resolution

	var bursts: Dictionary = economy.claim_resource_bursts(next)
	var eco_report: Dictionary = economy.compute_income_and_upkeep(next)
	economy.apply_income_and_upkeep(next, eco_report, bursts)
	log.append("Economy settled")
	_advance_tile_ages(next)
	log.append("Stability advanced")

	_update_stall_counter(next)

	var outcome: Dictionary = director.check_victory_or_loss(next)
	log.append("Outcome: %s" % String(outcome["status"]))
	if outcome.has("reason"):
		log.append("Reason: %s" % String(outcome["reason"]))

	next.last_log = log
	return next

func _update_stall_counter(state: GameState) -> void:
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
