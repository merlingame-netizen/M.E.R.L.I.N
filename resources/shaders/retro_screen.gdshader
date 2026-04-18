shader_type canvas_item;
render_mode unshaded;

uniform vec2 render_size = vec2(320.0, 180.0);
uniform vec2 screen_size = vec2(1280.0, 720.0);

// CRT barrel distortion
uniform float curvature : hint_range(0.0, 0.2) = 0.04;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

// Scanlines
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.15;

// Color quantization (PS1 = 15-bit color ~ 32 levels/channel)
uniform float color_levels : hint_range(2.0, 32.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 0.5) = 0.12;
uniform float saturation : hint_range(0.0, 1.5) = 0.85;

// Warm CRT phosphor tint
uniform vec3 warm_shift = vec3(1.04, 0.98, 0.90);

// Chromatic aberration (CRT RGB convergence error)
uniform float chroma_offset : hint_range(0.0, 0.005) = 0.001;

// Phosphor bleed (horizontal color spread from CRT electron beam)
uniform float bleed_amount : hint_range(0.0, 0.01) = 0.002;

// Film grain
uniform float noise_strength : hint_range(0.0, 0.1) = 0.03;

// Interlace field flicker
uniform float interlace_strength : hint_range(0.0, 0.15) = 0.04;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer4x4(vec2 pos) {
	ivec2 p = ivec2(pos) % 4;
	int idx = p.x + p.y * 4;
	float m[16] = float[16](
		0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return m[idx];
}

void fragment() {
	// CRT barrel distortion
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	uv += uv * r * r * curvature;
	uv = uv * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	// Chromatic aberration — RGB sampled at offset UVs
	float cr = texture(TEXTURE, uv + vec2(chroma_offset, 0.0)).r;
	float cg = texture(TEXTURE, uv).g;
	float cb = texture(TEXTURE, uv - vec2(chroma_offset, 0.0)).b;
	vec3 col = vec3(cr, cg, cb);

	// Phosphor bleed — horizontal color averaging
	vec3 left = texture(TEXTURE, uv - vec2(bleed_amount, 0.0)).rgb;
	vec3 right = texture(TEXTURE, uv + vec2(bleed_amount, 0.0)).rgb;
	col = mix(col, (col + left + right) / 3.0, 0.35);

	// Warm phosphor shift
	col *= warm_shift;

	// Desaturation (PS1/N64 slightly washed palette)
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// Bayer 4x4 ordered dithering + color quantization
	vec2 pixel_pos = uv * render_size;
	float threshold = bayer4x4(pixel_pos);
	float levels = color_levels - 1.0;
	vec3 dithered = col * levels;
	dithered += (threshold - 0.5) * dither_strength;
	col = floor(dithered + 0.5) / levels;

	// Scanlines
	float scan = 0.5 + 0.5 * sin(uv.y * render_size.y * 3.14159);
	col *= mix(1.0, scan, scanline_strength);

	// Interlace field flicker
	float field = mod(floor(uv.y * render_size.y), 2.0);
	float flicker = mod(TIME * 30.0, 2.0) < 1.0 ? field : 1.0 - field;
	col *= 1.0 - flicker * interlace_strength;

	// Film grain
	float n = rand(uv * render_size + TIME * 0.7);
	col += (n - 0.5) * noise_strength;

	// Vignette
	float vignette = smoothstep(1.0, 0.35, r);
	col *= mix(1.0 - vignette_strength, 1.0, vignette);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
