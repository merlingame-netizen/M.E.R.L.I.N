shader_type canvas_item;

// Explicit screen texture access (Godot 4.5 requires SCREEN_TEXTURE declaration)
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
// Pixel size (higher = chunkier pixels)
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
// Palette steps per channel
uniform float color_levels : hint_range(2.0, 32.0) = 8.0;
// Edge intensity
uniform float outline_strength : hint_range(0.0, 2.0) = 0.5;
// Edge color
uniform vec4 outline_color : source_color = vec4(0.1, 0.05, 0.02, 1.0);
// Saturation factor
uniform float saturation : hint_range(0.0, 2.0) = 1.2;
// Contrast factor
uniform float contrast : hint_range(0.5, 2.0) = 1.1;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	
	// Pixelisation
	vec2 pixel_uv = floor(uv * screen_size / pixel_size) * pixel_size / screen_size;
	
	// Sample pixelated color
	vec4 col = texture(SCREEN_TEXTURE, pixel_uv);
	
	// Reduce palette (posterize)
	col.rgb = floor(col.rgb * color_levels) / color_levels;
	
	// Boost saturation
	float grey = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(vec3(grey), col.rgb, saturation);
	
	// Boost contrast
	col.rgb = (col.rgb - 0.5) * contrast + 0.5;
	
	// Simple edge detection (light Sobel)
	float offset = pixel_size / screen_size.x;
	vec4 left = texture(SCREEN_TEXTURE, pixel_uv + vec2(-offset, 0));
	vec4 right = texture(SCREEN_TEXTURE, pixel_uv + vec2(offset, 0));
	vec4 up = texture(SCREEN_TEXTURE, pixel_uv + vec2(0, -offset));
	vec4 down = texture(SCREEN_TEXTURE, pixel_uv + vec2(0, offset));
	
	float edge = length(left.rgb - right.rgb) + length(up.rgb - down.rgb);
	edge = smoothstep(0.1, 0.3, edge);
	
	// Apply outline
	col.rgb = mix(col.rgb, outline_color.rgb, edge * outline_strength);
	
	// Final clamp
	col.rgb = clamp(col.rgb, 0.0, 1.0);
	
	COLOR = col;
}
