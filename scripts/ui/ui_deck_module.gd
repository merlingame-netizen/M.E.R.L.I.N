## ═══════════════════════════════════════════════════════════════════════════════
## UI Deck Module — Remaining deck + discard pile visuals
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_ui.gd — handles deck stack, discard stack,
## visual updates, and draw animation.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name UIDeckModule

var _ui: MerlinGameUI

const LIVE_DECK_VISIBLE_COUNT := 5
const DISCARD_VISIBLE_COUNT := 5
const RUN_DECK_ESTIMATE := 24

var _remaining_deck_cards: Array[Panel] = []
var _remaining_deck_estimate: int = RUN_DECK_ESTIMATE
var _discard_cards: Array[Panel] = []
var _discard_total: int = 0


func initialize(ui: MerlinGameUI) -> void:
	_ui = ui


func build_remaining_deck_stack() -> void:
	if not _ui._remaining_deck_root or not is_instance_valid(_ui._remaining_deck_root):
		return
	for child in _ui._remaining_deck_root.get_children():
		child.queue_free()
	_remaining_deck_cards.clear()

	for i in range(LIVE_DECK_VISIBLE_COUNT):
		var deck_card: Panel = Panel.new()
		deck_card.size = Vector2(78, 106)
		deck_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_card.modulate.a = 0.95 - float(i) * 0.1
		deck_card.pivot_offset = deck_card.size * 0.5
		var deck_style: StyleBoxFlat = StyleBoxFlat.new()
		var ink_deck: Color = MerlinVisual.CRT_PALETTE.phosphor
		deck_style.bg_color = Color(ink_deck.r, ink_deck.g, ink_deck.b, 0.96)
		var border_col: Color = MerlinVisual.CRT_PALETTE.get("green", Color(0.6, 0.8, 0.5))
		deck_style.border_color = Color(border_col.r, border_col.g, border_col.b, 0.72)
		deck_style.set_border_width_all(2)
		deck_style.set_corner_radius_all(7)
		deck_style.shadow_color = Color(0, 0, 0, 0.3)
		deck_style.shadow_size = 6
		deck_style.shadow_offset = Vector2(0, 2)
		deck_card.add_theme_stylebox_override("panel", deck_style)
		_ui._remaining_deck_root.add_child(deck_card)
		_remaining_deck_cards.append(deck_card)

	update_remaining_deck_visual()


func update_remaining_deck_visual() -> void:
	if _remaining_deck_cards.is_empty():
		return
	var visible_count: int = clampi(_remaining_deck_estimate, 0, LIVE_DECK_VISIBLE_COUNT)
	for i in range(_remaining_deck_cards.size()):
		var card: Panel = _remaining_deck_cards[i]
		if not card or not is_instance_valid(card):
			continue
		card.position = Vector2(12.0 + float(i) * 2.0, 10.0 + float(i) * 3.0)
		card.rotation_degrees = -2.0 + float(i) * 1.2
		card.scale = Vector2(1.0, 1.0)
		card.modulate.a = clampf(0.92 - float(i) * 0.12, 0.18, 1.0) if i < visible_count else 0.0

	if _ui._remaining_deck_label and is_instance_valid(_ui._remaining_deck_label):
		_ui._remaining_deck_label.text = "%d" % maxi(_remaining_deck_estimate, 0)


func build_discard_stack() -> void:
	if not _ui._discard_root or not is_instance_valid(_ui._discard_root):
		return
	for child in _ui._discard_root.get_children():
		child.queue_free()
	_discard_cards.clear()

	for i in range(DISCARD_VISIBLE_COUNT):
		var discard_card: Panel = Panel.new()
		discard_card.size = Vector2(62, 86)
		discard_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		discard_card.pivot_offset = discard_card.size * 0.5
		discard_card.add_theme_stylebox_override("panel", MerlinVisual.make_discard_card_style())
		_ui._discard_root.add_child(discard_card)
		_discard_cards.append(discard_card)

	update_discard_visual()


func update_discard_visual() -> void:
	if _discard_cards.is_empty():
		return
	var visible_count: int = clampi(_discard_total, 0, DISCARD_VISIBLE_COUNT)
	for i in range(_discard_cards.size()):
		var card: Panel = _discard_cards[i]
		if not card or not is_instance_valid(card):
			continue
		card.position = Vector2(10.0 + float(i) * 2.0, 8.0 + float(i) * 3.0)
		card.rotation_degrees = 1.8 + float(i) * 1.0
		card.modulate.a = clampf(0.86 - float(i) * 0.14, 0.18, 1.0) if i < visible_count else 0.08
	if _ui._discard_label and is_instance_valid(_ui._discard_label):
		_ui._discard_label.text = "%d" % maxi(_discard_total, 0)


func reset_run_visuals() -> void:
	_remaining_deck_estimate = RUN_DECK_ESTIMATE
	_discard_total = 0
	update_remaining_deck_visual()
	update_discard_visual()


func animate_remaining_deck_draw() -> void:
	if _remaining_deck_cards.is_empty():
		return
	var top_card: Panel = _remaining_deck_cards.pop_front()
	if not top_card or not is_instance_valid(top_card):
		return
	_remaining_deck_cards.append(top_card)
	update_remaining_deck_visual()


func increment_discard() -> void:
	_discard_total += 1
	update_discard_visual()


func update_cards_count(count: int) -> void:
	_remaining_deck_estimate = maxi(RUN_DECK_ESTIMATE - maxi(count, 0), 0)
	update_remaining_deck_visual()
