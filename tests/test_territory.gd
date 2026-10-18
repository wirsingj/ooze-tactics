extends SceneTree

const SCENARIO = preload("res://scripts/systems/TerritoryScenario.gd")
const RULES = preload("res://scripts/systems/TerritoryRules.gd")
const ORDERS = preload("res://scripts/systems/TerritoryOrders.gd")
const AI = preload("res://scripts/systems/TerritoryAI.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func organ(state: GameState, owner: int, pos: Vector2i, role: String) -> int:
	var id: int = state.spawn_block(owner,pos,false,int(Combat.TILE_RULES[role].max_hp),role)
	Combat.new()._apply_tile_stats(state.blocks[id],role,true)
	state.blocks[id].age = 2
	return id

func fill_rect(state: GameState, owner: int, rect: Rect2i) -> void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var pos := Vector2i(x,y)
			if state.is_empty_ground(pos):
				state.spawn_block(owner,pos,false,9)

func fixture() -> GameState:
	var state := GameState.new()
	state.territory_mode = true
	state.width = 24
	state.height = 16
	state.turn_limit = 0
	state.door_tile = Vector2i(-1,-1)
	state.entrance_tile = Vector2i(-1,-1)
	state.spawn_block(1,Vector2i(1,1),true,40)
	state.add_owner(2,"Enemy",80)
	state.spawn_block(2,Vector2i(22,14),true,40)
	return state

func _run() -> void:
	var war: GameState = SCENARIO.build()
	check(war.width*war.height==100*26*16,"Map area must be 100 times the old 2v2 map")
	check(war.players.size()==4 and war.turn_limit==0,"Territory War is 2v2 without an asymmetric deadline")
	check(war.copy_state().territory_mode,"Copies retain the ruleset")
	var opener: Array = AI.new().choose_orders(war,1,{})
	var opening_growth: Array = opener.filter(func(order): return not order.has("selection"))
	check(opening_growth.size()==1 and opening_growth[0].target==Vector2i(75,42),"AI opens by securing a nearby farm well instead of rushing the center")
	var order: Dictionary = {"type":"territory_order","owner":1,"tile_type":"gather","target":Vector2i(75,42)}
	var engine = ORDERS.new()
	var before: String = var_to_str(war.blocks)+var_to_str(war.players)
	var expansion: Dictionary = engine.expand(war,[order])
	check(expansion.actions.size()>10,"One front order must expand a corridor, not a single tile")
	check(before==var_to_str(war.blocks)+var_to_str(war.players),"Order previews do not mutate live state")
	check(Combat.new().preview_resolution(war,expansion.actions).failed_actions.is_empty(),"Expanded orders must apply under actual combat ordering")
	var linked_field: GameState = SCENARIO.build()
	fill_rect(linked_field,2,Rect2i(175,35,58,53))
	var linked_orders: Array = AI.new().choose_orders(linked_field,2,{})
	var linked_growth: Array = linked_orders.filter(func(candidate): return not candidate.has("selection"))
	check(linked_growth.size()==2,"A team with a linked farm keeps one small central expedition")
	if linked_growth.size()==2:
		check(linked_growth[0].growth_weight==1.0 and linked_growth[1].growth_weight==3.0,"Expedition and farm fronts receive a one-to-three growth split")
		check(linked_growth[0].target.x==130 and linked_growth[1].target==Vector2i(184,117),"Expedition goes to the center while the main front extends a nearby farm")
		var weighted: Dictionary = engine.expand(linked_field,linked_orders)
		check(int(weighted.growth.get(2,0))<=RULES.GROWTH_LIMIT and not weighted.actions.is_empty(),"Weighted fronts share the same bounded growth budget")
	var trailing_farms: GameState = linked_field.copy_state()
	trailing_farms.team_scores[1] = 40
	var comeback_growth: Array = AI.new().choose_orders(trailing_farms,2,{}).filter(func(candidate): return not candidate.has("selection"))
	check(comeback_growth.size()==1 and comeback_growth[0].target.x==130,"Global score pressure shifts a trailing team from farming to a full central push")
	var stance: GameState = fixture()
	stance.spawn_block(1,Vector2i(10,8),false,9)
	var rival_contact: int = stance.spawn_block(2,Vector2i(14,8),false,9)
	stance.team_scores[1] = 30
	var leading_roles: Array[String] = []
	for candidate in AI.new().choose_orders(stance,1,{}):
		leading_roles.append(String(candidate.tile_type))
	check(leading_roles.has("defense") and not leading_roles.has("ranged") and not leading_roles.has("melee"),"A global control lead makes micro contact orders hold the front")
	stance.team_scores[1] = 0
	stance.team_scores[2] = 30
	var trailing_roles: Array[String] = []
	for candidate in AI.new().choose_orders(stance,1,{}):
		trailing_roles.append(String(candidate.tile_type))
	check(trailing_roles.has("defense") and trailing_roles.has("ranged"),"A trailing team defends contact while adding a ranged counter-push")
	stance.team_scores[1] = 30
	stance.team_scores[2] = 0
	stance.remove_block(rival_contact)
	stance.spawn_block(2,Vector2i(11,8),false,9)
	var adjacent_roles: Array[String] = []
	for candidate in AI.new().choose_orders(stance,1,{}):
		adjacent_roles.append(String(candidate.tile_type))
	check(adjacent_roles.has("melee"),"Immediate enemy contact still triggers a melee response while the team leads")
	var state: GameState = fixture()
	var shield: int = organ(state,2,Vector2i(10,7),"defense")
	var rear: int = organ(state,2,Vector2i(12,7),"gather")
	organ(state,1,Vector2i(6,7),"ranged")
	check(not RULES.clear_shot(state,1,Vector2i(6,7),Vector2i(12,7)),"Defense intercepts shots toward rear organs")
	Combat.new().resolve([],state)
	check(state.blocks[shield].hp>=17 and state.blocks[rear].hp==8,"Defense holds ranged fire and protects the rear")
	organ(state,1,Vector2i(6,6),"ranged")
	organ(state,1,Vector2i(6,8),"ranged")
	Combat.new().resolve([],state)
	check(state.blocks[shield].hp==18,"Mature Defense absorbs each weak projectile, including concentrated fire")
	var melee_state: GameState = fixture()
	var wall: int = organ(melee_state,2,Vector2i(10,7),"defense")
	organ(melee_state,1,Vector2i(8,7),"melee")
	Combat.new().resolve([],melee_state)
	check(melee_state.blocks[wall].hp<=11,"Melee must break armor efficiently at two-tile reach")
	state = fixture()
	var victim: int = organ(state,2,Vector2i(10,7),"gather")
	organ(state,1,Vector2i(6,7),"ranged")
	state.set_walls([[8,7]])
	Combat.new().resolve([],state)
	check(state.blocks[victim].hp==8,"Ranged cannot shoot through rock")
	state.set_walls([])
	Combat.new().resolve([],state)
	check(state.blocks[victim].hp<8,"Ranged still damages an exposed organ when the rock is removed")
	check(not Combat.new()._can_damage_door(state,1),"Territory War has no phantom campaign door target")
	state = fixture()
	var site := Vector2i(7,8)
	# Fully cover a neutral site with one narrow supplied connection so removing
	# that bridge cuts control without relying on an impossible edge-site ratio.
	for y in range(2,9):
		state.spawn_block(1,Vector2i(1,y),false,9)
	for y in range(-6,7):
		for x in range(-6,7):
			if x*x+y*y>36:
				continue
			var pos := site+Vector2i(x,y)
			if state.get_block_at(pos).is_empty():
				state.spawn_block(1,pos,false,9)
	state.resource_nodes = [{"pos":site,"kind":"well","home":false,"controller":0}]
	var off_site: int = organ(state,1,Vector2i(8,8),"gather")
	check(Economy.new().compute_income_and_upkeep(state).delta[1]==18,"Only connected resource sites produce extra income")
	RULES.settle_sites(state)
	check(state.team_scores[1]==1,"Holding a supplied neutral site earns control")
	state.remove_block(int(state.get_block_at(Vector2i(1,4)).id))
	check(Economy.new().compute_income_and_upkeep(state).delta[1]==8,"Cut supply removes resource income immediately")
	RULES.settle_sites(state)
	check(state.team_scores[1]==1 and state.resource_nodes[0].controller==0,"A cut-off site stops scoring")
	state.remove_block(off_site)
	var farm_state: GameState = SCENARIO.build()
	var home_sites: Array = []
	for node in farm_state.resource_nodes:
		if bool(node.get("home",false)):
			home_sites.append(node)
	farm_state.resource_nodes = home_sites+[{"pos":Vector2i(75,42),"kind":"well","home":false,"controller":0},{"pos":Vector2i(130,42),"kind":"well","home":false,"controller":0}]
	fill_rect(farm_state,1,Rect2i(27,30,55,26))
	fill_rect(farm_state,4,Rect2i(27,109,105,17))
	fill_rect(farm_state,4,Rect2i(122,36,17,90))
	var farm_income: Dictionary = Economy.new().compute_income_and_upkeep(farm_state).delta
	check(int(farm_income[1])==30 and int(farm_income[4])==30,"Nearby secured wells share farm income across two allied owners")
	var group: Dictionary = {"type":"territory_order","owner":1,"tile_type":"gather","target":Vector2i(35,44),"selection":Rect2i(28,35,16,16)}
	var selection_result: Dictionary = engine.expand(war,[group])
	check(selection_result.actions.size()==1,"Intelligent Gather selection uses the well, not every selected tile")
	if not selection_result.actions.is_empty():
		check(war.blocks[selection_result.actions[0].block_id].pos==Vector2i(35,44),"Selected Gather is on the actual resource site")
	state = fixture()
	state.players[1].nutrients = 80
	for y in range(2,6):
		state.spawn_block(1,Vector2i(1,y),false,9)
	for y in range(5,10):
		for x in range(2,8):
			state.spawn_block(1,Vector2i(x,y),false,9)
	var existing: Dictionary = state.get_block_at(Vector2i(3,7))
	existing.tile_type = "gather"
	organ(state,2,Vector2i(10,7),"defense")
	var selected := Rect2i(2,5,6,5)
	for role in ["defense","melee","ranged"]:
		var assigned: Dictionary = engine.expand(state,[{"owner":1,"tile_type":role,"target":Vector2i(7,7),"selection":selected}])
		check(assigned.actions.size()==6,"A large %s group is bounded to six affordable organs" % role)
		check(assigned.state.blocks[existing.id].tile_type=="gather","Group assignment preserves existing organs")
		check(Combat.new().preview_resolution(state,assigned.actions).failed_actions.is_empty(),"Group actions obey actual combat application")
		for action in assigned.actions:
			var pos: Vector2i = action.target if action.has("target") else state.blocks[action.block_id].pos
			check(selected.has_point(pos),"Group assignment stays inside the selected area")
			if role in ["defense","melee"]:
				check(pos.x>=6,"Frontline organs prefer the enemy-facing edge")
	state.players[1].nutrients = 3
	check(engine.expand(state,[{"owner":1,"tile_type":"melee","target":Vector2i(7,7),"selection":selected}]).actions.is_empty(),"Group assignment cannot spend unavailable energy")
	var director := LevelDirector.new()
	war.team_scores = {1:100,2:100}
	check(director.check_victory_or_loss(war).status=="ongoing","Equal control at the threshold is not a side-biased win")
	war.team_scores[2] = 101
	check(director.check_victory_or_loss(war).status=="loss","A rival control lead over the threshold wins")
	war.team_scores = {1:0,2:0}
	for block in war.get_owner_blocks(1).duplicate():
		if block.core:
			war.remove_block(block.id)
	check(director.check_victory_or_loss(war).status=="ongoing","An allied heart keeps the team in play")
	for block in war.get_owner_blocks(4).duplicate():
		if block.core:
			war.remove_block(block.id)
	check(director.check_victory_or_loss(war).status=="loss","Destroying both allied hearts defeats the team")
	for failure in failures:
		printerr(failure)
	print("TERRITORY CHECKS: ","PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)
