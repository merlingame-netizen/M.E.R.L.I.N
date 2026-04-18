shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float global_intensity : hint_range(0.0, 1.0) = 0.7;

uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;

uniform float color_depth : hint_range(8.0, 64.0) = 32.0;

uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;

uniform float scanline_opacity : hint_range(0.0, 0.5) = 0.08;
uniform float scanline_count : hint_range(100.0, 600.0) = 240.0;

uniform vec4 tint_color : source_color = vec4(1.0, 0.96, 0.90, 1.0);
uniform float tint_blend : hint_range(0.0, 0.3) = 0.06;

uniform float saturation_boost : hint_range(0.8, 1.6) = 1.15;

uniform float curvature : hint_range(0.0, 0.08) = 0.02;

uniform float vignette_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float vignette_softness : hint_range(0.2, 1.0) = 0.6;

uniform float contrast : hint_range(0.8, 1.4) = 1.05;
uniform float brightness : hint_range(-0.1, 0.1) = 0.0;

uniform float fog_blend : hint_range(0.0, 0.3) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.12, 0.10, 0.18, 1.0);

float bayer4x4(ivec2 pos) {
	int x = pos.x % 4;
	int y = pos.y % 4;
	int index = x + y * 4;
	float values[16] = float[16](
		0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return values[index];
}

void fragment() {
	vec2 uv = UV;

	if (global_intensity < 0.001) {
		COLOR = texture(screen_texture, uv);
		return;
	}

	vec2 center_dist = uv - 0.5;
	float dist = length(center_dist);

	if (curvature > 0.0) {
		float r2 = dot(center_dist, center_dist);
		uv = 0.5 + center_dist * (1.0 + r2 * curvature * global_intensity);
	}

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float ps = mix(1.0, pixel_size, global_intensity);
	vec2 pixel_uv = uv;
	if (ps > 1.01) {
		pixel_uv = floor(uv * screen_size / ps) * ps / screen_size;
	}

	vec4 col = texture(screen_texture, pixel_uv);

	col.rgb = (col.rgb - 0.5) * mix(1.0, contrast, global_intensity) + 0.5
	          + brightness * global_intensity;

	float grey = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(grey), col.rgb, mix(1.0, saturation_boost, global_intensity));

	if (tint_blend > 0.0) {
		col.rgb = mix(col.rgb, col.rgb * tint_color.rgb, tint_blend * global_intensity);
	}

	if (fog_blend > 0.0) {
		col.rgb = mix(col.rgb, fog_color.rgb, fog_blend * global_intensity);
	}

	float levels = mix(64.0, color_depth, global_intensity) - 1.0;
	if (dither_strength > 0.0) {
		ivec2 sp = ivec2(FRAGCOORD.xy);
		float threshold = bayer4x4(sp);
		vec3 q = col.rgb * levels;
		q += (threshold - 0.5) * dither_strength * global_intensity;
		col.rgb = floor(q + 0.5) / levels;
	} else {
		col.rgb = floor(col.rgb * levels + 0.5) / levels;
	}

	if (scanline_opacity > 0.0) {
		float scan = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		scan = pow(scan, 2.0);
		col.rgb *= 1.0 - scan * scanline_opacity * global_intensity;
	}

	if (vignette_intensity > 0.0) {
		float vig = 1.0 - smoothstep(vignette_softness, 1.0, dist * 2.0);
		col.rgb *= mix(1.0, vig, vignette_intensity * global_intensity);
	}

	col.rgb = clamp(col.rgb, 0.0, 1.0);
	COLOR = col;
}
