extends SceneTree
## probe_dice_capture.gd : SONDE JETABLE N4-P1 (chantier 2/7) : capture le d20 seul sur fond
## sombre, aux temps de la nouvelle sequence pose -> pause 0,35 s -> verdict :
##   d20_tumble / d20_pose_pause_neutre (halo ENCORE neutre : rien ne spoile)
##   d20_halo_vert_renforce (halo renforce, pulses) / d20_halo_gold_* (eclatante prolongee)
## Lancer NON-headless (rendu reel) :
##   Godot --path . --script res://tools/probe_dice_capture.gd
## Sortie : output/captures/bugres/dice_p1/*.png + lignes [DICEQA]. Ne touche pas a la save.
## DUCK-TYPING OBLIGATOIRE (regle probes) : zero identifiant class_name du jeu au parse :
## en mode --script les autoloads (MerlinAudio...) ne sont pas resolus a la COMPILATION du
## script de sonde ; les scripts du jeu se chargent via load() au RUNTIME (autoloads prets).

const OUT_DIR: String = "res://output/captures/bugres/dice_p1/"


func _init() -> void:
	_run()


func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("[DICEQA] %s : image nulle" % nm)
		return
	var err: int = img.save_png(OUT_DIR + nm + ".png")
	print("[DICEQA] capture %s err=%d" % [nm, err])


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var vis: GDScript = load("res://scripts/game/merlin_visual.gd")
	var dice_scr: GDScript = load("res://scripts/game/merlin_dice.gd")
	if vis == null or dice_scr == null:
		print("[DICEQA] scripts du jeu introuvables")
		quit(1)
		return
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = vis.BG_PAGE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	root.add_child(host)
	host.size = root.get_visible_rect().size
	await process_frame

	# --- Jet 1 : reussite (halo VERT renforce). Reperes temporels de merlin_dice.gd :
	# tumble+slow 0,75 s -> settle 0,25 s -> pose ; pause 0,35 s ; halo (0,18 s + pulses).
	var d1: Control = dice_scr.roll(host, 17, true)
	await create_timer(0.85).timeout   # fin de culbute, pose imminente
	await _cap("d20_tumble")
	await create_timer(0.35).timeout   # ~1,20 s : face posee, DANS la micro-pause (halo neutre)
	await _cap("d20_pose_pause_neutre")
	await create_timer(0.55).timeout   # ~1,75 s : halo verdict monte + pulse 1
	await _cap("d20_halo_vert_renforce")
	# (pas de `await done` : le signal a pu etre deja emis, et le d20 s'auto-libere ; timers fixes.)
	if d1 != null:
		pass
	await create_timer(2.2).timeout    # pulses + fondu s'achevent, le d20 se libere seul

	# --- Jet 2 : eclatante (halo GOLD prolonge, chantier 7).
	var d2: Control = dice_scr.roll(host, 20, true, true)
	await create_timer(1.75).timeout
	await _cap("d20_halo_gold_eclatante")
	await create_timer(1.0).timeout    # tenue prolongee BRILLIANT_HOLD_S : halo encore visible
	await _cap("d20_halo_gold_prolonge")
	if d2 != null:
		pass
	await create_timer(1.5).timeout
	print("[DICEQA] DONE")
	quit(0)
