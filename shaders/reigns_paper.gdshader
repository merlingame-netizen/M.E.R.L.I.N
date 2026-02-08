shader_type canvas_item;

uniform vec4 paper_tint : source_color = vec4(0.96, 0.92, 0.84, 1.0);
uniform float grain_strength = 0.035;
uniform float vignette_strength = 0.12;
uniform float vignette_softness = 0.55;
uniform float grain_scale = 900.0;
uniform float grain_speed = 0.15;
uniform float warp_strength = 0.002;
uniform vec2 warp_speed = vec2(0.12, 0.08);

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 warp = vec2(
		sin(TIME * warp_speed.x + uv.y * 6.0),
		cos(TIME * warp_speed.y + uv.x * 6.0)
	) * warp_strength;
	vec2 warped_uv = uv + warp;
	float n = rand(warped_uv * grain_scale + TIME * grain_speed);
	float grain = (n - 0.5) * 2.0;
	float d = distance(uv, vec2(0.5));
	float vignette = smoothstep(vignette_softness, 0.92, d);
	vec3 color = paper_tint.rgb;
	color += grain * grain_strength;
	color -= vignette * vignette_strength;
	COLOR = vec4(color, 1.0);
}
