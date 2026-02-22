shader_type canvas_item;

// Iridescent border shimmer for Calendrier des Brumes event cards.
// Applied to PanelContainer — animates a subtle color shift on the border area.

uniform float speed : hint_range(0.1, 3.0) = 0.6;
uniform float intensity : hint_range(0.0, 1.0) = 0.35;
uniform float border_width : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// Detect border region (near edges of the UV rect)
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border_mask = smoothstep(0.0, border_width, edge);
	border_mask = 1.0 - border_mask;

	// Iridescent hue shift based on position + time
	float hue = fract(UV.x * 0.5 + UV.y * 0.3 + TIME * speed);
	vec3 iridescence = vec3(
		0.5 + 0.5 * sin(hue * 6.2832),
		0.5 + 0.5 * sin(hue * 6.2832 + 2.094),
		0.5 + 0.5 * sin(hue * 6.2832 + 4.189)
	);

	vec3 mixed = mix(base.rgb, iridescence, border_mask * intensity);
	COLOR = vec4(mixed, base.a);
}
