extends RefCounted
## BrocDenseFill — Spawn extra vegetation along path borders for density.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func populate(
	path_points: PackedVector3Array,
	forest_root: Node3D,
	tree_scenes: Array[PackedScene],
	bush_scenes: Array[PackedScene],
	detail_scenes: Dictionary,
	broc_scenes: Dictionary
) -> int:
	var count: int = 0
	var step: int = 2  # Every 2 waypoints for dense forest

	for i in range(0, path_points.size() - 1, step):
		var center: Vector3 = path_points[i]
		var next_idx: int = mini(i + step, path_points.size() - 1)
		var forward: Vector3 = (path_points[next_idx] - center).normalized()
		var right: Vector3 = forward.cross(Vector3.UP).normalized()

		# Left side
		count += _spawn_cluster(center, right * -1.0, forest_root, tree_scenes, bush_scenes, detail_scenes, broc_scenes)
		# Right side
		count += _spawn_cluster(center, right, forest_root, tree_scenes, bush_scenes, detail_scenes, broc_scenes)

	print("[BrocDenseFill] Spawned %d extra vegetation instances" % count)
	return count


func _spawn_cluster(
	center: Vector3,
	side_dir: Vector3,
	parent: Node3D,
	trees: Array[PackedScene],
	bushes: Array[PackedScene],
	details: Dictionary,
	broc: Dictionary
) -> int:
	var count: int = 0
	var offset_base: float = _rng.randf_range(4.0, 7.0)

	# 1-2 bushes
	for _j in range(_rng.randi_range(1, 2)):
		var pos: Vector3 = center + side_dir * (offset_base + _rng.randf_range(0.0, 1.5))
		pos.x += _rng.randf_range(-0.8, 0.8)
		pos.z += _rng.randf_range(-0.8, 0.8)
		if not bushes.is_empty():
			_spawn_instance(bushes[_rng.randi_range(0, bushes.size() - 1)], pos, _rng.randf_range(1.5, 2.8), parent, 40.0)
			count += 1

	# 1-2 ferns
	if details.has("fern"):
		for _j in range(_rng.randi_range(1, 2)):
			var pos: Vector3 = center + side_dir * (offset_base + _rng.randf_range(-0.5, 2.0))
			pos.x += _rng.randf_range(-1.0, 1.0)
			pos.z += _rng.randf_range(-1.0, 1.0)
			_spawn_instance(details["fern"], pos, _rng.randf_range(1.5, 2.5), parent, 25.0)
			count += 1

	# Occasional rock (30% chance)
	if _rng.randf() < 0.3 and details.has("rock_small"):
		var pos: Vector3 = center + side_dir * (offset_base + _rng.randf_range(0.5, 2.0))
		_spawn_instance(details["rock_small"], pos, _rng.randf_range(1.5, 3.0), parent, 45.0)
		count += 1

	# Occasional mushroom near path (20% chance)
	if _rng.randf() < 0.2 and details.has("mushroom_red"):
		var pos: Vector3 = center + side_dir * _rng.randf_range(3.0, 5.0)
		_spawn_instance(details["mushroom_red"], pos, _rng.randf_range(1.5, 2.5), parent, 25.0)
		count += 1

	# Rare fallen trunk across path (5% chance)
	if _rng.randf() < 0.05 and broc.has("fallen_trunk"):
		var pos: Vector3 = center + side_dir * _rng.randf_range(3.0, 5.0)
		_spawn_instance(broc["fallen_trunk"], pos, _rng.randf_range(1.5, 2.5), parent, 50.0)
		count += 1

	return count


func _spawn_instance(scene: PackedScene, pos: Vector3, scale_f: float, parent: Node3D, vis_range: float = 30.0) -> Node3D:
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
