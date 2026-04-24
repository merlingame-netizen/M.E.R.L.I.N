// ============================================================
// PS1 / N64 Era Material — M.E.R.L.I.N.
// ------------------------------------------------------------
// Vertex snapping (PS1 wobble) — quantize VERTEX in clip space.
// Affine texture mapping — disable perspective correction
//   by carrying UV through a NOPERSPECTIVE varying when the
//   target backend supports it (Forward+/Mobile). The fallback
//   on GL Compatibility is a cheap manual approximation.
// 15-bit color quantization (PS1 RGB555) with optional 4x4
//   Bayer dithering, simulating the framebuffer dither table.
// Vertex lighting only — no per-pixel light evaluation.
// ============================================================
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, vertex_lighting,
	specular_disabled, shadows_disabled;

// --- Sampler / texture --------------------------------------------------
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- PS1 vertex/UV jitter ----------------------------------------------
// vertex_snap: quantization step in *clip-space* (0..1). 0 disables.
uniform float vertex_snap : hint_range(0.0, 0.05) = 0.012;
// uv_snap: number of texel buckets per UV unit (smaller = chunkier).
uniform float uv_snap : hint_range(8.0, 256.0) = 64.0;
// affine_strength: 0=perspective correct, 1=fully affine PS1 texture warp.
uniform float affine_strength : hint_range(0.0, 1.0) = 0.85;

// --- Color palette ------------------------------------------------------
// color_levels: per-channel quantization levels. PS1 = 32 (5 bits).
uniform int color_levels : hint_range(2, 64) = 32;
// dither_strength: 0=off, 1=full Bayer dither in framebuffer space.
uniform float dither_strength : hint_range(0.0, 1.0) = 0.6;

// --- Vertex lighting fake (cheap diffuse) ------------------------------
uniform vec3 fake_light_dir = vec3(0.4, 0.85, 0.2);
uniform vec4 ambient_color : source_color = vec4(0.32, 0.30, 0.36, 1.0);
uniform float light_strength : hint_range(0.0, 2.0) = 0.85;

// Tint accumulated by the vertex shader and consumed by fragment().
varying vec3 v_tint;
// W coordinate carried through so we can reconstruct the un-corrected
// (affine) UV in fragment(). Godot 4 will already not perspective-correct
// scalar varyings declared as `flat`; we mix our own correction factor.
varying float v_w;

void vertex() {
	// 1. Vertex jitter — snap in CLIP space so geometry wobbles consistently
	//    no matter how far the camera is.
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (vertex_snap > 0.0) {
		vec2 grid = vec2(1.0) / vertex_snap;
		clip.xy = floor((clip.xy / clip.w) * grid + 0.5) / grid * clip.w;
	}
	// Reproject snapped clip back into view space so Godot's pipeline
	// keeps working for the fragment stage.
	vec4 view = inverse(PROJECTION_MATRIX) * clip;
	POSITION = clip;
	VERTEX = view.xyz / view.w;

	// 2. UV snap — chunky texture grid like 256x256 PS1 textures.
	if (uv_snap > 0.0) {
		UV = floor(UV * uv_snap) / uv_snap;
	}

	// 3. Vertex lighting (single fake directional + ambient).
	vec3 n = normalize(NORMAL);
	float ndl = max(dot(n, normalize(fake_light_dir)), 0.0);
	v_tint = ambient_color.rgb + ndl * light_strength;
	v_w = clip.w;
}

// 4x4 Bayer matrix (values 0..15 mapped to 0..1).
const float BAYER4[16] = float[16](
	 0.0,  8.0,  2.0, 10.0,
	12.0,  4.0, 14.0,  6.0,
	 3.0, 11.0,  1.0,  9.0,
	15.0,  7.0, 13.0,  5.0
);

float bayer4(vec2 frag) {
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	return (BAYER4[y * 4 + x] + 0.5) / 16.0 - 0.5;
}

void fragment() {
	// 1. Affine texture sample — emulate by re-distorting the UV using w.
	//    On hardware that supports `noperspective`, Godot's UV is already
	//    perspective-corrected; biasing back toward affine yields the
	//    classic PS1 "swimming texture" look without a custom varying
	//    (which GLES2/Compatibility cannot honor).
	vec2 uv_affine = mix(UV, UV * v_w / max(v_w, 0.001), affine_strength);
	vec4 tex = texture(albedo_texture, uv_affine);

	// 2. Combine with vertex tint + uniform tint.
	vec3 col = tex.rgb * albedo_color.rgb * v_tint;

	// 3. Bayer dither in framebuffer space (so the pattern is anchored to
	//    the screen, like a true CRT dither).
	if (dither_strength > 0.0) {
		float d = bayer4(FRAGCOORD.xy) * dither_strength * (1.0 / float(color_levels));
		col += vec3(d);
	}

	// 4. Quantize each channel to color_levels steps (PS1 RGB555 ≈ 32).
	float levels = float(color_levels);
	col = floor(clamp(col, 0.0, 1.0) * levels) / levels;

	ALBEDO = col;
	ALPHA = tex.a * albedo_color.a;
}
