extends SceneTree
## Capture FIABLE côté Godot (viewport interne, SANS Win32/focus) du flow MerlinGame :
## intro → Accepter → situation (encart central) → cartes montées. (user 2026-06-06 "2 capture")
## Lancer NON-headless (fenêtré) pour un vrai rendu :
##   "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --path . --script res://tools/capture_game_viewport.gd

const OUT := "C:/Users/PGNK2128/Downloads/"


func _init() -> void:
	_run()


func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(OUT + nm + ".png")
		print("[VP] saved %s (%dx%d)" % [nm, img.get_width(), img.get_height()])
	else:
		print("[VP] null image for %s" % nm)


func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/MerlinGame.tscn")
	await create_timer(1.4).timeout  # laisse _ready/_begin afficher l'intro
	await _cap("vp_1_intro")
	var game: Node = current_scene
	if game != null and game.has_method("_accept_quest"):
		game._accept_quest()
		print("[VP] _accept_quest appelé")
	else:
		print("[VP] _accept_quest introuvable")
	await create_timer(0.8).timeout
	await _cap("vp_2_situation")  # situation dans l'encart (typewriter en cours), cartes encore cachées
	await create_timer(5.5).timeout
	await _cap("vp_3_cards")  # typewriter fini → cartes montées pour le choix
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	if run != null and "hand" in run:
		print("[VP] run.hand = %d cartes" % (run.hand as Array).size())
	if game != null and "_hand_box" in game and game._hand_box != null:
		print("[VP] _hand_box visible=%s children=%d size=%s" % [str(game._hand_box.visible), game._hand_box.get_child_count(), str(game._hand_box.size)])
	quit()
