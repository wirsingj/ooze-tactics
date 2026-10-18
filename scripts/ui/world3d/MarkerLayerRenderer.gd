extends RefCounted
class_name MarkerLayerRenderer

const PREVIEW_MARKER_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha, unshaded;

uniform vec4 base_color : source_color = vec4(0.5, 1.0, 0.7, 0.85);
uniform float pulse_speed = 2.4;
uniform float pulse_amp = 0.38;
uniform float alpha_scale = 1.0;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.x * 6.0 + UV.y * 5.0);
	vec3 col = base_color.rgb * (0.74 + pulse * pulse_amp);
	ALBEDO = col;
	EMISSION = col * (0.20 + pulse * 0.30);
	ALPHA = base_color.a * alpha_scale * (0.78 + pulse * 0.22);
}
"""

var marker_material_cache: Dictionary = {}
var counters: Dictionary = {}

const PREVIEW_RING_CLEARANCE: float = 0.105
const PREVIEW_GHOST_CLEARANCE: float = 0.285
const QUEUED_RING_CLEARANCE: float = 0.095
const QUEUED_GHOST_CLEARANCE: float = 0.245
const INVALID_CROSS_CLEARANCE: float = 0.155
const TILE_MARKER_MIN_CLEARANCE: float = 0.070

func extract_queued_tiles(state: GameState, queued_actions: Array) -> Dictionary:
	var tiles: Dictionary = {}
	if state == null:
		return tiles
	for action in queued_actions:
		var kind: String = String(action.get("type", ""))
		if kind == "place_tile":
			var place_tile: Vector2i = action.get("target", Vector2i(-1, -1))
			if place_tile != Vector2i(-1, -1):
				tiles[_tile_key(place_tile)] = place_tile
		elif kind == "convert_tile" or kind == "upgrade_tile":
			var block_id: int = int(action.get("block_id", -1))
			if state.blocks.has(block_id):
				var existing_tile: Vector2i = state.blocks[block_id].get("pos", Vector2i(-1, -1))
				if existing_tile != Vector2i(-1, -1):
					tiles[_tile_key(existing_tile)] = existing_tile
	return tiles

func make_marker_stamp(
	state: GameState,
	selected_tile: Vector2i,
	hovered_tile: Vector2i,
	queued_tiles: Dictionary,
	queued_actions: Array,
	hover_preview_action: Dictionary,
	hover_invalid_reason: String,
	valid_place_targets: Array = [],
	enemy_intent_actions: Array = []
) -> String:
	var queued_keys: Array = queued_tiles.keys()
	queued_keys.sort()
	var queued_joined: String = ""
	for key_variant in queued_keys:
		if not queued_joined.is_empty():
			queued_joined += ","
		queued_joined += String(key_variant)
	var preview_tile: Vector2i = preview_target_tile(state, hover_preview_action)
	var preview_key: String = _tile_key(preview_tile)
	var preview_kind: String = String(hover_preview_action.get("type", "")) if not hover_preview_action.is_empty() else ""
	var preview_role: String = String(hover_preview_action.get("tile_type", hover_preview_action.get("to_type", ""))) if not hover_preview_action.is_empty() else ""
	var queued_sig: String = ""
	for action in queued_actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = queued_action_tile_role(state, action)
		if not queued_sig.is_empty():
			queued_sig += ","
		queued_sig += "%s:%s" % [_tile_key(info.get("tile", Vector2i(-1, -1))), String(info.get("role", "basic"))]
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [_tile_key(selected_tile), _tile_key(hovered_tile), queued_joined, preview_key, preview_kind, preview_role + ":" + hover_invalid_reason, queued_sig, str(valid_place_targets), str(enemy_intent_actions)]

func rebuild_markers(
	root: Node3D,
	state: GameState,
	tile_world_size: float,
	board_min: Vector3,
	ground_tops: Dictionary,
	selected_tile: Vector2i,
	hovered_tile: Vector2i,
	queued_tiles: Dictionary,
	queued_actions: Array,
	hover_preview_action: Dictionary,
	hover_invalid_reason: String,
	valid_place_targets: Array = [],
	enemy_intent_actions: Array = []
) -> void:
	_clear_children(root)
	if state == null or root == null:
		return
	for tile in valid_place_targets:
		if state.is_inside(tile):
			_add_tile_marker(root, state, tile_world_size, board_min, ground_tops, tile, Color(0.25, 1.0, 0.45, 0.48), 0.08)
	for action in enemy_intent_actions:
		var tile: Vector2i = preview_target_tile(state, action)
		if state.is_inside(tile):
			_add_tile_marker(root, state, tile_world_size, board_min, ground_tops, tile, Color(1.0, 0.28, 0.38, 0.65), 0.12)
	_add_queued_preview_markers(root, state, tile_world_size, board_min, ground_tops, queued_actions)
	if not hover_preview_action.is_empty():
		var preview_tile: Vector2i = preview_target_tile(state, hover_preview_action)
		if state.is_inside(preview_tile):
			var preview_role: String = String(hover_preview_action.get("tile_type", hover_preview_action.get("to_type", "basic")))
			var preview_ok: bool = hover_invalid_reason.is_empty()
			_add_preview_marker(root, state, tile_world_size, board_min, ground_tops, preview_tile, preview_role, preview_ok)
			if not preview_ok:
				_add_invalid_preview_cross(root, tile_world_size, board_min, ground_tops, preview_tile)
	if hovered_tile != Vector2i(-1, -1) and state.is_inside(hovered_tile):
		_add_tile_marker(root, state, tile_world_size, board_min, ground_tops, hovered_tile, Color(0.88, 0.96, 1.0, 0.42), 0.026)
	if selected_tile != Vector2i(-1, -1) and state.is_inside(selected_tile):
		_add_tile_marker(root, state, tile_world_size, board_min, ground_tops, selected_tile, Color(1.0, 0.93, 0.54, 0.52), 0.034)
	for key in queued_tiles.keys():
		var tile: Vector2i = queued_tiles[key]
		if state.is_inside(tile):
			_add_tile_marker(root, state, tile_world_size, board_min, ground_tops, tile, Color(0.54, 0.98, 0.76, 0.30), 0.019)

func preview_target_tile(state: GameState, action: Dictionary) -> Vector2i:
	if state == null or action.is_empty():
		return Vector2i(-1, -1)
	var action_type: String = String(action.get("type", ""))
	if action_type == "place_tile":
		return action.get("target", Vector2i(-1, -1))
	if action_type == "convert_tile" or action_type == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if state.blocks.has(block_id):
			return state.blocks[block_id].get("pos", Vector2i(-1, -1))
	return Vector2i(-1, -1)

func queued_action_tile_role(state: GameState, action: Dictionary) -> Dictionary:
	var result: Dictionary = {"tile": Vector2i(-1, -1), "role": "basic"}
	if state == null:
		return result
	var action_type: String = String(action.get("type", ""))
	if action_type == "place_tile":
		result["tile"] = action.get("target", Vector2i(-1, -1))
		result["role"] = String(action.get("tile_type", "basic"))
		return result
	if action_type == "convert_tile" or action_type == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if state.blocks.has(block_id):
			result["tile"] = state.blocks[block_id].get("pos", Vector2i(-1, -1))
			result["role"] = String(action.get("to_type", state.blocks[block_id].get("tile_type", "basic")))
	return result

func get_performance_counters() -> Dictionary:
	var out: Dictionary = counters.duplicate(true)
	out["marker_material_cache_entries"] = marker_material_cache.size()
	return out

func reset_performance_counters() -> void:
	counters.clear()

func _add_queued_preview_markers(
	root: Node3D,
	state: GameState,
	tile_world_size: float,
	board_min: Vector3,
	ground_tops: Dictionary,
	queued_actions: Array
) -> void:
	if state == null or queued_actions.is_empty():
		return
	var seen: Dictionary = {}
	for action in queued_actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = queued_action_tile_role(state, action)
		var tile: Vector2i = info.get("tile", Vector2i(-1, -1))
		var role: String = String(info.get("role", "basic"))
		if not state.is_inside(tile):
			continue
		var key: String = _tile_key(tile)
		if seen.has(key):
			continue
		seen[key] = true
		_add_preview_marker(root, state, tile_world_size, board_min, ground_tops, tile, role, true, true)

func _preview_material(color: Color, is_queued: bool = false) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = PREVIEW_MARKER_SHADER_CODE
	mat.shader = shader
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("pulse_speed", 1.6 if is_queued else 2.8)
	mat.set_shader_parameter("pulse_amp", 0.24 if is_queued else 0.40)
	mat.set_shader_parameter("alpha_scale", 0.80 if is_queued else 1.0)
	return mat

func _add_preview_marker(
	root: Node3D,
	_state: GameState,
	tile_world_size: float,
	board_min: Vector3,
	ground_tops: Dictionary,
	tile: Vector2i,
	role: String,
	is_valid: bool,
	is_queued: bool = false
) -> void:
	var top: float = _tile_ground_top(tile, ground_tops)
	var center: Vector3 = _tile_world_position(tile, board_min, tile_world_size)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = tile_world_size * 0.36
	ring_mesh.outer_radius = tile_world_size * 0.42
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	ring.position = center + Vector3(0.0, top + (QUEUED_RING_CLEARANCE if is_queued else PREVIEW_RING_CLEARANCE), 0.0)
	var preview_col: Color = Color(0.52, 1.0, 0.76, 0.90) if is_valid else Color(1.0, 0.32, 0.36, 0.90)
	if is_queued:
		preview_col = preview_col.lerp(Color(0.48, 0.86, 1.0, 0.88), 0.45)
	ring.material_override = _preview_material(preview_col, is_queued)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)

	var ghost: MeshInstance3D = MeshInstance3D.new()
	ghost.mesh = _preview_role_mesh(role)
	ghost.material_override = _preview_material(preview_col, is_queued)
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.position = center + Vector3(0.0, top + (QUEUED_GHOST_CLEARANCE if is_queued else PREVIEW_GHOST_CLEARANCE), 0.0)
	ghost.scale = Vector3(0.50, 0.50, 0.50) if is_queued else Vector3(0.58, 0.58, 0.58)
	root.add_child(ghost)

func _add_invalid_preview_cross(
	root: Node3D,
	tile_world_size: float,
	board_min: Vector3,
	ground_tops: Dictionary,
	tile: Vector2i
) -> void:
	var top: float = _tile_ground_top(tile, ground_tops)
	var center: Vector3 = _tile_world_position(tile, board_min, tile_world_size)
	for i in range(2):
		var slash: MeshInstance3D = MeshInstance3D.new()
		var slash_mesh: BoxMesh = BoxMesh.new()
		slash_mesh.size = Vector3(tile_world_size * 0.58, 0.03, 0.08)
		slash.mesh = slash_mesh
		slash.position = center + Vector3(0.0, top + INVALID_CROSS_CLEARANCE, 0.0)
		slash.rotation_degrees = Vector3(0.0, 45.0 if i == 0 else -45.0, 0.0)
		slash.material_override = _preview_material(Color(1.0, 0.26, 0.22, 0.92), false)
		slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(slash)

func _preview_role_mesh(role: String) -> PrimitiveMesh:
	match role:
		"melee":
			var shard: PrismMesh = PrismMesh.new()
			shard.left_to_right = 0.60
			shard.size = Vector3(0.22, 0.46, 0.18)
			return shard
		"ranged":
			var orb: SphereMesh = SphereMesh.new()
			orb.radius = 0.16
			orb.height = 0.28
			orb.radial_segments = 10
			orb.rings = 6
			return orb
		"defense":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.20
			cyl.bottom_radius = 0.24
			cyl.height = 0.24
			cyl.radial_segments = 12
			return cyl
		"gather":
			var cap: CapsuleMesh = CapsuleMesh.new()
			cap.radius = 0.11
			cap.height = 0.30
			cap.radial_segments = 10
			cap.rings = 6
			return cap
		_:
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.14
			sphere.height = 0.24
			sphere.radial_segments = 10
			sphere.rings = 6
			return sphere

func _add_tile_marker(
	root: Node3D,
	_state: GameState,
	tile_world_size: float,
	board_min: Vector3,
	ground_tops: Dictionary,
	tile: Vector2i,
	color: Color,
	y_offset: float
) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	# An open frame preserves floor/role visibility instead of painting a disc.
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = tile_world_size * 0.39
	mesh.outer_radius = tile_world_size * 0.43
	mesh.rings = 32
	mesh.ring_segments = 6
	marker.mesh = mesh
	marker.scale.y = 0.35
	var top: float = _tile_ground_top(tile, ground_tops)
	marker.position = _tile_world_position(tile, board_min, tile_world_size) + Vector3(0.0, top + maxf(y_offset, TILE_MARKER_MIN_CLEARANCE), 0.0)
	marker.material_override = _marker_material(color)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(marker)

func _marker_material(color: Color) -> StandardMaterial3D:
	var key: String = "%0.3f|%0.3f|%0.3f|%0.3f" % [color.r, color.g, color.b, color.a]
	if marker_material_cache.has(key):
		_counter_increment("marker_material_cache_hits")
		return marker_material_cache[key]
	_counter_increment("marker_material_builds")
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 0.32
	marker_material_cache[key] = mat
	return mat

func _tile_world_position(tile: Vector2i, board_min: Vector3, tile_world_size: float) -> Vector3:
	return board_min + Vector3(
		(float(tile.x) + 0.5) * tile_world_size,
		0.0,
		(float(tile.y) + 0.5) * tile_world_size
	)

func _tile_ground_top(tile: Vector2i, ground_tops: Dictionary) -> float:
	return float(ground_tops.get(_tile_key(tile), 0.0))

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.free()

func _counter_increment(key: String, amount: int = 1) -> void:
	counters[key] = int(counters.get(key, 0)) + amount

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
