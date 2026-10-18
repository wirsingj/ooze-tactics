shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tissue_texture : source_color, filter_nearest, repeat_disable;
// R: owner index, G: growth, B: faction hue, A: traversable floor.
uniform sampler2D colony_map : filter_nearest, repeat_disable;
uniform vec2 board_size;
uniform vec2 tissue_span = vec2(0.0);
uniform vec2 canvas_size;
uniform vec2 origin;
uniform vec2 step_size;
uniform float clock = 0.0;

vec4 cell(vec2 tile) {
	if (any(lessThan(tile, vec2(0.0))) || any(greaterThanEqual(tile, board_size))) return vec4(0.0);
	return texture(colony_map, (tile+0.5)/board_size);
}
float capsule(vec2 p, vec2 end, float radius) {
	return length(p-end*clamp(dot(p,end)/max(dot(end,end),0.0001),0.0,1.0))-radius;
}
float joined(vec4 a, vec4 b) {
	return abs(a.r-b.r)<0.001 && b.r>0.001 ? min(a.g,b.g) : 0.0;
}
float body(vec2 p, vec2 tile, vec4 data) {
	if (data.r < 0.001 || data.g < 0.001) return 100.0;
	float growth = data.g;
	// Expand joined sides into a common body instead of connecting isolated
	// rounded pads with narrow necks. Four-way intersections remain filled.
	vec2 negative = vec2(joined(data,cell(tile+vec2(-1,0))),joined(data,cell(tile+vec2(0,-1))));
	vec2 positive = vec2(joined(data,cell(tile+vec2(1,0))),joined(data,cell(tile+vec2(0,1))));
	vec2 low = -vec2(0.42*growth)-negative*0.15;
	vec2 high = vec2(0.42*growth)+positive*0.15;
	float radius = 0.11*growth;
	vec2 q = abs(p-(low+high)*0.5)-(high-low)*0.5+radius;
	float field = length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
	for (int i=0; i<4; i++) {
		vec2 dir = i==0 ? vec2(1,0) : (i==1 ? vec2(-1,0) : (i==2 ? vec2(0,1) : vec2(0,-1)));
		vec4 neighbor = cell(tile+dir);
		if (neighbor.a>0.5 && neighbor.r<0.001) {
			float reach = (0.48+0.10*sin(clock*1.15+dot(tile,vec2(1.7,3.1))+float(i)*1.3))*growth;
			field = min(field,capsule(p,dir*reach,0.032*growth));
		}
	}
	return field + sin(p.x*27.0+p.y*13.0+clock)*0.007*growth;
}
vec3 hsv_to_rgb(vec3 c) {
	vec3 p=abs(fract(c.xxx+vec3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0);
	return c.z*mix(vec3(1.0),clamp(p-1.0,0.0,1.0),c.y);
}
void fragment() {
	vec2 screen=floor(UV*canvas_size)-origin;
	vec2 p=vec2((screen.x/step_size.x-screen.y/step_size.y)*0.5,(screen.y/step_size.y+screen.x/step_size.x)*0.5);
	vec2 tile=floor(p+0.5);
	vec4 own=cell(tile);
	float field=100.0;
	float hue=own.b;
	if (own.a>0.5) {
		field=body(p-tile,tile,own);
		// Empty floor can receive probing tips; walls and opposing cells cannot.
		if (own.r<0.001) {
			for (int i=0; i<4; i++) {
				vec2 dir=i==0?vec2(1,0):(i==1?vec2(-1,0):(i==2?vec2(0,1):vec2(0,-1)));
				vec4 adjacent=cell(tile+dir);
				float candidate=body(p-tile-dir,tile+dir,adjacent);
				if (candidate<field) {field=candidate; hue=adjacent.b;}
			}
		}
	}
	vec2 material_uv = tissue_span.x>0.0 ? fract((p+0.5)/tissue_span) : clamp((p+0.5)/board_size,vec2(0.0),vec2(1.0));
	vec3 sample_color=texture(tissue_texture,material_uv).rgb;
	float value=max(max(sample_color.r,sample_color.g),sample_color.b);
	float low=min(min(sample_color.r,sample_color.g),sample_color.b);
	vec3 color=hsv_to_rgb(vec3(hue,(value-low)/max(value,0.001),value*0.68));
	color+=hsv_to_rgb(vec3(hue,0.4,(1.0-smoothstep(0.0,0.065,abs(field+0.055)))*0.20));
	color*=1.0-smoothstep(-0.025,0.0,field)*0.5;
	COLOR=vec4(color,1.0-smoothstep(-0.012,0.012,field));
}
