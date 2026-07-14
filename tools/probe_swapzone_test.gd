extends SceneTree
## probe_swapzone_test.gd (R159) — self-test MECANISME de MerlinVisual.swap_zone : un swap relance
## TUE le tween precedent ; son `build` (qui repose le contenu ET pose l'etat critique du beat :
## _beat_transition=false, _state=1) ne doit JAMAIS etre perdu (classe de bug R148). Reproduit et
## verifie le fix. Headless.  Godot --headless --path . --script res://tools/probe_swapzone_test.gd
const _Visual: GDScript = preload("res://scripts/game/merlin_visual.gd")


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	MerlinVisual.reduced_motion = false  # timing reel des tweens (fade-out 0.18 s) — ecriture via class_name (pas le preload const : Parse Error)
	var host: Control = Control.new()
	root.add_child(host)
	var zone: Control = Control.new()
	zone.size = Vector2(120, 120)
	host.add_child(zone)
	await process_frame

	var ran: Dictionary = {"a": false, "b": false}
	# Swap A puis IMMEDIATEMENT swap B (dans la fenetre de fade-out 0.18 s) sur la MEME zone :
	# B tue le tween de A avant que le callback de A n'ait pu s'executer.
	_Visual.swap_zone(zone, func() -> void: ran["a"] = true)
	_Visual.swap_zone(zone, func() -> void: ran["b"] = true)

	var dl: int = Time.get_ticks_msec() + 1500  # laisse les tweens finir
	while Time.get_ticks_msec() < dl:
		await process_frame

	var ok: bool = bool(ran["a"]) and bool(ran["b"])
	print("[SWAPTEST] build_A_ran=%s build_B_ran=%s -> %s" % [
		str(ran["a"]), str(ran["b"]), "PASS (aucun build perdu)" if ok else "FAIL (build A PERDU : bug R148)"])
	quit(0 if ok else 1)
