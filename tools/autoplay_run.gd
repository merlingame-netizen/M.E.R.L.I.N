extends SceneTree
## Autoplay UI (v10.13 Phase P, réécrit v11-W2 pivot ACTION+TRAIT) — joue N runs COMPLETS dans la
## vraie scène, LLM ON : intro → Accepter → chaque beat : 1 TUILE d'action + 1 TRAIT (combos variés,
## compteur croissant) → Résoudre (fusion + sustain) → avancer (+ draft pris/passé en alternance,
## + Encaisser/Pousser tranché) → MerlinEnd. PREUVE scène du « 100% fiable » : chaque run atteint
## MerlinEnd sans erreur script (grep côté CLI). Lancer NON-headless (rendu réel).
##   Godot --path . --script res://tools/autoplay_run.gd -- --loops=3
## Sortie : [AUTOPLAY] ... + « [AUTOPLAY] DONE — k/n PASS » ; exit 1 si échec.

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const RUN_DEADLINE_S: float = 960.0   # budget par run (v10.22 : chaînes 11-15 beats × fusion+sustain + cache-miss
                                      # LLM — 480 s faisait FAIL des runs SAINS → 600). v1.0-V4a : morts 36,6→4,6 %
                                      # ⇒ les chaînes 3 quêtes vont désormais AU BOUT (12-15 beats + drafts garantis) ;
                                      # 600 s re-faisait FAIL un run SAIN au beat 8 (0 SCRIPT ERROR, mesuré 2×) → 960.
const END_DEADLINE_S: float = 25.0    # bascule run_ended → MerlinEnd (fade + change_scene différé)

var _fail: int = 0
var _pick: int = 0  # v11-W2 : compteur CROISSANT (jamais remis à zéro) → l'action tourne sur les
                    # 4 verbes et le trait balaie la main — les combos varient entre beats ET runs.


func _init() -> void:
	_main()


var _slow_s: float = 0.0  # --slow=2.5 : temps de pause sur l'ISSUE écrite avant d'avancer (QA visuelle/captures)


func _main() -> void:
	var loops: int = 3
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--loops="):
			loops = maxi(1, int(s.trim_prefix("--loops=")))
		elif s.begins_with("--slow="):
			_slow_s = maxf(0.0, float(s.trim_prefix("--slow=")))
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
	# --slow ajoute ~N s de pause PAR BEAT (jusqu'à 15 beats) → deadline étendu d'autant (QA 2026-06-30 :
	# un run capture --slow=3 a dépassé les 480 s et FAIL alors que le jeu était sain).
	var dl: int = Time.get_ticks_msec() + int((RUN_DEADLINE_S + _slow_s * 20.0) * 1000.0)
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game):
			break  # scène libérée → bascule vers MerlinEnd en cours
		if run.ended:
			break
		# v10.13 (B3) / v11-V2b — Interstitiel « Merlin raconte » (entre Accept et Beat 1) : skip du
		# typewriter, avance vers le Beat 1 ; l'attente LLM vit désormais DANS l'encart (plus de
		# WaitStage plein écran) → clic simulé via le flag _interstitial_skip.
		if game._interstitial_open:
			if game._tw != null and game._tw.is_valid():
				game._skip_typewriter()
			elif game._can_advance:
				game._end_interstitial()
				print("[AUTOPLAY] run#%d — interstitiel passé" % k)
			else:
				game._interstitial_skip = true  # attente inline (encart) → clic simulé (fallback servi)
			await process_frame
			continue
		# Draft ouvert (v11-W3 : il sert des GREFFES, 2 gestes) ? Choisir la greffe PUIS cliquer une
		# tuile ÉLIGIBLE (grafts.size() < 3) — ou passer. Duck-typing pur : un renommage côté jeu
		# casse BRUYAMMENT (gate 0/N), jamais de faux vert.
		if game._draft_active:
			await create_timer(0.4).timeout
			if is_instance_valid(game) and game._draft_active:
				var cv: Node = _find_card_view(game._hand_box)
				if take_draft and cv != null:
					game._on_draft_card(cv.card)
					# Sélection rejetée par la garde anti-pick-aveugle (500 ms) ? Re-servi au tour
					# suivant de la boucle maîtresse — on ne loggue que les gestes RÉELS.
					if not (game._pending_graft as Dictionary).is_empty():
						print("[AUTOPLAY] run#%d — greffe choisie : %s" % [k, cv.card.card_name])
						# 2e geste : la tuile cible (première action éligible, duck-typé).
						await create_timer(0.3).timeout
						if is_instance_valid(game) and game._draft_active:
							var acts: Array = run.actions
							for a in acts:
								if (a.get("grafts") as Array).size() < int(run.MAX_GRAFTS_PER_ACTION):
									game._on_action_tile(a)
									if game._draft_done_flag:
										print("[AUTOPLAY] run#%d — greffe posée sur %s" % [k, str(a.get("card_name"))])
									break
				else:
					game._on_draft_skip()
					if game._draft_done_flag:
						print("[AUTOPLAY] run#%d — draft passé" % k)  # loggé sur geste RÉEL uniquement (garde 500 ms)
			await process_frame
			continue
		# Typewriter en cours ? On le saute (accélère sans changer la logique).
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
			await process_frame
			continue
		# v10.21 (R131) — PACTE d'intervention (Être/Compagnon) ouvert ? Trancher pour avancer.
		# Branche MANQUANTE jusqu'ici : sans elle, un pacte = spin jusqu'au deadline (les gates
		# verts passés tenaient au tirage de pilier — 60 % de bénédictions non-bloquantes).
		# On clique le BOUTON (fidèle au joueur), alterné Accepter/Refuser par run.
		if game._pact_row != null and is_instance_valid(game._pact_row):
			await create_timer(0.3).timeout
			if is_instance_valid(game) and game._pact_row != null and is_instance_valid(game._pact_row):
				var pact_btns: Array = []
				for pb in game._pact_row.get_children():
					if pb is Button:
						pact_btns.append(pb)
				if not pact_btns.is_empty():
					var pbi: int = k % pact_btns.size()
					(pact_btns[pbi] as Button).pressed.emit()
					print("[AUTOPLAY] run#%d — pacte bouton %d cliqué" % [k, pbi])
			await process_frame
			continue
		# v10.21 (R130) — choix « Encaisser / Pousser » pendant ? Trancher (alterné par run) pour avancer.
		if game._push_pending and game._push_row != null:
			await create_timer(0.3).timeout
			if is_instance_valid(game) and game._push_pending:
				game._on_push_choice(k % 2 == 0)
				print("[AUTOPLAY] run#%d — partiel %s" % [k, "poussé" if k % 2 == 0 else "encaissé"])
			await process_frame
			continue
		if game._state == 1:
			# v11-W2 — phase de choix : 1 TUILE d'action + 1 TRAIT, puis Résoudre. Duck-typing pur
			# (accès propriétés/méthodes sur Node) : un renommage côté jeu = erreur runtime BRUYANTE
			# (gate 0/N), jamais de faux vert silencieux.
			if game._choice_open and (run.hand as Array).size() >= 1:
				var acts: Array = run.actions
				if game._selected_action == null and not acts.is_empty():
					game._on_action_tile(acts[_pick % acts.size()])
				elif game._selected_trait == null:
					game._on_trait_card(run.hand[_pick % (run.hand as Array).size()])
					_pick += 1  # combo suivant : action ET trait décalés (k croissant)
				else:
					# Fire-and-forget VOLONTAIRE (fix 2026-06-30) : si la run se TERMINE pendant la fusion
					# (mort/corruption mid-resolve), la scène est libérée et la coroutine _on_resolve meurt —
					# un await ici ne reprend JAMAIS → boucle maîtresse suspendue AU-DELÀ de son deadline
					# (le while ne re-checke qu'entre itérations). Sans await, la boucle garde la main :
					# _state==2 pendant la résolution → aucune branche ne re-déclenche (pas de double-resolve).
					game._on_resolve()
		elif game._state == 2 and game._can_advance:
			# --slow : pause bornée sur l'ISSUE écrite (résolution même-fil + vignette visibles → captures QA).
			if _slow_s > 0.0:
				await create_timer(_slow_s).timeout
				if not is_instance_valid(game) or run.ended:
					continue
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
