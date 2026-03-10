extends RefCounted
## BrocGrassWind — Spawn wind-blown grass patches with shader-driven sway.
## Uses grass_wind_sway.gdshader as material_overlay on grass GLB instances.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _shader: Shader
var _instances: Array[Node3D] = []


func _init(
	forest_root: Node3D,
	path_points: PackedVector3Array,
	zone_centers: Array[Vector3],
	grass_tall_scene: PackedScene,
	grass_short_scene: PackedScene
) -> void:
	_rng.randomize()
	_shader = _try_load_shader("res://shaders/grass_wind_sway.gdshader")

	if not grass_tall_scene and not grass_short_scene:
		push_warning("[BrocGrassWind] No grass scenes available")
		return

	var count: int = 0

	# Along path borders (every 3 waypoints)
	for i in range(0, path_points.size() - 1, 3):
		var center: Vector3 = path_points[i]
		var next_idx: int = mini(i + 3, path_points.size() - 1)
		var forward: Vector3 = (path_points[next_idx] - center).normalized()
		var right: Vector3 = forward.cross(Vector3.UP).normalized()

		# 2-3 grass per side
		for side in [-1.0, 1.0]:
			var num: int = _rng.randi_range(1, 3)
			for _j in range(num):
				var offset: float = _rng.randf_range(1.0, 3.5) * side
				var scatter: Vector3 = Vector3(
					_rng.randf_range(-0.6, 0.6),
					0.0,
					_rng.randf_range(-0.6, 0.6)
				)
				var pos: Vector3 = center + right * offset + scatter
				var scene: PackedScene = grass_tall_scene if _rng.randf() > 0.4 else grass_short_scene
				if scene:
					var inst: Node3D = _spawn_grass(scene, pos, forest_root)
					if inst:
						count += 1

	# Extra clusters in clearings (Z3, Z6, Z7)
	var clearing_zones: Array[int] = [2, 5, 6]
	for zi in clearing_zones:
		if zi < zone_centers.size():
			var zc: Vector3 = zone_centers[zi]
			for _k in range(8):
				var pos: Vector3 = zc + Vector3(
					_rng.randf_range(-6.0, 6.0),
					0.0,
					_rng.randf_range(-6.0, 6.0)
				)
				var scene: PackedScene = grass_tall_scene if _rng.randf() > 0.3 else grass_short_scene
				if scene:
					var inst: Node3D = _spawn_grass(scene, pos, forest_root)
					if inst:
						count += 1

	print("[BrocGrassWind] Spawned %d grass instances with wind shader" % count)


func _spawn_grass(scene: PackedScene, pos: Vector3, parent: Node3D) -> Node3D:
	var raw: Node = scene.instantiate()
	var instance: Node3D = raw as Node3D
	if not instance:
		raw.queue_free()
		return null
	instance.position = pos
	instance.scale = Vector3.ONE * _rng.randf_range(0.5, 1.2)
	instance.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	parent.add_child(instance)
	_instances.append(instance)

	# Apply wind shader overlay
	if _shader:
		_apply_wind_shader(instance)

	return instance


func _apply_wind_shader(node: Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst: MeshInstance3D = child as MeshInstance3D
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = _shader
			mat.set_shader_parameter("wind_strength", _rng.randf_range(0.4, 0.8))
			mat.set_shader_parameter("wind_speed", _rng.randf_range(1.2, 2.2))
			mat.set_shader_parameter("turbulence", _rng.randf_range(0.2, 0.5))
			mesh_inst.material_overlay = mat
		elif child is Node3D:
			_apply_wind_shader(child as Node3D)


func _try_load_shader(path: String) -> Shader:
	if ResourceLoader.exists(path):
		return load(path) as Shader
	return null
