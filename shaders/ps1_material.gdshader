shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float vertex_snap : hint_range(0.005, 0.1) = 0.02;
uniform float uv_snap : hint_range(8.0, 128.0) = 64.0;
uniform float color_levels : hint_range(2.0, 32.0) = 16.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xyz = floor(clip.xyz / vertex_snap * clip.w) * vertex_snap / clip.w;
	POSITION = clip;
	UV = floor(UV * uv_snap) / uv_snap;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 col = tex.rgb * albedo_color.rgb;
	float levels = color_levels - 1.0;
	col = floor(col * levels + 0.5) / levels;
	ALBEDO = col;
	ALPHA = tex.a * albedo_color.a;
}
