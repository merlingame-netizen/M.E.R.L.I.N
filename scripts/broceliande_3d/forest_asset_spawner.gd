extends RefCounted
## ForestAssetSpawner — Loads GLB assets and provides spawning helpers.
## Extracted from BroceliandeForest3D for file size reduction.

var _forest_root: Node3D
var _rng: RandomNumberGenerator

# Loaded scene caches
var tree_scenes: Array[PackedScene] = []
var bush_scenes: Array[PackedScene] = []
var special_scenes: Dictionary = {}
var detail_scenes: Dictionary = {}
var broc_scenes: Dictionary = {}

# Swaying trees tracking (shared with main)
var sway_nodes: Array[Node3D] = []


func _init(forest_root: Node3D, rng: RandomNumberGenerator) -> void:
	_forest_root = forest_root
	_rng = rng


func load_assets(
	tree_models: Array[String],
	bush_models: Array[String],
	special_trees: Dictionary,
	detail_models: Dictionary,
	broc_assets: Dictionary,
) -> void:
	for path in tree_models:
		var scene: PackedScene = _try_load(path)
		if scene:
			tree_scenes.append(scene)

	for path in bush_models:
		var scene: PackedScene = _try_load(path)
		if scene:
			bush_scenes.append(scene)

	for key in special_trees:
		var scene: PackedScene = _try_load(special_trees[key])
		if scene:
			special_scenes[key] = scene

	for key in detail_models:
		var scene: PackedScene = _try_load(detail_models[key])
		if scene:
			detail_scenes[key] = scene

	for key in broc_assets:
		var scene: PackedScene = _try_load(broc_assets[key])
		if scene:
			broc_scenes[key] = scene
	print("[Broceliande] Loaded trees=%d bush=%d special=%d detail=%d broc=%d" % [tree_scenes.size(), bush_scenes.size(), special_scenes.size(), detail_scenes.size(), broc_scenes.size()])

	# Fallback: if no trees loaded, create procedural ones
	if tree_scenes.is_empty():
		print("[Broceliande] No GLB trees — generating procedural fallbacks")
		_create_procedural_trees()


func _create_procedural_trees() -> void:
	## Generate 3 procedural tree types as PackedScene substitutes
	## Each is a Node3D with trunk (CylinderMesh) + canopy (SphereMesh)
	for i in 3:
		var tree_root: Node3D = Node3D.new()
		tree_root.name = "ProceduralTree_%d" % i

		# Trunk
		var trunk: MeshInstance3D = MeshInstance3D.new()
		var trunk_mesh: CylinderMesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.08 + float(i) * 0.02
		trunk_mesh.bottom_radius = 0.15 + float(i) * 0.03
		trunk_mesh.height = 2.0 + float(i) * 1.0
		trunk.mesh = trunk_mesh
		trunk.position.y = trunk_mesh.height / 2.0
		var trunk_mat: StandardMaterial3D = StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.45, 0.30, 0.15)  # Warmer brown trunk
		trunk_mat.roughness = 0.9
		trunk.material_override = trunk_mat
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tree_root.add_child(trunk)

		# Canopy
		var canopy: MeshInstance3D = MeshInstance3D.new()
		var canopy_mesh: SphereMesh = SphereMesh.new()
		canopy_mesh.radius = 0.8 + float(i) * 0.4
		canopy_mesh.height = 1.2 + float(i) * 0.5
		canopy.mesh = canopy_mesh
		canopy.position.y = trunk_mesh.height + canopy_mesh.height * 0.3
		var canopy_mat: StandardMaterial3D = StandardMaterial3D.new()
		canopy_mat.albedo_color = Color(0.25 + float(i) * 0.08, 0.55 + float(i) * 0.1, 0.18)  # Brighter green canopy
		canopy_mat.roughness = 0.7
		canopy.material_override = canopy_mat
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		tree_root.add_child(canopy)

		# Pack as scene — we can't create PackedScene at runtime,
		# so we store the root nodes and spawn_glb will use them directly
		# Instead: add a helper array of Node3D templates
		_procedural_tree_templates.append(tree_root)

	# Create pseudo-PackedScenes by wrapping in a callable spawner
	print("[Broceliande] Created %d procedural tree templates" % _procedural_tree_templates.size())


var _procedural_tree_templates: Array[Node3D] = []


func spawn_procedural_tree(pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if _procedural_tree_templates.is_empty():
		return null
	var template: Node3D = _procedural_tree_templates[_rng.randi() % _procedural_tree_templates.size()]
	var instance: Node3D = template.duplicate()
	instance.position = pos
	instance.scale = Vector3.ONE * scale_f
	instance.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	_forest_root.add_child(instance)
	return instance


func has_trees() -> bool:
	return not tree_scenes.is_empty() or not _procedural_tree_templates.is_empty()


func _try_load(path: String) -> PackedScene:
	if ResourceLoader.exists(path):
		return load(path) as PackedScene
	return null


func spawn_glb(scene: PackedScene, pos: Vector3, scale_f: float = 1.0, rot_y: float = -1.0, vis_range: float = 0.0) -> Node3D:
	var instance: Node3D = scene.instantiate() as Node3D
	instance.position = pos
	instance.scale = Vector3.ONE * scale_f
	if rot_y < 0.0:
		instance.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	else:
		instance.rotation_degrees.y = rot_y
	if vis_range > 0.0:
		_apply_lod(instance, vis_range)
	_forest_root.add_child(instance)
	return instance


func _apply_lod(node: Node3D, range_end: float) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = range_end
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child in node.get_children():
		if child is Node3D:
			_apply_lod(child as Node3D, range_end)


func spawn_random_tree(pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if tree_scenes.is_empty():
		return create_fallback_tree(pos, scale_f)
	var scene: PackedScene = tree_scenes[_rng.randi_range(0, tree_scenes.size() - 1)]
	var node: Node3D = spawn_glb(scene, pos, scale_f, -1.0, 60.0)
	sway_nodes.append(node)
	return node


func spawn_random_bush(pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if bush_scenes.is_empty():
		return create_fallback_shrub(pos, scale_f)
	var scene: PackedScene = bush_scenes[_rng.randi_range(0, bush_scenes.size() - 1)]
	return spawn_glb(scene, pos, scale_f, -1.0, 40.0)


func spawn_special(key: String, pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if special_scenes.has(key):
		var node: Node3D = spawn_glb(special_scenes[key], pos, scale_f, -1.0, 60.0)
		sway_nodes.append(node)
		return node
	return create_fallback_tree(pos, scale_f)


func spawn_detail(key: String, pos: Vector3, scale_f: float = 1.0) -> Node3D:
	if detail_scenes.has(key):
		return spawn_glb(detail_scenes[key], pos, scale_f, -1.0, 25.0)
	return null


func spawn_broc(key: String, pos: Vector3, scale_f: float = 1.0, rot_y: float = -1.0) -> Node3D:
	if broc_scenes.has(key):
		return spawn_glb(broc_scenes[key], pos, scale_f, rot_y, 70.0)
	push_warning("[Broceliande] Missing asset: %s" % key)
	return null


# --- Fallbacks if GLB not loaded ---

func create_fallback_tree(pos: Vector3, scale_f: float) -> Node3D:
	var tree: Node3D = Node3D.new()
	tree.position = pos
	_forest_root.add_child(tree)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var tm: CylinderMesh = CylinderMesh.new()
	tm.height = 2.4 * scale_f
	tm.bottom_radius = 0.2 * scale_f
	tm.top_radius = 0.15 * scale_f
	tm.radial_segments = 6
	trunk.mesh = tm
	trunk.position = Vector3(0.0, 1.2 * scale_f, 0.0)
	var t_mat: StandardMaterial3D = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.20, 0.14, 0.08)
	t_mat.roughness = 1.0
	trunk.material_override = t_mat
	tree.add_child(trunk)
	for layer in 3:
		var crown: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.height = (1.3 - float(layer) * 0.15) * scale_f
		cone.bottom_radius = (1.3 - float(layer) * 0.2) * scale_f
		cone.top_radius = 0.0
		cone.radial_segments = 6
		crown.mesh = cone
		crown.position = Vector3(0.0, 2.4 * scale_f + 0.4 + float(layer) * 0.55, 0.0)
		var lm: StandardMaterial3D = StandardMaterial3D.new()
		lm.albedo_color = Color(0.14 + _rng.randf_range(-0.03, 0.04), 0.32, 0.12)
		lm.roughness = 1.0
		crown.material_override = lm
		tree.add_child(crown)
	sway_nodes.append(tree)
	return tree


func create_fallback_shrub(pos: Vector3, scale_f: float) -> Node3D:
	var shrub: MeshInstance3D = MeshInstance3D.new()
	shrub.position = pos + Vector3(0.0, 0.35 * scale_f, 0.0)
	_forest_root.add_child(shrub)
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.5 * scale_f
	sm.height = 0.7 * scale_f
	sm.radial_segments = 6
	sm.rings = 3
	shrub.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.34, 0.12)
	mat.roughness = 1.0
	shrub.material_override = mat
	return shrub
