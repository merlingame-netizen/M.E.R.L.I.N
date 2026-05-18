## ═══════════════════════════════════════════════════════════════════════════════
## CharacterHub v7.7.32 — Sprint 12.4(e) UI for cross-run progression
## ═══════════════════════════════════════════════════════════════════════════════
## Read-only display of MerlinProfile state : level, XP, oghams, traits,
## memory slots. Built programmatically (no .tscn-baked layout) so the test
## harness can instantiate it without scene dependencies and so a future
## redesign can swap the visual layer.
##
## Public API:
##   set_profile(profile)  -> attach a MerlinProfile instance and refresh()
##   load_profile(path)    -> load profile from disk + refresh
##   refresh()             -> redraw all panels from current profile snapshot
##   get_displayed_summary() -> Dictionary (test introspection)
##
## Caller graph (Sprint 12.4(e)+):
##   - scenes/CharacterHub.tscn (this script attached)
##   - scenes/TestCharacterHub.tscn (validation harness)
##   - Future : menu hub or pause menu navigation
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const VERSION := "7.7.32"
const ProfileSystemScript = preload("res://addons/merlin_ai/profile_system.gd")
const DEFAULT_PROFILE_PATH := "user://profile.json"

var _profile = null
var _last_snapshot: Dictionary = {}

# UI nodes (built lazily in _ready or via set_profile)
var _level_label: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _stats_label: Label
var _anam_label: Label
var _oghams_grid: GridContainer
var _traits_list: VBoxContainer
var _memory_list: VBoxContainer


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_layout()
	if _profile != null:
		refresh()


func _build_layout() -> void:
	if has_node("Root"):
		return
	var root := VBoxContainer.new()
	root.name = "Root"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	_level_label = Label.new()
	_level_label.text = "Druide niveau ?"
	_level_label.add_theme_font_size_override("font_size", 32)
	root.add_child(_level_label)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	root.add_child(xp_row)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(300, 24)
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	xp_row.add_child(_xp_bar)
	_xp_label = Label.new()
	_xp_label.text = "0 / ?  XP"
	xp_row.add_child(_xp_label)

	_stats_label = Label.new()
	_stats_label.text = "souffle ? essence ? runs ?"
	root.add_child(_stats_label)

	_anam_label = Label.new()
	_anam_label.text = "Anam : ?"
	root.add_child(_anam_label)

	var oghams_title := Label.new()
	oghams_title.text = "Oghams débloqués"
	oghams_title.add_theme_font_size_override("font_size", 20)
	root.add_child(oghams_title)
	_oghams_grid = GridContainer.new()
	_oghams_grid.columns = 6
	_oghams_grid.add_theme_constant_override("h_separation", 12)
	_oghams_grid.add_theme_constant_override("v_separation", 6)
	root.add_child(_oghams_grid)

	var traits_title := Label.new()
	traits_title.text = "Traits actifs"
	traits_title.add_theme_font_size_override("font_size", 20)
	root.add_child(traits_title)
	_traits_list = VBoxContainer.new()
	root.add_child(_traits_list)

	var mem_title := Label.new()
	mem_title.text = "Memoire druidique"
	mem_title.add_theme_font_size_override("font_size", 20)
	root.add_child(mem_title)
	_memory_list = VBoxContainer.new()
	root.add_child(_memory_list)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func set_profile(profile) -> void:
	_profile = profile
	if is_node_ready():
		refresh()


func load_profile(path: String = DEFAULT_PROFILE_PATH) -> bool:
	if _profile == null:
		_profile = ProfileSystemScript.new()
		add_child(_profile)
	var ok: bool = _profile.load_profile(path)
	if ok and is_node_ready():
		refresh()
	return ok


func refresh() -> void:
	if _profile == null:
		_last_snapshot = {}
		return
	_last_snapshot = _profile.summary()
	_redraw_header()
	_redraw_xp()
	_redraw_stats()
	_redraw_anam()
	_redraw_oghams()
	_redraw_traits()
	_redraw_memory()


func get_displayed_summary() -> Dictionary:
	return _last_snapshot.duplicate(true)


# ═══════════════════════════════════════════════════════════════════════════════
# RENDER PANELS
# ═══════════════════════════════════════════════════════════════════════════════

func _redraw_header() -> void:
	if _level_label == null:
		return
	var lvl: int = int(_last_snapshot.get("level", 1))
	_level_label.text = "Druide niveau %d" % lvl


func _redraw_xp() -> void:
	if _xp_bar == null or _xp_label == null:
		return
	var total: int = int(_last_snapshot.get("xp_total", 0))
	var to_next: int = int(_last_snapshot.get("xp_for_next_level", 100))
	var lvl: int = int(_last_snapshot.get("level", 1))
	var threshold_for_level: int = ProfileSystemScript.total_xp_for_level(lvl)
	var threshold_for_next: int = ProfileSystemScript.total_xp_for_level(lvl + 1)
	var into_level: int = max(0, total - threshold_for_level)
	var span: int = max(1, threshold_for_next - threshold_for_level)
	_xp_bar.max_value = span
	_xp_bar.value = into_level
	_xp_label.text = "%d / %d   (+%d XP -> niveau %d)" % [into_level, span, to_next, lvl + 1]


func _redraw_stats() -> void:
	if _stats_label == null:
		return
	var souffle: int = int(_last_snapshot.get("souffle_max", 5))
	var essence: int = int(_last_snapshot.get("essence_max", 20))
	var runs: int = int(_last_snapshot.get("completed_runs", 0))
	_stats_label.text = "Souffle max : %d   Essence max : %d   Marches complétées : %d" % [souffle, essence, runs]


func _redraw_anam() -> void:
	if _anam_label == null:
		return
	var anam: int = int(_last_snapshot.get("anam", 0))
	_anam_label.text = "Anam : %d" % anam


func _redraw_oghams() -> void:
	if _oghams_grid == null:
		return
	for child in _oghams_grid.get_children():
		child.queue_free()
	var oghams: Array = _last_snapshot.get("unlocked_oghams", [])
	if oghams.is_empty():
		var stub := Label.new()
		stub.text = "(aucun ogham débloqué)"
		_oghams_grid.add_child(stub)
		return
	for ogham in oghams:
		var lab := Label.new()
		lab.text = String(ogham)
		lab.add_theme_font_size_override("font_size", 18)
		_oghams_grid.add_child(lab)


func _redraw_traits() -> void:
	if _traits_list == null:
		return
	for child in _traits_list.get_children():
		child.queue_free()
	var traits: Array = _last_snapshot.get("active_traits", [])
	if traits.is_empty():
		var stub := Label.new()
		stub.text = "(aucun trait actif — joue plus de marches pour révéler ton style)"
		_traits_list.add_child(stub)
		return
	for t in traits:
		var row := VBoxContainer.new()
		_traits_list.add_child(row)
		var name_lab := Label.new()
		name_lab.text = "★ %s" % t.get("name", "?")
		name_lab.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lab)
		var prose_lab := Label.new()
		prose_lab.text = "    %s" % t.get("prose", "")
		prose_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(prose_lab)
		var effect_lab := Label.new()
		effect_lab.text = "    effet : %s" % t.get("effect_spec", "")
		row.add_child(effect_lab)


func _redraw_memory() -> void:
	if _memory_list == null:
		return
	for child in _memory_list.get_children():
		child.queue_free()
	var slots: Array = _last_snapshot.get("memory_slots", [])
	if slots.is_empty():
		var stub := Label.new()
		stub.text = "(aucun tag mémorisé)"
		_memory_list.add_child(stub)
		return
	for s in slots:
		var lab := Label.new()
		lab.text = "✦ %s   (depuis marche #%d)" % [s.get("tag", "?"), int(s.get("source_run", 0))]
		_memory_list.add_child(lab)
