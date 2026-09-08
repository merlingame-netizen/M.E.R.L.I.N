extends SceneTree
## Capture Merlin au menu dans ses quatre postures et ses six humeurs, pour le juger sur pièce.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_merlin_capture.gd
##
## Elle ne juge rien : elle rend des images. La pose est interpolée, on attend qu'elle soit prise.

const POSES: Array = [["attente", "neutral"], ["pensee", "doute"], ["verdict", "surprise"],
	["revelation", "gravite"], ["attente", "malice"], ["attente", "angry"]]

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
	var menu: Node = current_scene
	var art: Variant = menu.get("_scene_art") if menu != null else null
	if art == null:
		printerr("[MERLIN] pas de décor au menu")
		quit(1)
		return
	for p in POSES:
		(art as Node).call("set_posture", str(p[0]))
		(art as Node).call("set_eye_mood", str(p[1]))
		await create_timer(1.6).timeout   # la pose glisse à 2,2/s : prise aux neuf dixièmes
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img == null:
			continue
		# On ne garde que le cadre de Merlin : la moitié droite, au-dessus du bord bas.
		var w: int = img.get_width()
		var h: int = img.get_height()
		var cadre: Image = img.get_region(Rect2i(int(w * 0.50), int(h * 0.12), int(w * 0.48), int(h * 0.62)))
		var chemin: String = "%smerlin_%s_%s.png" % [_out, str(p[0]), str(p[1])]
		if cadre.save_png(chemin) == OK:
			print("[MERLIN] %s posture=%s humeur=%s" % [chemin, (art as Node).call("posture"), str(p[1])])
	quit(0)
