shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tissue_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 centers[32];
uniform int center_count = 0;
uniform vec4 fingers[64];
uniform int finger_count = 0;
uniform vec2 canvas_size = vec2(600.0, 300.0);
uniform float faction_hue = 0.43;
uniform float clock = 0.0;
uniform float extension = 0.0;
uniform vec2 growth_center = vec2(500.0, 220.0);
uniform bool grayscale = false;

float union_soft(float a, float b, float k) {
	float h = max(k-abs(a-b), 0.0)/k;
	return min(a,b)-h*h*k*0.25;
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b-a;
	return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.001),0.0,1.0));
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
	return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}

void fragment() {
	vec2 screen = floor(UV*canvas_size/2.0)*2.0;
	vec2 p = screen*vec2(1.0,2.0);
	float field = 10000.0;
	for (int i=0; i<32; i++) {
		if (i>=center_count) break;
		float r = 43.0 + sin(clock*1.1+float(i)*0.3)*0.8;
		field = union_soft(field, length(p-centers[i]*vec2(1.0,2.0))-r, 15.0);
	}
	if (extension>0.01) {
		field = union_soft(field, length(p-growth_center*vec2(1.0,2.0))-43.0*extension, 18.0);
	}
	for (int i=0; i<64; i++) {
		if (i>=finger_count) break;
		vec2 a = fingers[i].xy*vec2(1.0,2.0);
		vec2 direction = fingers[i].zw;
		float reach = 13.0 + 7.0*sin(clock*1.1+float(i)*1.7);
		field = union_soft(field, segment_distance(p,a,a+direction*reach)-3.1, 7.0);
	}
	float ripple = sin(p.x*0.13+p.y*0.04+clock)*1.0 + sin(p.y*0.11-clock*0.7)*0.7;
	field += ripple;
	vec3 sample_color = texture(tissue_texture, UV+vec2(sin(clock*0.25)*0.004,cos(clock*0.2)*0.004)).rgb;
	float value = max(max(sample_color.r,sample_color.g),sample_color.b);
	float min_value = min(min(sample_color.r,sample_color.g),sample_color.b);
	float saturation = (value-min_value)/max(value,0.001);
	vec3 color = hsv_to_rgb(vec3(faction_hue,saturation, value*0.63));
	float rim = (1.0-smoothstep(0.0,5.0,abs(field+4.0))) * 0.16;
	color += hsv_to_rgb(vec3(faction_hue,0.36,rim));
	color *= 1.0-smoothstep(-2.0,0.0,field)*0.55;
	if (grayscale) color=vec3(dot(color,vec3(0.2126,0.7152,0.0722)));
	COLOR = vec4(color,1.0-smoothstep(-0.8,0.5,field));
}
