shader_type canvas_item;

// Whisper Glitch v2 — Corruption par paliers (BIBLE R75, v10.13.1).
// Port Godot 4.5 (hint_screen_texture) + uniform `desaturation` (palier « trouble »+).
// Overlay plein écran (mouse_filter IGNORE, visible=false au palier sain) : désaturation,
// micro-décalage RGB intermittent, scanlines brèves, teinte violette discrète (corruption).
// L'effet reste un « hoquet du monde », jamais un mur de bruit (lisibilité §23 : cap 0.50).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.1, 5.0) = 1.5;
uniform float shift_amount : hint_range(0.0, 0.02) = 0.005;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.15;
uniform vec4 tint_color : source_color = vec4(0.482, 0.310, 0.639, 0.06); // VIOLET #7B4FA3

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 base = texture(screen_tex, uv).rgb;
	float t = TIME * time_scale;

	// Décalage horizontal bref (~toutes les 2s), proportionnel à l'intensité.
	float shift_trigger = step(0.95, fract(t * 0.5));
	float h_shift = shift_amount * intensity * shift_trigger * sin(uv.y * 40.0 + t * 10.0);

	// Aberration chromatique subtile (split R/B).
	float r = texture(screen_tex, uv + vec2(h_shift, 0.0)).r;
	float b = texture(screen_tex, uv - vec2(h_shift, 0.0)).b;
	vec3 glitched = vec3(r, base.g, b);

	// Scanlines fines, seulement pendant le hoquet.
	glitched += sin(uv.y * 800.0 + t * 5.0) * scanline_strength * intensity * shift_trigger;

	// Désaturation graduée (palier R75) — le monde perd ses couleurs sous l'emprise.
	float grey = dot(glitched, vec3(0.299, 0.587, 0.114));
	glitched = mix(glitched, vec3(grey), desaturation);

	// Teinte violette discrète (signature corruption, jamais saturée).
	glitched = mix(glitched, tint_color.rgb, tint_color.a * intensity * 4.0);

	// Compose : remplace l'écran par sa version traitée (identité quand k→0 ; l'overlay est
	// de toute façon masqué — visible=false — au palier sain pour un coût GPU nul).
	float k = clamp(max(intensity, desaturation), 0.0, 1.0);
	COLOR = vec4(mix(base, glitched, k), 1.0);
}
