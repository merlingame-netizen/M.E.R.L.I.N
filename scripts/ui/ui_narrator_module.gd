## ═══════════════════════════════════════════════════════════════════════════════
## UI Narrator Module — Narrator intro, scenario intro, typewriter, thinking
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles text presentation, narrator
## sequences, and thinking animations.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UINarratorModule

var _ui: MerlinGameUI

const NARRATOR_INTROS: Array[String] = [
	"Les brumes de Bretagne s'ouvrent devant toi... Le chemin serpente, et l'avenir est incertain.",
	"La foret murmure ton nom. Merlin veille... mais pour combien de temps encore?",
	"Le vent porte des echos anciens. Un nouveau cycle commence, voyageur.",
	"Les pierres se souviennent de chaque pas. Pret a ecrire un nouveau chapitre?",
	"L'aube se leve sur les landes. Quelque chose attend au bout du sentier.",
]

var _narrator_active: bool = false
var _waiting_narrator_click: bool = false
var _typewriter_active: bool = false
var _typewriter_abort: bool = false

# Thinking animation
var _thinking_active: bool = false
var _thinking_dots: int = 0
var _thinking_timer: Timer = null
var _thinking_spiral: Control = null

# Blip pool
var _blip_pool: Array[AudioStreamPlayer] = []
var _blip_idx: int = 0
const BLIP_POOL_SIZE := 4


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


func init_blip_pool() -> void:
	for i in range(BLIP_POOL_SIZE):
		var gen: AudioStreamGenerator = AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.02
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = gen
		player.volume_db = linear_to_db(0.04)
		_ui.add_child(player)
		_blip_pool.append(player)


func is_narrator_active() -> bool:
	return _narrator_active


func is_waiting_narrator_click() -> bool:
	return _waiting_narrator_click


func set_waiting_narrator_click(value: bool) -> void:
	_waiting_narrator_click = value


func is_typewriter_active() -> bool:
	return _typewriter_active


func abort_typewriter() -> void:
	_typewriter_abort = true


# ═══════════════════════════════════════════════════════════════════════════════
# THINKING ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

func show_thinking() -> void:
	if _thinking_active:
		return
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		push_warning("[MerlinUI] show_thinking: card_panel invalid, skipping")
		return
	_thinking_active = true
	_ui._card_display.disable_card_3d()

	if _ui.options_container and is_instance_valid(_ui.options_container):
		var tw: Tween = _ui.create_tween()
		tw.tween_property(_ui.options_container, "modulate:a", 0.3, 0.2)

	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		_ui.card_speaker.text = "Merlin"
		_ui.card_speaker.visible = true

	if _ui.card_panel and is_instance_valid(_ui.card_panel):
		if _thinking_spiral != null and is_instance_valid(_thinking_spiral):
			_thinking_spiral.visible = true
		else:
			_thinking_spiral = Control.new()
			_thinking_spiral.name = "ThinkingSpiral"
			_thinking_spiral.custom_minimum_size = Vector2(60, 60)
			_thinking_spiral.set_anchors_preset(Control.PRESET_CENTER)
			var panel_size: Vector2 = _ui.card_panel.size if _ui.card_panel.size.length() > 0 else Vector2(460, 360)
			_thinking_spiral.position = panel_size * 0.5 - Vector2(30, 50)
			_thinking_spiral.draw.connect(_draw_thinking_spiral.bind(_thinking_spiral))
			_ui.card_panel.add_child(_thinking_spiral)

	_thinking_dots = 0
	if _thinking_timer == null:
		_thinking_timer = Timer.new()
		_thinking_timer.wait_time = 0.4
		_thinking_timer.timeout.connect(_on_thinking_tick)
		_ui.add_child(_thinking_timer)
	_thinking_timer.start()
	_on_thinking_tick()


func hide_thinking() -> void:
	if not _thinking_active:
		return
	_thinking_active = false

	if _thinking_timer:
		_thinking_timer.stop()

	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		_thinking_spiral.visible = false

	if _ui.options_container and is_instance_valid(_ui.options_container):
		var tw: Tween = _ui.create_tween()
		tw.tween_property(_ui.options_container, "modulate:a", 1.0, 0.2)


func _on_thinking_tick() -> void:
	if not _ui.card_text or not is_instance_valid(_ui.card_text):
		if _thinking_timer and is_instance_valid(_thinking_timer):
			_thinking_timer.stop()
		_thinking_active = false
		return
	_thinking_dots = (_thinking_dots + 1) % 4
	var dots: String = ".".repeat(_thinking_dots)
	_ui.card_text.text = "Merlin reflechit" + dots

	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		var tw: Tween = _ui.create_tween()
		tw.tween_property(_thinking_spiral, "rotation", _thinking_spiral.rotation + PI * 0.5, 0.35)
		_thinking_spiral.queue_redraw()


func _draw_thinking_spiral(ctrl: Control) -> void:
	var cx: float = ctrl.size.x * 0.5
	var cy: float = ctrl.size.y * 0.5
	var r: float = mini(int(ctrl.size.x), int(ctrl.size.y)) * 0.35

	for arm in range(3):
		var angle_offset: float = TAU * arm / 3.0
		var points: PackedVector2Array = PackedVector2Array()
		for i in range(20):
			var t: float = float(i) / 19.0
			var spiral_r: float = r * t
			var angle: float = angle_offset + t * TAU * 0.75
			points.append(Vector2(
				cx + cos(angle) * spiral_r,
				cy + sin(angle) * spiral_r
			))
		if points.size() >= 2:
			ctrl.draw_polyline(points, MerlinVisual.CRT_PALETTE.amber, 2.0, true)

	ctrl.draw_circle(Vector2(cx, cy), 3.0, MerlinVisual.CRT_PALETTE.amber)


# ═══════════════════════════════════════════════════════════════════════════════
# TYPEWRITER
# ═══════════════════════════════════════════════════════════════════════════════

func typewriter_card_text(full_text: String) -> void:
	if _ui.card_text == null or not is_instance_valid(_ui.card_text):
		return

	_typewriter_active = true
	_typewriter_abort = false
	if _ui._text_pixel_fx_layer and is_instance_valid(_ui._text_pixel_fx_layer):
		for child in _ui._text_pixel_fx_layer.get_children():
			child.queue_free()

	_ui.card_text.text = full_text
	_ui.card_text.visible_characters = -1
	_ui.card_text.modulate.a = 0.0

	var pca: Node = _ui.get_node_or_null("/root/PixelContentAnimator")
	if pca:
		await _ui.get_tree().process_frame
		pca.reveal(_ui.card_text, {"duration": 0.35, "block_size": 6, "easing": "back_out"})
		_play_blip()
		await _ui.get_tree().create_timer(0.4).timeout
	else:
		_ui.card_text.modulate.a = 1.0

	_typewriter_active = false
	for btn in _ui.option_buttons:
		if is_instance_valid(btn) and btn.text != "\u2014":
			btn.disabled = false
	_ui._options_module.animate_option_entrance()


func _play_blip() -> void:
	return


# ═══════════════════════════════════════════════════════════════════════════════
# NARRATOR INTRO
# ═══════════════════════════════════════════════════════════════════════════════

func show_narrator_intro(biome_key: String = "") -> void:
	print("[MerlinUI] show_narrator_intro(biome=%s)" % biome_key)
	SFXManager.play("whoosh")
	_narrator_active = true
	var should_dim_ui: bool = not _ui._opening_sequence_done

	var pca: Node = _ui.get_node_or_null("/root/PixelContentAnimator")
	if should_dim_ui and _ui.options_container and is_instance_valid(_ui.options_container):
		if pca and _ui.options_container.modulate.a > 0.1:
			pca.dissolve(_ui.options_container, {"duration": 0.3, "block_size": 8})
		else:
			_ui.options_container.modulate.a = 0.0
	if should_dim_ui and _ui.info_panel and is_instance_valid(_ui.info_panel):
		if pca and _ui.info_panel.modulate.a > 0.1:
			pca.dissolve(_ui.info_panel, {"duration": 0.3, "block_size": 8})
		else:
			_ui.info_panel.modulate.a = 0.0

	var bk: String = biome_key.strip_edges().to_lower()
	if bk.is_empty():
		var gm: Node = _ui.get_node_or_null("/root/GameManager")
		if gm:
			var run_data: Variant = gm.get("run")
			if run_data is Dictionary:
				bk = str(run_data.get("current_biome", run_data.get("biome", {}).get("id", "")))
	if bk.is_empty():
		bk = "broceliande"
	var bk_short: String = bk
	for prefix in ["foret_", "landes_", "cotes_", "villages_", "cercles_", "marais_", "collines_"]:
		bk_short = bk_short.replace(prefix, "")

	var mission: Dictionary = MerlinConstants.get_mission_template(bk_short)
	if mission.is_empty():
		mission = MerlinConstants.get_mission_template(bk)

	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		var biome_display: String = bk.replace("_", " ").capitalize()
		if not mission.is_empty():
			var mission_name: String = str(mission.get("name", biome_display))
			_ui.card_speaker.text = "Merlin \u2014 %s" % mission_name
		else:
			_ui.card_speaker.text = "Merlin \u2014 %s" % biome_display
		_ui.card_speaker.visible = true

	var atmo_text: String = ""
	var intro_source: String = "static"
	var intro_file: FileAccess = FileAccess.open("user://temp_run_intro.json", FileAccess.READ)
	if intro_file:
		var json_str: String = intro_file.get_as_text()
		intro_file.close()
		var parsed: Variant = JSON.parse_string(json_str)
		if parsed is Dictionary:
			var llm_text: String = str(parsed.get("text", ""))
			if llm_text.length() >= 10:
				atmo_text = llm_text
				intro_source = "llm"
				print("[MerlinUI] LLM narrator intro loaded: %s" % llm_text.left(50))
		DirAccess.remove_absolute("user://temp_run_intro.json")

	if atmo_text.is_empty():
		var merlin_ai: Node = _ui.get_node_or_null("/root/MerlinAI")
		if merlin_ai and merlin_ai.has_method("generate_text") and merlin_ai.get("is_ready"):
			var inline_prompt: String = "Tu es Merlin. Accueille le voyageur en 2 phrases. Biome: %s." % bk
			var t0: int = Time.get_ticks_msec()
			var llm_r: Variant = await merlin_ai.generate_text(inline_prompt, {"max_tokens": 40, "temperature": 0.8})
			if (Time.get_ticks_msec() - t0) < 3000 and llm_r is Dictionary:
				var txt: String = str(llm_r.get("text", ""))
				if txt.length() >= 10:
					atmo_text = txt
					intro_source = "llm_inline"
	if atmo_text.is_empty():
		atmo_text = NARRATOR_INTROS[randi() % NARRATOR_INTROS.size()]

	var intro_text: String = ""
	if not mission.is_empty():
		var quest_title: String = str(mission.get("title", ""))
		var quest_text: String = str(mission.get("text", ""))
		if not quest_title.is_empty():
			intro_text = quest_title + "\n\n" + atmo_text
			if not quest_text.is_empty():
				intro_text += "\n\n" + quest_text
	if intro_text.is_empty():
		intro_text = atmo_text

	if _ui._card_source_badge and is_instance_valid(_ui._card_source_badge):
		LLMSourceBadge.update_badge(_ui._card_source_badge, intro_source)
		_ui._card_source_badge.visible = true

	SFXManager.play("eye_open")

	var pages: Array[String] = _split_into_pages(intro_text)
	for page_idx in range(pages.size()):
		if not _ui.is_inside_tree():
			return
		await typewriter_card_text(pages[page_idx])
		if not _ui.is_inside_tree():
			return
		var is_last_page: bool = (page_idx == pages.size() - 1)
		var continue_hint: String = "[color=#8a7a6a][i]Cliquez pour continuer...[/i][/color]" if not is_last_page else "[color=#8a7a6a][i]Cliquez pour commencer l'aventure...[/i][/color]"
		if _ui.card_text and is_instance_valid(_ui.card_text):
			_ui.card_text.text += "\n\n" + continue_hint
		_waiting_narrator_click = true
		var safety_deadline: int = Time.get_ticks_msec() + 30000
		while _waiting_narrator_click and _ui.is_inside_tree() and Time.get_ticks_msec() < safety_deadline:
			await _ui.get_tree().process_frame
		_waiting_narrator_click = false
		if not is_last_page:
			SFXManager.play("card_draw")

	SFXManager.play("card_draw")

	if should_dim_ui and _ui.options_container and is_instance_valid(_ui.options_container):
		if pca:
			pca.reveal(_ui.options_container, {"duration": 0.35, "block_size": 8})
		else:
			_ui.options_container.modulate.a = 1.0
	if should_dim_ui and _ui.info_panel and is_instance_valid(_ui.info_panel):
		if pca:
			pca.reveal(_ui.info_panel, {"duration": 0.35, "block_size": 8})
		else:
			_ui.info_panel.modulate.a = 1.0

	_narrator_active = false
	_ui.narrator_intro_finished.emit()
	print("[MerlinUI] narrator intro finished")


func show_scenario_intro(title: String, context: String) -> void:
	if not _ui.card_text or not is_instance_valid(_ui.card_text):
		return
	if context.strip_edges().is_empty():
		return
	print("[MerlinUI] show_scenario_intro: %s" % title)
	if _ui.card_speaker and is_instance_valid(_ui.card_speaker):
		_ui.card_speaker.text = title if not title.is_empty() else "Scenario"
		_ui.card_speaker.visible = true
	SFXManager.play("eye_open")
	await typewriter_card_text(context)
	if _ui.card_text and is_instance_valid(_ui.card_text):
		_ui.card_text.text += "\n\n[color=#8a7a6a][i]Cliquez pour commencer...[/i][/color]"
	_waiting_narrator_click = true
	var deadline: int = Time.get_ticks_msec() + 30000
	while _waiting_narrator_click and _ui.is_inside_tree() and Time.get_ticks_msec() < deadline:
		await _ui.get_tree().process_frame
	_waiting_narrator_click = false
	SFXManager.play("card_draw")


func _split_into_pages(text: String, max_chars: int = 180) -> Array[String]:
	var pages: Array[String] = []
	var blocks: Array[String] = []
	for block in text.split("\n\n"):
		var trimmed: String = block.strip_edges()
		if not trimmed.is_empty():
			blocks.append(trimmed)
	for block in blocks:
		if block.length() <= max_chars:
			pages.append(block)
		else:
			var sentences: PackedStringArray = block.split(". ")
			var current_page: String = ""
			for sent in sentences:
				var candidate: String = sent.strip_edges()
				if candidate.is_empty():
					continue
				if not candidate.ends_with(".") and not candidate.ends_with("!") and not candidate.ends_with("?"):
					candidate += "."
				if current_page.is_empty():
					current_page = candidate
				elif (current_page + " " + candidate).length() <= max_chars:
					current_page += " " + candidate
				else:
					pages.append(current_page)
					current_page = candidate
			if not current_page.is_empty():
				pages.append(current_page)
	if pages.is_empty():
		pages.append(text.strip_edges())
	return pages


func cleanup() -> void:
	_typewriter_abort = true
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.stop()
