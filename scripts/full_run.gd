## FullRun — Authentic on-rails forest run with parchment intro + 3D card events.
##
## Flow:
##   t=0     : Black, parchment overlay 2D — pen draws topdown path on aged paper
##   t=6     : Fade parchment, reveal 3D POV on the same path (rail walk starts)
##   t=10    : Forest assets spawn around the rail
##   t=20+   : Area3D triggers along the path -> 3D event card appears with 3 RPG choices
##   t=N     : Player chooses -> outcome animation, walk continues to next event
##
## This scene is SELF-CONTAINED — Path3D, Camera3D, lights, meshes all inline.
## No instantiation of BKForestRail (which had black-screen rendering issues).
extends Node3D

const BK_TREE_PATHS: Array[String] = [
	"res://Assets/bk_assets/vegetation/foret_broceliande/tree_bk_foret_broceliande_0000.glb",
	"res://Assets/bk_assets/vegetation/foret_broceliande/tree_bk_foret_broceliande_0001.glb",
	"res://Assets/bk_assets/vegetation/foret_broceliande/tree_bk_foret_broceliande_0002.glb",
	"res://Assets/bk_assets/vegetation/foret_broceliande/tree_bk_foret_broceliande_0003.glb",
]
const BK_MEGALITHS: Array[String] = [
	"res://Assets/3d_models/broceliande/megaliths/menhir_02_ogham.glb",
	"res://Assets/3d_models/broceliande/megaliths/dolmen_01.glb",
	"res://Assets/3d_models/broceliande/megaliths/menhir_01.glb",
]
const BK_OAK := "res://Assets/3d_models/broceliande/poi/merlin_oak.glb"
const BK_RAVEN := "res://Assets/3d_models/broceliande/creatures/giant_raven.glb"

@export var path_segments: int = 6
@export var path_length: float = 14.0
@export var walk_duration: float = 75.0
@export var trees_per_segment: int = 4

var _path: Path3D
var _path_follow: PathFollow3D
var _camera: Camera3D
var _walker_anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _bob_time: float = 0.0
var _camera_base_pos: Vector3
var _is_paused: bool = false


func _ready() -> void:
	_rng.seed = Time.get_unix_time_from_system() as int
	_setup_environment()
	_setup_lights()
	_setup_terrain()
	_generate_random_path()
	_setup_camera_rail()
	_populate_forest()
	_place_event_triggers()
	_start_walk_animation()


func _process(delta: float) -> void:
	if _is_paused or _camera == null:
		return
	_bob_time += delta
	var v: float = sin(_bob_time * TAU / 0.85) * 0.06
	var h: float = sin(_bob_time * TAU / 1.7) * 0.03
	_camera.position = _camera_base_pos + Vector3(h, v, 0.0)


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.10, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.42, 0.30)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.035
	env.fog_light_color = Color(0.22, 0.42, 0.28)
	env.fog_light_energy = 1.0
	env.fog_aerial_perspective = 0.25
	env.fog_height = 0.0
	env.fog_height_density = 0.4
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.05
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)


func _setup_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.95, 0.92, 0.78)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -32, 0)
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.40, 0.55, 0.45)
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-15, 145, 0)
	add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.42, 0.78)
	rim.light_energy = 0.35
	rim.rotation_degrees = Vector3(20, 200, 0)
	add_child(rim)


func _setup_terrain() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(150.0, path_length * float(path_segments) + 80.0)
	pm.subdivide_width = 16
	pm.subdivide_depth = 32
	ground.mesh = pm
	ground.position = Vector3(0, -0.02, -path_length * float(path_segments) * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.14)
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	ground.material_override = mat
	add_child(ground)


func _generate_random_path() -> void:
	_path = Path3D.new()
	var curve := Curve3D.new()
	# Start
	curve.add_point(Vector3(0, 1.5, 0))
	# Random middle points
	for i in range(1, path_segments):
		var z: float = -path_length * float(i)
		var x: float = _rng.randf_range(-4.5, 4.5)
		var in_handle: Vector3 = Vector3(0, 0, 4)
		var out_handle: Vector3 = Vector3(0, 0, -4)
		curve.add_point(Vector3(x, 1.5, z), in_handle, out_handle)
	# End straight
	curve.add_point(Vector3(0, 1.5, -path_length * float(path_segments)))
	_path.curve = curve
	add_child(_path)


func _setup_camera_rail() -> void:
	_path_follow = PathFollow3D.new()
	_path_follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	_path_follow.loop = false
	_path_follow.progress_ratio = 0.0
	_path.add_child(_path_follow)

	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.near = 0.1
	_camera.far = 220.0
	_camera.position = Vector3(0, 1.5, 0)
	_path_follow.add_child(_camera)
	_camera.current = true
	_camera_base_pos = _camera.position


func _populate_forest() -> void:
	# Sample tree along the path with random offsets
	var curve := _path.curve
	var sample_count: int = path_segments * trees_per_segment
	for i in range(sample_count):
		var t: float = float(i + 1) / float(sample_count + 1)
		var pos: Vector3 = curve.sample_baked(curve.get_baked_length() * t)
		# Offset to either side of the path (skip if too close to center)
		var side: int = -1 if (i % 2 == 0) else 1
		var offset_x: float = side * _rng.randf_range(3.5, 9.0)
		var tree_pos: Vector3 = pos + Vector3(offset_x, -1.5, 0)
		_spawn_glb(BK_TREE_PATHS[i % BK_TREE_PATHS.size()], tree_pos, _rng.randf_range(2.0, 3.2))

	# Hero assets at strategic points
	var oak_t: float = 0.18
	var oak_pos: Vector3 = curve.sample_baked(curve.get_baked_length() * oak_t)
	_spawn_glb(BK_OAK, oak_pos + Vector3(8.0, -1.5, 0), 2.5)

	var menhir_t: float = 0.40
	var menhir_pos: Vector3 = curve.sample_baked(curve.get_baked_length() * menhir_t)
	_spawn_glb(BK_MEGALITHS[0], menhir_pos + Vector3(-6.0, -1.5, 0), 1.6)

	var dolmen_t: float = 0.65
	var dolmen_pos: Vector3 = curve.sample_baked(curve.get_baked_length() * dolmen_t)
	_spawn_glb(BK_MEGALITHS[1], dolmen_pos + Vector3(7.0, -1.5, 0), 1.0)

	var raven_t: float = 0.32
	var raven_pos: Vector3 = curve.sample_baked(curve.get_baked_length() * raven_t)
	_spawn_glb(BK_RAVEN, raven_pos + Vector3(-3.0, 5.5, 0), 0.6)


func _spawn_glb(path: String, pos: Vector3, scale_factor: float) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node3D = packed.instantiate()
	inst.position = pos
	inst.scale = Vector3(scale_factor, scale_factor, scale_factor)
	inst.rotation.y = _rng.randf_range(0.0, TAU)
	add_child(inst)
	return inst


func _place_event_triggers() -> void:
	# 3 event positions along the rail (~25%, 55%, 85% of progress)
	var event_progress: Array[float] = [0.25, 0.55, 0.85]
	for i in range(event_progress.size()):
		var follower: PathFollow3D = PathFollow3D.new()
		follower.rotation_mode = PathFollow3D.ROTATION_ORIENTED
		follower.loop = false
		follower.progress_ratio = event_progress[i]
		_path.add_child(follower)
		# Trigger Area3D at that point (we'll connect it to UI later)
		var trigger := Area3D.new()
		trigger.name = "EventTrigger_" + str(i)
		trigger.set_meta("event_id", "FR_B1_00" + str(i + 1))
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 2.0
		shape.shape = sphere
		trigger.add_child(shape)
		follower.add_child(trigger)


func _start_walk_animation() -> void:
	_walker_anim = AnimationPlayer.new()
	add_child(_walker_anim)
	var anim := Animation.new()
	anim.length = walk_duration
	anim.step = 0.1
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(str(_path.get_path()) + "/" + str(_path_follow.name) + ":progress_ratio"))
	# We use a relative path that resolves from animation context — set it on the player owner
	anim.track_set_path(track, NodePath("../" + _path.name + "/" + _path_follow.name + ":progress_ratio"))
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, walk_duration, 1.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("auto_walk", anim)
	_walker_anim.add_animation_library("", lib)
	_walker_anim.play("auto_walk")
