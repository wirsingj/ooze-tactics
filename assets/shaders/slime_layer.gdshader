shader_type canvas_item;

uniform float rim_strength : hint_range(0.0, 0.45) = 0.18;
uniform float interior_lift : hint_range(0.0, 0.35) = 0.11;
uniform float directional_strength : hint_range(0.0, 0.25) = 0.08;
uniform float variation_strength : hint_range(0.0, 0.20) = 0.06;
uniform float soft_edge_strength : hint_range(0.0, 0.20) = 0.08;
uniform float emissive_strength : hint_range(0.0, 0.35) = 0.12;
uniform float rim_light_strength : hint_range(0.0, 0.45) = 0.22;
uniform float bloom_strength : hint_range(0.0, 0.40) = 0.20;
uniform float bloom_radius : hint_range(0.0, 0.25) = 0.10;
uniform float effect_boost : hint_range(0.0, 3.0) = 2.1;
uniform float u_time = 0.0;

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;
	float a = src.a;
	if (a <= 0.001) {
		COLOR = vec4(0.0);
		return;
	}

	// Derivative-based edge estimate avoids cross-tile atlas bleed while
	// giving a stable edge mask over the whole connected blob.
	float edge = clamp(fwidth(a) * 54.0, 0.0, 1.0);
	float interior = clamp(smoothstep(0.12, 0.98, a) * (1.0 - edge * 0.55), 0.0, 1.0);
	float interior_contrast = pow(interior, 1.18);

	vec2 world_uv = SCREEN_UV;
	vec2 light_dir = normalize(vec2(-0.86, -0.52)); // top-left light
	float directional = dot(world_uv - vec2(0.5), light_dir);
	float dir_term = (-directional + 0.08) * directional_strength;

	// Low-frequency movement keeps material alive without looking noisy or tiled.
	float wave_a = sin((world_uv.x * 2.4 + world_uv.y * 1.8) + u_time * 0.11);
	float wave_b = sin((world_uv.x * 1.7 - world_uv.y * 2.1) - u_time * 0.08);
	float variation = (wave_a * 0.56 + wave_b * 0.44) * variation_strength * interior_contrast;

	float value_scale = 1.0;
	value_scale += interior_contrast * interior_lift * effect_boost;
	value_scale += (dir_term + variation) * effect_boost;
	value_scale -= edge * rim_strength * effect_boost;
	value_scale = clamp(value_scale, 0.34, 1.72);

	float edge_mask = smoothstep(0.08, 0.88, edge);
	float emissive = interior_contrast * emissive_strength * effect_boost;
	float bloom_mask = smoothstep(0.20, 0.92, interior_contrast) * (1.0 - edge_mask * 0.62);
	float bloom = bloom_mask * bloom_strength * effect_boost;
	vec3 out_rgb = src.rgb * value_scale + src.rgb * emissive + src.rgb * bloom;

	// Owner tint is already baked into src.rgb; lift it on boundaries for a
	// spectral rim-light instead of hard black edges.
	vec3 rim_tint = clamp(src.rgb * (1.0 + rim_light_strength * effect_boost), vec3(0.0), vec3(1.0));
	out_rgb = mix(out_rgb, rim_tint, edge_mask * 0.28);

	float soft_alpha = smoothstep(0.02, 0.98, a);
	float edge_soften = clamp((soft_edge_strength + bloom_radius * 0.5) * effect_boost, 0.0, 1.0);
	float out_alpha = mix(a, soft_alpha, edge_soften);

	COLOR = vec4(clamp(out_rgb, vec3(0.0), vec3(1.0)), out_alpha);
}
