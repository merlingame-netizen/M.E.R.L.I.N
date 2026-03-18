## ═══════════════════════════════════════════════════════════════════════════════
## RencontreDialogue — Typewriter, response blocks, badges for SceneRencontreMerlin
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted module: handles text display, response UI, skip hints, LLM waiting.
## ═══════════════════════════════════════════════════════════════════════════════

class_name RencontreDialogue
extends RefCounted

const TYPEWRITER_DELAY := 0.011
const TYPEWRITER_PUNCT_DELAY := 0.028
const RESPONSE_CONFIRM_DELAY := 0.22

var _scene: Control


func _init(scene: Control) -> void:
	_scene = scene


# ═══════════════════════════════════════════════════════════════════════════════
# BADGES
# ═══════════════════════════════════════════════════════════════════════════════

func update_dialogue_badge(source: String) -> void:
	var badge: PanelContainer = _scene._dialogue_source_badge
	if badge and is_instance_valid(badge):
		LLMSourceBadge.update_badge(badge, source)
		badge.visible = true


func update_response_badge(source: String) -> void:
	var badge: PanelContainer = _scene._response_source_badge
	if badge and is_instance_valid(badge):
		LLMSourceBadge.update_badge(badge, source)
		badge.visible = true


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func show_text(text: String) -> void:
	text = text.replace("[long_pause]", "").replace("[pause]", "").replace("[beat]", "").strip_edges()
	_scene.typing_active = true
	_scene.typing_abort = false
	_scene.merlin_text.text = text
	_scene.merlin_text.visible_characters = 0

	for i in range(text.length()):
		if _scene.typing_abort or not _scene.is_inside_tree():
			break
		_scene.merlin_text.visible_characters = i + 1
		var ch := text[i]
		if ch != " ":
			_scene._play_blip()
		var delay := TYPEWRITER_DELAY
		if ch in [".", "!", "?"]:
			delay = TYPEWRITER_PUNCT_DELAY
		if not _scene.is_inside_tree():
			break
		await _scene.get_tree().create_timer(_scene._scaled_delay(delay)).timeout

	_scene.merlin_text.visible_characters = -1
	_scene.typing_active = false


func skip_typewriter() -> void:
	if _scene.typing_active:
		_scene.typing_abort = true
		_scene.merlin_text.visible_characters = -1


# ═══════════════════════════════════════════════════════════════════════════════
# LLM WAITING INDICATOR
# ═══════════════════════════════════════════════════════════════════════════════

func show_llm_waiting() -> void:
	if not _scene.merlin_text or not is_instance_valid(_scene.merlin_text):
		return
	_scene.merlin_text.text = "..."
	_scene.merlin_text.visible_characters = -1
	if _scene._llm_wait_tween:
		_scene._llm_wait_tween.kill()
	_scene._llm_wait_tween = _scene.create_tween().set_loops()
	_scene._llm_wait_tween.tween_property(_scene.merlin_text, "modulate:a", 0.3, _scene._scaled_delay(0.45)).set_trans(Tween.TRANS_SINE)
	_scene._llm_wait_tween.tween_property(_scene.merlin_text, "modulate:a", 1.0, _scene._scaled_delay(0.45)).set_trans(Tween.TRANS_SINE)


func hide_llm_waiting() -> void:
	if _scene._llm_wait_tween:
		_scene._llm_wait_tween.kill()
		_scene._llm_wait_tween = null
	if _scene.merlin_text and is_instance_valid(_scene.merlin_text):
		_scene.merlin_text.modulate.a = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# SKIP HINT
# ═══════════════════════════════════════════════════════════════════════════════

func set_skip_hint(show_hint: bool, custom_text: String = "") -> void:
	if not _scene.skip_hint or not is_instance_valid(_scene.skip_hint):
		return
	if custom_text != "":
		_scene.skip_hint.text = custom_text
	if show_hint:
		_scene.skip_hint.visible = true
		_scene.skip_hint.modulate.a = 1.0
		if _scene._skip_hint_tween:
			_scene._skip_hint_tween.kill()
		_scene._skip_hint_tween = _scene.create_tween().set_loops()
		_scene._skip_hint_tween.tween_property(_scene.skip_hint, "modulate:a", 0.42, _scene._scaled_delay(0.45)).set_trans(Tween.TRANS_SINE)
		_scene._skip_hint_tween.tween_property(_scene.skip_hint, "modulate:a", 1.0, _scene._scaled_delay(0.45)).set_trans(Tween.TRANS_SINE)
	else:
		if _scene._skip_hint_tween:
			_scene._skip_hint_tween.kill()
			_scene._skip_hint_tween = null
		_scene.skip_hint.visible = false
		_scene.skip_hint.modulate.a = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# RESPONSE BLOCKS
# ═══════════════════════════════════════════════════════════════════════════════

func show_response_blocks(line_index: int, context_line: String = "") -> void:
	_scene._response_chosen = -1
	var vp := _scene.get_viewport().get_visible_rect().size
	var rc_width := minf(450.0, vp.x * 0.8)
	_scene.response_container.position = Vector2((vp.x - rc_width) * 0.5, _scene.card.position.y + _scene.card.size.y + 16)
	_scene.response_container.size.x = rc_width

	# Try LLM-generated responses, fallback to static
	var responses: Array[String] = await _scene._llm_module.generate_responses(context_line, line_index)
	update_response_badge(_scene._last_response_source)
	for i in range(_scene.response_buttons.size()):
		if i < responses.size():
			_scene.response_buttons[i].text = "[%d] %s" % [i + 1, responses[i]]
			_scene.response_buttons[i].visible = true
			_scene.response_buttons[i].modulate.a = 0.0
		else:
			_scene.response_buttons[i].visible = false

	# Position buttons between card bottom and viewport bottom
	var visible_count := mini(responses.size(), 3)
	var total_h := visible_count * 44.0 + (visible_count - 1) * 10.0
	var btn_area_top: float = _scene.card.position.y + _scene.card.size.y + 16.0
	var btn_area_bottom: float = vp.y - 24.0
	var available_h: float = btn_area_bottom - btn_area_top
	var btn_y: float = btn_area_top + (available_h - total_h) * 0.5
	btn_y = clampf(btn_y, btn_area_top, vp.y - total_h - 16.0)
	_scene.response_container.position = Vector2((vp.x - rc_width) * 0.5, btn_y)
	_scene.response_container.size.x = rc_width

	_scene.response_container.visible = true
	var pca_rb: Node = _scene.get_node_or_null("/root/PixelContentAnimator")
	if pca_rb:
		var btns_reveal: Array[Control] = []
		for i in range(visible_count):
			btns_reveal.append(_scene.response_buttons[i])
		await _scene.get_tree().process_frame
		pca_rb.reveal_group(btns_reveal, {"duration": 0.2, "block_size": 8, "inter_delay": 0.06})
	else:
		for i in range(visible_count):
			var tw := _scene.create_tween()
			tw.tween_property(_scene.response_buttons[i], "modulate:a", 1.0, _scene._scaled_delay(0.16)).set_delay(_scene._scaled_delay(float(i) * 0.04))

	while _scene._response_chosen < 0 and not _scene.scene_finished:
		if not _scene.is_inside_tree():
			return
		await _scene.get_tree().process_frame

	if _scene._response_chosen >= 0 and _scene.is_inside_tree():
		await _scene.get_tree().create_timer(_scene._scaled_delay(RESPONSE_CONFIRM_DELAY)).timeout

	if pca_rb:
		pca_rb.dissolve(_scene.response_container, {"duration": 0.25, "block_size": 8})
		await _scene.get_tree().create_timer(0.3).timeout
	else:
		var hide_tw := _scene.create_tween()
		hide_tw.tween_property(_scene.response_container, "modulate:a", 0.0, _scene._scaled_delay(0.22))
		await hide_tw.finished
	_scene.response_container.visible = false
	_scene.response_container.modulate.a = 1.0
	for btn in _scene.response_buttons:
		btn.modulate.a = 1.0


## B.5 — First-run destination choice UI. Returns the chosen index (0 or 1).
func show_destination_choice() -> int:
	# Merlin asks the player
	var fade := _scene.create_tween()
	fade.tween_property(_scene.merlin_text, "modulate:a", 0.0, _scene._scaled_delay(0.15))
	await fade.finished
	if not _scene.is_inside_tree():
		return 0
	_scene.merlin_text.modulate.a = 1.0
	update_dialogue_badge("static")
	await show_text("Veux-tu explorer l'Antre avant de partir... ou t'elancer directement dans l'aventure ?")
	if not _scene.is_inside_tree():
		return 0

	# Show 2 choice buttons
	_scene._response_chosen = -1
	_scene.response_buttons[0].text = "[1] Explorer le Refuge"
	_scene.response_buttons[1].text = "[2] Commencer l'Aventure"
	_scene.response_buttons[0].visible = true
	_scene.response_buttons[1].visible = true
	_scene.response_buttons[2].visible = false

	var vp := _scene.get_viewport().get_visible_rect().size
	var rc_width := minf(380.0, vp.x * 0.75)
	var btn_area_top: float = _scene.card.position.y + _scene.card.size.y + 16.0
	var total_h: float = 2.0 * 44.0 + 10.0
	var btn_y: float = btn_area_top + ((vp.y - 24.0 - btn_area_top - total_h) * 0.5)
	_scene.response_container.position = Vector2((vp.x - rc_width) * 0.5, btn_y)
	_scene.response_container.size.x = rc_width
	_scene.response_container.visible = true
	for i in range(2):
		_scene.response_buttons[i].modulate.a = 1.0
	update_response_badge("static")

	while _scene._response_chosen < 0 and not _scene.scene_finished:
		if not _scene.is_inside_tree():
			return 0
		await _scene.get_tree().process_frame

	var result: int = _scene._response_chosen

	# Hide response buttons
	_scene.response_container.visible = false
	_scene.response_container.modulate.a = 1.0
	for btn in _scene.response_buttons:
		btn.modulate.a = 1.0
		btn.visible = false

	return result


func on_response_chosen(index: int) -> void:
	SFXManager.play("choice_select")
	_scene._response_chosen = index
	for i in range(_scene.response_buttons.size()):
		if i == index:
			_scene.response_buttons[i].add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
		else:
			_scene.response_buttons[i].modulate.a = 0.4
