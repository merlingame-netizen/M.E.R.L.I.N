shader_type spatial;
render_mode vertex_lighting, cull_disabled;

// ═══════════════════════════════════════════════════════════════════════════════
// Grass Wind Sway Shader — M.E.R.L.I.N. Celtic PS1 Aesthetic
// ═══════════════════════════════════════════════════════════════════════════════
// Applied as material_overlay on grass MeshInstance3D via BrocGrassWind.
// UV.y drives sway amplitude: 0=root (grounded), 1=tip (full sway).
// PS1-style: quantized vertex stutter, vertex lighting, faceted look.
// Celtic low-poly palette: forest greens with sunlit tips.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Wind Parameters ──────────────────────────────────────────────────────────
uniform float wind_speed : hint_range(0.1, 5.0) = 1.5;
uniform float wind_strength : hint_range(0.0, 1.5) = 0.35;
uniform float wind_frequency : hint_range(0.5, 8.0) = 2.5;

// PS1 vertex quantization step (0=smooth, 0.03=PS1 stutter, 0.06=N64 chop)
uniform float vertex_snap : hint_range(0.0, 0.1) = 0.03;

// ── Visual Parameters ────────────────────────────────────────────────────────
// Biome-driven color tint set by BrocGrassWind
uniform vec4 grass_color : source_color = vec4(0.22, 0.48, 0.18, 1.0);
uniform vec4 tip_tint : source_color = vec4(0.55, 0.78, 0.32, 1.0);

// Sway falloff from root (UV.y=0) to tip (UV.y=1)
// higher power = tips move much more than roots (more natural look)
uniform float height_power : hint_range(0.5, 3.0) = 1.8;

varying float v_uv_y;

void vertex() {
	v_uv_y = UV.y;

	// Height-based sway: clamp UV.y, apply power curve so roots stay grounded
	float sway_amt = pow(clamp(UV.y, 0.0, 1.0), height_power);

	// World-space X/Z for phase coherence across neighbouring grass instances
	vec3 world_v = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wind_speed;

	// Two-frequency horizontal wind sway (primary + flutter)
	float wx = sin(world_v.x * wind_frequency * 0.40 + t) +
	           sin(world_v.z * wind_frequency * 0.30 + t * 1.30) * 0.50;
	float wz = cos(world_v.z * wind_frequency * 0.35 + t * 0.90) +
	           cos(world_v.x * wind_frequency * 0.25 + t * 1.20) * 0.50;

	// PS1 vertex snap: quantize wind displacement for stutter-sway look
	if (vertex_snap > 0.001) {
		wx = floor(wx / vertex_snap) * vertex_snap;
		wz = floor(wz / vertex_snap) * vertex_snap;
	}

	// Apply lateral displacement only — no Y lift (grass bends, doesn't float)
	VERTEX.x += wx * wind_strength * sway_amt;
	VERTEX.z += wz * wind_strength * sway_amt;
}

void fragment() {
	// Base-to-tip color gradient via UV.y
	ALBEDO = mix(grass_color.rgb, tip_tint.rgb, clamp(v_uv_y, 0.0, 1.0));
	ROUGHNESS = 0.92;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
