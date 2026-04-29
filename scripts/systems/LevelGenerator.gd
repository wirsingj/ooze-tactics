extends RefCounted
class_name LevelGenerator

# Builds neutral cave maps with small starting blobs for each faction.
const HEART_RATIO: float = 0.4
const HEART_MAX_PER_CLUSTER: int = 3
const DEFAULT_PLAYER_ENERGY: int = 9
const DEFAULT_ENEMY_ENERGY: int = 8
const DEFAULT_DOOR_HP: int = 30
const LEVEL_LAYOUT_GENERATOR_SCRIPT: Script = preload("res://scripts/systems/LevelLayoutGenerator.gd")

var _layout_generator: RefCounted = LEVEL_LAYOUT_GENERATOR_SCRIPT.new()

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

	var layout: Dictionary = _layout_generator.build_layout(level_index, run_seed, room_templates, options)
	var room: Dictionary = _room_from_layout(layout)
	state.level_layout = layout.duplicate(true)
	state.width = int(room.get("width", 30))
	state.height = int(room.get("height", 18))
	var half_height: int = int(round(float(state.height) * 0.5))

	var entrance_raw: Array = room.get("entrance", [])
	if entrance_raw.size() >= 2:
		state.entrance_tile = Vector2i(int(entrance_raw[0]), int(entrance_raw[1]))
	else:
		var player_seed_raw_default: Array = room.get("player_seed", [4, half_height])
		state.entrance_tile = Vector2i(1, int(player_seed_raw_default[1]))
	state.entrance_tile.x = clampi(state.entrance_tile.x, 0, state.width - 1)
	state.entrance_tile.y = clampi(state.entrance_tile.y, 0, state.height - 1)

	var door_raw: Array = room.get("door", [state.width - 2, half_height])
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
	state.players[GameState.PLAYER_ID]["income_delta"] = int(options.get("player_income_delta", 0))
	state.players[GameState.PLAYER_ID]["max_actions"] = int(options.get("player_max_actions", 3))
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
		state.players[enemy_id]["income_delta"] = int(options.get("enemy_income_delta", 0))
		state.players[enemy_id]["max_actions"] = int(options.get("enemy_max_actions", 3))

	var ally_spawns: Array = _build_ally_spawns(room, state, ally_ai_count)
	for ally in ally_spawns:
		var ally_id: int = int(ally.get("owner", 50))
		if not state.players.has(ally_id):
			state.add_owner(ally_id, "Ally %d" % ally_id, ally_start_energy, GameState.TEAM_PLAYER, true)
		else:
			state.players[ally_id]["nutrients"] = ally_start_energy
			state.players[ally_id]["team"] = GameState.TEAM_PLAYER
			state.players[ally_id]["ai_controlled"] = true
		state.players[ally_id]["income_delta"] = int(options.get("ally_income_delta", options.get("player_income_delta", 0)))
		state.players[ally_id]["max_actions"] = int(options.get("ally_max_actions", options.get("player_max_actions", 3)))

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
				"upgrade_reward": kind == "adventurer",
				"upgrade_claimed": false,
			})

	if keep_player_shape.is_empty():
		var player_seeds: Array = _build_player_seeds(room, state, player_clusters + ally_ai_count)
		for i in range(player_seeds.size()):
			var spawn_seed: Vector2i = player_seeds[i]
			var owner_id: int = GameState.PLAYER_ID
			var cluster_size: int = rng.randi_range(
				int(options.get("player_cluster_size_min", 3)),
				int(options.get("player_cluster_size_max", 6))
			)
			var heart_max: int = int(options.get("player_heart_max", HEART_MAX_PER_CLUSTER))
			if i >= player_clusters and i - player_clusters < ally_spawns.size():
				owner_id = int(ally_spawns[i - player_clusters].get("owner", 50))
				cluster_size = rng.randi_range(
					int(options.get("ally_cluster_size_min", options.get("player_cluster_size_min", 3))),
					int(options.get("ally_cluster_size_max", options.get("player_cluster_size_max", 5)))
				)
				heart_max = int(options.get("ally_heart_max", options.get("player_heart_max", HEART_MAX_PER_CLUSTER)))
			_spawn_cluster(state, owner_id, spawn_seed, cluster_size, rng, heart_max)
	else:
		_spawn_carried_shape(state, keep_player_shape)
		for ally in ally_spawns:
			var ally_seed_raw: Array = ally.get("seed", [4, half_height])
			var ally_seed: Vector2i = Vector2i(int(ally_seed_raw[0]), int(ally_seed_raw[1]))
			var ally_owner_id: int = int(ally.get("owner", 50))
			_spawn_cluster(
				state,
				ally_owner_id,
				ally_seed,
				rng.randi_range(
					int(options.get("ally_cluster_size_min", 3)),
					int(options.get("ally_cluster_size_max", 5))
				),
				rng,
				int(options.get("ally_heart_max", HEART_MAX_PER_CLUSTER))
			)
		if player_clusters > 1:
			var carry_seeds: Array = _build_player_seeds(room, state, player_clusters)
			for i in range(1, carry_seeds.size()):
				var extra_seed: Vector2i = carry_seeds[i]
				_spawn_cluster(
					state,
					GameState.PLAYER_ID,
					extra_seed,
					rng.randi_range(
						int(options.get("player_cluster_size_min", 3)),
						int(options.get("player_cluster_size_max", 5))
					),
					rng,
					int(options.get("player_heart_max", HEART_MAX_PER_CLUSTER))
				)

	for enemy in enemy_spawns:
		var seed_raw: Array = enemy.get("seed", [state.width - 5, half_height])
		var enemy_seed: Vector2i = Vector2i(int(seed_raw[0]), int(seed_raw[1]))
		var enemy_owner: int = int(enemy.get("owner", 2))
		_spawn_cluster(
			state,
			enemy_owner,
			enemy_seed,
			rng.randi_range(
				int(options.get("enemy_cluster_size_min", 3)),
				int(options.get("enemy_cluster_size_max", 6))
			),
			rng,
			int(options.get("enemy_heart_max", HEART_MAX_PER_CLUSTER))
		)

	if bool(options.get("miniboss", false)):
		_apply_miniboss_modifiers(state, int(options.get("boss_core_hp_bonus", 16)))

	return state

func _room_from_layout(layout: Dictionary) -> Dictionary:
	var board_size: Array = layout.get("board_size", [30, 18])
	var width: int = 30
	var height: int = 18
	if board_size.size() >= 2:
		width = int(board_size[0])
		height = int(board_size[1])
	var spawn_positions: Dictionary = layout.get("spawn_positions", {})
	var objectives: Dictionary = layout.get("objective_positions", {})
	var half_height: int = int(round(float(height) * 0.5))
	var enemies: Array = []
	var enemy_hints: Array = spawn_positions.get("enemy_seed_hints", [])
	for hint_raw in enemy_hints:
		if typeof(hint_raw) != TYPE_ARRAY:
			continue
		var hint: Array = hint_raw
		if hint.size() < 2:
			continue
		enemies.append({
			"owner": 2 + enemies.size(),
			"seed": [int(hint[0]), int(hint[1])],
		})
	return {
		"id": String(layout.get("layout_id", "layout_runtime")),
		"width": width,
		"height": height,
		"player_seed": _array2(spawn_positions.get("player_seed", [4, half_height]), 4, half_height),
		"entrance": _array2(objectives.get("entrance", [1, half_height]), 1, half_height),
		"door": _array2(objectives.get("door", [width - 2, half_height]), width - 2, half_height),
		"walls": layout.get("inner_walls", []),
		"resource_nodes": layout.get("resource_nodes", []),
		"enemies": enemies,
	}

func _array2(value: Variant, fallback_x: int, fallback_y: int) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return [fallback_x, fallback_y]
	var arr: Array = value
	if arr.size() < 2:
		return [fallback_x, fallback_y]
	return [int(arr[0]), int(arr[1])]

func _build_player_seeds(room: Dictionary, state: GameState, count: int) -> Array:
	var seeds: Array = []
	if count <= 0:
		return seeds
	var half_height: int = int(round(float(state.height) * 0.5))
	var base_raw: Array = room.get("player_seed", [4, half_height])
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

	var half_height: int = int(round(float(state.height) * 0.5))
	var player_seed_raw: Array = room.get("player_seed", [4, half_height])
	var base: Vector2i = Vector2i(int(player_seed_raw[0]), int(player_seed_raw[1]))
	var offsets: Array[Vector2i] = [Vector2i(0, 4), Vector2i(0, -4), Vector2i(3, 2), Vector2i(3, -2)]

	for i in range(ally_count):
		var owner: int = 50 + i
		var ally_seed: Vector2i
		if i < offsets.size():
			ally_seed = base + offsets[i]
		else:
			ally_seed = Vector2i(clampi(base.x + 2 + i, 1, state.width - 2), clampi(base.y + i, 1, state.height - 2))
		ally_seed.x = clampi(ally_seed.x, 1, state.width - 2)
		ally_seed.y = clampi(ally_seed.y, 1, state.height - 2)
		if ally_seed == state.door_tile or ally_seed == state.entrance_tile:
			ally_seed = Vector2i(clampi(ally_seed.x - 2, 1, state.width - 2), ally_seed.y)
		out.append({
			"owner": owner,
			"seed": [ally_seed.x, ally_seed.y],
			"team": GameState.TEAM_PLAYER,
		})

	return out

func _build_enemy_spawns(room: Dictionary, state: GameState, enemy_count: int, enemies_allied: bool) -> Array:
	var room_enemies: Array = room.get("enemies", [])
	var out: Array = []
	var half_height: int = int(round(float(state.height) * 0.5))

	for i in range(enemy_count):
		var owner: int = 2 + i
		var team: int = GameState.TEAM_ENEMY if enemies_allied else (GameState.TEAM_ENEMY + i)
		var enemy_seed: Vector2i = Vector2i(state.width - 5, half_height)
		if i < room_enemies.size() and room_enemies[i] is Dictionary:
			var room_enemy: Dictionary = room_enemies[i]
			var seed_raw: Array = room_enemy.get("seed", [enemy_seed.x, enemy_seed.y])
			enemy_seed = Vector2i(int(seed_raw[0]), int(seed_raw[1]))
		else:
			var lane_y: int = int(round(((float(i) + 1.0) / (float(enemy_count) + 1.0)) * float(state.height - 1)))
			lane_y = clampi(lane_y, 1, state.height - 2)
			var lane_x: int = clampi(state.width - 5 - (i % 2), 1, state.width - 2)
			enemy_seed = Vector2i(lane_x, lane_y)
		if enemy_seed == state.door_tile or enemy_seed == state.entrance_tile:
			enemy_seed = Vector2i(clampi(enemy_seed.x - 2, 1, state.width - 2), enemy_seed.y)
		out.append({
			"owner": owner,
			"seed": [enemy_seed.x, enemy_seed.y],
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
	var half_height: int = int(round(float(state.height) * 0.5))
	var anchor: Vector2i = Vector2i(4, half_height - 2)

	for b in keep_player_shape:
		var rel_x: int = int(b["pos"][0]) - min_x
		var rel_y: int = int(b["pos"][1]) - min_y
		var pos: Vector2i = Vector2i(anchor.x + rel_x, anchor.y + rel_y)
		if not state.is_empty_ground(pos) or pos == state.door_tile or pos == state.entrance_tile:
			pos = _find_open_near(state, Vector2i(4, half_height))

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

func _spawn_cluster(
	state: GameState,
	owner_id: int,
	spawn_seed: Vector2i,
	size: int,
	rng: RandomNumberGenerator,
	heart_max: int = HEART_MAX_PER_CLUSTER
) -> void:
	var origin: Vector2i = spawn_seed
	if not state.is_empty_ground(origin) or origin == state.door_tile or origin == state.entrance_tile:
		origin = _find_open_near(state, spawn_seed)

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

	_mark_cluster_hearts(state, cluster_ids, heart_max)

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

func _mark_cluster_hearts(state: GameState, cluster_ids: Array[int], heart_max: int = HEART_MAX_PER_CLUSTER) -> void:
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
	desired_hearts = maxi(1, mini(maxi(1, heart_max), desired_hearts))

	for i in range(mini(desired_hearts, sorted_ids.size())):
		var block_id: int = int(sorted_ids[i])
		if not state.blocks.has(block_id):
			continue
		var block: Dictionary = state.blocks[block_id]
		block["is_heart"] = true
		block["max_hp"] = int(block.get("max_hp", Combat.TILE_RULES["basic"]["max_hp"])) + GameState.HEART_TILE_HP_BONUS
		block["hp"] = int(block.get("hp", block["max_hp"])) + GameState.HEART_TILE_HP_BONUS
		state.blocks[block_id] = block

func _apply_miniboss_modifiers(state: GameState, core_hp_bonus: int) -> void:
	var boss_owner: int = 2
	if not state.players.has(boss_owner):
		return
	state.players[boss_owner]["name"] = "Sealed Heart"
	state.players[boss_owner]["nutrients"] = int(state.players[boss_owner].get("nutrients", 0)) + 4

	var boss_blocks: Array = state.get_owner_blocks(boss_owner)
	if boss_blocks.is_empty():
		return

	var heart_ids: Array[int] = []
	var boss_center: Vector2i = boss_blocks[0].get("pos", Vector2i(state.width - 5, int(round(float(state.height) * 0.5))))
	for block in boss_blocks:
		if bool(block.get("is_heart", false)):
			var block_id: int = int(block.get("id", -1))
			heart_ids.append(block_id)
			if bool(block.get("core", false)):
				boss_center = block.get("pos", boss_center)

	for block_id in heart_ids:
		if not state.blocks.has(block_id):
			continue
		var heart: Dictionary = state.blocks[block_id]
		heart["max_hp"] = int(heart.get("max_hp", 0)) + core_hp_bonus
		heart["hp"] = int(heart.get("hp", 0)) + core_hp_bonus
		state.blocks[block_id] = heart

	var support_ids: Array[int] = []
	for block in boss_blocks:
		if bool(block.get("is_heart", false)):
			continue
		support_ids.append(int(block.get("id", -1)))
	support_ids.sort_custom(func(a: int, b: int) -> bool:
		if not state.blocks.has(a) or not state.blocks.has(b):
			return a < b
		var pa: Vector2i = state.blocks[a].get("pos", boss_center)
		var pb: Vector2i = state.blocks[b].get("pos", boss_center)
		var da: int = absi(pa.x - boss_center.x) + absi(pa.y - boss_center.y)
		var db: int = absi(pb.x - boss_center.x) + absi(pb.y - boss_center.y)
		if da != db:
			return da < db
		return a < b
	)

	var boss_roles: Array[String] = ["defense", "ranged", "melee", "defense"]
	for i in range(mini(support_ids.size(), boss_roles.size())):
		var block_id: int = support_ids[i]
		if not state.blocks.has(block_id):
			continue
		_apply_tile_role_stats(state, block_id, boss_roles[i])

func _apply_tile_role_stats(state: GameState, block_id: int, tile_type: String) -> void:
	if not state.blocks.has(block_id):
		return
	if not Combat.TILE_RULES.has(tile_type):
		return
	var rules: Dictionary = Combat.TILE_RULES[tile_type]
	var block: Dictionary = state.blocks[block_id]
	block["tile_type"] = tile_type
	block["max_hp"] = int(rules.get("max_hp", block.get("max_hp", 8)))
	block["hp"] = int(block["max_hp"])
	block["defense"] = int(rules.get("defense", 0))
	block["damage"] = int(rules.get("damage", 0))
	block["range"] = int(rules.get("range", 1))
	block["upgrade_tier"] = Combat.SPECIALIZATION_TIER
	state.blocks[block_id] = block

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
