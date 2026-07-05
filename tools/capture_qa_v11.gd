extends SceneTree
## Capture QA v11 (tâche #45 phase 1) — 8 phases × 1 biome par lancement, pour la fleet QA
## « agents humains ». Réutilise les patterns éprouvés de capture_game_viewport.gd (capture
## viewport interne après frame_post_draw) et autoplay_run.gd (pilotage UI duck-typé).
## Lancer NON-headless (fenêtré, rendu réel), une fois PAR biome :
##   MERLIN_BIOME=foret    "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --path . --script res://tools/capture_qa_v11.gd
##   MERLIN_BIOME=falaises "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --path . --script res://tools/capture_qa_v11.gd
## Sortie : output/captures/qa_v11/<biome>/ph<N>_<slug>.png + lignes [QA] (anomalies préfixées
## [QA][ANOMALIE] — matière du manifest). RÈGLE : duck-typing OBLIGATOIRE sur la scène de jeu
## (has_method / get / in) — un renommage côté jeu casse BRUYAMMENT au runtime, jamais au parse.

const OUT_ROOT: String = "res://output/captures/qa_v11/"
const GLOBAL_DEADLINE_S: float = 240.0  # budget TOTAL par biome (consigne tâche #45)
const BEAT_WAIT_S: float = 45.0         # au-delà : capture de l'état d'attente TEL QUEL (donnée QA)

var _biome: String = "foret"
var _dir: String = ""
var _t0: int = 0
var _anoms: PackedStringArray = []
var _saved: int = 0


func _init() -> void:
	_run()


# ---------------------------------------------------------------- helpers


func _left() -> float:
	return GLOBAL_DEADLINE_S - float(Time.get_ticks_msec() - _t0) / 1000.0


func _note(msg: String) -> void:
	_anoms.append(msg)
	print("[QA][ANOMALIE] " + msg)


# Attente bornée par le prédicat ET la deadline globale (pattern autoplay_run.gd).
func _until(pred: Callable, timeout_s: float) -> bool:
	var budget: float = minf(timeout_s, maxf(_left(), 0.0))
	var dl: int = Time.get_ticks_msec() + int(budget * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return bool(pred.call())


# Capture FIABLE côté Godot (viewport interne, sans Win32/focus) — capture_game_viewport.gd.
func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		_note("%s : image nulle (viewport non rendu ?)" % nm)
		return
	var path: String = _dir + nm + ".png"
	var err: int = img.save_png(path)
	if err == OK:
		_saved += 1
		print("[QA] capture %s (%dx%d) -> %s" % [nm, img.get_width(), img.get_height(), path])
	else:
		_note("%s : save_png a échoué (err=%d) vers %s" % [nm, err, path])


# Typewriter actif ? (duck-typé : _tw peut disparaître/changer côté jeu → false, jamais crash parse)
func _tw_active(game: Node) -> bool:
	if not is_instance_valid(game):
		return false
	var tw_v: Variant = game.get("_tw")
	var tw: Tween = tw_v as Tween
	return tw != null and tw.is_valid()


func _flag(game: Node, prop: String) -> bool:
	if not is_instance_valid(game):
		return false
	return bool(game.get(prop))


# Prédicat ph2 : les 3 parchemins (titre+pitch LLM) sont montés dans _cards_box.
func _parchemins_ready(sel: Node) -> bool:
	if not is_instance_valid(sel):
		return true  # scène partie → ne pas spinner
	var box_v: Variant = sel.get("_cards_box")
	var box: Node = box_v as Node
	return box != null and box.get_child_count() >= 3


# ---------------------------------------------------------------- flow principal


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	_biome = OS.get_environment("MERLIN_BIOME") if OS.has_environment("MERLIN_BIOME") else "foret"
	_dir = ProjectSettings.globalize_path(OUT_ROOT) + _biome + "/"
	var mk: int = DirAccess.make_dir_recursive_absolute(_dir)
	if mk != OK:
		print("[QA] FATAL — mkdir %s err=%d" % [_dir, mk])
		quit(1)
		return
	# Anti-flake autoplay 2026-06-30 : titre explicite, PAS de minimisation (rendu suspendu = noir).
	DisplayServer.window_set_title("MERLIN CAPTURE QA v11 (%s) — NE PAS FERMER" % _biome)
	print("[QA] start — biome=%s dir=%s" % [_biome, _dir])

	# Préserve la sauvegarde RÉELLE du joueur (pattern autoplay_run.gd).
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""

	# ---- ph1 : MerlinMenu (wordmark, boutons) --------------------------------
	change_scene_to_file("res://scenes/MerlinMenu.tscn")
	await create_timer(1.4).timeout
	await _cap("ph1_menu")

	# ---- ph2 : MerlinSelection (3 parchemins titre+pitch, LLM) ---------------
	change_scene_to_file("res://scenes/MerlinSelection.tscn")
	await create_timer(1.3).timeout
	var sel: Node = current_scene
	var ok2: bool = await _until(func() -> bool: return _parchemins_ready(sel), BEAT_WAIT_S)
	if ok2:
		await create_timer(1.0).timeout  # entrée animée des parchemins (pop échelle + fondu)
	else:
		_note("ph2 : parchemins pas montés après %ds — capture de l'état d'attente (overlay)" % int(BEAT_WAIT_S))
	await _cap("ph2_selection")

	# ---- MerlinGame : setup run programmatique (même chemin que MerlinSelection._on_pick,
	# pattern autoplay_run.gd) puis ph3 → ph7 → ph4 → ph5 → ph6 dans l'ordre NATUREL du flow
	# (interstitiel → draft d'ouverture garanti avant beat 1 → situation → combo → résolution).
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null or not run.has_method("new_run") or not sc.has_method("build_skeleton"):
		_note("autoloads MerlinRun/MerlinScenario indisponibles — phases 3 à 7 non capturables")
	else:
		run.clear_save()
		var skel: Dictionary = sc.build_skeleton(
			"Capture QA v11 — %s" % _biome, "Le sentier se referme derrière le Voyageur.")
		run.new_run(skel)
		sc.prepare_arc(skel)
		change_scene_to_file("res://scenes/MerlinGame.tscn")
		await create_timer(1.2).timeout
		var game: Node = current_scene
		if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
			_note("MerlinGame non chargée — phases 3 à 7 non capturables")
		else:
			await _drive_game(game, run)

	# ---- ph8 : MerlinEnd (la scène tient seule — fallback accomplissement) ---
	change_scene_to_file("res://scenes/MerlinEnd.tscn")
	await create_timer(2.0).timeout  # laisse le titre + état final + typewriter d'épilogue démarrer
	await _cap("ph8_end")

	# Restaure la sauvegarde joueur (même en cas d'anomalies) — pattern autoplay_run.gd.
	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
			print("[QA] sauvegarde joueur restaurée")
	elif run != null and run.has_method("clear_save"):
		run.clear_save()  # aucune save avant → on ne laisse pas la save du harnais

	print("[QA] DONE — biome=%s captures=%d anomalies=%d temps=%ds" % [
		_biome, _saved, _anoms.size(), int(float(Time.get_ticks_msec() - _t0) / 1000.0)])
	for a in _anoms:
		print("[QA][RECAP] " + a)
	quit(0)


# Pilote MerlinGame duck-typé : ph3 interstitiel → ph7 draft d'ouverture → ph4 situation
# → ph5 combo (preview R120) → ph6 résolution (pill + vignette + anneaux).
func _drive_game(game: Node, run: Node) -> void:
	# Intro : attendre le pop-up puis Accepter (autoplay : jusqu'à 12 s).
	var ok_intro: bool = await _until(
		func() -> bool: return not is_instance_valid(game) or _flag(game, "_intro_open"), 15.0)
	if not ok_intro:
		_note("intro jamais ouverte — le flow ne démarre pas (phases 3-7 compromises)")
	if is_instance_valid(game) and _flag(game, "_intro_open") and game.has_method("_accept_quest"):
		game._accept_quest()
		print("[QA] quête acceptée")

	# ---- ph3 : interstitiel « Merlin raconte » -------------------------------
	var ok3: bool = await _until(
		func() -> bool: return not is_instance_valid(game) or _flag(game, "_interstitial_open"), 10.0)
	if not ok3:
		_note("ph3 : interstitiel jamais ouvert — capture de l'état courant")
	await create_timer(1.2).timeout  # laisse le texte se poser (typewriter en cours = donnée QA ok)
	await _cap("ph3_interstitiel")

	# Traverser l'interstitiel comme un joueur (pattern autoplay : skip tw → clic attente → avancer).
	var dl_i: int = Time.get_ticks_msec() + int(minf(BEAT_WAIT_S, maxf(_left(), 0.0)) * 1000.0)
	while is_instance_valid(game) and _flag(game, "_interstitial_open") and Time.get_ticks_msec() < dl_i:
		if _tw_active(game) and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		elif _flag(game, "_can_advance") and game.has_method("_end_interstitial"):
			game._end_interstitial()  # fire-and-forget : coroutine (draft d'ouverture DEDANS)
		else:
			game.set("_interstitial_skip", true)  # attente inline (v11-V2b) → clic simulé
		await process_frame
	if is_instance_valid(game) and _flag(game, "_interstitial_open"):
		_note("interstitiel toujours ouvert après %ds — LLM lent ? (donnée QA)" % int(BEAT_WAIT_S))

	# ---- ph7 : draft de greffe d'OUVERTURE (3 choix, 2 gestes, zéro modal) ---
	# Garanti avant le beat 1 (flag opening_draft_done) → il s'ouvre DANS _end_interstitial().
	var ok7: bool = await _until(
		func() -> bool: return not is_instance_valid(game) or _flag(game, "_draft_active"), 20.0)
	if ok7 and is_instance_valid(game) and _flag(game, "_draft_active"):
		await create_timer(0.9).timeout  # montée animée des 3 choix + garde anti-pick-aveugle 500 ms
		await _cap("ph7_draft")
		# Passer le draft (retry : la garde 500 ms peut rejeter le 1er geste — autoplay-style).
		var dl_d: int = Time.get_ticks_msec() + int(minf(12.0, maxf(_left(), 0.0)) * 1000.0)
		while is_instance_valid(game) and _flag(game, "_draft_active") and Time.get_ticks_msec() < dl_d:
			if game.has_method("_on_draft_skip"):
				game._on_draft_skip()
			await create_timer(0.35).timeout
		if is_instance_valid(game) and _flag(game, "_draft_active"):
			_note("ph7 : draft impossible à passer (_on_draft_skip inopérant ?)")
		else:
			print("[QA] draft d'ouverture passé")
	else:
		_note("ph7 : draft d'ouverture jamais ouvert (opening_draft_done ? has_graftable_action ?) — capture de l'état courant")
		await _cap("ph7_draft")

	# ---- ph4 : beat 1 — encart situation + main 4 traits + 4 tuiles + ligne d'état
	var ok4: bool = await _until(
		func() -> bool: return not is_instance_valid(game) or _flag(game, "_choice_open"), BEAT_WAIT_S)
	if not ok4:
		_note("ph4 : choix jamais ouvert après %ds — capture de l'état d'attente (donnée QA)" % int(BEAT_WAIT_S))
	# Texte de situation COMPLET (skip typewriter, borné).
	var dl_t: int = Time.get_ticks_msec() + int(minf(6.0, maxf(_left(), 0.0)) * 1000.0)
	while _tw_active(game) and Time.get_ticks_msec() < dl_t:
		if game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		await process_frame
	await create_timer(0.6).timeout
	await _cap("ph4_situation")
	if is_instance_valid(game) and run != null:
		print("[QA] beat=%d main=%d actions=%d" % [
			int(run.beat_index), (run.hand as Array).size(), (run.actions as Array).size()])

	# ---- ph5 : combo 1 verbe + 1 trait (preview de résolution R120 visible) --
	if is_instance_valid(game) and _flag(game, "_choice_open") and run != null:
		var acts: Array = run.actions
		var hand: Array = run.hand
		if not acts.is_empty() and game.has_method("_on_action_tile"):
			game._on_action_tile(acts[0])
		await create_timer(0.35).timeout
		if is_instance_valid(game) and not hand.is_empty() and game.has_method("_on_trait_card"):
			game._on_trait_card(hand[0])
		await create_timer(0.8).timeout  # _update_preview (R120) + pulse d'armement du bouton
		if is_instance_valid(game) and (game.get("_selected_action") == null or game.get("_selected_trait") == null):
			_note("ph5 : sélection incomplète (action=%s trait=%s) — preview possiblement absente" % [
				str(game.get("_selected_action") != null), str(game.get("_selected_trait") != null)])
	else:
		_note("ph5 : choix non ouvert — combo impossible, capture de l'état courant")
	await _cap("ph5_combo")

	# ---- ph6 : après Résoudre — pill de degré + vignette d'effet + anneaux jauges
	# R130 : sur PARTIEL, le choix Encaisser/Pousser DIFFÈRE pill/vignette/anneaux au degré FINAL
	# (constaté au 1er run foret : _can_advance n'arrive jamais tant que le choix est ouvert).
	# → mini boucle maîtresse (pattern autoplay) : skip tw / pacte R131 / push R130 / _can_advance.
	if is_instance_valid(game) and game.has_method("_on_resolve") \
			and game.get("_selected_action") != null and game.get("_selected_trait") != null:
		game._on_resolve()  # fire-and-forget VOLONTAIRE (pattern autoplay : la scène peut mourir mid-resolve)
		print("[QA] résolution lancée")
		var done6: bool = false
		var dl6: int = Time.get_ticks_msec() + int(minf(BEAT_WAIT_S, maxf(_left(), 0.0)) * 1000.0)
		while Time.get_ticks_msec() < dl6:
			if not is_instance_valid(game) or bool(run.ended):
				_note("ph6 : run terminée pendant la résolution (mort/corruption au beat 1) — capture post-fin")
				break
			if int(game.get("_state")) == 2 and _flag(game, "_can_advance"):
				done6 = true
				break
			if _tw_active(game) and game.has_method("_skip_typewriter"):
				game._skip_typewriter()  # accélère l'écriture de l'issue (fidèle au joueur pressé)
				await process_frame
				continue
			# R131 — pacte d'intervention (Être/Compagnon) : cliquer le 1er bouton pour avancer.
			var pact: Node = game.get("_pact_row") as Node
			if pact != null and is_instance_valid(pact):
				await create_timer(0.3).timeout
				pact = game.get("_pact_row") as Node
				if is_instance_valid(game) and pact != null and is_instance_valid(pact):
					for pb in pact.get_children():
						if pb is Button:
							(pb as Button).pressed.emit()
							print("[QA] pacte R131 tranché (bouton 0)")
							break
				await process_frame
				continue
			# R130 — partiel : Encaisser → le degré FINAL pose pill + vignette + anneaux.
			if _flag(game, "_push_pending") and game.has_method("_on_push_choice"):
				await create_timer(0.4).timeout
				if is_instance_valid(game) and _flag(game, "_push_pending"):
					game._on_push_choice(false)
					print("[QA] partiel ENCAISSÉ (R130) — pill/vignette/anneaux au degré final")
				await process_frame
				continue
			await process_frame
		if done6:
			await create_timer(1.2).timeout  # pill posée + vignette + anneaux différés des jauges
		elif is_instance_valid(game) and not bool(run.ended):
			_note("ph6 : résolution pas aboutie après %ds — capture de l'état courant (fusion/attente LLM = donnée QA)" % int(BEAT_WAIT_S))
	else:
		_note("ph6 : Résoudre non déclenchable (pas de paire sélectionnée) — capture de l'état courant")
	await _cap("ph6_resolution")
	if run != null:
		print("[QA] post-résolution : integrite=%d corruption=%d beat=%d ended=%s" % [
			int(run.integrite), int(run.corruption), int(run.beat_index), str(run.ended)])
