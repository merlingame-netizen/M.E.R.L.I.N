extends Node3D
## Rail Walker — On-rails camera with head bob and event-driven card spawning.
## Native-first: AnimationPlayer drives PathFollow3D.progress_ratio (no per-frame movement code).
## This script only handles head bob (Tween) and card-trigger callbacks.

signal card_event_triggered(event_id: String)
signal walk_paused
signal walk_resumed
signal walk_completed

@export var bob_amplitude_v: float = 0.08
@export var bob_amplitude_h: float = 0.04
@export var bob_period: float = 0.85
@export var bob_enabled: bool = true
@export var biome_key: String = "foret_broceliande"
@export var step_interval: float = 0.5
@export var step_pitch_variation: float = 0.15
@export var card_trigger_sfx: String = "ogham_chime"

@onready var _path_follow: PathFollow3D = $Path3D/PathFollow3D
@onready var _camera: Camera3D = $Path3D/PathFollow3D/Camera3D
@onready var _walker_anim: AnimationPlayer = $WalkerAnimation

var _bob_time: float = 0.0
var _step_time: float = 0.0
var _camera_base_pos: Vector3
var _is_paused: bool = false
var _sfx: Node = null  # SFXManager autoload (resolved lazily)


func _ready() -> void:
	if _camera:
		_camera_base_pos = _camera.position
	if _walker_anim:
		if not _walker_anim.animation_finished.is_connected(_on_walker_animation_finished):
			_walker_anim.animation_finished.connect(_on_walker_animation_finished)
		if _walker_anim.has_animation(&"auto_walk"):
			_walker_anim.play(&"auto_walk")
	# Audio v3 — biome ambient via SFXManager autoload
	_sfx = get_node_or_null("/root/SFXManager")
	if _sfx and _sfx.has_method("play_biome_ambient"):
		_sfx.play_biome_ambient(biome_key)


func _process(delta: float) -> void:
	if not bob_enabled or _is_paused or _camera == null:
		return
	_bob_time += delta
	var v: float = sin(_bob_time * TAU / bob_period) * bob_amplitude_v
	var h: float = sin(_bob_time * TAU / (bob_period * 2.0)) * bob_amplitude_h
	_camera.position = _camera_base_pos + Vector3(h, v, 0.0)
	# Audio v3 — pas de marche cadenc\xc3\xa9s (path_scratch, varied pitch)
	_step_time += delta
	if _step_time >= step_interval:
		_step_time = 0.0
		if _sfx and _sfx.has_method("play_varied"):
			_sfx.play_varied("path_scratch", step_pitch_variation)


## Called by Area3D triggers along the path. Pauses the walk and spawns a card event.
func trigger_card_event(event_id: String) -> void:
	if _is_paused:
		return
	pause_walk()
	# Audio v3 — chime cristallin sur apparition carte
	if _sfx and _sfx.has_method("play"):
		_sfx.play(card_trigger_sfx)
	card_event_triggered.emit(event_id)


func pause_walk() -> void:
	_is_paused = true
	if _walker_anim:
		_walker_anim.pause()
	walk_paused.emit()


func resume_walk() -> void:
	_is_paused = false
	if _walker_anim:
		_walker_anim.play(&"auto_walk")
	walk_resumed.emit()


func get_progress_ratio() -> float:
	if _path_follow == null:
		return 0.0
	return _path_follow.progress_ratio


func _on_walker_animation_finished(_anim_name: StringName) -> void:
	walk_completed.emit()
