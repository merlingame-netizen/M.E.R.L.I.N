extends Control
## MerlinGame — boucle de jeu (bible §2, R54/R55/R72). Scène de jeu MVP.
## Situation (LLM prose) → main → combinaison (1 principale + 2 mods) → résolution (CODE)
## → narration (LLM) → beat suivant. Génération SÉQUENTIELLE à la demande (voile "Merlin écrit"),
## sans lookahead (le moteur natif est single-flight). Fallbacks partout → la run se termine toujours.

# v10.13 (A1) : palette ALIASÉE sur MerlinVisual (source de vérité unique — rebranding = 1 édition).
const COL_BG: Color = MerlinVisual.BG_PAGE  # DA flat (2026-05-26) — fond ink-brun du mockup validé
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_INK: Color = MerlinVisual.INK    # texte foncé sur la bande de narration crème
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_GREEN: Color = MerlinVisual.GREEN
const COL_VIOLET: Color = MerlinVisual.VIOLET
const COL_DIM: Color = MerlinVisual.DIM_WARM

const DEFAULT_TITLE: String = "Le Sentier des Murmures"
const DEFAULT_PITCH: String = "Un chemin s'ouvre sous les fougères, là où nul n'a marché. La forêt t'y attend, patiente."
const END_SCENE: String = "res://scenes/MerlinEnd.tscn"

var _life_gauge: MerlinRingGauge
var _corr_gauge: MerlinRingGauge
var _progress_box: HBoxContainer
var _scene_art: MerlinSceneArt
var _situ_panel: PanelContainer       # encart central : porte intro/situation/issue
var _situ_sb: StyleBoxFlat            # style de l'encart (bordure teintée par phase — signal de transition)
var _beat_header: Label               # marqueur discret « — Type · beat N/total — » (sorti du texte narratif)
var _situation_text: RichTextLabel
var _hand_box: Control
var _combo_box: HBoxContainer
var _combo_panel: PanelContainer  # zone combinaison/preview/résolution — visible SEULEMENT en phase de choix
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
var _situ_tw: Tween  # fondu de l'encart au nouveau beat (tué avant réutilisation → pas de course de tweens)
var _encart_phase_tw: Tween  # teinte de la bordure de l'encart (neutre situation ↔ couleur du degré à l'issue)

# v10.11/12 (user 2026-06-07) — Map du chemin (coin droit) + Draft « 1 carte sur 3 » aux beats clés.
var _beat_map: MerlinBeatMap = null      # v10.12 : carte « map » StS (chemin des beats), coin droit (remplace Destin)
var _pending_draft: bool = false         # armé en résolution (réussite/éclatante, beats restants) → draft à l'avance
var _draft_layer: Control = null         # overlay modal du draft
var _draft_pick: MerlinCard = null       # carte choisie (null = passer)
var _draft_done_flag: bool = false       # le joueur a tranché (choix ou passer)


# v10.13 (Fix 0) — garde canonique post-await : la scène est-elle toujours « fraîche » ?
# Toute coroutine qui reprend après un await DOIT vérifier _fresh(ep) avant de toucher l'UI.
func _fresh(ep: int) -> bool:
	return ep == _scene_epoch and is_inside_tree()


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
		get_node("/root/MerlinScenario").prepare_arc(skel)  # arc narratif LLM en fond (swappe le fallback avant beat 1)
	_on_gauges(run.integrite, run.corruption)
	if _beat_map != null:  # v10.12 : la map dessine le chemin du run (total beats + position courante)
		_beat_map.setup(int(run.scenario.get("total", 5)))
		_beat_map.set_current(run.beat_index)
	if run.beat_index == 0:
		# Intro d'abord : encart central plein, cartes CACHÉES. Le 1er beat n'est présenté qu'à l'Accept.
		_set_choice_ui(false)
		_show_intro_popup()
	else:
		_present_current_beat()  # run repris → directement au beat courant


func _present_current_beat() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.ended:
		return
	if _beat_map != null:  # v10.12 : avance la position « tu es ici » sur la map du chemin
		_beat_map.set_current(run.beat_index)
	_scene_epoch += 1  # toute issue LLM en vol du beat précédent devient périmée
	_can_advance = false
	_set_caret(false)
	_set_hand_dimmed(false)
	run.ensure_playable_hand()  # v10.13 (Fix 5) : invariant main ≥ 2 cartes — jamais de soft-lock de combo
	var beat: Dictionary = run.current_beat()
	# Situation procédurale INSTANTANÉE (zéro attente). Volontairement PAS d'enrichissement LLM
	# ici : à ~1 tok/s la gen (~40s) ne gagne jamais la course contre la lecture du joueur, et un
	# swap de texte en cours de lecture viole le pilier ÉVIDENT (bible §21.1). Le budget LLM
	# (moteur single-flight) est réservé à l'ISSUE — l'« effet des choix » que le joueur attend.
	_current_situation = get_node("/root/MerlinScenario").build_situation(beat)
	get_node("/root/MerlinScenario").invalidate_resolution()  # v10.4 : cache issue propre à chaque beat
	_hide_overlay()
	_combo.clear()
	# v10.10 (user 2026-06-06) : la SITUATION s'affiche SEULE dans l'encart central ; les cartes ne
	# montent qu'à la fin du typewriter (_on_typewriter_done state==1). Cartes cachées d'ici là.
	_set_choice_ui(false)
	# Signal de transition (user 2026-06-07) : bordure neutre + fondu de l'encart au nouveau beat.
	_set_encart_phase(Color("6E5A3C"))
	if _situ_panel != null:
		_situ_panel.modulate.a = 0.45
		if _situ_tw != null and _situ_tw.is_valid():
			_situ_tw.kill()  # évite la course si un beat enchaîne avant la fin du fondu
		_situ_tw = _situ_panel.create_tween()
		_situ_tw.tween_property(_situ_panel, "modulate:a", 1.0, 0.22)
	_show_situation(_current_situation)
	_state = 1


func _show_situation(situ: Dictionary, animate: bool = true) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var btype: String = str(situ.get("type", ""))
	if _scene_art != null:
		_scene_art.set_beat(btype)  # le décor reflète le type de beat (figure si Rencontre/Climax/Dilemme)
	if _beat_header != null:
		_beat_header.text = "— %s · beat %d/%d —" % [btype, run.beat_index + 1, int(run.scenario.get("total", 5))]
		_beat_header.visible = true
	_typewriter("[center]" + str(situ.get("narration", "")) + "[/center]", animate)


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
	# v10.6 (user 2026-06-06) — le geste canonique est un COMBO de 2 cartes (la 1ère = action
	# principale, la 2e = modificateur). On bloque au-delà de 2 (plus de trio).
	if _state != 1 or _combo.size() >= 2 or _combo.has(card):
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
	# v10.6 : le geste canonique = COMBO de 2 cartes. La résolution n'est active qu'à 2 cartes.
	var n: int = _combo.size()
	if n == 0:
		_preview_lbl.visible = true
		_preview_lbl.text = "Pose 2 cartes (la 1ère = action principale, la 2e = modificateur)."
		_resolve_btn.disabled = true
		return
	if n == 1:
		_preview_lbl.visible = true
		_preview_lbl.text = "Pose une 2e carte pour former la combinaison."
		_resolve_btn.disabled = true
		return
	# n == 2 : combinaison complète.
	_preview_lbl.visible = true
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [])
	var cov: Dictionary = res["coverage"]
	var covered: int = cov["covered"].size()
	var total: int = covered + cov["missing"].size()
	# v10.4 : plus de tags requis nommés (« ‹ Instinct › ») — seulement couverture/degré/coût.
	_preview_lbl.text = "Couverture %d/%d  ·  degré pressenti : %s  ·  coût Corruption : %d" % [covered, total, str(res["label"]), int(res["corruption_delta"])]
	var was_disabled: bool = _resolve_btn.disabled
	_resolve_btn.disabled = false
	if was_disabled and _resolve_btn.visible:
		_pop(_resolve_btn, 1.12)  # pulse 1-shot quand le combo devient complet (user 2026-06-07) — visible pour un pivot correct
	# v10.4 — pré-génération LLM spéculative pendant la pose (user 2026-06-06). Dédupé par signature
	# combo côté MerlinScenario ; au clic Résolution le texte est souvent déjà prêt (cache-hit).
	get_node("/root/MerlinScenario").prefetch_resolution(_current_situation, _combo.duplicate(), res)


func _on_resolve() -> void:
	# v10.6 : résolution UNIQUEMENT sur un combo de 2 cartes (le geste canonique).
	if _state != 1 or _combo.size() != 2:
		return
	_state = 2
	_resolve_btn.disabled = true
	var run: Node = get_node("/root/MerlinRun")
	var sc: Node = get_node("/root/MerlinScenario")
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [])
	var played_cards: Array = _combo.duplicate()  # cartes (objets) → interprétation LLM de la combinaison
	var situ: Dictionary = _current_situation.duplicate(true)  # fige la situation (LLM toujours pertinent)

	run.play_and_discard(_combo)
	run.apply_card_effects(played_cards)  # v10.11 : effets actifs (Rare+) AVANT le check de mort (un HEAL peut sauver)
	run.apply_resolution(res)
	# Draft « 1 carte sur 3 » armé : SEULEMENT aux beats clés (réussite/éclatante) tant qu'il reste des beats.
	var deg: String = str(res.get("degree", ""))
	_pending_draft = (deg == MerlinResolution.REUSSITE or deg == MerlinResolution.ECLATANTE) and not run.is_climax() and not run.ended
	run.faits_marquants.append("%s → %s" % [str(_current_situation.get("type", "")), str(res["label"])])
	if run.faits_marquants.size() > 6:
		run.faits_marquants = run.faits_marquants.slice(run.faits_marquants.size() - 6, run.faits_marquants.size())

	_scene_epoch += 1
	var ep: int = _scene_epoch
	_combo.clear()
	_set_hand_dimmed(true)  # ÉVIDENT : on lit l'issue ; main grisée + prompt/indice masqués
	_preview_lbl.visible = false
	_resolve_btn.visible = false
	_can_advance = false    # « avancer » (clic) seulement quand l'issue est entièrement écrite

	# v10.2 — Animation cinématique de fusion AVANT la prose. Reparente les card views du _combo_box
	# dans un layer overlay, anime 4 phases (~2-4.5s selon degré), puis détruit. Pendant ce temps la
	# pré-génération LLM (lancée à la pose, _update_preview) continue → masque la latence (user 2026-06-06).
	await _play_fusion_animation(res, played_cards)
	if not _fresh(ep):
		return  # scène quittée pendant la fusion (sécurité epoch + tree-check)

	_set_choice_ui(false)   # v10.10 : cartes redescendent → l'issue occupe l'encart central, SEULE (user 2026-06-06)
	_render_combo()         # _combo vide → clear _combo_box (les vues précédentes ont été reparented/free'd)

	# v10.4 — Issue TOUJOURS générée par le LLM (user 2026-06-06). take_resolution renvoie le cache
	# de pré-génération si prêt (cas courant : pose + anim ont couvert la latence), sinon génère et
	# attend (borné par le timeout moteur). Overlay « Merlin assemble… » SEULEMENT si le cache n'est
	# pas déjà prêt (review MEDIUM : évite le flash d'1 frame sur cache-hit).
	# v10.12 — le SUSTAIN animé de la fusion a déjà patienté jusqu'à is_resolution_ready (ou cap). Prêt
	# → prose LLM (cache, instantané, « le scénario suit »). Sinon → filet procédural SANS voile statique :
	# l'attente animée (caption « Merlin tisse… » + glow + sparks) a remplacé « Merlin assemble ». (user 2026-06-07)
	# v10.13 (Fix 3) : take_resolution ne bloque plus JAMAIS (cache-only) — toute l'attente appartient
	# au sustain animé (cap + skip). Cache prêt → prose LLM instantanée ; sinon filet procédural.
	var prose: String = str(sc.take_resolution(situ, played_cards, res))
	if prose.length() < 10:
		prose = sc.fallback_resolution(str(res.get("degree", "reussite")), str(situ.get("type", "")))
	sc.note_outcome(res)  # v10.13 (Fix 4) : fil rouge mis à jour MÊME en fallback (continuité du beat suivant)
	run.summary = prose
	_show_resolution(res, prose, true)
	# v10.13 (Fix 6) : PLUS de save ici — il persistait les jauges post-résolution avec un beat_index
	# non avancé → la reprise REJOUAIT le beat (coûts double-appliqués). Save unique dans _advance_to_next.


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
	var dur: Dictionary = FUSION_DURATIONS.get(degree, FUSION_DURATIONS["reussite"])
	var shake_px: float = float(FUSION_SHAKE_PX.get(degree, 12.0))
	var zoom_target: float = float(FUSION_ZOOM.get(degree, 1.08))
	var vig_alpha: float = float(FUSION_VIGNETTE_A.get(degree, 0.36))
	var ca_offset: float = float(FUSION_CA_OFFSET.get(degree, 2.5))
	var spark_count: int = int(FUSION_SPARK_COUNT.get(degree, 30))

	# Layer overlay au-dessus du plateau, plein écran. Absorbe les clics pendant la fusion.
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = screen_size / 2.0
	layer.pivot_offset = center  # zoom slow-mo Phase 4 démarre depuis le centre du layer

	# Glow plein écran, fade-in pendant la fusion. Couleur = degré.
	var glow: ColorRect = ColorRect.new()
	glow.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.0)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(glow)

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
	layer.add_child(vignette)

	# Capture + reparente les card views existantes. mouse_filter IGNORE après pour éviter le
	# hover MerlinCardView::_on_enter qui combat le tween de fusion (fix v10.2/MED).
	var card_views: Array = []
	var origins: Array = []
	for c in _combo_box.get_children():
		if c is MerlinCardView:
			card_views.append(c)
			origins.append((c as Control).global_position)
	for i in card_views.size():
		var cv: Control = card_views[i]
		var orig: Vector2 = origins[i]
		_combo_box.remove_child(cv)
		layer.add_child(cv)
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
	_emit_spark_wave(layer, center, glow_col, w1, burst_dur * 0.55, 280.0, 140.0, Vector2(1.0, 1.0), 1.00)
	# Screen shake concurrent (déclenche dès Vague 1, amplitude par degré, decay).
	_screen_shake(layer, shake_px, burst_dur * 0.55)
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
	_emit_spark_wave(layer, center, glow_col.lightened(0.10), w2, burst_dur * 0.65, 200.0, 100.0, Vector2(1.4, 1.4), 0.85)
	# Vague 3 (tail-end, cendres tombantes lentes).
	await get_tree().create_timer(burst_dur * 0.22).timeout
	_emit_spark_wave(layer, center, glow_col.darkened(0.20), w3, burst_dur * 0.85, 130.0, 70.0, Vector2(2.0, 2.0), 0.55)
	await p3_glow.finished

	# === Phase 4 — Expression === typewriter caractère par caractère + chromatic aberration + zoom slow-mo.
	var expr_text: String = _fusion_expression(played, res)
	var expr_dur: float = dur["expr"]

	# Container expression : position directe (Control sans anchors) pour éviter le décalage
	# DPI/viewport observé en v10.2 où l'anchor offset_top * 0.42 plaçait le label trop haut.
	var lbl_h: int = 96
	var lbl_w: int = int(screen_size.x * 0.82)
	var expr_box: Control = Control.new()
	expr_box.position = Vector2((screen_size.x - lbl_w) / 2.0, screen_size.y * 0.46)
	expr_box.size = Vector2(lbl_w, lbl_h)
	expr_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(expr_box)

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
	typer.tween_property(layer, "scale", Vector2(zoom_target, zoom_target), expr_dur * 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await typer.finished

	# Hold + fade simultané expression, glow, vignette, zoom retour.
	await get_tree().create_timer(expr_dur * 0.28).timeout
	var p4_fade: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	p4_fade.tween_property(expr_lbl, "modulate:a", 0.0, expr_dur * 0.40)
	p4_fade.tween_property(ca_red, "modulate:a", 0.0, expr_dur * 0.40)
	p4_fade.tween_property(ca_blue, "modulate:a", 0.0, expr_dur * 0.40)
	p4_fade.tween_property(glow, "color:a", 0.0, expr_dur * 0.55)
	p4_fade.tween_method(_set_vignette_intensity.bind(vig_mat), vig_alpha, 0.0, expr_dur * 0.55)
	p4_fade.tween_property(layer, "scale", Vector2.ONE, expr_dur * 0.55)
	await p4_fade.finished

	# === SUSTAIN (v10.12) — anime l'attente JUSQU'À ce que la prose LLM soit prête (cap 12s) : laisse
	# le moteur natif (lent) interpréter la fusion → l'issue « suit » vraiment (user 2026-06-07). Cache-hit
	# (prose déjà prête) → 0 frame de sustain. Remplace le voile texte « Merlin assemble ».
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null and not sc.is_resolution_ready(played, res):
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
		layer.add_child(cap_lbl)
		create_tween().tween_property(cap_lbl, "modulate:a", 0.85, 0.4)
		var pulse: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(glow, "color:a", 0.18, 0.9)
		pulse.tween_property(glow, "color:a", 0.06, 0.9)
		# v10.13 (Fix 2) : sustain SKIPPABLE — clic = on cesse d'attendre la prose LLM (fallback servi).
		# Lambda GDScript = capture par VALEUR → boîte mutable (Array) pour sortir le flag.
		var skip_box: Array = [false]
		layer.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				skip_box[0] = true)
		var sustain_t0: int = Time.get_ticks_msec()
		var deadline_ms: int = sustain_t0 + 20000  # cap large : couvre la gen LLM (≈1 tok/s) sans bloquer
		var next_spark_ms: int = 0
		var next_dot_ms: int = 0
		var dots: int = 0
		while is_inside_tree() and is_instance_valid(glow) and not skip_box[0] \
				and not sc.is_resolution_ready(played, res) and Time.get_ticks_msec() < deadline_ms:
			var now: int = Time.get_ticks_msec()
			if now >= next_spark_ms:
				next_spark_ms = now + 2200
				_emit_spark_wave(layer, center, glow_col, 8, 1.8, 60.0, 40.0, Vector2(1.6, 1.6), 0.5)
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

	if is_instance_valid(layer):
		layer.queue_free()


# === v10.3 — Helpers de fusion (sparks waves, screen shake, vignette setter, CA labels) ===

# Vague de sparks émise radialement depuis `center`. Non-bloquante : crée les ColorRect + tween,
# retourne immédiatement (les tweens vivent indépendamment, layer.queue_free les emportera).
func _emit_spark_wave(layer: Control, center: Vector2, color: Color, count: int, life: float, dist_base: float, dist_var: float, scale_target: Vector2, alpha_init: float) -> void:
	for i in count:
		var spark: ColorRect = ColorRect.new()
		spark.color = Color(color.r, color.g, color.b, alpha_init)
		spark.size = Vector2(8, 8)
		spark.position = center - Vector2(4, 4)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(spark)
		var ang: float = float(i) / float(maxi(count, 1)) * TAU + randf_range(-0.12, 0.12)
		var dist: float = dist_base + randf_range(0.0, dist_var)
		var dest: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist - Vector2(4, 4)
		var st: Tween = layer.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		st.tween_property(spark, "position", dest, life)
		st.tween_property(spark, "modulate:a", 0.0, life)
		st.tween_property(spark, "scale", scale_target, life)


# Screen shake : tween position du layer avec offsets aléatoires en décroissance, retour à zéro.
# Non-bloquant : démarre immédiatement, dure `duration` secondes.
func _screen_shake(layer: Control, amplitude: float, duration: float) -> void:
	var n_steps: int = 10
	var step_dur: float = duration / float(n_steps + 1)
	var amp: float = amplitude
	var st: Tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	for _i in n_steps:
		var off: Vector2 = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		st.tween_property(layer, "position", off, step_dur)
		amp *= 0.88  # decay exponentielle
	st.tween_property(layer, "position", Vector2.ZERO, step_dur)


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


func _show_resolution(res: Dictionary, narration: String, animate: bool = true) -> void:
	var deg_col: Color = _degree_color(str(res["degree"]))
	_set_encart_phase(deg_col)  # bordure encart = couleur du degré (feedback émotionnel, user 2026-06-07)
	if _beat_header != null:
		_beat_header.visible = false  # l'issue parle d'elle-même ; pas de marqueur de beat
	if animate:
		_situation_text.text = ""
	_typewriter("[center][color=#%s]%s[/color]\n\n%s[/center]" % [deg_col.to_html(false), str(res["label"]), narration], animate)
	if animate:
		_pop(_situation_text, 1.03)  # léger "thump" à la révélation de l'issue


func _advance_to_next() -> void:
	_set_caret(false)
	_can_advance = false
	# v10.11 — Draft « 1 carte sur 3 » aux beats clés, AVANT de passer au beat suivant.
	if _pending_draft:
		_pending_draft = false
		_scene_epoch += 1  # v10.13 (Fix 10) : tout enrichissement LLM en vol ne s'écrit pas sous le modal
		await _present_draft()
		if not is_inside_tree():
			return
	var run: Node = get_node("/root/MerlinRun")
	run.advance_beat()
	if run.ended:
		return
	# v10.13 (Fix 6) : save UNIQUE — au DÉBUT de beat (index avancé + carte draftée, atomique).
	# Resume = toujours au début de beat (canon BIBLE.md R73) ; transients (_combo/_state) jamais persistés.
	run.save()
	if not is_inside_tree():
		return  # la scène a pu être libérée pendant le draft / via run_ended (sécurité teardown)
	_present_current_beat()


# === v10.11 — Draft « 1 carte sur 3 » (style Slay the Spire) ===
func _present_draft() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var choices: Array = run.draft_choices(3)
	if choices.is_empty():
		return
	_draft_pick = null
	_draft_done_flag = false
	_build_draft_layer(choices)
	# v10.13 (Fix 1) : gardes STRUCTURELLES (pas de timeout mural — un joueur AFK sur un choix n'est
	# pas un bug). Les seuls vrais états de blocage = layer libéré / run terminée / scène quittée :
	# tous font sortir la boucle ; sortie sans flag = passer (aucune carte).
	while not _draft_done_flag and is_inside_tree() and is_instance_valid(_draft_layer) and not run.ended:
		await get_tree().process_frame
	if _draft_pick != null:
		run.add_card_to_deck(_draft_pick)
		if _beat_map != null:  # v10.12 : une carte draftée = déviation visible sur le chemin
			_beat_map.mark_draft()
	if _draft_layer != null:
		_draft_layer.queue_free()
		_draft_layer = null


func _build_draft_layer(choices: Array) -> void:
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP  # modal : absorbe les clics derrière
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)
	var title: Label = Label.new()
	title.text = "Une voie s'offre à toi — choisis une carte"
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for card in choices:
		var cv: MerlinCardView = MerlinCardView.new()
		row.add_child(cv)
		cv.setup(card)
		cv.card_clicked.connect(_on_draft_card)
	var skip: Button = Button.new()
	skip.text = "Passer"
	skip.custom_minimum_size = Vector2(180, 52)
	skip.add_theme_font_size_override("font_size", 22)
	skip.pressed.connect(_on_draft_skip)
	var skip_center: CenterContainer = CenterContainer.new()
	skip_center.add_child(skip)
	box.add_child(skip_center)
	add_child(layer)
	_draft_layer = layer


func _on_draft_card(card: MerlinCard) -> void:
	if _draft_done_flag:
		return
	_draft_pick = card
	_draft_done_flag = true


func _on_draft_skip() -> void:
	if _draft_done_flag:
		return
	_draft_pick = null
	_draft_done_flag = true


# === v10.12 — Carte « map » du chemin (coin droit, remplace la carte Destin) ===
func _build_beat_map() -> void:
	_beat_map = MerlinBeatMap.new()
	_beat_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beat_map.anchor_left = 1.0
	_beat_map.anchor_right = 1.0
	_beat_map.anchor_top = 0.5
	_beat_map.anchor_bottom = 0.5
	_beat_map.offset_left = -144.0  # largeur 120 + 24 d'inset depuis le bord droit
	_beat_map.offset_right = -24.0
	_beat_map.offset_top = -150.0   # ~300 de haut, centré verticalement
	_beat_map.offset_bottom = 150.0
	add_child(_beat_map)


# Clic sur la zone récit (scène/narration). Pendant la frappe → révèle tout le texte ;
# une fois l'issue entièrement écrite → passe au beat suivant. (Demande user 2026-05-26.)
func _on_story_click(event: InputEvent) -> void:
	if _intro_open or _draft_layer != null:
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
	if _state == 2:
		# Issue entièrement écrite → avance au clic + caret « continuer » clignotant.
		_can_advance = true
		if _caret != null:
			_caret.text = "▮ cliquer pour continuer"
		_set_caret(true)
	elif _state == 1:
		# Situation entièrement écrite → caret masqué, les cartes MONTENT pour le choix (user 2026-06-06).
		_set_caret(false)
		_preview_lbl.visible = true
		_resolve_btn.visible = true
		_set_choice_ui(true)   # visible AVANT le rendu → _hand_box a sa taille pour _layout_fan
		_render_hand(true)
		_render_combo()


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


# Cartes + zone de combinaison visibles UNIQUEMENT en phase de CHOIX (user 2026-06-06) : l'intro et
# les situations/issues occupent l'encart central SEUL ; les cartes montent au moment de composer.
func _set_choice_ui(on: bool) -> void:
	if _combo_panel != null:
		_combo_panel.visible = on
	if _hand_box != null:
		_hand_box.visible = on
		_hand_box.modulate.a = 1.0


# Teinte la bordure de l'encart selon la phase (situation neutre / issue = couleur du degré) — signal
# de transition visuel, en plus du contenu (user 2026-06-07, audit UX pilier ÉVIDENT).
func _set_encart_phase(col: Color) -> void:
	if _situ_sb == null:
		return
	if _encart_phase_tw != null and _encart_phase_tw.is_valid():
		_encart_phase_tw.kill()  # situation→issue peut arriver avant la fin du tween précédent
	_encart_phase_tw = create_tween()
	_encart_phase_tw.tween_property(_situ_sb, "border_color", col, 0.25)


# Affordance « clic pour passer » affichée DÈS le début du typewriter (avant le caret « continuer »
# clignotant qui n'apparaît qu'à la fin) — comble le temps mort perçu (user 2026-06-07, pilier FACILE).
func _show_skip_hint() -> void:
	if _caret == null:
		return
	if _caret_tw != null and _caret_tw.is_valid():
		_caret_tw.kill()
	_caret_tw = null
	_caret.text = "▶ clic pour passer"
	_caret.visible = true
	_caret.modulate.a = 0.5


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
	var sz: float = 24.0 if state == 1 else 18.0  # agrandi (user 2026-06-07, lisibilité 720p)
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


# DEBUG (v10.2 visual test) — F12 déclenche _play_fusion_animation avec une combo bidon depuis
# la main, pour permettre la capture autonome des 4 phases sans avoir à driver la résolution
# complète. Tag debug OS.is_debug_build pour ne pas embarquer en release.
func _input(event: InputEvent) -> void:
	# v10.6 (user 2026-06-06) — avance « cliquer pour continuer » BULLETPROOF via _input (reçu AVANT
	# la GUI), indépendant du z-order du catcher (qui était parfois bloqué par un conteneur au-dessus).
	# En résolution (state 2) : clic gauche → skip typewriter si en cours, sinon avance au beat suivant.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _intro_open or _draft_layer != null:
			return  # le draft est modal : ses clics sont gérés par l'overlay, pas par l'avance de beat
		if _state == 2:
			if _tw != null and _tw.is_valid():
				_skip_typewriter()
				get_viewport().set_input_as_handled()
			elif _can_advance:
				_advance_to_next()
				get_viewport().set_input_as_handled()
		return

	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_F12:
		return
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run == null or run.hand == null or run.hand.size() < 1:
		return
	var fake_played: Array = []
	var n: int = mini(run.hand.size(), 3)
	for i in n:
		fake_played.append(run.hand[i])
	# Cycle entre les 4 degrés selon le timestamp pour varier les couleurs au fil des F12.
	var degrees: Array = ["echec", "partiel", "reussite", "eclatante"]
	var deg: String = str(degrees[int(Time.get_unix_time_from_system()) % 4])
	var fake_res: Dictionary = {
		"degree": deg,
		"label": "Test fusion %s" % deg,
		"coverage": {"covered": [], "missing": []},
		"integrite_delta": 0,
		"corruption_delta": 0,
		"synergy": 0,
	}
	# Reparente fake_played dans _combo_box temporairement pour que _play_fusion_animation les pick.
	# On crée des MerlinCardView jetables.
	for c in _combo_box.get_children():
		c.queue_free()
	for i in fake_played.size():
		var cv: MerlinCardView = MerlinCardView.new()
		_combo_box.add_child(cv)
		cv.setup(fake_played[i], "principale" if i == 0 else "modificateur", true)
	await get_tree().process_frame  # laisse Godot poser les card views dans le layout
	await _play_fusion_animation(fake_res, fake_played)


func _on_run_ended(_end_type: String) -> void:
	# v10.13 (Fix 1) : si la run se termine pendant le modal de draft, on le ferme proprement
	# (la boucle de _present_draft sort via sa garde is_instance_valid/_draft_layer → skip).
	if _draft_layer != null:
		_draft_layer.queue_free()
		_draft_layer = null
		_draft_done_flag = true
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
	if _state == 1 or _state == 2:
		_show_skip_hint()  # affordance « clic = passer » visible DÈS le début (user 2026-06-07)
	_tw = create_tween()
	_tw.tween_property(_situation_text, "visible_characters", n, clampf(float(n) / 60.0, 0.4, 5.0))
	_tw.finished.connect(_on_typewriter_done)


func _kill_tw() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


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
	fade.color = Color(0.04, 0.03, 0.02, 0.62)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)  # voile plein écran derrière l'encart central
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE  # le layer parent capte déjà
	_intro_layer.add_child(fade)

	# ENCART CENTRAL ~80% (user 2026-06-06) : l'intro occupe le centre, pas un bandeau bas.
	var bandeau: PanelContainer = PanelContainer.new()
	bandeau.set_anchors_preset(Control.PRESET_FULL_RECT)
	bandeau.anchor_left = 0.1
	bandeau.anchor_right = 0.9
	bandeau.anchor_top = 0.1
	bandeau.anchor_bottom = 0.9
	bandeau.offset_left = 0
	bandeau.offset_right = 0
	bandeau.offset_top = 0
	bandeau.offset_bottom = 0
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
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)

	# v10.11 (user 2026-06-06) : commentaire CENTRÉ verticalement dans l'encart (plus de vide en bas).
	# CenterContainer extensible → centre le bloc (au lieu d'un scroll top-aligné qui laissait du vide).
	var mid: CenterContainer = CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mid)
	var intro_lbl: RichTextLabel = RichTextLabel.new()
	intro_lbl.bbcode_enabled = true
	intro_lbl.fit_content = true
	intro_lbl.custom_minimum_size = Vector2(1200, 0)  # bloc large, retour à la ligne, centré dans l'encart
	intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_lbl.add_theme_color_override("default_color", COL_TEXT)
	intro_lbl.add_theme_font_size_override("normal_font_size", 26)  # commentaire Merlin lisible (user 2026-06-06)
	mid.add_child(intro_lbl)
	# v10.8 (user 2026-06-06) : Merlin t'accueille PUIS l'ouverture narrative qui lance l'histoire et
	# coule dans le Beat 1. Pitch déjà présent dans la greeting → with_pitch=false (pas de doublon).
	var opening: String = get_node("/root/MerlinScenario").build_opening(run.scenario, false)
	var intro_text: String = str(data.get("intro", ""))
	if opening.strip_edges() != "":
		intro_text += "\n\n— · —\n\n" + opening
	_reveal_into(intro_lbl, intro_text)

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
	obj_lbl.add_theme_font_size_override("font_size", 22)
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_panel.add_child(obj_lbl)

	var accept: Button = Button.new()
	accept.text = "Accepter ✦"
	accept.custom_minimum_size = Vector2(260, 66)  # ≥44 px (pilier TACTILE+DESKTOP)
	accept.add_theme_font_size_override("font_size", 28)
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

	_bg_intro(run.scenario, intro_lbl, opening)


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
func _bg_intro(scenario: Dictionary, lbl: RichTextLabel, opening: String = "") -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return
	var sep: String = "\n\n— · —\n\n"
	# Greeting MERLIN enrichie (LLM, non bloquant) — conserve l'ouverture procédurale dessous.
	var prose: String = await sc.narrate_intro(scenario)
	if not _intro_open or _intro_layer == null or not is_instance_valid(lbl):
		return
	# ÉVIDENT : ne pas muter un texte en cours de lecture → enrichir seulement si le typewriter a fini.
	if prose.length() >= 10 and not (lbl.visible_characters >= 0 and lbl.visible_characters < lbl.get_total_character_count()):
		lbl.text = prose + (sep + opening if opening.strip_edges() != "" else "")
		lbl.visible_characters = -1
	# v10.13 (Fix 9) : le 2e appel LLM (narrate_opening) est SUPPRIMÉ ici — il occupait le moteur
	# single-flight exactement pendant la composition du beat 1, affamant le prefetch de résolution
	# (la prose d'ouverture ne gagnait jamais la course de toute façon). L'ouverture LLM revivra
	# derrière l'interstitiel « Merlin raconte » (plan v10.13 phase B3), sous priorité moteur.


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
	get_node("/root/MerlinRun").save()  # v10.13 (Fix 6) : quitter pendant le beat 1 → reprise au beat 1
	_present_current_beat()  # l'intro cède la place à la 1ère situation, dans l'encart central (user 2026-06-06)


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

	# Scène en silhouettes plates — bande supérieure FIXE (l'encart récit prend l'espace dessous).
	_scene_art = MerlinSceneArt.new()
	_scene_art.custom_minimum_size = Vector2(0, 150)
	root.add_child(_scene_art)

	# ENCART CENTRAL (~80%) crème : porte l'intro/commentaire PUIS chaque situation/issue (user 2026-06-06).
	# size_flags EXPAND → occupe tout l'espace restant quand les cartes sont cachées (hors phase de choix).
	# Bordure teintée par phase (_set_encart_phase) = signal de transition intro→situation→issue (user 2026-06-07).
	_situ_panel = PanelContainer.new()
	_situ_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_situ_panel.custom_minimum_size = Vector2(0, 260)
	_situ_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clics → capteur récit (skip/avance)
	_situ_sb = _cream_style()
	_situ_panel.add_theme_stylebox_override("panel", _situ_sb)
	root.add_child(_situ_panel)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_situ_panel.add_child(inner)
	# Marqueur de beat discret en haut de l'encart (sorti du texte narratif — user 2026-06-07).
	_beat_header = Label.new()
	_beat_header.add_theme_color_override("font_color", Color("8A6A2E"))
	_beat_header.add_theme_font_size_override("font_size", 18)
	_beat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_beat_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_beat_header)
	var situ_center: CenterContainer = CenterContainer.new()
	situ_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	situ_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(situ_center)
	_situation_text = RichTextLabel.new()
	_situation_text.bbcode_enabled = true
	_situation_text.fit_content = true
	_situation_text.custom_minimum_size = Vector2(1180, 0)  # bloc de texte large, centré dans l'encart
	_situation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_situation_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_situation_text.add_theme_color_override("default_color", COL_INK)
	_situation_text.add_theme_font_size_override("normal_font_size", 36)  # narratif ample (user 2026-06-06)
	situ_center.add_child(_situation_text)

	# Caret « cliquer pour continuer » : clignote faiblement quand l'issue est entièrement écrite.
	_caret = _mk_label(Color("8A6A2E"), 20)
	_caret.text = "▮ cliquer pour continuer"
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.visible = false
	root.add_child(_caret)

	_combo_panel = PanelContainer.new()
	_combo_panel.add_theme_stylebox_override("panel", _surface_style())
	_combo_panel.visible = false  # caché hors phase de CHOIX (cartes seulement au moment de choisir)
	root.add_child(_combo_panel)
	var combo_v: VBoxContainer = VBoxContainer.new()
	combo_v.add_theme_constant_override("separation", 8)
	_combo_panel.add_child(combo_v)
	# (combo_title retiré — redondant avec _preview_lbl, user 2026-06-07 §21.2 ❌7)
	_combo_box = HBoxContainer.new()
	_combo_box.add_theme_constant_override("separation", 10)
	_combo_box.custom_minimum_size = Vector2(0, 104)
	combo_v.add_child(_combo_box)
	_preview_lbl = _mk_label(COL_TEXT, 23)
	combo_v.add_child(_preview_lbl)
	var btn_row: HBoxContainer = HBoxContainer.new()
	combo_v.add_child(btn_row)
	_resolve_btn = Button.new()
	_resolve_btn.text = "Résolution"
	_resolve_btn.custom_minimum_size = Vector2(300, 66)
	_resolve_btn.add_theme_font_size_override("font_size", 26)
	_resolve_btn.pressed.connect(_on_resolve)
	btn_row.add_child(_resolve_btn)

	# v10.5 : label « Ta main : » retiré (user 2026-06-06). L'éventail se suffit visuellement.
	_hand_box = Control.new()
	_hand_box.custom_minimum_size = Vector2(0, 264)  # + haut : cartes agrandies (240) + lift survol
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_box.clip_contents = false  # le survol soulève/agrandit la carte hors cadre
	_hand_box.visible = false  # cartes cachées hors phase de CHOIX (révélées à la fin du typewriter)
	_hand_box.resized.connect(_layout_fan)
	root.add_child(_hand_box)

	# TOAST bas non-bloquant (ne recouvre PLUS le plateau — anti-pattern §21.2 ❌1 corrigé, user 2026-06-07).
	_overlay = Panel.new()
	_overlay.anchor_left = 0.5
	_overlay.anchor_right = 0.5
	_overlay.anchor_top = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.offset_left = -280
	_overlay.offset_right = 280
	_overlay.offset_top = -104
	_overlay.offset_bottom = -40
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # n'absorbe rien (plateau reste visible/interactif)
	var ov_sb: StyleBoxFlat = StyleBoxFlat.new()
	ov_sb.bg_color = Color(0.10, 0.08, 0.06, 0.94)
	ov_sb.set_corner_radius_all(10)
	ov_sb.set_border_width_all(1)
	ov_sb.border_color = COL_GOLD
	ov_sb.set_content_margin_all(12)
	_overlay.add_theme_stylebox_override("panel", ov_sb)
	add_child(_overlay)
	_overlay_lbl = Label.new()
	_overlay_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_lbl.add_theme_color_override("font_color", COL_GOLD)
	_overlay_lbl.add_theme_font_size_override("font_size", 22)
	_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_overlay_lbl)
	_overlay.visible = false

	_build_beat_map()  # v10.12 : carte « map » du chemin, coin droit (remplace la carte Destin)


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
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = COL_GOLD  # teinte par phase via _set_encart_phase (signal de transition)
	sb.set_content_margin_all(18)
	return sb
