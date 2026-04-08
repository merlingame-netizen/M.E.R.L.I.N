shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Fog dissolve via Bayer 4x4 dithering — avoids alpha blending (expensive on GL Compat).
// Objects dissolve into fog based on camera distance using a screen-space dither pattern.

uniform vec4 fog_color : source_color = vec4(0.08, 0.15, 0.08, 1.0);
uniform float near_dist : hint_range(0.0, 30.0) = 2.0;
uniform float far_dist : hint_range(1.0, 80.0) = 15.0;
uniform float density : hint_range(0.0, 1.0) = 0.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Camera distance
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = length(world_pos - cam);
	float fog_factor = clamp((dist - near_dist) / (far_dist - near_dist), 0.0, 1.0) * density;

	// Bayer 4x4 ordered dithering threshold
	int bx = int(FRAGCOORD.x) % 4;
	int by = int(FRAGCOORD.y) % 4;
	// Bayer matrix values (0-15) / 16
	int idx = bx + by * 4;
	float threshold;
	if (idx == 0) { threshold = 0.0; }
	else if (idx == 1) { threshold = 0.5; }
	else if (idx == 2) { threshold = 0.125; }
	else if (idx == 3) { threshold = 0.625; }
	else if (idx == 4) { threshold = 0.75; }
	else if (idx == 5) { threshold = 0.25; }
	else if (idx == 6) { threshold = 0.875; }
	else if (idx == 7) { threshold = 0.375; }
	else if (idx == 8) { threshold = 0.1875; }
	else if (idx == 9) { threshold = 0.6875; }
	else if (idx == 10) { threshold = 0.0625; }
	else if (idx == 11) { threshold = 0.5625; }
	else if (idx == 12) { threshold = 0.9375; }
	else if (idx == 13) { threshold = 0.4375; }
	else if (idx == 14) { threshold = 0.8125; }
	else { threshold = 0.3125; }

	ALBEDO = fog_color.rgb;
	// Discard pixels where fog hasn't reached yet (no alpha blend needed)
	if (fog_factor < threshold) { discard; }
}
