extends SceneTree
## probe_mastery_capture.gd — SONDE JETABLE (N5-C2) : capture les 4 TUILES avec la JAUGE DE MAÎTRISE
## dans 4 états (plafond +2 / +1 / progression / vierge cachée). Modelée sur capture_qa_v11.gd (menu
## warmup -> game -> pilotage duck-typé jusqu'au choix beat 1), puis SEED de verb_usage/talent + refresh
## des tuiles + capture. NON-headless. Restaure la save joueur.
##   "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --path . --script res://tools/probe_mastery_capture.gd

const OUT_DIR: String = "res://output/captures/qa_v11/mastery/"
const DEADLINE_S: float = 150.0
var _t0: int = 0


func _init() -> void:
	_run()


func _left() -> float:
	return DEADLINE_S - float(Time.get_ticks_msec() - _t0) / 1000.0


func _flag(g: Node, f: String) -> bool:
	if not is_instance_valid(g):
		return false
	var v: Variant = g.get(f)
	return v is bool and v


func _tw_on(g: Node) -> bool:
	if not is_instance_valid(g):
		return false
	var v: Variant = g.get("_tw")
	return v != null and v is Tween and (v as Tween).is_valid()


func _until(pred: Callable, timeout_s: float) -> bool:
	var budget: float = minf(timeout_s, maxf(_left(), 0.0))
	var dl: int = Time.get_ticks_msec() + int(budget * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return bool(pred.call())


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	var dir: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	DisplayServer.window_set_title("MERLIN CAPTURE MAITRISE — NE PAS FERMER")
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""

	# Menu d'abord (warmup LLM, comme capture_qa_v11 — évite le hang du flow sur modèle froid).
	change_scene_to_file("res://scenes/MerlinMenu.tscn")
	await create_timer(1.4).timeout

	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		print("[MAST] FAIL autoloads absents")
		quit(1)
		return
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Maitrise", "Le sentier se referme derrière le Voyageur.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file("res://scenes/MerlinGame.tscn")
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		print("[MAST] FAIL MerlinGame non chargée")
		quit(1)
		return

	# Intro -> interstitiel -> draft d'ouverture -> beat 1 (choix ouvert). Duck-typé, borné.
	await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_intro_open"), 15.0)
	if is_instance_valid(game) and _flag(game, "_intro_open") and game.has_method("_accept_quest"):
		game._accept_quest()
	var dl_i: int = Time.get_ticks_msec() + int(minf(45.0, maxf(_left(), 0.0)) * 1000.0)
	while is_instance_valid(game) and _flag(game, "_interstitial_open") and Time.get_ticks_msec() < dl_i:
		if _tw_on(game) and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		elif _flag(game, "_can_advance") and game.has_method("_end_interstitial"):
			game._end_interstitial()
		else:
			game.set("_interstitial_skip", true)
		await process_frame
	if await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_draft_active"), 20.0):
		var dl_d: int = Time.get_ticks_msec() + int(minf(12.0, maxf(_left(), 0.0)) * 1000.0)
		while is_instance_valid(game) and _flag(game, "_draft_active") and Time.get_ticks_msec() < dl_d:
			if game.has_method("_on_draft_skip"):
				game._on_draft_skip()
			await create_timer(0.35).timeout
	await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_choice_open"), 45.0)
	var dl_t: int = Time.get_ticks_msec() + int(minf(6.0, maxf(_left(), 0.0)) * 1000.0)
	while _tw_on(game) and Time.get_ticks_msec() < dl_t:
		if game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		await process_frame

	# Joue UN geste pour STABILISER le layout des tuiles (les slots + la jauge ne se dessinent qu'une
	# fois la taille posée par le HBox — c'est un état atteint dès la post-résolution ; à froid au beat 1,
	# NI les slots existants NI la jauge n'apparaissent, cf. ph4 vs ph6 capture_qa_v11).
	if _flag(game, "_choice_open"):
		if not (run.actions as Array).is_empty() and game.has_method("_on_action_tile"):
			game._on_action_tile((run.actions as Array)[0])
		await create_timer(0.35).timeout
		if not (run.hand as Array).is_empty() and game.has_method("_on_trait_card"):
			game._on_trait_card((run.hand as Array)[0])
		await create_timer(0.6).timeout
		if game.get("_selected_action") != null and game.get("_selected_trait") != null and game.has_method("_on_resolve"):
			game._on_resolve()
			var dl6: int = Time.get_ticks_msec() + int(minf(40.0, maxf(_left(), 0.0)) * 1000.0)
			while Time.get_ticks_msec() < dl6:
				if not is_instance_valid(game) or bool(run.ended):
					break
				if int(game.get("_state")) == 2 and _flag(game, "_can_advance"):
					break
				if _tw_on(game) and game.has_method("_skip_typewriter"):
					game._skip_typewriter()
					await process_frame
					continue
				if _flag(game, "_push_pending") and game.has_method("_on_push_choice"):
					await create_timer(0.3).timeout
					if _flag(game, "_push_pending"):
						game._on_push_choice(false)
					await process_frame
					continue
				await process_frame
			await create_timer(0.8).timeout

	# SEED des 4 états + talent (le +N badge = talent+maîtrise via skill_mod_for) puis refresh tuiles.
	run.verb_usage = {"PERCEVOIR": 6, "AGIR": 4, "PARLER": 2, "RESSENTIR": 0}
	run.talent = {"PERCEVOIR": 1, "AGIR": 0, "PARLER": 0, "RESSENTIR": 0}
	if game.has_method("_set_hand_dimmed"):
		game._set_hand_dimmed(false)  # tuiles à pleine opacité pour la capture de la jauge
	if game.has_method("_refresh_action_tiles"):
		game._refresh_action_tiles()
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		var err: int = img.save_png(dir + "tiles_mastery.png")
		print("[MAST] capture (%dx%d) err=%d -> %stiles_mastery.png" % [img.get_width(), img.get_height(), err, dir])
	else:
		print("[MAST] FAIL image nulle")

	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
	else:
		run.clear_save()
	print("[MAST] DONE — verb_usage=%s" % str(run.verb_usage))
	quit(0)
