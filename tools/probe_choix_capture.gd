extends SceneTree
## Capture l'écran du beat « choix » sur un sentier écrit, pour le juger sur pièce.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_choix_capture.gd
##
## POURQUOI UNE SONDE ET PAS UN SMOKE. Le beat « choix » ne s'atteint qu'au cinquième beat d'une
## quête écrite : y arriver en jouant demanderait le moteur, le modèle et cinq résolutions. On
## charge le sentier, on pose l'index sur le beat voulu, et `_begin` présente ce beat-là
## directement (run.beat_index != 0 → `_present_current_beat`, sans l'intro). Aucun appel au
## modèle : la prose du sentier est déjà écrite.
##
## Elle ne juge rien. Elle rend des images, et c'est Maxime qui juge.

const BEATS: Array = [5, 8, 6]   # les deux choix, puis un beat ordinaire pour comparer

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
	var sentier: String = OS.get_environment("MERLIN_SENTIER")
	if sentier == "":
		sentier = "le_compte_juste"
	var s: Dictionary = MerlinSentier.charger(sentier)
	if s.is_empty():
		printerr("[CAP] sentier introuvable : %s" % sentier)
		quit(1)
		return
	for n in BEATS:
		await _capturer(s, int(n))
	print("[CAP] fini — images dans %s" % _out)
	quit(0)


func _capturer(s: Dictionary, n: int) -> void:
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	if run == null:
		printerr("[CAP] MerlinRun absent (autoloads non montés ?)")
		return
	run.new_run(s)
	# L'INDEX EST À BASE ZÉRO : le beat 5 de la quête est l'index 4. Le poser AVANT de charger la
	# scène est ce qui fait sauter l'intro — `_begin` ne présente le popup que sur un index à 0.
	run.beat_index = maxi(0, n - 1)
	change_scene_to_file("res://scenes/MerlinGame.tscn")
	await create_timer(9.0).timeout   # le typewriter finit sa phrase avant qu'on juge
	var jeu: Node = current_scene
	if jeu != null:
		var hb: Variant = jeu.get("_hand_box")
		var ab: Variant = jeu.get("_action_bar")
		if hb != null:
			print("[CAP] zone de la main : %s" % str((hb as Control).get_global_rect()))
		if ab != null:
			print("[CAP] rangée des tuiles : %s" % str((ab as Control).get_global_rect()))
	var beat: Dictionary = run.current_beat()
	print("[CAP] beat %d — type=%s choix=%s lieu=%s" % [n, str(beat.get("type", "?")),
		str(MerlinSentier.est_un_choix(beat)), str(beat.get("lieu", ""))])
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("[CAP] pas d'image pour le beat %d (rendu absent ?)" % n)
		return
	var chemin: String = "%sbeat_%02d_%s.png" % [_out, n,
		"choix" if MerlinSentier.est_un_choix(beat) else "ordinaire"]
	if img.save_png(chemin) != OK:
		printerr("[CAP] écriture refusée : %s" % chemin)
		return
	print("[CAP] %s (%dx%d)" % [chemin, img.get_width(), img.get_height()])
