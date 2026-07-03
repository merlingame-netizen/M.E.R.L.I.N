extends SceneTree
## Autoplay UI (v10.13 Phase P) — joue N runs COMPLETS dans la vraie scène, LLM ON :
## intro → Accepter → chaque beat : composer le combo → résoudre (fusion + sustain) → avancer
## (+ draft pris/passé en alternance) → MerlinEnd. PREUVE scène du « 100% fiable » : chaque run
## atteint MerlinEnd sans erreur script (grep côté CLI). Lancer NON-headless (rendu réel).
##   Godot --path . --script res://tools/autoplay_run.gd -- --loops=3
## Sortie : [AUTOPLAY] ... + « [AUTOPLAY] DONE — k/n PASS » ; exit 1 si échec.

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const RUN_DEADLINE_S: float = 480.0   # budget par run (v10.14 : chaîne jusqu'à 15 beats × fusion+sustain)
const END_DEADLINE_S: float = 25.0    # bascule run_ended → MerlinEnd (fade + change_scene différé)

var _fail: int = 0


func _init() -> void:
	_main()


func _main() -> void:
	var loops: int = 3
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--loops="):
			loops = maxi(1, int(s.trim_prefix("--loops=")))
	await process_frame
	# Anti-flake (2026-06-30) : fermer la fenêtre = quit(0) silencieux SANS ligne DONE → gate 0/N alors que
	# le harnais tournait. Titre explicite + fenêtre MINIMISÉE (sauf capture : la minimisation suspend le
	# rendu → viewport noir, or MERLIN_CAPTURE_DIR a besoin des frames réelles).
	DisplayServer.window_set_title("MERLIN AUTOPLAY (test R109) — NE PAS FERMER")
	if not OS.has_environment("MERLIN_CAPTURE_DIR"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	print("[AUTOPLAY] start — loops=%d" % loops)
	# Préserve la sauvegarde RÉELLE du joueur (review HIGH) : le harness écrit/efface
	# user://merlin_run.json — on snapshot avant, on restaure après (même en échec).
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""
	for k in loops:
		var ok: bool = await _play_one(k)
		if not ok:
			_fail += 1
		await create_timer(1.5).timeout  # settle entre les runs (fade de fin, frees différés)
	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
			print("[AUTOPLAY] sauvegarde joueur restaurée")
	print("[AUTOPLAY] DONE — %d/%d PASS" % [loops - _fail, loops])
	quit(1 if _fail > 0 else 0)


func _play_one(k: int) -> bool:
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		print("[AUTOPLAY] FAIL run#%d — autoloads absents" % k)
		return false
	# Nouveau run propre (même chemin que MerlinSelection._on_pick).
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Autoplay #%d" % k, "Le sentier se referme derrière le Voyageur.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file(GAME_SCENE)
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		print("[AUTOPLAY] FAIL run#%d — MerlinGame non chargée" % k)
		return false

	# Intro : attendre le pop-up puis Accepter.
	if not await _until(func() -> bool: return not is_instance_valid(game) or game._intro_open, 12.0):
		print("[AUTOPLAY] FAIL run#%d — intro jamais ouverte" % k)
		return false
	if is_instance_valid(game) and game._intro_open:
		game._accept_quest()
		print("[AUTOPLAY] run#%d — quête acceptée" % k)

	# Boucle maîtresse pilotée par l'état — gère beats, fusion, draft, fin.
	var take_draft: bool = (k % 2 == 0)  # alterne prendre/passer le draft entre les runs
	var dl: int = Time.get_ticks_msec() + int(RUN_DEADLINE_S * 1000.0)
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game):
			break  # scène libérée → bascule vers MerlinEnd en cours
		if run.ended:
			break
		# v10.13 (B3) — Interstitiel « Merlin raconte » (entre Accept et Beat 1) : skip de
		# l'attente animée (WaitStage), du typewriter, puis avance vers le Beat 1.
		if game._interstitial_open:
			if game._interstitial_wait != null and is_instance_valid(game._interstitial_wait):
				game._interstitial_wait._skipped = true  # clic simulé sur le WaitStage
			elif game._tw != null and game._tw.is_valid():
				game._skip_typewriter()
			elif game._can_advance:
				game._end_interstitial()
				print("[AUTOPLAY] run#%d — interstitiel passé" % k)
			await process_frame
			continue
		# Modal draft ouvert ? Choisir ou passer.
		if game._draft_layer != null:
			await create_timer(0.4).timeout
			if is_instance_valid(game) and game._draft_layer != null:
				var cv: Node = _find_card_view(game._draft_layer)
				if take_draft and cv != null:
					game._on_draft_card(cv.card)
					print("[AUTOPLAY] run#%d — draft pris : %s" % [k, cv.card.card_name])
				else:
					game._on_draft_skip()
					print("[AUTOPLAY] run#%d — draft passé" % k)
			await process_frame
			continue
		# Typewriter en cours ? On le saute (accélère sans changer la logique).
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
			await process_frame
			continue
		if game._state == 1:
			# Phase de choix : poser 2 cartes puis résoudre.
			if game._hand_box != null and game._hand_box.visible and run.hand.size() >= 2:
				if game._combo.size() < 2:
					game._on_hand_card(run.hand[game._combo.size()])
				else:
					# Fire-and-forget VOLONTAIRE (fix 2026-06-30) : si la run se TERMINE pendant la fusion
					# (mort/corruption mid-resolve), la scène est libérée et la coroutine _on_resolve meurt —
					# un await ici ne reprend JAMAIS → boucle maîtresse suspendue AU-DELÀ de son deadline
					# (le while ne re-checke qu'entre itérations). Sans await, la boucle garde la main :
					# _state==2 pendant la résolution → aucune branche ne re-déclenche (pas de double-resolve).
					game._on_resolve()
		elif game._state == 2 and game._can_advance:
			# VOLONTAIREMENT fire-and-forget : _advance_to_next() attend le modal de draft, que
			# CETTE boucle doit servir (_on_draft_card/_on_draft_skip) → un await ici = deadlock.
			# Sûr : _can_advance repasse à false AVANT le 1er await de _advance_to_next.
			game._advance_to_next()
		await process_frame

	# Fin de run : on doit arriver sur MerlinEnd.
	var ok_end: bool = await _until(func() -> bool:
		return current_scene != null and str(current_scene.name) == "MerlinEnd", END_DEADLINE_S)
	if not ok_end:
		print("[AUTOPLAY] FAIL run#%d — MerlinEnd jamais atteint (ended=%s beat=%d)" % [
			k, str(run.ended), run.beat_index])
		return false
	print("[AUTOPLAY] run#%d PASS — fin '%s' (PV=%d Corr=%d beats=%d)" % [
		k, run.end_type, run.integrite, run.corruption, run.beat_index])
	run.clear_save()
	return true


func _until(pred: Callable, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return pred.call()


# Duck-typing VOLONTAIRE (aucune référence statique MerlinCardView) : une réf class_name ici tire
# merlin_card_view.gd dans la chaîne de compilation du harnais, qui compile AVANT l'enregistrement des
# autoloads en mode --script → « Identifier not found: MerlinAudio » (cassait tout l'autoplay, fix 2026-06-30).
func _find_card_view(node: Node) -> Node:
	if node.has_method("deal_in") and node.get("card") != null:
		return node
	for ch in node.get_children():
		var f: Node = _find_card_view(ch)
		if f != null:
			return f
	return null
