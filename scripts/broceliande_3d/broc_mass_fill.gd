extends RefCounted
## BrocMassFill — Massive vegetation fill with color variation and LOD.
## Spawns 300-500 extra objects outside the path for dense forest feel.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func populate(
	path_points: PackedVector3Array,
	zone_centers: Array[Vector3],
	forest_root: Node3D,
	tree_scenes: Array[PackedScene],
	bush_scenes: Array[PackedScene],
	detail_scenes: Dictionary,
	broc_scenes: Dictionary
) -> int:
	var count: int = 0
	var min_path_dist: float = 5.0  # Minimum distance from path

	# Dense trees between zones
	for zi in range(zone_centers.size()):
		var zc: Vector3 = zone_centers[zi]
		var tree_count: int = _rng.randi_range(20, 35)
		for _i in range(tree_count):
			var pos: Vector3 = zc + _roff(8.0, 30.0)
			if _is_too_close_to_path(pos, path_points, min_path_dist):
				continue
			if not tree_scenes.is_empty():
				var scene: PackedScene = tree_scenes[_rng.randi_range(0, tree_scenes.size() - 1)]
				var inst: Node3D = _spawn(scene, pos, _rng.randf_range(3.0, 5.5), forest_root, 60.0)
				if inst:
					_apply_color_tint(inst)
					count += 1

	# Bushes and flowers scattered everywhere
	for zi in range(zone_centers.size()):
		var zc: Vector3 = zone_centers[zi]
		# Bushes
		var bush_count: int = _rng.randi_range(8, 15)
		for _i in range(bush_count):
			var pos: Vector3 = zc + _roff(5.0, 25.0)
			if _is_too_close_to_path(pos, path_points, min_path_dist):
				continue
			if not bush_scenes.is_empty():
				var scene: PackedScene = bush_scenes[_rng.randi_range(0, bush_scenes.size() - 1)]
				var inst: Node3D = _spawn(scene, pos, _rng.randf_range(1.5, 3.0), forest_root, 40.0)
				if inst:
					_apply_color_tint(inst)
					count += 1

		# Flowers (daisy, mushrooms) for color
		var flower_keys: Array[String] = ["daisy", "mushroom_red", "mushroom_group", "fern", "rock_small"]
		for _i in range(_rng.randi_range(6, 12)):
			var key: String = flower_keys[_rng.randi_range(0, flower_keys.size() - 1)]
			if not detail_scenes.has(key):
				continue
			var pos: Vector3 = zc + _roff(4.0, 22.0)
			if _is_too_close_to_path(pos, path_points, min_path_dist):
				continue
			var inst: Node3D = _spawn(detail_scenes[key], pos, _rng.randf_range(1.5, 2.5), forest_root, 25.0)
			if inst:
				count += 1

	# Colored point lights for ambiance (2 per zone)
	for zi in range(zone_centers.size()):
		var zc: Vector3 = zone_centers[zi]
		for _i in range(2):
			var light: OmniLight3D = OmniLight3D.new()
			var hue: float = _rng.randf()
			light.light_color = Color.from_hsv(hue, 0.6, 0.8)
			light.light_energy = _rng.randf_range(0.1, 0.3)
			light.omni_range = _rng.randf_range(3.0, 6.0)
			light.shadow_enabled = false
			light.position = zc + _roff(4.0, 15.0) + Vector3(0.0, _rng.randf_range(0.5, 2.0), 0.0)
			forest_root.add_child(light)
			count += 1

	print("[BrocMassFill] Spawned %d extra objects with color variation" % count)
	return count


func _spawn(scene: PackedScene, pos: Vector3, scale_f: float, parent: Node3D, vis_range: float) -> Node3D:
	var raw: Node = scene.instantiate()
	var instance: Node3D = raw as Node3D
	if not instance:
		raw.queue_free()
		return null
	instance.position = pos
	instance.scale = Vector3.ONE * scale_f
	instance.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	_apply_lod(instance, vis_range)
	parent.add_child(instance)
	return instance


func _apply_lod(node: Node3D, range_end: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = range_end
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		if child is Node3D:
			_apply_lod(child as Node3D, range_end)


func _apply_color_tint(node: Node3D) -> void:
	## Apply subtle random hue shift to vegetation for color variety
	var hue_shift: float = _rng.randf_range(-0.08, 0.08)
	var sat_shift: float = _rng.randf_range(-0.1, 0.15)
	_tint_recursive(node, hue_shift, sat_shift)


func _tint_recursive(node: Node3D, hue_shift: float, sat_shift: float) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		for si in range(mi.mesh.get_surface_count() if mi.mesh else 0):
			var mat: Material = mi.get_active_material(si)
			if mat is StandardMaterial3D:
				var sm: StandardMaterial3D = mat as StandardMaterial3D
				var c: Color = sm.albedo_color
				var h: float = clampf(c.h + hue_shift, 0.0, 1.0)
				var s: float = clampf(c.s + sat_shift, 0.0, 1.0)
				sm.albedo_color = Color.from_hsv(h, s, c.v, c.a)
	for child in node.get_children():
		if child is Node3D:
			_tint_recursive(child as Node3D, hue_shift, sat_shift)


func _is_too_close_to_path(pos: Vector3, path: PackedVector3Array, min_dist: float) -> bool:
	## Check every 4th path point for performance
	for i in range(0, path.size(), 4):
		var d: float = Vector2(pos.x - path[i].x, pos.z - path[i].z).length()
		if d < min_dist:
			return true
	return false


func _roff(min_r: float, max_r: float) -> Vector3:
	var angle: float = _rng.randf() * TAU
	var dist: float = _rng.randf_range(min_r, max_r)
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
