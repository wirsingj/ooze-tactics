extends RefCounted
class_name LevelGenerator

# Builds neutral cave maps with small starting blobs for each faction.
const HEART_RATIO: float = 0.4
const HEART_MAX_PER_CLUSTER: int = 3
const DEFAULT_PLAYER_ENERGY: int = 9
const DEFAULT_ENEMY_ENERGY: int = 8
const DEFAULT_DOOR_HP: int = 30

func build_level(
	level_index: int,
	run_seed: int,
	room_templates: Array,
	keep_player_shape: Array,
	options: Dictionary = {}
) -> GameState:
	# keep_player_shape is a dormant hook for future between-level carryover.
	# Current runtime flow always passes [] and uses fresh per-level spawns.
	var state: GameState = GameState.new()
	state.level_index = level_index
	state.run_seed = run_seed
	state.turn_index = 0
	state.turn_limit = int(options.get("turn_limit", 50))
	state.enemies_allied = bool(options.get("enemies_allied", true))
	state.dev_player_immortal = bool(options.get("dev_player_immortal", false))
	state.spectator_mode = bool(options.get("dev_spectator_mode", false))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed + level_index * 77

	if room_templates.is_empty():
		room_templates = [_fallback_template()]

	var room: Dictionary = room_templates[rng.randi_range(0, room_templates.size() - 1)]
	state.width = int(room.get("width", 30))
	state.height = int(room.get("height", 18))

	var entrance_raw: Array = room.get("entrance", [])
	if entrance_raw.size() >= 2:
		state.entrance_tile = Vector2i(int(entrance_raw[0]), int(entrance_raw[1]))
	else:
		var player_seed_raw_default: Array = room.get("player_seed", [4, state.height / 2])
		state.entrance_tile = Vector2i(1, int(player_seed_raw_default[1]))
	state.entrance_tile.x = clampi(state.entrance_tile.x, 0, state.width - 1)
	state.entrance_tile.y = clampi(state.entrance_tile.y, 0, state.height - 1)

	var door_raw: Array = room.get("door", [state.width - 2, state.height / 2])
	state.door_tile = Vector2i(int(door_raw[0]), int(door_raw[1]))
	state.door_tile.x = clampi(state.door_tile.x, 0, state.width - 1)
	state.door_tile.y = clampi(state.door_tile.y, 0, state.height - 1)
	if state.entrance_tile == state.door_tile:
		state.entrance_tile = Vector2i(1, clampi(state.door_tile.y + 1, 1, state.height - 2))
	state.door_max_hp = int(options.get("door_hp", DEFAULT_DOOR_HP))
	state.door_hp = state.door_max_hp
	state.set_walls(room.get("walls", []))
	state.players[GameState.PLAYER_ID]["team"] = GameState.TEAM_PLAYER
	state.players[GameState.PLAYER_ID]["ai_controlled"] = false

	var player_clusters: int = maxi(0, int(options.get("player_cluster_count", 1)))
	if not state.spectator_mode:
		player_clusters = maxi(1, player_clusters)
	var ally_ai_count: int = maxi(0, int(options.get("ally_ai_count", 0)))
	var enemy_cluster_default: int = int(room.get("enemies", []).size())
	if enemy_cluster_default <= 0:
		enemy_cluster_default = 1
	var enemy_clusters: int = maxi(1, int(options.get("enemy_cluster_count", enemy_cluster_default)))

	var player_start_energy: int = int(options.get("player_start_energy", DEFAULT_PLAYER_ENERGY + level_index))
	var ally_start_energy: int = int(options.get("ally_start_energy", player_start_energy))
	var enemy_start_energy: int = int(options.get("enemy_start_energy", DEFAULT_ENEMY_ENERGY + level_index))
	state.players[GameState.PLAYER_ID]["nutrients"] = player_start_energy
	state.players[GameState.PLAYER_ID]["alive"] = player_clusters > 0
	if player_clusters <= 0:
		state.players[GameState.PLAYER_ID]["nutrients"] = 0

	var enemy_spawns: Array = _build_enemy_spawns(room, state, enemy_clusters, state.enemies_allied)
	for enemy in enemy_spawns:
		var enemy_id: int = int(enemy.get("owner", 2))
		if not state.players.has(enemy_id):
			state.add_owner(
				enemy_id,
				"Enemy %d" % enemy_id,
				enemy_start_energy,
				int(enemy.get("team", GameState.TEAM_ENEMY)),
				true
			)
		else:
			state.players[enemy_id]["nutrients"] = enemy_start_energy

	var ally_spawns: Array = _build_ally_spawns(room, state, ally_ai_count)
	for ally in ally_spawns:
		var ally_id: int = int(ally.get("owner", 50))
		if not state.players.has(ally_id):
			state.add_owner(ally_id, "Ally %d" % ally_id, ally_start_energy, GameState.TEAM_PLAYER, true)
		else:
			state.players[ally_id]["nutrients"] = ally_start_energy
			state.players[ally_id]["team"] = GameState.TEAM_PLAYER
			state.players[ally_id]["ai_controlled"] = true

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
		var player_seeds: Array = _build_player_seeds(room, state, player_clusters + ally_ai_count)
		for i in range(player_seeds.size()):
			var seed: Vector2i = player_seeds[i]
			var owner_id: int = GameState.PLAYER_ID
			if i >= player_clusters and i - player_clusters < ally_spawns.size():
				owner_id = int(ally_spawns[i - player_clusters].get("owner", 50))
			_spawn_cluster(state, owner_id, seed, rng.randi_range(3, 6), rng)
	else:
		_spawn_carried_shape(state, keep_player_shape)
		for ally in ally_spawns:
			var ally_seed_raw: Array = ally.get("seed", [4, state.height / 2])
			var ally_seed: Vector2i = Vector2i(int(ally_seed_raw[0]), int(ally_seed_raw[1]))
			var ally_owner_id: int = int(ally.get("owner", 50))
			_spawn_cluster(state, ally_owner_id, ally_seed, rng.randi_range(3, 5), rng)
		if player_clusters > 1:
			var carry_seeds: Array = _build_player_seeds(room, state, player_clusters)
			for i in range(1, carry_seeds.size()):
				var extra_seed: Vector2i = carry_seeds[i]
				_spawn_cluster(state, GameState.PLAYER_ID, extra_seed, rng.randi_range(3, 5), rng)

	for enemy in enemy_spawns:
		var seed_raw: Array = enemy.get("seed", [state.width - 5, state.height / 2])
		var seed: Vector2i = Vector2i(int(seed_raw[0]), int(seed_raw[1]))
		var enemy_owner: int = int(enemy.get("owner", 2))
		_spawn_cluster(state, enemy_owner, seed, rng.randi_range(3, 6), rng)

	return state

func _build_player_seeds(room: Dictionary, state: GameState, count: int) -> Array:
	var seeds: Array = []
	if count <= 0:
		return seeds
	var base_raw: Array = room.get("player_seed", [4, state.height / 2])
	var base: Vector2i = Vector2i(int(base_raw[0]), int(base_raw[1]))
	seeds.append(base)

	var offsets: Array[Vector2i] = [
		Vector2i(0, 4),
		Vector2i(0, -4),
		Vector2i(3, 2),
		Vector2i(3, -2),
		Vector2i(-2, 3),
		Vector2i(-2, -3),
	]

	while seeds.size() < count:
		var index: int = seeds.size() - 1
		var candidate: Vector2i
		if index < offsets.size():
			candidate = base + offsets[index]
		else:
			var y: int = clampi(base.y + (index * 2), 1, state.height - 2)
			candidate = Vector2i(clampi(base.x + 2 + (index % 3), 1, state.width - 2), y)

		candidate.x = clampi(candidate.x, 1, state.width - 2)
		candidate.y = clampi(candidate.y, 1, state.height - 2)
		if candidate == state.door_tile or candidate == state.entrance_tile:
			candidate = Vector2i(clampi(candidate.x - 2, 1, state.width - 2), candidate.y)
		seeds.append(candidate)

	return seeds

func _build_ally_spawns(room: Dictionary, state: GameState, ally_count: int) -> Array:
	var out: Array = []
	if ally_count <= 0:
		return out

	var player_seed_raw: Array = room.get("player_seed", [4, state.height / 2])
	var base: Vector2i = Vector2i(int(player_seed_raw[0]), int(player_seed_raw[1]))
	var offsets: Array[Vector2i] = [Vector2i(0, 4), Vector2i(0, -4), Vector2i(3, 2), Vector2i(3, -2)]

	for i in range(ally_count):
		var owner: int = 50 + i
		var seed: Vector2i
		if i < offsets.size():
			seed = base + offsets[i]
		else:
			seed = Vector2i(clampi(base.x + 2 + i, 1, state.width - 2), clampi(base.y + i, 1, state.height - 2))
		seed.x = clampi(seed.x, 1, state.width - 2)
		seed.y = clampi(seed.y, 1, state.height - 2)
		if seed == state.door_tile or seed == state.entrance_tile:
			seed = Vector2i(clampi(seed.x - 2, 1, state.width - 2), seed.y)
		out.append({
			"owner": owner,
			"seed": [seed.x, seed.y],
			"team": GameState.TEAM_PLAYER,
		})

	return out

func _build_enemy_spawns(room: Dictionary, state: GameState, enemy_count: int, enemies_allied: bool) -> Array:
	var room_enemies: Array = room.get("enemies", [])
	var out: Array = []

	for i in range(enemy_count):
		var owner: int = 2 + i
		var team: int = GameState.TEAM_ENEMY if enemies_allied else (GameState.TEAM_ENEMY + i)
		var seed: Vector2i = Vector2i(state.width - 5, int(state.height / 2))
		if i < room_enemies.size() and room_enemies[i] is Dictionary:
			var room_enemy: Dictionary = room_enemies[i]
			var seed_raw: Array = room_enemy.get("seed", [seed.x, seed.y])
			seed = Vector2i(int(seed_raw[0]), int(seed_raw[1]))
		else:
			var lane_y: int = int(round(((float(i) + 1.0) / (float(enemy_count) + 1.0)) * float(state.height - 1)))
			lane_y = clampi(lane_y, 1, state.height - 2)
			var lane_x: int = clampi(state.width - 5 - (i % 2), 1, state.width - 2)
			seed = Vector2i(lane_x, lane_y)
		if seed == state.door_tile or seed == state.entrance_tile:
			seed = Vector2i(clampi(seed.x - 2, 1, state.width - 2), seed.y)
		out.append({
			"owner": owner,
			"seed": [seed.x, seed.y],
			"team": team,
		})

	return out

func _spawn_carried_shape(state: GameState, keep_player_shape: Array) -> void:
	var min_x: int = 99999
	var min_y: int = 99999
	var carried_ids: Array[int] = []
	var any_heart: bool = false
	for b in keep_player_shape:
		min_x = mini(min_x, int(b["pos"][0]))
		min_y = mini(min_y, int(b["pos"][1]))
	var anchor: Vector2i = Vector2i(4, int(state.height / 2) - 2)

	for b in keep_player_shape:
		var rel_x: int = int(b["pos"][0]) - min_x
		var rel_y: int = int(b["pos"][1]) - min_y
		var pos: Vector2i = Vector2i(anchor.x + rel_x, anchor.y + rel_y)
		if not state.is_empty_ground(pos) or pos == state.door_tile or pos == state.entrance_tile:
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
		fresh["is_heart"] = bool(b.get("is_heart", false))
		if fresh["is_heart"]:
			any_heart = true
		state.blocks[id] = fresh
		carried_ids.append(id)

	if not any_heart:
		_mark_cluster_hearts(state, carried_ids)

func _spawn_cluster(state: GameState, owner_id: int, seed: Vector2i, size: int, rng: RandomNumberGenerator) -> void:
	var origin: Vector2i = seed
	if not state.is_empty_ground(origin) or origin == state.door_tile or origin == state.entrance_tile:
		origin = _find_open_near(state, seed)

	var first_id: int = state.spawn_block(owner_id, origin, true, int(Combat.TILE_RULES["basic"]["max_hp"]), "basic")
	var first: Dictionary = state.blocks[first_id]
	first["defense"] = int(Combat.TILE_RULES["basic"]["defense"])
	first["damage"] = 0
	first["range"] = 1
	first["age"] = 2
	state.blocks[first_id] = first
	var cluster_ids: Array[int] = [first_id]

	var placed: Dictionary = {_tile_key(origin): true}
	var frontier: Array = [origin]

	while placed.size() < size and not frontier.is_empty():
		var from: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
		var options: Array = []
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var t: Vector2i = from + step
			if not state.is_empty_ground(t):
				continue
			if t == state.door_tile or t == state.entrance_tile:
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
		cluster_ids.append(id)
		placed[_tile_key(target)] = true
		frontier.append(target)

	_mark_cluster_hearts(state, cluster_ids)

func _find_open_near(state: GameState, center: Vector2i) -> Vector2i:
	for radius in range(0, 14):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var p: Vector2i = Vector2i(x, y)
				if state.is_empty_ground(p) and p != state.door_tile and p != state.entrance_tile:
					return p
	return Vector2i(1, 1)

func _fallback_template() -> Dictionary:
	return {
		"id": "fallback",
		"width": 30,
		"height": 18,
		"player_seed": [4, 9],
		"entrance": [1, 9],
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

func _mark_cluster_hearts(state: GameState, cluster_ids: Array[int]) -> void:
	if cluster_ids.is_empty():
		return

	var center: Vector2 = Vector2.ZERO
	for block_id in cluster_ids:
		if not state.blocks.has(block_id):
			continue
		var p: Vector2i = state.blocks[block_id]["pos"]
		center += Vector2(p.x, p.y)
	center /= float(cluster_ids.size())

	var sorted_ids: Array = cluster_ids.duplicate()
	sorted_ids.sort_custom(func(a: int, b: int) -> bool:
		var a_core: bool = bool(state.blocks[a].get("core", false))
		var b_core: bool = bool(state.blocks[b].get("core", false))
		if a_core != b_core:
			return a_core
		var pa: Vector2i = state.blocks[a]["pos"]
		var pb: Vector2i = state.blocks[b]["pos"]
		var da: float = absf(float(pa.x) - center.x) + absf(float(pa.y) - center.y)
		var db: float = absf(float(pb.x) - center.x) + absf(float(pb.y) - center.y)
		if not is_equal_approx(da, db):
			return da < db
		return a < b
	)

	var desired_hearts: int = int(ceil(float(cluster_ids.size()) * HEART_RATIO))
	desired_hearts = maxi(1, mini(HEART_MAX_PER_CLUSTER, desired_hearts))

	for i in range(mini(desired_hearts, sorted_ids.size())):
		var block_id: int = int(sorted_ids[i])
		if not state.blocks.has(block_id):
			continue
		var block: Dictionary = state.blocks[block_id]
		block["is_heart"] = true
		block["max_hp"] = int(block.get("max_hp", Combat.TILE_RULES["basic"]["max_hp"])) + GameState.HEART_TILE_HP_BONUS
		block["hp"] = int(block.get("hp", block["max_hp"])) + GameState.HEART_TILE_HP_BONUS
		state.blocks[block_id] = block

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
