class_name MerlinMenuFx
extends RefCounted
## v10.18 — Recettes d'animation du menu (Phase 2), SANS ÉTAT, routées via MerlinTween + MerlinVisual.
## DA « atmosphérique discret » : faibles amplitudes, durées lentes, respect strict de reduced_motion.
## Garde merlin_menu.gd mince : ici les recettes de dessin/tween, là-bas l'orchestration + l'état des rangées.

const GOLD: Color = MerlinVisual.GOLD
const CREAM: Color = MerlinVisual.CREAM


## Halo doux derrière le disque d'icône (fade in/out au focus).
static func focus_halo(halo: CanvasItem, on: bool) -> void:
	if halo == null:
		return
	var target: float = 0.0
	if on and not MerlinVisual.reduced_motion:
		target = 0.55
	var tw: Tween = MerlinTween.retween(halo, "halo")
	tw.tween_property(halo, "modulate:a", target, MerlinVisual.DUR_FAST * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)


## Lumière discrète qui parcourt le trait connecteur (gauche → droite) au focus.
static func connector_charge(line: ColorRect) -> void:
	if line == null or MerlinVisual.reduced_motion:
		return
	var w: float = line.size.x
	if w < 8.0:
		return
	var spark: ColorRect = ColorRect.new()
	spark.color = Color(CREAM.r, CREAM.g, CREAM.b, 0.9)
	spark.size = Vector2(14.0, maxf(line.size.y, 1.0))
	spark.position = Vector2.ZERO
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(spark)
	var tw: Tween = spark.create_tween().set_parallel(true)
	tw.tween_property(spark, "position:x", w - 14.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(spark, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(spark.queue_free)


## Confirmation de sélection (DOUCE) : anneau qui s'évase depuis le disque + pop bref + flash du label.
static func confirm(lbl: Label, icon_box: Control) -> void:
	if icon_box != null:
		_ripple_ring(icon_box)
		var tp: Tween = MerlinTween.retween(icon_box, "confirm_pop")
		icon_box.scale = Vector2.ONE
		tp.tween_property(icon_box, "scale", Vector2(1.16, 1.16), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tp.tween_property(icon_box, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	if lbl != null:
		var tl: Tween = MerlinTween.retween(lbl, "confirm")
		tl.tween_property(lbl, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.06)
		tl.tween_property(lbl, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_SINE)


static func _ripple_ring(anchor: Control) -> void:
	var ring: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.6)
	sb.set_corner_radius_all(40)
	ring.add_theme_stylebox_override("panel", sb)
	ring.size = Vector2(52, 52)
	ring.pivot_offset = Vector2(26, 26)
	ring.position = Vector2.ZERO
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(ring)
	var s: float = 1.4 if MerlinVisual.reduced_motion else 2.6
	var tw: Tween = ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(s, s), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(ring.queue_free)


## Comète de navigation : faible traînée dorée glissant de l'ancienne à la nouvelle rangée.
static func comet(from_box: Control, to_box: Control, parent: Control) -> void:
	if from_box == null or to_box == null or parent == null or MerlinVisual.reduced_motion:
		return
	var a: Vector2 = from_box.get_global_rect().get_center()
	var b: Vector2 = to_box.get_global_rect().get_center()
	if a.distance_to(b) < 4.0:
		return
	var dot: ColorRect = ColorRect.new()
	dot.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.7)
	dot.size = Vector2(10, 4)
	dot.pivot_offset = Vector2(5, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dot)
	dot.global_position = a - Vector2(5, 2)
	var tw: Tween = dot.create_tween().set_parallel(true)
	tw.tween_property(dot, "global_position", b - Vector2(5, 2), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(dot, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(dot.queue_free)


## Invitation idle : léger souffle one-shot sur la 1re rangée active.
static func attention_nudge(box: Control) -> void:
	if box == null or MerlinVisual.reduced_motion:
		return
	var tw: Tween = MerlinTween.retween(box, "nudge")
	box.scale = Vector2.ONE
	tw.tween_property(box, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(box, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## Shimmer « verrouillé » très ténu sur le disque d'une rangée désactivée (boucle).
static func locked_shimmer(disc: CanvasItem) -> void:
	if disc == null or MerlinVisual.reduced_motion:
		return
	var tw: Tween = MerlinTween.retween_looping(disc, "shimmer")
	tw.tween_interval(2.0)
	tw.tween_property(disc, "modulate:a", 0.45, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(disc, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
