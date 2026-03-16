## ═══════════════════════════════════════════════════════════════════════════════
## UI Status Bar Module — Life, souffle, essences, clock, resources
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles top HUD status indicators.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIStatusBar

var _ui: MerlinGameUI

const SOUFFLE_ICON := "*"
const SOUFFLE_EMPTY := "o"
const SOUFFLE_MAX := 1

var current_souffle: int = 0
var _previous_souffle: int = -1
var _souffle_active: bool = false
var _souffle_glow_tween: Tween = null
var _life_segment_bars: Array = []


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


func setup_life_segments() -> void:
	_ui._life_bar.max_value = MerlinConstants.LIFE_ESSENCE_MAX
	_ui._life_bar.value = MerlinConstants.LIFE_ESSENCE_START
	MerlinVisual.apply_bar_theme(_ui._life_bar, "danger")
	_ui._life_bar.visible = false
	_life_segment_bars.clear()
	var seg_hbox: HBoxContainer = HBoxContainer.new()
	seg_hbox.name = "LifeSegmentsHBox"
	seg_hbox.add_theme_constant_override("separation", 3)
	_ui.life_panel.add_child(seg_hbox)
	for _i in range(MerlinConstants.LIFE_BAR_SEGMENTS):
		var seg: ProgressBar = ProgressBar.new()
		seg.max_value = 10
		seg.value = 10
		seg.show_percentage = false
		seg.custom_minimum_size = Vector2(20, 14)
		MerlinVisual.apply_bar_theme(seg, "danger")
		seg_hbox.add_child(seg)
		_life_segment_bars.append(seg)


func update_life_essence(life: int) -> void:
	if _ui._life_counter and is_instance_valid(_ui._life_counter):
		_ui._life_counter.text = "%d/%d" % [life, MerlinConstants.LIFE_ESSENCE_MAX]
		if life <= 0:
			_ui._life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		elif life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD:
			_ui._life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.warning)
		else:
			_ui._life_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	if _life_segment_bars.size() == MerlinConstants.LIFE_BAR_SEGMENTS:
		var remaining: int = clampi(life, 0, MerlinConstants.LIFE_ESSENCE_MAX)
		for seg_i in range(MerlinConstants.LIFE_BAR_SEGMENTS):
			var seg: ProgressBar = _life_segment_bars[seg_i]
			if not seg or not is_instance_valid(seg):
				continue
			var seg_max: int = 10
			var seg_filled: int = clampi(remaining - seg_i * seg_max, 0, seg_max)
			seg.value = float(seg_filled)
			var bar_pct: float = float(life) / float(MerlinConstants.LIFE_ESSENCE_MAX)
			if bar_pct <= 0.2:
				MerlinVisual.apply_bar_theme(seg, "danger")
			elif bar_pct <= 0.5:
				MerlinVisual.apply_bar_theme(seg, "warning")
		if life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD and _life_segment_bars.size() > 0:
			var last_full_seg: int = maxi(0, int(life / 10) - 1)
			var last_seg: ProgressBar = _life_segment_bars[last_full_seg]
			if last_seg and is_instance_valid(last_seg):
				var tw: Tween = _ui.create_tween()
				tw.set_loops(2)
				tw.tween_property(last_seg, "modulate:a", 0.5, 0.3)
				tw.tween_property(last_seg, "modulate:a", 1.0, 0.3)
	elif _ui._life_bar and is_instance_valid(_ui._life_bar):
		_ui._life_bar.value = life


func update_essences_collected(value: int) -> void:
	if _ui._essence_counter and is_instance_valid(_ui._essence_counter):
		_ui._essence_counter.text = "%d ◆" % maxi(value, 0)


func update_resource_bar(tool_id: String, day: int, mission_current: int, mission_total: int, essences_collected: int = 0) -> void:
	if _ui._tool_label:
		if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
			var tool_info: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
			_ui._tool_label.text = "%s %s" % [str(tool_info.get("icon", "")), str(tool_info.get("name", tool_id))]
		else:
			_ui._tool_label.text = ""
	if _ui._day_label:
		_ui._day_label.text = "Jour %d" % day
	if _ui._mission_progress_label:
		if mission_total > 0:
			_ui._mission_progress_label.text = "Mission %d/%d" % [mission_current, mission_total]
		else:
			_ui._mission_progress_label.text = ""
	update_essences_collected(essences_collected)


func update_souffle(souffle: int) -> void:
	var old_souffle: int = _previous_souffle
	_previous_souffle = souffle
	current_souffle = souffle

	if _ui._souffle_counter and is_instance_valid(_ui._souffle_counter):
		_ui._souffle_counter.text = "%d/%d" % [souffle, SOUFFLE_MAX]
		if souffle == 0:
			_ui._souffle_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.danger)
		elif souffle <= 2:
			_ui._souffle_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.warning)
		else:
			_ui._souffle_counter.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle)

	if not _ui.souffle_display:
		return

	for i in range(SOUFFLE_MAX):
		var icon: Label = _ui.souffle_display.get_child(i) as Label
		if icon:
			if i < souffle:
				icon.text = SOUFFLE_ICON
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle)
			else:
				icon.text = SOUFFLE_EMPTY
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.inactive_dark)

	# VFX: Regen animation
	if old_souffle >= 0 and souffle > old_souffle:
		for i in range(old_souffle, mini(souffle, SOUFFLE_MAX)):
			var icon: Label = _ui.souffle_display.get_child(i) as Label
			if icon:
				icon.scale = Vector2(0.3, 0.3)
				icon.pivot_offset = icon.size * 0.5
				var tw: Tween = _ui.create_tween()
				tw.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1 * (i - old_souffle))
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.15)
		SFXManager.play("souffle_regen")

	# VFX: Consumption animation
	if old_souffle >= 0 and souffle < old_souffle:
		for i in range(souffle, mini(old_souffle, SOUFFLE_MAX)):
			var icon: Label = _ui.souffle_display.get_child(i) as Label
			if icon:
				var tw: Tween = _ui.create_tween()
				tw.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.2) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)

	# VFX: Full souffle glow
	if souffle >= SOUFFLE_MAX:
		for i in range(SOUFFLE_MAX):
			var icon: Label = _ui.souffle_display.get_child(i) as Label
			if icon:
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle_full)
		if old_souffle >= 0 and old_souffle < SOUFFLE_MAX:
			SFXManager.play("souffle_full")

	# VFX: Empty souffle blink
	if souffle <= 0:
		for i in range(SOUFFLE_MAX):
			var icon: Label = _ui.souffle_display.get_child(i) as Label
			if icon:
				var tw: Tween = _ui.create_tween()
				tw.set_loops(3)
				tw.tween_property(icon, "modulate:a", 0.3, 0.4)
				tw.tween_property(icon, "modulate:a", 1.0, 0.4)

	_update_souffle_btn_state()

	# Glow pulsant sur l'icone souffle
	if _ui.souffle_display and is_instance_valid(_ui.souffle_display):
		var icon: Label = _ui.souffle_display.get_child(0) as Label
		if icon and is_instance_valid(icon):
			if _souffle_glow_tween and _souffle_glow_tween.is_valid():
				_souffle_glow_tween.kill()
			if souffle > 0:
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.souffle)
				_souffle_glow_tween = _ui.create_tween().set_loops()
				_souffle_glow_tween.tween_property(icon, "modulate:a", 0.55, 1.2).set_trans(Tween.TRANS_SINE)
				_souffle_glow_tween.tween_property(icon, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
			else:
				icon.modulate.a = 0.35
				icon.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.inactive_dark)


func on_souffle_btn_pressed() -> void:
	if current_souffle <= 0 or _souffle_active:
		SFXManager.play("error")
		return
	_souffle_active = true
	SFXManager.play("souffle_regen")
	if _ui._souffle_btn and is_instance_valid(_ui._souffle_btn):
		_ui._souffle_btn.text = "+" + SOUFFLE_ICON
		_ui._souffle_btn.pivot_offset = _ui._souffle_btn.size / 2.0
		var tw: Tween = _ui.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_ui._souffle_btn, "scale", Vector2(1.3, 1.3), 0.15)
		tw.tween_property(_ui._souffle_btn, "scale", Vector2(1.1, 1.1), 0.25)
	_ui.souffle_activated.emit()


func _update_souffle_btn_state() -> void:
	if not _ui._souffle_btn or not is_instance_valid(_ui._souffle_btn):
		return
	var can_use: bool = current_souffle > 0 and not _souffle_active
	_ui._souffle_btn.disabled = not can_use
	_ui._souffle_btn.modulate.a = 1.0 if can_use else 0.35


func is_souffle_active() -> bool:
	return _souffle_active


func consume_souffle_active() -> void:
	_souffle_active = false
	_update_souffle_btn_state()


func update_selected_perk(perk_id: String) -> void:
	if _ui._perk_badge == null or not is_instance_valid(_ui._perk_badge):
		return
	if perk_id.is_empty():
		_ui._perk_badge.visible = false
		return
	_ui._perk_badge.text = "[%s]" % perk_id.capitalize()
	_ui._perk_badge.visible = true


func update_clock_status() -> void:
	if not _ui._status_clock_label or not is_instance_valid(_ui._status_clock_label):
		return
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour: int = int(now.get("hour", 0))
	var minute: int = int(now.get("minute", 0))
	_ui._status_clock_label.text = "%02d:%02d" % [hour, minute]


func update_biome_indicator(biome_name: String, biome_color: Color) -> void:
	if _ui.biome_indicator:
		_ui.biome_indicator.text = "# %s #" % biome_name
		_ui.biome_indicator.add_theme_color_override("font_color", Color(biome_color.r, biome_color.g, biome_color.b, 0.7))


func update_mission(mission: Dictionary) -> void:
	if _ui.mission_label:
		if mission.get("revealed", false):
			var progress: int = int(mission.get("progress", 0))
			var total: int = int(mission.get("total", 0))
			_ui.mission_label.text = "Mission: %d/%d" % [progress, total]
		else:
			_ui.mission_label.text = "Mission: ???"


func update_cards_count(count: int) -> void:
	if _ui.cards_label:
		_ui.cards_label.text = "Cartes: %d" % count
