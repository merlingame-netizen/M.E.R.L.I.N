extends RefCounted
## ForestMerlinNPC — Merlin pixel-art NPC: spawn, rig build, visual update.
## Extracted from BroceliandeForest3D for file size reduction.

const MERLIN_PX: float = 0.12
const MERLIN_GRID: Array = [
	[0,0,0,0,0,0,0,6,0,0,0,0],
	[0,0,0,0,0,0,1,1,0,0,0,0],
	[0,0,0,0,0,1,1,1,1,0,0,0],
	[0,0,0,0,1,1,1,2,2,0,0,0],
	[0,0,0,1,1,1,2,2,2,2,0,0],
	[0,5,5,5,5,5,5,5,5,5,5,0],
	[0,0,3,3,4,4,4,4,3,3,0,0],
	[0,0,3,7,4,4,4,7,3,3,0,0],
	[0,0,3,3,4,3,3,3,3,3,0,0],
	[0,0,0,3,3,3,3,3,3,0,0,0],
	[0,0,0,0,3,3,3,3,0,0,0,0],
	[0,0,0,0,0,0,0,0,0,0,0,0],
]
const MERLIN_COLORS: Dictionary = {
	1: Color(0.07, 0.12, 0.29), 2: Color(0.12, 0.20, 0.42),
	3: Color(0.04, 0.05, 0.08), 4: Color(0.14, 0.15, 0.20),
	5: Color(0.03, 0.04, 0.06), 6: Color(0.34, 0.72, 1.0),
	7: Color(0.40, 0.84, 1.0),
}

var _merlin_node: Node3D
var _player: CharacterBody3D
var _zone_center: Vector3
var _rng: RandomNumberGenerator
var _owner_node: Node  # For create_tween()

var _pixel_rig: Node3D
var _orb_light: OmniLight3D
var _float_time: float = 0.0


func _init(merlin_node: Node3D, player: CharacterBody3D, zone_center: Vector3, rng: RandomNumberGenerator, owner_node: Node) -> void:
	_merlin_node = merlin_node
	_player = player
	_zone_center = zone_center
	_rng = rng
	_owner_node = owner_node


func spawn() -> void:
	_merlin_node.position = _zone_center
	_float_time = _rng.randf_range(0.0, TAU)
	_pixel_rig = Node3D.new()
	_pixel_rig.name = "PixelRig"
	_pixel_rig.position = Vector3(0.0, 0.65, 0.0)
	_merlin_node.add_child(_pixel_rig)
	_build_rig(_pixel_rig)


func _build_rig(rig: Node3D) -> void:
	var bx: BoxMesh = BoxMesh.new()
	bx.size = Vector3(MERLIN_PX, MERLIN_PX, 0.08)
	var pixels: Array[MeshInstance3D] = []
	var gh: int = MERLIN_GRID.size()
	var gw: int = int(MERLIN_GRID[0].size())
	var orb: Vector3 = Vector3.ZERO

	for row in gh:
		var rd: Array = MERLIN_GRID[row]
		for col in rd.size():
			var ci: int = int(rd[col])
			if ci == 0:
				continue
			var px: MeshInstance3D = MeshInstance3D.new()
			px.mesh = bx
			px.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = MERLIN_COLORS.get(ci, Color.WHITE)
			mat.roughness = 1.0
			if ci == 6 or ci == 7:
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 1.5 if ci == 6 else 2.0
			px.material_override = mat
			var target: Vector3 = Vector3(
				(float(col) - (float(gw) - 1.0) * 0.5) * MERLIN_PX,
				float(gh - 1 - row) * MERLIN_PX,
				0.0
			)
			px.position = target + Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(1.0, 2.5), _rng.randf_range(-0.1, 0.1))
			px.scale = Vector3.ONE * _rng.randf_range(0.4, 0.8)
			px.set_meta("t", target)
			px.set_meta("r", row)
			rig.add_child(px)
			pixels.append(px)
			if ci == 6:
				orb = target

	# Assemble animation
	var tw: Tween = _owner_node.create_tween().set_parallel(true)
	for px in pixels:
		var t: Vector3 = px.get_meta("t")
		var r: int = int(px.get_meta("r"))
		var dl: float = float(r) * 0.02 + _rng.randf_range(0.0, 0.2)
		var dur: float = 0.4 + _rng.randf_range(0.1, 0.4)
		tw.tween_property(px, "position", t, dur).set_delay(dl).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(px, "scale", Vector3.ONE, dur * 0.9).set_delay(dl).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_orb_light = OmniLight3D.new()
	_orb_light.light_color = Color(0.33, 0.73, 1.0)
	_orb_light.light_energy = 1.0
	_orb_light.omni_range = 4.0
	_orb_light.position = orb + Vector3(0.0, 0.0, 0.3)
	rig.add_child(_orb_light)


func update_visual(delta: float) -> void:
	if not is_instance_valid(_merlin_node):
		return
	_float_time += delta
	_merlin_node.position.y = _zone_center.y + sin(_float_time * 1.6) * 0.08
	if _pixel_rig and is_instance_valid(_pixel_rig) and is_instance_valid(_player):
		var look: Vector3 = Vector3(_player.global_position.x, _pixel_rig.global_position.y, _player.global_position.z)
		if _pixel_rig.global_position.distance_to(look) > 0.01:
			_pixel_rig.look_at(look, Vector3.UP)
	if _orb_light and is_instance_valid(_orb_light):
		_orb_light.light_energy = 0.8 + sin(_float_time * 4.5) * 0.3
