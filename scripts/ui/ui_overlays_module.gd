## ═══════════════════════════════════════════════════════════════════════════════
## UI Overlays Module — Facade delegating to focused sub-modules
## ═══════════════════════════════════════════════════════════════════════════════
## Sub-modules: UIOverlayDice, UIOverlayNarrative, UIOverlayEndScreen, UIOverlayEffects
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOverlaysModule

var _ui: MerlinGameUI

var _dice: UIOverlayDice
var _narrative: UIOverlayNarrative
var _endscreen: UIOverlayEndScreen
var _effects: UIOverlayEffects


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui
	_dice = UIOverlayDice.new()
	_dice.initialize(ui)
	_narrative = UIOverlayNarrative.new()
	_narrative.initialize(ui)
	_endscreen = UIOverlayEndScreen.new()
	_endscreen.initialize(ui)
	_effects = UIOverlayEffects.new()
	_effects.initialize(ui)


func setup_dialogue_nodes() -> void:
	_narrative.setup_dialogue_nodes()


func get_dialogue_btn() -> Button:
	return _narrative.get_dialogue_btn()


# ═══════════════════════════════════════════════════════════════════════════════
# DICE UI
# ═══════════════════════════════════════════════════════════════════════════════

func show_dice_roll(dc: int, target: int) -> void:
	await _dice.show_dice_roll(dc, target)


func show_dice_instant(dc: int, value: int) -> void:
	_dice.show_dice_instant(dc, value)


func show_dice_result(roll: int, dc: int, outcome: String) -> void:
	_dice.show_dice_result(roll, dc, outcome)


func hide_dice_overlay() -> void:
	_dice.hide_dice_overlay()


func show_score_to_d20(score: int, d20: int, tool_bonus: int) -> void:
	_dice.show_score_to_d20(score, d20, tool_bonus)


func show_minigame_intro(field: String, tool_bonus_text: String, tool_bonus: int) -> void:
	_dice.show_minigame_intro(field, tool_bonus_text, tool_bonus)


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL, DREAM, MERLIN THINKING, PAUSE, DIALOGUE
# ═══════════════════════════════════════════════════════════════════════════════

func show_travel_animation(text: String) -> void:
	await _narrative.show_travel_animation(text, _dice)


func show_dream_overlay(dream_text: String) -> void:
	await _narrative.show_dream_overlay(dream_text)


func show_merlin_thinking_overlay() -> void:
	_narrative.show_merlin_thinking_overlay()


func hide_merlin_thinking_overlay() -> void:
	_narrative.hide_merlin_thinking_overlay()


func show_pause_menu() -> void:
	_narrative.show_pause_menu()


func hide_pause_menu() -> void:
	_narrative.hide_pause_menu()


func show_merlin_dialogue_response(text: String) -> void:
	_narrative.show_merlin_dialogue_response(text)


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN, JOURNAL, TYPOLOGY
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	await _endscreen.show_end_screen(ending)


func show_journal_popup(run_summaries: Array[Dictionary]) -> void:
	_endscreen.show_journal_popup(run_summaries)


func show_typology_timer(total_seconds: float) -> void:
	_endscreen.show_typology_timer(total_seconds)


func update_typology_timer(remaining: float) -> void:
	_endscreen.update_typology_timer(remaining)


func hide_typology_timer() -> void:
	_endscreen.hide_typology_timer()


func show_typology_badge(_typology: String) -> void:
	_endscreen.show_typology_badge(_typology)


func hide_typology_badge() -> void:
	_endscreen.hide_typology_badge()


func show_typology_event(event: String) -> void:
	_endscreen.show_typology_event(event)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD OUTCOME ANIMATIONS & EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func show_reaction_text(text: String, outcome: String) -> void:
	_effects.show_reaction_text(text, outcome)


func show_result_text_transition(result_text: String, outcome: String) -> void:
	await _effects.show_result_text_transition(result_text, outcome)


func flash_biome_for_outcome(outcome: String) -> void:
	_effects.flash_biome_for_outcome(outcome)


func show_critical_badge() -> void:
	_effects.show_critical_badge()


func show_biome_passive(passive: Dictionary) -> void:
	_effects.show_biome_passive(passive)


func animate_card_outcome(outcome: String) -> void:
	_effects.animate_card_outcome(outcome)


func show_milestone_popup(title_text: String, desc_text: String) -> void:
	_effects.show_milestone_popup(title_text, desc_text)


func show_life_delta(delta: int) -> void:
	_effects.show_life_delta(delta)


func show_progressive_indicators() -> void:
	await _effects.show_progressive_indicators()
