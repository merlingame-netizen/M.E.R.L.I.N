## ═══════════════════════════════════════════════════════════════════════════════
## MerlinSoundBar — Digital audio-visualizer that represents Merlin in 3D space
## ═══════════════════════════════════════════════════════════════════════════════
## v7.7.15 — user request : « merlin sous forme de barre de son digitale qui
## s'anima quand il parle à l'aide d'une bulle ».
##
## 12 vertical bars (BoxMesh) at the back of the plateau, facing the player.
## Bars pulse upward when Merlin speaks (per-typewriter-char), then ease back
## to a low-amplitude idle wiggle.
##
## API :
##   pulse(intensity: float)       — bump a few random bars by `intensity` (0..1)
##   start_speaking()              — enable active speech state (taller idle baseline)
##   stop_speaking()               — return all bars to rest (~0.3s ease-out)
##   set_accent_color(c: Color)    — change emission tint (e.g. per biome)
##
## Visual : 12 BoxMesh + emission glow (no outline mesh — relies on material emission
## for the digital sound-bar look).
## ═══════════════════════════════════════════════════════════════════════════════

class_name MerlinSoundBar
extends Node3D

const BAR_COUNT: int = 12
const BAR_WIDTH: float = 0.08
const BAR_DEPTH: float = 0.05
const BAR_SPACING: float = 0.12
const BAR_IDLE_HEIGHT: float = 0.06           # baseline when silent
const BAR_SPEAKING_HEIGHT_MIN: float = 0.18    # min height during speech idle
const BAR_PULSE_HEIGHT_MAX: float = 0.85       # max height on intense pulse

const REST_DECAY: float = 0.10                 # per-frame lerp toward rest amplitude
const PULSE_DECAY: float = 0.25                # per-frame lerp toward target amplitude (speed)

var _bars: Array[MeshInstance3D] = []
var _amplitudes: Array[float] = []
var _targets: Array[float] = []
var _accent_color: Color = Color(0.92, 0.72, 0.20)   # default Persona gold
var _ink_color: Color = Color(0.04, 0.03, 0.03)
var _is_speaking: bool = false

# v? (2026-06-06) — Auto-pulse while Merlin's VoxCPM voice plays. The bar now
# syncs to actual TTS audio (via MerlinTTS signals), not just the typewriter.
const SPEECH_PULSE_INTERVAL: float = 0.10   # auto-pulse cadence while voicing
var _speech_pulse_accum: float = 0.0


func _ready() -> void:
	var total_width: float = float(BAR_COUNT - 1) * BAR_SPACING
	var start_x: float = -total_width * 0.5
	for i in range(BAR_COUNT):
		var bar := MeshInstance3D.new()
		bar.name = "Bar_%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(BAR_WIDTH, BAR_IDLE_HEIGHT, BAR_DEPTH)
		bar.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _ink_color
		mat.metallic = 0.10
		mat.roughness = 0.55
		mat.emission_enabled = true
		mat.emission = _accent_color
		mat.emission_energy_multiplier = 0.55
		bar.material_override = mat
		bar.position = Vector3(start_x + float(i) * BAR_SPACING, BAR_IDLE_HEIGHT * 0.5, 0.0)
		add_child(bar)
		_bars.append(bar)
		_amplitudes.append(BAR_IDLE_HEIGHT)
		_targets.append(BAR_IDLE_HEIGHT)
	# v7.7.17 — Apply CelShadingManager outline noir to each bar per user request
	# « TOUS les assets aient un effet cel shadé ... contour noir complet ».
	# Audit confirmed this was the single gap in 99% coverage.
	for bar in _bars:
		CelShadingManager.apply(bar, {"outline_thickness": 0.012, "skip_flat_remap": true})

	# 2026-06-06 — Animate whenever Merlin actually speaks (VoxCPM TTS). Guarded
	# so the bar still works in scenes/smoke without the MerlinTTS autoload.
	var tts := get_node_or_null("/root/MerlinTTS")
	if tts != null and tts.has_signal("speech_started"):
		tts.speech_started.connect(_on_tts_speech_started)
		tts.speech_finished.connect(_on_tts_speech_finished)


## Merlin's voice started playing — wake the bar into active-speech mode.
func _on_tts_speech_started(_text: String) -> void:
	start_speaking()


## Merlin's voice finished — let the bars decay back to rest.
func _on_tts_speech_finished() -> void:
	stop_speaking()


## v7.7.18 — Idle frame-skip to recover 0.4-0.8ms per frame.
## When silent AND all bars at rest, call set_process(false). Re-enable on
## pulse()/start_speaking().
const REST_TOLERANCE: float = 0.001

func _process(delta: float) -> void:
	# While Merlin's voice is playing, self-pulse so the bar dances to the speech
	# even when no typewriter is driving pulse() (e.g. the parchment intro).
	if _is_speaking:
		_speech_pulse_accum += delta
		if _speech_pulse_accum >= SPEECH_PULSE_INTERVAL:
			_speech_pulse_accum = 0.0
			pulse(randf_range(0.45, 0.9))
	var rest_amp: float = (BAR_SPEAKING_HEIGHT_MIN if _is_speaking else BAR_IDLE_HEIGHT)
	var all_at_rest: bool = not _is_speaking
	for i in range(BAR_COUNT):
		_amplitudes[i] = lerp(_amplitudes[i], _targets[i], PULSE_DECAY)
		_targets[i] = lerp(_targets[i], rest_amp, REST_DECAY)
		var bar: MeshInstance3D = _bars[i]
		if not is_instance_valid(bar):
			continue
		var box: BoxMesh = bar.mesh as BoxMesh
		if box != null:
			box.size = Vector3(BAR_WIDTH, _amplitudes[i], BAR_DEPTH)
		bar.position.y = _amplitudes[i] * 0.5
		# Check rest convergence
		if absf(_amplitudes[i] - rest_amp) > REST_TOLERANCE or absf(_targets[i] - rest_amp) > REST_TOLERANCE:
			all_at_rest = false
	# v7.7.18 — Once all 12 bars converged to rest AND not speaking, suspend
	# _process. Re-enabled by pulse() / start_speaking().
	if all_at_rest:
		set_process(false)


## Pulse N random bars by `intensity` (0..1). Trigger on each typewriter char.
func pulse(intensity: float) -> void:
	intensity = clampf(intensity, 0.0, 1.0)
	var pulse_count: int = 3 + int(intensity * 4.0)   # 3-7 bars per pulse
	var target_h: float = lerp(BAR_SPEAKING_HEIGHT_MIN, BAR_PULSE_HEIGHT_MAX, intensity)
	for _i in range(pulse_count):
		var idx: int = randi() % BAR_COUNT
		_targets[idx] = max(_targets[idx], randf_range(target_h * 0.6, target_h))
	set_process(true)   # v7.7.18 — wake up from idle


## Enable active-speech mode (taller idle baseline + auto-wiggle).
func start_speaking() -> void:
	_is_speaking = true
	set_process(true)   # v7.7.18 — wake up from idle


## Disable speech mode — bars decay to rest amplitude.
func stop_speaking() -> void:
	_is_speaking = false


## Change emission tint of all bars (e.g. on biome change).
func set_accent_color(c: Color) -> void:
	_accent_color = c
	for bar in _bars:
		if not is_instance_valid(bar):
			continue
		var mat: StandardMaterial3D = bar.material_override as StandardMaterial3D
		if mat != null:
			mat.emission = c
