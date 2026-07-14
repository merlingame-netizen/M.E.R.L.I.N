extends SceneTree
## probe_bugres_bootcheck.gd — SONDE JETABLE (diag bug 1re résolution) : mesure du FLAKE de
## compilation au boot. Reproduit le chemin minimal MerlinSelection._on_pick → new_run et vérifie
## l'intégrité de MerlinCard (make_actions → 4 tuiles). Un boot où merlin_card.gd a mal compilé
## (« Static function pattern_for_tag() not found in base MerlinGlyph ») donne actions=0 → FAIL.
##   Godot --path . --script res://tools/probe_bugres_bootcheck.gd
## Sortie : [BOOTCHECK] OK|FAIL ... ; exit 0/1. Ne touche pas à la save joueur (snapshot/restore).

func _init() -> void:
	_main()


func _main() -> void:
	await process_frame
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""

	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	var ok: bool = true
	var detail: String = ""
	if run == null or sc == null:
		ok = false
		detail = "autoloads absents"
	elif run.get_script() == null:
		ok = false
		detail = "MerlinRun sans script (compilation autoload échouée)"
	else:
		var skel: Dictionary = sc.build_skeleton("Bootcheck", "Le sentier se referme.")
		run.new_run(skel)
		var n_act: int = (run.get("actions") as Array).size()
		var n_hand: int = (run.get("hand") as Array).size()
		var n_deck: int = (run.get("deck") as Array).size()
		detail = "actions=%d hand=%d deck=%d" % [n_act, n_hand, n_deck]
		if n_act != 5 or n_hand < 2:  # R158 : 5 actions a icones
			ok = false

	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
	elif run != null and run.has_method("clear_save"):
		run.clear_save()

	print("[BOOTCHECK] %s — %s" % ["OK" if ok else "FAIL", detail])
	quit(0 if ok else 1)
