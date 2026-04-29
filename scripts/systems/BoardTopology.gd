extends RefCounted
class_name BoardTopology

const UNREACHABLE_DISTANCE: int = 99
const CARDINAL_STEPS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const MAX_CACHE_ENTRIES: int = 512

static var _distance_cache: Dictionary = {}
static var _distance_cache_order: Array[String] = []
static var _cache_hits: int = 0
static var _cache_misses: int = 0
static var _bfs_builds: int = 0

static func is_traversable(state: GameState, tile: Vector2i) -> bool:
	return state != null and state.is_inside(tile) and not state.is_blocked(tile)

static func distance_map_to_positions(state: GameState, targets: Array, max_distance: int = UNREACHABLE_DISTANCE) -> Dictionary:
	if state == null or targets.is_empty():
		return {}
	var cache_key: String = _distance_cache_key(state, targets, max_distance)
	if _distance_cache.has(cache_key):
		_cache_hits += 1
		return (_distance_cache[cache_key] as Dictionary).duplicate()
	_cache_misses += 1

	var distances: Dictionary = {}
	var queue: Array[Vector2i] = []
	var head: int = 0
	for target_variant in targets:
		var target: Vector2i = target_variant
		if not is_traversable(state, target):
			continue
		if distances.has(target):
			continue
		distances[target] = 0
		queue.append(target)

	while head < queue.size():
		var tile: Vector2i = queue[head]
		head += 1
		var dist: int = int(distances[tile])
		if dist >= max_distance:
			continue
		for step in CARDINAL_STEPS:
			var next_tile: Vector2i = tile + step
			if distances.has(next_tile):
				continue
			if not is_traversable(state, next_tile):
				continue
			distances[next_tile] = dist + 1
			queue.append(next_tile)

	_bfs_builds += 1
	_store_distance_cache(cache_key, distances)
	return distances.duplicate()

static func distance_to_nearest(state: GameState, tile: Vector2i, targets: Array, max_distance: int = UNREACHABLE_DISTANCE) -> int:
	if not is_traversable(state, tile):
		return UNREACHABLE_DISTANCE
	var distances: Dictionary = distance_map_to_positions(state, targets, max_distance)
	return int(distances.get(tile, UNREACHABLE_DISTANCE))

static func path_distance(state: GameState, start: Vector2i, target: Vector2i, max_distance: int = UNREACHABLE_DISTANCE) -> int:
	return distance_to_nearest(state, start, [target], max_distance)

static func is_reachable(state: GameState, start: Vector2i, target: Vector2i, max_distance: int = UNREACHABLE_DISTANCE) -> bool:
	return path_distance(state, start, target, max_distance) < UNREACHABLE_DISTANCE

static func cache_stats() -> Dictionary:
	return {
		"entries": _distance_cache.size(),
		"hits": _cache_hits,
		"misses": _cache_misses,
		"bfs_builds": _bfs_builds,
	}

static func reset_cache_stats() -> void:
	_cache_hits = 0
	_cache_misses = 0
	_bfs_builds = 0

static func clear_cache() -> void:
	_distance_cache.clear()
	_distance_cache_order.clear()
	reset_cache_stats()

static func _distance_cache_key(state: GameState, targets: Array, max_distance: int) -> String:
	var wall_keys: Array = state.wall_tiles.keys()
	wall_keys.sort()
	var target_keys: Array[String] = []
	for target_variant in targets:
		var target: Vector2i = target_variant
		target_keys.append("%d,%d" % [target.x, target.y])
	target_keys.sort()
	return "%d|%d|%d|%s|%s" % [
		state.width,
		state.height,
		max_distance,
		";".join(wall_keys),
		";".join(target_keys),
	]

static func _store_distance_cache(cache_key: String, distances: Dictionary) -> void:
	if _distance_cache.has(cache_key):
		_distance_cache[cache_key] = distances.duplicate()
		return
	_distance_cache[cache_key] = distances.duplicate()
	_distance_cache_order.append(cache_key)
	while _distance_cache_order.size() > MAX_CACHE_ENTRIES:
		var oldest: String = _distance_cache_order.pop_front()
		_distance_cache.erase(oldest)
