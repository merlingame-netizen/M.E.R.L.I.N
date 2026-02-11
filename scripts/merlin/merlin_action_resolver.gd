extends RefCounted
class_name MerlinActionResolver

const STYLE_MODS := {
	"PROTECTEUR": {"FORCE": -2, "LOGIQUE": 3, "FINESSE": 0},
	"AVENTUREUX": {"FORCE": 2, "LOGIQUE": -1, "FINESSE": 2},
	"PRAGMATIQUE": {"FORCE": 2, "LOGIQUE": 2, "FINESSE": -1},
	"SOMBRE": {"FORCE": 0, "LOGIQUE": 0, "FINESSE": 2},
	"PEDAGOGUE": {"FORCE": 0, "LOGIQUE": 3, "FINESSE": 0},
}

const POSTURE_MODS := {
	"Prudence": {"FORCE": 0, "LOGIQUE": 2, "FINESSE": 1},
	"Agressif": {"FORCE": 3, "LOGIQUE": -1, "FINESSE": 0},
	"Ruse": {"FORCE": 0, "LOGIQUE": 0, "FINESSE": 3},
	"Serenite": {"FORCE": 1, "LOGIQUE": 1, "FINESSE": 1},
}


func resolve(verb: String, subchoice: String, context: Dictionary) -> Dictionary:
	var state: Dictionary = context.get("state", {})
	var attr_key := _attr_for_verb(verb)
	var base_attr := _get_attr(state, attr_key)
	var modifiers := _get_modifiers(state, verb, context)
	var score := clampi(base_attr + modifiers, 0, 100)
	var chance := _chance_from_score(score)
	var risk := _risk_from_score(score)
	var hidden_test := _build_hidden_test(verb, score, context)

	return {
		"verb": verb,
		"subchoice": subchoice,
		"score": score,
		"chance": chance,
		"risk": risk,
		"hidden_test": hidden_test,
		"costs": context.get("costs", {}),
		"gain": context.get("gain", []),
	}


func _attr_for_verb(verb: String) -> String:
	match verb:
		"FORCE":
			return "power"
		"LOGIQUE":
			return "spirit"
		"FINESSE":
			return "finesse"
		_:
			return "power"


func _get_attr(state: Dictionary, key: String) -> int:
	var bestiole = state.get("bestiole", {})
	var stats = bestiole.get("stats", {})
	return int(stats.get(key, 10))


func _get_modifiers(state: Dictionary, verb: String, context: Dictionary) -> int:
	var total := 0
	var run = state.get("run", {})
	var posture = run.get("posture", "")
	if POSTURE_MODS.has(posture):
		total += int(POSTURE_MODS[posture].get(verb, 0))

	var momentum = int(run.get("momentum", 0))
	total += int(momentum / 20.0)

	var style = str(context.get("merlin_style", "")).to_upper()
	if STYLE_MODS.has(style):
		total += int(STYLE_MODS[style].get(verb, 0))

	var needs = state.get("bestiole", {}).get("needs", {})
	var stress = int(needs.get("Stress", 0))
	var energy = int(needs.get("Energy", 50))
	var hunger = int(needs.get("Hunger", 50))
	var hygiene = int(needs.get("Hygiene", 50))
	var mood = int(needs.get("Mood", 50))

	if stress > 70 and (verb == "LOGIQUE" or verb == "FINESSE"):
		total -= 3
	if energy < 30 and verb == "FORCE":
		total -= 3
	if hunger > 70:
		total -= 1
	if hygiene < 30:
		total -= 1
	if mood > 70:
		total += 1

	var fail_streak = int(run.get("fail_streak", 0))
	total += fail_streak * 5

	var extra = int(context.get("bonus", 0)) - int(context.get("penalty", 0))
	total += extra
	return total


func _chance_from_score(score: int) -> String:
	if score < 35:
		return "Low"
	if score < 65:
		return "Medium"
	return "High"


func _risk_from_score(score: int) -> String:
	if score < 35:
		return "Severe"
	if score < 65:
		return "Moderate"
	return "Light"


func _build_hidden_test(verb: String, score: int, context: Dictionary) -> Dictionary:
	var provided = context.get("hidden_test", {})
	if typeof(provided) == TYPE_DICTIONARY and provided.has("type"):
		return _normalize_hidden_test(provided, score, context)

	var test_type := "DICE"
	match verb:
		"FORCE":
			test_type = "TIMING"
		"LOGIQUE":
			test_type = "MEMORY"
		"FINESSE":
			test_type = "AIM"

	return _normalize_hidden_test({"type": test_type}, score, context)


func _normalize_hidden_test(test: Dictionary, score: int, context: Dictionary) -> Dictionary:
	var difficulty := clampi(10 - int(score / 10.0), 1, 10)
	var run = context.get("state", {}).get("run", {})
	var mod = int(run.get("difficulty_mod_next", 0))
	if mod != 0:
		difficulty = clampi(difficulty - mod, 1, 10)
	return {
		"type": str(test.get("type", "DICE")),
		"difficulty": difficulty,
		"modifiers": test.get("modifiers", {}),
	}
