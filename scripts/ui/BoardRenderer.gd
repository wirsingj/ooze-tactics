extends RefCounted
class_name BoardRenderer

# Atlas-driven world renderer:
# - Base slime layer uses adjacency mask + animation frame
# - Overlay layer defines tile role (gather/defense/melee/ranged)

const TYPE_ORDER: Array[String] = ["basic", "gather", "defense", "melee", "ranged"]
const ATLAS_CATALOG_SCRIPT: GDScript = preload("res://scripts/ui/AtlasCatalog.gd")
const OVERLAY_OWNER_BLEND: float = 0.04
const PREVIEW_ALPHA_SCALE: float = 0.72
const BASE_VARIANTS: int = 3
const FRONTLINE_RIM_ALPHA: float = 0.18
const RANGED_GLOW_ALPHA: float = 0.07
const HEART_GLOW_BASE_ALPHA: float = 0.18
const HEART_GLOW_PULSE_ALPHA: float = 0.18
const UPGRADE_BADGE_FILL_ALPHA: float = 0.74
const UPGRADE_RING_ALPHA: float = 0.58
const UPGRADE_RING_SHADOW_ALPHA: float = 0.30
const UPGRADE_TIER_DOT_SHADOW_ALPHA: float = 0.70
const UPGRADE_TIER_DOT_FILL_ALPHA: float = 1.0
const EMISSIVE_STRENGTH: float = 0.28
const EMISSIVE_BLOOM_STRENGTH: float = 0.24
const EMISSIVE_BLOOM_RADIUS_TILES: float = 0.44
const EMISSIVE_LOCAL_SPILL: float = 0.08
const EMISSIVE_DOOR_STRENGTH: float = 0.30
const EMISSIVE_RESOURCE_STRENGTH: float = 0.28
const PLAYER_TINT: Color = Color(0.30, 0.93, 0.78, 1.0)
const ALLY_TINTS: Array[Color] = [
	Color(0.06, 0.44, 0.99, 1.0), # deep azure
	Color(0.03, 0.67, 1.00, 1.0), # electric blue
	Color(0.00, 0.86, 0.95, 1.0), # bright cyan
	Color(0.00, 0.98, 0.74, 1.0), # seafoam
	Color(0.20, 1.00, 0.52, 1.0), # spring green
	Color(0.36, 0.97, 0.34, 1.0), # vivid green
]
const ENEMY_TINTS: Array[Color] = [
	Color(0.95, 0.34, 0.48, 1.0),
	Color(0.72, 0.34, 0.90, 1.0),
	Color(0.92, 0.52, 0.24, 1.0),
	Color(0.82, 0.28, 0.30, 1.0),
]

var tile_size: float = 32.0
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
	anim_frame: int,
	pulse_tiles: Array = [],
	pulse_alpha: float = 0.0
) -> void:
	if state == null:
		return

	draw_world_background(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		valid_place_targets,
		valid_convert_targets
	)
	draw_world_slime(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		queued_actions,
		enemy_intent_actions,
		hover_preview_action,
		anim_frame,
		pulse_tiles,
		pulse_alpha
	)
	draw_world_overlay(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		selected_tile,
		hovered_tile,
		queued_actions,
		hover_invalid_reason,
		recent_enemy_actions,
		enemy_flash_alpha
	)

func draw_world_background(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	valid_place_targets: Array,
	valid_convert_targets: Array
) -> void:
	if state == null:
		return
	_draw_ground(canvas, state, board_origin, board_clip_rect)
	_draw_valid_targets(canvas, board_origin, board_clip_rect, valid_place_targets, valid_convert_targets)
	_draw_door_and_resources(canvas, state, board_origin, board_clip_rect)

func draw_world_slime(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	queued_actions: Array,
	enemy_intent_actions: Array,
	hover_preview_action: Dictionary,
	anim_frame: int,
	pulse_tiles: Array = [],
	pulse_alpha: float = 0.0
) -> void:
	if state == null:
		return
	_rebuild_owner_cache(state)
	_draw_blocks(canvas, state, board_origin, board_clip_rect, anim_frame)
	_draw_action_previews(canvas, state, board_origin, board_clip_rect, queued_actions, enemy_intent_actions, hover_preview_action, anim_frame)
	_draw_turn_pulse(canvas, board_origin, board_clip_rect, pulse_tiles, pulse_alpha)

func draw_world_emissive(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	anim_frame: int
) -> void:
	if state == null:
		return
	_draw_block_emissive(canvas, state, board_origin, board_clip_rect, anim_frame)
	_draw_world_emissive_sources(canvas, state, board_origin, board_clip_rect, anim_frame)

func draw_world_overlay(
	canvas: Node2D,
	state: GameState,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	selected_tile: Vector2i,
	hovered_tile: Vector2i,
	queued_actions: Array,
	hover_invalid_reason: String,
	recent_enemy_actions: Array,
	enemy_flash_alpha: float
) -> void:
	if state == null:
		return
	_draw_recent_enemy_actions(canvas, state, board_origin, board_clip_rect, recent_enemy_actions, enemy_flash_alpha)
	_draw_hover_feedback(canvas, state, board_origin, board_clip_rect, hovered_tile, hover_invalid_reason)
	var show_selected: bool = state.is_inside(selected_tile) and (selected_tile == hovered_tile or _tile_has_queued_player_action(state, selected_tile, queued_actions))
	if show_selected:
		var rect: Rect2 = _tile_rect(selected_tile, board_origin)
		if board_clip_rect.intersects(rect):
			canvas.draw_rect(rect, Color(1.0, 0.94, 0.52, 0.95), false, 2.0)

func _draw_turn_pulse(canvas: Node2D, board_origin: Vector2, board_clip_rect: Rect2, pulse_tiles: Array, pulse_alpha: float) -> void:
	if pulse_alpha <= 0.0 or pulse_tiles.is_empty():
		return
	for pulse_tile in pulse_tiles:
		var tile: Vector2i = pulse_tile
		if tile == Vector2i(-1, -1):
			continue
		var rect: Rect2 = _tile_rect(tile, board_origin).grow(-2)
		if not board_clip_rect.intersects(rect):
			continue
		canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.24 * pulse_alpha), true)
		canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.96 * pulse_alpha), false, 2.0)

func make_ui_icon(tile_type: String, pixel_size: int = 32) -> Texture2D:
	var tex: Texture2D = atlas.make_texture("ui_icon_%s" % tile_type)
	if tex == null:
		return null

	var image: Image = tex.get_image()
	if image == null or image.is_empty():
		return tex

	if pixel_size > 0 and pixel_size != 32:
		image.resize(pixel_size, pixel_size, Image.INTERPOLATE_NEAREST)
	image = _enhance_ui_icon_image(image)
	return ImageTexture.create_from_image(image)

func make_ui_skin(sprite_name: String) -> Texture2D:
	return atlas.make_texture(sprite_name)

func owner_tint_for_ui(state: GameState, owner_id: int) -> Color:
	return _owner_tint(state, owner_id)

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
	var entrance_rect: Rect2 = _tile_rect(state.entrance_tile, board_origin)
	if board_clip_rect.intersects(entrance_rect):
		var entrance_tint: Color = Color(0.54, 0.84, 0.96, 0.94)
		atlas.draw(canvas, "door_00", entrance_rect, entrance_tint)

	if state.door_hp > 0:
		var door_rect: Rect2 = _tile_rect(state.door_tile, board_origin)
		if board_clip_rect.intersects(door_rect):
			var door_ratio: float = 1.0
			if state.door_max_hp > 0:
				door_ratio = clampf(float(state.door_hp) / float(state.door_max_hp), 0.0, 1.0)
			var door_tint: Color = Color(
				0.70 + 0.30 * door_ratio,
				0.56 + 0.44 * door_ratio,
				0.52 + 0.48 * door_ratio,
				0.94
			)
			atlas.draw(canvas, "door_00", door_rect, door_tint)

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

func _draw_block_emissive(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2, anim_frame: int) -> void:
	for block in state.blocks.values():
		var pos: Vector2i = block["pos"]
		var tile_rect: Rect2 = _tile_rect(pos, board_origin)
		if not board_clip_rect.intersects(tile_rect.grow(tile_size * 0.95)):
			continue

		var owner: int = int(block.get("owner", 0))
		var owner_tint: Color = _owner_tint(state, owner)
		var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
		var variant: int = _tile_variant(pos)
		var pulse: float = [0.0, 0.55, 1.0][(anim_frame + variant) % 3]
		var tile_type: String = String(block.get("tile_type", "basic"))

		if tile_type == "ranged":
			var ranged_core: Color = _overlay_role_tint("ranged").lerp(owner_tint, 0.35)
			var ranged_variation: float = _emissive_variation(pos, 17)
			if ranged_variation >= 0.34:
				var ranged_strength: float = EMISSIVE_STRENGTH * (0.68 + ranged_variation * 0.62) * (1.0 + pulse * 0.18)
				var ranged_size: float = tile_size * (0.20 + ranged_variation * 0.09)
				var ranged_radius: float = EMISSIVE_BLOOM_RADIUS_TILES * tile_size * (0.84 + ranged_variation * 0.34)
				var overlay_rect: Rect2 = _overlay_rect(tile_rect, tile_type).grow(0.3)
				var overlay_key: String = _overlay_key(tile_type, false)
				if atlas.has_sprite(overlay_key):
					atlas.draw(canvas, overlay_key, overlay_rect, Color(ranged_core.r, ranged_core.g, ranged_core.b, 0.14 * ranged_strength))
				_draw_emissive_bloom(
					canvas,
					center + Vector2(0.0, -0.5),
					ranged_size,
					ranged_core,
					ranged_strength,
					ranged_radius,
					EMISSIVE_LOCAL_SPILL
				)

		if bool(block.get("is_heart", false)):
			var heart_color: Color = owner_tint.lerp(Color(1.0, 0.98, 1.0, 1.0), 0.48)
			var heart_center: Vector2 = center + Vector2(0.0, -1.0)
			var heart_variation: float = _emissive_variation(pos, 43)
			var heart_strength: float = EMISSIVE_STRENGTH * 1.06 * (0.80 + heart_variation * 0.55) * (1.0 + pulse * 0.20)
			var heart_enabled: bool = heart_variation >= 0.26
			if heart_enabled:
				_draw_emissive_bloom(
					canvas,
					heart_center,
					tile_size * (0.20 + heart_variation * 0.06),
					heart_color,
					heart_strength,
					(tile_size * 0.56) + pulse * tile_size * 0.08,
					EMISSIVE_LOCAL_SPILL + 0.04
				)
			_draw_heart_icon(
				canvas,
				heart_center,
				tile_size * 0.20,
				Color(heart_color.r, heart_color.g, heart_color.b, 0.78),
				Color(1.0, 0.98, 1.0, 0.58)
			)

func _draw_world_emissive_sources(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2, anim_frame: int) -> void:
	var door_phase: float = [0.0, 0.5, 1.0][anim_frame % 3]

	var entrance_center: Vector2 = _tile_center(state.entrance_tile, board_origin)
	if board_clip_rect.has_point(entrance_center):
		var entrance_color: Color = Color(0.50, 0.88, 1.0, 1.0)
		_draw_emissive_bloom(
			canvas,
			entrance_center,
			tile_size * 0.21,
			entrance_color,
			EMISSIVE_DOOR_STRENGTH * 0.70,
			tile_size * 0.72,
			EMISSIVE_LOCAL_SPILL * 0.65
		)

	if state.door_hp > 0:
		var door_center: Vector2 = _tile_center(state.door_tile, board_origin)
		if board_clip_rect.has_point(door_center):
			var door_ratio: float = 1.0
			if state.door_max_hp > 0:
				door_ratio = clampf(float(state.door_hp) / float(state.door_max_hp), 0.0, 1.0)
			var door_color: Color = Color(
				0.86 + 0.14 * door_ratio,
				0.72 + 0.16 * door_ratio,
				0.42 + 0.28 * door_ratio,
				1.0
			)
			_draw_emissive_bloom(
				canvas,
				door_center,
				tile_size * 0.24,
				door_color,
				EMISSIVE_DOOR_STRENGTH * (0.88 + 0.20 * door_phase),
				tile_size * 0.86,
				EMISSIVE_LOCAL_SPILL * 0.80
			)
			atlas.draw(canvas, "door_00", _tile_rect(state.door_tile, board_origin).grow(0.7), Color(door_color.r, door_color.g, door_color.b, 0.22))

	for node in state.resource_nodes:
		if bool(node.get("consumed", false)):
			continue
		var tile: Vector2i = node.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile):
			continue
		var center: Vector2 = _tile_center(tile, board_origin)
		if not board_clip_rect.has_point(center):
			continue
		var is_rat: bool = String(node.get("kind", "gem")) == "rat"
		var resource_color: Color = Color(0.84, 1.0, 0.96, 1.0)
		var strength: float = EMISSIVE_RESOURCE_STRENGTH * (0.84 + 0.22 * door_phase)
		if is_rat:
			resource_color = Color(0.88, 0.74, 0.56, 1.0)
			strength *= 0.55
		_draw_emissive_bloom(
			canvas,
			center,
			tile_size * 0.20,
			resource_color,
			strength,
			tile_size * 0.68,
			EMISSIVE_LOCAL_SPILL * 0.54
		)

func _draw_emissive_bloom(
	canvas: Node2D,
	center: Vector2,
	core_radius: float,
	color: Color,
	strength: float,
	bloom_radius: float,
	spill: float
) -> void:
	var clamped_strength: float = maxf(0.0, strength)
	var clamped_bloom: float = maxf(core_radius + 1.0, bloom_radius)
	var core_alpha: float = 0.22 * clamped_strength
	var mid_alpha: float = 0.12 * clamped_strength * EMISSIVE_BLOOM_STRENGTH
	var outer_alpha: float = 0.07 * clamped_strength * EMISSIVE_BLOOM_STRENGTH
	var spill_alpha: float = 0.04 * clamped_strength * clampf(spill, 0.0, 1.0)

	canvas.draw_circle(center, clamped_bloom * 1.08, Color(color.r, color.g, color.b, spill_alpha))
	canvas.draw_circle(center, clamped_bloom, Color(color.r, color.g, color.b, outer_alpha))
	canvas.draw_circle(center, maxf(core_radius + 2.0, clamped_bloom * 0.58), Color(color.r, color.g, color.b, mid_alpha))
	canvas.draw_circle(center, core_radius, Color(color.r, color.g, color.b, core_alpha))

func _emissive_variation(tile: Vector2i, salt: int) -> float:
	var n: int = _tile_noise(tile.x, tile.y, salt)
	return float(n % 100) / 100.0

func _draw_blocks(canvas: Node2D, state: GameState, board_origin: Vector2, board_clip_rect: Rect2, anim_frame: int) -> void:
	for block in state.blocks.values():
		_draw_block(canvas, state, block, board_origin, board_clip_rect, anim_frame, Color.WHITE)

func _draw_block(canvas: Node2D, state: GameState, block: Dictionary, board_origin: Vector2, board_clip_rect: Rect2, anim_frame: int, modulate: Color) -> void:
	var owner: int = int(block["owner"])
	var pos: Vector2i = block["pos"]
	var mask: int = _connectivity_mask(state, owner, pos)
	var variant: int = _tile_variant(pos)
	var frame: int = (anim_frame + variant) % 3

	var tile_rect: Rect2 = _tile_rect(pos, board_origin)
	if not board_clip_rect.intersects(tile_rect):
		return

	var base_tint: Color = _multiply_tint(_owner_tint(state, owner), modulate)
	atlas.draw(canvas, _base_key(mask, frame, variant), tile_rect, base_tint)

	var tile_type: String = String(block.get("tile_type", "basic"))
	var upgrade_tier: int = int(block.get("upgrade_tier", 0))
	if tile_type == "basic":
		_draw_basic_tile_detail(canvas, tile_rect, _owner_tint(state, owner), pos, anim_frame, modulate)
	var overlay_key: String = _overlay_key(tile_type, int(block.get("gather_bonus", 0)) > 0)
	if not overlay_key.is_empty() and atlas.has_sprite(overlay_key):
		var overlay_rect: Rect2 = _overlay_rect(tile_rect, tile_type)
		if tile_type != "basic":
			var underlay: Color = _multiply_tint(Color(0.10, 0.14, 0.18, 0.38), modulate)
			atlas.draw(canvas, overlay_key, overlay_rect.grow(0.6), underlay)

		var role_tint: Color = _overlay_role_tint(tile_type)
		var overlay_tint: Color = role_tint.lerp(_owner_tint(state, owner), OVERLAY_OWNER_BLEND)
		if upgrade_tier > Combat.SPECIALIZATION_TIER:
			overlay_tint = overlay_tint.lerp(Color(1.0, 1.0, 1.0, overlay_tint.a), _tier_brightness_lerp(upgrade_tier))
		overlay_tint.a = _overlay_opacity(tile_type)
		var overlay_pass: Color = _multiply_tint(overlay_tint, modulate)
		atlas.draw(canvas, overlay_key, overlay_rect, overlay_pass)
		if tile_type != "basic":
			var clarity_tint: Color = overlay_tint.lerp(Color(1.0, 1.0, 1.0, overlay_tint.a), 0.48)
			clarity_tint.a = 1.0
			atlas.draw(canvas, overlay_key, overlay_rect, _multiply_tint(clarity_tint, modulate))

		var owner_glaze: Color = _owner_tint(state, owner)
		owner_glaze.a = 0.04 if tile_type != "basic" else 0.06
		atlas.draw(canvas, overlay_key, overlay_rect, _multiply_tint(owner_glaze, modulate))
		_draw_role_readability_accent(canvas, overlay_rect, tile_type, modulate)

	if upgrade_tier > 0:
		_draw_upgrade_badge(canvas, tile_rect, tile_type, upgrade_tier, modulate)

	if tile_type == "ranged":
		var pulse: float = [0.0, 0.55, 1.0][(anim_frame + variant) % 3]
		var ranged_glow: Color = _overlay_role_tint("ranged")
		ranged_glow.a = (RANGED_GLOW_ALPHA + pulse * 0.02) * modulate.a
		var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
		canvas.draw_circle(center, tile_size * 0.22, ranged_glow)
		var core_glow: Color = Color(1.0, 1.0, 1.0, (0.06 + pulse * 0.04) * modulate.a)
		canvas.draw_circle(center + Vector2(0.5, 0.0), tile_size * 0.10, core_glow)

	if bool(block.get("is_heart", false)):
		var pulse_phase: float = [0.0, 0.55, 1.0][(anim_frame + variant) % 3]
		var heart_color: Color = _owner_tint(state, owner).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.38)
		var center: Vector2 = tile_rect.position + tile_rect.size * 0.5 + Vector2(0.0, -1.0)
		var glow_alpha: float = (HEART_GLOW_BASE_ALPHA + HEART_GLOW_PULSE_ALPHA * pulse_phase) * modulate.a
		var glow: Color = Color(heart_color.r, heart_color.g, heart_color.b, glow_alpha)
		canvas.draw_circle(center + Vector2(0.0, 1.0), tile_size * 0.28, glow)
		var fill_color: Color = Color(heart_color.r, heart_color.g, heart_color.b, (0.88 + 0.10 * pulse_phase) * modulate.a)
		var line_color: Color = Color(1.0, 0.96, 0.96, 0.94 * modulate.a)
		_draw_heart_icon(canvas, center, tile_size * 0.22, fill_color, line_color)

	if bool(block.get("core", false)):
		var core_rect: Rect2 = _tile_rect(pos, board_origin).grow(-3)
		if board_clip_rect.intersects(core_rect):
			canvas.draw_rect(core_rect, Color(1, 1, 1, modulate.a * 0.42), false, 2.0)

	if _is_frontline_visual(state, owner, pos):
		var rim: Rect2 = tile_rect.grow(-1.8)
		if board_clip_rect.intersects(rim):
			var rim_color: Color = _owner_tint(state, owner)
			rim_color.a = FRONTLINE_RIM_ALPHA * modulate.a
			canvas.draw_rect(rim, rim_color, false, 1.7)

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
	var base_actions: Array = []
	base_actions.append_array(queued_actions)
	base_actions.append_array(enemy_intent_actions)
	var virtual_by_owner: Dictionary = {}
	for owner_id in state.players.keys():
		virtual_by_owner[int(owner_id)] = _build_virtual_tiles(state, base_actions, int(owner_id))

	for action in enemy_intent_actions:
		_draw_preview_action(canvas, state, board_origin, board_clip_rect, action, anim_frame, virtual_by_owner, Color(1.0, 0.42, 0.56, 0.58), Color(1.0, 0.42, 0.56, 0.26))

	for action in queued_actions:
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		_draw_preview_action(canvas, state, board_origin, board_clip_rect, action, anim_frame, virtual_by_owner, Color(0.60, 0.98, 0.72, 0.64), Color(0.60, 0.98, 0.72, 0.28))

	if not hover_preview_action.is_empty():
		var hover_actions: Array = base_actions.duplicate()
		hover_actions.append(hover_preview_action)
		var hover_virtual_by_owner: Dictionary = {}
		for owner_id in state.players.keys():
			hover_virtual_by_owner[int(owner_id)] = _build_virtual_tiles(state, hover_actions, int(owner_id))
		_draw_preview_action(canvas, state, board_origin, board_clip_rect, hover_preview_action, anim_frame, hover_virtual_by_owner, Color(1.0, 0.96, 0.64, 0.72), Color(1.0, 0.96, 0.64, 0.32))

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
	if kind != "place_tile" and kind != "convert_tile" and kind != "upgrade_tile":
		return

	var owner: int = int(action.get("owner", 0))
	var tile_type: String = "basic"
	var tile: Vector2i = Vector2i(-1, -1)
	var preview_tier: int = 0

	if kind == "place_tile":
		tile = action.get("target", Vector2i(-1, -1))
		tile_type = String(action.get("tile_type", "basic"))
		preview_tier = 0 if tile_type == "basic" else Combat.SPECIALIZATION_TIER
	elif kind == "convert_tile":
		var block_id: int = int(action.get("block_id", -1))
		if not state.blocks.has(block_id):
			return
		tile = state.blocks[block_id]["pos"]
		tile_type = String(action.get("to_type", "basic"))
		preview_tier = 0 if tile_type == "basic" else Combat.SPECIALIZATION_TIER
	elif kind == "upgrade_tile":
		var upgrade_block_id: int = int(action.get("block_id", -1))
		if not state.blocks.has(upgrade_block_id):
			return
		tile = state.blocks[upgrade_block_id]["pos"]
		tile_type = String(action.get("tile_type", String(state.blocks[upgrade_block_id].get("tile_type", "basic"))))
		var current_tier: int = int(state.blocks[upgrade_block_id].get("upgrade_tier", Combat.SPECIALIZATION_TIER))
		preview_tier = clampi(current_tier + 1, Combat.SPECIALIZATION_TIER, Combat.MAX_UPGRADE_TIER)

	if not state.is_inside(tile):
		return

	var extra_tiles: Dictionary = {}
	if virtual_by_owner.has(owner):
		extra_tiles = virtual_by_owner[owner]
	var mask: int = _connectivity_mask(state, owner, tile, extra_tiles)
	var variant: int = _tile_variant(tile)
	var frame: int = (anim_frame + variant) % 3
	# Keep preview geometry identical to committed tiles so queued ooze reads seamless.
	var rect: Rect2 = _tile_rect(tile, board_origin)
	if not board_clip_rect.intersects(rect):
		return

	var preview_modulate: Color = modulate
	preview_modulate.a = clampf(modulate.a * PREVIEW_ALPHA_SCALE, 0.0, 0.92)
	atlas.draw(canvas, _base_key(mask, frame, variant), rect, _multiply_tint(_owner_tint(state, owner), preview_modulate))
	var overlay_key: String = _overlay_key(tile_type, false)
	if not overlay_key.is_empty() and atlas.has_sprite(overlay_key):
		var overlay_rect: Rect2 = _overlay_rect(rect, tile_type)
		if tile_type != "basic":
			var preview_underlay: Color = _multiply_tint(Color(0.10, 0.14, 0.18, 0.30), preview_modulate)
			atlas.draw(canvas, overlay_key, overlay_rect.grow(0.6), preview_underlay)
		var role_tint: Color = _overlay_role_tint(tile_type).lerp(_owner_tint(state, owner), OVERLAY_OWNER_BLEND)
		if preview_tier > Combat.SPECIALIZATION_TIER:
			role_tint = role_tint.lerp(Color(1.0, 1.0, 1.0, role_tint.a), _tier_brightness_lerp(preview_tier))
		role_tint.a = _overlay_opacity(tile_type)
		atlas.draw(canvas, overlay_key, overlay_rect, _multiply_tint(role_tint, preview_modulate))
		if tile_type != "basic":
			var preview_clarity_tint: Color = role_tint.lerp(Color(1.0, 1.0, 1.0, role_tint.a), 0.48)
			preview_clarity_tint.a = clampf(role_tint.a * 0.80, 0.0, 1.0)
			atlas.draw(canvas, overlay_key, overlay_rect, _multiply_tint(preview_clarity_tint, preview_modulate))
		_draw_role_readability_accent(canvas, overlay_rect, tile_type, preview_modulate)

	if preview_tier > 0:
		_draw_upgrade_badge(canvas, rect, tile_type, preview_tier, preview_modulate)

	if tile_type == "melee":
		_draw_melee_preview(canvas, state, tile, board_origin, board_clip_rect, indicator_color)
	elif tile_type == "ranged":
		var ranged_profile: Dictionary = _preview_ranged_profile(action, state)
		_draw_ranged_preview(
			canvas,
			state,
			owner,
			tile,
			board_origin,
			board_clip_rect,
			indicator_color,
			int(ranged_profile.get("range", int(Combat.TILE_RULES["ranged"]["range"]))),
			int(ranged_profile.get("splash_radius", 1))
		)

func _draw_melee_preview(canvas: Node2D, state: GameState, origin: Vector2i, board_origin: Vector2, board_clip_rect: Rect2, color: Color) -> void:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var t: Vector2i = origin + step
		if not state.is_inside(t):
			continue
		var rect: Rect2 = _tile_rect(t, board_origin).grow(-8)
		if board_clip_rect.intersects(rect):
			canvas.draw_rect(rect, color, true)

func _draw_ranged_preview(
	canvas: Node2D,
	state: GameState,
	owner: int,
	origin: Vector2i,
	board_origin: Vector2,
	board_clip_rect: Rect2,
	color: Color,
	attack_range: int = 4,
	splash_radius: int = 1
) -> void:
	var center: Vector2 = _tile_center(origin, board_origin)
	if not board_clip_rect.has_point(center):
		return
	var target: Variant = _nearest_enemy_tile(state, owner, origin, attack_range)
	if target != null:
		var target_tile: Vector2i = target
		var target_center: Vector2 = _tile_center(target_tile, board_origin)
		if not board_clip_rect.has_point(target_center):
			return
		var line_color: Color = color
		line_color.a = clampf(color.a + 0.3, 0.0, 1.0)
		canvas.draw_line(center, target_center, line_color, 2.0)
		canvas.draw_circle(target_center, 4.0, line_color)
		var is_door_target: bool = target_tile == state.door_tile
		if is_door_target:
			return
		if _has_adjacent_hostile(state, owner, origin):
			return
		for y in range(target_tile.y - splash_radius, target_tile.y + splash_radius + 1):
			for x in range(target_tile.x - splash_radius, target_tile.x + splash_radius + 1):
				var splash_tile: Vector2i = Vector2i(x, y)
				if not state.is_inside(splash_tile):
					continue
				var distance: int = absi(splash_tile.x - target_tile.x) + absi(splash_tile.y - target_tile.y)
				if distance <= 0 or distance > splash_radius:
					continue
				var splash_block: Dictionary = state.get_block_at(splash_tile)
				if splash_block.is_empty():
					continue
				if not state.are_hostile(owner, int(splash_block["owner"])):
					continue
				var splash_rect: Rect2 = _tile_rect(splash_tile, board_origin).grow(-10)
				if board_clip_rect.intersects(splash_rect):
					canvas.draw_rect(splash_rect, Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.58), true)
		return

	for y in range(origin.y - attack_range, origin.y + attack_range + 1):
		for x in range(origin.x - attack_range, origin.x + attack_range + 1):
			var t: Vector2i = Vector2i(x, y)
			if not state.is_inside(t):
				continue
			var dist: int = absi(t.x - origin.x) + absi(t.y - origin.y)
			if dist == 0 or dist > attack_range:
				continue
			var rect: Rect2 = _tile_rect(t, board_origin).grow(-11)
			if board_clip_rect.intersects(rect):
				canvas.draw_rect(rect, color, true)

func _preview_ranged_profile(action: Dictionary, state: GameState) -> Dictionary:
	var range_value: int = int(Combat.TILE_RULES["ranged"]["range"])
	var splash_radius: int = 1
	if String(action.get("type", "")) == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if block_id >= 0 and state.blocks.has(block_id):
			var block: Dictionary = state.blocks[block_id]
			range_value = int(block.get("range", range_value)) + int(Combat.RANGED_UPGRADE_RANGE_BONUS)
			splash_radius = 1 + int(block.get("ranged_splash_bonus", 0)) + int(Combat.RANGED_UPGRADE_SPLASH_RADIUS_BONUS)
		else:
			range_value += Combat.RANGED_UPGRADE_RANGE_BONUS
			splash_radius += Combat.RANGED_UPGRADE_SPLASH_RADIUS_BONUS
	elif String(action.get("type", "")) == "convert_tile":
		var block_id: int = int(action.get("block_id", -1))
		if block_id >= 0 and state.blocks.has(block_id):
			range_value = int(maxi(range_value, int(state.blocks[block_id].get("range", range_value))))
			splash_radius += int(state.blocks[block_id].get("ranged_splash_bonus", 0))
	return {"range": range_value, "splash_radius": splash_radius}

func _draw_basic_tile_detail(
	canvas: Node2D,
	tile_rect: Rect2,
	owner_tint: Color,
	tile: Vector2i,
	anim_frame: int,
	modulate: Color
) -> void:
	var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
	var noise_a: float = float(_tile_noise(tile.x, tile.y, 31) % 100) / 100.0
	var noise_b: float = float(_tile_noise(tile.x, tile.y, 47) % 100) / 100.0
	var frame_pulse: float = [0.0, 0.45, 1.0][(anim_frame + _tile_variant(tile)) % 3]

	var core_tint: Color = owner_tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.20)
	core_tint.a = (0.14 + noise_a * 0.04 + frame_pulse * 0.03) * modulate.a
	var core_radius: float = tile_size * (0.12 + noise_b * 0.03)
	canvas.draw_circle(center + Vector2((noise_b - 0.5) * tile_size * 0.12, (noise_a - 0.5) * tile_size * 0.10), core_radius, core_tint)

	var mote_color: Color = Color(0.98, 1.0, 1.0, (0.10 + frame_pulse * 0.03) * modulate.a)
	canvas.draw_circle(center + Vector2(tile_size * 0.13, -tile_size * 0.10), tile_size * 0.05, mote_color)
	canvas.draw_circle(center + Vector2(-tile_size * 0.11, tile_size * 0.09), tile_size * 0.04, mote_color)

	var rim_rect: Rect2 = tile_rect.grow(-maxf(2.0, tile_size * 0.08))
	canvas.draw_rect(rim_rect, Color(1.0, 1.0, 1.0, (0.10 + noise_b * 0.04) * modulate.a), false, maxf(1.0, tile_size * 0.028))
	var arc_start: float = TAU * noise_a
	canvas.draw_arc(
		center,
		tile_size * 0.34,
		arc_start,
		arc_start + PI * (0.80 + noise_b * 0.25),
		10,
		Color(1.0, 1.0, 1.0, (0.08 + frame_pulse * 0.03) * modulate.a),
		maxf(1.0, tile_size * 0.022),
		true
	)

func _has_adjacent_hostile(state: GameState, owner: int, tile: Vector2i) -> bool:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var other: Dictionary = state.get_block_at(tile + step)
		if other.is_empty():
			continue
		if state.are_hostile(owner, int(other.get("owner", 0))):
			return true
	return false

func _draw_role_readability_accent(canvas: Node2D, overlay_rect: Rect2, tile_type: String, modulate: Color) -> void:
	var alpha_scale: float = clampf(modulate.a, 0.0, 1.0)
	match tile_type:
		"defense":
			var border_rect: Rect2 = overlay_rect.grow(-4.0)
			canvas.draw_rect(border_rect, Color(0.05, 0.09, 0.14, 0.72 * alpha_scale), false, 2.2)
			canvas.draw_line(
				border_rect.position + Vector2(2.0, 3.0),
				border_rect.position + Vector2(border_rect.size.x - 2.0, 3.0),
				Color(0.86, 0.98, 1.0, 0.68 * alpha_scale),
				1.6
			)
		"melee":
			var center: Vector2 = overlay_rect.position + overlay_rect.size * 0.5
			canvas.draw_line(center + Vector2(-7.0, 6.0), center + Vector2(0.0, -7.0), Color(0.06, 0.11, 0.16, 0.72 * alpha_scale), 2.2)
			canvas.draw_line(center + Vector2(7.0, 6.0), center + Vector2(0.0, -7.0), Color(0.06, 0.11, 0.16, 0.72 * alpha_scale), 2.2)
			canvas.draw_line(center + Vector2(-5.0, 6.0), center + Vector2(0.0, -5.0), Color(0.90, 1.0, 1.0, 0.62 * alpha_scale), 1.6)
			canvas.draw_line(center + Vector2(5.0, 6.0), center + Vector2(0.0, -5.0), Color(0.90, 1.0, 1.0, 0.62 * alpha_scale), 1.6)
		"ranged":
			var ranged_center: Vector2 = overlay_rect.position + overlay_rect.size * 0.5
			canvas.draw_circle(ranged_center, tile_size * 0.105, Color(0.06, 0.11, 0.16, 0.74 * alpha_scale))
			canvas.draw_circle(ranged_center, tile_size * 0.16, Color(0.94, 1.0, 1.0, 0.66 * alpha_scale), false, 1.8)
			canvas.draw_circle(ranged_center + Vector2(0.0, 0.5), tile_size * 0.05, Color(1.0, 1.0, 1.0, 0.56 * alpha_scale))
		"gather":
			var gem_center: Vector2 = overlay_rect.position + overlay_rect.size * 0.5
			var s: float = tile_size * 0.14
			var gem_poly: PackedVector2Array = PackedVector2Array([
				gem_center + Vector2(0.0, -s),
				gem_center + Vector2(s * 0.72, 0.0),
				gem_center + Vector2(0.0, s),
				gem_center + Vector2(-s * 0.72, 0.0),
			])
			var gem_outline: PackedVector2Array = PackedVector2Array([
				gem_poly[0],
				gem_poly[1],
				gem_poly[2],
				gem_poly[3],
				gem_poly[0],
			])
			canvas.draw_colored_polygon(gem_poly, Color(0.96, 1.0, 0.90, 0.60 * alpha_scale))
			canvas.draw_polyline(gem_outline, Color(0.05, 0.11, 0.16, 0.82 * alpha_scale), 1.6, true)
		_:
			pass

func _draw_upgrade_badge(canvas: Node2D, tile_rect: Rect2, tile_type: String, tier: int, modulate: Color) -> void:
	var clamped_tier: int = clampi(tier, 1, Combat.MAX_UPGRADE_TIER)
	var accent: Color = _overlay_role_tint(tile_type).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.26)
	var alpha_scale: float = clampf(modulate.a, 0.0, 1.0)
	var center: Vector2 = tile_rect.position + tile_rect.size * 0.5
	var outer_radius: float = tile_size * (0.33 + float(clamped_tier - 1) * 0.02)
	var glow_alpha: float = (UPGRADE_RING_SHADOW_ALPHA + float(clamped_tier - 1) * 0.08) * alpha_scale
	var rim_alpha: float = (UPGRADE_RING_ALPHA - 0.12 + float(clamped_tier - 1) * 0.03) * alpha_scale
	canvas.draw_circle(center, outer_radius + tile_size * 0.05, Color(accent.r, accent.g, accent.b, glow_alpha * 0.20))
	canvas.draw_circle(center, outer_radius, Color(accent.r, accent.g, accent.b, glow_alpha * 0.12))
	canvas.draw_circle(center, outer_radius * 0.94, Color(0.98, 0.99, 1.0, rim_alpha * 0.20), false, maxf(1.0, tile_size * 0.035))
	canvas.draw_circle(center + Vector2(0.0, tile_size * 0.01), tile_size * 0.16, Color(1.0, 1.0, 1.0, UPGRADE_BADGE_FILL_ALPHA * 0.08 * alpha_scale))

	var dot_radius: float = maxf(1.9, tile_size * 0.068)
	var dot_spacing: float = maxf(4.0, tile_size * 0.18)
	var dot_center_y: float = tile_rect.position.y + tile_rect.size.y * 0.74
	var start_x: float = tile_rect.position.x + tile_rect.size.x * 0.5 - dot_spacing * (float(clamped_tier - 1) * 0.5)
	for i in range(clamped_tier):
		var dot_center: Vector2 = Vector2(start_x + dot_spacing * float(i), dot_center_y)
		canvas.draw_circle(dot_center, dot_radius + 1.0, Color(0.04, 0.07, 0.10, UPGRADE_TIER_DOT_SHADOW_ALPHA * alpha_scale))
		canvas.draw_circle(dot_center, dot_radius, Color(0.98, 0.97, 0.88, UPGRADE_TIER_DOT_FILL_ALPHA * alpha_scale))
		canvas.draw_circle(dot_center, maxf(0.9, dot_radius * 0.48), Color(accent.r, accent.g, accent.b, minf(1.0, UPGRADE_BADGE_FILL_ALPHA + 0.14) * alpha_scale))

func _enhance_ui_icon_image(source: Image) -> Image:
	var image: Image = source.duplicate()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var width: int = image.get_width()
	var height: int = image.get_height()
	var out: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(height):
		for x in range(width):
			var px: Color = image.get_pixel(x, y)
			if px.a > 0.04:
				var icon_alpha: float = 1.0 if px.a >= 0.20 else clampf(0.88 + px.a * 0.35, 0.88, 1.0)
				out.set_pixel(
					x,
					y,
					Color(
						clampf(px.r * 1.08, 0.0, 1.0),
						clampf(px.g * 1.08, 0.0, 1.0),
						clampf(px.b * 1.08, 0.0, 1.0),
						icon_alpha
					)
				)
				continue

			var edge_alpha: float = 0.0
			for oy in range(-1, 2):
				var ny: int = y + oy
				if ny < 0 or ny >= height:
					continue
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var nx: int = x + ox
					if nx < 0 or nx >= width:
						continue
					edge_alpha = maxf(edge_alpha, image.get_pixel(nx, ny).a)

			if edge_alpha > 0.18:
				out.set_pixel(x, y, Color(0.05, 0.10, 0.14, clampf(0.58 + edge_alpha * 0.30, 0.58, 0.90)))
	return out

func _tier_brightness_lerp(tier: int) -> float:
	var bonus_steps: int = maxi(0, tier - Combat.SPECIALIZATION_TIER)
	return clampf(float(bonus_steps) * 0.08, 0.0, 0.18)

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

func _draw_heart_icon(canvas: Node2D, center: Vector2, radius: float, fill_color: Color, line_color: Color) -> void:
	var r: float = maxf(2.0, radius)
	var left: Vector2 = center + Vector2(-r * 0.56, -r * 0.28)
	var right: Vector2 = center + Vector2(r * 0.56, -r * 0.28)
	var lobe_radius: float = r * 0.58
	canvas.draw_circle(left, lobe_radius, fill_color)
	canvas.draw_circle(right, lobe_radius, fill_color)

	var fill_poly: PackedVector2Array = PackedVector2Array([
		center + Vector2(-r * 1.12, -r * 0.02),
		center + Vector2(r * 1.12, -r * 0.02),
		center + Vector2(0.0, r * 1.46),
	])
	canvas.draw_colored_polygon(fill_poly, fill_color)

	var outline_poly: PackedVector2Array = PackedVector2Array([
		center + Vector2(-r * 1.02, 0.0),
		center + Vector2(0.0, r * 1.40),
		center + Vector2(r * 1.02, 0.0),
	])
	canvas.draw_circle(left, lobe_radius, line_color, false, 1.4)
	canvas.draw_circle(right, lobe_radius, line_color, false, 1.4)
	canvas.draw_polyline(outline_poly, line_color, 1.5, true)

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
		if not state.are_hostile(owner, int(block["owner"])):
			continue
		var t: Vector2i = block["pos"]
		var dist: int = absi(origin.x - t.x) + absi(origin.y - t.y)
		if dist <= max_range and dist < best_dist:
			best_dist = dist
			best_tile = t
	if not state.are_hostile(owner, GameState.PLAYER_ID) and state.door_hp > 0:
		var door_dist: int = absi(origin.x - state.door_tile.x) + absi(origin.y - state.door_tile.y)
		if door_dist <= max_range and door_dist < best_dist:
			best_dist = door_dist
			best_tile = state.door_tile
	return best_tile

func _base_key(mask: int, frame: int, variant: int = 0) -> String:
	# Atlas contract: keys must match tools/generate_atlas.py output.
	# Keep fallback compatibility key for older atlases.
	var normalized_variant: int = int(posmod(variant, BASE_VARIANTS))
	var with_variant: String = "slime_base_neutral_m%02d_v%d_f%d" % [mask, normalized_variant, frame]
	if atlas.has_sprite(with_variant):
		return with_variant
	return "slime_base_neutral_m%02d_f%d" % [mask, frame]

func _overlay_key(tile_type: String, gather_infused: bool) -> String:
	# Atlas contract: overlay naming is consumed by renderer + UI icon pipeline.
	if tile_type == "basic":
		return ""
	if tile_type == "gather" and gather_infused:
		return "slime_overlay_gather_infused"
	if not TYPE_ORDER.has(tile_type):
		tile_type = "basic"
	return "slime_overlay_%s" % tile_type

func _owner_tint(state: GameState, owner_id: int) -> Color:
	if owner_id == GameState.PLAYER_ID:
		return PLAYER_TINT

	var is_hostile: bool = state.are_hostile(GameState.PLAYER_ID, owner_id)
	if not is_hostile:
		var ally_count: int = ALLY_TINTS.size()
		var ally_idx: int = _owner_palette_index(state, owner_id, false, ally_count)
		return ALLY_TINTS[ally_idx]

	var count: int = ENEMY_TINTS.size()
	var idx: int = _owner_palette_index(state, owner_id, true, count)
	return ENEMY_TINTS[idx]

func _owner_palette_index(state: GameState, owner_id: int, hostile_to_player: bool, palette_size: int) -> int:
	if palette_size <= 0:
		return 0
	var active_ids: Array[int] = _active_owner_ids_for_palette(state, hostile_to_player)
	if active_ids.is_empty():
		return int(posmod(owner_id, palette_size))
	var idx: int = active_ids.find(owner_id)
	if idx < 0:
		idx = active_ids.size()
	return int(posmod(idx, palette_size))

func _active_owner_ids_for_palette(state: GameState, hostile_to_player: bool) -> Array[int]:
	var ids: Array[int] = []
	for owner_variant in state.players.keys():
		var owner_id: int = int(owner_variant)
		if owner_id == GameState.PLAYER_ID:
			continue
		var player_data: Dictionary = state.players.get(owner_id, {})
		if not bool(player_data.get("alive", true)):
			continue
		if state.get_owner_blocks(owner_id).is_empty():
			continue
		var is_hostile: bool = state.are_hostile(GameState.PLAYER_ID, owner_id)
		if is_hostile != hostile_to_player:
			continue
		ids.append(owner_id)
	ids.sort()
	return ids

func _overlay_role_tint(tile_type: String) -> Color:
	match tile_type:
		"gather":
			return Color(0.92, 1.0, 0.72, 1.0)
		"defense":
			return Color(0.26, 0.56, 0.56, 1.0)
		"melee":
			return Color(0.26, 0.56, 0.92, 1.0)
		"ranged":
			return Color(0.84, 1.0, 1.0, 1.0)
		_:
			return Color(0.92, 0.96, 0.92, 1.0)

func _overlay_opacity(tile_type: String) -> float:
	match tile_type:
		"basic":
			return 0.36
		"gather":
			return 1.0
		"defense":
			return 1.0
		"melee":
			return 1.0
		"ranged":
			return 1.0
		_:
			return 0.94

func _overlay_rect(tile_rect: Rect2, tile_type: String) -> Rect2:
	if tile_type == "basic":
		return tile_rect
	return tile_rect.grow(maxf(2.0, tile_size * 0.08))

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

func _tile_variant(tile: Vector2i) -> int:
	var seed: int = int(tile.x * 92821) ^ int(tile.y * 68917)
	return int(posmod(absi(seed), BASE_VARIANTS))

func _tile_noise(x: int, y: int, level_index: int) -> int:
	var n: int = int(x * 73856093) ^ int(y * 19349663) ^ int(level_index * 83492791)
	return absi(n) % 97

func _is_frontline_visual(state: GameState, owner: int, tile: Vector2i) -> bool:
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var other: Dictionary = state.get_block_at(tile + step)
		if other.is_empty():
			continue
		if state.are_hostile(owner, int(other.get("owner", 0))):
			return true
	return false

func _tile_has_queued_player_action(state: GameState, tile: Vector2i, queued_actions: Array) -> bool:
	for action in queued_actions:
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			if action.get("target", Vector2i(-1, -1)) == tile:
				return true
		elif kind == "convert_tile":
			var block_id: int = int(action.get("block_id", -1))
			if block_id >= 0 and state.blocks.has(block_id):
				if state.blocks[block_id]["pos"] == tile:
					return true
		elif kind == "upgrade_tile":
			var upgrade_block_id: int = int(action.get("block_id", -1))
			if upgrade_block_id >= 0 and state.blocks.has(upgrade_block_id):
				if state.blocks[upgrade_block_id]["pos"] == tile:
					return true
	return false
