extends RefCounted
## BrocSeason — Season system with particle overlay and vegetation tint.
## Uses existing seasonal_particles.gdshader for 2D overlay.

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_NAMES: Array[String] = ["Printemps", "Ete", "Automne", "Hiver"]

const VEGETATION_TINTS: Array[Color] = [
	Color(0.65, 0.90, 0.50),  # Spring — bright green
	Color(0.40, 0.70, 0.30),  # Summer — deep green
	Color(0.75, 0.50, 0.20),  # Autumn — orange-gold
	Color(0.55, 0.55, 0.52),  # Winter — desaturated grey
]

const GROUND_TINTS: Array[Color] = [
	Color(0.28, 0.38, 0.18),  # Spring — fresh green-brown
	Color(0.22, 0.32, 0.14),  # Summer — deep green
	Color(0.35, 0.25, 0.12),  # Autumn — brown-orange
	Color(0.40, 0.40, 0.38),  # Winter — grey-brown
]

const PARTICLE_COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.90, 0.7),   # Spring — pink petals
	Color(1.0, 1.0, 0.8, 0.3),     # Summer — heat shimmer
	Color(0.85, 0.55, 0.15, 0.8),  # Autumn — orange leaves
	Color(0.95, 0.97, 1.0, 0.9),   # Winter — white snow
]

var _current: int = Season.SPRING
var _overlay: ColorRect
var _shader_mat: ShaderMaterial
var _forest_root: Node3D
var _original_materials: Dictionary = {}


func _init(forest_root: Node3D, viewport_parent: Node) -> void:
	_forest_root = forest_root
	_current = _season_from_system_month()
	_setup_overlay(viewport_parent)
	apply(_current)


func get_current() -> int:
	return _current


func get_name() -> String:
	return SEASON_NAMES[_current]


func cycle_next() -> void:
	_current = (_current + 1) % 4
	apply(_current)


func apply(season: int) -> void:
	_current = season

	# Update shader overlay
	if _shader_mat:
		_shader_mat.set_shader_parameter("season_type", season)
		_shader_mat.set_shader_parameter("particle_color", PARTICLE_COLORS[season])
		_shader_mat.set_shader_parameter("particle_density", 0.4 if season != Season.SUMMER else 0.2)
		_shader_mat.set_shader_parameter("animation_speed", 1.0)

	# Tint vegetation
	_apply_vegetation_tint(VEGETATION_TINTS[season])

	print("[BrocSeason] Applied: %s" % SEASON_NAMES[season])


func _setup_overlay(parent: Node) -> void:
	var shader_res: Shader = _try_load_shader("res://shaders/seasonal_particles.gdshader")
	if not shader_res:
		push_warning("[BrocSeason] seasonal_particles.gdshader not found")
		return

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader_res

	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.material = _shader_mat
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add as CanvasLayer so it renders on top of the 3D viewport
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 5
	canvas.name = "SeasonOverlay"
	canvas.add_child(_overlay)
	parent.add_child(canvas)


func _apply_vegetation_tint(tint: Color) -> void:
	# Tint vegetation by overriding albedo on StandardMaterial3D surfaces
	for child in _forest_root.get_children():
		if child is Node3D:
			_tint_recursive(child as Node3D, tint)


func _tint_recursive(node: Node3D, tint: Color) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		for surf_idx in range(mesh_inst.mesh.get_surface_count() if mesh_inst.mesh else 0):
			var mat: Material = mesh_inst.get_active_material(surf_idx)
			if mat is StandardMaterial3D:
				var std_mat: StandardMaterial3D = mat as StandardMaterial3D
				var id: int = mesh_inst.get_instance_id() * 100 + surf_idx
				# Store original albedo once
				if not _original_materials.has(id):
					_original_materials[id] = std_mat.albedo_color
				# Apply tint as multiply blend with original
				var original: Color = _original_materials[id] as Color
				std_mat.albedo_color = Color(
					clampf(original.r * tint.r * 2.0, 0.0, 1.0),
					clampf(original.g * tint.g * 2.0, 0.0, 1.0),
					clampf(original.b * tint.b * 2.0, 0.0, 1.0),
					original.a
				)

	for child in node.get_children():
		if child is Node3D:
			_tint_recursive(child as Node3D, tint)


func _try_load_shader(path: String) -> Shader:
	if ResourceLoader.exists(path):
		return load(path) as Shader
	return null


static func _season_from_system_month() -> int:
	## Map real month to season: Mar-May=SPRING, Jun-Aug=SUMMER, Sep-Nov=AUTUMN, Dec-Feb=WINTER
	var month: int = Time.get_datetime_dict_from_system()["month"]
	if month >= 3 and month <= 5:
		return Season.SPRING
	elif month >= 6 and month <= 8:
		return Season.SUMMER
	elif month >= 9 and month <= 11:
		return Season.AUTUMN
	else:
		return Season.WINTER
