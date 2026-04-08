## =============================================================================
## HubAntreTour — Guided tour for first-time players
## =============================================================================
## Extracted from HubAntre.gd. Handles step-by-step tutorial overlay.
## =============================================================================

extends RefCounted
class_name HubAntreTour

const TOUR_STEPS: Array[Dictionary] = [
	{"target": "overview", "text": "Bienvenue dans l'Antre. Ton refuge entre les runs."},
	{"target": "calendar", "text": "Le Calendrier. Saisons et fetes celtiques.", "hotspot_idx": 0},
	{"target": "arbre", "text": "L'Arbre de Vie. Ta progression, run apres run.", "hotspot_idx": 2},
	{"target": "collection", "text": "La Collection. Cartes, Runes, lore — tout ici.", "hotspot_idx": 4},
	{"target": "alignement", "text": "L'Alignement des biomes. Bientot disponible.", "hotspot_idx": 3},
	{"target": "partir", "text": "PARTIR. Choisis un biome et lance l'aventure."},
	{"target": "end", "text": "Tu connais l'essentiel. Le reste se decouvre en marchant."},
]

var _hub: Control


func _init(hub: Control) -> void:
	_hub = hub


func run_tour(hotspots: Array, partir_btn: Button, bubble: Node, chronicle_name: String) -> void:
	if not _hub.is_inside_tree():
		return

	# Wait for entry animation to finish
	await _hub.get_tree().create_timer(1.5).timeout
	if not _hub.is_inside_tree():
		return

	# Disable hotspot interaction during tour
	for hs: Control in hotspots:
		if hs.has_method("set_disabled"):
			hs.set_disabled(true)
		else:
			hs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if partir_btn:
		partir_btn.disabled = true

	# Create highlight overlay
	var highlight := _TourHighlight.new()
	_hub.add_child(highlight)

	for step: Dictionary in TOUR_STEPS:
		if not _hub.is_inside_tree():
			break

		var target_name: String = str(step.get("target", ""))
		var tour_text: String = str(step.get("text", ""))

		# Position highlight on target
		var target_pos: Vector2 = _get_target_pos(step, hotspots, partir_btn)
		if target_name == "overview" or target_name == "end":
			highlight.visible = false
		else:
			highlight.target_pos = target_pos
			highlight.visible = true

		# Show Merlin bubble with tour text
		if bubble and is_instance_valid(bubble):
			bubble.show_message(tour_text, 30.0)

		SFXManager.play("boot_line")

		# Wait for player advance (click/space)
		await _wait_advance()

	# Cleanup
	if is_instance_valid(highlight):
		highlight.queue_free()

	# Re-enable hotspot interaction
	for hs: Control in hotspots:
		if hs.has_method("set_disabled"):
			hs.set_disabled(false)
		else:
			hs.mouse_filter = Control.MOUSE_FILTER_PASS
	if partir_btn:
		partir_btn.disabled = false

	# Clear tour flag
	var gm: Node = _hub.get_node_or_null("/root/GameManager")
	if gm:
		gm.flags["hub_tour_pending"] = false
		gm.flags["hub_tour_done"] = true

	# Show final greeting
	if bubble and is_instance_valid(bubble):
		bubble.show_message("A toi de jouer, %s." % chronicle_name, 4.0)


func _get_target_pos(step: Dictionary, hotspots: Array, partir_btn: Button) -> Vector2:
	var target_name: String = str(step.get("target", ""))
	var vp: Vector2 = _hub.get_viewport_rect().size

	if step.has("hotspot_idx"):
		var idx: int = int(step["hotspot_idx"])
		if idx >= 0 and idx < hotspots.size():
			var hs: Control = hotspots[idx]
			return hs.position + Vector2(32.0, 32.0)

	if target_name == "partir" and partir_btn and is_instance_valid(partir_btn):
		return partir_btn.position + partir_btn.size * 0.5

	return vp * 0.5


func _wait_advance() -> void:
	while _hub.is_inside_tree():
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
		await _hub.get_tree().process_frame
	# Debounce
	if _hub.is_inside_tree():
		await _hub.get_tree().process_frame
		await _hub.get_tree().process_frame


## Inner class: pulsing amber circle highlight overlay
class _TourHighlight extends Control:
	var target_pos: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	const RADIUS := 50.0
	const PULSE_SPEED := 4.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		z_index = 5

	func _process(delta: float) -> void:
		_t += delta * PULSE_SPEED
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 0.12 + sin(_t) * 0.08
		var c: Color = MerlinVisual.CRT_PALETTE["amber"]
		c.a = alpha
		draw_circle(target_pos, RADIUS, c)
		# Inner ring
		var ring_c: Color = MerlinVisual.CRT_PALETTE["amber_bright"]
		ring_c.a = alpha * 1.5
		draw_arc(target_pos, RADIUS * 0.7, 0.0, TAU, 24, ring_c, 1.5)
