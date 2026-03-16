## ═══════════════════════════════════════════════════════════════════════════════
## UI Card Display Module — Card panel, 3D tilt, float, entry/exit, shadows
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles card rendering, stacking,
## fake 3D perspective tilt, float motion, and pixel entry/exit animations.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UICardDisplay

var _ui: MerlinGameUI

# Card stacking
var _card_shadows: Array[Panel] = []
const MAX_CARD_SHADOWS := 3

# Fake 3D card tilt
var _card_hovered: bool = false
var _card_tilt_target: Vector2 = Vector2.ZERO
var _card_tilt_current: Vector2 = Vector2.ZERO
var _card_3d_shine: ColorRect
var _card_3d_active: bool = false


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


# ═══════════════════════════════════════════════════════════════════════════════
# FAKE 3D CARD TILT
# ═══════════════════════════════════════════════════════════════════════════════

func setup_card_3d() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	_ui.card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_3d_shine = ColorRect.new()
	_card_3d_shine.name = "Card3DShine"
	_card_3d_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_3d_shine.color = Color(1.0, 1.0, 1.0, 0.0)
	_card_3d_shine.z_index = 6
	_card_3d_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.card_panel.add_child(_card_3d_shine)


func update_card_3d_tilt(delta: float) -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	if not _card_3d_active:
		if _card_tilt_current.length() > 0.001:
			_card_tilt_current = _card_tilt_current.lerp(Vector2.ZERO, delta * MerlinVisual.CARD_3D_TILT_SPEED)
			_apply_card_3d_transform()
		return

	var is_hovering: bool = false
	if _ui.card_container and is_instance_valid(_ui.card_container):
		var mouse_global: Vector2 = _ui.get_global_mouse_position()
		is_hovering = _ui.card_container.get_global_rect().has_point(mouse_global)
	_card_hovered = is_hovering

	if _card_hovered:
		var mouse_pos: Vector2 = _ui.card_panel.get_local_mouse_position()
		var card_size: Vector2 = _ui.card_panel.size
		if card_size.x > 10.0 and card_size.y > 10.0:
			var normalized: Vector2 = Vector2(
				clampf((mouse_pos.x / card_size.x - 0.5) * 2.0, -1.0, 1.0),
				clampf((mouse_pos.y / card_size.y - 0.5) * 2.0, -1.0, 1.0)
			)
			_card_tilt_target = normalized
	else:
		_card_tilt_target = Vector2.ZERO

	_card_tilt_current = _card_tilt_current.lerp(_card_tilt_target, delta * MerlinVisual.CARD_3D_TILT_SPEED)
	_apply_card_3d_transform()


func _apply_card_3d_transform() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	var tilt: Vector2 = _card_tilt_current
	var rotation_deg: float = tilt.x * MerlinVisual.CARD_3D_TILT_MAX
	_ui.card_panel.rotation_degrees = rotation_deg

	var hover_factor: float = clampf(tilt.length(), 0.0, 1.0)
	var base_scale: float = lerpf(1.0, MerlinVisual.CARD_3D_SCALE_HOVER, hover_factor)
	var scale_x: float = base_scale + tilt.y * 0.012
	var scale_y: float = base_scale - tilt.y * 0.008
	_ui.card_panel.scale = Vector2(scale_x, scale_y)

	var panel_style: StyleBox = _ui.card_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		var base_offset: Vector2 = Vector2(2.0, 4.0)
		var tilt_shift: Vector2 = Vector2(-tilt.x, -tilt.y) * MerlinVisual.CARD_3D_SHADOW_SHIFT
		panel_style.shadow_offset = base_offset + tilt_shift

	if _card_3d_shine and is_instance_valid(_card_3d_shine):
		var shine_alpha: float = hover_factor * MerlinVisual.CARD_3D_SHINE_ALPHA
		_card_3d_shine.color = Color(1.0, 1.0, 1.0, shine_alpha)
		var shine_margin_x: float = tilt.x * 20.0
		var shine_margin_y: float = tilt.y * 15.0
		_card_3d_shine.position = Vector2(shine_margin_x, shine_margin_y)

	if _ui._scene_compositor_v2 and is_instance_valid(_ui._scene_compositor_v2):
		_ui._scene_compositor_v2.apply_parallax(tilt)


func enable_card_3d() -> void:
	_card_3d_active = true
	_card_tilt_current = Vector2.ZERO
	_card_tilt_target = Vector2.ZERO


func disable_card_3d() -> void:
	_card_3d_active = false
	_card_tilt_target = Vector2.ZERO


func card_panel_safe_reset_transform() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	disable_card_3d()
	_ui.card_panel.scale = Vector2.ONE
	_ui.card_panel.rotation_degrees = 0.0
	_ui.card_panel.position = _ui._card_base_pos


# ═══════════════════════════════════════════════════════════════════════════════
# CARD FLOAT MOTION
# ═══════════════════════════════════════════════════════════════════════════════

func start_card_float_motion() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return
	if _ui._card_float_tween:
		_ui._card_float_tween.kill()
	_ui.card_panel.position = _ui._card_base_pos
	_ui._card_float_tween = _ui.create_tween().set_loops()
	_ui._card_float_tween.tween_property(_ui.card_panel, "position:y", _ui._card_base_pos.y - MerlinVisual.CARD_FLOAT_OFFSET, MerlinVisual.CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ui._card_float_tween.tween_property(_ui.card_panel, "position:y", _ui._card_base_pos.y + MerlinVisual.CARD_FLOAT_OFFSET * 0.6, MerlinVisual.CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func start_card_float_and_3d() -> void:
	start_card_float_motion()
	enable_card_3d()


# ═══════════════════════════════════════════════════════════════════════════════
# CARD STACKING — Shadow cards pile up behind the active card
# ═══════════════════════════════════════════════════════════════════════════════

func push_card_shadow() -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel) or not _ui.card_container:
		return
	if _card_shadows.size() >= MAX_CARD_SHADOWS:
		var oldest: Panel = _card_shadows.pop_front()
		if is_instance_valid(oldest):
			var fade_tw: Tween = _ui.create_tween()
			fade_tw.tween_property(oldest, "modulate:a", 0.0, 0.2)
			fade_tw.tween_callback(oldest.queue_free)

	var shadow: Panel = Panel.new()
	shadow.custom_minimum_size = _ui.card_panel.custom_minimum_size
	shadow.size = _ui.card_panel.size
	shadow.position = _ui.card_panel.position + Vector2(2, 2) * float(_card_shadows.size() + 1)
	shadow.modulate.a = maxf(0.06, 0.18 - 0.04 * float(_card_shadows.size()))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_style: StyleBox = _ui.card_panel.get_theme_stylebox("panel")
	if base_style:
		var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
		if style:
			style.bg_color = style.bg_color.darkened(0.15)
			shadow.add_theme_stylebox_override("panel", style)

	_ui.card_container.add_child(shadow)
	_ui.card_container.move_child(shadow, 0)
	_card_shadows.append(shadow)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD VISUAL & AUDIO TAGS (P1.9) — Ambient FX driven by LLM tags
# ═══════════════════════════════════════════════════════════════════════════════

const AUDIO_TAG_SOUNDS: Dictionary = {
	"danger": "critical_alert",
	"combat": "dice_shake",
	"magie": "magic_reveal",
	"sacre": "ogham_chime",
	"mystere": "mist_breath",
	"brume": "mist_breath",
	"orage": "flash_boom",
	"feu": "flash_boom",
	"soin": "magic_reveal",
	"ogham": "ogham_chime",
	"nuit": "mist_breath",
}

var _visual_tag_tints: Dictionary = {}
var _card_visual_tween: Tween = null


func _get_visual_tag_tints() -> Dictionary:
	if _visual_tag_tints.is_empty():
		_visual_tag_tints = MerlinVisual.VISUAL_TAG_TINTS
	return _visual_tag_tints


func apply_card_visual_tags(card: Dictionary) -> void:
	if not _ui.card_panel or not is_instance_valid(_ui.card_panel):
		return

	var vtags: Array = card.get("visual_tags", [])
	var tags: Array = card.get("tags", [])
	var all_tags: Array = vtags + tags

	var tint: Color = Color.WHITE
	var has_danger: bool = false
	for tag in all_tags:
		var tag_str: String = str(tag).to_lower()
		var tag_tints: Dictionary = _get_visual_tag_tints()
		if tag_tints.has(tag_str):
			tint = tag_tints[tag_str]
		if tag_str == "danger" or tag_str == "combat" or tag_str == "mort":
			has_danger = true

	if _card_visual_tween and _card_visual_tween.is_valid():
		_card_visual_tween.kill()

	if tint != Color.WHITE:
		_card_visual_tween = _ui.create_tween()
		_card_visual_tween.tween_property(_ui.card_panel, "self_modulate", tint, 0.6)
		if has_danger:
			var dim_tint: Color = tint.darkened(0.1)
			_card_visual_tween.set_loops(0)
			_card_visual_tween.tween_property(_ui.card_panel, "self_modulate", dim_tint, 1.2)
			_card_visual_tween.tween_property(_ui.card_panel, "self_modulate", tint, 1.2)
	else:
		_ui.card_panel.self_modulate = Color.WHITE


func apply_card_audio_tags(card: Dictionary) -> void:
	var atags: Array = card.get("audio_tags", [])
	var vtags: Array = card.get("visual_tags", [])
	var all_tags: Array = atags + vtags

	for tag in all_tags:
		var tag_str: String = str(tag).to_lower()
		if AUDIO_TAG_SOUNDS.has(tag_str):
			var sound_name: String = AUDIO_TAG_SOUNDS[tag_str]
			_ui.get_tree().create_timer(0.4).timeout.connect(
				func() -> void: SFXManager.play_varied(sound_name, 0.15),
				CONNECT_ONE_SHOT
			)
			return


func derive_card_fallback_tags(card: Dictionary) -> Array:
	var biome: String = str(card.get("biome", "foret_broceliande"))
	var base: Array = PixelSceneData.BIOME_DEFAULT_TAGS.get(biome, ["foret", "arbres"])
	var result: Array = base.duplicate()
	var tags: Array = card.get("tags", [])
	for tag in tags:
		var modifier_tags: Array = PixelSceneData.MODIFIER_TAGS.get(str(tag), [])
		for mt in modifier_tags:
			if mt not in result:
				result.append(mt)
	return result


func detect_card_source(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if "llm_generated" in tags:
		return "llm"
	if "emergency_fallback" in tags:
		return "fallback"
	var gen_by: String = str(card.get("_generated_by", ""))
	if gen_by.contains("llm"):
		return "llm"
	if gen_by != "":
		return "llm"
	if card.has("_omniscient"):
		return "llm"
	return "fallback"


# ═══════════════════════════════════════════════════════════════════════════════
# CELTIC ANIMAL DRAWING
# ═══════════════════════════════════════════════════════════════════════════════

func draw_animal(ctrl: Control, animal: String, color: Color) -> void:
	var sz: Vector2 = ctrl.size
	var cx: float = sz.x * 0.5
	var cy: float = sz.y * 0.5
	var r: float = mini(int(sz.x), int(sz.y)) * 0.4

	match animal:
		"sanglier":
			_draw_sanglier(ctrl, cx, cy, r, color)
		"corbeau":
			_draw_corbeau(ctrl, cx, cy, r, color)
		"cerf":
			_draw_cerf(ctrl, cx, cy, r, color)
		_:
			ctrl.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, color, 2.0)


func _draw_sanglier(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	var body: PackedVector2Array = PackedVector2Array()
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	body.append(Vector2(cx - r * 0.7, cy - r * 0.5))
	body.append(Vector2(cx - r * 0.2, cy - r * 0.7))
	body.append(Vector2(cx + r * 0.3, cy - r * 0.6))
	body.append(Vector2(cx + r * 0.8, cy - r * 0.3))
	body.append(Vector2(cx + r * 1.0, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.3, cy + r * 0.7))
	body.append(Vector2(cx - r * 0.4, cy + r * 0.6))
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	ctrl.draw_polyline(body, color, 2.0, true)
	ctrl.draw_line(Vector2(cx + r * 0.85, cy - r * 0.1), Vector2(cx + r * 1.1, cy - r * 0.5), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 0.85, cy + r * 0.0), Vector2(cx + r * 1.1, cy + r * 0.1), color, 1.5)
	ctrl.draw_circle(Vector2(cx + r * 0.5, cy - r * 0.2), r * 0.12, color)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.6), Vector2(cx - r * 0.5, cy + r * 1.0), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy + r * 0.65), Vector2(cx + r * 0.4, cy + r * 1.0), color, 1.5)


func _draw_corbeau(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	var body: PackedVector2Array = PackedVector2Array()
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.5, cy - r * 0.3))
	body.append(Vector2(cx + r * 0.1, cy - r * 0.2))
	body.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	body.append(Vector2(cx - r * 0.5, cy + r * 0.4))
	body.append(Vector2(cx + r * 0.2, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	ctrl.draw_polyline(body, color, 2.0, true)
	ctrl.draw_line(Vector2(cx + r * 0.8, cy + r * 0.1), Vector2(cx + r * 1.2, cy - r * 0.05), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 1.2, cy - r * 0.05), Vector2(cx + r * 0.8, cy + r * 0.2), color, 1.5)
	ctrl.draw_circle(Vector2(cx + r * 0.55, cy - r * 0.1), r * 0.1, color)
	var wing: PackedVector2Array = PackedVector2Array()
	wing.append(Vector2(cx - r * 0.1, cy - r * 0.1))
	wing.append(Vector2(cx - r * 0.7, cy - r * 0.8))
	wing.append(Vector2(cx - r * 1.0, cy - r * 0.5))
	wing.append(Vector2(cx - r * 0.8, cy - r * 0.2))
	wing.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	ctrl.draw_polyline(wing, color, 1.5, true)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.9, cy + r * 0.7), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.7, cy + r * 0.8), color, 1.5)


func _draw_cerf(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	var head: PackedVector2Array = PackedVector2Array()
	head.append(Vector2(cx, cy + r * 0.8))
	head.append(Vector2(cx - r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx - r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx, cy - r * 0.4))
	head.append(Vector2(cx + r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx + r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx, cy + r * 0.8))
	ctrl.draw_polyline(head, color, 2.0, true)
	ctrl.draw_circle(Vector2(cx, cy), r * 0.1, color)
	ctrl.draw_line(Vector2(cx - r * 0.25, cy - r * 0.2), Vector2(cx - r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.4, cy - r * 0.5), Vector2(cx - r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.55, cy - r * 0.7), Vector2(cx - r * 0.9, cy - r * 0.9), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.25, cy - r * 0.2), Vector2(cx + r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy - r * 0.5), Vector2(cx + r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.55, cy - r * 0.7), Vector2(cx + r * 0.9, cy - r * 0.9), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.2, cy - r * 0.3), Vector2(cx - r * 0.35, cy - r * 0.45), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.2, cy - r * 0.3), Vector2(cx + r * 0.35, cy - r * 0.45), color, 1.5)
