extends RefCounted

const RULES = preload("res://scripts/systems/TerritoryRules.gd")
const SIZE = Vector2i(260,160)

static func build(seed_value: int = 1337) -> GameState:
	var state := GameState.new()
	state.width = SIZE.x
	state.height = SIZE.y
	state.run_seed = seed_value
	state.territory_mode = true
	state.turn_limit = 0
	state.entrance_tile = Vector2i(-1,-1)
	state.door_tile = Vector2i(-1,-1)
	state.door_hp = 1 # Territory objectives are handled explicitly by LevelDirector.
	state.add_owner(2,"Crimson",80)
	state.add_owner(3,"Violet",80)
	state.add_owner(4,"Azure",80,GameState.TEAM_PLAYER)
	var seeds := {1:Vector2i(35,42),4:Vector2i(35,117),2:Vector2i(224,42),3:Vector2i(224,117)}
	var walls: Array = []
	# Two long ridges divide nine resource districts; three wide passes keep
	# multiple viable fronts and flank routes instead of a single corridor.
	for x in [98,99,100,159,160,161]:
		for y in range(12,148):
			if absi(y-42)<=7 or absi(y-80)<=7 or absi(y-117)<=7:
				continue
			walls.append([x,y])
	state.set_walls(walls)
	for owner in seeds:
		state.players[owner].nutrients = 80
		state.players[owner].max_actions = RULES.GROWTH_LIMIT+RULES.ORDER_LIMIT*RULES.SPECIALIZE_LIMIT
		var center: Vector2i = seeds[owner]
		for y in range(-8,9):
			for x in range(-8,9):
				if x*x+y*y>64:
					continue
				var pos: Vector2i = center+Vector2i(x,y)
				state.spawn_block(owner,pos,pos==center,40 if pos==center else 9)
		state.resource_nodes.append({"pos":center+Vector2i(0,2),"kind":"well","home":true,"controller":owner,"consumed":false})
	for x in [75,130,184]:
		for y in [42,80,117]:
			state.resource_nodes.append({"pos":Vector2i(x,y),"kind":"well","home":false,"controller":0,"consumed":false})
	state.level_layout = {"layout_id":"territory_fronts_v2","board_size":[SIZE.x,SIZE.y],"inner_walls":walls}
	return state
