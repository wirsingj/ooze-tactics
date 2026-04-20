extends RefCounted
class_name GameState

# Central mutable state for a run/level.

const PLAYER_ID: int = 1
const TEAM_PLAYER: int = 1
const TEAM_ENEMY: int = 2
const MIN_SUPPORT_FOR_PLACEMENT: int = 3
const CORRIDOR_SUPPORT_DISCOUNT: int = 1
const CORRIDOR_BLOCKED_SIDES_THRESHOLD: int = 2
const HEART_TILE_HP_BONUS: int = 4

var width: int = 30
var height: int = 20
var level_index: int = 1
var run_seed: int = 1337
var turn_index: int = 0

var players: Dictionary = {}
var blocks: Dictionary = {}
var resource_nodes: Array = []
var wall_tiles: Dictionary = {}
var reclaim_timers: Dictionary = {}
var entrance_tile: Vector2i = Vector2i(1, 10)
var door_tile: Vector2i = Vector2i(28, 10)
var door_hp: int = 28
var door_max_hp: int = 28
var turn_limit: int = 50
var enemies_allied: bool = true
var dev_player_immortal: bool = false
var spectator_mode: bool = false

var stall_counter: int = 0
var next_block_id: int = 1
var last_log: Array[String] = []
var last_resolution_report: Dictionary = {}
# Runtime has no active card-draft flow today, but these modifiers are still read by
# combat/economy/cost math and should remain deterministic if re-enabled later.
var card_modifiers: Dictionary = {}
var upgrade_counts: Dictionary = {}

func _init() -> void:
	players = {
		PLAYER_ID: {
			"name": "Player",
			"nutrients": 8,
			"alive": true,
			"team": TEAM_PLAYER,
			"ai_controlled": false,
		},
	}
	_ensure_owner_upgrade_bucket(PLAYER_ID)

func copy_state() -> GameState:
	var cloned: GameState = GameState.new()
	cloned.width = width
	cloned.height = height
	cloned.level_index = level_index
	cloned.run_seed = run_seed
	cloned.turn_index = turn_index
	cloned.players = players.duplicate(true)
	cloned.blocks = blocks.duplicate(true)
	cloned.resource_nodes = resource_nodes.duplicate(true)
	cloned.wall_tiles = wall_tiles.duplicate(true)
	cloned.reclaim_timers = reclaim_timers.duplicate(true)
	cloned.entrance_tile = entrance_tile
	cloned.door_tile = door_tile
	cloned.door_hp = door_hp
	cloned.door_max_hp = door_max_hp
	cloned.turn_limit = turn_limit
	cloned.enemies_allied = enemies_allied
	cloned.dev_player_immortal = dev_player_immortal
	cloned.spectator_mode = spectator_mode
	cloned.stall_counter = stall_counter
	cloned.next_block_id = next_block_id
	cloned.last_log = last_log.duplicate()
	cloned.last_resolution_report = last_resolution_report.duplicate(true)
	cloned.card_modifiers = card_modifiers.duplicate(true)
	cloned.upgrade_counts = upgrade_counts.duplicate(true)
	return cloned

func add_owner(owner_id: int, name: String, nutrients: int, team: int = TEAM_ENEMY, ai_controlled: bool = true) -> void:
	players[owner_id] = {
		"name": name,
		"nutrients": nutrients,
		"alive": true,
		"team": team,
		"ai_controlled": ai_controlled,
	}
	_ensure_owner_upgrade_bucket(owner_id)

func get_owner_team(owner_id: int) -> int:
	if not players.has(owner_id):
		return TEAM_ENEMY
	return int(players[owner_id].get("team", TEAM_ENEMY))

func spawn_block(owner_id: int, pos: Vector2i, is_core: bool, base_hp: int = 10, tile_type: String = "basic") -> int:
	var id: int = next_block_id
	next_block_id += 1
	blocks[id] = {
		"id": id,
		"owner": owner_id,
		"pos": pos,
		"hp": base_hp,
		"max_hp": base_hp,
		"defense": 0,
		"tile_type": tile_type,
		"core": is_core,
		"range": 1,
		"damage": 0,
		"gather_bonus": 0,
		"age": 0,
		"last_converted_turn": -999999,
		"is_heart": is_core,
		"upgrade_tier": 0,
		"melee_break_bonus": 0,
		"ranged_splash_bonus": 0,
		"defense_guard_bonus": 0,
		"gather_upgrade_bonus": 0,
	}
	return id

func get_upgrade_count(owner_id: int, tile_type: String) -> int:
	_ensure_owner_upgrade_bucket(owner_id)
	return int(upgrade_counts.get(owner_id, {}).get(tile_type, 0))

func get_total_upgrade_count(owner_id: int) -> int:
	_ensure_owner_upgrade_bucket(owner_id)
	var bucket: Dictionary = upgrade_counts.get(owner_id, {})
	var total: int = 0
	for tile_type in bucket.keys():
		total += int(bucket.get(tile_type, 0))
	return total

func register_tile_upgrade(owner_id: int, tile_type: String) -> void:
	if tile_type == "basic":
		return
	_ensure_owner_upgrade_bucket(owner_id)
	var bucket: Dictionary = upgrade_counts.get(owner_id, {})
	bucket[tile_type] = int(bucket.get(tile_type, 0)) + 1
	upgrade_counts[owner_id] = bucket

func get_block_at(tile: Vector2i) -> Dictionary:
	for block in blocks.values():
		if block["pos"] == tile:
			return block
	return {}

func get_owner_blocks(owner_id: int) -> Array:
	var out: Array = []
	for block in blocks.values():
		if int(block["owner"]) == owner_id:
			out.append(block)
	return out

func get_core(owner_id: int) -> Dictionary:
	for block in blocks.values():
		if int(block["owner"]) == owner_id and bool(block["core"]):
			return block
	return {}

func get_resource_node_at(tile: Vector2i) -> Dictionary:
	for node in resource_nodes:
		if node["pos"] == tile:
			return node
	return {}

func remove_dead_blocks() -> Array[int]:
	var removed: Array[int] = []
	for block_id in blocks.keys():
		var b: Dictionary = blocks[block_id]
		if int(b["hp"]) <= 0:
			removed.append(int(block_id))
	for block_id in removed:
		blocks.erase(block_id)
	return removed

func is_inside(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height

func is_blocked(tile: Vector2i) -> bool:
	return wall_tiles.has(_tile_key(tile))

func is_reclaim_blocked(tile: Vector2i) -> bool:
	var key: String = _tile_key(tile)
	return int(reclaim_timers.get(key, 0)) > 0

func is_empty_ground(tile: Vector2i) -> bool:
	return is_inside(tile) and tile != entrance_tile and tile != door_tile and not is_blocked(tile) and not is_reclaim_blocked(tile) and get_block_at(tile).is_empty()

func mark_reclaim_block(tile: Vector2i, turns: int = 1) -> void:
	if not is_inside(tile):
		return
	if is_blocked(tile):
		return
	var key: String = _tile_key(tile)
	# +1 keeps a destroyed tile blocked for one full subsequent turn after the
	# destruction turn has already resolved.
	var pending_turns: int = maxi(1, turns) + 1
	reclaim_timers[key] = maxi(int(reclaim_timers.get(key, 0)), pending_turns)

func tick_reclaim_blocks() -> void:
	# This must be called once per resolved turn (after combat) to preserve the
	# one-turn reclaim delay contract used by validation and tests.
	if reclaim_timers.is_empty():
		return
	var keys: Array = reclaim_timers.keys()
	for key_variant in keys:
		var key: String = String(key_variant)
		var turns_left: int = int(reclaim_timers.get(key, 0)) - 1
		if turns_left <= 0:
			reclaim_timers.erase(key)
		else:
			reclaim_timers[key] = turns_left

func set_walls(walls: Array) -> void:
	wall_tiles.clear()
	for w in walls:
		if w is Array and w.size() >= 2:
			wall_tiles[_tile_key(Vector2i(int(w[0]), int(w[1])))] = true

func count_adjacent_owned(owner_id: int, tile: Vector2i, extra_owned_tiles: Dictionary = {}) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t: Vector2i = tile + step
		if extra_owned_tiles.has(_tile_key(t)):
			count += 1
			continue
		var neighbor: Dictionary = get_block_at(t)
		if not neighbor.is_empty() and int(neighbor["owner"]) == owner_id:
			count += 1
	return count

func evaluate_growth_target(owner_id: int, tile: Vector2i, min_adjacent: int, extra_owned_tiles: Dictionary = {}) -> Dictionary:
	# Support-based placement rule:
	# 1) Must connect via cardinal adjacency.
	# 2) Must have sufficient local support in Manhattan radius 2.
	#    Narrow corridor tiles get a small support discount to keep 1-tile
	#    passages playable without opening up free-form snaking in open rooms.
	var adjacent_owned: int = count_adjacent_owned(owner_id, tile, extra_owned_tiles)
	if adjacent_owned <= 0:
		return {"ok": false, "reason": "not adjacent"}
	if adjacent_owned < min_adjacent:
		return {"ok": false, "reason": "adjacency too low (%d/%d)" % [adjacent_owned, min_adjacent]}

	var support: int = count_owned_within_manhattan(owner_id, tile, 2, extra_owned_tiles)
	var required_support: int = support_required_for_tile(tile, owner_id)
	if support < required_support:
		return {"ok": false, "reason": "needs more support (%d/%d)" % [support, required_support]}

	return {"ok": true}

func support_required_for_tile(tile: Vector2i, owner_id: int = PLAYER_ID) -> int:
	var required_support: int = MIN_SUPPORT_FOR_PLACEMENT
	if is_narrow_corridor_tile(tile):
		required_support -= CORRIDOR_SUPPORT_DISCOUNT
	if owner_id == PLAYER_ID:
		required_support += int(card_modifiers.get("placement_support_delta", 0))
	return maxi(1, required_support)

func is_narrow_corridor_tile(tile: Vector2i) -> bool:
	var blocked_sides: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var side: Vector2i = tile + step
		if not is_inside(side):
			blocked_sides += 1
			continue
		if is_blocked(side):
			blocked_sides += 1
			continue
		if side == entrance_tile:
			blocked_sides += 1
			continue
		if side == door_tile:
			blocked_sides += 1
	return blocked_sides >= CORRIDOR_BLOCKED_SIDES_THRESHOLD

func count_owned_within_manhattan(owner_id: int, tile: Vector2i, max_distance: int, extra_owned_tiles: Dictionary = {}, include_center: bool = false) -> int:
	var count: int = 0
	for y in range(tile.y - max_distance, tile.y + max_distance + 1):
		for x in range(tile.x - max_distance, tile.x + max_distance + 1):
			var p: Vector2i = Vector2i(x, y)
			if not is_inside(p):
				continue
			var dist: int = absi(tile.x - p.x) + absi(tile.y - p.y)
			if dist > max_distance:
				continue
			if not include_center and dist == 0:
				continue
			if extra_owned_tiles.has(_tile_key(p)):
				count += 1
				continue
			var block: Dictionary = get_block_at(p)
			if not block.is_empty() and int(block["owner"]) == owner_id:
				count += 1
	return count

func has_any_legal_action(owner_id: int, min_adjacent: int, grow_cost: int) -> bool:
	if not players.has(owner_id):
		return false
	var energy: int = int(players[owner_id]["nutrients"])

	if energy >= grow_cost:
		for y in range(height):
			for x in range(width):
				var t: Vector2i = Vector2i(x, y)
				if not is_empty_ground(t):
					continue
				if bool(evaluate_growth_target(owner_id, t, min_adjacent, {}).get("ok", false)):
					return true

	for block in get_owner_blocks(owner_id):
		var from_type: String = String(block.get("tile_type", "basic"))
		if from_type != "basic":
			return true # can always convert specialized tiles back to basic for a refund
		for to_type in ["defense", "melee", "ranged", "gather"]:
			var delta: int = Combat.conversion_energy_delta(from_type, to_type, int(block.get("upgrade_tier", 0)))
			if energy >= delta:
				return true

	for block in get_owner_blocks(owner_id):
		var role: String = String(block.get("tile_type", "basic"))
		if role == "melee":
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var target: Dictionary = get_block_at(block["pos"] + step)
				if not target.is_empty() and are_hostile(owner_id, int(target["owner"])):
					return true
		elif role == "ranged":
			for enemy in blocks.values():
				if are_hostile(owner_id, int(enemy["owner"])):
					return true

	return false

func get_total_hp(owner_id: int) -> int:
	var total: int = 0
	for block in get_owner_blocks(owner_id):
		total += int(block.get("hp", 0))
	return total

func count_heart_tiles(owner_id: int) -> int:
	var count: int = 0
	for block in get_owner_blocks(owner_id):
		if bool(block.get("is_heart", false)):
			count += 1
	return count

func are_hostile(a_owner: int, b_owner: int) -> bool:
	# Authoritative hostility contract for combat, AI targeting, UI summaries,
	# and door-damage permissions. Keep all team-rule changes centralized here.
	if a_owner == b_owner:
		return false

	var a_team: int = get_owner_team(a_owner)
	var b_team: int = get_owner_team(b_owner)
	if a_team == b_team:
		# Dev mode can split enemy owners into separate hostile factions.
		if a_team == TEAM_ENEMY and not enemies_allied:
			return true
		return false

	# Different teams are always hostile in current ruleset.
	return true

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _ensure_owner_upgrade_bucket(owner_id: int) -> void:
	if upgrade_counts.has(owner_id):
		return
	upgrade_counts[owner_id] = {
		"melee": 0,
		"ranged": 0,
		"defense": 0,
		"gather": 0,
	}
