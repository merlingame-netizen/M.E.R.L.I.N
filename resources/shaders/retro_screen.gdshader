shader_type canvas_item;
render_mode unshaded;

uniform vec2 render_size = vec2(320.0, 180.0);
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float curvature = 0.06;
uniform float scanline_strength = 0.18;
uniform float grid_strength = 0.12;
uniform float noise_strength = 0.04;
uniform float vignette_strength = 0.25;
uniform float color_levels = 3.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	uv += uv * r * r * curvature;
	uv = uv * 0.5 + 0.5;
	vec4 col = vec4(0.0, 0.0, 0.0, 1.0);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		col = texture(TEXTURE, uv);

		float scan = 0.5 + 0.5 * sin(uv.y * render_size.y * 3.14159);
		col.rgb *= mix(1.0, scan, scanline_strength);

		vec2 grid = fract(uv * render_size);
		float g = step(grid.x, 0.02) + step(grid.y, 0.02);
		col.rgb *= 1.0 - g * grid_strength;

		float n = rand(uv * render_size + TIME);
		col.rgb += (n - 0.5) * noise_strength;

		col.rgb = floor(col.rgb * color_levels) / color_levels;

		float vignette = smoothstep(1.0, 0.35, r);
		col.rgb *= mix(1.0 - vignette_strength, 1.0, vignette);
	}

	COLOR = col;
}
