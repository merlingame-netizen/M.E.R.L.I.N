extends SceneTree
## Capture des 4 paliers de glitch Corruption (R75) — preuve visuelle v10.13.1.
## Force corruption 0/5/10/15 via _on_gauges puis capture le viewport (pattern
## capture_game_viewport.gd). Lancer NON-headless (fenêtré) pour un vrai rendu :
##   Godot_v4.5.1-stable_win64_console.exe --path . --script res://tools/capture_glitch_paliers.gd

const OUT := "C:/Users/PGNK2128/Downloads/"
const PALIERS := [0, 5, 10, 15]


func _init() -> void:
	_run()


func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img != null:
		img.save_png(OUT + nm + ".png")
		print("[GLITCH] saved %s (%dx%d)" % [nm, img.get_width(), img.get_height()])
	else:
		print("[GLITCH] null image for %s" % nm)


func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/MerlinGame.tscn")
	await create_timer(1.4).timeout  # _ready/_begin → intro
	var game: Node = current_scene
	if game == null:
		print("[GLITCH] scene introuvable")
		quit(1)
		return
	if game.has_method("_accept_quest"):
		game._accept_quest()
	await create_timer(1.0).timeout
	# Traverse l'interstitiel « le récit s'ouvre » comme un joueur (skip + avance).
	if "_interstitial_open" in game and game._interstitial_open:
		if game.get("_interstitial_skip") != null:
			game._interstitial_skip = true  # v11-V2b : attente inline (plus de WaitStage) — skip vivant
			await create_timer(0.5).timeout
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
		if game.has_method("_end_interstitial"):
			game._end_interstitial()
	await create_timer(1.5).timeout  # voile + situation posée
	for lvl in PALIERS:
		game._on_gauges(8, int(lvl))   # force le palier (déclenche _update_corruption_fx)
		await create_timer(1.3).timeout  # burst (0.5s) + tween palier (0.8s) terminés
		await _cap("glitch_palier_%02d" % int(lvl))
	print("[GLITCH] done")
	quit(0)
