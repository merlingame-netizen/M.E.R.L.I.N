## ═══════════════════════════════════════════════════════════════════════════════
## UI Status Bar Module — Life, essences, clock, resources
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles top HUD status indicators.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIStatusBar

var _ui: MerlinGameUI

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
