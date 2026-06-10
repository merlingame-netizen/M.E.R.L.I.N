class_name MerlinFx
extends Control
## v10.13 (A2) — Animation cinématique de fusion (extraite VERBATIM de merlin_game.gd, v10.2→v10.13).
## MerlinFx EST le layer overlay : il s'ajoute au host (plein écran, absorbe les clics), anime les
## 4 phases (Gather → Fuse → Burst → Expression) + le SUSTAIN skippable, puis se queue_free().
## Correction « tweens orphelins » PAR CONSTRUCTION : tout tween interne est créé sur CE node
## (create_tween() d'un Control = tween lié au node) → la mort du layer emporte ses animations.
## Découplage LLM : le sustain ne lit PLUS /root/MerlinScenario — prédicat `ready` injecté (Callable).
## Les card views du combo sont passées par l'appelant et reparentées DANS le layer (free'd avec lui).
##
## Usage (merlin_game._on_resolve / debug F12) :
##   var fx: MerlinFx = MerlinFx.play(self, res, played_cards, vues_du_combo, ready_pred)
##   await fx.run()

# Avant la prose de résolution, les cartes du combo se rassemblent au centre, fusionnent dans un
# glow coloré par degré, éclatent en sparks, et révèlent une "expression" — la synthèse verbale
# de la combinaison. Puis fondu vers la résolution textuelle existante. Awaitable, ~2.5s total.

const FUSION_COLORS: Dictionary = {
	"echec": Color("D04848"),       # rouge-violet vif (chute, malédiction)
	"partiel": Color("D8A030"),     # ambre (effort à demi tenu)
	"reussite": Color("E8C45A"),    # or chaud (geste accompli)
	"eclatante": Color("F4E0A8"),   # or pâle / blanc-or (apothéose)
}

# v10.3 — Amplification dramatique par degré (user 2026-06-06 AskUserQuestion).
# Durées par phase (s) — échec court & mat, éclatante long & ample.
const FUSION_DURATIONS: Dictionary = {
	"echec":     {"gather": 0.30, "fuse": 0.45, "burst": 0.50, "expr": 0.75},
	"partiel":   {"gather": 0.40, "fuse": 0.55, "burst": 0.65, "expr": 1.40},
	"reussite":  {"gather": 0.50, "fuse": 0.70, "burst": 0.80, "expr": 1.50},
	"eclatante": {"gather": 0.60, "fuse": 0.85, "burst": 1.10, "expr": 1.95},
}
const FUSION_SHAKE_PX: Dictionary = {"echec": 4.0, "partiel": 8.0, "reussite": 12.0, "eclatante": 20.0}
const FUSION_ZOOM: Dictionary = {"echec": 1.04, "partiel": 1.06, "reussite": 1.08, "eclatante": 1.12}
const FUSION_VIGNETTE_A: Dictionary = {"echec": 0.60, "partiel": 0.42, "reussite": 0.36, "eclatante": 0.55}
const FUSION_CA_OFFSET: Dictionary = {"echec": 1.5, "partiel": 2.0, "reussite": 2.5, "eclatante": 4.0}
const FUSION_SPARK_COUNT: Dictionary = {"echec": 18, "partiel": 24, "reussite": 30, "eclatante": 42}

# Vignette via shader canvas_item : sombre les coins selon `intensity`, teinte `tint` (selon degré).
const VIGNETTE_SHADER_CODE: String = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv) * 1.41421;  // 0 au centre, 1 aux coins (sqrt(2)/2 normalisé)
	float v = smoothstep(0.28, 1.0, d) * intensity;
	COLOR = vec4(tint.rgb, v * tint.a);
}
"""

# Cartographie tag → substantif évocateur (pour l'expression de fusion).
const TAG_NOUNS: Dictionary = {
	"Sens": "le Regard", "Savoir": "la Mémoire", "Mémoire": "le Souvenir",
	"Force": "le Choc", "Agilité": "le Pas", "Endurance": "le Souffle",
	"Empathie": "la Compassion", "Verbe": "la Voix", "Ruse": "la Feinte",
	"Instinct": "l'Élan", "Nature": "le Lien",
}

const DEGREE_ECHO: Dictionary = {
	"echec": " — et rien ne répond.",
	"partiel": " — à demi.",
	"reussite": " — et la voie s'entrouvre.",
	"eclatante": " — et Brocéliande s'incline.",
}

# Paramètres injectés par play() — figés pour toute la durée de l'animation.
var _res: Dictionary = {}
var _played: Array = []
var _card_views: Array = []   # MerlinCardView encore parentées chez l'appelant (reparentées dans run())
var _ready_pred: Callable     # prédicat « la prose LLM est prête » (remplace /root/MerlinScenario)


# Crée le layer de fusion, le configure plein écran et l'ajoute au host. NE lance PAS l'animation :
# l'appelant fait `await fx.run()` (même frame → les global_position des card views restent valides).
static func play(host: Control, res: Dictionary, played: Array, card_views: Array, ready: Callable) -> MerlinFx:
	var fx: MerlinFx = MerlinFx.new()
	fx._res = res
	fx._played = played
	fx._card_views = card_views
	fx._ready_pred = ready
	# Layer overlay au-dessus du plateau, plein écran. Absorbe les clics pendant la fusion.
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(fx)
	return fx


# Animation 4 phases : Gather → Fuse → Burst → Expression (+ sustain skippable). Awaitable.
# Reparente les MerlinCardView passées par l'appelant DANS ce layer, anime, puis se détruit
# (les cartes reparentées sont free'd avec). Pendant l'animation, le clic est absorbé par le
# layer (mouse_filter STOP). À la fin, l'appelant render hand/combo + show prose.
func run() -> void:
	var degree: String = str(_res.get("degree", "reussite"))
	var glow_col: Color = FUSION_COLORS.get(degree, FUSION_COLORS["reussite"])
	var dur: Dictionary = FUSION_DURATIONS.get(degree, FUSION_DURATIONS["reussite"])
	var shake_px: float = float(FUSION_SHAKE_PX.get(degree, 12.0))
	var zoom_target: float = float(FUSION_ZOOM.get(degree, 1.08))
	var vig_alpha: float = float(FUSION_VIGNETTE_A.get(degree, 0.36))
	var ca_offset: float = float(FUSION_CA_OFFSET.get(degree, 2.5))
	var spark_count: int = int(FUSION_SPARK_COUNT.get(degree, 30))

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = screen_size / 2.0
	pivot_offset = center  # zoom slow-mo Phase 4 démarre depuis le centre du layer

	# Glow plein écran, fade-in pendant la fusion. Couleur = degré.
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.0)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	# Vignette shader : sombre les coins, teinte selon degré (rouge sombre pour échec, or pour
	# éclatante). Intensity 0 → vig_alpha pendant Gather/Fuse/Burst, fade out en Phase 4.
	var vignette: ColorRect = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig_shader: Shader = Shader.new()
	vig_shader.code = VIGNETTE_SHADER_CODE
	var vig_mat: ShaderMaterial = ShaderMaterial.new()
	vig_mat.shader = vig_shader
	vig_mat.set_shader_parameter("intensity", 0.0)
	vig_mat.set_shader_parameter("tint", Color(glow_col.r * 0.30, glow_col.g * 0.22, glow_col.b * 0.22, 1.0))
	vignette.material = vig_mat
	add_child(vignette)

	# Reparente les card views passées par l'appelant (origines = global_position AVANT reparent ;
	# le layer est full-rect à l'origine → position == global_position). mouse_filter IGNORE après
	# pour éviter le hover MerlinCardView::_on_enter qui combat le tween de fusion (fix v10.2/MED).
	var card_views: Array = []
	var origins: Array = []
	for c in _card_views:
		if c is MerlinCardView and is_instance_valid(c):
			card_views.append(c)
			origins.append((c as Control).global_position)
	for i in card_views.size():
		var cv: Control = card_views[i]
		var orig: Vector2 = origins[i]
		var par: Node = cv.get_parent()
		if par != null:
			par.remove_child(cv)
		add_child(cv)
		cv.position = orig
		cv.z_index = 100 + i
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# === Phase 1 — Gather === convergence vers le centre, scale 1.0 → 1.3, glow 0 → 18%.
	var p1: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in card_views.size():
		var cv: Control = card_views[i]
		var t_off: float = float(i) - float(card_views.size() - 1) / 2.0
		var target: Vector2 = center - cv.size / 2.0 + Vector2(t_off * 90.0, -20.0)
		p1.tween_property(cv, "position", target, dur["gather"])
		p1.tween_property(cv, "scale", Vector2(1.30, 1.30), dur["gather"])
		p1.tween_property(cv, "rotation", 0.0, dur["gather"])
	p1.tween_property(glow, "color:a", 0.18, dur["gather"])
	p1.tween_method(_set_vignette_intensity.bind(vig_mat), 0.0, vig_alpha * 0.40, dur["gather"])
	await p1.finished

	# === Phase 2 — Fuse === superposition serrée, scale 1.3 → 1.55, rotation éventail, glow 18 → 45%.
	var p2: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var mid_idx: float = float(card_views.size() - 1) / 2.0
	for i in card_views.size():
		var cv: Control = card_views[i]
		var rot: float = deg_to_rad((float(i) - mid_idx) * 8.0)
		var nudge: Vector2 = Vector2((float(i) - mid_idx) * 18.0, 0.0)
		var target: Vector2 = center - cv.size / 2.0 + nudge
		p2.tween_property(cv, "position", target, dur["fuse"])
		p2.tween_property(cv, "rotation", rot, dur["fuse"])
		p2.tween_property(cv, "scale", Vector2(1.55, 1.55), dur["fuse"])
		p2.tween_property(cv, "modulate", Color(1.15, 1.10, 0.95, 1.0), dur["fuse"])
	p2.tween_property(glow, "color:a", 0.45, dur["fuse"] * 0.85)
	p2.tween_method(_set_vignette_intensity.bind(vig_mat), vig_alpha * 0.40, vig_alpha * 0.75, dur["fuse"])
	await p2.finished

	# === Phase 3 — Burst === flash glow + 3 vagues de sparks (cascade) + cards explose + screen shake.
	var burst_dur: float = dur["burst"]
	var w1: int = int(spark_count * 0.40)
	var w2: int = int(spark_count * 0.35)
	var w3: int = spark_count - w1 - w2
	# Vague 1 — sparks rapides, brillants, dispersion large (éclat initial).
	spark_wave(center, glow_col, w1, burst_dur * 0.55, 280.0, 140.0, Vector2(1.0, 1.0), 1.00)
	# Screen shake concurrent (déclenche dès Vague 1, amplitude par degré, decay).
	shake(self, shake_px, burst_dur * 0.55)
	# Cards explose vers l'extérieur + fade.
	var p3: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in card_views.size():
		var cv: Control = card_views[i]
		var dir_v: Vector2 = (cv.position + cv.size / 2.0 - center).normalized()
		if dir_v.length() < 0.001:
			dir_v = Vector2(0, -1)
		var dest_v: Vector2 = cv.position + dir_v * 180.0
		p3.tween_property(cv, "position", dest_v, burst_dur * 0.60)
		p3.tween_property(cv, "scale", Vector2(2.40, 2.40), burst_dur * 0.60)
		p3.tween_property(cv, "modulate:a", 0.0, burst_dur * 0.60)
		p3.tween_property(cv, "rotation", cv.rotation + randf_range(-0.7, 0.7), burst_dur * 0.60)
	# Glow flash pic 0.92 → 0.30 (tween séquentiel séparé, fix v10.2/HIGH #1).
	var p3_glow: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p3_glow.tween_property(glow, "color:a", 0.92, burst_dur * 0.18)
	p3_glow.tween_property(glow, "color:a", 0.30, burst_dur * 0.50)
	# Vignette pic — atteint vig_alpha plein durant le burst.
	var p3_vig: Tween = create_tween()
	p3_vig.tween_method(_set_vignette_intensity.bind(vig_mat), vig_alpha * 0.75, vig_alpha, burst_dur * 0.30)
	# Vague 2 (mid-burst, embers/braises).
	await get_tree().create_timer(burst_dur * 0.18).timeout
	spark_wave(center, glow_col.lightened(0.10), w2, burst_dur * 0.65, 200.0, 100.0, Vector2(1.4, 1.4), 0.85)
	# Vague 3 (tail-end, cendres tombantes lentes).
	await get_tree().create_timer(burst_dur * 0.22).timeout
	spark_wave(center, glow_col.darkened(0.20), w3, burst_dur * 0.85, 130.0, 70.0, Vector2(2.0, 2.0), 0.55)
	await p3_glow.finished

	# v10.14 : _roll_die(rarity) s'insérera ICI, entre Burst et Expression — révélation animée du dé
	# (polygone flat par taille, chiffres décélérés, liseré rareté). Le dé est PRÉ-TIRÉ dans res
	# (res.die calculé par MerlinResolution.resolve) : l'animation ne fait que révéler.

	# === Phase 4 — Expression === typewriter caractère par caractère + chromatic aberration + zoom slow-mo.
	var expr_text: String = _fusion_expression(_played, _res)
	var expr_dur: float = dur["expr"]

	# Container expression : position directe (Control sans anchors) pour éviter le décalage
	# DPI/viewport observé en v10.2 où l'anchor offset_top * 0.42 plaçait le label trop haut.
	var lbl_h: int = 96
	var lbl_w: int = int(screen_size.x * 0.82)
	var expr_box: Control = Control.new()
	expr_box.position = Vector2((screen_size.x - lbl_w) / 2.0, screen_size.y * 0.46)
	expr_box.size = Vector2(lbl_w, lbl_h)
	expr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(expr_box)

	var bbcode: String = "[center][color=#%s]%s[/color][/center]" % [glow_col.to_html(false), expr_text]
	# Chromatic aberration : copies décalées rouge (gauche) + cyan (droite) DERRIÈRE le label principal.
	var ca_red: RichTextLabel = _make_expr_label(bbcode, Color(1.0, 0.20, 0.20, 0.55), Vector2(-ca_offset, 0.0), Vector2(lbl_w, lbl_h))
	expr_box.add_child(ca_red)
	var ca_blue: RichTextLabel = _make_expr_label(bbcode, Color(0.20, 0.55, 1.0, 0.55), Vector2(ca_offset, 0.0), Vector2(lbl_w, lbl_h))
	expr_box.add_child(ca_blue)
	var expr_lbl: RichTextLabel = _make_expr_label(bbcode, Color(1, 1, 1, 1), Vector2.ZERO, Vector2(lbl_w, lbl_h))
	expr_box.add_child(expr_lbl)

	# Typewriter : visible_characters 0 → N sur 50% de la phase, sur les 3 layers (main + CA).
	var n_chars: int = expr_lbl.get_total_character_count()
	expr_lbl.visible_characters = 0
	ca_red.visible_characters = 0
	ca_blue.visible_characters = 0
	var typer: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_LINEAR)
	typer.tween_property(expr_lbl, "visible_characters", n_chars, expr_dur * 0.50)
	typer.tween_property(ca_red, "visible_characters", n_chars, expr_dur * 0.50)
	typer.tween_property(ca_blue, "visible_characters", n_chars, expr_dur * 0.50)
	# Slow-mo zoom sur le layer entier (centre = pivot_offset déjà set).
	typer.tween_property(self, "scale", Vector2(zoom_target, zoom_target), expr_dur * 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await typer.finished

	# Hold + fade simultané expression, glow, vignette, zoom retour.
	await get_tree().create_timer(expr_dur * 0.28).timeout
	var p4_fade: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p4_fade.tween_property(expr_lbl, "modulate:a", 0.0, expr_dur * 0.40)
	p4_fade.tween_property(ca_red, "modulate:a", 0.0, expr_dur * 0.40)
	p4_fade.tween_property(ca_blue, "modulate:a", 0.0, expr_dur * 0.40)
	p4_fade.tween_property(glow, "color:a", 0.0, expr_dur * 0.55)
	p4_fade.tween_method(_set_vignette_intensity.bind(vig_mat), vig_alpha, 0.0, expr_dur * 0.55)
	p4_fade.tween_property(self, "scale", Vector2.ONE, expr_dur * 0.55)
	await p4_fade.finished

	# === SUSTAIN (v10.12) — anime l'attente JUSQU'À ce que la prose LLM soit prête (cap 20s) : laisse
	# le moteur natif (lent) interpréter la fusion → l'issue « suit » vraiment (user 2026-06-07). Cache-hit
	# (prose déjà prête) → 0 frame de sustain. Remplace le voile texte « Merlin assemble ».
	# v10.13 (A2) : prédicat `ready` INJECTÉ (Callable) — plus de lecture de /root/MerlinScenario ici.
	if not _is_ready():
		# Caption ANIMÉE « Merlin tisse les fils du sort … » (points cyclants) — l'attente est animée,
		# JAMAIS un voile statique (user 2026-06-07). + glow qui respire + sparks lentes en orbite.
		var cap_lbl: Label = Label.new()
		cap_lbl.add_theme_color_override("font_color", glow_col)
		cap_lbl.add_theme_font_size_override("font_size", 26)
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap_lbl.size = Vector2(screen_size.x, 40.0)
		cap_lbl.position = Vector2(0.0, screen_size.y * 0.60)
		cap_lbl.modulate.a = 0.0
		add_child(cap_lbl)
		create_tween().tween_property(cap_lbl, "modulate:a", 0.85, 0.4)
		var pulse: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "color:a", 0.18, 0.9)
		pulse.tween_property(glow, "color:a", 0.06, 0.9)
		# v10.13 (Fix 2) : sustain SKIPPABLE — clic = on cesse d'attendre la prose LLM (fallback servi).
		# Lambda GDScript = capture par VALEUR → boîte mutable (Array) pour sortir le flag.
		var skip_box: Array = [false]
		gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				skip_box[0] = true)
		var sustain_t0: int = Time.get_ticks_msec()
		var deadline_ms: int = sustain_t0 + 20000  # cap large : couvre la gen LLM (≈1 tok/s) sans bloquer
		var next_spark_ms: int = 0
		var next_dot_ms: int = 0
		var dots: int = 0
		while is_inside_tree() and is_instance_valid(glow) and not skip_box[0] \
				and not _is_ready() and Time.get_ticks_msec() < deadline_ms:
			var now: int = Time.get_ticks_msec()
			if now >= next_spark_ms:
				next_spark_ms = now + 2200
				spark_wave(center, glow_col, 8, 1.8, 60.0, 40.0, Vector2(1.6, 1.6), 0.5)
			if now >= next_dot_ms and is_instance_valid(cap_lbl):
				next_dot_ms = now + 450
				dots = (dots + 1) % 4
				# Affordance de skip révélée après 4s d'attente (pilier FACILE — pas de gel perçu).
				var hint: String = "  ·  clic pour continuer" if now - sustain_t0 > 4000 else ""
				cap_lbl.text = "Merlin tisse les fils du sort " + ".".repeat(dots) + hint
			await get_tree().process_frame
		if pulse != null and pulse.is_valid():
			pulse.kill()
		if is_instance_valid(cap_lbl):
			cap_lbl.queue_free()
		if is_inside_tree() and is_instance_valid(glow):
			var sout: Tween = create_tween()
			sout.tween_property(glow, "color:a", 0.0, 0.25)
			await sout.finished

	if is_instance_valid(self):  # la scène a pu nous libérer pendant le fade final (review HIGH)
		queue_free()  # auto-destruction du layer : cartes reparentées, sparks et tweens partent avec


# Prédicat injecté « la prose est prête » — Callable invalide = prêt (pas de sustain), comme
# l'ancien `sc == null` (extraction pure : même sémantique de garde).
func _is_ready() -> bool:
	if not _ready_pred.is_valid():
		return true
	return bool(_ready_pred.call())


# Synthèse verbale de la combinaison : 1-3 substantifs des tags dominants + écho de degré.
# Le joueur lit son geste APRÈS l'animation de fusion, avant la prose narrative.
func _fusion_expression(played: Array, res: Dictionary) -> String:
	var nouns: PackedStringArray = []
	var seen: Dictionary = {}
	for c in played:
		if c == null or not "tags" in c:
			continue
		for t in c.tags:
			var key: String = str(t)
			if seen.has(key):
				continue
			seen[key] = true
			nouns.append(str(TAG_NOUNS.get(key, key)))
			if nouns.size() >= 3:
				break
		if nouns.size() >= 3:
			break
	var phrase: String
	if nouns.size() == 0:
		phrase = "Ton geste s'élance"
	elif nouns.size() == 1:
		phrase = "%s s'élance" % nouns[0]
	elif nouns.size() == 2:
		phrase = "%s se mêle à %s" % [nouns[0], nouns[1]]
	else:
		phrase = "Tu mêles %s, %s et %s" % [nouns[0], nouns[1], nouns[2]]
	return phrase + str(DEGREE_ECHO.get(str(res.get("degree", "reussite")), ""))


# === v10.3 — Helpers de fusion (sparks waves, screen shake, vignette setter, CA labels) ===

# Vague de sparks émise radialement depuis `center`. PUBLIC (réutilisable par le sustain et,
# en phase B, par d'autres écrans via une instance MerlinFx). Non-bloquante : crée les ColorRect
# + tweens LIÉS À CE NODE, retourne immédiatement (queue_free du layer les emporte).
func spark_wave(center: Vector2, color: Color, count: int, life: float, dist_base: float, dist_var: float, scale_target: Vector2, alpha_init: float) -> void:
	for i in count:
		var spark: ColorRect = ColorRect.new()
		spark.color = Color(color.r, color.g, color.b, alpha_init)
		spark.size = Vector2(8, 8)
		spark.position = center - Vector2(4, 4)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var ang: float = float(i) / float(maxi(count, 1)) * TAU + randf_range(-0.12, 0.12)
		var dist: float = dist_base + randf_range(0.0, dist_var)
		var dest: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist - Vector2(4, 4)
		var st: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		st.tween_property(spark, "position", dest, life)
		st.tween_property(spark, "modulate:a", 0.0, life)
		st.tween_property(spark, "scale", scale_target, life)


# Screen shake : tween position de `target` avec offsets aléatoires en décroissance, retour à zéro.
# STATIC réutilisable. Non-bloquant : démarre immédiatement, dure `duration` secondes. Le tween est
# lié à `target` (target.create_tween()) → meurt avec lui, jamais orphelin.
static func shake(target: Control, amplitude: float, duration: float) -> void:
	var n_steps: int = 10
	var step_dur: float = duration / float(n_steps + 1)
	var amp: float = amplitude
	var st: Tween = target.create_tween().set_trans(Tween.TRANS_LINEAR)
	for _i in n_steps:
		var off: Vector2 = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		st.tween_property(target, "position", off, step_dur)
		amp *= 0.88  # decay exponentielle
	st.tween_property(target, "position", Vector2.ZERO, step_dur)


# Setter pour le shader uniform — Tween.tween_method requiert un Callable.
func _set_vignette_intensity(mat: ShaderMaterial, v: float) -> void:
	if mat != null:
		mat.set_shader_parameter("intensity", v)


# Fabrique un RichTextLabel pour l'expression de fusion (utilisé pour main + 2 copies CA).
func _make_expr_label(bbcode: String, mod: Color, offset_px: Vector2, sz: Vector2) -> RichTextLabel:
	var lbl: RichTextLabel = RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("normal_font_size", 32)
	lbl.text = bbcode
	lbl.position = offset_px
	lbl.size = sz
	lbl.modulate = mod
	return lbl
