## ═══════════════════════════════════════════════════════════════════════════════
## End Run Screen — Narrative ending, journey map, rewards (Phase 7)
## ═══════════════════════════════════════════════════════════════════════════════
## Three-screen flow after run ends:
## 1. Narrative ending text (LLM or fallback)
## 2. Journey map (events played during run)
## 3. Rewards summary (anam, faction rep, unlocks)
## Optional: faction choice if 2+ factions >= 80
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name EndRunScreen

signal screen_completed(screen_name: String)
signal return_to_hub()
signal faction_chosen(faction: String)

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _run_data: Dictionary = {}
var _rewards: Dictionary = {}
var _ending_text: String = ""
var _current_screen: int = 0  # 0=narrative, 1=journey, 2=rewards, 3=faction_choice

const SCREEN_NARRATIVE := 0
const SCREEN_JOURNEY := 1
const SCREEN_REWARDS := 2
const SCREEN_FACTION_CHOICE := 3


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func start(run_data: Dictionary, rewards: Dictionary, ending_text: String) -> void:
	_run_data = run_data
	_rewards = rewards
	_ending_text = ending_text
	_current_screen = SCREEN_NARRATIVE


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN 1: NARRATIVE ENDING
# ═══════════════════════════════════════════════════════════════════════════════

func show_narrative_ending(text: String) -> Dictionary:
	_ending_text = text
	var reason: String = str(_run_data.get("reason", ""))

	if text.is_empty():
		text = _get_fallback_ending(reason)

	_current_screen = SCREEN_NARRATIVE
	screen_completed.emit("narrative")

	return {
		"screen": "narrative",
		"text": text,
		"reason": reason,
	}


func _get_fallback_ending(reason: String) -> String:
	match reason:
		"death":
			return "Les tenebres t'enveloppent. Le monde celtique s'estompe, mais ton ame persiste. Tu reviendras."
		"hard_max":
			return "Le voyage touche a sa fin. Les chemins se referment, les etoiles s'alignent. Il est temps de rentrer."
		_:
			return "Le vent tourne. Une page se ferme, une autre s'ouvrira bientot."


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN 2: JOURNEY MAP
# ═══════════════════════════════════════════════════════════════════════════════

func show_journey_map(events: Array) -> Dictionary:
	_current_screen = SCREEN_JOURNEY

	# Build a simplified timeline of key events
	var timeline: Array = []
	for event in events:
		if not (event is Dictionary):
			continue
		timeline.append({
			"card_id": str(event.get("card_id", "")),
			"option_index": int(event.get("option_index", 0)),
			"score": int(event.get("score", 0)),
			"effects_count": int(event.get("effects_count", 0)),
		})

	screen_completed.emit("journey")

	return {
		"screen": "journey",
		"events": timeline,
		"total_cards": timeline.size(),
		"biome": str(_run_data.get("biome", "")),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN 3: REWARDS
# ═══════════════════════════════════════════════════════════════════════════════

func show_rewards(rewards: Dictionary) -> Dictionary:
	_rewards = rewards
	_current_screen = SCREEN_REWARDS

	var display: Dictionary = {
		"screen": "rewards",
		"anam_earned": int(rewards.get("anam", 0)),
		"faction_rep_delta": rewards.get("faction_rep_delta", {}),
		"trust_delta": int(rewards.get("trust_delta", 0)),
		"biome_currency": int(rewards.get("biome_currency", 0)),
		"cards_played": int(rewards.get("cards_played", 0)),
		"minigames_won": int(rewards.get("minigames_won", 0)),
		"promises_kept": int(rewards.get("promises_kept", 0)),
		"promises_broken": int(rewards.get("promises_broken", 0)),
	}

	screen_completed.emit("rewards")
	return display


# ═══════════════════════════════════════════════════════════════════════════════
# SCREEN 4 (OPTIONAL): FACTION CHOICE — if 2+ factions >= 80
# ═══════════════════════════════════════════════════════════════════════════════

func show_faction_choice(factions: Array) -> Dictionary:
	_current_screen = SCREEN_FACTION_CHOICE
	return {
		"screen": "faction_choice",
		"eligible_factions": factions,
	}


func check_faction_choice_needed(faction_rep: Dictionary) -> Array:
	var eligible: Array = []
	for faction in faction_rep:
		if float(faction_rep[faction]) >= 80.0:
			eligible.append(str(faction))
	return eligible


func select_faction(faction: String) -> void:
	faction_chosen.emit(faction)


# ═══════════════════════════════════════════════════════════════════════════════
# NAVIGATION
# ═══════════════════════════════════════════════════════════════════════════════

func advance_screen() -> int:
	_current_screen += 1

	# After rewards, check for faction choice
	if _current_screen == SCREEN_FACTION_CHOICE:
		var faction_rep: Dictionary = _rewards.get("faction_rep_final", {})
		var eligible: Array = check_faction_choice_needed(faction_rep)
		if eligible.size() < 2:
			# Skip faction choice, go to hub
			_current_screen += 1

	if _current_screen > SCREEN_FACTION_CHOICE:
		return_to_hub.emit()

	return _current_screen


func get_current_screen() -> int:
	return _current_screen


# ═══════════════════════════════════════════════════════════════════════════════
# REWARD CALCULATION — Called before display
# ═══════════════════════════════════════════════════════════════════════════════

static func calculate_display_rewards(run_state: Dictionary, store_rewards: Dictionary) -> Dictionary:
	var display: Dictionary = store_rewards.duplicate(true)

	# Add run context
	display["biome"] = str(run_state.get("biome", ""))
	display["cards_played"] = int(run_state.get("cards_played", 0))
	display["biome_currency"] = int(run_state.get("biome_currency", 0))

	# Promise summary
	var promises: Array = run_state.get("active_promises", [])
	display["promises_remaining"] = promises.size()

	return display
