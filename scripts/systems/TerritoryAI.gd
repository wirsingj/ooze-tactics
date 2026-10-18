extends RefCounted

const RULES = preload("res://scripts/systems/TerritoryRules.gd")
const FARM_LINK_PRIORITY: float = 54.0
const CENTRAL_LANE_PRIORITY: float = 12.0

func choose_orders(state: GameState, owner: int, reserved_sites: Dictionary = {}) -> Array:
	if not bool(state.players.get(owner,{}).get("alive",false)):
		return []
	var owned: Array = state.get_owner_blocks(owner)
	var frontier = preload("res://scripts/systems/TerritoryFrontier.gd").new(state,owner)
	var orders: Array = []
	# Extraction is tied to actual supplied sites; rear-field farming is useless.
	for node in state.resource_nodes:
		var block: Dictionary = state.get_block_at(node.pos)
		if not block.is_empty() and int(block.owner)==owner and block.tile_type=="basic":
			orders.append(_order(owner,"gather",node.pos,Rect2i(node.pos,Vector2i.ONE)))
			break
	var front: Vector2i = Vector2i(-1,-1)
	var closest: int = 999999
	var enemy_role: String = ""
	for block in owned:
		var boundary: bool = false
		for dir in BoardTopology.CARDINAL_STEPS:
			var neighbor: Dictionary = state.get_block_at(block.pos+dir)
			if neighbor.is_empty() or state.are_hostile(owner,int(neighbor.owner)):
				boundary = true
				break
		if not boundary:
			continue
		var threat: Dictionary = frontier.nearest(block.pos)
		if int(threat.distance)<closest:
			closest = threat.distance
			front = block.pos
			enemy_role = String(threat.block.get("tile_type",""))
	# MICRO: direct contact/threat is the strongest local signal. The global
	# control race decides whether this edge should hold or counter-punch.
	var team: int = state.get_owner_team(owner)
	var score_gap: int = _control_race_gap(state,team)
	if closest<=10:
		var counts := {"melee":0,"ranged":0,"defense":0}
		for block in owned:
			if _distance(block.pos,front)<=10 and counts.has(block.tile_type):
				counts[block.tile_type] += 1
		var defensive_stance: bool = score_gap<=-8
		if counts.defense<(3 if defensive_stance else 2) and closest>=3:
			orders.append(_order(owner,"defense",front))
		if closest<=2 or (not defensive_stance and (closest<=3 or enemy_role=="defense")):
			orders.append(_order(owner,"melee",front))
		elif counts.ranged<4 and not defensive_stance:
			orders.append(_order(owner,"ranged",front))
	# MACRO: grow useful, connected local farms and maintain a single forward
	# expedition. The ally reservations coordinate the two colonies as a team.
	var best_site: Vector2i = Vector2i(-1,-1)
	var best_value: float = -INF
	var supplied: Dictionary = RULES.supplied_tiles(state)
	var site_statuses: Dictionary = {}
	for node in state.resource_nodes:
		site_statuses[node.pos] = RULES.site_status(state,node,supplied)
	var friendly_sites: Array[Vector2i] = []
	for node in state.resource_nodes:
		if bool(node.get("home",false)):
			continue
		var controller: int = int(site_statuses[node.pos].controller)
		if controller>0 and not state.are_hostile(owner,controller):
			friendly_sites.append(node.pos)
	var linked_farms: int = 0
	for index in range(friendly_sites.size()):
		for other_index in range(index+1,friendly_sites.size()):
			if _distance(friendly_sites[index],friendly_sites[other_index])<=RULES.FARM_LINK_RADIUS:
				linked_farms += 1
	for node in state.resource_nodes:
		var controller: int = int(site_statuses[node.pos].controller)
		if controller>0 and not state.are_hostile(owner,controller):
			continue
		if reserved_sites.has(node.pos):
			continue
		var distance: int = 999999
		for block in owned:
			if supplied.has(block.pos):
				distance = mini(distance,_distance(block.pos,node.pos))
		var nearby_farms: int = 0
		for farm in friendly_sites:
			if _distance(farm,node.pos)<=RULES.FARM_LINK_RADIUS:
				nearby_farms += 1
		# GLOBAL: score pressure can raise or lower the appetite for the contested
		# spine. In an even race, local linked wells win over an early rush.
		var central_value: float = -30.0 if linked_farms==0 else CENTRAL_LANE_PRIORITY
		if score_gap>=8:
			central_value += minf(36.0,float(score_gap-8)*1.5)
		elif score_gap<=-8:
			central_value -= minf(18.0,float(-score_gap-8))
		var value: float = -float(distance)+float(nearby_farms)*FARM_LINK_PRIORITY+(central_value if node.pos.x==130 else 0.0)+(18.0 if controller==0 else -12.0)
		if value>best_value:
			best_value = value
			best_site = node.pos
	if best_site.x>=0:
		reserved_sites[best_site] = true
		var add_expedition: bool = false
		if owner==_team_scout_owner(state,team) and linked_farms>0 and best_site.x!=130 and orders.size()<=RULES.ORDER_LIMIT-2:
			var expedition: Vector2i = _best_central_site(state,owner,supplied,site_statuses,reserved_sites,best_site)
			if expedition.x>=0:
				reserved_sites[expedition] = true
				orders.append(_order(owner,"gather",expedition,Rect2i(),1.0))
				add_expedition = true
		orders.append(_order(owner,"gather",best_site,Rect2i(),3.0 if add_expedition else 1.0))
		# An expedition receives one quarter of its owner's growth allowance;
		# the local farm receives three quarters and keeps a broad supported front.
	if closest<=10 and orders.size()<RULES.ORDER_LIMIT:
		# Use a spare order to broaden the contested edge instead of stacking guns behind it.
		var flank_y: int = clampi(front.y+(12 if front.y<80 else -12),1,state.height-2)
		orders.append(_order(owner,"basic",Vector2i(front.x,flank_y)))
	return orders.slice(0,RULES.ORDER_LIMIT)

func _order(owner: int, role: String, target: Vector2i, selection: Rect2i = Rect2i(), growth_weight: float = 1.0) -> Dictionary:
	var order: Dictionary = {"type":"territory_order","owner":owner,"tile_type":role,"target":target}
	if selection.has_area():
		order.selection = selection
	elif role in ["basic","gather"]:
		order.growth_weight = maxf(0.01,growth_weight)
	return order

func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func _best_central_site(state: GameState,owner: int,supplied: Dictionary,site_statuses: Dictionary,reserved_sites: Dictionary,primary: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1,-1)
	var best_distance: int = 999999
	for node in state.resource_nodes:
		if node.pos.x!=130 or node.pos==primary or reserved_sites.has(node.pos):
			continue
		var controller: int = int(site_statuses[node.pos].controller)
		if controller>0 and not state.are_hostile(owner,controller):
			continue
		var distance: int = 999999
		for block in state.get_owner_blocks(owner):
			if supplied.has(block.pos):
				distance = mini(distance,_distance(block.pos,node.pos))
		if distance<best_distance:
			best_distance = distance
			best = node.pos
	return best

func _team_scout_owner(state: GameState,team: int) -> int:
	var candidates: Array[int] = []
	for player_id in state.players:
		var id: int = int(player_id)
		if id!=GameState.PLAYER_ID and bool(state.players[id].get("alive",false)) and state.get_owner_team(id)==team:
			candidates.append(id)
	if candidates.is_empty():
		return GameState.PLAYER_ID
	candidates.sort()
	return candidates[0]

func _control_race_gap(state: GameState,team: int) -> int:
	var own_score: int = int(state.team_scores.get(team,0))
	var rival_score: int = 0
	for rival in state.team_scores:
		if int(rival)!=team:
			rival_score = maxi(rival_score,int(state.team_scores[rival]))
	return rival_score-own_score
