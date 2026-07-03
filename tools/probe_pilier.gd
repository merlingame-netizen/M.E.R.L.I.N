extends SceneTree
## Sonde QA v10.21 — rend le décor PLEIN ÉCRAN avec chaque silhouette de PILIER matérialisée et
## sauve 1 PNG par pilier dans MERLIN_CAPTURE_DIR (ou user://). Lancer FENÊTRÉ (rendu réel) :
##   Godot --path . --script res://tools/probe_pilier.gd
## Duck-typing VOLONTAIRE : load() runtime, ZÉRO référence class_name (compile-order --script, cf. KB).

const PILIERS: Array = ["choeur", "etre", "chevalier", "compagnon", "enfant"]


func _init() -> void:
	_main()


func _main() -> void:
	await process_frame
	var out_dir: String = OS.get_environment("MERLIN_CAPTURE_DIR")
	if out_dir.is_empty():
		out_dir = "user://"
	var art_script: GDScript = load("res://scripts/game/merlin_scene_art.gd")
	var art: Control = art_script.new()
	root.add_child(art)
	art.size = root.get_visible_rect().size
	art.set_animated(true)
	art.set_time_of_day(22)
	art.set_season("ete")
	art.set_decor_reveal(1.0)
	for pk in PILIERS:
		# Teinte de faction cohérente avec le pilier (l'Enfant garde la teinte courante — wildcard).
		match str(pk):
			"choeur": art.set_faction("druides")
			"etre": art.set_faction("creatures")
			"chevalier": art.set_faction("chevalerie")
			"compagnon": art.set_faction("corrompus")
		art.set_pilier(str(pk), true)
		for i in 70:  # ~1.2 s : matérialisation complète (1.0 s) + marge
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("pilier_%s.png" % pk))
		print("[PROBE] pilier_%s.png sauve" % pk)
		art.set_pilier("", false)
		for i in 45:
			await process_frame
	print("[PROBE] DONE")
	quit(0)
