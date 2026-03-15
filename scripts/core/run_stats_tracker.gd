extends RefCounted
class_name RunStatsTracker
## Per-run statistics tracker.
## Collects gameplay metrics during a single run for save/telemetry.

# --- Counters ---
var cards_played: int = 0
var choices_made: Dictionary = {}
var minigames_completed: int = 0
var minigame_scores: Array = []
var oghams_activated: int = 0
var effects_applied: int = 0
var damage_taken: int = 0
var healing_received: int = 0
var factions_changed: Dictionary = {}
var promises_made: int = 0
var promises_kept: int = 0
var promises_broken: int = 0
var run_duration_ms: int = 0
var biome: String = ""
var final_life: int = 0
var death: bool = false

# --- Internal ---
var _start_time_ms: int = 0
var _running: bool = false


func start_run(p_biome: String) -> void:
	cards_played = 0
	choices_made = {0: 0, 1: 0, 2: 0}
	minigames_completed = 0
	minigame_scores = []
	oghams_activated = 0
	effects_applied = 0
	damage_taken = 0
	healing_received = 0
	factions_changed = {}
	promises_made = 0
	promises_kept = 0
	promises_broken = 0
	run_duration_ms = 0
	biome = p_biome
	final_life = 0
	death = false
	_start_time_ms = Time.get_ticks_msec()
	_running = true


func record_card() -> void:
	cards_played += 1


func record_choice(option_index: int) -> void:
	var key: int = clampi(option_index, 0, 2)
	if choices_made.has(key):
		choices_made[key] = choices_made[key] + 1
	else:
		choices_made[key] = 1


func record_minigame(score: int) -> void:
	var clamped: int = clampi(score, 0, 100)
	minigames_completed += 1
	minigame_scores.append(clamped)


func record_ogham() -> void:
	oghams_activated += 1


func record_effect(effect_type: String, value: int) -> void:
	effects_applied += 1
	match effect_type:
		"DAMAGE_LIFE":
			damage_taken += absi(value)
		"HEAL_LIFE":
			healing_received += absi(value)
		"ADD_REPUTATION":
			_record_faction_delta(effect_type, value)
		_:
			pass


func _record_faction_delta(_effect_type: String, _value: int) -> void:
	# ADD_REPUTATION routes through record_faction_change instead
	pass


## Record a faction reputation change with a signed delta.
func record_faction_change(faction_name: String, delta: int) -> void:
	if factions_changed.has(faction_name):
		factions_changed[faction_name] = factions_changed[faction_name] + delta
	else:
		factions_changed[faction_name] = delta


func record_promise_made() -> void:
	promises_made += 1


func record_promise_kept() -> void:
	promises_kept += 1


func record_promise_broken() -> void:
	promises_broken += 1


func end_run(p_final_life: int) -> void:
	if _running:
		run_duration_ms = Time.get_ticks_msec() - _start_time_ms
	_running = false
	final_life = p_final_life
	death = p_final_life <= 0


func to_dict() -> Dictionary:
	var avg_score: float = 0.0
	if minigame_scores.size() > 0:
		var total: int = 0
		for s: int in minigame_scores:
			total += s
		avg_score = float(total) / float(minigame_scores.size())

	return {
		"biome": biome,
		"cards_played": cards_played,
		"choices_made": choices_made.duplicate(),
		"minigames_completed": minigames_completed,
		"minigame_scores": minigame_scores.duplicate(),
		"minigame_avg_score": snapped(avg_score, 0.1),
		"oghams_activated": oghams_activated,
		"effects_applied": effects_applied,
		"damage_taken": damage_taken,
		"healing_received": healing_received,
		"factions_changed": factions_changed.duplicate(),
		"promises_made": promises_made,
		"promises_kept": promises_kept,
		"promises_broken": promises_broken,
		"run_duration_ms": run_duration_ms,
		"final_life": final_life,
		"death": death,
	}


func get_summary() -> String:
	var avg_str: String = "n/a"
	if minigame_scores.size() > 0:
		var total: int = 0
		for s: int in minigame_scores:
			total += s
		avg_str = str(snapped(float(total) / float(minigame_scores.size()), 0.1))

	var duration_s: float = float(run_duration_ms) / 1000.0
	var outcome: String = "DEATH" if death else "ALIVE(%d)" % final_life

	return "%s | %s | %d cards | %d minigames (avg %s) | %d oghams | dmg %d heal %d | %d effects | promises %d/%d/%d | %.1fs" % [
		biome,
		outcome,
		cards_played,
		minigames_completed,
		avg_str,
		oghams_activated,
		damage_taken,
		healing_received,
		effects_applied,
		promises_made,
		promises_kept,
		promises_broken,
		duration_s,
	]
