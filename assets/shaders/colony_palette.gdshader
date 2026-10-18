shader_type canvas_item;
render_mode unshaded;

uniform float faction_hue : hint_range(0.0, 1.0) = 0.43;
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform int role = 0;
uniform float action = 0.0;
uniform bool grayscale = false;
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float opacity = 1.0;
uniform float damage_flash = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w-q.y)/(6.0*d+0.00001)), d/(q.x+0.00001), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0/3.0, 1.0/3.0))*6.0-3.0);
	return c.z * mix(vec3(1.0), clamp(p-1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 local_uv = (UV-source_region.xy)/source_region.zw;
	vec2 uv = local_uv;
	float alive = sin(clock * 1.65 + phase);
	// Keep the root planted. Each organ deforms its upper tissue differently.
	float free_tissue = pow(clamp(1.0 - local_uv.y, 0.0, 1.0), 1.6);
	float breath = 0.010 * alive;
	if (role == 0) breath += 0.018 * pow(max(0.0, sin(clock*2.2)), 5.0);
	if (role == 1) uv.x -= free_tissue * (0.009*alive + 0.08*action);
	if (role == 2) breath += action * 0.09;
	if (role == 3) uv.y -= free_tissue * action * 0.025;
	if (role == 4) uv.x += sin(local_uv.y*18.0-clock*2.0) * 0.003;
	uv.x = 0.5 + (uv.x-0.5) * (1.0 - breath*free_tissue);
	vec4 source = texture(TEXTURE, source_region.xy+uv*source_region.zw);
	vec3 hsv = rgb_to_hsv(source.rgb);
	float tissue = smoothstep(0.23, 0.34, hsv.x) * (1.0-smoothstep(0.61, 0.70, hsv.x));
	vec3 shifted = hsv_to_rgb(vec3(faction_hue, hsv.y, hsv.z));
	vec3 color = mix(source.rgb, shifted, tissue);
	if (grayscale) color = vec3(dot(color, vec3(0.2126, 0.7152, 0.0722)));
	// Generated sources contain a soft alpha halo. Remove it at display time;
	// preserve the source and its internal amber material for future authoring.
	float alpha = smoothstep(0.64, 0.94, source.a);
	color = mix(color, vec3(1.0,0.65,0.35), damage_flash*0.7);
	COLOR = vec4(color, alpha*opacity);
}
