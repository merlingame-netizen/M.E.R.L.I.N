## ═══════════════════════════════════════════════════════════════════════════════
## Contextual Layers — surcouches musicales par meteo / saison / moment / situation
## ═══════════════════════════════════════════════════════════════════════════════
## Second decoupage de la musique, orthogonal a StemsMusicManager :
##
##   StemsMusicManager  decoupe par INTENSITE  — base/rhythm/melody/climax,
##                      empiles quand la tension monte.
##   ContextualLayers   decoupe par SITUATION  — 12 couches identifiees, allumees
##                      selon le contexte de jeu. S'il pleut, un oud entre.
##
## Les deux systemes lisent des fichiers rendus par tools/audio/synth_palette.py,
## tous cales sur la MEME boucle (165,52 s a 58 BPM) et la MEME harmonie. Les
## couches se combinent donc librement, sans dissonance possible.
##
## Synchronisation : une couche qui demarre a 0.0 alors que le theme en est a la
## mesure 23 jouerait l'harmonie de la mesure 1 par-dessus celle de la 23. Chaque
## couche est donc lancee a la position de lecture de l'horloge de reference
## (`attach_clock`), pas au debut.
##
##   var layers := ContextualLayers.new()
##   add_child(layers)
##   layers.setup()
##   layers.attach_clock(theme_player)
##   layers.set_context({"meteo": "pluie", "saison": "automne", "moment": "nuit"})
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name ContextualLayers

signal layers_changed(active: Array)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const MANIFEST_PATH: String = "res://audio/music/menu/layers.json"
const LAYER_DIR: String = "res://audio/music/menu"
const CROSSFADE_DURATION: float = 4.0

## Au-dela de trois couches simultanees, on n'entend plus une couleur de contexte
## mais un second orchestre. Les couches sont triees par ordre de priorite d'axe
## et le surplus est ignore.
const MAX_ACTIVE: int = 3
const AXIS_PRIORITY: Array[String] = ["situation", "meteo", "moment", "saison"]

const VOLUME_DB_MIN: float = -80.0

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _defs: Array = []                  ## entrees du manifeste
var _axes: Dictionary = {}             ## axe -> valeurs admises
var _players: Dictionary = {}          ## layer_id -> AudioStreamPlayer
var _target_volumes: Dictionary = {}   ## layer_id -> float 0..1
var _context: Dictionary = {}          ## axe -> valeur courante
var _active: Array[String] = []
var _clock: AudioStreamPlayer = null
var _master_volume: float = 0.8
var _loop_seconds: float = 0.0
var _ready: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup() -> bool:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("ContextualLayers: %s introuvable, surcouches desactivees" % MANIFEST_PATH)
		return false

	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ContextualLayers: %s illisible" % MANIFEST_PATH)
		return false

	var manifest: Dictionary = parsed
	_axes = manifest.get("axes", {})
	_loop_seconds = float(manifest.get("loop_seconds", 0.0))
	_defs = manifest.get("layers", [])

	for entry_v in _defs:
		var entry: Dictionary = entry_v
		var layer_id: String = String(entry.get("id", ""))
		var path: String = "%s/%s" % [LAYER_DIR, String(entry.get("file", ""))]
		if layer_id.is_empty() or not ResourceLoader.exists(path):
			continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = VOLUME_DB_MIN
		player.stream = load(path)
		add_child(player)
		_players[layer_id] = player
		_target_volumes[layer_id] = 0.0

	_ready = _players.size() > 0
	return _ready


## L'horloge donne la position de lecture a laquelle demarrer une couche. En
## general le lecteur du theme ou celui du stem "base".
func attach_clock(player: AudioStreamPlayer) -> void:
	_clock = player


func is_ready() -> bool:
	return _ready


func available_axes() -> Dictionary:
	return _axes.duplicate(true)


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXTE
# ═══════════════════════════════════════════════════════════════════════════════

## `context` : {"meteo": "pluie", "saison": "hiver", "moment": "nuit",
##              "situation": "sacre"}. Les axes absents gardent leur valeur.
func set_context(context: Dictionary) -> void:
	if not _ready:
		return
	var changed: bool = false
	for axis in context.keys():
		var value: String = String(context[axis])
		if String(_context.get(axis, "")) != value:
			_context[axis] = value
			changed = true
	if changed:
		_resolve()


func set_axis(axis: String, value: String) -> void:
	set_context({axis: value})


func get_context() -> Dictionary:
	return _context.duplicate()


func get_active_layers() -> Array[String]:
	return _active.duplicate()


## Force une couche precise, hors contexte (scriptage narratif).
func force_layer(layer_id: String, on: bool) -> void:
	if not _players.has(layer_id):
		return
	if on and not _active.has(layer_id):
		_active.append(layer_id)
		_start_synced(layer_id)
	elif not on:
		_active.erase(layer_id)
	_apply_targets()
	layers_changed.emit(_active.duplicate())


func _resolve() -> void:
	var matched: Array[String] = []
	for axis in AXIS_PRIORITY:
		var value: String = String(_context.get(axis, ""))
		if value.is_empty():
			continue
		for entry_v in _defs:
			var entry: Dictionary = entry_v
			if String(entry.get("axis", "")) != axis:
				continue
			var layer_id: String = String(entry.get("id", ""))
			if not _players.has(layer_id) or matched.has(layer_id):
				continue
			var triggers: Array = entry.get("when", [])
			if triggers.has(value):
				matched.append(layer_id)

	if matched.size() > MAX_ACTIVE:
		matched.resize(MAX_ACTIVE)

	for layer_id in matched:
		if not _active.has(layer_id):
			_start_synced(layer_id)
	_active = matched
	_apply_targets()
	layers_changed.emit(_active.duplicate())


func _apply_targets() -> void:
	for layer_id in _players.keys():
		var gain: float = _layer_gain(String(layer_id))
		_target_volumes[layer_id] = (gain * _master_volume) if _active.has(layer_id) else 0.0


func _layer_gain(layer_id: String) -> float:
	for entry_v in _defs:
		var entry: Dictionary = entry_v
		if String(entry.get("id", "")) == layer_id:
			return clampf(float(entry.get("gain", 1.0)), 0.0, 1.0)
	return 1.0


## Demarre la couche a la position de l'horloge, sinon elle jouerait l'harmonie
## de la mesure 1 par-dessus celle en cours.
func _start_synced(layer_id: String) -> void:
	var player: AudioStreamPlayer = _players.get(layer_id)
	if player == null or player.stream == null:
		return
	# Déjà en cours : elle était en train de s'éteindre et on la rallume. La
	# relancer la remettrait à zéro de volume et couperait le son une seconde
	# pour rien — elle est déjà calée, il suffit d'inverser le fondu.
	if player.playing:
		return
	var position: float = 0.0
	if _clock != null and _clock.playing:
		position = _clock.get_playback_position()
		if _loop_seconds > 0.0:
			position = fposmod(position, _loop_seconds)
	player.volume_db = VOLUME_DB_MIN
	player.play(position)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS — fondus longs
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _ready:
		return
	var step: float = delta / CROSSFADE_DURATION
	for layer_id in _players.keys():
		var player: AudioStreamPlayer = _players[layer_id]
		if player == null or player.stream == null:
			continue
		var target: float = float(_target_volumes.get(layer_id, 0.0))
		var current: float = db_to_linear(player.volume_db) if player.volume_db > VOLUME_DB_MIN else 0.0
		if is_equal_approx(current, target):
			if target <= 0.0 and player.playing:
				player.stop()
			continue
		var next: float = move_toward(current, target, step)
		if next < 0.005:
			player.volume_db = VOLUME_DB_MIN
			if player.playing:
				player.stop()
		else:
			player.volume_db = linear_to_db(next)


func set_master_volume(volume: float) -> void:
	_master_volume = clampf(volume, 0.0, 1.0)
	_apply_targets()


func stop() -> void:
	_active.clear()
	_apply_targets()
	for player in _players.values():
		if player is AudioStreamPlayer:
			player.stop()
