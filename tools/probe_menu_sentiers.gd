extends SceneTree
## Sonde de la porte SENTIERS du menu : l'ouvre, la capture, lance un sentier, vérifie qu'on est en jeu.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_menu_sentiers.gd
##
## POURQUOI. `--check-only` ne compile pas le menu (faux positif MerlinAudio, autoload absent) : la
## seule preuve qu'une entrée de menu marche est de la presser. Elle rend deux images et un verdict.

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
	change_scene_to_file("res://scenes/MerlinMenu.tscn")
	await create_timer(4.0).timeout
	var menu: Node = current_scene
	if menu == null or not menu.has_method("_on_sentiers"):
		printerr("[SONDE] le menu n'a pas de porte SENTIERS")
		quit(1)
		return
	menu.call("_on_sentiers")
	await create_timer(1.5).timeout
	var voile: Node = menu.get_node_or_null("SentiersOverlay")
	print("[SONDE] voile SENTIERS : %s" % ("ouvert" if voile != null else "ABSENT"))
	var lignes: int = 0
	if voile != null:
		for b in voile.find_children("*", "Button", true, false):
			if (b as Button).custom_minimum_size.y >= 80.0:
				lignes += 1
	print("[SONDE] sentiers proposés : %d (attendu %d)" % [lignes, MerlinSentier.liste().size()])
	await _capturer("menu_sentiers")
	if voile == null:
		quit(1)
		return
	menu.call("_lancer_le_sentier", "le_compte_juste", voile)
	await create_timer(6.0).timeout
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var en_jeu: bool = current_scene != null and current_scene.scene_file_path.ends_with("MerlinGame.tscn")
	var beat: Dictionary = run.current_beat() if run != null else {}
	print("[SONDE] scène courante : %s" % (current_scene.scene_file_path if current_scene != null else "aucune"))
	print("[SONDE] biome=%s beat=%s sentier=%s" % [str(run.biome) if run != null else "?",
		str(beat.get("n", "?")), str(beat.get("sentier", false))])
	await _capturer("jeu_depuis_sentier")
	var ok: bool = en_jeu and lignes == MerlinSentier.liste().size() and bool(beat.get("sentier", false))
	print("[SONDE] %s" % ("SONDE PASSÉE" if ok else "SONDE ÉCHOUÉE"))
	quit(0 if ok else 1)


func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[SONDE] pas d'image pour %s" % nom)
		return
	var chemin: String = "%s%s.png" % [_out, nom]
	if img.save_png(chemin) == OK:
		print("[SONDE] %s (%dx%d)" % [chemin, img.get_width(), img.get_height()])
