## GrassCarpet — Builds dense cross-billboard grass via MultiMesh.
## Each grass instance = 2 vertical quads at 90° (4 tris, 8 verts).
## Per-instance color variation via MultiMesh.use_colors.
## Wind animation via grass_wind_sway.gdshader material_override.

extends RefCounted

const GRASS_SHADER_PATH: String = "res://shaders/grass_wind_sway.gdshader"

## Base colors for vertical gradient (dark base → bright tip)
const COL_BASE: Color = Color(0.12, 0.22, 0.08, 0.9)
const COL_TIP: Color = Color(0.28, 0.50, 0.15, 0.9)

## Default blade dimensions
const BLADE_WIDTH: float = 0.15
const BLADE_HEIGHT: float = 0.5


## Build a cross-billboard mesh (2 vertical quads at 90°).
## Returns a Mesh with 4 triangles, 8 vertices, vertex colors baked in.
static func build_cross_mesh(width: float = BLADE_WIDTH, height: float = BLADE_HEIGHT) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var hw: float = width * 0.5

	# Quad 1: along X axis (front/back)
	_add_blade_quad(st, Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(hw, height, 0), Vector3(-hw, height, 0))

	# Quad 2: along Z axis (left/right), rotated 90°
	_add_blade_quad(st, Vector3(0, 0, -hw), Vector3(0, 0, hw), Vector3(0, height, hw), Vector3(0, height, -hw))

	return st.commit()


## Build a MultiMeshInstance3D grass carpet scattered within area.
## config keys: "color" (Color), "jitter" (float 0-1), "vis_end" (float)
func build(root: Node3D, rng: RandomNumberGenerator, area: Rect2, count: int, config: Dictionary = {}) -> MultiMeshInstance3D:
	var base_color: Color = config.get("color", Color(0.18, 0.42, 0.12, 0.9)) as Color
	var jitter: float = config.get("jitter", 0.25) as float
	var vis_end: float = config.get("vis_end", 8.0) as float

	var mesh: ArrayMesh = build_cross_mesh()

	var shader_mat: ShaderMaterial = _load_wind_shader()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count

	for i in count:
		var x: float = rng.randf_range(area.position.x, area.position.x + area.size.x)
		var z: float = rng.randf_range(area.position.y, area.position.y + area.size.y)
		var scale_f: float = rng.randf_range(0.5, 1.4)
		var rot_y: float = rng.randf_range(0.0, TAU)

		var t: Transform3D = Transform3D.IDENTITY
		t = t.scaled(Vector3(scale_f, scale_f, scale_f))
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = Vector3(x, 0.05, z)
		mm.set_instance_transform(i, t)

		# Per-instance color with jitter
		var h_shift: float = rng.randf_range(-jitter, jitter)
		var v_shift: float = rng.randf_range(-jitter * 0.5, jitter * 0.5)
		var col: Color = Color(
			clampf(base_color.r + h_shift * 0.1, 0.05, 0.5),
			clampf(base_color.g + h_shift * 0.15 + v_shift, 0.15, 0.7),
			clampf(base_color.b + h_shift * 0.05, 0.02, 0.3),
			base_color.a
		)
		mm.set_instance_color(i, col)

	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = vis_end
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mmi.name = "GrassCarpet"

	if shader_mat:
		mmi.material_override = shader_mat

	return mmi


## Build grass for a chunk (z_range based, used by BrocChunkManager).
func build_chunk(rng: RandomNumberGenerator, chunk_x_half: float, z_range: Vector2, count: int, config: Dictionary = {}) -> MultiMeshInstance3D:
	var area: Rect2 = Rect2(-chunk_x_half, z_range.x, chunk_x_half * 2.0, z_range.y - z_range.x)
	# Reuse build() with a null root (caller adds to scene tree)
	return build(null, rng, area, count, config)


static func _add_blade_quad(st: SurfaceTool, bl: Vector3, br: Vector3, tr: Vector3, tl: Vector3) -> void:
	# Bottom-left triangle
	st.set_color(COL_BASE)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(bl)

	st.set_color(COL_BASE)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(br)

	st.set_color(COL_TIP)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(tr)

	# Top-right triangle
	st.set_color(COL_BASE)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(bl)

	st.set_color(COL_TIP)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(tr)

	st.set_color(COL_TIP)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(tl)


func _load_wind_shader() -> ShaderMaterial:
	if not ResourceLoader.exists(GRASS_SHADER_PATH):
		return null
	var shader: Shader = load(GRASS_SHADER_PATH) as Shader
	if not shader:
		return null
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("wind_strength", 0.6)
	mat.set_shader_parameter("wind_speed", 1.8)
	mat.set_shader_parameter("turbulence", 0.3)
	return mat
