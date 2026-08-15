class_name MerlinWaitStage
extends Control
## v10.13 (A3) — Composant d'attente ANIMÉE générique, DA flat (couleurs MerlinVisual).
## Pattern extrait du sustain de fusion (merlin_fx.gd) : l'attente n'est JAMAIS un voile statique
## (user 2026-06-07) — caption à points cyclants + glow qui respire + affordance de skip + cap.
## Consommateurs prévus (phase B, PAS encore branchés) : boot modèle, écran de sélection,
## sustain (via MerlinFx), épilogue.
##
## Usage :
##   var ws: MerlinWaitStage = MerlinWaitStage.start(self, {"caption": "Merlin s'éveille"})
##   var issue: String = await ws.wait_until(func() -> bool: return model_ready)
##   # issue ∈ {"ready", "timeout", "skipped"} — le layer s'est queue_free() tout seul.

const DOT_PERIOD_MS: int = 450      # cadence des points cyclants de la caption
const SKIP_REVEAL_MS: int = 4000    # l'affordance de skip se révèle après 4s (pilier FACILE)
const GLOW_PULSE_S: float = 0.9     # respiration du glow (TRANS_SINE, parité sustain fusion)
const GLOW_A_HI: float = 0.18       # alpha haut de la respiration (parité sustain fusion)
const GLOW_A_LO: float = 0.06       # alpha bas
const FS_WAIT_CAPTION: int = 26     # taille caption (parité sustain fusion)
const SKIP_TEXT_DEFAULT: String = "▶ clic pour passer"  # copy skip unifiée (plan v10.13 A3)
# NOTE 2026-08-15 : cette classe n'est plus instanciée (v11-V2b — l'attente vit dans l'encart de
# merlin_game). Le cap ci-dessous ne dimensionne donc RIEN ; il est conservé tel quel pour ne pas
# toucher à du code dormant, mais ne doit pas servir de référence — il fut calé sur « ≈1 tok/s »,
# chiffre démenti (mesure réelle : 4,31 tok/s).
const CAP_MS_DEFAULT: int = 20000

# Configuration figée par start().
var _caption: String = ""
var _skip_text: String = SKIP_TEXT_DEFAULT
var _skippable: bool = true
var _cap_ms: int = CAP_MS_DEFAULT
var _skip_reveal_ms: int = SKIP_REVEAL_MS  # audit ux_flow F1 : révélation du skip paramétrable
var _skipped: bool = false          # armé par le clic gauche (gui_input) si skippable
var _caption_lbl: Label = null


# Crée le layer d'attente, le configure plein écran et l'ajoute au host. opts (toutes optionnelles) :
#   caption: String       — texte de la caption (points cyclants ajoutés automatiquement)
#   color: Color          — teinte caption + glow (défaut MerlinVisual.GOLD)
#   glow: bool            — glow plein écran qui respire (défaut true)
#   skippable: bool       — clic gauche = sortir en "skipped" (défaut true)
#   skip_text: String     — copy de l'affordance (défaut « ▶ clic pour passer »)
#   cap_ms: int           — deadline murale en ms (défaut 20000)
#   dim_alpha: float      — voile assombrissant 0.0-1.0 (défaut 0.0 = aucun)
static func start(host: Control, opts: Dictionary) -> MerlinWaitStage:
	var ws: MerlinWaitStage = MerlinWaitStage.new()
	ws._caption = str(opts.get("caption", ""))
	ws._skippable = bool(opts.get("skippable", true))
	ws._skip_text = str(opts.get("skip_text", SKIP_TEXT_DEFAULT))
	ws._cap_ms = int(opts.get("cap_ms", CAP_MS_DEFAULT))
	var col: Color = opts.get("color", MerlinVisual.GOLD)
	var with_glow: bool = bool(opts.get("glow", true))
	var dim_alpha: float = float(opts.get("dim_alpha", 0.0))
	ws._skip_reveal_ms = int(opts.get("skip_reveal_ms", SKIP_REVEAL_MS))
	ws.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Skippable → modal (absorbe les clics pour les recevoir) ; sinon transparent aux clics.
	ws.mouse_filter = Control.MOUSE_FILTER_STOP if ws._skippable else Control.MOUSE_FILTER_IGNORE
	host.add_child(ws)
	ws._build(col, with_glow, dim_alpha)
	return ws


# Construit les couches visuelles (après add_child : les anchors s'appliquent dans l'arbre).
func _build(col: Color, with_glow: bool, dim_alpha: float) -> void:
	# Voile assombrissant optionnel (fond du modal, teinte ink-brun DA flat).
	if dim_alpha > 0.0:
		var dim: ColorRect = ColorRect.new()
		dim.color = Color(MerlinVisual.BG_DEEP.r, MerlinVisual.BG_DEEP.g, MerlinVisual.BG_DEEP.b, dim_alpha)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)

	# Glow plein écran qui respire (TRANS_SINE 0.9s) — l'attente est vivante, jamais figée.
	if with_glow:
		var glow: ColorRect = ColorRect.new()
		glow.color = Color(col.r, col.g, col.b, 0.0)
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow)
		# Tween lié à CE node (create_tween d'un Control) → meurt avec le layer, jamais orphelin.
		var pulse: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "color:a", GLOW_A_HI, GLOW_PULSE_S)
		pulse.tween_property(glow, "color:a", GLOW_A_LO, GLOW_PULSE_S)

	# Caption centrée (bande pleine largeur à 60% de hauteur — parité sustain fusion), fade-in.
	_caption_lbl = Label.new()
	_caption_lbl.add_theme_color_override("font_color", col)
	_caption_lbl.add_theme_font_size_override("font_size", FS_WAIT_CAPTION)
	_caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_lbl.anchor_left = 0.0
	_caption_lbl.anchor_right = 1.0
	_caption_lbl.anchor_top = 0.60
	_caption_lbl.anchor_bottom = 0.60
	_caption_lbl.offset_top = 0.0
	_caption_lbl.offset_bottom = 40.0
	_caption_lbl.text = _caption
	_caption_lbl.modulate.a = 0.0
	add_child(_caption_lbl)
	create_tween().tween_property(_caption_lbl, "modulate:a", 0.85, 0.4)

	if _skippable:
		gui_input.connect(_on_gui_input)


# Clic gauche = skip (affordance révélée dans la caption après SKIP_REVEAL_MS).
func _on_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_skipped = true


# Attente animée awaitable. Sort dès que `pred` est vrai ("ready"), au clic si skippable
# ("skipped"), ou au cap ("timeout"). Boucle process_frame avec garde is_inside_tree (la scène
# peut être libérée pendant l'attente). À la sortie, le layer se queue_free() lui-même.
func wait_until(pred: Callable) -> String:
	var issue: String = "timeout"
	var t0: int = Time.get_ticks_msec()
	var deadline_ms: int = t0 + _cap_ms
	var next_dot_ms: int = 0
	var dots: int = 0
	while is_inside_tree():
		if _skipped:
			issue = "skipped"
			break
		# Prédicat invalide = jamais prêt → le cap tranche (pas de crash sur Callable mort).
		if pred.is_valid() and bool(pred.call()):
			issue = "ready"
			break
		var now: int = Time.get_ticks_msec()
		if now >= deadline_ms:
			issue = "timeout"
			break
		if now >= next_dot_ms and is_instance_valid(_caption_lbl):
			next_dot_ms = now + DOT_PERIOD_MS
			dots = (dots + 1) % 4
			# Affordance de skip révélée après 4s d'attente (pilier FACILE — pas de gel perçu).
			var hint: String = ""
			if _skippable and now - t0 > _skip_reveal_ms:
				hint = "  ·  " + _skip_text
			_caption_lbl.text = _caption + " " + ".".repeat(dots) + hint
		await get_tree().process_frame
	if is_instance_valid(self):  # le parent a pu nous libérer (sortie is_inside_tree=false)
		queue_free()
	return issue


# Met à jour le texte de base de la caption (les points cyclants + hint sont re-suffixés par la boucle).
func set_caption(txt: String) -> void:
	_caption = txt
	if is_instance_valid(_caption_lbl):
		_caption_lbl.text = txt
