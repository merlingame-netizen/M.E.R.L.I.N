class_name MerlinFx
extends Control
## v10.13 (A2) — Animation cinématique de fusion (extraite VERBATIM de merlin_game.gd, v10.2→v10.13).
## MerlinFx EST le layer overlay : il s'ajoute au host (plein écran, absorbe les clics), anime les
## 3 phases (Rassemblement → Burst → Décrue+Dé) + le SUSTAIN skippable, puis se queue_free().
## v11-W0/W1 (user 2026-07-04 « le jeu est trop complexe ») : la phase « Expression » (slogan jaune +
## aberration chromatique + zoom) est SUPPRIMÉE, gather+fuse fusionnés, swell supprimé, le dé UNIQUE
## (MerlinDice) se lance en chevauchement sur la décrue — overhead fixe ~2,1-2,4 s (vs ~6-8 s).
## Correction « tweens orphelins » PAR CONSTRUCTION : tout tween interne est créé sur CE node
## (create_tween() d'un Control = tween lié au node) → la mort du layer emporte ses animations.
## Découplage LLM : le sustain ne lit PLUS /root/MerlinScenario — prédicat `ready` injecté (Callable).
## Les card views du combo sont passées par l'appelant et reparentées DANS le layer (free'd avec lui).
##
## Usage (merlin_game._on_resolve / debug F12) :
##   var fx: MerlinFx = MerlinFx.play(self, res, played_cards, vues_du_combo, ready_pred)
##   await fx.run()

# Avant la prose de résolution, les cartes du combo se rassemblent au centre, fusionnent dans un
# glow NEUTRE, éclatent en sparks, puis le glow décroit et fondu vers la résolution textuelle
# existante (même fil que la situation, R128). Awaitable, ~2-3,5s total.
#
# N4-P1 (chantier 2a, panel BLOQUANT_FUN) : fusion NEUTRE : la fusion SPOILAIT le degré (couleur,
# durées, shake, sparks tous clés par degré AVANT le dé). Plus AUCUNE lecture du degré dans les
# phases 1-3 : teinte unique GOLD sobre + profil d'intensité UNIQUE (mid). Le degré ne colore que
# l'APRÈS-pose : halo du d20 (MerlinDice), stinger, pill, encart. Les FUSION_* par degré sont morts.

# v10.3 — Amplification dramatique par degré (user 2026-06-06 AskUserQuestion) : échec court & mat,
# éclatante longue & ample.
# v11-W1 (spec panel 2026-07-04, user « le jeu est trop complexe ») — fusion RECAPÉE : gather+fuse
# FUSIONNÉS en un seul rassemblement, swell supprimé, totaux {0,90 / 1,10 / 1,30 / 1,70 s} (vs
# 1,88-3,35 s). Le dé se lance EN CHEVAUCHEMENT sur la décrue. Toutes les durées ×motion() (R134).
const FUSION_GF: float = 0.50        # rassemblement (profil unique mid, ex-"reussite" moyenne)
const FUSION_BURST: float = 0.45
const FUSION_DECRUE: float = 0.24
const FUSION_SHAKE_PX: float = 12.0
const FUSION_VIGNETTE_A: float = 0.42
const FUSION_SPARK_COUNT: int = 32

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

# Paramètres injectés par play() — figés pour toute la durée de l'animation.
var _res: Dictionary = {}
var _played: Array = []
var _card_views: Array = []   # MerlinCardView encore parentées chez l'appelant (reparentées dans run())
var _ready_pred: Callable     # prédicat « la prose LLM est prête » (remplace /root/MerlinScenario)
var _verdict_cb: Callable = Callable()  # N4-P1 (chantier 2b) : stinger de degré, joué PAR le dé au halo


# Crée le layer de fusion, le configure plein écran et l'ajoute au host. NE lance PAS l'animation :
# l'appelant fait `await fx.run()` (même frame → les global_position des card views restent valides).
# N4-P1 : `verdict` (optionnel) = Callable jouée à l'instant du halo du d20 (séquence pose → pause
# → verdict, chantier 2b). Callable() invalide = aucun stinger déclenché par le dé (ex. debug F12).
static func play(host: Control, res: Dictionary, played: Array, card_views: Array, ready: Callable,
		verdict: Callable = Callable()) -> MerlinFx:
	var fx: MerlinFx = MerlinFx.new()
	fx._res = res
	fx._played = played
	fx._card_views = card_views
	fx._ready_pred = ready
	fx._verdict_cb = verdict
	# Layer overlay au-dessus du plateau, plein écran. Absorbe les clics pendant la fusion.
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(fx)
	return fx


# Animation 3 phases : Rassemblement → Burst → Décrue+Dé (+ sustain skippable). Awaitable.
# Reparente les MerlinCardView passées par l'appelant DANS ce layer, anime, puis se détruit
# (les cartes reparentées sont free'd avec). Pendant l'animation, le clic est absorbé par le
# layer (mouse_filter STOP). À la fin, l'appelant render hand/combo + show prose.
func run() -> void:
	# N4-P1 (chantier 2a) : le degré n'est plus lu que pour le DÉ (halo/célébration après la pose).
	# Toute l'intensité des phases 1-3 est NEUTRE : teinte GOLD sobre unique, profil mid unique.
	var degree: String = str(_res.get("degree", "reussite"))
	var glow_col: Color = MerlinVisual.GOLD
	var shake_px: float = FUSION_SHAKE_PX
	var vig_alpha: float = FUSION_VIGNETTE_A
	var spark_count: int = FUSION_SPARK_COUNT

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = screen_size / 2.0

	# Glow plein écran, fade-in pendant la fusion. Couleur = degré.
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.0)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	# Vignette shader : sombre les coins, teinte NEUTRE dérivée du glow GOLD (N4-P1 chantier 2a :
	# plus de teinte par degré). Intensity 0 → vig_alpha pendant Gather/Fuse/Burst, fade out en Phase 4.
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

	# === Phase 1 — Rassemblement === v11-W1 : gather+fuse FUSIONNÉS (spec panel — l'enchaînement en
	# 3 temps « punissait » chaque geste par l'attente). Les cartes convergent DIRECTEMENT vers la pose
	# fusionnée (éventail serré, scale 1.55, teinte chaude) ; glow 0 → 45 %, vignette 0 → 75 %.
	var m: float = MerlinVisual.motion()
	var gf: float = FUSION_GF * m
	var p1: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var mid_idx: float = float(card_views.size() - 1) / 2.0
	for i in card_views.size():
		var cv: Control = card_views[i]
		var rot: float = deg_to_rad((float(i) - mid_idx) * 8.0)
		var nudge: Vector2 = Vector2((float(i) - mid_idx) * 18.0, 0.0)
		var target: Vector2 = center - cv.size / 2.0 + nudge
		p1.tween_property(cv, "position", target, gf)
		p1.tween_property(cv, "rotation", rot, gf)
		p1.tween_property(cv, "scale", Vector2(1.55, 1.55), gf)
		p1.tween_property(cv, "modulate", Color(1.15, 1.10, 0.95, 1.0), gf)
	p1.tween_property(glow, "color:a", 0.45, gf * 0.85)
	p1.tween_method(_set_vignette_intensity.bind(vig_mat), 0.0, vig_alpha * 0.75, gf)
	await p1.finished

	# === Impact freeze + flash (Hades-style dramatic pause) ===
	MerlinAudio.play_sfx("seal_stamp", 0.85)
	await get_tree().create_timer(MerlinVisual.DUR_IMPACT_FREEZE * m).timeout
	if not MerlinVisual.reduced_motion:
		var flash_rect: ColorRect = ColorRect.new()
		flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash_rect)
		var flash_tw: Tween = create_tween()
		flash_tw.tween_property(flash_rect, "color:a", 0.55, MerlinVisual.DUR_FLASH * 0.3)
		flash_tw.tween_property(flash_rect, "color:a", 0.0, MerlinVisual.DUR_FLASH * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flash_tw.tween_callback(flash_rect.queue_free)

	# === Phase 2 — Burst === flash glow + 4 vagues de sparks (cascade) + cards explose + screen shake.
	var burst_dur: float = FUSION_BURST * m
	var w1: int = int(spark_count * 0.34)
	var w2: int = int(spark_count * 0.28)
	var w3: int = int(spark_count * 0.22)
	var w4: int = spark_count - w1 - w2 - w3  # v10.20 : 4e vague (cendres lentes)
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
	# Vague 4 (v10.20) — cendres TRÈS lentes, longue traîne (enrichit la retombée).
	if w4 > 0:
		await get_tree().create_timer(burst_dur * 0.18).timeout
		spark_wave(center, glow_col.darkened(0.30), w4, burst_dur * 1.05, 90.0, 50.0, Vector2(2.6, 2.6), 0.40)
	# N4-BUG (HIGH, latent) : p3_glow (0,68 x burst) court PENDANT les 3 timers séquentiels ci-dessus
	# (0,58 x burst cumulés). Sous forte charge CPU (gen Gemma en vol : frames de 0,3-0,5 s), chaque
	# await de timer déborde d'une frame entière → p3_glow peut être DÉJÀ fini ici, et awaiter le
	# `finished` d'un tween terminé ne rend JAMAIS la main : fusion figée, _can_advance jamais posé
	# (softlock 90 s reproduit par probe_bugres_fast --pace=think --wait-llm=1). Même garde que
	# p4_fade plus bas.
	if p3_glow.is_running():
		await p3_glow.finished

	# === Phase 3 — Décrue + Dé en CHEVAUCHEMENT === v11-W1 (spec panel) : UN SEUL dé — MerlinDice
	# (v2-W4, d20 culbute fausse-3D + halo success/échec) lancé PENDANT la décrue du glow. Le disque
	# B8 en doublon est supprimé (deux dés successifs = l'« animation bizarre » du feedback user). La
	# face 1-20 est PRÉ-TIRÉE au beat (R120 preview = résolution) ; l'animation ne fait que révéler.
	# `success` (§K, degré FINAL) → halo VERT/ROUGE : plus AUCUNE lecture de die_mod/die_rarity ici.
	var decrue: float = FUSION_DECRUE * m
	var p4_fade: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p4_fade.tween_property(glow, "color:a", 0.0, decrue)
	p4_fade.tween_method(_set_vignette_intensity.bind(vig_mat), vig_alpha, 0.0, decrue)
	if int(_res.get("die", 0)) >= 1:
		# N4-P1 (chantiers 2b/2c/7) : séquence pose → pause 0,35 s → verdict VIT dans MerlinDice.
		# `_verdict_cb` (stinger de degré) est appelé PAR le dé à l'instant du halo, jamais avant.
		# Le dé est parenté à l'HÔTE (pas à ce layer) : ses 2 pulses persistants et la célébration
		# éclatante survivent au queue_free() du layer en fin de run() (il se fade/free tout seul).
		var dice_host: Control = self
		var par: Node = get_parent()
		if par is Control and is_instance_valid(par):
			dice_host = par
		var dice: MerlinDice = MerlinDice.roll(dice_host, int(_res.get("die", 0)),
			bool(_res.get("success", false)), degree == "eclatante", _verdict_cb)
		await dice.done
		if not is_inside_tree():
			return
	if p4_fade.is_running():
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
		# R128 (user 2026-06-30) — barre de progression « où on en est ». Gemma ne streame PAS (texte d'un bloc)
		# → progression HEURISTIQUE temps écoulé, plafonnée à 0.90 jusqu'à ce que l'issue soit prête, puis 100 %.
		var bar_w: float = 360.0
		var bar_track: ColorRect = ColorRect.new()
		bar_track.color = Color(MerlinVisual.INK.r, MerlinVisual.INK.g, MerlinVisual.INK.b, 0.50)
		bar_track.size = Vector2(bar_w, 6.0)
		bar_track.position = Vector2((screen_size.x - bar_w) * 0.5, screen_size.y * 0.655)
		bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_track.modulate.a = 0.0
		add_child(bar_track)
		var bar_fill: ColorRect = ColorRect.new()
		bar_fill.color = MerlinVisual.GOLD
		bar_fill.size = Vector2(0.0, 6.0)
		bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_track.add_child(bar_fill)
		create_tween().tween_property(bar_track, "modulate:a", 0.85, 0.4)
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
		var deadline_ms: int = sustain_t0 + 12000  # v10.20.1 (T4) : cap baissé 20→12 s → fallback procédural plus tôt
		var next_spark_ms: int = 0
		var next_dot_ms: int = 0
		var dots: int = 0
		# R128 — petits sons de « réflexion magique » (point d'interrogation), espacés 3-5 s, JAMAIS superposés
		# (seule source sonore du sustain : voix de situation finie, voix d'issue pas commencée).
		var next_think_ms: int = sustain_t0 + 1200
		var think_sfx: Array = ["question_transition", "ogham_chime", "magic_reveal"]
		var think_idx: int = 0
		while is_inside_tree() and is_instance_valid(glow) and not skip_box[0] \
				and not _is_ready() and Time.get_ticks_msec() < deadline_ms:
			var now: int = Time.get_ticks_msec()
			if is_instance_valid(bar_fill):
				bar_fill.size.x = minf(0.90, float(now - sustain_t0) / 10000.0) * bar_w  # progression estimée (plafond 0.90)
			if now >= next_think_ms:
				next_think_ms = now + randi_range(3000, 5000)  # cadence 3-5 s, jamais superposé
				MerlinAudio.play_sfx(str(think_sfx[think_idx % think_sfx.size()]))
				think_idx += 1
			if now >= next_spark_ms:
				next_spark_ms = now + 2200
				spark_wave(center, glow_col, 8, 1.8, 60.0, 40.0, Vector2(1.6, 1.6), 0.5)
			if now >= next_dot_ms and is_instance_valid(cap_lbl):
				next_dot_ms = now + 450
				dots = (dots + 1) % 4
				# v10.20.1 (T2) : affordance de skip révélée vite (1,5 s) — le joueur qui a compris avance.
				var hint: String = "  ·  clic pour continuer" if now - sustain_t0 > 1500 else ""
				cap_lbl.text = "Merlin tisse les fils du sort " + ".".repeat(dots) + hint
			await get_tree().process_frame
		if pulse != null and pulse.is_valid():
			pulse.kill()
		if is_instance_valid(bar_fill):
			bar_fill.size.x = bar_w  # issue prête → barre pleine (100 %), honnête : on n'atteint 100 % qu'ici
		if is_instance_valid(bar_track):
			var bout: Tween = bar_track.create_tween()
			bout.tween_interval(0.18)
			bout.tween_property(bar_track, "modulate:a", 0.0, 0.22)
			bout.tween_callback(bar_track.queue_free)
		if is_instance_valid(cap_lbl):
			cap_lbl.queue_free()
		if is_inside_tree() and is_instance_valid(glow):
			var sout: Tween = create_tween()
			sout.tween_property(glow, "color:a", 0.0, 0.25)
			await sout.finished

	if is_instance_valid(self):  # la scène a pu nous libérer pendant le fade final (review HIGH)
		queue_free()  # auto-destruction du layer : cartes reparentées, sparks et tweens partent avec


# (v11-W1 : le disque B8 `_reveal_die` est supprimé — le dé unique est MerlinDice, lancé dans run()
# en chevauchement sur la décrue. Monolocalité R112 restaurée : UN dé, UN lieu.)


# Prédicat injecté « la prose est prête » — Callable invalide = prêt (pas de sustain), comme
# l'ancien `sc == null` (extraction pure : même sémantique de garde).
func _is_ready() -> bool:
	if not _ready_pred.is_valid():
		return true
	return bool(_ready_pred.call())


# === v10.3 — Helpers de fusion (sparks waves, screen shake, vignette setter) ===

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


# Screen shake : tween position de `target` avec offsets aléatoires en décroissance, retour à la
# position de DÉPART. STATIC réutilisable. Non-bloquant : démarre immédiatement, dure `duration`
# secondes. Le tween est lié à `target` (target.create_tween()) → meurt avec lui, jamais orphelin.
# v10.13 (B9) : secousse autour de la position COURANTE (et non ZERO) — le layer fusion vit en
# (0,0) (comportement inchangé), mais un panneau layouté par un container (ex. _situ_panel) ne
# doit pas finir téléporté à l'origine de son parent.
static func shake(target: Control, amplitude: float, duration: float) -> void:
	var n_steps: int = 10
	var step_dur: float = duration / float(n_steps + 1)
	var amp: float = amplitude
	var base: Vector2 = target.position
	var st: Tween = target.create_tween().set_trans(Tween.TRANS_LINEAR)
	for _i in n_steps:
		var off: Vector2 = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		st.tween_property(target, "position", base + off, step_dur)
		amp *= 0.88  # decay exponentielle
	st.tween_property(target, "position", base, step_dur)


# Setter pour le shader uniform — Tween.tween_method(callable.bind(mat)) : la valeur INTERPOLÉE arrive en
# 1er argument, les args bindés en DERNIER. L'ancien ordre (mat, v) recevait (float, mat) → « Cannot convert
# argument 1 from float to Object » à CHAQUE step : la vignette de fusion n'a jamais animé (fix 2026-06-30,
# découvert par le harnais autoplay réparé).
func _set_vignette_intensity(v: float, mat: ShaderMaterial) -> void:
	if mat != null:
		mat.set_shader_parameter("intensity", v)


# === v10.13.1 — Juice pack 1 (BIBLE §21 R116) : helpers statics réutilisables ===
# Cascade game-design Wave1/Wave2 (2026-06-12) : ghost = node NEUF (jamais reparenter une
# CardView réelle) ; voile = IGNORE (jamais STOP) ; tweens liés au node qu'ils animent.


# Vol de carte main↔combo (§21 `ui`) : ghost crème indépendant, arc -18px (bezier quadratique),
# scale →0.62, fade final, queue_free. Fire-and-forget — ne touche JAMAIS l'état logique.
static func ghost_flight(host: Control, from_rect: Rect2, to_pos: Vector2, accent: Color, dur: float = -1.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var d: float = (MerlinVisual.DUR_UI if dur <= 0.0 else dur) * MerlinVisual.motion()
	var ghost: Panel = Panel.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 90
	ghost.size = from_rect.size
	ghost.pivot_offset = from_rect.size / 2.0
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = MerlinVisual.CREAM
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = accent
	ghost.add_theme_stylebox_override("panel", sb)
	host.add_child(ghost)
	ghost.global_position = from_rect.position
	var from_p: Vector2 = from_rect.position
	var to_tl: Vector2 = to_pos - from_rect.size * 0.5  # le pivot centré garde le centre visuel sur to_pos
	var arc: float = -9.0 if MerlinVisual.reduced_motion else -18.0
	var mid: Vector2 = (from_p + to_tl) * 0.5 + Vector2(0.0, arc)
	var tw: Tween = ghost.create_tween().set_parallel(true)
	tw.tween_method(_ghost_step.bind(ghost, from_p, mid, to_tl), 0.0, 1.0, d) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(ghost, "scale", Vector2(0.62, 0.62), d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# v10.24 (charte cartes) — le ghost S'INCLINE dans le sens de son vol (banking léger, artisanat).
	if not MerlinVisual.reduced_motion:
		tw.tween_property(ghost, "rotation", 0.10 if to_tl.x >= from_p.x else -0.10, d * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade: Tween = ghost.create_tween()
	fade.tween_interval(d)
	fade.tween_property(ghost, "modulate:a", 0.0, 0.08)
	fade.tween_callback(ghost.queue_free)


# Pas de bezier sur le ghost via lambda multiligne (parse fragile) — helper bindé.
static func _ghost_step(t: float, ghost: Control, a: Vector2, m: Vector2, b: Vector2) -> void:
	if is_instance_valid(ghost):
		ghost.global_position = a.lerp(m, t).lerp(m.lerp(b, t), t)


# Chiffre delta de jauge qui monte et s'évanouit (§21 `float_delta`) — promu de merlin_game v10.13.
# Tween lié au LABEL (et non à la scène) : meurt avec lui, jamais orphelin.
static func float_delta(host: Control, anchor: Control, delta: int, col: Color) -> void:
	float_text(host, anchor, ("+%d" % delta) if delta > 0 else str(delta), col)


# N4-P1 (chantier 7) : variante TEXTE LIBRE du même canal §21 `float_delta` (ex. « ✦ +1 » du gain
# de talent près de la pill de degré). Le corps historique de float_delta vit ici, inchangé.
static func float_text(host: Control, anchor: Control, text: String, col: Color) -> void:
	if host == null or not host.is_inside_tree() or anchor == null:
		return
	var f: Label = Label.new()
	f.text = text
	f.add_theme_color_override("font_color", col)
	f.add_theme_font_size_override("font_size", 22)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.z_index = 100
	host.add_child(f)
	f.global_position = anchor.global_position + Vector2(anchor.size.x * 0.5 - 10.0, anchor.size.y + 2.0)
	var gy: float = f.global_position.y
	var t: Tween = f.create_tween()
	t.tween_property(f, "global_position:y", gy - 30.0, MerlinVisual.DUR_FLOAT_LABEL * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(f, "modulate:a", 0.0, MerlinVisual.DUR_FLOAT_LABEL * MerlinVisual.motion())
	t.tween_callback(f.queue_free)


# Pop d'échelle 1-shot — promu de merlin_game v10.13 ; tween lié au node animé.
# (v11-V2b : le static `beat_veil` est SUPPRIMÉ — les cross-fades de zone l'ont remplacé, spec écran stable.)
static func pop(node: Control, peak: float) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size / 2.0
	var p: float = 1.0 + (peak - 1.0) * (0.5 if MerlinVisual.reduced_motion else 1.0)
	var t: Tween = node.create_tween()
	t.tween_property(node, "scale", Vector2(p, p), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
