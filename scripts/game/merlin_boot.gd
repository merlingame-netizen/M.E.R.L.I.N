extends Control
## v10.18 — Écran de CHARGEMENT (boot). Le modèle Gemma 4 charge DANS UN THREAD (MerlinNative → zéro
## freeze). Ici : Merlin se MATÉRIALISE couche par couche (cape → tête → regard bleu) pendant que des
## LOGS s'égrènent à GAUCHE (style console d'éveil). Fondu vers le menu quand prêt. Scène de lancement.

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"
const REVEAL_S: float = 3.4      # durée de la matérialisation de Merlin
const MIN_SHOW_S: float = 3.6    # on laisse la matérialisation se jouer en entier
const MAX_WAIT_S: float = 30.0   # filet : on passe au menu même si le modèle traîne (procédural OK)

# Logs d'éveil (seuil de matérialisation → ligne). Style « console » : préfixe ▸, gauche, séquentiel.
const NARR: Array = [
	[0.00, "invocation du grimoire ancien"],
	[0.18, "éveil de la conscience"],
	[0.40, "tissage de la cape d'ombre"],
	[0.62, "matérialisation de la silhouette"],
	[0.80, "allumage du regard"],
]

var _scene_art: MerlinSceneArt
var _logbox: VBoxContainer
var _caret: Label
var _llm_line: Label
var _ready_model: bool = false
var _t0: float = 0.0
var _reveal: float = 0.0
var _narr_shown: int = 0
var _going: bool = false
var _caret_t: float = 0.0
var _caret_on: bool = true
# Capture dev (env-gated MERLIN_CAPTURE_DIR) — jamais active en prod.
var _cap_dir: String = ""
var _cap_iv_ms: int = 300
var _cap_max: int = 12
var _cap_count: int = 0
var _cap_last: int = 0
var _cap_boot: int = 0


func _ready() -> void:
	MerlinVisual.load_prefs()
	var bg: ColorRect = ColorRect.new()
	bg.color = MerlinVisual.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Décor vivant : Merlin (beat Climax) se matérialise via set_figure_reveal (piloté ci-dessous).
	_scene_art = MerlinSceneArt.new()
	_scene_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_art.modulate.a = 0.85
	add_child(_scene_art)
	_scene_art.set_menu_decor(true)
	_scene_art.set_beat("Climax")
	_scene_art.set_animated(true)
	_scene_art.set_figure_reveal(0.0)  # Merlin invisible au départ
	var tod_hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		tod_hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_scene_art.set_time_of_day(tod_hour)

	# Wordmark discret, en haut à GAUCHE (pas centré).
	var wm: Label = Label.new()
	wm.text = "M·E·R·L·I·N"
	wm.add_theme_color_override("font_color", MerlinVisual.GOLD)
	wm.add_theme_font_size_override("font_size", 38)
	wm.position = Vector2(52, 44)
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wm)

	# Feed de LOGS, à GAUCHE, aligné à gauche, séquentiel (style console d'éveil).
	_logbox = VBoxContainer.new()
	_logbox.anchor_left = 0.0
	_logbox.anchor_top = 0.0
	_logbox.offset_left = 54
	_logbox.offset_top = 150
	_logbox.add_theme_constant_override("separation", 7)
	_logbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logbox)
	# Ligne « modèle » réelle (▸ … → ✓ prêt sur model_ready).
	_llm_line = _make_log_label("▸ chargement du moteur (Gemma 4 E2B)…", MerlinVisual.DIM_WARM)
	_logbox.add_child(_llm_line)
	# Curseur clignotant (« prompt » de la console) en bas du feed.
	_caret = _make_log_label("▸ _", MerlinVisual.GOLD)
	_logbox.add_child(_caret)

	# Barre shimmer fine, en bas, pleine largeur (gauche → droite).
	var bar_bg: Panel = Panel.new()
	bar_bg.anchor_left = 0.0
	bar_bg.anchor_right = 1.0
	bar_bg.anchor_top = 1.0
	bar_bg.anchor_bottom = 1.0
	bar_bg.offset_left = 54
	bar_bg.offset_right = -54
	bar_bg.offset_top = -34
	bar_bg.offset_bottom = -30
	bar_bg.clip_contents = true
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = MerlinVisual.RING_BG
	bar_bg.add_theme_stylebox_override("panel", bsb)
	add_child(bar_bg)
	var fill: ColorRect = ColorRect.new()
	fill.color = MerlinVisual.GOLD
	fill.size = Vector2(120, 4)
	fill.position = Vector2(-120, 0)
	bar_bg.add_child(fill)
	var sh: Tween = create_tween().set_loops()
	sh.tween_property(fill, "position:x", 1400.0, 1.4).from(-120.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sh.tween_interval(0.25)

	# Connexion au modèle (chargé en thread). Connecter AVANT is_ready() (anti-race).
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.has_signal("model_ready") and not mn.model_ready.is_connected(_on_model_ready):
			mn.model_ready.connect(_on_model_ready)
		if mn.has_signal("model_failed") and not mn.model_failed.is_connected(_on_model_failed):
			mn.model_failed.connect(_on_model_failed)
		if mn.is_ready():
			_on_model_ready()
	else:
		_on_model_ready()

	_cap_dir = OS.get_environment("MERLIN_CAPTURE_DIR")
	var civ: String = OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS")
	if civ != "":
		_cap_iv_ms = maxi(50, int(civ))
	var cmx: String = OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES")
	if cmx != "":
		_cap_max = maxi(1, int(cmx))

	_t0 = Time.get_ticks_msec() / 1000.0
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	set_process(true)


func _make_log_label(txt: String, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 17)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_model_ready() -> void:
	_ready_model = true
	if _llm_line != null:
		_llm_line.text = "✓ Gemma 4 E2B — prêt"
		_llm_line.add_theme_color_override("font_color", MerlinVisual.GREEN)


func _on_model_failed(_reason: String) -> void:
	_ready_model = true  # le menu marche sans LLM (fallback procédural) → ne pas attendre pour rien
	if _llm_line != null:
		_llm_line.text = "▸ moteur indisponible — mode procédural"
		_llm_line.add_theme_color_override("font_color", MerlinVisual.VIOLET)


func _process(delta: float) -> void:
	_maybe_capture()
	# Matérialisation de Merlin (couche par couche, piloté par _reveal 0→1).
	_reveal = minf(_reveal + delta / REVEAL_S, 1.0)
	if _scene_art != null:
		_scene_art.set_figure_reveal(_reveal)
	# Logs d'éveil : on insère chaque ligne quand la matérialisation franchit son seuil.
	while _narr_shown < NARR.size() and _reveal >= float(NARR[_narr_shown][0]):
		var line: Label = _make_log_label("▸ " + str(NARR[_narr_shown][1]), MerlinVisual.CREAM)
		line.modulate.a = 0.0
		_logbox.add_child(line)
		_logbox.move_child(_caret, _logbox.get_child_count() - 1)  # curseur reste en bas
		create_tween().tween_property(line, "modulate:a", 1.0, 0.3)
		_narr_shown += 1
	# Curseur clignotant.
	_caret_t += delta
	if _caret_t >= 0.45:
		_caret_t = 0.0
		_caret_on = not _caret_on
		if _caret != null:
			_caret.modulate.a = 1.0 if _caret_on else 0.25
	# Transition : matérialisation finie ET modèle prêt (ou filet) ET durée mini écoulée.
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _t0
	if not _going and _reveal >= 1.0 and elapsed >= MIN_SHOW_S and (_ready_model or elapsed >= MAX_WAIT_S):
		_go_to_menu()


func _go_to_menu() -> void:
	_going = true
	set_process(false)
	# Hygiène (review LOW) : se déconnecter de l'autoload persistant avant de céder la scène.
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.has_signal("model_ready") and mn.model_ready.is_connected(_on_model_ready):
			mn.model_ready.disconnect(_on_model_ready)
		if mn.has_signal("model_failed") and mn.model_failed.is_connected(_on_model_failed):
			mn.model_failed.disconnect(_on_model_failed)
	if _caret != null:
		_caret.text = "✦ Merlin veille."
		_caret.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))


func _maybe_capture() -> void:
	if _cap_dir.is_empty():
		return
	if _cap_boot < 3:
		_cap_boot += 1  # laisse 3 frames de warmup avant la 1ère capture
		return
	var now: int = Time.get_ticks_msec()
	if now - _cap_last < _cap_iv_ms or _cap_count >= _cap_max:
		return
	_cap_last = now
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	if img.get_width() > 640:
		var ratio: float = 640.0 / float(img.get_width())
		img.resize(640, int(float(img.get_height()) * ratio), Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/frame_%04d.png" % [_cap_dir, _cap_count])
	_cap_count += 1
