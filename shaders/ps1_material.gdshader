shader_type spatial;

// PS1/N64 Material — Vertex jitter, clip-space snapping, color banding
// Applied to 3D meshes via BrocRetroMaterials for authentic retro rendering.
// Preserves lighting (Gouraud-like at 320x180) while adding PS1 character.

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float vertex_snap_res : hint_range(32.0, 320.0) = 160.0;
uniform float jitter_intensity : hint_range(0.0, 0.03) = 0.006;
uniform float color_depth : hint_range(8.0, 256.0) = 32.0;
uniform float uv_snap : hint_range(16.0, 256.0) = 128.0;
uniform bool use_texture = true;

void vertex() {
	// PS1 clip-space vertex snapping — vertices lock to a virtual screen grid
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(vertex_snap_res);
	clip.xy = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;

	// Temporal vertex jitter — the signature PS1 polygon shimmer
	if (jitter_intensity > 0.001) {
		float h1 = fract(sin(dot(VERTEX.xz + vec2(TIME * 3.0), vec2(127.1, 311.7))) * 43758.5453);
		float h2 = fract(sin(dot(VERTEX.yz + vec2(TIME * 3.0), vec2(269.5, 183.3))) * 43758.5453);
		clip.xy += vec2(h1 - 0.5, h2 - 0.5) * 2.0 * jitter_intensity * clip.w;
	}

	POSITION = clip;

	// UV quantization — PS1 texture coordinate precision was limited
	UV = floor(UV * uv_snap + 0.5) / uv_snap;
}

void fragment() {
	vec4 tex_color = vec4(1.0);
	if (use_texture) {
		tex_color = texture(albedo_texture, UV);
	}

	// PS1-style binary transparency (1-bit alpha — no blending)
	if (tex_color.a < 0.5) {
		discard;
	}

	vec3 col = tex_color.rgb * albedo_color.rgb;

	// PS1 15-bit color depth (32 levels per channel)
	col = floor(col * color_depth + 0.5) / color_depth;

	ALBEDO = col;
}
