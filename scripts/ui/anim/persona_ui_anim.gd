extends RefCounted
class_name PersonaUIAnim
## Persona-style UI animation library — punchy, dynamic, anime-influenced motion.
## All functions return a Tween (caller manages lifetime / await tween.finished).
## Call as static — no instance needed.
##
## Design refs : Persona 5 menu transitions, Sakurai pause screens, Sumire's confidant cards.

# Color palette — bold red/black/cream for energy
const COLOR_INK: Color = Color(0.22, 0.13, 0.07)
const COLOR_BLOOD: Color = Color(0.65, 0.13, 0.10)
const COLOR_CREAM: Color = Color(0.92, 0.83, 0.65)
const COLOR_BLACK: Color = Color(0.06, 0.04, 0.03)


## ENTRY — Slash diagonal entry (top-left → bottom-right). Best on 200x200+ panels.
## Card starts off-screen top-left, rotated +18deg, scale (0.4, 0.6) — flies in with overshoot.
## Returns parallel tween that finishes in ~0.45s.
static func slash_entry(target: Control, screen_size: Vector2) -> Tween:
	var center: Vector2 = (screen_size - target.size) * 0.5
	target.pivot_offset = target.size * 0.5
	target.position = Vector2(-target.size.x - 60.0, -60.0)
	target.scale = Vector2(0.4, 0.6)
	target.rotation = deg_to_rad(18.0)
	target.modulate.a = 0.0
	var t: Tween = target.create_tween().set_parallel(true)
	t.tween_property(target, "position", center, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "scale", Vector2(1.0, 1.0), 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "rotation", 0.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE)
	return t


## EXIT — Slash diagonal exit (opposite of slash_entry). Card flies down-right + tilts.
static func slash_exit(target: Control) -> Tween:
	var t: Tween = target.create_tween().set_parallel(true)
	t.tween_property(target, "position:x", target.position.x + 220.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(target, "position:y", target.position.y + 80.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(target, "rotation", deg_to_rad(-12.0), 0.30).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(target, "scale", Vector2(0.7, 0.7), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(target, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	return t


## PUNCH — Single bouncy emphasis. Scale up overshoot then settle. ~0.30s.
## Use on choice buttons when clicked, or on a stat label that just changed.
static func punch(target: Control, intensity: float = 1.15) -> Tween:
	target.pivot_offset = target.size * 0.5
	var t: Tween = target.create_tween()
	t.tween_property(target, "scale", Vector2(intensity, intensity), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## SHAKE — Camera-style shake on a UI element (rotation + position jitter). ~0.25s.
## Use on critical_failure narration, big damage events.
static func shake(target: Control, magnitude: float = 6.0) -> Tween:
	var orig_pos: Vector2 = target.position
	var t: Tween = target.create_tween()
	for i in 6:
		var ox: float = randf_range(-magnitude, magnitude)
		var oy: float = randf_range(-magnitude, magnitude)
		t.tween_property(target, "position", orig_pos + Vector2(ox, oy), 0.04)
	t.tween_property(target, "position", orig_pos, 0.04)
	return t


## TILT — Persistent slight tilt (anime feel). Returns the tween in case caller wants to stop.
## Apply to background panels, parallax effect.
static func tilt_idle(target: Control, amplitude_deg: float = 1.5, period: float = 4.0) -> Tween:
	target.pivot_offset = target.size * 0.5
	var t: Tween = target.create_tween().set_loops()
	t.tween_property(target, "rotation", deg_to_rad(amplitude_deg), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(target, "rotation", deg_to_rad(-amplitude_deg), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


## COLOR_BURST — Brief bright flash on the target (hue + alpha pulse). ~0.40s.
## Use on critical success: punchy moment, the screen reads "this matters".
static func color_burst(target: Control, burst_color: Color = COLOR_BLOOD) -> Tween:
	var orig: Color = target.modulate
	var t: Tween = target.create_tween()
	t.tween_property(target, "modulate", burst_color, 0.10).set_trans(Tween.TRANS_SINE)
	t.tween_property(target, "modulate", orig, 0.30).set_trans(Tween.TRANS_SINE)
	return t


## TYPEWRITER_PUNCH — Letter-by-letter reveal with each char punching in.
## Replaces stale typewriter; gives a "speech with weight" feel.
## Caller should set the label.text to "" first, then call this with the full text.
static func typewriter_punch(label: Label, full_text: String, char_interval_s: float = 0.025) -> Tween:
	label.text = full_text
	label.visible_characters = 0
	var t: Tween = label.create_tween()
	for i in range(full_text.length() + 1):
		t.tween_callback(_set_visible_chars.bind(label, i))
		t.tween_interval(char_interval_s)
	return t


static func _set_visible_chars(label: Label, n: int) -> void:
	if is_instance_valid(label):
		label.visible_characters = n


## SLIDE_IN_FROM — Slide a Control from a direction with fade. Persona-classic.
## direction: "left", "right", "top", "bottom".
static func slide_in_from(target: Control, direction: String, distance: float = 120.0) -> Tween:
	var orig: Vector2 = target.position
	var offset: Vector2 = Vector2.ZERO
	match direction:
		"left":   offset = Vector2(-distance, 0)
		"right":  offset = Vector2(distance, 0)
		"top":    offset = Vector2(0, -distance)
		"bottom": offset = Vector2(0, distance)
	target.position = orig + offset
	target.modulate.a = 0.0
	var t: Tween = target.create_tween().set_parallel(true)
	t.tween_property(target, "position", orig, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(target, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	return t


## STAGGERED_REVEAL — Apply slide_in_from to a list of children with stagger delay.
## Use on choice button rows: each button slides in 50ms after the previous.
static func staggered_reveal(targets: Array, direction: String = "bottom", stagger_s: float = 0.06) -> void:
	for i in targets.size():
		var node: Control = targets[i] as Control
		if not is_instance_valid(node):
			continue
		var delay: float = float(i) * stagger_s
		if delay > 0.0:
			# Use a one-shot timer to delay the slide
			var orig_y: float = node.position.y
			node.position.y = orig_y + (120.0 if direction == "bottom" else -120.0)
			node.modulate.a = 0.0
			var dt: Tween = node.create_tween()
			dt.tween_interval(delay)
			dt.tween_callback(_run_slide_in.bind(node, direction))
		else:
			slide_in_from(node, direction)


static func _run_slide_in(node: Control, direction: String) -> void:
	if is_instance_valid(node):
		slide_in_from(node, direction)
