extends RefCounted
## Unit Tests — MiniGameRegistry
## Tests: field detection, tag mapping, ogham bonus, fallback, game selection.
## NOTE: MiniGameRegistry has static funcs but references MiniGameBase (Control),
## so we test constants directly and reimplement detection logic for headless mode.

const Registry = preload("res://scripts/minigames/minigame_registry.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# Helper — Local reimplementation of detect_field for headless testing
# ═══════════════════════════════════════════════════════════════════════════════

func _detect_field(narrative_text: String, gm_hint: String = "", tags: Array = []) -> String:
	if gm_hint != "" and Registry.FIELDS.has(gm_hint):
		return gm_hint
	for tag in tags:
		var tag_str: String = str(tag).to_lower()
		if Registry.TAG_FIELD_MAP.has(tag_str):
			return Registry.TAG_FIELD_MAP[tag_str]
	var lower := narrative_text.to_lower()
	var scores := {}
	for field in Registry.FIELDS:
		scores[field] = 0
	for field in Registry.FIELDS:
		for keyword in Registry.FIELDS[field]:
			if lower.find(keyword) >= 0:
				scores[field] += 1
	var best_field := "chance"
	var best_score: int = 0
	for field in scores:
		if scores[field] > best_score:
			best_score = scores[field]
			best_field = field
	return best_field


func _get_ogham_bonus(ogham_category: String, game_field: String) -> int:
	var bonus_field: String = Registry.OGHAM_FIELD_BONUS.get(ogham_category, "")
	if bonus_field == game_field:
		return 10
	if ogham_category == "special":
		return 5
	return 0


# ═══════════════════════════════════════════════════════════════════════════════
# FIELD DETECTION — Keyword matching
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_field_from_combat_keywords() -> bool:
	# Keywords use exact substring: "combattre" and "frapper" (not "frappe")
	var field: String = _detect_field("Le guerrier doit combattre et esquiver", "", [])
	if field != "finesse":
		push_error("Combat keywords should map to finesse, got %s" % field)
		return false
	return true


func test_detect_field_from_magic_keywords() -> bool:
	var field: String = _detect_field("Il doit resoudre l'enigme des runes", "", [])
	if field != "logique":
		push_error("Magic keywords should map to logique, got %s" % field)
		return false
	return true


func test_detect_field_from_social_keywords() -> bool:
	var field: String = _detect_field("Negocier avec le marchand pour convaincre", "", [])
	if field != "bluff":
		push_error("Social keywords should map to bluff, got %s" % field)
		return false
	return true


func test_detect_field_from_observation_keywords() -> bool:
	var field: String = _detect_field("Observer les traces et chercher des indices", "", [])
	if field != "observation":
		push_error("Observation keywords should map to observation, got %s" % field)
		return false
	return true


func test_detect_field_from_esprit_keywords() -> bool:
	var field: String = _detect_field("Mediter et se concentrer en silence", "", [])
	if field != "esprit":
		push_error("Spirit keywords should map to esprit, got %s" % field)
		return false
	return true


func test_detect_field_from_perception_keywords() -> bool:
	var field: String = _detect_field("Entendre l'echo dans les ombres", "", [])
	if field != "perception":
		push_error("Perception keywords should map to perception, got %s" % field)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GM HINT — Priority override
# ═══════════════════════════════════════════════════════════════════════════════

func test_gm_hint_overrides_keywords() -> bool:
	var field: String = _detect_field("Le guerrier frappe avec son epee", "logique", [])
	if field != "logique":
		push_error("GM hint should override keywords, got %s" % field)
		return false
	return true


func test_invalid_gm_hint_ignored() -> bool:
	var field: String = _detect_field("Mediter en silence", "invalid_field", [])
	if field != "esprit":
		push_error("Invalid GM hint should be ignored, got %s" % field)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TAG MAPPING
# ═══════════════════════════════════════════════════════════════════════════════

func test_tag_combat_maps_to_finesse() -> bool:
	var field: String = _detect_field("Some text", "", ["combat"])
	if field != "finesse":
		push_error("Tag 'combat' should map to finesse, got %s" % field)
		return false
	return true


func test_tag_mystery_maps_to_logique() -> bool:
	var field: String = _detect_field("Some text", "", ["mystery"])
	if field != "logique":
		push_error("Tag 'mystery' should map to logique, got %s" % field)
		return false
	return true


func test_tag_stealth_maps_to_perception() -> bool:
	var field: String = _detect_field("Some text", "", ["stealth"])
	if field != "perception":
		push_error("Tag 'stealth' should map to perception, got %s" % field)
		return false
	return true


func test_all_tag_fields_are_valid() -> bool:
	for tag in Registry.TAG_FIELD_MAP:
		var field: String = Registry.TAG_FIELD_MAP[tag]
		if not Registry.FIELDS.has(field):
			push_error("TAG_FIELD_MAP tag '%s' maps to invalid field '%s'" % [tag, field])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM BONUS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_bonus_matching_field() -> bool:
	var bonus: int = _get_ogham_bonus("reveal", "observation")
	if bonus != 10:
		push_error("Matching ogham bonus should be 10, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_non_matching() -> bool:
	var bonus: int = _get_ogham_bonus("reveal", "vigueur")
	if bonus != 0:
		push_error("Non-matching bonus should be 0, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_special() -> bool:
	var bonus: int = _get_ogham_bonus("special", "anything")
	if bonus != 5:
		push_error("Special ogham bonus should be 5, got %d" % bonus)
		return false
	return true


func test_all_ogham_bonus_fields_are_valid() -> bool:
	for cat in Registry.OGHAM_FIELD_BONUS:
		var field: String = Registry.OGHAM_FIELD_BONUS[cat]
		if not Registry.FIELDS.has(field):
			push_error("OGHAM_FIELD_BONUS category '%s' maps to invalid field '%s'" % [cat, field])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GAMES — All 8 fields have games
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_fields_have_games() -> bool:
	for field in Registry.FIELDS:
		if not Registry.GAMES.has(field):
			push_error("Field '%s' has no games" % field)
			return false
		if Registry.GAMES[field].is_empty():
			push_error("Field '%s' has empty game list" % field)
			return false
	return true


func test_8_fields_exist() -> bool:
	if Registry.FIELDS.size() != 8:
		push_error("Expected 8 fields, got %d" % Registry.FIELDS.size())
		return false
	return true


func test_total_minigame_count() -> bool:
	var total: int = 0
	for field in Registry.GAMES:
		total += Registry.GAMES[field].size()
	if total < 24:
		push_error("Expected at least 24 minigames, got %d" % total)
		return false
	return true
