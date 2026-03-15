## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — NPC Merchant System
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: NPC roster (4 NPCs), NPC attributes, biome affinity routing,
## spawn conditions, price modifiers, merchant card structure, option types,
## effect validation, edge cases.
## Pattern: extends RefCounted, each test_ returns bool, run_all() aggregates.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TestMerchantSystem


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array = []


# ═══════════════════════════════════════════════════════════════════════════════
# NPC ROSTER — Reference data (the system under test will define these)
# ═══════════════════════════════════════════════════════════════════════════════

const EXPECTED_NPC_NAMES: Array = ["Gwenn", "Puck", "Bran", "Seren"]

const NPC_REQUIRED_FIELDS: Array = [
	"name", "faction", "price_modifier", "biome_affinity", "description",
]

const VALID_FACTIONS: Array = ["druides", "anciens", "korrigans", "niamh", "ankou"]

const VALID_EFFECT_TYPES: Array = [
	"HEAL_LIFE", "DAMAGE_LIFE", "ADD_REPUTATION", "ADD_ANAM",
	"ADD_BIOME_CURRENCY", "UNLOCK_OGHAM", "PLAY_SFX", "TRIGGER_EVENT",
]

const VALID_OPTION_TYPES: Array = ["buy", "trade", "decline"]

## NPC roster definition — source of truth for merchant NPCs.
## In production this would live in a dedicated system file; here we inline it
## so the tests are self-contained and document the expected contract.
const NPC_ROSTER: Dictionary = {
	"gwenn": {
		"name": "Gwenn",
		"faction": "druides",
		"price_modifier": 0.85,
		"biome_affinity": ["foret_broceliande", "landes_bruyere", "cercles_pierres"],
		"description": "Herboriste errante, Gwenn propose des remedes a prix doux.",
	},
	"puck": {
		"name": "Puck",
		"faction": "korrigans",
		"price_modifier": 1.25,
		"biome_affinity": ["marais_korrigans", "cotes_sauvages", "iles_mystiques"],
		"description": "Farceur du marais, Puck vend des curiosites a prix fort.",
	},
	"bran": {
		"name": "Bran",
		"faction": "anciens",
		"price_modifier": 1.0,
		"biome_affinity": ["villages_celtes", "collines_dolmens", "foret_broceliande"],
		"description": "Forgeron itinerant, Bran echange au juste prix.",
	},
	"seren": {
		"name": "Seren",
		"faction": "niamh",
		"price_modifier": 0.95,
		"biome_affinity": ["iles_mystiques", "cercles_pierres", "landes_bruyere"],
		"description": "Tisseuse de brumes, Seren troque des secrets contre des ecumes.",
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _assert(condition: bool, msg: String) -> bool:
	if condition:
		_pass_count += 1
		_results.append({"test": msg, "passed": true})
	else:
		_fail_count += 1
		_results.append({"test": msg, "passed": false})
		push_error("[MERCHANT TEST FAIL] %s" % msg)
	return condition


func run_all() -> Dictionary:
	_pass_count = 0
	_fail_count = 0
	_results = []

	var methods: Array = get_method_list()
	for m in methods:
		var mname: String = str(m.get("name", ""))
		if mname.begins_with("test_") and m.get("args", []).size() == 0:
			var result: bool = call(mname)
			# result already tracked by _assert calls inside each test

	return {"passed": _pass_count, "failed": _fail_count, "results": _results}


## Get NPCs available for a given biome (1-2 NPCs whose biome_affinity includes it).
func _get_npcs_for_biome(biome_key: String) -> Array:
	var matches: Array = []
	for npc_id in NPC_ROSTER:
		var npc: Dictionary = NPC_ROSTER[npc_id]
		var affinity: Array = npc.get("biome_affinity", [])
		if affinity.has(biome_key):
			matches.append(npc)
	return matches


## Determine if a merchant should spawn based on cards played and last merchant card.
func _should_spawn_merchant(cards_played: int, last_merchant_card: int) -> bool:
	if cards_played < 3:
		return false
	var gap: int = cards_played - last_merchant_card
	return gap >= 5 and gap <= 8


## Build a mock merchant card with 3 options (buy, trade, decline).
func _build_merchant_card(npc_id: String) -> Dictionary:
	var npc: Dictionary = NPC_ROSTER.get(npc_id, {})
	if npc.is_empty():
		return {}
	var price_mod: float = float(npc.get("price_modifier", 1.0))
	return {
		"type": "merchant",
		"npc": npc_id,
		"npc_name": npc.get("name", ""),
		"options": [
			{
				"label": "Acheter un remede",
				"type": "buy",
				"effects": [
					{"type": "HEAL_LIFE", "amount": int(10 * price_mod)},
					{"type": "ADD_BIOME_CURRENCY", "amount": int(-5 * price_mod)},
				],
			},
			{
				"label": "Troquer un secret",
				"type": "trade",
				"effects": [
					{"type": "ADD_REPUTATION", "faction": npc.get("faction", "druides"), "amount": 5},
				],
			},
			{
				"label": "Decliner poliment",
				"type": "decline",
				"effects": [],
			},
		],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. ROSTER SIZE — Exactly 4 NPCs
# ═══════════════════════════════════════════════════════════════════════════════

func test_roster_has_exactly_4_npcs() -> bool:
	return _assert(
		NPC_ROSTER.size() == 4,
		"Roster should have exactly 4 NPCs, got %d" % NPC_ROSTER.size()
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. ROSTER NAMES — Gwenn, Puck, Bran, Seren
# ═══════════════════════════════════════════════════════════════════════════════

func test_roster_contains_gwenn() -> bool:
	var names: Array = []
	for npc_id in NPC_ROSTER:
		names.append(str(NPC_ROSTER[npc_id].get("name", "")))
	return _assert(names.has("Gwenn"), "Roster should contain Gwenn")


func test_roster_contains_puck() -> bool:
	var names: Array = []
	for npc_id in NPC_ROSTER:
		names.append(str(NPC_ROSTER[npc_id].get("name", "")))
	return _assert(names.has("Puck"), "Roster should contain Puck")


func test_roster_contains_bran() -> bool:
	var names: Array = []
	for npc_id in NPC_ROSTER:
		names.append(str(NPC_ROSTER[npc_id].get("name", "")))
	return _assert(names.has("Bran"), "Roster should contain Bran")


func test_roster_contains_seren() -> bool:
	var names: Array = []
	for npc_id in NPC_ROSTER:
		names.append(str(NPC_ROSTER[npc_id].get("name", "")))
	return _assert(names.has("Seren"), "Roster should contain Seren")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. NPC ATTRIBUTES — Each NPC has required fields
# ═══════════════════════════════════════════════════════════════════════════════

func test_gwenn_has_required_fields() -> bool:
	var npc: Dictionary = NPC_ROSTER.get("gwenn", {})
	var all_ok: bool = true
	for field in NPC_REQUIRED_FIELDS:
		if not npc.has(field):
			all_ok = false
	return _assert(all_ok, "Gwenn should have all required fields: %s" % str(NPC_REQUIRED_FIELDS))


func test_puck_has_required_fields() -> bool:
	var npc: Dictionary = NPC_ROSTER.get("puck", {})
	var all_ok: bool = true
	for field in NPC_REQUIRED_FIELDS:
		if not npc.has(field):
			all_ok = false
	return _assert(all_ok, "Puck should have all required fields: %s" % str(NPC_REQUIRED_FIELDS))


func test_bran_has_required_fields() -> bool:
	var npc: Dictionary = NPC_ROSTER.get("bran", {})
	var all_ok: bool = true
	for field in NPC_REQUIRED_FIELDS:
		if not npc.has(field):
			all_ok = false
	return _assert(all_ok, "Bran should have all required fields: %s" % str(NPC_REQUIRED_FIELDS))


func test_seren_has_required_fields() -> bool:
	var npc: Dictionary = NPC_ROSTER.get("seren", {})
	var all_ok: bool = true
	for field in NPC_REQUIRED_FIELDS:
		if not npc.has(field):
			all_ok = false
	return _assert(all_ok, "Seren should have all required fields: %s" % str(NPC_REQUIRED_FIELDS))


# ═══════════════════════════════════════════════════════════════════════════════
# 4. NPC FACTIONS — Each NPC belongs to a valid faction
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_npcs_have_valid_faction() -> bool:
	var all_ok: bool = true
	for npc_id in NPC_ROSTER:
		var faction: String = str(NPC_ROSTER[npc_id].get("faction", ""))
		if not VALID_FACTIONS.has(faction):
			all_ok = false
	return _assert(all_ok, "All NPCs should belong to a valid faction from %s" % str(VALID_FACTIONS))


# ═══════════════════════════════════════════════════════════════════════════════
# 5. BIOME AFFINITY — get_npcs_for_biome returns 1-2 for each biome
# ═══════════════════════════════════════════════════════════════════════════════

func test_biome_foret_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("foret_broceliande")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"foret_broceliande should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_landes_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("landes_bruyere")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"landes_bruyere should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_cotes_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("cotes_sauvages")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"cotes_sauvages should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_villages_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("villages_celtes")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"villages_celtes should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_cercles_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("cercles_pierres")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"cercles_pierres should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_marais_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("marais_korrigans")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"marais_korrigans should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_collines_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("collines_dolmens")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"collines_dolmens should have 1-2 merchants, got %d" % npcs.size()
	)


func test_biome_iles_has_merchants() -> bool:
	var npcs: Array = _get_npcs_for_biome("iles_mystiques")
	return _assert(
		npcs.size() >= 1 and npcs.size() <= 2,
		"iles_mystiques should have 1-2 merchants, got %d" % npcs.size()
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 6. EVERY BIOME COVERED — All 8 biomes have at least 1 merchant
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_biome_has_at_least_one_merchant() -> bool:
	var biomes: Array = [
		"foret_broceliande", "landes_bruyere", "cotes_sauvages",
		"villages_celtes", "cercles_pierres", "marais_korrigans",
		"collines_dolmens", "iles_mystiques",
	]
	var uncovered: Array = []
	for biome in biomes:
		var npcs: Array = _get_npcs_for_biome(biome)
		if npcs.size() == 0:
			uncovered.append(biome)
	return _assert(
		uncovered.size() == 0,
		"All 8 biomes should have >= 1 merchant. Uncovered: %s" % str(uncovered)
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 7. SPAWN CONDITIONS — should_spawn_merchant
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_spawn_before_card_3() -> bool:
	var spawns: bool = _should_spawn_merchant(2, 0)
	return _assert(not spawns, "should_spawn_merchant should return false for cards_played < 3")


func test_no_spawn_at_card_1() -> bool:
	var spawns: bool = _should_spawn_merchant(1, 0)
	return _assert(not spawns, "should_spawn_merchant should return false at card 1")


func test_spawn_true_in_range_5_to_8() -> bool:
	# cards_played=10, last_merchant=5 => gap=5 => true
	var spawns: bool = _should_spawn_merchant(10, 5)
	return _assert(spawns, "should_spawn_merchant should return true when gap is 5 (within 5-8)")


func test_spawn_true_at_gap_8() -> bool:
	# cards_played=13, last_merchant=5 => gap=8 => true
	var spawns: bool = _should_spawn_merchant(13, 5)
	return _assert(spawns, "should_spawn_merchant should return true when gap is 8")


func test_spawn_false_gap_too_small() -> bool:
	# cards_played=7, last_merchant=5 => gap=2 => false
	var spawns: bool = _should_spawn_merchant(7, 5)
	return _assert(not spawns, "should_spawn_merchant should return false when gap is 2 (< 5)")


func test_spawn_false_gap_too_large() -> bool:
	# cards_played=14, last_merchant=5 => gap=9 => false
	var spawns: bool = _should_spawn_merchant(14, 5)
	return _assert(not spawns, "should_spawn_merchant should return false when gap is 9 (> 8)")


# ═══════════════════════════════════════════════════════════════════════════════
# 8. PRICE MODIFIERS — Gwenn cheap, Puck expensive
# ═══════════════════════════════════════════════════════════════════════════════

func test_gwenn_price_modifier_cheap() -> bool:
	var mod: float = float(NPC_ROSTER.get("gwenn", {}).get("price_modifier", 1.0))
	return _assert(mod < 1.0, "Gwenn price_modifier should be < 1.0 (cheap), got %f" % mod)


func test_puck_price_modifier_expensive() -> bool:
	var mod: float = float(NPC_ROSTER.get("puck", {}).get("price_modifier", 1.0))
	return _assert(mod > 1.0, "Puck price_modifier should be > 1.0 (expensive), got %f" % mod)


# ═══════════════════════════════════════════════════════════════════════════════
# 9. MERCHANT CARD STRUCTURE — 3 options
# ═══════════════════════════════════════════════════════════════════════════════

func test_merchant_card_has_3_options() -> bool:
	var card: Dictionary = _build_merchant_card("gwenn")
	var opts: Array = card.get("options", [])
	return _assert(opts.size() == 3, "Merchant card should have exactly 3 options, got %d" % opts.size())


func test_merchant_card_has_type_merchant() -> bool:
	var card: Dictionary = _build_merchant_card("bran")
	var card_type: String = str(card.get("type", ""))
	return _assert(card_type == "merchant", "Merchant card type should be 'merchant', got '%s'" % card_type)


func test_merchant_card_has_npc_name() -> bool:
	var card: Dictionary = _build_merchant_card("seren")
	var npc_name: String = str(card.get("npc_name", ""))
	return _assert(npc_name == "Seren", "Merchant card npc_name should be 'Seren', got '%s'" % npc_name)


# ═══════════════════════════════════════════════════════════════════════════════
# 10. OPTION TYPES — buy, trade, decline
# ═══════════════════════════════════════════════════════════════════════════════

func test_merchant_card_options_include_buy() -> bool:
	var card: Dictionary = _build_merchant_card("gwenn")
	var types: Array = []
	for opt in card.get("options", []):
		types.append(str(opt.get("type", "")))
	return _assert(types.has("buy"), "Merchant card should include a 'buy' option")


func test_merchant_card_options_include_trade() -> bool:
	var card: Dictionary = _build_merchant_card("gwenn")
	var types: Array = []
	for opt in card.get("options", []):
		types.append(str(opt.get("type", "")))
	return _assert(types.has("trade"), "Merchant card should include a 'trade' option")


func test_merchant_card_options_include_decline() -> bool:
	var card: Dictionary = _build_merchant_card("gwenn")
	var types: Array = []
	for opt in card.get("options", []):
		types.append(str(opt.get("type", "")))
	return _assert(types.has("decline"), "Merchant card should include a 'decline' option")


# ═══════════════════════════════════════════════════════════════════════════════
# 11. EFFECT TYPES — All effects use valid types
# ═══════════════════════════════════════════════════════════════════════════════

func test_merchant_card_effects_use_valid_types() -> bool:
	var all_ok: bool = true
	for npc_id in NPC_ROSTER:
		var card: Dictionary = _build_merchant_card(npc_id)
		for opt in card.get("options", []):
			for eff in opt.get("effects", []):
				var etype: String = str(eff.get("type", ""))
				if not VALID_EFFECT_TYPES.has(etype):
					all_ok = false
					push_error("NPC %s has invalid effect type: %s" % [npc_id, etype])
	return _assert(all_ok, "All merchant card effects should use valid effect types")


func test_decline_option_has_no_effects() -> bool:
	var card: Dictionary = _build_merchant_card("puck")
	var decline_effects: Array = []
	for opt in card.get("options", []):
		if str(opt.get("type", "")) == "decline":
			decline_effects = opt.get("effects", [])
	return _assert(
		decline_effects.size() == 0,
		"Decline option should have 0 effects, got %d" % decline_effects.size()
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 12. EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_card_invalid_npc_returns_empty() -> bool:
	var card: Dictionary = _build_merchant_card("nonexistent_npc")
	return _assert(card.is_empty(), "Building card for unknown NPC should return empty dict")


func test_biome_affinity_no_duplicates() -> bool:
	var all_ok: bool = true
	for npc_id in NPC_ROSTER:
		var affinity: Array = NPC_ROSTER[npc_id].get("biome_affinity", [])
		var seen: Dictionary = {}
		for biome in affinity:
			if seen.has(biome):
				all_ok = false
				push_error("NPC %s has duplicate biome_affinity: %s" % [npc_id, biome])
			seen[biome] = true
	return _assert(all_ok, "No NPC should have duplicate biome_affinity entries")


func test_description_not_empty() -> bool:
	var all_ok: bool = true
	for npc_id in NPC_ROSTER:
		var desc: String = str(NPC_ROSTER[npc_id].get("description", ""))
		if desc.length() < 10:
			all_ok = false
			push_error("NPC %s has description too short: '%s'" % [npc_id, desc])
	return _assert(all_ok, "All NPCs should have a description of at least 10 characters")


func test_price_modifier_positive() -> bool:
	var all_ok: bool = true
	for npc_id in NPC_ROSTER:
		var mod: float = float(NPC_ROSTER[npc_id].get("price_modifier", 0.0))
		if mod <= 0.0:
			all_ok = false
			push_error("NPC %s has non-positive price_modifier: %f" % [npc_id, mod])
	return _assert(all_ok, "All NPCs should have a positive price_modifier")


func test_spawn_at_card_0_returns_false() -> bool:
	var spawns: bool = _should_spawn_merchant(0, 0)
	return _assert(not spawns, "should_spawn_merchant should return false at card 0")
