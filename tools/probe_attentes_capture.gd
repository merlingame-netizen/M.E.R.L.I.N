extends SceneTree
## Capture les scènes où l'on patiente : le boot, le voile de la sélection (« Merlin rêve »), la
## fusion qui attend l'issue (« Merlin tisse »). Elle rend des images, sans modèle.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_attentes_capture.gd

var _out: String = ""


func _init() -> void:
	_run()


func _run() -> void:
	_out = OS.get_environment("MERLIN_CAP_OUT")
	if _out == "":
		_out = "user://"
	if not _out.ends_with("/"):
		_out += "/"
	await process_frame
	if ResourceLoader.exists("res://scenes/MerlinBoot.tscn"):
		change_scene_to_file("res://scenes/MerlinBoot.tscn")
		await create_timer(1.6).timeout
		await _capturer("attente_boot_1")
		await create_timer(2.0).timeout
		await _capturer("attente_boot_2")
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	if run != null:
		run.biome = "foret"
	change_scene_to_file("res://scenes/MerlinSelection.tscn")
	await create_timer(4.0).timeout
	await _capturer("attente_selection_reve")
	# La fusion qui attend : on charge un sentier et on joue la fusion avec un prédicat jamais prêt.
	var s: Dictionary = MerlinSentier.charger("le_compte_juste")
	if run != null and not s.is_empty():
		run.new_run(s)
		run.beat_index = 2
	change_scene_to_file("res://scenes/MerlinGame.tscn")
	await create_timer(5.0).timeout
	var jeu: Node = current_scene
	if jeu != null and jeu.scene_file_path.ends_with("MerlinGame.tscn"):
		var res: Dictionary = {"degree": "reussite", "die": 7, "total": 10, "dc": 9, "margin": 1,
			"phrase_geste": "Vous passez en force", "mise": "", "success": true, "meca_verb": "COMBATTRE"}
		var fx: Node = MerlinFx.play(jeu, res, [], [], func() -> bool: return false, Callable(), null)
		fx.call("run")
		await create_timer(1.2).timeout
		await _capturer("attente_fusion_1")
		await create_timer(5.5).timeout
		await _capturer("attente_fusion_tisse_1")
		await create_timer(9.0).timeout
		await _capturer("attente_fusion_tisse_2")
	print("[ATTENTES] fini")
	quit(0)


func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		return
	var chemin: String = "%s%s.png" % [_out, nom]
	if img.save_png(chemin) == OK:
		print("[ATTENTES] %s" % chemin)
