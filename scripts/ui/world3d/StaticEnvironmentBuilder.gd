extends RefCounted
class_name StaticEnvironmentBuilder

const FLOOR_SURFACE_TOP_OFFSET: float = 0.070
const INNER_WALL_TILE_FOOTPRINT: float = 0.86
const INNER_WALL_HEIGHT: float = 1.82
const FRONT_WALL_CUTOUT_MIN: float = 0.24
const FRONT_WALL_CUTOUT_MAX: float = 0.76
const OUTER_WALL_BASE_SINK: float = 0.34
const OUTER_WALL_CONTACT_HEIGHT: float = 0.120
const OUTER_WALL_CONTACT_SINK: float = 0.045
const FLOOR_DETAIL_PLACEMENT_RATE: float = 0.0
const VISUAL_FLOOR_BORDER_TILES: int = 3
const INNER_WALL_ASSET_HEIGHT: float = 1.16
const INNER_WALL_BASE_SINK: float = 0.10
const OUTER_TOP_LEDGE_WIDTH: float = 5.8
const OUTER_TOP_LEDGE_HEIGHT_OFFSET: float = 1.46

var _wall_contact_material: StandardMaterial3D = null
var _wall_apron_material: Material = null
var _dungeon_surround_material: StandardMaterial3D = null
var _wall_core_material: StandardMaterial3D = null
var _inner_wall_footing_material: StandardMaterial3D = null

func build_static_world(
	context,
	terrain_root: Node3D,
	state: GameState,
	tile_world_size: float,
	board_min: Vector3,
	board_max: Vector3,
	camera_base_target: Vector3,
	ground_tops: Dictionary,
	floor_surface_tops: Dictionary,
	rendered_inner_wall_tiles: Dictionary
) -> bool:
	context._clear_children(terrain_root)
	ground_tops.clear()
	floor_surface_tops.clear()
	rendered_inner_wall_tiles.clear()
	if state == null:
		return false

	var board_width: float = float(state.width) * tile_world_size
	var board_height: float = float(state.height) * tile_world_size
	var board_top: float = -0.02

	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			var terrain_top: float = context._terrain_ground_top_for_tile(tile, board_top)
			ground_tops[context._tile_key(tile)] = terrain_top
			floor_surface_tops[context._tile_key(tile)] = terrain_top

	_build_asset_kit_floor(context, terrain_root, state, tile_world_size, camera_base_target, ground_tops, floor_surface_tops, board_width, board_height, board_top)
	_build_asset_kit_chamber(context, terrain_root, state, tile_world_size, ground_tops, board_width, board_height, board_top)
	_build_asset_kit_blockers(context, terrain_root, state, ground_tops, floor_surface_tops, rendered_inner_wall_tiles, board_top)
	_add_cave_doors(context, terrain_root, state, tile_world_size, board_min, board_max, camera_base_target)
	return true

func layout_outer_bounds_tiles(state: GameState) -> Dictionary:
	if state == null:
		return {"min": Vector2i(0, 0), "max": Vector2i(0, 0)}
	var layout: Dictionary = state.get_level_layout()
	var raw_bounds: Dictionary = layout.get("outer_bounds", {})
	var min_arr: Array = raw_bounds.get("min", [0, 0])
	var max_arr: Array = raw_bounds.get("max", [state.width - 1, state.height - 1])
	var min_tile: Vector2i = Vector2i(0, 0)
	var max_tile: Vector2i = Vector2i(state.width - 1, state.height - 1)
	if min_arr.size() >= 2:
		min_tile = Vector2i(int(min_arr[0]), int(min_arr[1]))
	if max_arr.size() >= 2:
		max_tile = Vector2i(int(max_arr[0]), int(max_arr[1]))
	min_tile = Vector2i(clampi(min_tile.x, 0, state.width - 1), clampi(min_tile.y, 0, state.height - 1))
	max_tile = Vector2i(clampi(max_tile.x, 0, state.width - 1), clampi(max_tile.y, 0, state.height - 1))
	if min_tile.x > max_tile.x:
		var swap_x: int = min_tile.x
		min_tile.x = max_tile.x
		max_tile.x = swap_x
	if min_tile.y > max_tile.y:
		var swap_y: int = min_tile.y
		min_tile.y = max_tile.y
		max_tile.y = swap_y
	return {"min": min_tile, "max": max_tile}

func validate_wall_tile_visual_alignment(state: GameState, rendered_inner_wall_tiles: Dictionary) -> Dictionary:
	if state == null:
		return {"ok": true, "missing_tiles": [], "extra_tiles": []}
	var missing: Array = []
	var extra: Array = []
	for key_variant in state.wall_tiles.keys():
		var key: String = String(key_variant)
		if not rendered_inner_wall_tiles.has(key):
			missing.append(key)
	for key_variant in rendered_inner_wall_tiles.keys():
		var key: String = String(key_variant)
		if not state.wall_tiles.has(key):
			extra.append(key)
	return {
		"ok": missing.is_empty() and extra.is_empty(),
		"missing_tiles": missing,
		"extra_tiles": extra,
	}

func _build_asset_kit_floor(
	context,
	terrain_root: Node3D,
	state: GameState,
	tile_world_size: float,
	camera_base_target: Vector3,
	ground_tops: Dictionary,
	floor_surface_tops: Dictionary,
	board_width: float,
	board_height: float,
	board_top: float
) -> void:
	if terrain_root == null:
		return
	if state == null:
		return
	if not context._has_asset_scene("floor_tile_rock"):
		return

	var mat: Material = context._stone_shader_material(
		Color(0.480, 0.488, 0.495, 1.0),
		Color(0.390, 0.398, 0.405, 1.0),
		Color(0.305, 0.314, 0.322, 1.0),
		9.0,
		0.000,
		0.006,
		0.012,
		0.36,
		0.004,
		0.330,
		0.485
	)
	var bounds: Dictionary = layout_outer_bounds_tiles(state)
	var min_tile: Vector2i = bounds.get("min", Vector2i(0, 0))
	var max_tile: Vector2i = bounds.get("max", Vector2i(state.width - 1, state.height - 1))
	var visual_min: Vector2i = min_tile - Vector2i(VISUAL_FLOOR_BORDER_TILES, VISUAL_FLOOR_BORDER_TILES)
	var visual_max: Vector2i = max_tile + Vector2i(VISUAL_FLOOR_BORDER_TILES, VISUAL_FLOOR_BORDER_TILES)
	_add_wall_to_wall_floor_fill(context, terrain_root, visual_min, visual_max, tile_world_size, ground_tops, mat)
	for y in range(visual_min.y, visual_max.y + 1):
		for x in range(visual_min.x, visual_max.x + 1):
			var tile: Vector2i = Vector2i(x, y)
			var sample_tile: Vector2i = Vector2i(
				clampi(tile.x, min_tile.x, max_tile.x),
				clampi(tile.y, min_tile.y, max_tile.y)
			)
			var center: Vector3 = context._tile_world_position(tile)
			var top: float = float(ground_tops.get(context._tile_key(sample_tile), 0.0))
			var floor_top: float = top + FLOOR_SURFACE_TOP_OFFSET
			if tile.x >= min_tile.x and tile.x <= max_tile.x and tile.y >= min_tile.y and tile.y <= max_tile.y:
				ground_tops[context._tile_key(tile)] = floor_top
				floor_surface_tops[context._tile_key(tile)] = floor_top
			if not _should_place_floor_detail(context, tile):
				continue
			var yaw_deg: float = 90.0 if int(abs(tile.x + tile.y)) % 2 == 1 else 0.0
			var sx: float = tile_world_size * 1.01
			var sy: float = 1.00
			var sz: float = tile_world_size * 1.01
			var tile_basis: Basis = Basis.from_euler(Vector3(
				0.0,
				deg_to_rad(yaw_deg),
				0.0
			)).scaled(Vector3(sx, sy, sz))
			var tf: Transform3D = Transform3D(
				tile_basis,
				center + Vector3(0.0, top - 0.070, 0.0)
			)
			context._add_asset_instance(terrain_root, "floor_tile_rock", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, mat)

func _should_place_floor_detail(context, tile: Vector2i) -> bool:
	var noise: float = context._noise01(tile.x * 101 + 17, tile.y * 127 + 31)
	if noise <= FLOOR_DETAIL_PLACEMENT_RATE:
		return true
	return false

func _add_wall_to_wall_floor_fill(
	context,
	terrain_root: Node3D,
	min_tile: Vector2i,
	max_tile: Vector2i,
	tile_world_size: float,
	ground_tops: Dictionary,
	mat: Material
) -> void:
	if terrain_root == null:
		return
	var mesh: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var verts_w: int = max_tile.x - min_tile.x + 2
	var verts_h: int = max_tile.y - min_tile.y + 2
	for vy in range(verts_h):
		for vx in range(verts_w):
			var sample_x: float = float(min_tile.x) - 0.5 + float(vx)
			var sample_y: float = float(min_tile.y) - 0.5 + float(vy)
			var tile_x: int = clampi(int(floor(sample_x + 0.5)), min_tile.x, max_tile.x)
			var tile_y: int = clampi(int(floor(sample_y + 0.5)), min_tile.y, max_tile.y)
			var top: float = float(ground_tops.get(context._tile_key(Vector2i(tile_x, tile_y)), 0.0))
			var world_x: float = context._tile_world_position(Vector2i(min_tile.x, min_tile.y)).x + (float(vx) - 0.5) * tile_world_size
			var world_z: float = context._tile_world_position(Vector2i(min_tile.x, min_tile.y)).z + (float(vy) - 0.5) * tile_world_size
			vertices.push_back(Vector3(world_x, top + FLOOR_SURFACE_TOP_OFFSET - 0.160, world_z))
			normals.push_back(Vector3.UP)
			uvs.push_back(Vector2(float(vx), float(vy)))
	for y in range(verts_h - 1):
		for x in range(verts_w - 1):
			var i0: int = y * verts_w + x
			var i1: int = i0 + 1
			var i2: int = i0 + verts_w
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
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var fill: MeshInstance3D = MeshInstance3D.new()
	fill.name = "WallToWallDungeonFloorFill"
	fill.mesh = mesh
	fill.material_override = mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(fill)

func _build_asset_kit_chamber(
	context,
	terrain_root: Node3D,
	state: GameState,
	tile_world_size: float,
	ground_tops: Dictionary,
	_board_width: float,
	_board_height: float,
	_board_top: float
) -> void:
	if terrain_root == null:
		return
	if state == null:
		return
	if not context._has_asset_scene("cave_wall"):
		return

	var bounds: Dictionary = layout_outer_bounds_tiles(state)
	var min_tile: Vector2i = bounds.get("min", Vector2i(0, 0))
	var max_tile: Vector2i = bounds.get("max", Vector2i(state.width - 1, state.height - 1))
	for x in range(min_tile.x, max_tile.x + 1):
		_add_perimeter_wall_segment(context, terrain_root, tile_world_size, ground_tops, Vector2i(x, min_tile.y), Vector3(0.0, 0.0, -1.0), 180.0, "north", min_tile, max_tile)
		_add_perimeter_wall_segment(context, terrain_root, tile_world_size, ground_tops, Vector2i(x, max_tile.y), Vector3(0.0, 0.0, 1.0), 0.0, "south", min_tile, max_tile)
	for y in range(min_tile.y + 1, max_tile.y):
		_add_perimeter_wall_segment(context, terrain_root, tile_world_size, ground_tops, Vector2i(min_tile.x, y), Vector3(-1.0, 0.0, 0.0), -90.0, "west", min_tile, max_tile)
		_add_perimeter_wall_segment(context, terrain_root, tile_world_size, ground_tops, Vector2i(max_tile.x, y), Vector3(1.0, 0.0, 0.0), 90.0, "east", min_tile, max_tile)

	_add_perimeter_wall_core_runs(context, terrain_root, tile_world_size, ground_tops, min_tile, max_tile)

	if context._has_asset_scene("cave_corner"):
		var corners: Array[Dictionary] = [
			{"tile": Vector2i(min_tile.x, min_tile.y), "offset": Vector3(-1.0, 0.0, -1.0), "yaw": 135.0},
			{"tile": Vector2i(max_tile.x, min_tile.y), "offset": Vector3(1.0, 0.0, -1.0), "yaw": 225.0},
			{"tile": Vector2i(min_tile.x, max_tile.y), "offset": Vector3(-1.0, 0.0, 1.0), "yaw": 45.0},
			{"tile": Vector2i(max_tile.x, max_tile.y), "offset": Vector3(1.0, 0.0, 1.0), "yaw": -45.0},
		]
		for corner in corners:
			var tile: Vector2i = corner["tile"]
			var center: Vector3 = context._tile_world_position(tile)
			var top: float = float(ground_tops.get(context._tile_key(tile), 0.0))
			var corner_scale: Vector3 = Vector3(1.52, 1.82, 1.52)
			var corner_basis: Basis = Basis.from_euler(Vector3(
				0.0,
				deg_to_rad(float(corner.get("yaw", 0.0))),
				0.0
			)).scaled(corner_scale)
			var corner_pos: Vector3 = center + corner["offset"] * (tile_world_size * 0.48)
			var tf: Transform3D = Transform3D(
				corner_basis,
				Vector3(corner_pos.x, top + 0.12 - OUTER_WALL_BASE_SINK, corner_pos.z)
			)
			context._add_asset_instance(terrain_root, "cave_corner", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	# The gray dungeon target wants floor-to-wall masonry, not a cave-style outer shelf.

func _add_outer_top_ledge(
	context,
	terrain_root: Node3D,
	min_tile: Vector2i,
	max_tile: Vector2i,
	tile_world_size: float,
	ground_tops: Dictionary
) -> void:
	if terrain_root == null:
		return
	var min_center: Vector3 = context._tile_world_position(min_tile)
	var max_center: Vector3 = context._tile_world_position(max_tile)
	var min_x: float = min_center.x - tile_world_size * 0.5
	var max_x: float = max_center.x + tile_world_size * 0.5
	var min_z: float = min_center.z - tile_world_size * 0.5
	var max_z: float = max_center.z + tile_world_size * 0.5
	var ledge_top: float = _average_perimeter_floor_top(context, min_tile, max_tile, ground_tops) + OUTER_TOP_LEDGE_HEIGHT_OFFSET
	var mesh: ArrayMesh = _build_outer_top_ledge_mesh(min_x, max_x, min_z, max_z, ledge_top, tile_world_size * OUTER_TOP_LEDGE_WIDTH, -0.85)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = "OuterTopDungeonLedge"
	inst.mesh = mesh
	inst.material_override = _dungeon_surround_stone_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_root.add_child(inst)

func _average_perimeter_floor_top(context, min_tile: Vector2i, max_tile: Vector2i, ground_tops: Dictionary) -> float:
	var total: float = 0.0
	var count: int = 0
	for x in range(min_tile.x, max_tile.x + 1):
		var north: Vector2i = Vector2i(x, min_tile.y)
		var south: Vector2i = Vector2i(x, max_tile.y)
		total += float(ground_tops.get(context._tile_key(north), 0.0))
		total += float(ground_tops.get(context._tile_key(south), 0.0))
		count += 2
	for y in range(min_tile.y + 1, max_tile.y):
		var west: Vector2i = Vector2i(min_tile.x, y)
		var east: Vector2i = Vector2i(max_tile.x, y)
		total += float(ground_tops.get(context._tile_key(west), 0.0))
		total += float(ground_tops.get(context._tile_key(east), 0.0))
		count += 2
	return total / float(maxi(1, count))

func _build_outer_top_ledge_mesh(
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float,
	ledge_top: float,
	ledge_width: float,
	inner_lip: float = 0.42
) -> ArrayMesh:
	var outer_min_x: float = min_x - ledge_width
	var outer_max_x: float = max_x + ledge_width
	var outer_min_z: float = min_z - ledge_width
	var outer_max_z: float = max_z + ledge_width
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var rings: Array = [
		[
			Vector3(outer_min_x, ledge_top + 0.04, outer_min_z),
			Vector3(outer_max_x, ledge_top - 0.02, outer_min_z),
			Vector3(outer_max_x, ledge_top + 0.02, outer_max_z),
			Vector3(outer_min_x, ledge_top - 0.03, outer_max_z),
		],
		[
			Vector3(min_x + inner_lip, ledge_top - 0.08, min_z + inner_lip),
			Vector3(max_x - inner_lip, ledge_top - 0.06, min_z + inner_lip),
			Vector3(max_x - inner_lip, ledge_top - 0.08, max_z - inner_lip),
			Vector3(min_x + inner_lip, ledge_top - 0.06, max_z - inner_lip),
		],
	]
	for ring_index in range(rings.size()):
		var ring: Array = rings[ring_index]
		for i in range(4):
			vertices.push_back(ring[i])
			normals.push_back(Vector3.UP)
			uvs.push_back(Vector2(float(i == 1 or i == 2), float(i >= 2)))
	for i in range(4):
		var next_i: int = (i + 1) % 4
		var outer_a: int = i
		var outer_b: int = next_i
		var inner_a: int = 4 + i
		var inner_b: int = 4 + next_i
		indices.push_back(outer_a)
		indices.push_back(inner_a)
		indices.push_back(inner_b)
		indices.push_back(outer_a)
		indices.push_back(inner_b)
		indices.push_back(outer_b)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _add_perimeter_wall_segment(
	context,
	terrain_root: Node3D,
	tile_world_size: float,
	ground_tops: Dictionary,
	tile: Vector2i,
	outward_dir: Vector3,
	yaw_deg: float,
	edge_kind: String,
	min_tile: Vector2i,
	max_tile: Vector2i
) -> void:
	var edge_profile: Dictionary = _perimeter_segment_profile(edge_kind, tile, min_tile, max_tile)
	var edge_span: int = int(edge_profile.get("span", 1))
	var edge_index: int = int(edge_profile.get("index", 0))
	var edge_id: int = int(edge_profile.get("edge_id", 0))
	var span_t: float = 0.5
	if edge_span > 1:
		span_t = float(edge_index) / float(edge_span - 1)
	if edge_kind == "south" and span_t >= FRONT_WALL_CUTOUT_MIN and span_t <= FRONT_WALL_CUTOUT_MAX:
		return

	var center: Vector3 = context._tile_world_position(tile)
	var top: float = float(ground_tops.get(context._tile_key(tile), 0.0))
	var tilt_x_deg: float = 0.0
	var tilt_z_deg: float = 0.0
	var yaw_variation_deg: float = float(edge_profile.get("yaw_offset_deg", 0.0))
	var tangent: Vector3 = Vector3(outward_dir.z, 0.0, -outward_dir.x).normalized()
	var tangent_shift_tiles: float = float(edge_profile.get("tangent_shift_tiles", 0.0))
	var height_scale: float = 1.48
	if edge_kind == "south":
		height_scale = 1.08
	var height_mul: float = float(edge_profile.get("height_mul", 1.0))
	var thickness_mul: float = float(edge_profile.get("thickness_mul", 1.0))
	var wall_scale: Vector3 = Vector3(
		1.04 * thickness_mul,
		height_scale * height_mul,
		1.04 * thickness_mul
	)
	var wall_basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(tilt_x_deg),
		deg_to_rad(yaw_deg + yaw_variation_deg),
		deg_to_rad(tilt_z_deg)
	)).scaled(wall_scale)
	var outward_shift_tiles: float = 0.38 + float(edge_profile.get("outward_shift_tiles", 0.0))
	var pos: Vector3 = center + outward_dir.normalized() * (tile_world_size * outward_shift_tiles) + tangent * (tile_world_size * tangent_shift_tiles)
	var tf: Transform3D = Transform3D(
		wall_basis,
		Vector3(pos.x, top + 0.06 - OUTER_WALL_BASE_SINK, pos.z)
	)
	context._add_asset_instance(terrain_root, "cave_wall", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _add_perimeter_wall_core_runs(
	context,
	terrain_root: Node3D,
	tile_world_size: float,
	ground_tops: Dictionary,
	min_tile: Vector2i,
	max_tile: Vector2i
) -> void:
	if terrain_root == null:
		return
	var min_center: Vector3 = context._tile_world_position(min_tile)
	var max_center: Vector3 = context._tile_world_position(max_tile)
	var min_x: float = min_center.x - tile_world_size * 0.5
	var max_x: float = max_center.x + tile_world_size * 0.5
	var min_z: float = min_center.z - tile_world_size * 0.5
	var max_z: float = max_center.z + tile_world_size * 0.5
	var avg_top: float = _average_perimeter_floor_top(context, min_tile, max_tile, ground_tops)
	var wall_height: float = tile_world_size * 1.55
	var wall_thickness: float = tile_world_size * 0.34
	var y: float = avg_top - 0.22 + wall_height * 0.5
	var overlap: float = tile_world_size * 0.12
	_add_wall_core_box(
		terrain_root,
		Vector3((min_x + max_x) * 0.5, y, min_z - tile_world_size * 0.48),
		Vector3((max_x - min_x) + overlap * 2.0, wall_height, wall_thickness)
	)
	var south_cut_min: float = lerpf(min_x, max_x, FRONT_WALL_CUTOUT_MIN)
	var south_cut_max: float = lerpf(min_x, max_x, FRONT_WALL_CUTOUT_MAX)
	if south_cut_min > min_x + tile_world_size:
		_add_wall_core_box(
			terrain_root,
			Vector3((min_x + south_cut_min) * 0.5, y, max_z + tile_world_size * 0.48),
			Vector3((south_cut_min - min_x) + overlap, wall_height * 0.86, wall_thickness)
		)
	if south_cut_max < max_x - tile_world_size:
		_add_wall_core_box(
			terrain_root,
			Vector3((south_cut_max + max_x) * 0.5, y, max_z + tile_world_size * 0.48),
			Vector3((max_x - south_cut_max) + overlap, wall_height * 0.86, wall_thickness)
		)
	_add_wall_core_box(
		terrain_root,
		Vector3(min_x - tile_world_size * 0.48, y, (min_z + max_z) * 0.5),
		Vector3(wall_thickness, wall_height, (max_z - min_z) + overlap * 2.0)
	)
	_add_wall_core_box(
		terrain_root,
		Vector3(max_x + tile_world_size * 0.48, y, (min_z + max_z) * 0.5),
		Vector3(wall_thickness, wall_height, (max_z - min_z) + overlap * 2.0)
	)

func _add_wall_core_box(terrain_root: Node3D, center: Vector3, size: Vector3) -> void:
	var box: MeshInstance3D = MeshInstance3D.new()
	box.name = "PerimeterMasonryCore"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.position = center
	box.material_override = _wall_core_stone_material()
	box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_root.add_child(box)

func _add_outer_wall_contact_patch(
	terrain_root: Node3D,
	pos: Vector3,
	floor_top: float,
	yaw_deg: float,
	footprint: Vector2
) -> void:
	if terrain_root == null:
		return
	var patch: MeshInstance3D = MeshInstance3D.new()
	patch.name = "OuterWallContact"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.50
	mesh.bottom_radius = 0.50
	mesh.height = OUTER_WALL_CONTACT_HEIGHT
	mesh.radial_segments = 18
	patch.mesh = mesh
	patch.position = Vector3(pos.x, floor_top - OUTER_WALL_CONTACT_SINK + OUTER_WALL_CONTACT_HEIGHT * 0.5, pos.z)
	patch.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	patch.scale = Vector3(maxf(0.10, footprint.x), 1.0, maxf(0.10, footprint.y))
	patch.material_override = _outer_wall_contact_material()
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_root.add_child(patch)

func _outer_wall_contact_material() -> StandardMaterial3D:
	if _wall_contact_material != null:
		return _wall_contact_material
	_wall_contact_material = StandardMaterial3D.new()
	_wall_contact_material.albedo_color = Color(0.070, 0.068, 0.064, 0.36)
	_wall_contact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_contact_material.roughness = 0.96
	_wall_contact_material.metallic = 0.0
	_wall_contact_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _wall_contact_material

func _wall_apron_stone_material() -> Material:
	if _wall_apron_material != null:
		return _wall_apron_material
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.245, 0.23, 1.0)
	mat.roughness = 0.96
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall_apron_material = mat
	return _wall_apron_material

func _wall_core_stone_material() -> StandardMaterial3D:
	if _wall_core_material != null:
		return _wall_core_material
	_wall_core_material = StandardMaterial3D.new()
	_wall_core_material.albedo_color = Color(0.245, 0.250, 0.252, 1.0)
	_wall_core_material.roughness = 0.94
	_wall_core_material.metallic = 0.0
	_wall_core_material.metallic_specular = 0.10
	_wall_core_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _wall_core_material

func _inner_wall_footing_stone_material() -> StandardMaterial3D:
	if _inner_wall_footing_material != null:
		return _inner_wall_footing_material
	_inner_wall_footing_material = StandardMaterial3D.new()
	_inner_wall_footing_material.albedo_color = Color(0.285, 0.292, 0.296, 1.0)
	_inner_wall_footing_material.roughness = 0.96
	_inner_wall_footing_material.metallic = 0.0
	_inner_wall_footing_material.metallic_specular = 0.08
	_inner_wall_footing_material.cull_mode = BaseMaterial3D.CULL_BACK
	return _inner_wall_footing_material

func _dungeon_surround_stone_material() -> StandardMaterial3D:
	if _dungeon_surround_material != null:
		return _dungeon_surround_material
	_dungeon_surround_material = StandardMaterial3D.new()
	_dungeon_surround_material.albedo_color = Color(0.18, 0.185, 0.19, 1.0)
	_dungeon_surround_material.roughness = 0.98
	_dungeon_surround_material.metallic = 0.0
	_dungeon_surround_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dungeon_surround_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _dungeon_surround_material

func _add_wall_apron_mesh(
	terrain_root: Node3D,
	pos: Vector3,
	floor_top: float,
	yaw_deg: float,
	footprint: Vector2,
	height: float,
	seed: int
) -> void:
	if terrain_root == null:
		return
	var segments: int = 18
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.push_back(Vector3.ZERO)
	normals.push_back(Vector3.UP)
	uvs.push_back(Vector2(0.5, 0.5))
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		var r: float = 1.0
		r += sin(angle * 3.0 + float(seed) * 0.17) * 0.10
		r += cos(angle * 5.0 + float(seed) * 0.11) * 0.055
		var x: float = cos(angle) * footprint.x * r
		var z: float = sin(angle) * footprint.y * r
		var y: float = sin(angle * 2.0 + float(seed) * 0.07) * height
		vertices.push_back(Vector3(x, y, z))
		normals.push_back(Vector3.UP)
		uvs.push_back(Vector2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5))
	for i in range(segments):
		indices.push_back(0)
		indices.push_back(1 + i)
		indices.push_back(1 + ((i + 1) % segments))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = "WallEmbeddedApron"
	inst.mesh = mesh
	inst.position = Vector3(pos.x, floor_top - 0.018, pos.z)
	inst.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	inst.material_override = _wall_apron_stone_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_root.add_child(inst)

func edge_id_from_kind(edge_kind: String) -> int:
	match edge_kind:
		"north":
			return 0
		"south":
			return 1
		"west":
			return 2
		"east":
			return 3
	return 4

func _perimeter_segment_profile(edge_kind: String, tile: Vector2i, min_tile: Vector2i, max_tile: Vector2i) -> Dictionary:
	var edge_id: int = 0
	match edge_kind:
		"north":
			edge_id = 0
		"south":
			edge_id = 1
		"west":
			edge_id = 2
		"east":
			edge_id = 3

	var edge_span: int = 1
	var edge_index: int = 0
	if edge_kind == "north" or edge_kind == "south":
		edge_span = maxi(1, max_tile.x - min_tile.x + 1)
		edge_index = clampi(tile.x - min_tile.x, 0, edge_span - 1)
	else:
		edge_span = maxi(1, max_tile.y - min_tile.y + 1)
		edge_index = clampi(tile.y - min_tile.y, 0, edge_span - 1)

	var segment_len: int = 4
	var segment_index: int = edge_index / maxi(1, segment_len)
	var local_index: int = int(posmod(edge_index, segment_len))
	var is_end_cap: bool = edge_index <= 0 or edge_index >= edge_span - 1

	var outward_shift_tiles: float = 0.0
	var tangent_shift_tiles: float = 0.0
	var yaw_offset_deg: float = 0.0
	var height_mul: float = 1.0
	var thickness_mul: float = 1.0
	if not is_end_cap:
		var group_phase: int = int(posmod(segment_index + edge_id, 3))
		height_mul = 1.00 + float(group_phase - 1) * 0.025
		thickness_mul = 1.00 + (0.025 if local_index == 0 or local_index == segment_len - 1 else 0.0)

	var near_corner: bool = edge_index <= 1 or edge_index >= edge_span - 2
	if near_corner:
		height_mul = maxf(height_mul, 1.06)
		thickness_mul = maxf(thickness_mul, 1.05)

	return {
		"edge_id": edge_id,
		"index": edge_index,
		"span": edge_span,
		"outward_shift_tiles": outward_shift_tiles,
		"tangent_shift_tiles": tangent_shift_tiles,
		"yaw_offset_deg": yaw_offset_deg,
		"height_mul": height_mul,
		"thickness_mul": thickness_mul,
	}

func _build_asset_kit_blockers(
	context,
	terrain_root: Node3D,
	state: GameState,
	ground_tops: Dictionary,
	floor_surface_tops: Dictionary,
	rendered_inner_wall_tiles: Dictionary,
	_board_top: float
) -> void:
	if state == null:
		return
	var blocker_mat: Material = context._default_asset_material_for("blocker_wall")
	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not state.is_blocked(tile):
				continue
			var center: Vector3 = context._tile_world_position(tile)
			var top: float = float(floor_surface_tops.get(context._tile_key(tile), float(ground_tops.get(context._tile_key(tile), 0.0))))
			var yaw_deg: float = 90.0 if int(abs(tile.x + tile.y)) % 2 == 1 else 0.0
			var scale: Vector3 = Vector3(0.98, INNER_WALL_ASSET_HEIGHT, 0.98)
			var basis: Basis = Basis.from_euler(Vector3(
				0.0,
				deg_to_rad(yaw_deg),
				0.0
			)).scaled(scale)
			var tf: Transform3D = Transform3D(basis, center + Vector3(0.0, top - INNER_WALL_BASE_SINK, 0.0))
			context._add_asset_instance(terrain_root, "blocker_wall", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, blocker_mat)
			ground_tops[context._tile_key(tile)] = maxf(float(ground_tops.get(context._tile_key(tile), 0.0)), top + INNER_WALL_HEIGHT)
			rendered_inner_wall_tiles[context._tile_key(tile)] = true
	_add_inner_wall_footing_runs(context, terrain_root, state, floor_surface_tops)

func _add_inner_wall_footing_runs(
	context,
	terrain_root: Node3D,
	state: GameState,
	floor_surface_tops: Dictionary
) -> void:
	if terrain_root == null or state == null:
		return
	var visited: Dictionary = {}
	for key_variant in state.wall_tiles.keys():
		var key: String = String(key_variant)
		if visited.has(key):
			continue
		var start: Vector2i = context._tile_from_key(key)
		if not state.is_inside(start) or not state.is_blocked(start):
			continue
		var horizontal: bool = state.is_blocked(start + Vector2i.LEFT) or state.is_blocked(start + Vector2i.RIGHT)
		var step: Vector2i = Vector2i.RIGHT if horizontal else Vector2i.DOWN
		var run_start: Vector2i = start
		while state.is_blocked(run_start - step):
			run_start -= step
		var run_tiles: Array[Vector2i] = []
		var cursor: Vector2i = run_start
		while state.is_blocked(cursor):
			var run_key: String = context._tile_key(cursor)
			visited[run_key] = true
			run_tiles.append(cursor)
			cursor += step
		if run_tiles.is_empty():
			continue
		_add_inner_wall_footing_run(context, terrain_root, run_tiles, horizontal, floor_surface_tops)

func _add_inner_wall_footing_run(
	context,
	terrain_root: Node3D,
	run_tiles: Array[Vector2i],
	horizontal: bool,
	floor_surface_tops: Dictionary
) -> void:
	var first_tile: Vector2i = run_tiles.front()
	var last_tile: Vector2i = run_tiles.back()
	var first_center: Vector3 = context._tile_world_position(first_tile)
	var last_center: Vector3 = context._tile_world_position(last_tile)
	var top_total: float = 0.0
	for tile in run_tiles:
		top_total += float(floor_surface_tops.get(context._tile_key(tile), 0.0))
	var top: float = top_total / float(maxi(1, run_tiles.size()))
	var center: Vector3 = (first_center + last_center) * 0.5
	var length: float = float(run_tiles.size()) * 0.96
	var size: Vector3
	if horizontal:
		size = Vector3(length, 0.24, 0.94)
	else:
		size = Vector3(0.94, 0.24, length)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var footing: MeshInstance3D = MeshInstance3D.new()
	footing.name = "InnerWallMasonryFooting"
	footing.mesh = mesh
	footing.position = Vector3(center.x, top - 0.010 + size.y * 0.5, center.z)
	footing.material_override = _inner_wall_footing_stone_material()
	footing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain_root.add_child(footing)

func _add_cave_doors(
	context,
	terrain_root: Node3D,
	state: GameState,
	tile_world_size: float,
	board_min: Vector3,
	board_max: Vector3,
	_camera_base_target: Vector3
) -> void:
	if state == null:
		return
	var left_tile: Vector2i = state.entrance_tile
	var right_tile: Vector2i = state.door_tile
	var left_center: Vector3 = context._tile_world_position(left_tile)
	var right_center: Vector3 = context._tile_world_position(right_tile)
	var left_top: float = context._tile_ground_top(left_tile) if state.is_inside(left_tile) else 0.0
	var right_top: float = context._tile_ground_top(right_tile) if state.is_inside(right_tile) else 0.0
	var left_pos: Vector3 = Vector3(board_min.x + tile_world_size * 0.18, left_top, left_center.z)
	var right_pos: Vector3 = Vector3(board_max.x - tile_world_size * 0.18, right_top, right_center.z)
	var right_is_closed: bool = state.door_hp > 0

	if not context._has_asset_scene("door_arch"):
		return
	var left_tf: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90.0)).scaled(Vector3(1.02, 1.18, 0.96)),
		left_pos + Vector3(0.0, 0.02, 0.0)
	)
	context._add_asset_instance(terrain_root, "door_arch", left_tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_objective_door_panel(terrain_root, left_pos, Color(0.08, 0.28, 0.62, 1.0), true)

	var right_scale: Vector3 = Vector3(1.02, 1.22, 0.96) if right_is_closed else Vector3(0.98, 1.12, 0.92)
	var right_tf: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-90.0)).scaled(right_scale),
		right_pos + Vector3(0.0, 0.02, 0.0)
	)
	context._add_asset_instance(terrain_root, "door_arch", right_tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_objective_door_panel(terrain_root, right_pos, Color(0.66, 0.05, 0.12, 1.0), false)

	var left_door_glow: OmniLight3D = OmniLight3D.new()
	left_door_glow.position = left_pos + Vector3(0.0, 0.92, 0.0)
	left_door_glow.light_color = Color(0.28, 0.58, 0.90, 1.0)
	left_door_glow.light_energy = 0.34
	left_door_glow.omni_range = 2.8
	left_door_glow.shadow_enabled = false
	terrain_root.add_child(left_door_glow)

	var right_door_glow: OmniLight3D = OmniLight3D.new()
	right_door_glow.position = right_pos + Vector3(0.0, 0.92, 0.0)
	right_door_glow.light_color = Color(0.92, 0.58, 0.28, 1.0)
	right_door_glow.light_energy = 0.42 if right_is_closed else 0.28
	right_door_glow.omni_range = 3.0
	right_door_glow.shadow_enabled = false
	terrain_root.add_child(right_door_glow)

func _add_objective_door_panel(terrain_root: Node3D, base_pos: Vector3, color: Color, left_side: bool) -> void:
	if terrain_root == null:
		return
	var panel_mesh: BoxMesh = BoxMesh.new()
	panel_mesh.size = Vector3(0.070, 1.02, 0.72)
	var panel_mat: StandardMaterial3D = StandardMaterial3D.new()
	panel_mat.albedo_color = color
	panel_mat.roughness = 0.62
	panel_mat.metallic = 0.0
	panel_mat.emission_enabled = true
	panel_mat.emission = color
	panel_mat.emission_energy_multiplier = 0.06
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.name = "ObjectiveDoorPanel"
	panel.mesh = panel_mesh
	panel.material_override = panel_mat
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var inset_x: float = 0.045 if left_side else -0.045
	panel.position = base_pos + Vector3(inset_x, 0.58, 0.0)
	terrain_root.add_child(panel)
