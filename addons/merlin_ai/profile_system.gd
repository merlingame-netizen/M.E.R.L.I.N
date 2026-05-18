## ═══════════════════════════════════════════════════════════════════════════════
## Profile System v7.7.32 — Cross-run XP, level, unlocks, traits, memory slots
## ═══════════════════════════════════════════════════════════════════════════════
## Sprint 12.4 in-game port of tools/profile_system.py (Sprint 12.3, commit 451a85ba).
## Schema matches the Python version verbatim so the Python sidecar
## (adaptive_trait_emergence.py) can read/write the same user://profile.json
## without code coupling.
##
## Public API (mirrors Python class Profile):
##   load_profile(path)      -> reads or initialises a profile (returns bool ok)
##   save_profile(path="")   -> writes to disk
##   grant_xp(amount, src)   -> add xp, level-up if needed, return Array[Dict] events
##   grant_xp_from_run(run)  -> compute XP from a run state, apply
##   add_trait(trait_dict)   -> hook for adaptive trait emergence
##   add_memory_slot(tag, n) -> pin cross-run tag if slot cap allows
##   summary()               -> Dictionary for HUD display
##
## Signals:
##   xp_gained(amount, source, total)
##   level_up(new_level, label)
##   trait_unlocked(trait_dict)
##
## XP curve : total_xp(L) = 100 * L * L  →  L5=2500, L10=10000, L30=90000
##
## Caller graph:
##   - scripts/board_narration/board_narration.gd  (post-run hook, Sprint 12.4)
##   - scenes/CharacterHub.tscn UI (Sprint 12.4 in-game)
##   - tools/adaptive_trait_emergence.py reads same JSON path (zero coupling)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name MerlinProfile

const VERSION := "7.7.32"
const DEFAULT_PROFILE_PATH := "user://profile.json"

## Level-unlock palier (matches tools/profile_system.py LEVEL_UNLOCKS).
const LEVEL_UNLOCKS := {
	1: {
		"unlock_oghams": ["beith", "luis", "nion"],
		"souffle_max": 5,
		"essence_max": 20,
		"memory_slots_total": 1,
		"trait_slots_active": 1,
		"_label": "Starter druide",
	},
	3: {"trait_slots_active_delta": 1, "_label": "Eveil"},
	5: {
		"unlock_oghams": ["fearn", "saille", "huath"],
		"souffle_max_delta": 1,
		"essence_max_delta": 5,
		"_label": "Premiere lune",
	},
	7: {
		"trait_slots_active_delta": 1,
		"memory_slots_total_delta": 1,
		"_label": "Memoire ancienne",
	},
	10: {
		"unlock_oghams": ["duir", "tinne", "coll"],
		"souffle_max_delta": 1,
		"essence_max_delta": 5,
		"memory_slots_total_delta": 1,
		"_label": "Sceau de chene",
	},
	15: {
		"unlock_oghams": ["quert", "muin", "gort"],
		"souffle_max_delta": 1,
		"essence_max_delta": 5,
		"_label": "Vigne du temps",
	},
	20: {
		"unlock_oghams": ["ngetal", "straif", "ruis"],
		"souffle_max_delta": 1,
		"essence_max_delta": 5,
		"memory_slots_total_delta": 1,
		"_label": "Voile noir",
	},
	25: {
		"unlock_oghams": ["ailm", "onn", "ur"],
		"souffle_max_delta": 1,
		"essence_max_delta": 5,
		"_label": "Couronne de pin",
	},
	30: {"_label": "Prestige - Druide accompli"},
}


# ═══════════════════════════════════════════════════════════════════════════════
# MUTABLE STATE
# ═══════════════════════════════════════════════════════════════════════════════

var profile_version: String = "v" + VERSION
var character: Dictionary = {}
var behavioral_summary: Dictionary = {}
var anam: int = 0
var completed_runs: int = 0
var created_at: String = ""
var last_updated: String = ""
var _path: String = ""

## Emitted whenever level changes - hooks for UI HUD animations.
signal level_up(new_level: int, label: String)
signal trait_unlocked(trait_dict: Dictionary)
signal xp_gained(amount: int, source: String, total: int)


# ═══════════════════════════════════════════════════════════════════════════════
# XP CURVE
# ═══════════════════════════════════════════════════════════════════════════════

static func total_xp_for_level(level: int) -> int:
	if level <= 0:
		return 0
	return 100 * level * level


static func level_from_total_xp(xp_total: int) -> int:
	if xp_total <= 0:
		return 1
	# Solve 100*L*L <= xp_total  =>  L = floor(sqrt(xp_total / 100))
	return max(1, int(floor(sqrt(float(xp_total) / 100.0))))


static func xp_to_next_level(xp_total: int) -> int:
	var current := level_from_total_xp(xp_total)
	var needed := total_xp_for_level(current + 1)
	return max(0, needed - xp_total)


# ═══════════════════════════════════════════════════════════════════════════════
# XP-FROM-RUN HEURISTIC (matches Python compute_xp_from_run)
# ═══════════════════════════════════════════════════════════════════════════════

## Score a v7.7.31 run state dict into XP. Returns {xp: int, breakdown: Dict}.
static func compute_xp_from_run(run: Dictionary) -> Dictionary:
	var breakdown := {"base_completion": 100}
	var cards: Array = run.get("cards_played", [])

	var dc_success := 0
	for c in cards:
		if c.get("dc_result", "") == "success":
			dc_success += 1
	breakdown["dc_success_bonus"] = dc_success * 30

	var final_state: Dictionary = run.get("final_state", {})
	var faction_rep: Dictionary = final_state.get("faction_rep", {})
	var max_rep := 0
	for v in faction_rep.values():
		if int(v) > max_rep:
			max_rep = int(v)
	breakdown["faction_emergence_bonus"] = 50 if max_rep >= 10 else 0

	var tags: Array = final_state.get("tags", [])
	breakdown["tag_bonus"] = tags.size() * 10

	var karma := int(final_state.get("karma", 0))
	breakdown["karma_bonus"] = max(0, karma) * 5

	var life := int(final_state.get("life_essence", 0))
	breakdown["life_bonus"] = 50 if life >= 80 else 0

	var total := 0
	for v in breakdown.values():
		total += int(v)
	return {"xp": total, "breakdown": breakdown}


# ═══════════════════════════════════════════════════════════════════════════════
# I/O
# ═══════════════════════════════════════════════════════════════════════════════

func load_profile(path: String = DEFAULT_PROFILE_PATH) -> bool:
	_path = path
	if not FileAccess.file_exists(path):
		push_warning("MerlinProfile: %s does not exist - initialising fresh" % path)
		_apply_level_unlocks(1)
		created_at = Time.get_datetime_string_from_system()
		last_updated = created_at
		return true
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MerlinProfile: cannot open %s" % path)
		return false
	var raw_text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_error("MerlinProfile: %s does not contain a JSON dict" % path)
		return false
	profile_version = parsed.get("version", "v" + VERSION)
	character = parsed.get("character", {})
	behavioral_summary = parsed.get("behavioral_summary", {})
	anam = int(parsed.get("anam", 0))
	completed_runs = int(parsed.get("completed_runs", 0))
	created_at = parsed.get("created_at", Time.get_datetime_string_from_system())
	last_updated = parsed.get("last_updated", Time.get_datetime_string_from_system())
	if not character.has("level"):
		_apply_level_unlocks(1)
	return true


func save_profile(path: String = "") -> bool:
	if path.is_empty():
		path = _path
	if path.is_empty():
		push_error("MerlinProfile: no path set - call save_profile(path) explicitly")
		return false
	last_updated = Time.get_datetime_string_from_system()
	var payload := {
		"version": profile_version,
		"character": character,
		"behavioral_summary": behavioral_summary,
		"anam": anam,
		"completed_runs": completed_runs,
		"created_at": created_at,
		"last_updated": last_updated,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("MerlinProfile: cannot write to %s" % path)
		return false
	f.store_string(JSON.stringify(payload, "  ", false))
	f.close()
	_path = path
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# XP / LEVEL
# ═══════════════════════════════════════════════════════════════════════════════

## Apply XP and trigger level-ups. Returns events list as Array[Dictionary].
func grant_xp(amount: int, source: String = "manual") -> Array:
	if amount <= 0:
		return []
	var events: Array = []
	var before_level := int(character.get("level", 1))
	var before_total := int(character.get("xp_total", 0))
	var after_total := before_total + amount
	var after_level := level_from_total_xp(after_total)

	character["xp_total"] = after_total
	character["level"] = after_level
	character["xp_for_next_level"] = xp_to_next_level(after_total)

	events.append({
		"event": "xp_gain",
		"amount": amount,
		"source": source,
		"xp_total": after_total,
	})
	emit_signal("xp_gained", amount, source, after_total)

	for lv in range(before_level + 1, after_level + 1):
		_apply_level_unlocks(lv)
		var lbl: String = LEVEL_UNLOCKS.get(lv, {}).get("_label", "(palier)")
		events.append({"event": "level_up", "level": lv, "label": lbl})
		emit_signal("level_up", lv, lbl)
	return events


## Convenience : compute XP from a v7.7.31 run dict + apply.
func grant_xp_from_run(run: Dictionary) -> Array:
	var xp_calc := compute_xp_from_run(run)
	completed_runs += 1
	var events: Array = grant_xp(int(xp_calc["xp"]), "run")
	events.insert(0, {
		"event": "run_completed",
		"completed_runs": completed_runs,
		"xp_breakdown": xp_calc["breakdown"],
		"xp_total_from_run": int(xp_calc["xp"]),
	})
	return events


func _apply_level_unlocks(target_level: int) -> void:
	var unlocks: Dictionary = LEVEL_UNLOCKS.get(target_level, {})
	if unlocks.is_empty():
		return
	# Initialise character defaults on first call.
	_ensure_character_defaults(target_level)

	for key in unlocks.keys():
		var value = unlocks[key]
		if key == "_label":
			continue
		elif key == "unlock_oghams":
			var lst: Array = character["unlocked_oghams"]
			for ogham in value:
				if not lst.has(ogham):
					lst.append(ogham)
		elif key in ["souffle_max", "essence_max", "memory_slots_total", "trait_slots_active"]:
			character[key] = value
		elif key == "souffle_max_delta":
			character["souffle_max"] = int(character.get("souffle_max", 5)) + int(value)
		elif key == "essence_max_delta":
			character["essence_max"] = int(character.get("essence_max", 20)) + int(value)
		elif key == "memory_slots_total_delta":
			character["memory_slots_total"] = int(character.get("memory_slots_total", 0)) + int(value)
		elif key == "trait_slots_active_delta":
			character["trait_slots_active"] = int(character.get("trait_slots_active", 1)) + int(value)
	character["level"] = max(int(character.get("level", 1)), target_level)


func _ensure_character_defaults(level: int) -> void:
	if not character.has("level"):
		character["level"] = level
	if not character.has("xp_total"):
		character["xp_total"] = 0
	if not character.has("xp_for_next_level"):
		character["xp_for_next_level"] = 100
	if not character.has("unlocked_oghams"):
		character["unlocked_oghams"] = []
	if not character.has("souffle_max"):
		character["souffle_max"] = 5
	if not character.has("essence_max"):
		character["essence_max"] = 20
	if not character.has("traits"):
		character["traits"] = []
	if not character.has("memory_slots"):
		character["memory_slots"] = []
	if not character.has("memory_slots_total"):
		character["memory_slots_total"] = 0
	if not character.has("trait_slots_active"):
		character["trait_slots_active"] = 1


# ═══════════════════════════════════════════════════════════════════════════════
# TRAITS + MEMORY SLOTS
# ═══════════════════════════════════════════════════════════════════════════════

## Hook for adaptive_trait_emergence sidecar. Returns true if added.
func add_trait(trait_dict: Dictionary) -> bool:
	if not character.has("traits"):
		character["traits"] = []
	var traits: Array = character["traits"]
	for t in traits:
		if t.get("trait_id", "") == trait_dict.get("trait_id", ""):
			return false  # already in profile
	var active_count := 0
	for t in traits:
		if t.get("active", false):
			active_count += 1
	var active_cap := int(character.get("trait_slots_active", 1))
	var new_trait := trait_dict.duplicate()
	if not new_trait.has("acquired_at_run"):
		new_trait["acquired_at_run"] = completed_runs
	if not new_trait.has("active"):
		new_trait["active"] = active_count < active_cap
	traits.append(new_trait)
	emit_signal("trait_unlocked", new_trait)
	return true


## Pin a cross-run tag into a memory slot if cap allows.
func add_memory_slot(tag: String, source_run: int) -> bool:
	if not character.has("memory_slots"):
		character["memory_slots"] = []
	var slots: Array = character["memory_slots"]
	var cap := int(character.get("memory_slots_total", 0))
	if slots.size() >= cap:
		return false
	for s in slots:
		if s.get("tag", "") == tag:
			return false
	slots.append({"tag": tag, "source_run": source_run, "slot_idx": slots.size()})
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# INTROSPECTION (for HUD)
# ═══════════════════════════════════════════════════════════════════════════════

func summary() -> Dictionary:
	var active_traits: Array = []
	for t in character.get("traits", []):
		if t.get("active", false):
			active_traits.append(t)
	return {
		"version": profile_version,
		"level": int(character.get("level", 1)),
		"xp_total": int(character.get("xp_total", 0)),
		"xp_for_next_level": int(character.get("xp_for_next_level", 100)),
		"souffle_max": int(character.get("souffle_max", 5)),
		"essence_max": int(character.get("essence_max", 20)),
		"n_unlocked_oghams": character.get("unlocked_oghams", []).size(),
		"unlocked_oghams": character.get("unlocked_oghams", []),
		"n_traits": character.get("traits", []).size(),
		"active_traits": active_traits,
		"memory_slots": character.get("memory_slots", []),
		"anam": anam,
		"completed_runs": completed_runs,
		"last_updated": last_updated,
	}
