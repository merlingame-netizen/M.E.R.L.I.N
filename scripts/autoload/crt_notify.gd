## CRTNotify — Terminal-style notification toasts (autoload: Notify)
## Shows brief CRT-styled event toasts during gameplay.
## Usage:
##   Notify.show("DRUIDES +5", "reputation")
##   Notify.life_changed(-1)
##   Notify.reputation("druides", 5)
##   Notify.ogham_activated("beith")

extends CanvasLayer
class_name CRTNotify

const MAX_VISIBLE: int = 4
const TOAST_DURATION: float = 2.5
const FADE_IN_DURATION: float = 0.25
const FADE_OUT_DURATION: float = 0.4
const SLIDE_OFFSET: float = 120.0
const TOAST_HEIGHT: int = 36
const TOAST_SPACING: int = 6
const TOAST_MARGIN_RIGHT: int = 16
const TOAST_MARGIN_TOP: int = 64

const CATEGORY_ICONS: Dictionary = {
	"life_up": "\u2665",
	"life_down": "\u2665",
	"reputation": "\u2726",
	"ogham": "\u25C6",
	"promise": "\u2234",
	"success": "\u2713",
	"fail": "\u2717",
	"info": "\u25B8",
	"danger": "\u26A0",
	"currency": "\u2756",
	"unlock": "\u2605",
}

var _container: VBoxContainer
var _active_toasts: Array[Control] = []
var _queue: Array[Dictionary] = []
var _is_processing: bool = false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS

	var anchor: Control = Control.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.anchor_left = 0.65
	anchor.anchor_right = 1.0
	anchor.anchor_top = 0.0
	anchor.anchor_bottom = 1.0
	anchor.offset_right = -TOAST_MARGIN_RIGHT
	anchor.offset_top = TOAST_MARGIN_TOP
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_container.anchor_left = 0.0
	_container.anchor_right = 1.0
	_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_container.add_theme_constant_override("separation", TOAST_SPACING)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(_container)


func show(text: String, category: String = "info") -> void:
	_queue.append({"text": text, "category": category})
	if not _is_processing:
		_process_queue()


func life_changed(delta: int) -> void:
	if delta == 0:
		return
	var cat: String = "life_up" if delta > 0 else "life_down"
	var sign: String = "+" if delta > 0 else ""
	show("VIE %s%d" % [sign, delta], cat)


func reputation(faction: String, delta: int) -> void:
	if delta == 0:
		return
	var sign: String = "+" if delta > 0 else ""
	show("%s %s%d" % [faction.to_upper(), sign, delta], "reputation")


func ogham_activated(ogham_id: String) -> void:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	var name: String = str(spec.get("name", ogham_id))
	var sym: String = str(spec.get("unicode", "\u25C6"))
	show("RUNE %s %s" % [sym, name], "ogham")


func promise_event(text: String, kept: bool) -> void:
	var cat: String = "success" if kept else "danger"
	show(text, cat)


func currency_changed(delta: int, currency_name: String = "monnaie") -> void:
	if delta == 0:
		return
	var sign: String = "+" if delta > 0 else ""
	show("%s %s%d" % [currency_name.to_upper(), sign, delta], "currency")


func minigame_result(score: int) -> void:
	if score >= 80:
		show("REUSSITE  %d/100" % score, "success")
	elif score >= 50:
		show("PARTIEL  %d/100" % score, "info")
	else:
		show("ECHEC  %d/100" % score, "fail")


func unlock(text: String) -> void:
	show(text, "unlock")


func _process_queue() -> void:
	_is_processing = true
	while not _queue.is_empty():
		if _active_toasts.size() >= MAX_VISIBLE:
			_dismiss_oldest()
			await get_tree().create_timer(0.1).timeout
		var item: Dictionary = _queue.pop_front()
		_spawn_toast(item.text, item.category)
		await get_tree().create_timer(0.08).timeout
	_is_processing = false


func _spawn_toast(text: String, category: String) -> void:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	var color: Color = _get_category_color(category)
	var icon: String = CATEGORY_ICONS.get(category, "\u25B8")

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(pal.bg_dark.r, pal.bg_dark.g, pal.bg_dark.b, 0.88)
	style.border_color = Color(color.r, color.g, color.b, 0.5)
	style.border_width_left = 3
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	var icon_label: Label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_color_override("font_color", color)
	icon_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(14))
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		icon_label.add_theme_font_override("font", font)
	hbox.add_child(icon_label)

	var text_label: Label = Label.new()
	text_label.text = text
	text_label.add_theme_color_override("font_color", color)
	text_label.add_theme_font_size_override("font_size", MerlinVisual.responsive_size(13))
	if font:
		text_label.add_theme_font_override("font", font)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_label)

	panel.modulate.a = 0.0
	panel.position.x = SLIDE_OFFSET
	_container.add_child(panel)
	_active_toasts.append(panel)

	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, FADE_IN_DURATION)
	tw.tween_property(panel, "position:x", 0.0, FADE_IN_DURATION)

	if is_instance_valid(SFXManager):
		match category:
			"life_down", "fail", "danger":
				SFXManager.play("click")
			"success", "unlock":
				SFXManager.play("boot_confirm")
			"ogham":
				SFXManager.play("ogham_chime")
			_:
				SFXManager.play("boot_line")

	_schedule_dismiss(panel)


func _schedule_dismiss(panel: PanelContainer) -> void:
	await get_tree().create_timer(TOAST_DURATION).timeout
	if is_instance_valid(panel) and panel.is_inside_tree():
		_dismiss_toast(panel)


func _dismiss_toast(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	_active_toasts.erase(panel)
	var tw: Tween = create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 0.0, FADE_OUT_DURATION)
	tw.tween_property(panel, "position:x", -40.0, FADE_OUT_DURATION)
	tw.chain().tween_callback(panel.queue_free)


func _dismiss_oldest() -> void:
	if _active_toasts.is_empty():
		return
	_dismiss_toast(_active_toasts[0])


func _get_category_color(category: String) -> Color:
	var pal: Dictionary = MerlinVisual.CRT_PALETTE
	match category:
		"life_up":
			return pal.success
		"life_down":
			return pal.danger
		"reputation":
			return pal.amber
		"ogham":
			return pal.cyan_bright
		"promise":
			return pal.amber_bright
		"success":
			return pal.phosphor_bright
		"fail":
			return pal.danger
		"danger":
			return pal.danger
		"currency":
			return pal.amber
		"unlock":
			return pal.cyan_bright
		_:
			return pal.phosphor_dim
