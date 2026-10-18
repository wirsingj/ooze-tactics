shader_type canvas_item;
render_mode unshaded;

// One screen-sized draw replaces thousands of individual tile polygons and
// antialiased outlines. The same data texture/projection drives living tissue.
uniform sampler2D colony_map : filter_nearest, repeat_disable;
uniform vec2 board_size;
uniform vec2 canvas_size;
uniform vec2 origin;
uniform vec2 step_size;
uniform bool overview = false;

bool inside(vec2 tile) {
	return all(greaterThanEqual(tile, vec2(0.0))) && all(lessThan(tile, board_size));
}
bool wall(vec2 tile) {
	return inside(tile) && texture(colony_map, (tile+0.5)/board_size).a<0.5;
}
float variation(vec2 tile) {
	return mod(tile.x*7.0+tile.y*13.0,5.0)*0.008;
}
void fragment() {
	vec2 screen = UV*canvas_size-origin;
	vec2 p = vec2((screen.x/step_size.x-screen.y/step_size.y)*0.5,
		(screen.y/step_size.y+screen.x/step_size.x)*0.5);
	vec2 tile = floor(p+0.5);
	vec3 color = vec3(16.0,24.0,23.0)/255.0;
	if (inside(tile)) {
		bool blocked = wall(tile);
		color = overview && !blocked ? vec3(37.0,53.0,49.0)/255.0 :
			(blocked ? vec3(0.075,0.093,0.10) : vec3(0.12,0.16,0.15))+variation(tile);
		if (!overview || blocked) {
			// World-space edge distance converted to pixels keeps a one-pixel
			// grid at every zoom, without antialiased polyline draw calls.
			vec2 distance_px = (vec2(0.5)-abs(p-tile))/max(fwidth(p),vec2(0.0001));
			float line = 1.0-smoothstep(0.15,0.9,min(distance_px.x,distance_px.y));
			color = mix(color,vec3(41.0,55.0,53.0)/255.0,line);
		}
	}
	// Raised rock caps use the same silhouette and offset as the original
	// tile geometry, including pixels projecting across a tile's upper edge.
	vec2 cap_p = p+vec2(-0.14,0.14);
	vec2 cap_tile = floor(cap_p+0.5);
	vec2 cap_q = abs(cap_p-cap_tile);
	if (wall(cap_tile) && max(cap_q.x,cap_q.y)<0.42) {
		color = vec3(48.0,58.0,59.0)/255.0;
		float edge = (0.42-cap_q.y)/max(fwidth(p.y),0.0001);
		if (cap_p.y-cap_tile.y>0.0) {
			color = mix(vec3(71.0,83.0,81.0)/255.0,color,smoothstep(0.0,1.0,edge));
		}
	}
	COLOR = vec4(color,1.0);
}
