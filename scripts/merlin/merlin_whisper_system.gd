extends RefCounted
class_name MerlinWhisperSystem

const FACTIONS: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]

const FACTION_DISPLAY_NAMES: Dictionary = {
	"druides": "Druides",
	"anciens": "Anciens",
	"korrigans": "Korrigans",
	"niamh": "Niamh",
	"ankou": "Ankou",
}

const MIN_CARDS_BETWEEN_WHISPERS: int = 3

var _shown_this_run: Array[String] = []
var _last_whisper_card: int = -99
var _whispers: Array[Dictionary] = []


func _init() -> void:
	_build_catalogue()


func reset() -> void:
	_shown_this_run.clear()
	_last_whisper_card = -99


func check_whisper(state: Dictionary) -> Dictionary:
	var cards_played: int = int(state.get("cards_played", 0))
	if cards_played - _last_whisper_card < MIN_CARDS_BETWEEN_WHISPERS:
		return {"triggered": false}

	var seen_cross_run: Array = state.get("meta", {}).get("whispers_seen", [])

	for w: Dictionary in _whispers:
		var wid: String = w["id"]
		if _shown_this_run.has(wid):
			continue

		var trust_min: int = w.get("trust_min", 0)
		var current_trust: int = _get_trust_tier_index(state)
		if current_trust < trust_min:
			continue

		var condition: Callable = w["condition"]
		if not condition.call(state):
			continue

		var text: String = w["text"]
		if w.get("interpolate_faction", false):
			var faction_name: String = _find_triggering_faction(state, w)
			text = text.replace("[FACTION]", faction_name)

		_shown_this_run.append(wid)
		_last_whisper_card = cards_played

		var tier_label: String = _get_trust_tier_label(state)
		return {"triggered": true, "id": wid, "text": text, "tier": tier_label}

	return {"triggered": false}


func get_shown_ids() -> Array[String]:
	return _shown_this_run.duplicate()


func _get_trust_tier_index(state: Dictionary) -> int:
	var trust: int = int(state.get("meta", {}).get("trust_merlin", 0))
	if trust >= 75:
		return 3
	if trust >= 50:
		return 2
	if trust >= 25:
		return 1
	return 0


func _get_trust_tier_label(state: Dictionary) -> String:
	var idx: int = _get_trust_tier_index(state)
	match idx:
		3: return "T3"
		2: return "T2"
		1: return "T1"
	return "T0"


func _get_karma(state: Dictionary) -> float:
	return float(state.get("hidden", {}).get("karma", 0.0))


func _get_tension(state: Dictionary) -> float:
	return float(state.get("hidden", {}).get("tension", 0.0))


func _get_faction_rep(state: Dictionary) -> Dictionary:
	return state.get("meta", {}).get("faction_rep", {})


func _find_triggering_faction(state: Dictionary, whisper: Dictionary) -> String:
	var rep: Dictionary = _get_faction_rep(state)
	var wid: String = whisper["id"]
	if wid == "w_faction_honore":
		for f: String in FACTIONS:
			if float(rep.get(f, 20.0)) >= 80.0:
				return FACTION_DISPLAY_NAMES.get(f, f)
	elif wid == "w_faction_hostile":
		for f: String in FACTIONS:
			if float(rep.get(f, 20.0)) <= 5.0:
				return FACTION_DISPLAY_NAMES.get(f, f)
	return "inconnus"


func _build_catalogue() -> void:
	_whispers = [
		# Karma
		{
			"id": "w_karma_dark", "trust_min": 0,
			"text": "Les ombres s'epaississent autour de toi... je les sens qui murmurent.",
			"condition": func(s: Dictionary) -> bool: return _get_karma(s) < -30.0,
		},
		{
			"id": "w_karma_light", "trust_min": 0,
			"text": "La lumiere te suit, voyageur. Meme les pierres le savent.",
			"condition": func(s: Dictionary) -> bool: return _get_karma(s) > 50.0,
		},
		{
			"id": "w_karma_zero", "trust_min": 0,
			"text": "Tu marches sur le fil... ni ombre, ni lumiere. Fascinant.",
			"condition": func(s: Dictionary) -> bool:
				return is_zero_approx(_get_karma(s)) and int(s.get("cards_played", 0)) > 10,
		},

		# Tension
		{
			"id": "w_tension_high", "trust_min": 0,
			"text": "Quelque chose approche. Je le sens dans mes vieux os de chene.",
			"condition": func(s: Dictionary) -> bool: return _get_tension(s) > 70.0,
		},
		{
			"id": "w_tension_spike", "trust_min": 0,
			"text": "Deja tant de tumulte... et le chemin est encore long.",
			"condition": func(s: Dictionary) -> bool:
				return _get_tension(s) > 50.0 and int(s.get("cards_played", 0)) < 10,
		},
		{
			"id": "w_tension_calm", "trust_min": 0,
			"text": "Le silence... il n'est jamais bon signe dans cette foret.",
			"condition": func(s: Dictionary) -> bool:
				return _get_tension(s) < 10.0 and int(s.get("cards_played", 0)) > 15,
		},

		# Faction
		{
			"id": "w_faction_honore", "trust_min": 0, "interpolate_faction": true,
			"text": "Les [FACTION] te regardent differemment. Ils voient un des leurs.",
			"condition": func(s: Dictionary) -> bool:
				var rep: Dictionary = _get_faction_rep(s)
				for f: String in FACTIONS:
					if float(rep.get(f, 20.0)) >= 80.0:
						return true
				return false,
		},
		{
			"id": "w_faction_hostile", "trust_min": 0, "interpolate_faction": true,
			"text": "Tu as des ennemis maintenant. Les [FACTION] n'oublient pas.",
			"condition": func(s: Dictionary) -> bool:
				var rep: Dictionary = _get_faction_rep(s)
				for f: String in FACTIONS:
					if float(rep.get(f, 20.0)) <= 5.0:
						return true
				return false,
		},
		{
			"id": "w_faction_all_neutral", "trust_min": 0,
			"text": "Tu ne te mouilles pour personne, hein ? Habile... ou lache.",
			"condition": func(s: Dictionary) -> bool:
				var rep: Dictionary = _get_faction_rep(s)
				if rep.is_empty():
					return false
				for f: String in FACTIONS:
					var v: float = float(rep.get(f, 20.0))
					if v < 15.0 or v > 25.0:
						return false
				return true,
		},

		# Biome
		{
			"id": "w_biome_marais", "trust_min": 0,
			"text": "Les korrigans chuchotent entre eux. Ils parlent de toi.",
			"condition": func(s: Dictionary) -> bool:
				return str(s.get("biome", "")) == "marais_korrigans",
		},
		{
			"id": "w_biome_cercles", "trust_min": 0,
			"text": "Ces pierres etaient la avant moi. Et elles seront la apres toi.",
			"condition": func(s: Dictionary) -> bool:
				return str(s.get("biome", "")) == "cercles_pierres",
		},
		{
			"id": "w_biome_iles", "trust_min": 0,
			"text": "L'eau qui nous entoure... elle cache des choses que meme moi je n'ose pas regarder.",
			"condition": func(s: Dictionary) -> bool:
				return str(s.get("biome", "")) == "iles_mystiques",
		},

		# Trust (higher tiers only)
		{
			"id": "w_trust_t1_unlock", "trust_min": 1,
			"text": "Tu commences a m'ecouter. Bien. J'ai tant de choses a te dire.",
			"condition": func(s: Dictionary) -> bool:
				return _get_trust_tier_index(s) == 1,
		},
		{
			"id": "w_trust_t2_secret", "trust_min": 2,
			"text": "Il y a un Ogham que personne n'a trouve depuis trois siecles. Je te dirai ou... un jour.",
			"condition": func(s: Dictionary) -> bool:
				return _get_trust_tier_index(s) >= 2,
		},
		{
			"id": "w_trust_t3_truth", "trust_min": 3,
			"text": "Je ne suis pas ce que tu crois. Mais tu le savais deja, n'est-ce pas ?",
			"condition": func(s: Dictionary) -> bool:
				return _get_trust_tier_index(s) == 3,
		},

		# Milestones
		{
			"id": "w_milestone_10", "trust_min": 0,
			"text": "Dix cartes. Dix choix. Chacun resonne encore dans le bois.",
			"condition": func(s: Dictionary) -> bool:
				return int(s.get("cards_played", 0)) == 10,
		},
		{
			"id": "w_milestone_30", "trust_min": 0,
			"text": "Tu persistes. Rares sont ceux qui vont aussi loin.",
			"condition": func(s: Dictionary) -> bool:
				return int(s.get("cards_played", 0)) == 30,
		},
		{
			"id": "w_milestone_first_death", "trust_min": 0,
			"text": "Pas encore, voyageur. Pas comme ca.",
			"condition": func(s: Dictionary) -> bool:
				return int(s.get("life_essence", 100)) <= 5,
		},

		# Promise
		{
			"id": "w_promise_warning", "trust_min": 0,
			"text": "Tu avais promis, rappelle-toi. Le temps presse.",
			"condition": func(s: Dictionary) -> bool:
				var promises: Array = s.get("active_promises", [])
				var cp: int = int(s.get("cards_played", 0))
				for p: Dictionary in promises:
					var deadline: int = int(p.get("deadline_card", 999))
					if deadline - cp <= 2 and deadline - cp >= 0:
						return true
				return false,
		},
	]
