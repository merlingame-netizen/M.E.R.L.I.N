## ═══════════════════════════════════════════════════════════════════════════════
## Tutorial System — Onboarding for first-time players
## ═══════════════════════════════════════════════════════════════════════════════
## Manages step-by-step tutorial aligned with Game Design Bible v2.4 section 10.
## Diegetic approach: Merlin guides through narration + progressive tooltips.
## Stores completion in profile meta.tutorial_completed via MerlinStore.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name TutorialSystem

signal step_changed(step: int)
signal tutorial_completed


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL STEPS (enum)
# ═══════════════════════════════════════════════════════════════════════════════

enum TutorialStep {
	NONE = -1,
	INTRO = 0,
	HUB_TOUR = 1,
	BIOME_SELECT = 2,
	OGHAM_INTRO = 3,
	FIRST_CARD = 4,
	FIRST_MINIGAME = 5,
	FIRST_EFFECTS = 6,
	COMPLETE = 7,
}

const STEP_COUNT: int = 8


# ═══════════════════════════════════════════════════════════════════════════════
# HINT TEXTS — Diegetic voice of Merlin (bible 10.1)
# ═══════════════════════════════════════════════════════════════════════════════

const HINT_TEXTS: Dictionary = {
	TutorialStep.INTRO: "Ah, voyageur... Bienvenue dans mon antre. Je suis Merlin, et tu es ici parce que les Oghams t'ont appele. Ecoute bien, car ce monde ne pardonne pas l'ignorance.",
	TutorialStep.HUB_TOUR: "Voici ton refuge entre les voyages. Observe : les factions qui guettent ta loyaute, les biomes qui attendent ton pas, et les Oghams — tes pouvoirs anciens.",
	TutorialStep.BIOME_SELECT: "Pour ton premier voyage, la Foret de Broceliande t'attend. C'est la que tout commence, voyageur. Choisis-la.",
	TutorialStep.OGHAM_INTRO: "Les Oghams sont tes pouvoirs. Tu en possedes trois pour commencer : Beith le revelateur, Luis le protecteur, et Quert le guerisseur. Equipe celui qui te parle.",
	TutorialStep.FIRST_CARD: "Chaque carte te presente trois voies. Lis bien les effets — un choix imprudent peut te couter cher. Active ton Ogham avant de choisir, si tu le souhaites.",
	TutorialStep.FIRST_MINIGAME: "Chaque action declenche une epreuve. Ton score determine l'intensite des effets. Plus tu reussis, plus le resultat est favorable.",
	TutorialStep.FIRST_EFFECTS: "Observe comment ton score transforme le monde. La vie, la reputation, les promesses — tout decoule de tes actes et de ta maitrise.",
	TutorialStep.COMPLETE: "Tu es pret, voyageur. Le chemin s'ouvre devant toi. Que les Oghams te guident... ou te trahissent.",
}


# ═══════════════════════════════════════════════════════════════════════════════
# TOOLTIP TRIGGERS — Progressive tooltips (bible 10.1 table)
# ═══════════════════════════════════════════════════════════════════════════════

const TOOLTIP_TEXTS: Dictionary = {
	"first_minigame": "Chaque action declenche une epreuve. Ton score determine l'intensite des effets.",
	"first_ogham_available": "Clique sur l'icone Ogham pour activer ton pouvoir.",
	"first_faction_change": "Ta reputation aupres des factions evolue. Elle persiste entre les runs.",
	"first_biome_currency": "La monnaie biome peut etre depensee aupres des marchands ou en offrandes.",
	"first_promise": "Les promesses ont un delai. Tiens-les pour gagner en reputation.",
}


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _current_step: int = TutorialStep.NONE
var _completed: bool = false
var _store: MerlinStore = null
var _tooltip_flags: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func initialize(store: MerlinStore) -> void:
	if store == null:
		push_error("[TutorialSystem] store is null — cannot initialize")
		return
	_store = store
	_load_state_from_profile()


func _load_state_from_profile() -> void:
	if _store == null:
		return
	var meta: Dictionary = _store.state.get("meta", {})
	_completed = bool(meta.get("tutorial_completed", false))
	var flags: Dictionary = meta.get("tutorial_flags", {})
	_tooltip_flags = flags.duplicate()


func _save_state_to_profile() -> void:
	if _store == null:
		return
	var meta: Dictionary = _store.state.get("meta", {})
	var updated_meta: Dictionary = meta.duplicate(true)
	updated_meta["tutorial_completed"] = _completed
	updated_meta["tutorial_flags"] = _tooltip_flags.duplicate()
	_store.state["meta"] = updated_meta
	_store.save_system.save_profile(updated_meta)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func start_tutorial() -> void:
	if _completed:
		return
	_current_step = TutorialStep.INTRO
	step_changed.emit(_current_step)


func advance() -> void:
	if _completed:
		return
	if _current_step == TutorialStep.NONE:
		return
	var next_step: int = _current_step + 1
	if next_step >= STEP_COUNT:
		next_step = TutorialStep.COMPLETE
	_current_step = next_step
	step_changed.emit(_current_step)
	if _current_step == TutorialStep.COMPLETE:
		_mark_complete()


func skip_tutorial() -> void:
	_current_step = TutorialStep.COMPLETE
	_mark_complete()
	step_changed.emit(_current_step)


func is_complete() -> bool:
	return _completed


func get_current_step() -> int:
	return _current_step


func get_current_step_name() -> String:
	match _current_step:
		TutorialStep.NONE: return "NONE"
		TutorialStep.INTRO: return "INTRO"
		TutorialStep.HUB_TOUR: return "HUB_TOUR"
		TutorialStep.BIOME_SELECT: return "BIOME_SELECT"
		TutorialStep.OGHAM_INTRO: return "OGHAM_INTRO"
		TutorialStep.FIRST_CARD: return "FIRST_CARD"
		TutorialStep.FIRST_MINIGAME: return "FIRST_MINIGAME"
		TutorialStep.FIRST_EFFECTS: return "FIRST_EFFECTS"
		TutorialStep.COMPLETE: return "COMPLETE"
	return "UNKNOWN"


func get_hint_text() -> String:
	if _current_step == TutorialStep.NONE:
		return ""
	return HINT_TEXTS.get(_current_step, "")


# ═══════════════════════════════════════════════════════════════════════════════
# TOOLTIP SYSTEM — Progressive tooltips (bible 10.1)
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the tooltip text if this trigger has not been shown before.
## Returns empty string if already shown. Marks the trigger as shown.
func try_show_tooltip(trigger_key: String) -> String:
	if _tooltip_flags.get(trigger_key, false):
		return ""
	if not TOOLTIP_TEXTS.has(trigger_key):
		return ""
	var updated_flags: Dictionary = _tooltip_flags.duplicate()
	updated_flags[trigger_key] = true
	_tooltip_flags = updated_flags
	_save_state_to_profile()
	return TOOLTIP_TEXTS[trigger_key]


func is_tooltip_shown(trigger_key: String) -> bool:
	return bool(_tooltip_flags.get(trigger_key, false))


func get_shown_tooltip_count() -> int:
	var count: int = 0
	for key in _tooltip_flags:
		if bool(_tooltip_flags[key]):
			count += 1
	return count


# ═══════════════════════════════════════════════════════════════════════════════
# FIRST RUN DETECTION (bible 3.1 — premier run onboarding)
# ═══════════════════════════════════════════════════════════════════════════════

func is_first_run() -> bool:
	if _store == null:
		return true
	var meta: Dictionary = _store.state.get("meta", {})
	var total_runs: int = int(meta.get("total_runs", 0))
	return total_runs == 0 and not _completed


func get_forced_biome() -> String:
	## Bible 3.1: first run forces foret_broceliande
	if is_first_run():
		return "foret_broceliande"
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _mark_complete() -> void:
	_completed = true
	_save_state_to_profile()
	tutorial_completed.emit()
