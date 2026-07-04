extends Control
## v10.18 — BOOT CINÉMATIQUE (5 actes). Le modèle Gemma 4 charge DANS UN THREAD (MerlinNative → zéro
## freeze). On démarre DÉJÀ zoomé sur les yeux de Merlin : (1) ils se réveillent, (2) ils regardent,
## (3) dézoom + le décor apparaît selon SAISON + heure du jour, (4) pause 0,5s, (5) GRONDEMENT + le menu
## est poussé DE FORCE depuis la gauche (décor + yeux ébahis, 1,3s) → swap vers MerlinMenu. Scène de lancement.

const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"
const EVEIL_MUSIC: String = "res://music/intro/boot_eveil.wav"  # cue d'éveil (≠ thème → crossfade propre au menu)
const EVEIL_FADE_IN: float = 2.0    # fondu d'entrée doux de la musique d'éveil
const ZOOM_START: float = 3.4       # gros plan initial sur les yeux
const ACT1_WAKE_S: float = 1.6      # réveil des yeux (ouverture + allumage)
const ACT2_GAZE_S: float = 1.8      # le regard (gauche → droite → centre)
const ACT3_DEZOOM_S: float = 2.2    # dézoom + apparition du décor (saison + heure)
const ACT4_PAUSE_S: float = 0.5     # pause suspendue
const ACT5_PUSH_S: float = 1.3      # grondement + push du menu depuis la gauche
const GATE_MAX_S: float = 8.0       # filet : on n'attend pas le modèle indéfiniment
const SHAKE_AMP: float = 16.0       # amplitude grondement (px)
const SHAKE_AMP_RM: float = 7.0     # amplitude reduced_motion

var _scene_art: MerlinSceneArt
var _stage: Control                 # reçoit la poussée latérale (shove) à l'acte 5
var _panel: ColorRect               # « menu » qui barge depuis la gauche
var _cap_label: Label
var _ready_model: bool = false
var _going: bool = false
var _shake_amp: float = 0.0
var _shake_t: float = 0.0
# Capture dev (env-gated MERLIN_CAPTURE_DIR) — jamais active en prod.
var _cap_dir: String = ""
var _cap_iv_ms: int = 300
var _cap_max: int = 14
var _cap_count: int = 0
var _cap_last: int = 0
var _cap_boot: int = 0


func _ready() -> void:
	MerlinVisual.load_prefs()
	_setup_eveil_music()  # musique d'intro : enchaîne sur le thème à l'arrivée au menu

	var bg: ColorRect = ColorRect.new()
	bg.color = MerlinVisual.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Étage décor : translaté vers la droite (shove) à l'acte 5. Ancrage TOP_LEFT + taille explicite
	# (recalée en _process) → position.x librement tweenable sans que le layout ne la réécrive (C1/C2 review).
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	# Décor vivant — Merlin (beat Climax). Zoom = scale du Control autour du pivot YEUX (recalculé chaque
	# frame en _process). Shake = _scene_art.position. Démarre en gros plan (scale 3.4×), décor caché.
	_scene_art = MerlinSceneArt.new()
	_scene_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_scene_art)
	_scene_art.set_menu_decor(true)
	_scene_art.set_beat("Climax")
	_scene_art.set_season(MerlinSceneArt.season_for_now())
	var tod_hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		tod_hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_scene_art.set_time_of_day(tod_hour)
	# v10.22 — le boot révèle le ciel NEUTRE (comme le menu) : le monde/biome n'apparaît qu'après le
	# choix Forêt/Falaises de Nouvelle Partie.
	_scene_art.set_biome("")
	_scene_art.set_decor_reveal(0.0)     # décor caché : gros plan sur les yeux
	_scene_art.set_figure_reveal(0.65)   # cape + tête prêtes ; yeux à matérialiser
	_scene_art.set_eye_open(0.0)         # yeux fermés
	_scene_art.set_eye_glow(0.0)         # éteints
	_scene_art.scale = Vector2(ZOOM_START, ZOOM_START)
	_scene_art.set_animated(true)

	# Caption discrète (bas-centre) — un mot par acte, très estompé.
	_cap_label = Label.new()
	_cap_label.add_theme_color_override("font_color", MerlinVisual.DIM_WARM)
	_cap_label.add_theme_font_size_override("font_size", 17)
	_cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_label.anchor_left = 0.0
	_cap_label.anchor_right = 1.0
	_cap_label.anchor_top = 1.0
	_cap_label.anchor_bottom = 1.0
	_cap_label.offset_top = -64.0
	_cap_label.offset_bottom = -38.0
	_cap_label.modulate.a = 0.0
	_cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cap_label)

	# Panneau « menu » qui barge depuis la gauche (acte 5). TOP_LEFT + taille explicite (_process) → slide
	# horizontal fiable. Hors écran au départ ; au-dessus de tout.
	_panel = ColorRect.new()
	_panel.color = MerlinVisual.BG_DEEP
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(-4000.0, 0.0)
	add_child(_panel)

	# Modèle Gemma : chargé EN THREAD (MerlinNative) → zéro freeze. Connecter AVANT is_ready() (anti-race).
	# CONNECT_DEFERRED : MerlinNative peut émettre model_ready depuis son thread → le slot court sur le
	# thread principal (pas d'écriture cross-thread de _ready_model — review H2).
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.has_signal("model_ready") and not mn.model_ready.is_connected(_on_model_ready):
			mn.model_ready.connect(_on_model_ready, CONNECT_DEFERRED)
		if mn.has_signal("model_failed") and not mn.model_failed.is_connected(_on_model_failed):
			mn.model_failed.connect(_on_model_failed, CONNECT_DEFERRED)
		if mn.is_ready():
			_on_model_ready()
	else:
		_on_model_ready()

	_cap_dir = OS.get_environment("MERLIN_CAPTURE_DIR")
	if not _cap_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_cap_dir)  # dev : garantir le dossier de capture
	var civ: String = OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS")
	if civ != "":
		_cap_iv_ms = maxi(50, int(civ))
	var cmx: String = OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES")
	if cmx != "":
		_cap_max = maxi(1, int(cmx))

	modulate.a = 0.0
	set_process(true)
	_play_cinematic()


func _setup_eveil_music() -> void:
	if not ResourceLoader.exists(EVEIL_MUSIC):
		return  # cue pas encore généré → silence (le menu lancera le thème)
	var stream: AudioStream = load(EVEIL_MUSIC)
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
	var ma: Node = get_node_or_null("/root/MerlinAudio")
	if ma != null and ma.has_method("play_music"):
		ma.play_music(stream, EVEIL_FADE_IN)  # le menu crossfadera vers le thème (pistes différentes)


func _process(delta: float) -> void:
	# Taille explicite des couches TOP_LEFT (≠ vp seulement → pas de re-sort inutile qui clobberait le shake).
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if _stage != null and _stage.size != vp:
		_stage.size = vp
	if _panel != null and _panel.size != vp:
		_panel.size = vp
	# Pivot du zoom = position des YEUX, recalculé chaque frame (size peut changer au 1er layout).
	if _scene_art != null:
		var ss: Vector2 = _scene_art.size
		if ss.x > 4.0 and ss.y > 4.0:
			_scene_art.pivot_offset = Vector2(ss.x * 0.5, ss.y * 0.37)
	# Shake (grondement, acte 5) — décroissance ~frame-rate-indépendante, arrondi pixel (anti-scintillement).
	if _shake_t > 0.0 and _scene_art != null:
		_shake_t -= delta
		_shake_amp *= pow(0.86, delta * 60.0)
		var ox: float = (randf() * 2.0 - 1.0) * _shake_amp
		var oy: float = (randf() * 2.0 - 1.0) * _shake_amp * 0.45
		_scene_art.position = Vector2(round(ox), round(oy))
		if _shake_t <= 0.0:
			_scene_art.position = Vector2.ZERO
	_maybe_capture()


func _play_cinematic() -> void:
	var m: float = MerlinVisual.motion()
	var rm: bool = MerlinVisual.reduced_motion
	await get_tree().process_frame   # layout settle → pivot/size valides avant le fondu
	var vw: float = float(get_viewport().get_visible_rect().size.x)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5 * m)   # fondu d'entrée (masque le 1er settle)

	# Dev (env-gated) : sauter directement à l'acte 5 pour capturer le push sans la lenteur du gros plan.
	if OS.get_environment("MERLIN_BOOT_SKIP_TO_PUSH") != "":
		_scene_art.scale = Vector2.ONE
		_scene_art.set_figure_reveal(1.0)
		_scene_art.set_eye_open(-1.0)
		_scene_art.set_decor_reveal(1.0)
		_ready_model = true
		await get_tree().create_timer(0.8).timeout
		_push_to_menu(vw, m, rm)
		return

	# ===== ACTE 1 — RÉVEIL DES YEUX (gros plan) =====
	_caption("il s'éveille")
	var t1: Tween = create_tween().set_parallel(true)
	t1.tween_property(_scene_art, "_eye_open_force", 1.0, ACT1_WAKE_S * m).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t1.tween_property(_scene_art, "_eye_glow", 1.0, ACT1_WAKE_S * m).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t1.tween_property(_scene_art, "_fig_reveal", 1.0, ACT1_WAKE_S * m).from(0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t1.finished

	# ===== ACTE 2 — LE REGARD (gros plan) =====
	_caption("il observe")
	_scene_art.set_scripted_gaze(true, Vector2.ZERO)
	var seg: float = (ACT2_GAZE_S * m) / 3.6
	var t2: Tween = create_tween()
	t2.tween_property(_scene_art, "_gaze_forced", Vector2(-0.85, 0.0), seg * 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(_scene_art, "_gaze_forced", Vector2(0.85, -0.10), seg * 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property(_scene_art, "_gaze_forced", Vector2.ZERO, seg).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t2.finished

	# ===== ACTE 3 — DÉZOOM + ÉVEIL DU DÉCOR (saison + heure) =====
	_caption("le monde s'ouvre")
	_scene_art.set_scripted_gaze(false)   # le regard reprend la main (suit la souris)
	var t3: Tween = create_tween().set_parallel(true)
	t3.tween_property(_scene_art, "scale", Vector2.ONE, ACT3_DEZOOM_S * m).from(Vector2(ZOOM_START, ZOOM_START)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var dz: PropertyTweener = t3.tween_property(_scene_art, "_decor_reveal", 1.0, maxf(ACT3_DEZOOM_S - 0.3, 0.4) * m).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dz.set_delay(0.3 * m)   # le décor « rattrape » la caméra
	await t3.finished

	# ===== ACTE 4 — PAUSE SUSPENDUE + GATE model_ready =====
	_caption("")
	await get_tree().create_timer(ACT4_PAUSE_S * m).timeout
	var waited: float = 0.0
	while not _ready_model and waited < GATE_MAX_S:   # ne JAMAIS quitter avant que le modèle soit prêt
		await get_tree().create_timer(0.1).timeout
		waited += 0.1

	# ===== ACTE 5 — GRONDEMENT + PUSH DEPUIS LA GAUCHE =====
	_push_to_menu(vw, m, rm)


# Acte 5 : grondement (shake + impact sonore) + le menu poussé DE FORCE depuis la gauche ;
# le décor est shové vers la droite, les yeux s'écarquillent (ébahis) et fixent la source.
func _push_to_menu(vw: float, m: float, rm: bool) -> void:
	if _going:
		return
	_going = true
	# GRONDEMENT — impact sonore grave (stamp pitché ↓) + screen-shake.
	var ma: Node = get_node_or_null("/root/MerlinAudio")
	if ma != null and ma.has_method("play_sfx"):
		ma.play_sfx("seal_stamp", 0.55)
	_shake_amp = SHAKE_AMP_RM if rm else SHAKE_AMP
	_shake_t = (0.6 if rm else 1.0) * m

	# YEUX ÉBAHIS — écartement + flash de luminosité + regard qui dérape vers la gauche (la force entrante).
	_scene_art.set_scripted_gaze(true, Vector2(-1.0, 0.0))
	if not rm:
		var tw_eye: Tween = create_tween()
		tw_eye.tween_interval(0.10 * m)
		tw_eye.tween_property(_scene_art, "_eye_widen", 1.5, 0.30 * m).from(1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_eye.tween_property(_scene_art, "_eye_widen", 1.12, 0.45 * m).set_trans(Tween.TRANS_SINE)
		var tw_glow: Tween = create_tween()
		tw_glow.tween_interval(0.10 * m)
		tw_glow.tween_property(_scene_art, "_eye_glow", 1.35, 0.18 * m).from(1.0).set_trans(Tween.TRANS_QUAD)
		tw_glow.tween_property(_scene_art, "_eye_glow", 1.0, 0.40 * m).set_trans(Tween.TRANS_SINE)
	else:
		_scene_art.set_eye_widen(1.2)
	var tw_gaze: Tween = create_tween()
	tw_gaze.tween_interval(0.55 * m)
	tw_gaze.tween_property(_scene_art, "_gaze_forced", Vector2.ZERO, 0.5 * m).set_trans(Tween.TRANS_SINE)

	# DÉCOR shové vers la droite (encaisse la poussée).
	var tw_shove: Tween = create_tween()
	tw_shove.tween_interval(0.15 * m)
	tw_shove.tween_property(_stage, "position:x", vw * 0.40, 0.55 * m).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# MENU poussé DE FORCE depuis la gauche : panneau BG_DEEP, entrée brusque (BACK overshoot).
	var tw_push: Tween = create_tween()
	tw_push.tween_interval((0.10 if rm else 0.15) * m)
	if rm:
		tw_push.tween_property(_panel, "position:x", 0.0, 0.30 * m).from(-vw).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw_push.tween_property(_panel, "position:x", 0.0, 0.85 * m).from(-vw).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(ACT5_PUSH_S * m).timeout
	# Hygiène : se déconnecter de l'autoload persistant avant de céder la scène.
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null:
		if mn.has_signal("model_ready") and mn.model_ready.is_connected(_on_model_ready):
			mn.model_ready.disconnect(_on_model_ready)
		if mn.has_signal("model_failed") and mn.model_failed.is_connected(_on_model_failed):
			mn.model_failed.disconnect(_on_model_failed)
	set_process(false)
	get_tree().change_scene_to_file(MENU_SCENE)


func _caption(txt: String) -> void:
	if _cap_label == null:
		return
	if txt == "":
		create_tween().tween_property(_cap_label, "modulate:a", 0.0, 0.3)
		return
	_cap_label.text = "✦ " + txt
	_cap_label.modulate.a = 0.0
	create_tween().tween_property(_cap_label, "modulate:a", 0.65, 0.5)


func _on_model_ready() -> void:
	_ready_model = true


func _on_model_failed(_reason: String) -> void:
	_ready_model = true   # le menu marche sans LLM (fallback procédural) → ne pas bloquer le boot


func _maybe_capture() -> void:
	if _cap_dir.is_empty():
		return
	if _cap_boot < 3:
		_cap_boot += 1  # laisse 3 frames de warmup avant la 1ère capture
		return
	var now: int = Time.get_ticks_msec()
	if now - _cap_last < _cap_iv_ms or _cap_count >= _cap_max:
		return
	_cap_last = now
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	if img.get_width() > 640:
		var ratio: float = 640.0 / float(img.get_width())
		img.resize(640, int(float(img.get_height()) * ratio), Image.INTERPOLATE_BILINEAR)
	img.save_png("%s/frame_%04d.png" % [_cap_dir, _cap_count])
	_cap_count += 1
