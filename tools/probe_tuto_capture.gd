extends SceneTree
## probe_tuto_capture.gd (N4-TUTO) : sonde FENÊTRÉE de capture du guide de Merlin, sur chronique
## VIERGE simulée (section [chronique] de user://options.cfg effacée puis RESTAURÉE à l'octet
## près, comme la save joueur : pattern autoplay_run/capture_qa_v11). Capture : (a) la proposition
## Z4, (b) 3-4 étapes du guide (verbes surlignés, pose de la combinaison par Merlin, d20/sceau
## expliqué, envoi), (c) la reprise en main par le joueur (+ le draft d'ouverture décalé, B3).
## Lancer NON-headless (rendu réel) :
##   "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --path . --script res://tools/probe_tuto_capture.gd
## Sortie : output/captures/tuto/*.png + lignes [TUTO-CAP] ; anomalies préfixées [TUTO-CAP][ANOMALIE].
## RÈGLE : duck-typing OBLIGATOIRE sur la scène de jeu et le tutoriel (has_method / get) : un
## renommage côté jeu casse BRUYAMMENT au runtime, jamais au parse.

const OUT_DIR: String = "res://output/captures/tuto/"
const GLOBAL_DEADLINE_S: float = 300.0
const OPTIONS_PATH: String = "user://options.cfg"
const SAVE_PATH: String = "user://merlin_run.json"

# step_id du tutoriel -> nom de capture (au moment où le clic est armé : mise en scène posée).
const STEP_CAPS: Dictionary = {
	"verbes": "ph_b1_verbes",
	"combo": "ph_b2_combo_merlin",
	"sceau": "ph_b3_sceau_d20",
	"envoi": "ph_b4_envoi",
}

var _t0: int = 0
var _saved: int = 0
var _anoms: PackedStringArray = []


func _init() -> void:
	_run()


func _left() -> float:
	return GLOBAL_DEADLINE_S - float(Time.get_ticks_msec() - _t0) / 1000.0


func _note(msg: String) -> void:
	_anoms.append(msg)
	print("[TUTO-CAP][ANOMALIE] " + msg)


func _until(pred: Callable, timeout_s: float) -> bool:
	var budget: float = minf(timeout_s, maxf(_left(), 0.0))
	var dl: int = Time.get_ticks_msec() + int(budget * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return bool(pred.call())


func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		_note("%s : image nulle (viewport non rendu ?)" % nm)
		return
	var path: String = ProjectSettings.globalize_path(OUT_DIR) + nm + ".png"
	var err: int = img.save_png(path)
	if err == OK:
		_saved += 1
		print("[TUTO-CAP] capture %s (%dx%d) -> %s" % [nm, img.get_width(), img.get_height(), path])
	else:
		_note("%s : save_png a échoué (err=%d)" % [nm, err])


func _flag(node: Node, prop: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return bool(node.get(prop))


func _tw_active(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var tw: Tween = node.get("_tw") as Tween
	return tw != null and tw.is_valid()


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	var mk: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if mk != OK:
		print("[TUTO-CAP] FATAL : mkdir err=%d" % mk)
		quit(1)
		return
	DisplayServer.window_set_title("MERLIN CAPTURE TUTO (N4) — NE PAS FERMER")
	print("[TUTO-CAP] start")

	# Sauvegardes RÉELLES du joueur : snapshot avant, restauration après (même en échec).
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	var save_backup: String = FileAccess.get_file_as_string(SAVE_PATH) if had_save else ""
	var had_opts: bool = FileAccess.file_exists(OPTIONS_PATH)
	var opts_backup: String = FileAccess.get_file_as_string(OPTIONS_PATH) if had_opts else ""

	# Chronique VIERGE simulée : la section [chronique] disparaît (defaults = runs_played 0,
	# tuto_proposed false) ; les autres sections (audio/a11y/tuto hints) restent intactes.
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(OPTIONS_PATH)
	if cfg.has_section("chronique"):
		cfg.erase_section("chronique")
	cfg.save(OPTIONS_PATH)
	print("[TUTO-CAP] chronique vierge simulée")

	await _drive()

	# Restauration à l'octet près (pattern autoplay_run).
	if had_opts:
		var fo: FileAccess = FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
		if fo != null:
			fo.store_string(opts_backup)
			fo.close()
			print("[TUTO-CAP] options.cfg restauré")
	elif FileAccess.file_exists(OPTIONS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OPTIONS_PATH))
	if had_save:
		var fs: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if fs != null:
			fs.store_string(save_backup)
			fs.close()
			print("[TUTO-CAP] sauvegarde joueur restaurée")
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("[TUTO-CAP] DONE — captures=%d anomalies=%d temps=%ds" % [
		_saved, _anoms.size(), int(float(Time.get_ticks_msec() - _t0) / 1000.0)])
	for a in _anoms:
		print("[TUTO-CAP][RECAP] " + a)
	quit(0 if _anoms.is_empty() else 1)


func _drive() -> void:
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		_note("autoloads MerlinRun/MerlinScenario indisponibles")
		return
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Capture N4-TUTO", "Le sentier se referme derrière le Voyageur.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file("res://scenes/MerlinGame.tscn")
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		_note("MerlinGame non chargée")
		return

	# Intro puis interstitiel (pattern capture_qa_v11).
	var ok_intro: bool = await _until(
		func() -> bool: return not is_instance_valid(game) or _flag(game, "_intro_open"), 15.0)
	if not ok_intro:
		_note("intro jamais ouverte")
	if is_instance_valid(game) and _flag(game, "_intro_open") and game.has_method("_accept_quest"):
		game._accept_quest()
		print("[TUTO-CAP] quête acceptée")
	var dl_i: int = Time.get_ticks_msec() + int(minf(45.0, maxf(_left(), 0.0)) * 1000.0)
	while is_instance_valid(game) and _flag(game, "_interstitial_open") and Time.get_ticks_msec() < dl_i:
		if _tw_active(game) and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		elif _flag(game, "_can_advance") and game.has_method("_end_interstitial"):
			game._end_interstitial()
		else:
			game.set("_interstitial_skip", true)
		await process_frame

	# (a) La PROPOSITION de Merlin (rangée Z4, chronique vierge).
	var ok_prompt: bool = await _until(func() -> bool:
		if not is_instance_valid(game):
			return true
		var row: Node = game.get("_tuto_prompt_row") as Node
		return row != null and is_instance_valid(row), 12.0)
	if not ok_prompt or not is_instance_valid(game):
		_note("proposition du guide jamais ouverte (should_offer_tuto ?)")
		await _cap("ph_a_proposition")
		return
	await create_timer(0.8).timeout  # fondu Z4 posé
	await _cap("ph_a_proposition")

	# Accepter : « Guide-moi » (1er bouton de la rangée).
	var row2: Node = game.get("_tuto_prompt_row") as Node
	if row2 != null and is_instance_valid(row2):
		for tb in row2.get_children():
			if tb is Button:
				(tb as Button).pressed.emit()
				print("[TUTO-CAP] « Guide-moi » cliqué")
				break

	# (b) Les étapes du guide : avance au clic simulé (probe_click), capture aux étapes clés.
	var ok_tuto: bool = await _until(func() -> bool:
		return not is_instance_valid(game) or (game.get("_tuto") as Node) != null, 10.0)
	var tuto: Node = null
	if is_instance_valid(game):
		tuto = game.get("_tuto") as Node
	if not ok_tuto or tuto == null or not is_instance_valid(tuto):
		_note("orchestrateur du guide jamais créé")
		return
	var captured: Dictionary = {}
	var last_step: String = ""
	while is_instance_valid(tuto) and is_instance_valid(game) and _left() > 0.0:
		var sid: String = str(tuto.get("step_id"))
		if sid != last_step:
			last_step = sid
			print("[TUTO-CAP] étape : %s (t=%ds)" % [sid, int(float(Time.get_ticks_msec() - _t0) / 1000.0)])
		var armed: bool = bool(tuto.get("_click_armed"))
		var typing: Tween = tuto.get("_tw") as Tween
		if armed and STEP_CAPS.has(sid) and not captured.has(sid):
			await create_timer(0.5).timeout  # mise en scène posée (spotlight + pose de Merlin)
			if is_instance_valid(tuto) and str(tuto.get("step_id")) == sid:
				await _cap(str(STEP_CAPS[sid]))
				captured[sid] = true
				if tuto.has_method("probe_click"):
					tuto.probe_click()
		elif (typing != null and typing.is_valid()) or armed:
			if tuto.has_method("probe_click"):
				tuto.probe_click()  # révèle le texte puis avance (2 passages)
		await create_timer(0.25).timeout
	for want in STEP_CAPS.keys():
		if not captured.has(want):
			_note("étape « %s » jamais capturée (guide écourté ou étape sautée ?)" % str(want))

	# (c) La REPRISE en main : le guide s'est libéré, le caret « continuer » rend la main.
	if not is_instance_valid(game):
		_note("scène de jeu libérée pendant le guide (run terminée ?)")
		return
	await create_timer(1.0).timeout
	await _cap("ph_c_reprise")

	# Bonus B3 : le premier clic du joueur sert le draft d'ouverture DÉCALÉ (gate unique).
	if _flag(game, "_can_advance") and game.has_method("_advance_to_next"):
		game._advance_to_next()  # fire-and-forget (le draft s'ouvre DANS la coroutine)
		var ok_draft: bool = await _until(
			func() -> bool: return not is_instance_valid(game) or _flag(game, "_draft_active"), 15.0)
		if ok_draft and is_instance_valid(game) and _flag(game, "_draft_active"):
			await create_timer(0.9).timeout
			await _cap("ph_c2_draft_ouverture_decale")
			var dl_d: int = Time.get_ticks_msec() + int(minf(12.0, maxf(_left(), 0.0)) * 1000.0)
			while is_instance_valid(game) and _flag(game, "_draft_active") and Time.get_ticks_msec() < dl_d:
				if game.has_method("_on_draft_skip"):
					game._on_draft_skip()
				await create_timer(0.35).timeout
		else:
			_note("draft d'ouverture décalé jamais ouvert au premier clic post-guide (gate B3 ?)")
	else:
		_note("reprise : _can_advance faux après le guide (état inattendu)")
