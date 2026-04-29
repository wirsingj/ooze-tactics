extends RefCounted
class_name DynamicOozeRenderer

const OOZE_MASK_SCALE: int = 16
const OOZE_MASK_SMOOTH_PASSES: int = 2
const OOZE_SURFACE_OFFSET: float = 0.090
const OOZE_BASE_SURFACE_OFFSET: float = 0.165
const OOZE_GROWTH_BASE_OFFSET: float = 0.180
const OOZE_BASE_THICKNESS: float = 0.30

func build_owner_layers(
	context,
	dynamic_root: Node3D,
	state: GameState,
	tile_world_size: float,
	camera_base_target: Vector3,
	owner_mask_texture_cache: Dictionary,
	active_mask_cache_keys: Dictionary,
	ooze_surface_mesh_cache: Dictionary,
	rendered_owner_tiles_by_owner: Dictionary,
	growth_anim_entries: Array,
	owner_id: int,
	blocks: Array,
	enable_fragmented_details: bool
) -> void:
	_build_owner_ooze(context, dynamic_root, state, tile_world_size, camera_base_target, owner_mask_texture_cache, active_mask_cache_keys, ooze_surface_mesh_cache, rendered_owner_tiles_by_owner, owner_id, blocks)
	if enable_fragmented_details:
		_build_owner_blob_caps(context, dynamic_root, state, owner_id, blocks)
		_build_owner_micro_bubbles(context, dynamic_root, state, owner_id, blocks)
		_build_owner_edge_beads(context, dynamic_root, state, owner_id, blocks)
	_build_specialization_markers(context, dynamic_root, state, tile_world_size, growth_anim_entries, owner_id, blocks)
	_build_heart_markers(context, dynamic_root, state, tile_world_size, growth_anim_entries, owner_id, blocks)

func build_owner_mask_texture(
	context,
	state: GameState,
	tile_set: Dictionary,
	owner_mask_texture_cache: Dictionary,
	active_mask_cache_keys: Dictionary = {}
) -> Texture2D:
	if state == null:
		return null
	var cache_key: String = _owner_mask_cache_key(context, state, tile_set)
	if active_mask_cache_keys != null:
		active_mask_cache_keys[cache_key] = true
	if owner_mask_texture_cache.has(cache_key):
		context._perf_increment("mask_cache_hits")
		return owner_mask_texture_cache[cache_key] as Texture2D
	context._perf_increment("mask_rebuilds")
	var mask_total_start: int = Time.get_ticks_usec()
	var mask_scale: int = OOZE_MASK_SCALE
	var img_w: int = maxi(8, state.width * mask_scale)
	var img_h: int = maxi(8, state.height * mask_scale)
	var image: Image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var bridge_half: int = maxi(1, int(round(float(mask_scale) * 0.50)))
	var tile_pad: int = 0
	for tile_key in tile_set.keys():
		var tile: Vector2i = tile_set[tile_key]
		var wall_adjacent: bool = _tile_touches_blocked_neighbor(state, tile)
		var wall_shrink: int = 1 if wall_adjacent else 0
		var px0: int = tile.x * mask_scale + tile_pad + wall_shrink
		var py0: int = tile.y * mask_scale + tile_pad + wall_shrink
		var px1: int = (tile.x + 1) * mask_scale - 1 - tile_pad - wall_shrink
		var py1: int = (tile.y + 1) * mask_scale - 1 - tile_pad - wall_shrink
		_stamp_rect(image, px0, py0, px1, py1, 1.0)
		var cx: int = tile.x * mask_scale + int(floor(float(mask_scale) * 0.5))
		var cy: int = tile.y * mask_scale + int(floor(float(mask_scale) * 0.5))
		var right: Vector2i = tile + Vector2i.RIGHT
		var down: Vector2i = tile + Vector2i.DOWN
		if tile_set.has(context._tile_key(right)):
			var cx2: int = right.x * mask_scale + int(floor(float(mask_scale) * 0.5))
			_stamp_rect(image, mini(cx, cx2), cy - bridge_half, maxi(cx, cx2), cy + bridge_half, 1.0)
		if tile_set.has(context._tile_key(down)):
			var cy2: int = down.y * mask_scale + int(floor(float(mask_scale) * 0.5))
			_stamp_rect(image, cx - bridge_half, mini(cy, cy2), cx + bridge_half, maxi(cy, cy2), 1.0)

	var cluster_start: int = Time.get_ticks_usec()
	var clusters: Array = _connected_owner_clusters(context, tile_set)
	context._perf_record_time("profile_mask_cluster_bfs", cluster_start)
	var mask_bounds: Rect2i = _tile_set_pixel_bounds(tile_set, mask_scale, image, 2)
	var smoothing_start: int = Time.get_ticks_usec()
	_dilate_mask_region(image, mask_bounds)
	for _i in range(OOZE_MASK_SMOOTH_PASSES):
		_smooth_mask_region(image, mask_bounds)
	context._perf_record_time("profile_mask_smoothing", smoothing_start)
	var clear_start: int = Time.get_ticks_usec()
	_clear_unowned_tiles_from_mask(context, state, image, mask_scale, tile_set)
	context._perf_record_time("profile_mask_clear_unowned", clear_start)
	var carve_start: int = Time.get_ticks_usec()
	_apply_cluster_organic_silhouette(context, state, image, mask_scale, tile_set, clusters)
	context._perf_record_time("profile_mask_organic_carve", carve_start)
	var wall_carve_start: int = Time.get_ticks_usec()
	_carve_blocked_tiles_from_mask(state, image, mask_scale)
	_carve_wall_contact_moat(state, image, mask_scale)
	context._perf_record_time("profile_mask_wall_carve", wall_carve_start)
	var texture_start: int = Time.get_ticks_usec()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	context._perf_record_time("profile_mask_texture_upload", texture_start)
	owner_mask_texture_cache[cache_key] = texture
	context._perf_record_time("profile_mask_total", mask_total_start)
	return texture

func validate_ooze_wall_blocking(
	context,
	state: GameState,
	owner_mask_texture_cache: Dictionary,
	alpha_threshold: float = 0.02
) -> Dictionary:
	if state == null:
		return {"ok": true, "violations": 0, "samples": []}
	var owner_tiles: Dictionary = {}
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile) or state.is_blocked(tile):
			continue
		var owner_id: int = int(block.get("owner", 0))
		if not owner_tiles.has(owner_id):
			owner_tiles[owner_id] = {}
		var bucket: Dictionary = owner_tiles[owner_id]
		bucket[context._tile_key(tile)] = tile
		owner_tiles[owner_id] = bucket

	var violations: int = 0
	var samples: Array = []
	for owner_variant in owner_tiles.keys():
		var owner_id: int = int(owner_variant)
		var tile_set: Dictionary = owner_tiles[owner_id]
		if tile_set.is_empty():
			continue
		var mask_tex: Texture2D = build_owner_mask_texture(context, state, tile_set, owner_mask_texture_cache)
		if mask_tex == null:
			continue
		var img: Image = mask_tex.get_image()
		if img == null or img.is_empty():
			continue
		var mask_scale: int = OOZE_MASK_SCALE
		var w: int = img.get_width()
		var h: int = img.get_height()
		for key_variant in state.wall_tiles.keys():
			var wall_tile: Vector2i = context._tile_from_key(String(key_variant))
			if not state.is_inside(wall_tile):
				continue
			var px0: int = clampi(wall_tile.x * mask_scale, 0, w - 1)
			var py0: int = clampi(wall_tile.y * mask_scale, 0, h - 1)
			var px1: int = clampi((wall_tile.x + 1) * mask_scale - 1, 0, w - 1)
			var py1: int = clampi((wall_tile.y + 1) * mask_scale - 1, 0, h - 1)
			var tile_has_violation: bool = false
			for py in range(py0, py1 + 1):
				for px in range(px0, px1 + 1):
					var alpha: float = img.get_pixel(px, py).a
					if alpha > alpha_threshold:
						violations += 1
						if samples.size() < 10:
							samples.append({
								"owner": owner_id,
								"wall_tile": [wall_tile.x, wall_tile.y],
								"alpha": alpha,
							})
						tile_has_violation = true
						break
				if tile_has_violation:
					break
	return {
		"ok": violations == 0,
		"violations": violations,
		"samples": samples,
	}

func validate_territory_visual_alignment(state: GameState, rendered_owner_tiles_by_owner: Dictionary) -> Dictionary:
	if state == null:
		return {"ok": true, "missing_tiles": {}, "extra_tiles": {}}
	var expected_by_owner: Dictionary = {}
	var blocked_owned_tiles: Array = []
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile):
			continue
		if state.is_blocked(tile):
			blocked_owned_tiles.append(_tile_key(tile))
			continue
		var owner_id: int = int(block.get("owner", 0))
		if not expected_by_owner.has(owner_id):
			expected_by_owner[owner_id] = {}
		var bucket: Dictionary = expected_by_owner[owner_id]
		bucket[_tile_key(tile)] = true
		expected_by_owner[owner_id] = bucket

	var missing: Dictionary = {}
	var extra: Dictionary = {}
	for owner_variant in expected_by_owner.keys():
		var owner_id: int = int(owner_variant)
		var expected: Dictionary = expected_by_owner[owner_id]
		var rendered: Dictionary = rendered_owner_tiles_by_owner.get(owner_id, {})
		for key_variant in expected.keys():
			var key: String = String(key_variant)
			if not rendered.has(key):
				if not missing.has(owner_id):
					missing[owner_id] = []
				missing[owner_id].append(key)
	for owner_variant in rendered_owner_tiles_by_owner.keys():
		var owner_id: int = int(owner_variant)
		var rendered: Dictionary = rendered_owner_tiles_by_owner[owner_id]
		var expected: Dictionary = expected_by_owner.get(owner_id, {})
		for key_variant in rendered.keys():
			var key: String = String(key_variant)
			if not expected.has(key):
				if not extra.has(owner_id):
					extra[owner_id] = []
				extra[owner_id].append(key)
	return {
		"ok": missing.is_empty() and extra.is_empty() and blocked_owned_tiles.is_empty(),
		"missing_tiles": missing,
		"extra_tiles": extra,
		"blocked_owned_tiles": blocked_owned_tiles,
	}

func validate_ooze_layering_contract(context, state: GameState) -> Dictionary:
	if state == null:
		return {"ok": true, "violations": []}
	var violations: Array = []
	var min_base_clearance: float = 0.040
	var min_growth_clearance: float = 0.005
	for block_variant in state.blocks.values():
		var block: Dictionary = block_variant
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile) or state.is_blocked(tile):
			continue
		var floor_top: float = context._tile_floor_top(tile)
		var ooze_y: float = floor_top + OOZE_BASE_SURFACE_OFFSET
		if ooze_y < floor_top + min_base_clearance:
			violations.append({
				"tile": [tile.x, tile.y],
				"kind": "base_ooze_below_clearance",
				"floor_top": floor_top,
				"ooze_y": ooze_y,
			})
		var role: String = String(block.get("tile_type", "basic"))
		if bool(block.get("is_heart", false)) or role != "basic":
			var growth_y: float = floor_top + OOZE_GROWTH_BASE_OFFSET
			if growth_y < ooze_y + min_growth_clearance:
				violations.append({
					"tile": [tile.x, tile.y],
					"kind": "growth_below_ooze_clearance",
					"floor_top": floor_top,
					"ooze_y": ooze_y,
					"growth_y": growth_y,
				})
	return {
		"ok": violations.is_empty(),
		"violations": violations,
		"base_clearance": OOZE_BASE_SURFACE_OFFSET,
		"growth_clearance": OOZE_GROWTH_BASE_OFFSET - OOZE_BASE_SURFACE_OFFSET,
	}

func _build_owner_ooze(
	context,
	dynamic_root: Node3D,
	state: GameState,
	tile_world_size: float,
	camera_base_target: Vector3,
	owner_mask_texture_cache: Dictionary,
	active_mask_cache_keys: Dictionary,
	ooze_surface_mesh_cache: Dictionary,
	rendered_owner_tiles_by_owner: Dictionary,
	owner_id: int,
	blocks: Array
) -> void:
	if blocks.is_empty():
		return

	var tile_set: Dictionary = {}
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if state.is_inside(tile) and not state.is_blocked(tile):
			tile_set[context._tile_key(tile)] = tile
	if tile_set.is_empty():
		return
	rendered_owner_tiles_by_owner[owner_id] = tile_set.duplicate()
	var mask_tex: Texture2D = build_owner_mask_texture(context, state, tile_set, owner_mask_texture_cache, active_mask_cache_keys)
	if mask_tex == null:
		return

	var surface_start: int = Time.get_ticks_usec()
	var quad: MeshInstance3D = MeshInstance3D.new()
	var board_width: float = float(state.width) * tile_world_size
	var board_height: float = float(state.height) * tile_world_size
	quad.mesh = _cached_ooze_surface_mesh(context, ooze_surface_mesh_cache, board_width, board_height, OOZE_BASE_SURFACE_OFFSET, 2.6)
	quad.position = camera_base_target
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var ooze_mat: ShaderMaterial = context._owner_pool_material(owner_id, mask_tex).duplicate(true)
	ooze_mat.set_shader_parameter("owner_color", context._owner_ooze_tint(owner_id))
	ooze_mat.set_shader_parameter("pulse_speed", 0.24)
	ooze_mat.set_shader_parameter("bubble_strength", 0.0011)
	ooze_mat.set_shader_parameter("emission_strength", 0.030)
	ooze_mat.set_shader_parameter("detail_scale", 4.9)
	ooze_mat.set_shader_parameter("body_thickness", 0.040)
	ooze_mat.set_shader_parameter("lip_thickness", 0.046)
	ooze_mat.set_shader_parameter("flow_scale", 1.16)
	ooze_mat.set_shader_parameter("flow_speed", 0.005)
	ooze_mat.set_shader_parameter("flow_normal_strength", 0.28)
	ooze_mat.set_shader_parameter("edge_darkening_strength", 0.26)
	ooze_mat.set_shader_parameter("contact_darkening_strength", 0.18)
	ooze_mat.set_shader_parameter("clearcoat_strength", 0.46)
	ooze_mat.set_shader_parameter("specular_strength", 0.34)
	ooze_mat.set_shader_parameter("rim_highlight_strength", 0.34)
	ooze_mat.set_shader_parameter("acid_glow_strength", 0.032)
	ooze_mat.set_shader_parameter("edge_wobble_strength", 0.072)
	ooze_mat.set_shader_parameter("inner_pulse_strength", 0.014)
	ooze_mat.set_shader_parameter("bubble_pop_strength", 0.28)
	quad.material_override = ooze_mat
	dynamic_root.add_child(quad)
	context._perf_record_time("profile_ooze_surface_setup", surface_start)
	var shell_start: int = Time.get_ticks_usec()
	_build_owner_volume_shell(context, dynamic_root, state, owner_id, blocks, tile_set)
	context._perf_record_time("profile_ooze_edge_shell", shell_start)
	var meniscus_start: int = Time.get_ticks_usec()
	_build_owner_meniscus(context, dynamic_root, state, tile_world_size, camera_base_target, ooze_surface_mesh_cache, owner_mask_texture_cache, owner_id, blocks, tile_set, mask_tex)
	context._perf_record_time("profile_ooze_meniscus", meniscus_start)
	var masses_start: int = Time.get_ticks_usec()
	_build_owner_tile_masses(context, dynamic_root, state, tile_world_size, ooze_surface_mesh_cache, owner_id, blocks, tile_set)
	context._perf_record_time("profile_ooze_tile_masses", masses_start)

func _build_owner_volume_shell(context, dynamic_root: Node3D, state: GameState, owner_id: int, blocks: Array, tile_set: Dictionary) -> void:
	if blocks.is_empty() or tile_set.is_empty():
		return
	var lobe_mesh: SphereMesh = SphereMesh.new()
	lobe_mesh.radius = 0.16
	lobe_mesh.height = 0.24
	lobe_mesh.radial_segments = 14
	lobe_mesh.rings = 7
	var lobe_transforms: Array[Transform3D] = []
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile):
			continue
		var center: Vector3 = context._tile_world_position(tile)
		var top: float = context._tile_floor_top(tile)
		var y_off: float = top + OOZE_BASE_SURFACE_OFFSET - OOZE_BASE_THICKNESS * 0.5 + 0.004
		if not tile_set.has(context._tile_key(tile + Vector2i.RIGHT)):
			_append_edge_lobes(context, lobe_transforms, tile, owner_id, center, y_off, Vector3.RIGHT)
		if not tile_set.has(context._tile_key(tile + Vector2i.LEFT)):
			_append_edge_lobes(context, lobe_transforms, tile, owner_id, center, y_off, Vector3.LEFT)
		if not tile_set.has(context._tile_key(tile + Vector2i.DOWN)):
			_append_edge_lobes(context, lobe_transforms, tile, owner_id, center, y_off, Vector3.BACK)
		if not tile_set.has(context._tile_key(tile + Vector2i.UP)):
			_append_edge_lobes(context, lobe_transforms, tile, owner_id, center, y_off, Vector3.FORWARD)
	if lobe_transforms.is_empty():
		return
	var shell_mat: StandardMaterial3D = context._ooze_shell_material(context._owner_ooze_tint(owner_id))
	dynamic_root.add_child(context._make_multimesh_instance(lobe_mesh, lobe_transforms, [], shell_mat, false))

func _append_edge_lobes(
	context,
	transforms: Array,
	tile: Vector2i,
	owner_id: int,
	center: Vector3,
	y_off: float,
	normal: Vector3
) -> void:
	var tangent: Vector3 = Vector3(normal.z, 0.0, -normal.x)
	var base_seed: int = context._tile_noise(tile.x + owner_id * 29 + int(normal.x * 7.0), tile.y + owner_id * 31 + int(normal.z * 11.0), 901)
	var count: int = 2 + int(context._noise01(base_seed + 3, base_seed + 5) > 0.72)
	for i in range(count):
		var along: float = -0.27 + float(i) * (0.54 / maxf(1.0, float(count - 1)))
		along += (context._noise01(base_seed + i * 17, base_seed + i * 19) - 0.5) * 0.12
		var inset: float = 0.260 + context._noise01(base_seed + i * 23, base_seed + 41) * 0.030
		var lift: float = 0.060 + context._noise01(base_seed + i * 29, base_seed + 47) * 0.026
		var sx: float = 0.92 + context._noise01(base_seed + i * 31, base_seed + 53) * 0.40
		var sy: float = 0.34 + context._noise01(base_seed + i * 37, base_seed + 59) * 0.18
		var sz: float = 0.64 + context._noise01(base_seed + i * 43, base_seed + 61) * 0.32
		var yaw: float = atan2(normal.x, normal.z) + (context._noise01(base_seed + i * 13, base_seed + 71) - 0.5) * 0.35
		var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(sx, sy, sz))
		var pos: Vector3 = center + normal * inset + tangent * along + Vector3(0.0, y_off + lift, 0.0)
		transforms.append(Transform3D(basis, pos))

func _build_owner_meniscus(
	context,
	dynamic_root: Node3D,
	state: GameState,
	tile_world_size: float,
	camera_base_target: Vector3,
	ooze_surface_mesh_cache: Dictionary,
	_owner_mask_texture_cache: Dictionary,
	owner_id: int,
	blocks: Array,
	tile_set: Dictionary,
	mask_tex: Texture2D
) -> void:
	if blocks.is_empty() or tile_set.is_empty() or mask_tex == null:
		return
	var quad: MeshInstance3D = MeshInstance3D.new()
	var board_width: float = float(state.width) * tile_world_size
	var board_height: float = float(state.height) * tile_world_size
	quad.mesh = _cached_ooze_surface_mesh(context, ooze_surface_mesh_cache, board_width, board_height, OOZE_BASE_SURFACE_OFFSET + 0.012, 2.2)
	quad.position = camera_base_target
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var meniscus: ShaderMaterial = context._owner_pool_material(owner_id, mask_tex).duplicate(true)
	meniscus.set_shader_parameter("owner_color", context._owner_ooze_tint(owner_id))
	meniscus.set_shader_parameter("pulse_speed", 0.22)
	meniscus.set_shader_parameter("bubble_strength", 0.0010)
	meniscus.set_shader_parameter("emission_strength", 0.028)
	meniscus.set_shader_parameter("detail_scale", 5.0)
	meniscus.set_shader_parameter("body_thickness", 0.026)
	meniscus.set_shader_parameter("lip_thickness", 0.050)
	meniscus.set_shader_parameter("flow_scale", 1.18)
	meniscus.set_shader_parameter("flow_speed", 0.006)
	meniscus.set_shader_parameter("flow_normal_strength", 0.28)
	meniscus.set_shader_parameter("edge_darkening_strength", 0.26)
	meniscus.set_shader_parameter("contact_darkening_strength", 0.18)
	meniscus.set_shader_parameter("clearcoat_strength", 0.42)
	meniscus.set_shader_parameter("specular_strength", 0.32)
	meniscus.set_shader_parameter("rim_highlight_strength", 0.38)
	meniscus.set_shader_parameter("acid_glow_strength", 0.034)
	meniscus.set_shader_parameter("edge_wobble_strength", 0.090)
	meniscus.set_shader_parameter("inner_pulse_strength", 0.010)
	meniscus.set_shader_parameter("bubble_pop_strength", 0.22)
	quad.material_override = meniscus
	dynamic_root.add_child(quad)

func _build_owner_tile_masses(
	context,
	dynamic_root: Node3D,
	state: GameState,
	tile_world_size: float,
	ooze_surface_mesh_cache: Dictionary,
	owner_id: int,
	blocks: Array,
	tile_set: Dictionary
) -> void:
	if blocks.is_empty() or tile_set.is_empty():
		return
	var mesh: ArrayMesh = _cached_viscous_tile_mesh(ooze_surface_mesh_cache)
	var transforms_by_role: Dictionary = {}
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile) or state.is_blocked(tile):
			continue
		var role: String = "core" if bool(block.get("is_heart", false)) else String(block.get("tile_type", "basic"))
		if role != "basic" and context._has_asset_scene(_growth_asset_key_for_role(role)):
			continue
		var direction: Vector3 = _tile_attack_direction(context, state, owner_id, tile)
		var yaw: float = atan2(direction.x, direction.z)
		var seed: int = context._tile_noise(tile.x + owner_id * 17, tile.y + owner_id * 23, 461)
		var neighbor_count: int = context._owned_neighbor_count(tile, tile_set)
		if role == "basic":
			var relief_gate: float = context._noise01(seed + 31, seed + 37)
			var required_gate: float = 0.70 if neighbor_count < 4 else 0.90
			if relief_gate < required_gate:
				continue
		var role_scale: Vector3 = Vector3(0.48, 0.13, 0.48)
		var y_lift: float = OOZE_BASE_SURFACE_OFFSET + 0.014
		match role:
			"core":
				role_scale = Vector3(1.08, 1.34, 1.08)
				y_lift += 0.012
			"melee":
				role_scale = Vector3(1.10, 1.10, 0.78)
				y_lift += 0.010
			"ranged":
				role_scale = Vector3(0.78, 1.18, 0.78)
				y_lift += 0.014
			"defense":
				role_scale = Vector3(1.12, 0.64, 1.12)
				y_lift += 0.006
			"gather":
				role_scale = Vector3(0.82, 0.86, 0.82)
				y_lift += 0.008
			_:
				role = "basic"
		var yaw_jitter: float = (context._noise01(seed + 3, seed + 5) - 0.5) * TAU
		var scale_jitter_x: float = 0.92 + context._noise01(seed + 7, seed + 11) * 0.18
		var scale_jitter_z: float = 0.92 + context._noise01(seed + 13, seed + 17) * 0.18
		var basis: Basis = Basis(Vector3.UP, yaw + yaw_jitter).scaled(Vector3(
			role_scale.x * scale_jitter_x * tile_world_size,
			role_scale.y,
			role_scale.z * scale_jitter_z * tile_world_size
		))
		var center: Vector3 = context._tile_world_position(tile)
		var tf: Transform3D = Transform3D(basis, center + Vector3(0.0, context._tile_floor_top(tile) + y_lift, 0.0))
		if not transforms_by_role.has(role):
			transforms_by_role[role] = []
		var transforms: Array = transforms_by_role[role]
		transforms.append(tf)
		transforms_by_role[role] = transforms
	var owner_tint: Color = context._owner_ooze_tint(owner_id)
	for role_variant in transforms_by_role.keys():
		var role_name: String = String(role_variant)
		var transforms_for_role: Array = transforms_by_role[role_name]
		if transforms_for_role.is_empty():
			continue
		var mat: StandardMaterial3D = context._ooze_tile_mass_material(owner_tint, role_name)
		dynamic_root.add_child(context._make_multimesh_instance(mesh, transforms_for_role, [], mat, true))

func _build_heart_markers(context, dynamic_root: Node3D, state: GameState, tile_world_size: float, growth_anim_entries: Array, owner_id: int, blocks: Array) -> void:
	var profile_start: int = Time.get_ticks_usec()
	if not context._has_asset_scene("core_growth"):
		context._perf_record_time("profile_heart_markers", profile_start)
		return
	var owner_tint: Color = context._owner_ooze_tint(owner_id)
	var heart_tint: Color = context._owner_role_growth_tint(owner_tint, "heart")
	var core_mat: StandardMaterial3D = context._ooze_growth_material(owner_tint, heart_tint, "heart", false)
	core_mat.emission_energy_multiplier *= 1.08
	core_mat.roughness = clampf(core_mat.roughness - 0.03, 0.34, 0.82)
	core_mat.clearcoat = clampf(core_mat.clearcoat + 0.04, 0.0, 0.36)
	for block in blocks:
		if not bool(block.get("is_heart", false)):
			continue
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile) or state.is_blocked(tile):
			continue
		_add_growth_asset_instance(context, dynamic_root, state, tile_world_size, growth_anim_entries, owner_id, "core", tile, core_mat, int(block.get("upgrade_tier", 0)))
	context._perf_record_time("profile_heart_markers", profile_start)

func _build_specialization_markers(context, dynamic_root: Node3D, state: GameState, tile_world_size: float, growth_anim_entries: Array, owner_id: int, blocks: Array) -> void:
	var profile_start: int = Time.get_ticks_usec()
	var role_to_asset: Dictionary = {
		"melee": "melee_growth",
		"ranged": "ranged_growth",
		"defense": "defense_growth",
		"gather": "gather_growth",
	}
	var role_materials: Dictionary = {}
	for role_key in role_to_asset.keys():
		var role_name: String = String(role_key)
		if not context._has_asset_scene(String(role_to_asset[role_name])):
			continue
		var owner_tint: Color = context._owner_ooze_tint(owner_id)
		var role_tint: Color = context._owner_role_growth_tint(owner_tint, role_name)
		var growth_mat: StandardMaterial3D = context._ooze_growth_material(owner_tint, role_tint, role_name, false)
		growth_mat.emission_energy_multiplier *= 0.96
		growth_mat.roughness = clampf(growth_mat.roughness - 0.02, 0.38, 0.86)
		growth_mat.clearcoat = clampf(growth_mat.clearcoat + 0.03, 0.0, 0.34)
		role_materials[role_name] = growth_mat
	for block in blocks:
		var role: String = String(block.get("tile_type", "basic"))
		if role == "basic" or not role_to_asset.has(role):
			continue
		if not role_materials.has(role):
			continue
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile) or state.is_blocked(tile):
			continue
		var growth_mat: Material = role_materials[role]
		_add_growth_asset_instance(context, dynamic_root, state, tile_world_size, growth_anim_entries, owner_id, role, tile, growth_mat, int(block.get("upgrade_tier", 0)))
	context._perf_record_time("profile_specialization_markers", profile_start)

func _growth_asset_key_for_role(role: String) -> String:
	match role:
		"core":
			return "core_growth"
		"melee":
			return "melee_growth"
		"ranged":
			return "ranged_growth"
		"defense":
			return "defense_growth"
		"gather":
			return "gather_growth"
		_:
			return ""

func _add_growth_asset_instance(
	context,
	dynamic_root: Node3D,
	state: GameState,
	tile_world_size: float,
	growth_anim_entries: Array,
	owner_id: int,
	role: String,
	tile: Vector2i,
	mat: Material,
	tier: int = 0
) -> void:
	var asset_key: String = _growth_asset_key_for_role(role)
	if asset_key.is_empty():
		return
	if not context._has_asset_scene(asset_key):
		return
	var clamped_tier: int = clampi(tier, 0, 3)
	var center: Vector3 = context._tile_world_position(tile)
	var direction: Vector3 = _tile_attack_direction(context, state, owner_id, tile)
	var yaw: float = atan2(direction.x, direction.z)
	var role_y_lift: float = OOZE_GROWTH_BASE_OFFSET
	var role_scale: Vector3 = Vector3.ONE
	var forward_lean_degrees: float = 0.0
	var role_yaw_variation_deg: float = 9.0
	var lateral_jitter_tiles: float = 0.04
	var forward_jitter_tiles: float = 0.03
	match role:
		"core":
			role_y_lift += 0.08
			role_scale = Vector3(1.26, 1.44, 1.26)
			role_yaw_variation_deg = 7.0
			lateral_jitter_tiles = 0.03
			forward_jitter_tiles = 0.02
		"melee":
			role_y_lift += 0.04
			role_scale = Vector3(1.12, 1.04, 1.12)
			forward_lean_degrees = -6.0
			role_yaw_variation_deg = 8.0
			lateral_jitter_tiles = 0.04
			forward_jitter_tiles = 0.04
		"ranged":
			role_y_lift += 0.06
			role_scale = Vector3(0.74, 1.84, 0.74)
			forward_lean_degrees = -8.0
			role_yaw_variation_deg = 12.0
			lateral_jitter_tiles = 0.07
			forward_jitter_tiles = 0.06
		"defense":
			role_y_lift += 0.03
			role_scale = Vector3(1.42, 0.66, 1.42)
			role_yaw_variation_deg = 8.0
			lateral_jitter_tiles = 0.03
			forward_jitter_tiles = 0.02
		"gather":
			role_y_lift += 0.03
			role_scale = Vector3(1.12, 0.82, 1.12)
			role_yaw_variation_deg = 10.0
			lateral_jitter_tiles = 0.05
			forward_jitter_tiles = 0.04
	var tier_scale_xy: float = 1.0 + float(clamped_tier) * 0.08
	var tier_scale_y: float = 1.0 + float(clamped_tier) * 0.12
	role_scale.x *= tier_scale_xy
	role_scale.z *= tier_scale_xy
	role_scale.y *= tier_scale_y
	var noise_seed: int = context._tile_noise(tile.x + owner_id * 13, tile.y + owner_id * 17, 1237)
	var yaw_variation: float = deg_to_rad((context._noise01(noise_seed + 3, noise_seed + 7) - 0.5) * role_yaw_variation_deg)
	var scale_jitter: float = 0.98 + context._noise01(noise_seed + 11, noise_seed + 13) * 0.12
	var lateral_jitter: float = (context._noise01(noise_seed + 17, noise_seed + 19) - 0.5) * tile_world_size * lateral_jitter_tiles
	var forward_jitter: float = (context._noise01(noise_seed + 23, noise_seed + 29) - 0.5) * tile_world_size * forward_jitter_tiles
	var forward_dir: Vector3 = direction.normalized()
	var lateral_dir: Vector3 = Vector3(forward_dir.z, 0.0, -forward_dir.x)
	if lateral_dir.length_squared() < 0.0001:
		lateral_dir = Vector3.RIGHT
	else:
		lateral_dir = lateral_dir.normalized()
	var facing_basis: Basis = Basis(Vector3.UP, yaw + yaw_variation)
	var lean_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(forward_lean_degrees))
	var basis: Basis = (facing_basis * lean_basis).scaled(role_scale * scale_jitter)
	var jitter_offset: Vector3 = lateral_dir * lateral_jitter + forward_dir * forward_jitter
	var tf: Transform3D = Transform3D(basis, center + jitter_offset + Vector3(0.0, context._tile_floor_top(tile) + role_y_lift, 0.0))
	var per_tile_material: Material = mat
	if clamped_tier > 0 and mat is StandardMaterial3D:
		var tiered_mat: StandardMaterial3D = (mat as StandardMaterial3D).duplicate(true)
		tiered_mat.roughness = clampf(tiered_mat.roughness - float(clamped_tier) * 0.04, 0.28, 0.92)
		tiered_mat.clearcoat = clampf(tiered_mat.clearcoat + float(clamped_tier) * 0.03, 0.0, 0.42)
		tiered_mat.emission_energy_multiplier *= 1.0 + float(clamped_tier) * 0.12
		per_tile_material = tiered_mat
	var inst: Node3D = context._claim_dynamic_growth_asset_instance(
		dynamic_root,
		asset_key,
		tf,
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		per_tile_material
	)
	if inst == null:
		return
	_register_growth_animation(context, growth_anim_entries, inst, role, tile, owner_id, clamped_tier)

func _register_growth_animation(context, growth_anim_entries: Array, node: Node3D, role: String, tile: Vector2i, owner_id: int, tier: int) -> void:
	var phase_seed: int = context._tile_noise(tile.x + owner_id * 11, tile.y + owner_id * 19, 1979)
	var phase: float = context._noise01(phase_seed + 3, phase_seed + 7) * TAU
	growth_anim_entries.append({
		"node": node,
		"base_tf": node.transform,
		"role": role,
		"phase": phase,
		"tier": tier,
	})

func _cached_ooze_surface_mesh(context, ooze_surface_mesh_cache: Dictionary, board_width: float, board_height: float, surface_offset: float, density: float) -> ArrayMesh:
	var key: String = "%0.3f|%0.3f|%0.3f|%0.3f" % [board_width, board_height, surface_offset, density]
	if ooze_surface_mesh_cache.has(key):
		return ooze_surface_mesh_cache[key] as ArrayMesh
	var mesh: ArrayMesh = _build_ooze_surface_mesh(context, board_width, board_height, surface_offset, density)
	ooze_surface_mesh_cache[key] = mesh
	return mesh

func _cached_viscous_tile_mesh(ooze_surface_mesh_cache: Dictionary) -> ArrayMesh:
	var key: String = "viscous_tile_mass_v2"
	if ooze_surface_mesh_cache.has(key):
		return ooze_surface_mesh_cache[key] as ArrayMesh
	var mesh: ArrayMesh = _build_viscous_tile_mesh()
	ooze_surface_mesh_cache[key] = mesh
	return mesh

func _build_viscous_tile_mesh() -> ArrayMesh:
	var segments: int = 22
	var rings: int = 4
	var max_radius: float = 0.42
	var max_height: float = 0.075
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for ring in range(rings + 1):
		var rn: float = float(ring) / float(rings)
		for seg in range(segments):
			var a: float = TAU * float(seg) / float(segments)
			var edge_lobe: float = 1.0 + sin(a * 3.0 + 0.55) * 0.065 + sin(a * 5.0 + 1.7) * 0.045
			var r: float = max_radius * rn * edge_lobe
			var x: float = cos(a) * r
			var z: float = sin(a) * r
			var dome: float = pow(maxf(0.0, 1.0 - rn), 1.65)
			var ridge: float = smoothstep(0.58, 0.82, rn) * (1.0 - smoothstep(0.82, 1.0, rn))
			var lobe_height: float = (sin(a * 2.0 + 0.9) * 0.010 + sin(a * 4.0 + 2.2) * 0.006) * (1.0 - rn * 0.55)
			var y: float = max_height * dome + ridge * 0.018 + lobe_height
			if ring == rings:
				y = 0.0
			vertices.append(Vector3(x, y, z))
			normals.append(Vector3(0.0, 1.0, 0.0))
			uvs.append(Vector2(0.5 + x / (max_radius * 2.0), 0.5 + z / (max_radius * 2.0)))
	for ring in range(rings):
		for seg in range(segments):
			var next_seg: int = (seg + 1) % segments
			var i0: int = ring * segments + seg
			var i1: int = ring * segments + next_seg
			var i2: int = (ring + 1) * segments + seg
			var i3: int = (ring + 1) * segments + next_seg
			indices.push_back(i0)
			indices.push_back(i2)
			indices.push_back(i1)
			indices.push_back(i1)
			indices.push_back(i2)
			indices.push_back(i3)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_ooze_surface_mesh(context, board_width: float, board_height: float, surface_offset: float, density: float = 2.1) -> ArrayMesh:
	var sx: int = maxi(16, int(board_width * density))
	var sz: int = maxi(16, int(board_height * density))
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.resize((sx + 1) * (sz + 1))
	normals.resize((sx + 1) * (sz + 1))
	uvs.resize((sx + 1) * (sz + 1))
	var eps_x: float = board_width / float(sx)
	var eps_z: float = board_height / float(sz)
	for z in range(sz + 1):
		var fz: float = float(z) / float(sz)
		var lz: float = (fz - 0.5) * board_height
		for x in range(sx + 1):
			var fx: float = float(x) / float(sx)
			var lx: float = (fx - 0.5) * board_width
			var h: float = context._sample_ground_height_at_local(lx, lz, board_width, board_height) + surface_offset
			var idx: int = z * (sx + 1) + x
			vertices[idx] = Vector3(lx, h, lz)
			uvs[idx] = Vector2(fx, fz)
			var h_l: float = context._sample_ground_height_at_local(lx - eps_x, lz, board_width, board_height) + surface_offset
			var h_r: float = context._sample_ground_height_at_local(lx + eps_x, lz, board_width, board_height) + surface_offset
			var h_d: float = context._sample_ground_height_at_local(lx, lz - eps_z, board_width, board_height) + surface_offset
			var h_u: float = context._sample_ground_height_at_local(lx, lz + eps_z, board_width, board_height) + surface_offset
			var tx: Vector3 = Vector3(2.0 * eps_x, h_r - h_l, 0.0)
			var tz: Vector3 = Vector3(0.0, h_u - h_d, 2.0 * eps_z)
			normals[idx] = tx.cross(tz).normalized()
	for z in range(sz):
		for x in range(sx):
			var i0: int = z * (sx + 1) + x
			var i1: int = i0 + 1
			var i2: int = i0 + (sx + 1)
			var i3: int = i2 + 1
			indices.push_back(i0)
			indices.push_back(i2)
			indices.push_back(i1)
			indices.push_back(i1)
			indices.push_back(i2)
			indices.push_back(i3)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _tile_attack_direction(context, state: GameState, owner_id: int, tile: Vector2i) -> Vector3:
	var fallback: Vector3 = Vector3.RIGHT if owner_id == GameState.PLAYER_ID else Vector3.LEFT
	if state == null:
		return fallback
	var src: Vector3 = context._tile_world_position(tile)
	var best_dist_sq: float = INF
	var best_dir: Vector3 = fallback
	for block in state.blocks.values():
		if not bool(block.get("is_heart", false)):
			continue
		if int(block.get("owner", owner_id)) == owner_id:
			continue
		var other: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(other):
			continue
		var delta: Vector3 = context._tile_world_position(other) - src
		delta.y = 0.0
		var dist_sq: float = delta.length_squared()
		if dist_sq <= 0.0001 or dist_sq >= best_dist_sq:
			continue
		best_dist_sq = dist_sq
		best_dir = delta.normalized()
	return best_dir

func _build_owner_blob_caps(context, dynamic_root: Node3D, state: GameState, owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if state.is_inside(t):
			tile_set[context._tile_key(t)] = true
	var blob_mesh: SphereMesh = SphereMesh.new()
	blob_mesh.radius = 0.18
	blob_mesh.height = 0.24
	blob_mesh.radial_segments = 10
	blob_mesh.rings = 5
	var transforms: Array[Transform3D] = []
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile):
			continue
		var neighbor_count: int = context._owned_neighbor_count(tile, tile_set)
		if neighbor_count <= 0:
			continue
		var edge_tile: bool = neighbor_count < 4
		var noise_gate: float = context._noise01(tile.x * 17 + owner_id * 19, tile.y * 31 + owner_id * 7)
		if edge_tile:
			if noise_gate < 0.60:
				continue
		elif noise_gate < 0.82:
			continue
		var center: Vector3 = context._tile_world_position(tile)
		var top: float = context._tile_ground_top(tile)
		var noise_scale: float = 0.66 + context._noise01(tile.x + owner_id * 7, tile.y + 13) * 0.24
		var blob_basis: Basis = Basis().scaled(Vector3(1.0, 0.48, 1.0) * noise_scale)
		transforms.append(Transform3D(blob_basis, center + Vector3(0.0, top + 0.040, 0.0)))
	if transforms.is_empty():
		return
	var tint: Color = context._owner_tint(owner_id)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r * 0.52, tint.g * 0.52, tint.b * 0.52, 1.0)
	mat.roughness = 0.52
	mat.metallic = 0.01
	mat.metallic_specular = 0.26
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.08
	mat.clearcoat_roughness = 0.44
	mat.emission_enabled = true
	mat.emission = Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16, 1.0)
	mat.emission_energy_multiplier = 0.010
	dynamic_root.add_child(context._make_multimesh_instance(blob_mesh, transforms, [], mat, true))

func _build_owner_micro_bubbles(context, dynamic_root: Node3D, state: GameState, owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if state.is_inside(t):
			tile_set[context._tile_key(t)] = true
	var bubble_mesh: SphereMesh = SphereMesh.new()
	bubble_mesh.radius = 0.06
	bubble_mesh.height = 0.12
	bubble_mesh.radial_segments = 8
	bubble_mesh.rings = 5
	var bubble_transforms: Array[Transform3D] = []
	var max_bubbles: int = mini(96, maxi(24, int(blocks.size() * 0.35)))
	for block in blocks:
		if bubble_transforms.size() >= max_bubbles:
			break
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile):
			continue
		var neighbor_count: int = context._owned_neighbor_count(tile, tile_set)
		if neighbor_count <= 0:
			continue
		var edge_tile: bool = neighbor_count < 4
		var presence_gate: float = context._noise01(tile.x * 11 + owner_id * 43, tile.y * 13 + owner_id * 57)
		if edge_tile:
			if presence_gate < 0.78:
				continue
		elif presence_gate < 0.94:
			continue
		var center: Vector3 = context._tile_world_position(tile)
		var top: float = context._tile_ground_top(tile)
		var dx: float = (context._noise01(tile.x * 7 + owner_id, tile.y * 13 + 3) - 0.5) * 0.30
		var dz: float = (context._noise01(tile.x * 11 + owner_id * 5, tile.y * 5 + 9) - 0.5) * 0.30
		var scale_v: float = 0.66 + context._noise01(tile.x * 17 + 2, tile.y * 19 + owner_id) * 0.58
		var bb: Basis = Basis().scaled(Vector3.ONE * scale_v)
		bubble_transforms.append(Transform3D(bb, center + Vector3(dx, top + 0.048, dz)))
	if bubble_transforms.is_empty():
		return
	var tint: Color = context._owner_tint(owner_id)
	var bubble_mat: StandardMaterial3D = StandardMaterial3D.new()
	bubble_mat.albedo_color = Color(tint.r * 0.58, tint.g * 0.58, tint.b * 0.58, 1.0)
	bubble_mat.roughness = 0.52
	bubble_mat.metallic = 0.01
	bubble_mat.metallic_specular = 0.28
	bubble_mat.clearcoat_enabled = true
	bubble_mat.clearcoat = 0.08
	bubble_mat.clearcoat_roughness = 0.48
	bubble_mat.emission_enabled = true
	bubble_mat.emission = Color(tint.r * 0.16, tint.g * 0.16, tint.b * 0.16, 1.0)
	bubble_mat.emission_energy_multiplier = 0.010
	dynamic_root.add_child(context._make_multimesh_instance(bubble_mesh, bubble_transforms, [], bubble_mat, false))

func _build_owner_edge_beads(context, dynamic_root: Node3D, state: GameState, owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if state.is_inside(t):
			tile_set[context._tile_key(t)] = true
	var bead_mesh: SphereMesh = SphereMesh.new()
	bead_mesh.radius = 0.08
	bead_mesh.height = 0.16
	bead_mesh.radial_segments = 8
	bead_mesh.rings = 5
	var transforms: Array[Transform3D] = []
	var max_beads: int = mini(84, maxi(18, int(blocks.size() * 0.28)))
	for block in blocks:
		if transforms.size() >= max_beads:
			break
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not state.is_inside(tile):
			continue
		var neighbors: int = context._owned_neighbor_count(tile, tile_set)
		if neighbors >= 4:
			continue
		var gate: float = context._noise01(tile.x * 47 + owner_id * 13, tile.y * 29 + owner_id * 31)
		if gate < 0.60:
			continue
		var center: Vector3 = context._tile_world_position(tile)
		var top: float = context._tile_ground_top(tile)
		var bead_count: int = 1 + int(floor(context._noise01(tile.x * 11 + owner_id * 7, tile.y * 17 + owner_id * 19) * 2.0))
		for n in range(bead_count):
			if transforms.size() >= max_beads:
				break
			var ang: float = context._noise01(tile.x * 73 + n * 19 + owner_id, tile.y * 41 + n * 23 + owner_id * 3) * TAU
			var rad: float = 0.24 + context._noise01(tile.x * 59 + n * 29, tile.y * 67 + n * 17) * 0.20
			var sx: float = 0.72 + context._noise01(tile.x * 13 + n * 7, tile.y * 19 + n * 5) * 0.38
			var bead_basis: Basis = Basis().scaled(Vector3.ONE * sx)
			transforms.append(Transform3D(bead_basis, center + Vector3(cos(ang) * rad, top + 0.038, sin(ang) * rad)))
	if transforms.is_empty():
		return
	var tint: Color = context._owner_tint(owner_id)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(tint.r * 0.58, tint.g * 0.58, tint.b * 0.58, 1.0)
	mat.roughness = 0.56
	mat.metallic = 0.01
	mat.metallic_specular = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.06
	mat.clearcoat_roughness = 0.50
	mat.emission_enabled = true
	mat.emission = Color(tint.r * 0.14, tint.g * 0.14, tint.b * 0.14, 1.0)
	mat.emission_energy_multiplier = 0.008
	dynamic_root.add_child(context._make_multimesh_instance(bead_mesh, transforms, [], mat, false))

func _owner_mask_cache_key(context, state: GameState, tile_set: Dictionary) -> String:
	var tile_keys: Array = tile_set.keys()
	tile_keys.sort()
	var wall_keys: Array = state.wall_tiles.keys()
	wall_keys.sort()
	return "organic_silhouette_v3|%d|%d|%d|%s|%s" % [
		state.width,
		state.height,
		OOZE_MASK_SCALE,
		context._join_string_keys(wall_keys),
		context._join_string_keys(tile_keys),
	]

func _tile_touches_blocked_neighbor(state: GameState, tile: Vector2i) -> bool:
	if state == null:
		return false
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = tile + step
		if state.is_inside(neighbor) and state.is_blocked(neighbor):
			return true
	return false

func _connected_owner_clusters(context, tile_set: Dictionary) -> Array:
	var unvisited: Dictionary = {}
	for key_variant in tile_set.keys():
		unvisited[String(key_variant)] = true
	var clusters: Array = []
	while not unvisited.is_empty():
		var start_key: String = String(unvisited.keys()[0])
		var queue: Array[String] = [start_key]
		var tiles: Dictionary = {}
		unvisited.erase(start_key)
		var seed_accum: int = 17
		while not queue.is_empty():
			var key: String = queue.pop_front()
			var tile: Vector2i = tile_set.get(key, Vector2i(-1, -1))
			if tile == Vector2i(-1, -1):
				continue
			tiles[key] = tile
			seed_accum = int(seed_accum * 131 + tile.x * 977 + tile.y * 613)
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = tile + step
				var neighbor_key: String = context._tile_key(neighbor)
				if not unvisited.has(neighbor_key):
					continue
				unvisited.erase(neighbor_key)
				queue.append(neighbor_key)
		clusters.append({
			"tiles": tiles,
			"seed": absi(seed_accum),
		})
	return clusters

func _clear_unowned_tiles_from_mask(
	context,
	state: GameState,
	image: Image,
	mask_scale: int,
	tile_set: Dictionary
) -> void:
	if state == null:
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			if tile_set.has(context._tile_key(tile)):
				continue
			var px0: int = clampi(x * mask_scale, 0, w - 1)
			var py0: int = clampi(y * mask_scale, 0, h - 1)
			var px1: int = clampi((x + 1) * mask_scale - 1, 0, w - 1)
			var py1: int = clampi((y + 1) * mask_scale - 1, 0, h - 1)
			image.fill_rect(Rect2i(px0, py0, px1 - px0 + 1, py1 - py0 + 1), Color(1.0, 1.0, 1.0, 0.0))

func _tile_set_pixel_bounds(tile_set: Dictionary, mask_scale: int, image: Image, pad: int) -> Rect2i:
	var min_x: int = image.get_width() - 1
	var min_y: int = image.get_height() - 1
	var max_x: int = 0
	var max_y: int = 0
	for tile_variant in tile_set.values():
		var tile: Vector2i = tile_variant
		min_x = mini(min_x, tile.x * mask_scale - pad)
		min_y = mini(min_y, tile.y * mask_scale - pad)
		max_x = maxi(max_x, (tile.x + 1) * mask_scale - 1 + pad)
		max_y = maxi(max_y, (tile.y + 1) * mask_scale - 1 + pad)
	min_x = clampi(min_x, 1, image.get_width() - 2)
	min_y = clampi(min_y, 1, image.get_height() - 2)
	max_x = clampi(max_x, 1, image.get_width() - 2)
	max_y = clampi(max_y, 1, image.get_height() - 2)
	return Rect2i(min_x, min_y, maxi(1, max_x - min_x + 1), maxi(1, max_y - min_y + 1))

func _apply_cluster_organic_silhouette(
	context,
	state: GameState,
	image: Image,
	mask_scale: int,
	tile_set: Dictionary,
	clusters: Array
) -> void:
	if state == null:
		return
	for cluster_variant in clusters:
		var cluster: Dictionary = cluster_variant
		var cluster_tiles: Dictionary = cluster.get("tiles", {})
		var cluster_seed: int = int(cluster.get("seed", 0))
		for key_variant in cluster_tiles.keys():
			var tile: Vector2i = cluster_tiles[key_variant]
			_carve_tile_exposed_silhouette(context, image, mask_scale, tile_set, tile, cluster_seed)

func _carve_tile_exposed_silhouette(
	context,
	image: Image,
	mask_scale: int,
	tile_set: Dictionary,
	tile: Vector2i,
	cluster_seed: int
) -> void:
	var exposed_sides: Array[Vector2i] = []
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not tile_set.has(context._tile_key(tile + step)):
			exposed_sides.append(step)
	if exposed_sides.is_empty():
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	var px0: int = clampi(tile.x * mask_scale, 0, w - 1)
	var py0: int = clampi(tile.y * mask_scale, 0, h - 1)
	var px1: int = clampi((tile.x + 1) * mask_scale - 1, 0, w - 1)
	var py1: int = clampi((tile.y + 1) * mask_scale - 1, 0, h - 1)
	var max_depth: float = maxf(3.0, float(mask_scale) * 0.34)
	var side_depths: Dictionary = {}
	for side in exposed_sides:
		var depths: Array[float] = []
		for i in range(mask_scale):
			var along: float
			if side == Vector2i.LEFT or side == Vector2i.RIGHT:
				along = float(tile.y) + (float(i) + 0.5) / float(mask_scale)
			else:
				along = float(tile.x) + (float(i) + 0.5) / float(mask_scale)
			var profile: float = _cluster_edge_profile(context, cluster_seed, along, side)
			depths.append(0.70 + profile * max_depth)
		side_depths[side] = depths
	for py in range(py0, py1 + 1):
		for px in range(px0, px1 + 1):
			var lx: int = px - tile.x * mask_scale
			var ly: int = py - tile.y * mask_scale
			var carved_alpha: float = image.get_pixel(px, py).a
			if carved_alpha <= 0.0:
				continue
			for side in exposed_sides:
				var dist: float = _pixel_distance_to_side(lx, ly, mask_scale, side)
				if dist > max_depth + 1.0:
					continue
				var depths_for_side: Array = side_depths.get(side, [])
				var depth_index: int = clampi(ly if side == Vector2i.LEFT or side == Vector2i.RIGHT else lx, 0, mask_scale - 1)
				var depth: float = float(depths_for_side[depth_index]) if depth_index < depths_for_side.size() else max_depth * 0.5
				if dist < depth:
					var keep: float = smoothstep(0.0, maxf(0.001, depth), dist)
					carved_alpha = minf(carved_alpha, keep)
				else:
					var feather: float = smoothstep(depth, depth + 1.35, dist)
					carved_alpha = minf(carved_alpha, 0.82 + feather * 0.18)
			carved_alpha = minf(
				carved_alpha,
				_corner_silhouette_keep(context, tile_set, tile, lx, ly, mask_scale, cluster_seed)
			)
			image.set_pixel(px, py, Color(1.0, 1.0, 1.0, clampf(carved_alpha, 0.0, 1.0)))

func _pixel_distance_to_side(local_x: int, local_y: int, mask_scale: int, side: Vector2i) -> float:
	if side == Vector2i.LEFT:
		return float(local_x)
	if side == Vector2i.RIGHT:
		return float(mask_scale - 1 - local_x)
	if side == Vector2i.UP:
		return float(local_y)
	return float(mask_scale - 1 - local_y)

func _pixel_cluster_along(tile: Vector2i, local_x: int, local_y: int, mask_scale: int, side: Vector2i) -> float:
	if side == Vector2i.LEFT or side == Vector2i.RIGHT:
		return float(tile.y) + (float(local_y) + 0.5) / float(mask_scale)
	return float(tile.x) + (float(local_x) + 0.5) / float(mask_scale)

func _cluster_edge_profile(context, cluster_seed: int, along: float, side: Vector2i) -> float:
	var side_seed: int = int(side.x * 37 + side.y * 53)
	var low: float = sin(along * 2.35 + float(cluster_seed % 997) * 0.017 + float(side_seed) * 0.11)
	var mid: float = sin(along * 5.10 + float(cluster_seed % 593) * 0.031 + float(side_seed) * 0.07)
	var cell: int = int(floor(along * 2.0))
	var n0: float = context._noise01(cluster_seed + cell * 19 + side_seed, cluster_seed + cell * 31)
	var n1: float = context._noise01(cluster_seed + (cell + 1) * 19 + side_seed, cluster_seed + (cell + 1) * 31)
	var raw_frac: float = along * 2.0
	var frac_v: float = raw_frac - floor(raw_frac)
	var stepped_noise: float = lerp(n0, n1, frac_v)
	return clampf(0.46 + low * 0.22 + mid * 0.12 + (stepped_noise - 0.5) * 0.34, 0.0, 1.0)

func _corner_silhouette_keep(
	context,
	tile_set: Dictionary,
	tile: Vector2i,
	local_x: int,
	local_y: int,
	mask_scale: int,
	cluster_seed: int
) -> float:
	var keep: float = 1.0
	var corners: Array[Dictionary] = [
		{
			"sides": [Vector2i.LEFT, Vector2i.UP],
			"corner": Vector2(0.0, 0.0),
			"neighbor_a": tile + Vector2i.LEFT,
			"neighbor_b": tile + Vector2i.UP,
		},
		{
			"sides": [Vector2i.RIGHT, Vector2i.UP],
			"corner": Vector2(float(mask_scale - 1), 0.0),
			"neighbor_a": tile + Vector2i.RIGHT,
			"neighbor_b": tile + Vector2i.UP,
		},
		{
			"sides": [Vector2i.LEFT, Vector2i.DOWN],
			"corner": Vector2(0.0, float(mask_scale - 1)),
			"neighbor_a": tile + Vector2i.LEFT,
			"neighbor_b": tile + Vector2i.DOWN,
		},
		{
			"sides": [Vector2i.RIGHT, Vector2i.DOWN],
			"corner": Vector2(float(mask_scale - 1), float(mask_scale - 1)),
			"neighbor_a": tile + Vector2i.RIGHT,
			"neighbor_b": tile + Vector2i.DOWN,
		},
	]
	for corner_variant in corners:
		var corner_data: Dictionary = corner_variant
		if tile_set.has(context._tile_key(corner_data["neighbor_a"])) or tile_set.has(context._tile_key(corner_data["neighbor_b"])):
			continue
		var corner: Vector2 = corner_data["corner"]
		var dist: float = Vector2(float(local_x), float(local_y)).distance_to(corner)
		var profile: float = context._noise01(cluster_seed + tile.x * 43 + tile.y * 59 + int(corner.x) * 7, cluster_seed + int(corner.y) * 11)
		var radius: float = float(mask_scale) * (0.26 + profile * 0.16)
		keep = minf(keep, smoothstep(radius * 0.42, radius, dist))
	return keep

func _carve_blocked_tiles_from_mask(state: GameState, image: Image, mask_scale: int) -> void:
	if state == null:
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	var guard_band: int = maxi(0, int(round(float(mask_scale) * 0.05)))
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_blocked(tile):
				continue
			var px0: int = x * mask_scale + guard_band
			var py0: int = y * mask_scale + guard_band
			var px1: int = (x + 1) * mask_scale - 1 - guard_band
			var py1: int = (y + 1) * mask_scale - 1 - guard_band
			px0 = clampi(px0, 0, w - 1)
			px1 = clampi(px1, 0, w - 1)
			py0 = clampi(py0, 0, h - 1)
			py1 = clampi(py1, 0, h - 1)
			image.fill_rect(Rect2i(px0, py0, px1 - px0 + 1, py1 - py0 + 1), Color(1.0, 1.0, 1.0, 0.0))

func _carve_wall_contact_moat(state: GameState, image: Image, mask_scale: int) -> void:
	if state == null:
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	var pad: int = maxi(1, int(round(float(mask_scale) * 0.28)))
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_blocked(tile):
				continue
			var px0: int = x * mask_scale - pad
			var py0: int = y * mask_scale - pad
			var px1: int = (x + 1) * mask_scale - 1 + pad
			var py1: int = (y + 1) * mask_scale - 1 + pad
			px0 = clampi(px0, 0, w - 1)
			px1 = clampi(px1, 0, w - 1)
			py0 = clampi(py0, 0, h - 1)
			py1 = clampi(py1, 0, h - 1)
			image.fill_rect(Rect2i(px0, py0, px1 - px0 + 1, py1 - py0 + 1), Color(1.0, 1.0, 1.0, 0.0))

func _dilate_mask(image: Image) -> void:
	_dilate_mask_region(image, Rect2i(1, 1, image.get_width() - 2, image.get_height() - 2))

func _dilate_mask_region(image: Image, region: Rect2i) -> void:
	var copy: Image = image.duplicate()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var x0: int = clampi(region.position.x, 1, w - 2)
	var y0: int = clampi(region.position.y, 1, h - 2)
	var x1: int = clampi(region.position.x + region.size.x - 1, 1, w - 2)
	var y1: int = clampi(region.position.y + region.size.y - 1, 1, h - 2)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var current: float = copy.get_pixel(x, y).a
			var n1: float = copy.get_pixel(x + 1, y).a
			var n2: float = copy.get_pixel(x - 1, y).a
			var n3: float = copy.get_pixel(x, y + 1).a
			var n4: float = copy.get_pixel(x, y - 1).a
			var max_n: float = maxf(maxf(n1, n2), maxf(n3, n4))
			var expanded: float = maxf(current, max_n * 0.94)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, expanded))

func _stamp_rect(image: Image, x0: int, y0: int, x1: int, y1: int, strength: float) -> void:
	var clamped_x0: int = maxi(0, mini(x0, x1))
	var clamped_x1: int = mini(image.get_width() - 1, maxi(x0, x1))
	var clamped_y0: int = maxi(0, mini(y0, y1))
	var clamped_y1: int = mini(image.get_height() - 1, maxi(y0, y1))
	image.fill_rect(
		Rect2i(clamped_x0, clamped_y0, clamped_x1 - clamped_x0 + 1, clamped_y1 - clamped_y0 + 1),
		Color(1.0, 1.0, 1.0, strength)
	)

func _smooth_mask(image: Image) -> void:
	_smooth_mask_region(image, Rect2i(1, 1, image.get_width() - 2, image.get_height() - 2))

func _smooth_mask_region(image: Image, region: Rect2i) -> void:
	var copy: Image = image.duplicate()
	var w: int = image.get_width()
	var h: int = image.get_height()
	var x0: int = clampi(region.position.x, 1, w - 2)
	var y0: int = clampi(region.position.y, 1, h - 2)
	var x1: int = clampi(region.position.x + region.size.x - 1, 1, w - 2)
	var y1: int = clampi(region.position.y + region.size.y - 1, 1, h - 2)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var a0: float = copy.get_pixel(x, y).a
			var a1: float = copy.get_pixel(x + 1, y).a
			var a2: float = copy.get_pixel(x - 1, y).a
			var a3: float = copy.get_pixel(x, y + 1).a
			var a4: float = copy.get_pixel(x, y - 1).a
			var smoothed: float = clampf(a0 * 0.36 + (a1 + a2 + a3 + a4) * 0.16, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, smoothed))

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
