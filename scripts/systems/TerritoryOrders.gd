extends RefCounted

const RULES = preload("res://scripts/systems/TerritoryRules.gd")
var combat := Combat.new()
const FRONTIER = preload("res://scripts/systems/TerritoryFrontier.gd")
var frontiers: Dictionary = {}

func expand(state: GameState, orders: Array) -> Dictionary:
	var staged: GameState = state.copy_state()
	var actions: Array = []
	var notices: Array[String] = []
	var counts: Dictionary = {}
	var supplied: Dictionary = RULES.supplied_tiles(staged)
	var depths: Dictionary = {}
	var growth_orders: Dictionary = {}
	var growth_weights: Dictionary = {}
	var growth_used: Dictionary = {}
	frontiers.clear()
	for pos in supplied:
		depths[pos] = 0
	for order in orders:
		if order.get("tile_type","") in ["basic","gather"] and not order.has("selection"):
			var owner: int = int(order.get("owner",0))
			var pending: int = int(growth_orders.get(owner,0))
			if pending>=RULES.ORDER_LIMIT:
				continue
			growth_orders[owner] = pending+1
			growth_weights[owner] = float(growth_weights.get(owner,0.0))+maxf(0.01,float(order.get("growth_weight",1.0)))
	for order in orders:
		var owner: int = int(order.get("owner",0))
		if not staged.players.has(owner) or not bool(staged.players[owner].alive):
			continue
		counts[owner] = int(counts.get(owner,0))+1
		if counts[owner]>RULES.ORDER_LIMIT:
			continue
		var start_size: int = actions.size()
		var role: String = String(order.get("tile_type","basic"))
		if not Combat.TILE_RULES.has(role):
			continue
		if role in ["basic","gather"] and not order.has("selection"):
			var remaining: int = RULES.GROWTH_LIMIT-int(growth_used.get(owner,0))
			var weight: float = maxf(0.01,float(order.get("growth_weight",1.0)))
			var total_weight: float = maxf(weight,float(growth_weights.get(owner,weight)))
			var quota: int = int(ceil(float(remaining)*weight/total_weight))
			var grown: int = _grow(staged,state,owner,order.get("target",Vector2i(-1,-1)),role,actions,supplied,depths,quota)
			growth_used[owner] = int(growth_used.get(owner,0))+grown
			growth_orders[owner] = maxi(0,int(growth_orders.get(owner,1))-1)
			growth_weights[owner] = maxf(0.0,float(growth_weights.get(owner,weight))-weight)
		else:
			_specialize(staged,state,owner,order,actions,supplied)
		if actions.size()==start_size:
			notices.append("%s: no affordable, supplied change fits that order" % role.capitalize())
	return {"actions":actions,"notices":notices,"state":staged,"growth":growth_used}

func is_complete(state: GameState, order: Dictionary, supplied_override: Dictionary = {}) -> bool:
	var role: String = order.tile_type
	if role not in ["basic","gather"] or order.has("selection"):
		return true # Group specialization is a single, explicitly priced assignment.
	var owner: int = int(order.owner)
	var supplied: Dictionary = supplied_override
	if supplied.is_empty():
		supplied = RULES.supplied_tiles(state)
	var target: Vector2i = order.target
	if role=="gather":
		var node: Dictionary = state.get_resource_node_at(target)
		var block: Dictionary = state.get_block_at(target)
		return not node.is_empty() and int(RULES.site_status(state,node,supplied).controller)==owner and block.get("tile_type","")=="gather"
	var owned: int = 0
	var total: int = 0
	for y in range(-6,7):
		for x in range(-6,7):
			var pos: Vector2i = target+Vector2i(x,y)
			if x*x+y*y>36 or not state.is_inside(pos) or state.is_blocked(pos):
				continue
			total += 1
			if supplied.get(pos,0)==owner:
				owned += 1
	return total>0 and float(owned)/total>=0.85

func _grow(state: GameState, original: GameState, owner: int, target: Vector2i, role: String, actions: Array, supplied: Dictionary, depths: Dictionary, quota: int) -> int:
	if not state.is_inside(target) or state.is_blocked(target):
		return 0
	if role=="gather":
		var nearest: int = 999999
		var site: Vector2i = target
		for node in state.resource_nodes:
			var distance: int = _distance(node.pos,target)
			if distance<nearest:
				nearest = distance
				site = node.pos
		target = site
	var center_block: Dictionary = state.get_block_at(target)
	if role=="gather" and not center_block.is_empty() and int(center_block.owner)==owner and supplied.has(target) and original.blocks.has(center_block.id):
		_convert(state,center_block,"gather",actions)
	if is_complete(state,{"tile_type":role,"target":target,"owner":owner},supplied):
		return 0
	var grown: int = 0
	var boundary: Dictionary = {}
	var nearest: float = INF
	# Build this front once. Re-scanning every owned tile on every growth wave
	# made a late-game turn cost several seconds as the colonies filled the map.
	for pos in supplied:
		if int(supplied[pos])!=owner:
			continue
		nearest = minf(nearest,Vector2(pos).distance_to(Vector2(target)))
		var depth: int = int(depths.get(pos,0))
		if depth>=RULES.GROWTH_STEPS:
			continue
		for dir in BoardTopology.CARDINAL_STEPS:
			var next: Vector2i = pos+dir
			if state.is_empty_ground(next) and not state.is_reclaim_blocked(next):
				boundary[next] = mini(int(boundary.get(next,999)),depth+1)
	for wave in range(RULES.GROWTH_STEPS):
		var candidates: Array = []
		for pos in boundary:
			if not state.is_empty_ground(pos) or state.is_reclaim_blocked(pos):
				continue
			var distance: float = Vector2(pos).distance_to(Vector2(target))
			if distance>nearest+RULES.FRONT_BAND:
				continue
			var support: int = 0
			var available: int = 0
			for y in range(-2,3):
				for x in range(-2,3):
					if x==0 and y==0:
						continue
					var neighbor: Vector2i = pos+Vector2i(x,y)
					if not state.is_inside(neighbor) or state.is_blocked(neighbor):
						continue
					available += 1
					if supplied.get(neighbor,0)==owner:
						support += 1
			# Require a developed shoulder before advancing; walls and map bounds
			# scale the requirement to the ground that can actually support growth.
			if support<maxi(2,int(ceil(float(available)/3.0))):
				continue
			candidates.append({"pos":pos,"depth":boundary[pos],"rank":support*2.0-distance*0.35})
		candidates.sort_custom(func(a,b): return a.rank>b.rank if a.rank!=b.rank else (a.pos.y*state.width+a.pos.x)<(b.pos.y*state.width+b.pos.x))
		var allowance: int = int(ceil(float(quota-grown)/(RULES.GROWTH_STEPS-wave)))
		var placed: int = 0
		var placed_positions: Array[Vector2i] = []
		for candidate in candidates:
			if placed>=allowance or grown>=quota:
				break
			var pos: Vector2i = candidate.pos
			var tile_role: String = "gather" if role=="gather" and pos==target and int(state.players[owner].nutrients)>=4 else "basic"
			var cost: int = RULES.GROWTH_COST if tile_role=="basic" else int(Combat.TILE_RULES[tile_role].cost)
			if _apply(state,{"type":"place_tile","owner":owner,"target":pos,"tile_type":tile_role,"cost":cost,"min_adjacent":1},actions):
				supplied[pos] = owner
				depths[pos] = candidate.depth
				boundary.erase(pos)
				grown += 1
				placed += 1
				placed_positions.append(pos)
		for pos in placed_positions:
			nearest = minf(nearest,Vector2(pos).distance_to(Vector2(target)))
			var depth: int = int(depths[pos])
			if depth>=RULES.GROWTH_STEPS:
				continue
			for dir in BoardTopology.CARDINAL_STEPS:
				var next: Vector2i = pos+dir
				if state.is_empty_ground(next) and not state.is_reclaim_blocked(next):
					boundary[next] = mini(int(boundary.get(next,999)),depth+1)
	return grown

func _specialize(state: GameState, original: GameState, owner: int, order: Dictionary, actions: Array, supplied: Dictionary) -> void:
	var role: String = order.tile_type
	var target: Vector2i = order.target
	var selection: Rect2i = order.get("selection",Rect2i(target-Vector2i(10,10),Vector2i(21,21)))
	if not frontiers.has(owner):
		frontiers[owner] = FRONTIER.new(original,owner)
	var frontier = frontiers[owner]
	var candidates: Array = []
	for block in state.get_owner_blocks(owner):
		if block.core or not original.blocks.has(block.id) or not supplied.has(block.pos) or not selection.has_point(block.pos):
			continue
		if block.tile_type==role:
			continue
		# Do not silently tear down existing specialized organs.
		if block.tile_type!="basic":
			continue
		var near: int = frontier.nearest(block.pos).distance
		var exposed: bool = false
		for dir in BoardTopology.CARDINAL_STEPS:
			if state.is_empty_ground(block.pos+dir):
				exposed = true
		var rank: float = -float(_distance(block.pos,target))*0.2
		match role:
			"gather":
				if state.get_resource_node_at(block.pos).is_empty():
					continue
				rank += 100
			"defense":
				if not exposed and near>2:
					continue
				rank -= near
			"melee":
				if not exposed and near>2:
					continue
				rank -= near*2
			"ranged":
				if near<=1:
					continue
				rank -= absf(float(near)-6.0)*2.0
				if not exposed:
					rank += 3
		candidates.append({"id":block.id,"rank":rank})
	# A breach or holding order can extend the front with specialized tissue,
	# rather than stalling once every existing edge tile has a role.
	var seen: Dictionary = {}
	if role!="gather":
		for block in state.get_owner_blocks(owner):
			if not supplied.has(block.pos):
				continue
			for dir in BoardTopology.CARDINAL_STEPS:
				var pos: Vector2i = block.pos+dir
				if seen.has(pos) or not selection.has_point(pos) or not state.is_empty_ground(pos):
					continue
				seen[pos] = true
				if not state.evaluate_growth_target(owner,pos,1).get("ok",false):
					continue
				var near: int = frontier.nearest(pos).distance
				if role=="ranged" and near<=2:
					continue
				var rank: float = -float(_distance(pos,target))*0.2
				rank -= absf(float(near)-6.0)*2.0 if role=="ranged" else float(near)*(2.0 if role=="melee" else 1.0)
				candidates.append({"id":-1,"target":pos,"rank":rank})
	candidates.sort_custom(func(a,b): return a.rank>b.rank if a.rank!=b.rank else str(a)<str(b))
	var changes: int = 0
	for candidate in candidates:
		if changes>=RULES.SPECIALIZE_LIMIT:
			break
		var applied: bool = false
		if candidate.id<0:
			applied = _apply(state,{"type":"place_tile","owner":owner,"target":candidate.target,"tile_type":role,"cost":int(Combat.TILE_RULES[role].cost),"min_adjacent":1},actions)
			if applied:
				supplied[candidate.target] = owner
		else:
			applied = _convert(state,state.blocks[candidate.id],role,actions)
		if applied:
			changes += 1

func _convert(state: GameState, block: Dictionary, role: String, actions: Array) -> bool:
	if block.is_empty() or block.core or block.tile_type!="basic":
		return false
	return _apply(state,{"type":"convert_tile","owner":block.owner,"block_id":block.id,"to_type":role,"energy_delta":Combat.conversion_energy_delta("basic",role)},actions)

func _apply(state: GameState, action: Dictionary, actions: Array) -> bool:
	var report: Dictionary = combat._apply_staged_actions([action],state,false,true)
	if int(report.get("applied_count",0))==0:
		return false
	actions.append(action)
	return true

func _distance(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
