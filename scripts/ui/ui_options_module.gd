## ═══════════════════════════════════════════════════════════════════════════════
## UI Options Module — Option buttons, hover, highlight, what-if labels
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles option button interactions,
## entrance animations, keyboard navigation, and what-if effect labels.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIOptionsModule

var _ui: MerlinGameUI

const ACTION_VERB_FALLBACK: Array[String] = ["Observer", "Canaliser", "Braver"]
const ACTION_VERBS: Array[String] = [
	"Explorer", "Fuir", "Negocier", "Observer", "Defier", "Invoquer",
	"Traverser", "Accepter", "Refuser", "Proteger", "Attaquer", "Apaiser",
	"Chercher", "Ecouter", "Suivre", "Braver", "Canaliser", "Mediter",
	"Soigner", "Sacrifier", "Marchander", "Implorer", "Confronter",
	"Esquiver", "Sonder", "Conjurer", "Purifier", "Resister",
	"Avancer", "Agir", "Reculer", "Parler", "Ignorer", "Prendre",
	"Toucher", "Ouvrir", "Courir", "Attendre", "Prier", "Ramasser",
	"Contourner", "Plonger", "Grimper", "Frapper", "Appeler",
]

const OPTION_KEYS: Dictionary = {
	MerlinConstants.CardOption.LEFT: "A",
	MerlinConstants.CardOption.CENTER: "B",
	MerlinConstants.CardOption.RIGHT: "C",
}

var _highlighted_option: int = -1


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


func reset_highlight() -> void:
	_highlighted_option = -1


func on_option_hover_enter(option_index: int) -> void:
	SFXManager.play("hover")
	if _ui.current_card.is_empty():
		return
	var options: Array = _ui.current_card.get("options", [])
	if option_index >= options.size():
		return
	var option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	var btn: Button = _ui.option_buttons[option_index] if option_index < _ui.option_buttons.size() else null
	if _ui._reward_badge and is_instance_valid(_ui._reward_badge) and btn and is_instance_valid(btn):
		_ui._reward_badge.show_for_option(option, btn)

	if btn and is_instance_valid(btn):
		btn.pivot_offset = btn.size / 2.0
		var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.07, 1.07), 0.18)

	for k in range(_ui._option_desc_labels.size()):
		if k < _ui._option_desc_labels.size() and is_instance_valid(_ui._option_desc_labels[k]):
			var show_it: bool = k == option_index and not _ui._option_desc_labels[k].text.is_empty()
			_ui._option_desc_labels[k].visible = show_it
			if show_it:
				_ui._option_desc_labels[k].modulate.a = 0.0
				var desc_tw: Tween = _ui.create_tween()
				desc_tw.tween_property(_ui._option_desc_labels[k], "modulate:a", 1.0, 0.15)


func on_option_hover_exit() -> void:
	if _ui._reward_badge and is_instance_valid(_ui._reward_badge):
		_ui._reward_badge.hide_badge()
	for ob in _ui.option_buttons:
		if is_instance_valid(ob):
			ob.scale = Vector2.ONE
	for dl in _ui._option_desc_labels:
		if is_instance_valid(dl):
			dl.visible = false


func highlight_option(option: int) -> void:
	if _ui.current_card.is_empty():
		return
	if _highlighted_option == option:
		return

	for i in range(_ui.option_buttons.size()):
		var btn: Button = _ui.option_buttons[i]
		if is_instance_valid(btn):
			btn.scale = Vector2.ONE
			btn.pivot_offset = btn.size / 2.0

	_highlighted_option = option
	SFXManager.play("hover")

	if option < _ui.option_buttons.size():
		var btn: Button = _ui.option_buttons[option]
		if is_instance_valid(btn):
			btn.pivot_offset = btn.size / 2.0
			var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.12)
		on_option_hover_enter(option)


func on_option_pressed(option: int) -> void:
	if _ui.current_card.is_empty():
		return

	_highlighted_option = -1
	SFXManager.play("choice_select")

	if option < _ui.option_buttons.size():
		var btn: Button = _ui.option_buttons[option]
		btn.pivot_offset = btn.size / 2.0
		var tween: Tween = _ui.create_tween()
		tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
		tween.parallel().tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.08)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.15)

	for j in range(_ui.option_buttons.size()):
		if j == option:
			continue
		if not is_instance_valid(_ui.option_buttons[j]):
			continue
		var other_btn: Button = _ui.option_buttons[j]
		other_btn.pivot_offset = other_btn.size / 2.0
		var clear_tw: Tween = _ui.create_tween().set_parallel(true)
		clear_tw.tween_property(other_btn, "modulate:a", 0.0, 0.25)
		clear_tw.tween_property(other_btn, "scale", Vector2(0.85, 0.85), 0.25)

	for dl in _ui._option_desc_labels:
		if is_instance_valid(dl):
			dl.visible = false

	_ui.option_chosen.emit(option)


func animate_option_entrance() -> void:
	var pixel_btn_config: Dictionary = {
		"duration": MerlinVisual.OPTION_SLIDE_DURATION,
		"block_size": 6,
		"row_stagger": 0.003,
		"jitter": 0.008,
		"scatter_x": 12.0,
		"scatter_y_min": -20.0,
		"scatter_y_max": -50.0,
		"easing": "back_out",
	}
	for j in range(_ui.option_buttons.size()):
		if not is_instance_valid(_ui.option_buttons[j]) or _ui.option_buttons[j].disabled:
			continue
		var btn: Button = _ui.option_buttons[j]
		btn.pivot_offset = btn.size / 2.0
		btn.modulate.a = 0.0
		btn.scale = Vector2(0.95, 0.95)
		var delay: float = float(j) * MerlinVisual.OPTION_STAGGER_DELAY
		if delay > 0.0:
			await _ui.get_tree().create_timer(delay).timeout
			if not _ui.is_inside_tree():
				return
		PixelContentAnimator.reveal(btn, pixel_btn_config)
		var settle_tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		settle_tw.tween_property(btn, "scale", Vector2.ONE, MerlinVisual.OPTION_SLIDE_DURATION)
	_ui.get_tree().create_timer(1.2).timeout.connect(func():
		for btn2 in _ui.option_buttons:
			if is_instance_valid(btn2) and not btn2.disabled and btn2.modulate.a < 0.5:
				btn2.modulate.a = 1.0
				btn2.scale = Vector2.ONE
	)


func actionize_option_label(raw_label: String, option_index: int) -> String:
	var clean: String = raw_label.strip_edges()
	if clean.is_empty():
		return ACTION_VERB_FALLBACK[clampi(option_index, 0, ACTION_VERB_FALLBACK.size() - 1)]
	var words: PackedStringArray = clean.replace(":", " ").replace(",", " ").replace(".", " ").split(" ", false)
	if words.is_empty():
		return ACTION_VERB_FALLBACK[clampi(option_index, 0, ACTION_VERB_FALLBACK.size() - 1)]
	return words[0].capitalize()


func hide_what_if_labels() -> void:
	for lbl in _ui._what_if_labels:
		if lbl and is_instance_valid(lbl):
			lbl.visible = false
			lbl.text = ""


func show_reveal_effects(options: Array, target_index: int) -> void:
	var reveal_color: Color = MerlinVisual.CRT_PALETTE.get("ogham_gold", Color(0.85, 0.75, 0.4))
	for i in range(mini(options.size(), 3)):
		if target_index >= 0 and i != target_index:
			continue
		var opt: Dictionary = options[i] if i < options.size() else {}
		var effects: Array = opt.get("effects", [])
		if effects.is_empty():
			continue
		var parts: Array[String] = []
		for eff in effects:
			var eff_dict: Dictionary = eff if eff is Dictionary else {}
			var etype: String = str(eff_dict.get("type", ""))
			var amount: int = int(eff_dict.get("amount", eff_dict.get("intensity", 0)))
			if etype == "ADD_KARMA" or etype == "KARMA":
				parts.append("Karma %+d" % amount)
			elif etype == "DAMAGE_LIFE":
				parts.append("Vie -%d" % absi(amount))
			elif etype == "HEAL_LIFE":
				parts.append("Vie +%d" % absi(amount))
			else:
				parts.append(etype.to_lower())
		if parts.is_empty():
			continue
		var summary: String = " | ".join(parts)
		if i < _ui._what_if_labels.size():
			var lbl: Label = _ui._what_if_labels[i]
			if lbl and is_instance_valid(lbl):
				lbl.text = summary
				lbl.add_theme_color_override("font_color", reveal_color)
				lbl.visible = true
				var tw: Tween = _ui.create_tween()
				tw.tween_interval(4.0)
				tw.tween_callback(func():
					if lbl and is_instance_valid(lbl):
						lbl.visible = false
						lbl.text = "")


func get_highlighted_option() -> int:
	return _highlighted_option
