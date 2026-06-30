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
const GAMEPLAY_MUSIC: String = "res://music/gameplay/gameplay_calm.wav"
const GAMEPLAY_MUSIC_FADE: float = 4.0

var _life_gauge: MerlinRingGauge
var _corr_gauge: MerlinRingGauge
var _beat_map: MerlinBeatMap
var _scene_art: MerlinSceneArt
var _situ_panel: PanelContainer       # encart central : porte intro/situation/issue
var _situ_sb: StyleBoxFlat            # style de l'encart (bordure teintée par phase — signal de transition)
var _situation_text: RichTextLabel
var _hand_box: Control
var _combo_box: HBoxContainer
var _combo_panel: PanelContainer  # zone combinaison/preview/résolution — visible SEULEMENT en phase de choix
var _resolve_btn: Button
var _overlay: Panel
var _overlay_lbl: Label
var _caret: Label  # marqueur clignotant « cliquer pour continuer » (fin de phrase, UX boîte de dialogue)
var _caret_tw: Tween
var _can_advance: bool = false  # true quand l'issue est entièrement écrite → clic = beat suivant

var _current_situation: Dictionary = {}
var _combo: Array = []
var _state: int = 0  # 0=loading 1=playing 2=resolving
var _eye_cursor_acc: float = 0.0  # v10.20 — throttle du suivi curseur de l'œil-lune (yeux de Merlin)
var _cap_last_ms: int = 0         # dev capture in-game
var _cap_n: int = 0
var _tw_target: RichTextLabel = null  # v10.20 — cible du typewriter (situation, qui porte aussi l'issue R128)
# v10.21 (user 2026-06-30) — l'issue s'écrit À LA SUITE de la situation, dans le MÊME fil (_situation_text).
# _res_block ne porte plus que la VIGNETTE d'effet, qui apparaît SOUS le texte APRÈS le typewriter de l'issue.
var _res_block: VBoxContainer = null
var _effect_vignette: HBoxContainer = null
var _pending_res: Dictionary = {}    # res/degré mémorisés au resolve → fade-in vignette post-typewriter
var _pending_degree: String = ""
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
var _tw_tick_count: int = 0
var _quill_tw: Tween
var _deal_pending: bool = false  # déclenche l'anim de distribution au prochain _layout_fan
var _life_tw: Tween  # tween de remplissage de l'anneau vie (tué avant un nouveau → pas de snap arrière)
var _corr_tw: Tween
var _situ_tw: Tween  # fondu de l'encart au nouveau beat (tué avant réutilisation → pas de course de tweens)
var _prose_tw: Tween  # v10.15 : prose breathing loop (killed before next typewriter)
var _situ_rest_y: float = 0.0  # v10.15 : canonical Y of _situ_panel (for slide-up anchoring)
var _encart_phase_tw: Tween  # teinte de la bordure de l'encart (neutre situation ↔ couleur du degré à l'issue)

# v10.11/12 (user 2026-06-07) — Map du chemin (coin droit) + Draft « 1 carte sur 3 » aux beats clés.
var _pending_draft: bool = false         # armé en résolution (réussite/éclatante, beats restants) → draft à l'avance
var _draft_layer: Control = null         # overlay modal du draft
var _draft_pick: MerlinCard = null       # carte choisie (null = passer)
var _draft_done_flag: bool = false       # le joueur a tranché (choix ou passer)

# v10.13.1 — juice pack 1 (§21) : gardes d'animation.
var _beat_transition: bool = false  # review HIGH-1 : anti double-fire de _present_current_beat (voile)
var _ghost_in_flight: bool = false  # le pop_in du compact attend l'arrivée du ghost (cascade Wave2)
var _quest_shown: int = -1          # v10.14 : quête affichée (frontières de chaîne, map par quête)

# v10.13.1 (R75/R64) — glitch corruption par paliers : 0-4 sain · 5-9 trouble · 10-14 emprise ·
# 15+ dissolution. Caps cascade Wave1 : 0.50/0.25 permanents max (lisibilité §23) ; burst ≤0.5s.
const GLITCH_LEVELS: Array = [
	{"i": 0.0, "d": 0.0},    # sain
	{"i": 0.15, "d": 0.10},  # trouble
	{"i": 0.35, "d": 0.20},  # emprise (+ tremblement bref à l'arrivée de prose)
	{"i": 0.50, "d": 0.25},  # dissolution (cap permanent)
]
var _glitch_overlay: ColorRect = null
var _glitch_mat: ShaderMaterial = null
var _glitch_tw: Tween = null
var _corruption_palier: int = 0
var _corr_dot: Panel = null  # pastille statique VIOLET (R74/R75 : l'info survit à reduce-motion)
var _glitch_i: float = 0.0   # valeurs courantes des uniforms (source des tween_method — le
var _glitch_d: float = 0.0   # tween_property sur shader_parameter/* ne les voit pas toujours)

# v10.13 (Phase B) — interstitiel « Merlin raconte » (B3), hint intro (B2), sceau de degré (B9).
var _interstitial_open: bool = false           # B3 : interstitiel actif (entre Accept et Beat 1)
var _interstitial_wait: MerlinWaitStage = null # B3 : attente animée en cours (skippée par autoplay)
var _intro_reveal_tw: Tween = null             # B2 : typewriter du pop-up d'intro (kill au clic)
var _degree_seal: Control = null               # B9 : sceau circulaire de degré (haut-droit encart)
var _draft_open_ms: int = 0                    # F2 : anti pick-aveugle pendant le deal du draft


# v10.13 (Fix 0) — garde canonique post-await : la scène est-elle toujours « fraîche » ?
# Toute coroutine qui reprend après un await DOIT vérifier _fresh(ep) avant de toucher l'UI.
func _fresh(ep: int) -> bool:
	return ep == _scene_epoch and is_inside_tree()


func _process(delta: float) -> void:
	_maybe_game_capture()  # dev (MERLIN_CAPTURE_DIR) : capture in-game pour QA
	# v10.20 — l'ŒIL-LUNE (yeux de Merlin dans la lune) suit le CURSEUR : le joueur manipule ses cartes
	# en bas → les yeux le regardent. Throttle 30 fps. Suivi off en reduced_motion (l'humeur reste).
	if _scene_art == null or MerlinVisual.reduced_motion:
		return
	_eye_cursor_acc += delta
	if _eye_cursor_acc >= 1.0 / 30.0:
		_eye_cursor_acc = 0.0
		var rect: Rect2 = _scene_art.get_global_rect()
		if rect.size.x > 4.0:
			_scene_art.set_cursor(get_global_mouse_position() - rect.position, true)


# Dev (env MERLIN_CAPTURE_DIR) : capture périodique de l'écran in-game (QA). Jamais active en prod.
func _maybe_game_capture() -> void:
	var dir: String = OS.get_environment("MERLIN_CAPTURE_DIR")
	if dir.is_empty():
		return
	var iv_ms: int = maxi(100, int(OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS")) if OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS") != "" else 700)
	var cap_max: int = maxi(1, int(OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES")) if OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES") != "" else 30)
	var now: int = Time.get_ticks_msec()
	if now - _cap_last_ms < iv_ms or _cap_n >= cap_max:
		return
	_cap_last_ms = now
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	if img.get_width() > 720:
		var r: float = 720.0 / float(img.get_width())
		img.resize(720, int(float(img.get_height()) * r), Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png("%s/game_%04d.png" % [dir, _cap_n])
	_cap_n += 1


func _ready() -> void:
	_build_ui()
	_setup_gameplay_music()
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


func _setup_gameplay_music() -> void:
	if not ResourceLoader.exists(GAMEPLAY_MUSIC):
		return
	var stream: AudioStream = load(GAMEPLAY_MUSIC)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.format != AudioStreamWAV.FORMAT_IMA_ADPCM:
			var bps: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var ch: int = 2 if wav.stereo else 1
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / float(bps * ch))
	MerlinAudio.play_music(stream, GAMEPLAY_MUSIC_FADE)


func _present_current_beat() -> void:
	var run: Node = get_node("/root/MerlinRun")
	if run.ended or _beat_transition:
		return  # review HIGH-1 : jamais deux transitions concurrentes (double-tap, races futures)
	# v10.13.1 (§21 `veil`, cascade Wave1/playtester) — voile de transition : couvre le swap du
	# contenu. COROUTINE appelée fire-and-forget par tous les appelants (_begin/_advance_to_next/
	# _end_interstitial) — AUCUN await ajouté dans _advance_to_next. Le voile est IGNORE : aucun
	# clic volé, l'autoplay (appels directs) n'est jamais bloqué. Skip inutile : 0.20s opaque max,
	# le typewriter (skippable) démarre sous le voile sortant.
	_beat_transition = true
	var veil: ColorRect = MerlinFx.beat_veil(self)
	var vin: Tween = veil.create_tween()
	vin.tween_property(veil, "modulate:a", 0.85, MerlinVisual.DUR_VEIL_IN * MerlinVisual.motion())
	await vin.finished
	_beat_transition = false
	if not is_inside_tree():
		return  # scène quittée pendant le voile (le voile, enfant de la scène, part avec elle)
	if run.ended:
		veil.queue_free()
		return
	# Sortie fire-and-forget : le contenu (swappé ci-dessous) se révèle sous le voile qui se lève.
	var vout: Tween = veil.create_tween()
	vout.tween_property(veil, "modulate:a", 0.0, MerlinVisual.DUR_VEIL_OUT * MerlinVisual.motion())
	vout.tween_callback(veil.queue_free)
	_interstitial_open = false  # v10.13 (B3) : défense — l'interstitiel est forcément clos ici
	_clear_degree_seal()        # v10.13 (B9) : le sceau du beat précédent ne survit pas au suivant
	# v10.21 — reset au nouveau beat : situation pleine opacité, vignette d'effet cachée (l'issue R128 vit
	# dans _situation_text, réécrit par _show_situation au beat suivant).
	if _res_block != null:
		_res_block.visible = false
	if _situation_text != null:
		_situation_text.modulate.a = 1.0
	# v10.14 — frontière de quête (chaîne) : la map repart sur la quête courante et le fil
	# narratif bascule (begin_quest : nouvel arc, last_gist conservé). Au resume (was == -1,
	# beat > 0), begin_quest restaure aussi le fil de la quête en cours.
	var cur_b: Dictionary = run.current_beat()
	var local_i: int = int(cur_b.get("qn", run.beat_index + 1)) - 1
	var bq: int = int(cur_b.get("quest", 0))
	if bq != _quest_shown:
		var was: int = _quest_shown
		_quest_shown = bq
		if _beat_map != null:
			_beat_map.setup(int(cur_b.get("qtotal", int(run.scenario.get("total", 5)))))
		if (was >= 0 and bq != was) or (was == -1 and run.beat_index > 0):
			get_node("/root/MerlinScenario").begin_quest(run.scenario, bq)
	if _beat_map != null:  # v10.12 : avance « tu es ici » (index PAR QUÊTE depuis v10.14)
		if local_i > 0:
			_beat_map.animate_advance(local_i)  # v10.13 (B4) : le connecteur POUSSE + pop du halo
		else:
			_beat_map.set_current(local_i)
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
	# v10.14 (ramification v1) — découverte AU beat : le chemin a basculé suite au revers
	# précédent. Indice micro-narratif d'UNE phrase (Wave2 : jamais d'explication mécanique)
	# + déviation marquée sur la map. Le beat basculé est déjà persisté (swap avant save, R108).
	if bool(beat.get("swapped", false)):
		_current_situation["narration"] = "Le sentier se déroba sous ses pas — un autre chemin s'imposa.\n\n" \
			+ str(_current_situation.get("narration", ""))
		if _beat_map != null:
			_beat_map.mark_draft()
	get_node("/root/MerlinScenario").invalidate_resolution()  # v10.4 : cache issue propre à chaque beat
	_hide_overlay()
	_combo.clear()
	# v10.10 (user 2026-06-06) : la SITUATION s'affiche SEULE dans l'encart central ; les cartes ne
	# montent qu'à la fin du typewriter (_on_typewriter_done state==1). Cartes cachées d'ici là.
	_set_choice_ui(false)
	# Signal de transition (user 2026-06-07) : bordure neutre + fondu de l'encart au nouveau beat.
	_set_encart_phase(MerlinVisual.INK_DIM)
	if _situ_panel != null:
		_situ_panel.modulate.a = 0.45
		# v10.15 — Slide-up : l'encart monte de 12px en fondant (situation « arrive »).
		# Ancré sur _situ_rest_y pour éviter le drift si le tween précédent est interrompu.
		if _situ_rest_y == 0.0:
			_situ_rest_y = _situ_panel.position.y
		_situ_panel.position.y = _situ_rest_y + 12.0
		if _situ_tw != null and _situ_tw.is_valid():
			_situ_tw.kill()
		_situ_tw = _situ_panel.create_tween().set_parallel(true)
		_situ_tw.tween_property(_situ_panel, "modulate:a", 1.0, 0.22)
		var slide_dur: float = MerlinVisual.DUR_SLIDE_UP * MerlinVisual.motion()
		_situ_tw.tween_property(_situ_panel, "position:y", _situ_rest_y, slide_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_situation(_current_situation)
	_state = 1


func _show_situation(situ: Dictionary, animate: bool = true) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var btype: String = str(situ.get("type", ""))
	if _scene_art != null:
		_scene_art.set_beat(btype)  # le décor reflète le type de beat (figure si Rencontre/Climax/Dilemme)
		var sc_f: Node = get_node_or_null("/root/MerlinScenario")  # Wave C : décor teinté par la faction de la run
		if sc_f != null and sc_f.has_method("current_faction"):
			_scene_art.set_faction(str(sc_f.current_faction()))
		_scene_art.set_eye_mood(MerlinSceneArt.mood_for_text(str(situ.get("narration", ""))))  # v10.20 : œil-lune réagit
	_typewriter("[center]" + str(situ.get("narration", "")) + "[/center]", animate)
	# v10.21 — feedforward « Ce lieu réclame » RETIRÉ (user 2026-06-30) : immersion narrative ; l'issue continue le fil.
	# v10.13.1 (R75 palier emprise+) : tremblement BREF du cadre à l'ARRIVÉE de la prose —
	# jamais pendant la lecture (Wave1 : amplitude ≤2px), off en reduce-motion (pastille = info).
	if animate and _corruption_palier >= 2 and not MerlinVisual.reduced_motion and _situ_panel != null:
		MerlinFx.shake(_situ_panel, 2.0, 0.2)


func _render_hand(deal: bool = false) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var wanted: Array = []
	for card in run.hand:
		if not _combo.has(card):
			wanted.append(card)
	# v10.13.1 (§21 `fast`) — RÉUTILISE les vues : l'éventail REFLOW en douceur au lieu de snapper
	# (rebuild). Vues en trop : sortie discard_out si visibles (sinon libération immédiate — la
	# carte partie au combo est déjà remplacée à l'écran par son ghost).
	var keep: Dictionary = {}
	for c in _hand_box.get_children():
		if c is MerlinCardView and not c.is_queued_for_deletion():
			var cv: MerlinCardView = c
			if cv._discarding:
				continue  # review HIGH-2 : une vue en sortie discard ne se réutilise JAMAIS
			if wanted.has(cv.card) and not keep.has(cv.card):
				keep[cv.card] = cv
			elif cv.visible:
				cv.discard_out()
			else:
				cv.queue_free()
	for card in wanted:
		if not keep.has(card):
			var cv: MerlinCardView = MerlinCardView.new()
			_hand_box.add_child(cv)
			cv.setup(card)
			cv.card_clicked.connect(_on_hand_card)
			keep[card] = cv
	for i in wanted.size():  # ordre des enfants = ordre de la main (recouvrement stable)
		_hand_box.move_child(keep[wanted[i]], i)
	_deal_pending = deal  # anime la distribution seulement sur une main fraîche (beat/résolution)
	call_deferred("_layout_fan")


# Dispose la main en éventail dynamique : cartes centrées, arc + rotation depuis le centre.
func _layout_fan() -> void:
	if _hand_box == null:
		return
	var cards: Array = []
	for c in _hand_box.get_children():
		if c is MerlinCardView and not c.is_queued_for_deletion():
			cards.append(c)  # v10.13.1 : les vues en cours de discard_out ne comptent plus
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
		cv.set_fan_transform(Vector2(x, y), rot, not _deal_pending)  # deal → snap, deal_in anime
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
			# v10.13.1 : si un ghost vole vers le combo, le compact POP à son arrivée (DUR_UI).
			var delay: float = MerlinVisual.DUR_UI * MerlinVisual.motion() if _ghost_in_flight else 0.0
			cv.pop_in(delay)  # seule la carte la plus récente fait son pop
	_update_preview()


func _on_hand_card(card: MerlinCard) -> void:
	# v10.6 (user 2026-06-06) — le geste canonique est un COMBO de 2 cartes (la 1ère = action
	# principale, la 2e = modificateur). On bloque au-delà de 2 (plus de trio).
	if _state != 1 or _combo.size() >= 2 or _combo.has(card):
		return
	# v10.13.1 (§21 `ui`) — ghost de vol main→combo : node INDÉPENDANT (cascade Wave1) ; la vraie
	# vue disparaît immédiatement (le ghost la remplace à l'écran). AUCUN await : la main reste
	# cliquable pendant le vol (pilier FACILE).
	var src: MerlinCardView = _find_card_view(_hand_box, card)
	_combo.append(card)
	if src != null and _combo_box != null and _combo_box.is_inside_tree():
		var idx: int = _combo.size() - 1
		var to_pos: Vector2 = _combo_box.global_position + Vector2(
			float(idx) * (MerlinCardView.CARD_SIZE_COMPACT.x + 10.0) + MerlinCardView.CARD_SIZE_COMPACT.x * 0.5,
			MerlinCardView.CARD_SIZE_COMPACT.y * 0.5)
		MerlinFx.ghost_flight(self, src.get_global_rect(), to_pos, COL_GOLD)
		src.visible = false  # remplacée par le ghost — _render_hand la libère
		_ghost_in_flight = true  # le compact POP à l'arrivée du ghost (pas avant — cascade Wave2)
	_render_hand()   # la carte quitte l'éventail (slot vidé)
	_render_combo()
	_ghost_in_flight = false


func _on_combo_card(card: MerlinCard) -> void:
	if _state != 1:
		return
	# v10.13.1 — ghost retour combo→main (vers le centre de l'éventail).
	var src: MerlinCardView = _find_card_view(_combo_box, card)
	_combo.erase(card)
	if src != null and _hand_box != null and _hand_box.is_inside_tree():
		var to_pos: Vector2 = _hand_box.global_position + _hand_box.size * 0.5
		MerlinFx.ghost_flight(self, src.get_global_rect(), to_pos, COL_GOLD)
		src.visible = false
	_render_hand()   # la carte revient dans l'éventail
	_render_combo()


# Retrouve la vue d'une carte dans un conteneur (main ou combo) — null si absente/libérée.
func _find_card_view(box: Control, card: MerlinCard) -> MerlinCardView:
	if box == null:
		return null
	for c in box.get_children():
		if c is MerlinCardView and not c.is_queued_for_deletion() and (c as MerlinCardView).card == card:
			return c
	return null


func _update_preview() -> void:
	# v10.6 : le geste canonique = COMBO de 2 cartes. La résolution n'est active qu'à 2 cartes.
	var n: int = _combo.size()
	if n < 2:
		_resolve_btn.disabled = true
		return
	var reqs: Array = _current_situation.get("required_tags", [])
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [], int(_current_situation.get("die", 0)))
	var was_disabled: bool = _resolve_btn.disabled
	_resolve_btn.disabled = false
	if was_disabled and _resolve_btn.visible:
		MerlinAudio.play_sfx("draft_reveal")
		_pop(_resolve_btn, 1.15)
		_combo_complete_pulse()
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
	var res: Dictionary = MerlinResolution.resolve(reqs, _combo, [], int(_current_situation.get("die", 0)))
	var played_cards: Array = _combo.duplicate()  # cartes (objets) → interprétation LLM de la combinaison
	var situ: Dictionary = _current_situation.duplicate(true)  # fige la situation (LLM toujours pertinent)

	# v10.20 — capture des Δ jauges (net : coût + effets + résolution) pour la VIGNETTE d'effet. user 2026-06-29.
	var int_before: int = int(run.get("integrite"))
	var corr_before: int = int(run.get("corruption"))
	run.play_and_discard(_combo)
	run.apply_card_effects(played_cards)  # v10.11 : effets actifs (Rare+) AVANT le check de mort (un HEAL peut sauver)
	run.apply_resolution(res)
	res["integrite_delta"] = int(run.get("integrite")) - int_before
	res["corruption_delta"] = int(run.get("corruption")) - corr_before
	var fx_effects: Array = []  # effets actifs déclenchés (HEAL/PURGE/DRAW) pour les glyphes de la vignette
	for c in played_cards:
		if c is MerlinCard and str(c.effect_type) != "":
			fx_effects.append(str(c.effect_type))
	res["fx_effects"] = fx_effects
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
	_resolve_btn.visible = false
	_can_advance = false    # « avancer » (clic) seulement quand l'issue est entièrement écrite

	# v10.2 — Animation cinématique de fusion AVANT la prose. Pendant ce temps la pré-génération
	# LLM (lancée à la pose, _update_preview) continue → masque la latence (user 2026-06-06).
	# v10.13 (A2) : la fusion vit dans MerlinFx (layer autonome — tweens liés à lui, auto-queue_free).
	# Les card views du combo sont capturées ICI puis reparentées dans le layer par MerlinFx ;
	# le prédicat `ready` injecte is_resolution_ready (le sustain ne lit plus /root/MerlinScenario).
	var vues_du_combo: Array = []
	for c in _combo_box.get_children():
		if c is MerlinCardView:
			vues_du_combo.append(c)
	if _scene_art != null:
		_scene_art.set_thinking(true)  # R128 : Merlin « réfléchit » (halo lune accéléré) pendant la fusion + l'attente LLM
	var fx: MerlinFx = MerlinFx.play(self, res, played_cards, vues_du_combo, func() -> bool: return sc.is_resolution_ready(played_cards, res))
	await fx.run()
	if _scene_art != null and is_instance_valid(_scene_art):
		_scene_art.set_thinking(false)  # l'issue est prête → Merlin cesse de réfléchir, l'issue s'écrit
	if not _fresh(ep):
		return  # scène quittée pendant la fusion (sécurité epoch + tree-check)
	if _scene_art != null:
		match deg:
			"eclatante":
				_scene_art.flash_moon()
				_scene_art.sway_trees()
			"reussite":
				_scene_art.flash_moon()
			"partiel":
				_scene_art.thicken_mist()
			"echec":
				_scene_art.dim_moon()
				_scene_art.thicken_mist()
				_scene_art.sway_trees()

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
	sc.note_outcome(res, situ, played_cards)  # v10.20.1 : gist SPÉCIFIQUE (action réelle) + pont vers la situation suivante
	run.summary = prose
	_show_resolution(res, prose, true)
	# v10.13 (Fix 6) : PLUS de save ici — il persistait les jauges post-résolution avec un beat_index
	# non avancé → la reprise REJOUAIT le beat (coûts double-appliqués). Save unique dans _advance_to_next.


# === v10.13 (A2) — L'animation de fusion (4 phases + sustain skippable) vit dans MerlinFx ===
# scripts/game/merlin_fx.gd : consts FUSION_* / VIGNETTE_SHADER_CODE / TAG_NOUNS / DEGREE_ECHO,
# _fusion_expression, run() (Gather→Fuse→Burst→Expression + sustain), spark_wave public, shake static.


func _show_resolution(res: Dictionary, narration: String, animate: bool = true) -> void:
	var degree: String = str(res["degree"])
	var deg_col: Color = _degree_color(degree)
	_set_encart_phase(deg_col)  # bordure encart = couleur du degré (feedback émotionnel, user 2026-06-07)
	# v10.21 (user 2026-06-30, R128) : l'issue s'écrit À LA SUITE de la situation, dans le MÊME fil de prose —
	# la situation reste PLEINE (plus d'estompage 0.55), plus de filet or. La vignette d'effet (degré + Δ jauges)
	# apparaît SOUS le texte APRÈS le typewriter (différée → _on_typewriter_done via _pending_res/_pending_degree).
	_pending_res = res
	_pending_degree = degree
	if degree == "echec" and not MerlinVisual.reduced_motion and _situ_panel != null:
		MerlinFx.shake(_situ_panel, 4.0, MerlinVisual.DUR_ENCART_TINT * MerlinVisual.motion())  # l'échec se SENT (B9)
	_play_seal_audio(degree)  # stinger de degré (seal_stamp + stinger)
	# Humeur de l'œil-lune selon l'issue : échec → rouge, éclatante → jaune, sinon depuis le texte.
	if _scene_art != null:
		var mood: String = "angry" if degree == "echec" else ("surprise" if degree == "eclatante" else MerlinSceneArt.mood_for_text(narration))
		_scene_art.set_eye_mood(mood)
	# Texte COMBINÉ : ce qui est RÉELLEMENT affiché (situation, éventuellement enrichie) + l'issue, à la suite.
	# _typewriter(from_chars = longueur situation) → seule l'issue se révèle, la situation reste écrite.
	var cur: String = _situation_text.text
	var situ_chars: int = _situation_text.get_total_character_count()
	var combined: String
	if cur.ends_with("[/center]"):
		combined = cur.substr(0, cur.length() - 9) + "\n\n%s[/center]" % narration  # 9 = len("[/center]")
	else:
		combined = "[center]%s\n\n%s[/center]" % [cur, narration]
	_typewriter(combined, animate, _situation_text, situ_chars)


# v10.20 — Vignette d'effet (sous le filet) : badge de degré + Δ jauges + glyphes d'effet de carte. Fondu d'entrée.
func _build_effect_vignette(res: Dictionary, degree: String) -> void:
	if _effect_vignette == null:
		return
	for c in _effect_vignette.get_children():
		c.queue_free()
	var badge: Panel = Panel.new()
	badge.custom_minimum_size = Vector2(58, 58)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsb: StyleBoxFlat = StyleBoxFlat.new()
	bsb.bg_color = _degree_color(degree)
	bsb.set_corner_radius_all(29)
	badge.add_theme_stylebox_override("panel", bsb)
	var blbl: Label = Label.new()
	blbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	blbl.text = str(DEGREE_SEAL_LABEL.get(degree, "RÉUSSITE"))
	blbl.add_theme_color_override("font_color", MerlinVisual.CREAM)
	blbl.add_theme_font_size_override("font_size", 11)
	blbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	blbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(blbl)
	_effect_vignette.add_child(badge)
	var di: int = int(res.get("integrite_delta", 0))
	var dc: int = int(res.get("corruption_delta", 0))
	if di != 0:
		_effect_vignette.add_child(_vignette_chip("Intégrité %+d" % di, MerlinVisual.GREEN if di > 0 else MerlinVisual.VIOLET))
	if dc != 0:
		_effect_vignette.add_child(_vignette_chip("Corruption %+d" % dc, MerlinVisual.VIOLET if dc > 0 else MerlinVisual.GREEN))
	for e in res.get("fx_effects", []):
		match str(e):
			"HEAL": _effect_vignette.add_child(_vignette_chip("✚ Soin", MerlinVisual.EFFECT_HEAL))
			"PURGE": _effect_vignette.add_child(_vignette_chip("❖ Purge", MerlinVisual.EFFECT_PURGE))
			"DRAW": _effect_vignette.add_child(_vignette_chip("✦ Pioche", MerlinVisual.EFFECT_DRAW))
	_effect_vignette.modulate.a = 0.0
	_effect_vignette.create_tween().tween_property(_effect_vignette, "modulate:a", 1.0, MerlinVisual.DUR_SEAL_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)


func _vignette_chip(text: String, col: Color) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.18)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = col
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


# v10.13 (B9) — Sceau de degré : cercle flat (fond = MerlinVisual.degree_color), libellé CREAM,
# slam scale 2.2 → 1.0 (TRANS_BACK 0.3s) en haut-droit de l'encart ; micro-secousse si échec.
# Décalé du bord droit pour ne pas chevaucher la map CHEMIN. Nettoyé à _present_current_beat.
const DEGREE_SEAL_LABEL: Dictionary = {
	"echec": "ÉCHEC", "partiel": "PARTIEL", "reussite": "RÉUSSITE", "eclatante": "ÉCLATANTE",
}
const SEAL_D: float = 96.0  # diamètre du sceau (≥44 px — non cliquable mais lisible)


func _slam_degree_seal(degree: String) -> void:
	_clear_degree_seal()
	if _situ_panel == null:
		return
	var seal: Panel = Panel.new()
	seal.custom_minimum_size = Vector2(SEAL_D, SEAL_D)
	seal.size = Vector2(SEAL_D, SEAL_D)
	seal.pivot_offset = Vector2(SEAL_D, SEAL_D) * 0.5
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.z_index = 60
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = MerlinVisual.degree_color(degree)
	sb.set_corner_radius_all(int(SEAL_D * 0.5))  # cercle plein flat (DA : zéro dégradé)
	seal.add_theme_stylebox_override("panel", sb)
	var lbl: Label = Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = str(DEGREE_SEAL_LABEL.get(degree, "RÉUSSITE"))
	lbl.add_theme_color_override("font_color", MerlinVisual.CREAM)
	lbl.add_theme_font_size_override("font_size", 16)  # §21.5 : minimum 16px (audit ux_flow T1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(lbl)
	add_child(seal)
	seal.global_position = _situ_panel.global_position + Vector2(_situ_panel.size.x - SEAL_D - 24.0, 14.0)
	_degree_seal = seal
	seal.scale = Vector2(2.2, 2.2)
	seal.modulate.a = 0.0
	var tw: Tween = seal.create_tween().set_parallel(true)
	tw.tween_property(seal, "scale", Vector2.ONE, MerlinVisual.DUR_SEAL_POP * MerlinVisual.motion()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(seal, "modulate:a", 1.0, MerlinVisual.DUR_SEAL_FADE * MerlinVisual.motion())
	if degree == "echec" and not MerlinVisual.reduced_motion:
		MerlinFx.shake(_situ_panel, 4.0, MerlinVisual.DUR_ENCART_TINT * MerlinVisual.motion())  # micro-secousse : l'échec se SENT (B9)
	_play_seal_audio(degree)  # v10.13.1 (§22, Wave1) : le sceau SONNE — seal_stamp + stinger


func _play_seal_audio(degree: String) -> void:
	MerlinAudio.play_stinger(degree)


func _clear_degree_seal() -> void:
	if _degree_seal != null and is_instance_valid(_degree_seal):
		_degree_seal.queue_free()
	_degree_seal = null


func _advance_to_next() -> void:
	_set_caret(false)
	_can_advance = false
	_clear_degree_seal()  # audit ux_flow M2 : le sceau du beat résolu ne flotte pas sur le modal de draft
	var run: Node = get_node("/root/MerlinRun")
	# Wave D — offrande du PILIER au beat « Rencontre » (1×/run, INDÉPENDANTE du degré) : le PNJ tend une carte
	# signée par sa nature. REMPLACE le draft standard ce beat. current_beat() = le beat JUSTE résolu (advance_beat
	# n'a pas encore tourné). Le flag pilier_offering_done (posé à l'ouverture, persisté) garantit l'unicité au resume.
	if str(run.current_beat().get("type", "")) == "Rencontre" and not run.pilier_offering_done and not run.ended:
		var pk: String = _current_offer_pilier()
		if pk != "":
			_pending_draft = false  # l'offrande du pilier remplace le draft standard ce beat
			_scene_epoch += 1
			await _present_pilier_offering(pk)
			if not is_inside_tree():
				return
	# v10.11 — Draft « 1 carte sur 3 » aux beats clés, AVANT de passer au beat suivant.
	if _pending_draft:
		_pending_draft = false
		_scene_epoch += 1  # v10.13 (Fix 10) : tout enrichissement LLM en vol ne s'écrit pas sous le modal
		await _present_draft()
		if not is_inside_tree():
			return
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


# === Wave D — Offrande du pilier (modal de draft réutilisé, titre thémé par le PNJ) ===

# Pilier qui fait l'offrande : le pilier de faction, SAUF si le wildcard L'Enfant est présent (il surcharge).
func _current_offer_pilier() -> String:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return ""
	var pk: String = str(sc.current_pilier()) if sc.has_method("current_pilier") else ""
	if sc.has_method("current_pilier2") and str(sc.current_pilier2()) == "enfant":
		pk = "enfant"  # le wildcard Enfant fait l'offrande quand présent (exception inquiétante)
	return pk


# Titre + sous-titre du modal, signés par la nature du PNJ (le « piège »/« tentation » est dans le TON, pas une stat).
func _pilier_offer_text(pilier_key: String) -> Dictionary:
	match pilier_key:
		"choeur":
			return {"title": "Le Chœur des Druides t'offre un présent", "sub": "Un don de la forêt — sans prix, sans ombre."}
		"etre":
			return {"title": "L'Être Indéfinissable te propose un pacte", "sub": "Un pouvoir réel — contre une part de toi."}
		"compagnon":
			return {"title": "Le Compagnon te tend une carte", "sub": "Sa main est chaude. Ce qu'elle coûte l'est moins."}
		"chevalier":
			return {"title": "Le Chevalier déchu te confie une lame", "sub": "L'acier reste tranchant, même terni."}
		"enfant":
			return {"title": "L'Enfant te montre ce qu'il a trouvé", "sub": "« C'est pour toi », dit-il en souriant."}
	return {"title": "Une voie s'offre à toi — choisis une carte", "sub": "Elle rejoint ton grimoire."}


# Présente l'offrande signée. Calque exact de _present_draft (mêmes gardes structurelles, même cycle de modal),
# mais cartes = banque du pilier et titre thémé. Flag d'unicité posé à l'OUVERTURE (résiste resume/replay).
func _present_pilier_offering(pilier_key: String) -> void:
	var run: Node = get_node("/root/MerlinRun")
	run.pilier_offering_done = true  # AVANT le filtre vide : même un skip (banque épuisée) ne re-tente jamais
	var choices: Array = run.pilier_offering(pilier_key, 2)
	if choices.is_empty():
		return  # tout déjà possédé → pas de modal vide
	_draft_pick = null
	_draft_done_flag = false
	var txt: Dictionary = _pilier_offer_text(pilier_key)
	_build_draft_layer(choices, str(txt["title"]), str(txt["sub"]))
	while not _draft_done_flag and is_inside_tree() and is_instance_valid(_draft_layer) and not run.ended:
		await get_tree().process_frame
	if _draft_pick != null:
		run.add_card_to_deck(_draft_pick)
		if _beat_map != null:
			_beat_map.mark_draft()
	if _draft_layer != null:
		_draft_layer.queue_free()
		_draft_layer = null


func _build_draft_layer(choices: Array, title_text: String = "Une voie s'offre à toi — choisis une carte", sub_text: String = "Elle rejoint ton grimoire — de nouvelles forces ouvrent d'autres voies.") -> void:
	_draft_open_ms = Time.get_ticks_msec()  # arme la garde F2 (pas de pick aveugle pendant le deal)
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP  # modal : absorbe les clics derrière
	var dim: ColorRect = ColorRect.new()
	dim.color = MerlinVisual.DIM_MODAL
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
	title.text = title_text  # Wave D : titre thémé pour l'offrande du pilier (défaut = draft standard)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# v10.20.1 (O4) — explique la VALEUR du draft (avant, il apparaissait sans dire pourquoi).
	var sub: Label = Label.new()
	sub.text = sub_text
	sub.add_theme_color_override("font_color", MerlinVisual.DIM_WARM)
	sub.add_theme_font_size_override("font_size", 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
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
	MerlinVisual.apply_button_da(skip)
	skip.pressed.connect(_on_draft_skip)
	MerlinVisual.connect_button_feedback(skip)  # v10.13.1 — feedback canon §21 `tap`
	var skip_center: CenterContainer = CenterContainer.new()
	skip_center.add_child(skip)
	box.add_child(skip_center)
	add_child(layer)
	_draft_layer = layer
	_stagger_draft_in(title, row, skip_center)  # v10.13 (B5) : entrée staggered (titre→cartes→Passer)


# v10.13 (B5) — Entrée staggered du draft : titre fade 0.2s, cartes deal_in en cascade (0.12s/i),
# bouton Passer fade 0.3s en dernier. Attend 1 frame que le HBox pose les cartes : deal_in anime
# vers _base_pos, qu'on fige sur la position container via set_fan_transform (sinon base = ZERO).
func _stagger_draft_in(title: Control, row: Control, skip_c: Control) -> void:
	title.modulate.a = 0.0
	skip_c.modulate.a = 0.0
	var cards: Array = []
	for c in row.get_children():
		if c is MerlinCardView:
			(c as Control).modulate.a = 0.0  # invisibles jusqu'au deal_in (pas de flash 1 frame)
			cards.append(c)
	var t_title: Tween = title.create_tween()
	t_title.tween_property(title, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame  # layout du HBox posé → positions container valides
	if _draft_layer == null or not is_instance_valid(row) or not is_inside_tree():
		return  # draft déjà refermé (run terminée / scène quittée pendant la frame)
	for i in cards.size():
		var cv: MerlinCardView = cards[i]
		if not is_instance_valid(cv):
			continue
		cv.modulate.a = 1.0  # deal_in gère son propre fondu depuis 0
		cv.set_fan_transform(cv.position, 0.0)  # fige la position container comme base du deal
		cv.deal_in(0.20 + 0.12 * float(i))
	var t_skip: Tween = skip_c.create_tween()
	t_skip.tween_interval(0.20 + 0.12 * float(cards.size()))
	t_skip.tween_property(skip_c, "modulate:a", 1.0, 0.3)


func _on_draft_card(card: MerlinCard) -> void:
	if _draft_done_flag or Time.get_ticks_msec() - _draft_open_ms < 500:
		return  # audit ux_flow F2 : pas de pick AVEUGLE pendant le deal (contrôles encore à alpha 0)
	_draft_pick = card
	_draft_done_flag = true


func _on_draft_skip() -> void:
	if _draft_done_flag or Time.get_ticks_msec() - _draft_open_ms < 500:
		return  # audit ux_flow F2 : idem — un double-clic d'avance ne doit pas skipper sans voir
	_draft_pick = null
	_draft_done_flag = true




# Clic sur la zone récit (scène/narration). Pendant la frappe → révèle tout le texte ;
# une fois l'issue entièrement écrite → passe au beat suivant. (Demande user 2026-05-26.)
func _on_story_click(event: InputEvent) -> void:
	if _intro_open or _draft_layer != null or _interstitial_open:
		return  # interstitiel (B3) : clics gérés par _input (skip/avance) ou par le WaitStage
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
	var lbl: RichTextLabel = _tw_target if _tw_target != null else _situation_text
	lbl.visible_characters = -1
	_on_typewriter_done()


func _on_typewriter_done() -> void:
	# v10.13 (B3) : ouverture de l'interstitiel entièrement écrite → clic = présenter le Beat 1.
	if _interstitial_open:
		_can_advance = true
		if _caret != null:
			_caret.text = "▮ cliquer pour continuer"
		_set_caret(true)
		return
	if _state == 2:
		# Issue entièrement écrite → la VIGNETTE d'effet (degré + Δ jauges + effets) apparaît SOUS le texte
		# (R128 : compacte, après coup, sans casser la prose), puis avance au clic + caret « continuer ».
		if not _pending_res.is_empty():
			_build_effect_vignette(_pending_res, _pending_degree)
			if _res_block != null:
				_res_block.visible = true
			_pending_res = {}
		_can_advance = true
		if _caret != null:
			_caret.text = "▮ cliquer pour continuer"
		_set_caret(true)
	elif _state == 1:
		# Situation entièrement écrite → caret masqué, les cartes MONTENT pour le choix (user 2026-06-06).
		_set_caret(false)
		# v10.15 — Prose breathing : le texte pulse doucement (alpha 0.88↔1.0) en attendant le choix.
		# Stocké dans _prose_tw pour kill au prochain _typewriter (review HIGH-1).
		if not MerlinVisual.reduced_motion and _situation_text != null:
			if _prose_tw != null and _prose_tw.is_valid():
				_prose_tw.kill()
			_prose_tw = _situation_text.create_tween().set_loops()
			var half: float = MerlinVisual.DUR_BREATHE * MerlinVisual.motion()
			_prose_tw.tween_property(_situation_text, "modulate:a", 0.88, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_prose_tw.tween_property(_situation_text, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
		_caret_tw.tween_property(_caret, "modulate:a", 0.18, MerlinVisual.DUR_CARET_BLINK * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
		_caret_tw.tween_property(_caret, "modulate:a", 0.65, MerlinVisual.DUR_CARET_BLINK * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)


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
	_encart_phase_tw.tween_property(_situ_sb, "border_color", col, MerlinVisual.DUR_ENCART_TINT * MerlinVisual.motion())


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
	return MerlinVisual.degree_color(degree)


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
			var life_flash_col: Color = COL_GREEN if di > 0 else COL_VIOLET
			var lf_tw: Tween = _life_gauge.create_tween()
			lf_tw.tween_property(_life_gauge, "modulate", Color(life_flash_col.r, life_flash_col.g, life_flash_col.b, 1.0), 0.06)
			lf_tw.tween_property(_life_gauge, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if dc != 0:
			_pop(_corr_gauge, 1.18)
			_float_delta(_corr_gauge, dc, COL_VIOLET if dc > 0 else COL_GREEN)
			if dc > 0:
				MerlinFx.shake(_corr_gauge, 3.0, 0.15)
				MerlinAudio.play_sfx("corruption_tick")
		if di > 0:
			MerlinAudio.play_sfx("gauge_up")
		elif di < 0:
			MerlinAudio.play_sfx("gauge_down")
	# Pulse continue quand la stat est critique (vie basse / corruption haute).
	_life_gauge.set_critical(integrite <= 3)
	_corr_gauge.set_critical(corruption >= int(MerlinRun.CORRUPTION_CAP * 0.66))
	_prev_integrite = integrite
	_prev_corruption = corruption
	_update_corruption_fx(corruption)  # v10.13.1 (R75) : glitch par palier + pastille statique


# v10.13.1 (R75/R64) — glitch corruption : tween des uniforms vers le palier (0.8s), burst bref
# au franchissement de seuil (pic 0.8 pendant 0.15s → palier en 0.35s, total ≤0.5s — Wave1).
# Reduce-motion : intensité cap 0.1 (R74), l'information reste portée par la pastille.
func _update_corruption_fx(corruption: int) -> void:
	if _glitch_overlay == null or _glitch_mat == null:
		return
	var palier: int = clampi(int(float(corruption) / 5.0), 0, 3)
	var prev: int = _corruption_palier
	_corruption_palier = palier
	if palier > prev and prev >= 0:
		MerlinAudio.play_sfx("whisper_threshold")
	MerlinAudio.set_corruption_layer(palier)
	var lv: Dictionary = GLITCH_LEVELS[palier]
	var ti: float = float(lv["i"])
	var td: float = float(lv["d"])
	if MerlinVisual.reduced_motion:
		ti = minf(ti, 0.1)
	if _corr_dot != null and _corr_gauge != null:
		var alphas: Array = [0.0, 0.5, 0.75, 1.0]
		_corr_dot.visible = palier >= 1
		_corr_dot.modulate.a = float(alphas[palier])
		_corr_dot.position = Vector2(_corr_gauge.size.x * 0.5 - 6.0, _corr_gauge.size.y + 4.0)
	if palier > 0:
		_glitch_overlay.visible = true
	if _glitch_tw != null and _glitch_tw.is_valid():
		_glitch_tw.kill()
	# tween_method + set_shader_parameter (pattern vignette MerlinFx) — tween_property sur
	# "shader_parameter/x" échouait au runtime (« property does not exist », smoke 2026-06-12).
	_glitch_tw = create_tween().set_parallel(true)
	if palier > prev and palier > 0 and not MerlinVisual.reduced_motion:
		_set_glitch_i(0.8)  # burst de seuil — pic BREF (Wave1 : ≤0.5s total)
		_glitch_tw.tween_method(_set_glitch_i, 0.8, ti, 0.35).set_delay(0.15)
		_glitch_tw.tween_method(_set_glitch_d, _glitch_d, td, 0.35).set_delay(0.15)
	else:
		_glitch_tw.tween_method(_set_glitch_i, _glitch_i, ti, 0.8)
		_glitch_tw.tween_method(_set_glitch_d, _glitch_d, td, 0.8)
	if palier == 0:
		_glitch_tw.chain().tween_callback(_hide_glitch_if_sane)


func _set_glitch_i(v: float) -> void:
	_glitch_i = v
	if _glitch_mat != null:
		_glitch_mat.set_shader_parameter("intensity", v)


func _set_glitch_d(v: float) -> void:
	_glitch_d = v
	if _glitch_mat != null:
		_glitch_mat.set_shader_parameter("desaturation", v)


func _hide_glitch_if_sane() -> void:
	if _corruption_palier == 0 and _glitch_overlay != null:
		_glitch_overlay.visible = false


func _tween_ratio(g: MerlinRingGauge, target: float, prev: Tween) -> Tween:
	if prev != null and prev.is_valid():
		prev.kill()  # évite deux tweens concurrents sur le même anneau (snap arrière)
	var t: Tween = create_tween()
	t.tween_method(g.set_ratio, g.get_ratio(), target, 0.3).set_trans(Tween.TRANS_SINE)
	return t


# v10.13.1 — promus en statics MerlinFx (§21, réutilisables par menu/selection/end).
# Wrappers conservés : comportement et sites d'appel inchangés.
func _pop(node: Control, peak: float) -> void:
	MerlinFx.pop(node, peak)


func _float_delta(anchor: Control, delta: int, col: Color) -> void:
	MerlinFx.float_delta(self, anchor, delta, col)


func _combo_complete_pulse() -> void:
	if MerlinVisual.reduced_motion:
		return
	var center: Vector2 = _combo_box.global_position + _combo_box.size * 0.5
	for ri in 3:
		var ring: ColorRect = ColorRect.new()
		ring.color = Color(MerlinVisual.GOLD.r, MerlinVisual.GOLD.g, MerlinVisual.GOLD.b, 0.0)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.size = Vector2(4.0, 4.0)
		ring.pivot_offset = Vector2(2.0, 2.0)
		ring.position = center - Vector2(2.0, 2.0)
		add_child(ring)
		var delay: float = float(ri) * 0.06
		var tw: Tween = ring.create_tween().set_parallel(true)
		tw.tween_property(ring, "scale", Vector2(60.0, 60.0), 0.45).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "modulate:a", 0.0, 0.45).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var tw_a: Tween = ring.create_tween()
		tw_a.tween_property(ring, "color:a", 0.35 - float(ri) * 0.08, 0.04).set_delay(delay)
		tw_a.chain().tween_interval(0.45)
		tw_a.tween_callback(ring.queue_free)
	for si in 8:
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(3.0, 3.0)
		spark.color = MerlinVisual.GOLD
		spark.position = center - Vector2(1.5, 1.5)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(spark)
		var angle: float = float(si) / 8.0 * TAU + randf() * 0.4
		var dist: float = 30.0 + randf() * 25.0
		var dest: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
		var st: Tween = spark.create_tween().set_parallel(true)
		st.tween_property(spark, "position", dest - Vector2(1.5, 1.5), MerlinVisual.DUR_MOTE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(spark, "modulate:a", 0.0, MerlinVisual.DUR_MOTE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.chain().tween_callback(spark.queue_free)



# DEBUG (v10.2 visual test) — F12 déclenche la fusion (MerlinFx) avec une combo bidon depuis
# la main, pour permettre la capture autonome des 4 phases sans avoir à driver la résolution
# complète. Tag debug OS.is_debug_build pour ne pas embarquer en release.
func _input(event: InputEvent) -> void:
	# v10.6 (user 2026-06-06) — avance « cliquer pour continuer » BULLETPROOF via _input (reçu AVANT
	# la GUI), indépendant du z-order du catcher (qui était parfois bloqué par un conteneur au-dessus).
	# En résolution (state 2) : clic gauche → skip typewriter si en cours, sinon avance au beat suivant.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _intro_open or _draft_layer != null:
			return  # le draft est modal : ses clics sont gérés par l'overlay, pas par l'avance de beat
		# v10.13 (B3) — interstitiel « Merlin raconte » : clic = skip typewriter, puis avance Beat 1.
		if _interstitial_open:
			if _interstitial_wait != null:
				return  # le WaitStage (modal) gère son propre clic-skip
			if _tw != null and _tw.is_valid():
				_skip_typewriter()
				get_viewport().set_input_as_handled()
			elif _can_advance:
				_end_interstitial()
				get_viewport().set_input_as_handled()
			return
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
	# v10.13 (A2) : crée des MerlinCardView jetables dans _combo_box puis passe par MerlinFx.play —
	# les vues sont capturées ICI et reparentées dans le layer par MerlinFx (parité résolution réelle).
	for c in _combo_box.get_children():
		c.queue_free()
	var vues: Array = []
	for i in fake_played.size():
		var cv: MerlinCardView = MerlinCardView.new()
		_combo_box.add_child(cv)
		cv.setup(fake_played[i], "principale" if i == 0 else "modificateur", true)
		vues.append(cv)
	await get_tree().process_frame  # laisse Godot poser les card views dans le layout
	# Prédicat `ready` injecté : même source que la résolution réelle (is_resolution_ready). Pas de
	# scénario (probe hors-jeu) → prêt d'office = pas de sustain (parité avec l'ancien `sc == null`).
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	var ready_pred: Callable
	if sc != null:
		ready_pred = func() -> bool: return sc.is_resolution_ready(fake_played, fake_res)
	else:
		ready_pred = func() -> bool: return true
	var fx: MerlinFx = MerlinFx.play(self, fake_res, fake_played, vues, ready_pred)
	await fx.run()


func _on_run_ended(_end_type: String) -> void:
	# v10.13 (Fix 1) : si la run se termine pendant le modal de draft, on le ferme proprement
	# (la boucle de _present_draft sort via sa garde is_instance_valid/_draft_layer → skip).
	if _draft_layer != null:
		_draft_layer.queue_free()
		_draft_layer = null
		_draft_done_flag = true
	_interstitial_open = false  # hygiène (review MEDIUM B3) : état net pendant la transition de fin
	# v10.19 — Chronique cross-run (user 2026-06-29) : mémorise l'issue AVANT de purger la save,
	# pour que Merlin commente « la dernière fois » au prochain menu.
	var run: Node = get_node("/root/MerlinRun")
	var title: String = ""
	var scen: Variant = run.get("scenario")
	if scen is Dictionary:
		var sd: Dictionary = scen
		title = str(sd.get("title", sd.get("titre", "")))
	# v10.20.2 — mémorise AUSSI la faction + le pilier PNJ de la run (récurrence : reconnaissance au run suivant).
	var sc_mem: Node = get_node_or_null("/root/MerlinScenario")
	var faction: String = str(sc_mem.current_faction()) if sc_mem != null and sc_mem.has_method("current_faction") else ""
	var pilier: String = str(sc_mem.current_pilier()) if sc_mem != null and sc_mem.has_method("current_pilier") else ""
	MerlinChronicle.record_end(_end_type, title, int(run.get("integrite")), int(run.get("corruption")), faction, pilier)
	# Audit design P1 : une run TERMINÉE n'a pas de save de reprise — un save ici créait une
	# « save zombie » (Continuer rechargerait une run finie) si on quittait avant MerlinEnd.
	run.clear_save()
	call_deferred("_goto_end")


func _goto_end() -> void:
	_scene_epoch += 1  # invalide tout enrichissement LLM en vol avant de quitter la scène
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		mn.cancel()
	MerlinTransition.change_scene(END_SCENE)


# R128 — `from_chars` : pour la CONTINUATION (issue à la suite de la situation), l'animation part de la fin de
# la situation (visible_characters = from_chars) → seule la portion ajoutée se révèle ; le reste demeure écrit.
func _typewriter(txt: String, animate: bool = true, target: RichTextLabel = null, from_chars: int = 0) -> void:
	var lbl: RichTextLabel = target if target != null else _situation_text
	_tw_target = lbl
	if _prose_tw != null and _prose_tw.is_valid():
		_prose_tw.kill()
	lbl.modulate.a = 1.0
	_kill_tw()
	lbl.text = txt
	if not animate:
		lbl.visible_characters = -1  # tout révélé (swap d'enrichissement)
		_on_typewriter_done()
		return
	var n: int = lbl.get_total_character_count()
	var start: int = clampi(from_chars, 0, n)
	lbl.visible_characters = start
	if n <= start:
		_on_typewriter_done()
		return
	if _state == 1 or _state == 2 or _interstitial_open:
		_show_skip_hint()  # affordance « clic = passer » visible DÈS le début (user 2026-06-07)
	_tw_tick_count = 0
	var added: int = n - start  # nombre de caractères réellement animés (l'issue seule en continuation)
	var dur: float = clampf(float(added) / 30.0, 0.8, 10.0)
	_tw = create_tween()
	_tw.tween_property(lbl, "visible_characters", n, dur)
	_tw.finished.connect(_on_typewriter_done)
	if _quill_tw != null and _quill_tw.is_valid():
		_quill_tw.kill()
	var tick_interval: float = dur / maxf(float(added), 1.0) * 3.0
	var tick_count: int = maxi(added / 3, 1)
	# v10.20 — Merlin PARLE : sa VOIX procédurale accompagne sa prose (humeur depuis le texte), à la place
	# du quill (user 2026-06-29 : « il faut ce son dans toutes les scenes où il parle »).
	var mood: String = MerlinSceneArt.mood_for_text(txt)
	var sess: int = MerlinAudio.begin_voice()  # voix unique : coupe un locuteur précédent (anti-superposition)
	_quill_tw = create_tween()
	for i in tick_count:
		_quill_tw.tween_interval(tick_interval)
		_quill_tw.tween_callback(func() -> void: MerlinAudio.play_voice_session(sess, mood))


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
	fade.color = MerlinVisual.DIM_LIGHT
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
	bandeau.mouse_filter = Control.MOUSE_FILTER_PASS  # v10.13 (B2) : le clic remonte au layer (skip)
	_intro_layer.add_child(bandeau)

	# Layout vertical : titre + intro (scroll si long) + ligne objectif/accepter.
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_PASS  # v10.13 (B2) : idem — propagation vers _intro_layer
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
	intro_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE  # v10.13 (B2) : le clic atteint le layer
	mid.add_child(intro_lbl)
	# v10.13 (B3) : l'ouverture narrative ne vit PLUS dans le pop-up — elle est portée par
	# l'interstitiel « Merlin raconte » après l'Accept (anti « info ×2 »). Pop-up = greeting seul.
	var intro_text: String = str(data.get("intro", ""))

	# v10.13 (B2) — hint « tout lire » dès le début du typewriter (pilier FACILE, ≤2 gestes :
	# clic 1 = tout révéler, clic 2 = Accepter). Disparaît au clic ou à la fin de la frappe.
	# DIM_WARM (clair) sur panneau sombre — INK_DIM était ≈2.4:1, sous le seuil 3:1 (audit ux_flow E1).
	var read_hint: Label = MerlinVisual.make_label(MerlinVisual.DIM_WARM, MerlinVisual.FS_HINT)
	read_hint.text = "▶ clic pour tout lire"
	read_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	read_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(read_hint)

	_intro_reveal_tw = _reveal_into(intro_lbl, intro_text)
	if _intro_reveal_tw != null:
		_intro_reveal_tw.finished.connect(func() -> void:
			if is_instance_valid(read_hint):
				read_hint.visible = false)
	else:
		read_hint.visible = false  # rien à révéler → pas d'affordance
	# 1er clic n'importe où sur le panneau (hors bouton Accepter) → tout le texte est révélé.
	_intro_layer.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			return
		if intro_lbl.visible_characters >= 0 and intro_lbl.visible_characters < intro_lbl.get_total_character_count():
			if _intro_reveal_tw != null and _intro_reveal_tw.is_valid():
				_intro_reveal_tw.kill()
			intro_lbl.visible_characters = -1
			if is_instance_valid(read_hint):
				read_hint.visible = false)

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
	MerlinVisual.apply_button_da(accept)
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

	# v10.13 (B3) : ouverture pré-générée en cache (priorité moteur BASSE — ne se lance que si le
	# moteur est idle) AVANT l'enrichissement de greeting. Consommée par l'interstitiel à l'Accept.
	get_node("/root/MerlinScenario").prefetch_opening(run.scenario)
	_bg_intro(run.scenario, intro_lbl)


# v10.13 (B2) : retourne le tween de frappe (null si rien à écrire) → skippable au clic.
func _reveal_into(lbl: RichTextLabel, txt: String) -> Tween:
	lbl.text = txt
	lbl.visible_characters = 0
	var n: int = lbl.get_total_character_count()
	if n <= 0:
		return null
	var dur: float = clampf(float(n) / 55.0, 0.6, 4.0)
	var t: Tween = lbl.create_tween()
	t.tween_property(lbl, "visible_characters", n, dur)
	# v10.20 — voix de Merlin sur l'intro/ouverture (était muette). Cadence ~1 blip / 3 lettres.
	var mood: String = MerlinSceneArt.mood_for_text(txt)
	var sess: int = MerlinAudio.begin_voice()  # voix unique (anti-superposition)
	var ticks: int = maxi(n / 3, 1)
	var iv: float = dur / float(maxi(ticks, 1))
	var vt: Tween = lbl.create_tween()
	for i in ticks:
		vt.tween_interval(iv)
		vt.tween_callback(func() -> void: MerlinAudio.play_voice_session(sess, mood))
	return t


func _pulse(node: Control) -> void:
	_pulse_tw = node.create_tween().set_loops()
	_pulse_tw.tween_property(node, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)


# Enrichit l'intro en arrière-plan ; ne remplace QUE si le pop-up est encore ouvert. Jamais bloquant.
# v10.13 (B3) : plus de paramètre `opening` — l'ouverture vit dans l'interstitiel « Merlin raconte ».
func _bg_intro(scenario: Dictionary, lbl: RichTextLabel) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return
	# Greeting MERLIN enrichie (LLM, non bloquant).
	var prose: String = await sc.narrate_intro(scenario)
	if not _intro_open or _intro_layer == null or not is_instance_valid(lbl):
		return
	# ÉVIDENT : ne pas muter un texte en cours de lecture → enrichir seulement si le typewriter a fini.
	if prose.length() >= 10 and not (lbl.visible_characters >= 0 and lbl.visible_characters < lbl.get_total_character_count()):
		lbl.text = prose
		lbl.visible_characters = -1
	# v10.13 (Fix 9) : le 2e appel LLM (narrate_opening) est SUPPRIMÉ ici — il occupait le moteur
	# single-flight exactement pendant la composition du beat 1, affamant le prefetch de résolution
	# (la prose d'ouverture ne gagnait jamais la course de toute façon). L'ouverture LLM vit
	# désormais derrière l'interstitiel « Merlin raconte » (B3), via prefetch_opening (priorité basse).


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
	t.tween_property(layer, "modulate:a", 0.0, MerlinVisual.DUR_VEIL_OUT * MerlinVisual.motion())
	t.tween_callback(layer.queue_free)
	get_node("/root/MerlinRun").save()  # v10.13 (Fix 6) : quitter pendant le beat 1 → reprise au beat 1
	# v10.13 (B3) : l'intro cède la place à l'interstitiel « Merlin raconte » (ouverture narrative),
	# qui présentera lui-même le Beat 1 au clic suivant. La save reste AVANT (Fix 6c).
	_play_opening_interstitial()


# === v10.13 (B3) — Interstitiel « Merlin raconte » : entre l'Accept et le Beat 1 ===
# Sert l'ouverture narrative (LLM si le cache prefetch_opening est prêt, sinon attente animée
# bornée 8s puis procédural) ET couvre la gen d'arc en arrière-plan (retarde arc_locked → plus
# d'arcs LLM gagnent la course). Clic pendant le typewriter = tout révéler ; clic ensuite =
# _present_current_beat() (≤2 gestes, pilier FACILE). Piloté par _input via _interstitial_open.
func _play_opening_interstitial() -> void:
	_scene_epoch += 1  # toute gen/anim liée au pop-up d'intro devient périmée
	var ep: int = _scene_epoch
	_interstitial_open = true
	_can_advance = false
	_set_caret(false)
	_set_choice_ui(false)
	var run: Node = get_node("/root/MerlinRun")
	var sc: Node = get_node("/root/MerlinScenario")
	# Review HIGH (B3) : si le prefetch lancé à l'ouverture de l'intro a été SAUTÉ (moteur occupé
	# par la gen d'arc — cas courant au cold start), on RETENTE ici : l'arc a eu toute la lecture
	# de l'intro pour finir, et le WaitStage (8s) attend alors une VRAIE gen, pas du vide.
	# Jamais si déjà prête ou en vol (prefetch_opening fait une RAZ inconditionnelle).
	if not sc.is_opening_ready() and not sc.is_opening_pending():
		sc.prefetch_opening(run.scenario)
	_set_encart_phase(MerlinVisual.INK_DIM)  # bordure neutre (même teinte que les situations)
	if _situation_text != null:
		_situation_text.text = ""
	if _situ_panel != null:
		_situ_panel.modulate.a = 0.45
		if _situ_tw != null and _situ_tw.is_valid():
			_situ_tw.kill()
		_situ_tw = _situ_panel.create_tween()
		_situ_tw.tween_property(_situ_panel, "modulate:a", 1.0, 0.22)
	var opening: String = ""
	if bool(sc.is_opening_ready()):
		opening = str(sc.take_opening())
	else:
		# Attente animée bornée (cap 8s, skippable) : couvre les gens de fond (arc/ouverture).
		_interstitial_wait = MerlinWaitStage.start(self, {
			"caption": "Merlin rassemble les fils de l'histoire",
			"cap_ms": 8000,
			"dim_alpha": 0.55,       # audit ux_flow E2 : caption or sur l'encart crème ≈1.8:1 → voile sombre
			"skip_reveal_ms": 1500,  # audit ux_flow F1 : skip révélé à 1.5s (cap court 8s)
		})
		var issue: String = await _interstitial_wait.wait_until(func() -> bool: return bool(sc.is_opening_ready()))
		_interstitial_wait = null
		if not _fresh(ep):
			_interstitial_open = false
			return  # scène quittée / supplantée pendant l'attente
		if issue == "ready":
			opening = str(sc.take_opening())
	if opening.strip_edges() == "":
		opening = str(sc.build_opening(run.scenario))  # procédural verbeux (cadre + accroche du pitch)
	_typewriter("[center]" + opening + "[/center]", true)
	# La suite (skip typewriter / avance au Beat 1) est pilotée par _input (_interstitial_open).


# Sortie de l'interstitiel (clic « continuer » ou autoplay) → présentation du Beat 1.
func _end_interstitial() -> void:
	if not _interstitial_open:
		return
	_interstitial_open = false
	_can_advance = false
	_set_caret(false)
	_present_current_beat()


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
	root.add_theme_constant_override("separation", 10)
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
	_beat_map = MerlinBeatMap.new()
	_beat_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beat_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_beat_map.custom_minimum_size = Vector2(0, 28)
	hud.add_child(_beat_map)
	var sp_r: Control = Control.new()
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(sp_r)
	_corr_gauge = MerlinRingGauge.new()
	hud.add_child(_corr_gauge)
	_corr_gauge.setup(COL_VIOLET, true)  # jauge « vivante » : respiration continue

	# Scène en silhouettes plates — bande supérieure FIXE (l'encart récit prend l'espace dessous).
	_scene_art = MerlinSceneArt.new()
	_scene_art.custom_minimum_size = Vector2(0, 280)
	root.add_child(_scene_art)
	_scene_art.set_animated(true)  # v10.13 (B7) : couche ambiante GAME (halo lune + brume vivantes)
	_scene_art.set_watch_eyes(true)  # v10.20 : les yeux de Merlin vivent dans la LUNE et suivent le curseur

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

	# v10.21 (R128) — Bloc RÉSOLUTION = uniquement la VIGNETTE d'effet (degré + Δ jauges + effets), compacte
	# SOUS le texte. L'issue elle-même s'écrit dans _situation_text (même fil narratif) — plus de filet or ni de
	# label séparé (user 2026-06-30). Caché hors résolution ; apparaît APRÈS le typewriter de l'issue.
	_res_block = VBoxContainer.new()
	_res_block.add_theme_constant_override("separation", 10)
	_res_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_block.visible = false
	inner.add_child(_res_block)
	_effect_vignette = HBoxContainer.new()
	_effect_vignette.alignment = BoxContainer.ALIGNMENT_CENTER
	_effect_vignette.add_theme_constant_override("separation", 16)
	_effect_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_block.add_child(_effect_vignette)

	# Caret « cliquer pour continuer » : clignote faiblement quand l'issue est entièrement écrite.
	_caret = _mk_label(MerlinVisual.GOLD_DARK, 20)
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
	combo_v.add_theme_constant_override("separation", 6)
	_combo_panel.add_child(combo_v)
	_combo_box = HBoxContainer.new()
	_combo_box.add_theme_constant_override("separation", 10)
	_combo_box.custom_minimum_size = Vector2(0, 104)
	_combo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	combo_v.add_child(_combo_box)
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	combo_v.add_child(btn_row)
	_resolve_btn = Button.new()
	_resolve_btn.text = "Résolution"
	_resolve_btn.custom_minimum_size = Vector2(300, 66)
	_resolve_btn.add_theme_font_size_override("font_size", 26)
	MerlinVisual.apply_button_da(_resolve_btn)
	_resolve_btn.pressed.connect(_on_resolve)
	btn_row.add_child(_resolve_btn)
	MerlinVisual.connect_button_feedback(_resolve_btn)  # v10.13.1 — feedback canon §21 `tap`

	# v10.5 : label « Ta main : » retiré (user 2026-06-06). L'éventail se suffit visuellement.
	_hand_box = Control.new()
	_hand_box.custom_minimum_size = Vector2(0, 220)
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
	ov_sb.bg_color = MerlinVisual.TOAST_BG
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


	# v10.13.1 (R75) — overlay glitch corruption : plein écran, IGNORE, caché au palier sain
	# (coût GPU nul). hide()/show() uniquement — jamais de queue_free cyclique (playtester).
	_glitch_overlay = ColorRect.new()
	_glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_overlay.z_index = 95
	_glitch_overlay.visible = false
	var gl_shader: Shader = load("res://shaders/whisper_glitch.gdshader")
	if gl_shader != null:
		_glitch_mat = ShaderMaterial.new()
		_glitch_mat.shader = gl_shader
		_glitch_overlay.material = _glitch_mat
	add_child(_glitch_overlay)
	# Pastille statique VIOLET sous la jauge Corruption : visible dès le palier 1, quelle que
	# soit l'option reduce-motion (pilier ÉVIDENT — l'état corruption ne disparaît jamais).
	_corr_dot = Panel.new()
	_corr_dot.custom_minimum_size = Vector2(12, 12)
	_corr_dot.size = Vector2(12, 12)
	_corr_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corr_dot.visible = false
	var dsb: StyleBoxFlat = StyleBoxFlat.new()
	dsb.bg_color = MerlinVisual.VIOLET
	dsb.set_corner_radius_all(6)
	_corr_dot.add_theme_stylebox_override("panel", dsb)
	_corr_gauge.add_child(_corr_dot)

	# v10.13 (B7) — « Merlin pense » : sonde 0.5s du moteur natif → le décor signale honnêtement
	# quand une génération tourne (halo de lune accéléré + mote or en orbite du menhir).
	var think_t: Timer = Timer.new()
	think_t.wait_time = 0.5
	think_t.autostart = true
	add_child(think_t)
	think_t.timeout.connect(_on_think_tick)


func _on_think_tick() -> void:
	if _scene_art == null:
		return
	var mn: Node = get_node_or_null("/root/MerlinNative")
	_scene_art.set_thinking(mn != null and mn.is_busy())


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
