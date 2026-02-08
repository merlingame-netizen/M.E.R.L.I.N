shader_type canvas_item;

uniform float speed : hint_range(0.01, 1.0) = 0.3;
uniform float density : hint_range(0.05, 0.5) = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float col = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float sc = 6.0 + fi * 4.0;
		vec2 uv = UV * sc;
		uv.y -= TIME * speed * (0.6 + fi * 0.15);
		uv.x += sin(TIME * 0.15 * (fi + 1.0) + fi * 2.0) * 0.8;
		vec2 id = floor(uv);
		vec2 gf = fract(uv) - 0.5;
		float n = hash(id + fi * 73.0);
		if (n < density) {
			vec2 off = vec2(hash(id + 11.0) - 0.5, hash(id + 23.0) - 0.5) * 0.3;
			float d = length(gf - off);
			float sz = (1.5 + n * 1.5) / sc;
			col += smoothstep(sz, sz * 0.2, d) * (0.25 + fi * 0.06);
		}
	}
	col = clamp(col, 0.0, 0.6);
	COLOR = vec4(1.0, 1.0, 1.0, col * 0.35);
}
