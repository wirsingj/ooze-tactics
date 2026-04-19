extends RefCounted
class_name GameState

# Central mutable state for a run/level.

const PLAYER_ID: int = 1
const MIN_SUPPORT_FOR_PLACEMENT: int = 3

var width: int = 30
var height: int = 20
var level_index: int = 1
var run_seed: int = 1337
var turn_index: int = 0

var players: Dictionary = {}
var blocks: Dictionary = {}
var resource_nodes: Array = []
var wall_tiles: Dictionary = {}
var door_tile: Vector2i = Vector2i(28, 10)

var stall_counter: int = 0
var next_block_id: int = 1
var last_log: Array[String] = []
var last_resolution_report: Dictionary = {}
var card_modifiers: Dictionary = {}

func _init() -> void:
	players = {
		PLAYER_ID: {
			"name": "Player",
			"nutrients": 8,
			"alive": true,
		},
	}

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
	cloned.door_tile = door_tile
	cloned.stall_counter = stall_counter
	cloned.next_block_id = next_block_id
	cloned.last_log = last_log.duplicate()
	cloned.last_resolution_report = last_resolution_report.duplicate(true)
	cloned.card_modifiers = card_modifiers.duplicate(true)
	return cloned

func add_owner(owner_id: int, name: String, nutrients: int) -> void:
	players[owner_id] = {
		"name": name,
		"nutrients": nutrients,
		"alive": true,
	}

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
	}
	return id

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

func is_empty_ground(tile: Vector2i) -> bool:
	return is_inside(tile) and not is_blocked(tile) and get_block_at(tile).is_empty()

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
	var adjacent_owned: int = count_adjacent_owned(owner_id, tile, extra_owned_tiles)
	if adjacent_owned <= 0:
		return {"ok": false, "reason": "not adjacent"}
	if adjacent_owned < min_adjacent:
		return {"ok": false, "reason": "adjacency too low (%d/%d)" % [adjacent_owned, min_adjacent]}

	var support: int = count_owned_within_manhattan(owner_id, tile, 2, extra_owned_tiles)
	if support < MIN_SUPPORT_FOR_PLACEMENT:
		return {"ok": false, "reason": "needs more support (%d/%d)" % [support, MIN_SUPPORT_FOR_PLACEMENT]}

	return {"ok": true}

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
			return true # can always convert back to basic at zero cost
		for to_type in ["defense", "melee", "ranged", "gather"]:
			var delta: int = Combat.conversion_energy_delta(from_type, to_type)
			if energy >= delta:
				return true

	for block in get_owner_blocks(owner_id):
		var role: String = String(block.get("tile_type", "basic"))
		if role == "melee":
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var target: Dictionary = get_block_at(block["pos"] + step)
				if not target.is_empty() and int(target["owner"]) != owner_id:
					return true
		elif role == "ranged":
			for enemy in blocks.values():
				if int(enemy["owner"]) != owner_id:
					return true

	return false

func get_total_hp(owner_id: int) -> int:
	var total: int = 0
	for block in get_owner_blocks(owner_id):
		total += int(block.get("hp", 0))
	return total

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
