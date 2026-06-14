extends CanvasLayer
## MerlinTransition — fondu au noir entre scènes (autoload). Remplace les change_scene_to_file
## directs (coupures sèches) par : fondu vers le noir → changement → fondu depuis le noir.
## Non bloquant, court (≤ ~220ms par sens). Au-dessus de tout (layer 200).

const DUR: float = 0.22
const COL_FADE: Color = MerlinVisual.BG_DEEP

var _rect: ColorRect
var _caption: Label
var _busy: bool = false


func _ready() -> void:
	layer = 200  # au-dessus du debug overlay (128)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = COL_FADE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_color", MerlinVisual.DIM_WARM)
	_caption.add_theme_font_size_override("font_size", MerlinVisual.FS_CAPTION)
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.position.y = -60.0
	_rect.add_child(_caption)


## Change de scène avec fondu. Fire-and-forget (pas besoin d'await côté appelant).
## v10.15 — caption optionnel : texte bref visible pendant le noir (ex: nom de lieu, ellipse).
func change_scene(path: String, caption: String = "") -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("[MerlinTransition] scène introuvable: %s" % path)
		return
	_busy = true
	_rect.visible = true
	_rect.modulate.a = 0.0
	_caption.text = caption
	_caption.modulate.a = 0.0
	var t_in: Tween = create_tween()
	t_in.tween_property(_rect, "modulate:a", 1.0, DUR).set_trans(Tween.TRANS_SINE)
	await t_in.finished
	var _caption_tw: Tween
	if caption != "":
		_caption_tw = create_tween()
		_caption_tw.tween_property(_caption, "modulate:a", 0.7, 0.18).set_trans(Tween.TRANS_SINE)
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[MerlinTransition] change_scene_to_file err=%d path=%s" % [err, path])
		if _caption_tw != null and _caption_tw.is_valid():
			_caption_tw.kill()
		_caption.modulate.a = 0.0
		_rect.visible = false
		_busy = false
		return
	await get_tree().process_frame  # laisse la nouvelle scène construire son _ready
	_caption.modulate.a = 0.0  # caption disparaît avec le voile
	var t_out: Tween = create_tween()
	t_out.tween_property(_rect, "modulate:a", 0.0, DUR).set_trans(Tween.TRANS_SINE)
	await t_out.finished
	_rect.visible = false
	_busy = false
