extends CanvasLayer
## P3 (chantier 1, CDC-UX-04) — Overlay PAUSE système de MerlinGame. Échap ouvre cet overlay qui
## GÈLE la boucle via get_tree().paused (tweens + typewriter + fusion + coroutines de draft figés).
## Exception ASSUMÉE au « zéro modal » (R136 / CDC-UX-04) : ne vise que les phases de JEU.
##
## Enfant de MerlinGame, process_mode = ALWAYS : reste vivant pendant que l'arbre est en pause
## (MerlinGame, lui, PAUSABLE → ses tweens gèlent). Boutons : Reprendre · Options · Menu principal.
## « Menu principal » est save-safe R108 : la save sur disque est TOUJOURS le DÉBUT du beat courant
## (écrite à l'avance-beat) → on ne réécrit jamais un état mi-beat « sale » ; CONTINUER reprend juste.
##
## Réutilise la grammaire visuelle de MerlinOptions (dim + panneau centré + boutons DA).

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_GOLD: Color = MerlinVisual.GOLD
const DUR_IN: float = MerlinVisual.DUR_PANEL_OPEN
const DUR_OUT: float = MerlinVisual.DUR_VEIL_IN
const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"

var _dim: ColorRect = null
var _panel: MarginContainer = null
var _tw: Tween = null
var _leaving: bool = false   # garde anti double-clic « Menu principal » (une seule navigation)
var _resuming: bool = false  # garde anti double-clic « Reprendre » (revue gameplay HIGH : sinon le 2e
                             # clic tue le tween que le 1er attend → coroutine + Tween fuités, sfx x2)


func _ready() -> void:
	layer = 140  # sous MerlinOptions (150) : Options s'ouvre AU-DESSUS de la pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	get_tree().paused = true  # GÈLE la boucle (tweens/typewriter/fusion/draft)
	visible = true
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(1.0, 0.85)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = DUR_IN * MerlinVisual.motion()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_dim, "modulate:a", 1.0, d).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_panel, "modulate:a", 1.0, d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_panel, "scale", Vector2.ONE, d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	MerlinAudio.play_sfx("button_tap")


# Reprendre : referme l'overlay et DÉGÈLE l'arbre. Le fondu de sortie tourne sur le tween d'un node
# ALWAYS → il joue bien même si l'arbre vient d'être dépausé.
func _resume() -> void:
	# Garde de ré-entrance (revue gameplay HIGH) : `visible` ne bascule qu'APRÈS l'await ; sans ce flag,
	# un 2e clic « Reprendre » (ou Échap + clic quasi simultanés) tuerait le tween que le 1er await
	# attend → coroutine + Tween fuités. On pose _resuming AVANT tout await.
	if not visible or _resuming:
		return
	_resuming = true
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var d: float = DUR_OUT * MerlinVisual.motion()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_dim, "modulate:a", 0.0, d).set_trans(Tween.TRANS_SINE)
	_tw.tween_property(_panel, "modulate:a", 0.0, d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.tween_property(_panel, "scale", Vector2(1.0, 0.85), d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tw.finished
	visible = false
	_resuming = false
	get_tree().paused = false
	MerlinAudio.play_sfx("button_tap")


func _on_options() -> void:
	MerlinOptions.toggle()  # s'ouvre AU-DESSUS (layer 150, autoload ALWAYS) — l'arbre reste en pause


# Menu principal — save-safe R108. La save sur disque est déjà le début du beat courant : on ne
# réécrit rien (un save mi-beat persisterait des jauges post-résolution sous un beat non avancé →
# rejeu double au resume, cf. R108). On coupe la génération LLM en vol + la nappe, on DÉGÈLE l'arbre
# AVANT de changer de scène (sinon le menu se charge en pause), puis on navigue.
func _to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		mn.cancel()
	MerlinAudio.stop_pad()
	get_tree().paused = false
	MerlinTransition.change_scene(MENU_SCENE)


# Échap referme la pause (Reprendre) — SAUF si les Options sont ouvertes par-dessus : dans ce cas
# c'est MerlinOptions qui consomme Échap (garde robuste quel que soit l'ordre de _unhandled_input).
func _unhandled_input(event: InputEvent) -> void:
	if visible and not _leaving and event.is_action_pressed("ui_cancel") and not MerlinOptions.is_open():
		_resume()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = MerlinVisual.DIM_MODAL
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP  # bloque tout clic vers le plateau (déjà gelé)
	root.add_child(_dim)

	_panel = MarginContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.add_child(_panel)
	_panel.resized.connect(func() -> void: _panel.pivot_offset = _panel.size * 0.5)

	var bg: PanelContainer = PanelContainer.new()
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = COL_BG
	psb.set_corner_radius_all(12)
	psb.set_border_width_all(2)
	psb.border_color = COL_GOLD
	psb.set_content_margin_all(40)
	bg.add_theme_stylebox_override("panel", psb)
	_panel.add_child(bg)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Pause"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Filet + triskèle or (DA alignée sur Options/menu).
	var rule: HBoxContainer = MerlinOrnament.triskele_rule(20.0)
	vbox.add_child(rule)
	MerlinOrnament.spin_triskele(rule)

	_menu_button("Reprendre", _resume, vbox)
	_menu_button("Options", _on_options, vbox)
	_menu_button("Menu principal", _to_menu, vbox)


func _menu_button(txt: String, cb: Callable, parent: Control) -> void:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(320, 56)  # ≥44 px (pilier TACTILE)
	b.add_theme_font_size_override("font_size", 22)
	MerlinVisual.apply_button_da(b)
	MerlinVisual.connect_button_feedback(b)
	b.pressed.connect(cb)
	parent.add_child(b)
