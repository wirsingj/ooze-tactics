extends Node3D
class_name World3DRenderer

const PLAYER_TINT: Color = Color(0.30, 0.93, 0.78, 1.0)
const CAVE_FLOOR_BASE: Color = Color(0.36, 0.31, 0.27, 1.0)
const CAVE_FLOOR_ALT: Color = Color(0.21, 0.18, 0.15, 1.0)
const CAVE_WALL_BASE: Color = Color(0.27, 0.23, 0.20, 1.0)
const CAVE_WALL_ALT: Color = Color(0.12, 0.10, 0.09, 1.0)

const CAMERA_MIN_DISTANCE: float = 8.0
const CAMERA_MAX_DISTANCE: float = 62.0
const CAMERA_MIN_PITCH: float = deg_to_rad(22.0)
const CAMERA_MAX_PITCH: float = deg_to_rad(74.0)
const CAMERA_YAW_MIN: float = deg_to_rad(-128.0)
const CAMERA_YAW_MAX: float = deg_to_rad(42.0)
const CAMERA_DEFAULT_YAW: float = deg_to_rad(-34.0)
const CAMERA_DEFAULT_PITCH: float = deg_to_rad(49.0)
const CAMERA_DRAG_THRESHOLD: float = 6.0
const DRAG_NONE: int = 0
const DRAG_ORBIT: int = 1
const DRAG_PAN: int = 2
const OOZE_MASK_SCALE: int = 10
const OOZE_MASK_SMOOTH_PASSES: int = 4
const OOZE_ENABLE_FRAGMENTED_SURFACE_DETAILS: bool = false

# Known-good stabilization lock for gameplay readability.
# Future art experiments should preserve this as the quick revert baseline.
const STABILIZATION_BASELINE_ID: String = "gameplay_readability_v1"
const STABILIZATION_CAMERA_BASELINE := {
	"default_yaw": CAMERA_DEFAULT_YAW,
	"default_pitch": CAMERA_DEFAULT_PITCH,
	"yaw_min": CAMERA_YAW_MIN,
	"yaw_max": CAMERA_YAW_MAX,
	"pitch_min": CAMERA_MIN_PITCH,
	"pitch_max": CAMERA_MAX_PITCH,
	"distance_min": CAMERA_MIN_DISTANCE,
	"distance_max": CAMERA_MAX_DISTANCE,
}
const STABILIZATION_ENV_BASELINE := {
	"background_color": Color(0.02, 0.018, 0.016, 1.0),
	"ambient_color": Color(0.42, 0.40, 0.37, 1.0),
	"ambient_energy": 1.06,
	"brightness": 1.00,
	"contrast": 1.04,
	"saturation": 1.02,
	"fog_enabled": false,
	"fog_density": 0.0,
}
const STABILIZATION_LIGHT_BASELINE := {
	"key_energy": 1.95,
	"fill_energy": 1.08,
	"fill_range": 88.0,
	"rim_energy": 0.26,
}
const STONE_ALBEDO_TEXTURE_PATH: String = "res://assets/world3d/generated/stone_albedo.png"
const STONE_ROUGHNESS_TEXTURE_PATH: String = "res://assets/world3d/generated/stone_roughness.png"
const STONE_NORMAL_TEXTURE_PATH: String = "res://assets/world3d/generated/stone_normal.png"
const SLIME_DETAIL_TEXTURE_PATH: String = "res://assets/world3d/generated/slime_detail.png"

const POOL_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 owner_color : source_color = vec4(0.3, 0.9, 0.8, 1.0);
uniform sampler2D mask_tex;
uniform sampler2D detail_tex;
uniform vec2 texel_size = vec2(0.01, 0.01);
uniform float pulse_speed = 0.42;
uniform float bubble_strength = 0.006;
uniform float emission_strength = 0.010;
uniform float detail_scale = 22.0;
uniform float body_thickness = 0.010;
uniform float lip_thickness = 0.018;
uniform float flow_scale = 1.8;
uniform float flow_speed = 0.020;
uniform float flow_normal_strength = 0.55;
uniform float edge_darkening_strength = 0.18;
uniform float contact_darkening_strength = 0.14;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	float m = texture(mask_tex, UV).a;
	float body = smoothstep(0.22, 0.92, m);
	float lip = smoothstep(0.40, 0.74, m) - smoothstep(0.80, 0.98, m);
	vec2 flow_uv = UV * flow_scale + vec2(TIME * flow_speed, -TIME * flow_speed * 0.72);
	float flow0 = texture(detail_tex, flow_uv).r;
	float flow1 = texture(detail_tex, flow_uv + vec2(0.13, -0.09)).r;
	float flow = (flow0 * 0.62 + flow1 * 0.38) - 0.5;
	float wave = sin((VERTEX.x + VERTEX.z) * 1.9 + TIME * pulse_speed) * 0.5;
	wave += sin((VERTEX.x * 0.9 - VERTEX.z * 1.1) * 1.4 + TIME * pulse_speed * 1.12) * 0.5;
	float disp = body * body_thickness + lip * lip_thickness;
	disp += flow * bubble_strength * 0.90;
	disp += wave * bubble_strength * 0.35;
	VERTEX.y += disp;
}

void fragment() {
	float m0 = texture(mask_tex, UV).a;
	float m1 = texture(mask_tex, UV + vec2(texel_size.x, 0.0)).a;
	float m2 = texture(mask_tex, UV + vec2(0.0, texel_size.y)).a;
	float m3 = texture(mask_tex, UV + vec2(texel_size.x, texel_size.y)).a;
	float mask = (m0 * 0.58) + (m1 + m2) * 0.16 + m3 * 0.10;
	mask = clamp(mask, 0.0, 1.0);
	float alpha = smoothstep(0.18, 0.86, mask);
	if (alpha < 0.02) {
		discard;
	}
	float gx = texture(mask_tex, UV + vec2(texel_size.x, 0.0)).a - texture(mask_tex, UV - vec2(texel_size.x, 0.0)).a;
	float gy = texture(mask_tex, UV + vec2(0.0, texel_size.y)).a - texture(mask_tex, UV - vec2(0.0, texel_size.y)).a;
	vec2 grad = vec2(gx, gy);
	float grad_len = length(grad);
	float lip = smoothstep(0.40, 0.74, mask) - smoothstep(0.80, 0.98, mask);
	float thickness = smoothstep(0.22, 0.92, mask);
	float edge_band = clamp(lip * (0.75 + grad_len * 8.0), 0.0, 1.0);

	vec2 flow_uv = UV * flow_scale + vec2(TIME * flow_speed, -TIME * flow_speed * 0.72);
	float flow0 = texture(detail_tex, flow_uv).r;
	float flowx = texture(detail_tex, flow_uv + vec2(0.012, 0.0)).r;
	float flowy = texture(detail_tex, flow_uv + vec2(0.0, 0.012)).r;
	vec2 flow_grad = vec2(flowx - flow0, flowy - flow0);
	float broad = fbm(UV * (detail_scale * 0.22) + vec2(TIME * 0.024, -TIME * 0.018));
	float broad2 = fbm(UV * (detail_scale * 0.13) - vec2(TIME * 0.012, TIME * 0.009));
	float surface_wave = clamp(broad * 0.62 + broad2 * 0.38, 0.0, 1.0);

	vec2 normal_xy = flow_grad * flow_normal_strength * 2.0 + grad * (lip * 0.45);
	vec3 mapped_normal = normalize(vec3(normal_xy, 1.0));
	NORMAL_MAP = mapped_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	float shimmer = 0.5 + 0.5 * sin(TIME * 0.26 + UV.x * 1.8 + UV.y * 1.6);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.45);
	vec3 deep_col = owner_color.rgb * 0.34;
	vec3 mid_col = owner_color.rgb * 0.58;
	vec3 base_col = mix(deep_col, mid_col, thickness);
	base_col *= 0.92 + surface_wave * 0.14 + shimmer * 0.05;
	base_col = mix(base_col, base_col * 0.78, edge_darkening_strength * edge_band);
	base_col = mix(base_col, base_col * 0.70, contact_darkening_strength * edge_band);
	base_col += owner_color.rgb * (fres * 0.035 + edge_band * 0.018);

	ALBEDO = base_col;
	ROUGHNESS = clamp(0.44 - thickness * 0.15 - edge_band * 0.09 + (1.0 - surface_wave) * 0.05, 0.16, 0.58);
	METALLIC = 0.0;
	SPECULAR = 0.56;
	CLEARCOAT = clamp(0.22 + edge_band * 0.34, 0.0, 1.0);
	CLEARCOAT_GLOSS = 0.82;
	EMISSION = owner_color.rgb * (
		0.00018
		+ emission_strength * (0.0035 + thickness * 0.004 + edge_band * 0.003)
	);
	ALPHA = alpha * 0.96;
}
"""

const HAZE_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 haze_color : source_color = vec4(0.36, 0.33, 0.28, 0.08);
uniform float noise_scale = 5.0;
uniform float drift_speed = 0.020;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv0 = UV * noise_scale + vec2(TIME * drift_speed, -TIME * drift_speed * 0.7);
	vec2 uv1 = UV * (noise_scale * 1.9) - vec2(TIME * drift_speed * 0.5, TIME * drift_speed * 0.35);
	float n0 = noise(uv0);
	float n1 = noise(uv1);
	float veil = clamp(n0 * 0.62 + n1 * 0.38, 0.0, 1.0);
	float fade = smoothstep(0.02, 0.22, UV.x) * smoothstep(0.02, 0.22, UV.y) *
		(1.0 - smoothstep(0.78, 0.98, UV.x)) * (1.0 - smoothstep(0.78, 0.98, UV.y));
	float alpha = haze_color.a * (0.45 + veil * 0.55) * fade;
	ALBEDO = haze_color.rgb;
	EMISSION = haze_color.rgb * 0.018;
	ALPHA = alpha;
}
"""

const STONE_SHADER_CODE: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 stone_base : source_color = vec4(0.30, 0.24, 0.19, 1.0);
uniform vec4 stone_alt : source_color = vec4(0.19, 0.16, 0.14, 1.0);
uniform vec4 damp_tint : source_color = vec4(0.11, 0.17, 0.16, 1.0);
uniform float uv_scale = 12.0;
uniform sampler2D detail_albedo_tex : source_color;
uniform sampler2D detail_roughness_tex;
uniform sampler2D detail_normal_tex : hint_normal;
uniform float detail_mix = 0.68;
uniform float normal_strength = 0.62;
uniform float height_amp = 0.03;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
	vec2 p = UV * uv_scale;
	float n0 = noise(p);
	float n1 = noise(p * 2.1 + vec2(5.2, 2.7));
	float disp = (n0 * 0.65 + n1 * 0.35) - 0.5;
	VERTEX.y += disp * height_amp;
}

void fragment() {
	vec2 p = UV * uv_scale;
	float n0 = noise(p);
	float n1 = noise(p * 2.3 + vec2(7.2, 1.9));
	float n2 = noise(p * 4.1 + vec2(3.1, 8.7));
	float n3 = noise(p * 7.4 + vec2(9.4, 2.7));
	float blend = clamp(n0 * 0.50 + n1 * 0.28 + n2 * 0.14 + n3 * 0.08, 0.0, 1.0);
	float damp = smoothstep(0.52, 0.88, n1);
	float crack_field = abs(n2 - n3);
	float cracks = 1.0 - smoothstep(0.08, 0.20, crack_field);
	vec2 tex_uv = UV * max(1.0, uv_scale * 0.17);
	vec3 detail_col = texture(detail_albedo_tex, tex_uv).rgb;
	float detail_rough = texture(detail_roughness_tex, tex_uv).r;
	vec3 detail_nrm = texture(detail_normal_tex, tex_uv).rgb;
	vec3 stone = mix(stone_alt.rgb, stone_base.rgb, blend);
	stone = mix(stone, detail_col, detail_mix);
	stone = mix(stone, damp_tint.rgb, damp * 0.30);
	stone = mix(stone, stone * 0.52, cracks * 0.28);
	ALBEDO = stone * 1.16 + vec3(0.018);
	ROUGHNESS = clamp((0.76 + n2 * 0.14 - damp * 0.16 + cracks * 0.06) * 0.60 + detail_rough * 0.40, 0.0, 1.0);
	METALLIC = 0.02;
	SPECULAR = 0.34;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), detail_nrm, normal_strength);
	NORMAL_MAP_DEPTH = 1.0;
}
"""

const ROLE_CREST_SHADER_CODE: String = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 crest_color : source_color = vec4(0.8, 0.8, 1.0, 1.0);
uniform vec4 crest_emission : source_color = vec4(0.8, 0.8, 1.0, 1.0);
uniform float crest_roughness = 0.52;
uniform float pulse_speed = 1.6;
uniform float pulse_amp = 0.018;

void vertex() {
	float phase = TIME * pulse_speed + WORLD_MATRIX[3].x * 1.9 + WORLD_MATRIX[3].z * 1.3;
	VERTEX.y += sin(phase) * pulse_amp;
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.x * 5.8 + UV.y * 4.1);
	ALBEDO = crest_color.rgb * (0.92 + pulse * 0.08);
	ROUGHNESS = crest_roughness;
	METALLIC = 0.01;
	EMISSION = crest_emission.rgb * (0.02 + pulse * 0.08);
}
"""

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


var tile_world_size: float = 1.0

var _state: GameState = null
var _palette_renderer: BoardRenderer = null
var _pool_material_cache: Dictionary = {}
var _marker_material_cache: Dictionary = {}
var _ground_tops: Dictionary = {}

var _viewport_size: Vector2i = Vector2i(1280, 720)
var _board_min: Vector3 = Vector3.ZERO
var _board_max: Vector3 = Vector3.ZERO
var _camera_base_target: Vector3 = Vector3.ZERO
var _visual_time: float = 0.0

var _selected_tile: Vector2i = Vector2i(-1, -1)
var _hovered_tile: Vector2i = Vector2i(-1, -1)
var _queued_tiles: Dictionary = {}
var _queued_actions: Array = []
var _hover_preview_action: Dictionary = {}
var _hover_invalid_reason: String = ""

var _last_static_stamp: String = ""
var _last_dynamic_stamp: String = ""
var _last_marker_stamp: String = ""

var _camera_pan_offset: Vector3 = Vector3.ZERO
var _camera_yaw: float = CAMERA_DEFAULT_YAW
var _camera_pitch: float = CAMERA_DEFAULT_PITCH
var _camera_distance: float = 24.0
var _camera_yaw_target: float = CAMERA_DEFAULT_YAW
var _camera_pitch_target: float = CAMERA_DEFAULT_PITCH
var _camera_distance_target: float = 24.0
var _camera_initialized: bool = false

var _drag_mode: int = DRAG_NONE
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _consume_left_release: bool = false

var _terrain_root: Node3D = null
var _dynamic_root: Node3D = null
var _marker_root: Node3D = null
var _camera: Camera3D = null
var _key_light: DirectionalLight3D = null
var _rim_light: DirectionalLight3D = null
var _fill_light: OmniLight3D = null
var _environment: WorldEnvironment = null
var _point_lights: Array[OmniLight3D] = []
var _haze_layer: MeshInstance3D = null

var _stone_texture_cache: Texture2D = null
var _stone_roughness_texture_cache: Texture2D = null
var _stone_normal_texture_cache: Texture2D = null
var _slime_detail_texture_cache: Texture2D = null
var _camera_contract_signature: String = ""
var _force_camera_reset: bool = false

func _ready() -> void:
	_build_scene_graph()

func configure(palette_renderer: BoardRenderer) -> void:
	_palette_renderer = palette_renderer

func reset_startup_contract() -> void:
	_force_camera_reset = true
	_camera_contract_signature = ""
	_camera_initialized = false

func set_viewport_size(size: Vector2i) -> void:
	_viewport_size = Vector2i(maxi(64, size.x), maxi(64, size.y))
	_update_camera_transform(true)

func sync_world(
	state: GameState,
	selected_tile: Vector2i,
	hovered_tile: Vector2i,
	queued_actions: Array,
	hover_preview_action: Dictionary,
	hover_invalid_reason: String,
	_recent_enemy_actions: Array,
	_anim_frame: int
) -> void:
	_state = state
	_selected_tile = selected_tile
	_hovered_tile = hovered_tile
	_queued_tiles = _extract_queued_tiles(queued_actions)
	_queued_actions = queued_actions
	_hover_preview_action = hover_preview_action
	_hover_invalid_reason = hover_invalid_reason
	if _state == null:
		return

	_refresh_board_bounds()

	var static_stamp: String = _make_static_stamp()
	if static_stamp != _last_static_stamp:
		_rebuild_static_world()
		_last_static_stamp = static_stamp
		_last_dynamic_stamp = ""
		_last_marker_stamp = ""

	var dynamic_stamp: String = _make_dynamic_stamp()
	if dynamic_stamp != _last_dynamic_stamp:
		_rebuild_dynamic_world()
		_last_dynamic_stamp = dynamic_stamp
		_last_marker_stamp = ""

	var marker_stamp: String = _make_marker_stamp()
	if marker_stamp != _last_marker_stamp:
		_rebuild_markers()
		_last_marker_stamp = marker_stamp

	# Camera ownership contract:
	# - sync/rebuild may only initialize camera once per explicit match/reset.
	# - gameplay turns and marker/dynamic rebuilds must not reset/recenter camera state.
	_apply_startup_visual_contract(static_stamp)
	_reset_camera_if_needed()
	_update_camera_transform(false)

func tick_visual(delta: float) -> void:
	_visual_time += maxf(0.0, delta)
	_animate_lights()
	_update_camera_transform(false)

func handle_camera_input(event: InputEvent, viewport_pos: Vector2, inside_board: bool) -> bool:
	if _state == null:
		return false

	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if not inside_board:
			if button_event.button_index == MOUSE_BUTTON_LEFT and not button_event.pressed:
				_drag_mode = DRAG_NONE
				_drag_moved = false
			return false

		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			_camera_distance_target = clampf(_camera_distance_target * 0.90, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
			return true
		if button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			_camera_distance_target = clampf(_camera_distance_target * 1.10, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
			return true

		if button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				_drag_mode = DRAG_PAN if _is_pan_modifier_active() else DRAG_ORBIT
				_drag_origin = viewport_pos
				_drag_moved = false
				_consume_left_release = false
				return false
			if _drag_mode != DRAG_NONE:
				_consume_left_release = _drag_moved
				_drag_mode = DRAG_NONE
				var consumed: bool = _consume_left_release
				_drag_moved = false
				return consumed
		return false

	if event is InputEventMouseMotion and _drag_mode != DRAG_NONE:
		var motion: InputEventMouseMotion = event
		if not _drag_moved and viewport_pos.distance_to(_drag_origin) >= CAMERA_DRAG_THRESHOLD:
			_drag_moved = true
		if _drag_moved:
			if _drag_mode == DRAG_PAN:
				_pan_camera(motion.relative)
			else:
				_orbit_camera(motion.relative)
			return true
		return false

	return false

func should_consume_left_release() -> bool:
	var consume: bool = _consume_left_release
	_consume_left_release = false
	return consume

func viewport_to_tile(viewport_pos: Vector2) -> Vector2i:
	if _state == null or _camera == null:
		return Vector2i(-1, -1)
	if viewport_pos.x < 0.0 or viewport_pos.y < 0.0:
		return Vector2i(-1, -1)
	if viewport_pos.x >= float(_viewport_size.x) or viewport_pos.y >= float(_viewport_size.y):
		return Vector2i(-1, -1)

	var ray_origin: Vector3 = _camera.project_ray_origin(viewport_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(viewport_pos)
	if absf(ray_dir.y) < 0.00001:
		return Vector2i(-1, -1)
	var t: float = (0.0 - ray_origin.y) / ray_dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit: Vector3 = ray_origin + ray_dir * t
	var tx: int = int(floor((hit.x - _board_min.x) / tile_world_size))
	var ty: int = int(floor((hit.z - _board_min.z) / tile_world_size))
	var tile: Vector2i = Vector2i(tx, ty)
	if not _state.is_inside(tile):
		return Vector2i(-1, -1)
	return tile

func _build_scene_graph() -> void:
	if _terrain_root != null:
		return

	_terrain_root = Node3D.new()
	_terrain_root.name = "TerrainRoot"
	add_child(_terrain_root)

	_dynamic_root = Node3D.new()
	_dynamic_root.name = "DynamicRoot"
	add_child(_dynamic_root)

	_marker_root = Node3D.new()
	_marker_root.name = "MarkerRoot"
	add_child(_marker_root)

	_camera = Camera3D.new()
	_camera.name = "TacticalCamera3D"
	_camera.current = true
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 42.0
	_camera.near = 0.05
	_camera.far = 240.0
	add_child(_camera)

	_key_light = DirectionalLight3D.new()
	_key_light.name = "CaveKeyLight"
	_key_light.light_color = Color(1.0, 0.90, 0.78, 1.0)
	_key_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["key_energy"])
	_key_light.shadow_enabled = true
	_key_light.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	add_child(_key_light)

	_rim_light = DirectionalLight3D.new()
	_rim_light.name = "RimLight"
	_rim_light.light_color = Color(0.30, 0.40, 0.54, 1.0)
	_rim_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["rim_energy"])
	_rim_light.shadow_enabled = false
	_rim_light.rotation_degrees = Vector3(-44.0, 145.0, 0.0)
	add_child(_rim_light)

	_fill_light = OmniLight3D.new()
	_fill_light.name = "CaveFillLight"
	_fill_light.light_color = Color(0.48, 0.45, 0.42, 1.0)
	_fill_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["fill_energy"])
	_fill_light.omni_range = float(STABILIZATION_LIGHT_BASELINE["fill_range"])
	add_child(_fill_light)

	_environment = WorldEnvironment.new()
	_environment.name = "CaveEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(STABILIZATION_ENV_BASELINE["background_color"])
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(STABILIZATION_ENV_BASELINE["ambient_color"])
	env.ambient_light_energy = float(STABILIZATION_ENV_BASELINE["ambient_energy"])
	env.ssao_enabled = false
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 2.2
	env.glow_intensity = 0.03
	env.fog_enabled = bool(STABILIZATION_ENV_BASELINE["fog_enabled"])
	env.fog_light_color = Color(0.20, 0.18, 0.16, 1.0)
	env.fog_light_energy = 0.20
	env.fog_density = float(STABILIZATION_ENV_BASELINE["fog_density"])
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_brightness = float(STABILIZATION_ENV_BASELINE["brightness"])
	env.adjustment_contrast = float(STABILIZATION_ENV_BASELINE["contrast"])
	env.adjustment_saturation = float(STABILIZATION_ENV_BASELINE["saturation"])
	_environment.environment = env
	add_child(_environment)

func _refresh_board_bounds() -> void:
	_board_min = Vector3(
		-float(_state.width) * tile_world_size * 0.5,
		0.0,
		-float(_state.height) * tile_world_size * 0.5
	)
	_board_max = Vector3(
		_board_min.x + float(_state.width) * tile_world_size,
		0.0,
		_board_min.z + float(_state.height) * tile_world_size
	)
	_camera_base_target = Vector3(
		_board_min.x + float(_state.width) * tile_world_size * 0.5,
		0.0,
		_board_min.z + float(_state.height) * tile_world_size * 0.5
	)

func _make_static_stamp() -> String:
	return "%d|%d|%d|%d" % [_state.width, _state.height, _state.level_index, _state.wall_tiles.size()]

func _make_dynamic_stamp() -> String:
	var consumed_resources: int = 0
	for node in _state.resource_nodes:
		if bool(node.get("consumed", false)):
			consumed_resources += 1
	var block_signature: int = 0
	for block in _state.blocks.values():
		var block_id: int = int(block.get("id", 0))
		var owner_id: int = int(block.get("owner", 0))
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		var tile_type: String = String(block.get("tile_type", "basic"))
		var tier: int = int(block.get("tier", 0))
		block_signature = int(
			(block_signature * 1103515245)
			+ block_id * 97
			+ owner_id * 193
			+ tile.x * 389
			+ tile.y * 769
			+ tier * 53
			+ hash(tile_type)
		)
	return "%d|%d|%d|%d" % [
		_state.blocks.size(),
		_state.next_block_id,
		_state.door_hp,
		block_signature + consumed_resources * 17,
	]

func _make_marker_stamp() -> String:
	var queued_keys: Array = _queued_tiles.keys()
	queued_keys.sort()
	var queued_joined: String = ""
	for key_variant in queued_keys:
		if not queued_joined.is_empty():
			queued_joined += ","
		queued_joined += String(key_variant)
	var preview_tile: Vector2i = _preview_target_tile(_hover_preview_action)
	var preview_key: String = _tile_key(preview_tile)
	var preview_kind: String = String(_hover_preview_action.get("type", "")) if not _hover_preview_action.is_empty() else ""
	var preview_role: String = String(_hover_preview_action.get("tile_type", _hover_preview_action.get("to_type", ""))) if not _hover_preview_action.is_empty() else ""
	var queued_sig: String = ""
	for action in _queued_actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = _queued_action_tile_role(action)
		if not queued_sig.is_empty():
			queued_sig += ","
		queued_sig += "%s:%s" % [_tile_key(info.get("tile", Vector2i(-1, -1))), String(info.get("role", "basic"))]
	return "%s|%s|%s|%s|%s|%s|%s" % [_tile_key(_selected_tile), _tile_key(_hovered_tile), queued_joined, preview_key, preview_kind, preview_role + ":" + _hover_invalid_reason, queued_sig]

func _rebuild_static_world() -> void:
	_clear_children(_terrain_root)
	_ground_tops.clear()
	if _state == null:
		return

	var board_width: float = float(_state.width) * tile_world_size
	var board_height: float = float(_state.height) * tile_world_size
	var board_top: float = 0.02

	var floor_base: MeshInstance3D = MeshInstance3D.new()
	var floor_base_mesh: BoxMesh = BoxMesh.new()
	floor_base_mesh.size = Vector3(board_width, 0.34, board_height)
	floor_base.mesh = floor_base_mesh
	floor_base.position = _camera_base_target + Vector3(0.0, board_top - 0.17, 0.0)
	var floor_base_mat: ShaderMaterial = _stone_shader_material(
		CAVE_FLOOR_BASE.lerp(Color(0.22, 0.19, 0.18, 1.0), 0.18),
		CAVE_FLOOR_ALT,
		Color(0.08, 0.08, 0.08, 1.0),
		18.0
	)
	floor_base.material_override = floor_base_mat
	floor_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_root.add_child(floor_base)

	var floor_skin: MeshInstance3D = MeshInstance3D.new()
	var floor_skin_mesh: PlaneMesh = PlaneMesh.new()
	floor_skin_mesh.size = Vector2(board_width, board_height)
	floor_skin_mesh.subdivide_width = maxi(24, int(board_width * 2.0))
	floor_skin_mesh.subdivide_depth = maxi(24, int(board_height * 2.0))
	floor_skin.mesh = floor_skin_mesh
	floor_skin.position = _camera_base_target + Vector3(0.0, board_top + 0.005, 0.0)
	floor_skin.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var floor_skin_mat: ShaderMaterial = _stone_shader_material(
		CAVE_FLOOR_BASE.lerp(Color(0.28, 0.25, 0.22, 1.0), 0.36),
		CAVE_FLOOR_ALT.lerp(Color(0.12, 0.11, 0.10, 1.0), 0.36),
		Color(0.08, 0.11, 0.12, 1.0),
		26.0,
		0.075,
		0.78
	)
	floor_skin.material_override = floor_skin_mat
	floor_skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(floor_skin)

	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(tile_world_size * 0.92, 0.90, tile_world_size * 0.92)
	var wall_transforms: Array[Transform3D] = []

	for y in range(_state.height):
		for x in range(_state.width):
			var tile: Vector2i = Vector2i(x, y)
			var center: Vector3 = _tile_world_position(tile)
			if _state.is_blocked(tile):
				var n: int = _tile_noise(x, y, _state.level_index)
				var wall_h: float = 0.80 + float(n % 6) * 0.06
				var tf_wall: Transform3D = Transform3D(
					Basis().scaled(Vector3(1.0, wall_h / wall_mesh.size.y, 1.0)),
					center + Vector3(0.0, board_top + wall_h * 0.5, 0.0)
				)
				wall_transforms.append(tf_wall)
				_ground_tops[_tile_key(tile)] = board_top + wall_h
			else:
				_ground_tops[_tile_key(tile)] = board_top

	if not wall_transforms.is_empty():
		var wall_material: ShaderMaterial = _stone_shader_material(
			CAVE_WALL_BASE.lerp(Color(0.23, 0.20, 0.18, 1.0), 0.35),
			CAVE_WALL_ALT,
			Color(0.11, 0.12, 0.12, 1.0),
			11.0,
			0.025,
			0.64
		)
		_terrain_root.add_child(_make_multimesh_instance(wall_mesh, wall_transforms, [], wall_material, true))

	# Recovery mode: keep the gameplay board clean/readable and avoid clutter noise.
	_add_wet_patches()
	_add_cave_doors()
	_add_torch_sconces()
	_add_cave_perimeter()
	# Recovery mode: avoid heavy/dark atmospheric overlays until baseline readability is stable.

func _rebuild_dynamic_world() -> void:
	_clear_children(_dynamic_root)
	_point_lights.clear()
	if _state == null:
		return

	var owner_blocks: Dictionary = {}
	for block in _state.blocks.values():
		var owner: int = int(block.get("owner", 0))
		if not owner_blocks.has(owner):
			owner_blocks[owner] = []
		owner_blocks[owner].append(block)

	for owner_variant in owner_blocks.keys():
		var owner_id: int = int(owner_variant)
		var blocks: Array = owner_blocks[owner_id]
		_build_owner_ooze(owner_id, blocks)
		_build_owner_meniscus(owner_id, blocks)
		if OOZE_ENABLE_FRAGMENTED_SURFACE_DETAILS:
			_build_owner_blob_caps(owner_id, blocks)
			_build_owner_micro_bubbles(owner_id, blocks)
			_build_owner_edge_beads(owner_id, blocks)
		_build_specialization_markers(owner_id, blocks)
		_build_heart_markers(owner_id, blocks)

	_build_world_points()

func _build_owner_ooze(owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return

	var tile_set: Dictionary = {}
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		tile_set[_tile_key(tile)] = tile
	var mask_tex: Texture2D = _build_owner_mask_texture(tile_set)
	if mask_tex == null:
		return

	var quad: MeshInstance3D = MeshInstance3D.new()
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(float(_state.width) * tile_world_size, float(_state.height) * tile_world_size)
	quad.mesh = quad_mesh
	quad.position = _camera_base_target + Vector3(0.0, 0.034, 0.0)
	quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.material_override = _owner_pool_material(owner_id, mask_tex)
	_dynamic_root.add_child(quad)

	# Keep ooze glow material-driven to avoid one dynamic light per owner.

func _build_owner_meniscus(owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		tile_set[_tile_key(tile)] = tile
	var mask_tex: Texture2D = _build_owner_mask_texture(tile_set)
	if mask_tex == null:
		return
	var quad: MeshInstance3D = MeshInstance3D.new()
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(float(_state.width) * tile_world_size, float(_state.height) * tile_world_size)
	quad.mesh = quad_mesh
	quad.position = _camera_base_target + Vector3(0.0, 0.042, 0.0)
	quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var meniscus: ShaderMaterial = _owner_pool_material(owner_id, mask_tex).duplicate(true)
	meniscus.set_shader_parameter("pulse_speed", 0.32)
	meniscus.set_shader_parameter("bubble_strength", 0.0018)
	meniscus.set_shader_parameter("emission_strength", 0.0022)
	meniscus.set_shader_parameter("detail_scale", 6.0)
	meniscus.set_shader_parameter("body_thickness", 0.0045)
	meniscus.set_shader_parameter("lip_thickness", 0.021)
	meniscus.set_shader_parameter("flow_scale", 1.45)
	meniscus.set_shader_parameter("flow_speed", 0.015)
	meniscus.set_shader_parameter("flow_normal_strength", 0.42)
	meniscus.set_shader_parameter("edge_darkening_strength", 0.24)
	meniscus.set_shader_parameter("contact_darkening_strength", 0.20)
	quad.material_override = meniscus
	_dynamic_root.add_child(quad)

func _build_owner_blob_caps(owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _state.is_inside(t):
			tile_set[_tile_key(t)] = true

	var blob_mesh: SphereMesh = SphereMesh.new()
	blob_mesh.radius = 0.18
	blob_mesh.height = 0.24
	blob_mesh.radial_segments = 10
	blob_mesh.rings = 5
	var transforms: Array[Transform3D] = []
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var neighbor_count: int = _owned_neighbor_count(tile, tile_set)
		if neighbor_count <= 0:
			continue
		var edge_tile: bool = neighbor_count < 4
		var noise_gate: float = _noise01(tile.x * 17 + owner_id * 19, tile.y * 31 + owner_id * 7)
		if edge_tile:
			if noise_gate < 0.60:
				continue
		elif noise_gate < 0.82:
			continue
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var noise_scale: float = 0.66 + _noise01(tile.x + owner_id * 7, tile.y + 13) * 0.24
		var blob_basis: Basis = Basis().scaled(Vector3(1.0, 0.48, 1.0) * noise_scale)
		transforms.append(Transform3D(blob_basis, center + Vector3(0.0, top + 0.040, 0.0)))
	if transforms.is_empty():
		return
	var tint: Color = _owner_tint(owner_id)
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
	_dynamic_root.add_child(_make_multimesh_instance(blob_mesh, transforms, [], mat, true))

func _build_owner_micro_bubbles(owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _state.is_inside(t):
			tile_set[_tile_key(t)] = true

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
		if not _state.is_inside(tile):
			continue
		var neighbor_count: int = _owned_neighbor_count(tile, tile_set)
		if neighbor_count <= 0:
			continue
		var edge_tile: bool = neighbor_count < 4
		var presence_gate: float = _noise01(tile.x * 11 + owner_id * 43, tile.y * 13 + owner_id * 57)
		if edge_tile:
			if presence_gate < 0.78:
				continue
		elif presence_gate < 0.94:
			continue
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var dx: float = (_noise01(tile.x * 7 + owner_id, tile.y * 13 + 3) - 0.5) * 0.30
		var dz: float = (_noise01(tile.x * 11 + owner_id * 5, tile.y * 5 + 9) - 0.5) * 0.30
		var scale_v: float = 0.66 + _noise01(tile.x * 17 + 2, tile.y * 19 + owner_id) * 0.58
		var bb: Basis = Basis().scaled(Vector3.ONE * scale_v)
		bubble_transforms.append(Transform3D(bb, center + Vector3(dx, top + 0.048, dz)))
	if bubble_transforms.is_empty():
		return
	var tint: Color = _owner_tint(owner_id)
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
	_dynamic_root.add_child(_make_multimesh_instance(bubble_mesh, bubble_transforms, [], bubble_mat, false))

func _build_owner_edge_beads(owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _state.is_inside(t):
			tile_set[_tile_key(t)] = true

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
		if not _state.is_inside(tile):
			continue
		var neighbors: int = _owned_neighbor_count(tile, tile_set)
		if neighbors >= 4:
			continue
		var gate: float = _noise01(tile.x * 47 + owner_id * 13, tile.y * 29 + owner_id * 31)
		if gate < 0.60:
			continue
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var bead_count: int = 1 + int(floor(_noise01(tile.x * 11 + owner_id * 7, tile.y * 17 + owner_id * 19) * 2.0))
		for n in range(bead_count):
			if transforms.size() >= max_beads:
				break
			var ang: float = _noise01(tile.x * 73 + n * 19 + owner_id, tile.y * 41 + n * 23 + owner_id * 3) * TAU
			var rad: float = 0.24 + _noise01(tile.x * 59 + n * 29, tile.y * 67 + n * 17) * 0.20
			var sx: float = 0.72 + _noise01(tile.x * 13 + n * 7, tile.y * 19 + n * 5) * 0.38
			var basis: Basis = Basis().scaled(Vector3.ONE * sx)
			transforms.append(
				Transform3D(
					basis,
					center + Vector3(cos(ang) * rad, top + 0.038, sin(ang) * rad)
				)
			)
	if transforms.is_empty():
		return
	var tint: Color = _owner_tint(owner_id)
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
	_dynamic_root.add_child(_make_multimesh_instance(bead_mesh, transforms, [], mat, false))

func _build_owner_mask_texture(tile_set: Dictionary) -> Texture2D:
	if _state == null:
		return null
	var mask_scale: int = OOZE_MASK_SCALE
	var img_w: int = maxi(8, _state.width * mask_scale)
	var img_h: int = maxi(8, _state.height * mask_scale)
	var image: Image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var radius: int = maxi(2, int(round(float(mask_scale) * 1.10)))
	var bridge_half: int = maxi(1, int(round(float(mask_scale) * 0.62)))
	for tile_key in tile_set.keys():
		var tile: Vector2i = tile_set[tile_key]
		var jx: int = int(round((_noise01(tile.x * 23 + 7, tile.y * 19 + 11) - 0.5) * float(mask_scale) * 0.08))
		var jy: int = int(round((_noise01(tile.x * 31 + 3, tile.y * 29 + 17) - 0.5) * float(mask_scale) * 0.08))
		var local_radius: int = radius + int(round((_noise01(tile.x * 41 + 5, tile.y * 37 + 13) - 0.5) * 0.9))
		local_radius = maxi(2, local_radius)
		var cx: int = tile.x * mask_scale + int(floor(float(mask_scale) * 0.5)) + jx
		var cy: int = tile.y * mask_scale + int(floor(float(mask_scale) * 0.5)) + jy
		_stamp_circle(image, cx, cy, local_radius, 0.98)
		_stamp_circle(image, cx + int(round(float(mask_scale) * 0.08)), cy - int(round(float(mask_scale) * 0.04)), maxi(1, local_radius - 1), 0.86)
		var right: Vector2i = tile + Vector2i.RIGHT
		var down: Vector2i = tile + Vector2i.DOWN
		if tile_set.has(_tile_key(right)):
			var cx2: int = right.x * mask_scale + int(floor(float(mask_scale) * 0.5))
			_stamp_rect(image, mini(cx, cx2), cy - bridge_half, maxi(cx, cx2), cy + bridge_half, 1.0)
		if tile_set.has(_tile_key(down)):
			var cy2: int = down.y * mask_scale + int(floor(float(mask_scale) * 0.5))
			_stamp_rect(image, cx - bridge_half, mini(cy, cy2), cx + bridge_half, maxi(cy, cy2), 1.0)

	_dilate_mask(image)
	for _i in range(OOZE_MASK_SMOOTH_PASSES):
		_smooth_mask(image)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture

func _dilate_mask(image: Image) -> void:
	var copy: Image = image.duplicate()
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var current: float = copy.get_pixel(x, y).a
			var n1: float = copy.get_pixel(x + 1, y).a
			var n2: float = copy.get_pixel(x - 1, y).a
			var n3: float = copy.get_pixel(x, y + 1).a
			var n4: float = copy.get_pixel(x, y - 1).a
			var max_n: float = maxf(maxf(n1, n2), maxf(n3, n4))
			var expanded: float = maxf(current, max_n * 0.94)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, expanded))

func _stamp_circle(image: Image, cx: int, cy: int, radius: int, strength: float) -> void:
	var x0: int = maxi(0, cx - radius)
	var x1: int = mini(image.get_width() - 1, cx + radius)
	var y0: int = maxi(0, cy - radius)
	var y1: int = mini(image.get_height() - 1, cy + radius)
	var r2: float = float(radius * radius)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx: float = float(x - cx)
			var dy: float = float(y - cy)
			var dist2: float = dx * dx + dy * dy
			if dist2 > r2:
				continue
			var falloff: float = 1.0 - (dist2 / maxf(1.0, r2))
			var alpha: float = clampf(strength * (0.60 + 0.40 * falloff), 0.0, 1.0)
			var current: Color = image.get_pixel(x, y)
			if alpha > current.a:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

func _stamp_rect(image: Image, x0: int, y0: int, x1: int, y1: int, strength: float) -> void:
	var clamped_x0: int = maxi(0, mini(x0, x1))
	var clamped_x1: int = mini(image.get_width() - 1, maxi(x0, x1))
	var clamped_y0: int = maxi(0, mini(y0, y1))
	var clamped_y1: int = mini(image.get_height() - 1, maxi(y0, y1))
	for y in range(clamped_y0, clamped_y1 + 1):
		for x in range(clamped_x0, clamped_x1 + 1):
			var current: Color = image.get_pixel(x, y)
			if strength > current.a:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, strength))

func _smooth_mask(image: Image) -> void:
	var copy: Image = image.duplicate()
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var a0: float = copy.get_pixel(x, y).a
			var a1: float = copy.get_pixel(x + 1, y).a
			var a2: float = copy.get_pixel(x - 1, y).a
			var a3: float = copy.get_pixel(x, y + 1).a
			var a4: float = copy.get_pixel(x, y - 1).a
			var smoothed: float = clampf(a0 * 0.36 + (a1 + a2 + a3 + a4) * 0.16, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, smoothed))

func _build_heart_markers(owner_id: int, blocks: Array) -> void:
	var heart_transforms: Array[Transform3D] = []
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 10
	mesh.rings = 5
	var heart_color: Color = _owner_tint(owner_id).lerp(Color(1.0, 0.96, 0.98, 1.0), 0.35)
	for block in blocks:
		if not bool(block.get("is_heart", false)):
			continue
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		var top: float = _tile_ground_top(tile)
		var tf: Transform3D = Transform3D(Basis(), _tile_world_position(tile) + Vector3(0.0, top + 0.18, 0.0))
		heart_transforms.append(tf)
	if heart_transforms.is_empty():
		return
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = heart_color
	mat.roughness = 0.12
	mat.metallic = 0.02
	mat.emission_enabled = true
	mat.emission = _owner_tint(owner_id).lerp(Color(1.0, 0.92, 0.98, 1.0), 0.45)
	mat.emission_energy_multiplier = 1.00
	_dynamic_root.add_child(_make_multimesh_instance(mesh, heart_transforms, [], mat, false))

func _build_specialization_markers(owner_id: int, blocks: Array) -> void:
	var role_tiles: Dictionary = {
		"melee": [],
		"ranged": [],
		"defense": [],
		"gather": [],
	}
	for block in blocks:
		var role: String = String(block.get("tile_type", "basic"))
		if role_tiles.has(role):
			role_tiles[role].append(block)

	for role in role_tiles.keys():
		var entries: Array = role_tiles[role]
		if entries.is_empty():
			continue
		_build_role_marker_layer(owner_id, role, entries)

func _build_role_marker_layer(owner_id: int, role: String, entries: Array) -> void:
	var base_mesh: Mesh = _role_base_mesh(role)
	var base_transforms: Array[Transform3D] = []

	var crest_mesh: Mesh = _role_crest_mesh(role)
	var crest_transforms: Array[Transform3D] = []
	var owner_tint: Color = _owner_tint(owner_id)
	var role_tint: Color = _role_tint(role)
	var crest_tint: Color = role_tint.lerp(owner_tint, 0.22).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.06)
	var base_y_offset: float = 0.12
	var crest_y_offset: float = 0.43
	if role == "defense":
		base_y_offset = 0.10
		crest_y_offset = 0.30
	elif role == "melee":
		base_y_offset = 0.12
		crest_y_offset = 0.52
	elif role == "gather":
		base_y_offset = 0.13
		crest_y_offset = 0.46
	elif role == "ranged":
		base_y_offset = 0.13
		crest_y_offset = 0.50

	for block in entries:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		var top: float = _tile_ground_top(tile)
		var center: Vector3 = _tile_world_position(tile)
		var rot: float = _noise01(tile.x * 53 + owner_id * 7, tile.y * 47 + owner_id * 13) * TAU
		var s: float = 0.92 + _noise01(tile.x * 17 + owner_id * 3, tile.y * 29 + owner_id * 5) * 0.30
		var base_basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3.ONE * s)
		var crest_basis: Basis = Basis(Vector3.UP, rot + 0.24).scaled(Vector3.ONE * (1.02 + (s - 0.92) * 0.6))
		base_transforms.append(Transform3D(base_basis, center + Vector3(0.0, top + base_y_offset, 0.0)))
		crest_transforms.append(Transform3D(crest_basis, center + Vector3(0.0, top + crest_y_offset, 0.0)))

	var base_material: StandardMaterial3D = _role_base_material(role, role_tint, owner_tint)
	_dynamic_root.add_child(_make_multimesh_instance(base_mesh, base_transforms, [], base_material, true))

	var crest_material: ShaderMaterial = ShaderMaterial.new()
	var crest_shader: Shader = Shader.new()
	crest_shader.code = ROLE_CREST_SHADER_CODE
	crest_material.shader = crest_shader
	crest_material.set_shader_parameter("crest_color", crest_tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.24))
	crest_material.set_shader_parameter("crest_emission", crest_tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.12))
	crest_material.set_shader_parameter("crest_roughness", 0.36 if role == "ranged" else (0.50 if role == "gather" else (0.64 if role == "melee" else 0.72)))
	crest_material.set_shader_parameter("pulse_speed", 1.9 if role == "ranged" else (1.6 if role == "gather" else 1.4))
	crest_material.set_shader_parameter("pulse_amp", 0.026 if role == "gather" else (0.020 if role == "ranged" else 0.014))
	_dynamic_root.add_child(_make_multimesh_instance(crest_mesh, crest_transforms, [], crest_material, true))

func _build_world_points() -> void:
	if _state == null:
		return

	_add_door_marker(_state.entrance_tile, true)
	if _state.door_hp > 0:
		_add_door_marker(_state.door_tile, false)

	for node in _state.resource_nodes:
		var tile: Vector2i = node.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		_add_resource_marker(tile, String(node.get("kind", "gem")), bool(node.get("consumed", false)))

	# No per-turn ambient point lights: too expensive at high sim speed.

func _add_ambient_lights() -> void:
	return

func _rebuild_markers() -> void:
	_clear_children(_marker_root)
	if _state == null:
		return
	_add_queued_preview_markers()
	if not _hover_preview_action.is_empty():
		var preview_tile: Vector2i = _preview_target_tile(_hover_preview_action)
		if _state.is_inside(preview_tile):
			var preview_role: String = String(_hover_preview_action.get("tile_type", _hover_preview_action.get("to_type", "basic")))
			var preview_ok: bool = _hover_invalid_reason.is_empty()
			_add_preview_marker(preview_tile, preview_role, preview_ok)
			if not preview_ok:
				_add_invalid_preview_cross(preview_tile)
	if _hovered_tile != Vector2i(-1, -1) and _state.is_inside(_hovered_tile):
		_add_tile_marker(_hovered_tile, Color(0.88, 0.96, 1.0, 0.42), 0.026)
	if _selected_tile != Vector2i(-1, -1) and _state.is_inside(_selected_tile):
		_add_tile_marker(_selected_tile, Color(1.0, 0.93, 0.54, 0.52), 0.034)
	for key in _queued_tiles.keys():
		var tile: Vector2i = _queued_tiles[key]
		if _state.is_inside(tile):
			_add_tile_marker(tile, Color(0.54, 0.98, 0.76, 0.30), 0.019)

func _preview_target_tile(action: Dictionary) -> Vector2i:
	if _state == null or action.is_empty():
		return Vector2i(-1, -1)
	var action_type: String = String(action.get("type", ""))
	if action_type == "place_tile":
		return action.get("target", Vector2i(-1, -1))
	if action_type == "convert_tile" or action_type == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if _state.blocks.has(block_id):
			return _state.blocks[block_id].get("pos", Vector2i(-1, -1))
	return Vector2i(-1, -1)

func _add_queued_preview_markers() -> void:
	if _state == null or _queued_actions.is_empty():
		return
	var seen: Dictionary = {}
	for action in _queued_actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = _queued_action_tile_role(action)
		var tile: Vector2i = info.get("tile", Vector2i(-1, -1))
		var role: String = String(info.get("role", "basic"))
		if not _state.is_inside(tile):
			continue
		var key: String = _tile_key(tile)
		if seen.has(key):
			continue
		seen[key] = true
		_add_preview_marker(tile, role, true, true)

func _queued_action_tile_role(action: Dictionary) -> Dictionary:
	var result: Dictionary = {"tile": Vector2i(-1, -1), "role": "basic"}
	if _state == null:
		return result
	var action_type: String = String(action.get("type", ""))
	if action_type == "place_tile":
		result["tile"] = action.get("target", Vector2i(-1, -1))
		result["role"] = String(action.get("tile_type", "basic"))
		return result
	if action_type == "convert_tile" or action_type == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if _state.blocks.has(block_id):
			result["tile"] = _state.blocks[block_id].get("pos", Vector2i(-1, -1))
			result["role"] = String(action.get("to_type", _state.blocks[block_id].get("tile_type", "basic")))
	return result

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

func _add_preview_marker(tile: Vector2i, role: String, is_valid: bool, is_queued: bool = false) -> void:
	var top: float = _tile_ground_top(tile)
	var center: Vector3 = _tile_world_position(tile)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = tile_world_size * 0.36
	ring_mesh.outer_radius = tile_world_size * 0.42
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 24
	ring.mesh = ring_mesh
	ring.position = center + Vector3(0.0, top + (0.044 if is_queued else 0.048), 0.0)
	var preview_col: Color = Color(0.52, 1.0, 0.76, 0.90) if is_valid else Color(1.0, 0.32, 0.36, 0.90)
	if is_queued:
		preview_col = preview_col.lerp(Color(0.48, 0.86, 1.0, 0.88), 0.45)
	ring.material_override = _preview_material(preview_col, is_queued)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker_root.add_child(ring)

	var ghost: MeshInstance3D = MeshInstance3D.new()
	ghost.mesh = _preview_role_mesh(role)
	ghost.material_override = _preview_material(preview_col, is_queued)
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.position = center + Vector3(0.0, top + (0.13 if is_queued else 0.16), 0.0)
	ghost.scale = Vector3(0.50, 0.50, 0.50) if is_queued else Vector3(0.58, 0.58, 0.58)
	_marker_root.add_child(ghost)

func _add_invalid_preview_cross(tile: Vector2i) -> void:
	var top: float = _tile_ground_top(tile)
	var center: Vector3 = _tile_world_position(tile)
	for i in range(2):
		var slash: MeshInstance3D = MeshInstance3D.new()
		var slash_mesh: BoxMesh = BoxMesh.new()
		slash_mesh.size = Vector3(tile_world_size * 0.58, 0.03, 0.08)
		slash.mesh = slash_mesh
		slash.position = center + Vector3(0.0, top + 0.08, 0.0)
		slash.rotation_degrees = Vector3(0.0, 45.0 if i == 0 else -45.0, 0.0)
		slash.material_override = _preview_material(Color(1.0, 0.26, 0.22, 0.92), false)
		slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker_root.add_child(slash)

func _preview_role_mesh(role: String) -> PrimitiveMesh:
	match role:
		"melee":
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.03
			cone.bottom_radius = 0.22
			cone.height = 0.44
			cone.radial_segments = 12
			return cone
		"ranged":
			var cap: CapsuleMesh = CapsuleMesh.new()
			cap.radius = 0.16
			cap.height = 0.42
			cap.radial_segments = 10
			cap.rings = 6
			return cap
		"defense":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.21
			cyl.bottom_radius = 0.21
			cyl.height = 0.30
			cyl.radial_segments = 12
			return cyl
		"gather":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.36, 0.26, 0.36)
			return box
		_:
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.30
			sphere.radial_segments = 10
			sphere.rings = 6
			return sphere

func _add_tile_marker(tile: Vector2i, color: Color, y_offset: float) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = tile_world_size * 0.45
	mesh.bottom_radius = tile_world_size * 0.46
	mesh.height = 0.016
	mesh.radial_segments = 16
	marker.mesh = mesh
	var top: float = _tile_ground_top(tile)
	marker.position = _tile_world_position(tile) + Vector3(0.0, top + y_offset, 0.0)
	marker.material_override = _marker_material(color)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker_root.add_child(marker)

func _add_door_marker(tile: Vector2i, entrance: bool) -> void:
	if _state == null or not _state.is_inside(tile):
		return
	var top: float = _tile_ground_top(tile)
	var center: Vector3 = _tile_world_position(tile)
	var frame: MeshInstance3D = MeshInstance3D.new()
	var frame_mesh: BoxMesh = BoxMesh.new()
	frame_mesh.size = Vector3(tile_world_size * 0.60, 0.30, tile_world_size * 0.60)
	frame.mesh = frame_mesh
	frame.position = center + Vector3(0.0, top + 0.16, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.66, 0.78, 1.0) if entrance else Color(0.72, 0.58, 0.34, 1.0)
	mat.roughness = 0.46
	mat.metallic = 0.12
	mat.emission_enabled = true
	mat.emission = Color(0.40, 0.74, 0.90, 1.0) if entrance else Color(0.84, 0.62, 0.34, 1.0)
	mat.emission_energy_multiplier = 0.36
	frame.material_override = mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_dynamic_root.add_child(frame)

	# Door glow comes from emissive material only (no dynamic point light).

func _add_resource_marker(tile: Vector2i, kind: String, consumed: bool) -> void:
	var top: float = _tile_ground_top(tile)
	var center: Vector3 = _tile_world_position(tile)
	var crystal: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.24
	mesh.radial_segments = 10
	mesh.rings = 5
	crystal.mesh = mesh
	crystal.position = center + Vector3(0.0, top + 0.14, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if consumed:
		mat.albedo_color = Color(0.34, 0.34, 0.34, 1.0)
		mat.roughness = 0.80
	else:
		if kind == "rat":
			mat.albedo_color = Color(0.84, 0.78, 0.64, 1.0)
			mat.emission = Color(0.74, 0.68, 0.48, 1.0)
		else:
			mat.albedo_color = Color(0.48, 0.96, 0.86, 1.0)
			mat.emission = Color(0.34, 1.0, 0.86, 1.0)
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 0.42
		mat.roughness = 0.32
	crystal.material_override = mat
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_dynamic_root.add_child(crystal)

func _add_floor_scars() -> void:
	if _state == null:
		return
	var scar_mesh: BoxMesh = BoxMesh.new()
	scar_mesh.size = Vector3(0.55, 0.008, 0.07)
	var scar_transforms: Array[Transform3D] = []
	var used_tiles: Dictionary = {}
	var scar_count: int = maxi(10, int((_state.width + _state.height) * 0.55))
	var attempts: int = scar_count * 5
	for idx in range(attempts):
		if scar_transforms.size() >= scar_count:
			break
		var sx: int = int(floor(_noise01(idx * 47 + 5, idx * 23 + 11) * float(_state.width)))
		var sy: int = int(floor(_noise01(idx * 29 + 3, idx * 71 + 13) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(sx, 0, _state.width - 1), clampi(sy, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		if _is_near_used_tile(tile, used_tiles, 1):
			continue
		used_tiles[_tile_key(tile)] = true
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var rot: float = _noise01(idx * 97 + 17, idx * 43 + 19) * TAU
		var stretch: float = 0.72 + _noise01(idx * 61 + 7, idx * 37 + 2) * 0.56
		var scar_basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3(stretch, 1.0, 1.0))
		scar_transforms.append(Transform3D(scar_basis, center + Vector3(0.0, top + 0.006, 0.0)))
	if scar_transforms.is_empty():
		return
	var scar_mat: StandardMaterial3D = StandardMaterial3D.new()
	scar_mat.albedo_color = Color(0.10, 0.09, 0.08, 0.14)
	scar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scar_mat.roughness = 0.92
	scar_mat.metallic = 0.0
	_terrain_root.add_child(_make_multimesh_instance(scar_mesh, scar_transforms, [], scar_mat, false))

func _add_cobble_relief() -> void:
	if _state == null:
		return
	var cobble_mesh: SphereMesh = SphereMesh.new()
	cobble_mesh.radius = 0.10
	cobble_mesh.height = 0.12
	cobble_mesh.radial_segments = 8
	cobble_mesh.rings = 5
	var transforms: Array[Transform3D] = []
	var used_tiles: Dictionary = {}
	var cobble_count: int = maxi(10, int((_state.width + _state.height) * 0.40))
	var attempts: int = cobble_count * 6
	for idx in range(attempts):
		if transforms.size() >= cobble_count:
			break
		var tx: int = int(floor(_noise01(idx * 31 + 3, idx * 17 + 19) * float(_state.width)))
		var ty: int = int(floor(_noise01(idx * 47 + 7, idx * 13 + 11) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(tx, 0, _state.width - 1), clampi(ty, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		if _is_near_used_tile(tile, used_tiles, 0):
			continue
		used_tiles[_tile_key(tile)] = true
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var rot: float = _noise01(idx * 83 + 2, idx * 59 + 5) * TAU
		var sx: float = 0.80 + _noise01(idx * 41 + 7, idx * 67 + 13) * 0.40
		var sz: float = 0.80 + _noise01(idx * 19 + 11, idx * 73 + 29) * 0.40
		var sy: float = 0.70 + _noise01(idx * 23 + 17, idx * 37 + 23) * 0.30
		var jitter_x: float = (_noise01(idx * 13 + 5, idx * 29 + 31) - 0.5) * 0.30
		var jitter_z: float = (_noise01(idx * 17 + 3, idx * 31 + 37) - 0.5) * 0.30
		var basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3(sx, sy, sz))
		transforms.append(Transform3D(basis, center + Vector3(jitter_x, top + 0.017, jitter_z)))
	if transforms.is_empty():
		return
	var mat: ShaderMaterial = _stone_shader_material(
		CAVE_FLOOR_BASE.lerp(Color(0.22, 0.20, 0.18, 1.0), 0.30),
		CAVE_FLOOR_ALT,
		Color(0.08, 0.10, 0.10, 1.0),
		22.0
	)
	_terrain_root.add_child(_make_multimesh_instance(cobble_mesh, transforms, [], mat, false))

func _add_wet_patches() -> void:
	if _state == null:
		return
	var patch_mesh: QuadMesh = QuadMesh.new()
	patch_mesh.size = Vector2(0.95, 0.72)
	var patch_transforms: Array[Transform3D] = []
	var patch_count: int = maxi(8, int((_state.width + _state.height) * 0.30))
	var used_tiles: Dictionary = {}
	var attempts: int = patch_count * 6
	for idx in range(attempts):
		if patch_transforms.size() >= patch_count:
			break
		var tx: int = int(floor(_noise01(idx * 43 + 7, idx * 19 + 13) * float(_state.width)))
		var ty: int = int(floor(_noise01(idx * 29 + 11, idx * 31 + 23) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(tx, 0, _state.width - 1), clampi(ty, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		if _is_near_used_tile(tile, used_tiles, 1):
			continue
		used_tiles[_tile_key(tile)] = true
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var rot: float = _noise01(idx * 71 + 3, idx * 37 + 17) * TAU
		var sx: float = 0.72 + _noise01(idx * 11 + 5, idx * 97 + 2) * 0.62
		var sy: float = 0.66 + _noise01(idx * 61 + 7, idx * 53 + 19) * 0.54
		var basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3(sx, 1.0, sy))
		patch_transforms.append(Transform3D(basis, center + Vector3(0.0, top + 0.010, 0.0)))
	if patch_transforms.is_empty():
		return
	var patch_mat: StandardMaterial3D = StandardMaterial3D.new()
	patch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	patch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	patch_mat.albedo_color = Color(0.15, 0.17, 0.18, 0.10)
	patch_mat.roughness = 0.18
	patch_mat.metallic = 0.0
	patch_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	patch_mat.metallic_specular = 0.58
	_terrain_root.add_child(_make_multimesh_instance(patch_mesh, patch_transforms, [], patch_mat, false))

func _add_cave_doors() -> void:
	if _state == null:
		return
	var door_positions: Array[Vector3] = [
		Vector3(_board_min.x + tile_world_size * 1.4, 0.0, _board_min.z + tile_world_size * 1.2),
		Vector3(_board_max.x - tile_world_size * 1.4, 0.0, _board_max.z - tile_world_size * 1.2),
	]
	for idx in range(door_positions.size()):
		var pos: Vector3 = door_positions[idx]
		var arch: MeshInstance3D = MeshInstance3D.new()
		var arch_mesh: BoxMesh = BoxMesh.new()
		arch_mesh.size = Vector3(0.95, 1.15, 0.22)
		arch.mesh = arch_mesh
		arch.position = pos + Vector3(0.0, 0.48, 0.0)
		arch.rotation_degrees = Vector3(0.0, 36.0 if idx == 0 else -144.0, 0.0)
		var arch_mat: StandardMaterial3D = StandardMaterial3D.new()
		arch_mat.albedo_color = Color(0.23, 0.18, 0.12, 1.0)
		arch_mat.roughness = 0.86
		arch_mat.metallic = 0.02
		arch.material_override = arch_mat
		arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_terrain_root.add_child(arch)

		var door_core: MeshInstance3D = MeshInstance3D.new()
		var door_mesh: BoxMesh = BoxMesh.new()
		door_mesh.size = Vector3(0.52, 0.72, 0.08)
		door_core.mesh = door_mesh
		door_core.position = pos + Vector3(0.0, 0.40, 0.0)
		door_core.rotation_degrees = arch.rotation_degrees
		var door_mat: StandardMaterial3D = StandardMaterial3D.new()
		door_mat.albedo_color = Color(0.20, 0.15, 0.11, 1.0)
		door_mat.roughness = 0.84
		door_mat.metallic = 0.03
		door_core.material_override = door_mat
		door_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_terrain_root.add_child(door_core)

func _add_ground_boulders() -> void:
	if _state == null:
		return
	var rock_mesh_a: SphereMesh = SphereMesh.new()
	rock_mesh_a.radius = 0.20
	rock_mesh_a.height = 0.28
	rock_mesh_a.radial_segments = 10
	rock_mesh_a.rings = 6
	var rock_mesh_b: SphereMesh = SphereMesh.new()
	rock_mesh_b.radius = 0.14
	rock_mesh_b.height = 0.22
	rock_mesh_b.radial_segments = 9
	rock_mesh_b.rings = 5
	var rock_transforms_a: Array[Transform3D] = []
	var rock_transforms_b: Array[Transform3D] = []
	var used_tiles: Dictionary = {}
	var rock_count: int = maxi(14, int((_state.width + _state.height) * 0.95))
	var attempts: int = rock_count * 6
	for idx in range(attempts):
		if rock_transforms_a.size() + rock_transforms_b.size() >= rock_count:
			break
		var sx: int = int(floor(_noise01(idx * 23 + 7, idx * 13 + 3) * float(_state.width)))
		var sy: int = int(floor(_noise01(idx * 37 + 11, idx * 17 + 9) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(sx, 0, _state.width - 1), clampi(sy, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		if _is_near_used_tile(tile, used_tiles, 1):
			continue
		used_tiles[_tile_key(tile)] = true
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var rx: float = (_noise01(idx * 41 + 13, idx * 31 + 17) - 0.5) * 0.58
		var rz: float = (_noise01(idx * 19 + 2, idx * 59 + 5) - 0.5) * 0.58
		var scale_v: float = 0.36 + _noise01(idx * 61 + 21, idx * 47 + 27) * 0.74
		var rot: float = _noise01(idx * 79 + 7, idx * 97 + 11) * TAU
		var rock_basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3(1.0, 0.72, 1.0) * scale_v)
		var tf: Transform3D = Transform3D(rock_basis, center + Vector3(rx, top + 0.02, rz))
		if _noise01(idx * 13 + 2, idx * 29 + 5) > 0.55:
			rock_transforms_a.append(tf)
		else:
			rock_transforms_b.append(tf)
	if rock_transforms_a.is_empty() and rock_transforms_b.is_empty():
		return
	var rock_mat: ShaderMaterial = _stone_shader_material(
		CAVE_FLOOR_ALT.lerp(Color(0.16, 0.13, 0.11, 1.0), 0.20),
		CAVE_WALL_ALT,
		Color(0.10, 0.10, 0.09, 1.0),
		15.0
	)
	if not rock_transforms_a.is_empty():
		_terrain_root.add_child(_make_multimesh_instance(rock_mesh_a, rock_transforms_a, [], rock_mat, false))
	if not rock_transforms_b.is_empty():
		_terrain_root.add_child(_make_multimesh_instance(rock_mesh_b, rock_transforms_b, [], rock_mat, false))

func _add_torch_sconces() -> void:
	if _state == null:
		return
	var positions: Array[Vector3] = [
		Vector3(_board_min.x + 1.5, 0.0, _board_min.z + 1.3),
		Vector3(_board_max.x - 1.5, 0.0, _board_min.z + 1.5),
		Vector3(_board_min.x + 1.3, 0.0, _board_max.z - 1.5),
		Vector3(_board_max.x - 1.4, 0.0, _board_max.z - 1.4),
	]
	for pos in positions:
		var stand: MeshInstance3D = MeshInstance3D.new()
		var stand_mesh: CylinderMesh = CylinderMesh.new()
		stand_mesh.top_radius = 0.08
		stand_mesh.bottom_radius = 0.12
		stand_mesh.height = 0.48
		stand_mesh.radial_segments = 12
		stand.mesh = stand_mesh
		stand.position = pos + Vector3(0.0, 0.16, 0.0)
		var stand_mat: StandardMaterial3D = StandardMaterial3D.new()
		stand_mat.albedo_color = Color(0.20, 0.15, 0.10, 1.0)
		stand_mat.roughness = 0.82
		stand_mat.metallic = 0.08
		stand.material_override = stand_mat
		stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(stand)

		var flame: MeshInstance3D = MeshInstance3D.new()
		var flame_mesh: SphereMesh = SphereMesh.new()
		flame_mesh.radius = 0.09
		flame_mesh.height = 0.16
		flame_mesh.radial_segments = 10
		flame_mesh.rings = 5
		flame.mesh = flame_mesh
		flame.position = pos + Vector3(0.0, 0.42, 0.0)
		var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, 0.78, 0.44, 1.0)
		flame_mat.roughness = 0.18
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.66, 0.24, 1.0)
		flame_mat.emission_energy_multiplier = 0.95
		flame.material_override = flame_mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(flame)

		var torch_light: OmniLight3D = OmniLight3D.new()
		torch_light.position = pos + Vector3(0.0, 0.46, 0.0)
		torch_light.light_color = Color(1.0, 0.68, 0.30, 1.0)
		torch_light.light_energy = 0.72
		torch_light.omni_range = 4.8
		torch_light.shadow_enabled = false
		_terrain_root.add_child(torch_light)

func _add_cave_perimeter() -> void:
	if _state == null:
		return
	_add_cave_boundary_walls()
	# Buttresses read as prototype pillars; keep perimeter cleaner and cave-like.

func _add_cave_buttresses() -> void:
	var buttress_mesh: BoxMesh = BoxMesh.new()
	buttress_mesh.size = Vector3(0.95, 1.35, 0.80)
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var corners: Array[Vector3] = [
		_camera_base_target + Vector3(-board_w * 0.52, 0.52, -board_h * 0.52),
		_camera_base_target + Vector3(board_w * 0.52, 0.52, -board_h * 0.52),
		_camera_base_target + Vector3(-board_w * 0.52, 0.52, board_h * 0.52),
		_camera_base_target + Vector3(board_w * 0.52, 0.52, board_h * 0.52),
	]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = CAVE_WALL_BASE.lerp(Color(0.20, 0.18, 0.18, 1.0), 0.40)
	mat.roughness = 0.86
	mat.metallic = 0.0
	for c in corners:
		var buttress: MeshInstance3D = MeshInstance3D.new()
		buttress.mesh = buttress_mesh
		buttress.position = c
		buttress.material_override = mat
		buttress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(buttress)

func _add_cave_tunnel_mouths() -> void:
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var mouths: Array[Dictionary] = [
		{"pos": _camera_base_target + Vector3(-board_w * 0.32, 0.88, -board_h * 0.54), "yaw": 14.0},
		{"pos": _camera_base_target + Vector3(board_w * 0.30, 0.86, -board_h * 0.54), "yaw": -16.0},
	]
	for mouth in mouths:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var ring_mesh: CylinderMesh = CylinderMesh.new()
		ring_mesh.top_radius = 1.18
		ring_mesh.bottom_radius = 1.42
		ring_mesh.height = 0.76
		ring_mesh.radial_segments = 20
		ring.mesh = ring_mesh
		ring.position = mouth["pos"]
		ring.rotation_degrees = Vector3(90.0, float(mouth["yaw"]), 0.0)
		var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.22, 0.19, 0.17, 1.0)
		ring_mat.roughness = 0.74
		ring_mat.metallic = 0.0
		ring.material_override = ring_mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(ring)

func _add_cave_boundary_walls() -> void:
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var ring_r: float = maxf(board_w, board_h) * 0.80
	var wall_height: float = maxf(board_w, board_h) * 0.52
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = ring_r
	ring_mesh.bottom_radius = ring_r * 1.04
	ring_mesh.height = wall_height
	ring_mesh.radial_segments = 56
	ring_mesh.rings = 6
	ring.mesh = ring_mesh
	ring.position = _camera_base_target + Vector3(0.0, wall_height * 0.50 - 0.22, 0.0)
	var mat: ShaderMaterial = _stone_shader_material(
		CAVE_WALL_BASE.lerp(Color(0.19, 0.17, 0.15, 1.0), 0.34),
		CAVE_WALL_ALT.lerp(Color(0.10, 0.09, 0.085, 1.0), 0.24),
		Color(0.10, 0.10, 0.11, 1.0),
		10.0,
		0.035,
		0.66
	)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(ring)

	var floor_edge_cover: MeshInstance3D = MeshInstance3D.new()
	var cover_mesh: BoxMesh = BoxMesh.new()
	cover_mesh.size = Vector3(board_w + 0.6, 0.12, board_h + 0.6)
	floor_edge_cover.mesh = cover_mesh
	floor_edge_cover.position = _camera_base_target + Vector3(0.0, -0.06, 0.0)
	var cover_mat: StandardMaterial3D = StandardMaterial3D.new()
	cover_mat.albedo_color = Color(0.09, 0.08, 0.08, 1.0)
	cover_mat.roughness = 0.94
	cover_mat.metallic = 0.0
	floor_edge_cover.material_override = cover_mat
	floor_edge_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(floor_edge_cover)

func _add_crystal_beds() -> void:
	if _state == null:
		return
	var cluster_count: int = 7
	for idx in range(cluster_count):
		var seed_a: int = idx * 59 + _state.level_index * 13
		var seed_b: int = idx * 41 + _state.level_index * 23
		var edge_pick: int = int(floor(_noise01(seed_a + 7, seed_b + 11) * 4.0))
		var t: float = _noise01(seed_a + 19, seed_b + 31)
		var px: float = _camera_base_target.x
		var pz: float = _camera_base_target.z
		if edge_pick == 0:
			px = lerpf(_board_min.x + 1.1, _board_max.x - 1.1, t)
			pz = _board_min.z - 0.55
		elif edge_pick == 1:
			px = lerpf(_board_min.x + 1.1, _board_max.x - 1.1, t)
			pz = _board_max.z + 0.55
		elif edge_pick == 2:
			px = _board_min.x - 0.55
			pz = lerpf(_board_min.z + 1.1, _board_max.z - 1.1, t)
		else:
			px = _board_max.x + 0.55
			pz = lerpf(_board_min.z + 1.1, _board_max.z - 1.1, t)

		var cluster_root: Vector3 = Vector3(px, 0.02, pz)
		var crystal_count: int = 3 + int(floor(_noise01(seed_a + 43, seed_b + 53) * 4.0))
		for n in range(crystal_count):
			var crystal: MeshInstance3D = MeshInstance3D.new()
			var c_mesh: CylinderMesh = CylinderMesh.new()
			c_mesh.top_radius = 0.018
			c_mesh.bottom_radius = 0.07 + _noise01(seed_a + n * 17, seed_b + n * 13) * 0.05
			c_mesh.height = 0.22 + _noise01(seed_a + n * 19, seed_b + n * 23) * 0.34
			c_mesh.radial_segments = 7
			crystal.mesh = c_mesh
			var angle: float = _noise01(seed_a + n * 29, seed_b + n * 31) * TAU
			var radius: float = 0.05 + _noise01(seed_a + n * 37, seed_b + n * 41) * 0.24
			var rot_y: float = _noise01(seed_a + n * 43, seed_b + n * 47) * TAU
			crystal.position = cluster_root + Vector3(cos(angle) * radius, c_mesh.height * 0.5, sin(angle) * radius)
			crystal.rotation_degrees = Vector3(0.0, rad_to_deg(rot_y), 0.0)
			var hue: float = 0.53 + _noise01(seed_a + n * 7, seed_b + n * 5) * 0.20
			var glow_color: Color = Color.from_hsv(hue, 0.62, 0.95, 1.0)
			var c_mat: StandardMaterial3D = StandardMaterial3D.new()
			c_mat.albedo_color = glow_color * 0.64
			c_mat.roughness = 0.30
			c_mat.metallic = 0.0
			c_mat.emission_enabled = true
			c_mat.emission = glow_color
			c_mat.emission_energy_multiplier = 0.40
			crystal.material_override = c_mat
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_terrain_root.add_child(crystal)

func _add_cave_glow_clusters() -> void:
	if _state == null:
		return
	var cluster_count: int = 5
	for idx in range(cluster_count):
		var seed_a: int = idx * 83 + _state.level_index * 19
		var seed_b: int = idx * 61 + _state.level_index * 47
		var angle: float = _noise01(seed_a + 17, seed_b + 23) * TAU
		var radius: float = maxf(float(_state.width), float(_state.height)) * tile_world_size * (0.32 + _noise01(seed_a + 29, seed_b + 37) * 0.20)
		var x: float = _camera_base_target.x + cos(angle) * radius
		var z: float = _camera_base_target.z + sin(angle) * radius
		var y: float = -0.04
		var cluster_pos: Vector3 = Vector3(x, y, z)

		var hue: float = _noise01(seed_a + 31, seed_b + 37)
		var glow_color: Color = Color.from_hsv(0.55 + hue * 0.25, 0.58, 0.94, 1.0)
		var crystal_count: int = 4 + int(floor(_noise01(seed_a + 11, seed_b + 5) * 3.0))
		for c in range(crystal_count):
			var crystal: MeshInstance3D = MeshInstance3D.new()
			var crystal_mesh: CylinderMesh = CylinderMesh.new()
			crystal_mesh.top_radius = 0.02
			crystal_mesh.bottom_radius = 0.08 + _noise01(seed_a + c * 29, seed_b + c * 13) * 0.06
			crystal_mesh.height = 0.18 + _noise01(seed_a + c * 17, seed_b + c * 19) * 0.38
			crystal_mesh.radial_segments = 7
			crystal.mesh = crystal_mesh
			var c_angle: float = _noise01(seed_a + c * 37, seed_b + c * 41) * TAU
			var c_radius: float = 0.04 + _noise01(seed_a + c * 43, seed_b + c * 47) * 0.24
			crystal.position = cluster_pos + Vector3(cos(c_angle) * c_radius, crystal_mesh.height * 0.5, sin(c_angle) * c_radius)
			crystal.rotation_degrees = Vector3(0.0, rad_to_deg(_noise01(seed_a + c * 53, seed_b + c * 59) * TAU), 0.0)

			var crystal_mat: StandardMaterial3D = StandardMaterial3D.new()
			crystal_mat.albedo_color = glow_color * 0.72
			crystal_mat.roughness = 0.24
			crystal_mat.metallic = 0.0
			crystal_mat.emission_enabled = true
			crystal_mat.emission = glow_color
			crystal_mat.emission_energy_multiplier = 0.46
			crystal.material_override = crystal_mat
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_terrain_root.add_child(crystal)

func _add_cave_shell() -> void:
	if _state == null:
		return
	var span: float = maxf(float(_state.width), float(_state.height)) * tile_world_size
	var shell: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = span * 2.45
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 14
	shell.mesh = sphere
	shell.position = _camera_base_target + Vector3(0.0, span * 0.72, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.albedo_texture = _stone_texture()
	mat.albedo_color = Color(0.30, 0.26, 0.23, 1.0)
	mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	mat.roughness = 0.66
	mat.metallic = 0.0
	mat.emission_enabled = false
	shell.material_override = mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(shell)

func _add_far_cave_backdrop() -> void:
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var ring_radius: float = maxf(board_w, board_h) * 1.05
	var dome: MeshInstance3D = MeshInstance3D.new()
	var dome_mesh: SphereMesh = SphereMesh.new()
	dome_mesh.radius = ring_radius
	dome_mesh.height = ring_radius * 1.08
	dome_mesh.radial_segments = 36
	dome_mesh.rings = 16
	dome.mesh = dome_mesh
	dome.position = _camera_base_target + Vector3(0.0, ring_radius * 0.46, 0.0)
	var dome_mat: StandardMaterial3D = StandardMaterial3D.new()
	dome_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	dome_mat.albedo_texture = _stone_texture()
	dome_mat.albedo_color = Color(0.16, 0.14, 0.13, 1.0)
	dome_mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	dome_mat.roughness = 0.90
	dome_mat.metallic = 0.0
	dome.material_override = dome_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(dome)

func _add_atmospheric_haze(board_width: float, board_height: float) -> void:
	if _terrain_root == null:
		return
	_haze_layer = MeshInstance3D.new()
	_haze_layer.name = "AtmosphericHaze"
	var haze_mesh: QuadMesh = QuadMesh.new()
	haze_mesh.size = Vector2(board_width * 1.22, board_height * 1.22)
	_haze_layer.mesh = haze_mesh
	_haze_layer.position = _camera_base_target + Vector3(0.0, 0.46, 0.0)
	_haze_layer.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_haze_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var haze_mat: ShaderMaterial = ShaderMaterial.new()
	var haze_shader: Shader = Shader.new()
	haze_shader.code = HAZE_SHADER_CODE
	haze_mat.shader = haze_shader
	haze_mat.set_shader_parameter("haze_color", Color(0.36, 0.33, 0.29, 0.075))
	haze_mat.set_shader_parameter("noise_scale", 5.6)
	haze_mat.set_shader_parameter("drift_speed", 0.018)
	_haze_layer.material_override = haze_mat
	_terrain_root.add_child(_haze_layer)

func _make_multimesh_instance(
	mesh: Mesh,
	transforms: Array,
	colors: Array,
	material: Material,
	cast_shadow: bool
) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var has_colors: bool = colors.size() == transforms.size() and not colors.is_empty()
	mm.use_colors = has_colors
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		if has_colors:
			mm.set_instance_color(i, colors[i])

	var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst

func _owner_pool_material(owner_id: int, mask_tex: Texture2D) -> ShaderMaterial:
	var cache_key: String = "%d|%d|%d" % [owner_id, _state.width, _state.height]
	if _pool_material_cache.has(cache_key):
		var cached: ShaderMaterial = _pool_material_cache[cache_key]
		cached.set_shader_parameter("mask_tex", mask_tex)
		cached.set_shader_parameter("detail_tex", _slime_detail_texture())
		cached.set_shader_parameter(
			"texel_size",
			Vector2(
				1.0 / float(maxi(1, mask_tex.get_width())),
				1.0 / float(maxi(1, mask_tex.get_height()))
			)
		)
		cached.set_shader_parameter("pulse_speed", 0.40)
		cached.set_shader_parameter("bubble_strength", 0.0022)
		cached.set_shader_parameter("emission_strength", 0.0045)
		cached.set_shader_parameter("detail_scale", 6.8)
		cached.set_shader_parameter("body_thickness", 0.010)
		cached.set_shader_parameter("lip_thickness", 0.019)
		cached.set_shader_parameter("flow_scale", 1.65)
		cached.set_shader_parameter("flow_speed", 0.018)
		cached.set_shader_parameter("flow_normal_strength", 0.52)
		cached.set_shader_parameter("edge_darkening_strength", 0.18)
		cached.set_shader_parameter("contact_darkening_strength", 0.14)
		return cached
	var tint: Color = _owner_tint(owner_id)
	var mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = POOL_SHADER_CODE
	mat.shader = shader
	mat.set_shader_parameter("owner_color", tint)
	mat.set_shader_parameter("mask_tex", mask_tex)
	mat.set_shader_parameter("detail_tex", _slime_detail_texture())
	mat.set_shader_parameter(
		"texel_size",
		Vector2(
			1.0 / float(maxi(1, mask_tex.get_width())),
			1.0 / float(maxi(1, mask_tex.get_height()))
		)
	)
	mat.set_shader_parameter("pulse_speed", 0.40)
	mat.set_shader_parameter("bubble_strength", 0.0022)
	mat.set_shader_parameter("emission_strength", 0.0045)
	mat.set_shader_parameter("detail_scale", 6.8)
	mat.set_shader_parameter("body_thickness", 0.010)
	mat.set_shader_parameter("lip_thickness", 0.019)
	mat.set_shader_parameter("flow_scale", 1.65)
	mat.set_shader_parameter("flow_speed", 0.018)
	mat.set_shader_parameter("flow_normal_strength", 0.52)
	mat.set_shader_parameter("edge_darkening_strength", 0.18)
	mat.set_shader_parameter("contact_darkening_strength", 0.14)
	_pool_material_cache[cache_key] = mat
	return mat

func _role_crest_mesh(role: String) -> Mesh:
	match role:
		"melee":
			var spike: CylinderMesh = CylinderMesh.new()
			spike.top_radius = 0.03
			spike.bottom_radius = 0.28
			spike.height = 1.06
			spike.radial_segments = 12
			return spike
		"ranged":
			var orb: SphereMesh = SphereMesh.new()
			orb.radius = 0.40
			orb.height = 0.80
			orb.radial_segments = 12
			orb.rings = 7
			return orb
		"defense":
			var shield: CylinderMesh = CylinderMesh.new()
			shield.top_radius = 0.38
			shield.bottom_radius = 0.44
			shield.height = 0.22
			shield.radial_segments = 16
			return shield
		"gather":
			var prism: PrismMesh = PrismMesh.new()
			prism.left_to_right = 0.0
			prism.size = Vector3(0.50, 0.92, 0.50)
			return prism
		_:
			var fallback: SphereMesh = SphereMesh.new()
			fallback.radius = 0.15
			fallback.height = 0.30
			fallback.radial_segments = 10
			fallback.rings = 6
			return fallback

func _role_base_mesh(role: String) -> Mesh:
	match role:
		"melee":
			var base_m: CylinderMesh = CylinderMesh.new()
			base_m.top_radius = 0.34
			base_m.bottom_radius = 0.48
			base_m.height = 0.18
			base_m.radial_segments = 14
			return base_m
		"defense":
			var base_d: BoxMesh = BoxMesh.new()
			base_d.size = Vector3(0.86, 0.20, 0.86)
			return base_d
		"ranged":
			var base_r: SphereMesh = SphereMesh.new()
			base_r.radius = 0.30
			base_r.height = 0.28
			base_r.radial_segments = 10
			base_r.rings = 5
			return base_r
		"gather":
			var base_g: CylinderMesh = CylinderMesh.new()
			base_g.top_radius = 0.24
			base_g.bottom_radius = 0.42
			base_g.height = 0.24
			base_g.radial_segments = 12
			return base_g
		_:
			var fallback: CylinderMesh = CylinderMesh.new()
			fallback.top_radius = 0.34
			fallback.bottom_radius = 0.40
			fallback.height = 0.18
			return fallback

func _role_base_material(role: String, role_tint: Color, owner_tint: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	match role:
		"melee":
			mat.albedo_color = role_tint.lerp(owner_tint, 0.12).lerp(Color(0.08, 0.07, 0.06, 1.0), 0.52)
			mat.roughness = 0.80
			mat.metallic = 0.02
			mat.emission_enabled = false
		"defense":
			mat.albedo_color = role_tint.lerp(Color(0.12, 0.13, 0.14, 1.0), 0.62)
			mat.roughness = 0.88
			mat.metallic = 0.03
			mat.emission_enabled = false
		"ranged":
			mat.albedo_color = role_tint.lerp(owner_tint, 0.26).lerp(Color(0.10, 0.10, 0.12, 1.0), 0.44)
			mat.roughness = 0.40
			mat.metallic = 0.02
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.06
			mat.clearcoat_roughness = 0.62
			mat.emission_enabled = true
			mat.emission = role_tint * 0.18
			mat.emission_energy_multiplier = 0.05
		"gather":
			mat.albedo_color = role_tint.lerp(owner_tint, 0.28).lerp(Color(0.10, 0.12, 0.08, 1.0), 0.40)
			mat.roughness = 0.56
			mat.metallic = 0.01
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.04
			mat.clearcoat_roughness = 0.58
			mat.emission_enabled = true
			mat.emission = role_tint * 0.14
			mat.emission_energy_multiplier = 0.04
		_:
			mat.albedo_color = role_tint.lerp(Color(0.10, 0.10, 0.12, 1.0), 0.56)
			mat.roughness = 0.74
			mat.metallic = 0.01
			mat.emission_enabled = false
	return mat

func _marker_material(color: Color) -> StandardMaterial3D:
	var key: String = "%0.3f|%0.3f|%0.3f|%0.3f" % [color.r, color.g, color.b, color.a]
	if _marker_material_cache.has(key):
		return _marker_material_cache[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b, 1.0)
	mat.emission_energy_multiplier = 0.32
	_marker_material_cache[key] = mat
	return mat

func _extract_queued_tiles(queued_actions: Array) -> Dictionary:
	var tiles: Dictionary = {}
	if _state == null:
		return tiles
	for action in queued_actions:
		var kind: String = String(action.get("type", ""))
		if kind == "place_tile":
			var place_tile: Vector2i = action.get("target", Vector2i(-1, -1))
			if place_tile != Vector2i(-1, -1):
				tiles[_tile_key(place_tile)] = place_tile
		elif kind == "convert_tile" or kind == "upgrade_tile":
			var block_id: int = int(action.get("block_id", -1))
			if _state.blocks.has(block_id):
				var tile: Vector2i = _state.blocks[block_id].get("pos", Vector2i(-1, -1))
				if tile != Vector2i(-1, -1):
					tiles[_tile_key(tile)] = tile
	return tiles

func _owner_centroid(blocks: Array) -> Vector3:
	if blocks.is_empty():
		return _camera_base_target
	var acc: Vector3 = Vector3.ZERO
	var count: int = 0
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		acc += _tile_world_position(tile)
		count += 1
	if count <= 0:
		return _camera_base_target
	return acc / float(count)

func _tile_world_position(tile: Vector2i) -> Vector3:
	return Vector3(
		_board_min.x + (float(tile.x) + 0.5) * tile_world_size,
		0.0,
		_board_min.z + (float(tile.y) + 0.5) * tile_world_size
	)

func _tile_ground_top(tile: Vector2i) -> float:
	return float(_ground_tops.get(_tile_key(tile), 0.0))

func _owner_tint(owner_id: int) -> Color:
	if _state == null:
		return PLAYER_TINT
	if _palette_renderer != null:
		return _palette_renderer.owner_tint_for_ui(_state, owner_id)
	if owner_id == GameState.PLAYER_ID:
		return PLAYER_TINT
	return Color(0.86, 0.35, 0.45, 1.0)

func _stone_shader_material(
	base: Color,
	alt: Color,
	damp: Color,
	uv_scale: float,
	height_amp: float = 0.0,
	detail_mix: float = 0.72
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = STONE_SHADER_CODE
	mat.shader = shader
	mat.set_shader_parameter("stone_base", base)
	mat.set_shader_parameter("stone_alt", alt)
	mat.set_shader_parameter("damp_tint", damp)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("detail_albedo_tex", _stone_texture())
	mat.set_shader_parameter("detail_roughness_tex", _stone_roughness_texture())
	mat.set_shader_parameter("detail_normal_tex", _stone_normal_texture())
	mat.set_shader_parameter("detail_mix", detail_mix)
	mat.set_shader_parameter("normal_strength", 0.66)
	mat.set_shader_parameter("height_amp", height_amp)
	return mat

func _stone_texture() -> Texture2D:
	if _stone_texture_cache != null:
		return _stone_texture_cache
	var tex: Texture2D = _load_texture_or_null(STONE_ALBEDO_TEXTURE_PATH)
	if tex != null:
		_stone_texture_cache = tex
		return _stone_texture_cache
	var size: int = 192
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n0: float = _noise01(x * 13 + y * 17, x * 7 + y * 5)
			var n1: float = _noise01(x * 31 + y * 11, x * 19 + y * 23)
			var n2: float = _noise01(x * 53 + y * 47, x * 29 + y * 37)
			var mix_t: float = clampf(n0 * 0.66 + n1 * 0.34, 0.0, 1.0)
			var col: Color = CAVE_FLOOR_ALT.lerp(CAVE_FLOOR_BASE, mix_t)
			col = col.lerp(Color(0.38, 0.30, 0.24, 1.0), 0.22)
			if n1 > 0.72:
				col = col.lerp(Color(0.16, 0.20, 0.18, 1.0), 0.15)
			if n0 < 0.24 and n1 > 0.52:
				col = col.lerp(Color(0.12, 0.10, 0.09, 1.0), 0.28)
			if n2 > 0.88:
				col = col.lerp(Color(0.09, 0.08, 0.07, 1.0), 0.55)
			image.set_pixel(x, y, col)
	_stone_texture_cache = ImageTexture.create_from_image(image)
	return _stone_texture_cache

func _stone_roughness_texture() -> Texture2D:
	if _stone_roughness_texture_cache != null:
		return _stone_roughness_texture_cache
	var tex: Texture2D = _load_texture_or_null(STONE_ROUGHNESS_TEXTURE_PATH)
	if tex != null:
		_stone_roughness_texture_cache = tex
		return _stone_roughness_texture_cache
	var fallback: Image = Image.create(4, 4, false, Image.FORMAT_RF)
	fallback.fill(Color(0.72, 0.0, 0.0, 1.0))
	_stone_roughness_texture_cache = ImageTexture.create_from_image(fallback)
	return _stone_roughness_texture_cache

func _stone_normal_texture() -> Texture2D:
	if _stone_normal_texture_cache != null:
		return _stone_normal_texture_cache
	var tex: Texture2D = _load_texture_or_null(STONE_NORMAL_TEXTURE_PATH)
	if tex != null:
		_stone_normal_texture_cache = tex
		return _stone_normal_texture_cache
	var fallback: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	fallback.fill(Color(0.5, 0.5, 1.0, 1.0))
	_stone_normal_texture_cache = ImageTexture.create_from_image(fallback)
	return _stone_normal_texture_cache

func _slime_detail_texture() -> Texture2D:
	if _slime_detail_texture_cache != null:
		return _slime_detail_texture_cache
	var tex: Texture2D = _load_texture_or_null(SLIME_DETAIL_TEXTURE_PATH)
	if tex != null:
		_slime_detail_texture_cache = tex
		return _slime_detail_texture_cache
	_slime_detail_texture_cache = _stone_texture()
	return _slime_detail_texture_cache

func _load_texture_or_null(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return res as Texture2D
	return null

func _role_tint(tile_type: String) -> Color:
	match tile_type:
		"gather":
			return Color(0.70, 0.95, 0.56, 1.0)
		"defense":
			return Color(0.43, 0.85, 0.98, 1.0)
		"melee":
			return Color(0.94, 0.34, 0.34, 1.0)
		"ranged":
			return Color(0.82, 0.70, 1.0, 1.0)
		_:
			return Color(0.86, 0.90, 0.92, 1.0)

func _animate_lights() -> void:
	var pulse: float = 0.95 + 0.05 * sin(_visual_time * 1.5)
	if _fill_light != null:
		_fill_light.light_energy = 1.06 + 0.08 * sin(_visual_time * 1.1)
	for light in _point_lights:
		if light == null or not is_instance_valid(light):
			continue
		light.light_energy = 0.32 * pulse
	for key in _pool_material_cache.keys():
		var mat: Material = _pool_material_cache[key]
		if mat == null:
			continue
		if mat is ShaderMaterial:
			var shader_mat: ShaderMaterial = mat
			shader_mat.set_shader_parameter("emission_strength", 0.0045 + 0.0008 * sin(_visual_time * 0.85))
			shader_mat.set_shader_parameter("bubble_strength", 0.0022 + 0.0006 * sin(_visual_time * 1.35))
			shader_mat.set_shader_parameter("pulse_speed", 0.40 + 0.02 * sin(_visual_time * 0.45))
	if _key_light != null:
		_key_light.light_energy = 1.92 + 0.08 * sin(_visual_time * 0.42)

func _orbit_camera(delta: Vector2) -> void:
	_camera_yaw_target -= delta.x * 0.008
	_camera_pitch_target = clampf(_camera_pitch_target + delta.y * 0.006, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	_camera_yaw_target = clampf(_camera_yaw_target, CAMERA_YAW_MIN, CAMERA_YAW_MAX)

func _pan_camera(delta: Vector2) -> void:
	if _camera == null:
		return
	var cam_basis: Basis = _camera.global_transform.basis
	var right_flat: Vector3 = cam_basis.x
	right_flat.y = 0.0
	right_flat = right_flat.normalized()
	var forward_flat: Vector3 = -cam_basis.z
	forward_flat.y = 0.0
	forward_flat = forward_flat.normalized()
	var pan_scale: float = _camera_distance_target * 0.0026
	_camera_pan_offset += (-right_flat * delta.x + forward_flat * delta.y) * pan_scale
	_clamp_pan_offset()

func _clamp_pan_offset() -> void:
	if _state == null:
		return
	var max_pan_x: float = float(_state.width) * tile_world_size * 0.30
	var max_pan_z: float = float(_state.height) * tile_world_size * 0.30
	_camera_pan_offset.x = clampf(_camera_pan_offset.x, -max_pan_x, max_pan_x)
	_camera_pan_offset.y = 0.0
	_camera_pan_offset.z = clampf(_camera_pan_offset.z, -max_pan_z, max_pan_z)

func _is_pan_modifier_active() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)

func _apply_startup_visual_contract(static_stamp: String) -> void:
	if _state == null:
		return
	var signature: String = static_stamp
	var should_reset: bool = _force_camera_reset or _camera_contract_signature.is_empty()
	if should_reset:
		_camera_contract_signature = signature
		_force_camera_reset = false
		_apply_camera_baseline_defaults()
		_camera_distance_target = _default_camera_distance()
		_camera_yaw = _camera_yaw_target
		_camera_pitch = _camera_pitch_target
		_camera_distance = _camera_distance_target
		_camera_initialized = true
	_ensure_lighting_contract()

func _ensure_lighting_contract() -> void:
	if _environment != null and _environment.environment != null:
		var env: Environment = _environment.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(STABILIZATION_ENV_BASELINE["background_color"])
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(STABILIZATION_ENV_BASELINE["ambient_color"])
		env.ambient_light_energy = float(STABILIZATION_ENV_BASELINE["ambient_energy"])
		env.adjustment_enabled = true
		env.adjustment_brightness = float(STABILIZATION_ENV_BASELINE["brightness"])
		env.adjustment_contrast = float(STABILIZATION_ENV_BASELINE["contrast"])
		env.adjustment_saturation = float(STABILIZATION_ENV_BASELINE["saturation"])
		env.fog_enabled = bool(STABILIZATION_ENV_BASELINE["fog_enabled"])
		env.fog_density = float(STABILIZATION_ENV_BASELINE["fog_density"])
	if _key_light != null:
		_key_light.light_energy = maxf(_key_light.light_energy, float(STABILIZATION_LIGHT_BASELINE["key_energy"]) - 0.10)
	if _fill_light != null:
		_fill_light.light_energy = maxf(_fill_light.light_energy, float(STABILIZATION_LIGHT_BASELINE["fill_energy"]) - 0.08)
		_fill_light.omni_range = maxf(_fill_light.omni_range, float(STABILIZATION_LIGHT_BASELINE["fill_range"]))

func _reset_camera_if_needed() -> void:
	var default_distance: float = _default_camera_distance()
	if not _camera_initialized:
		_camera_distance = default_distance
		_camera_distance_target = default_distance
		_camera_yaw = float(STABILIZATION_CAMERA_BASELINE["default_yaw"])
		_camera_yaw_target = _camera_yaw
		_camera_pitch = float(STABILIZATION_CAMERA_BASELINE["default_pitch"])
		_camera_pitch_target = _camera_pitch
		_camera_pan_offset = Vector3.ZERO
		_camera_initialized = true
	_camera_yaw_target = clampf(_camera_yaw_target, float(STABILIZATION_CAMERA_BASELINE["yaw_min"]), float(STABILIZATION_CAMERA_BASELINE["yaw_max"]))
	_camera_pitch_target = clampf(_camera_pitch_target, float(STABILIZATION_CAMERA_BASELINE["pitch_min"]), float(STABILIZATION_CAMERA_BASELINE["pitch_max"]))
	_camera_distance_target = clampf(_camera_distance_target, float(STABILIZATION_CAMERA_BASELINE["distance_min"]), float(STABILIZATION_CAMERA_BASELINE["distance_max"]))

func _apply_camera_baseline_defaults() -> void:
	_camera_pan_offset = Vector3.ZERO
	_camera_yaw_target = clampf(
		float(STABILIZATION_CAMERA_BASELINE["default_yaw"]),
		float(STABILIZATION_CAMERA_BASELINE["yaw_min"]),
		float(STABILIZATION_CAMERA_BASELINE["yaw_max"])
	)
	_camera_pitch_target = clampf(
		float(STABILIZATION_CAMERA_BASELINE["default_pitch"]),
		float(STABILIZATION_CAMERA_BASELINE["pitch_min"]),
		float(STABILIZATION_CAMERA_BASELINE["pitch_max"])
	)

func _default_camera_distance() -> float:
	if _state == null:
		return 22.0
	var board_span: float = maxf(float(_state.width), float(_state.height)) * tile_world_size
	var aspect: float = float(_viewport_size.x) / maxf(1.0, float(_viewport_size.y))
	var aspect_adjust: float = 0.90 + clampf(1.50 - aspect, -0.18, 0.60) * 0.18
	return clampf(board_span * aspect_adjust + 2.6, CAMERA_MIN_DISTANCE + 1.0, CAMERA_MAX_DISTANCE * 0.78)

func _update_camera_transform(force: bool) -> void:
	if _camera == null or _state == null:
		return
	if force:
		_camera_yaw = _camera_yaw_target
		_camera_pitch = _camera_pitch_target
		_camera_distance = _camera_distance_target
	else:
		var smoothing: float = 0.14
		_camera_yaw = lerp_angle(_camera_yaw, _camera_yaw_target, smoothing)
		_camera_pitch = lerpf(_camera_pitch, _camera_pitch_target, smoothing)
		_camera_distance = lerpf(_camera_distance, _camera_distance_target, smoothing)
	_camera_pitch = clampf(_camera_pitch, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	_camera_yaw = clampf(_camera_yaw, CAMERA_YAW_MIN, CAMERA_YAW_MAX)
	_camera_distance = clampf(_camera_distance, CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE)
	_clamp_pan_offset()

	var target: Vector3 = _camera_base_target + _camera_pan_offset
	var cp: float = cos(_camera_pitch)
	var offset: Vector3 = Vector3(
		cp * sin(_camera_yaw),
		sin(_camera_pitch),
		cp * cos(_camera_yaw)
	) * _camera_distance
	_camera.position = target + offset
	_camera.look_at(target + Vector3(0.0, 0.18, 0.0), Vector3.UP)
	if _key_light != null:
		_key_light.position = target + Vector3(-6.0, 18.0, -4.0)
	if _rim_light != null:
		_rim_light.position = target + Vector3(0.0, 14.0, 0.0)
	if _fill_light != null:
		_fill_light.position = target + Vector3(0.0, 4.8, 0.0)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _owned_neighbor_count(tile: Vector2i, tile_set: Dictionary) -> int:
	var count: int = 0
	for n in [tile + Vector2i.RIGHT, tile + Vector2i.LEFT, tile + Vector2i.UP, tile + Vector2i.DOWN]:
		if tile_set.has(_tile_key(n)):
			count += 1
	return count

func _is_near_used_tile(tile: Vector2i, used_tiles: Dictionary, radius: int) -> bool:
	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			if ox == 0 and oy == 0:
				continue
			if used_tiles.has(_tile_key(tile + Vector2i(ox, oy))):
				return true
	return false

func _tile_noise(x: int, y: int, salt: int) -> int:
	var n: int = int(x * 73856093) ^ int(y * 19349663) ^ int(salt * 83492791)
	return absi(n) % 997

func _noise01(x: int, y: int) -> float:
	return float(_tile_noise(x, y, 313) % 1000) / 999.0

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
