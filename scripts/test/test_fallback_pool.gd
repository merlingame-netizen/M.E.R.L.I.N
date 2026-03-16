## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinFallbackPool
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: pool not empty after init, card has required fields, no triade effects,
## emergency card generation, pool selection by context, recent tracking.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

# Required fields every card in the pool must have
const REQUIRED_CARD_FIELDS: Array = ["id", "text", "type", "options"]

# Effect types that belong to the removed Triade system (must never appear)
const FORBIDDEN_EFFECT_TYPES: Array = [
	"ADD_TRIADE", "REMOVE_TRIADE", "SET_TRIADE",
	"TRIADE_BONUS", "TRIADE_PENALTY",
]


func _make_pool() -> MerlinFallbackPool:
	return MerlinFallbackPool.new()


func _make_context(cards_played: int = 5) -> Dictionary:
	return {
		"cards_played": cards_played,
		"gauges": {},
		"factions": {
			"druides": 50.0, "anciens": 50.0, "korrigans": 50.0,
			"niamh": 50.0, "ankou": 50.0,
		},
		"active_tags": [],
		"narrative": {"world_state": {"biome": "foret_broceliande"}, "active_arcs": []},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# POOL NOT EMPTY
# ═══════════════════════════════════════════════════════════════════════════════

func test_pool_not_empty() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	var total := 0
	for ctx in sizes:
		total += int(sizes[ctx])
	if total == 0:
		push_error("Fallback pool should have at least 1 card after init")
		return false
	return true


func test_universal_pool_not_empty() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	if int(sizes.get("universal", 0)) == 0:
		push_error("Universal pool must always have cards (last-resort fallback)")
		return false
	return true


func test_early_game_pool_not_empty() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	if int(sizes.get("early_game", 0)) == 0:
		push_error("early_game pool should have cards")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARD HAS REQUIRED FIELDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_has_required_fields() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		push_error("get_fallback_card returned empty dict")
		return false
	for field in REQUIRED_CARD_FIELDS:
		if not card.has(field):
			push_error("Card missing required field: %s" % field)
			return false
	return true


func test_card_id_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if str(card.get("id", "")).is_empty():
		push_error("Card id must not be empty")
		return false
	return true


func test_card_text_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if str(card.get("text", "")).is_empty():
		push_error("Card text must not be empty")
		return false
	return true


func test_card_has_3_options() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	if options.size() != 3:
		push_error("Card should have exactly 3 options, got %d" % options.size())
		return false
	return true


func test_card_options_have_label() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		if str(opt.get("label", "")).is_empty():
			push_error("Option %d missing 'label'" % i)
			return false
	return true


func test_card_options_have_effects() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		if not opt.has("effects"):
			push_error("Option %d missing 'effects' key" % i)
			return false
	return true


func test_card_type_is_narrative_or_known() -> bool:
	var pool := _make_pool()
	var valid_types: Array = ["narrative", "merlin", "npc_encounter"]
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var card_type: String = str(card.get("type", ""))
	if not valid_types.has(card_type):
		push_error("Card type '%s' not in known types" % card_type)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NO TRIADE EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_triade_effects_in_pool() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	# Iterate through all pool contexts and check every card
	for ctx_key in pool.cards_by_context:
		var cards: Array = pool.cards_by_context[ctx_key]
		for card in cards:
			if not (card is Dictionary):
				continue
			var options: Array = card.get("options", [])
			for opt in options:
				if not (opt is Dictionary):
					continue
				var effects: Array = opt.get("effects", [])
				for eff in effects:
					if not (eff is Dictionary):
						continue
					var eff_type: String = str(eff.get("type", ""))
					if FORBIDDEN_EFFECT_TYPES.has(eff_type):
						push_error("Found forbidden Triade effect '%s' in card '%s'" % [eff_type, card.get("id", "?")])
						return false
	return true


func test_no_decay_rep_effects() -> bool:
	# Decay rep was removed in v2.1 — must not appear
	var pool := _make_pool()
	for ctx_key in pool.cards_by_context:
		var cards: Array = pool.cards_by_context[ctx_key]
		for card in cards:
			if not (card is Dictionary):
				continue
			var options: Array = card.get("options", [])
			for opt in options:
				if not (opt is Dictionary):
					continue
				var effects: Array = opt.get("effects", [])
				for eff in effects:
					if not (eff is Dictionary):
						continue
					var eff_type: String = str(eff.get("type", ""))
					if eff_type == "DECAY_REPUTATION":
						push_error("Found removed DECAY_REPUTATION in card '%s'" % card.get("id", "?"))
						return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT-AWARE POOL SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_card_early_game_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)  # early game: < 30
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		push_error("Should return a card for early game context")
		return false
	return true


func test_get_card_mid_game_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(40)  # mid game: 31-70
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		push_error("Should return a card for mid game context")
		return false
	return true


func test_get_card_late_game_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(80)  # late game: > 70
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		push_error("Should return a card for late game context")
		return false
	return true


func test_get_card_crisis_low_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	ctx["gauges"] = {"life": 10}  # < 15 triggers crisis_low
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		push_error("Should return a card for crisis_low context")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RECENT TRACKING — no immediate repeats
# ═══════════════════════════════════════════════════════════════════════════════

func test_recent_tracking_avoids_immediate_repeat() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	var first: Dictionary = pool.get_fallback_card(ctx)
	var first_id: String = str(first.get("id", ""))
	# Draw a second card — if pool has > 1 card it should differ
	var second: Dictionary = pool.get_fallback_card(ctx)
	var second_id: String = str(second.get("id", ""))
	# Only assert if pool has more than 1 card (otherwise repeat is expected)
	var sizes: Dictionary = pool.get_pool_sizes()
	var total := 0
	for s in sizes:
		total += int(sizes[s])
	if total > 1 and first_id == second_id:
		push_error("Recent tracking should prevent immediate repeat (pool has %d cards)" % total)
		return false
	return true


func test_recently_used_resets_when_exhausted() -> bool:
	var pool := _make_pool()
	# Fill recently_used beyond pool size to force a reset
	pool.recently_used.clear()
	# Grab all card IDs from all pools
	var all_ids: Array[String] = []
	for ctx_key in pool.cards_by_context:
		for card in pool.cards_by_context[ctx_key]:
			if card is Dictionary:
				all_ids.append(str(card.get("id", "")))
	# Mark all as recently used
	pool.recently_used = all_ids
	# Draw should still return a card (forces reset)
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if card.is_empty():
		push_error("Should still return a card even when all recently used")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EMERGENCY CARD
# ═══════════════════════════════════════════════════════════════════════════════

func test_emergency_card_has_required_fields() -> bool:
	var pool := _make_pool()
	# Call _generate_emergency_card directly
	var ctx: Dictionary = _make_context()
	var card: Dictionary = pool._generate_emergency_card(ctx)
	for field in REQUIRED_CARD_FIELDS:
		if not card.has(field):
			push_error("Emergency card missing required field: %s" % field)
			return false
	return true


func test_emergency_card_has_3_options() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	var options: Array = card.get("options", [])
	if options.size() != 3:
		push_error("Emergency card should have 3 options, got %d" % options.size())
		return false
	return true


func test_emergency_card_type_is_narrative() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	if str(card.get("type", "")) != "narrative":
		push_error("Emergency card type should be 'narrative'")
		return false
	return true


func test_emergency_card_id_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	if str(card.get("id", "")).is_empty():
		push_error("Emergency card id must not be empty")
		return false
	return true


func test_emergency_card_generated_flag() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	if not card.get("_generated", false):
		push_error("Emergency card should have _generated = true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ADD_CARD API
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_card_to_valid_context() -> bool:
	var pool := _make_pool()
	var before: int = pool.cards_by_context["universal"].size()
	var new_card: Dictionary = {
		"id": "test_add_001",
		"text": "Test card.",
		"type": "narrative",
		"options": [
			{"direction": "left", "label": "A", "effects": []},
			{"direction": "center", "label": "B", "effects": []},
			{"direction": "right", "label": "C", "effects": []},
		],
		"tags": ["test"],
	}
	var ok: bool = pool.add_card("universal", new_card)
	if not ok:
		push_error("add_card to valid context should return true")
		return false
	if pool.cards_by_context["universal"].size() != before + 1:
		push_error("Pool size should increase by 1 after add_card")
		return false
	return true


func test_add_card_to_invalid_context() -> bool:
	var pool := _make_pool()
	var ok: bool = pool.add_card("nonexistent_context", {"id": "x"})
	if ok:
		push_error("add_card to invalid context should return false")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NPC CARD
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_npc_card_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_npc_card()
	if card.is_empty():
		push_error("get_npc_card should return a card (npc_encounter pool has entries)")
		return false
	return true


func test_get_npc_card_has_required_fields() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_npc_card()
	if card.is_empty():
		return true  # Already tested above
	for field in REQUIRED_CARD_FIELDS:
		if not card.has(field):
			push_error("NPC card missing required field: %s" % field)
			return false
	return true
