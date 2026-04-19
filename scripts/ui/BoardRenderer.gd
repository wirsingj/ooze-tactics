extends RefCounted
class_name BoardRenderer

# Atlas-driven world renderer:
# - Base slime layer uses adjacency mask + animation frame
# - Overlay layer defines tile role (gather/defense/melee/ranged)

const TYPE_ORDER: Array[String] = ["basic", "gather", "defense", "melee", "ranged"]
const ATLAS_CATALOG_SCRIPT: GDScript = preload("res://scripts/ui/AtlasCatalog.gd")
const OVERLAY_OWNER_BLEND: float = 0.22
const PLAYER_TINT: Color = Color(0.30, 0.93, 0.78, 1.0)
const ENEMY_TINTS: Array[Color] = [
	Color(0.95, 0.34, 0.48, 1.0),
	Color(0.72, 0.34, 0.90, 1.0),
	Color(0.92, 0.52, 0.24, 1.0),
	Color(0.82, 0.28, 0.30, 1.0),
]

var tile_size: int = 32
var atlas = ATLAS_CATALOG_SCRIPT.new()

var _owner_by_tile: Dictionary = {}

func draw_world(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	selected_tile: Vector2i,
	hovered_tile: Vector2i,
	queued_actions: Array,
	enemy_intent_actions: Array,
	valid_place_targets: Array,
	valid_convert_targets: Array,
	hover_preview_action: Dictionary,
	hover_invalid_reason: String,
	recent_enemy_actions: Array,
	enemy_flash_alpha: float,
	anim_frame: int
) -> void:
	if state == null:
		return

	_rebuild_owner_cache(state)
	_draw_ground(canvas, state, board_origin, board_clip_rect)
	_draw_valid_targets(canvas, board_origin, board_clip_rect, valid_place_targets, valid_convert_targets)
	_draw_door_and_resources(canvas, state, board_origin, board_clip_rect)
	_draw_blocks(canvas, state, board_origin, board_clip_rect, anim_frame)
	_draw_action_previews(canvas, state, board_origin, board_clip_rect, queued_actions, enemy_intent_actions, hover_preview_action, anim_frame)
	_draw_recent_enemy_actions(canvas, state, board_origin, board_clip_rect, recent_enemy_actions, enemy_flash_alpha)
	_draw_hover_feedback(canvas, state, board_origin, board_clip_rect, hovered_tile, hover_invalid_reason)

	if state.is_inside(selected_tile):
		var rect: Rect2 = _tile_rect(selected_tile, board_origin)
		if board_clip_rect.intersects(rect):
			canvas.draw_rect(rect, Color(1.0, 0.94, 0.52, 0.95), false, 2.0)

func make_ui_icon(tile_type: String) -> Texture2D:
	return atlas.make_texture("ui_icon_%s" % tile_type)

func make_ui_skin(sprite_name: String) -> Texture2D:
	return atlas.make_texture(sprite_name)

func _draw_ground(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2) -> void:
	for y in range(state.height):
		for x in range(state.width):
			var t: Vector2i = Vector2i(x, y)
			var noise: int = _tile_noise(x, y, state.level_index)
			var key: String = "ground_%02d" % (noise % 2)
			var modulate: Color = Color(0.88, 0.88, 0.88, 1.0)
			if state.is_blocked(t):
				key = "wall_%02d" % (noise % 3)
				modulate = Color(0.84, 0.84, 0.84, 1.0)
			var rect: Rect2 = _tile_rect(t, board_origin)
			if not board_clip_rect.intersects(rect):
				continue
			atlas.draw(canvas, key, rect, modulate)

func _draw_valid_targets(canvas: Node2D, board_origin: Vector2, board_clip_rect: Rect2, place_targets: Array, convert_targets: Array) -> void:
	for tile in place_targets:
		var t: Vector2i = tile
		var rect: Rect2 = _tile_rect(t, board_origin).grow(-10)
		if board_clip_rect.intersects(rect):
			canvas.draw_rect(rect, Color(0.45, 0.98, 0.62, 0.22), true)

	for tile in convert_targets:
		var t2: Vector2i = tile
		var rect2: Rect2 = _tile_rect(t2, board_origin).grow(-6)
		if board_clip_rect.intersects(rect2):
			canvas.draw_rect(rect2, Color(0.55, 0.88, 1.0, 0.58), false, 2.0)

func _draw_door_and_resources(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2) -> void:
	var door_rect: Rect2 = _tile_rect(state.door_tile, board_origin)
	if board_clip_rect.intersects(door_rect):
		atlas.draw(canvas, "door_00", door_rect, Color(1, 1, 1, 0.97))

	for node in state.resource_nodes:
		var tile: Vector2i = node["pos"]
		if not state.is_inside(tile):
			continue

		var key: String = "resource_gem_00"
		if String(node.get("kind", "gem")) == "rat":
			key = "resource_rat_00"
		if bool(node.get("consumed", false)):
			key = "resource_consumed_00"

		var rect: Rect2 = _tile_rect(tile, board_origin)
		if board_clip_rect.intersects(rect):
			atlas.draw(canvas, key, rect, Color(1, 1, 1, 0.95))

func _draw_blocks(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2, anim_frame: int) -> void:
	for block in state.blocks.values():
		_draw_block(canvas, state, block, board_origin, board_clip_rect, anim_frame, Color.WHITE)

func _draw_block(canvas: Node2D, state: GameState, block: Dictionary, board_origin: Vector2, board_clip_rect: Rect2, anim_frame: int, modulate: Color) -> void:
	var owner: int = int(block["owner"])
	var pos: Vector2i = block["pos"]
	var mask: int = _connectivity_mask(state, owner, pos)
	var frame: int = anim_frame % 3

	var tile_rect: Rect2 = _tile_rect(pos, board_origin)
	if not board_clip_rect.intersects(tile_rect):
		return

	var base_tint: Color = _multiply_tint(_owner_tint(owner), modulate)
	atlas.draw(canvas, _base_key(mask, frame), tile_rect, base_tint)

	var tile_type: String = String(block.get("tile_type", "basic"))
	var overlay_key: String = _overlay_key(tile_type, int(block.get("gather_bonus", 0)) > 0)
	if not overlay_key.is_empty() and atlas.has_sprite(overlay_key):
		var role_tint: Color = _overlay_role_tint(tile_type)
		var overlay_tint: Color = role_tint.lerp(_owner_tint(owner), OVERLAY_OWNER_BLEND)
		overlay_tint.a = 0.72
		var overlay_pass: Color = _multiply_tint(overlay_tint, modulate)
		atlas.draw(canvas, overlay_key, tile_rect, overlay_pass)

		var owner_glaze: Color = _owner_tint(owner)
		owner_glaze.a = 0.18
		atlas.draw(canvas, overlay_key, tile_rect, _multiply_tint(owner_glaze, modulate))

	if bool(block.get("core", false)):
		var core_rect: Rect2 = _tile_rect(pos, board_origin).grow(-3)
		if board_clip_rect.intersects(core_rect):
			canvas.draw_rect(core_rect, Color(1, 1, 1, modulate.a * 0.42), false, 2.0)

func _draw_action_previews(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	queued_actions: Array,
	enemy_intent_actions: Array,
	hover_preview_action: Dictionary,
	anim_frame: int
) -> void:
	var all_actions: Array = []
	all_actions.append_array(queued_actions)
	all_actions.append_array(enemy_intent_actions)
	if not hover_preview_action.is_empty():
		all_actions.append(hover_preview_action)

	var virtual_by_owner: Dictionary = {}
	for owner_id in state.players.keys():
		virtual_by_owner[int(owner_id)] = _build_virtual_tiles(state, all_actions, int(owner_id))

	for action in enemy_intent_actions:
		_draw_preview_action(canvas, state, board_origin, board_clip_rect, action, anim_frame, virtual_by_owner, Color(1.0, 0.42, 0.56, 0.58), Color(1.0, 0.42, 0.56, 0.26))

	for action in queued_actions:
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		_draw_preview_action(canvas, state, board_origin, board_clip_rect, action, anim_frame, virtual_by_owner, Color(0.60, 0.98, 0.72, 0.64), Color(0.60, 0.98, 0.72, 0.28))

	if not hover_preview_action.is_empty():
		_draw_preview_action(canvas, state, board_origin, board_clip_rect, hover_preview_action, anim_frame, virtual_by_owner, Color(1.0, 0.96, 0.64, 0.72), Color(1.0, 0.96, 0.64, 0.32))

func _draw_preview_action(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	action: Dictionary,
	anim_frame: int,
	virtual_by_owner: Dictionary,
	modulate: Color,
	indicator_color: Color
) -> void:
	var kind: String = String(action.get("type", "pass"))
	if kind != "place_tile" and kind != "convert_tile":
		return

	var owner: int = int(action.get("owner", 0))
	var tile_type: String = "basic"
	var tile: Vector2i = Vector2i(-1, -1)

	if kind == "place_tile":
		tile = action.get("target", Vector2i(-1, -1))
		tile_type = String(action.get("tile_type", "basic"))
	elif kind == "convert_tile":
		var block_id: int = int(action.get("block_id", -1))
		if not state.blocks.has(block_id):
			return
		tile = state.blocks[block_id]["pos"]
		tile_type = String(action.get("to_type", "basic"))

	if not state.is_inside(tile):
		return

	var extra_tiles: Dictionary = {}
	if virtual_by_owner.has(owner):
		extra_tiles = virtual_by_owner[owner]
	var mask: int = _connectivity_mask(state, owner, tile, extra_tiles)
	var frame: int = anim_frame % 3
	var rect: Rect2 = _tile_rect(tile, board_origin).grow(-1)
	if not board_clip_rect.intersects(rect):
		return

	atlas.draw(canvas, _base_key(mask, frame), rect, _multiply_tint(_owner_tint(owner), modulate))
	var overlay_key: String = _overlay_key(tile_type, false)
	if not overlay_key.is_empty() and atlas.has_sprite(overlay_key):
		var role_tint: Color = _overlay_role_tint(tile_type).lerp(_owner_tint(owner), OVERLAY_OWNER_BLEND)
		role_tint.a = 0.70
		atlas.draw(canvas, overlay_key, rect, _multiply_tint(role_tint, modulate))

	if tile_type == "melee":
		_draw_melee_preview(canvas, state, tile, board_origin, board_clip_rect, indicator_color)
	elif tile_type == "ranged":
		_draw_ranged_preview(canvas, state, owner, tile, board_origin, board_clip_rect, indicator_color)

func _draw_melee_preview(canvas: Node2D, state: GameState, origin: Vector2i, board_origin: Vector2, board_clip_rect: Rect2, color: Color) -> void:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t: Vector2i = origin + step
		if not state.is_inside(t):
			continue
		var rect: Rect2 = _tile_rect(t, board_origin).grow(-8)
		if board_clip_rect.intersects(rect):
			canvas.draw_rect(rect, color, true)

func _draw_ranged_preview(canvas: Node2D, state: GameState, owner: int, origin: Vector2i, board_origin: Vector2, board_clip_rect: Rect2, color: Color) -> void:
	var center: Vector2 = _tile_center(origin, board_origin)
	if not board_clip_rect.has_point(center):
		return
	var target: Variant = _nearest_enemy_tile(state, owner, origin, int(Combat.TILE_RULES["ranged"]["range"]))
	if target != null:
		var target_tile: Vector2i = target
		var target_center: Vector2 = _tile_center(target_tile, board_origin)
		if not board_clip_rect.has_point(target_center):
			return
		var line_color: Color = color
		line_color.a = clampf(color.a + 0.3, 0.0, 1.0)
		canvas.draw_line(center, target_center, line_color, 2.0)
		canvas.draw_circle(target_center, 4.0, line_color)
		return

	for y in range(origin.y - 4, origin.y + 5):
		for x in range(origin.x - 4, origin.x + 5):
			var t: Vector2i = Vector2i(x, y)
			if not state.is_inside(t):
				continue
			var dist: int = absi(t.x - origin.x) + absi(t.y - origin.y)
			if dist == 0 or dist > 4:
				continue
			var rect: Rect2 = _tile_rect(t, board_origin).grow(-11)
			if board_clip_rect.intersects(rect):
				canvas.draw_rect(rect, color, true)

func _draw_recent_enemy_actions(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2, recent_enemy_actions: Array, alpha: float) -> void:
	if alpha <= 0.0:
		return

	var fill: Color = Color(1.0, 0.22, 0.34, 0.25 * alpha)
	var line: Color = Color(1.0, 0.45, 0.55, 0.75 * alpha)
	for action in recent_enemy_actions:
		if int(action.get("owner", 0)) == GameState.PLAYER_ID:
			continue

		var tile: Vector2i = Vector2i(-1, -1)
		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			tile = action.get("target", Vector2i(-1, -1))
		elif kind == "convert_tile":
			var block_id: int = int(action.get("block_id", -1))
			if state.blocks.has(block_id):
				tile = state.blocks[block_id]["pos"]
		if tile == Vector2i(-1, -1):
			continue
		if not state.is_inside(tile):
			continue
		var rect: Rect2 = _tile_rect(tile, board_origin).grow(-5)
		if not board_clip_rect.intersects(rect):
			continue
		canvas.draw_rect(rect, fill, true)
		canvas.draw_rect(rect, line, false, 2.0)

func _draw_hover_feedback(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2, hovered_tile: Vector2i, hover_invalid_reason: String) -> void:
	if hovered_tile == Vector2i(-1, -1) or not state.is_inside(hovered_tile):
		return

	var rect: Rect2 = _tile_rect(hovered_tile, board_origin)
	if not board_clip_rect.intersects(rect):
		return
	if hover_invalid_reason.is_empty():
		canvas.draw_rect(rect.grow(-2), Color(1.0, 1.0, 1.0, 0.28), false, 1.5)
		return

	canvas.draw_rect(rect.grow(-2), Color(1.0, 0.28, 0.34, 0.65), false, 2.0)
	canvas.draw_line(rect.position + Vector2(8, 8), rect.position + Vector2(tile_size - 8, tile_size - 8), Color(1.0, 0.28, 0.34, 0.8), 2.0)
	canvas.draw_line(rect.position + Vector2(tile_size - 8, 8), rect.position + Vector2(8, tile_size - 8), Color(1.0, 0.28, 0.34, 0.8), 2.0)

func _build_virtual_tiles(state: GameState, actions: Array, owner: int) -> Dictionary:
	var tiles: Dictionary = {}
	for block in state.get_owner_blocks(owner):
		tiles[_tile_key(block["pos"])] = true

	for action in actions:
		if int(action.get("owner", 0)) != owner:
			continue
		if String(action.get("type", "")) != "place_tile":
			continue
		var t: Vector2i = action.get("target", Vector2i(-1, -1))
		tiles[_tile_key(t)] = true

	return tiles

func _connectivity_mask(state: GameState, owner: int, tile: Vector2i, extra_owned_tiles: Dictionary = {}) -> int:
	var mask: int = 0
	if _has_owner_tile(state, owner, tile + Vector2i.UP, extra_owned_tiles):
		mask |= 1
	if _has_owner_tile(state, owner, tile + Vector2i.RIGHT, extra_owned_tiles):
		mask |= 2
	if _has_owner_tile(state, owner, tile + Vector2i.DOWN, extra_owned_tiles):
		mask |= 4
	if _has_owner_tile(state, owner, tile + Vector2i.LEFT, extra_owned_tiles):
		mask |= 8
	return mask

func _has_owner_tile(state: GameState, owner: int, tile: Vector2i, extra_owned_tiles: Dictionary) -> bool:
	var key: String = _tile_key(tile)
	if extra_owned_tiles.has(key):
		return true
	if _owner_by_tile.has(key) and int(_owner_by_tile[key]) == owner:
		return true
	var block: Dictionary = state.get_block_at(tile)
	return not block.is_empty() and int(block["owner"]) == owner

func _rebuild_owner_cache(state: GameState) -> void:
	_owner_by_tile.clear()
	for block in state.blocks.values():
		_owner_by_tile[_tile_key(block["pos"])] = int(block["owner"])

func _nearest_enemy_tile(state: GameState, owner: int, origin: Vector2i, max_range: int) -> Variant:
	var best_dist: int = 999999
	var best_tile: Variant = null
	for block in state.blocks.values():
		if int(block["owner"]) == owner:
			continue
		var t: Vector2i = block["pos"]
		var dist: int = absi(origin.x - t.x) + absi(origin.y - t.y)
		if dist <= max_range and dist < best_dist:
			best_dist = dist
			best_tile = t
	return best_tile

func _base_key(mask: int, frame: int) -> String:
	return "slime_base_neutral_m%02d_f%d" % [mask, frame]

func _overlay_key(tile_type: String, gather_infused: bool) -> String:
	if tile_type == "basic":
		return ""
	if tile_type == "gather" and gather_infused:
		return "slime_overlay_gather_infused"
	if not TYPE_ORDER.has(tile_type):
		tile_type = "basic"
	return "slime_overlay_%s" % tile_type

func _owner_tint(owner_id: int) -> Color:
	if owner_id == GameState.PLAYER_ID:
		return PLAYER_TINT

	var count: int = ENEMY_TINTS.size()
	var idx: int = (owner_id - 2) % count
	if idx < 0:
		idx += count
	return ENEMY_TINTS[idx]

func _overlay_role_tint(tile_type: String) -> Color:
	match tile_type:
		"gather":
			return Color(0.72, 0.98, 0.74, 1.0)
		"defense":
			return Color(0.34, 0.58, 0.56, 1.0)
		"melee":
			return Color(0.28, 0.56, 0.72, 1.0)
		"ranged":
			return Color(0.60, 0.86, 0.98, 1.0)
		_:
			return Color(0.92, 0.96, 0.92, 1.0)

func _multiply_tint(base: Color, modifier: Color) -> Color:
	return Color(
		clampf(base.r * modifier.r, 0.0, 1.0),
		clampf(base.g * modifier.g, 0.0, 1.0),
		clampf(base.b * modifier.b, 0.0, 1.0),
		clampf(base.a * modifier.a, 0.0, 1.0)
	)

func _tile_rect(tile: Vector2i, board_origin: Vector2) -> Rect2:
	return Rect2(board_origin.x + tile.x * tile_size, board_origin.y + tile.y * tile_size, tile_size, tile_size)

func _tile_center(tile: Vector2i, board_origin: Vector2) -> Vector2:
	return Vector2(
		board_origin.x + tile.x * tile_size + tile_size * 0.5,
		board_origin.y + tile.y * tile_size + tile_size * 0.5
	)

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _tile_noise(x: int, y: int, level_index: int) -> int:
	var n: int = int(x * 73856093) ^ int(y * 19349663) ^ int(level_index * 83492791)
	return absi(n) % 97
