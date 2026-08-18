extends Control
## MerlinSelection — écran de sélection (bible R56). Merlin propose 3 sentiers (titre + pitch),
## le joueur en CHOISIT un MANUELLEMENT → montage (squelette + arc) → scène de jeu.
## v10.19 (user 2026-06-29) : les 3 TITRES sont FORCÉMENT LLM — montage « Merlin rêve les sentiers »
## ultra-animé tant qu'ils ne sont pas prêts. Le pick enchaîne sur la transition à l'encre
## (user 2026-08-14 : le montage « zoom vers Merlin » a été retiré).
## v23 (user 2026-08-15) : le contrat devient ABSOLU — plus de bouton « passer », plus de titres
## écrits en dur. Merlin écrit, ou l'écran renonce et rend la main au menu après un second essai.
## Le secours n'est plus un lot de consolation silencieux : il n'existe plus ici.

const COL_BG: Color = MerlinVisual.BG_DEEP
const COL_SURFACE: Color = MerlinVisual.SURFACE
const COL_TEXT: Color = MerlinVisual.CREAM
const COL_GOLD: Color = MerlinVisual.GOLD

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const MENU_SCENE: String = "res://scenes/MerlinMenu.tscn"
const GAME_MUSIC: String = "res://music/loop/VOYAGEUR - INTRO (Tri Martolod) (Remastered).mp3-loop.wav"

# Filet dur. Au-delà, on ne sert PAS les titres en dur : on renonce et on rend la main au menu
# (user 2026-08-15).
#
# 120 s VIENT DE LA MESURE, pas d'un pifomètre : l'agent `native-bench` a chronométré le moteur
# sur CETTE tâche (VM ARM, gemma4-e4b) — 2,93 tok/s, 130 tokens, soit **44 s** par sélection,
# plus 3,4 s de chargement à froid. Deux essais coûtent donc ~90 s dans le pire cas.
#
# L'ancienne valeur de 75 s rendait le second essai DÉCORATIF : le filet tombait avant qu'il ait
# pu aboutir, et le joueur repartait au menu alors que Merlin écrivait encore. Un garde-fou qui
# tranche au milieu de ce qu'il est censé protéger ne protège rien.
const TITLES_CAP_S: float = 120.0

# Images par seconde pendant l'attente. 5 et non 1 : en dessous, les fondus et les points
# cyclants deviennent saccadés au point de faire croire à un blocage — l'écran doit rester
# VIVANT pendant qu'il attend, c'est ce qui distingue « il travaille » de « il a planté ».
const FPS_ATTENTE: int = 5
# Retenu HORS de la coroutine : si la scène est libérée pendant l'attente, celle-ci ne reprend
# jamais et la restauration en ligne ne s'exécuterait pas — le JEU ENTIER resterait à 5 images
# par seconde, un mal bien pire que celui qu'on soigne. _exit_tree rattrape ce cas.
var _fps_avant: int = -1
# Début de l'attente des titres. Sert au TÉMOIN de réussite : sans chiffre, « ça a marché » ne
# se distingue pas de « ça a marché en deux minutes », qui est un défaut.
var _t_debut: int = 0

var _cards_box: HBoxContainer
var _backdrop: MerlinSceneArt          # décor de fond, arrêté pendant la génération
var _decor_gele: bool = false
var _reveles: int = 0                  # parchemins déjà montrés depuis le flux d'écriture
var _title_lbl: Label
var _back_btn: Button
var _overlay: Panel
var _overlay_art: MerlinSceneArt
var _overlay_lbl: Label
var _busy: bool = false
var _overlay_dots_tw: Tween = null
var _overlay_pulse_tw: Tween = null
var _overlay_base_txt: String = ""


func _ready() -> void:
	# TÉMOIN D'OUVERTURE. Cet écran ne parlait QUE lorsqu'il renonçait : une réussite était muette,
	# donc indistinguable d'un écran jamais ouvert. Le 2026-08-18, un test lancé sur cette scène
	# n'a laissé aucune trace, et il a fallu deux tours pour comprendre que le harnais coupait le
	# jeu avant la fin — ce que cette seule ligne aurait dit tout de suite.
	print("[MerlinSelection] écran ouvert · biome=%s" % str(get_node("/root/MerlinRun").biome))
	_build_ui()
	_animate_entrance()
	_setup_music()
	call_deferred("_load_selection")


func _setup_music() -> void:
	if not ResourceLoader.exists(GAME_MUSIC):
		return
	var stream: AudioStream = load(GAME_MUSIC)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream
		if wav.format != AudioStreamWAV.FORMAT_IMA_ADPCM:
			var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if wav.stereo else 1
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.data.size() / float(bytes_per_sample * channels))
	MerlinAudio.play_music(stream, 1.5)


func _load_selection() -> void:
	var sc: Node = get_node("/root/MerlinScenario")
	_show_overlay("Merlin rêve les trois sentiers")
	# Titres FORCÉMENT écrits par le modèle. Il n'y a plus de bouton « passer » et plus de secours :
	# soit Merlin écrit, soit on renonce et on retourne au menu. take_selection() ne sert plus que
	# de récupérateur et rend un tableau VIDE tant que rien n'a été écrit.
	# CADENCE RÉDUITE PENDANT QUE MERLIN ÉCRIT (mesuré 2026-08-16). Le jeu consomme ~343 % de CPU
	# — près de 3,5 cœurs sur 4 — en rendu LOGICIEL (llvmpipe, pas de GPU sur la VM). Le moteur LLM
	# vit DANS CE MÊME PROCESSUS : il se dispute les cœurs avec le rendu. D'où l'écart qui a résisté
	# deux jours — 32 s en sonde headless contre plus de 90 s en jeu, même code, même modèle.
	#
	# Cet écran est une ATTENTE : un voile immobile et trois points qui clignotent. Personne ne
	# distingue 5 images par seconde de 30 sur ce contenu, mais le modèle, lui, récupère les cœurs.
	# Restauré DANS TOUS LES CAS plus bas — un jeu resté à 5 images/s après coup serait pire que le
	# mal qu'on soigne.
	_fps_avant = Engine.max_fps
	Engine.max_fps = FPS_ATTENTE
	_geler_le_decor()
	# RÉVÉLATION PROGRESSIVE (bible R57 « streaming OUI au MVP », jamais fait jusqu'ici).
	# Mesuré le 2026-08-18 : l'écriture des trois titres prend 38 s en jeu. Le premier est
	# pourtant terminé au tiers du parcours — le joueur attendait donc vingt-cinq secondes devant
	# un voile alors que Merlin avait déjà quelque chose à lui montrer.
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn != null and mn.has_signal("generation_chunk"):
		mn.generation_chunk.connect(_on_flux)
	_t_debut = Time.get_ticks_msec()
	var ok: bool = await _force_wait_titles(sc)
	if mn != null and mn.has_signal("generation_chunk") and mn.generation_chunk.is_connected(_on_flux):
		mn.generation_chunk.disconnect(_on_flux)
	_rendre_la_cadence()
	_degeler_le_decor()
	var sels: Array = await sc.take_selection() if ok else []
	if not is_inside_tree():
		return
	if sels.size() < 3:
		# Renoncement : on retire ce que le flux avait déjà montré. Laisser des parchemins à
		# l'écran pendant qu'on annonce que Merlin ne répond pas serait un mensonge visuel.
		_vider_les_parchemins()
		await _give_up()
		return
	_hide_overlay()
	var titres: Array = []
	for s in sels:
		titres.append(str(s.get("title", "?")))
	# Seuls ceux que le flux n'a pas déjà posés : les réafficher ferait clignoter l'écran, et le
	# joueur croirait à un défaut. Le nettoyage étant déterministe et appliqué entrée par entrée,
	# les premiers du flux sont exactement les premiers de la liste finale.
	for i in range(_reveles, sels.size()):
		var e: Dictionary = sels[i]
		_add_parchemin(str(e.get("title", "?")), str(e.get("pitch", "")))
	# La DURÉE, écrite par le jeu lui-même dans les conditions du joueur — rendu logiciel compris.
	# Une sonde à côté ne mesure pas la même chose : elle ne dessine rien.
	var mur: int = Time.get_ticks_msec() - _t_debut
	print("[MerlinSelection] trois sentiers en %.1f s : %s" % [mur / 1000.0, str(titres)])
	_verdict_e2e(true, "", mur, titres)


# Attend les titres du modèle. Vrai si prêts ; faux si le modèle a déclaré forfait ou si le filet
# dur a été atteint. Aucune sortie ne distribue de titres en dur (user 2026-08-15).
func _force_wait_titles(sc: Node) -> bool:
	var t0: int = Time.get_ticks_msec()
	var essai_affiche: int = 1
	while is_inside_tree():
		if sc.has_method("is_selection_ready") and sc.is_selection_ready():
			return true
		if sc.has_method("is_selection_failed") and sc.is_selection_failed():
			return false  # essais épuisés — inutile de faire patienter pour rien
		# Le second essai est DIT, pas subi : sans ça, la relance ressemble à un écran figé.
		if sc.has_method("selection_attempt"):
			var n: int = int(sc.selection_attempt())
			if n > essai_affiche:
				essai_affiche = n
				_set_overlay_text("Merlin reprend son souffle")
		if float(Time.get_ticks_msec() - t0) / 1000.0 >= TITLES_CAP_S:
			return false
		# Robustesse : relance la pré-gen si elle n'a pas démarré (modèle prêt plus tard que le menu),
		# ou si le premier essai a échoué. No-op une fois les essais épuisés.
		if sc.has_method("ensure_selection_prefetch"):
			sc.ensure_selection_prefetch()
		await get_tree().create_timer(0.25).timeout
	return false


# Renoncement visible : on nomme ce qui s'est passé, en français simple, puis retour au menu.
# Jamais de titres écrits en dur en guise de lot de consolation.
func _give_up() -> void:
	# Le motif n'est PAS montré au joueur — « réponse illisible : aucun tableau JSON trouvé » ne
	# lui apprendrait rien et casserait la fiction. Mais il part dans le journal, parce que sans
	# lui le prochain diagnostic recommence à zéro : c'est exactement ce qui vient d'arriver, un
	# retour au menu sans la moindre raison consignée nulle part.
	var sc: Node = get_node_or_null("/root/MerlinScenario")
	if sc != null:
		var essais: int = int(sc.selection_attempt()) if sc.has_method("selection_attempt") else 0
		var motif: String = str(sc.selection_motif()) if sc.has_method("selection_motif") else ""
		if motif == "":
			# ZÉRO ESSAI, donc aucun motif : `ensure_selection_prefetch` ne lance rien tant que le
			# moteur n'est pas prêt ET libre. Si cette condition ne s'ouvre jamais, l'attente tourne
			# à vide jusqu'au filet et le renoncement partait SANS RIEN DIRE — le cas le plus
			# fréquent était donc le seul resté muet, et c'est exactement celui qu'on a rencontré.
			# On interroge alors le moteur lui-même pour nommer le verrou fermé.
			var mn: Node = get_node_or_null("/root/MerlinNative")
			if mn == null:
				motif = "MerlinNative absent"
			elif not mn.is_ready():
				var be: String = str(mn.boot_error()) if mn.has_method("boot_error") else ""
				motif = ("le moteur n'a jamais été prêt (%s)" % be) if be != "" \
						else "le moteur charge encore — rien n'a pu être tenté"
			elif mn.is_busy():
				motif = "le moteur est resté occupé par une autre génération"
			else:
				motif = "aucune tentative — cause inconnue"
		push_warning("[MerlinSelection] renoncement après %d essai(s) — %s" % [essais, motif])
		_verdict_e2e(false, motif, Time.get_ticks_msec() - _t_debut, [])
	_set_overlay_text("Merlin ne répond pas ce soir")
	if _overlay_art != null:
		_overlay_art.set_thinking(false)
	if _overlay_dots_tw != null and _overlay_dots_tw.is_valid():
		_overlay_dots_tw.kill()   # les points « … » promettent une suite qui ne viendra pas
	await get_tree().create_timer(2.2).timeout
	if is_inside_tree():
		MerlinTransition.change_scene(MENU_SCENE)


# VERDICT DE BOUT EN BOUT. Actif uniquement si MERLIN_E2E=1 — le jeu normal ne s'arrête jamais
# tout seul et n'écrit aucun fichier ici.
#
# POURQUOI DANS LA SCÈNE, et non dans une sonde à côté : `tools/probe_selection_e2e.gd` rend déjà
# un verdict binaire, mais il tourne SANS rien dessiner. Or c'est justement le rendu logiciel qui
# est suspecté de coûter les secondes. Un verdict qui ne passe pas par le vrai écran ne mesure
# donc pas ce que Maxime vit. Celui-ci, si.
#
# Le fichier ET le code de sortie : le premier porte les détails, le second permet à un script de
# refuser une livraison. Un test qui rend toujours 0 ne bloque rien.
func _verdict_e2e(ok: bool, motif: String, mur_ms: int, titres: Array) -> void:
	if OS.get_environment("MERLIN_E2E") != "1":
		return
	var d: Dictionary = {
		"ok": ok, "motif": motif, "mur_ms": mur_ms, "titres": titres,
		"biome": str(get_node("/root/MerlinRun").biome),
		"t": Time.get_datetime_string_from_system(true),
	}
	var chemin: String = OS.get_environment("MERLIN_E2E_OUT")
	if chemin == "":
		chemin = "user://merlin_e2e_selection.json"
	var f: FileAccess = FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()
	else:
		push_warning("[MerlinSelection] verdict e2e non écrit : %s illisible" % chemin)
	print("[E2E_JSON] " + JSON.stringify(d))
	get_tree().quit(0 if ok else 1)


# v10.22 (QA user, screenshot) — carte À LA CHARTE du menu : hauteur AJUSTÉE AU CONTENU (fini le panneau
# 560px aux 2/3 vide), ornement triskèle sous le titre (langage du menu), pitch centré, bouton collé au
# texte. La carte se centre verticalement dans la rangée (SHRINK_CENTER).
func _add_parchemin(title: String, pitch: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)  # hauteur = contenu
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _surface_style())
	var marg: MarginContainer = MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		marg.add_theme_constant_override(side, 30)
	marg.add_theme_constant_override("margin_top", 26)
	marg.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(marg)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	marg.add_child(v)

	var t: Label = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COL_GOLD)
	t.add_theme_font_size_override("font_size", 30)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	v.add_child(MerlinOrnament.triskele_rule(18.0))  # ornement du menu — même langage partout (R125)

	var p: Label = Label.new()
	p.text = pitch
	p.add_theme_color_override("font_color", COL_TEXT)
	p.add_theme_font_size_override("font_size", 22)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(p)

	var sp: Control = Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)

	var b: Button = Button.new()
	b.text = "Suivre ce sentier"
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 22)
	MerlinVisual.apply_button_da(b)
	b.pressed.connect(_on_pick.bind(title, pitch))
	MerlinVisual.connect_button_feedback(b)
	v.add_child(b)

	_cards_box.add_child(panel)
	_card_in(panel, 0.10 + 0.14 * float(_cards_box.get_child_count() - 1))


# Entrée de parchemin : pop d'échelle + fondu (juice renforcé, user 2026-06-29). Pas de position
# (l'HBox la pilote) → on anime modulate + scale (que le conteneur ne réécrit pas).
func _card_in(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.90, 0.90)
	var m: float = MerlinVisual.motion()
	var tw: Tween = node.create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	# v10.22 : pivot posé APRÈS layout (hauteur = contenu → custom_minimum_size.y vaut 0 désormais).
	tw.tween_callback(func() -> void: node.pivot_offset = node.size * 0.5)
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.45 * m).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2.ONE, 0.55 * m).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pick(title: String, pitch: String) -> void:
	if _busy:
		return
	_busy = true
	# Squelette INSTANTANÉ (le pitch est le synopsis) → bascule immédiate vers le jeu.
	var skel: Dictionary = get_node("/root/MerlinScenario").build_skeleton(title, pitch)
	get_node("/root/MerlinRun").new_run(skel)
	# Arc narratif LLM en arrière-plan (fire-and-forget) ; l'interstitiel in-game (R111) le couvre.
	get_node("/root/MerlinScenario").prepare_arc(skel)
	# Transition à l'encre, sans légende (user 2026-08-14) : le montage « zoom vers Merlin » est retiré
	# — il montrait Merlin seul, agrandi, sur fond sombre, sans rien dire. Les captions CANNÉES restent
	# neutralisées depuis la Vague D (D1) : aucun panneau de texte à la bascule.
	MerlinTransition.change_scene(GAME_SCENE)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# v10.20 — fond SCÈNE VIVANTE (DA alignée sur le menu, user 2026-06-29) : même monde, dimmé.
	# Retenu dans un champ (2026-08-18) : il faut pouvoir l'ARRÊTER pendant que Merlin écrit.
	_backdrop = MerlinOrnament.scene_backdrop(0.40)
	add_child(_backdrop)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 40)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	_title_lbl = Label.new()
	_title_lbl.text = "Choisis ton chemin"
	_title_lbl.add_theme_color_override("font_color", COL_GOLD)
	_title_lbl.add_theme_font_size_override("font_size", 46)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title_lbl)
	# Filet + triskèle or (signature DA du menu).
	var rule: HBoxContainer = MerlinOrnament.triskele_rule(24.0)
	root.add_child(rule)
	MerlinOrnament.spin_triskele(rule)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 24)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_cards_box)

	_back_btn = Button.new()
	_back_btn.text = "◀ Retour"
	_back_btn.custom_minimum_size = Vector2(140, 44)
	MerlinVisual.apply_button_da(_back_btn)
	_back_btn.pressed.connect(_on_back)
	root.add_child(_back_btn)
	MerlinVisual.connect_button_feedback(_back_btn)

	# --- Overlay « montage réflexion de Merlin » (ultra-animé) ---
	_overlay = Panel.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ov_sb: StyleBoxFlat = StyleBoxFlat.new()
	ov_sb.bg_color = Color(MerlinVisual.BG_DEEP.r, MerlinVisual.BG_DEEP.g, MerlinVisual.BG_DEEP.b, 0.96)
	_overlay.add_theme_stylebox_override("panel", ov_sb)
	# MOUSE_FILTER_STOP reste : le voile avale les clics pour qu'aucune carte en dessous ne soit
	# cliquable pendant l'attente. Plus aucun gui_input à écouter — le « passer » a disparu.
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	# Scène vivante de Merlin (réflexion) en fond du montage, atténuée pour la lisibilité du texte.
	_overlay_art = MerlinSceneArt.new()
	_overlay_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_art.modulate.a = 0.5
	_overlay.add_child(_overlay_art)
	_overlay_art.set_menu_decor(true)
	_overlay_art.set_beat("Rencontre")
	_overlay_art.set_season(MerlinSceneArt.season_for_now())
	_overlay_art.set_biome(str(get_node("/root/MerlinRun").biome))  # v10.22 : même monde que la run
	var hour: int = int(Time.get_datetime_dict_from_system().get("hour", 21))
	if OS.has_environment("MERLIN_TOD_HOUR"):
		hour = int(OS.get_environment("MERLIN_TOD_HOUR"))
	_overlay_art.set_time_of_day(hour)
	_overlay_art.set_animated(true)
	_overlay_lbl = Label.new()
	_overlay_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_lbl.add_theme_color_override("font_color", COL_GOLD)
	_overlay_lbl.add_theme_font_size_override("font_size", 40)
	_overlay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_overlay_lbl)
	_overlay.visible = false


# Chaque morceau de texte écrit par le modèle passe ici. On n'attend pas la fin : dès qu'un objet
# JSON se referme, son parchemin peut être posé.
func _on_flux(cumul: String) -> void:
	if not is_inside_tree():
		return
	var objets: Array = _objets_complets(cumul)
	# Un compte qui RECULE veut dire qu'une nouvelle tentative a commencé (le cumul repart de
	# zéro) : on efface ce que la précédente avait posé plutôt que de mélanger deux écritures.
	if objets.size() < _reveles:
		_vider_les_parchemins()
	while _reveles < objets.size():
		var propre: Array = MerlinProse.clean_selection([objets[_reveles]])
		_reveles += 1
		if propre.is_empty():
			continue   # entrée inexploitable : on la saute sans casser le compte
		var e: Dictionary = propre[0]
		_hide_overlay()   # idempotent — le voile ne tombe qu'au premier parchemin
		_add_parchemin(str(e.get("title", "?")), str(e.get("pitch", "")))


# Objets JSON COMPLETS trouvés dans un texte encore en cours d'écriture. On suit l'état des
# guillemets et des échappements : un « } » à l'intérieur d'un titre ne doit pas être pris pour
# une fin d'objet, sinon on afficherait des moitiés de parchemin.
func _objets_complets(txt: String) -> Array:
	var out: Array = []
	var profondeur: int = 0
	var debut: int = -1
	var dans_chaine: bool = false
	var echappe: bool = false
	for i in txt.length():
		var c: String = txt[i]
		if dans_chaine:
			if echappe:
				echappe = false
			elif c == "\\":
				echappe = true
			elif c == "\"":
				dans_chaine = false
			continue
		if c == "\"":
			dans_chaine = true
		elif c == "{":
			if profondeur == 0:
				debut = i
			profondeur += 1
		elif c == "}":
			profondeur -= 1
			if profondeur == 0 and debut >= 0:
				var d: Variant = JSON.parse_string(txt.substr(debut, i - debut + 1))
				if d is Dictionary:
					out.append(d)
				debut = -1
			elif profondeur < 0:
				profondeur = 0   # accolade orpheline : on repart proprement
	return out


func _vider_les_parchemins() -> void:
	_reveles = 0
	if _cards_box == null:
		return
	for enfant in _cards_box.get_children():
		enfant.queue_free()


# ARRÊTER LE DÉCOR PENDANT QUE MERLIN ÉCRIT (mesuré 2026-08-18).
#
# LE CHIFFRE : la même génération prend 31,5 s sans rien dessiner et 112,4 s dans cet écran.
# Quatre-vingt-une secondes d'écart pour de la décoration. La VM n'a pas de carte graphique —
# tout est dessiné par le processeur (llvmpipe), et le modèle vit DANS LE MÊME PROCESSUS : chaque
# pixel peint est un pixel volé à Merlin.
#
# Et il y a DEUX décors procéduraux plein écran empilés ici, chacun avec près de quatre-vingt-dix
# appels de dessin : le fond, et la scène du voile. Le fond est recouvert à 96 % par le voile —
# on le redessinait donc intégralement pour ne rien montrer.
#
# `set_process(false)` en plus de `set_animated(false)` : sans lui `_process` continue de tourner
# et de demander des redessins (feuilles, regard, halo). Couper l'animation sans couper le
# processus ne gèlerait que l'apparence, pas le coût.
#
# Ce que le joueur perd : Merlin ne respire plus pendant qu'il écrit. Ce qu'il gagne : Merlin
# écrit. Arbitrage assumé (décision Maxime, 2026-08-18).
func _geler_le_decor() -> void:
	if _decor_gele:
		return
	_decor_gele = true
	for art in [_backdrop, _overlay_art]:
		if art != null and is_instance_valid(art):
			art.set_animated(false)
			art.set_process(false)


# Idempotent, et appelé sur TOUS les chemins de sortie : un décor resté gelé après coup donnerait
# un écran mort, exactement le défaut qu'on cherche à éviter ailleurs.
func _degeler_le_decor() -> void:
	if not _decor_gele:
		return
	_decor_gele = false
	for art in [_backdrop, _overlay_art]:
		if art != null and is_instance_valid(art):
			art.set_process(true)
			art.set_animated(true)


# Rend la cadence d'origine. Idempotent : appelée en fin d'attente ET à la sortie de scène,
# sans qu'aucun des deux chemins n'ait à savoir si l'autre est déjà passé.
func _rendre_la_cadence() -> void:
	if _fps_avant >= 0:
		Engine.max_fps = _fps_avant
		_fps_avant = -1


func _exit_tree() -> void:
	_rendre_la_cadence()
	_decor_gele = false   # les nœuds partent avec la scène : rien à dégeler, mais l'état doit être net


func _on_back() -> void:
	MerlinTransition.change_scene(MENU_SCENE)


func _show_overlay(txt: String) -> void:
	_overlay.visible = true
	_overlay_base_txt = txt
	_overlay_lbl.text = txt
	if _overlay_art != null:
		_overlay_art.set_thinking(true)  # mote « Merlin réfléchit »
	# Pulse de la légende (respiration) — « ultra animé ».
	if _overlay_pulse_tw != null and _overlay_pulse_tw.is_valid():
		_overlay_pulse_tw.kill()
	if not MerlinVisual.reduced_motion:
		_overlay_pulse_tw = create_tween().set_loops()
		_overlay_pulse_tw.tween_property(_overlay_lbl, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)
		_overlay_pulse_tw.tween_property(_overlay_lbl, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	if _overlay_dots_tw != null and _overlay_dots_tw.is_valid():
		_overlay_dots_tw.kill()
	_overlay_dots_tw = create_tween().set_loops()
	for suffix in ["", "  ·", "  · ·", "  · · ·"]:
		_overlay_dots_tw.tween_callback(_set_overlay_suffix.bind(suffix))
		_overlay_dots_tw.tween_interval(0.4)
	# Note (user 2026-06-30) : le « son de point » (quill_tick toutes les 0.6 s) est RETIRÉ — jugé inutile.
	# Les points « … » restent purement visuels.


func _set_overlay_suffix(suffix: String) -> void:
	if _overlay_lbl != null:
		_overlay_lbl.text = _overlay_base_txt + suffix


# Change la légende SANS toucher aux animations en cours (les points « … » continuent de suivre
# le nouveau texte via _set_overlay_suffix, qui lit _overlay_base_txt).
func _set_overlay_text(txt: String) -> void:
	_overlay_base_txt = txt
	if _overlay_lbl != null:
		_overlay_lbl.text = txt


func _hide_overlay() -> void:
	_overlay.visible = false
	if _overlay_art != null:
		_overlay_art.set_thinking(false)
		_overlay_art.set_animated(false)  # stoppe les redraws du décor une fois le montage fini
	for tw in [_overlay_dots_tw, _overlay_pulse_tw]:
		if tw != null and tw.is_valid():
			tw.kill()
	_overlay_dots_tw = null
	_overlay_pulse_tw = null


func _animate_entrance() -> void:
	_fade_in(_title_lbl, 0.00, 0.45)
	_fade_in(_cards_box, 0.20, 0.50)
	_fade_in(_back_btn, 0.55, 0.35)


func _fade_in(node: CanvasItem, delay: float, dur: float) -> void:
	node.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_interval(maxf(delay, 0.001))
	tw.tween_property(node, "modulate:a", 1.0, dur * MerlinVisual.motion()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _surface_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COL_SURFACE
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	return sb
