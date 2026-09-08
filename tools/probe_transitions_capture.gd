extends SceneTree
## Capture l'encre en mouvement (menu → jeu « depuis » Merlin, jeu → fin « bas ») et le verdict lisible
## (la marge sous le dé, la lune teintée, les yeux) sur un sentier écrit. Elle rend des images.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_transitions_capture.gd

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
	await create_timer(3.0).timeout
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var s: Dictionary = MerlinSentier.charger("le_compte_juste")
	if run == null or s.is_empty():
		printerr("[TRANS] pas de run ou de sentier")
		quit(1)
		return
	run.biome = "falaises"
	run.new_run(s)
	run.beat_index = 2   # le beat 3, une Épreuve : le décor doit réagir
	var menu: Node = current_scene
	var origine: Vector2 = Vector2(-1.0, -1.0)
	if menu != null and menu.has_method("_origine_de_merlin"):
		origine = menu.call("_origine_de_merlin")
	print("[TRANS] origine de l'encre : %s" % str(origine))
	root.get_node("/root/MerlinTransition").change_scene("res://scenes/MerlinGame.tscn", "", "depuis", origine)
	await create_timer(0.55).timeout
	await _capturer("encre_depuis_merlin")
	await create_timer(6.0).timeout
	var jeu: Node = current_scene
	var en_jeu: bool = jeu != null and jeu.scene_file_path.ends_with("MerlinGame.tscn")
	print("[TRANS] en jeu : %s" % str(en_jeu))
	if en_jeu and jeu.has_method("_reagir_au_verdict"):
		jeu.call("_reagir_au_verdict", {"die": 7, "total": 10, "dc": 9, "margin": 1}, "reussite")
		await create_timer(0.6).timeout
		await _capturer("verdict_reussite")
		await create_timer(2.5).timeout
		jeu.call("_reagir_au_verdict", {"die": 4, "total": 6, "dc": 12, "margin": -6}, "echec")
		await create_timer(0.6).timeout
		await _capturer("verdict_echec")
		await create_timer(2.5).timeout
	root.get_node("/root/MerlinTransition").change_scene("res://scenes/MerlinEnd.tscn", "", "bas")
	await create_timer(0.55).timeout
	await _capturer("encre_vers_la_fin")
	await create_timer(4.0).timeout
	await _capturer("ecran_de_fin")
	print("[TRANS] %s" % ("SONDE PASSÉE" if en_jeu else "SONDE ÉCHOUÉE"))
	quit(0 if en_jeu else 1)


func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		return
	var chemin: String = "%s%s.png" % [_out, nom]
	if img.save_png(chemin) == OK:
		print("[TRANS] %s" % chemin)
