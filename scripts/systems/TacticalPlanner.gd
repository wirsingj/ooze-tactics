extends RefCounted

# Bounded two-tick combat search over the visible board. No queued human
# orders, extra resources, or simulated actor-by-actor economy ticks.
const MAX_CANDIDATES: int = 12
const MAX_DEPTH: int = 3
var rollouts: int = 0
var combat := Combat.new()
var tick := TickSystem.new()
var objective_map: Dictionary = {}

func refine(state: GameState, owner: int, min_adjacent: int, proposed: Array) -> Array:
	rollouts = 0
	var targets: Array = []
	var nearby: bool = false
	for enemy in state.blocks.values():
		if not state.are_hostile(owner,int(enemy.owner)):
			continue
		if enemy.core:
			targets.append(enemy.pos)
		for own in state.get_owner_blocks(owner):
			if _distance(own.pos,enemy.pos)<=6:
				nearby = true
	if not nearby:
		return proposed
	objective_map = BoardTopology.distance_map_to_positions(state,targets)
	var max_actions: int = maxi(1,int(state.players[owner].get("max_actions",3)))
	var best: Array = proposed.slice(0,max_actions)
	var best_score: float = _score_plan(state,owner,best)
	var prefix: Array = []
	var prefix_score: float = _score_plan(state,owner,prefix)
	# Waiting can be preferable to buying tissue that dies without helping.
	if prefix_score>best_score+0.1:
		best = []
		best_score = prefix_score
	for depth in range(mini(max_actions,MAX_DEPTH)):
		var staged: GameState = state.copy_state()
		combat._apply_staged_actions(prefix,staged,false,true)
		var candidates: Array = _candidates(staged,owner,min_adjacent,prefix)
		var next_prefix: Array = prefix
		var next_score: float = prefix_score
		for candidate in candidates.slice(0,MAX_CANDIDATES):
			var plan: Array = prefix.duplicate(true)
			plan.append(candidate.action)
			var value: float = _score_plan(state,owner,plan)
			if value>next_score+0.1:
				next_prefix = plan
				next_score = value
		if next_prefix.size()==prefix.size():
			break
		prefix = next_prefix
		prefix_score = next_score
		if prefix_score>best_score+0.1:
			best = prefix
			best_score = prefix_score
	return best

func _score_plan(state: GameState, owner: int, actions: Array) -> float:
	var preview: Dictionary = combat.preview_resolution(state,actions)
	if not preview.get("failed_actions",[]).is_empty():
		return -INF
	rollouts += 1
	var next: GameState = tick.step_fast_for_trainer(state,actions)
	if bool(next.players.get(owner,{}).get("alive",false)):
		next = tick.step_fast_for_trainer(next,[])
	var score: float = 0.0
	var frontier: int = 99
	for id in next.players:
		var sign_: float = -1.0 if next.are_hostile(owner,id) else (1.0 if id==owner else 0.65)
		if not bool(next.players[id].get("alive",false)):
			score -= sign_*1000.0
	for block in next.blocks.values():
		var sign_: float = -1.0 if next.are_hostile(owner,int(block.owner)) else (1.0 if int(block.owner)==owner else 0.65)
		var role: String = String(block.tile_type)
		var worth: float = 1.0+float(Combat.TILE_RULES[role].cost)*1.5+float(block.get("upgrade_tier",0))*1.5
		# A firing organ is a continuing threat, not just its purchase price.
		# Value removing firepower above adding cheap, passive bodies.
		worth += float(block.get("damage",0))*3.0
		score += sign_*worth*clampf(float(block.hp)/maxf(1.0,float(block.max_hp)),0,1)
		if block.core:
			score += sign_*float(block.hp)*4.0
		if int(block.owner)==owner:
			frontier = mini(frontier,int(objective_map.get(block.pos,99)))
	score -= float(frontier)*1.3
	score += float(next.players[owner].get("nutrients",0))*0.85
	# Two income settlements are already present in the simulated treasury.
	# A small residual value avoids rewarding six turns of economy against
	# only two turns of combat, which made farming beat immediate retaliation.
	score += float(Economy.new().compute_income_and_upkeep(next).delta.get(owner,0))
	return score

func _candidates(state: GameState, owner: int, min_adjacent: int, prefix: Array) -> Array:
	var candidates: Array = []
	var spent_blocks: Dictionary = {}
	for action in prefix:
		if action.has("block_id"):
			spent_blocks[action.block_id] = true
	var energy: int = int(state.players[owner].nutrients)
	for block in state.get_owner_blocks(owner):
		if block.core or spent_blocks.has(block.id):
			continue
		var near: int = _nearest_hostile(state,owner,block.pos)
		if block.tile_type=="basic" and state.turn_index-int(block.get("last_converted_turn",-999))>=2:
			for role in _roles(near):
				if role=="basic":
					continue
				var cost: int = Combat.conversion_energy_delta("basic",role)
				if cost<=energy:
					_add(candidates,state,owner,block.pos,role,{"type":"convert_tile","owner":owner,"block_id":block.id,"to_type":role,"energy_delta":cost})
		elif near<=5 and int(block.get("upgrade_tier",1))<Combat.MAX_UPGRADE_TIER:
			var cost: int = Combat.upgrade_energy_cost(state,owner,block.tile_type,0,0,int(block.get("upgrade_tier",1)))
			if cost>=0 and cost<=energy:
				_add(candidates,state,owner,block.pos,block.tile_type,{"type":"upgrade_tile","owner":owner,"block_id":block.id,"tile_type":block.tile_type,"cost":cost})
	var seen: Dictionary = {}
	for block in state.get_owner_blocks(owner):
		for dir in BoardTopology.CARDINAL_STEPS:
			var pos: Vector2i = block.pos+dir
			if seen.has(pos) or not state.is_empty_ground(pos):
				continue
			seen[pos] = true
			if not state.evaluate_growth_target(owner,pos,min_adjacent).get("ok",false):
				continue
			for role in _roles(_nearest_hostile(state,owner,pos)):
				var cost: int = int(Combat.TILE_RULES[role].cost)
				if cost<=energy:
					_add(candidates,state,owner,pos,role,{"type":"place_tile","owner":owner,"target":pos,"tile_type":role,"cost":cost,"min_adjacent":min_adjacent})
	candidates.sort_custom(func(a,b): return a.rank>b.rank if a.rank!=b.rank else a.key<b.key)
	return candidates

func _roles(distance: int) -> Array:
	if distance<=1:
		return ["melee","defense","ranged","basic"]
	if distance<=4:
		return ["ranged","defense","basic"]
	return ["basic","gather"]

func _add(out: Array, state: GameState, owner: int, pos: Vector2i, role: String, action: Dictionary) -> void:
	var rank: float = -float(objective_map.get(pos,99))
	for enemy in state.blocks.values():
		if not state.are_hostile(owner,int(enemy.owner)):
			continue
		var distance: int = _distance(pos,enemy.pos)
		if (role=="melee" and distance==1) or (role=="ranged" and distance<=4):
			rank += 8.0+(5.0 if enemy.core else 0.0)
		if role=="defense" and distance<=2:
			rank += 3.0
	# Always evaluate survival/actual damage; this rank only bounds the shortlist.
	out.append({"action":action,"rank":rank,"key":"%03d/%03d/%s/%s" % [pos.y,pos.x,role,action.type]})

func _nearest_hostile(state: GameState, owner: int, pos: Vector2i) -> int:
	var nearest: int = 99
	for block in state.blocks.values():
		if state.are_hostile(owner,int(block.owner)):
			nearest = mini(nearest,_distance(pos,block.pos))
	return nearest

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)
