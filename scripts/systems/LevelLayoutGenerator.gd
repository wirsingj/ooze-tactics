extends RefCounted
class_name LevelLayoutGenerator

const MAP_TYPE_LEVEL_1: String = "level_1_duel"
const MAP_TYPE_LEVEL_2: String = "level_2_chokepoints"
const MAP_TYPE_LEVEL_3: String = "level_3_multi_front"
const MAP_TYPE_LEVEL_4: String = "level_4_pressure"
const MAP_TYPE_LEVEL_5: String = "level_5_miniboss"

func build_layout(level_index: int, run_seed: int, room_templates: Array, options: Dictionary = {}) -> Dictionary:
	var map_type: String = _map_type_for_level(level_index)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed + level_index * 4099
	var template: Dictionary = {}
	if bool(options.get("use_curated_vertical_slice", false)):
		template = _fallback_template_for_map_type(map_type)
	else:
		template = _select_template_for_map_type(room_templates, map_type, rng)
	if template.is_empty():
		template = _fallback_template_for_map_type(map_type)
	var normalized: Dictionary = _normalize_template_layout(template, map_type, level_index, options)
	return normalized

func _map_type_for_level(level_index: int) -> String:
	if level_index <= 1:
		return MAP_TYPE_LEVEL_1
	if level_index == 2:
		return MAP_TYPE_LEVEL_2
	if level_index == 3:
		return MAP_TYPE_LEVEL_3
	if level_index == 4:
		return MAP_TYPE_LEVEL_4
	return MAP_TYPE_LEVEL_5

func _select_template_for_map_type(room_templates: Array, map_type: String, rng: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = []
	var fallbacks: Array = []
	for entry in room_templates:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = entry
		var wall_count: int = int(room.get("walls", []).size())
		var enemy_count: int = int(room.get("enemies", []).size())
		fallbacks.append(room)
		match map_type:
			MAP_TYPE_LEVEL_1:
				if enemy_count <= 1 and wall_count <= 16:
					candidates.append(room)
			MAP_TYPE_LEVEL_2:
				if enemy_count >= 2 and wall_count >= 14 and wall_count <= 24:
					candidates.append(room)
			MAP_TYPE_LEVEL_3:
				if enemy_count >= 2 and wall_count >= 18:
					candidates.append(room)
			MAP_TYPE_LEVEL_4:
				if enemy_count >= 2 and wall_count >= 18:
					candidates.append(room)
			_:
				if wall_count >= 18:
					candidates.append(room)
	if candidates.is_empty():
		candidates = fallbacks
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)

func _normalize_template_layout(template: Dictionary, map_type: String, level_index: int, options: Dictionary) -> Dictionary:
	var width: int = maxi(14, int(template.get("width", 30)))
	var height: int = maxi(10, int(template.get("height", 18)))
	var half_height: int = int(round(float(height) * 0.5))
	var player_seed: Vector2i = _clamp_tile(_to_vec2i(template.get("player_seed", [4, half_height]), Vector2i(4, half_height)), width, height)
	var entrance: Vector2i = _clamp_tile(_to_vec2i(template.get("entrance", [1, player_seed.y]), Vector2i(1, player_seed.y)), width, height)
	var door: Vector2i = _clamp_tile(_to_vec2i(template.get("door", [width - 2, half_height]), Vector2i(width - 2, half_height)), width, height)
	if entrance == door:
		entrance = Vector2i(1, clampi(door.y + 1, 1, height - 2))

	var walls: Array = _normalize_wall_tiles(template.get("walls", []), width, height, entrance, door)
	var resource_nodes: Array = _normalize_resource_nodes(template.get("resource_nodes", []), width, height, walls, entrance, door)
	var enemy_hint_count: int = maxi(1, int(options.get("enemy_cluster_count", int(template.get("enemies", []).size()))))
	var ally_hint_count: int = maxi(0, int(options.get("ally_ai_count", 0)))
	var enemy_hints: Array = _normalize_enemy_hints(template.get("enemies", []), width, height, enemy_hint_count, entrance, door, walls)
	var ally_hints: Array = _build_ally_seed_hints(player_seed, width, height, ally_hint_count, walls, entrance, door)

	return {
		"layout_id": String(template.get("id", "generated_%s_l%d" % [map_type, level_index])),
		"map_type": map_type,
		"board_size": [width, height],
		"outer_bounds": {"min": [0, 0], "max": [width - 1, height - 1]},
		"inner_walls": walls,
		"spawn_positions": {
			"player_seed": [player_seed.x, player_seed.y],
			"ally_seed_hints": ally_hints,
			"enemy_seed_hints": enemy_hints,
		},
		"objective_positions": {
			"entrance": [entrance.x, entrance.y],
			"door": [door.x, door.y],
		},
		"resource_nodes": resource_nodes,
	}

func _normalize_wall_tiles(walls_raw: Array, width: int, height: int, entrance: Vector2i, door: Vector2i) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for wall_raw in walls_raw:
		if typeof(wall_raw) != TYPE_ARRAY:
			continue
		var wall_arr: Array = wall_raw
		if wall_arr.size() < 2:
			continue
		var tile: Vector2i = _clamp_tile(Vector2i(int(wall_arr[0]), int(wall_arr[1])), width, height)
		if tile == entrance or tile == door:
			continue
		var key: String = _tile_key(tile)
		if seen.has(key):
			continue
		seen[key] = true
		out.append([tile.x, tile.y])
	return out

func _normalize_resource_nodes(nodes_raw: Array, width: int, height: int, walls: Array, entrance: Vector2i, door: Vector2i) -> Array:
	var out: Array = []
	var wall_set: Dictionary = {}
	for wall_raw in walls:
		if typeof(wall_raw) != TYPE_ARRAY:
			continue
		var wall_arr: Array = wall_raw
		if wall_arr.size() < 2:
			continue
		wall_set[_tile_key(Vector2i(int(wall_arr[0]), int(wall_arr[1])))] = true
	for node_raw in nodes_raw:
		if typeof(node_raw) != TYPE_ARRAY:
			continue
		var node_arr: Array = node_raw
		if node_arr.size() < 2:
			continue
		var tile: Vector2i = _clamp_tile(Vector2i(int(node_arr[0]), int(node_arr[1])), width, height)
		if tile == entrance or tile == door:
			continue
		if wall_set.has(_tile_key(tile)):
			continue
		var kind: String = "gem"
		if node_arr.size() >= 3:
			kind = String(node_arr[2])
		out.append([tile.x, tile.y, kind])
	return out

func _normalize_enemy_hints(
	enemies_raw: Array,
	width: int,
	height: int,
	target_count: int,
	entrance: Vector2i,
	door: Vector2i,
	walls: Array
) -> Array:
	var wall_set: Dictionary = {}
	for wall_raw in walls:
		if typeof(wall_raw) != TYPE_ARRAY:
			continue
		var wall_arr: Array = wall_raw
		if wall_arr.size() < 2:
			continue
		wall_set[_tile_key(Vector2i(int(wall_arr[0]), int(wall_arr[1])))] = true

	var hints: Array = []
	for enemy_raw in enemies_raw:
		if typeof(enemy_raw) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_raw
		var half_height: int = int(round(float(height) * 0.5))
		var spawn_seed: Vector2i = _clamp_tile(_to_vec2i(enemy.get("seed", [width - 5, half_height]), Vector2i(width - 5, half_height)), width, height)
		if not _is_open_tile(spawn_seed, wall_set, entrance, door):
			spawn_seed = _fallback_open_tile(Vector2i(width - 5, spawn_seed.y), width, height, wall_set, entrance, door)
		hints.append([spawn_seed.x, spawn_seed.y])
		if hints.size() >= target_count:
			return hints

	while hints.size() < target_count:
		var lane_index: int = hints.size()
		var lane_y: int = int(round(((float(lane_index) + 1.0) / (float(target_count) + 1.0)) * float(height - 1)))
		lane_y = clampi(lane_y, 1, height - 2)
		var candidate: Vector2i = Vector2i(clampi(width - 5 - (lane_index % 2), 1, width - 2), lane_y)
		if not _is_open_tile(candidate, wall_set, entrance, door):
			candidate = _fallback_open_tile(candidate, width, height, wall_set, entrance, door)
		hints.append([candidate.x, candidate.y])
	return hints

func _build_ally_seed_hints(
	player_seed: Vector2i,
	width: int,
	height: int,
	count: int,
	wall_tiles: Array,
	entrance: Vector2i,
	door: Vector2i
) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var wall_set: Dictionary = {}
	for wall_raw in wall_tiles:
		if typeof(wall_raw) != TYPE_ARRAY:
			continue
		var wall_arr: Array = wall_raw
		if wall_arr.size() < 2:
			continue
		wall_set[_tile_key(Vector2i(int(wall_arr[0]), int(wall_arr[1])))] = true
	var offsets: Array[Vector2i] = [Vector2i(0, 4), Vector2i(0, -4), Vector2i(3, 2), Vector2i(3, -2)]
	for i in range(count):
		var candidate: Vector2i = player_seed
		if i < offsets.size():
			candidate = player_seed + offsets[i]
		else:
			candidate = Vector2i(player_seed.x + 2 + i, player_seed.y + (i % 3) - 1)
		candidate = _clamp_tile(candidate, width, height)
		if not _is_open_tile(candidate, wall_set, entrance, door):
			candidate = _fallback_open_tile(candidate, width, height, wall_set, entrance, door)
		out.append([candidate.x, candidate.y])
	return out

func _is_open_tile(tile: Vector2i, wall_set: Dictionary, entrance: Vector2i, door: Vector2i) -> bool:
	if wall_set.has(_tile_key(tile)):
		return false
	if tile == entrance or tile == door:
		return false
	return true

func _fallback_open_tile(
	start: Vector2i,
	width: int,
	height: int,
	wall_set: Dictionary,
	entrance: Vector2i,
	door: Vector2i
) -> Vector2i:
	for radius in range(0, 14):
		for y in range(start.y - radius, start.y + radius + 1):
			for x in range(start.x - radius, start.x + radius + 1):
				var tile: Vector2i = _clamp_tile(Vector2i(x, y), width, height)
				if _is_open_tile(tile, wall_set, entrance, door):
					return tile
	return _clamp_tile(start, width, height)

func _to_vec2i(raw: Variant, fallback: Vector2i) -> Vector2i:
	if typeof(raw) != TYPE_ARRAY:
		return fallback
	var arr: Array = raw
	if arr.size() < 2:
		return fallback
	return Vector2i(int(arr[0]), int(arr[1]))

func _clamp_tile(tile: Vector2i, width: int, height: int) -> Vector2i:
	return Vector2i(clampi(tile.x, 0, width - 1), clampi(tile.y, 0, height - 1))

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _fallback_template_for_map_type(map_type: String) -> Dictionary:
	match map_type:
		MAP_TYPE_LEVEL_1:
			return {
				"id": "layout_fallback_level_1",
				"width": 16,
				"height": 12,
				"player_seed": [3, 6],
				"entrance": [1, 6],
				"door": [14, 6],
				"walls": [[8, 3], [8, 4], [8, 8], [8, 9]],
				"resource_nodes": [[6, 4, "gem"], [9, 6, "rat"]],
				"enemies": [{"owner": 2, "seed": [10, 6]}],
			}
		MAP_TYPE_LEVEL_2:
			return {
				"id": "layout_fallback_level_2",
				"width": 22,
				"height": 14,
				"player_seed": [3, 7],
				"entrance": [1, 7],
				"door": [20, 7],
				"walls": [[8, 3], [8, 4], [8, 5], [8, 9], [8, 10], [8, 11], [13, 4], [14, 4], [13, 10], [14, 10]],
				"resource_nodes": [[6, 3, "gem"], [10, 7, "rat"], [15, 11, "gem"]],
				"enemies": [{"owner": 2, "seed": [15, 5]}, {"owner": 3, "seed": [15, 9]}],
			}
		MAP_TYPE_LEVEL_3:
			return {
				"id": "layout_fallback_level_3",
				"width": 26,
				"height": 16,
				"player_seed": [3, 8],
				"entrance": [1, 8],
				"door": [24, 8],
				"walls": [[7, 3], [7, 4], [7, 11], [7, 12], [13, 2], [14, 2], [13, 8], [14, 8], [13, 13], [14, 13], [19, 5], [19, 10]],
				"resource_nodes": [[6, 12, "rat"], [10, 7, "gem"], [17, 4, "gem"], [19, 11, "rat"]],
				"enemies": [{"owner": 2, "seed": [18, 4]}, {"owner": 3, "seed": [18, 8]}, {"owner": 4, "seed": [18, 12]}],
			}
		MAP_TYPE_LEVEL_4:
			return {
				"id": "layout_fallback_level_4_pressure",
				"width": 26,
				"height": 16,
				"player_seed": [3, 8],
				"entrance": [1, 8],
				"door": [24, 8],
				"walls": [
					[7, 2], [7, 3], [7, 4], [7, 11], [7, 12], [7, 13],
					[12, 5], [13, 5], [15, 5], [16, 5],
					[12, 10], [13, 10], [15, 10], [16, 10],
					[20, 6], [20, 7], [20, 9], [20, 10]
				],
				"resource_nodes": [[6, 3, "gem"], [10, 8, "rat"], [13, 8, "adventurer"], [19, 12, "gem"]],
				"enemies": [{"owner": 2, "seed": [21, 4]}, {"owner": 3, "seed": [21, 8]}, {"owner": 4, "seed": [21, 12]}],
			}
		_:
			return {
				"id": "layout_fallback_level_5_miniboss",
				"width": 24,
				"height": 16,
				"player_seed": [3, 8],
				"entrance": [1, 8],
				"door": [22, 8],
				"walls": [
					[7, 3], [7, 4], [7, 11], [7, 12],
					[12, 3], [13, 3], [12, 12], [13, 12],
					[15, 6], [15, 9],
					[18, 5], [18, 6], [18, 10], [18, 11]
				],
				"resource_nodes": [[6, 12, "gem"], [10, 8, "rat"], [14, 6, "gem"]],
				"enemies": [{"owner": 2, "seed": [16, 8]}],
			}
