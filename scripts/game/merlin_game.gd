extends Control
## MerlinGame — boucle de jeu (bible §2, R54/R55/R72). Scène de jeu MVP.
## v11-W2 (pivot ACTION+TRAIT) : situation (LLM prose) → geste = 1 ACTION (tuile permanente, rangée
## basse) + 1 TRAIT (main 4, redraw complet par beat) → résolution (CODE) → narration (LLM) → beat
## suivant. Génération SÉQUENTIELLE à la demande, sans lookahead (moteur single-flight). Fallbacks
## partout → la run se termine toujours.

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
# v10.21 (L-b) — pré-alerte de seuil : pastille statique + libellé Emprise + garde anti-re-pulse.
var _thr_dot: ColorRect = null
var _emprise_lbl: Label = null
var _near_thr_shown: bool = false
var _beat_map: MerlinBeatMap
var _scene_art: MerlinSceneArt
var _situ_panel: PanelContainer       # encart central : porte intro/situation/issue
var _situ_sb: StyleBoxFlat            # style de l'encart (bordure teintée par phase — signal de transition)
var _situation_text: RichTextLabel
var _hand_box: Control
# v11-W2 (spec §I) — rangée basse PERMANENTE : 4 tuiles d'action 260×116 + Résoudre + indice de dé.
# Le combo panel (104 px) est SUPPRIMÉ : la sélection se lit SUR l'élément (bordure GOLD).
var _action_bar: HBoxContainer = null
var _action_views: Array = []          # les 4 MerlinActionView (construites à _begin depuis run.actions)
# N4-RUNES : _req_row (chips des tags requis) SUPPRIMÉE : zéro jargon à l'écran, preview R120.
var _resolve_btn: Button
var _overlay: Panel
var _overlay_lbl: Label
var _caret: Label  # marqueur clignotant « cliquer pour continuer » (fin de phrase, UX boîte de dialogue)
var _caret_tw: Tween
var _can_advance: bool = false  # true quand l'issue est entièrement écrite → clic = beat suivant

var _current_situation: Dictionary = {}
# v11-W2 (spec §A) — le geste = 1 ACTION + 1 TRAIT, sélection en 2 clics, re-clic = désélection.
# Remplace l'ancien _combo Array (2 cartes de la main).
var _selected_action: MerlinCard = null
var _selected_trait: MerlinCard = null
var _state: int = 0  # 0=loading 1=playing 2=resolving
var _eye_cursor_acc: float = 0.0  # v10.20 — throttle du suivi curseur de l'œil-lune (yeux de Merlin)
var _cap_last_ms: int = 0         # dev capture in-game
var _cap_n: int = 0
var _tw_target: RichTextLabel = null  # v10.20 — cible du typewriter (situation, qui porte aussi l'issue R128)
# v10.21 (user 2026-06-30) — l'issue s'écrit À LA SUITE de la situation, dans le MÊME fil (_situation_text).
# _res_block ne porte plus que la VIGNETTE d'effet, qui apparaît SOUS le texte APRÈS le typewriter de l'issue.
var _res_block: VBoxContainer = null
var _effect_vignette: HBoxContainer = null
var _status_line: Control = null     # v11-V2a — Z4 « ligne d'état » 72 px FIXE (vignette/choix au centre, caret à droite)
var _choice_open: bool = false       # v11-V2a — garde anti-clic du choix (reprend le rôle de _hand_box.visible)
var _pending_res: Dictionary = {}    # res/degré mémorisés au resolve → fade-in vignette post-typewriter
var _pending_degree: String = ""
# v10.21 (Wave G, R130) — PARTIEL = CHOIX « Encaisser / Pousser » : l'application de la résolution est
# DIFFÉRÉE jusqu'au choix (play_and_discard + effets de cartes restent immédiats — un HEAL sauve avant).
var _push_pending: bool = false
var _push_res_raw: Dictionary = {}   # deltas BRUTS de resolve() préservés pour l'application différée
var _push_situ: Dictionary = {}
var _push_cards: Array = []
var _push_row: HBoxContainer = null
# Garde anti-clobber : incrémenté à CHAQUE transition d'affichage (nouvelle situation,
# issue affichée, fin de run). Un enrichissement LLM en arrière-plan ne remplace le texte
# QUE si l'epoch n'a pas bougé depuis qu'il a été lancé (sinon le joueur a déjà avancé).
var _scene_epoch: int = 0
var _tw: Tween
# v11-V2b (spec écran stable) — l'intro de quête vit DANS les zones : plus de layer modal. Le
# titre/pitch/objectif occupent l'encart (Z3), « Accepter ✦ » le slot central de Z4.
var _intro_open: bool = false
var _intro_accept_btn: Button = null  # bouton « Accepter ✦ » (Z4) — cross-fadé par _accept_quest
var _intro_data: Dictionary = {}      # titre/pitch/objectif figés → recomposition à l'enrichissement LLM
var _pulse_tw: Tween
var _prev_integrite: int = -999  # pour animer les deltas de jauges (-999 = pas encore initialisé)
var _prev_corruption: int = -999
var _tw_tick_count: int = 0
var _quill_tw: Tween
var _deal_pending: bool = false  # déclenche l'anim de distribution au prochain _layout_fan
var _life_tw: Tween  # tween de remplissage de l'anneau vie (tué avant un nouveau → pas de snap arrière)
var _corr_tw: Tween
var _situ_tw: Tween  # fondu de l'encart (interstitiel) — tué avant réutilisation → pas de course de tweens
var _prose_tw: Tween  # v10.15 : prose breathing loop (killed before next typewriter)
var _resolve_tw: Tween = null  # v11-V2a : fade armé/désarmé du bouton Résoudre (self_modulate)
var _encart_phase_tw: Tween  # teinte de la bordure de l'encart (neutre situation ↔ couleur du degré à l'issue)

# v10.11/12 (user 2026-06-07) — Map du chemin (coin droit) + Draft « 1 carte sur 3 » aux beats clés.
# v11-V2b (spec matrice ligne 9) : le draft vit DANS les zones — les 3 cartes remplacent l'éventail,
# titre + « Passer » dans Z4. Le flag _draft_active REMPLACE l'ancien overlay modal _draft_layer.
var _pending_draft: bool = false         # armé en résolution (réussite/éclatante, beats restants) → draft à l'avance
var _draft_active: bool = false          # draft/offrande ouvert dans les zones (outillé par l'autoplay)
var _draft_bar: HBoxContainer = null     # Z4 : titre + « Passer » pendant le draft
var _draft_pick: MerlinCard = null       # carte choisie (null = passer)
var _draft_done_flag: bool = false       # le joueur a tranché (choix ou passer)
# v11-W3 (spec §E) — le draft sert des GREFFES en 2 GESTES : clic greffe (carte levée + GOLD) →
# clic tuile cible (pose via run.apply_graft). Les cartes affichées sont des MerlinCard de
# PRÉSENTATION ; le dict de greffe vit dans _graft_by_id (id → graft).
var _graft_by_id: Dictionary = {}        # id de greffe → dict (draft courant)
var _pending_graft: Dictionary = {}      # greffe sélectionnée en attente de cible ({} = étape 1)
var _graft_applied: bool = false         # une greffe a été posée pendant ce draft (→ mark_draft)
var _draft_title_lbl: Label = null       # libellé Z4 (re-titré à l'étape cible, cross-fade)
var _draft_title_base: String = ""       # titre de l'étape 1 (restauré à la désélection)

# v10.13.1 — juice pack 1 (§21) : gardes d'animation.
var _beat_transition: bool = false  # review HIGH-1 : anti double-fire de _present_current_beat (voile)
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

# v10.13 (Phase B) — interstitiel « Merlin raconte » (B3), sceau de degré (B9).
var _interstitial_open: bool = false           # B3 : interstitiel actif (entre Accept et Beat 1)
var _interstitial_wait: MerlinWaitStage = null # v11-V2b : TOUJOURS null — l'attente LLM vit DANS
                                               # l'encart (_interstitial_skip). Membre conservé :
                                               # l'outillage capture teste encore `!= null`.
var _interstitial_skip: bool = false           # v11-V2b : clic pendant l'attente inline → fallback servi
var _gauges_deferred: bool = false             # v11-W1 : anneaux GELÉS pendant la résolution (le layer
                                               # MerlinFx couvre l'écran) — commit visuel post-typewriter
var _draft_open_ms: int = 0                    # F2 : anti pick-aveugle pendant le deal du draft
# v11-V2b (spec §tuto) — micro-tuto : 2 hints one-shot, labels PASSIFS (MOUSE_FILTER_IGNORE — jamais
# bloquants, l'autoplay n'a rien à servir) dans Z4, persistés via MerlinVisual (section [tuto]).
var _tuto_lbl: Label = null
var _tuto_a_active: bool = false               # hint A affiché (beat 1) — désarmé à la 1re paire complète
var _tuto_b_active: bool = false               # hint B affiché (beat 2) — désarmé au 1er clic de tuile

# N4-TUTO (2026-07-11) : le GUIDE de première traversée (merlin_tutorial.gd), PROPOSÉ (jamais
# imposé) sur chronique vierge après l'interstitiel : rangée Z4 [Guide-moi / Je connais le chemin]
# outillée par l'autoplay (revue design B1) ; réponse persistée en SYNCHRONE (B2, MerlinChronicle).
const TUTO_SCRIPT: GDScript = preload("res://scripts/game/merlin_tutorial.gd")  # R147bis
var _tuto: Node = null                         # orchestrateur du guide (null hors guide)
var _tuto_prompt_row: HBoxContainer = null     # rangée de proposition Z4 (duck-typée par l'autoplay)


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
	_build_action_tiles()  # v11-W2 : les 4 tuiles permanentes (run.actions n'existe qu'après new_run/load_run)
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
	# v11-V2a (spec écran stable) — le voile plein écran (MerlinFx.beat_veil) est SUPPRIMÉ : le
	# contenu de l'encart bascule par cross-fade de zone (swap_zone, en fin de fonction) et les
	# zones ne bougent jamais. _beat_transition reste la garde anti double-fire — posée ici,
	# relâchée au rebuild du contenu. Fonction devenue SYNCHRONE (plus d'await).
	_beat_transition = true
	_interstitial_open = false  # v10.13 (B3) : défense — l'interstitiel est forcément clos ici
	# v10.21 — reset au nouveau beat : situation pleine opacité, vignette d'effet estompée (elle vit
	# en Z4 désormais ; l'issue R128 vit dans _situation_text, réécrit par _show_situation).
	_fade_res_block(false)
	if _push_row != null and is_instance_valid(_push_row):  # R130 : jamais de choix fantôme au beat suivant
		_push_row.queue_free()
		_push_row = null
	_push_pending = false
	_push_res_raw = {}
	if _pact_row != null and is_instance_valid(_pact_row):  # R131 : idem pour le pacte
		_pact_row.queue_free()
		_pact_row = null
	_pact_pending_pilier = ""  # review V2b MEDIUM-5 : un pacte non consommé ne traverse pas les beats
	_clear_tuto_hint()  # v11-V2b : hygiène — un hint non désarmé ne survit pas au beat (non consommé)
	_intervention_done_this_beat = false
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
			# v10.21 (Wave L-d) — frontières de CHAÎNE visibles : quêtes accomplies/futures autour du chemin.
			# Garde de type : les squelettes harnais/legacy peuvent porter « quests » sous une autre forme
			# (cast direct = SCRIPT ERROR + beat jamais présenté — attrapé par le gate R109 2026-07-04).
			var qv2: Variant = run.scenario.get("quests", [])
			_beat_map.set_quest_context(int(cur_b.get("quest", 0)), (qv2 as Array).size() if qv2 is Array else 1)
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
	# v11-W2 (spec §C) : REDRAW COMPLET de la main de 4 traits (cycle vrai — défausse totale,
	# reshuffle <4). Les caps R113 (≤1 corrompu/main, ≥1 trait) vivent dans merlin_run.
	run.redraw_hand()
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
	# v11-W2 : sélection nettoyée + tuiles rafraîchies (feedforward du nouveau beat).
	# N4-RUNES (2026-07-11) : les chips de tags requis sont SUPPRIMÉES (zéro jargon à l'écran) ;
	# l'affinité se lit au souligné feedforward des tuiles + à la preview de résolution (R120).
	_selected_action = null
	_selected_trait = null
	_set_resolve_armed(false)  # Z6 : le bouton reste VISIBLE, simplement désarmé (alpha 0.35)
	_refresh_action_tiles()
	# v10.10 (user 2026-06-06) : la SITUATION s'affiche SEULE dans l'encart central ; le choix ne
	# s'ouvre qu'à la fin du typewriter (_on_typewriter_done state==1). Zones estompées d'ici là.
	_set_choice_ui(false)
	# Signal de transition (user 2026-06-07) : bordure neutre ; le NOUVEAU beat arrive par cross-fade
	# de zone (fade-out → contenu → fade-in), JAMAIS par tween de position (leçon C1 : tweener la
	# position d'un Control ancré fait perdre la main au layout). Le slide-up v10.15 est supprimé.
	_set_encart_phase(MerlinVisual.INK_DIM)
	if _situ_tw != null and _situ_tw.is_valid():
		_situ_tw.kill()  # fondu d'interstitiel en vol → le swap de zone prend la main sur l'alpha
	MerlinVisual.swap_zone(_situ_panel, func() -> void:
		_beat_transition = false
		_show_situation(_current_situation)
		_state = 1)


func _show_situation(situ: Dictionary, animate: bool = true) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var btype: String = str(situ.get("type", ""))
	if _scene_art != null:
		_scene_art.set_beat(btype)  # le décor reflète le type de beat (figure si Rencontre/Climax/Dilemme)
		var sc_f: Node = get_node_or_null("/root/MerlinScenario")  # Wave C : décor teinté par la faction de la run
		if sc_f != null and sc_f.has_method("current_faction"):
			_scene_art.set_faction(str(sc_f.current_faction()))
		_scene_art.set_eye_mood(MerlinSceneArt.mood_for_text(str(situ.get("narration", ""))))  # v10.20 : œil-lune réagit
		# v10.21 (spec panel) — PRÉSENCE du PNJ pilier aux beats de Rencontre : silhouette matérialisée +
		# réaction de la lune (Chœur/Chevalier = flash chaleureux, mood neutre ; autres = surprise ;
		# JAMAIS angry à l'apparition — réservé au degré échec). Le mood pilier PRIME sur mood_for_text.
		var pk2: String = _current_offer_pilier()
		if btype == "Rencontre" and pk2 != "":
			# v10.21 (Wave I, R131) / v11-V2b — PLANIFICATION des interventions (persistée R108,
			# jamais le climax final) : UNE seule par run désormais (spec écran stable — la
			# planification du 2e beat est retirée ; le cap d'exécution vit dans _maybe_intervention).
			if (run.intervention_beats as Array).is_empty() and int(run.pilier_interventions) == 0:
				var total_b: int = int(run.scenario.get("total", 5))
				var t1: int = run.beat_index + 1 + (randi() % 2)
				if t1 < total_b - 1:
					run.intervention_beats.append(t1)
			_scene_art.set_pilier(pk2, true)
			MerlinAudio.play_pad("pad_" + pk2)  # v10.21 Wave A : la nappe SIGNÉE s'installe avec lui
			if pk2 == "choeur" or pk2 == "chevalier":
				_scene_art.set_eye_mood("neutral")
				_scene_art.flash_moon()
			else:
				_scene_art.set_eye_mood("surprise")
		else:
			_scene_art.set_pilier("", false)
			MerlinAudio.stop_pad()  # le pilier s'en va → sa nappe s'éteint (canal unique, jamais superposé)
	_typewriter("[center]" + str(situ.get("narration", "")) + "[/center]", animate)
	# v10.21 — feedforward « Ce lieu réclame » RETIRÉ (user 2026-06-30) : immersion narrative ; l'issue continue le fil.
	# v10.13.1 (R75 palier emprise+) : tremblement BREF du cadre à l'ARRIVÉE de la prose —
	# jamais pendant la lecture (Wave1 : amplitude ≤2px), off en reduce-motion (pastille = info).
	if animate and _corruption_palier >= 2 and not MerlinVisual.reduced_motion and _situ_panel != null:
		MerlinFx.shake(_situ_panel, 2.0, 0.2)


func _render_hand(deal: bool = false) -> void:
	var run: Node = get_node("/root/MerlinRun")
	# v11-W2 : la main ENTIÈRE reste dans l'éventail (la sélection se lit sur l'élément — levée +
	# bordure GOLD — plus de vol vers un combo panel).
	var wanted: Array = []
	for card in run.hand:
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
			if run.blessed_tags.has(str(card.id)):  # R131 : bénédiction VISIBLE (badge ✦tag)
				cv.set_blessed(str(run.blessed_tags[str(card.id)]))
			cv.card_clicked.connect(_on_trait_card)
			keep[card] = cv
	for i in wanted.size():  # ordre des enfants = ordre de la main (recouvrement stable)
		_hand_box.move_child(keep[wanted[i]], i)
	# N4-P1 (chantier 1, BLOQUANT_FUN) : AFFINITÉ dorée GRADUÉE sur les cartes-runes : le CADRE
	# entier s'illumine selon le NOMBRE de tags requis couverts (0 = rien · 1 = lueur nette ·
	# 2+ = intense + pulse lent). Même calcul canon que _refresh_action_tiles, zéro mot de tag.
	var reqs_hand: Array = []
	for r in _current_situation.get("required_tags", []):
		reqs_hand.append(MerlinTags.to_canon(str(r)))
	for card in keep:  # v11-W2 : l'état de sélection se lit SUR la carte (levée + bordure GOLD)
		var cvk: MerlinCardView = keep[card]
		cvk.set_selected(card == _selected_trait)
		var covered_count: int = 0
		var seen_reqs: Array = []  # review P1 LOW-4 : dedupe (un requis duplique ne compte qu'une fois)
		for rq in reqs_hand:  # tags REQUIS couverts (distincts) : c'est le degré qui se joue (§K)
			if seen_reqs.has(rq):
				continue
			seen_reqs.append(rq)
			for t in (card as MerlinCard).tags:
				if MerlinTags.to_canon(str(t)) == str(rq):
					covered_count += 1
					break
		cvk.set_affinity(covered_count)
	_deal_pending = deal  # anime la distribution seulement sur une main fraîche (beat/résolution)
	call_deferred("_layout_fan")


# Dispose la main en éventail dynamique : cartes centrées, arc + rotation depuis le centre.
func _layout_fan() -> void:
	if _hand_box == null or _draft_active:
		return  # v11-V2b : pendant le draft, l'éventail appartient aux 3 cartes (positions manuelles)
	var cards: Array = []
	for c in _hand_box.get_children():
		# v10.13.1 : les vues en cours de discard_out ne comptent plus. N4-TUTO : le filtre
		# _discarding est désormais EFFECTIF (le commentaire le promettait, le code ne le faisait
		# pas) : sans lui, le deal_in du reflow TUE le tween de discard et RESSUSCITE la vue dans
		# l'éventail (8 cartes au beat 1 du guide, mesuré par probe : d=true a=1.00 permanent).
		# Le flow normal était masqué par le rebuild du draft d'ouverture (_swap_hand_zone).
		if c is MerlinCardView and not c.is_queued_for_deletion() and not (c as MerlinCardView)._discarding:
			cards.append(c)
	var n: int = cards.size()
	if n == 0:
		return
	var cw: float = MerlinCardView.CARD_SIZE.x
	var w: float = _hand_box.size.x
	if w <= 0.0:
		w = float(get_viewport().get_visible_rect().size.x) - 56.0
	var center_x: float = w / 2.0
	# N4-P1 (chantier 4, MAJEUR) : eventail DE-TRONQUE. L'ancien pas 0,62 x carte coupait les noms
	# (Tenacit...) des 4 cartes et laissait Z5 aux 2/3 vide a 1920. Nouveau pas :
	#   plafond 1,30 x carte (fan aere, zero chevauchement des que la largeur le permet) ;
	#   plancher 142 px = reserve de NOM (le titre, pleine largeur depuis la reserve chantier 4b,
	#   finit a x=141 : la carte suivante ne mord jamais le nom, verifie jusqu'a 8 cartes a 1920
	#   comme a 1280 : 7 x 142 + 150 = 1144 px, ca tient).
	var spacing: float = clampf((w - cw) / float(maxi(n - 1, 1)), 142.0, cw * 1.30)
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


# v11-W2 — sélection du TRAIT sur l'élément : levée +20 px + bordure GOLD ; re-clic = désélection.
# Plus aucun vol vers un combo panel : la carte reste dans l'éventail (pilier MINIMAL).
func _on_trait_card(card: MerlinCard) -> void:
	if _state != 1 or not _choice_open:
		return  # v11-V2a : zone estompée = choix fermé (l'alpha n'est pas une porte, _choice_open l'est)
	_selected_trait = null if _selected_trait == card else card
	for c in _hand_box.get_children():
		if c is MerlinCardView and not c.is_queued_for_deletion():
			(c as MerlinCardView).set_selected((c as MerlinCardView).card == _selected_trait)
	_update_preview()


# v11-W2 — sélection de l'ACTION sur la tuile : bordure GOLD 3 px ; re-clic = désélection.
func _on_action_tile(card: MerlinCard) -> void:
	# v11-W3 — pendant le draft de greffe, la tuile est une CIBLE : dispatch AVANT le check _state
	# (le draft vit en _state 2 — la garde _draft_active prime, vigilance V2b #2).
	if _draft_active:
		_on_graft_target(card)
		return
	if _state != 1 or not _choice_open:
		return  # v11-V2a : même garde que les traits — clic hors phase de choix ignoré
	if _tuto_b_active:
		# v11-V2b — hint B désarmé au PREMIER clic de tuile du beat 2 (one-shot, persisté [tuto]).
		_tuto_b_active = false
		MerlinVisual.tuto_hint_b_done = true
		MerlinVisual.save_prefs()
		_clear_tuto_hint()
	_selected_action = null if _selected_action == card else card
	for v in _action_views:
		if is_instance_valid(v):
			(v as MerlinActionView).set_selected((v as MerlinActionView).card == _selected_action)
	_update_preview()


# Retrouve la tuile d'une action (null si absente) — les MerlinCard d'action sont partagées avec run.actions.
func _tile_for(action: MerlinCard) -> MerlinActionView:
	for v in _action_views:
		if is_instance_valid(v) and (v as MerlinActionView).card == action:
			return v
	return null


# v2-W2 — retrouve la tuile par VERBE (card_name de l'action) : la cible d'un nœud de talent.
func _tile_for_verb(verb: String) -> MerlinActionView:
	for v in _action_views:
		if is_instance_valid(v) and str((v as MerlinActionView).card.card_name) == verb:
			return v
	return null


# v11-W2 — construit les 4 tuiles PERMANENTES depuis run.actions (objets partagés : la sélection
# compare par référence). Appelé à _begin (après new_run/load_run) ; re-render léger par beat via
# _refresh_action_tiles — jamais de rebuild.
func _build_action_tiles() -> void:
	if _action_bar == null:
		return
	for v in _action_views:
		if is_instance_valid(v):
			(v as MerlinActionView).queue_free()
	_action_views = []
	var run: Node = get_node("/root/MerlinRun")
	var acts: Array = run.actions
	for i in acts.size():
		var av: MerlinActionView = MerlinActionView.new()
		_action_bar.add_child(av)
		_action_bar.move_child(av, i)  # tuiles AVANT le gap/bouton (ordre stable des 4 verbes)
		av.setup(acts[i])
		av.action_clicked.connect(_on_action_tile)
		_action_views.append(av)


# v11-W2 — re-render léger des tuiles : sélection, bénédictions R131 (badge ✦tag), feedforward
# (souligné GOLD pulsé quand la tuile couvre ≥1 tag requis du beat — spec §I).
func _refresh_action_tiles() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var reqs_canon: Array = []
	for r in _current_situation.get("required_tags", []):
		reqs_canon.append(MerlinTags.to_canon(str(r)))
	for v in _action_views:
		if not is_instance_valid(v):
			continue
		var av: MerlinActionView = v
		av.set_selected(av.card == _selected_action)
		av.set_talent(run.skill_mod_for(av.card))  # v2-W2 : badge « +N » = niveau de talent du verbe (skill_mod visible)
		var btag: String = str(run.blessed_tags.get(str(av.card.id), ""))
		av.set_blessed(btag)
		var covers: bool = false
		for t in av.card.tags:
			if reqs_canon.has(MerlinTags.to_canon(str(t))):
				covers = true
		if btag != "" and reqs_canon.has(MerlinTags.to_canon(btag)):
			covers = true
		av.set_feedforward(covers)


# N4-RUNES (2026-07-11) : _render_required_tags SUPPRIMÉE (chips « ce lieu réclame » retirées de
# l'encart). Les required_tags restent 100 % MÉCANIQUES (couverture, feedforward, moteur d20) :
# l'affinité se lit au souligné GOLD des tuiles + à la preview de résolution (R120).


# Retrouve la vue d'une carte dans un conteneur (main ou combo) — null si absente/libérée.
func _find_card_view(box: Control, card: MerlinCard) -> MerlinCardView:
	if box == null:
		return null
	for c in box.get_children():
		if c is MerlinCardView and not c.is_queued_for_deletion() and (c as MerlinCardView).card == card:
			return c
	return null


func _update_preview() -> void:
	# v11-W2 : le geste canonique = 1 ACTION + 1 TRAIT. La résolution ne s'arme qu'à la paire complète
	# (bouton Résoudre CONSERVÉ, spec §A — jamais de résolution auto au 2e clic).
	if _selected_action == null or _selected_trait == null:
		_set_resolve_armed(false)
		return
	var combo: Array = [_selected_action, _selected_trait]
	var reqs: Array = _current_situation.get("required_tags", [])
	var run_p: Node = get_node("/root/MerlinRun")
	# v2-W2/W3 — skill_mod = talent du VERBE ; graft_bonus = greffes « roll » posées sur l'action.
	# La preview passe EXACTEMENT les mêmes arguments que la résolution (die, diff, skill_mod, graft_bonus) — R120.
	var skill_mod_p: int = run_p.skill_mod_for(_selected_action)
	var graft_bonus_p: int = run_p.graft_roll_bonus(_selected_action)
	var res: Dictionary = MerlinResolution.resolve(reqs, combo, [], int(_current_situation.get("die", 0)),
		run_p.blessed_bonus(combo),
		int(_current_situation.get("difficulte", 2)), skill_mod_p, graft_bonus_p)  # R131 + d20 + talent + greffes-jet : preview = résolution (R120)
	var was_disabled: bool = _resolve_btn.disabled
	_set_resolve_armed(true)
	# v11-V2a (dé-jargonnage) — l'indice de dé est SUPPRIMÉ : le liseré de la tuile porte déjà la
	# qualité du jet (R133) ; le bouton qui s'arme suffit à dire « la paire est complète ».
	if was_disabled and _choice_open:
		MerlinAudio.play_sfx("draft_reveal")
		_pop(_resolve_btn, 1.15)
		_selection_complete_pulse()
	if _tuto_a_active:
		# v11-V2b — hint A désarmé à la PREMIÈRE paire complète (one-shot, persisté [tuto]).
		_tuto_a_active = false
		MerlinVisual.tuto_hint_a_done = true
		MerlinVisual.save_prefs()
		_clear_tuto_hint()
	# v10.4 — pré-génération LLM spéculative sur la SÉLECTION courante uniquement (guardrail spec :
	# jamais les 16 combos). Dédupée par signature combo [action, trait] côté MerlinScenario.
	get_node("/root/MerlinScenario").prefetch_resolution(_current_situation, combo.duplicate(), res)


func _on_resolve() -> void:
	# v11-W2 : résolution UNIQUEMENT sur la paire complète ACTION + TRAIT (le geste canonique).
	if _state != 1 or _selected_action == null or _selected_trait == null:
		return
	_state = 2
	_set_resolve_armed(false)  # Z6 : désarmé (alpha 0.35 + disabled) — le bouton ne disparaît jamais
	var run: Node = get_node("/root/MerlinRun")
	var sc: Node = get_node("/root/MerlinScenario")
	var combo: Array = [_selected_action, _selected_trait]  # [0] = action (contrat resolve R20)
	var reqs: Array = _current_situation.get("required_tags", [])
	# v2-W2/W3 — mêmes arguments que la preview (die, diff, skill_mod=talent du verbe, graft_bonus=greffes roll) → R120.
	var skill_mod_r: int = run.skill_mod_for(_selected_action)
	var graft_bonus_r: int = run.graft_roll_bonus(_selected_action)
	var res: Dictionary = MerlinResolution.resolve(reqs, combo, [], int(_current_situation.get("die", 0)),
		run.blessed_bonus(combo),
		int(_current_situation.get("difficulte", 2)), skill_mod_r, graft_bonus_r)  # R131 + d20 + talent + greffes-jet : mêmes args que la preview (R120)
	var played_cards: Array = combo.duplicate()  # cartes (objets) → interprétation LLM de la combinaison
	var situ: Dictionary = _current_situation.duplicate(true)  # fige la situation (LLM toujours pertinent)

	# v10.20 — capture des Δ jauges (net : coût + effets + résolution) pour la VIGNETTE d'effet. user 2026-06-29.
	var int_before: int = int(run.get("integrite"))
	var corr_before: int = int(run.get("corruption"))
	# v11-W1 (spec panel, CRITICAL UX) — le MODÈLE s'applique immédiatement (invariants soak intacts)
	# mais le COMMIT VISUEL des anneaux est différé : joués maintenant, les deltas seraient INVISIBLES
	# sous le layer plein écran de MerlinFx. _flush_gauges() rejoue tout après le typewriter.
	_gauges_deferred = true
	run.play_and_discard(combo)  # v11 : l'action (permanente) y est ignorée côté défausse
	run.note_verb_played(combo[0])  # v2-W2 : compteur d'usage du verbe (cible du nœud de talent au draft)
	run.consume_blessings(played_cards)  # R131 : une bénédiction sert UNE fois (érodée à la pose)
	run.apply_card_effects(played_cards)  # v10.11 : effets actifs (Rare+) AVANT le check de mort (un HEAL peut sauver)
	# v11-W3 (spec §E) — charges de GREFFE du verbe joué (HEAL/PURGE/DRAW, 1 charge consommée par
	# greffe "charge"), à côté des effets de cartes — mêmes règles, AVANT le check de mort.
	var graft_fx: Dictionary = run.apply_graft_charges(combo[0])
	# v10.21 (Wave G, R130) — PARTIEL = CHOIX : si budget Pousser disponible, l'application de la
	# résolution est DIFFÉRÉE jusqu'au choix Encaisser/Pousser (post-lecture). Sinon flux inchangé.
	var deg_raw: String = str(res.get("degree", ""))
	_push_pending = deg_raw == MerlinResolution.PARTIEL \
		and int(run.get("pushes_left_quest")) > 0 and not run.ended
	if _push_pending:
		_push_res_raw = res.duplicate(true)  # deltas BRUTS préservés pour l'application différée
		_push_situ = situ
		_push_cards = played_cards
	else:
		run.apply_resolution(res)
		run.gain_talent_points(str(res.get("degree", "")))  # v2-W2 : points de talent au degré FINAL (réussite +1 / éclatante +2)
	res["integrite_delta"] = int(run.get("integrite")) - int_before
	res["corruption_delta"] = int(run.get("corruption")) - corr_before
	var fx_effects: Array = []  # effets actifs déclenchés (HEAL/PURGE/DRAW) pour les glyphes de la vignette
	for c in played_cards:
		if c is MerlinCard and str(c.effect_type) != "":
			fx_effects.append(str(c.effect_type))
	# v11-W3 — les charges de greffe déclenchées alimentent les mêmes chips (info à UN endroit §23).
	if int(graft_fx.get("heal", 0)) > 0 and not fx_effects.has("HEAL"):
		fx_effects.append("HEAL")
	if int(graft_fx.get("purge", 0)) > 0 and not fx_effects.has("PURGE"):
		fx_effects.append("PURGE")
	if int(graft_fx.get("draw", 0)) > 0 and not fx_effects.has("DRAW"):
		fx_effects.append("DRAW")
	res["fx_effects"] = fx_effects
	# Draft « 1 carte sur 3 » armé : SEULEMENT aux beats clés (réussite/éclatante) tant qu'il reste des beats.
	var deg: String = str(res.get("degree", ""))
	_pending_draft = (deg == MerlinResolution.REUSSITE or deg == MerlinResolution.ECLATANTE) and not run.is_climax() and not run.ended
	if not _push_pending:  # R130 : différé → consigné au CHOIX avec le degré FINAL
		run.faits_marquants.append("%s → %s" % [str(_current_situation.get("type", "")), str(res["label"])])
		if run.faits_marquants.size() > 6:
			run.faits_marquants = run.faits_marquants.slice(run.faits_marquants.size() - 6, run.faits_marquants.size())

	_scene_epoch += 1
	var ep: int = _scene_epoch
	# v11-W2 — capture des vues AVANT le clear : SEULE la vue du TRAIT vole dans la fusion (aspirée
	# par MerlinFx) ; l'ACTION est une tuile permanente qui PULSE sur place pendant la séquence.
	var trait_view: MerlinCardView = _find_card_view(_hand_box, _selected_trait)
	var tile: MerlinActionView = _tile_for(_selected_action)
	_selected_action = null
	_selected_trait = null
	# v11-V2a : la MAIN s'estompe (ÉVIDENT : on lit l'issue) mais la rangée d'actions reste PLEINE
	# alpha pendant la fusion — la tuile jouée pulse à 1.0 ; l'estompe de Z6 part APRÈS fx.run().
	_set_hand_dimmed(true)
	_can_advance = false    # « avancer » (clic) seulement quand l'issue est entièrement écrite

	# v10.2 — Animation cinématique de fusion AVANT la prose. Pendant ce temps la pré-génération
	# LLM (lancée à la pose, _update_preview) continue → masque la latence (user 2026-06-06).
	# v10.13 (A2) : la fusion vit dans MerlinFx (layer autonome — tweens liés à lui, auto-queue_free).
	# La vue du trait est capturée ICI puis reparentée dans le layer par MerlinFx ;
	# le prédicat `ready` injecte is_resolution_ready (le sustain ne lit plus /root/MerlinScenario).
	var vues_du_combo: Array = []
	if trait_view != null:
		vues_du_combo.append(trait_view)
	if tile != null:
		tile.set_selected(false)
		tile.queue_redraw()  # v11-W3 : compteurs de charges décrémentés → slots redessinés
		tile.fusion_pulse(true)  # la tuile bat au rythme de la fusion — jamais aspirée
	if _scene_art != null:
		_scene_art.set_thinking(true)  # R128 : Merlin « réfléchit » (halo lune accéléré) pendant la fusion + l'attente LLM
	# N4-BUG #2b : décision d'attente prise AU CLIC (sticky, begin_resolution_wait) : si AUCUNE prose
	# n'est en route pour CETTE combo (cache vide + rien en vol : cold start, moteur pris par l'arc,
	# drain échoué), la résolution est fallback-bound → AUCUN sustain (~2-3 s de fusion au lieu du cap
	# ~12 s, mesuré 14,4-14,7 s clic→issue avant fix) et la demande #2a est abandonnée (model_ready
	# mi-fusion ne confisque plus la fenêtre pour une prose trop tardive). Une gen en vol AU CLIC pour
	# cette combo garde toute sa fenêtre (le prédicat reste dynamique : gen morte en route = fallback) ;
	# le clic-skip du sustain reste intact.
	var wait_worth: bool = sc.begin_resolution_wait(played_cards, res)
	# N4-P1 (chantier 2b) : le stinger de degré (_play_seal_audio) est déclenché PAR le d20 à
	# l'instant du halo (pose → pause 0,35 s → verdict), plus jamais avant. Sans dé sur ce beat,
	# _show_resolution garde le stinger (repli inchangé).
	var fx: MerlinFx = MerlinFx.play(self, res, played_cards, vues_du_combo, func() -> bool:
		return not wait_worth or sc.is_resolution_ready(played_cards, res) \
			or not sc.is_resolution_incoming(played_cards, res),
		func() -> void:
			if is_instance_valid(self):  # review P1 HIGH-1 : le dé (hébergé hors layer) peut survivre à la scène
				_play_seal_audio(deg))
	await fx.run()
	if tile != null and is_instance_valid(tile):
		tile.fusion_pulse(false)
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

	# v11-W1 : le jet de dé vit DANS la fusion (MerlinFx.run Phase 3, en chevauchement sur la décrue) —
	# plus de second dé séquentiel ici (le doublon rallongeait la séquence et brouillait la lecture).
	_set_choice_ui(false)   # v11-V2a : estompe Z5+Z6 APRÈS la fusion — l'issue occupe l'encart, SEULE

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
		# N2a — secours COMPOSÉ : reflète la combinaison (registre des cartes) + le biome + le degré.
		prose = sc.fallback_resolution(str(res.get("degree", "reussite")), str(situ.get("type", "")),
			played_cards, str(run.get("biome")))
	prose = MerlinProse.ensure_italic_action(prose)  # v11-N1 (R140) : 1re phrase = action en [i]…[/i] (robustesse si le LLM oublie l'italique)
	if not _push_pending:  # R130 : différé → note_outcome au CHOIX avec le degré FINAL
		sc.note_outcome(res, situ, played_cards)  # v10.20.1 : gist SPÉCIFIQUE (action réelle) + pont vers la situation suivante
	run.summary = prose
	_show_resolution(res, prose, true)
	# v10.13 (Fix 6) : PLUS de save ici — il persistait les jauges post-résolution avec un beat_index
	# non avancé → la reprise REJOUAIT le beat (coûts double-appliqués). Save unique dans _advance_to_next.


# === v10.13 (A2) / v11-W1 — L'animation de fusion (3 phases + sustain skippable) vit dans MerlinFx ===
# scripts/game/merlin_fx.gd : consts FUSION_* / VIGNETTE_SHADER_CODE, run() (Rassemblement→Burst→
# Décrue+Dé + sustain), spark_wave public, shake static. Le dé (MerlinDice) est lancé PAR MerlinFx.


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
	# N4-P1 (chantier 2b) : avec un d20 sur ce beat, le stinger a DÉJÀ joué à l'instant du halo
	# (callback passé à MerlinFx.play). Il ne joue ici qu'en repli sans dé (res["die"] < 1).
	if int(res.get("die", 0)) < 1:
		_play_seal_audio(degree)  # stinger de degré (repli sans jet)
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


# === v10.21 (Wave I, R131) — INTERVENTIONS du pilier : il revient se mêler du sentier (1-2×/run) ===
# Lignes SIGNÉES (panel design, docs/spec_v10.21_presences.md) écrites À LA SUITE du fil (R128).
const INTERVENTION_LINES: Dictionary = {
	"choeur": "Nous avons chanté sur celle-ci, Voyageur — quand ta main la lâchera, la forêt se souviendra que tu fus des nôtres.",
	"chevalier": "Je n'ai plus de cause, alors prends mon fer — qu'il tranche pour toi ce que je n'ai pas su défendre.",
	"etre": "Accepte, et ce que tu ne sais pas nommer ouvrira les portes à ta place — il suffit que tu me laisses entrer, un peu.",
	"compagnon": "Prends, comme avant — là où je marche on ne garde rien, et ce que cela te coûte, tu me le rendras plus tard.",
	"enfant": "Regarde, j'ai écarté les ronces pour toi — c'est facile, quand on me laisse faire.",
}
var _intervention_done_this_beat: bool = false
var _pact_row: HBoxContainer = null
# Review V2b MEDIUM-5 — pacte en DONE-PATH : posé par _play_intervention, consommé par
# _on_typewriter_done (appelé AUSSI au skip — un tween tué n'émet jamais `finished`, l'ancien
# `await _tw.finished` perdait le pacte unique de la run sur un simple clic de skip).
var _pact_pending_pilier: String = ""


# Ce beat est-il planifié pour une intervention ? Consommation à l'OUVERTURE (R108) + save atomique.
func _maybe_intervention() -> bool:
	var run: Node = get_node("/root/MerlinRun")
	if _intervention_done_this_beat or run.ended or run.is_climax():
		return false
	# v11-V2b : cap 1/run (était 2) — une save W2 avec 2 beats planifiés reste valide, le cap coupe ici.
	if not (run.intervention_beats as Array).has(run.beat_index) or int(run.pilier_interventions) >= 1:
		return false
	var pk: String = _current_offer_pilier()
	if pk == "":
		return false
	_intervention_done_this_beat = true
	run.intervention_beats.erase(run.beat_index)
	run.pilier_interventions = int(run.pilier_interventions) + 1
	run.save()  # même le quit mid-séquence ne re-proposera jamais cette intervention
	_play_intervention(pk)
	return true


# Séquence scriptée (~1.8s, spec panel) : silhouette + nappe + réaction lune + ligne signée dans le fil
# + effet. Les effets SANS consentement (bénédictions) s'appliquent à l'ouverture ; les pactes via boutons.
func _play_intervention(pk: String) -> void:
	if _scene_art != null:
		_scene_art.set_pilier(pk, true)
		if pk == "choeur" or pk == "chevalier":
			_scene_art.set_eye_mood("neutral")
			_scene_art.flash_moon()
		else:
			_scene_art.set_eye_mood("surprise")
	MerlinAudio.play_pad("pad_" + pk)
	# Effets SANS consentement (bénédiction/aide) appliqués à l'ouverture — R108 : payés = acquis.
	if pk == "choeur" or pk == "chevalier" or pk == "enfant":
		_apply_blessing(pk)
	# Ligne signée écrite À LA SUITE (pattern R128 from_chars) → le handler state 1 re-passe ensuite.
	var situ_chars: int = _situation_text.get_total_character_count()
	var combined: String = _situation_text.text.replace("[/center]",
		"\n\n« %s »[/center]" % str(INTERVENTION_LINES.get(pk, "")))
	_typewriter(combined, true, _situation_text, situ_chars)
	# Pactes opt-in (Être / Compagnon) : boutons à la FIN de l'écriture — done-path, jamais d'await
	# sur _tw.finished (review V2b MEDIUM-5 : le skip tue le tween sans émettre `finished`).
	if pk == "etre" or pk == "compagnon":
		_pact_pending_pilier = pk


# Bénédiction (v11-W2, spec §G) : une ACTION gagne un tag temporaire VISIBLE (badge sur la tuile),
# consommé à la pose. Les ids action_* sont STABLES → run.blessed_tags[action_id] survit au resume (R108).
# Chœur = Nature/Équilibre · Chevalier = Force/Autorité · Enfant = un tag REQUIS du beat (l'aide innocente).
func _apply_blessing(pk: String) -> void:
	var tag: String = ""
	match pk:
		"choeur":
			tag = "Nature" if randf() < 0.5 else "Équilibre"
		"chevalier":
			tag = "Force" if randf() < 0.5 else "Autorité"
		"enfant":
			var reqs2: Array = _current_situation.get("required_tags", [])
			if reqs2.is_empty():
				return
			tag = str(reqs2[randi() % reqs2.size()])
	_bless_action(tag)
	get_node("/root/MerlinRun").save()


# Pose la bénédiction sur une action ÉLIGIBLE : ne portant pas déjà le tag (fallback : la première).
func _bless_action(tag: String) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var acts: Array = run.actions
	if acts.is_empty() or tag == "":
		return
	var pick: MerlinCard = null
	for a in acts:
		if a is MerlinCard and not ((a as MerlinCard).tags as Array).has(tag):
			pick = a
			break
	if pick == null:
		pick = acts[0]
	run.blessed_tags[str(pick.id)] = tag
	_refresh_action_tiles()  # badge ✦tag visible immédiatement (pilier ÉVIDENT)


# Pacte opt-in (1 geste, prix AFFICHÉ) : Être = la porte s'ouvre (tag requis béni) contre +1 Corruption ;
# Compagnon = pioche 1 contre +1 Corruption. Refuser = rien. Ignorable (la main reste jouable).
func _build_pact_choice(pk: String) -> void:
	var run: Node = get_node("/root/MerlinRun")
	# v11-V2b (vigilance V2a #2) — le slot central Z4 ne porte qu'UN contenu à la fois : la vignette
	# du beat précédent est purgée et le hint tuto s'efface (sans être consommé) devant le pacte.
	_clear_tuto_hint()
	if _effect_vignette != null:
		for c in _effect_vignette.get_children():
			c.queue_free()
	_pact_row = HBoxContainer.new()
	_pact_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pact_row.add_theme_constant_override("separation", 24)
	var acc: Button = Button.new()
	acc.text = ("Accepter  (la voie s'ouvre · Corruption +1)" if pk == "etre"
		else "Accepter  (pioche 1 · Corruption +1)")
	var ref: Button = Button.new()
	ref.text = "Refuser"
	for b in [acc, ref]:
		var btn: Button = b
		btn.custom_minimum_size = Vector2(300, 52)
		btn.add_theme_font_size_override("font_size", 18)
		MerlinVisual.apply_button_da(btn)
		MerlinVisual.connect_button_feedback(btn)
		_pact_row.add_child(btn)
	acc.pressed.connect(_on_pact_choice.bind(pk, true))
	ref.pressed.connect(_on_pact_choice.bind(pk, false))
	if _res_block != null:
		_res_block.add_child(_pact_row)
		_fade_res_block(true)


func _on_pact_choice(pk: String, accepted: bool) -> void:
	var run: Node = get_node("/root/MerlinRun")
	if accepted:
		if pk == "etre":
			# v11-W2 : le pacte de l'Être bénit une ACTION (tag requis → la porte s'ouvre par le verbe).
			var reqs3: Array = _current_situation.get("required_tags", [])
			if not reqs3.is_empty():
				_bless_action(str(reqs3[randi() % reqs3.size()]))
		elif pk == "compagnon":
			run.draw_extra(1)
			_render_hand(true)
		run.add_corruption(1)  # le prix du pacte — affiché sur le bouton AVANT le clic
		run.save()
	if _pact_row != null and is_instance_valid(_pact_row):
		_pact_row.queue_free()
		_pact_row = null
	if _res_block != null and _effect_vignette != null and _effect_vignette.get_child_count() == 0:
		_fade_res_block(false)  # rien d'autre à montrer dans le slot central


# v10.21 (Wave G, R130) — Choix « Encaisser / Pousser » sous la vignette : 1 geste, zéro timer (R99),
# boutons ≥44 px, LEDGER affiché par bouton (prix criant AVANT le clic). Anti-misclick : disabled 250 ms.
const PUSH_CODAS: Array = [
	"[i]Vous forcez votre volonté dans la brèche.[/i] La forêt cède — mais quelque chose s'infiltre dans votre sillage.",
	"[i]Vous poussez le passage d'un souffle de plus.[/i] La voie s'ouvre en grand ; l'ombre, elle, retient votre nom.",
	"[i]Vous arrachez ce dernier effort à vous-même.[/i] La forêt plie, et prélève sa part sans un mot.",
]


func _build_push_choice() -> void:
	var run: Node = get_node("/root/MerlinRun")
	# v11-V2b (vigilance V2a #1) — Z4 ne porte qu'UN contenu : boutons+ledger D'ABORD, la vignette
	# sera re-frappée APRÈS le choix au degré FINAL (_on_push_choice). Purge du slot avant pose.
	_clear_tuto_hint()
	if _effect_vignette != null:
		for c in _effect_vignette.get_children():
			c.queue_free()
	_push_row = HBoxContainer.new()
	_push_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_push_row.add_theme_constant_override("separation", 24)
	_push_row.mouse_filter = Control.MOUSE_FILTER_PASS
	var corr_cost: int = int(_push_res_raw.get("corruption_delta", 0))
	var enc: Button = Button.new()
	enc.text = "Encaisser  (Intégrité %d · Corruption +%d)" % [int(_push_res_raw.get("integrite_delta", 0)), corr_cost]
	var pou: Button = Button.new()
	var proj: int = int(run.get("corruption")) + corr_cost + MerlinResolution.PUSH_PRICE
	pou.text = "Pousser  (Réussite · Corruption +%d → %d)" % [corr_cost + MerlinResolution.PUSH_PRICE, proj]
	for b in [enc, pou]:
		var btn: Button = b
		btn.custom_minimum_size = Vector2(320, 56)  # ≥44 px (pilier TACTILE)
		btn.add_theme_font_size_override("font_size", 18)
		MerlinVisual.apply_button_da(btn)
		MerlinVisual.connect_button_feedback(btn)
		btn.disabled = true  # anti-misclick : armés après 250 ms
		_push_row.add_child(btn)
	enc.pressed.connect(_on_push_choice.bind(false))
	pou.pressed.connect(_on_push_choice.bind(true))
	if _res_block != null:
		_res_block.add_child(_push_row)
		_fade_res_block(true)
	var arm_tw: Tween = create_tween()
	arm_tw.tween_interval(0.25)
	arm_tw.tween_callback(func() -> void:
		if is_instance_valid(enc):
			enc.disabled = false
		if is_instance_valid(pou):
			pou.disabled = false)


func _on_push_choice(push: bool) -> void:
	if not _push_pending and _push_res_raw.is_empty():
		return
	_push_pending = false
	var run: Node = get_node("/root/MerlinRun")
	var sc: Node = get_node("/root/MerlinScenario")
	if push:
		_push_res_raw["degree"] = MerlinResolution.REUSSITE
		_push_res_raw["integrite_delta"] = 0  # l'Intégrité est ÉPARGNÉE ; le prix du partiel reste dû
		_push_res_raw["corruption_delta"] = int(_push_res_raw.get("corruption_delta", 0)) + MerlinResolution.PUSH_PRICE
		_push_res_raw["label"] = str(_push_res_raw.get("label", "")) + " (forcé)"
		run.set("pushes_left_quest", int(run.get("pushes_left_quest")) - 1)
	run.apply_resolution(_push_res_raw)  # application UNIQUE différée
	run.gain_talent_points(str(_push_res_raw.get("degree", "")))  # v2-W2 : points de talent au degré FINAL (poussé = réussite → +1)
	_flush_gauges()  # v11-W1 : le choix est fait → les anneaux jouent le delta cumulé (coût + résolution finale)
	run.faits_marquants.append("%s → %s" % [str(_push_situ.get("type", "")), str(_push_res_raw.get("label", ""))])
	if run.faits_marquants.size() > 6:
		run.faits_marquants = run.faits_marquants.slice(run.faits_marquants.size() - 6, run.faits_marquants.size())
	sc.note_outcome(_push_res_raw, _push_situ, _push_cards)  # fil rouge avec le degré FINAL (R120)
	if push and _situation_text != null:
		# Coda procédurale écrite dans le MÊME fil (R128).
		_situation_text.text = _situation_text.text.replace("[/center]",
			"\n\n" + str(PUSH_CODAS[randi() % PUSH_CODAS.size()]) + "[/center]")
		_situation_text.visible_characters = -1
	# v11-V2b (vigilance V2a #1) — cross-fade Z4 : les boutons partent, la vignette re-frappée au
	# degré FINAL arrive (encaissé = partiel, poussé = réussite forcée). Un contenu à la fois.
	var final_res: Dictionary = _push_res_raw
	var final_deg: String = str(_push_res_raw.get("degree", MerlinResolution.PARTIEL))
	var row: HBoxContainer = _push_row
	_push_row = null
	_push_res_raw = {}
	if run.ended:
		if row != null and is_instance_valid(row):
			row.queue_free()
		return  # mort/fin via l'application différée → run_ended a pris la main
	MerlinVisual.swap_zone(_res_block, func() -> void:
		if row != null and is_instance_valid(row):
			row.queue_free()
		_build_effect_vignette(final_res, final_deg))
	_can_advance = true
	if _caret != null:
		_caret.text = "▮ cliquer pour continuer"
	_set_caret(true)


# v10.20 — Vignette d'effet (sous le filet) : badge de degré + Δ jauges + glyphes d'effet de carte. Fondu d'entrée.
func _build_effect_vignette(res: Dictionary, degree: String) -> void:
	if _effect_vignette == null:
		return
	for c in _effect_vignette.get_children():
		c.queue_free()
	# v11-W1 (spec panel) — PILL de degré 170×48 : UN SEUL marqueur, lisible (l'ancien badge rond 58 px
	# au libellé 11 px violait §23). Pastille 32 px = couleur du degré ; libellé 19 px CREAM sur SURFACE.
	var pill: PanelContainer = PanelContainer.new()
	pill.custom_minimum_size = Vector2(170, 48)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = MerlinVisual.SURFACE
	psb.set_corner_radius_all(24)
	psb.set_border_width_all(1)
	psb.border_color = _degree_color(degree)
	psb.set_content_margin_all(8)
	pill.add_theme_stylebox_override("panel", psb)
	var prow: HBoxContainer = HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(prow)
	var pdot: Panel = Panel.new()
	pdot.custom_minimum_size = Vector2(32, 32)
	pdot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pdot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dsb: StyleBoxFlat = StyleBoxFlat.new()
	dsb.bg_color = _degree_color(degree)
	dsb.set_corner_radius_all(16)
	pdot.add_theme_stylebox_override("panel", dsb)
	prow.add_child(pdot)
	var blbl: Label = Label.new()
	blbl.text = str(DEGREE_SEAL_LABEL.get(degree, "RÉUSSITE"))
	blbl.add_theme_color_override("font_color", MerlinVisual.CREAM)
	blbl.add_theme_font_size_override("font_size", 19)
	blbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	blbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prow.add_child(blbl)
	_effect_vignette.add_child(pill)
	# Slam bref — le sceau se pose (0,25 s ×motion), sans écraser la lecture. Pivot recalé au layout
	# réel (review : la min-size 170 peut être dépassée par le libellé — jamais de moitié en dur).
	if not MerlinVisual.reduced_motion:
		pill.resized.connect(func() -> void: pill.pivot_offset = pill.size * 0.5)
		pill.pivot_offset = pill.custom_minimum_size * 0.5
		pill.scale = Vector2(1.35, 1.35)
		pill.create_tween().tween_property(pill, "scale", Vector2.ONE,
			0.25 * MerlinVisual.motion()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# N4-P1 (chantier 7, MAJEUR) : le gain de talent (R142, silencieux jusqu'ici) devient VISIBLE :
	# micro-label GOLD flottant pres de la pill, meme canal que les deltas d'anneaux (float_delta).
	# R130 : la vignette est TOUJOURS batie au degre FINAL (partiel pousse = reussite via
	# _on_push_choice) : l'affichage colle exactement a run.gain_talent_points. Differe d'une frame
	# (call_deferred) : la pill vient d'entrer dans le HBox, son global_position attend le layout.
	var run_tp: Node = get_node("/root/MerlinRun")
	var tp_gain: int = 0
	if degree == MerlinResolution.REUSSITE:
		tp_gain = int(run_tp.TALENT_GAIN_REUSSITE)
	elif degree == MerlinResolution.ECLATANTE:
		tp_gain = int(run_tp.TALENT_GAIN_ECLATANTE)
	if tp_gain > 0:
		call_deferred("_float_talent_gain", pill, tp_gain)
	# v11-W0 (user : « un compteur avec des chiffres ») — les chips chiffrées Intégrité/Corruption sont
	# SUPPRIMÉES : les deltas de jauges vivent dans les ANNEAUX animés (float_delta), un seul endroit (§23).
	# v2-W4 (2026-07-05) — la chip « ⚄ Le sort a souri » (proxy die_mod) est SUPPRIMÉE : le HALO du d20
	# (vert = réussi, rouge = raté, MerlinFx) porte désormais l'issue du jet, et la pill porte le degré.
	# Plus AUCUN lecteur de rendu ne dépend de die_mod/die_rarity (§K, décision W4). MINIMAL (§23).
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
	# v11-V2b — chips re-calibrées pour BG_PAGE (elles vivaient sur la crème en amont de V2a) :
	# fond 0.18→0.30 + libellé éclairci (dérivé de la couleur de palette, zéro hex nouveau).
	sb.bg_color = Color(col.r, col.g, col.b, 0.30)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = col
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col.lightened(0.35))
	l.add_theme_font_size_override("font_size", 18)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


# v11-W1 — libellés de degré de la PILL (_build_effect_vignette). L'ancien sceau circulaire B9
# (_slam_degree_seal, 96 px haut-droit) était du code MORT depuis R128 — supprimé, la pill est
# l'UNIQUE marqueur de degré (§23 : l'info ne vit qu'à UN endroit).
const DEGREE_SEAL_LABEL: Dictionary = {
	"echec": "ÉCHEC", "partiel": "PARTIEL", "reussite": "RÉUSSITE", "eclatante": "ÉCLATANTE",
}


func _play_seal_audio(degree: String) -> void:
	MerlinAudio.play_stinger(degree)


# N4-P1 (chantier 7) : « ✦ +N » GOLD flottant pres de la pill de degre (gain de talent R142).
# Appele en deferred depuis _build_effect_vignette (layout du HBox pose). Gardes : la pill a pu
# mourir si la zone a ete re-swappee dans la meme frame (R130 push) : silence, jamais de crash.
func _float_talent_gain(anchor: Control, gain: int) -> void:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	MerlinFx.float_text(self, anchor, "✦ +%d" % gain, MerlinVisual.GOLD)


func _advance_to_next() -> void:
	_set_caret(false)
	_can_advance = false
	var run: Node = get_node("/root/MerlinRun")
	# Wave D — offrande du PILIER au beat « Rencontre » (1×/run, INDÉPENDANTE du degré) : le PNJ tend une carte
	# signée par sa nature. REMPLACE le draft standard ce beat. current_beat() = le beat JUSTE résolu (advance_beat
	# n'a pas encore tourné). Le flag pilier_offering_done (posé à l'ouverture, persisté) garantit l'unicité au resume.
	# v11-W3 : les 4 actions pleines (12 greffes) → plus AUCUN draft/offrande ne se déclenche.
	if str(run.current_beat().get("type", "")) == "Rencontre" and not run.pilier_offering_done \
			and not run.ended and run.has_graftable_action():
		var pk: String = _current_offer_pilier()
		if pk != "":
			_pending_draft = false  # l'offrande du pilier remplace le draft standard ce beat
			_scene_epoch += 1
			await _present_pilier_offering(pk)
			if not is_inside_tree():
				return
	# v1.0-V4a (BAL-11-B/GD-27) — draft GARANTI à chaque transition de quête : le beat tout juste
	# résolu referme sa quête (qn == qtotal) et la run continue → une greffe s'offre quel que soit
	# le degré. Le draft sur réussite/éclatante (armé par _on_resolve) reste inchangé.
	var cb: Dictionary = run.current_beat()
	if cb.has("qtotal") and int(cb.get("qn", 1)) >= int(cb.get("qtotal", 1)) \
			and not run.is_climax() and not run.ended and run.has_graftable_action():
		_pending_draft = true
	# N4-TUTO (revue design B3) : le draft d'ouverture DÉCALÉ par le guide se fond dans le gate
	# UNIQUE des drafts servis ici : jamais deux drafts coup sur coup au beat 1. Flag posé à
	# l'armement (même contrat que _end_interstitial : un « Passer » n'est jamais re-proposé,
	# persisté par le save de fin de fonction) ; hors guide, opening_draft_done est déjà true : no-op.
	if run.beat_index == 0 and not run.opening_draft_done and not run.ended \
			and run.has_graftable_action():
		run.opening_draft_done = true
		_pending_draft = true
	# v10.11/v11-W3 — Draft de GREFFE « 1 sur 3 » aux beats clés, AVANT de passer au beat suivant.
	if _pending_draft:
		_pending_draft = false
		if run.has_graftable_action():
			_scene_epoch += 1  # v10.13 (Fix 10) : tout enrichissement LLM en vol ne s'écrit pas sous le modal
			await _present_draft()
			if not is_inside_tree():
				return
	run.advance_beat()
	if run.ended:
		return
	# v10.13 (Fix 6) : save UNIQUE — au DÉBUT de beat (index avancé + carte draftée, atomique).
	# Resume = toujours au début de beat (canon BIBLE.md R73) ; transients (_selected_*/_state) jamais persistés.
	run.save()
	if not is_inside_tree():
		return  # la scène a pu être libérée pendant le draft / via run_ended (sécurité teardown)
	_present_current_beat()


# === v10.11/v11-W3 — Draft de GREFFES « 1 sur 3 » : choisir la greffe PUIS toucher le verbe ===
# v11-V2b : le draft vit DANS les zones (_open_draft_zone) — l'await-loop structurel est conservé.
# Le 2e geste (cible) passe par _on_action_tile (dispatch _draft_active) qui pose la greffe via
# run.apply_graft et lève _draft_done_flag. « Passer » inchangé.
func _present_draft() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var grafts: Array = run.graft_choices(3)
	if grafts.is_empty():
		return
	_begin_graft_draft(grafts, "Une greffe s'offre à toi — choisis, puis touche un verbe", "")
	# v10.13 (Fix 1) : gardes STRUCTURELLES (pas de timeout mural — un joueur AFK sur un choix n'est
	# pas un bug). Les seuls vrais états de blocage = zone refermée / run terminée / scène quittée :
	# tous font sortir la boucle ; sortie sans flag = passer (aucune greffe).
	while not _draft_done_flag and is_inside_tree() and _draft_active and not run.ended:
		await get_tree().process_frame
	if _graft_applied and _beat_map != null:
		_beat_map.mark_draft()  # v10.12 : une greffe posée = déviation visible sur le chemin
	_close_draft_zone()


# v11-W3 — ouverture commune draft/offrande : fabrique les MerlinCard de PRÉSENTATION depuis les
# dicts de greffe (mapping id → graft conservé à part) puis ouvre la zone de draft existante.
func _begin_graft_draft(grafts: Array, title_text: String, pilier: String) -> void:
	_graft_by_id = {}
	_pending_graft = {}
	_graft_applied = false
	_draft_pick = null
	_draft_done_flag = false
	_draft_title_base = title_text
	var offered: Array = _inject_talent_node(grafts)  # v2-W2 : un des 3 choix peut être un NŒUD DE TALENT
	var cards: Array = []
	for g in offered:
		if not (g is Dictionary):
			continue
		_graft_by_id[str((g as Dictionary).get("id", ""))] = g
		cards.append(_graft_presentation_card(g))
	_open_draft_zone(cards, title_text, pilier)


# v2-W2 — quand le joueur a assez de points ET un verbe sous le cap, REMPLACE l'un des choix de draft
# par un nœud de talent (rendu comme une carte de greffe, R136 : zéro nouvel écran). L'id "talent_node"
# est stable → _graft_by_id le retrouve ; _on_draft_card l'applique en 1 geste (le verbe est déjà ciblé).
func _inject_talent_node(grafts: Array) -> Array:
	var run: Node = get_node("/root/MerlinRun")
	if not run.can_offer_talent_node():
		return grafts
	var node: Dictionary = run.build_talent_node()
	node["id"] = "talent_node"  # id stable (jamais confondu avec une greffe d'action)
	var out: Array = grafts.duplicate()
	if out.is_empty():
		out.append(node)
	else:
		out[randi() % out.size()] = node  # remplace UN choix (jamais un 4e — l'écran reste à 3 cartes)
	return out


# v11-W3 — carte de PRÉSENTATION d'une greffe (MerlinCardView réutilisé tel quel) : nom + évocation,
# pastille famille si +tag, badge d'effet si charges, gemme de coût si corr_cost (prix affiché §E).
func _graft_presentation_card(g: Dictionary) -> MerlinCard:
	var kind: String = str(g.get("kind", ""))
	var tags_p: Array = []
	var eff_t: String = ""
	var eff_v: int = 0
	if kind == "tag":
		tags_p = [str(g.get("tag", ""))]
	elif kind == "charge":
		eff_t = str(g.get("effect_type", ""))
		eff_v = int(g.get("effect_value", 1))
	elif kind == "roll":
		# v2-W3 — greffe « +N au jet » : rareté Rare (liseré bleu-acier — distinct du nœud de talent
		# Mythique/GOLD) ; le badge « +N au jet » GOLD est ajouté au build de la vue (set_roll_bonus).
		return MerlinCard.make(str(g.get("id", "")), str(g.get("name", "")), tags_p,
			str(g.get("evocation", "")), 0, "Rare")
	elif kind == "talent":
		# v2-W2 — NŒUD DE TALENT rendu comme une carte de greffe : rareté Mythique (liseré GOLD épais,
		# distinction visuelle immédiate SANS nouvel écran) ; le tag = famille du verbe ciblé (le glyphe
		# de la carte reflète le verbe). Le badge « ✦ +N TALENT » est ajouté à la construction de la vue.
		var fam: String = _verb_family(str(g.get("verb", "")))
		if fam != "":
			tags_p = [fam]
		return MerlinCard.make(str(g.get("id", "")), str(g.get("name", "")), tags_p,
			str(g.get("evocation", "")), 0, "Mythique")
	return MerlinCard.make(str(g.get("id", "")), str(g.get("name", "")), tags_p,
		str(g.get("evocation", "")), int(g.get("corr_cost", 0)), "Commune", eff_t, eff_v)


# v2-W2 — famille (tag) représentative d'un verbe, pour que le glyphe de la carte-nœud reflète le
# verbe ciblé (mêmes familles que MerlinCard.make_actions). "" si verbe inconnu.
const VERB_FAMILY_TAG: Dictionary = {
	"PERCEVOIR": "Sens", "AGIR": "Force", "PARLER": "Verbe", "RESSENTIR": "Instinct",
}


func _verb_family(verb: String) -> String:
	return str(VERB_FAMILY_TAG.get(verb, ""))


# v11-W3 — étape 2 : Z6 se rallume de façon CIBLÉE (vigilance V2b : Z6 est estompée souris OFF
# pendant le draft), les tuiles ÉLIGIBLES (< 3 greffes) pulsent, les pleines restent estompées
# localement (modulate tuile ≠ alpha de zone — un seul propriétaire par niveau, R136).
func _set_draft_target_mode(on: bool) -> void:
	if _action_bar == null:
		return
	MerlinVisual.set_zone_active(_action_bar, on)
	for v in _action_views:
		if not is_instance_valid(v):
			continue
		var av: MerlinActionView = v
		var eligible: bool = ((av.card.grafts as Array).size() < MerlinRun.MAX_GRAFTS_PER_ACTION)
		av.await_pulse(on and eligible)
		av.modulate.a = 0.45 if (on and not eligible) else 1.0


# v11-W3 — reflète la sélection de greffe SUR les cartes du draft (levée + GOLD, set_selected
# existant). card == null → tout désélectionné.
func _select_draft_view(card: MerlinCard) -> void:
	if _hand_box == null:
		return
	for c in _hand_box.get_children():
		if c is MerlinCardView and not c.is_queued_for_deletion():
			(c as MerlinCardView).set_selected((c as MerlinCardView).card == card)


# v11-W3 — re-titre la barre Z4 (cross-fade du LIBELLÉ seul : la zone reste posée, « Passer »
# reste cliquable pendant toute la séquence).
func _set_draft_title(txt: String) -> void:
	if _draft_title_lbl == null or not is_instance_valid(_draft_title_lbl):
		return
	var lbl: Label = _draft_title_lbl
	if not lbl.is_inside_tree() or MerlinVisual.reduced_motion:
		lbl.text = txt
		lbl.modulate.a = 1.0
		return
	if lbl.has_meta("_tw_title"):
		var prev: Tween = lbl.get_meta("_tw_title")
		if prev != null and prev.is_valid():
			prev.kill()
	var t: Tween = lbl.create_tween()
	t.tween_property(lbl, "modulate:a", 0.0, 0.10 * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: lbl.text = txt)
	t.tween_property(lbl, "modulate:a", 1.0, 0.18 * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	lbl.set_meta("_tw_title", t)


# v11-W3 — étape 2, clic tuile : pose de la greffe (cap 3 géré par run.apply_graft, prix one-shot),
# micro-anim slot (pop + flash) + liseré re-dérivé, puis _draft_done_flag → le driver referme la
# zone et le flux normal reprend (_advance_to_next → advance_beat → save unique, R108).
func _on_graft_target(action: MerlinCard) -> void:
	var run: Node = get_node("/root/MerlinRun")
	var g: Dictionary = _pending_graft
	if g.is_empty():
		return  # aucune greffe sélectionnée (étape 1) — clic de tuile ignoré
	if not run.apply_graft(str(action.id), g):
		return  # tuile pleine (non éligible, déjà estompée) — le geste reste ouvert
	_pending_graft = {}
	_graft_applied = true
	var tile: MerlinActionView = _tile_for(action)
	if tile != null:
		tile.graft_pop()                         # glyphe pop TRANS_BACK + flash GOLD
		tile.set_die_rarity(str(action.rarity))  # liseré re-dérivé (rim_for_rarity, R133)
	_set_draft_target_mode(false)
	_draft_done_flag = true


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
			return {"title": "Le Compagnon te tend un présent", "sub": "Sa main est chaude. Ce qu'elle coûte l'est moins."}
		"chevalier":
			return {"title": "Le Chevalier déchu te confie une lame", "sub": "L'acier reste tranchant, même terni."}
		"enfant":
			return {"title": "L'Enfant te montre ce qu'il a trouvé", "sub": "« C'est pour toi », dit-il en souriant."}
	return {"title": "Une greffe s'offre à toi — choisis, puis touche un verbe", "sub": "Elle rejoint tes verbes."}


# Présente l'offrande signée — v11-W3 : la banque du pilier sert des GREFFES (calque exact de
# _present_draft : mêmes gardes structurelles, même cycle 2 gestes). Flag d'unicité posé à
# l'OUVERTURE (résiste resume/replay).
func _present_pilier_offering(pilier_key: String) -> void:
	var run: Node = get_node("/root/MerlinRun")
	run.pilier_offering_done = true  # AVANT le filtre vide : même un skip (banque épuisée) ne re-tente jamais
	var grafts: Array = run.pilier_graft_offering(pilier_key, 2)
	if grafts.is_empty():
		return  # tout déjà greffé → pas d'offrande vide
	var txt: Dictionary = _pilier_offer_text(pilier_key)
	_begin_graft_draft(grafts, str(txt["title"]), pilier_key)
	while not _draft_done_flag and is_inside_tree() and _draft_active and not run.ended:
		await get_tree().process_frame
	if _graft_applied and _beat_map != null:
		_beat_map.mark_draft()
	_close_draft_zone()


# v11-V2b (spec matrice ligne 9) — Draft/Offrande DANS les zones : les 3 cartes REMPLACENT
# l'éventail (cross-fade + deal_in conservé) ; titre + « Passer » dans le slot central de Z4 ;
# le texte d'issue reste dans l'encart (contexte). `pilier` = signature du PNJ (déjà résolue dans
# le titre par l'appelant) — paramètre gardé pour la greffe V3 (tuiles éligibles qui pulsent).
func _open_draft_zone(cards: Array, title_text: String, pilier: String) -> void:
	_draft_open_ms = Time.get_ticks_msec()  # arme la garde F2 (pas de pick aveugle pendant le deal)
	_draft_active = true
	# Z4 : titre + « Passer » sur UNE rangée (72 px — jamais d'empilement), via cross-fade du slot.
	MerlinVisual.swap_zone(_res_block, func() -> void:
		if not _draft_active:
			return  # review V2b LOW-6 : fermé pendant la fenêtre du swap → pas de barre fantôme
		if _effect_vignette != null:
			for c in _effect_vignette.get_children():
				c.queue_free()  # la vignette d'issue cède le slot (un contenu à la fois)
		if _draft_bar != null and is_instance_valid(_draft_bar):
			_draft_bar.queue_free()  # défense : jamais deux barres (re-entrée improbable)
		_draft_bar = HBoxContainer.new()
		_draft_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		_draft_bar.add_theme_constant_override("separation", 24)
		var title: Label = MerlinVisual.make_label(COL_GOLD, MerlinVisual.FS_CAPTION)
		title.text = title_text
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_draft_bar.add_child(title)
		_draft_title_lbl = title  # v11-W3 : re-titré à l'étape cible (cross-fade du libellé)
		var skip: Button = Button.new()
		skip.text = "Passer"
		skip.custom_minimum_size = Vector2(180, 52)  # ≥44 px (pilier TACTILE)
		skip.add_theme_font_size_override("font_size", MerlinVisual.FS_CAPTION)
		MerlinVisual.apply_button_da(skip)
		MerlinVisual.connect_button_feedback(skip)  # feedback canon §21 `tap`
		skip.pressed.connect(_on_draft_skip)
		_draft_bar.add_child(skip)
		if _res_block != null:
			_res_block.add_child(_draft_bar))
	# (Review V2b MEDIUM-3 : pas de _fade_res_block(true) ici — le swap_zone termine déjà à
	# alpha 1.0 ; deux tweens sur le même modulate = pop sans cross-fade.)
	# Z5 : les 3 cartes remplacent l'éventail — fade-out du contenu puis deal_in en cascade.
	_swap_hand_zone(func() -> void:
		if not _draft_active:
			return  # review V2b LOW-6 : fermé pendant la fenêtre du swap → pas de contenu fantôme
		for c in _hand_box.get_children():
			if c is MerlinCardView:
				c.queue_free()
		var n: int = cards.size()
		var cw: float = MerlinCardView.CARD_SIZE.x
		var gap: float = 30.0
		var w: float = _hand_box.size.x
		if w <= 0.0:
			w = float(get_viewport().get_visible_rect().size.x) - 56.0
		var x0: float = (w - (float(n) * cw + float(maxi(n - 1, 0)) * gap)) * 0.5
		for i in n:
			var cv: MerlinCardView = MerlinCardView.new()
			_hand_box.add_child(cv)
			cv.setup(cards[i])
			# v2-W2 — le nœud de talent porte un badge « ✦ +N TALENT » (distinct des greffes d'action).
			var gcard: Dictionary = _graft_by_id.get(str((cards[i] as MerlinCard).id), {})
			if str(gcard.get("kind", "")) == "talent":
				cv.set_talent_node(int(gcard.get("amount", 1)))
			elif str(gcard.get("kind", "")) == "roll":
				# v2-W3 — greffe « roll » : badge GOLD « +N au jet » (le bonus d20 est ÉVIDENT au draft).
				cv.set_roll_bonus(int(gcard.get("amount", MerlinCard.ROLL_BONUS_DEFAULT)))
			cv.card_clicked.connect(_on_draft_card)
			cv.set_fan_transform(Vector2(x0 + float(i) * (cw + gap), 6.0), 0.0)  # base du deal (snap 1er layout)
			cv.deal_in(float(i) * 0.12)
		# Vigilance V2a #6 : vues créées pendant une zone éteinte → état souris + alpha re-appliqués.
		MerlinVisual.set_zone_active(_hand_box, true))


# Referme la zone de draft : Z4 rendue, la main COURANTE revient ESTOMPÉE (elle sera de toute
# façon redrawée au beat suivant). Idempotent — un double close est un no-op.
func _close_draft_zone() -> void:
	if not _draft_active:
		return
	_draft_active = false
	# v11-W3 : hygiène du mode cible — pulses éteints, tuiles restaurées, sélection purgée.
	_set_draft_target_mode(false)
	_pending_graft = {}
	_graft_by_id = {}
	_draft_title_lbl = null
	if _draft_bar != null and is_instance_valid(_draft_bar):
		_draft_bar.queue_free()
	_draft_bar = null
	_fade_res_block(false)
	if not is_inside_tree() or _hand_box == null:
		return  # scène en cours de libération : rien à ranger visuellement
	_swap_hand_zone(func() -> void:
		for c in _hand_box.get_children():
			if c is MerlinCardView:
				c.queue_free()
		_render_hand(false)
		MerlinVisual.set_zone_active(_hand_box, false))  # vigilance #6 : main rendue zone éteinte


# v11-V2b — cross-fade du CONTENU de l'éventail (main ↔ 3 cartes de draft) : fade-out 0.18 s puis
# build ; la REMONTÉE d'alpha appartient à set_zone_active, appelé PAR le build avec l'état cible
# (swap_zone vise 1.0 en dur et se battrait avec l'estompe posée par _present_current_beat).
# Même clé meta que swap_zone (_fx_tw_swap) : un swap relancé tue le précédent.
func _swap_hand_zone(build: Callable) -> void:
	if _hand_box == null or not is_instance_valid(_hand_box) or not _hand_box.is_inside_tree():
		if build.is_valid():
			build.call()  # zone absente → au moins poser le contenu
		return
	if _hand_box.has_meta("_fx_tw_swap"):
		var prev: Tween = _hand_box.get_meta("_fx_tw_swap")
		if prev != null and prev.is_valid():
			prev.kill()
	if MerlinVisual.reduced_motion:
		build.call()  # swap sec — set_zone_active (dans le build) restitue l'alpha cible
		return
	var t: Tween = _hand_box.create_tween()
	t.tween_property(_hand_box, "modulate:a", 0.0, 0.18 * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	t.tween_callback(build)
	_hand_box.set_meta("_fx_tw_swap", t)


# v11-W3 — étape 1 du draft de greffe : clic greffe = sélection (carte levée + GOLD) → Z4 re-titrée
# « Touche l'action qui recevra la greffe » + tuiles éligibles en pulse ; re-clic = désélection.
func _on_draft_card(card: MerlinCard) -> void:
	if _draft_done_flag or Time.get_ticks_msec() - _draft_open_ms < 500:
		return  # audit ux_flow F2 : pas de pick AVEUGLE pendant le deal (contrôles encore à alpha 0)
	var g: Dictionary = _graft_by_id.get(str(card.id), {})
	if g.is_empty():
		return  # défense : carte étrangère au draft courant
	# v2-W2 — NŒUD DE TALENT : le verbe est DÉJÀ ciblé (le plus utilisé) → application en 1 GESTE (pas
	# d'étape « touche un verbe » : ce ne serait pas la cible du nœud). save après (progression réelle, R108).
	if str(g.get("kind", "")) == "talent":
		var run_t: Node = get_node("/root/MerlinRun")
		if not run_t.apply_talent_node(g):
			return  # points insuffisants / verbe au cap (course improbable) — le geste reste ouvert
		_graft_applied = true
		var tile_t: MerlinActionView = _tile_for_verb(str(g.get("verb", "")))
		if tile_t != null:
			tile_t.graft_pop()  # micro-retour SUR la tuile ciblée (le talent s'y grave)
		_select_draft_view(card)
		run_t.save()
		_refresh_action_tiles()  # le « +N » de la tuile ciblée se met à jour immédiatement (ÉVIDENT)
		_draft_done_flag = true
		return
	if not _pending_graft.is_empty() and str(_pending_graft.get("id", "")) == str(card.id):
		_pending_graft = {}  # re-clic = désélection → retour étape 1
		_select_draft_view(null)
		_set_draft_target_mode(false)
		_set_draft_title(_draft_title_base)
		return
	_pending_graft = g
	_select_draft_view(card)
	_set_draft_target_mode(true)
	_set_draft_title("Touche l'action qui recevra la greffe")


func _on_draft_skip() -> void:
	if _draft_done_flag or Time.get_ticks_msec() - _draft_open_ms < 500:
		return  # audit ux_flow F2 : idem — un double-clic d'avance ne doit pas skipper sans voir
	_draft_pick = null
	_draft_done_flag = true




# Clic sur la zone récit (scène/narration). Pendant la frappe → révèle tout le texte ;
# une fois l'issue entièrement écrite → passe au beat suivant. (Demande user 2026-05-26.)
func _on_story_click(event: InputEvent) -> void:
	if _intro_open or _draft_active or _interstitial_open or _tuto_blocks():
		return  # intro/draft/interstitiel/guide : clics gérés par _input ou par les contrôles des zones
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
	# v11-V2b — fin de frappe de l'INTRO : rien à piloter (« Accepter ✦ » attend en Z4).
	if _intro_open:
		_set_caret(false)
		return
	# v10.13 (B3) : ouverture de l'interstitiel entièrement écrite → clic = présenter le Beat 1.
	if _interstitial_open:
		_can_advance = true
		if _caret != null:
			_caret.text = "▮ cliquer pour continuer"
		_set_caret(true)
		return
	if _state == 2:
		# v10.21 (Wave G, R130) — PARTIEL différé : le choix Encaisser/Pousser REMPLACE l'avance au clic.
		# v11-V2b (vigilance V2a #1) : boutons+ledger D'ABORD — la vignette est re-frappée APRÈS le
		# choix au degré FINAL (_on_push_choice) ; les anneaux aussi (v11-W1 : ledger seul avant).
		if _push_pending:
			_pending_res = {}  # la vignette de ce beat vivra dans _on_push_choice (degré final)
			_build_push_choice()
			return
		# Issue entièrement écrite → la VIGNETTE d'effet (degré + Δ jauges + effets) apparaît en Z4
		# (R128 : compacte, après coup, sans casser la prose), puis avance au clic + caret « continuer ».
		if not _pending_res.is_empty():
			_build_effect_vignette(_pending_res, _pending_degree)
			_fade_res_block(true)
			_pending_res = {}
		_flush_gauges()  # v11-W1 : l'issue est lue → les anneaux jouent le delta cumulé (un seul endroit §23)
		_can_advance = true
		if _caret != null:
			_caret.text = "▮ cliquer pour continuer"
		_set_caret(true)
	elif _state == 1:
		# v10.21 (Wave I, R131) — INTERVENTION du pilier : si ce beat est planifié, la séquence prend la
		# main (ligne signée écrite à la suite → re-typewriter → ce handler re-passe, flag posé).
		if _maybe_intervention():
			return
		# Review V2b MEDIUM-5 — pacte pending (ligne signée entièrement écrite OU skippée) : les
		# boutons se posent ICI. Pas de return : le choix de beat s'ouvre en parallèle (sémantique
		# v10.21 — l'autoplay sert le pacte AVANT la branche state 1).
		if _pact_pending_pilier != "":
			var ppk: String = _pact_pending_pilier
			_pact_pending_pilier = ""
			if not get_node("/root/MerlinRun").ended:
				_build_pact_choice(ppk)
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
		_set_choice_ui(true)   # v11-V2a : zones permanentes — l'ouverture du choix est une estompe inverse
		_render_hand(true)
		_refresh_action_tiles()  # v11-W2 : feedforward + sélection propres à l'ouverture du choix
		_update_preview()        # paire incomplète → bouton Résoudre désarmé (alpha 0.35)
		_maybe_tuto_hint()       # v11-V2b : micro-tuto one-shot (beats 1-2, labels passifs Z4)


func _set_caret(on: bool) -> void:
	if _caret == null:
		return
	if _caret_tw != null and _caret_tw.is_valid():
		_caret_tw.kill()
	_caret_tw = null
	if on:
		_caret.modulate.a = 0.65
		_caret_tw = _caret.create_tween().set_loops()
		_caret_tw.tween_property(_caret, "modulate:a", 0.18, MerlinVisual.DUR_CARET_BLINK * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
		_caret_tw.tween_property(_caret, "modulate:a", 0.65, MerlinVisual.DUR_CARET_BLINK * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	elif _caret.is_inside_tree():
		# v11-V2a : extinction par ALPHA (le node ne disparaît jamais — la zone reste stable)
		_caret_tw = _caret.create_tween()
		_caret_tw.tween_property(_caret, "modulate:a", 0.0, MerlinVisual.DUR_FAST * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	else:
		_caret.modulate.a = 0.0


# v11-V2a (Z6) — armement du bouton Résoudre PERMANENT : jamais de visible=false. Désarmé =
# self_modulate 0.35 + disabled ; armé = pleine alpha (le pulse d'armement vit dans _update_preview).
# self_modulate et PAS modulate : le hover-tint de connect_button_feedback tweene modulate.
func _set_resolve_armed(armed: bool) -> void:
	if _resolve_btn == null:
		return
	_resolve_btn.disabled = not armed
	var target: float = 1.0 if armed else 0.35
	if _resolve_tw != null and _resolve_tw.is_valid():
		_resolve_tw.kill()
	if _resolve_btn.is_inside_tree():
		_resolve_tw = _resolve_btn.create_tween()
		_resolve_tw.tween_property(_resolve_btn, "self_modulate:a", target,
			MerlinVisual.DUR_ZONE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	else:
		_resolve_btn.self_modulate.a = target


# N4-RUNES : _set_req_visible SUPPRIMÉE avec la rangée de chips des tags requis (zéro jargon).


# v11-V2a (Z4) — le slot central de la ligne d'état (vignette / choix différés) vit par alpha.
# Tween lié au bloc + kill via meta (pattern MerlinVisual) — jamais deux fades concurrents.
func _fade_res_block(on: bool) -> void:
	if _res_block == null:
		return
	var target: float = 1.0 if on else 0.0
	if _res_block.has_meta("_tw_fade"):
		var prev: Tween = _res_block.get_meta("_tw_fade")
		if prev != null and prev.is_valid():
			prev.kill()
	# Review V2b HIGH-1 — UN SEUL propriétaire d'alpha : un swap_zone encore en vol (double-clic
	# Encaisser puis avance <0,18 s) survivrait au fade et RESSUSCITERAIT la vignette du beat
	# précédent à pleine alpha. On le tue ici.
	if _res_block.has_meta("_fx_tw_swap"):
		var prev_swap: Tween = _res_block.get_meta("_fx_tw_swap")
		if prev_swap != null and prev_swap.is_valid():
			prev_swap.kill()
		_res_block.remove_meta("_fx_tw_swap")
	if _res_block.is_inside_tree():
		var t: Tween = _res_block.create_tween()
		t.tween_property(_res_block, "modulate:a", target,
			MerlinVisual.DUR_ZONE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
		_res_block.set_meta("_tw_fade", t)
	else:
		_res_block.modulate.a = target


# v11-V2a — estompe de LECTURE de la main (grammaire de zone : dim = zone inactive). La rangée
# d'actions n'est volontairement PAS couplée ici : pendant la fusion elle reste pleine alpha (la
# tuile jouée pulse) — son estompe passe par _set_choice_ui(false) APRÈS fx.run().
func _set_hand_dimmed(on: bool) -> void:
	MerlinVisual.set_zone_active(_hand_box, not on)


# v11-V2a (spec écran stable) — le CHOIX s'ouvre/se ferme par ESTOMPE de zone (alpha 0.35 + souris
# off via mouse_filter), JAMAIS par visible : les zones existent 100 % du temps. _choice_open est
# LA garde anti-clic (_on_action_tile/_on_trait_card) — reprend le rôle de _hand_box.visible.
func _set_choice_ui(on: bool) -> void:
	_choice_open = on
	MerlinVisual.set_zone_active(_hand_box, on)
	MerlinVisual.set_zone_active(_action_bar, on)
	# N4-RUNES : plus de rangée de tags requis à révéler (chips supprimées, preview R120).
	if on and _scene_art != null:
		_scene_art.set_reading_recess(false)  # v10.21 (L-a) : la main s'éveille → la forêt revit


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
	_caret.modulate.a = 0.5  # v11-V2a : présence par alpha (jamais visible=false)


# === v11-V2b (spec §tuto) — micro-tuto : 2 hints one-shot, labels PASSIFS dans Z4 ===
# MOUSE_FILTER_IGNORE : jamais bloquants (l'autoplay n'a rien à servir, le harnais reste vert).
const TUTO_HINT_A: String = "Choisis un verbe (tuile) et une manière (carte), puis Résous."
# N4-RUNES (revue design, finding 4) : le hint couvre les DEUX moitiés du geste (tuiles ET cartes).
const TUTO_HINT_B: String = "La forêt réclame : tuiles et cartes nimbées d'or y répondent."  # N4-P1 : cadre lumineux (ex-souligné)


# À l'ouverture du choix : hint A au beat 1, hint B au beat 2 — une seule fois par profil
# (persistance [tuto] via MerlinVisual, pattern reduced_motion).
func _maybe_tuto_hint() -> void:
	if _tuto != null and is_instance_valid(_tuto):
		return  # N4-TUTO : le guide couvre tout ce que les hints enseignent : zéro bruit par-dessus
	var run: Node = get_node("/root/MerlinRun")
	if int(run.beat_index) == 0 and not MerlinVisual.tuto_hint_a_done:
		_tuto_a_active = true
		_show_tuto_hint(TUTO_HINT_A)
	elif int(run.beat_index) == 1 and not MerlinVisual.tuto_hint_b_done:
		_tuto_b_active = true
		_show_tuto_hint(TUTO_HINT_B)


func _show_tuto_hint(txt: String) -> void:
	if _tuto_lbl == null or not is_instance_valid(_tuto_lbl):
		_tuto_lbl = MerlinVisual.make_label(MerlinVisual.DIM_WARM, MerlinVisual.FS_HINT)
		_tuto_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tuto_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tuto_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_status_line.add_child(_tuto_lbl)
	_tuto_lbl.text = txt
	# N4-BUG #3 : PRESET_CENTER posé sur un label VIDE (size 0 à la création) laissait le texte
	# grandir depuis l'ORIGINE de _status_line → moitié gauche du hint hors écran (100 % repro).
	# Fix : anchors + offsets PLEINE ZONE re-posés APRÈS la pose du texte, à CHAQUE affichage
	# (setter la taille/le texte réécrit les offsets en Godot 4 : un simple set_anchors_preset à
	# la création laissait le label collé à gauche, vérifié par capture). Le label épouse Z4 et
	# les alignements centre centrent le texte quelle que soit sa longueur (hints A ET B).
	_tuto_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tuto_lbl.modulate.a = 0.0
	if _tuto_lbl.is_inside_tree():
		var t: Tween = _tuto_lbl.create_tween()
		t.tween_property(_tuto_lbl, "modulate:a", 0.9,
			MerlinVisual.DUR_ZONE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	else:
		_tuto_lbl.modulate.a = 0.9


# Efface le hint SANS le consommer (les désarmes one-shot posent les flags + save_prefs ailleurs).
func _clear_tuto_hint() -> void:
	_tuto_a_active = false
	_tuto_b_active = false
	if _tuto_lbl == null or not is_instance_valid(_tuto_lbl):
		_tuto_lbl = null
		return
	var lbl: Label = _tuto_lbl
	_tuto_lbl = null
	if not lbl.is_inside_tree():
		lbl.queue_free()
		return
	var t: Tween = lbl.create_tween()
	t.tween_property(lbl, "modulate:a", 0.0,
		MerlinVisual.DUR_ZONE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
	t.tween_callback(lbl.queue_free)


func _degree_color(degree: String) -> Color:
	return MerlinVisual.degree_color(degree)


func _on_gauges(integrite: int, corruption: int) -> void:
	if _gauges_deferred:
		return  # v11-W1 : _prev_* intouchés → le flush rejouera le delta CUMULÉ de la résolution
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
	# v10.21 (L-b) — PRÉ-ALERTE de seuil : à 1 du prochain seuil /5, pulse UNIQUE à l'entrée en zone
	# + pastille statique persistante (info, pas boucle). Libellé « l'Emprise guette » à cap−2.
	var near_thr: bool = (corruption % 5) == 4 and corruption < MerlinRun.CORRUPTION_CAP
	if near_thr and not _near_thr_shown and not MerlinVisual.reduced_motion:
		_pop(_corr_gauge, 1.12)
	_near_thr_shown = near_thr
	if _thr_dot != null:
		_thr_dot.visible = near_thr
	if _emprise_lbl != null:
		_emprise_lbl.visible = corruption >= MerlinRun.CORRUPTION_CAP - 2
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


# v11-W1 — rejoue le commit visuel des anneaux avec les valeurs FINALES (delta cumulé coût+effets+
# résolution). Appelé après le typewriter (issue lue) ou après le choix Encaisser/Pousser (R130).
func _flush_gauges() -> void:
	if not _gauges_deferred:
		return
	_gauges_deferred = false
	var run: Node = get_node("/root/MerlinRun")
	_on_gauges(int(run.get("integrite")), int(run.get("corruption")))


# v11-W2 — la paire ACTION + TRAIT est complète : onde + sparks centrées sur le bouton Résoudre
# (il s'arme + pulse — spec §A, le regard est guidé vers la confirmation).
func _selection_complete_pulse() -> void:
	if MerlinVisual.reduced_motion:
		return
	var center: Vector2 = _resolve_btn.global_position + _resolve_btn.size * 0.5
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
		# v11-V2b — intro DANS les zones (plus de modal) : clic 1 = tout révéler (skip typewriter) ;
		# clic 2 = « Accepter ✦ » (Z4) via la GUI — jamais consommé ici quand la frappe est finie.
		if _intro_open:
			if _tw != null and _tw.is_valid():
				_skip_typewriter()
				get_viewport().set_input_as_handled()
			return
		if _draft_active:
			return  # le draft vit dans les zones : cartes + « Passer » gèrent leurs propres clics
		# v10.13 (B3) — interstitiel « Merlin raconte » : clic = skip (attente inline OU typewriter),
		# puis avance Beat 1. L'attente LLM vit DANS l'encart (v11-V2b) — le clic arme le fallback.
		if _interstitial_open:
			if _tw != null and _tw.is_valid():
				_skip_typewriter()
			elif _can_advance:
				_end_interstitial()
			else:
				_interstitial_skip = true  # attente inline → cesser d'attendre la prose LLM
			get_viewport().set_input_as_handled()
			return
		# N4-TUTO : le guide confisque l'avance de beat (ses propres clics vivent dans son
		# catcher) mais laisse vivre le skip du typewriter (lecture réactive pendant la démo).
		if _tuto_blocks():
			if _tw != null and _tw.is_valid():
				_skip_typewriter()
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
	if run == null or (run.hand as Array).is_empty() or (run.actions as Array).is_empty():
		return
	# v11-W2 : geste canonique [action, trait] — l'action en [0] (contrat resolve R20).
	var fake_played: Array = [run.actions[0], run.hand[0]]
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
	# v10.13 (A2)/v11-W2 : une vue de TRAIT jetable (l'action est une tuile permanente — elle n'est
	# jamais aspirée) puis MerlinFx.play — la vue est reparentée dans le layer (parité résolution réelle).
	var vues: Array = []
	var cv: MerlinCardView = MerlinCardView.new()
	add_child(cv)
	cv.setup(run.hand[0])
	cv.position = Vector2(size.x * 0.5 - MerlinCardView.CARD_SIZE.x * 0.5,
		size.y - MerlinCardView.CARD_SIZE.y - 140.0)
	vues.append(cv)
	await get_tree().process_frame  # laisse Godot poser la card view dans le layout
	# Prédicat `ready` injecté : même source que la résolution réelle (is_resolution_ready). Pas de
	# scénario (probe hors-jeu) → prêt d'office = pas de sustain (parité avec l'ancien `sc == null`).
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	var ready_pred: Callable
	if sc != null:
		# N4-BUG #2b (parité F12) : même court-circuit que la résolution réelle : rien en route
		# pour la combo factice (jamais préfetchée) → pas d'attente vaine du cap, la fusion de
		# debug se termine d'elle-même (elle teste l'animation, pas l'attente LLM).
		ready_pred = func() -> bool:
			return sc.is_resolution_ready(fake_played, fake_res) \
				or not sc.is_resolution_incoming(fake_played, fake_res)
	else:
		ready_pred = func() -> bool: return true
	var fx: MerlinFx = MerlinFx.play(self, fake_res, fake_played, vues, ready_pred)
	await fx.run()


func _on_run_ended(_end_type: String) -> void:
	MerlinAudio.stop_pad()  # v10.21 Wave A : la nappe du pilier ne survit pas à la run (autoload)
	# v10.13 (Fix 1) / v11-V2b : si la run se termine pendant le draft, la boucle du driver
	# (_present_draft/_present_pilier_offering) sort via run.ended et _close_draft_zone range la zone.
	if _draft_active:
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
	if _scene_art != null:
		_scene_art.set_reading_recess(true)  # v10.21 (L-a) : la forêt s'efface pendant que la prose s'écrit
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


# --- Intro de quête (R56) — v11-V2b : DANS les zones (spec écran stable, matrice ligne 1). ---
# Plus de layer plein écran ni de DIM_MODAL : titre 40 px + pitch (typewriter) + ligne objectif
# vivent dans l'encart Z3 (swap_zone) ; « Accepter ✦ » (pulse conservé) dans le slot central de
# Z4 ; Z5/Z6 restent visibles ESTOMPÉES (teaser passif — la main du beat 1 est déjà piochée par
# new_run). Clic 1 = tout révéler (via _input), clic 2 = Accepter (pilier FACILE, ≤2 gestes).
func _show_intro_popup() -> void:
	var run: Node = get_node("/root/MerlinRun")
	var data: Dictionary = get_node("/root/MerlinScenario").build_intro(run.scenario)
	_intro_open = true
	_intro_data = {
		"title": str(run.scenario.get("title", "La Quête")),
		"intro": str(data.get("intro", "")),
		"objectif": str(data.get("objectif", "")),
	}
	# Teaser Z5 : la main du beat 1, rendue puis re-éteinte (vigilance V2a #6 : vues créées pendant
	# une zone estompée → état souris re-appliqué ; _set_choice_ui(false) est déjà passé dans _begin).
	_render_hand(false)
	MerlinVisual.set_zone_active(_hand_box, false)
	# Z3 : le fil porte l'intro (titre révélé d'emblée, pitch au typewriter via from_chars R128).
	MerlinVisual.swap_zone(_situ_panel, func() -> void:
		_typewriter(_intro_bbcode(str(_intro_data["intro"])), true, _situation_text,
			str(_intro_data["title"]).length() + 2)
		_show_skip_hint()
		if _caret != null:
			_caret.text = "▶ clic pour tout lire")
	_build_intro_accept()
	# v10.13 (B3) : ouverture pré-générée en cache (priorité moteur BASSE — ne se lance que si le
	# moteur est idle) AVANT l'enrichissement de greeting. Consommée par l'interstitiel à l'Accept.
	get_node("/root/MerlinScenario").prefetch_opening(run.scenario)
	_bg_intro(run.scenario)


# Compose le BBCode de l'intro — un seul fil dans _situation_text, recomposable quand le LLM
# enrichit le pitch (_bg_intro). Titre en GOLD_DARK : l'or LISIBLE sur crème (GOLD pur ≈1.5:1,
# sous le seuil 3:1 du §23 — même choix que degree_color réussite).
func _intro_bbcode(intro_text: String) -> String:
	var gold: String = MerlinVisual.GOLD_DARK.to_html(false)
	return "[center][font_size=%d][color=#%s]%s[/color][/font_size]\n\n%s\n\n[color=#%s]✦ Objectif : %s[/color][/center]" % [
		MerlinVisual.FS_TITLE_POPUP, gold, str(_intro_data.get("title", "")),
		intro_text, gold, str(_intro_data.get("objectif", ""))]


# Bouton « Accepter ✦ » dans le slot central de Z4 (56 px de haut : tient dans la ligne d'état 72 px).
func _build_intro_accept() -> void:
	var accept: Button = Button.new()
	accept.text = "Accepter ✦"
	accept.custom_minimum_size = Vector2(260, 56)  # ≥44 px (pilier TACTILE+DESKTOP)
	accept.add_theme_font_size_override("font_size", 28)
	accept.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	MerlinVisual.apply_button_da(accept)
	MerlinVisual.connect_button_feedback(accept)  # feedback canon §21 `tap`
	accept.pressed.connect(_accept_quest)
	_intro_accept_btn = accept
	if _res_block != null:
		_res_block.add_child(accept)
		_fade_res_block(true)
	accept.resized.connect(func() -> void: accept.pivot_offset = accept.size / 2.0)
	_pulse(accept)


func _pulse(node: Control) -> void:
	_pulse_tw = node.create_tween().set_loops()
	_pulse_tw.tween_property(node, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.7).set_trans(Tween.TRANS_SINE)


# Enrichit le PITCH d'intro en arrière-plan ; jamais bloquant. v11-V2b : recompose le BBCode complet
# (titre + pitch enrichi + objectif) dans _situation_text — seulement si l'intro est encore ouverte
# ET la frappe finie (ÉVIDENT : ne jamais muter un texte en cours de lecture).
func _bg_intro(scenario: Dictionary) -> void:
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc == null:
		return
	# Greeting MERLIN enrichie (LLM, non bloquant).
	var prose: String = await sc.narrate_intro(scenario)
	if not _intro_open or _situation_text == null or not is_inside_tree():
		return
	var lbl: RichTextLabel = _situation_text
	if prose.length() >= 10 and not (lbl.visible_characters >= 0 and lbl.visible_characters < lbl.get_total_character_count()):
		lbl.text = _intro_bbcode(prose)
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
	_kill_tw()  # frappe d'intro encore en cours → coupée net (l'interstitiel reprend l'encart)
	_set_caret(false)
	# v11-V2b — cross-fade Z4 vers l'état suivant : le bouton part en fondu (souris off immédiate,
	# zéro clic fantôme), le slot central s'éteint ; l'interstitiel posera le hint skip (caret).
	if _intro_accept_btn != null and is_instance_valid(_intro_accept_btn):
		var btn: Button = _intro_accept_btn
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if btn.is_inside_tree():
			var t: Tween = btn.create_tween()
			t.tween_property(btn, "modulate:a", 0.0,
				MerlinVisual.DUR_ZONE_FADE * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE)
			t.tween_callback(btn.queue_free)
		else:
			btn.queue_free()
	_intro_accept_btn = null
	_fade_res_block(false)
	get_node("/root/MerlinRun").save()  # v10.13 (Fix 6) : quitter pendant le beat 1 → reprise au beat 1
	# v10.13 (B3) : l'intro cède la place à l'interstitiel « Merlin raconte » (ouverture narrative),
	# qui présentera lui-même le Beat 1 au clic suivant. La save reste AVANT (Fix 6c).
	_play_opening_interstitial()


# === v10.13 (B3) — Interstitiel « Merlin raconte » : entre l'Accept et le Beat 1 ===
# Sert l'ouverture narrative (LLM si le cache prefetch_opening est prêt, sinon attente inline
# bornée 8s puis procédural) ET couvre la gen d'arc en arrière-plan (retarde arc_locked → plus
# d'arcs LLM gagnent la course). Clic pendant le typewriter = tout révéler ; clic ensuite =
# _present_current_beat() (≤2 gestes, pilier FACILE). Piloté par _input via _interstitial_open.
# v11-V2b : plus de MerlinWaitStage plein écran — l'attente vit DANS l'encart (caption + points
# cyclants), le hint skip dans Z4 (caret). Les zones ne bougent jamais.
const INTERSTITIAL_CAPTION: String = "Merlin rassemble les fils de l'histoire"
const INTERSTITIAL_CAP_MS: int = 8000   # au-delà, l'ouverture procédurale sert (le LLM rattrapera)
const INTERSTITIAL_DOT_MS: int = 450    # cadence des points cyclants (parité sustain fusion)


func _play_opening_interstitial() -> void:
	_scene_epoch += 1  # toute gen/anim liée à l'intro devient périmée
	var ep: int = _scene_epoch
	_interstitial_open = true
	_interstitial_skip = false
	_can_advance = false
	_set_caret(false)
	_set_choice_ui(false)
	var run: Node = get_node("/root/MerlinRun")
	var sc: Node = get_node("/root/MerlinScenario")
	# Review HIGH (B3) : si le prefetch lancé à l'ouverture de l'intro a été SAUTÉ (moteur occupé
	# par la gen d'arc — cas courant au cold start), on RETENTE ici : l'arc a eu toute la lecture
	# de l'intro pour finir, et l'attente inline (8s) couvre alors une VRAIE gen, pas du vide.
	# Jamais si déjà prête ou en vol (prefetch_opening fait une RAZ inconditionnelle).
	if not sc.is_opening_ready() and not sc.is_opening_pending():
		sc.prefetch_opening(run.scenario)
	_set_encart_phase(MerlinVisual.INK_DIM)  # bordure neutre (même teinte que les situations)
	if _situ_tw != null and _situ_tw.is_valid():
		_situ_tw.kill()  # fondu legacy en vol → les swaps de zone prennent la main sur l'alpha
	var opening: String = ""
	if bool(sc.is_opening_ready()):
		opening = str(sc.take_opening())
	else:
		# v11-V2b — attente DANS l'encart : caption + points cyclants, skip au clic (cap 8s).
		var issue: String = await _interstitial_inline_wait(ep, func() -> bool: return bool(sc.is_opening_ready()))
		if not _fresh(ep) or not _interstitial_open:
			return  # scène quittée / interstitiel clos par l'outillage pendant l'attente
		if issue == "ready":
			opening = str(sc.take_opening())
	if opening.strip_edges() == "":
		opening = str(sc.build_opening(run.scenario))  # procédural verbeux (cadre + accroche du pitch)
	# Review V2b HIGH-2 — TOUJOURS via swap_zone (même méta _fx_tw_swap → tue le swap de caption
	# encore en vol) : en « frappe directe », un skip pendant la fenêtre 0,18 s laissait le callback
	# du swap réécrire la caption PAR-DESSUS l'ouverture frappée — information détruite.
	MerlinVisual.swap_zone(_situ_panel, func() -> void:
		_typewriter("[center]" + opening + "[/center]", true))
	# La suite (skip typewriter / avance au Beat 1) est pilotée par _input (_interstitial_open).


# v11-V2b — attente LLM de l'interstitiel DANS l'encart (plus de WaitStage plein écran) : caption
# GOLD_DARK + points cyclants écrits dans _situation_text (Z3), hint skip porté par le caret (Z4).
# Sort sur "ready" (prédicat) / "skipped" (clic → _interstitial_skip) / "timeout" (cap 8 s).
# Ne construit AUCUN node — les zones ne bougent jamais.
func _interstitial_inline_wait(ep: int, pred: Callable) -> String:
	_interstitial_skip = false
	var cap_col: String = MerlinVisual.GOLD_DARK.to_html(false)
	MerlinVisual.swap_zone(_situ_panel, func() -> void:
		if _situation_text != null:
			_situation_text.text = "[center][color=#%s]%s[/color][/center]" % [cap_col, INTERSTITIAL_CAPTION])
	_show_skip_hint()  # affordance immédiate (« ▶ clic pour passer », Z4)
	var t0: int = Time.get_ticks_msec()
	var next_dot_ms: int = 0
	var dots: int = 0
	var issue: String = "timeout"
	while _fresh(ep) and _interstitial_open:
		if _interstitial_skip:
			issue = "skipped"
			break
		if pred.is_valid() and bool(pred.call()):
			issue = "ready"
			break
		var now: int = Time.get_ticks_msec()
		if now - t0 >= INTERSTITIAL_CAP_MS:
			break
		if now >= next_dot_ms and _situation_text != null:
			next_dot_ms = now + INTERSTITIAL_DOT_MS
			dots = (dots + 1) % 4
			_situation_text.text = "[center][color=#%s]%s %s[/color][/center]" % [
				cap_col, INTERSTITIAL_CAPTION, ".".repeat(dots)]
		await get_tree().process_frame
	return issue


# Sortie de l'interstitiel (clic « continuer » ou autoplay) → présentation du Beat 1.
# v1.0-V4a : coroutine (draft d'ouverture) — les appelants restent fire-and-forget.
func _end_interstitial() -> void:
	if not _interstitial_open:
		return
	_interstitial_open = false
	_can_advance = false
	_set_caret(false)
	# N4-TUTO : proposition du guide au tout premier run (chronique vierge ou ré-armé via les
	# Options). La suite du flow (draft d'ouverture + beat 1) attend la réponse (_on_tuto_answer).
	if MerlinChronicle.should_offer_tuto():
		_build_tuto_prompt()
		return
	await _continue_after_interstitial()


# N4-TUTO : suite du flow post-interstitiel (draft d'ouverture + beat 1), extraite de
# _end_interstitial pour être rejouée après la réponse à la proposition du guide. Guide ACCEPTÉ :
# le draft d'ouverture est DÉCALÉ (revue design B3) et se fondra dans le gate unique de
# _advance_to_next (flag intact, GD-27 conservé : déplacé, jamais perdu).
func _continue_after_interstitial() -> void:
	# v1.0-V4a (BAL-11-B/GD-27) — draft d'OUVERTURE : une greffe s'offre AVANT le 1er beat (le
	# build démarre avec une direction). UNE fois par run : flag persisté opening_draft_done posé à
	# l'OUVERTURE (review MEDIUM — un « Passer » n'est jamais re-proposé au resume, anti re-roll ;
	# même contrat que pilier_offering_done).
	var run: Node = get_node("/root/MerlinRun")
	# N4-TUTO : guide actif : le draft d'ouverture ne s'ouvre PAS ici (décalé, revue design B3) :
	# opening_draft_done reste false et le gate unique de _advance_to_next le servira au beat 1.
	if _tuto == null and run.beat_index == 0 and not run.ended and not run.opening_draft_done \
			and run.has_graftable_action():
		run.opening_draft_done = true
		_scene_epoch += 1
		await _present_draft()
		if not is_inside_tree():
			return
		run.save()  # greffe d'ouverture + flag survivent à un quit pendant le beat 1 (R108)
	_present_current_beat()


# === N4-TUTO : proposition + cycle de vie du guide de Merlin (merlin_tutorial.gd) ===


# Le guide verrouille-t-il l'input de jeu ? (duck-typé : merlin_tutorial.blocking)
func _tuto_blocks() -> bool:
	return _tuto != null and is_instance_valid(_tuto) and bool(_tuto.get("blocking"))


# Rangée de proposition (Z4, pattern « Accepter ✦ ») : question de Merlin + 2 boutons ≥44 px sur
# UNE rangée (72 px : jamais d'empilement). Non-modale (R136 : les zones restent posées).
func _build_tuto_prompt() -> void:
	_clear_tuto_hint()
	if _effect_vignette != null:
		for c in _effect_vignette.get_children():
			c.queue_free()  # le slot central de Z4 ne porte qu'UN contenu à la fois
	_tuto_prompt_row = HBoxContainer.new()
	_tuto_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tuto_prompt_row.add_theme_constant_override("separation", 20)
	var q: Label = MerlinVisual.make_label(MerlinVisual.CREAM, MerlinVisual.FS_CAPTION)
	q.text = "Premier pas dans la forêt, Voyageur... je te guide ?"  # revue design M2 : court
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tuto_prompt_row.add_child(q)
	var yes: Button = Button.new()
	yes.text = "Guide-moi"
	var no: Button = Button.new()
	no.text = "Je connais le chemin"
	for b in [yes, no]:
		var btn: Button = b
		btn.custom_minimum_size = Vector2(230, 52)  # ≥44 px (pilier TACTILE)
		btn.add_theme_font_size_override("font_size", 18)
		MerlinVisual.apply_button_da(btn)
		MerlinVisual.connect_button_feedback(btn)
		_tuto_prompt_row.add_child(btn)
	yes.pressed.connect(_on_tuto_answer.bind(true))
	no.pressed.connect(_on_tuto_answer.bind(false))
	if _res_block != null:
		_res_block.add_child(_tuto_prompt_row)
		_fade_res_block(true)


# Réponse à la proposition : persistée en SYNCHRONE (revue design B2 : un quit/crash juste après
# le clic ne re-propose JAMAIS), puis le flow post-interstitiel reprend (guide actif ou non).
func _on_tuto_answer(accepted: bool) -> void:
	if _tuto_prompt_row == null:
		return  # double-clic pendant le fondu : réponse déjà consommée
	var row: HBoxContainer = _tuto_prompt_row
	_tuto_prompt_row = null
	MerlinChronicle.mark_tuto_proposed()
	if row != null and is_instance_valid(row):
		row.queue_free()
	_fade_res_block(false)
	if accepted:
		_tuto = TUTO_SCRIPT.new()
		add_child(_tuto)
		_tuto.finished.connect(_on_tuto_finished)
		_tuto.start(self, {
			"encart": _situ_panel, "etat": _status_line, "main": _hand_box,
			"resoudre": _resolve_btn, "vie": _life_gauge, "corruption": _corr_gauge,
		})
	_continue_after_interstitial()  # fire-and-forget (coroutine) : même contrat que _end_interstitial


func _on_tuto_finished(_completed: bool) -> void:
	_tuto = null  # le node se libère lui-même (teardown en fin de _run côté tutorial)


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

	# v11-V2a (grille fixe 1920×1080, spec écran stable) : marges 16 verticales / 28 horizontales,
	# séparations 8 — le total des 6 zones fixes tient sous 1080 sans SIZE_EXPAND_FILL vertical.
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var hud: HBoxContainer = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 16)
	root.add_child(hud)
	_life_gauge = MerlinRingGauge.new()
	hud.add_child(_life_gauge)
	# N4-P1 (chantier 6) : glyphe grave au centre (souffle/coeur = Integrite) : l'anneau se nomme sans texte.
	_life_gauge.setup(COL_GREEN, true, "coeur")
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
	# N4-P1 (chantier 6) : spirale voilee = Corruption ; le lisere de presence a 0 (dans la classe)
	# dit qu'une 2e jauge existe avant meme le premier point de corruption.
	_corr_gauge.setup(COL_VIOLET, true, "spirale")
	# v10.21 (L-b) — PRÉ-ALERTE de seuil : pastille statique 6px collée à l'anneau (visible à 1 du
	# prochain seuil /5, silencieuse, persiste — porte l'info même en reduce-motion).
	_thr_dot = ColorRect.new()
	_thr_dot.color = MerlinVisual.VIOLET
	_thr_dot.size = Vector2(6, 6)
	_thr_dot.position = Vector2(-10, 4)
	_thr_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thr_dot.visible = false
	_corr_gauge.add_child(_thr_dot)
	# Alerte forte (cap−2) : libellé court sous l'anneau — « l'Emprise guette » (FS 16, DIM_WARM sur sombre).
	_emprise_lbl = Label.new()
	_emprise_lbl.text = "l'Emprise guette"
	_emprise_lbl.add_theme_color_override("font_color", MerlinVisual.DIM_WARM)
	_emprise_lbl.add_theme_font_size_override("font_size", 16)
	_emprise_lbl.position = Vector2(-34, 52)
	_emprise_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emprise_lbl.visible = false
	_corr_gauge.add_child(_emprise_lbl)

	# Scène en silhouettes plates — Z2 DÉCOR 200 px FIXE (dessine relatif à `size`).
	_scene_art = MerlinSceneArt.new()
	_scene_art.custom_minimum_size = Vector2(0, 200)
	root.add_child(_scene_art)
	_scene_art.set_animated(true)  # v10.13 (B7) : couche ambiante GAME (halo lune + brume vivantes)
	_scene_art.set_watch_eyes(true)  # v10.20 : les yeux de Merlin vivent dans la LUNE et suivent le curseur
	_scene_art.set_biome(str(get_node("/root/MerlinRun").biome))  # v10.22 : le monde choisi au menu
	# v10.22 (user) — le paysage se CONSTRUIT à l'entrée de scène (rampe reveal → étages du décor).
	if not MerlinVisual.reduced_motion:
		_scene_art.set_decor_reveal(0.0)
		var rvl: Tween = create_tween()
		rvl.tween_method(_scene_art.set_decor_reveal, 0.0, 1.0, 1.4 * MerlinVisual.motion()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Z3 ENCART crème 348 px FIXE (v11-V2a : plus AUCUN SIZE_EXPAND_FILL vertical — la grille ne
	# reflow jamais). Porte chaque situation/issue ; bordure teintée par phase (_set_encart_phase).
	_situ_panel = PanelContainer.new()
	_situ_panel.custom_minimum_size = Vector2(0, 348)
	_situ_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # clics → capteur récit (skip/avance)
	_situ_sb = _cream_style()
	_situ_panel.add_theme_stylebox_override("panel", _situ_sb)
	root.add_child(_situ_panel)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_situ_panel.add_child(inner)
	# N4-RUNES (2026-07-11) : la rangée de chips des tags requis est SUPPRIMÉE de la tête d'encart
	# (zéro jargon à l'écran). Le fil narratif récupère les 26 px ; l'affinité vit au souligné
	# feedforward des tuiles + à la preview de résolution (R120).
	# v11-V2a : fil type VN — toute longueur tient dans la hauteur fixe par SCROLL (suivi pendant la
	# frappe) ; textes courts alignés en haut (le CenterContainer vertical est supprimé : zéro reflow).
	_situation_text = RichTextLabel.new()
	_situation_text.bbcode_enabled = true
	_situation_text.fit_content = false
	_situation_text.scroll_active = true
	_situation_text.scroll_following = true
	_situation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_situation_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_situation_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_situation_text.add_theme_color_override("default_color", COL_INK)
	_situation_text.add_theme_font_size_override("normal_font_size", MerlinVisual.FS_NARRATIVE)
	# N4-P1 (chantier 3, MAJEUR) : l'italique d'ACTION (R140 : 1re phrase [i]…[/i]) se rendait à la
	# taille de thème (~16 px) face au récit 36 px. Overrides italics/bold_italics = FS_NARRATIVE.
	# (Pas de fonte italique dédiée au thème : le fallback rend l'italique en romain, la TAILLE prime.)
	_situation_text.add_theme_font_size_override("italics_font_size", MerlinVisual.FS_NARRATIVE)
	_situation_text.add_theme_font_size_override("bold_italics_font_size", MerlinVisual.FS_NARRATIVE)
	inner.add_child(_situation_text)

	# v11-V2a (Z4) — LIGNE D'ÉTAT 72 px FIXE entre l'encart et l'éventail : slot central (vignette
	# d'effet R128 / choix Encaisser-Pousser / pacte — encore portés par _res_block en V2a, re-ciblage
	# propre en V2b) + caret « continuer » aligné à droite. La zone existe 100 % du temps.
	_status_line = Control.new()
	_status_line.custom_minimum_size = Vector2(0, 72)
	_status_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status_line)
	_res_block = VBoxContainer.new()
	_res_block.set_anchors_preset(Control.PRESET_FULL_RECT)
	_res_block.alignment = BoxContainer.ALIGNMENT_CENTER
	_res_block.add_theme_constant_override("separation", 10)
	_res_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_block.modulate.a = 0.0  # révélé par alpha (_fade_res_block), JAMAIS par visible=false
	_status_line.add_child(_res_block)
	_effect_vignette = HBoxContainer.new()
	_effect_vignette.alignment = BoxContainer.ALIGNMENT_CENTER
	_effect_vignette.add_theme_constant_override("separation", 16)
	_effect_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_block.add_child(_effect_vignette)

	# Caret « cliquer pour continuer » : clignote quand l'issue est écrite — alpha-fade, jamais caché.
	_caret = _mk_label(MerlinVisual.GOLD_DARK, 20)
	_caret.text = "▮ cliquer pour continuer"
	_caret.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.modulate.a = 0.0
	_status_line.add_child(_caret)
	_caret.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_caret.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# v11-W2 (spec §I) — ÉVENTAIL de 4 TRAITS (150×190 CREAM) au-dessus de la rangée d'actions.
	# v10.5 : label « Ta main : » retiré (user 2026-06-06). L'éventail se suffit visuellement.
	_hand_box = Control.new()
	_hand_box.custom_minimum_size = Vector2(0, 208)  # Z5 : 208 px FIXE — zone PERMANENTE, estompée
	# hors phase de choix (set_zone_active) ; le lift des cartes déborde sur Z4 (cosmétique assumé).
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_box.clip_contents = false  # le survol soulève/agrandit la carte hors cadre
	_hand_box.resized.connect(_layout_fan)
	root.add_child(_hand_box)

	# v11-W2 (spec §I) — RANGÉE D'ACTIONS permanente : 4 tuiles 260×116 (SURFACE, grammaire distincte
	# des traits CREAM) + bouton Résoudre + indice de dé, centrés. Le combo panel (104 px) est SUPPRIMÉ.
	# Les tuiles sont insérées par _build_action_tiles (run.actions n'existe qu'après new_run/load_run).
	_action_bar = HBoxContainer.new()
	_action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_bar.add_theme_constant_override("separation", 16)
	_action_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(_action_bar)
	var bar_gap: Control = Control.new()
	bar_gap.custom_minimum_size = Vector2(24, 0)
	bar_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_bar.add_child(bar_gap)
	_resolve_btn = Button.new()
	_resolve_btn.text = "Résoudre"
	_resolve_btn.custom_minimum_size = Vector2(240, 66)  # ≥44 px (pilier TACTILE)
	_resolve_btn.add_theme_font_size_override("font_size", MerlinVisual.FS_BTN)
	_resolve_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MerlinVisual.apply_button_da(_resolve_btn)
	_resolve_btn.pressed.connect(_on_resolve)
	_resolve_btn.disabled = true
	_resolve_btn.self_modulate.a = 0.35  # Z6 : TOUJOURS visible — désarmé = estompe (jamais visible=false)
	_action_bar.add_child(_resolve_btn)
	MerlinVisual.connect_button_feedback(_resolve_btn)  # v10.13.1 — feedback canon §21 `tap`
	# v11-V2a (dé-jargonnage) — l'indice de dé (_die_hint) est SUPPRIMÉ : le liseré de la tuile
	# porte déjà la qualité du jet (R133).

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


func _cream_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_TEXT  # crème parchemin (#E8DCC0)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3)
	sb.border_color = COL_GOLD  # teinte par phase via _set_encart_phase (signal de transition)
	sb.set_content_margin_all(18)
	return sb
