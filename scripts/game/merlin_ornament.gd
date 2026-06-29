class_name MerlinOrnament
extends RefCounted
## Ornements DA PARTAGÉS (R125, user 2026-06-29) : filet or, triskèle, diamant, fond scène vivante.
## Source UNIQUE pour que Sélection + Options « ressemblent au menu principal » (mêmes signes visuels).
## Statique : entrée → node, zéro état. Réplique exacte des ornements de merlin_menu.gd.


# Filet fin (liseré brun discret) — comme le wordmark du menu.
static func hline() -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = MerlinVisual.INK_DIM
	r.custom_minimum_size = Vector2(24, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# Filet — triskèle or — filet (signature visuelle du menu). Le triskèle est l'enfant d'index 1 (rotation).
static func triskele_rule(glyph_size: float = 22.0) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(0, glyph_size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hline())
	var g: MerlinGlyph = MerlinGlyph.new()
	g.custom_minimum_size = Vector2(glyph_size, glyph_size)
	g.pivot_offset = Vector2(glyph_size * 0.5, glyph_size * 0.5)
	g.setup("triskele", MerlinVisual.GOLD, 1.6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(g)
	box.add_child(hline())
	return box


# Lance la rotation lente du triskèle d'un triskele_rule (juice — comme le menu). No-op en reduced_motion.
static func spin_triskele(rule: HBoxContainer, period: float = 36.0) -> void:
	if rule == null or rule.get_child_count() < 2 or MerlinVisual.reduced_motion:
		return
	var g: Control = rule.get_child(1)
	var tw: Tween = g.create_tween().set_loops()
	tw.tween_property(g, "rotation", TAU, period).from(0.0)


# Petit diamant or (tête/fin d'élément, comme les lignes de menu).
static func diamond(col: Color = MerlinVisual.INK_DIM) -> Panel:
	var d: Panel = Panel.new()
	d.custom_minimum_size = Vector2(8, 8)
	d.size = Vector2(8, 8)
	d.pivot_offset = Vector2(4, 4)
	d.rotation = deg_to_rad(45)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	d.add_theme_stylebox_override("panel", sb)
	return d


# Fond SCÈNE VIVANTE (dimmé) pour les écrans secondaires → même monde que le menu (saison + heure réelles).
static func scene_backdrop(dim: float = 0.42) -> MerlinSceneArt:
	var art: MerlinSceneArt = MerlinSceneArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate.a = dim
	art.set_menu_decor(true)
	art.set_beat("Rencontre")
	art.set_season(MerlinSceneArt.season_for_now())
	var hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	art.set_time_of_day(hour)
	art.set_animated(true)
	return art
