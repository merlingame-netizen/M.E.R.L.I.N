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
	# v10.13 (B3) : l'interstitiel « Merlin raconte » s'ouvre après l'Accept — on le CAPTURE
	# (preuve visuelle) puis on le traverse comme un joueur (skip WaitStage + typewriter + clic).
	await create_timer(1.2).timeout
	await _cap("vp_2a_interstitiel")
	if game != null and "_interstitial_open" in game and game._interstitial_open:
		if game._interstitial_wait != null:
			game._interstitial_wait._skipped = true  # clic simulé sur l'attente animée
			await create_timer(0.5).timeout
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
		await create_timer(0.3).timeout
		await _cap("vp_2b_interstitiel_texte")
		if game.has_method("_end_interstitial"):
			game._end_interstitial()
			print("[VP] interstitiel traversé")
	await create_timer(0.8).timeout
	await _cap("vp_2_situation")  # situation dans l'encart (typewriter en cours) + stamp glyphe B4
	await create_timer(5.5).timeout
	await _cap("vp_3_cards")  # typewriter fini → cartes montées pour le choix
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	if run != null and "hand" in run:
		print("[VP] run.hand = %d cartes" % (run.hand as Array).size())
	if game != null and "_hand_box" in game and game._hand_box != null:
		print("[VP] _hand_box visible=%s children=%d size=%s" % [str(game._hand_box.visible), game._hand_box.get_child_count(), str(game._hand_box.size)])
	# v10.12 — drive un beat complet : combo (2 cartes) → résolution → fusion → issue.
	if game != null and run != null and (run.hand as Array).size() >= 2 and game.has_method("_on_hand_card"):
		game._on_hand_card(run.hand[0])
		game._on_hand_card(run.hand[1])
		print("[VP] combo composé (2 cartes)")
		await create_timer(0.9).timeout
		await _cap("vp_4_combo")
		if game.has_method("_on_resolve"):
			game._on_resolve()  # coroutine : fusion + sustain + issue (on capture pendant)
			print("[VP] _on_resolve lancé")
		await create_timer(1.4).timeout
		await _cap("vp_5_fusion_a")
		await create_timer(2.2).timeout
		await _cap("vp_5_fusion_b")
		await create_timer(3.0).timeout
		await _cap("vp_5_fusion_c")
		await create_timer(5.0).timeout
		await _cap("vp_5d_sustain")        # attente ANIMÉE (caption « Merlin tisse… » + glow + sparks)
		await create_timer(16.0).timeout   # > cap sustain 20s total → l'issue s'affiche (LLM ou filet)
		await _cap("vp_6_resolution")
		print("[VP] post-résolution : integrite=%d corruption=%d beat=%d" % [run.integrite, run.corruption, run.beat_index])
	quit()
