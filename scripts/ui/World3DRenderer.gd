extends Node3D
class_name World3DRenderer

const World3DAssetsScript: GDScript = preload("res://scripts/ui/world3d/World3DAssets.gd")
const World3DLightingScript: GDScript = preload("res://scripts/ui/world3d/World3DLighting.gd")
const MarkerLayerRendererScript: GDScript = preload("res://scripts/ui/world3d/MarkerLayerRenderer.gd")
const StaticEnvironmentBuilderScript: GDScript = preload("res://scripts/ui/world3d/StaticEnvironmentBuilder.gd")
const DynamicOozeRendererScript: GDScript = preload("res://scripts/ui/world3d/DynamicOozeRenderer.gd")

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
const OOZE_MASK_SCALE: int = 16
const OOZE_MASK_SMOOTH_PASSES: int = 2
const OOZE_ENABLE_FRAGMENTED_SURFACE_DETAILS: bool = false
const PHASED_BUILD_MODE_ENABLED: bool = false
const ASSET_MANIFEST_PATH: String = "res://data/world3d_asset_manifest.json"
const FLOOR_SURFACE_TOP_OFFSET: float = 0.115
const OOZE_SURFACE_OFFSET: float = 0.090
const OOZE_BASE_SURFACE_OFFSET: float = 0.165
const OOZE_GROWTH_BASE_OFFSET: float = 0.180
const OOZE_BASE_THICKNESS: float = 0.30
const OOZE_MIN_VALUE: float = 0.48
const OOZE_MIN_LUMA: float = 0.20
const OOZE_MAX_SATURATION: float = 1.0
const OOZE_GROWTH_MIN_VALUE: float = 0.50
const OOZE_GROWTH_MIN_LUMA: float = 0.21
const INNER_WALL_TILE_FOOTPRINT: float = 0.86
const INNER_WALL_HEIGHT: float = 1.82
const FRONT_WALL_CUTOUT_MIN: float = 0.24
const FRONT_WALL_CUTOUT_MAX: float = 0.76

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
	"background_color": Color(0.040, 0.040, 0.044, 1.0),
	"ambient_color": Color(0.52, 0.52, 0.51, 1.0),
	"ambient_energy": 0.96,
	"brightness": 1.06,
	"contrast": 1.08,
	"saturation": 0.78,
	"fog_enabled": true,
	"fog_density": 0.003,
}
const STABILIZATION_LIGHT_BASELINE := {
	"key_energy": 0.32,
	"fill_energy": 0.62,
	"fill_range": 42.0,
	"rim_energy": 0.14,
}

const POOL_SHADER_CODE: String = """
shader_type spatial;
render_mode blend_mix, diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 owner_color : source_color = vec4(0.3, 0.9, 0.8, 1.0);
uniform sampler2D mask_tex;
uniform sampler2D detail_tex;
uniform vec2 texel_size = vec2(0.01, 0.01);
uniform float pulse_speed = 0.22;
uniform float bubble_strength = 0.0015;
uniform float emission_strength = 0.007;
uniform float detail_scale = 6.2;
uniform float body_thickness = 0.010;
uniform float lip_thickness = 0.018;
uniform float flow_scale = 1.34;
uniform float flow_speed = 0.010;
uniform float flow_normal_strength = 0.32;
uniform float edge_darkening_strength = 0.22;
uniform float contact_darkening_strength = 0.14;
uniform float clearcoat_strength = 0.56;
uniform float specular_strength = 0.50;
uniform float rim_highlight_strength = 0.18;
uniform float acid_glow_strength = 0.020;
uniform float edge_wobble_strength = 0.055;
uniform float inner_pulse_strength = 0.010;
uniform float bubble_pop_strength = 0.20;

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
	float slow_pulse = sin(TIME * (pulse_speed * 1.9) + fbm(UV * 3.4) * 6.2831);
	float bubble_lift = smoothstep(0.68, 0.96, fbm(UV * 18.0 + vec2(TIME * 0.11, -TIME * 0.09)));
	VERTEX.y += body * body_thickness * (0.55 + bulge * 0.65)
		+ lip * lip_thickness
		+ flow * bubble_strength
		+ wave * bubble_strength * 0.40
		+ body * slow_pulse * inner_pulse_strength
		+ body * bubble_lift * bubble_strength * 1.75;
}

void fragment() {
	float m0 = texture(mask_tex, UV).a;
	// Keep wall carving absolute; do not blur back into blocked pixels.
	float mask = m0;
	float boundary_noise = fbm(UV * 28.0 + vec2(TIME * 0.018, -TIME * 0.014));
	float edge_zone = 1.0 - smoothstep(0.58, 0.96, mask);
	float alpha_threshold = 0.10 + boundary_noise * edge_wobble_strength * edge_zone;
	float alpha = smoothstep(alpha_threshold, 0.92, mask);
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
	float veins = smoothstep(0.56, 0.88, fbm(flow_uv * 0.42 + vec2(TIME * 0.04, -TIME * 0.03)));
	float shimmer = 0.5 + 0.5 * sin(TIME * pulse_speed + UV.x * 2.0 + UV.y * 1.7);
	vec2 bubble_grid = UV * vec2(18.0, 12.0);
	vec2 bubble_cell = floor(bubble_grid);
	vec2 bubble_uv = fract(bubble_grid);
	float bubble_seed = hash12(bubble_cell);
	vec2 bubble_center = vec2(0.30 + hash12(bubble_cell + vec2(4.1, 1.7)) * 0.40, 0.30 + hash12(bubble_cell + vec2(2.3, 8.9)) * 0.40);
	float bubble_phase = fract(TIME * (0.10 + bubble_seed * 0.06) + bubble_seed);
	float bubble_dist = length(bubble_uv - bubble_center);
	float bubble_ring = smoothstep(0.115 + bubble_phase * 0.11, 0.045 + bubble_phase * 0.11, abs(bubble_dist - (0.035 + bubble_phase * 0.095)));
	float bubble_flash = bubble_ring * smoothstep(0.72, 0.98, bubble_phase) * smoothstep(0.20, 0.82, body) * (1.0 - edge * 0.60);
	float living_pulse = 0.5 + 0.5 * sin(TIME * pulse_speed * 2.2 + broad * 4.8);

	vec2 normal_xy = flow_grad * flow_normal_strength + grad * edge * 0.34;
	normal_xy += (bubble_uv - bubble_center) * bubble_flash * 0.16;
	vec3 mapped_normal = normalize(vec3(normal_xy, 1.0));
	NORMAL_MAP = mapped_normal * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	vec3 acid_shadow = vec3(0.025, 0.032, 0.030);
	vec3 dark_tint = mix(owner_color.rgb * 0.34, acid_shadow, 0.38);
	vec3 mid_tint = mix(owner_color.rgb * 0.74, vec3(0.08, 0.12, 0.10), 0.16);
	vec3 col = mix(dark_tint, mid_tint, body);
	col *= 0.76 + broad * 0.14 + shimmer * 0.035 + living_pulse * inner_pulse_strength * 1.8;
	col = mix(col, col * 1.16, veins * 0.14 * body);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.4);
	vec3 rim_col = mix(owner_color.rgb, vec3(0.92, 1.0, 0.86), 0.24);
	col = mix(col, col * 0.76, edge * edge_darkening_strength);
	col = mix(col, col * 0.78, edge * contact_darkening_strength);
	col += rim_col * fres * rim_highlight_strength * (0.48 + edge * 0.30 + body * 0.12);
	col += rim_col * veins * body * 0.018;
	col += rim_col * bubble_flash * bubble_pop_strength * 0.24;

	ALBEDO = col;
	ROUGHNESS = clamp(0.62 - body * 0.08 + (1.0 - broad) * 0.12 + edge * 0.08, 0.38, 0.86);
	METALLIC = 0.0;
	SPECULAR = specular_strength + fres * 0.08;
	CLEARCOAT = clearcoat_strength * (0.34 + edge * 0.12);
	EMISSION = owner_color.rgb * emission_strength * (0.14 + edge * 0.24 + broad * 0.06)
		+ rim_col * acid_glow_strength * fres * (0.30 + edge * 0.24)
		+ rim_col * acid_glow_strength * veins * body * 0.11
		+ rim_col * bubble_flash * bubble_pop_strength * 0.12;
	ALPHA = clamp(alpha * (0.98 + edge * 0.04), 0.0, 1.0);
}
"""

const STONE_SHADER_CODE: String = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec4 stone_base : source_color = vec4(0.30, 0.24, 0.19, 1.0);
uniform vec4 stone_alt : source_color = vec4(0.19, 0.16, 0.14, 1.0);
uniform vec4 damp_tint : source_color = vec4(0.08, 0.12, 0.14, 1.0);
uniform float uv_scale = 12.0;
uniform sampler2D detail_albedo_tex : source_color;
uniform sampler2D detail_roughness_tex;
uniform sampler2D detail_normal_tex : hint_normal;
uniform float detail_mix = 0.62;
uniform float normal_strength = 0.52;
uniform float height_amp = 0.016;
uniform float tile_variation_strength = 0.035;
uniform float seam_strength = 0.40;
uniform float detail_color_strength = 0.018;
uniform float min_midtone = 0.250;
uniform float max_midtone = 0.430;

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
	VERTEX.y += disp * height_amp * 0.18;
}

void fragment() {
	vec2 tile_coord = floor(UV);
	vec2 tile_uv = fract(UV);
	vec2 tile_edge_dist = abs(tile_uv - vec2(0.5));
	float tile_hash = hash(tile_coord + vec2(13.0, 29.0));
	float stone_mix = clamp(0.60 + (tile_hash - 0.5) * tile_variation_strength, 0.0, 1.0);
	float seam = smoothstep(0.438, 0.494, max(tile_edge_dist.x, tile_edge_dist.y));
	float fine_wear = noise(UV * max(1.0, uv_scale * 0.20) + vec2(2.1, 4.7));
	float seam_crack_noise = noise(tile_coord * 1.73 + vec2(tile_uv.x * 7.0, tile_uv.y * 7.0));
	float cracks = seam * smoothstep(0.62, 0.92, seam_crack_noise);
	vec2 tex_uv = UV * max(1.0, uv_scale * 0.08);
	vec3 detail_col = texture(detail_albedo_tex, tex_uv).rgb;
	float detail_rough = texture(detail_roughness_tex, tex_uv).r;
	vec3 detail_nrm = texture(detail_normal_tex, tex_uv).rgb;
	vec3 stone = mix(stone_alt.rgb, stone_base.rgb, stone_mix);
	stone = mix(stone, detail_col, detail_mix * detail_color_strength);
	stone = mix(stone, damp_tint.rgb, cracks * 0.10);
	stone = mix(stone, stone * 0.82, seam * seam_strength + cracks * 0.18);
	stone = mix(stone, stone * 1.025, fine_wear * 0.045);
	float view_rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	stone = mix(stone, stone * 1.045, view_rim * 0.10);
	float stone_luma = dot(stone, vec3(0.299, 0.587, 0.114));
	stone = mix(vec3(stone_luma), stone, 0.08);
	stone = clamp(stone, vec3(min_midtone, min_midtone + 0.005, min_midtone + 0.008), vec3(max_midtone, max_midtone + 0.005, max_midtone + 0.008));
	ALBEDO = stone;
	ROUGHNESS = clamp(0.80 + seam * 0.08 + detail_rough * 0.035, 0.66, 0.98);
	METALLIC = 0.0;
	SPECULAR = 0.12;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), detail_nrm, normal_strength * 0.22);
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

var tile_world_size: float = 1.0

var _state: GameState = null
var _palette_renderer: BoardRenderer = null
var _pool_material_cache: Dictionary = {}
var _owner_mask_texture_cache: Dictionary = {}
var _shell_material_cache: Dictionary = {}
var _growth_material_template_cache: Dictionary = {}
var _ground_tops: Dictionary = {}
var _floor_surface_tops: Dictionary = {}
var _ooze_surface_mesh_cache: Dictionary = {}

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
var _valid_place_targets: Array = []
var _enemy_intent_actions: Array = []

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
var _growth_pool_root: Node3D = null
var _dynamic_light_root: Node3D = null
var _marker_root: Node3D = null
var _combat_feedback_root: Node3D = null
var _combat_feedback_time: float = 0.0
var _hero_shot_root: Node3D = null
var _camera: Camera3D = null
var _key_light: DirectionalLight3D = null
var _rim_light: DirectionalLight3D = null
var _fill_light: OmniLight3D = null
var _environment: WorldEnvironment = null
var _point_lights: Array[OmniLight3D] = []
var _wall_lights: Array[OmniLight3D] = []
var _hero_shot_lights: Array[OmniLight3D] = []
var _play_area_fill_light: OmniLight3D = null
var _dynamic_light_pool: Dictionary = {}
var _growth_anim_entries: Array[Dictionary] = []
var _growth_asset_pool: Dictionary = {}
var _active_growth_asset_nodes: Array[Node3D] = []
var _rendered_inner_wall_tiles: Dictionary = {}
var _rendered_owner_tiles_by_owner: Dictionary = {}

var _stone_texture_cache: Texture2D = null
var _stone_roughness_texture_cache: Texture2D = null
var _stone_normal_texture_cache: Texture2D = null
var _slime_detail_texture_cache: Texture2D = null
var _asset_material_cache: Dictionary = {}
var _assets: RefCounted = World3DAssetsScript.new()
var _lighting: RefCounted = World3DLightingScript.new()
var _marker_layer: RefCounted = MarkerLayerRendererScript.new()
var _static_environment: RefCounted = StaticEnvironmentBuilderScript.new()
var _dynamic_ooze: RefCounted = DynamicOozeRendererScript.new()
var _perf_counters: Dictionary = {}
var _frame_time_accum: float = 0.0
var _frame_time_samples: int = 0
var _frame_time_max_ms: float = 0.0
var _growth_animation_time_accum_ms: float = 0.0
var _growth_animation_time_samples: int = 0
var _growth_animation_time_max_ms: float = 0.0
var _dynamic_rebuild_time_accum_ms: float = 0.0
var _dynamic_rebuild_time_samples: int = 0
var _dynamic_rebuild_time_max_ms: float = 0.0
var _dynamic_rebuild_time_last_ms: float = 0.0
var _perf_dynamic_rendering_enabled: bool = true
var _perf_growth_animation_enabled: bool = true
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

func apply_hero_shot_composition() -> void:
	if _state == null:
		return
	initialize_runtime_renderer()
	_clear_hero_shot_composition()
	_ensure_hero_shot_root()
	var focal_tile: Vector2i = _find_hero_focal_tile()
	_apply_hero_shot_lighting(focal_tile)
	_add_hero_shot_story_props(focal_tile)
	_add_hero_shot_ooze_presence(focal_tile)

func clear_hero_shot_composition() -> void:
	_clear_hero_shot_composition()

func sync_world(
	state: GameState,
	selected_tile: Vector2i,
	hovered_tile: Vector2i,
	queued_actions: Array,
	hover_preview_action: Dictionary,
	hover_invalid_reason: String,
	_recent_enemy_actions: Array,
	_anim_frame: int,
	valid_place_targets: Array = [],
	enemy_intent_actions: Array = []
) -> void:
	_perf_increment("sync_calls")
	_state = state
	_selected_tile = selected_tile
	_hovered_tile = hovered_tile
	_queued_tiles = _extract_queued_tiles(queued_actions)
	_queued_actions = queued_actions
	_hover_preview_action = hover_preview_action
	_hover_invalid_reason = hover_invalid_reason
	_valid_place_targets = valid_place_targets
	_enemy_intent_actions = enemy_intent_actions
	if _state == null:
		return

	_refresh_board_bounds()

	var static_stamp: String = _make_static_stamp()
	if static_stamp != _last_static_stamp:
		_perf_increment("static_stamp_changes")
		_rebuild_static_world()
		_last_static_stamp = static_stamp
		_last_dynamic_stamp = ""
		_last_marker_stamp = ""

	var dynamic_stamp: String = _make_dynamic_stamp()
	if dynamic_stamp != _last_dynamic_stamp:
		_perf_increment("dynamic_stamp_changes")
		_rebuild_dynamic_world()
		_last_dynamic_stamp = dynamic_stamp

	var marker_stamp: String = _make_marker_stamp()
	if marker_stamp != _last_marker_stamp:
		_perf_increment("marker_stamp_changes")
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
	_update_combat_feedback(maxf(0.0, delta))
	var frame_ms: float = maxf(0.0, delta) * 1000.0
	_frame_time_accum += frame_ms
	_frame_time_samples += 1
	_frame_time_max_ms = maxf(_frame_time_max_ms, frame_ms)
	_animate_lights()
	if _perf_growth_animation_enabled:
		var growth_anim_start_usec: int = Time.get_ticks_usec()
		_animate_growth_assets()
		var growth_anim_ms: float = float(Time.get_ticks_usec() - growth_anim_start_usec) / 1000.0
		_growth_animation_time_accum_ms += growth_anim_ms
		_growth_animation_time_samples += 1
		_growth_animation_time_max_ms = maxf(_growth_animation_time_max_ms, growth_anim_ms)
	_update_camera_transform(false)

func show_combat_events(events: Array) -> void:
	if _combat_feedback_root == null:
		_combat_feedback_root = Node3D.new()
		_combat_feedback_root.name = "CombatFeedback"
		add_child(_combat_feedback_root)
	_clear_children(_combat_feedback_root)
	_combat_feedback_time = 1.8
	for event in events:
		var label: Label3D = Label3D.new()
		var dissolved: bool = String(event.get("kind", "")) == "dissolved"
		label.text = "Dissolved" if dissolved else "-%d" % int(event.get("amount", 0))
		label.font_size = 38 if dissolved else 48
		label.outline_size = 8
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color(1.0, 0.86, 0.64) if dissolved else Color(1.0, 0.57, 0.32)
		var tile: Vector2i = event.get("tile", Vector2i.ZERO)
		label.position = _tile_world_position(tile) + Vector3(0.0, _tile_floor_top(tile) + tile_world_size * 0.95, 0.0)
		_combat_feedback_root.add_child(label)

func _update_combat_feedback(delta: float) -> void:
	if _combat_feedback_root == null or _combat_feedback_time <= 0.0:
		return
	_combat_feedback_time = maxf(0.0, _combat_feedback_time - delta)
	if _combat_feedback_time <= 0.0:
		_clear_children(_combat_feedback_root)
		return
	for label in _combat_feedback_root.get_children():
		label.position.y += delta * 0.22
		label.modulate.a = minf(1.0, _combat_feedback_time / 0.45)

func set_perf_dynamic_rendering_enabled(enabled: bool) -> void:
	_perf_dynamic_rendering_enabled = enabled
	if not enabled:
		_release_active_growth_asset_nodes()
		_clear_children(_dynamic_root)
		_point_lights.clear()
		_growth_anim_entries.clear()
		_rendered_owner_tiles_by_owner.clear()

func set_perf_growth_animation_enabled(enabled: bool) -> void:
	_perf_growth_animation_enabled = enabled

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

	_growth_pool_root = Node3D.new()
	_growth_pool_root.name = "GrowthPoolRoot"
	_growth_pool_root.visible = false
	add_child(_growth_pool_root)

	_dynamic_light_root = Node3D.new()
	_dynamic_light_root.name = "DynamicLightRoot"
	add_child(_dynamic_light_root)

	_marker_root = Node3D.new()
	_marker_root.name = "MarkerRoot"
	add_child(_marker_root)

	_hero_shot_root = Node3D.new()
	_hero_shot_root.name = "HeroShotRoot"
	add_child(_hero_shot_root)

	_camera = Camera3D.new()
	_camera.name = "TacticalCamera3D"
	_camera.current = true
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 34.0
	_camera.near = 0.05
	_camera.far = 240.0
	add_child(_camera)

	var lighting_nodes: Dictionary = _lighting.create_base_lighting(
		self,
		STABILIZATION_ENV_BASELINE,
		STABILIZATION_LIGHT_BASELINE
	)
	_key_light = lighting_nodes.get("key_light", null)
	_rim_light = lighting_nodes.get("rim_light", null)
	_fill_light = lighting_nodes.get("fill_light", null)
	_environment = lighting_nodes.get("environment", null)

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
	var wall_signature: int = 0
	var wall_keys: Array = _state.wall_tiles.keys()
	wall_keys.sort()
	for key_variant in wall_keys:
		var wall_key: String = String(key_variant)
		wall_signature = int(wall_signature * 131 + hash(wall_key))
	var bounds: Dictionary = _layout_outer_bounds_tiles()
	var min_tile: Vector2i = bounds.get("min", Vector2i(0, 0))
	var max_tile: Vector2i = bounds.get("max", Vector2i(_state.width - 1, _state.height - 1))
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		_state.width,
		_state.height,
		_state.level_index,
		_state.wall_tiles.size(),
		min_tile.x,
		min_tile.y,
		max_tile.x,
		max_tile.y,
		_state.entrance_tile.x,
		_state.entrance_tile.y,
		_state.door_tile.x,
		_state.door_tile.y,
		wall_signature,
	]

func _make_dynamic_stamp() -> String:
	var resource_signature: int = 0
	for node in _state.resource_nodes:
		var resource_tile: Vector2i = node.get("pos", Vector2i(-1, -1))
		resource_signature = int(
			resource_signature * 131
			+ resource_tile.x * 97
			+ resource_tile.y * 193
			+ hash(String(node.get("kind", "gem")))
			+ (17 if bool(node.get("consumed", false)) else 0)
		)
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
		block_signature + resource_signature,
	]

func _make_marker_stamp() -> String:
	return _marker_layer.make_marker_stamp(
		_state,
		_selected_tile,
		_hovered_tile,
		_queued_tiles,
		_queued_actions,
		_hover_preview_action,
		_hover_invalid_reason,
		_valid_place_targets,
		_enemy_intent_actions
	)

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
			normals[idx] = tz.cross(tx).normalized()
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

func _sample_ground_height_at_local(local_x: float, local_z: float, board_width: float, board_height: float) -> float:
	if _state == null:
		return 0.0
	var nx: float = clampf((local_x / maxf(0.001, board_width)) + 0.5, 0.0, 1.0)
	var nz: float = clampf((local_z / maxf(0.001, board_height)) + 0.5, 0.0, 1.0)
	var px: float = nx * float(maxi(1, _state.width - 1))
	var py: float = nz * float(maxi(1, _state.height - 1))
	var x0: int = clampi(int(floor(px)), 0, _state.width - 1)
	var y0: int = clampi(int(floor(py)), 0, _state.height - 1)
	var x1: int = mini(_state.width - 1, x0 + 1)
	var y1: int = mini(_state.height - 1, y0 + 1)
	var tx: float = px - float(x0)
	var ty: float = py - float(y0)
	var h00: float = _tile_floor_top(Vector2i(x0, y0))
	var h10: float = _tile_floor_top(Vector2i(x1, y0))
	var h01: float = _tile_floor_top(Vector2i(x0, y1))
	var h11: float = _tile_floor_top(Vector2i(x1, y1))
	var hx0: float = lerpf(h00, h10, tx)
	var hx1: float = lerpf(h01, h11, tx)
	return lerpf(hx0, hx1, ty)

func _rebuild_static_world() -> void:
	_perf_increment("static_rebuilds")
	_ooze_surface_mesh_cache.clear()
	_owner_mask_texture_cache.clear()
	var built: bool = _static_environment.build_static_world(
		self,
		_terrain_root,
		_state,
		tile_world_size,
		_board_min,
		_board_max,
		_camera_base_target,
		_ground_tops,
		_floor_surface_tops,
		_rendered_inner_wall_tiles
	)
	if built:
		_add_chamber_accent_lights()

func _layout_outer_bounds_tiles() -> Dictionary:
	return _static_environment.layout_outer_bounds_tiles(_state)

func _rebuild_dynamic_world() -> void:
	var rebuild_start_usec: int = Time.get_ticks_usec()
	_perf_increment("dynamic_rebuilds")
	var active_mask_cache_keys: Dictionary = {}
	_release_active_growth_asset_nodes()
	_clear_children(_dynamic_root)
	_point_lights.clear()
	_growth_anim_entries.clear()
	_rendered_owner_tiles_by_owner.clear()
	_begin_dynamic_light_sync()
	if _state == null or not _perf_dynamic_rendering_enabled:
		_end_dynamic_light_sync({})
		_prune_owner_mask_texture_cache(active_mask_cache_keys)
		_record_dynamic_rebuild_time(rebuild_start_usec)
		return

	var active_light_keys: Dictionary = {}
	var owner_blocks: Dictionary = {}
	for block in _state.blocks.values():
		var owner_id_local: int = int(block.get("owner", 0))
		if not owner_blocks.has(owner_id_local):
			owner_blocks[owner_id_local] = []
		owner_blocks[owner_id_local].append(block)

	for owner_variant in owner_blocks.keys():
		var owner_id: int = int(owner_variant)
		var blocks: Array = owner_blocks[owner_id]
		var owner_layers_start: int = Time.get_ticks_usec()
		_dynamic_ooze.build_owner_layers(
			self,
			_dynamic_root,
			_state,
			tile_world_size,
			_camera_base_target,
			_owner_mask_texture_cache,
			active_mask_cache_keys,
			_ooze_surface_mesh_cache,
			_rendered_owner_tiles_by_owner,
			_growth_anim_entries,
			owner_id,
			blocks,
			OOZE_ENABLE_FRAGMENTED_SURFACE_DETAILS
		)
		_perf_record_time("profile_owner_layers", owner_layers_start)
		var owner_light_start: int = Time.get_ticks_usec()
		_add_owner_zone_light(owner_id, blocks, active_light_keys)
		_perf_record_time("profile_owner_lights", owner_light_start)

	_prune_owner_mask_texture_cache(active_mask_cache_keys)
	var world_points_start: int = Time.get_ticks_usec()
	_build_world_points()
	_perf_record_time("profile_world_points", world_points_start)
	var objective_lights_start: int = Time.get_ticks_usec()
	_add_objective_glow_lights(active_light_keys)
	_perf_record_time("profile_objective_lights", objective_lights_start)
	_end_dynamic_light_sync(active_light_keys)
	_record_dynamic_rebuild_time(rebuild_start_usec)

func _prune_owner_mask_texture_cache(active_mask_cache_keys: Dictionary) -> void:
	var pruned_count: int = 0
	for key_variant in _owner_mask_texture_cache.keys():
		var key: String = String(key_variant)
		if active_mask_cache_keys.has(key):
			continue
		_owner_mask_texture_cache.erase(key)
		pruned_count += 1
	if pruned_count > 0:
		_perf_increment("mask_cache_prunes")
		_perf_increment("mask_cache_pruned_entries", pruned_count)

func _record_dynamic_rebuild_time(start_usec: int) -> void:
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	_dynamic_rebuild_time_last_ms = elapsed_ms
	_dynamic_rebuild_time_accum_ms += elapsed_ms
	_dynamic_rebuild_time_samples += 1
	_dynamic_rebuild_time_max_ms = maxf(_dynamic_rebuild_time_max_ms, elapsed_ms)

func _animate_growth_assets() -> void:
	for entry in _growth_anim_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var node: Node3D = entry.get("node", null)
		if node == null or not is_instance_valid(node):
			continue
		var base_tf: Transform3D = entry.get("base_tf", node.transform)
		var role: String = String(entry.get("role", "gather"))
		var phase: float = float(entry.get("phase", 0.0))
		var tier: int = clampi(int(entry.get("tier", 0)), 0, 3)
		var t: float = _visual_time + phase

		var pulse_amp: float = 0.035
		var pulse_speed: float = 1.2
		var sway_amp: float = deg_to_rad(1.1)
		var sway_speed: float = 0.9
		var bob_amp: float = 0.010
		var scale_mul: Vector3 = Vector3.ONE
		match role:
			"core":
				pulse_amp = 0.055
				pulse_speed = 0.84
				sway_amp = deg_to_rad(0.8)
				sway_speed = 0.66
				bob_amp = 0.014
			"melee":
				pulse_amp = 0.030
				pulse_speed = 1.40
				sway_amp = deg_to_rad(2.2)
				sway_speed = 1.32
				bob_amp = 0.009
			"ranged":
				pulse_amp = 0.036
				pulse_speed = 1.08
				sway_amp = deg_to_rad(1.6)
				sway_speed = 1.06
				bob_amp = 0.012
				scale_mul.y += 0.08 * (0.5 + 0.5 * sin(t * 1.9))
			"defense":
				pulse_amp = 0.018
				pulse_speed = 0.72
				sway_amp = deg_to_rad(0.5)
				sway_speed = 0.62
				bob_amp = 0.006
			"gather":
				pulse_amp = 0.044
				pulse_speed = 1.54
				sway_amp = deg_to_rad(1.2)
				sway_speed = 1.18
				bob_amp = 0.010
		var tier_mul: float = 1.0 + float(tier) * 0.10
		pulse_amp *= tier_mul
		bob_amp *= tier_mul

		var pulse: float = 1.0 + pulse_amp * sin(t * pulse_speed)
		scale_mul *= pulse
		var sway_x: float = sin(t * sway_speed) * sway_amp
		var sway_z: float = cos(t * (sway_speed * 0.82 + 0.11)) * sway_amp * 0.72
		var bob: float = sin(t * (pulse_speed * 0.58 + 0.22)) * bob_amp

		var base_scale: Vector3 = base_tf.basis.get_scale()
		var base_rot: Basis = base_tf.basis.orthonormalized()
		var sway_basis: Basis = Basis(Vector3.RIGHT, sway_x) * Basis(Vector3.FORWARD, sway_z)
		var animated_scale: Vector3 = Vector3(
			base_scale.x * scale_mul.x,
			base_scale.y * scale_mul.y,
			base_scale.z * scale_mul.z
		)
		var animated_basis: Basis = (base_rot * sway_basis).scaled(animated_scale)
		node.transform = Transform3D(animated_basis, base_tf.origin + Vector3(0.0, bob, 0.0))

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

func _begin_dynamic_light_sync() -> void:
	_perf_increment("light_rebuild_passes")
	for light_variant in _dynamic_light_pool.values():
		var light: OmniLight3D = light_variant as OmniLight3D
		if light == null or not is_instance_valid(light):
			continue
		light.visible = false

func _end_dynamic_light_sync(active_light_keys: Dictionary) -> void:
	if _dynamic_light_root == null:
		return
	for key_variant in _dynamic_light_pool.keys():
		var key: String = String(key_variant)
		var light: OmniLight3D = _dynamic_light_pool[key] as OmniLight3D
		if light == null or not is_instance_valid(light):
			continue
		light.visible = active_light_keys.has(key)

func _claim_dynamic_light(key: String, active_light_keys: Dictionary) -> OmniLight3D:
	active_light_keys[key] = true
	var light: OmniLight3D = _dynamic_light_pool.get(key, null) as OmniLight3D
	if light == null or not is_instance_valid(light):
		light = OmniLight3D.new()
		light.name = "DynamicLight_%s" % key.replace(":", "_").replace(",", "_")
		light.shadow_enabled = false
		_dynamic_light_pool[key] = light
		_perf_increment("lights_created")
		if _dynamic_light_root != null:
			_dynamic_light_root.add_child(light)
	elif light.get_parent() == null and _dynamic_light_root != null:
		_dynamic_light_root.add_child(light)
	light.visible = true
	if not _point_lights.has(light):
		_point_lights.append(light)
	return light

func _configure_dynamic_light(
	light: OmniLight3D,
	light_position: Vector3,
	color: Color,
	energy: float,
	omni_range: float
) -> void:
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.set_meta("base_energy", energy)
	light.omni_range = omni_range
	light.shadow_enabled = false

func _add_objective_glow_lights(active_light_keys: Dictionary) -> void:
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
		var glow_color: Color = _owner_tint(owner_id).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.10)
		var light: OmniLight3D = _claim_dynamic_light("heart:%s" % _tile_key(tile), active_light_keys)
		_configure_dynamic_light(
			light,
			_tile_world_position(tile) + Vector3(0.0, _tile_ground_top(tile) + 0.78, 0.0),
			glow_color,
			0.32,
			4.8
		)
		heart_lights_added += 1
		if heart_lights_added >= 4:
			break
	if _state.is_inside(_state.entrance_tile):
		var entry_light: OmniLight3D = _claim_dynamic_light("entrance", active_light_keys)
		_configure_dynamic_light(
			entry_light,
			_tile_world_position(_state.entrance_tile) + Vector3(0.0, _tile_ground_top(_state.entrance_tile) + 0.58, 0.0),
			Color(0.28, 0.60, 0.90, 1.0),
			0.76,
			3.8
		)
	if _state.door_hp > 0 and _state.is_inside(_state.door_tile):
		var door_light: OmniLight3D = _claim_dynamic_light("door", active_light_keys)
		_configure_dynamic_light(
			door_light,
			_tile_world_position(_state.door_tile) + Vector3(0.0, _tile_ground_top(_state.door_tile) + 0.64, 0.0),
			Color(0.94, 0.60, 0.28, 1.0),
			1.04,
			4.1
		)

func _add_owner_zone_light(owner_id: int, blocks: Array, active_light_keys: Dictionary) -> void:
	if blocks.is_empty():
		return
	var centroid: Vector3 = _owner_centroid(blocks)
	var nearest_tile: Vector2i = blocks[0].get("pos", Vector2i(-1, -1))
	var top: float = _tile_ground_top(nearest_tile) if _state != null and _state.is_inside(nearest_tile) else 0.0
	var strength: float = clampf(0.34 + float(blocks.size()) * 0.0060, 0.34, 0.72)
	var light: OmniLight3D = _claim_dynamic_light("owner:%d" % owner_id, active_light_keys)
	_configure_dynamic_light(
		light,
		centroid + Vector3(0.0, top + 0.88, 0.0),
		_owner_ooze_tint(owner_id).lerp(Color(1.0, 1.0, 1.0, 1.0), 0.02),
		strength,
		11.2
	)

func _rebuild_markers() -> void:
	_perf_increment("marker_rebuilds")
	_marker_layer.rebuild_markers(
		_marker_root,
		_state,
		tile_world_size,
		_board_min,
		_floor_surface_tops,
		_selected_tile,
		_hovered_tile,
		_queued_tiles,
		_queued_actions,
		_hover_preview_action,
		_hover_invalid_reason,
		_valid_place_targets,
		_enemy_intent_actions
	)

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

func _add_chamber_accent_lights() -> void:
	if _state == null:
		return
	_wall_lights.clear()
	_play_area_fill_light = null
	var board_w: float = float(_state.width) * tile_world_size
	var board_h: float = float(_state.height) * tile_world_size
	var inside: float = tile_world_size * 0.48
	var center_x: float = (_board_min.x + _board_max.x) * 0.5
	var center_z: float = (_board_min.z + _board_max.z) * 0.5
	var entries: Array[Dictionary] = [
		{"pos": Vector3(_board_min.x + inside, 0.0, center_z), "energy": 2.25, "range": 10.4, "phase": 0.0},
		{"pos": Vector3(_board_max.x - inside, 0.0, center_z), "energy": 2.35, "range": 10.8, "phase": 1.3},
		{"pos": Vector3(_board_min.x + inside, 0.0, _board_min.z + inside), "energy": 1.52, "range": 8.2, "phase": 2.4},
		{"pos": Vector3(_board_max.x - inside, 0.0, _board_min.z + inside), "energy": 1.52, "range": 8.2, "phase": 3.2},
		{"pos": Vector3(_board_min.x + inside, 0.0, _board_max.z - inside), "energy": 1.45, "range": 8.0, "phase": 4.1},
		{"pos": Vector3(_board_max.x - inside, 0.0, _board_max.z - inside), "energy": 1.45, "range": 8.0, "phase": 5.0},
	]
	for entry in entries:
		var pos: Vector3 = entry["pos"]
		var local_x: float = pos.x - _camera_base_target.x
		var local_z: float = pos.z - _camera_base_target.z
		var ground_y: float = _sample_ground_height_at_local(local_x, local_z, board_w, board_h)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "HiddenWallTorchLight"
		light.position = Vector3(pos.x, ground_y + 2.25, pos.z)
		light.light_color = Color(1.0, 0.74, 0.46, 1.0)
		light.light_energy = float(entry["energy"])
		light.set_meta("base_energy", float(entry["energy"]))
		light.set_meta("flicker_phase", float(entry["phase"]))
		light.omni_range = float(entry["range"])
		light.shadow_enabled = false
		_terrain_root.add_child(light)
		_wall_lights.append(light)

	_play_area_fill_light = OmniLight3D.new()
	_play_area_fill_light.name = "HiddenPlayAreaWarmFill"
	_play_area_fill_light.position = _camera_base_target + Vector3(0.0, 6.2, 0.0)
	_play_area_fill_light.light_color = Color(0.86, 0.78, 0.66, 1.0)
	_play_area_fill_light.light_energy = 2.75
	_play_area_fill_light.omni_range = maxf(board_w, board_h) * 1.05
	_play_area_fill_light.shadow_enabled = false
	_terrain_root.add_child(_play_area_fill_light)

func _ensure_hero_shot_root() -> void:
	if _hero_shot_root != null and is_instance_valid(_hero_shot_root):
		return
	_hero_shot_root = Node3D.new()
	_hero_shot_root.name = "HeroShotRoot"
	add_child(_hero_shot_root)

func _clear_hero_shot_composition() -> void:
	if _hero_shot_root != null and is_instance_valid(_hero_shot_root):
		_clear_children(_hero_shot_root)
	_hero_shot_lights.clear()

func _find_hero_focal_tile() -> Vector2i:
	if _state == null:
		return Vector2i(-1, -1)
	var best_tile: Vector2i = _state.door_tile if _state.is_inside(_state.door_tile) else Vector2i(int(floor(float(_state.width) * 0.5)), int(floor(float(_state.height) * 0.5)))
	var best_score: int = 999999
	for block_a_variant in _state.blocks.values():
		var block_a: Dictionary = block_a_variant
		var owner_a: int = int(block_a.get("owner", -1))
		var tile_a: Vector2i = block_a.get("pos", Vector2i(-1, -1))
		if owner_a <= 0 or not _state.is_inside(tile_a):
			continue
		for block_b_variant in _state.blocks.values():
			var block_b: Dictionary = block_b_variant
			var owner_b: int = int(block_b.get("owner", -1))
			if owner_b <= 0 or owner_b == owner_a:
				continue
			var tile_b: Vector2i = block_b.get("pos", Vector2i(-1, -1))
			if not _state.is_inside(tile_b):
				continue
			var dist: int = abs(tile_a.x - tile_b.x) + abs(tile_a.y - tile_b.y)
			if dist >= best_score:
				continue
			var mid: Vector2i = Vector2i(int(round(float(tile_a.x + tile_b.x) * 0.5)), int(round(float(tile_a.y + tile_b.y) * 0.5)))
			if _state.is_inside(mid) and not _state.wall_tiles.has(_tile_key(mid)):
				best_score = dist
				best_tile = mid
	return best_tile

func _apply_hero_shot_lighting(focal_tile: Vector2i) -> void:
	var focal: Vector3 = _tile_world_position(focal_tile)
	var focal_top: float = _tile_floor_top(focal_tile)
	if _environment != null and _environment.environment != null:
		var env: Environment = _environment.environment
		env.background_color = Color(0.032, 0.032, 0.036, 1.0)
		env.ambient_light_color = Color(0.54, 0.54, 0.52, 1.0)
		env.ambient_light_energy = 0.66
		env.adjustment_brightness = 1.03
		env.adjustment_contrast = 1.12
		env.adjustment_saturation = 0.90
	if _key_light != null:
		_key_light.light_color = Color(0.82, 0.80, 0.76, 1.0)
		_key_light.light_energy = 0.28
		_key_light.shadow_enabled = true
	if _fill_light != null:
		_fill_light.light_energy = 0.72
		_fill_light.omni_range = 42.0
	if _rim_light != null:
		_rim_light.light_color = Color(0.34, 0.40, 0.50, 1.0)
		_rim_light.light_energy = 0.20

	var torch_pos: Vector3 = focal + Vector3(-2.4, focal_top + 2.5, -2.1)
	_add_hero_omni_light("HeroShotFocalTorch", torch_pos, Color(1.0, 0.63, 0.30, 1.0), 4.7, 8.8, true)
	_add_hero_omni_light("HeroShotBoardReadabilityFill", _camera_base_target + Vector3(0.0, 7.4, 0.0), Color(0.74, 0.72, 0.68, 1.0), 1.20, maxf(float(_state.width), float(_state.height)) * tile_world_size * 0.92, false)
	_add_hero_omni_light("HeroShotOozeRim", focal + Vector3(2.6, focal_top + 1.35, 1.9), Color(0.45, 0.90, 0.64, 1.0), 0.74, 5.4, false)
	_add_hero_omni_light("HeroShotDoorAccent", _tile_world_position(_state.door_tile) + Vector3(0.0, _tile_floor_top(_state.door_tile) + 1.55, 0.0), Color(1.0, 0.70, 0.40, 1.0), 1.15, 5.8, true)

func _add_hero_omni_light(name: String, position: Vector3, color: Color, energy: float, light_range: float, shadows: bool) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.set_meta("base_energy", energy)
	light.set_meta("flicker_phase", float(_hero_shot_lights.size()) * 1.71)
	light.omni_range = light_range
	light.shadow_enabled = shadows
	light.shadow_bias = 0.035
	_hero_shot_root.add_child(light)
	_hero_shot_lights.append(light)

func _add_hero_shot_story_props(focal_tile: Vector2i) -> void:
	var prop_tile: Vector2i = _find_nearby_empty_floor_tile(focal_tile, 3, Vector2i(-1, 1))
	var altar_tile: Vector2i = _find_nearby_empty_floor_tile(focal_tile, 4, Vector2i(2, -1))
	var rubble_tile: Vector2i = _find_nearby_empty_floor_tile(focal_tile, 3, Vector2i(1, 0))
	if _state.is_inside(prop_tile):
		_add_hero_skeleton_and_weapon(prop_tile)
	if _state.is_inside(altar_tile):
		_add_hero_cracked_altar(altar_tile)
	if _state.is_inside(rubble_tile):
		_add_hero_rubble_cluster(rubble_tile)

func _find_nearby_empty_floor_tile(origin: Vector2i, radius: int, preference: Vector2i) -> Vector2i:
	var best_tile: Vector2i = Vector2i(-1, -1)
	var best_score: int = 999999
	for y in range(origin.y - radius, origin.y + radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			var tile: Vector2i = Vector2i(x, y)
			if not _state.is_inside(tile):
				continue
			if _state.wall_tiles.has(_tile_key(tile)) or _tile_has_block(tile):
				continue
			var dx: int = tile.x - origin.x
			var dy: int = tile.y - origin.y
			var dist: int = abs(dx) + abs(dy)
			if dist <= 0 or dist > radius:
				continue
			var preference_score: int = abs(dx - preference.x) + abs(dy - preference.y)
			var score: int = dist * 10 + preference_score
			if score < best_score:
				best_score = score
				best_tile = tile
	return best_tile

func _tile_has_block(tile: Vector2i) -> bool:
	if _state == null:
		return false
	for block_variant in _state.blocks.values():
		var block: Dictionary = block_variant
		if block.get("pos", Vector2i(-999, -999)) == tile:
			return true
	return false

func _add_hero_skeleton_and_weapon(tile: Vector2i) -> void:
	var center: Vector3 = _tile_world_position(tile)
	var top: float = _tile_floor_top(tile)
	var base: Vector3 = center + Vector3(-0.10, top + 0.070, 0.04)
	var bone_mat: StandardMaterial3D = _hero_bone_material()
	var metal_mat: StandardMaterial3D = _hero_metal_material()
	_add_hero_bone("HeroShotSpine", base, 0.54, 0.030, 18.0, bone_mat)
	_add_hero_bone("HeroShotRibA", base + Vector3(0.09, 0.015, 0.03), 0.30, 0.020, 74.0, bone_mat)
	_add_hero_bone("HeroShotRibB", base + Vector3(-0.09, 0.015, -0.04), 0.28, 0.020, -58.0, bone_mat)
	_add_hero_box("HeroShotSkull", base + Vector3(0.32, 0.025, 0.12), Vector3(0.16, 0.12, 0.13), bone_mat, -18.0)
	_add_hero_bone("HeroShotBrokenSwordGrip", center + Vector3(0.23, top + 0.078, -0.26), 0.42, 0.018, -35.0, metal_mat)
	_add_hero_box("HeroShotBrokenSwordTip", center + Vector3(0.39, top + 0.080, -0.41), Vector3(0.20, 0.025, 0.055), metal_mat, -35.0)

func _add_hero_bone(name: String, position: Vector3, length: float, radius: float, yaw_degrees: float, mat: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.position = position
	inst.rotation_degrees = Vector3(90.0, yaw_degrees, 0.0)
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hero_shot_root.add_child(inst)

func _add_hero_cracked_altar(tile: Vector2i) -> void:
	var center: Vector3 = _tile_world_position(tile)
	var top: float = _tile_floor_top(tile)
	var mat: StandardMaterial3D = _hero_dark_stone_material()
	_add_hero_box("HeroShotCrackedAltarBase", center + Vector3(0.0, top + 0.13, 0.0), Vector3(0.74, 0.20, 0.48), mat, 8.0)
	_add_hero_box("HeroShotCrackedAltarSlab", center + Vector3(0.04, top + 0.28, -0.02), Vector3(0.88, 0.12, 0.56), mat, 8.0)
	_add_hero_box("HeroShotAltarBrokenCorner", center + Vector3(-0.36, top + 0.32, 0.21), Vector3(0.20, 0.10, 0.16), mat, -19.0)

func _add_hero_rubble_cluster(tile: Vector2i) -> void:
	var center: Vector3 = _tile_world_position(tile)
	var top: float = _tile_floor_top(tile)
	var mat: StandardMaterial3D = _hero_rubble_material()
	for i in range(5):
		var offset: Vector3 = Vector3(_noise01(tile.x * 31 + i, tile.y * 43) - 0.5, 0.0, _noise01(tile.x * 53, tile.y * 29 + i) - 0.5) * 0.58
		var size: Vector3 = Vector3(0.18 + 0.10 * _noise01(tile.x + i, tile.y), 0.08 + 0.08 * _noise01(tile.x, tile.y + i), 0.14 + 0.11 * _noise01(tile.x - i, tile.y + i))
		_add_hero_box("HeroShotRubble%d" % i, center + offset + Vector3(0.0, top + size.y * 0.5 + 0.035, 0.0), size, mat, float((i * 37 + tile.x * 11) % 90))

func _add_hero_shot_ooze_presence(focal_tile: Vector2i) -> void:
	var candidates: Array[Dictionary] = []
	for block_variant in _state.blocks.values():
		var block: Dictionary = block_variant
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if not _state.is_inside(tile):
			continue
		var dist: int = abs(tile.x - focal_tile.x) + abs(tile.y - focal_tile.y)
		if dist <= 3:
			candidates.append({"tile": tile, "owner_id": int(block.get("owner", 0)), "dist": dist})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("dist", 99)) < int(b.get("dist", 99))
	)
	var added: int = 0
	for entry in candidates:
		if added >= 4:
			break
		_add_hero_ooze_highlight_patch(entry["tile"], int(entry["owner_id"]), added)
		added += 1

func _add_hero_ooze_highlight_patch(tile: Vector2i, owner_id: int, index: int) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.radius = 0.5
	mesh.height = 1.0
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = "HeroShotThickOozeMass"
	inst.mesh = mesh
	var center: Vector3 = _tile_world_position(tile)
	var top: float = _tile_floor_top(tile)
	var yaw: float = float((tile.x * 73 + tile.y * 37 + index * 19) % 360)
	inst.position = center + Vector3(0.05 * sin(float(index)), top + OOZE_GROWTH_BASE_OFFSET + 0.015, 0.04 * cos(float(index) * 1.7))
	inst.rotation_degrees = Vector3(0.0, yaw, 0.0)
	inst.scale = Vector3(0.84, 0.105 + 0.018 * float(index % 2), 0.54)
	inst.material_override = _hero_ooze_accent_material(owner_id)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hero_shot_root.add_child(inst)

func _add_hero_box(name: String, position: Vector3, size: Vector3, mat: Material, yaw_degrees: float) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.position = position
	inst.rotation_degrees = Vector3(0.0, yaw_degrees, 0.0)
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_hero_shot_root.add_child(inst)

func _hero_bone_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.66, 0.55, 1.0)
	mat.roughness = 0.84
	mat.metallic = 0.0
	return mat

func _hero_metal_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.35, 0.35, 1.0)
	mat.roughness = 0.54
	mat.metallic = 0.28
	return mat

func _hero_dark_stone_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.24, 0.25, 0.25, 1.0)
	mat.roughness = 0.92
	mat.metallic = 0.0
	return mat

func _hero_rubble_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.31, 0.31, 1.0)
	mat.roughness = 0.94
	mat.metallic = 0.0
	return mat

func _hero_ooze_accent_material(owner_id: int) -> StandardMaterial3D:
	var tint: Color = _owner_ooze_tint(owner_id)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tint.lerp(Color(0.02, 0.025, 0.02, 1.0), 0.18)
	mat.roughness = 0.40
	mat.metallic = 0.0
	mat.metallic_specular = 0.34
	mat.emission_enabled = true
	mat.emission = tint.lerp(Color(0.70, 1.0, 0.50, 1.0), 0.18)
	mat.emission_energy_multiplier = 0.14
	_apply_standard_ooze_rim(mat, tint, 0.52, 0.38)
	return mat

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
	var shadow_mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.cast_shadow = shadow_mode
	return inst

func _owner_pool_material(owner_id: int, mask_tex: Texture2D) -> ShaderMaterial:
	var cache_key: String = "%d|%d|%d" % [owner_id, _state.width, _state.height]
	if _pool_material_cache.has(cache_key):
		_perf_increment("pool_material_cache_hits")
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
		cached.set_shader_parameter("pulse_speed", 0.17)
		cached.set_shader_parameter("bubble_strength", 0.0010)
		cached.set_shader_parameter("emission_strength", 0.026)
		cached.set_shader_parameter("detail_scale", 4.35)
		cached.set_shader_parameter("body_thickness", 0.034)
		cached.set_shader_parameter("lip_thickness", 0.044)
		cached.set_shader_parameter("flow_scale", 1.08)
		cached.set_shader_parameter("flow_speed", 0.0045)
		cached.set_shader_parameter("flow_normal_strength", 0.30)
		cached.set_shader_parameter("edge_darkening_strength", 0.30)
		cached.set_shader_parameter("contact_darkening_strength", 0.20)
		cached.set_shader_parameter("clearcoat_strength", 0.34)
		cached.set_shader_parameter("specular_strength", 0.25)
		cached.set_shader_parameter("rim_highlight_strength", 0.24)
		cached.set_shader_parameter("acid_glow_strength", 0.024)
		cached.set_shader_parameter("edge_wobble_strength", 0.060)
		cached.set_shader_parameter("inner_pulse_strength", 0.012)
		cached.set_shader_parameter("bubble_pop_strength", 0.24)
		return cached
	_perf_increment("pool_material_builds")
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
	mat.set_shader_parameter("pulse_speed", 0.17)
	mat.set_shader_parameter("bubble_strength", 0.0010)
	mat.set_shader_parameter("emission_strength", 0.026)
	mat.set_shader_parameter("detail_scale", 4.35)
	mat.set_shader_parameter("body_thickness", 0.034)
	mat.set_shader_parameter("lip_thickness", 0.044)
	mat.set_shader_parameter("flow_scale", 1.08)
	mat.set_shader_parameter("flow_speed", 0.0045)
	mat.set_shader_parameter("flow_normal_strength", 0.30)
	mat.set_shader_parameter("edge_darkening_strength", 0.30)
	mat.set_shader_parameter("contact_darkening_strength", 0.20)
	mat.set_shader_parameter("clearcoat_strength", 0.34)
	mat.set_shader_parameter("specular_strength", 0.25)
	mat.set_shader_parameter("rim_highlight_strength", 0.24)
	mat.set_shader_parameter("acid_glow_strength", 0.024)
	mat.set_shader_parameter("edge_wobble_strength", 0.060)
	mat.set_shader_parameter("inner_pulse_strength", 0.012)
	mat.set_shader_parameter("bubble_pop_strength", 0.24)
	_pool_material_cache[cache_key] = mat
	return mat

func _ooze_shell_material(owner_tint: Color) -> StandardMaterial3D:
	var readable_tint: Color = _normalize_ooze_color(owner_tint, OOZE_MIN_VALUE, OOZE_MIN_LUMA, OOZE_MAX_SATURATION)
	var cache_key: String = _color_cache_key(readable_tint)
	if _shell_material_cache.has(cache_key):
		_perf_increment("shell_material_cache_hits")
		return _shell_material_cache[cache_key] as StandardMaterial3D
	_perf_increment("shell_material_builds")
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = readable_tint.lerp(Color(0.035, 0.045, 0.040, 1.0), 0.28)
	mat.roughness = 0.54
	mat.metallic = 0.0
	mat.metallic_specular = 0.15
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.12
	mat.clearcoat_roughness = 0.58
	mat.emission_enabled = true
	mat.emission = readable_tint
	mat.emission_energy_multiplier = 0.024
	_apply_standard_ooze_rim(mat, readable_tint, 0.22, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_shell_material_cache[cache_key] = mat
	return mat

func _ooze_tile_mass_material(owner_tint: Color, role: String = "basic") -> StandardMaterial3D:
	var readable_tint: Color = _normalize_ooze_color(owner_tint, OOZE_MIN_VALUE, OOZE_MIN_LUMA, OOZE_MAX_SATURATION)
	var hue_bucket: float = floor(readable_tint.h * 20.0 + 0.5) / 20.0
	var saturation_bucket: float = floor(readable_tint.s * 10.0 + 0.5) / 10.0
	var value_bucket: float = floor(readable_tint.v * 10.0 + 0.5) / 10.0
	var cache_key: String = "%0.2f,%0.1f,%0.1f|tile_mass|%s" % [hue_bucket, saturation_bucket, value_bucket, role]
	if _shell_material_cache.has(cache_key):
		_perf_increment("shell_material_cache_hits")
		return _shell_material_cache[cache_key] as StandardMaterial3D
	_perf_increment("shell_material_builds")
	var role_tint: Color = _owner_role_growth_tint(readable_tint, role)
	var mix_amount: float = 0.10
	var roughness: float = 0.58
	var emission_energy: float = 0.020
	var rim_strength: float = 0.26
	match role:
		"core", "heart":
			mix_amount = 0.05
			roughness = 0.52
			emission_energy = 0.030
			rim_strength = 0.34
		"melee":
			mix_amount = 0.03
			roughness = 0.64
			emission_energy = 0.016
			rim_strength = 0.24
		"ranged":
			mix_amount = 0.10
			roughness = 0.56
			emission_energy = 0.034
			rim_strength = 0.34
		"defense":
			mix_amount = 0.03
			roughness = 0.74
			emission_energy = 0.012
			rim_strength = 0.18
		"gather":
			mix_amount = 0.12
			roughness = 0.60
			emission_energy = 0.036
			rim_strength = 0.34
	var darken_amount: float = 0.10 if role == "basic" else 0.18
	var body: Color = readable_tint.lerp(role_tint, mix_amount).lerp(Color(0.020, 0.028, 0.026, 1.0), darken_amount)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = body
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.metallic_specular = 0.14
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.14
	mat.clearcoat_roughness = clampf(roughness + 0.10, 0.40, 0.82)
	mat.emission_enabled = true
	mat.emission = readable_tint.lerp(role_tint, 0.16)
	mat.emission_energy_multiplier = emission_energy
	_apply_standard_ooze_rim(mat, body, rim_strength, 0.32)
	_shell_material_cache[cache_key] = mat
	return mat

func _ooze_growth_material(owner_tint: Color, role_tint: Color, role: String, accent: bool) -> StandardMaterial3D:
	var readable_owner: Color = _normalize_ooze_color(owner_tint, OOZE_GROWTH_MIN_VALUE, OOZE_GROWTH_MIN_LUMA, OOZE_MAX_SATURATION)
	var readable_role: Color = _normalize_ooze_color(role_tint, OOZE_GROWTH_MIN_VALUE, OOZE_GROWTH_MIN_LUMA, OOZE_MAX_SATURATION)
	var growth_cache_key: String = "%s|%s|%s|%s" % [_color_cache_key(readable_owner), _color_cache_key(readable_role), role, str(accent)]
	if _growth_material_template_cache.has(growth_cache_key):
		_perf_increment("growth_material_template_hits")
		return (_growth_material_template_cache[growth_cache_key] as StandardMaterial3D).duplicate(true)
	_perf_increment("growth_material_template_builds")
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var role_mix: float = 0.22
	var roughness: float = 0.62
	var clearcoat: float = 0.18
	var emission_strength: float = 0.034
	var rim_strength: float = 0.28
	var rim_tint: float = 0.32
	match role:
		"heart":
			role_mix = 0.08
			roughness = 0.54
			clearcoat = 0.24
			emission_strength = 0.056
			rim_strength = 0.36
			rim_tint = 0.30
		"melee":
			role_mix = 0.10
			roughness = 0.70
			clearcoat = 0.14
			emission_strength = 0.030
			rim_strength = 0.28
			rim_tint = 0.26
		"ranged":
			role_mix = 0.12
			roughness = 0.58
			clearcoat = 0.22
			emission_strength = 0.060
			rim_strength = 0.36
			rim_tint = 0.38
		"defense":
			role_mix = 0.08
			roughness = 0.82
			clearcoat = 0.10
			emission_strength = 0.022
			rim_strength = 0.18
			rim_tint = 0.18
		"gather":
			role_mix = 0.14
			roughness = 0.64
			clearcoat = 0.20
			emission_strength = 0.060
			rim_strength = 0.34
			rim_tint = 0.36
	if accent:
		roughness = maxf(0.48, roughness - 0.03)
		clearcoat = minf(0.34, clearcoat + 0.02)
		emission_strength *= 1.08
	var base_color: Color = readable_owner.lerp(readable_role, role_mix).lerp(Color(0.018, 0.026, 0.024, 1.0), 0.16)
	mat.albedo_color = base_color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.metallic_specular = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = clearcoat
	mat.clearcoat_roughness = clampf(roughness + 0.12, 0.42, 0.86)
	mat.emission_enabled = true
	mat.emission = readable_owner.lerp(readable_role, minf(0.78, role_mix + 0.16))
	mat.emission_energy_multiplier = emission_strength * 0.92
	_apply_standard_ooze_rim(mat, base_color, rim_strength, rim_tint)
	_growth_material_template_cache[growth_cache_key] = mat
	return mat.duplicate(true)

func _normalize_ooze_color(source: Color, min_value: float, min_luma: float, max_saturation: float) -> Color:
	var hue: float = source.h
	var saturation: float = clampf(source.s, 0.0, max_saturation)
	var value: float = maxf(source.v, min_value)
	var lifted: Color = Color.from_hsv(hue, saturation, value, source.a)
	var luma: float = _color_luma(lifted)
	if luma < min_luma:
		var lift_amount: float = clampf((min_luma - luma) * 1.35, 0.0, 0.20)
		lifted = lifted.lerp(Color(1.0, 1.0, 1.0, source.a), lift_amount)
	lifted.a = source.a
	return lifted

func _color_luma(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _apply_standard_ooze_rim(mat: StandardMaterial3D, base_color: Color, rim_strength: float, rim_tint: float) -> void:
	if mat == null:
		return
	_set_material_property_if_present(mat, "rim_enabled", true)
	_set_material_property_if_present(mat, "rim", rim_strength)
	_set_material_property_if_present(mat, "rim_tint", rim_tint)
	_set_material_property_if_present(mat, "backlight_enabled", true)
	_set_material_property_if_present(mat, "backlight", base_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.22) * 0.12)

func _set_material_property_if_present(mat: Material, property_name: String, value: Variant) -> void:
	if mat == null:
		return
	for property_info in mat.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			mat.set(property_name, value)
			return

func _extract_queued_tiles(queued_actions: Array) -> Dictionary:
	return _marker_layer.extract_queued_tiles(_state, queued_actions)

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

func _terrain_ground_top_for_tile(tile: Vector2i, board_top: float) -> float:
	if _state == null:
		return board_top
	var w: float = maxf(float(_state.width), 1.0)
	var h: float = maxf(float(_state.height), 1.0)
	var nx: float = (float(tile.x) + 0.5) / w - 0.5
	var nz: float = (float(tile.y) + 0.5) / h - 0.5
	var gradient: float = nx * 0.050 - nz * 0.042
	var bowl: float = (0.19 - (nx * nx + nz * nz)) * 0.040
	var undulation: float = sin((nx + 0.18) * PI * 2.4) * 0.022 + cos((nz - 0.12) * PI * 2.1) * 0.018
	return board_top + gradient + bowl + undulation

func _tile_ground_top(tile: Vector2i) -> float:
	return float(_ground_tops.get(_tile_key(tile), 0.0))

func _tile_floor_top(tile: Vector2i) -> float:
	return float(_floor_surface_tops.get(_tile_key(tile), _tile_ground_top(tile)))

func _owner_tint(owner_id: int) -> Color:
	if _state == null:
		return PLAYER_TINT
	if _palette_renderer != null:
		return _palette_renderer.owner_tint_for_ui(_state, owner_id)
	if owner_id == GameState.PLAYER_ID:
		return PLAYER_TINT
	return Color(0.86, 0.35, 0.45, 1.0)

func _owner_is_left_side(owner_id: int) -> bool:
	if _state == null:
		return owner_id == GameState.PLAYER_ID
	var core: Dictionary = _state.get_core(owner_id)
	if not core.is_empty():
		var tile: Vector2i = core.get("pos", Vector2i(-1, -1))
		if _state.is_inside(tile):
			return tile.x < int(floor(float(_state.width) / 2.0))
	return owner_id == GameState.PLAYER_ID

func _owner_ooze_tint(owner_id: int) -> Color:
	return _normalize_ooze_color(_owner_tint(owner_id), OOZE_MIN_VALUE, OOZE_MIN_LUMA, OOZE_MAX_SATURATION)

func _owner_role_growth_tint(owner_tint: Color, role: String) -> Color:
	match role:
		"heart":
			return owner_tint.lerp(Color(0.78, 0.96, 0.58, 1.0), 0.04)
		"melee":
			return owner_tint.lerp(Color(0.03, 0.04, 0.035, 1.0), 0.16)
		"ranged":
			return owner_tint.lerp(Color(0.72, 1.0, 0.72, 1.0), 0.05)
		"defense":
			return owner_tint.lerp(Color(0.025, 0.030, 0.028, 1.0), 0.24)
		"gather":
			return owner_tint.lerp(Color(0.76, 1.0, 0.44, 1.0), 0.07)
		_:
			return owner_tint

func _stone_shader_material(
	base: Color,
	alt: Color,
	damp: Color,
	uv_scale: float,
	height_amp: float = 0.0,
	detail_mix: float = 0.72,
	tile_variation_strength: float = 0.035,
	seam_strength: float = 0.40,
	detail_color_strength: float = 0.018,
	min_midtone: float = 0.250,
	max_midtone: float = 0.430
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
	mat.set_shader_parameter("normal_strength", 0.82)
	mat.set_shader_parameter("height_amp", height_amp)
	mat.set_shader_parameter("tile_variation_strength", tile_variation_strength)
	mat.set_shader_parameter("seam_strength", seam_strength)
	mat.set_shader_parameter("detail_color_strength", detail_color_strength)
	mat.set_shader_parameter("min_midtone", min_midtone)
	mat.set_shader_parameter("max_midtone", max_midtone)
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
			var col: Color = Color(0.38, 0.39, 0.39, 1.0).lerp(Color(0.24, 0.25, 0.25, 1.0), blend * 0.42)
			if crack > 0.78:
				col = col.lerp(Color(0.18, 0.19, 0.19, 1.0), 0.32)
			if n2 < 0.16:
				col = col.lerp(Color(0.43, 0.44, 0.44, 1.0), 0.16)
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
	var animated_point_lights: Array[OmniLight3D] = []
	for wall_light in _wall_lights:
		if wall_light != null and is_instance_valid(wall_light):
			animated_point_lights.append(wall_light)
	for point_light in _point_lights:
		if point_light != null and is_instance_valid(point_light):
			animated_point_lights.append(point_light)
	_lighting.animate_lights(
		_visual_time,
		_key_light,
		_fill_light,
		_rim_light,
		animated_point_lights,
		STABILIZATION_LIGHT_BASELINE
	)

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
	_lighting.apply_lighting_contract(
		_environment,
		_key_light,
		_fill_light,
		_rim_light,
		STABILIZATION_ENV_BASELINE,
		STABILIZATION_LIGHT_BASELINE
	)

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
	if not is_instance_valid(_camera) or not _camera.is_inside_tree():
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
	var camera_pos: Vector3 = target + offset
	_camera.look_at_from_position(camera_pos, target + Vector3(0.0, 0.34, 0.0), Vector3.UP)
	if _key_light != null:
		_key_light.position = target + Vector3(-8.5, 16.0, -7.0)
	if _rim_light != null and is_instance_valid(_rim_light) and _rim_light.is_inside_tree():
		var rim_pos: Vector3 = camera_pos + Vector3(0.0, 2.2, 0.0)
		_rim_light.look_at_from_position(rim_pos, target + Vector3(0.0, 0.40, 0.0), Vector3.UP)
	if _fill_light != null:
		_fill_light.position = target + Vector3(offset.x * 0.18, 5.4, offset.z * 0.18)

func _load_asset_manifest() -> void:
	_asset_material_cache.clear()
	_assets.load_manifest(ASSET_MANIFEST_PATH)

func _texture_path_for(key: String) -> String:
	return _assets.texture_path_for(key)

func _asset_paths_for(key: String) -> Array[String]:
	return _assets.asset_paths_for(key)

func _asset_scene_for_path(path: String) -> PackedScene:
	return _assets.asset_scene_for_path(path)

func _asset_scene_for(key: String) -> PackedScene:
	return _assets.asset_scene_for(key)

func _asset_variant_path_for_transform(key: String, tf: Transform3D) -> String:
	return _assets.asset_variant_path_for_transform(key, tf)

func _has_asset_scene(key: String) -> bool:
	return _assets.has_asset_scene(key)

func _instantiate_asset_scene(key: String, path_override: String = "") -> Node3D:
	return _assets.instantiate_asset_scene(key, path_override)

func _set_geometry_visuals(
	node: Node,
	cast_shadow: GeometryInstance3D.ShadowCastingSetting,
	material_override: Material = null
) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = cast_shadow
	if material_override != null and node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material_override
	for child in node.get_children():
		_set_geometry_visuals(child, cast_shadow, material_override)

func _normalized_asset_transform(key: String, base_tf: Transform3D) -> Transform3D:
	return _assets.normalized_asset_transform(key, base_tf)

func _default_asset_material_for(key: String) -> Material:
	if _asset_material_cache.has(key):
		_perf_increment("asset_material_cache_hits")
		return _asset_material_cache[key] as Material
	_perf_increment("asset_material_builds")
	var material: Material = null
	match key:
		"blocker_wall":
			material = _stone_shader_material(
				Color(0.335, 0.342, 0.346, 1.0),
				Color(0.225, 0.232, 0.236, 1.0),
				Color(0.145, 0.152, 0.156, 1.0),
				8.0,
				0.002,
				0.030,
				0.018,
				0.34,
				0.006,
				0.215,
				0.345
			)
		"cave_wall", "cave_corner":
			material = _stone_shader_material(
				Color(0.330, 0.337, 0.340, 1.0),
				Color(0.218, 0.225, 0.229, 1.0),
				Color(0.140, 0.148, 0.152, 1.0),
				8.4,
				0.002,
				0.030,
				0.016,
				0.32,
				0.006,
				0.205,
				0.335
			)
		"board_edge_trim":
			material = _stone_shader_material(
				Color(0.35, 0.36, 0.36, 1.0),
				Color(0.23, 0.24, 0.24, 1.0),
				Color(0.15, 0.16, 0.16, 1.0),
				8.4,
				0.002,
				0.030,
				0.018,
				0.34,
				0.006,
				0.215,
				0.345
			)
		"door_arch":
			var door_mat: StandardMaterial3D = StandardMaterial3D.new()
			door_mat.albedo_color = Color(0.34, 0.35, 0.35, 1.0)
			door_mat.roughness = 0.70
			door_mat.metallic = 0.04
			door_mat.emission_enabled = true
			door_mat.emission = Color(0.72, 0.62, 0.46, 1.0)
			door_mat.emission_energy_multiplier = 0.10
			material = door_mat
		"node_base":
			material = _stone_shader_material(
				Color(0.36, 0.37, 0.37, 1.0),
				Color(0.22, 0.23, 0.23, 1.0),
				Color(0.14, 0.15, 0.15, 1.0),
				6.2,
				0.004,
				0.030,
				0.020,
				0.34,
				0.008,
				0.220,
				0.350
			)
		"core_growth", "basic_tile", "melee_growth", "ranged_growth", "defense_growth", "gather_growth":
			material = _ooze_growth_material(
				Color(0.30, 0.86, 0.42, 1.0),
				Color(0.38, 0.92, 0.52, 1.0),
				"heart" if key == "core_growth" else ("gather" if key == "basic_tile" else key.replace("_growth", "")),
				false
			)
	_asset_material_cache[key] = material
	return material

func validate_wall_tile_visual_alignment() -> Dictionary:
	return _static_environment.validate_wall_tile_visual_alignment(_state, _rendered_inner_wall_tiles)

func validate_ooze_wall_blocking(alpha_threshold: float = 0.02) -> Dictionary:
	return _dynamic_ooze.validate_ooze_wall_blocking(self, _state, _owner_mask_texture_cache, alpha_threshold)

func validate_render_truth_contract() -> Dictionary:
	if _state == null:
		return {"ok": true}
	var layout_truth: Dictionary = validate_layout_truth_contract()
	var wall_truth: Dictionary = validate_wall_blocking_contract()
	var territory_truth: Dictionary = validate_territory_visual_alignment()
	var layering_truth: Dictionary = validate_ooze_layering_contract()
	var ok: bool = (
		bool(layout_truth.get("ok", false))
		and bool(wall_truth.get("ok", false))
		and bool(territory_truth.get("ok", false))
		and bool(layering_truth.get("ok", false))
	)
	return {
		"ok": ok,
		"layout": layout_truth,
		"walls": wall_truth,
		"territory": territory_truth,
		"layering": layering_truth,
	}

func validate_layout_truth_contract() -> Dictionary:
	if _state == null:
		return {"ok": true}
	var layout: Dictionary = _state.get_level_layout()
	var board_size: Array = layout.get("board_size", [_state.width, _state.height])
	var board_ok: bool = board_size.size() >= 2 and int(board_size[0]) == _state.width and int(board_size[1]) == _state.height

	var objective_positions: Dictionary = layout.get("objective_positions", {})
	var entrance_arr: Array = objective_positions.get("entrance", [_state.entrance_tile.x, _state.entrance_tile.y])
	var door_arr: Array = objective_positions.get("door", [_state.door_tile.x, _state.door_tile.y])
	var entrance_ok: bool = entrance_arr.size() >= 2 and Vector2i(int(entrance_arr[0]), int(entrance_arr[1])) == _state.entrance_tile
	var door_ok: bool = door_arr.size() >= 2 and Vector2i(int(door_arr[0]), int(door_arr[1])) == _state.door_tile

	var layout_walls: Dictionary = {}
	for wall_raw in layout.get("inner_walls", []):
		if typeof(wall_raw) != TYPE_ARRAY:
			continue
		var wall_arr: Array = wall_raw
		if wall_arr.size() < 2:
			continue
		layout_walls[_tile_key(Vector2i(int(wall_arr[0]), int(wall_arr[1])))] = true
	var missing_from_layout: Array = []
	var extra_in_layout: Array = []
	for key_variant in _state.wall_tiles.keys():
		var key: String = String(key_variant)
		if not layout_walls.has(key):
			missing_from_layout.append(key)
	for key_variant in layout_walls.keys():
		var key: String = String(key_variant)
		if not _state.wall_tiles.has(key):
			extra_in_layout.append(key)

	var bounds: Dictionary = _layout_outer_bounds_tiles()
	var min_tile: Vector2i = bounds.get("min", Vector2i(0, 0))
	var max_tile: Vector2i = bounds.get("max", Vector2i(_state.width - 1, _state.height - 1))
	var bounds_ok: bool = (
		_state.is_inside(min_tile)
		and _state.is_inside(max_tile)
		and min_tile.x <= max_tile.x
		and min_tile.y <= max_tile.y
	)
	return {
		"ok": board_ok and entrance_ok and door_ok and missing_from_layout.is_empty() and extra_in_layout.is_empty() and bounds_ok,
		"board_size_ok": board_ok,
		"entrance_ok": entrance_ok,
		"door_ok": door_ok,
		"bounds_ok": bounds_ok,
		"missing_walls_from_layout": missing_from_layout,
		"extra_walls_in_layout": extra_in_layout,
	}

func validate_territory_visual_alignment() -> Dictionary:
	return _dynamic_ooze.validate_territory_visual_alignment(_state, _rendered_owner_tiles_by_owner)

func validate_ooze_layering_contract() -> Dictionary:
	return _dynamic_ooze.validate_ooze_layering_contract(self, _state)

func validate_wall_blocking_contract() -> Dictionary:
	if _state == null:
		return {"ok": true}
	var blocked_ownership: int = 0
	for block_variant in _state.blocks.values():
		var block: Dictionary = block_variant
		var tile: Vector2i = block.get("pos", Vector2i(-1, -1))
		if _state.is_inside(tile) and _state.is_blocked(tile):
			blocked_ownership += 1
	var visual_alignment: Dictionary = validate_wall_tile_visual_alignment()
	var ooze_blocking: Dictionary = validate_ooze_wall_blocking()
	var ok: bool = bool(visual_alignment.get("ok", false)) and bool(ooze_blocking.get("ok", false)) and blocked_ownership == 0
	return {
		"ok": ok,
		"blocked_owned_tiles": blocked_ownership,
		"wall_visual_alignment": visual_alignment,
		"ooze_wall_blocking": ooze_blocking,
	}

func get_performance_counters() -> Dictionary:
	var out: Dictionary = _perf_counters.duplicate(true)
	for key_variant in _perf_counters.keys():
		var key: String = String(key_variant)
		if not key.begins_with("profile_") or not key.ends_with("_usec"):
			continue
		var count_key: String = key.replace("_usec", "_count")
		var avg_key: String = key.replace("_usec", "_avg_ms")
		out[avg_key] = float(_perf_counters[key]) / 1000.0 / float(maxi(1, int(_perf_counters.get(count_key, 0))))
	var marker_counters: Dictionary = _marker_layer.get_performance_counters()
	for key_variant in marker_counters.keys():
		var key: String = String(key_variant)
		out[key] = marker_counters[key_variant]
	out["world3d_total_node_count"] = _count_nodes_recursive(self)
	out["terrain_root_child_count"] = _terrain_root.get_child_count() if _terrain_root != null else 0
	out["dynamic_root_child_count"] = _dynamic_root.get_child_count() if _dynamic_root != null else 0
	out["dynamic_root_total_node_count"] = _count_nodes_recursive(_dynamic_root)
	out["growth_pool_root_child_count"] = _growth_pool_root.get_child_count() if _growth_pool_root != null else 0
	out["marker_root_child_count"] = _marker_root.get_child_count() if _marker_root != null else 0
	out["marker_root_total_node_count"] = _count_nodes_recursive(_marker_root)
	out["light_root_child_count"] = _dynamic_light_root.get_child_count() if _dynamic_light_root != null else 0
	out["dynamic_light_pool_entries"] = _dynamic_light_pool.size()
	out["point_light_tracking_count"] = _point_lights.size()
	out["growth_animation_count"] = _growth_anim_entries.size()
	out["active_growth_asset_count"] = _active_growth_asset_nodes.size()
	out["pooled_growth_asset_count"] = _growth_asset_pool_node_count()
	out["mask_cache_entries"] = _owner_mask_texture_cache.size()
	out["pool_material_cache_entries"] = _pool_material_cache.size()
	out["shell_material_cache_entries"] = _shell_material_cache.size()
	out["growth_material_template_cache_entries"] = _growth_material_template_cache.size()
	out["asset_material_cache_entries"] = _asset_material_cache.size()
	out["ooze_surface_mesh_cache_entries"] = _ooze_surface_mesh_cache.size()
	out["avg_frame_ms"] = _frame_time_accum / float(maxi(1, _frame_time_samples))
	out["max_frame_ms"] = _frame_time_max_ms
	out["frame_time_samples"] = _frame_time_samples
	out["avg_growth_animation_ms"] = _growth_animation_time_accum_ms / float(maxi(1, _growth_animation_time_samples))
	out["max_growth_animation_ms"] = _growth_animation_time_max_ms
	out["growth_animation_time_samples"] = _growth_animation_time_samples
	out["avg_dynamic_rebuild_ms"] = _dynamic_rebuild_time_accum_ms / float(maxi(1, _dynamic_rebuild_time_samples))
	out["max_dynamic_rebuild_ms"] = _dynamic_rebuild_time_max_ms
	out["last_dynamic_rebuild_ms"] = _dynamic_rebuild_time_last_ms
	out["dynamic_rebuild_time_samples"] = _dynamic_rebuild_time_samples
	return out

func reset_performance_counters() -> void:
	_perf_counters.clear()
	_marker_layer.reset_performance_counters()
	_frame_time_accum = 0.0
	_frame_time_samples = 0
	_frame_time_max_ms = 0.0
	_growth_animation_time_accum_ms = 0.0
	_growth_animation_time_samples = 0
	_growth_animation_time_max_ms = 0.0
	_dynamic_rebuild_time_accum_ms = 0.0
	_dynamic_rebuild_time_samples = 0
	_dynamic_rebuild_time_max_ms = 0.0
	_dynamic_rebuild_time_last_ms = 0.0

func _perf_increment(key: String, amount: int = 1) -> void:
	_perf_counters[key] = int(_perf_counters.get(key, 0)) + amount

func _perf_record_time(key: String, start_usec: int) -> void:
	var elapsed: int = maxi(0, Time.get_ticks_usec() - start_usec)
	_perf_increment("%s_usec" % key, elapsed)
	_perf_increment("%s_count" % key, 1)

func _add_asset_instance(
	parent: Node3D,
	key: String,
	tf: Transform3D,
	cast_shadow: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
	material_override: Material = null
) -> Node3D:
	if parent == null:
		return null
	var variant_path: String = _asset_variant_path_for_transform(key, tf)
	var inst: Node3D = _instantiate_asset_scene(key, variant_path)
	if inst == null:
		return null
	parent.add_child(inst)
	inst.transform = _normalized_asset_transform(key, tf)
	var effective_material: Material = material_override if material_override != null else _default_asset_material_for(key)
	_set_geometry_visuals(inst, cast_shadow, effective_material)
	return inst

func _claim_dynamic_growth_asset_instance(
	parent: Node3D,
	key: String,
	tf: Transform3D,
	cast_shadow: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
	material_override: Material = null
) -> Node3D:
	if parent == null:
		return null
	var pool: Array = _growth_asset_pool.get(key, [])
	var inst: Node3D = null
	while not pool.is_empty():
		var candidate: Node3D = pool.pop_back() as Node3D
		if candidate != null and is_instance_valid(candidate):
			inst = candidate
			break
	_growth_asset_pool[key] = pool
	if inst == null:
		_perf_increment("growth_asset_pool_misses")
		var variant_path: String = _asset_variant_path_for_transform(key, tf)
		inst = _instantiate_asset_scene(key, variant_path)
		if inst == null:
			return null
	else:
		_perf_increment("growth_asset_pool_hits")
	if inst.get_parent() != parent:
		if inst.get_parent() != null:
			inst.get_parent().remove_child(inst)
		parent.add_child(inst)
	inst.visible = true
	inst.transform = _normalized_asset_transform(key, tf)
	var effective_material: Material = material_override if material_override != null else _default_asset_material_for(key)
	_set_geometry_visuals(inst, cast_shadow, effective_material)
	inst.set_meta("dynamic_growth_asset_key", key)
	_active_growth_asset_nodes.append(inst)
	return inst

func _release_active_growth_asset_nodes() -> void:
	for node in _active_growth_asset_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var key: String = String(node.get_meta("dynamic_growth_asset_key", ""))
		if key.is_empty():
			continue
		node.visible = false
		if _growth_pool_root != null and is_instance_valid(_growth_pool_root):
			if node.get_parent() != _growth_pool_root:
				if node.get_parent() != null:
					node.get_parent().remove_child(node)
				_growth_pool_root.add_child(node)
		elif node.get_parent() != null:
			node.get_parent().remove_child(node)
		var pool: Array = _growth_asset_pool.get(key, [])
		pool.append(node)
		_growth_asset_pool[key] = pool
		_perf_increment("growth_asset_pool_releases")
	_active_growth_asset_nodes.clear()

func _growth_asset_pool_node_count() -> int:
	var total: int = 0
	for pool_variant in _growth_asset_pool.values():
		var pool: Array = pool_variant
		total += pool.size()
	return total

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.free()

func _count_nodes_recursive(node: Node) -> int:
	if node == null:
		return 0
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes_recursive(child)
	return count

func _owned_neighbor_count(tile: Vector2i, tile_set: Dictionary) -> int:
	var count: int = 0
	for n in [tile + Vector2i.RIGHT, tile + Vector2i.LEFT, tile + Vector2i.UP, tile + Vector2i.DOWN]:
		if tile_set.has(_tile_key(n)):
			count += 1
	return count

func _tile_noise(x: int, y: int, salt: int) -> int:
	var n: int = int(x * 73856093) ^ int(y * 19349663) ^ int(salt * 83492791)
	return absi(n) % 997

func _noise01(x: int, y: int) -> float:
	return float(_tile_noise(x, y, 313) % 1000) / 999.0

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _tile_from_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() < 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

func _join_string_keys(keys: Array) -> String:
	var out: String = ""
	for key_variant in keys:
		if not out.is_empty():
			out += ";"
		out += String(key_variant)
	return out

func _color_cache_key(color: Color) -> String:
	return "%0.2f,%0.2f,%0.2f,%0.2f" % [color.r, color.g, color.b, color.a]
