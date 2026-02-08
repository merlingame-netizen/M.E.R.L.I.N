shader_type spatial;

// Optional access to screen texture; keeps SCREEN_TEXTURE declared for compatibility
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D albedo_texture : source_color;
uniform float vertex_snap = 0.02;
uniform float uv_snap = 64.0;

void vertex() {
	VERTEX.xyz = floor(VERTEX.xyz / vertex_snap) * vertex_snap;
	UV = floor(UV * uv_snap) / uv_snap;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb;
}
