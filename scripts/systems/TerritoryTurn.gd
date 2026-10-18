extends RefCounted

var orders = preload("res://scripts/systems/TerritoryOrders.gd").new()
var ai = preload("res://scripts/systems/TerritoryAI.gd").new()
var tick := TickSystem.new()

func ai_orders(state: GameState, include_player: bool = false) -> Array:
	var intents: Array = []
	var reservations: Dictionary = {}
	for owner in state.players:
		if owner==GameState.PLAYER_ID and not include_player:
			continue
		var team: int = state.get_owner_team(owner)
		if not reservations.has(team):
			reservations[team] = {}
		intents.append_array(ai.choose_orders(state,owner,reservations[team]))
	return intents

func resolve(state: GameState, committed_orders: Array) -> Dictionary:
	var plan: Dictionary = orders.expand(state,committed_orders)
	var next: GameState = tick.step(state,plan.actions)
	return {"state":next,"actions":plan.actions,"notices":plan.notices,"outcome":LevelDirector.new().check_victory_or_loss(next)}
