shader_type canvas_item;

// Screen VFX shader — multi-effect overlay for Broceliande
// Supports: vignette, flash, color grading, glitch/distortion
// All effects controlled by uniforms, stackable

// --- Vignette ---
uniform float vignette_intensity : hint_range(0.0, 1.5) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// --- Flash ---
uniform float flash_alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- Color grading ---
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float hue_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;

// --- Glitch ---
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV;

	// --- Glitch: horizontal UV displacement ---
	if (glitch_amount > 0.01) {
		float line = floor(uv.y * 80.0);
		float noise = fract(sin(line * 43758.5453 + TIME * 12.0) * 43758.5453);
		float threshold = 1.0 - glitch_amount * 0.3;
		if (noise > threshold) {
			uv.x += (noise - threshold) * glitch_amount * 0.15 * sign(noise - 0.5);
		}
	}

	vec4 color = texture(TEXTURE, uv);

	// --- Scanlines ---
	if (scanline_intensity > 0.01) {
		float scan = sin(SCREEN_UV.y * 600.0) * 0.5 + 0.5;
		color.rgb *= 1.0 - scanline_intensity * scan * 0.3;
	}

	// --- Color grading ---
	// Desaturation
	if (desaturation > 0.01) {
		float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		color.rgb = mix(color.rgb, vec3(grey), desaturation);
	}

	// Hue shift
	if (abs(hue_shift) > 0.01) {
		vec3 hsv = rgb_to_hsv(color.rgb);
		hsv.x = fract(hsv.x + hue_shift);
		color.rgb = hsv_to_rgb(hsv);
	}

	// Contrast + brightness
	color.rgb = (color.rgb - 0.5) * contrast + 0.5 + brightness;

	// --- Vignette ---
	if (vignette_intensity > 0.01) {
		vec2 center = UV - 0.5;
		float dist = length(center) * 1.414;
		float vig = smoothstep(0.3, 1.0, dist) * vignette_intensity;
		color.rgb = mix(color.rgb, vignette_color.rgb, vig);
	}

	// --- Flash overlay ---
	if (flash_alpha > 0.01) {
		color.rgb = mix(color.rgb, flash_color.rgb, flash_alpha);
	}

	// --- Chromatic aberration (glitch) ---
	if (glitch_amount > 0.05) {
		float offset = glitch_amount * 0.005;
		float r = texture(TEXTURE, uv + vec2(offset, 0.0)).r;
		float b = texture(TEXTURE, uv - vec2(offset, 0.0)).b;
		color.r = mix(color.r, r, glitch_amount);
		color.b = mix(color.b, b, glitch_amount);
	}

	COLOR = color;
}
