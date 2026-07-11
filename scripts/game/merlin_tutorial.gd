extends CanvasLayer
## MerlinTutorial (N4-TUTO, 2026-07-11) : le GUIDE de première traversée. Merlin prend la main et
## joue lui-même le VRAI premier beat (ses choix sont appliqués pour de vrai, R120 intact), étape
## par étape : chaque étape = il PARLE (texte STATIQUE, sa voix canon, typewriter) + l'élément est
## MIS EN SCÈNE (spotlight : assombrissement autour d'un trou + liseré GOLD pulsant) + l'input est
## VERROUILLÉ sauf « clic pour continuer ». UN CLIC par étape ; « Passer le guide » à tout moment.
## PROPOSÉ, jamais imposé : construit par merlin_game (_build_tuto_prompt) sur chronique vierge
## (MerlinChronicle, revue design B2) ; rejouable via Options. R136 : zéro modal, overlay léger.
## Revue design (GO AVEC CORRECTIONS) appliquée : B3 (le draft d'ouverture décalé se fond dans le
## gate unique de _advance_to_next : l'étape « greffes » ANNONCE, elle n'ouvre rien), I1 (spotlight
## tuiles ≠ bouton Résoudre), I2 (texte Pousser ancré sur l'issue réelle), I4 (ré-affichage piloté
## par l'état, zéro timer), I5 (l'avance de l'étape combo n'arme qu'après la pose de Merlin).

# R147bis : appels inter-classes par preload const (jamais par nom de classe : flake de compilation).
const _Visual: GDScript = preload("res://scripts/game/merlin_visual.gd")
const _Chronicle: GDScript = preload("res://scripts/game/merlin_chronicle.gd")
const _Tags: GDScript = preload("res://scripts/game/merlin_tags.gd")

signal finished(completed: bool)

const TUTO_LAYER: int = 120          # sous MerlinOptions (150), au-dessus de la scène de jeu
const HOLE_PAD: float = 10.0         # respiration autour de la cible du spotlight
const BANNER_W: float = 860.0
const BANNER_H: float = 170.0
const BANNER_MARGIN: float = 18.0
const TW_CPS: float = 30.0           # cadence du typewriter (parité merlin_game)
const POSE_PAUSE_S: float = 0.7      # respiration entre les 2 gestes de Merlin (étape combo)
const VOICE_TICK_S: float = 0.14     # cadence des syllabes procédurales pendant la frappe

# ── Textes du guide : voix canon de Merlin (tutoiement, « Voyageur / mon ami », taquin-mélancolique,
# images celtiques brèves ; « tuile / rune / bouton / dé » OK en atelier, jamais de meta au-delà).
# STATIQUES : le guide est instantané et fiable, zéro LLM. ──
const TXT_SITUATION: String = "Ici, la forêt te parle. Chaque pas t'offre une scène... Lis-la bien, mon ami : elle réclame toujours quelque chose."
const TXT_VERBES: String = "Ces quatre tuiles sont tes verbes : percevoir, agir, parler, ressentir. Tout geste commence par l'un d'eux."
const TXT_RUNES: String = "Et voilà tes runes, ta manière de faire. Quand l'or souligne une tuile ou une rune, c'est qu'elle répond à ce que le lieu réclame. Suis l'or, il ment rarement."
const TXT_COMBO: String = "Laisse-moi faire, pour cette fois. Un verbe... une rune... et le geste prend forme."
const TXT_PREVIEW: String = "Vois : le bouton s'éveille, notre geste est prêt. Clique, et regarde bien... je le scelle."
const TXT_SCEAU: String = "Le dé a roulé. Halo vert, la forêt cède ; rouge, elle se cabre. Et le sceau, lui, te dit combien."
const TXT_JAUGES: String = "Deux anneaux veillent là-haut. Le vert, ton Intégrité : garde-la vivante. Le violet, la Corruption... elle ne demande qu'à grandir. Entre les deux, le chemin qu'il te reste à parcourir."
# I2 : la variante s'ancre sur ce qui vient RÉELLEMENT de se passer (partiel servi ou non).
const TXT_POUSSER_REEL: String = "La forêt n'a cédé qu'à moitié, Voyageur. Encaisser le coup, ou pousser le passage en payant d'un peu de toi... Cette fois, j'encaisse pour nous."
const TXT_POUSSER_INFO: String = "La forêt a tranché net, cette fois. Mais quand elle ne cède qu'à moitié, tu choisiras : encaisser le coup, ou pousser le passage... en payant d'un peu de toi."
const TXT_GREFFES: String = "En chemin, on t'offrira des greffes et des talents pour nourrir tes verbes. La première t'attend au prochain pas... choisis, ou passe ton chemin."
const TXT_ENVOI: String = "À toi de jouer, Voyageur. La forêt t'attend... et moi, je regarde."

# lu duck-typé par merlin_game (_tuto_blocks) et l'outillage : true = le guide confisque les clics
var blocking: bool = false
var step_id: String = ""             # étape courante (sonde de capture N4-TUTO)

var _game: Node = null
var _zones: Dictionary = {}          # refs de zones passées par merlin_game (Controls)
var _active: bool = false
var _done: bool = false
var _skip_req: bool = false
var _root: Control = null
var _dim_rects: Array = []           # 4 ColorRect autour du trou (purement visuels, IGNORE)
var _frame: Panel = null             # liseré GOLD pulsant sur la cible
var _frame_tw: Tween = null
var _banner: PanelContainer = null
var _banner_text: RichTextLabel = null
var _caret: Label = null
var _caret_tw: Tween = null
var _catcher: Control = null         # verrou d'input plein écran (STOP) : tout clic = continuer
var _skip_btn: Button = null
var _tw: Tween = null                # typewriter du bandeau
var _reveal_req: bool = false        # clic pendant la frappe : tout révéler
var _advance_req: bool = false       # clic une fois armé : étape suivante
var _click_armed: bool = false


# Point d'entrée (appelé par merlin_game APRÈS add_child). zones : encart / etat / main / resoudre /
# vie / corruption (Controls). Les tuiles de verbe sont relues via _game._action_views (I1).
func start(game: Node, zones: Dictionary) -> void:
	_game = game
	_zones = zones
	layer = TUTO_LAYER
	_active = true
	blocking = true
	_build_ui()
	_run()  # fire-and-forget : chaque await re-checke _ok() (pattern _fresh de merlin_game)


# Outillage (sonde capture N4-TUTO / harnais) : simule le clic du joueur sur le catcher.
func probe_click() -> void:
	if _tw != null and _tw.is_valid():
		_reveal_req = true
	elif _click_armed:
		_advance_req = true


# ── Cœur : la séquence d'étapes ────────────────────────────────────────────────────────────────


# La scène est-elle toujours pilotable ? Garde canonique post-await (parité merlin_game._fresh).
# Revue N4-TUTO (M1) : garde run.ended UNIFORME sur tous les waits (pas seulement _step_resolve) :
# une fin de run pendant le guide ne doit jamais laisser la coroutine suspendue sur une scène en
# cours de libération (esprit R148, défense en profondeur).
func _ok() -> bool:
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run != null and bool(run.get("ended")):
		return false
	return _active and not _done and not _skip_req and is_inside_tree() \
		and _game != null and is_instance_valid(_game) and _game.is_inside_tree()


func _run() -> void:
	var completed: bool = await _run_steps()
	_teardown(completed)


func _run_steps() -> bool:
	# Le beat 1 se présente pendant que la proposition se refermait : attendre l'ouverture du choix.
	await _until(func() -> bool: return not _ok() or bool(_game.get("_choice_open")))
	if not _ok():
		return false
	if not await _step("situation", _zone_rect("encart"), TXT_SITUATION):
		return false
	if not await _step("verbes", _verbs_rect(), TXT_VERBES):
		return false
	if not await _step("runes", _zone_rect("main"), TXT_RUNES):
		return false
	if not await _step_combo():
		return false
	if not await _step("sceau_pret", _zone_rect("resoudre"), TXT_PREVIEW):
		return false
	if not await _step_resolve():
		return false
	# I2 : si un partiel est RÉELLEMENT en attente (R130), le choix se traite AVANT les jauges
	# (les anneaux ne jouent leur delta différé qu'après le choix : v11-W1 _flush_gauges).
	var push_seen: bool = _push_open()
	if push_seen:
		if not await _step_pousser(true):
			return false
	if not await _step("jauges", _zone_rect("jauges"), TXT_JAUGES):
		return false
	if not push_seen:
		if not await _step_pousser(false):
			return false
	# B3 (revue design) : l'étape greffes ANNONCE seulement : le vrai draft d'ouverture (décalé)
	# sortira du gate UNIQUE de _advance_to_next au premier clic du joueur. Jamais deux drafts.
	if not await _step("greffes", _zone_rect("main"), TXT_GREFFES):
		return false
	if not await _step("envoi", _zone_rect("encart"), TXT_ENVOI):
		return false
	return true


# Étape générique : spotlight sur la cible, Merlin parle, avance au clic.
func _step(id: String, hole: Rect2, text: String) -> bool:
	if not _ok():
		return false
	step_id = id
	_show_spotlight(hole)
	await _speak(text)
	if not _ok():
		return false
	await _wait_click()
	return _ok()


# Étape combo : Merlin POSE lui-même (tuile puis rune, sélections réelles du jeu : bordure GOLD +
# levée, mêmes chemins que le joueur). I5 : le clic d'avance ne s'arme qu'APRÈS la pose complète.
func _step_combo() -> bool:
	if not _ok():
		return false
	step_id = "combo"
	_show_spotlight(_verbs_rect().merge(_zone_rect("main")))
	await _speak(TXT_COMBO)
	if not _ok():
		return false
	var pair: Array = _pick_demo_pair()
	if pair.size() == 2:
		await _pause(POSE_PAUSE_S)
		if not _ok():
			return false
		_game._on_action_tile(pair[0])
		await _pause(POSE_PAUSE_S)
		if not _ok():
			return false
		_game._on_trait_card(pair[1])
		await _pause(POSE_PAUSE_S * 0.5)
		if not _ok():
			return false
	await _wait_click()
	return _ok()


# Étape résolution : Merlin scelle. La fusion + le d20 couvrent l'écran : le guide s'efface
# (visuels OFF) mais reste BLOQUANT (merlin_game._input laisse vivre le skip du typewriter,
# jamais l'avance de beat). I4 : ré-affichage piloté par l'ÉTAT du jeu, zéro timer.
func _step_resolve() -> bool:
	if not _ok():
		return false
	step_id = "resolve"
	_set_overlay_visible(false)
	var run: Node = get_node_or_null("/root/MerlinRun")
	_game._on_resolve()  # fire-and-forget (pattern autoplay : la scène peut mourir mid-resolve)
	await _until(func() -> bool:
		return not _ok() or run == null or bool(run.get("ended")) \
			or (int(_game.get("_state")) == 2 and (bool(_game.get("_can_advance")) or _push_open())))
	if not _ok() or run == null or bool(run.get("ended")):
		return false
	_set_overlay_visible(true)
	step_id = "sceau"
	_show_spotlight(_zone_rect("etat"))
	await _speak(TXT_SCEAU)
	if not _ok():
		return false
	await _wait_click()
	return _ok()


# Étape Encaisser/Pousser : expliquée UNE fois. real=true : un partiel est ouvert, Merlin tranche
# lui-même Encaisser après son texte (prix affiché : la démo reste lisible).
func _step_pousser(real: bool) -> bool:
	if not _ok():
		return false
	step_id = "pousser"
	_show_spotlight(_zone_rect("etat"))
	await _speak(TXT_POUSSER_REEL if real else TXT_POUSSER_INFO)
	if not _ok():
		return false
	if real and _push_open():
		await _pause(POSE_PAUSE_S)
		if not _ok():
			return false
		if _push_open():
			_game._on_push_choice(false)  # Merlin encaisse (mêmes chemins que le joueur)
	await _wait_click()
	return _ok()


# ── Attentes & clics ───────────────────────────────────────────────────────────────────────────


func _until(pred: Callable) -> void:
	while not bool(pred.call()):
		await get_tree().process_frame


func _pause(s: float) -> void:
	var dl: int = Time.get_ticks_msec() + int(s * _Visual.motion() * 1000.0)
	while _ok() and Time.get_ticks_msec() < dl:
		await get_tree().process_frame


# Merlin parle : typewriter dans le bandeau + syllabes procédurales (parité merlin_game, allégé).
# Clic pendant la frappe = tout révéler (via _on_catcher_input). Poll d'état, zéro await de tween
# (leçon R148 : un tween tué/fini n'émet jamais `finished`).
func _speak(text: String) -> void:
	_click_armed = false
	_advance_req = false
	_reveal_req = false
	_set_caret(false)
	if _banner_text == null or not is_instance_valid(_banner_text):
		return
	_banner_text.text = "[center]%s[/center]" % text
	var n: int = _banner_text.get_total_character_count()
	_kill_tw()
	if _Visual.reduced_motion or n <= 0 or not _banner_text.is_inside_tree():
		_banner_text.visible_characters = -1  # l'information ne s'efface jamais (§23)
		return
	_banner_text.visible_characters = 0
	var dur: float = clampf(float(n) / TW_CPS, 0.6, 6.0)
	_tw = _banner_text.create_tween()
	_tw.tween_property(_banner_text, "visible_characters", n, dur)
	var sess: int = MerlinAudio.begin_voice()
	var next_tick: int = 0
	while _ok() and _tw != null and _tw.is_valid() and _tw.is_running():
		if _reveal_req:
			break
		var now: int = Time.get_ticks_msec()
		if now >= next_tick:
			next_tick = now + int(VOICE_TICK_S * 1000.0)
			MerlinAudio.play_voice_session(sess, "neutral")
		await get_tree().process_frame
	_kill_tw()
	if _banner_text != null and is_instance_valid(_banner_text):
		_banner_text.visible_characters = -1


# Caret armé : le prochain clic du catcher fait avancer l'étape.
func _wait_click() -> void:
	_click_armed = true
	_advance_req = false
	_set_caret(true)
	while _ok() and not _advance_req:
		await get_tree().process_frame
	_click_armed = false
	_set_caret(false)


func _on_catcher_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if _tw != null and _tw.is_valid():
		_reveal_req = true
	elif _click_armed:
		_advance_req = true
		MerlinAudio.play_sfx("button_tap")
	get_viewport().set_input_as_handled()


func _request_skip() -> void:
	if _done or _skip_req:
		return
	_skip_req = true
	blocking = false             # la main revient au joueur IMMÉDIATEMENT
	_set_overlay_visible(false)  # le teardown complet vit en fin de _run (aucun free sous coroutine)


# ── Spotlight & bandeau ────────────────────────────────────────────────────────────────────────


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


# Rect d'une zone passée par merlin_game (+ marge). « jauges » = union des 2 anneaux (M3 : la
# beat map vit entre les deux : le spotlight embrasse toute la ligne HUD).
func _zone_rect(key: String) -> Rect2:
	if key == "jauges":
		return _ctrl_rect("vie").merge(_ctrl_rect("corruption"))
	return _ctrl_rect(key)


func _ctrl_rect(key: String) -> Rect2:
	var c: Control = _zones.get(key) as Control
	if c == null or not is_instance_valid(c) or not c.is_inside_tree():
		var vp: Vector2 = _viewport_size()
		return Rect2(vp * 0.25, vp * 0.5)  # filet : le centre de l'écran
	return c.get_global_rect().grow(HOLE_PAD)


# I1 (revue design) : les 4 tuiles de verbe SEULES (le bouton Résoudre partage _action_bar :
# l'étape « verbes » ne doit pas l'encadrer). Relues duck-typé depuis _game._action_views.
func _verbs_rect() -> Rect2:
	var views: Variant = _game.get("_action_views") if _game != null and is_instance_valid(_game) else null
	var out: Rect2 = Rect2()
	var first: bool = true
	if views is Array:
		for v in (views as Array):
			if v is Control and is_instance_valid(v) and (v as Control).is_inside_tree():
				var r: Rect2 = (v as Control).get_global_rect()
				out = r if first else out.merge(r)
				first = false
	if first:
		return _ctrl_rect("etat")  # filet improbable : la ligne d'état
	return out.grow(HOLE_PAD)


# Spotlight : 4 rects assombris autour du trou + liseré GOLD pulsant + bandeau repositionné.
func _show_spotlight(hole: Rect2) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_set_overlay_visible(true)
	var vp: Vector2 = _viewport_size()
	var h: Rect2 = hole.intersection(Rect2(Vector2.ZERO, vp))
	if h.size.x <= 0.0 or h.size.y <= 0.0:
		h = Rect2(vp * 0.25, vp * 0.5)
	if _dim_rects.size() == 4:
		var top: ColorRect = _dim_rects[0]
		top.position = Vector2.ZERO
		top.size = Vector2(vp.x, h.position.y)
		var bottom: ColorRect = _dim_rects[1]
		bottom.position = Vector2(0.0, h.end.y)
		bottom.size = Vector2(vp.x, maxf(vp.y - h.end.y, 0.0))
		var left: ColorRect = _dim_rects[2]
		left.position = Vector2(0.0, h.position.y)
		left.size = Vector2(h.position.x, h.size.y)
		var right: ColorRect = _dim_rects[3]
		right.position = Vector2(h.end.x, h.position.y)
		right.size = Vector2(maxf(vp.x - h.end.x, 0.0), h.size.y)
	if _frame != null and is_instance_valid(_frame):
		_frame.position = h.position
		_frame.size = h.size
		_pulse_frame()
	_position_banner(h)


# Liseré GOLD pulsant (alpha 1.0 vers 0.45 en boucle). reduced_motion : statique, l'info reste.
func _pulse_frame() -> void:
	if _frame_tw != null and _frame_tw.is_valid():
		_frame_tw.kill()
	_frame_tw = null
	if _frame == null or not is_instance_valid(_frame):
		return
	_frame.modulate.a = 1.0
	if _Visual.reduced_motion or not _frame.is_inside_tree():
		return
	var half: float = _Visual.DUR_CARET_BLINK * _Visual.motion()
	_frame_tw = _frame.create_tween().set_loops()
	_frame_tw.tween_property(_frame, "modulate:a", 0.45, half).set_trans(Tween.TRANS_SINE)
	_frame_tw.tween_property(_frame, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)


# Le bandeau se place au-dessus OU au-dessous du trou (jamais dessus), centré, borné à l'écran.
func _position_banner(hole: Rect2) -> void:
	if _banner == null or not is_instance_valid(_banner):
		return
	var vp: Vector2 = _viewport_size()
	var x: float = (vp.x - BANNER_W) * 0.5
	var y: float
	if hole.get_center().y >= vp.y * 0.55:
		y = hole.position.y - BANNER_H - BANNER_MARGIN  # cible en bas : bandeau au-dessus
	else:
		y = hole.end.y + BANNER_MARGIN                  # cible en haut : bandeau au-dessous
	y = clampf(y, 12.0, vp.y - BANNER_H - 12.0)
	_banner.position = Vector2(x, y)
	_banner.size = Vector2(BANNER_W, BANNER_H)


func _set_overlay_visible(on: bool) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	if _root.visible == on:
		return
	_root.visible = on
	if on and not _Visual.reduced_motion and _root.is_inside_tree():
		_root.modulate.a = 0.0
		var t: Tween = _root.create_tween()
		t.tween_property(_root, "modulate:a", 1.0,
			_Visual.DUR_ZONE_FADE * _Visual.motion()).set_trans(Tween.TRANS_SINE)
	else:
		_root.modulate.a = 1.0


func _set_caret(on: bool) -> void:
	if _caret == null or not is_instance_valid(_caret):
		return
	if _caret_tw != null and _caret_tw.is_valid():
		_caret_tw.kill()
	_caret_tw = null
	if on:
		_caret.modulate.a = 0.65
		if not _Visual.reduced_motion and _caret.is_inside_tree():
			_caret_tw = _caret.create_tween().set_loops()
			_caret_tw.tween_property(_caret, "modulate:a", 0.18,
				_Visual.DUR_CARET_BLINK * _Visual.motion()).set_trans(Tween.TRANS_SINE)
			_caret_tw.tween_property(_caret, "modulate:a", 0.65,
				_Visual.DUR_CARET_BLINK * _Visual.motion()).set_trans(Tween.TRANS_SINE)
	else:
		_caret.modulate.a = 0.0


func _kill_tw() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


# ── Aides de jeu (duck-typées : un renommage côté jeu casse BRUYAMMENT, jamais de faux vert) ────


func _push_open() -> bool:
	if _game == null or not is_instance_valid(_game):
		return false
	var row: Node = _game.get("_push_row") as Node
	return bool(_game.get("_push_pending")) and row != null and is_instance_valid(row)


# La paire de démo de Merlin : tuile puis rune à MEILLEURE couverture des tags requis (I3 : la
# couverture complète n'est pas garantie par la main de départ : on prend le meilleur disponible).
func _pick_demo_pair() -> Array:
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run == null or _game == null or not is_instance_valid(_game):
		return []
	var situ: Variant = _game.get("_current_situation")
	var reqs: Array = []
	if situ is Dictionary:
		for r in ((situ as Dictionary).get("required_tags", []) as Array):
			reqs.append(_Tags.to_canon(str(r)))
	var acts: Array = run.get("actions") as Array
	var hand: Array = run.get("hand") as Array
	if acts.is_empty() or hand.is_empty():
		return []
	return [_best_cover(acts, reqs), _best_cover(hand, reqs)]


func _best_cover(cards: Array, reqs_canon: Array) -> Variant:
	var best: Variant = cards[0]
	var best_n: int = -1
	for c in cards:
		if c == null:
			continue
		var n: int = 0
		for t in (c.get("tags") as Array):
			if reqs_canon.has(_Tags.to_canon(str(t))):
				n += 1
		if n > best_n:
			best_n = n
			best = c
	return best


# ── Construction / teardown ────────────────────────────────────────────────────────────────────


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# 4 rects du spotlight : visuels purs (IGNORE), le verrou vit dans le catcher au-dessus.
	for i in 4:
		var r: ColorRect = ColorRect.new()
		r.color = _Visual.DIM_LIGHT
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(r)
		_dim_rects.append(r)
	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb: StyleBoxFlat = StyleBoxFlat.new()
	fsb.draw_center = false
	fsb.set_border_width_all(3)
	fsb.border_color = _Visual.GOLD
	fsb.set_corner_radius_all(10)
	_frame.add_theme_stylebox_override("panel", fsb)
	_root.add_child(_frame)
	# Bandeau parchemin : la voix de Merlin (INK sur CREAM, même grammaire que l'encart).
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", _Visual.cream_style())
	_root.add_child(_banner)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(col)
	_banner_text = RichTextLabel.new()
	_banner_text.bbcode_enabled = true
	_banner_text.fit_content = true
	_banner_text.scroll_active = false
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_banner_text.add_theme_color_override("default_color", _Visual.INK)
	_banner_text.add_theme_font_size_override("normal_font_size", _Visual.FS_CAPTION)
	_banner_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_banner_text)
	_caret = _Visual.make_label(_Visual.GOLD_DARK, _Visual.FS_HINT)
	_caret.text = "▮ cliquer pour continuer"
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.modulate.a = 0.0
	col.add_child(_caret)
	# Verrou d'input : plein écran, STOP : tout clic (trou compris) = révéler / continuer.
	_catcher = Control.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	_root.add_child(_catcher)
	# « Passer le guide » : discret, coin bas-droit, ≥44 px (pilier TACTILE), AU-DESSUS du catcher.
	_skip_btn = Button.new()
	_skip_btn.text = "Passer le guide"
	_skip_btn.custom_minimum_size = Vector2(190, 48)
	_skip_btn.add_theme_font_size_override("font_size", 16)
	_Visual.apply_button_da(_skip_btn)
	_Visual.connect_button_feedback(_skip_btn)
	_skip_btn.self_modulate.a = 0.85  # self_modulate : le hover-tint du feedback tweene modulate
	_skip_btn.pressed.connect(_request_skip)
	_root.add_child(_skip_btn)
	var vp: Vector2 = _viewport_size()
	_skip_btn.position = Vector2(vp.x - 214.0, vp.y - 62.0)


# Teardown UNIQUE, en fin de _run (jamais de queue_free sous une coroutine en vol).
func _teardown(completed: bool) -> void:
	if _done:
		return
	_done = true
	_active = false
	blocking = false
	step_id = "fin"
	_kill_tw()
	if _frame_tw != null and _frame_tw.is_valid():
		_frame_tw.kill()
	if _caret_tw != null and _caret_tw.is_valid():
		_caret_tw.kill()
	# Le guide couvre tout ce que les hints A/B enseignaient : consommés (jamais redondants).
	# NB : assigner une static var À TRAVERS un preload const est un Parse Error (« Cannot assign
	# a new value to a constant ») : l'écriture passe par le nom de classe (pattern merlin_game).
	MerlinVisual.tuto_hint_a_done = true
	MerlinVisual.tuto_hint_b_done = true
	_Visual.save_prefs()
	_Chronicle.mark_tuto_done()  # même écourté, le guide a été vu : il ne se relance jamais seul
	finished.emit(completed)
	if _root != null and is_instance_valid(_root) and _root.visible \
			and _root.is_inside_tree() and not _Visual.reduced_motion:
		var t: Tween = _root.create_tween()
		t.tween_property(_root, "modulate:a", 0.0,
			_Visual.DUR_ZONE_FADE * _Visual.motion()).set_trans(Tween.TRANS_SINE)
		t.tween_callback(queue_free)
	else:
		queue_free()
