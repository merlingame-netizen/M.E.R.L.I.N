extends Control
## MerlinGame — boucle de jeu (bible §2, R54/R55/R72). Scène de jeu MVP.
## Situation (LLM prose) → main → combinaison (1 principale + 2 mods) → résolution (CODE)
## → narration (LLM) → beat suivant. Génération SÉQUENTIELLE à la demande (voile "Merlin écrit"),
## sans lookahead (le moteur natif est single-flight). Fallbacks partout → la run se termine toujours.

const COL_BG: Color = Color("1E1A14")  # DA flat (2026-05-26) — fond ink-brun du mockup validé
const COL_SURFACE: Color = Color("2A2018")
const COL_TEXT: Color = Color("E8DCC0")
const COL_INK: Color = Color("2A2018")    # texte foncé sur la bande de narration crème
const COL_GOLD: Color = Color("C9A24B")
const COL_GREEN: Color = Color("7FA65C")
const COL_VIOLET: Color = Color("7B4FA3")
const COL_DIM: Color = Color("9C8C6A")

const DEFAULT_TITLE: String = "Le Sentier des Murmures"
const DEFAULT_PITCH: String = "Un chemin s'ouvre sous les fougères, là où nul n'a marché. La forêt t'y attend, patiente."
const END_SCENE: String = "res://scenes/MerlinEnd.tscn"

var _life_gauge: MerlinRingGauge
var _corr_gauge: MerlinRingGauge
var _progress_box: HBoxContainer
var _scene_art: MerlinSceneArt
var _situation_text: RichTextLabel
var _hint_lbl: Label
var _hand_box: Control
var _combo_box: HBoxContainer
var _preview_lbl: Label
var _resolve_btn: Button
var _overlay: Panel
var _overlay_lbl: Label
var _caret: Label  # marqueur clignotant « cliquer pour continuer » (fin de phrase, UX boîte de dialogue)
var _caret_tw: Tween
var _can_advance: bool = false  # true quand l'issue est entièrement écrite → clic = beat suivant

var _current_situation: Dictionary = {}
var _combo: Array = []
var _state: int = 0  # 0=loading 1=playing 2=resolving
# Garde anti-clobber : incrémenté à CHAQUE transition d'affichage (nouvelle situation,
# issue affichée, fin de run). Un enrichissement LLM en arrière-plan ne remplace le texte
# QUE si l'epoch n'a pas bougé depuis qu'il a été lancé (sinon le joueur a déjà avancé).
var _scene_epoch: int = 0
var _tw: Tween
var _intro_layer: Control = null  # pop-up modal d'intro de quête (R56)
var _intro_open: bool = false
var _pulse_tw: Tween
var _prev_integrite: int = -999  # pour animer les deltas de jauges (-999 = pas encore initialisé)
var _prev_corruption: int = -999
var _deal_pending: bool = false  # déclenche l'anim de distribution au prochain _layout_fan
var _life_tw: Tween  # tween de remplissage de l'anneau vie (tué avant un nouveau → pas de snap arrière)
var _corr_tw: Tween


func _ready() -> void:
	_build_ui()
	var run: Node = get_node("/root/MerlinRun")
	run.gauges_changed.connect(_on_gauges)
	run.run_ended.connect(_on_run_ended)
	call_deferred("_begin")


func _begin() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.scenario.is_empty():
		# Squelette INSTANTANÉ (le pitch est le synopsis) — aucune attente.
		var skel: Dictionary = get_node("/root/MerlinScenario").build_skeleton(DEFAULT_TITLE, DEFAULT_PITCH)
		run.new_run(skel)
	_on_gauges(run.integrite, run.corruption)
	_present_current_beat()
	if run.beat_index == 0:
		_show_intro_popup()  # briefing de quête modal (à accepter) au démarrage du run


func _present_current_beat() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.ended:
		return
	_scene_epoch += 1  # toute issue LLM en vol du beat précédent devient périmée
	_can_advance = false
	_set_caret(false)
	_set_hand_dimmed(false)
	# v10/H1 (audit UX bible §21.2 #5 — loi de Miller, max 7 affordances) : _hint_lbl ET _preview_lbl
	# disaient la même chose. Le préfixe « Ce moment appelle… » bascule dans _preview_lbl dès qu'une
	# carte est posée (_update_preview) — un seul des deux est visible à la fois.
	_hint_lbl.visible = true
	_preview_lbl.visible = false
	_resolve_btn.visible = true
	var beat: Dictionary = run.current_beat()
	# Situation procédurale INSTANTANÉE (zéro attente). Volontairement PAS d'enrichissement LLM
	# ici : à ~1 tok/s la gen (~40s) ne gagne jamais la course contre la lecture du joueur, et un
	# swap de texte en cours de lecture viole le pilier ÉVIDENT (bible §21.1). Le budget LLM
	# (moteur single-flight) est réservé à l'ISSUE — l'« effet des choix » que le joueur attend.
	_current_situation = get_node("/root/MerlinScenario").build_situation(beat)
	_hide_overlay()
	_show_situation(_current_situation)
	_combo.clear()
	_render_hand(true)
	_render_combo()
	_state = 1


func _show_situation(situ: Dictionary, animate: bool = true) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var btype: String = str(situ.get("type", ""))
	if _scene_art != null:
		_scene_art.set_beat(btype)  # le décor reflète le type de beat (figure si Rencontre/Climax/Dilemme)
	var marker: String = "[color=#6E5A3C]— %s · beat %d/%d —[/color]\n\n" % [btype, run.beat_index + 1, int(run.scenario.get("total", 5))]
	_typewriter(marker + str(situ.get("narration", "")), animate)
	var reqs: Array = situ.get("required_tags", [])
	_hint_lbl.text = "Ce moment appelle :  " + _format_tags(reqs)


func _format_tags(tags: Array) -> String:
	var parts: PackedStringArray = []
	for t in tags:
		parts.append("‹ %s ›" % str(t))
	return "   ".join(parts)


func _render_hand(deal: bool = false) -> void:
	for c in _hand_box.get_children():
		c.queue_free()
	var run: Node = get_node("/root/MerlinRun")
	for card in run.hand:
		if _combo.has(card):
			continue  # carte posée → son slot est vidé dans l'éventail (repioche à la résolution)
		var cv: MerlinCardView = MerlinCardView.new()
		_hand_box.add_child(cv)
		cv.setup(card)
		cv.card_clicked.connect(_on_hand_card)
	_deal_pending = deal  # anime la distribution seulement sur une main fraîche (beat/résolution)
	call_deferred("_layout_fan")


# Dispose la main en éventail dynamique : cartes centrées, arc + rotation depuis le centre.
func _layout_fan() -> void:
	if _hand_box == null:
		return
	var cards: Array = []
	for c in _hand_box.get_children():
		if c is MerlinCardView:
			cards.append(c)
	var n: int = cards.size()
	if n == 0:
		return
	var cw: float = MerlinCardView.CARD_SIZE.x
	var w: float = _hand_box.size.x
	if w <= 0.0:
		w = float(get_viewport().get_visible_rect().size.x) - 56.0
	var center_x: float = w / 2.0
	# Éventail allégé (demande user 2026-05-26) : resserré (pas de carte clippée à droite),
	# peu courbé (arc plat) et remonté.
	var spacing: float = min(cw * 0.62, (w - cw) / float(maxi(n - 1, 1)))
	var base_y: float = 3.0   # éventail remonté (demande user 2026-05-27)
	for i in n:
		var t: float = float(i) - float(n - 1) / 2.0  # négatif à gauche, 0 au centre, positif à droite
		var x: float = center_x + t * spacing - cw / 2.0
		var y: float = base_y + (t * t) * 2.2   # arc quasi plat (bords à peine plus bas)
		var rot: float = deg_to_rad(t * 2.0)     # rotation discrète
		var cv: MerlinCardView = cards[i]
		cv.z_index = i  # carte de droite au-dessus (recouvrement naturel)
		cv.set_fan_transform(Vector2(x, y), rot)
	if _deal_pending:
		_deal_pending = false
		for i in n:
			(cards[i] as MerlinCardView).deal_in(float(i) * 0.05)  # distribution en cascade


func _render_combo() -> void:
	for c in _combo_box.get_children():
		c.queue_free()
	for i in _combo.size():
		var card: MerlinCard = _combo[i]
		var role: String = "principale" if i == 0 else "modificateur"
		var cv: MerlinCardView = MerlinCardView.new()
		_combo_box.add_child(cv)
		cv.setup(card, role, true)  # compact (carte posée)
		cv.card_clicked.connect(_on_combo_card)
		if i == _combo.size() - 1:
			cv.pop_in()  # seule la carte la plus récente fait son pop
	_update_preview()


func _on_hand_card(card: MerlinCard) -> void:
	if _state != 1 or _combo.size() >= 3 or _combo.has(card):
		return
	_combo.append(card)
	_render_hand()   # la carte quitte l'éventail (slot vidé)
	_render_combo()


func _on_combo_card(card: MerlinCard) -> void:
	if _state != 1:
		return
	_combo.erase(card)
	_render_hand()   # la carte revient dans l'éventail
	_render_combo()


func _update_preview() -> void:
	if _combo.is_empty():
		# v10/H1 : combo vide → seul _hint_lbl visible (« Ce moment appelle… »). _preview_lbl masqué
		# pour rester sous le plafond Miller (≤7 affordances simultanées, bible §21.2 #5).
		_hint_lbl.visible = true
		_preview_lbl.visible = false
		_resolve_btn.disabled = true
		return
	# combo non-vide → on bascule sur _preview_lbl avec les tags requis EMBARQUÉS en préfixe
	# (zéro perte d'info) + couverture + degré + coût ; _hint_lbl masqué pour ne pas doubler.
	_hint_lbl.visible = false
	_preview_lbl.visible = true
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [])
	var cov: Dictionary = res["coverage"]
	var covered: int = cov["covered"].size()
	var total: int = covered + cov["missing"].size()
	_preview_lbl.text = "%s  →  Couverture %d/%d  ·  degré pressenti : %s  ·  coût Corruption : %d" % [_format_tags(reqs), covered, total, str(res["label"]), int(res["corruption_delta"])]
	_resolve_btn.disabled = false


func _on_resolve() -> void:
	if _state != 1 or _combo.is_empty():
		return
	_state = 2
	_resolve_btn.disabled = true
	var run: Node = get_node("/root/MerlinRun")
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [])
	var played_cards: Array = _combo.duplicate()  # cartes (objets) → interprétation LLM de la combinaison

	# Issue procédurale INSTANTANÉE — aucune attente. Le LLM enrichit l'issue en arrière-plan.
	var fallback: String = get_node("/root/MerlinScenario").fallback_resolution(str(res.get("degree", "reussite")))
	run.play_and_discard(_combo)
	run.apply_resolution(res)
	run.faits_marquants.append("%s → %s" % [str(_current_situation.get("type", "")), str(res["label"])])
	if run.faits_marquants.size() > 6:
		run.faits_marquants = run.faits_marquants.slice(run.faits_marquants.size() - 6, run.faits_marquants.size())
	run.summary = fallback

	_scene_epoch += 1
	var ep: int = _scene_epoch
	_combo.clear()
	_set_hand_dimmed(true)  # ÉVIDENT : on lit l'issue ; main grisée + prompt/indice masqués
	_hint_lbl.visible = false
	_preview_lbl.visible = false
	_resolve_btn.visible = false
	_can_advance = false    # « avancer » (clic) seulement quand l'issue est entièrement écrite

	# v10.2 — Animation cinématique de fusion AVANT la prose (user 2026-06-06). Reparente les
	# card views du _combo_box dans un layer overlay, anime 4 phases (~2.5s), puis détruit.
	# Le rendu hand/combo + prose se font APRÈS l'animation pour ne pas clobber le visuel.
	await _play_fusion_animation(res, played_cards)
	if ep != _scene_epoch or not is_inside_tree():
		return  # scène quittée pendant la fusion (sécurité epoch + tree-check)

	_render_hand()          # main repiochée (play_and_discard) — affichée grisée pendant l'issue
	_render_combo()         # _combo vide → clear _combo_box (les vues précédentes ont été reparented/free'd)
	_show_resolution(res, fallback, true)
	run.save()

	# LLM réservé aux moments forts (Climax / éclatante) — évite les rafales qui stallent le moteur
	# natif ; ailleurs l'issue procédurale (déjà affichée) suffit. (user 2026-05-29)
	if not run.ended and get_node("/root/MerlinScenario").is_strong_moment(str(_current_situation.get("type", "")), str(res.get("degree", ""))):
		_bg_resolution(ep, _current_situation, played_cards, res)


# === v10.2 — Animation cinématique de fusion (user 2026-06-06) ===
# Avant la prose de résolution, les cartes du combo se rassemblent au centre, fusionnent dans un
# glow coloré par degré, éclatent en sparks, et révèlent une "expression" — la synthèse verbale
# de la combinaison. Puis fondu vers la résolution textuelle existante. Awaitable, ~2.5s total.

const FUSION_COLORS: Dictionary = {
	"echec": Color("D04848"),       # rouge-violet vif (chute, malédiction)
	"partiel": Color("D8A030"),     # ambre (effort à demi tenu)
	"reussite": Color("E8C45A"),    # or chaud (geste accompli)
	"eclatante": Color("F4E0A8"),   # or pâle / blanc-or (apothéose)
}

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


# Animation 4 phases : Gather → Fuse → Burst → Expression. Awaitable.
# Reparent les MerlinCardView du _combo_box dans un layer overlay full-rect, anime, puis
# détruit le layer (les cartes reparented sont free'd avec). Pendant l'animation, le clic est
# absorbé par le layer (mouse_filter STOP). À la fin, l'appelant render hand/combo + show prose.
func _play_fusion_animation(res: Dictionary, played: Array) -> void:
	var degree: String = str(res.get("degree", "reussite"))
	var glow_col: Color = FUSION_COLORS.get(degree, FUSION_COLORS["reussite"])

	# Layer overlay au-dessus du plateau, plein écran. Absorbe les clics pendant la fusion.
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)

	# Glow plein écran, fade-in pendant la fusion. Couleur = degré.
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.0)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(glow)

	# Capture les card views existantes + leurs positions globales AVANT reparenting.
	var card_views: Array = []
	var origins: Array = []
	for c in _combo_box.get_children():
		if c is MerlinCardView:
			card_views.append(c)
			origins.append((c as Control).global_position)

	# Reparent : retire de _combo_box, ajoute à layer, repositionne en absolu.
	# Fix v10.2/MED — coupe le mouse_filter sur les cartes après reparenting pour éviter que
	# _on_enter (hover handler de MerlinCardView) ne se déclenche en plein vol et lance un tween
	# concurrent qui combat la fusion. Le layer parent absorbe déjà les clics.
	for i in card_views.size():
		var cv: Control = card_views[i]
		var orig: Vector2 = origins[i]
		_combo_box.remove_child(cv)
		layer.add_child(cv)
		cv.position = orig
		cv.z_index = 100 + i
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = screen_size / 2.0

	# Phase 1 — Gather (0.45s) : convergence vers le centre, scale 1.0 → 1.3, rotation vers 0.
	var p1: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in card_views.size():
		var cv: Control = card_views[i]
		var spread: float = 90.0
		var t_off: float = float(i) - float(card_views.size() - 1) / 2.0
		var target: Vector2 = center - cv.size / 2.0 + Vector2(t_off * spread, -20.0)
		p1.tween_property(cv, "position", target, 0.45)
		p1.tween_property(cv, "scale", Vector2(1.30, 1.30), 0.45)
		p1.tween_property(cv, "rotation", 0.0, 0.45)
	p1.tween_property(glow, "color:a", 0.18, 0.45)
	await p1.finished

	# Phase 2 — Fuse (0.50s) : superposition centrale, scale 1.3 → 1.55, rotation éventail serré.
	var p2: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var mid_idx: float = float(card_views.size() - 1) / 2.0
	for i in card_views.size():
		var cv: Control = card_views[i]
		var rot: float = deg_to_rad((float(i) - mid_idx) * 8.0)
		var nudge: Vector2 = Vector2((float(i) - mid_idx) * 18.0, 0.0)
		var target: Vector2 = center - cv.size / 2.0 + nudge
		p2.tween_property(cv, "position", target, 0.50)
		p2.tween_property(cv, "rotation", rot, 0.50)
		p2.tween_property(cv, "scale", Vector2(1.55, 1.55), 0.50)
		p2.tween_property(cv, "modulate", Color(1.15, 1.10, 0.95, 1.0), 0.50)
	p2.tween_property(glow, "color:a", 0.45, 0.40)
	await p2.finished

	# Phase 3 — Burst (0.55s) : flash, sparks, cards explode outward + fade.
	# Spark wheel : 14 petits ColorRect émis radialement, fade out 0.5s.
	for i in 14:
		var spark: ColorRect = ColorRect.new()
		spark.color = glow_col
		spark.size = Vector2(8, 8)
		spark.position = center - Vector2(4, 4)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(spark)
		var ang: float = float(i) / 14.0 * TAU + randf_range(-0.10, 0.10)
		var dist: float = 220.0 + randf_range(0.0, 100.0)
		var dest: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist - Vector2(4, 4)
		var st: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		st.tween_property(spark, "position", dest, 0.55)
		st.tween_property(spark, "modulate:a", 0.0, 0.55)
		st.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.55)
	# Cards : explosion vers extérieur + fade. Direction = depuis le centre.
	var p3: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in card_views.size():
		var cv: Control = card_views[i]
		var dir_v: Vector2 = (cv.position + cv.size / 2.0 - center).normalized()
		if dir_v.length() < 0.001:
			dir_v = Vector2(0, -1)
		var dest_v: Vector2 = cv.position + dir_v * 140.0
		p3.tween_property(cv, "position", dest_v, 0.45)
		p3.tween_property(cv, "scale", Vector2(2.20, 2.20), 0.45)
		p3.tween_property(cv, "modulate:a", 0.0, 0.45)
		p3.tween_property(cv, "rotation", cv.rotation + randf_range(-0.6, 0.6), 0.45)
	# Glow flash : tween séquentiel séparé (fix v10.2/HIGH #1 — chain() sur tween parallèle
	# avait une sémantique fragile). Pic 0.85 sur 0.10s puis descente à 0.30 sur 0.45s.
	var p3_glow: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p3_glow.tween_property(glow, "color:a", 0.85, 0.10)
	p3_glow.tween_property(glow, "color:a", 0.30, 0.45)
	await p3_glow.finished  # 0.55s, couvre aussi p3 (0.45s) qui est plus court

	# Phase 4 — Expression : label avec la synthèse verbale apparaît centré, tient ~1s, fond.
	var expr_text: String = _fusion_expression(played, res)
	var expr_lbl: RichTextLabel = RichTextLabel.new()
	expr_lbl.bbcode_enabled = true
	expr_lbl.fit_content = true
	expr_lbl.scroll_active = false
	expr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expr_lbl.add_theme_font_size_override("normal_font_size", 30)
	expr_lbl.text = "[center][color=#%s]%s[/color][/center]" % [glow_col.to_html(false), expr_text]
	expr_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	expr_lbl.offset_left = 80
	expr_lbl.offset_right = -80
	expr_lbl.offset_top = int(screen_size.y * 0.42)
	expr_lbl.offset_bottom = -int(screen_size.y * 0.38)
	expr_lbl.modulate.a = 0.0
	expr_lbl.scale = Vector2(0.92, 0.92)
	expr_lbl.pivot_offset = Vector2(screen_size.x * 0.5 - 80, 0)
	layer.add_child(expr_lbl)
	var p4: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	p4.tween_property(expr_lbl, "modulate:a", 1.0, 0.30)
	p4.tween_property(expr_lbl, "scale", Vector2(1.0, 1.0), 0.30)
	await p4.finished
	# Maintien 0.85s puis fondu simultané de l'expression + du glow.
	# Fix v10.2/HIGH #2 — chain() après tween_interval sur tween parallèle avait une sémantique
	# fragile (le glow fade démarrait pendant le hold). Hold via create_timer + tween parallèle frais.
	await get_tree().create_timer(0.85).timeout
	var p4b: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p4b.tween_property(expr_lbl, "modulate:a", 0.0, 0.40)
	p4b.tween_property(glow, "color:a", 0.0, 0.60)
	await p4b.finished

	layer.queue_free()


func _show_resolution(res: Dictionary, narration: String, animate: bool = true) -> void:
	var deg_col: Color = _degree_color(str(res["degree"]))
	if animate:
		_situation_text.text = ""
	_typewriter("[color=#%s]%s[/color]\n\n%s" % [deg_col.to_html(false), str(res["label"]), narration], animate)
	if animate:
		_pop(_situation_text, 1.03)  # léger "thump" à la révélation de l'issue


# Enrichit l'issue en arrière-plan ; ne remplace QUE si le joueur n'a pas cliqué « Continuer »
# (epoch stable) et que le run n'est pas fini. Jamais bloquant.
func _bg_resolution(ep: int, situ: Dictionary, played: Array, res: Dictionary) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	var run: Node = get_node_or_null("/root/MerlinRun")
	if sc == null or run == null:
		return
	if not await _wait_engine_free(ep):
		return
	var prose: String = await sc.narrate_resolution(situ, played, res)
	if ep != _scene_epoch or run.ended or prose.length() < 10 or not is_inside_tree():
		return
	if _tw != null and _tw.is_valid():
		return  # typewriter de l'issue procédurale encore en cours → ne pas swap (anti-saut de lecture)
	run.summary = prose
	_show_resolution(res, prose, false)  # swap sans ré-animer


func _advance_to_next() -> void:
	_set_caret(false)
	_can_advance = false
	var run: Node = get_node("/root/MerlinRun")
	run.advance_beat()
	if run.ended:
		return
	_present_current_beat()


# Clic sur la zone récit (scène/narration). Pendant la frappe → révèle tout le texte ;
# une fois l'issue entièrement écrite → passe au beat suivant. (Demande user 2026-05-26.)
func _on_story_click(event: InputEvent) -> void:
	if _intro_open:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _tw != null and _tw.is_valid():
		_skip_typewriter()
	elif _state == 2 and _can_advance:
		_advance_to_next()


func _skip_typewriter() -> void:
	if _tw == null or not _tw.is_valid():
		return
	_kill_tw()
	_situation_text.visible_characters = -1
	_on_typewriter_done()


func _on_typewriter_done() -> void:
	# L'issue entièrement écrite : on autorise l'avance au clic + caret clignotant.
	if _state == 2:
		_can_advance = true
		_set_caret(true)


func _set_caret(on: bool) -> void:
	if _caret == null:
		return
	_caret.visible = on
	if _caret_tw != null and _caret_tw.is_valid():
		_caret_tw.kill()
	_caret_tw = null
	if on:
		_caret.modulate.a = 0.65
		_caret_tw = _caret.create_tween().set_loops()
		_caret_tw.tween_property(_caret, "modulate:a", 0.18, 0.6).set_trans(Tween.TRANS_SINE)
		_caret_tw.tween_property(_caret, "modulate:a", 0.65, 0.6).set_trans(Tween.TRANS_SINE)


func _set_hand_dimmed(on: bool) -> void:
	if _hand_box != null:
		_hand_box.modulate.a = 0.35 if on else 1.0


func _degree_color(degree: String) -> Color:
	# Couleurs LISIBLES sur la bande de narration crème (le label de degré s'y affiche).
	match degree:
		"echec": return Color("7B4FA3")     # violet
		"partiel": return Color("6E5A3C")    # brun-ink
		"eclatante": return Color("4F6B3E")  # vert sombre
		_: return Color("8A6A2E")            # or sombre (réussite)


func _on_gauges(integrite: int, corruption: int) -> void:
	var di: int = integrite - _prev_integrite
	var dc: int = corruption - _prev_corruption
	var life_r: float = clampf(float(integrite) / 10.0, 0.0, 1.0)
	var corr_r: float = clampf(float(corruption) / float(MerlinRun.CORRUPTION_CAP), 0.0, 1.0)
	if _prev_integrite == -999:
		# Init : pas d'anim au premier affichage.
		_life_gauge.set_ratio(life_r)
		_corr_gauge.set_ratio(corr_r)
	else:
		_life_tw = _tween_ratio(_life_gauge, life_r, _life_tw)
		_corr_tw = _tween_ratio(_corr_gauge, corr_r, _corr_tw)
		if di != 0:
			_pop(_life_gauge, 1.18)
			_float_delta(_life_gauge, di, COL_GREEN if di > 0 else COL_VIOLET)
		if dc != 0:
			_pop(_corr_gauge, 1.18)
			_float_delta(_corr_gauge, dc, COL_VIOLET if dc > 0 else COL_GREEN)
	# Pulse continue quand la stat est critique (vie basse / corruption haute).
	_life_gauge.set_critical(integrite <= 3)
	_corr_gauge.set_critical(corruption >= int(MerlinRun.CORRUPTION_CAP * 0.66))
	_prev_integrite = integrite
	_prev_corruption = corruption
	_render_perles()


func _tween_ratio(g: MerlinRingGauge, target: float, prev: Tween) -> Tween:
	if prev != null and prev.is_valid():
		prev.kill()  # évite deux tweens concurrents sur le même anneau (snap arrière)
	var t: Tween = create_tween()
	t.tween_method(g.set_ratio, g.get_ratio(), target, 0.3).set_trans(Tween.TRANS_SINE)
	return t


func _pop(node: Control, peak: float) -> void:
	node.pivot_offset = node.size / 2.0
	var t: Tween = create_tween()
	t.tween_property(node, "scale", Vector2(peak, peak), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)


func _float_delta(anchor: Control, delta: int, col: Color) -> void:
	var f: Label = Label.new()
	f.text = ("+%d" % delta) if delta > 0 else str(delta)
	f.add_theme_color_override("font_color", col)
	f.add_theme_font_size_override("font_size", 22)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.z_index = 100
	add_child(f)
	# Sous la jauge, centré (les jauges sont aux bords → un offset à droite sortirait de l'écran
	# pour la jauge Corruption). Le chiffre monte vers la jauge puis s'efface.
	f.global_position = anchor.global_position + Vector2(anchor.size.x * 0.5 - 10.0, anchor.size.y + 2.0)
	var gy: float = f.global_position.y
	var t: Tween = create_tween()
	t.tween_property(f, "global_position:y", gy - 30.0, 0.6).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(f, "modulate:a", 0.0, 0.6)
	t.tween_callback(f.queue_free)


func _render_perles() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var total: int = int(run.scenario.get("total", 5))
	var cur: int = run.beat_index
	# Pool réutilisé (pas de free+rebuild → pas de doublon 1-frame). remove_child = comptage immédiat.
	while _progress_box.get_child_count() > total:
		var last: Node = _progress_box.get_child(_progress_box.get_child_count() - 1)
		_progress_box.remove_child(last)
		last.queue_free()
	while _progress_box.get_child_count() < total:
		_progress_box.add_child(_make_dot(0))
	for i in total:
		# Complétion du scénario : 2=beat résolu, 1=beat courant, 0=à venir.
		var st: int = 2 if i < cur else (1 if i == cur else 0)
		_style_dot(_progress_box.get_child(i) as Panel, st)


func _make_dot(state: int) -> Panel:
	var d: Panel = Panel.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_dot(d, state)
	return d


func _style_dot(d: Panel, state: int) -> void:
	var sz: float = 16.0 if state == 1 else 12.0
	d.custom_minimum_size = Vector2(sz, sz)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(int(sz / 2.0))
	if state == 0:      # à venir : creux estompé
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.border_color = COL_DIM
	elif state == 1:    # courant : plein or + liseré crème (le plus saillant)
		sb.bg_color = COL_GOLD
		sb.set_border_width_all(2)
		sb.border_color = COL_TEXT
	else:               # résolu : plein or
		sb.bg_color = COL_GOLD
	d.add_theme_stylebox_override("panel", sb)


func _on_run_ended(_end_type: String) -> void:
	get_node("/root/MerlinRun").save()
	call_deferred("_goto_end")


func _goto_end() -> void:
	_scene_epoch += 1  # invalide tout enrichissement LLM en vol avant de quitter la scène
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		mn.cancel()
	MerlinTransition.change_scene(END_SCENE)


func _typewriter(txt: String, animate: bool = true) -> void:
	_kill_tw()
	_situation_text.text = txt
	if not animate:
		_situation_text.visible_characters = -1  # tout révélé (swap d'enrichissement)
		_on_typewriter_done()
		return
	_situation_text.visible_characters = 0
	var n: int = _situation_text.get_total_character_count()
	if n <= 0:
		_on_typewriter_done()
		return
	_tw = create_tween()
	_tw.tween_property(_situation_text, "visible_characters", n, clampf(float(n) / 60.0, 0.4, 5.0))
	_tw.finished.connect(_on_typewriter_done)


func _kill_tw() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


# Attend (en arrière-plan, jamais bloquant pour le joueur) que le moteur LLM se libère.
# Retourne false si la scène a changé (epoch) / run fini / moteur indispo → l'appelant abandonne.
func _wait_engine_free(ep: int) -> bool:
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn == null or not mn.is_ready():
		return false
	var guard: int = 0
	while mn.is_busy() and guard < 6000 and ep == _scene_epoch and is_inside_tree():
		await get_tree().process_frame
		guard += 1
	if not is_inside_tree():
		return false  # scène quittée pendant l'attente (ne pas toucher un nœud en cours de libération)
	var run: Node = get_node_or_null("/root/MerlinRun")
	return ep == _scene_epoch and run != null and not run.ended


func _show_overlay(txt: String) -> void:
	_overlay.visible = true
	_overlay_lbl.text = txt


func _hide_overlay() -> void:
	_overlay.visible = false


# --- Bandeau d'intro de quête (R56) : développement narratif + objectif, à accepter. ---
# v10/C2 (audit UX bible §21.2 #1) : NE recouvre PLUS le plateau 3D — bandeau slide-up bottom ≤30%
# hauteur. Le plateau reste visible au-dessus ; le layer absorbe les clics (modal soft) sans dim
# plein-rect. (user 2026-05-31 /goal)
func _show_intro_popup() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var data: Dictionary = get_node("/root/MerlinScenario").build_intro(run.scenario)
	_intro_open = true

	_intro_layer = Control.new()
	_intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP  # absorbe les clics du plateau (modal soft)
	add_child(_intro_layer)

	# Voile léger limité au tiers bas (continuité visuelle bandeau↔plateau), pas de dim plein-rect.
	var fade: ColorRect = ColorRect.new()
	fade.color = Color(0.04, 0.03, 0.02, 0.45)
	fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fade.anchor_top = 0.66
	fade.anchor_bottom = 1.0
	fade.offset_top = 0
	fade.offset_bottom = 0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE  # le layer parent capte déjà
	_intro_layer.add_child(fade)

	# Bandeau ancré en bas : 30% hauteur, marge horizontale 24 px, bordure or supérieure 3 px.
	var bandeau: PanelContainer = PanelContainer.new()
	bandeau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bandeau.anchor_top = 0.70
	bandeau.anchor_bottom = 1.0
	bandeau.offset_top = 0
	bandeau.offset_bottom = -16  # petit padding bottom écran
	bandeau.offset_left = 24
	bandeau.offset_right = -24
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(10)
	sb.border_color = COL_GOLD
	sb.border_width_top = 3
	sb.set_content_margin_all(20)
	bandeau.add_theme_stylebox_override("panel", sb)
	_intro_layer.add_child(bandeau)

	# Layout vertical : titre + intro (scroll si long) + ligne objectif/accepter.
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	bandeau.add_child(v)

	var title: Label = Label.new()
	title.text = str(run.scenario.get("title", "La Quête"))
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)

	# ScrollContainer : l'intro générée peut être longue (4-6 phrases corpus Merlin). On laisse
	# l'utilisateur scroller dans le bandeau sans déborder du tiers bas.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var intro_lbl: RichTextLabel = RichTextLabel.new()
	intro_lbl.bbcode_enabled = true
	intro_lbl.fit_content = true
	intro_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_lbl.add_theme_color_override("default_color", COL_TEXT)
	intro_lbl.add_theme_font_size_override("normal_font_size", 16)
	scroll.add_child(intro_lbl)
	_reveal_into(intro_lbl, str(data.get("intro", "")))

	# Ligne basse : Objectif (gauche, expand) + Accepter (droite, fixed). Une seule rangée → cibles
	# tactiles ≥44 px (bible §21.1 pilier TACTILE+DESKTOP).
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)

	var obj_panel: PanelContainer = PanelContainer.new()
	obj_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var osb: StyleBoxFlat = StyleBoxFlat.new()
	osb.bg_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.12)
	osb.set_corner_radius_all(6)
	osb.set_content_margin_all(10)
	osb.border_color = COL_GOLD
	osb.border_width_left = 3
	obj_panel.add_theme_stylebox_override("panel", osb)
	row.add_child(obj_panel)
	var obj_lbl: Label = Label.new()
	obj_lbl.text = "✦ Objectif : " + str(data.get("objectif", ""))
	obj_lbl.add_theme_color_override("font_color", COL_GOLD)
	obj_lbl.add_theme_font_size_override("font_size", 14)
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_panel.add_child(obj_lbl)

	var accept: Button = Button.new()
	accept.text = "Accepter ✦"
	accept.custom_minimum_size = Vector2(180, 48)  # ≥44 px (pilier TACTILE+DESKTOP)
	accept.add_theme_font_size_override("font_size", 18)
	accept.pressed.connect(_accept_quest)
	row.add_child(accept)
	accept.resized.connect(func() -> void: accept.pivot_offset = accept.size / 2.0)
	_pulse(accept)

	# Animation slide-up depuis sous l'écran + fade-in du voile (300 ms, BACK out).
	var screen_h: float = float(get_viewport().get_visible_rect().size.y)
	bandeau.position.y = screen_h * 0.3  # offset visuel = simule un slide-up depuis le bas
	var t: Tween = bandeau.create_tween()
	t.tween_property(bandeau, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fade.modulate = Color(1, 1, 1, 0)
	fade.create_tween().tween_property(fade, "modulate:a", 1.0, 0.3)

	_bg_intro(run.scenario, intro_lbl)


func _reveal_into(lbl: RichTextLabel, txt: String) -> void:
	lbl.text = txt
	lbl.visible_characters = 0
	var n: int = lbl.get_total_character_count()
	if n <= 0:
		return
	var t: Tween = lbl.create_tween()
	t.tween_property(lbl, "visible_characters", n, clampf(float(n) / 55.0, 0.6, 4.0))


func _pulse(node: Control) -> void:
	_pulse_tw = node.create_tween().set_loops()
	_pulse_tw.tween_property(node, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)


# Enrichit l'intro en arrière-plan ; ne remplace QUE si le pop-up est encore ouvert. Jamais bloquant.
func _bg_intro(scenario: Dictionary, lbl: RichTextLabel) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return
	var prose: String = await sc.narrate_intro(scenario)
	# Garde-fou : pop-up encore ouvert (layer non null = pas d'accept en cours) ET label vivant.
	if not _intro_open or _intro_layer == null or not is_instance_valid(lbl) or prose.length() < 10:
		return
	# ÉVIDENT : ne pas muter un texte en cours de lecture → enrichir seulement si le typewriter a fini.
	if lbl.visible_characters >= 0 and lbl.visible_characters < lbl.get_total_character_count():
		return
	lbl.text = prose
	lbl.visible_characters = -1


func _accept_quest() -> void:
	if not _intro_open:
		return
	_intro_open = false
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null
	var layer: Control = _intro_layer
	_intro_layer = null
	if layer == null:
		return
	var t: Tween = create_tween()
	t.tween_property(layer, "modulate:a", 0.0, 0.25)
	t.tween_callback(layer.queue_free)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Capteur « zone récit » : derrière le contenu, reçoit les clics non consommés par les cartes
	# ou le bouton → accélère le texte / passe au beat suivant (caret). Demande user 2026-05-26.
	var catcher: Control = Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_story_click)
	add_child(catcher)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var hud: HBoxContainer = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 16)
	root.add_child(hud)
	_life_gauge = MerlinRingGauge.new()
	hud.add_child(_life_gauge)
	_life_gauge.setup(COL_GREEN, true)  # jauge « vivante » : respiration continue
	var sp_l: Control = Control.new()
	sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(sp_l)
	_progress_box = HBoxContainer.new()
	_progress_box.add_theme_constant_override("separation", 10)
	_progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_child(_progress_box)
	var sp_r: Control = Control.new()
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(sp_r)
	_corr_gauge = MerlinRingGauge.new()
	hud.add_child(_corr_gauge)
	_corr_gauge.setup(COL_VIOLET, true)  # jauge « vivante » : respiration continue

	# Scène en silhouettes plates (au-dessus de la narration) — prend l'espace extensible.
	_scene_art = MerlinSceneArt.new()
	_scene_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene_art.custom_minimum_size = Vector2(0, 200)
	root.add_child(_scene_art)

	# Bande de narration crème + texte ink (comme le mockup validé).
	var situ_panel: PanelContainer = PanelContainer.new()
	situ_panel.custom_minimum_size = Vector2(0, 96)
	situ_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clics → capteur récit (skip/avance)
	situ_panel.add_theme_stylebox_override("panel", _cream_style())
	root.add_child(situ_panel)
	_situation_text = RichTextLabel.new()
	_situation_text.bbcode_enabled = true
	_situation_text.fit_content = true
	_situation_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_situation_text.add_theme_color_override("default_color", COL_INK)
	_situation_text.add_theme_font_size_override("normal_font_size", 19)
	situ_panel.add_child(_situation_text)

	# Caret « cliquer pour continuer » : clignote faiblement quand l'issue est entièrement écrite.
	_caret = _mk_label(Color("8A6A2E"), 14)
	_caret.text = "▮ cliquer pour continuer"
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.visible = false
	root.add_child(_caret)

	_hint_lbl = _mk_label(COL_GOLD, 15)
	root.add_child(_hint_lbl)

	var combo_panel: PanelContainer = PanelContainer.new()
	combo_panel.add_theme_stylebox_override("panel", _surface_style())
	root.add_child(combo_panel)
	var combo_v: VBoxContainer = VBoxContainer.new()
	combo_v.add_theme_constant_override("separation", 8)
	combo_panel.add_child(combo_v)
	var combo_title: Label = _mk_label(COL_DIM, 14)
	combo_title.text = "Combinaison (clic pour poser / retirer) :"
	combo_v.add_child(combo_title)
	_combo_box = HBoxContainer.new()
	_combo_box.add_theme_constant_override("separation", 10)
	_combo_box.custom_minimum_size = Vector2(0, 78)
	combo_v.add_child(_combo_box)
	_preview_lbl = _mk_label(COL_TEXT, 15)
	combo_v.add_child(_preview_lbl)
	var btn_row: HBoxContainer = HBoxContainer.new()
	combo_v.add_child(btn_row)
	_resolve_btn = Button.new()
	_resolve_btn.text = "Résolution"
	_resolve_btn.custom_minimum_size = Vector2(200, 48)
	_resolve_btn.pressed.connect(_on_resolve)
	btn_row.add_child(_resolve_btn)

	var hand_lbl: Label = _mk_label(COL_DIM, 14)
	hand_lbl.text = "Ta main :"
	root.add_child(hand_lbl)
	_hand_box = Control.new()
	_hand_box.custom_minimum_size = Vector2(0, 214)
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_box.clip_contents = false  # le survol soulève/agrandit la carte hors cadre
	_hand_box.resized.connect(_layout_fan)
	root.add_child(_hand_box)

	_overlay = Panel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_sb: StyleBoxFlat = StyleBoxFlat.new()
	ov_sb.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	_overlay.add_theme_stylebox_override("panel", ov_sb)
	add_child(_overlay)
	_overlay_lbl = Label.new()
	_overlay_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_lbl.add_theme_color_override("font_color", COL_GOLD)
	_overlay_lbl.add_theme_font_size_override("font_size", 26)
	_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_overlay_lbl)
	_overlay.visible = false


func _mk_label(col: Color, fsize: int) -> Label:
	var l: Label = Label.new()
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", fsize)
	return l


func _surface_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	return sb


func _cream_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_TEXT  # crème parchemin (#E8DCC0)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	return sb
