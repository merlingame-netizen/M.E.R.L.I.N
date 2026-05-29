extends Node
## MerlinRun — état de run central (autoload). Bible R60 (état structuré), R64 (Corruption),
## R65 (Intégrité + économie de main), R69 (fins). 100% logique pure (pas de LLM ici).

signal gauges_changed(integrite: int, corruption: int)
signal corruption_threshold(level: int)
signal run_ended(end_type: String)

const START_INTEGRITE: int = 10
const MAX_INTEGRITE: int = 10
const HAND_SIZE: int = 5
const CORRUPTION_THRESHOLD_STEP: int = 5
const CORRUPTION_CAP: int = 18
const SAVE_PATH: String = "user://merlin_run.json"
const SAVE_VERSION: int = 1

var integrite: int = START_INTEGRITE
var corruption: int = 0
var scenario: Dictionary = {}
var beat_index: int = 0
var deck: Array = []
var hand: Array = []
var discard: Array = []
var summary: String = ""
var faits_marquants: Array = []
var pnj_rencontres: Array = []
var choix_cles: Array = []
var cartes_notables: Array = []
var ended: bool = false
var end_type: String = ""
var _last_threshold: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func new_run(p_scenario: Dictionary) -> void:
	integrite = START_INTEGRITE
	corruption = 0
	scenario = p_scenario.duplicate(true)
	beat_index = 0
	summary = ""
	faits_marquants = []
	pnj_rencontres = []
	choix_cles = []
	cartes_notables = []
	ended = false
	end_type = ""
	_last_threshold = 0
	deck = MerlinCard.starter_deck()
	hand = []
	discard = []
	_shuffle(deck)
	draw_to_full()
	emit_signal("gauges_changed", integrite, corruption)


func draw_to_full() -> void:
	while hand.size() < HAND_SIZE:
		if deck.is_empty():
			if discard.is_empty():
				break
			deck = discard.duplicate()
			discard = []
			_shuffle(deck)
		hand.append(deck.pop_back())


func play_and_discard(cards: Array) -> void:
	# La repioche prend le SLOT LIBÉRÉ (même index dans la main) au lieu d'être ajoutée
	# en bout de main → sinon la nouvelle carte file à droite de l'éventail (demande user 2026-05-27).
	for c in cards:
		var idx: int = hand.find(c)
		var rep: MerlinCard = _draw_one()  # tirer AVANT de défausser c (évite de re-piocher c)
		if idx >= 0:
			if rep != null:
				hand[idx] = rep
			else:
				hand.remove_at(idx)
		elif rep != null:
			hand.append(rep)
		discard.append(c)
		if not cartes_notables.has(c.card_name):
			cartes_notables.append(c.card_name)
	draw_to_full()  # filet : complète si le deck était vide à un tirage


func _draw_one() -> MerlinCard:
	if deck.is_empty():
		if discard.is_empty():
			return null
		deck = discard.duplicate()
		discard = []
		_shuffle(deck)
	return deck.pop_back() if not deck.is_empty() else null


func apply_resolution(res: Dictionary) -> void:
	var di: int = int(res.get("integrite_delta", 0))
	var dc: int = int(res.get("corruption_delta", 0))
	integrite = clampi(integrite + di, 0, MAX_INTEGRITE)
	corruption = max(0, corruption + dc)
	emit_signal("gauges_changed", integrite, corruption)
	_check_corruption_threshold()
	_check_end_after_resolution()


func _check_corruption_threshold() -> void:
	var lvl: int = int(corruption / CORRUPTION_THRESHOLD_STEP)
	if lvl > _last_threshold:
		_last_threshold = lvl
		_inject_corrupted_card()
		emit_signal("corruption_threshold", lvl)


func _inject_corrupted_card() -> void:
	var idx: int = corruption
	var c: MerlinCard = MerlinCard.make(
		"corrompu_%d" % idx, "Murmure Corrompu", ["Murmure", "Vide"],
		"Une voix sans bouche s'invite dans ta main. Elle veut que tu l'écoutes.", 1, "Glitch")
	discard.append(c)


func _check_end_after_resolution() -> void:
	if ended:
		return
	if corruption >= CORRUPTION_CAP:
		_end("corrompu")
	elif integrite <= 0:
		_end("mort")


func advance_beat() -> void:
	beat_index += 1
	if ended:
		return
	var total: int = int(scenario.get("total", 5))
	if beat_index >= total:
		_end("accomplissement")


func _end(p_type: String) -> void:
	ended = true
	end_type = p_type
	emit_signal("run_ended", p_type)


func current_beat() -> Dictionary:
	var beats: Array = scenario.get("beats", [])
	if beat_index >= 0 and beat_index < beats.size():
		return beats[beat_index]
	return {}


func is_climax() -> bool:
	var total: int = int(scenario.get("total", 5))
	return beat_index >= total - 1


func to_state_dict() -> Dictionary:
	return {
		"jauges": {"integrite": integrite, "corruption": corruption},
		"scenario": {
			"titre": scenario.get("title", ""),
			"beat_courant": beat_index + 1,
			"total": int(scenario.get("total", 5)),
		},
		"faits_marquants": faits_marquants.duplicate(),
		"pnj_rencontres": pnj_rencontres.duplicate(),
		"choix_cles": choix_cles.duplicate(),
		"cartes_notables_jouees": cartes_notables.duplicate(),
	}


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- Sauvegarde (R73 : auto-save par beat) ---

func save() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"integrite": integrite,
		"corruption": corruption,
		"scenario": scenario,
		"beat_index": beat_index,
		"deck": _cards_to_dicts(deck), "hand": _cards_to_dicts(hand), "discard": _cards_to_dicts(discard),
		"summary": summary,
		"faits_marquants": faits_marquants,
		"pnj_rencontres": pnj_rencontres,
		"choix_cles": choix_cles,
		"cartes_notables": cartes_notables,
		"last_threshold": _last_threshold,
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_run() -> bool:
	if not has_save():
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		return false
	integrite = int(data.get("integrite", START_INTEGRITE))
	corruption = int(data.get("corruption", 0))
	scenario = data.get("scenario", {})
	beat_index = int(data.get("beat_index", 0))
	summary = str(data.get("summary", ""))
	faits_marquants = data.get("faits_marquants", [])
	pnj_rencontres = data.get("pnj_rencontres", [])
	choix_cles = data.get("choix_cles", [])
	cartes_notables = data.get("cartes_notables", [])
	_last_threshold = int(data.get("last_threshold", 0))
	deck = _dicts_to_cards(data.get("deck", []))
	hand = _dicts_to_cards(data.get("hand", []))
	discard = _dicts_to_cards(data.get("discard", []))
	ended = false
	end_type = ""
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _cards_to_dicts(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(c.to_dict())
	return out


func _dicts_to_cards(arr: Array) -> Array:
	var out: Array = []
	for d in arr:
		if d is Dictionary:
			out.append(MerlinCard.from_dict(d))
	return out
