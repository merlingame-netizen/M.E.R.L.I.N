extends CanvasLayer
## MerlinDebugOverlay — autoload DEBUG. Panneau « Gemma — Live » épinglé à droite, TOUTES scènes.
## Affiche l'état du moteur (idle / génère + étiquette + chrono) et le journal des dernières
## générations (sélection, intro, issue, épilogue…). Bascule avec F9. Click-through (ne bloque
## jamais le jeu). Temporaire / outil de test (demande utilisateur 2026-05-26).

const PANEL_W: int = 360
const PANEL_H: int = 460
const COL_BG: Color = Color(0.06, 0.05, 0.04, 0.90)
const COL_GOLD: Color = Color("C9A24B")
const COL_TEXT: Color = Color("E8DCC0")
const COL_DIM: Color = Color("9C8C6A")
const COL_GREEN: Color = Color("7FA65C")
const COL_VIOLET: Color = Color("7B4FA3")

var _panel: Panel
var _status_lbl: RichTextLabel
var _log_lbl: RichTextLabel


func _ready() -> void:
	if not OS.is_debug_build():
		# Outil dev uniquement : absent des builds release (pilier MINIMAL). Aucun nœud, aucun process.
		set_process(false)
		set_process_input(false)
		return
	layer = 128  # au-dessus de tout
	process_mode = Node.PROCESS_MODE_ALWAYS  # tourne même si l'arbre est en pause
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -(PANEL_W + 10)
	_panel.offset_right = -10
	_panel.offset_top = 10
	_panel.offset_bottom = 10 + PANEL_H
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # click-through : ne bloque pas le jeu
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = COL_GOLD
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)

	var header: Label = Label.new()
	header.text = "✦ GEMMA — LIVE   (F9)"
	header.add_theme_color_override("font_color", COL_GOLD)
	header.add_theme_font_size_override("font_size", 16)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(header)

	_status_lbl = _mk_rtl(15)
	_status_lbl.custom_minimum_size = Vector2(0, 52)
	v.add_child(_status_lbl)

	var sep: HSeparator = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)

	var jtitle: Label = Label.new()
	jtitle.text = "Journal (récent → ancien)"
	jtitle.add_theme_color_override("font_color", COL_DIM)
	jtitle.add_theme_font_size_override("font_size", 12)
	jtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(jtitle)

	_log_lbl = _mk_rtl(13)
	_log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_log_lbl)


func _mk_rtl(fsize: int) -> RichTextLabel:
	var r: RichTextLabel = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_color_override("default_color", COL_TEXT)
	r.add_theme_font_size_override("normal_font_size", fsize)
	return r


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_panel.visible = not _panel.visible


func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn == null:
		_status_lbl.text = "[color=#9C8C6A]MerlinNative absent[/color]"
		return
	if not mn.is_ready():
		_status_lbl.text = "[color=#C9A24B]… chargement du modèle Gemma 4 E2B[/color]"
		return
	if mn.is_busy():
		var secs: float = mn.get_elapsed_ms() / 1000.0
		_status_lbl.text = "[color=#7FA65C]⟳ GÉNÈRE[/color]  [color=#E8DCC0]« %s »[/color]\n[color=#9C8C6A]%.1f s écoulées…[/color]" % [mn.get_current_label(), secs]
	else:
		_status_lbl.text = "[color=#7FA65C]● prêt[/color]  [color=#9C8C6A](moteur libre)[/color]"
	_render_log(mn.get_activity_log())


func _render_log(log: Array) -> void:
	var lines: PackedStringArray = []
	for i in range(log.size() - 1, -1, -1):  # récent → ancien
		var e: Dictionary = log[i]
		var ok: bool = bool(e.get("ok", true))
		var mark: String = "[color=#7FA65C]✓[/color]" if ok else "[color=#7B4FA3]✗[/color]"
		var secs: float = float(e.get("ms", 0)) / 1000.0
		lines.append("%s [color=#E8DCC0]%s[/color]  [color=#9C8C6A]%.1fs · %dc[/color]" % [
			mark, str(e.get("label", "?")), secs, int(e.get("chars", 0))])
	_log_lbl.text = "\n".join(lines)
