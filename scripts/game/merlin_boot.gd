extends Control
## v10.18 — Écran de CHARGEMENT (boot). Le modèle Gemma 4 est chargé DANS UN THREAD par MerlinNative
## (zéro freeze) ; ici on anime un éveil de Merlin fluide (triskèle rotative, wordmark qui respire,
## barre shimmer, décor vivant + Merlin qui flotte/cligne) puis on FOND vers le menu quand c'est prêt.
## Scène de lancement (project.godot main_scene). Le menu marche sans LLM → filet de temps si ça traîne.

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"
const MIN_SHOW_S: float = 1.3    # durée mini d'affichage (évite un flash si le modèle charge vite)
const MAX_WAIT_S: float = 30.0   # filet : on passe au menu même si le modèle traîne (procédural OK)

var _scene_art: MerlinSceneArt
var _title: Label
var _status: Label
var _tris: MerlinGlyph
var _bar_fill: ColorRect
var _ready_model: bool = false
var _t0: float = 0.0
var _going: bool = false
var _dots_t: float = 0.0
var _dots: int = 0


func _ready() -> void:
	MerlinVisual.load_prefs()
	var bg: ColorRect = ColorRect.new()
	bg.color = MerlinVisual.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Décor vivant en fond (atténué) — cohérent avec le menu → transition seamless. Merlin (beat
	# Climax) flotte/cligne pendant le chargement.
	_scene_art = MerlinSceneArt.new()
	_scene_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_art.modulate.a = 0.55
	add_child(_scene_art)
	_scene_art.set_menu_decor(true)
	_scene_art.set_beat("Climax")
	_scene_art.set_animated(true)
	var tod_hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		tod_hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_scene_art.set_time_of_day(tod_hour)

	# Bloc central.
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_tris = MerlinGlyph.new()
	_tris.custom_minimum_size = Vector2(64, 64)
	_tris.pivot_offset = Vector2(32, 32)
	_tris.setup("triskele", MerlinVisual.GOLD, 2.4)
	box.add_child(_tris)

	_title = Label.new()
	_title.text = "M·E·R·L·I·N"
	_title.add_theme_color_override("font_color", MerlinVisual.GOLD)
	_title.add_theme_font_size_override("font_size", 46)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_status = Label.new()
	_status.text = "✦ Éveil de Merlin"
	_status.add_theme_color_override("font_color", MerlinVisual.DIM_WARM)
	_status.add_theme_font_size_override("font_size", 20)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	# Barre de chargement SHIMMER (indéterminée : un éclat or balaie de gauche à droite).
	var bar_bg: Panel = Panel.new()
	bar_bg.custom_minimum_size = Vector2(260, 4)
	bar_bg.clip_contents = true
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = MerlinVisual.RING_BG
	bsb.set_corner_radius_all(2)
	bar_bg.add_theme_stylebox_override("panel", bsb)
	box.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = MerlinVisual.GOLD
	_bar_fill.size = Vector2(70, 4)
	_bar_fill.position = Vector2(-70, 0)
	bar_bg.add_child(_bar_fill)

	# Animations idle (THREAD PRINCIPAL → toujours fluides puisque le load est threadé).
	var rot: Tween = create_tween().set_loops()
	rot.tween_property(_tris, "rotation", TAU, 18.0).from(0.0)
	var tb: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tb.tween_property(_title, "modulate:a", 0.7, 1.1)
	tb.tween_property(_title, "modulate:a", 1.0, 1.1)
	var sh: Tween = create_tween().set_loops()
	sh.tween_property(_bar_fill, "position:x", 260.0, 1.1).from(-70.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sh.tween_interval(0.3)

	# Connexion au modèle (chargé en thread par MerlinNative). Connecter AVANT le is_ready() (anti-race).
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.has_signal("model_ready") and not mn.model_ready.is_connected(_on_model_ready):
			mn.model_ready.connect(_on_model_ready)
		if mn.has_signal("model_failed") and not mn.model_failed.is_connected(_on_model_failed):
			mn.model_failed.connect(_on_model_failed)
		if mn.is_ready():
			_ready_model = true
	else:
		_ready_model = true  # pas de moteur → on file au menu (procédural)

	_t0 = Time.get_ticks_msec() / 1000.0
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)
	set_process(true)


func _on_model_ready() -> void:
	_ready_model = true


func _on_model_failed(_reason: String) -> void:
	_ready_model = true  # le menu marche sans LLM (fallback procédural) → ne pas attendre pour rien


func _process(delta: float) -> void:
	_dots_t += delta
	if _dots_t >= 0.4:
		_dots_t = 0.0
		_dots = (_dots + 1) % 4
		if _status != null:
			_status.text = "✦ Éveil de Merlin" + ".".repeat(_dots)
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _t0
	if not _going and elapsed >= MIN_SHOW_S and (_ready_model or elapsed >= MAX_WAIT_S):
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
	if _status != null:
		_status.text = "✦ Merlin veille"
		_status.add_theme_color_override("font_color", MerlinVisual.GOLD)
	var tw: Tween = create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
