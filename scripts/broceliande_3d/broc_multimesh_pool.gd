## ═══════════════════════════════════════════════════════════════════════════════
## BrocMultiMeshPool — Extracts Mesh+Material from PackedScene assets at setup.
## ═══════════════════════════════════════════════════════════════════════════════
## Instantiates each GLB once, grabs the first MeshInstance3D's mesh+material,
## then frees the temp node. Provides mesh data for MultiMesh batching.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

## Stored mesh data: { "key" -> { "mesh": Mesh, "material": Material } }
var _entries: Dictionary = {}


func register_scenes(key_prefix: String, scenes: Array[PackedScene]) -> void:
	for i in scenes.size():
		var entry_key: String = "%s_%d" % [key_prefix, i]
		_extract_mesh_from_scene(entry_key, scenes[i])


func register_scene(key: String, scene: PackedScene) -> void:
	_extract_mesh_from_scene(key, scene)


func register_dict(scenes: Dictionary) -> void:
	for key: String in scenes:
		if scenes[key] is PackedScene:
			_extract_mesh_from_scene(key, scenes[key] as PackedScene)


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
