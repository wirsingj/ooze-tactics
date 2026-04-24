extends Node3D
class_name World3DRenderer

const PLAYER_TINT: Color = Color(0.33, 0.90, 0.44, 1.0)
const CAVE_FLOOR_BASE: Color = Color(0.22, 0.22, 0.23, 1.0)
const CAVE_FLOOR_ALT: Color = Color(0.12, 0.12, 0.13, 1.0)
const CAVE_WALL_BASE: Color = Color(0.18, 0.17, 0.18, 1.0)
const CAVE_WALL_ALT: Color = Color(0.08, 0.08, 0.09, 1.0)

const CAMERA_MIN_DISTANCE: float = 8.0
const CAMERA_MAX_DISTANCE: float = 46.0
const CAMERA_MIN_PITCH: float = deg_to_rad(36.0)
const CAMERA_MAX_PITCH: float = deg_to_rad(62.0)
const CAMERA_YAW_MIN: float = deg_to_rad(-112.0)
const CAMERA_YAW_MAX: float = deg_to_rad(18.0)
const CAMERA_DEFAULT_YAW: float = deg_to_rad(0.0)
const CAMERA_DEFAULT_PITCH: float = deg_to_rad(49.0)
const CAMERA_DRAG_THRESHOLD: float = 6.0
const DRAG_NONE: int = 0
const DRAG_ORBIT: int = 1
const DRAG_PAN: int = 2
const OOZE_MASK_SCALE: int = 10
const OOZE_MASK_SMOOTH_PASSES: int = 2
const OOZE_ENABLE_FRAGMENTED_SURFACE_DETAILS: bool = false
const PHASED_BUILD_MODE_ENABLED: bool = false
const STRICT_ENV_ASSET_KIT_ONLY: bool = true
const ASSET_MANIFEST_PATH: String = "res://data/world3d_asset_manifest.json"

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
	"background_color": Color(0.026, 0.024, 0.031, 1.0),
	"ambient_color": Color(0.30, 0.29, 0.32, 1.0),
	"ambient_energy": 0.82,
	"brightness": 1.12,
	"contrast": 1.24,
	"saturation": 0.96,
	"fog_enabled": true,
	"fog_density": 0.010,
}
const STABILIZATION_LIGHT_BASELINE := {
	"key_energy": 3.42,
	"fill_energy": 0.98,
	"fill_range": 70.0,
	"rim_energy": 0.50,
}
const ENABLE_CAVE_CEILING: bool = false

const POOL_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 owner_color : source_color = vec4(0.3, 0.9, 0.8, 1.0);
uniform sampler2D mask_tex;
uniform sampler2D detail_tex;
uniform vec2 texel_size = vec2(0.01, 0.01);
uniform float pulse_speed = 0.22;
uniform float bubble_strength = 0.0015;
uniform float emission_strength = 0.010;
uniform float detail_scale = 6.2;
uniform float body_thickness = 0.010;
uniform float lip_thickness = 0.018;
uniform float flow_scale = 1.34;
uniform float flow_speed = 0.010;
uniform float flow_normal_strength = 0.36;
uniform float edge_darkening_strength = 0.18;
uniform float contact_darkening_strength = 0.10;
uniform float clearcoat_strength = 0.64;
uniform float specular_strength = 0.56;

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
	float body = smoothstep(0.20, 0.90, m);
	float lip = smoothstep(0.42, 0.66, m) - smoothstep(0.78, 0.98, m);
	vec2 flow_uv = UV * flow_scale + vec2(TIME * flow_speed, -TIME * flow_speed * 0.7);
	float flow = texture(detail_tex, flow_uv).r - 0.5;
	float bulge = fbm(UV * (detail_scale * 0.32) + vec2(TIME * flow_speed * 0.35, -TIME * flow_speed * 0.21));
	float wave = sin((VERTEX.x * 1.1 + VERTEX.z * 1.0) + TIME * pulse_speed);
	VERTEX.y += body * body_thickness * (0.55 + bulge * 0.65)
		+ lip * lip_thickness
		+ flow * bubble_strength
		+ wave * bubble_strength * 0.40;
}

void fragment() {
	float m0 = texture(mask_tex, UV).a;
	float m1 = texture(mask_tex, UV + vec2(texel_size.x, 0.0)).a;
	float m2 = texture(mask_tex, UV + vec2(0.0, texel_size.y)).a;
	float m3 = texture(mask_tex, UV + vec2(texel_size.x, texel_size.y)).a;
	float mask = clamp(m0 * 0.60 + (m1 + m2) * 0.15 + m3 * 0.10, 0.0, 1.0);
	float alpha = smoothstep(0.20, 0.90, mask);
	if (alpha < 0.02) {
		discard;
	}

	float gx = texture(mask_tex, UV + vec2(texel_size.x, 0.0)).a - texture(mask_tex, UV - vec2(texel_size.x, 0.0)).a;
	float gy = texture(mask_tex, UV + vec2(0.0, texel_size.y)).a - texture(mask_tex, UV - vec2(0.0, texel_size.y)).a;
	vec2 grad = vec2(gx, gy);
	float edge = smoothstep(0.42, 0.66, mask) - smoothstep(0.78, 0.98, mask);
	float body = smoothstep(0.20, 0.90, mask);

	vec2 flow_uv = UV * detail_scale + vec2(TIME * flow_speed * 1.4, -TIME * flow_speed);
	float flow0 = texture(detail_tex, flow_uv).r;
	float flowx = texture(detail_tex, flow_uv + vec2(0.01, 0.0)).r;
	float flowy = texture(detail_tex, flow_uv + vec2(0.0, 0.01)).r;
	vec2 flow_grad = vec2(flowx - flow0, flowy - flow0);
	float broad = fbm(UV * (detail_scale * 0.38) + vec2(TIME * 0.02, -TIME * 0.015));
	float shimmer = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.x * 2.0 + UV.y * 1.7);

	vec2 normal_xy = flow_grad * flow_normal_strength + grad * edge * 0.34;
	vec3 mapped_normal = normalize(vec3(normal_xy, 1.0));
	NORMAL_MAP = mapped_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	vec3 dark_tint = mix(owner_color.rgb * 0.48, vec3(0.03, 0.04, 0.05), 0.36);
	vec3 mid_tint = owner_color.rgb * 0.86;
	vec3 col = mix(dark_tint, mid_tint, body);
	col *= 0.86 + broad * 0.16 + shimmer * 0.05;
	col = mix(col, col * 0.80, edge * edge_darkening_strength * 2.0);
	col = mix(col, col * 0.74, edge * contact_darkening_strength * 2.0);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);

	ALBEDO = col;
	ROUGHNESS = clamp(0.40 - body * 0.06 + (1.0 - broad) * 0.14 + edge * 0.08, 0.22, 0.68);
	METALLIC = 0.0;
	SPECULAR = specular_strength + fres * 0.12;
	CLEARCOAT = clearcoat_strength * (0.46 + edge * 0.18);
	EMISSION = owner_color.rgb * emission_strength * (0.06 + edge * 0.12 + broad * 0.05 + fres * 0.10);
	ALPHA = alpha * (0.76 + edge * 0.16);
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
uniform vec4 damp_tint : source_color = vec4(0.08, 0.12, 0.14, 1.0);
uniform float uv_scale = 12.0;
uniform sampler2D detail_albedo_tex : source_color;
uniform sampler2D detail_roughness_tex;
uniform sampler2D detail_normal_tex : hint_normal;
uniform float detail_mix = 0.52;
uniform float normal_strength = 0.42;
uniform float height_amp = 0.012;

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
	vec2 p = UV * max(1.0, uv_scale * 0.22);
	float n0 = noise(p);
	float n1 = noise(p * 1.8 + vec2(2.8, 4.4));
	float disp = (n0 * 0.60 + n1 * 0.40) - 0.5;
	VERTEX.y += disp * height_amp;
}

void fragment() {
	vec2 macro_uv = UV * max(1.0, uv_scale * 0.16);
	float n0 = noise(macro_uv);
	float n1 = noise(macro_uv * 1.7 + vec2(3.2, 6.8));
	float n2 = noise(macro_uv * 2.3 + vec2(7.1, 1.9));
	float blend = clamp(n0 * 0.54 + n1 * 0.34 + n2 * 0.12, 0.0, 1.0);
	float striations = noise(macro_uv * 3.6 + vec2(5.2, 1.4));
	striations = smoothstep(0.62, 0.88, striations);
	float cracks = abs(sin(macro_uv.x * 17.0 + n1 * 5.8) * cos(macro_uv.y * 15.0 - n2 * 6.6));
	cracks = smoothstep(0.74, 0.97, cracks);
	float mineral = noise(macro_uv * 4.8 + vec2(1.7, 9.3));
	float damp = smoothstep(0.56, 0.90, n2);
	vec2 tex_uv = UV * max(1.0, uv_scale * 0.08);
	vec3 detail_col = texture(detail_albedo_tex, tex_uv).rgb;
	float detail_rough = texture(detail_roughness_tex, tex_uv).r;
	vec3 detail_nrm = texture(detail_normal_tex, tex_uv).rgb;
	vec3 stone = mix(stone_alt.rgb, stone_base.rgb, blend);
	stone = mix(stone, detail_col, detail_mix * 0.26);
	stone = mix(stone, damp_tint.rgb, damp * 0.18);
	stone = mix(stone, stone * 0.78, striations * 0.18 + cracks * 0.26);
	stone = mix(stone, stone * 1.06, mineral * 0.10);
	float wet = clamp(damp * 0.64 + (1.0 - blend) * 0.12, 0.0, 1.0);
	ALBEDO = stone;
	ROUGHNESS = clamp(0.66 + (1.0 - blend) * 0.12 - wet * 0.22 + striations * 0.08 + detail_rough * 0.08, 0.26, 0.92);
	METALLIC = 0.0;
	SPECULAR = 0.34;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), detail_nrm, normal_strength * 0.40);
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
	float phase = TIME * pulse_speed + MODEL_MATRIX[3].x * 1.9 + MODEL_MATRIX[3].z * 1.3;
	VERTEX.y += sin(phase) * pulse_amp;
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.x * 5.8 + UV.y * 4.1);
	ALBEDO = crest_color.rgb * (0.92 + pulse * 0.08);
	ROUGHNESS = crest_roughness;
	METALLIC = 0.01;
	EMISSION = crest_emission.rgb * (0.10 + pulse * 0.30);
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
var _asset_scene_cache: Dictionary = {}
var _asset_material_cache: Dictionary = {}
var _asset_manifest: Dictionary = {}
var _geometry_asset_registry: Dictionary = {}
var _geometry_asset_normalize: Dictionary = {}
var _texture_asset_registry: Dictionary = {}
var _camera_contract_signature: String = ""
var _force_camera_reset: bool = false
var _scene_graph_built: bool = false

func _ready() -> void:
	initialize_runtime_renderer()

func initialize_runtime_renderer() -> void:
	if _scene_graph_built:
		return
	_load_asset_manifest()
	_build_scene_graph()
	_scene_graph_built = true

func configure(palette_renderer: BoardRenderer) -> void:
	_palette_renderer = palette_renderer

func reset_startup_contract() -> void:
	_force_camera_reset = true
	_camera_contract_signature = ""
	_camera_initialized = false

func set_viewport_size(size: Vector2i) -> void:
	_viewport_size = Vector2i(maxi(64, size.x), maxi(64, size.y))
	_update_camera_transform(true)

func apply_capture_camera_preset(yaw_degrees: float = 0.0, pitch_degrees: float = 48.0, distance: float = 26.0) -> void:
	_camera_pan_offset = Vector3.ZERO
	_camera_yaw = deg_to_rad(yaw_degrees)
	_camera_yaw_target = _camera_yaw
	_camera_pitch = deg_to_rad(pitch_degrees)
	_camera_pitch_target = _camera_pitch
	_camera_distance = distance
	_camera_distance_target = distance
	_camera_initialized = true
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

func _phase_one_world_only() -> bool:
	return PHASED_BUILD_MODE_ENABLED

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
	_camera.fov = 34.0
	_camera.near = 0.05
	_camera.far = 240.0
	add_child(_camera)

	_key_light = DirectionalLight3D.new()
	_key_light.name = "CaveKeyLight"
	_key_light.light_color = Color(0.90, 0.78, 0.66, 1.0)
	_key_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["key_energy"])
	_key_light.shadow_enabled = true
	_key_light.rotation_degrees = Vector3(-56.0, -28.0, 0.0)
	add_child(_key_light)

	_rim_light = DirectionalLight3D.new()
	_rim_light.name = "RimLight"
	_rim_light.light_color = Color(0.22, 0.34, 0.56, 1.0)
	_rim_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["rim_energy"])
	_rim_light.shadow_enabled = false
	_rim_light.rotation_degrees = Vector3(-38.0, 142.0, 0.0)
	add_child(_rim_light)

	_fill_light = OmniLight3D.new()
	_fill_light.name = "CaveFillLight"
	_fill_light.light_color = Color(0.24, 0.28, 0.34, 1.0)
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
	env.glow_enabled = false
	env.fog_enabled = bool(STABILIZATION_ENV_BASELINE["fog_enabled"])
	env.fog_light_color = Color(0.22, 0.24, 0.30, 1.0)
	env.fog_light_energy = 0.28
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
		var tier: int = int(block.get("upgrade_tier", 0))
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

func _terrain_height_local(local_x: float, local_z: float, board_width: float, board_height: float) -> float:
	var nx: float = local_x / maxf(0.001, board_width * 0.5)
	var nz: float = local_z / maxf(0.001, board_height * 0.5)
	var level_phase: float = float(_state.level_index) * 0.67 if _state != null else 0.0
	var angle: float = atan2(nz, nx)
	var footprint_warp: float = sin(angle * 2.7 + level_phase * 0.35) * 0.09 + sin(angle * 5.1 - level_phase * 0.22) * 0.05
	var edge: float = maxf(absf(nx), absf(nz)) + footprint_warp
	var rim_t: float = clampf((edge - 0.48) / 0.52, 0.0, 1.0)
	rim_t = rim_t * rim_t * (3.0 - 2.0 * rim_t)
	var basin_t: float = clampf((0.62 - edge) / 0.62, 0.0, 1.0)
	basin_t = basin_t * basin_t * (3.0 - 2.0 * basin_t)
	var wave_a: float = sin(local_x * 0.28 + level_phase * 0.50) * cos(local_z * 0.24 - level_phase * 0.40)
	var wave_b: float = sin((local_x + local_z) * 0.18 + level_phase * 1.10)
	var lane_center: float = sin(nx * 1.8 + level_phase * 0.30) * board_height * 0.16 + cos(nx * 0.8 - level_phase * 0.22) * board_height * 0.04
	var lane_dist: float = absf(local_z - lane_center)
	var lane_t: float = clampf(1.0 - lane_dist / maxf(0.001, board_height * 0.42), 0.0, 1.0)
	lane_t = lane_t * lane_t * (3.0 - 2.0 * lane_t)
	var side_ridge: float = smoothstep(0.18, 0.86, absf(nz))
	var shoulder: float = smoothstep(0.14, 0.78, absf(nx)) * smoothstep(0.08, 0.64, absf(nz))
	var tilt: float = nx * 0.14 + nz * 0.05
	var recess_band: float = sin(local_x * 0.14 - local_z * 0.10 + level_phase * 0.24)
	return -0.24 + rim_t * 1.52 - basin_t * 0.36 + wave_a * 0.22 + wave_b * 0.16 - lane_t * 0.22 + side_ridge * 0.10 + shoulder * 0.08 + tilt + recess_band * 0.08

func _tile_terrain_top(tile: Vector2i, board_width: float, board_height: float, board_top: float) -> float:
	var lx: float = ((float(tile.x) + 0.5) / maxf(1.0, float(_state.width)) - 0.5) * board_width
	var lz: float = ((float(tile.y) + 0.5) / maxf(1.0, float(_state.height)) - 0.5) * board_height
	return board_top + _terrain_height_local(lx, lz, board_width, board_height)

func _build_carved_floor_mesh(board_width: float, board_height: float, board_top: float, sub_x: int, sub_z: int) -> ArrayMesh:
	var sx: int = maxi(2, sub_x)
	var sz: int = maxi(2, sub_z)
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
			var h: float = board_top + _terrain_height_local(lx, lz, board_width, board_height)
			var idx: int = z * (sx + 1) + x
			vertices[idx] = Vector3(lx, h, lz)
			uvs[idx] = Vector2(fx, fz)
			var h_l: float = board_top + _terrain_height_local(lx - eps_x, lz, board_width, board_height)
			var h_r: float = board_top + _terrain_height_local(lx + eps_x, lz, board_width, board_height)
			var h_d: float = board_top + _terrain_height_local(lx, lz - eps_z, board_width, board_height)
			var h_u: float = board_top + _terrain_height_local(lx, lz + eps_z, board_width, board_height)
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

func _build_ooze_conforming_mesh(board_width: float, board_height: float, board_top: float, density: float = 2.1) -> ArrayMesh:
	var sx: int = maxi(16, int(board_width * density))
	var sz: int = maxi(16, int(board_height * density))
	return _build_carved_floor_mesh(board_width, board_height, board_top, sx, sz)

func _append_skirt_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	var base: int = vertices.size()
	vertices.push_back(a)
	vertices.push_back(b)
	vertices.push_back(c)
	vertices.push_back(d)
	normals.push_back(normal)
	normals.push_back(normal)
	normals.push_back(normal)
	normals.push_back(normal)
	uvs.push_back(Vector2(0.0, 0.0))
	uvs.push_back(Vector2(1.0, 0.0))
	uvs.push_back(Vector2(1.0, 1.0))
	uvs.push_back(Vector2(0.0, 1.0))
	indices.push_back(base + 0)
	indices.push_back(base + 1)
	indices.push_back(base + 2)
	indices.push_back(base + 0)
	indices.push_back(base + 2)
	indices.push_back(base + 3)

func _add_terrain_skirt(board_width: float, board_height: float, board_top: float) -> void:
	if _state == null:
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var inset: float = 0.34
	var outward: float = 2.20
	var drop: float = 2.05
	var seg_x: int = maxi(12, _state.width * 2)
	var seg_z: int = maxi(12, _state.height * 2)

	var to_world := func(local: Vector3) -> Vector3:
		return _camera_base_target + local

	var half_w: float = board_width * 0.5
	var half_h: float = board_height * 0.5
	var inner_north_z: float = -half_h - inset
	var outer_north_z: float = inner_north_z - outward
	var inner_south_z: float = half_h + inset
	var outer_south_z: float = inner_south_z + outward
	for i in range(seg_x):
		var t0: float = float(i) / float(seg_x)
		var t1: float = float(i + 1) / float(seg_x)
		var x0: float = lerpf(-half_w - inset, half_w + inset, t0)
		var x1: float = lerpf(-half_w - inset, half_w + inset, t1)
		var y_n0: float = board_top + _terrain_height_local(x0, inner_north_z, board_width, board_height) - 0.03
		var y_n1: float = board_top + _terrain_height_local(x1, inner_north_z, board_width, board_height) - 0.03
		var y_n_out0: float = y_n0 - 0.18 - _noise01(int((x0 + 41.0) * 19.0), int((outer_north_z + 67.0) * 23.0)) * 0.52
		var y_n_out1: float = y_n1 - 0.18 - _noise01(int((x1 + 43.0) * 19.0), int((outer_north_z + 71.0) * 23.0)) * 0.52
		var n_in0: Vector3 = to_world.call(Vector3(x0, y_n0, inner_north_z))
		var n_in1: Vector3 = to_world.call(Vector3(x1, y_n1, inner_north_z))
		var n_out0: Vector3 = to_world.call(Vector3(x0, y_n_out0, outer_north_z))
		var n_out1: Vector3 = to_world.call(Vector3(x1, y_n_out1, outer_north_z))
		_append_skirt_quad(vertices, normals, uvs, indices, n_in0, n_in1, n_out1, n_out0)
		_append_skirt_quad(
			vertices,
			normals,
			uvs,
			indices,
			n_out0,
			n_out1,
			n_out1 + Vector3(0.0, -drop, 0.0),
			n_out0 + Vector3(0.0, -drop, 0.0)
		)

		var y_s0: float = board_top + _terrain_height_local(x0, inner_south_z, board_width, board_height) - 0.03
		var y_s1: float = board_top + _terrain_height_local(x1, inner_south_z, board_width, board_height) - 0.03
		var y_s_out0: float = y_s0 - 0.16 - _noise01(int((x0 + 53.0) * 17.0), int((outer_south_z + 79.0) * 29.0)) * 0.52
		var y_s_out1: float = y_s1 - 0.16 - _noise01(int((x1 + 57.0) * 17.0), int((outer_south_z + 83.0) * 29.0)) * 0.52
		var s_in0: Vector3 = to_world.call(Vector3(x0, y_s0, inner_south_z))
		var s_in1: Vector3 = to_world.call(Vector3(x1, y_s1, inner_south_z))
		var s_out0: Vector3 = to_world.call(Vector3(x0, y_s_out0, outer_south_z))
		var s_out1: Vector3 = to_world.call(Vector3(x1, y_s_out1, outer_south_z))
		_append_skirt_quad(vertices, normals, uvs, indices, s_in1, s_in0, s_out0, s_out1)
		_append_skirt_quad(
			vertices,
			normals,
			uvs,
			indices,
			s_out1,
			s_out0,
			s_out0 + Vector3(0.0, -drop, 0.0),
			s_out1 + Vector3(0.0, -drop, 0.0)
		)

	var inner_west_x: float = -half_w - inset
	var outer_west_x: float = inner_west_x - outward
	var inner_east_x: float = half_w + inset
	var outer_east_x: float = inner_east_x + outward
	for i in range(seg_z):
		var t0: float = float(i) / float(seg_z)
		var t1: float = float(i + 1) / float(seg_z)
		var z0: float = lerpf(-half_h - inset, half_h + inset, t0)
		var z1: float = lerpf(-half_h - inset, half_h + inset, t1)
		var y_w0: float = board_top + _terrain_height_local(inner_west_x, z0, board_width, board_height) - 0.03
		var y_w1: float = board_top + _terrain_height_local(inner_west_x, z1, board_width, board_height) - 0.03
		var y_w_out0: float = y_w0 - 0.16 - _noise01(int((outer_west_x + 61.0) * 17.0), int((z0 + 73.0) * 19.0)) * 0.52
		var y_w_out1: float = y_w1 - 0.16 - _noise01(int((outer_west_x + 67.0) * 17.0), int((z1 + 79.0) * 19.0)) * 0.52
		var w_in0: Vector3 = to_world.call(Vector3(inner_west_x, y_w0, z0))
		var w_in1: Vector3 = to_world.call(Vector3(inner_west_x, y_w1, z1))
		var w_out0: Vector3 = to_world.call(Vector3(outer_west_x, y_w_out0, z0))
		var w_out1: Vector3 = to_world.call(Vector3(outer_west_x, y_w_out1, z1))
		_append_skirt_quad(vertices, normals, uvs, indices, w_in1, w_in0, w_out0, w_out1)
		_append_skirt_quad(
			vertices,
			normals,
			uvs,
			indices,
			w_out1,
			w_out0,
			w_out0 + Vector3(0.0, -drop, 0.0),
			w_out1 + Vector3(0.0, -drop, 0.0)
		)

		var y_e0: float = board_top + _terrain_height_local(inner_east_x, z0, board_width, board_height) - 0.03
		var y_e1: float = board_top + _terrain_height_local(inner_east_x, z1, board_width, board_height) - 0.03
		var y_e_out0: float = y_e0 - 0.16 - _noise01(int((outer_east_x + 71.0) * 17.0), int((z0 + 83.0) * 19.0)) * 0.52
		var y_e_out1: float = y_e1 - 0.16 - _noise01(int((outer_east_x + 79.0) * 17.0), int((z1 + 89.0) * 19.0)) * 0.52
		var e_in0: Vector3 = to_world.call(Vector3(inner_east_x, y_e0, z0))
		var e_in1: Vector3 = to_world.call(Vector3(inner_east_x, y_e1, z1))
		var e_out0: Vector3 = to_world.call(Vector3(outer_east_x, y_e_out0, z0))
		var e_out1: Vector3 = to_world.call(Vector3(outer_east_x, y_e_out1, z1))
		_append_skirt_quad(vertices, normals, uvs, indices, e_in0, e_in1, e_out1, e_out0)
		_append_skirt_quad(
			vertices,
			normals,
			uvs,
			indices,
			e_out0,
			e_out1,
			e_out1 + Vector3(0.0, -drop, 0.0),
			e_out0 + Vector3(0.0, -drop, 0.0)
		)

	if vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var skirt: MeshInstance3D = MeshInstance3D.new()
	skirt.mesh = mesh
	skirt.material_override = _stone_shader_material(
		Color(0.17, 0.16, 0.17, 1.0),
		Color(0.08, 0.08, 0.09, 1.0),
		Color(0.08, 0.10, 0.12, 1.0),
		6.8,
		0.026,
		0.52
	)
	skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_root.add_child(skirt)

func _add_floor_rock_shelves(board_width: float, board_height: float, board_top: float) -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if not _has_asset_scene("cave_wall"):
		return
	var shelves: Array[Dictionary] = [
		{"offset": Vector3(-board_width * 0.68, 0.0, -board_height * 0.64), "yaw": 44.0, "scale": Vector3(1.90, 0.76, 1.18), "lift": 0.06},
		{"offset": Vector3(board_width * 0.14, 0.0, -board_height * 0.68), "yaw": 182.0, "scale": Vector3(1.72, 0.72, 1.08), "lift": 0.04},
		{"offset": Vector3(board_width * 0.62, 0.0, -board_height * 0.32), "yaw": 104.0, "scale": Vector3(1.44, 0.66, 1.04), "lift": 0.03},
		{"offset": Vector3(-board_width * 0.52, 0.0, board_height * 0.58), "yaw": 132.0, "scale": Vector3(1.70, 0.66, 1.02), "lift": 0.03},
	]
	for i in range(shelves.size()):
		var shelf: Dictionary = shelves[i]
		var seed: int = i + _state.level_index * 73
		var offset: Vector3 = shelf["offset"]
		offset.x += (_noise01(seed * 17 + 3, seed * 29 + 11) - 0.5) * 0.24
		offset.z += (_noise01(seed * 31 + 5, seed * 37 + 13) - 0.5) * 0.22
		var pos: Vector3 = _camera_base_target + offset
		pos.y = board_top - 0.44 + float(shelf.get("lift", 0.0)) + (_noise01(seed * 41 + 7, seed * 43 + 17) - 0.5) * 0.10
		var yaw: float = deg_to_rad(float(shelf["yaw"]) + (_noise01(seed * 47 + 19, seed * 53 + 23) - 0.5) * 18.0)
		var scale: Vector3 = shelf["scale"]
		scale.x *= 0.90 + _noise01(seed * 59 + 2, seed * 61 + 7) * 0.26
		scale.y *= 0.90 + _noise01(seed * 67 + 11, seed * 71 + 13) * 0.18
		scale.z *= 0.90 + _noise01(seed * 73 + 17, seed * 79 + 29) * 0.20
		_add_asset_instance(
			_terrain_root,
			"cave_wall",
			Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos),
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)

func _add_board_edge_cliffs(board_width: float, board_height: float, board_top: float) -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if _has_asset_scene("cave_wall"):
		var cliff_data: Array[Dictionary] = [
			{"offset": Vector3(-board_width * 0.86, -0.30, -board_height * 0.10), "yaw": -92.0, "scale": Vector3(2.22, 3.08, 1.64)},
			{"offset": Vector3(board_width * 0.86, -0.30, -board_height * 0.10), "yaw": 92.0, "scale": Vector3(2.22, 3.08, 1.64)},
			{"offset": Vector3(-board_width * 0.28, -0.34, -board_height * 0.90), "yaw": 172.0, "scale": Vector3(1.98, 3.18, 1.52)},
			{"offset": Vector3(board_width * 0.28, -0.34, -board_height * 0.90), "yaw": 188.0, "scale": Vector3(1.98, 3.18, 1.52)},
			{"offset": Vector3(0.0, -0.42, -board_height * 0.96), "yaw": 180.0, "scale": Vector3(2.34, 3.46, 1.84)},
		]
		for i in range(cliff_data.size()):
			var seed: int = i + _state.level_index * 151
			var entry: Dictionary = cliff_data[i]
			var pos: Vector3 = _camera_base_target + entry["offset"]
			pos.x += (_noise01(seed * 17 + 3, seed * 23 + 7) - 0.5) * 0.28
			pos.y += (_noise01(seed * 31 + 11, seed * 37 + 13) - 0.5) * 0.16
			pos.z += (_noise01(seed * 41 + 17, seed * 43 + 19) - 0.5) * 0.22
			var yaw: float = deg_to_rad(float(entry["yaw"]) + (_noise01(seed * 47 + 23, seed * 53 + 29) - 0.5) * 10.0)
			var scale: Vector3 = entry["scale"]
			scale.x *= 0.92 + _noise01(seed * 59 + 31, seed * 61 + 37) * 0.16
			scale.y *= 0.92 + _noise01(seed * 67 + 41, seed * 71 + 43) * 0.18
			scale.z *= 0.92 + _noise01(seed * 73 + 47, seed * 79 + 53) * 0.14
			_add_asset_instance(
				_terrain_root,
				"cave_wall",
				Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos),
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i <= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
		return

	var fallback_mesh: BoxMesh = BoxMesh.new()
	fallback_mesh.size = Vector3(board_width + 1.8, 1.8, 0.8)
	var fallback_mat: ShaderMaterial = _stone_shader_material(
		Color(0.18, 0.17, 0.18, 1.0),
		Color(0.08, 0.08, 0.09, 1.0),
		Color(0.08, 0.10, 0.12, 1.0),
		7.2,
		0.026,
		0.76
	)
	var cliff: MeshInstance3D = MeshInstance3D.new()
	cliff.mesh = fallback_mesh
	cliff.material_override = fallback_mat
	cliff.position = _camera_base_target + Vector3(0.0, board_top - 0.62, -board_height * 0.94)
	cliff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_root.add_child(cliff)

func _add_phase1_structural_massing(board_width: float, board_height: float, board_top: float) -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if _has_asset_scene("cave_wall"):
		var masses: Array[Dictionary] = [
			{"offset": Vector3(-board_width * 0.34, -0.20, -board_height * 0.02), "yaw": -26.0, "scale": Vector3(1.34, 1.52, 1.08)},
			{"offset": Vector3(board_width * 0.30, -0.18, -board_height * 0.16), "yaw": 28.0, "scale": Vector3(1.24, 1.46, 1.00)},
			{"offset": Vector3(board_width * 0.22, -0.24, board_height * 0.26), "yaw": 96.0, "scale": Vector3(1.20, 1.40, 0.92)},
			{"offset": Vector3(-board_width * 0.18, -0.22, board_height * 0.30), "yaw": -102.0, "scale": Vector3(1.14, 1.34, 0.88)},
			{"offset": Vector3(0.02, -0.18, -board_height * 0.34), "yaw": 180.0, "scale": Vector3(1.08, 1.26, 0.84)},
		]
		for mass in masses:
			var pos: Vector3 = _camera_base_target + mass["offset"]
			_add_asset_instance(
				_terrain_root,
				"cave_wall",
				Transform3D(Basis(Vector3.UP, deg_to_rad(float(mass["yaw"]))).scaled(mass["scale"]), pos),
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			)
	else:
		var fallback_mat: ShaderMaterial = _stone_shader_material(
			Color(0.20, 0.19, 0.20, 1.0),
			Color(0.09, 0.09, 0.10, 1.0),
			Color(0.09, 0.10, 0.12, 1.0),
			7.6,
			0.024,
			0.82
		)
		var fallback_mesh: BoxMesh = BoxMesh.new()
		fallback_mesh.size = Vector3(1.6, 2.4, 1.2)
		var fallback_offsets: Array[Vector3] = [
			Vector3(-board_width * 0.32, board_top + 0.60, -board_height * 0.04),
			Vector3(board_width * 0.28, board_top + 0.58, -board_height * 0.18),
			Vector3(board_width * 0.20, board_top + 0.54, board_height * 0.24),
		]
		for o in fallback_offsets:
			var m: MeshInstance3D = MeshInstance3D.new()
			m.mesh = fallback_mesh
			m.position = _camera_base_target + o
			m.material_override = fallback_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			_terrain_root.add_child(m)

	# Carved lane walls for readable chokepoints (large forms, no tile-grid repetition).
	var lane_mat: ShaderMaterial = _stone_shader_material(
		CAVE_WALL_BASE.lerp(Color(0.24, 0.22, 0.21, 1.0), 0.16),
		CAVE_WALL_ALT.lerp(Color(0.11, 0.11, 0.12, 1.0), 0.20),
		Color(0.10, 0.11, 0.12, 1.0),
		8.2,
		0.032,
		0.86
	)
	var lane_mesh: BoxMesh = BoxMesh.new()
	lane_mesh.size = Vector3(1.32, 0.74, 0.46)
	var lane_chunks: Array[Dictionary] = [
		{"offset": Vector3(-board_width * 0.08, board_top + 0.20, -board_height * 0.10), "yaw": 0.0, "scale": Vector3(1.14, 1.0, 1.0)},
		{"offset": Vector3(board_width * 0.10, board_top + 0.20, -board_height * 0.12), "yaw": 0.0, "scale": Vector3(1.06, 1.0, 1.0)},
		{"offset": Vector3(0.00, board_top + 0.18, board_height * 0.12), "yaw": 0.0, "scale": Vector3(1.20, 1.0, 1.0)},
	]
	for chunk in lane_chunks:
		var lane: MeshInstance3D = MeshInstance3D.new()
		lane.mesh = lane_mesh
		lane.position = _camera_base_target + chunk["offset"]
		lane.rotation_degrees = Vector3(0.0, float(chunk["yaw"]), 0.0)
		lane.scale = chunk["scale"]
		lane.material_override = lane_mat
		lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_terrain_root.add_child(lane)

func _rebuild_static_world() -> void:
	_clear_children(_terrain_root)
	_ground_tops.clear()
	if _state == null:
		return

	var board_width: float = float(_state.width) * tile_world_size
	var board_height: float = float(_state.height) * tile_world_size
	var board_top: float = -0.02

	for y in range(_state.height):
		for x in range(_state.width):
			var tile: Vector2i = Vector2i(x, y)
			_ground_tops[_tile_key(tile)] = board_top

	_build_asset_kit_floor(board_width, board_height, board_top)
	_build_asset_kit_chamber(board_width, board_height, board_top)
	_build_asset_kit_blockers(board_top)
	_add_cave_doors()
	_add_chamber_accent_lights()
	_add_cave_foreground_occluders()

func _build_asset_kit_floor(board_width: float, board_height: float, board_top: float) -> void:
	if _terrain_root == null:
		return
	if not _has_asset_scene("floor_tile_rock"):
		return

	var segments: Array[Dictionary] = [
		{"offset": Vector3(-board_width * 0.30, board_top, -board_height * 0.24), "yaw": -10.0, "scale": Vector3(board_width * 0.46, 1.0, board_height * 0.42)},
		{"offset": Vector3(board_width * 0.24, board_top + 0.01, -board_height * 0.26), "yaw": 11.0, "scale": Vector3(board_width * 0.48, 1.0, board_height * 0.40)},
		{"offset": Vector3(-board_width * 0.18, board_top - 0.01, board_height * 0.22), "yaw": 6.0, "scale": Vector3(board_width * 0.44, 1.0, board_height * 0.44)},
		{"offset": Vector3(board_width * 0.28, board_top + 0.00, board_height * 0.24), "yaw": -13.0, "scale": Vector3(board_width * 0.46, 1.0, board_height * 0.42)},
		{"offset": Vector3(0.0, board_top + 0.02, 0.0), "yaw": 0.0, "scale": Vector3(board_width * 0.34, 1.0, board_height * 0.30)},
	]
	for seg in segments:
		var tf: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(seg["yaw"]))).scaled(seg["scale"]),
			_camera_base_target + seg["offset"]
		)
		var mat: Material = _stone_shader_material(
			Color(0.15, 0.15, 0.16, 1.0),
			Color(0.08, 0.08, 0.09, 1.0),
			Color(0.09, 0.11, 0.12, 1.0),
			8.0,
			0.020,
			0.78
		)
		_add_asset_instance(_terrain_root, "floor_tile_rock", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, mat)

func _build_asset_kit_chamber(board_width: float, board_height: float, board_top: float) -> void:
	if _terrain_root == null:
		return
	if not _has_asset_scene("cave_wall"):
		return

	var outer_masses: Array[Dictionary] = [
		{"asset": "cave_wall", "offset": Vector3(-board_width * 0.58, board_top + 0.12, -board_height * 0.44), "yaw": 156.0, "scale": Vector3(2.10, 2.60, 1.36)},
		{"asset": "cave_wall", "offset": Vector3(-board_width * 0.08, board_top + 0.14, -board_height * 0.56), "yaw": 180.0, "scale": Vector3(2.24, 2.74, 1.40)},
		{"asset": "cave_wall", "offset": Vector3(board_width * 0.44, board_top + 0.12, -board_height * 0.46), "yaw": 208.0, "scale": Vector3(2.08, 2.58, 1.34)},
		{"asset": "cave_wall", "offset": Vector3(-board_width * 0.72, board_top + 0.04, -board_height * 0.04), "yaw": -94.0, "scale": Vector3(1.84, 2.42, 1.22)},
		{"asset": "cave_wall", "offset": Vector3(board_width * 0.72, board_top + 0.04, -board_height * 0.02), "yaw": 92.0, "scale": Vector3(1.84, 2.42, 1.22)},
		{"asset": "cave_wall", "offset": Vector3(-board_width * 0.54, board_top, board_height * 0.44), "yaw": -30.0, "scale": Vector3(1.86, 2.14, 1.18)},
		{"asset": "cave_wall", "offset": Vector3(board_width * 0.56, board_top, board_height * 0.42), "yaw": 26.0, "scale": Vector3(1.86, 2.14, 1.18)},
	]
	for entry in outer_masses:
		var key: String = String(entry.get("asset", "cave_wall"))
		if not _has_asset_scene(key):
			continue
		var tf: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(entry["yaw"]))).scaled(entry["scale"]),
			_camera_base_target + entry["offset"]
		)
		_add_asset_instance(_terrain_root, key, tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	var corner_masses: Array[Dictionary] = [
		{"asset": "cave_corner", "offset": Vector3(-board_width * 0.82, board_top + 0.08, -board_height * 0.60), "yaw": 132.0, "scale": Vector3(1.68, 2.28, 1.68)},
		{"asset": "cave_corner", "offset": Vector3(board_width * 0.82, board_top + 0.08, -board_height * 0.60), "yaw": 228.0, "scale": Vector3(1.68, 2.28, 1.68)},
		{"asset": "cave_corner", "offset": Vector3(-board_width * 0.78, board_top, board_height * 0.58), "yaw": 46.0, "scale": Vector3(1.54, 2.06, 1.54)},
		{"asset": "cave_corner", "offset": Vector3(board_width * 0.78, board_top, board_height * 0.58), "yaw": -46.0, "scale": Vector3(1.54, 2.06, 1.54)},
	]
	for entry in corner_masses:
		var key: String = String(entry.get("asset", "cave_corner"))
		if not _has_asset_scene(key):
			continue
		var tf: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(entry["yaw"]))).scaled(entry["scale"]),
			_camera_base_target + entry["offset"]
		)
		_add_asset_instance(_terrain_root, key, tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	var intrusions: Array[Dictionary] = [
		{"offset": Vector3(-board_width * 0.20, board_top + 0.04, board_height * 0.02), "yaw": 8.0, "scale": Vector3(1.24, 1.38, 1.02)},
		{"offset": Vector3(board_width * 0.16, board_top + 0.04, -board_height * 0.06), "yaw": -12.0, "scale": Vector3(1.20, 1.34, 1.02)},
	]
	for entry in intrusions:
		var tf: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(entry["yaw"]))).scaled(entry["scale"]),
			_camera_base_target + entry["offset"]
		)
		_add_asset_instance(_terrain_root, "cave_wall", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _build_asset_kit_blockers(board_top: float) -> void:
	if _state == null or not _has_asset_scene("blocker_wall"):
		return
	for y in range(_state.height):
		for x in range(_state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not _state.is_blocked(tile):
				continue
			var center: Vector3 = _tile_world_position(tile)
			var blocked_l: bool = _state.is_inside(tile + Vector2i.LEFT) and _state.is_blocked(tile + Vector2i.LEFT)
			var blocked_r: bool = _state.is_inside(tile + Vector2i.RIGHT) and _state.is_blocked(tile + Vector2i.RIGHT)
			var blocked_u: bool = _state.is_inside(tile + Vector2i.UP) and _state.is_blocked(tile + Vector2i.UP)
			var blocked_d: bool = _state.is_inside(tile + Vector2i.DOWN) and _state.is_blocked(tile + Vector2i.DOWN)
			var yaw: float = 0.0
			if blocked_u or blocked_d:
				yaw = deg_to_rad(90.0)
			var tf: Transform3D = Transform3D(
				Basis(Vector3.UP, yaw).scaled(Vector3(1.04, 1.02, 1.04)),
				center + Vector3(0.0, board_top + 0.44, 0.0)
			)
			_add_asset_instance(_terrain_root, "blocker_wall", tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
			_ground_tops[_tile_key(tile)] = board_top + 0.88

func _add_board_channels(board_width: float, board_height: float, board_top: float) -> void:
	var groove_mat: StandardMaterial3D = StandardMaterial3D.new()
	groove_mat.albedo_color = Color(0.10, 0.095, 0.10, 1.0)
	groove_mat.roughness = 0.88
	groove_mat.metallic = 0.0

	var groove_long: BoxMesh = BoxMesh.new()
	groove_long.size = Vector3(0.08, 0.004, board_height * 0.76)
	var groove_wide: BoxMesh = BoxMesh.new()
	groove_wide.size = Vector3(board_width * 0.78, 0.004, 0.08)

	var lanes_x: Array[float] = [0.0]
	for lane_x in lanes_x:
		var groove: MeshInstance3D = MeshInstance3D.new()
		groove.mesh = groove_long
		groove.position = _camera_base_target + Vector3(lane_x, board_top + 0.005, 0.0)
		groove.material_override = groove_mat
		groove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(groove)

	var lanes_z: Array[float] = [0.0]
	for lane_z in lanes_z:
		var groove: MeshInstance3D = MeshInstance3D.new()
		groove.mesh = groove_wide
		groove.position = _camera_base_target + Vector3(0.0, board_top + 0.005, lane_z)
		groove.material_override = groove_mat
		groove.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(groove)

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
		_build_owner_volume_shell(owner_id, blocks)
		_build_owner_meniscus(owner_id, blocks)
		if OOZE_ENABLE_FRAGMENTED_SURFACE_DETAILS:
			_build_owner_blob_caps(owner_id, blocks)
			_build_owner_micro_bubbles(owner_id, blocks)
			_build_owner_edge_beads(owner_id, blocks)
		_build_specialization_markers(owner_id, blocks)
		_build_heart_markers(owner_id, blocks)

	_build_world_points()
	_add_objective_glow_lights()

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
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(float(_state.width) * tile_world_size, float(_state.height) * tile_world_size)
	plane_mesh.subdivide_width = maxi(24, _state.width * 4)
	plane_mesh.subdivide_depth = maxi(24, _state.height * 4)
	quad.mesh = plane_mesh
	quad.position = _camera_base_target + Vector3(0.0, 0.068, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.material_override = _owner_pool_material(owner_id, mask_tex)
	_dynamic_root.add_child(quad)

	# Keep ooze glow material-driven to avoid one dynamic light per owner.

func _build_owner_volume_shell(owner_id: int, blocks: Array) -> void:
	if blocks.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in blocks:
		var t: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _state.is_inside(t):
			tile_set[_tile_key(t)] = t
	if tile_set.is_empty():
		return

	var edge_mesh_x: BoxMesh = BoxMesh.new()
	edge_mesh_x.size = Vector3(0.13, 0.030, 0.86)
	var edge_mesh_z: BoxMesh = BoxMesh.new()
	edge_mesh_z.size = Vector3(0.86, 0.030, 0.13)
	var edges_x: Array[Transform3D] = []
	var edges_z: Array[Transform3D] = []
	for block in blocks:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var y_off: float = top + 0.044
		var jitter: float = (_noise01(tile.x * 53 + owner_id * 11, tile.y * 31 + 17) - 0.5) * 0.025
		if not tile_set.has(_tile_key(tile + Vector2i.RIGHT)):
			edges_x.append(Transform3D(Basis(), center + Vector3(0.47, y_off + jitter, 0.0)))
		if not tile_set.has(_tile_key(tile + Vector2i.LEFT)):
			edges_x.append(Transform3D(Basis(), center + Vector3(-0.47, y_off + jitter, 0.0)))
		if not tile_set.has(_tile_key(tile + Vector2i.DOWN)):
			edges_z.append(Transform3D(Basis(), center + Vector3(0.0, y_off + jitter, 0.47)))
		if not tile_set.has(_tile_key(tile + Vector2i.UP)):
			edges_z.append(Transform3D(Basis(), center + Vector3(0.0, y_off + jitter, -0.47)))

	if edges_x.is_empty() and edges_z.is_empty():
		return

	var tint: Color = _owner_ooze_tint(owner_id)
	var shell_mat: StandardMaterial3D = StandardMaterial3D.new()
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell_mat.albedo_color = Color(tint.r * 0.84, tint.g * 0.84, tint.b * 0.84, 0.44)
	shell_mat.roughness = 0.12
	shell_mat.metallic = 0.0
	shell_mat.metallic_specular = 0.74
	shell_mat.clearcoat_enabled = true
	shell_mat.clearcoat = 0.70
	shell_mat.clearcoat_roughness = 0.16
	shell_mat.emission_enabled = true
	shell_mat.emission = tint * 0.14
	shell_mat.emission_energy_multiplier = 0.05
	if not edges_x.is_empty():
		_dynamic_root.add_child(_make_multimesh_instance(edge_mesh_x, edges_x, [], shell_mat, false))
	if not edges_z.is_empty():
		_dynamic_root.add_child(_make_multimesh_instance(edge_mesh_z, edges_z, [], shell_mat, false))

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
	quad.position = _camera_base_target + Vector3(0.0, 0.074, 0.0)
	quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var meniscus: ShaderMaterial = _owner_pool_material(owner_id, mask_tex).duplicate(true)
	meniscus.set_shader_parameter("pulse_speed", 0.20)
	meniscus.set_shader_parameter("bubble_strength", 0.0015)
	meniscus.set_shader_parameter("emission_strength", 0.008)
	meniscus.set_shader_parameter("detail_scale", 5.6)
	meniscus.set_shader_parameter("body_thickness", 0.012)
	meniscus.set_shader_parameter("lip_thickness", 0.034)
	meniscus.set_shader_parameter("flow_scale", 1.30)
	meniscus.set_shader_parameter("flow_speed", 0.008)
	meniscus.set_shader_parameter("flow_normal_strength", 0.28)
	meniscus.set_shader_parameter("edge_darkening_strength", 0.12)
	meniscus.set_shader_parameter("contact_darkening_strength", 0.10)
	meniscus.set_shader_parameter("clearcoat_strength", 0.48)
	meniscus.set_shader_parameter("specular_strength", 0.42)
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
		var wall_adjacent: bool = _tile_touches_blocked_neighbor(tile)
		var jitter_scale: float = 0.03 if wall_adjacent else 0.08
		var jx: int = int(round((_noise01(tile.x * 23 + 7, tile.y * 19 + 11) - 0.5) * float(mask_scale) * jitter_scale))
		var jy: int = int(round((_noise01(tile.x * 31 + 3, tile.y * 29 + 17) - 0.5) * float(mask_scale) * jitter_scale))
		var local_radius: int = radius + int(round((_noise01(tile.x * 41 + 5, tile.y * 37 + 13) - 0.5) * 0.9))
		if wall_adjacent:
			local_radius -= maxi(1, int(round(float(mask_scale) * 0.28)))
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
	_carve_blocked_tiles_from_mask(image, mask_scale)
	_carve_wall_contact_moat(image, mask_scale)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	return texture

func _tile_touches_blocked_neighbor(tile: Vector2i) -> bool:
	if _state == null:
		return false
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = tile + step
		if _state.is_inside(neighbor) and _state.is_blocked(neighbor):
			return true
	return false

func _carve_blocked_tiles_from_mask(image: Image, mask_scale: int) -> void:
	if _state == null:
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	var guard_band: int = maxi(0, int(round(float(mask_scale) * 0.05)))
	for y in range(_state.height):
		for x in range(_state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not _state.is_blocked(tile):
				continue
			var px0: int = x * mask_scale + guard_band
			var py0: int = y * mask_scale + guard_band
			var px1: int = (x + 1) * mask_scale - 1 - guard_band
			var py1: int = (y + 1) * mask_scale - 1 - guard_band
			px0 = clampi(px0, 0, w - 1)
			px1 = clampi(px1, 0, w - 1)
			py0 = clampi(py0, 0, h - 1)
			py1 = clampi(py1, 0, h - 1)
			for py in range(py0, py1 + 1):
				for px in range(px0, px1 + 1):
					image.set_pixel(px, py, Color(1.0, 1.0, 1.0, 0.0))

func _carve_wall_contact_moat(image: Image, mask_scale: int) -> void:
	if _state == null:
		return
	var w: int = image.get_width()
	var h: int = image.get_height()
	var pad: int = maxi(1, int(round(float(mask_scale) * 0.08)))
	for y in range(_state.height):
		for x in range(_state.width):
			var tile: Vector2i = Vector2i(x, y)
			if not _state.is_blocked(tile):
				continue
			var px0: int = x * mask_scale - pad
			var py0: int = y * mask_scale - pad
			var px1: int = (x + 1) * mask_scale - 1 + pad
			var py1: int = (y + 1) * mask_scale - 1 + pad
			px0 = clampi(px0, 0, w - 1)
			px1 = clampi(px1, 0, w - 1)
			py0 = clampi(py0, 0, h - 1)
			py1 = clampi(py1, 0, h - 1)
			for py in range(py0, py1 + 1):
				for px in range(px0, px1 + 1):
					image.set_pixel(px, py, Color(1.0, 1.0, 1.0, 0.0))

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
	var base_mesh: SphereMesh = SphereMesh.new()
	base_mesh.radius = 0.44
	base_mesh.height = 0.46
	base_mesh.radial_segments = 16
	base_mesh.rings = 10
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.16
	core_mesh.height = 0.24
	core_mesh.radial_segments = 14
	core_mesh.rings = 8
	var lobe_mesh: SphereMesh = SphereMesh.new()
	lobe_mesh.radius = 0.18
	lobe_mesh.height = 0.22
	lobe_mesh.radial_segments = 12
	lobe_mesh.rings = 7
	var tip_mesh: CylinderMesh = CylinderMesh.new()
	tip_mesh.top_radius = 0.02
	tip_mesh.bottom_radius = 0.12
	tip_mesh.height = 0.26
	tip_mesh.radial_segments = 10
	var tendril_mesh: CylinderMesh = CylinderMesh.new()
	tendril_mesh.top_radius = 0.054
	tendril_mesh.bottom_radius = 0.092
	tendril_mesh.height = 0.58
	tendril_mesh.radial_segments = 10
	var use_heart_asset: bool = _has_asset_scene("heart_crystal")

	var base_transforms: Array[Transform3D] = []
	var core_transforms: Array[Transform3D] = []
	var lobe_transforms: Array[Transform3D] = []
	var tip_transforms: Array[Transform3D] = []
	var tendril_transforms: Array[Transform3D] = []
	var heart_asset_transforms: Array[Transform3D] = []
	for block in blocks:
		if not bool(block.get("is_heart", false)):
			continue
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var top: float = _tile_ground_top(tile)
		var center: Vector3 = _tile_world_position(tile)
		var dir: Vector3 = _tile_attack_direction(owner_id, tile)
		var yaw: float = atan2(dir.x, dir.z)
		var spread: float = 0.36
		var mound_scale: float = 1.08 + _noise01(tile.x * 37 + owner_id * 5, tile.y * 29 + owner_id * 11) * 0.34
		var mound_basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(1.12, 0.74, 1.04) * mound_scale)
		base_transforms.append(Transform3D(mound_basis, center + Vector3(0.0, top + 0.12, 0.0)))

		var side: Vector3 = Vector3(-dir.z, 0.0, dir.x).normalized()
		if use_heart_asset:
			var hero_scale: float = 1.02 + _noise01(tile.x * 41 + owner_id * 19, tile.y * 47 + owner_id * 7) * 0.24
			var hero_basis: Basis = Basis(Vector3.UP, yaw + 0.18).scaled(Vector3.ONE * hero_scale)
			heart_asset_transforms.append(Transform3D(hero_basis, center + dir * 0.02 + Vector3(0.0, top + 0.34, 0.0)))
		else:
			var core_scale: float = 1.00 + _noise01(tile.x * 41 + owner_id * 19, tile.y * 47 + owner_id * 7) * 0.20
			var core_basis: Basis = Basis(Vector3.UP, yaw + 0.2).scaled(Vector3(1.00, 1.12, 1.00) * core_scale)
			core_transforms.append(Transform3D(core_basis, center + Vector3(0.0, top + 0.40, 0.0)))
			var lobe_scale: float = 0.96 + _noise01(tile.x * 53 + owner_id * 17, tile.y * 59 + owner_id * 13) * 0.18
			var lobe_a_pos: Vector3 = center + side * 0.11 + dir * 0.03 + Vector3(0.0, top + 0.38, 0.0)
			var lobe_b_pos: Vector3 = center - side * 0.11 + dir * 0.03 + Vector3(0.0, top + 0.38, 0.0)
			lobe_transforms.append(Transform3D(Basis(Vector3.UP, yaw + 0.1).scaled(Vector3(1.0, 1.0, 1.0) * lobe_scale), lobe_a_pos))
			lobe_transforms.append(Transform3D(Basis(Vector3.UP, yaw - 0.1).scaled(Vector3(1.0, 1.0, 1.0) * lobe_scale), lobe_b_pos))
			var tip_basis: Basis = Basis(Vector3.UP, yaw + PI) * Basis(Vector3.RIGHT, deg_to_rad(-10.0))
			tip_transforms.append(Transform3D(tip_basis, center + dir * 0.02 + Vector3(0.0, top + 0.30, 0.0)))

		for i in range(6):
			var t: float = float(i) / 6.0
			var angle: float = t * TAU + _noise01(tile.x * 13 + i * 17, tile.y * 19 + i * 23) * 0.35
			var radial: Vector3 = Vector3(cos(angle), 0.0, sin(angle)).normalized()
			var bias: float = 0.22 + maxf(0.0, radial.dot(dir)) * 0.20
			var tendril_pos: Vector3 = center + radial * (spread + bias * 0.30) + Vector3(0.0, top + 0.18, 0.0)
			var tendril_yaw: float = atan2(radial.x, radial.z)
			var lean: float = deg_to_rad(20.0 + 16.0 * maxf(0.0, radial.dot(side)))
			var tendril_scale: float = 0.76 + _noise01(tile.x * 31 + i * 3, tile.y * 17 + i * 7) * 0.34
			var tendril_basis: Basis = Basis(Vector3.UP, tendril_yaw) * Basis(Vector3.RIGHT, -lean)
			tendril_basis = tendril_basis.scaled(Vector3(1.0, 1.0 + tendril_scale * 0.22, 1.0))
			tendril_transforms.append(Transform3D(tendril_basis, tendril_pos))

	if base_transforms.is_empty():
		return
	var owner_tint: Color = _owner_ooze_tint(owner_id)
	var heart_tint: Color = owner_tint.lerp(_owner_tint(owner_id), 0.18).lerp(Color(1.0, 0.92, 0.96, 1.0), 0.04)
	var heart_mat: StandardMaterial3D = _ooze_growth_material(owner_tint, heart_tint, "heart", false)
	var heart_core_mat: StandardMaterial3D = _ooze_growth_material(owner_tint, heart_tint, "heart", true)
	var lobe_mat: StandardMaterial3D = _ooze_growth_material(owner_tint, heart_tint, "heart", true)
	_dynamic_root.add_child(_make_multimesh_instance(base_mesh, base_transforms, [], heart_mat, true))
	_dynamic_root.add_child(_make_multimesh_instance(tendril_mesh, tendril_transforms, [], heart_mat, true))
	if use_heart_asset and not heart_asset_transforms.is_empty():
		for tf in heart_asset_transforms:
			_add_asset_instance(
				_dynamic_root,
				"heart_crystal",
				tf,
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
				heart_core_mat
			)
	else:
		_dynamic_root.add_child(_make_multimesh_instance(core_mesh, core_transforms, [], heart_core_mat, false))
		_dynamic_root.add_child(_make_multimesh_instance(lobe_mesh, lobe_transforms, [], lobe_mat, false))
		_dynamic_root.add_child(_make_multimesh_instance(tip_mesh, tip_transforms, [], lobe_mat, false))

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
		_build_role_growth_surface(owner_id, String(role), entries)
		_build_role_ooze_growth(owner_id, String(role), entries)

func _build_role_growth_surface(owner_id: int, role: String, entries: Array) -> void:
	if entries.is_empty():
		return
	var mound_mesh: SphereMesh = SphereMesh.new()
	mound_mesh.radius = 0.26
	mound_mesh.height = 0.14
	mound_mesh.radial_segments = 12
	mound_mesh.rings = 6
	var transforms: Array[Transform3D] = []
	for block in entries:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var top: float = _tile_ground_top(tile)
		var center: Vector3 = _tile_world_position(tile)
		var rot: float = _noise01(tile.x * 31 + owner_id * 17, tile.y * 37 + owner_id * 11) * TAU
		var scale: Vector3 = Vector3(1.06, 0.72, 1.00)
		match role:
			"melee":
				scale = Vector3(1.10, 0.76, 0.96)
			"ranged":
				scale = Vector3(1.00, 0.68, 1.00)
			"defense":
				scale = Vector3(1.12, 0.82, 1.12)
			"gather":
				scale = Vector3(1.00, 0.66, 1.00)
		var n: float = 0.92 + _noise01(tile.x * 13 + 7, tile.y * 19 + 5) * 0.22
		transforms.append(Transform3D(Basis(Vector3.UP, rot).scaled(scale * n), center + Vector3(0.0, top + 0.062, 0.0)))
	if transforms.is_empty():
		return
	var base_tint: Color = _owner_ooze_tint(owner_id)
	var role_tint: Color = _role_tint(role)
	var mat: StandardMaterial3D = _ooze_growth_material(base_tint, role_tint, role, false)
	mat.emission_energy_multiplier *= 0.72
	mat.roughness = clampf(mat.roughness + 0.08, 0.28, 0.72)
	_dynamic_root.add_child(_make_multimesh_instance(mound_mesh, transforms, [], mat, true))

func _build_role_ooze_growth(owner_id: int, role: String, entries: Array) -> void:
	if entries.is_empty():
		return
	var owner_tint: Color = _owner_ooze_tint(owner_id)
	var role_tint: Color = _role_tint(role)
	var core_mat: StandardMaterial3D = _ooze_growth_material(owner_tint, role_tint, role, false)
	var accent_mat: StandardMaterial3D = _ooze_growth_material(owner_tint, role_tint, role, true)

	var base_mesh: SphereMesh = SphereMesh.new()
	base_mesh.radius = 0.26
	base_mesh.height = 0.20
	base_mesh.radial_segments = 14
	base_mesh.rings = 7

	var accent_a: Mesh = null
	var accent_b: Mesh = null
	match role:
		"melee":
			base_mesh.radius = 0.28
			base_mesh.height = 0.22
			var spike: PrismMesh = PrismMesh.new()
			spike.left_to_right = 0.56
			spike.size = Vector3(0.16, 0.42, 0.14)
			accent_a = spike
		"ranged":
			base_mesh.radius = 0.26
			base_mesh.height = 0.20
			var bulb: SphereMesh = SphereMesh.new()
			bulb.radius = 0.14
			bulb.height = 0.20
			bulb.radial_segments = 12
			bulb.rings = 7
			accent_a = bulb
			var nozzle: CylinderMesh = CylinderMesh.new()
			nozzle.top_radius = 0.030
			nozzle.bottom_radius = 0.054
			nozzle.height = 0.18
			nozzle.radial_segments = 8
			accent_b = nozzle
		"defense":
			base_mesh.radius = 0.30
			base_mesh.height = 0.24
			var shell: CapsuleMesh = CapsuleMesh.new()
			shell.radius = 0.13
			shell.height = 0.30
			shell.radial_segments = 10
			shell.rings = 5
			accent_a = shell
		"gather":
			base_mesh.radius = 0.24
			base_mesh.height = 0.18
			var nodule: SphereMesh = SphereMesh.new()
			nodule.radius = 0.11
			nodule.height = 0.16
			nodule.radial_segments = 10
			nodule.rings = 6
			accent_a = nodule

	var base_transforms: Array[Transform3D] = []
	var accent_a_transforms: Array[Transform3D] = []
	var accent_b_transforms: Array[Transform3D] = []
	for block in entries:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var top: float = _tile_ground_top(tile)
		var center: Vector3 = _tile_world_position(tile)
		var direction: Vector3 = _tile_attack_direction(owner_id, tile)
		var yaw: float = atan2(direction.x, direction.z)
		var scale_noise: float = 0.86 + _noise01(tile.x * 17 + owner_id * 13, tile.y * 31 + owner_id * 7) * 0.30
		var base_basis: Basis = Basis(Vector3.UP, yaw + _noise01(tile.x * 13 + 2, tile.y * 11 + 5) * 0.36).scaled(Vector3.ONE * scale_noise)
		base_transforms.append(Transform3D(base_basis, center + Vector3(0.0, top + 0.078, 0.0)))
		var accent_gate: float = _noise01(tile.x * 43 + owner_id * 19, tile.y * 47 + owner_id * 23)

		match role:
			"melee":
				var side: Vector3 = Vector3(-direction.z, 0.0, direction.x).normalized()
				for i in range(2):
					var lane: float = -0.08 if i == 0 else 0.08
					var spike_pos: Vector3 = center + direction * 0.08 + side * lane + Vector3(0.0, top + 0.17, 0.0)
					var spike_basis: Basis = Basis(Vector3.UP, yaw + lane * 1.7) * Basis(Vector3.RIGHT, deg_to_rad(-18.0))
					var spike_scale: float = 0.90 + _noise01(tile.x * 29 + i * 7, tile.y * 37 + i * 5) * 0.30
					accent_a_transforms.append(Transform3D(spike_basis.scaled(Vector3.ONE * spike_scale), spike_pos))
			"ranged":
				var bulb_pos: Vector3 = center + Vector3(0.0, top + 0.17, 0.0)
				var bulb_scale: float = 0.84 + _noise01(tile.x * 11 + 9, tile.y * 13 + 3) * 0.28
				accent_a_transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * bulb_scale), bulb_pos))
				var nozzle_pos: Vector3 = center + direction * 0.08 + Vector3(0.0, top + 0.21, 0.0)
				var nozzle_basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-14.0))
				accent_b_transforms.append(Transform3D(nozzle_basis, nozzle_pos))
			"defense":
				var shell_basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(1.06, 1.16, 1.06))
				accent_a_transforms.append(Transform3D(shell_basis, center + Vector3(0.0, top + 0.18, 0.0)))
			"gather":
				if accent_gate < 0.45:
					continue
				for i in range(3):
					var a: float = float(i) * (TAU / 3.0) + _noise01(tile.x * 23 + i * 3, tile.y * 19 + i * 5) * 0.32
					var p: Vector3 = center + Vector3(cos(a) * 0.12, top + 0.16, sin(a) * 0.12)
					var n_scale: float = 0.72 + _noise01(tile.x * 41 + i * 11, tile.y * 43 + i * 13) * 0.24
					accent_a_transforms.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * n_scale), p))

	if not base_transforms.is_empty():
		_dynamic_root.add_child(_make_multimesh_instance(base_mesh, base_transforms, [], core_mat, true))
	if accent_a != null and not accent_a_transforms.is_empty():
		_dynamic_root.add_child(_make_multimesh_instance(accent_a, accent_a_transforms, [], accent_mat, true))
	if accent_b != null and not accent_b_transforms.is_empty():
		_dynamic_root.add_child(_make_multimesh_instance(accent_b, accent_b_transforms, [], accent_mat, true))

func _tile_attack_direction(owner_id: int, tile: Vector2i) -> Vector3:
	var fallback: Vector3 = Vector3.RIGHT if owner_id == GameState.PLAYER_ID else Vector3.LEFT
	if _state == null:
		return fallback
	var src: Vector3 = _tile_world_position(tile)
	var best_dist_sq: float = INF
	var best_dir: Vector3 = fallback
	for block in _state.blocks.values():
		if not bool(block.get("is_heart", false)):
			continue
		if int(block.get("owner", owner_id)) == owner_id:
			continue
		var other: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(other):
			continue
		var delta: Vector3 = _tile_world_position(other) - src
		delta.y = 0.0
		var dist_sq: float = delta.length_squared()
		if dist_sq <= 0.0001 or dist_sq >= best_dist_sq:
			continue
		best_dist_sq = dist_sq
		best_dir = delta.normalized()
	return best_dir

func _build_role_marker_layer(owner_id: int, role: String, entries: Array) -> void:
	var owner_tint: Color = _owner_tint(owner_id)
	var role_tint: Color = _role_tint(role)
	var crest_tint: Color = role_tint.lerp(owner_tint, 0.52).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.14)
	var base_y_offset: float = 0.088
	var crest_y_offset: float = 0.188
	if role == "defense":
		base_y_offset = 0.082
		crest_y_offset = 0.152
	elif role == "melee":
		base_y_offset = 0.094
		crest_y_offset = 0.202
	elif role == "gather":
		base_y_offset = 0.086
		crest_y_offset = 0.168
	elif role == "ranged":
		base_y_offset = 0.088
		crest_y_offset = 0.196

	var base_mesh: Mesh = _role_base_mesh(role)
	var base_transforms: Array[Transform3D] = []

	var crest_mesh: Mesh = _role_crest_mesh(role)
	var crest_transforms: Array[Transform3D] = []

	for block in entries:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		var top: float = _tile_ground_top(tile)
		var center: Vector3 = _tile_world_position(tile)
		var rot: float = _noise01(tile.x * 53 + owner_id * 7, tile.y * 47 + owner_id * 13) * TAU
		var s: float = 1.00 + _noise01(tile.x * 17 + owner_id * 3, tile.y * 29 + owner_id * 5) * 0.28
		var base_basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3.ONE * (0.74 + (s - 1.0) * 0.32))
		var crest_basis: Basis = Basis(Vector3.UP, rot + 0.24).scaled(Vector3.ONE * (0.74 + (s - 1.0) * 0.28))
		base_transforms.append(Transform3D(base_basis, center + Vector3(0.0, top + base_y_offset, 0.0)))
		crest_transforms.append(Transform3D(crest_basis, center + Vector3(0.0, top + crest_y_offset, 0.0)))

	var base_material: StandardMaterial3D = _role_base_material(role, role_tint, owner_tint)
	_dynamic_root.add_child(_make_multimesh_instance(base_mesh, base_transforms, [], base_material, true))

	var crest_material: ShaderMaterial = ShaderMaterial.new()
	var crest_shader: Shader = Shader.new()
	crest_shader.code = ROLE_CREST_SHADER_CODE
	crest_material.shader = crest_shader
	crest_material.set_shader_parameter("crest_color", crest_tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.30))
	crest_material.set_shader_parameter("crest_emission", crest_tint.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.20))
	crest_material.set_shader_parameter("crest_roughness", 0.30 if role == "ranged" else (0.40 if role == "gather" else (0.52 if role == "melee" else 0.60)))
	crest_material.set_shader_parameter("pulse_speed", 1.9 if role == "ranged" else (1.6 if role == "gather" else 1.4))
	crest_material.set_shader_parameter("pulse_amp", 0.030 if role == "gather" else (0.024 if role == "ranged" else 0.018))
	_dynamic_root.add_child(_make_multimesh_instance(crest_mesh, crest_transforms, [], crest_material, true))

func _build_role_surface_overlay(owner_id: int, role: String, entries: Array) -> void:
	if entries.is_empty():
		return
	var tile_set: Dictionary = {}
	for block in entries:
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _state.is_inside(tile):
			tile_set[_tile_key(tile)] = tile
	if tile_set.is_empty():
		return
	var mask_tex: Texture2D = _build_owner_mask_texture(tile_set)
	if mask_tex == null:
		return
	var quad: MeshInstance3D = MeshInstance3D.new()
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(float(_state.width) * tile_world_size, float(_state.height) * tile_world_size)
	quad.mesh = quad_mesh
	quad.position = _camera_base_target + Vector3(0.0, 0.079, 0.0)
	quad.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: ShaderMaterial = _owner_pool_material(owner_id, mask_tex).duplicate(true)
	var role_mix: float = 0.40
	if role == "defense":
		role_mix = 0.30
	elif role == "gather":
		role_mix = 0.46
	elif role == "ranged":
		role_mix = 0.36
	var tint: Color = _owner_ooze_tint(owner_id).lerp(_role_tint(role), role_mix)
	mat.set_shader_parameter("owner_color", tint)
	mat.set_shader_parameter("pulse_speed", 0.30 if role == "ranged" else 0.24)
	mat.set_shader_parameter("bubble_strength", 0.0010)
	mat.set_shader_parameter("emission_strength", 0.013 if role == "ranged" else (0.011 if role == "gather" else 0.009))
	mat.set_shader_parameter("detail_scale", 6.0)
	mat.set_shader_parameter("body_thickness", 0.0065)
	mat.set_shader_parameter("lip_thickness", 0.011)
	mat.set_shader_parameter("flow_scale", 1.42)
	mat.set_shader_parameter("flow_speed", 0.013 if role == "melee" else 0.010)
	mat.set_shader_parameter("flow_normal_strength", 0.31)
	mat.set_shader_parameter("clearcoat_strength", 0.56)
	mat.set_shader_parameter("specular_strength", 0.50)
	quad.material_override = mat
	_dynamic_root.add_child(quad)

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

func _add_objective_glow_lights() -> void:
	if _state == null:
		return
	var heart_lights_added: int = 0
	for block in _state.blocks.values():
		if not bool(block.get("is_heart", false)):
			continue
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var owner_id: int = int(block.get("owner", GameState.PLAYER_ID))
		var glow_color: Color = _owner_tint(owner_id).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.02)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = _tile_world_position(tile) + Vector3(0.0, _tile_ground_top(tile) + 0.72, 0.0)
		light.light_color = glow_color
		light.light_energy = 0.72
		light.set_meta("base_energy", 0.72)
		light.omni_range = 3.6
		light.shadow_enabled = false
		_dynamic_root.add_child(light)
		_point_lights.append(light)
		heart_lights_added += 1
		if heart_lights_added >= 4:
			break
	if _state.is_inside(_state.entrance_tile):
		var entry_light: OmniLight3D = OmniLight3D.new()
		entry_light.position = _tile_world_position(_state.entrance_tile) + Vector3(0.0, _tile_ground_top(_state.entrance_tile) + 0.58, 0.0)
		entry_light.light_color = Color(0.22, 0.55, 0.86, 1.0)
		entry_light.light_energy = 0.68
		entry_light.set_meta("base_energy", 0.68)
		entry_light.omni_range = 3.2
		entry_light.shadow_enabled = false
		_dynamic_root.add_child(entry_light)
		_point_lights.append(entry_light)
	if _state.door_hp > 0 and _state.is_inside(_state.door_tile):
		var door_light: OmniLight3D = OmniLight3D.new()
		door_light.position = _tile_world_position(_state.door_tile) + Vector3(0.0, _tile_ground_top(_state.door_tile) + 0.64, 0.0)
		door_light.light_color = Color(0.86, 0.52, 0.20, 1.0)
		door_light.light_energy = 0.84
		door_light.set_meta("base_energy", 0.84)
		door_light.omni_range = 3.4
		door_light.shadow_enabled = false
		_dynamic_root.add_child(door_light)
		_point_lights.append(door_light)

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
	var tint: Color = Color(0.40, 0.74, 0.90, 1.0) if entrance else Color(0.84, 0.62, 0.34, 1.0)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = tile_world_size * 0.20
	ring_mesh.outer_radius = tile_world_size * 0.34
	ring_mesh.rings = 14
	ring_mesh.ring_segments = 28
	ring.mesh = ring_mesh
	ring.position = center + Vector3(0.0, top + 0.055, 0.0)
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = tint * 0.70
	ring_mat.roughness = 0.24
	ring_mat.metallic = 0.0
	ring_mat.emission_enabled = true
	ring_mat.emission = tint
	ring_mat.emission_energy_multiplier = 0.24
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dynamic_root.add_child(ring)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	var beacon_mesh: SphereMesh = SphereMesh.new()
	beacon_mesh.radius = 0.11
	beacon_mesh.height = 0.16
	beacon_mesh.radial_segments = 10
	beacon_mesh.rings = 6
	beacon.mesh = beacon_mesh
	beacon.position = center + Vector3(0.0, top + 0.09, 0.0)
	var beacon_mat: StandardMaterial3D = StandardMaterial3D.new()
	beacon_mat.albedo_color = tint * 0.78
	beacon_mat.roughness = 0.20
	beacon_mat.metallic = 0.0
	beacon_mat.emission_enabled = true
	beacon_mat.emission = tint
	beacon_mat.emission_energy_multiplier = 0.18
	beacon.material_override = beacon_mat
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dynamic_root.add_child(beacon)

func _add_resource_marker(tile: Vector2i, kind: String, consumed: bool) -> void:
	var top: float = _tile_ground_top(tile)
	var center: Vector3 = _tile_world_position(tile)
	if not consumed and kind == "scroll":
		var scroll_disc: MeshInstance3D = MeshInstance3D.new()
		var disc_mesh: CylinderMesh = CylinderMesh.new()
		disc_mesh.top_radius = 0.16
		disc_mesh.bottom_radius = 0.16
		disc_mesh.height = 0.040
		disc_mesh.radial_segments = 16
		scroll_disc.mesh = disc_mesh
		scroll_disc.position = center + Vector3(0.0, top + 0.055, 0.0)
		var scroll_mat: StandardMaterial3D = StandardMaterial3D.new()
		scroll_mat.albedo_color = Color(0.82, 0.74, 0.58, 1.0)
		scroll_mat.roughness = 0.36
		scroll_mat.metallic = 0.0
		scroll_mat.emission_enabled = true
		scroll_mat.emission = Color(0.66, 0.56, 0.36, 1.0)
		scroll_mat.emission_energy_multiplier = 0.10
		scroll_disc.material_override = scroll_mat
		scroll_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dynamic_root.add_child(scroll_disc)
		return
	var marker: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if consumed:
		var spent_mesh: SphereMesh = SphereMesh.new()
		spent_mesh.radius = 0.06
		spent_mesh.height = 0.09
		spent_mesh.radial_segments = 10
		spent_mesh.rings = 6
		marker.mesh = spent_mesh
		marker.position = center + Vector3(0.0, top + 0.035, 0.0)
		mat.albedo_color = Color(0.20, 0.20, 0.20, 1.0)
		mat.roughness = 0.92
	elif kind == "rat":
		var pebble: SphereMesh = SphereMesh.new()
		pebble.radius = 0.11
		pebble.height = 0.16
		pebble.radial_segments = 10
		pebble.rings = 6
		marker.mesh = pebble
		marker.position = center + Vector3(0.0, top + 0.08, 0.0)
		mat.albedo_color = Color(0.62, 0.58, 0.52, 1.0)
		mat.roughness = 0.72
	else:
		var gem_mesh: PrismMesh = PrismMesh.new()
		gem_mesh.left_to_right = 0.52
		gem_mesh.size = Vector3(0.15, 0.24, 0.15)
		marker.mesh = gem_mesh
		marker.position = center + Vector3(0.0, top + 0.11, 0.0)
		mat.albedo_color = Color(0.48, 0.96, 0.86, 1.0)
		mat.roughness = 0.34
		mat.emission_enabled = true
		mat.emission = Color(0.34, 1.0, 0.86, 1.0)
		mat.emission_energy_multiplier = 0.30
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dynamic_root.add_child(marker)

func _add_floor_scars() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var scar_mesh: BoxMesh = BoxMesh.new()
	scar_mesh.size = Vector3(1.02, 0.012, 0.13)
	var scar_transforms: Array[Transform3D] = []
	var used_tiles: Dictionary = {}
	var scar_count: int = maxi(6, int((_state.width + _state.height) * 0.26))
	var attempts: int = scar_count * 4
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
		var stretch: float = 0.92 + _noise01(idx * 61 + 7, idx * 37 + 2) * 1.02
		var width: float = 0.76 + _noise01(idx * 83 + 11, idx * 89 + 13) * 0.30
		var scar_basis: Basis = Basis(Vector3.UP, rot).scaled(Vector3(stretch, 1.0, width))
		scar_transforms.append(Transform3D(scar_basis, center + Vector3(0.0, top + 0.004, 0.0)))
	if scar_transforms.is_empty():
		return
	var scar_mat: StandardMaterial3D = StandardMaterial3D.new()
	scar_mat.albedo_color = Color(0.07, 0.065, 0.06, 0.30)
	scar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	scar_mat.roughness = 0.96
	scar_mat.metallic = 0.0
	_terrain_root.add_child(_make_multimesh_instance(scar_mesh, scar_transforms, [], scar_mat, false))

func _add_cobble_relief() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var cobble_mesh: SphereMesh = SphereMesh.new()
	cobble_mesh.radius = 0.08
	cobble_mesh.height = 0.10
	cobble_mesh.radial_segments = 8
	cobble_mesh.rings = 5
	var transforms: Array[Transform3D] = []
	var used_tiles: Dictionary = {}
	var cobble_count: int = maxi(4, int((_state.width + _state.height) * 0.10))
	var attempts: int = cobble_count * 6
	var center_tile: Vector2 = Vector2(float(_state.width) * 0.5, float(_state.height) * 0.5)
	var center_keepout: float = maxf(2.0, minf(float(_state.width), float(_state.height)) * 0.20)
	for idx in range(attempts):
		if transforms.size() >= cobble_count:
			break
		var tx: int = int(floor(_noise01(idx * 31 + 3, idx * 17 + 19) * float(_state.width)))
		var ty: int = int(floor(_noise01(idx * 47 + 7, idx * 13 + 11) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(tx, 0, _state.width - 1), clampi(ty, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		if Vector2(float(tile.x), float(tile.y)).distance_to(center_tile) < center_keepout:
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
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var patch_mesh: QuadMesh = QuadMesh.new()
	patch_mesh.size = Vector2(0.95, 0.72)
	var patch_transforms: Array[Transform3D] = []
	var patch_count: int = maxi(6, int((_state.width + _state.height) * 0.16))
	var used_tiles: Dictionary = {}
	var attempts: int = patch_count * 6
	var center_tile: Vector2 = Vector2(float(_state.width) * 0.5, float(_state.height) * 0.5)
	var center_keepout: float = maxf(2.4, minf(float(_state.width), float(_state.height)) * 0.24)
	for idx in range(attempts):
		if patch_transforms.size() >= patch_count:
			break
		var tx: int = int(floor(_noise01(idx * 43 + 7, idx * 19 + 13) * float(_state.width)))
		var ty: int = int(floor(_noise01(idx * 29 + 11, idx * 31 + 23) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(tx, 0, _state.width - 1), clampi(ty, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		if Vector2(float(tile.x), float(tile.y)).distance_to(center_tile) < center_keepout:
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
	patch_mat.albedo_color = Color(0.14, 0.16, 0.17, 0.07)
	patch_mat.roughness = 0.18
	patch_mat.metallic = 0.0
	patch_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	patch_mat.metallic_specular = 0.52
	_terrain_root.add_child(_make_multimesh_instance(patch_mesh, patch_transforms, [], patch_mat, false))

func _add_side_door_leaf(pos: Vector3, yaw_degrees: float) -> void:
	return

func _add_cave_doors() -> void:
	if _state == null:
		return
	# Door layout lock:
	# left wall -> open gateway from previous chamber
	# right wall -> closed gateway to deeper cave (opens when door_hp <= 0)
	var left_pos: Vector3 = Vector3(_board_min.x - tile_world_size * 1.45, 0.0, _camera_base_target.z - tile_world_size * 0.6)
	var right_pos: Vector3 = Vector3(_board_max.x + tile_world_size * 1.45, 0.0, _camera_base_target.z + tile_world_size * 0.6)
	var right_is_closed: bool = _state.door_hp > 0

	if not _has_asset_scene("door_arch"):
		return
	var left_tf: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90.0)).scaled(Vector3(1.10, 1.22, 1.06)),
		left_pos + Vector3(0.0, 0.06, 0.0)
	)
	_add_asset_instance(_terrain_root, "door_arch", left_tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	var right_scale: Vector3 = Vector3(1.10, 1.26, 1.06) if right_is_closed else Vector3(1.02, 1.14, 0.98)
	var right_tf: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-90.0)).scaled(right_scale),
		right_pos + Vector3(0.0, 0.06, 0.0)
	)
	_add_asset_instance(_terrain_root, "door_arch", right_tf, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

	var left_door_glow: OmniLight3D = OmniLight3D.new()
	left_door_glow.position = left_pos + Vector3(0.0, 0.94, 0.0)
	left_door_glow.light_color = Color(0.24, 0.54, 0.84, 1.0)
	left_door_glow.light_energy = 0.42
	left_door_glow.omni_range = 2.8
	left_door_glow.shadow_enabled = false
	_terrain_root.add_child(left_door_glow)

	var right_door_glow: OmniLight3D = OmniLight3D.new()
	right_door_glow.position = right_pos + Vector3(0.0, 0.94, 0.0)
	right_door_glow.light_color = Color(0.84, 0.50, 0.22, 1.0)
	right_door_glow.light_energy = 0.56 if right_is_closed else 0.34
	right_door_glow.omni_range = 3.2
	right_door_glow.shadow_enabled = false
	_terrain_root.add_child(right_door_glow)

func _add_ground_boulders() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
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
	var rock_count: int = maxi(6, int((_state.width + _state.height) * 0.24))
	var attempts: int = rock_count * 6
	for idx in range(attempts):
		if rock_transforms_a.size() + rock_transforms_b.size() >= rock_count:
			break
		var sx: int = int(floor(_noise01(idx * 23 + 7, idx * 13 + 3) * float(_state.width)))
		var sy: int = int(floor(_noise01(idx * 37 + 11, idx * 17 + 9) * float(_state.height)))
		var tile: Vector2i = Vector2i(clampi(sx, 0, _state.width - 1), clampi(sy, 0, _state.height - 1))
		if _state.is_blocked(tile):
			continue
		var edge_dist: int = mini(mini(tile.x, _state.width - 1 - tile.x), mini(tile.y, _state.height - 1 - tile.y))
		if edge_dist > 2:
			continue
		if _is_near_used_tile(tile, used_tiles, 1):
			continue
		used_tiles[_tile_key(tile)] = true
		var center: Vector3 = _tile_world_position(tile)
		var top: float = _tile_ground_top(tile)
		var rx: float = (_noise01(idx * 41 + 13, idx * 31 + 17) - 0.5) * 0.58
		var rz: float = (_noise01(idx * 19 + 2, idx * 59 + 5) - 0.5) * 0.58
		var scale_v: float = 0.28 + _noise01(idx * 61 + 21, idx * 47 + 27) * 0.58
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
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var positions: Array[Vector3] = [
		Vector3(_board_min.x - 1.4, 0.0, _board_min.z - 1.1),
		Vector3(_board_max.x + 1.3, 0.0, _board_min.z - 1.0),
	]
	for pos in positions:
		var stand: MeshInstance3D = MeshInstance3D.new()
		var stand_mesh: CylinderMesh = CylinderMesh.new()
		stand_mesh.top_radius = 0.08
		stand_mesh.bottom_radius = 0.12
		stand_mesh.height = 0.48
		stand_mesh.radial_segments = 12
		stand.mesh = stand_mesh
		stand.position = pos + Vector3(0.0, 0.22, 0.0)
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
		flame.position = pos + Vector3(0.0, 0.52, 0.0)
		var flame_mat: StandardMaterial3D = StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, 0.78, 0.44, 1.0)
		flame_mat.roughness = 0.12
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.58, 0.18, 1.0)
		flame_mat.emission_energy_multiplier = 1.15
		flame.material_override = flame_mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(flame)

		# Emissive-only sconces keep camera movement responsive.

func _add_chamber_accent_lights() -> void:
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var accents: Array[Dictionary] = [
		{"offset": Vector3(-board_w * 0.54, 1.10, -board_h * 0.58), "color": Color(0.20, 0.56, 1.0, 1.0), "energy": 0.74, "range": 7.0},
		{"offset": Vector3(board_w * 0.54, 1.06, -board_h * 0.58), "color": Color(0.74, 0.26, 1.0, 1.0), "energy": 0.74, "range": 7.0},
		{"offset": Vector3(0.0, 1.20, -board_h * 0.66), "color": Color(0.90, 0.56, 0.24, 1.0), "energy": 0.54, "range": 7.8},
	]
	for entry in accents:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = _camera_base_target + entry["offset"]
		light.light_color = entry["color"]
		light.light_energy = float(entry["energy"])
		light.set_meta("base_energy", float(entry["energy"]))
		light.omni_range = float(entry["range"])
		light.shadow_enabled = false
		_terrain_root.add_child(light)
		_point_lights.append(light)

func _add_cave_perimeter() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if _has_asset_scene("cave_wall"):
		_add_cave_perimeter_assets()
		return
	_add_cave_boundary_walls()
	_add_cave_buttresses()
	_add_cave_tunnel_mouths()

func _add_cave_perimeter_assets() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var jitter_scale: float = 0.0 if _phase_one_world_only() else 1.0
	# Composition-first massing: fewer, larger cave forms with asymmetric intrusion.
	var cluster_data: Array[Dictionary] = [
		{"offset": Vector3(-board_w * 0.58, 0.26, -board_h * 0.54), "yaw": 154.0, "scale": Vector3(2.72, 3.50, 1.94)},
		{"offset": Vector3(-board_w * 0.08, 0.24, -board_h * 0.60), "yaw": 176.0, "scale": Vector3(2.86, 3.68, 2.00)},
		{"offset": Vector3(board_w * 0.44, 0.22, -board_h * 0.56), "yaw": 202.0, "scale": Vector3(2.62, 3.42, 1.90)},
		{"offset": Vector3(-board_w * 0.72, 0.14, -board_h * 0.02), "yaw": -100.0, "scale": Vector3(2.12, 3.12, 1.58)},
		{"offset": Vector3(board_w * 0.72, 0.14, -board_h * 0.08), "yaw": 100.0, "scale": Vector3(2.10, 3.08, 1.56)},
		{"offset": Vector3(-board_w * 0.50, 0.10, board_h * 0.20), "yaw": -72.0, "scale": Vector3(1.86, 2.76, 1.42)},
		{"offset": Vector3(board_w * 0.20, 0.04, board_h * 0.52), "yaw": 206.0, "scale": Vector3(2.00, 2.40, 1.34)},
		{"offset": Vector3(-board_w * 0.26, 0.02, board_h * 0.60), "yaw": 148.0, "scale": Vector3(1.92, 2.34, 1.30)},
		{"offset": Vector3(0.06, -0.06, board_h * 0.66), "yaw": 180.0, "scale": Vector3(1.78, 2.16, 1.18)},
	]
	for i in range(cluster_data.size()):
		var cluster: Dictionary = cluster_data[i]
		var seed: int = i + _state.level_index * 31
		var p: Vector3 = _camera_base_target + cluster["offset"]
		p.x += (_noise01(seed * 19 + 7, seed * 29 + 11) - 0.5) * 0.40 * jitter_scale
		p.y += (_noise01(seed * 37 + 5, seed * 41 + 13) - 0.5) * 0.20 * jitter_scale
		p.z += (_noise01(seed * 43 + 9, seed * 47 + 3) - 0.5) * 0.38 * jitter_scale
		var yaw: float = deg_to_rad(float(cluster["yaw"]) + (_noise01(seed * 53 + 17, seed * 59 + 19) - 0.5) * 16.0 * jitter_scale)
		var scale: Vector3 = cluster["scale"]
		scale.x *= 1.0 + ((_noise01(seed * 61 + 21, seed * 67 + 23) - 0.5) * 0.20 * jitter_scale)
		scale.y *= 1.0 + ((_noise01(seed * 71 + 27, seed * 73 + 31) - 0.5) * 0.20 * jitter_scale)
		scale.z *= 1.0 + ((_noise01(seed * 79 + 33, seed * 83 + 35) - 0.5) * 0.18 * jitter_scale)
		_add_asset_instance(
			_terrain_root,
			"cave_wall",
			Transform3D(Basis(Vector3.UP, yaw).scaled(scale), p),
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i <= 5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)

	# Door placements are owned by _add_cave_doors() to keep one deterministic
	# progression entry (left open) and one progression exit (right closed/open).

func _add_cave_buttresses() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
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
	mat.albedo_color = CAVE_WALL_BASE.lerp(Color(0.26, 0.22, 0.20, 1.0), 0.34)
	mat.roughness = 0.82
	mat.metallic = 0.0
	for c in corners:
		var buttress: MeshInstance3D = MeshInstance3D.new()
		buttress.mesh = buttress_mesh
		buttress.position = c
		buttress.material_override = mat
		buttress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(buttress)

func _add_cave_tunnel_mouths() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
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
		ring_mat.albedo_color = Color(0.30, 0.24, 0.20, 1.0)
		ring_mat.roughness = 0.68
		ring_mat.metallic = 0.0
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.70, 0.42, 0.18, 1.0)
		ring_mat.emission_energy_multiplier = 0.12
		ring.material_override = ring_mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(ring)

func _add_cave_boundary_walls() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var ring_r: float = maxf(board_w, board_h) * 1.08
	var wall_height: float = maxf(board_w, board_h) * 0.78
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = ring_r
	ring_mesh.bottom_radius = ring_r * 1.10
	ring_mesh.height = wall_height
	ring_mesh.radial_segments = 72
	ring_mesh.rings = 8
	ring.mesh = ring_mesh
	ring.position = _camera_base_target + Vector3(0.0, wall_height * 0.50 - 0.26, 0.0)
	var mat: ShaderMaterial = _stone_shader_material(
		CAVE_WALL_BASE.lerp(Color(0.25, 0.21, 0.18, 1.0), 0.28),
		CAVE_WALL_ALT.lerp(Color(0.13, 0.11, 0.10, 1.0), 0.24),
		Color(0.10, 0.10, 0.11, 1.0),
		5.8,
		0.016,
		0.16
	)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(ring)

	var floor_edge_cover: MeshInstance3D = MeshInstance3D.new()
	var cover_mesh: BoxMesh = BoxMesh.new()
	cover_mesh.size = Vector3(board_w + 2.8, 0.18, board_h + 2.8)
	floor_edge_cover.mesh = cover_mesh
	floor_edge_cover.position = _camera_base_target + Vector3(0.0, -0.10, 0.0)
	var cover_mat: StandardMaterial3D = StandardMaterial3D.new()
	cover_mat.albedo_color = Color(0.11, 0.10, 0.10, 1.0)
	cover_mat.roughness = 0.96
	cover_mat.metallic = 0.0
	floor_edge_cover.material_override = cover_mat
	floor_edge_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_root.add_child(floor_edge_cover)

func _add_crystal_beds() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if _has_asset_scene("role_crystal"):
		var cluster_count_asset: int = 5
		for idx in range(cluster_count_asset):
			var seed_a_asset: int = idx * 59 + _state.level_index * 13
			var seed_b_asset: int = idx * 41 + _state.level_index * 23
			var edge_pick_asset: int = int(floor(_noise01(seed_a_asset + 7, seed_b_asset + 11) * 4.0))
			var t_asset: float = _noise01(seed_a_asset + 19, seed_b_asset + 31)
			var px_asset: float = _camera_base_target.x
			var pz_asset: float = _camera_base_target.z
			if edge_pick_asset == 0:
				px_asset = lerpf(_board_min.x + 1.1, _board_max.x - 1.1, t_asset)
				pz_asset = _board_min.z - 0.55
			elif edge_pick_asset == 1:
				px_asset = lerpf(_board_min.x + 1.1, _board_max.x - 1.1, t_asset)
				pz_asset = _board_max.z + 0.55
			elif edge_pick_asset == 2:
				px_asset = _board_min.x - 0.55
				pz_asset = lerpf(_board_min.z + 1.1, _board_max.z - 1.1, t_asset)
			else:
				px_asset = _board_max.x + 0.55
				pz_asset = lerpf(_board_min.z + 1.1, _board_max.z - 1.1, t_asset)
			var cluster_root_asset: Vector3 = Vector3(px_asset, 0.02, pz_asset)
			var crystal_count_asset: int = 2 + int(floor(_noise01(seed_a_asset + 43, seed_b_asset + 53) * 3.0))
			for n_asset in range(crystal_count_asset):
				var angle_asset: float = _noise01(seed_a_asset + n_asset * 29, seed_b_asset + n_asset * 31) * TAU
				var radius_asset: float = 0.05 + _noise01(seed_a_asset + n_asset * 37, seed_b_asset + n_asset * 41) * 0.24
				var rot_y_asset: float = _noise01(seed_a_asset + n_asset * 43, seed_b_asset + n_asset * 47) * TAU
				var scale_asset: float = 0.12 + _noise01(seed_a_asset + n_asset * 17, seed_b_asset + n_asset * 13) * 0.12
				var hue_asset: float = 0.54 + _noise01(seed_a_asset + n_asset * 7, seed_b_asset + n_asset * 5) * 0.18
				var glow_color_asset: Color = Color.from_hsv(hue_asset, 0.56, 0.86, 1.0)
				var crystal_mat_asset: StandardMaterial3D = StandardMaterial3D.new()
				crystal_mat_asset.albedo_color = glow_color_asset * 0.56
				crystal_mat_asset.roughness = 0.34
				crystal_mat_asset.metallic = 0.0
				crystal_mat_asset.emission_enabled = true
				crystal_mat_asset.emission = glow_color_asset
				crystal_mat_asset.emission_energy_multiplier = 0.22
				var crystal_tf_asset: Transform3D = Transform3D(
					Basis(Vector3.UP, rot_y_asset).scaled(Vector3.ONE * scale_asset),
					cluster_root_asset + Vector3(cos(angle_asset) * radius_asset, 0.0, sin(angle_asset) * radius_asset)
				)
				_add_asset_instance(
					_terrain_root,
					"role_crystal",
					crystal_tf_asset,
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
					crystal_mat_asset
				)
		return

	var cluster_count: int = 5
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
		var crystal_count: int = 2 + int(floor(_noise01(seed_a + 43, seed_b + 53) * 3.0))
		for n in range(crystal_count):
			var crystal: MeshInstance3D = MeshInstance3D.new()
			var c_mesh: CylinderMesh = CylinderMesh.new()
			c_mesh.top_radius = 0.024
			c_mesh.bottom_radius = 0.09 + _noise01(seed_a + n * 17, seed_b + n * 13) * 0.06
			c_mesh.height = 0.28 + _noise01(seed_a + n * 19, seed_b + n * 23) * 0.40
			c_mesh.radial_segments = 7
			crystal.mesh = c_mesh
			var angle: float = _noise01(seed_a + n * 29, seed_b + n * 31) * TAU
			var radius: float = 0.05 + _noise01(seed_a + n * 37, seed_b + n * 41) * 0.24
			var rot_y: float = _noise01(seed_a + n * 43, seed_b + n * 47) * TAU
			crystal.position = cluster_root + Vector3(cos(angle) * radius, c_mesh.height * 0.5, sin(angle) * radius)
			crystal.rotation_degrees = Vector3(0.0, rad_to_deg(rot_y), 0.0)
			var hue: float = 0.54 + _noise01(seed_a + n * 7, seed_b + n * 5) * 0.18
			var glow_color: Color = Color.from_hsv(hue, 0.56, 0.86, 1.0)
			var c_mat: StandardMaterial3D = StandardMaterial3D.new()
			c_mat.albedo_color = glow_color * 0.56
			c_mat.roughness = 0.34
			c_mat.metallic = 0.0
			c_mat.emission_enabled = true
			c_mat.emission = glow_color
			c_mat.emission_energy_multiplier = 0.22
			crystal.material_override = c_mat
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_terrain_root.add_child(crystal)

func _add_cave_glow_clusters() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if _has_asset_scene("role_crystal"):
		var cluster_count_asset: int = 2
		for idx in range(cluster_count_asset):
			var seed_a_asset: int = idx * 83 + _state.level_index * 19
			var seed_b_asset: int = idx * 61 + _state.level_index * 47
			var angle_asset: float = _noise01(seed_a_asset + 17, seed_b_asset + 23) * TAU
			var radius_asset: float = maxf(float(_state.width), float(_state.height)) * tile_world_size * (0.62 + _noise01(seed_a_asset + 29, seed_b_asset + 37) * 0.22)
			var x_asset: float = _camera_base_target.x + cos(angle_asset) * radius_asset
			var z_asset: float = _camera_base_target.z + sin(angle_asset) * radius_asset
			var cluster_pos_asset: Vector3 = Vector3(x_asset, 0.02, z_asset)
			var hue_asset: float = _noise01(seed_a_asset + 31, seed_b_asset + 37)
			var glow_color_asset: Color = Color.from_hsv(0.55 + hue_asset * 0.25, 0.58, 0.94, 1.0)
			var crystal_count_asset: int = 3 + int(floor(_noise01(seed_a_asset + 11, seed_b_asset + 5) * 2.0))
			for c_asset in range(crystal_count_asset):
				var c_angle_asset: float = _noise01(seed_a_asset + c_asset * 37, seed_b_asset + c_asset * 41) * TAU
				var c_radius_asset: float = 0.04 + _noise01(seed_a_asset + c_asset * 43, seed_b_asset + c_asset * 47) * 0.24
				var c_rot_asset: float = _noise01(seed_a_asset + c_asset * 53, seed_b_asset + c_asset * 59) * TAU
				var c_scale_asset: float = 0.14 + _noise01(seed_a_asset + c_asset * 29, seed_b_asset + c_asset * 13) * 0.16
				var crystal_mat_asset: StandardMaterial3D = StandardMaterial3D.new()
				crystal_mat_asset.albedo_color = glow_color_asset * 0.72
				crystal_mat_asset.roughness = 0.24
				crystal_mat_asset.metallic = 0.0
				crystal_mat_asset.emission_enabled = true
				crystal_mat_asset.emission = glow_color_asset
				crystal_mat_asset.emission_energy_multiplier = 0.56
				var crystal_tf_asset: Transform3D = Transform3D(
					Basis(Vector3.UP, c_rot_asset).scaled(Vector3.ONE * c_scale_asset),
					cluster_pos_asset + Vector3(cos(c_angle_asset) * c_radius_asset, 0.0, sin(c_angle_asset) * c_radius_asset)
				)
				_add_asset_instance(
					_terrain_root,
					"role_crystal",
					crystal_tf_asset,
					GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
					crystal_mat_asset
				)
			var glow_light_asset: OmniLight3D = OmniLight3D.new()
			glow_light_asset.position = cluster_pos_asset + Vector3(0.0, 0.72, 0.0)
			glow_light_asset.light_color = glow_color_asset.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.08)
			glow_light_asset.light_energy = 0.42
			glow_light_asset.set_meta("base_energy", 0.42)
			glow_light_asset.omni_range = 3.6
			glow_light_asset.shadow_enabled = false
			_terrain_root.add_child(glow_light_asset)
			_point_lights.append(glow_light_asset)
		return

	var cluster_count: int = 2
	for idx in range(cluster_count):
		var seed_a: int = idx * 83 + _state.level_index * 19
		var seed_b: int = idx * 61 + _state.level_index * 47
		var angle: float = _noise01(seed_a + 17, seed_b + 23) * TAU
		var radius: float = maxf(float(_state.width), float(_state.height)) * tile_world_size * (0.62 + _noise01(seed_a + 29, seed_b + 37) * 0.22)
		var x: float = _camera_base_target.x + cos(angle) * radius
		var z: float = _camera_base_target.z + sin(angle) * radius
		var y: float = 0.58
		var cluster_pos: Vector3 = Vector3(x, y, z)

		var hue: float = _noise01(seed_a + 31, seed_b + 37)
		var glow_color: Color = Color.from_hsv(0.55 + hue * 0.25, 0.58, 0.94, 1.0)
		var crystal_count: int = 3 + int(floor(_noise01(seed_a + 11, seed_b + 5) * 2.0))
		for c in range(crystal_count):
			var crystal: MeshInstance3D = MeshInstance3D.new()
			var crystal_mesh: CylinderMesh = CylinderMesh.new()
			crystal_mesh.top_radius = 0.03
			crystal_mesh.bottom_radius = 0.10 + _noise01(seed_a + c * 29, seed_b + c * 13) * 0.08
			crystal_mesh.height = 0.26 + _noise01(seed_a + c * 17, seed_b + c * 19) * 0.46
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
			crystal_mat.emission_energy_multiplier = 0.56
			crystal.material_override = crystal_mat
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_terrain_root.add_child(crystal)
		var glow_light: OmniLight3D = OmniLight3D.new()
		glow_light.position = cluster_pos + Vector3(0.0, 0.72, 0.0)
		glow_light.light_color = glow_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.08)
		glow_light.light_energy = 0.42
		glow_light.set_meta("base_energy", 0.42)
		glow_light.omni_range = 3.6
		glow_light.shadow_enabled = false
		_terrain_root.add_child(glow_light)
		_point_lights.append(glow_light)

func _add_cave_shell() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	if _has_asset_scene("cave_wall"):
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var wall_mat: ShaderMaterial = _stone_shader_material(
		CAVE_WALL_BASE.lerp(Color(0.16, 0.15, 0.16, 1.0), 0.34),
		CAVE_WALL_ALT.lerp(Color(0.08, 0.08, 0.09, 1.0), 0.24),
		Color(0.08, 0.10, 0.11, 1.0),
		5.0,
		0.010,
		0.24
	)

	var back_wall: MeshInstance3D = MeshInstance3D.new()
	var back_mesh: BoxMesh = BoxMesh.new()
	back_mesh.size = Vector3(board_w + 6.2, 5.4, 2.4)
	back_wall.mesh = back_mesh
	back_wall.position = _camera_base_target + Vector3(0.0, 1.75, -board_h * 0.5 - 2.45)
	back_wall.material_override = wall_mat
	back_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_root.add_child(back_wall)

	var left_wall: MeshInstance3D = MeshInstance3D.new()
	var left_mesh: BoxMesh = BoxMesh.new()
	left_mesh.size = Vector3(2.8, 4.6, board_h + 5.2)
	left_wall.mesh = left_mesh
	left_wall.position = _camera_base_target + Vector3(-board_w * 0.5 - 2.35, 1.45, -0.15)
	left_wall.material_override = wall_mat
	left_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_root.add_child(left_wall)

	var right_wall: MeshInstance3D = MeshInstance3D.new()
	var right_mesh: BoxMesh = BoxMesh.new()
	right_mesh.size = Vector3(2.8, 4.8, board_h + 5.6)
	right_wall.mesh = right_mesh
	right_wall.position = _camera_base_target + Vector3(board_w * 0.5 + 2.30, 1.52, -0.22)
	right_wall.material_override = wall_mat
	right_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_terrain_root.add_child(right_wall)

	if ENABLE_CAVE_CEILING:
		var ceiling: MeshInstance3D = MeshInstance3D.new()
		var ceiling_mesh: BoxMesh = BoxMesh.new()
		ceiling_mesh.size = Vector3(board_w + 6.4, 2.0, board_h + 6.8)
		ceiling.mesh = ceiling_mesh
		ceiling.position = _camera_base_target + Vector3(0.0, 3.95, -0.30)
		ceiling.material_override = wall_mat
		ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_terrain_root.add_child(ceiling)

func _add_cave_foreground_occluders() -> void:
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	if STRICT_ENV_ASSET_KIT_ONLY and not _has_asset_scene("cave_wall"):
		return
	if _has_asset_scene("cave_wall"):
		var jitter_scale: float = 0.0 if _phase_one_world_only() else 1.0
		var chunks: Array[Dictionary] = [
			{"offset": Vector3(-board_w * 0.70, -0.04, board_h * 0.72), "yaw": -22.0, "scale": Vector3(2.04, 1.72, 1.44)},
			{"offset": Vector3(board_w * 0.70, -0.04, board_h * 0.72), "yaw": 24.0, "scale": Vector3(2.04, 1.72, 1.44)},
			{"offset": Vector3(board_w * 0.64, -0.18, board_h * 0.18), "yaw": 72.0, "scale": Vector3(1.54, 1.28, 1.16)},
		]
		for i in range(chunks.size()):
			var seed: int = i + _state.level_index * 101
			var c: Dictionary = chunks[i]
			var pos: Vector3 = _camera_base_target + c["offset"]
			pos.x += (_noise01(seed * 17 + 3, seed * 19 + 11) - 0.5) * 0.22 * jitter_scale
			pos.z += (_noise01(seed * 23 + 7, seed * 29 + 13) - 0.5) * 0.16 * jitter_scale
			pos.y += (_noise01(seed * 31 + 17, seed * 37 + 19) - 0.5) * 0.10 * jitter_scale
			var yaw: float = deg_to_rad(float(c["yaw"]) + (_noise01(seed * 41 + 5, seed * 43 + 23) - 0.5) * 12.0 * jitter_scale)
			var scale: Vector3 = c["scale"]
			scale.x *= 1.0 + ((_noise01(seed * 47 + 29, seed * 53 + 31) - 0.5) * 0.18 * jitter_scale)
			scale.y *= 1.0 + ((_noise01(seed * 59 + 37, seed * 61 + 41) - 0.5) * 0.16 * jitter_scale)
			scale.z *= 1.0 + ((_noise01(seed * 67 + 43, seed * 71 + 47) - 0.5) * 0.16 * jitter_scale)
			_add_asset_instance(
				_terrain_root,
				"cave_wall",
				Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos),
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i <= 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
		return
	if STRICT_ENV_ASSET_KIT_ONLY:
		return

	var fallback_mesh: SphereMesh = SphereMesh.new()
	fallback_mesh.radius = 0.82
	fallback_mesh.height = 1.24
	fallback_mesh.radial_segments = 12
	fallback_mesh.rings = 7
	var fallback_mat: ShaderMaterial = _stone_shader_material(
		Color(0.20, 0.18, 0.17, 1.0),
		Color(0.10, 0.10, 0.11, 1.0),
		Color(0.10, 0.11, 0.12, 1.0),
		7.8,
		0.024,
		0.64
	)
	var fallback_positions: Array[Vector3] = [
		_camera_base_target + Vector3(-board_w * 0.70, -0.08, board_h * 0.70),
		_camera_base_target + Vector3(board_w * 0.70, -0.08, board_h * 0.70),
	]
	for pos in fallback_positions:
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.mesh = fallback_mesh
		rock.material_override = fallback_mat
		rock.position = pos
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(rock)

func _add_far_cave_backdrop() -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _state == null:
		return
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	if _has_asset_scene("cave_wall"):
		var jitter_scale: float = 0.0 if _phase_one_world_only() else 1.0
		var deep_back_z: float = _camera_base_target.z - board_h * 0.5 - 2.4
		for i in range(4):
			var t: float = float(i) / 3.0
			var x: float = lerpf(_camera_base_target.x - board_w * 0.70, _camera_base_target.x + board_w * 0.70, t)
			var seed: int = i + _state.level_index * 41
			x += (_noise01(seed * 23 + 5, seed * 31 + 7) - 0.5) * 0.56 * jitter_scale
			var y: float = -0.02 + (_noise01(seed * 37 + 11, seed * 43 + 13) * 0.54 * jitter_scale)
			var basis: Basis = Basis(
				Vector3.UP,
				deg_to_rad(180.0 + (_noise01(seed * 47 + 17, seed * 53 + 19) - 0.5) * 12.0 * jitter_scale)
			).scaled(Vector3(
				2.18 + (_noise01(seed * 59 + 3, seed * 61 + 9) - 0.5) * 0.52 * jitter_scale,
				3.22 + (_noise01(seed * 67 + 11, seed * 71 + 15) - 0.5) * 0.90 * jitter_scale,
				1.90 + (_noise01(seed * 73 + 17, seed * 79 + 21) - 0.5) * 0.52 * jitter_scale
			))
			_add_asset_instance(
				_terrain_root,
				"cave_wall",
				Transform3D(basis, Vector3(x, y, deep_back_z)),
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)

		var vault_basis: Basis = Basis(Vector3.UP, deg_to_rad(180.0)).scaled(Vector3(2.86, 3.66, 2.46))
		_add_asset_instance(
			_terrain_root,
			"cave_wall",
			Transform3D(vault_basis, _camera_base_target + Vector3(0.0, -0.06, deep_back_z - 1.54)),
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		var side_back_z: float = _camera_base_target.z + board_h * 0.02
		var side_x: float = board_w * 0.5 + 2.7
		for i in range(2):
			var sign: float = -1.0 if i == 0 else 1.0
			var side_basis: Basis = Basis(Vector3.UP, deg_to_rad(92.0 * sign)).scaled(Vector3(2.06, 2.62, 1.78))
			_add_asset_instance(
				_terrain_root,
				"cave_wall",
				Transform3D(side_basis, _camera_base_target + Vector3(sign * side_x, 0.00, side_back_z)),
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
		return

	var wall_height: float = maxf(board_w, board_h) * 1.10
	var inset: float = 3.4
	var wall_thickness: float = 0.80
	var wall_material: ShaderMaterial = _stone_shader_material(
		Color(0.14, 0.13, 0.14, 1.0),
		Color(0.08, 0.08, 0.09, 1.0),
		Color(0.07, 0.08, 0.09, 1.0),
		4.2,
		0.010,
		0.12
	)

	var wall_ns_mesh: BoxMesh = BoxMesh.new()
	wall_ns_mesh.size = Vector3(board_w + inset * 2.0, wall_height, wall_thickness)
	var wall_ew_mesh: BoxMesh = BoxMesh.new()
	wall_ew_mesh.size = Vector3(wall_thickness, wall_height, board_h + inset * 2.0)
	var wall_positions: Array[Dictionary] = [
		{"mesh": wall_ns_mesh, "offset": Vector3(0.0, wall_height * 0.5 - 0.20, -board_h * 0.5 - inset)},
		{"mesh": wall_ew_mesh, "offset": Vector3(board_w * 0.5 + inset, wall_height * 0.5 - 0.20, 0.0)},
	]
	for wall_data in wall_positions:
		var wall: MeshInstance3D = MeshInstance3D.new()
		wall.mesh = wall_data["mesh"]
		wall.position = _camera_base_target + wall_data["offset"]
		wall.material_override = wall_material
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(wall)

	if ENABLE_CAVE_CEILING:
		var ceiling: MeshInstance3D = MeshInstance3D.new()
		var ceiling_mesh: BoxMesh = BoxMesh.new()
		ceiling_mesh.size = Vector3(board_w + inset * 2.0, 0.70, board_h + inset * 2.0)
		ceiling.mesh = ceiling_mesh
		ceiling.position = _camera_base_target + Vector3(0.0, wall_height + 0.32, 0.0)
		var ceiling_mat: StandardMaterial3D = StandardMaterial3D.new()
		ceiling_mat.albedo_color = Color(0.06, 0.06, 0.07, 1.0)
		ceiling_mat.roughness = 0.96
		ceiling_mat.metallic = 0.0
		ceiling.material_override = ceiling_mat
		ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_terrain_root.add_child(ceiling)

func _add_atmospheric_haze(board_width: float, board_height: float) -> void:
	if STRICT_ENV_ASSET_KIT_ONLY:
		return
	if _terrain_root == null:
		return
	_haze_layer = MeshInstance3D.new()
	_haze_layer.name = "AtmosphericHaze"
	var haze_mesh: QuadMesh = QuadMesh.new()
	haze_mesh.size = Vector2(board_width * 1.22, board_height * 1.22)
	_haze_layer.mesh = haze_mesh
	_haze_layer.position = _camera_base_target + Vector3(0.0, 0.56, 0.0)
	_haze_layer.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_haze_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var haze_mat: ShaderMaterial = ShaderMaterial.new()
	var haze_shader: Shader = Shader.new()
	haze_shader.code = HAZE_SHADER_CODE
	haze_mat.shader = haze_shader
	haze_mat.set_shader_parameter("haze_color", Color(0.24, 0.22, 0.20, 0.060))
	haze_mat.set_shader_parameter("noise_scale", 4.8)
	haze_mat.set_shader_parameter("drift_speed", 0.015)
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
		cached.set_shader_parameter("owner_color", _owner_ooze_tint(owner_id))
		cached.set_shader_parameter("pulse_speed", 0.22)
		cached.set_shader_parameter("bubble_strength", 0.0018)
		cached.set_shader_parameter("emission_strength", 0.008)
		cached.set_shader_parameter("detail_scale", 6.2)
		cached.set_shader_parameter("body_thickness", 0.024)
		cached.set_shader_parameter("lip_thickness", 0.032)
		cached.set_shader_parameter("flow_scale", 1.34)
		cached.set_shader_parameter("flow_speed", 0.008)
		cached.set_shader_parameter("flow_normal_strength", 0.30)
		cached.set_shader_parameter("edge_darkening_strength", 0.18)
		cached.set_shader_parameter("contact_darkening_strength", 0.10)
		cached.set_shader_parameter("clearcoat_strength", 0.44)
		cached.set_shader_parameter("specular_strength", 0.38)
		return cached
	var tint: Color = _owner_ooze_tint(owner_id)
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
	mat.set_shader_parameter("pulse_speed", 0.22)
	mat.set_shader_parameter("bubble_strength", 0.0018)
	mat.set_shader_parameter("emission_strength", 0.008)
	mat.set_shader_parameter("detail_scale", 6.2)
	mat.set_shader_parameter("body_thickness", 0.024)
	mat.set_shader_parameter("lip_thickness", 0.032)
	mat.set_shader_parameter("flow_scale", 1.34)
	mat.set_shader_parameter("flow_speed", 0.008)
	mat.set_shader_parameter("flow_normal_strength", 0.30)
	mat.set_shader_parameter("edge_darkening_strength", 0.18)
	mat.set_shader_parameter("contact_darkening_strength", 0.10)
	mat.set_shader_parameter("clearcoat_strength", 0.44)
	mat.set_shader_parameter("specular_strength", 0.38)
	_pool_material_cache[cache_key] = mat
	return mat

func _ooze_growth_material(owner_tint: Color, role_tint: Color, role: String, accent: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var role_mix: float = 0.44
	var roughness: float = 0.44
	var clearcoat: float = 0.22
	var emission_strength: float = 0.08
	match role:
		"heart":
			role_mix = 0.18
			roughness = 0.36
			clearcoat = 0.26
			emission_strength = 0.10
		"melee":
			role_mix = 0.58
			roughness = 0.48
			clearcoat = 0.20
			emission_strength = 0.11
		"ranged":
			role_mix = 0.55
			roughness = 0.40
			clearcoat = 0.24
			emission_strength = 0.13
		"defense":
			role_mix = 0.46
			roughness = 0.52
			clearcoat = 0.18
			emission_strength = 0.07
		"gather":
			role_mix = 0.52
			roughness = 0.42
			clearcoat = 0.22
			emission_strength = 0.10
	if accent:
		roughness = maxf(0.30, roughness - 0.08)
		clearcoat = minf(0.34, clearcoat + 0.06)
		emission_strength *= 1.26
	var base_color: Color = owner_tint.lerp(role_tint, role_mix).lerp(Color(0.08, 0.09, 0.10, 1.0), 0.06)
	mat.albedo_color = base_color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.metallic_specular = 0.20
	mat.clearcoat_enabled = true
	mat.clearcoat = clearcoat
	mat.clearcoat_roughness = clampf(roughness + 0.10, 0.20, 0.70)
	mat.emission_enabled = true
	mat.emission = owner_tint.lerp(role_tint, minf(0.78, role_mix + 0.16))
	mat.emission_energy_multiplier = emission_strength
	return mat

func _role_crest_mesh(role: String) -> Mesh:
	match role:
		"melee":
			var shard: PrismMesh = PrismMesh.new()
			shard.left_to_right = 0.56
			shard.size = Vector3(0.22, 0.38, 0.16)
			return shard
		"ranged":
			var orb: SphereMesh = SphereMesh.new()
			orb.radius = 0.14
			orb.height = 0.22
			orb.radial_segments = 10
			orb.rings = 6
			return orb
		"defense":
			var bastion: CapsuleMesh = CapsuleMesh.new()
			bastion.radius = 0.12
			bastion.height = 0.30
			bastion.radial_segments = 10
			bastion.rings = 6
			return bastion
		"gather":
			var bulb: CapsuleMesh = CapsuleMesh.new()
			bulb.radius = 0.12
			bulb.height = 0.34
			bulb.radial_segments = 12
			bulb.rings = 7
			return bulb
		_:
			var fallback: SphereMesh = SphereMesh.new()
			fallback.radius = 0.15
			fallback.height = 0.30
			fallback.radial_segments = 10
			fallback.rings = 6
			return fallback

func _role_base_mesh(role: String) -> Mesh:
	var dome: SphereMesh = SphereMesh.new()
	dome.radius = 0.24
	dome.height = 0.15
	dome.radial_segments = 14
	dome.rings = 8
	match role:
		"melee":
			dome.radius = 0.25
			dome.height = 0.16
			return dome
		"defense":
			dome.radius = 0.27
			dome.height = 0.17
			return dome
		"ranged":
			dome.radius = 0.23
			dome.height = 0.15
			return dome
		"gather":
			dome.radius = 0.22
			dome.height = 0.14
			return dome
		_:
			return dome

func _role_base_material(role: String, role_tint: Color, owner_tint: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	match role:
		"melee":
			mat.albedo_color = owner_tint.lerp(role_tint, 0.40).lerp(Color(0.08, 0.08, 0.08, 1.0), 0.24)
			mat.roughness = 0.22
			mat.metallic = 0.01
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.36
			mat.clearcoat_roughness = 0.26
			mat.emission_enabled = true
			mat.emission = role_tint * 0.18
			mat.emission_energy_multiplier = 0.08
		"defense":
			mat.albedo_color = owner_tint.lerp(role_tint, 0.34).lerp(Color(0.08, 0.08, 0.09, 1.0), 0.28)
			mat.roughness = 0.30
			mat.metallic = 0.01
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.30
			mat.clearcoat_roughness = 0.34
			mat.emission_enabled = true
			mat.emission = role_tint * 0.12
			mat.emission_energy_multiplier = 0.05
		"ranged":
			mat.albedo_color = owner_tint.lerp(role_tint, 0.42).lerp(Color(0.09, 0.09, 0.10, 1.0), 0.24)
			mat.roughness = 0.20
			mat.metallic = 0.01
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.40
			mat.clearcoat_roughness = 0.24
			mat.emission_enabled = true
			mat.emission = role_tint * 0.22
			mat.emission_energy_multiplier = 0.09
		"gather":
			mat.albedo_color = owner_tint.lerp(role_tint, 0.44).lerp(Color(0.09, 0.10, 0.08, 1.0), 0.22)
			mat.roughness = 0.18
			mat.metallic = 0.01
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.44
			mat.clearcoat_roughness = 0.22
			mat.emission_enabled = true
			mat.emission = role_tint * 0.20
			mat.emission_energy_multiplier = 0.08
		_:
			mat.albedo_color = owner_tint.lerp(role_tint, 0.30).lerp(Color(0.08, 0.08, 0.09, 1.0), 0.30)
			mat.roughness = 0.28
			mat.metallic = 0.01
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.30
			mat.clearcoat_roughness = 0.32
			mat.emission_enabled = true
			mat.emission = role_tint * 0.12
			mat.emission_energy_multiplier = 0.05
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

func _owner_ooze_tint(owner_id: int) -> Color:
	var raw: Color = _owner_tint(owner_id)
	return raw.lerp(Color(0.10, 0.11, 0.12, 1.0), 0.18)

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
	mat.set_shader_parameter("normal_strength", 0.68)
	mat.set_shader_parameter("height_amp", height_amp)
	return mat

func _stone_texture() -> Texture2D:
	if _stone_texture_cache != null:
		return _stone_texture_cache
	var imported: Texture2D = _load_texture_or_null(_texture_path_for("stone_albedo"))
	if imported != null:
		_stone_texture_cache = imported
		return _stone_texture_cache
	var size: int = 160
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var n0: float = _noise01(x * 7 + y * 11, x * 5 + y * 3)
			var n1: float = _noise01(x * 17 + y * 13, x * 23 + y * 19)
			var n2: float = _noise01(x * 31 + y * 29, x * 37 + y * 41)
			var crack: float = absf(sin(float(x) * 0.18 + n1 * 3.2) * cos(float(y) * 0.16 - n2 * 2.8))
			var blend: float = clampf(n0 * 0.52 + n1 * 0.34 + n2 * 0.14, 0.0, 1.0)
			var col: Color = Color(0.24, 0.22, 0.21, 1.0).lerp(Color(0.10, 0.10, 0.11, 1.0), blend)
			if crack > 0.78:
				col = col.lerp(Color(0.07, 0.07, 0.08, 1.0), 0.52)
			if n2 < 0.16:
				col = col.lerp(Color(0.30, 0.28, 0.25, 1.0), 0.22)
			image.set_pixel(x, y, col)
	_stone_texture_cache = ImageTexture.create_from_image(image)
	return _stone_texture_cache

func _stone_roughness_texture() -> Texture2D:
	if _stone_roughness_texture_cache != null:
		return _stone_roughness_texture_cache
	var imported: Texture2D = _load_texture_or_null(_texture_path_for("stone_roughness"))
	if imported != null:
		_stone_roughness_texture_cache = imported
		return _stone_roughness_texture_cache
	var size: int = 96
	var image: Image = Image.create(size, size, false, Image.FORMAT_RF)
	for y in range(size):
		for x in range(size):
			var n0: float = _noise01(x * 13 + y * 7, x * 17 + y * 11)
			var n1: float = _noise01(x * 29 + y * 31, x * 19 + y * 23)
			var wet_mask: float = clampf(n1 * 1.18 - 0.70, 0.0, 1.0)
			var rough: float = clampf(0.78 - wet_mask * 0.34 + n0 * 0.12, 0.20, 0.92)
			image.set_pixel(x, y, Color(rough, 0.0, 0.0, 1.0))
	_stone_roughness_texture_cache = ImageTexture.create_from_image(image)
	return _stone_roughness_texture_cache

func _stone_normal_texture() -> Texture2D:
	if _stone_normal_texture_cache != null:
		return _stone_normal_texture_cache
	var imported: Texture2D = _load_texture_or_null(_texture_path_for("stone_normal"))
	if imported != null:
		_stone_normal_texture_cache = imported
		return _stone_normal_texture_cache
	var size: int = 96
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(size * size)
	for y in range(size):
		for x in range(size):
			var h0: float = _noise01(x * 11 + y * 17, x * 13 + y * 7)
			var h1: float = _noise01(x * 23 + y * 29, x * 31 + y * 19)
			var h2: float = _noise01(x * 37 + y * 41, x * 43 + y * 47)
			heights[y * size + x] = clampf(h0 * 0.54 + h1 * 0.32 + h2 * 0.14, 0.0, 1.0)
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var xm1: int = (x - 1 + size) % size
			var xp1: int = (x + 1) % size
			var ym1: int = (y - 1 + size) % size
			var yp1: int = (y + 1) % size
			var dx: float = heights[y * size + xp1] - heights[y * size + xm1]
			var dy: float = heights[yp1 * size + x] - heights[ym1 * size + x]
			var n: Vector3 = Vector3(-dx * 2.6, -dy * 2.6, 1.0).normalized()
			image.set_pixel(
				x,
				y,
				Color(
					n.x * 0.5 + 0.5,
					n.y * 0.5 + 0.5,
					n.z * 0.5 + 0.5,
					1.0
				)
			)
	_stone_normal_texture_cache = ImageTexture.create_from_image(image)
	return _stone_normal_texture_cache

func _slime_detail_texture() -> Texture2D:
	if _slime_detail_texture_cache != null:
		return _slime_detail_texture_cache
	var tex: Texture2D = _load_texture_or_null(_texture_path_for("slime_detail"))
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
			return Color(0.62, 0.88, 0.44, 1.0)
		"defense":
			return Color(0.36, 0.70, 0.62, 1.0)
		"melee":
			return Color(0.78, 0.46, 0.36, 1.0)
		"ranged":
			return Color(0.42, 0.74, 0.94, 1.0)
		_:
			return Color(0.72, 0.76, 0.80, 1.0)

func _animate_lights() -> void:
	var pulse: float = 0.97 + 0.03 * sin(_visual_time * 0.70)
	if _fill_light != null:
		_fill_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["fill_energy"]) + 0.04 * sin(_visual_time * 0.55)
	for light in _point_lights:
		if light == null or not is_instance_valid(light):
			continue
		var base_energy: float = float(light.get_meta("base_energy")) if light.has_meta("base_energy") else light.light_energy
		light.light_energy = base_energy * pulse
	if _key_light != null:
		_key_light.light_energy = float(STABILIZATION_LIGHT_BASELINE["key_energy"]) + 0.03 * sin(_visual_time * 0.30)

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
	var aspect_adjust: float = 0.70 + clampf(1.45 - aspect, -0.16, 0.54) * 0.15
	return clampf(board_span * aspect_adjust + 0.8, CAMERA_MIN_DISTANCE + 0.8, CAMERA_MAX_DISTANCE * 0.58)

func _update_camera_transform(force: bool) -> void:
	if _camera == null or _state == null:
		return
	if force:
		_camera_yaw = _camera_yaw_target
		_camera_pitch = _camera_pitch_target
		_camera_distance = _camera_distance_target
	else:
		var smoothing: float = 0.11
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
	_camera.look_at(target + Vector3(0.0, 0.34, 0.0), Vector3.UP)
	if _key_light != null:
		_key_light.position = target + Vector3(-8.5, 16.0, -7.0)
	if _rim_light != null:
		_rim_light.position = target + Vector3(0.0, 12.6, 0.0)
	if _fill_light != null:
		_fill_light.position = target + Vector3(0.0, 5.6, 0.0)

func _load_asset_manifest() -> void:
	_asset_manifest.clear()
	_geometry_asset_registry.clear()
	_geometry_asset_normalize.clear()
	_texture_asset_registry.clear()
	_asset_scene_cache.clear()
	_asset_material_cache.clear()

	var file: FileAccess = FileAccess.open(ASSET_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("World3D asset manifest missing: %s" % ASSET_MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("World3D asset manifest invalid JSON dictionary: %s" % ASSET_MANIFEST_PATH)
		return

	_asset_manifest = parsed
	var textures_variant: Variant = _asset_manifest.get("textures", {})
	if typeof(textures_variant) == TYPE_DICTIONARY:
		var textures: Dictionary = textures_variant
		for key_variant in textures.keys():
			var key: String = String(key_variant)
			var value: Variant = textures[key_variant]
			if typeof(value) == TYPE_STRING:
				var path: String = String(value)
				if not path.is_empty():
					_texture_asset_registry[key] = path
			elif typeof(value) == TYPE_DICTIONARY:
				var entry: Dictionary = value
				var entry_path: String = String(entry.get("path", ""))
				if not entry_path.is_empty():
					_texture_asset_registry[key] = entry_path

	var geometry_variant: Variant = _asset_manifest.get("geometry", {})
	if typeof(geometry_variant) != TYPE_DICTIONARY:
		return
	var geometry: Dictionary = geometry_variant
	for key_variant in geometry.keys():
		var key: String = String(key_variant)
		var entry_variant: Variant = geometry[key_variant]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var path: String = String(entry.get("path", ""))
		if path.is_empty():
			continue
		_geometry_asset_registry[key] = path
		var normalize: Dictionary = {}
		var normalize_variant: Variant = entry.get("normalize", {})
		if typeof(normalize_variant) == TYPE_DICTIONARY:
			var normalize_entry: Dictionary = normalize_variant
			if normalize_entry.has("scale"):
				normalize["scale"] = _manifest_vec3(normalize_entry.get("scale"), Vector3.ONE)
			if normalize_entry.has("rotation_degrees"):
				normalize["rotation_degrees"] = _manifest_vec3(normalize_entry.get("rotation_degrees"), Vector3.ZERO)
			if normalize_entry.has("offset"):
				normalize["offset"] = _manifest_vec3(normalize_entry.get("offset"), Vector3.ZERO)
		if not normalize.is_empty():
			_geometry_asset_normalize[key] = normalize

func _manifest_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return value as Vector3
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var arr: Array = value
	if arr.size() < 3:
		return fallback
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func _texture_path_for(key: String) -> String:
	return String(_texture_asset_registry.get(key, ""))

func _asset_path_for(key: String) -> String:
	return String(_geometry_asset_registry.get(key, ""))

func _asset_scene_for(key: String) -> PackedScene:
	if _asset_scene_cache.has(key):
		return _asset_scene_cache[key] as PackedScene
	var path: String = _asset_path_for(key)
	if path.is_empty():
		_asset_scene_cache[key] = null
		return null
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		scene = res as PackedScene
	if scene == null and path.to_lower().ends_with(".glb"):
		scene = _runtime_scene_from_gltf(path)
	_asset_scene_cache[key] = scene
	return scene

func _runtime_scene_from_gltf(res_path: String) -> PackedScene:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: int = gltf.append_from_file(abs_path, state)
	if err != OK:
		return null
	var generated: Node = gltf.generate_scene(state)
	if generated == null:
		return null
	var packed: PackedScene = PackedScene.new()
	var pack_err: int = packed.pack(generated)
	generated.free()
	if pack_err != OK:
		return null
	return packed

func _has_asset_scene(key: String) -> bool:
	return _asset_scene_for(key) != null

func _instantiate_asset_scene(key: String) -> Node3D:
	var scene: PackedScene = _asset_scene_for(key)
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	if instance is Node3D:
		return instance as Node3D
	var holder: Node3D = Node3D.new()
	holder.name = "AssetHolder_%s" % key
	holder.add_child(instance)
	return holder

func _set_geometry_visuals(node: Node, cast_shadow: int, material_override: Material = null) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = cast_shadow
	if material_override != null and node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material_override
	for child in node.get_children():
		_set_geometry_visuals(child, cast_shadow, material_override)

func _normalized_asset_transform(key: String, base_tf: Transform3D) -> Transform3D:
	if not _geometry_asset_normalize.has(key):
		return base_tf
	var normalize: Dictionary = _geometry_asset_normalize[key]
	var scale: Vector3 = normalize.get("scale", Vector3.ONE)
	var rotation_deg: Vector3 = normalize.get("rotation_degrees", Vector3.ZERO)
	var local_offset: Vector3 = normalize.get("offset", Vector3.ZERO)
	var local_basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rotation_deg.x),
		deg_to_rad(rotation_deg.y),
		deg_to_rad(rotation_deg.z)
	)).scaled(scale)
	return base_tf * Transform3D(local_basis, local_offset)

func _default_asset_material_for(key: String) -> Material:
	if _asset_material_cache.has(key):
		return _asset_material_cache[key] as Material
	var material: Material = null
	match key:
		"blocker_wall":
			material = _stone_shader_material(
				Color(0.26, 0.23, 0.21, 1.0),
				Color(0.11, 0.10, 0.10, 1.0),
				Color(0.09, 0.11, 0.13, 1.0),
				7.8,
				0.034,
				0.84
			)
		"cave_wall":
			material = _stone_shader_material(
				Color(0.22, 0.21, 0.22, 1.0),
				Color(0.08, 0.08, 0.09, 1.0),
				Color(0.09, 0.11, 0.13, 1.0),
				7.2,
				0.046,
				0.96
			)
		"board_edge_trim":
			material = _stone_shader_material(
				Color(0.19, 0.18, 0.18, 1.0),
				Color(0.08, 0.08, 0.09, 1.0),
				Color(0.08, 0.10, 0.12, 1.0),
				8.4,
				0.034,
				0.72
			)
		"door_arch":
			var door_mat: StandardMaterial3D = StandardMaterial3D.new()
			door_mat.albedo_color = Color(0.13, 0.10, 0.08, 1.0)
			door_mat.roughness = 0.70
			door_mat.metallic = 0.04
			door_mat.emission_enabled = true
			door_mat.emission = Color(0.78, 0.46, 0.20, 1.0)
			door_mat.emission_energy_multiplier = 0.18
			material = door_mat
		"node_base":
			material = _stone_shader_material(
				CAVE_WALL_BASE.lerp(Color(0.32, 0.26, 0.22, 1.0), 0.20),
				CAVE_WALL_ALT.lerp(Color(0.17, 0.13, 0.11, 1.0), 0.20),
				Color(0.12, 0.12, 0.11, 1.0),
				6.2,
				0.018,
				0.66
			)
	_asset_material_cache[key] = material
	return material

func _add_asset_instance(
	parent: Node3D,
	key: String,
	tf: Transform3D,
	cast_shadow: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
	material_override: Material = null
) -> Node3D:
	if parent == null:
		return null
	var inst: Node3D = _instantiate_asset_scene(key)
	if inst == null:
		return null
	parent.add_child(inst)
	inst.transform = _normalized_asset_transform(key, tf)
	var effective_material: Material = material_override if material_override != null else _default_asset_material_for(key)
	_set_geometry_visuals(inst, cast_shadow, effective_material)
	return inst

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
