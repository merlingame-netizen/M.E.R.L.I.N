extends RefCounted
## BrocRetroMaterials — PS1/N64 vertex jitter + color banding on all 3D meshes.
## Walks the forest node tree, replaces surface materials with ps1_material.gdshader
## while preserving original albedo textures and colors.

const PS1_SHADER_PATH: String = "res://shaders/ps1_material.gdshader"

var _ps1_shader: Shader
var _materials: Array[ShaderMaterial] = []
var _mesh_count: int = 0

const JITTER_BY_CATEGORY: Dictionary = {
	"tree": 0.003,
	"bush": 0.005,
	"rock": 0.002,
	"creature": 0.008,
	"megalith": 0.001,
	"mushroom": 0.006,
	"deadwood": 0.004,
	"groundcover": 0.004,
	"structure": 0.002,
	"collectible": 0.007,
	"prop": 0.003,
	"default": 0.005,
}

const SKIP_NAMES: Array[String] = [
	"ground", "terrain", "floor", "path", "road",
	"fog", "mist", "ray", "particle", "curtain",
]


func apply_to_tree(root: Node3D) -> void:
	_ps1_shader = load(PS1_SHADER_PATH) as Shader
	if not _ps1_shader:
		push_warning("[BrocRetroMaterials] PS1 shader not found at %s" % PS1_SHADER_PATH)
		return
	_walk_and_apply(root, "default")
	print("[BrocRetroMaterials] Applied PS1 material to %d mesh surfaces" % _mesh_count)


func _walk_and_apply(node: Node, category: String) -> void:
	var cat: String = _detect_category(node.name)
	if cat != "":
		category = cat

	if _should_skip(node.name):
		return

	if node is MeshInstance3D:
		_apply_ps1_to_mesh(node as MeshInstance3D, category)

	for child in node.get_children():
		_walk_and_apply(child, category)


func _apply_ps1_to_mesh(mesh: MeshInstance3D, category: String) -> void:
	if not mesh.mesh:
		return
	if mesh.mesh.get_surface_count() == 0:
		return
	if mesh.get_surface_override_material(0) is ShaderMaterial:
		return

	var jitter: float = JITTER_BY_CATEGORY.get(category, JITTER_BY_CATEGORY["default"])

	for surface_idx in mesh.mesh.get_surface_count():
		var orig_mat: Material = mesh.get_active_material(surface_idx)
		var albedo_tex: Texture2D = null
		var albedo_col: Color = Color.WHITE

		if orig_mat is BaseMaterial3D:
			var base_mat: BaseMaterial3D = orig_mat as BaseMaterial3D
			albedo_tex = base_mat.albedo_texture
			albedo_col = base_mat.albedo_color

		var ps1_mat: ShaderMaterial = ShaderMaterial.new()
		ps1_mat.shader = _ps1_shader
		if albedo_tex:
			ps1_mat.set_shader_parameter("albedo_texture", albedo_tex)
		ps1_mat.set_shader_parameter("albedo_color", albedo_col)
		ps1_mat.set_shader_parameter("jitter_intensity", jitter)
		ps1_mat.set_shader_parameter("use_texture", albedo_tex != null)
		ps1_mat.set_shader_parameter("vertex_snap_res", 160.0)
		ps1_mat.set_shader_parameter("color_depth", 32.0)
		ps1_mat.set_shader_parameter("uv_snap", 128.0)

		mesh.set_surface_override_material(surface_idx, ps1_mat)
		_materials.append(ps1_mat)
		_mesh_count += 1


func set_jitter_intensity(intensity: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter("jitter_intensity", intensity)


func set_color_depth(depth: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter("color_depth", depth)


func set_snap_resolution(res: float) -> void:
	for mat in _materials:
		mat.set_shader_parameter("vertex_snap_res", res)


func _detect_category(node_name: String) -> String:
	var lower: String = node_name.to_lower()
	for cat: String in JITTER_BY_CATEGORY:
		if cat == "default":
			continue
		if cat in lower:
			return cat
	if "menhir" in lower or "dolmen" in lower or "stone_circle" in lower:
		return "megalith"
	if "korrigan" in lower or "doe" in lower or "wolf" in lower or "raven" in lower:
		return "creature"
	return ""


func _should_skip(node_name: String) -> bool:
	var lower: String = node_name.to_lower()
	for skip: String in SKIP_NAMES:
		if skip in lower:
			return true
	return false
