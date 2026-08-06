## ═══════════════════════════════════════════════════════════════════════════════
## Menu Casting — la météo, la saison et l'heure changent QUI joue, pas COMBIEN
## ═══════════════════════════════════════════════════════════════════════════════
## Le thème de menu est découpé en un SOCLE, toujours audible, et trois RÔLES :
##
##   chant   qui porte Tri Martolod
##   corde   l'accompagnement pincé
##   halo    le scintillement de l'aigu
##
## Chaque rôle a plusieurs titulaires possibles, rendus aux mêmes notes et aux
## mêmes instants. Le contexte décide seulement lequel joue. S'il pleut, ce n'est
## pas qu'un oud s'ajoute : c'est que la guitare celtique s'en va et que l'oud
## prend sa place. L'effectif ne change jamais, la densité non plus.
##
## Exactement un titulaire par rôle est audible à la fois — c'est ce qui en fait
## un remplacement et non une superposition.
##
## Les fichiers partagent tous la même boucle, donc basculer est un simple fondu
## croisé. Un titulaire qui entre démarre à la position de lecture courante,
## sinon il jouerait l'harmonie de la mesure 1 par-dessus celle en cours.
##
##   var casting := MenuCasting.new()
##   add_child(casting)
##   casting.setup()
##   casting.play()
##   casting.set_context({"meteo": "pluie", "saison": "automne"})
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MenuCasting

signal casting_changed(cast: Dictionary)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const DIR: String = "res://audio/music/menu"
const MANIFEST_PATH: String = "res://audio/music/menu/casting.json"
const CROSSFADE: float = 3.5
const VOLUME_DB_MIN: float = -80.0

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _roles: Array = []                 ## ["chant", "corde", "halo"]
var _default: Dictionary = {}          ## rôle -> id du titulaire par défaut
var _axes: Dictionary = {}             ## axe -> valeurs admises
var _priority: Array = []              ## ordre de résolution des axes
var _context_map: Dictionary = {}      ## valeur d'axe -> {rôle: titulaire}
var _candidates: Dictionary = {}       ## rôle -> [{id, label, file, gain}, ...]

var _bed: AudioStreamPlayer = null
var _players: Dictionary = {}          ## "role__id" -> AudioStreamPlayer
var _targets: Dictionary = {}          ## "role__id" -> volume visé 0..1
var _cast: Dictionary = {}             ## rôle -> id en cours
var _context: Dictionary = {}
var _loop_seconds: float = 0.0
var _master_volume: float = 0.8
var _ready: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup() -> bool:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("MenuCasting: %s introuvable" % MANIFEST_PATH)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MenuCasting: %s illisible" % MANIFEST_PATH)
		return false

	var man: Dictionary = parsed
	_roles = man.get("roles", [])
	_default = man.get("default", {})
	_axes = man.get("axes", {})
	_priority = man.get("priority", [])
	_context_map = man.get("context", {})
	_candidates = man.get("candidates", {})
	_loop_seconds = float(man.get("loop_seconds", 0.0))

	_bed = _make_player("%s/bed.ogg" % DIR)
	if _bed == null:
		push_warning("MenuCasting: bed.ogg manquant, distribution désactivée")
		return false

	for role in _roles:
		for entry_v in _candidates.get(role, []):
			var entry: Dictionary = entry_v
			var key: String = "%s__%s" % [role, String(entry.get("id", ""))]
			var player: AudioStreamPlayer = _make_player(
				"%s/%s" % [DIR, String(entry.get("file", ""))])
			if player != null:
				_players[key] = player
				_targets[key] = 0.0

	_cast = _default.duplicate()
	_ready = _players.size() > 0
	return _ready


func _make_player(path: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = VOLUME_DB_MIN
	player.stream = load(path)
	add_child(player)
	return player


func is_ready() -> bool:
	return _ready


func available_axes() -> Dictionary:
	return _axes.duplicate(true)


func get_casting() -> Dictionary:
	return _cast.duplicate()


# ═══════════════════════════════════════════════════════════════════════════════
# LECTURE
# ═══════════════════════════════════════════════════════════════════════════════

func play() -> void:
	if not _ready:
		return
	_bed.play()
	_bed.volume_db = linear_to_db(_master_volume)
	for role in _roles:
		_start_titular(role, String(_cast.get(role, _default.get(role, ""))))
	_apply_targets()


func stop() -> void:
	if _bed != null:
		_bed.stop()
	for player in _players.values():
		if player is AudioStreamPlayer:
			player.stop()
	for key in _targets:
		_targets[key] = 0.0


func set_master_volume(volume: float) -> void:
	_master_volume = clampf(volume, 0.0, 1.0)
	if _bed != null and _bed.playing:
		_bed.volume_db = linear_to_db(maxf(_master_volume, 0.0001))
	_apply_targets()


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXTE
# ═══════════════════════════════════════════════════════════════════════════════

## `context` : {"meteo": "pluie", "saison": "hiver", "moment": "nuit"}.
## Les axes absents gardent leur valeur.
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
		_apply_casting(_resolve())


## Impose un titulaire, hors contexte (scriptage narratif).
func set_role(role: String, candidate: String) -> void:
	if not _ready or not _players.has("%s__%s" % [role, candidate]):
		return
	var cast: Dictionary = _cast.duplicate()
	cast[role] = candidate
	_apply_casting(cast)


## Rôle par rôle, le premier axe de `priority` qui se prononce l'emporte.
## Un axe muet laisse passer le suivant ; le titulaire par défaut ferme la marche.
func _resolve() -> Dictionary:
	var out: Dictionary = _default.duplicate()
	var decided: Dictionary = {}
	for axis in _priority:
		var value: String = String(_context.get(axis, ""))
		if value.is_empty():
			continue
		var entry: Dictionary = _context_map.get(value, {})
		for role in entry.keys():
			if not decided.has(role):
				out[role] = String(entry[role])
				decided[role] = true
	return out


func _apply_casting(cast: Dictionary) -> void:
	for role in _roles:
		var next_id: String = String(cast.get(role, _default.get(role, "")))
		if String(_cast.get(role, "")) == next_id:
			continue
		_cast[role] = next_id
		if _bed != null and _bed.playing:
			_start_titular(role, next_id)
	_apply_targets()
	casting_changed.emit(_cast.duplicate())


## Le `gain` de casting.json est le correctif d'appariement, mesuré sur les
## fichiers rendus (voir tools/audio/match_levels.py). Sans lui, le đàn tranh et
## le psaltérion sortent 5 dB sous la guitare, et la bascule s'entend comme une
## baisse de volume plutôt que comme un changement d'instrument.
func _apply_targets() -> void:
	for role in _roles:
		var held: String = String(_cast.get(role, ""))
		for entry_v in _candidates.get(role, []):
			var entry: Dictionary = entry_v
			var cid: String = String(entry.get("id", ""))
			var key: String = "%s__%s" % [role, cid]
			if not _targets.has(key):
				continue
			if cid == held:
				var trim: float = clampf(float(entry.get("gain", 1.0)), 0.05, 4.0)
				_targets[key] = _master_volume * trim
			else:
				_targets[key] = 0.0


## Démarre un titulaire à la position de lecture du socle. Sans ça il jouerait
## l'harmonie de la mesure 1 par-dessus celle en cours.
func _start_titular(role: String, candidate: String) -> void:
	var key: String = "%s__%s" % [role, candidate]
	var player: AudioStreamPlayer = _players.get(key)
	if player == null or player.stream == null or player.playing:
		return
	var position: float = 0.0
	if _bed != null and _bed.playing:
		position = _bed.get_playback_position()
		if _loop_seconds > 0.0:
			position = fposmod(position, _loop_seconds)
	player.volume_db = VOLUME_DB_MIN
	player.play(position)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS — fondus croisés
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _ready:
		return
	var step: float = delta / CROSSFADE
	for key in _players.keys():
		var player: AudioStreamPlayer = _players[key]
		if player == null or player.stream == null:
			continue
		var target: float = float(_targets.get(key, 0.0))
		var current: float = 0.0
		if player.volume_db > VOLUME_DB_MIN:
			current = db_to_linear(player.volume_db)
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
