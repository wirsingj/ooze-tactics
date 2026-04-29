extends RefCounted
class_name World3DLighting

func create_base_lighting(
	parent: Node,
	env_baseline: Dictionary,
	light_baseline: Dictionary
) -> Dictionary:
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "DungeonGlobalKeyLight"
	key_light.light_color = Color(0.86, 0.78, 0.66, 1.0)
	key_light.light_energy = float(light_baseline["key_energy"])
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.055
	key_light.rotation_degrees = Vector3(-56.0, -28.0, 0.0)
	parent.add_child(key_light)

	var rim_light: DirectionalLight3D = DirectionalLight3D.new()
	rim_light.name = "DungeonGlobalRimLight"
	rim_light.light_color = Color(0.46, 0.50, 0.56, 1.0)
	rim_light.light_energy = float(light_baseline["rim_energy"])
	rim_light.shadow_enabled = false
	rim_light.rotation_degrees = Vector3(-34.0, 24.0, 0.0)
	parent.add_child(rim_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.name = "DungeonGlobalFillLight"
	fill_light.light_color = Color(0.62, 0.58, 0.52, 1.0)
	fill_light.light_energy = float(light_baseline["fill_energy"])
	fill_light.omni_range = float(light_baseline["fill_range"])
	parent.add_child(fill_light)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "DungeonEnvironment"
	var env: Environment = Environment.new()
	env.ssao_enabled = false
	env.set("sdfgi_enabled", false)
	env.set("ssil_enabled", false)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false
	env.fog_light_color = Color(0.30, 0.31, 0.35, 1.0)
	env.fog_light_energy = 0.28
	env.fog_sky_affect = 0.0
	world_environment.environment = env
	parent.add_child(world_environment)
	apply_lighting_contract(world_environment, key_light, fill_light, rim_light, env_baseline, light_baseline)

	return {
		"key_light": key_light,
		"rim_light": rim_light,
		"fill_light": fill_light,
		"environment": world_environment,
	}

func apply_lighting_contract(
	world_environment: WorldEnvironment,
	key_light: DirectionalLight3D,
	fill_light: OmniLight3D,
	rim_light: DirectionalLight3D,
	env_baseline: Dictionary,
	light_baseline: Dictionary
) -> void:
	if world_environment != null and world_environment.environment != null:
		var env: Environment = world_environment.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(env_baseline["background_color"])
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(env_baseline["ambient_color"])
		env.ambient_light_energy = float(env_baseline["ambient_energy"])
		env.set("sdfgi_enabled", false)
		env.set("ssil_enabled", false)
		env.adjustment_enabled = true
		env.adjustment_brightness = float(env_baseline["brightness"])
		env.adjustment_contrast = float(env_baseline["contrast"])
		env.adjustment_saturation = float(env_baseline["saturation"])
		env.fog_enabled = bool(env_baseline["fog_enabled"])
		env.fog_density = float(env_baseline["fog_density"])
	if key_light != null:
		key_light.light_energy = float(light_baseline["key_energy"])
		key_light.visible = key_light.light_energy > 0.0
	if fill_light != null:
		fill_light.light_energy = float(light_baseline["fill_energy"])
		fill_light.omni_range = float(light_baseline["fill_range"])
		fill_light.visible = fill_light.light_energy > 0.0
	if rim_light != null:
		rim_light.light_energy = float(light_baseline["rim_energy"])
		rim_light.visible = rim_light.light_energy > 0.0

func animate_lights(
	visual_time: float,
	key_light: DirectionalLight3D,
	fill_light: OmniLight3D,
	rim_light: DirectionalLight3D,
	point_lights: Array[OmniLight3D],
	light_baseline: Dictionary
) -> void:
	if fill_light != null:
		var fill_energy: float = float(light_baseline["fill_energy"])
		fill_light.light_energy = fill_energy + (0.03 * sin(visual_time * 0.55) if fill_energy > 0.0 else 0.0)
	for light in point_lights:
		if light == null or not is_instance_valid(light):
			continue
		var base_energy: float = float(light.get_meta("base_energy")) if light.has_meta("base_energy") else light.light_energy
		var phase: float = float(light.get_meta("flicker_phase")) if light.has_meta("flicker_phase") else 0.0
		var torch_pulse: float = 0.94 + 0.045 * sin(visual_time * 5.1 + phase) + 0.025 * sin(visual_time * 11.3 + phase * 0.7)
		light.light_energy = base_energy * torch_pulse
	if key_light != null:
		var key_energy: float = float(light_baseline["key_energy"])
		key_light.light_energy = key_energy + (0.02 * sin(visual_time * 0.30) if key_energy > 0.0 else 0.0)
	if rim_light != null:
		var rim_energy: float = float(light_baseline["rim_energy"])
		rim_light.light_energy = rim_energy + (0.02 * sin(visual_time * 0.47) if rim_energy > 0.0 else 0.0)
