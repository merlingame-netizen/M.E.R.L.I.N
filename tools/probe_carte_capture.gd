extends SceneTree
## Capture la carte à l'encre de la sélection : l'attente qui se dessine, deux parchemins qui
## arrivent, le choix qui prolonge le trait. Sans modèle : les titres sont posés par la sonde.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_carte_capture.gd

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
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	if run != null:
		run.biome = "foret"
	change_scene_to_file("res://scenes/MerlinSelection.tscn")
	await create_timer(7.0).timeout
	await _capturer("carte_1_attente")
	var sel: Node = current_scene
	if sel == null or not sel.has_method("_add_parchemin"):
		printerr("[CARTE] pas de sélection")
		quit(1)
		return
	sel.call("_add_parchemin", "La Cloche d'Ys", "La marée descend depuis une heure, et le sable tient sous la botte.")
	await create_timer(2.5).timeout
	await _capturer("carte_2_premier_parchemin")
	sel.call("_add_parchemin", "Le Compte Juste", "Un phare que personne n'allume plus, et quelqu'un qui y monte tous les jours.")
	sel.call("_add_parchemin", "Les Neuf Corbeaux", "Dame Aveline compte ses oiseaux, et il en manque un.")
	await create_timer(3.0).timeout
	await _capturer("carte_3_trois_parchemins")
	sel.call("_on_pick", "Le Compte Juste", "Un phare que personne n'allume plus, et quelqu'un qui y monte tous les jours.")
	await create_timer(6.0).timeout
	await _capturer("carte_4_trace_ton_sentier")
	sel.set("_saut_ouverture", true)
	await create_timer(3.0).timeout
	print("[CARTE] scène : %s" % (current_scene.scene_file_path if current_scene != null else "?"))
	print("[CARTE] fini")
	quit(0)


func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		return
	var chemin: String = "%s%s.png" % [_out, nom]
	if img.save_png(chemin) == OK:
		print("[CARTE] %s" % chemin)
