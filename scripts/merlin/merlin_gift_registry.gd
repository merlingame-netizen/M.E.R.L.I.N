extends RefCounted
class_name MerlinGiftRegistry
## Run-scoped gift draw + apply system. See data/rpg/run_gifts.json + docs/BALANCE_FORMULA.md.
## Called from BroceliandeForest3D at cards 2 and 4 to offer 3 random gifts.

const GIFTS_PATH := "res://data/rpg/run_gifts.json"
const TIER_WEIGHTS := {"common": 4, "uncommon": 2, "rare": 1}

static var _gifts_cache: Array = []
static var _loaded: bool = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(GIFTS_PATH):
		return
	var f: FileAccess = FileAccess.open(GIFTS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		return
	_gifts_cache = (json.data as Dictionary).get("gifts", []) as Array


## Draw 3 random gifts. Filters out gifts already taken AND gifts with anti_synergy
## conflicting with already-taken gifts. Tier-weighted random.
static func draw_three(state: Dictionary) -> Array:
	_load()
	if _gifts_cache.is_empty():
		return []
	var run: Dictionary = state.get("run", {}) as Dictionary
	var taken: Array = run.get("gifts_taken", []) as Array
	var taken_keys: Array[String] = []
	for g in taken:
		taken_keys.append(String((g as Dictionary).get("key", "")))
	# Build candidate pool
	var pool: Array = []
	for gift_def in _gifts_cache:
		var gift: Dictionary = gift_def as Dictionary
		var key: String = String(gift.get("key", ""))
		if key in taken_keys:
			continue
		var anti: String = String(gift.get("anti_synergy", ""))
		if not anti.is_empty() and anti in taken_keys:
			continue
		pool.append(gift)
	if pool.is_empty():
		return []
	# Tier-weighted draw
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var picks: Array = []
	for i in 3:
		if pool.is_empty():
			break
		var weights: Array[int] = []
		var total: int = 0
		for g in pool:
			var w: int = int(TIER_WEIGHTS.get(String((g as Dictionary).get("tier", "common")), 1))
			weights.append(w)
			total += w
		var roll: int = rng.randi_range(1, total)
		var cumulative: int = 0
		var pick_idx: int = 0
		for j in weights.size():
			cumulative += weights[j]
			if roll <= cumulative:
				pick_idx = j
				break
		picks.append(pool[pick_idx])
		pool.remove_at(pick_idx)
	return picks


## Apply a gift to the run state (mutates state.run.gifts_taken + state.run.run_modifiers).
static func apply_gift(state: Dictionary, gift: Dictionary) -> void:
	if not state.has("run"):
		state["run"] = {}
	var run: Dictionary = state["run"] as Dictionary
	if not run.has("gifts_taken"):
		run["gifts_taken"] = []
	if not run.has("run_modifiers"):
		run["run_modifiers"] = {
			"drain_modifier": 0,
			"narrative_modifier": 0,
			"xp_multiplier": 1.0,
			"anam_bonus": 1.0,
			"crit_next_test": false,
			"reroll_charges": 0,
			"vie_max_delta": 0,
			"preview_next_dc": false,
			"stat_buffs": {"souffle": 0, "esprit": 0, "coeur": 0},
		}
	(run["gifts_taken"] as Array).append(gift)
	_apply_effect(run["run_modifiers"] as Dictionary, gift.get("effect", {}) as Dictionary)
	state["run"] = run


static func _apply_effect(mods: Dictionary, effect: Dictionary) -> void:
	var t: String = String(effect.get("type", ""))
	match t:
		"stat_buff":
			var axis: String = String(effect.get("axis", "esprit"))
			var stat_buffs: Dictionary = mods["stat_buffs"] as Dictionary
			stat_buffs[axis] = int(stat_buffs.get(axis, 0)) + int(effect.get("value", 0))
			mods["stat_buffs"] = stat_buffs
		"drain_modifier":
			mods["drain_modifier"] = int(mods.get("drain_modifier", 0)) + int(effect.get("value", 0))
		"xp_multiplier":
			mods["xp_multiplier"] = float(mods.get("xp_multiplier", 1.0)) * float(effect.get("value", 1.0))
		"crit_chance":
			mods["crit_next_test"] = true
		"reroll":
			mods["reroll_charges"] = int(mods.get("reroll_charges", 0)) + int(effect.get("value", 1))
		"vie_max":
			mods["vie_max_delta"] = int(mods.get("vie_max_delta", 0)) + int(effect.get("value", 0))
		"narrative_modifier":
			mods["narrative_modifier"] = int(mods.get("narrative_modifier", 0)) + int(effect.get("value", 0))
		"compound":
			# Compound effect — apply each sub-key
			if effect.has("anam_bonus"):
				mods["anam_bonus"] = float(mods.get("anam_bonus", 1.0)) * float(effect["anam_bonus"])
			if effect.has("xp_multiplier"):
				mods["xp_multiplier"] = float(mods.get("xp_multiplier", 1.0)) * float(effect["xp_multiplier"])
			if effect.has("vie_max_delta"):
				mods["vie_max_delta"] = int(mods.get("vie_max_delta", 0)) + int(effect["vie_max_delta"])
			if effect.has("drain_modifier"):
				mods["drain_modifier"] = int(mods.get("drain_modifier", 0)) + int(effect["drain_modifier"])
			if effect.has("preview_next_dc"):
				mods["preview_next_dc"] = bool(effect["preview_next_dc"])
			# Per-axis compound buffs
			for axis_key in ["souffle", "esprit", "coeur"]:
				var buff_key: String = "%s_buff" % axis_key
				if effect.has(buff_key):
					var sb: Dictionary = mods["stat_buffs"] as Dictionary
					sb[axis_key] = int(sb.get(axis_key, 0)) + int(effect[buff_key])
					mods["stat_buffs"] = sb


## Determine if the player should be offered gifts at this card index.
## Default: cards 2 and 4 (1-indexed).
static func should_offer_at(card_index: int) -> bool:
	return card_index == 2 or card_index == 4
