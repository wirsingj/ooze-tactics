extends RefCounted
class_name LevelGenerator

# Builds neutral cave maps with small starting blobs for each faction.

func build_level(level_index: int, run_seed: int, room_templates: Array, _enemy_defs: Array, keep_player_shape: Array) -> GameState:
	var state: GameState = GameState.new()
	state.level_index = level_index
	state.run_seed = run_seed
	state.turn_index = 0

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed + level_index * 77

	if room_templates.is_empty():
		room_templates = [_fallback_template()]

	var room: Dictionary = room_templates[rng.randi_range(0, room_templates.size() - 1)]
	state.width = int(room.get("width", 30))
	state.height = int(room.get("height", 18))

	var door_raw: Array = room.get("door", [state.width - 2, state.height / 2])
	state.door_tile = Vector2i(int(door_raw[0]), int(door_raw[1]))
	state.set_walls(room.get("walls", []))

	state.players[GameState.PLAYER_ID]["nutrients"] = 8 + level_index

	for enemy in room.get("enemies", []):
		var enemy_id: int = int(enemy.get("owner", 2))
		if not state.players.has(enemy_id):
			state.add_owner(enemy_id, "Enemy %d" % enemy_id, 8 + level_index)

	state.resource_nodes = []
	for node in room.get("resource_nodes", []):
		if node is Array and node.size() >= 2:
			var kind: String = "gem"
			if node.size() >= 3:
				kind = String(node[2])
			state.resource_nodes.append({
				"pos": Vector2i(int(node[0]), int(node[1])),
				"kind": kind,
				"consumed": false,
			})

	if keep_player_shape.is_empty():
		var p_seed_raw: Array = room.get("player_seed", [4, state.height / 2])
		var p_seed: Vector2i = Vector2i(int(p_seed_raw[0]), int(p_seed_raw[1]))
		_spawn_cluster(state, GameState.PLAYER_ID, p_seed, rng.randi_range(3, 6), rng)
	else:
		_spawn_carried_shape(state, keep_player_shape)

	for enemy in room.get("enemies", []):
		var seed_raw: Array = enemy.get("seed", [state.width - 5, state.height / 2])
		var seed: Vector2i = Vector2i(int(seed_raw[0]), int(seed_raw[1]))
		_spawn_cluster(state, int(enemy.get("owner", 2)), seed, rng.randi_range(3, 6), rng)

	return state

func _spawn_carried_shape(state: GameState, keep_player_shape: Array) -> void:
	var min_x: int = 99999
	var min_y: int = 99999
	for b in keep_player_shape:
		min_x = mini(min_x, int(b["pos"][0]))
		min_y = mini(min_y, int(b["pos"][1]))
	var anchor: Vector2i = Vector2i(4, int(state.height / 2) - 2)

	for b in keep_player_shape:
		var rel_x: int = int(b["pos"][0]) - min_x
		var rel_y: int = int(b["pos"][1]) - min_y
		var pos: Vector2i = Vector2i(anchor.x + rel_x, anchor.y + rel_y)
		if not state.is_empty_ground(pos) or pos == state.door_tile:
			pos = _find_open_near(state, Vector2i(4, state.height / 2))

		var tile_type: String = String(b.get("tile_type", "basic"))
		if not Combat.TILE_RULES.has(tile_type):
			tile_type = "basic"

		var hp: int = int(b.get("max_hp", int(Combat.TILE_RULES[tile_type]["max_hp"])))
		var id: int = state.spawn_block(GameState.PLAYER_ID, pos, bool(b.get("core", false)), hp, tile_type)
		var fresh: Dictionary = state.blocks[id]
		fresh["tile_type"] = tile_type
		fresh["defense"] = int(Combat.TILE_RULES[tile_type]["defense"])
		fresh["damage"] = int(Combat.TILE_RULES[tile_type]["damage"])
		fresh["range"] = int(Combat.TILE_RULES[tile_type]["range"])
		fresh["gather_bonus"] = int(b.get("gather_bonus", 0))
		fresh["age"] = int(b.get("age", 2))
		state.blocks[id] = fresh

func _spawn_cluster(state: GameState, owner_id: int, seed: Vector2i, size: int, rng: RandomNumberGenerator) -> void:
	var origin: Vector2i = seed
	if not state.is_empty_ground(origin) or origin == state.door_tile:
		origin = _find_open_near(state, seed)

	var first_id: int = state.spawn_block(owner_id, origin, true, int(Combat.TILE_RULES["basic"]["max_hp"]), "basic")
	var first: Dictionary = state.blocks[first_id]
	first["defense"] = int(Combat.TILE_RULES["basic"]["defense"])
	first["damage"] = 0
	first["range"] = 1
	first["age"] = 2
	state.blocks[first_id] = first

	var placed: Dictionary = {_tile_key(origin): true}
	var frontier: Array = [origin]

	while placed.size() < size and not frontier.is_empty():
		var from: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
		var options: Array = []
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var t: Vector2i = from + step
			if not state.is_empty_ground(t):
				continue
			if t == state.door_tile:
				continue
			if placed.has(_tile_key(t)):
				continue
			options.append(t)

		if options.is_empty():
			frontier.erase(from)
			continue

		var preferred: Array = []
		var best_adjacent: int = -1
		for option in options:
			var adjacent_count: int = _adjacent_count_to_placed(option, placed)
			if adjacent_count > best_adjacent:
				best_adjacent = adjacent_count
				preferred = [option]
			elif adjacent_count == best_adjacent:
				preferred.append(option)

		var target: Vector2i = preferred[rng.randi_range(0, preferred.size() - 1)]
		var id: int = state.spawn_block(owner_id, target, false, int(Combat.TILE_RULES["basic"]["max_hp"]), "basic")
		var block: Dictionary = state.blocks[id]
		block["defense"] = int(Combat.TILE_RULES["basic"]["defense"])
		block["damage"] = 0
		block["range"] = 1
		block["age"] = 2
		state.blocks[id] = block
		placed[_tile_key(target)] = true
		frontier.append(target)

func _find_open_near(state: GameState, center: Vector2i) -> Vector2i:
	for radius in range(0, 14):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var p: Vector2i = Vector2i(x, y)
				if state.is_empty_ground(p) and p != state.door_tile:
					return p
	return Vector2i(1, 1)

func _fallback_template() -> Dictionary:
	return {
		"id": "fallback",
		"width": 30,
		"height": 18,
		"player_seed": [4, 9],
		"door": [27, 9],
		"walls": [],
		"resource_nodes": [[10, 4, "gem"], [14, 12, "rat"], [20, 7, "gem"]],
		"enemies": [{"owner": 2, "seed": [24, 8]}],
	}

func _adjacent_count_to_placed(tile: Vector2i, placed: Dictionary) -> int:
	var count: int = 0
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if placed.has(_tile_key(tile + step)):
			count += 1
	return count

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
