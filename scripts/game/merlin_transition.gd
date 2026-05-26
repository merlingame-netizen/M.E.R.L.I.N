extends CanvasLayer
## MerlinTransition — fondu au noir entre scènes (autoload). Remplace les change_scene_to_file
## directs (coupures sèches) par : fondu vers le noir → changement → fondu depuis le noir.
## Non bloquant, court (≤ ~220ms par sens). Au-dessus de tout (layer 200).

const DUR: float = 0.22
const COL_FADE: Color = Color(0.02, 0.02, 0.03, 1.0)

var _rect: ColorRect
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


## Change de scène avec fondu. Fire-and-forget (pas besoin d'await côté appelant).
func change_scene(path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(path):
		push_error("[MerlinTransition] scène introuvable: %s" % path)
		return
	_busy = true
	_rect.visible = true
	_rect.modulate.a = 0.0
	var t_in: Tween = create_tween()
	t_in.tween_property(_rect, "modulate:a", 1.0, DUR).set_trans(Tween.TRANS_SINE)
	await t_in.finished
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		# Échec de chargement : on ne reste PAS coincé en noir/_busy (sinon plus aucune navigation).
		push_error("[MerlinTransition] change_scene_to_file err=%d path=%s" % [err, path])
		_rect.visible = false
		_busy = false
		return
	await get_tree().process_frame  # laisse la nouvelle scène construire son _ready
	var t_out: Tween = create_tween()
	t_out.tween_property(_rect, "modulate:a", 0.0, DUR).set_trans(Tween.TRANS_SINE)
	await t_out.finished
	_rect.visible = false
	_busy = false
