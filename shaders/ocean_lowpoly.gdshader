shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.03, 0.12, 0.28, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.12, 0.35, 0.50, 1.0);
uniform vec4 foam_color : source_color = vec4(0.55, 0.70, 0.78, 1.0);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.2;
uniform float wave_height : hint_range(0.0, 3.0) = 0.8;
uniform float wave_frequency : hint_range(0.1, 5.0) = 1.5;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.6;

varying float vertex_height;
varying float depth_factor;

void vertex() {
	// Multi-frequency Gerstner-like waves
	float x = VERTEX.x;
	float z = VERTEX.z;
	float t = TIME * wave_speed;

	// 4 overlapping sine waves for organic motion
	float wave1 = sin(x * 0.15 + t * 1.0) * sin(z * 0.1 + t * 0.7);
	float wave2 = sin(x * 0.08 + z * 0.12 + t * 1.3) * 0.7;
	float wave3 = sin(x * 0.25 + t * 2.1) * sin(z * 0.18 - t * 0.5) * 0.4;
	float wave4 = sin(z * 0.3 + t * 0.9) * 0.3;

	float height = (wave1 + wave2 + wave3 + wave4) * wave_height;

	// Faceted look: quantize height to steps
	height = floor(height * 4.0) / 4.0;

	VERTEX.y += height;
	vertex_height = height;

	// Depth based on distance from camera (z position)
	depth_factor = clamp((VERTEX.z + 15.0) / -60.0, 0.0, 1.0);
}

void fragment() {
	// Color gradient: shallow near cliff -> deep far away
	vec3 base = mix(shallow_color.rgb, deep_color.rgb, depth_factor);

	// Foam on wave crests
	float foam = smoothstep(foam_threshold, foam_threshold + 0.15, vertex_height / wave_height);
	base = mix(base, foam_color.rgb, foam * 0.6);

	// Subtle variation based on position
	float noise = fract(sin(dot(vec2(UV.x * 10.0, UV.y * 10.0), vec2(12.9898, 78.233))) * 43758.5453);
	base += noise * 0.02;

	ALBEDO = base;
}
