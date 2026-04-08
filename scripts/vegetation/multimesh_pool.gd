## MultiMeshPool — Shared mesh+material cache for MultiMesh vegetation batching.
## Extracts Mesh+Material from GLB PackedScenes or accepts procedural meshes.
## Used by VegetationManager, BrocChunkManager, and any scene needing instanced vegetation.

extends RefCounted

## Stored mesh data: { "key" -> { "mesh": Mesh, "material": Material } }
var _entries: Dictionary = {}


## Register an array of PackedScene assets with auto-numbered keys.
func register_scenes(key_prefix: String, scenes: Array[PackedScene]) -> void:
	for i in scenes.size():
		var entry_key: String = "%s_%d" % [key_prefix, i]
		_extract_mesh_from_scene(entry_key, scenes[i])


## Register a single PackedScene with a custom key.
func register_scene(key: String, scene: PackedScene) -> void:
	_extract_mesh_from_scene(key, scene)


## Register all entries from a Dictionary of PackedScenes.
func register_dict(scenes: Dictionary) -> void:
	for key: String in scenes:
		if scenes[key] is PackedScene:
			_extract_mesh_from_scene(key, scenes[key] as PackedScene)


## Load GLB files from path strings and register with auto-numbered keys.
func register_glb_paths(prefix: String, paths: Array[String]) -> void:
	for i in paths.size():
		var path: String = paths[i]
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene:
			var entry_key: String = "%s_%d" % [prefix, i]
			_extract_mesh_from_scene(entry_key, scene)


## Register a procedural (runtime-built) mesh directly.
func register_procedural(key: String, mesh: Mesh, material: Material = null) -> void:
	if mesh:
		_entries[key] = {"mesh": mesh, "material": material}


func has_key(key: String) -> bool:
	return _entries.has(key)


func get_mesh(key: String) -> Mesh:
	if _entries.has(key):
		return _entries[key]["mesh"] as Mesh
	return null


func get_material(key: String) -> Material:
	if _entries.has(key):
		return _entries[key]["material"] as Material
	return null


func get_keys_with_prefix(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for key: String in _entries:
		if key.begins_with(prefix):
			result.append(key)
	return result


func get_all_keys() -> Array[String]:
	var result: Array[String] = []
	for key: String in _entries:
		result.append(key)
	return result


func get_entry_count() -> int:
	return _entries.size()


func _extract_mesh_from_scene(key: String, scene: PackedScene) -> void:
	if not scene:
		return
	var temp: Node = scene.instantiate()
	if not temp:
		return

	var mesh_inst: MeshInstance3D = _find_first_mesh_instance(temp)
	if mesh_inst and mesh_inst.mesh:
		var mat: Material = null
		if mesh_inst.get_surface_override_material(0):
			mat = mesh_inst.get_surface_override_material(0)
		elif mesh_inst.mesh.surface_get_material(0):
			mat = mesh_inst.mesh.surface_get_material(0)
		_entries[key] = {
			"mesh": mesh_inst.mesh,
			"material": mat,
		}

	temp.free()


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_first_mesh_instance(child)
		if found:
			return found
	return null
