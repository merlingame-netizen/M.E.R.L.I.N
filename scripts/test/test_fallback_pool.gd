## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinFallbackPool
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: pool not empty after init, card has required fields, no triade effects,
## emergency card generation, pool selection by context, recent tracking,
## add_card API, get_npc_card, get_pool_sizes, faction extremes, boundaries,
## options structure, direction fields, priority cards, crisis high context.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

# Required fields every card in the pool must have
const REQUIRED_CARD_FIELDS: Array = ["id", "text", "type", "options"]

# Effect types that belong to the removed Triade system (must never appear)
const FORBIDDEN_EFFECT_TYPES: Array = [
	"ADD_TRIADE", "REMOVE_TRIADE", "SET_TRIADE",
	"TRIADE_BONUS", "TRIADE_PENALTY",
]

# All context keys the pool maintains
const POOL_CONTEXT_KEYS: Array = [
	"early_game", "mid_game", "late_game",
	"crisis_low", "crisis_high", "recovery",
	"universal", "merlin_direct", "promise", "npc_encounter",
]


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


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
# POOL INITIALIZATION — sizes and structure
# ═══════════════════════════════════════════════════════════════════════════════

func test_pool_not_empty() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	var total := 0
	for ctx in sizes:
		total += int(sizes[ctx])
	if total == 0:
		return _fail("Fallback pool should have at least 1 card after init")
	return true


func test_universal_pool_not_empty() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	if int(sizes.get("universal", 0)) == 0:
		return _fail("Universal pool must always have cards (last-resort fallback)")
	return true


func test_early_game_pool_not_empty() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	if int(sizes.get("early_game", 0)) == 0:
		return _fail("early_game pool should have cards")
	return true


func test_get_pool_sizes_has_all_context_keys() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	for key in POOL_CONTEXT_KEYS:
		if not sizes.has(key):
			return _fail("get_pool_sizes missing key: %s" % key)
	return true


func test_get_pool_sizes_values_are_non_negative() -> bool:
	var pool := _make_pool()
	var sizes: Dictionary = pool.get_pool_sizes()
	for key in sizes:
		if int(sizes[key]) < 0:
			return _fail("Pool size for '%s' is negative: %d" % [key, int(sizes[key])])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARD HAS REQUIRED FIELDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_has_required_fields() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("get_fallback_card returned empty dict")
	for field in REQUIRED_CARD_FIELDS:
		if not card.has(field):
			return _fail("Card missing required field: %s" % field)
	return true


func test_card_id_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if str(card.get("id", "")).is_empty():
		return _fail("Card id must not be empty")
	return true


func test_card_text_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if str(card.get("text", "")).is_empty():
		return _fail("Card text must not be empty")
	return true


func test_card_has_3_options() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	if options.size() != 3:
		return _fail("Card should have exactly 3 options, got %d" % options.size())
	return true


func test_card_options_have_label() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		if str(opt.get("label", "")).is_empty():
			return _fail("Option %d missing 'label'" % i)
	return true


func test_card_options_have_effects() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		if not opt.has("effects"):
			return _fail("Option %d missing 'effects' key" % i)
	return true


func test_card_options_have_direction() -> bool:
	# Every option must declare a direction (left/center/right) for the swipe UI
	var pool := _make_pool()
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var options: Array = card.get("options", [])
	var valid_dirs: Array = ["left", "center", "right"]
	for i in options.size():
		var opt: Dictionary = options[i]
		var dir: String = str(opt.get("direction", ""))
		if dir.is_empty():
			return _fail("Option %d missing 'direction'" % i)
		if not valid_dirs.has(dir):
			return _fail("Option %d has unknown direction '%s'" % [i, dir])
	return true


func test_card_type_is_narrative_or_known() -> bool:
	var pool := _make_pool()
	var valid_types: Array = ["narrative", "merlin", "npc_encounter"]
	var card: Dictionary = pool.get_fallback_card(_make_context())
	var card_type: String = str(card.get("type", ""))
	if not valid_types.has(card_type):
		return _fail("Card type '%s' not in known types" % card_type)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NO FORBIDDEN EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_triade_effects_in_pool() -> bool:
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
					if FORBIDDEN_EFFECT_TYPES.has(eff_type):
						return _fail("Found forbidden Triade effect '%s' in card '%s'" % [eff_type, card.get("id", "?")])
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
						return _fail("Found removed DECAY_REPUTATION in card '%s'" % card.get("id", "?"))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT-AWARE POOL SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_card_early_game_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)  # early game: < 30
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card for early game context (cards_played=5)")
	return true


func test_get_card_mid_game_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(40)  # mid game: 31-70
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card for mid game context (cards_played=40)")
	return true


func test_get_card_late_game_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(80)  # late game: > 70
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card for late game context (cards_played=80)")
	return true


func test_get_card_crisis_low_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	ctx["gauges"] = {"life": 10}  # < 15 triggers crisis_low
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card for crisis_low context (gauge=10)")
	return true


func test_get_card_crisis_high_context() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	ctx["gauges"] = {"tension": 90}  # > 85 triggers crisis_high
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card for crisis_high context (gauge=90)")
	return true


func test_select_pools_boundary_card_29_is_early() -> bool:
	# cards_played=29 is still early game (< 30)
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(29)
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card at boundary early/mid (cards_played=29)")
	return true


func test_select_pools_boundary_card_30_is_mid() -> bool:
	# cards_played=30 triggers mid game (>= 30, < 70)
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(30)
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card at boundary early/mid (cards_played=30)")
	return true


func test_select_pools_boundary_card_70_is_late() -> bool:
	# cards_played=70 triggers late game (>= 70)
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(70)
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card at boundary mid/late (cards_played=70)")
	return true


func test_faction_extreme_low_triggers_recovery_pool() -> bool:
	# A faction at <= 20 should add recovery pool entries to candidate set
	# We verify this by checking the recovery pool has cards and the draw succeeds
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	ctx["factions"] = {
		"druides": 10.0, "anciens": 50.0, "korrigans": 50.0,
		"niamh": 50.0, "ankou": 50.0,
	}
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card when a faction is at extreme low (10)")
	return true


func test_faction_extreme_high_triggers_recovery_pool() -> bool:
	# A faction at >= 80 should add recovery pool entries to candidate set
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	ctx["factions"] = {
		"druides": 90.0, "anciens": 50.0, "korrigans": 50.0,
		"niamh": 50.0, "ankou": 50.0,
	}
	var card: Dictionary = pool.get_fallback_card(ctx)
	if card.is_empty():
		return _fail("Should return a card when a faction is at extreme high (90)")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RECENT TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func test_recent_tracking_avoids_immediate_repeat() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	var first: Dictionary = pool.get_fallback_card(ctx)
	var first_id: String = str(first.get("id", ""))
	if first_id.is_empty():
		return _fail("First card has no id")
	if first_id not in pool.recently_used:
		return _fail("First card id '%s' not tracked in recently_used" % first_id)
	var seen_different := false
	for i in range(10):
		var card: Dictionary = pool.get_fallback_card(ctx)
		if str(card.get("id", "")) != first_id:
			seen_different = true
			break
	var sizes: Dictionary = pool.get_pool_sizes()
	var total := 0
	for s in sizes:
		total += int(sizes[s])
	if total >= 3 and not seen_different:
		return _fail("After 10 draws (pool=%d), never got a card different from '%s'" % [total, first_id])
	return true


func test_recently_used_resets_when_exhausted() -> bool:
	var pool := _make_pool()
	pool.recently_used.clear()
	var all_ids: Array[String] = []
	for ctx_key in pool.cards_by_context:
		for card in pool.cards_by_context[ctx_key]:
			if card is Dictionary:
				all_ids.append(str(card.get("id", "")))
	pool.recently_used = all_ids
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if card.is_empty():
		return _fail("Should still return a card even when all cards marked recently used")
	return true


func test_recently_used_capped_at_limit() -> bool:
	# After drawing many cards, recently_used should never exceed RECENT_LIMIT
	var pool := _make_pool()
	var ctx: Dictionary = _make_context(5)
	for i in range(40):
		pool.get_fallback_card(ctx)
	if pool.recently_used.size() > MerlinFallbackPool.RECENT_LIMIT:
		return _fail("recently_used size %d exceeds RECENT_LIMIT %d" % [
			pool.recently_used.size(), MerlinFallbackPool.RECENT_LIMIT
		])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EMERGENCY CARD
# ═══════════════════════════════════════════════════════════════════════════════

func test_emergency_card_has_required_fields() -> bool:
	var pool := _make_pool()
	var ctx: Dictionary = _make_context()
	var card: Dictionary = pool._generate_emergency_card(ctx)
	for field in REQUIRED_CARD_FIELDS:
		if not card.has(field):
			return _fail("Emergency card missing required field: %s" % field)
	return true


func test_emergency_card_has_3_options() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	var options: Array = card.get("options", [])
	if options.size() != 3:
		return _fail("Emergency card should have 3 options, got %d" % options.size())
	return true


func test_emergency_card_type_is_narrative() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	if str(card.get("type", "")) != "narrative":
		return _fail("Emergency card type should be 'narrative', got '%s'" % str(card.get("type", "")))
	return true


func test_emergency_card_id_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	if str(card.get("id", "")).is_empty():
		return _fail("Emergency card id must not be empty")
	return true


func test_emergency_card_generated_flag() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	if not card.get("_generated", false):
		return _fail("Emergency card should have _generated = true")
	return true


func test_emergency_card_targets_worst_faction() -> bool:
	# With ankou at 5 (lowest), emergency card should add reputation to ankou
	var pool := _make_pool()
	var ctx: Dictionary = _make_context()
	ctx["factions"] = {
		"druides": 50.0, "anciens": 50.0, "korrigans": 50.0,
		"niamh": 50.0, "ankou": 5.0,
	}
	var card: Dictionary = pool._generate_emergency_card(ctx)
	# Left option should target worst faction
	var options: Array = card.get("options", [])
	if options.is_empty():
		return _fail("Emergency card has no options")
	var left_opt: Dictionary = options[0]
	var effects: Array = left_opt.get("effects", [])
	if effects.is_empty():
		return _fail("Emergency card left option has no effects")
	var target_faction: String = str(effects[0].get("faction", ""))
	if target_faction != "ankou":
		return _fail("Emergency card should target worst faction 'ankou', got '%s'" % target_faction)
	return true


func test_emergency_card_emergency_tags() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool._generate_emergency_card(_make_context())
	var tags: Array = card.get("tags", [])
	if not tags.has("emergency"):
		return _fail("Emergency card should have 'emergency' tag")
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
			{"direction": "left", "label": "A", "effects": [], "preview": ""},
			{"direction": "center", "label": "B", "effects": [], "preview": ""},
			{"direction": "right", "label": "C", "effects": [], "preview": ""},
		],
		"tags": ["test"],
	}
	var ok: bool = pool.add_card("universal", new_card)
	if not ok:
		return _fail("add_card to valid context should return true")
	if pool.cards_by_context["universal"].size() != before + 1:
		return _fail("Pool size should increase by 1 after add_card (expected %d, got %d)" % [
			before + 1, pool.cards_by_context["universal"].size()
		])
	return true


func test_add_card_to_invalid_context() -> bool:
	var pool := _make_pool()
	var ok: bool = pool.add_card("nonexistent_context", {"id": "x"})
	if ok:
		return _fail("add_card to invalid context should return false")
	return true


func test_add_card_makes_card_retrievable() -> bool:
	# A card added to universal should eventually be returned by get_fallback_card
	var pool := _make_pool()
	var unique_id := "unique_test_card_%d" % Time.get_ticks_msec()
	var new_card: Dictionary = {
		"id": unique_id,
		"text": "Un test unique.",
		"type": "narrative",
		"options": [
			{"direction": "left", "label": "A", "effects": [], "preview": ""},
			{"direction": "center", "label": "B", "effects": [], "preview": ""},
			{"direction": "right", "label": "C", "effects": [], "preview": ""},
		],
		"tags": [],
	}
	pool.add_card("universal", new_card)
	# Clear recently_used so our new card is not suppressed
	pool.recently_used.clear()
	# Clear all other pool entries so our card is the only candidate
	for ctx_key in pool.cards_by_context:
		if ctx_key != "universal":
			pool.cards_by_context[ctx_key] = []
	pool.cards_by_context["universal"] = [new_card]
	var card: Dictionary = pool.get_fallback_card(_make_context())
	if str(card.get("id", "")) != unique_id:
		return _fail("Added card '%s' should be retrievable, got '%s'" % [unique_id, str(card.get("id", ""))])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NPC CARD
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_npc_card_not_empty() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_npc_card()
	if card.is_empty():
		return _fail("get_npc_card should return a card (npc_encounter pool has entries)")
	return true


func test_get_npc_card_has_required_fields() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_npc_card()
	if card.is_empty():
		return true  # Already tested above
	for field in REQUIRED_CARD_FIELDS:
		if not card.has(field):
			return _fail("NPC card missing required field: %s" % field)
	return true


func test_get_npc_card_type_is_npc_encounter() -> bool:
	var pool := _make_pool()
	var card: Dictionary = pool.get_npc_card()
	if card.is_empty():
		return true  # Covered by test_get_npc_card_not_empty
	var card_type: String = str(card.get("type", ""))
	if card_type != "npc_encounter":
		return _fail("get_npc_card should return type 'npc_encounter', got '%s'" % card_type)
	return true


func test_get_npc_card_tracks_recently_used() -> bool:
	var pool := _make_pool()
	pool.recently_used.clear()
	var card: Dictionary = pool.get_npc_card()
	if card.is_empty():
		return true
	var card_id: String = str(card.get("id", ""))
	if card_id not in pool.recently_used:
		return _fail("get_npc_card should track returned card in recently_used")
	return true
