shader_type spatial;
render_mode unshaded, cull_disabled;

// World Edge Fog — The boundary of generated reality.
// Used for the "world_edge" whisper: the forest stops, then rebuilds.
// A vertical fog wall that pulses subtly, hinting at the void beyond.

uniform vec4 fog_color : source_color = vec4(0.08, 0.15, 0.08, 0.85);
uniform vec4 edge_glow : source_color = vec4(0.15, 0.6, 0.25, 0.3);
uniform float pulse_speed : hint_range(0.1, 3.0) = 0.8;
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;
uniform float edge_fade : hint_range(0.1, 2.0) = 0.5;
uniform float void_depth : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Base fog with vertical gradient
	float height_factor = clamp(world_pos.y * 0.2 + 0.5, 0.0, 1.0);

	// Noise-like pattern from world position
	float noise = fract(sin(dot(world_pos.xz * noise_scale, vec2(12.9898, 78.233))) * 43758.5453);
	noise = noise * 0.3 + 0.7;

	// Pulse — slow breathing of the void
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

	// Edge glow at the boundary
	float glow = pow(1.0 - height_factor, 2.0) * edge_glow.a * pulse;

	// Mix fog + glow
	vec3 color = mix(fog_color.rgb, edge_glow.rgb, glow);

	// Void darkness behind
	color = mix(vec3(0.0), color, noise * pulse);

	// Alpha: dense at center, fading at edges
	float alpha = fog_color.a * height_factor * noise * pulse;
	alpha = clamp(alpha, void_depth, fog_color.a);

	ALBEDO = color;
	ALPHA = alpha;
}
