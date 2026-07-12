extends SceneTree
## P3 — sonde de CAPTURE (before/after) des 4 états visibles de la vague « session tenable » :
##   1_world_preamble · 2_pause · 3_options_reading · 4_slot_reveal
## Défensive (has_method / `in`) : tourne AUSSI sur HEAD (états « avant ») — les features absentes
## sont sautées avec un log, la capture montre l'équivalent d'époque. Lancer NON-headless (rendu réel) :
##   MERLIN_P3_TAG=after  Godot --path . --script res://tools/probe_p3_capture.gd
## Snapshot/restore de la save joueur pour ne rien polluer. Sortie : output/captures/p3/<tag>_<nm>.png

const OUTDIR: String = "res://output/captures/p3/"
const SAVE_PATH: String = "user://merlin_run.json"
var _tag: String = ""
var _save_backup: String = ""
var _had_save: bool = false


func _init() -> void:
	_run()


func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("[P3CAP] image nulle pour %s" % nm)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTDIR))
	var p: String = OUTDIR + _tag + nm + ".png"
	img.save_png(p)
	print("[P3CAP] %s (%dx%d)" % [ProjectSettings.globalize_path(p), img.get_width(), img.get_height()])


func _until(pred: Callable, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return pred.call()


func _restore_save() -> void:
	if _had_save:
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_save_backup)
			f.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _run() -> void:
	_tag = OS.get_environment("MERLIN_P3_TAG")
	if _tag != "":
		_tag += "_"
	await process_frame
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(SAVE_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))  # run frais → intro (préambule)

	change_scene_to_file("res://scenes/MerlinGame.tscn")
	if not await _until(func() -> bool:
			return current_scene != null and "_intro_open" in current_scene and current_scene._intro_open, 14.0):
		print("[P3CAP] intro jamais ouverte — abort")
		_restore_save()
		quit()
		return
	var game: Node = current_scene

	# 1) PRÉAMBULE DU MONDE — révèle tout le texte puis scroll en tête (§0 = Graal) : capture lisible.
	await create_timer(1.0).timeout
	if game._tw != null and game._tw.is_valid():
		game._skip_typewriter()
	await create_timer(0.4).timeout
	if "_situation_text" in game and game.get("_situation_text") != null:
		game._situation_text.scroll_to_line(0)
	await create_timer(0.4).timeout
	await _cap("1_world_preamble")

	# 2) PAUSE — patched : overlay ; HEAD : jeu sans pause (baseline avant).
	if "_pause" in game and game.get("_pause") != null and game._pause.has_method("open"):
		game._pause.open()
		await create_timer(0.7).timeout
		await _cap("2_pause")
		if game._pause.has_method("_resume"):
			game._pause._resume()
			await create_timer(0.7).timeout
	else:
		print("[P3CAP] pas de _pause (HEAD) — baseline sans overlay")
		await _cap("2_pause")

	# 3) OPTIONS + PACK LECTURE (superposé sur la scène courante).
	var opt: Node = root.get_node_or_null("/root/MerlinOptions")
	if opt != null and opt.has_method("toggle"):
		if not opt.is_open():
			opt.toggle()
		await create_timer(0.8).timeout
		await _cap("3_options_reading")
		if opt.is_open():
			opt.toggle()
		await create_timer(0.5).timeout

	# 4) LISIBILITÉ DU SLOT POSÉ — accepter → traverser l'interstitiel → atteindre un beat → poser
	#    une greffe sur une action → la sélectionner (patched : pastille de lecture ; HEAD : rien).
	if game._intro_open and game.has_method("_accept_quest"):
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
		game._accept_quest()
	await create_timer(0.9).timeout
	if "_interstitial_open" in game and game._interstitial_open:
		if game.get("_interstitial_skip") != null:
			game._interstitial_skip = true
		await create_timer(0.5).timeout
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
		await create_timer(0.3).timeout
		if game.has_method("_end_interstitial"):
			game._end_interstitial()
	await create_timer(0.6).timeout
	# Atteindre un beat : traverser tout ce qui bloque (interstitiel, DRAFT D'OUVERTURE, proposition de
	# guide, typewriters). Le draft d'ouverture attend un pick/pass → sans ça _state ne devient jamais 1.
	var dl2: int = Time.get_ticks_msec() + 45000
	while is_instance_valid(game) and int(game.get("_state")) != 1 and Time.get_ticks_msec() < dl2:
		if bool(game.get("_interstitial_open")):
			if game.get("_interstitial_skip") != null:
				game._interstitial_skip = true
			if game._tw != null and game._tw.is_valid():
				game._skip_typewriter()
			elif bool(game.get("_can_advance")) and game.has_method("_end_interstitial"):
				game._end_interstitial()
		elif "_tuto_prompt_row" in game and game.get("_tuto_prompt_row") != null and game.has_method("_on_tuto_answer"):
			game._on_tuto_answer(false)
		elif bool(game.get("_draft_active")) and game.has_method("_on_draft_skip"):
			game._on_draft_skip()
		elif game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
		await create_timer(0.4).timeout
	if not is_instance_valid(game):
		_restore_save()
		quit()
		return
	if int(game.get("_state")) != 1:
		print("[P3CAP] beat jamais atteint — capture de l'état courant")
	if game._tw != null and game._tw.is_valid():
		game._skip_typewriter()
	await _until(func() -> bool: return bool(game.get("_choice_open")), 8.0)
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	if run != null and run.has_method("apply_graft") and run.has_method("graft_choices") \
			and not (run.actions as Array).is_empty():
		var choices: Array = run.graft_choices(1)
		if not choices.is_empty():
			run.apply_graft(str(run.actions[0].id), choices[0])
			if game.has_method("_refresh_action_tiles"):
				game._refresh_action_tiles()
	if game.has_method("_on_action_tile") and not (run.actions as Array).is_empty():
		game._on_action_tile(run.actions[0])
	await create_timer(0.7).timeout
	await _cap("4_slot_reveal")

	print("[P3CAP] done tag=%s" % _tag)
	_restore_save()
	quit()
