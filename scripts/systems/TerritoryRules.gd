extends RefCounted

# Territory War uses the shared simulation with explicit, symmetric rules.
# Ordinary tissue spreads within a colony-wide biological growth allowance;
# energy buys organs. There is no incentive to save energy by drawing a thread.
const GROWTH_COST = 0
const GROWTH_LIMIT = 180
const GROWTH_STEPS = 4
const FRONT_BAND = 18.0
const SITE_RADIUS = 6
const SITE_COVERAGE = 0.60
const HOME_INCOME = 8
const WELL_INCOME = 10
const EXTRACTOR_INCOME = 6
const FARM_LINK_RADIUS = 60
const FARM_LINK_INCOME = 2
const WIN_SCORE = 100
const ORDER_LIMIT = 3
const SPECIALIZE_LIMIT = 6

static func supplied_tiles(state: GameState) -> Dictionary:
	var reached: Dictionary = {}
	var queue: Array[Vector2i] = []
	for block in state.blocks.values():
		if block.core and int(block.hp)>0:
			reached[block.pos] = int(block.owner)
			queue.append(block.pos)
	var head: int = 0
	while head<queue.size():
		var pos: Vector2i = queue[head]
		head += 1
		for dir in BoardTopology.CARDINAL_STEPS:
			var next: Vector2i = pos+dir
			if reached.has(next):
				continue
			var block: Dictionary = state.get_block_at(next)
			if not block.is_empty() and int(block.owner)==int(reached[pos]) and int(block.hp)>0:
				reached[next] = int(block.owner)
				queue.append(next)
	return reached

static func settle_sites(state: GameState) -> void:
	var supplied: Dictionary = supplied_tiles(state)
	for node in state.resource_nodes:
		var status: Dictionary = site_status(state,node,supplied)
		var owner: int = int(status.controller)
		node["controller"] = owner
		node["coverage"] = status.coverage
		node["contested"] = status.contested
		if owner>0 and not bool(node.get("home",false)):
			var team: int = state.get_owner_team(owner)
			state.team_scores[team] = int(state.team_scores.get(team,0))+1

static func site_status(state: GameState, node: Dictionary, supplied: Dictionary) -> Dictionary:
	var owner: int = int(supplied.get(node.pos,0))
	var counts: Dictionary = {}
	var total: int = 0
	for y in range(-SITE_RADIUS,SITE_RADIUS+1):
		for x in range(-SITE_RADIUS,SITE_RADIUS+1):
			var pos: Vector2i = node.pos+Vector2i(x,y)
			if x*x+y*y>SITE_RADIUS*SITE_RADIUS or not state.is_inside(pos) or state.is_blocked(pos):
				continue
			total += 1
			var cell_owner: int = int(supplied.get(pos,0))
			if cell_owner>0:
				var team: int = state.get_owner_team(cell_owner)
				counts[team] = int(counts.get(team,0))+1
	var coverage: float = float(counts.get(state.get_owner_team(owner),0))/maxi(1,total) if owner>0 else 0.0
	var hostile_count: int = 0
	for team in counts:
		if owner>0 and team!=state.get_owner_team(owner):
			hostile_count += counts[team]
	var contested: bool = float(hostile_count)/maxi(1,total)>=0.25
	var secured: bool = owner>0 and (bool(node.get("home",false)) or (coverage>=SITE_COVERAGE and not contested))
	return {"controller":owner if secured else 0,"occupant":owner,"coverage":coverage,"contested":contested}

static func income(state: GameState) -> Dictionary:
	var supplied: Dictionary = supplied_tiles(state)
	var result: Dictionary = {}
	var upkeep: Dictionary = {}
	var controlled_sites: Array[Dictionary] = []
	for owner in state.players:
		result[owner] = HOME_INCOME if state.players[owner].alive else 0
		upkeep[owner] = 0
	for node in state.resource_nodes:
		var owner: int = int(site_status(state,node,supplied).controller)
		if owner<=0:
			continue
		result[owner] += WELL_INCOME
		var block: Dictionary = state.get_block_at(node.pos)
		if block.get("tile_type","")=="gather":
			result[owner] += EXTRACTOR_INCOME+int(block.get("gather_upgrade_bonus",0))*2
		if not bool(node.get("home",false)):
			controlled_sites.append({"owner":owner,"team":state.get_owner_team(owner),"pos":node.pos})
	for site in controlled_sites:
		var links: int = 0
		for other in controlled_sites:
			if site.pos==other.pos or site.team!=other.team:
				continue
			if absi(site.pos.x-other.pos.x)+absi(site.pos.y-other.pos.y)<=FARM_LINK_RADIUS:
				links += 1
		# Each endpoint receives a small bonus for every secured allied well nearby.
		result[site.owner] += links*FARM_LINK_INCOME
	return {"income":result,"upkeep":upkeep,"delta":result.duplicate()}

static func clear_shot(state: GameState, owner: int, origin: Vector2i, target: Vector2i) -> bool:
	# Supercover traversal prevents corner shots between two blocking cells.
	var current: Vector2i = origin
	var delta: Vector2i = target-origin
	var nx: int = absi(delta.x)
	var ny: int = absi(delta.y)
	var step := Vector2i(signi(delta.x),signi(delta.y))
	var ix: int = 0
	var iy: int = 0
	while ix<nx or iy<ny:
		var decision: int = (1+2*ix)*ny-(1+2*iy)*nx
		if decision==0:
			if blocked_shot(state,owner,current+Vector2i(step.x,0),target) or blocked_shot(state,owner,current+Vector2i(0,step.y),target):
				return false
			current += step
			ix += 1
			iy += 1
		elif decision<0:
			current.x += step.x
			ix += 1
		else:
			current.y += step.y
			iy += 1
		if blocked_shot(state,owner,current,target):
			return false
	return true

static func blocked_shot(state: GameState, owner: int, pos: Vector2i, target: Vector2i) -> bool:
	if state.is_blocked(pos):
		return true
	if pos==target:
		return false
	var block: Dictionary = state.get_block_at(pos)
	return not block.is_empty() and block.get("tile_type","")=="defense" and state.are_hostile(owner,int(block.owner)) and int(block.hp)>0
