extends SceneTree
## probe_tuto_draft_headless.gd (R159) — GATE HEADLESS du softlock « le jeu se fige apres avoir pris
## le PREMIER BONUS ». Chemin EXACT rapporte par l'utilisateur, JAMAIS couvert par l'autoplay (qui
## REFUSE le tuto) : depart a froid -> tuto ACCEPTE (« Guide-moi ») -> le guide joue le beat 1 ->
## la main revient -> 1er _advance_to_next ouvre le DRAFT D'OUVERTURE DECALE (B3, opening_draft_done)
## -> le joueur PREND une greffe (geste 1 = carte, geste 2 = toucher une tuile-verbe -> _on_graft_target)
## -> le jeu DOIT repartir (draft ferme + beat avance + choix reouvert). Softlock = ne repart pas.
##
## 100% HEADLESS (exigence utilisateur : « tester en headless totalement ») : aucun rendu, aucune
## capture, aucun input reel. On pilote la VRAIE logique via l'API du jeu (duck-typing has_method/get),
## on avance le temps par process_frame, on ASSERTE l'avancement sous DEADLINE (echec = hang).
##   Godot --headless --path . --script res://tools/probe_tuto_draft_headless.gd
## Sortie : [TDH] ... ; verdict [TDH][PASS] / [TDH][FAIL] ; exit 0/1.

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const OPTIONS_PATH: String = "user://options.cfg"
const SAVE_PATH: String = "user://merlin_run.json"
const TUTO_DEADLINE_S: float = 200.0    # le guide complet (avec la resolution LLM/fallback du beat 1)
const DRAFT_OPEN_DEADLINE_S: float = 30.0
const ADVANCE_DEADLINE_S: float = 60.0  # apres la prise de greffe : le beat DOIT avancer sous ce delai
const GLOBAL_DEADLINE_S: float = 320.0

var _t0: int = 0
var _fails: PackedStringArray = []


func _init() -> void:
	_run()


func _t() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[TDH][FAIL] " + msg)


func _flag(n: Node, prop: String) -> bool:
	if not is_instance_valid(n):
		return false
	var v: Variant = n.get(prop)
	return v != null and bool(v)


func _until(pred: Callable, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return bool(pred.call())


func _dump(game: Node, run: Node, label: String) -> void:
	if not is_instance_valid(game):
		print("[TDH][%s] t=%.1f GAME FREED ended=%s beat=%s" % [
			label, _t(), str(run.get("ended")), str(run.get("beat_index"))])
		return
	print("[TDH][%s] t=%.1f state=%s choice=%s can_adv=%s draft=%s draft_done=%s beat_trans=%s pending_graft=%s tuto=%s beat=%s opening_done=%s ended=%s" % [
		label, _t(), str(game.get("_state")), str(_flag(game, "_choice_open")),
		str(_flag(game, "_can_advance")), str(_flag(game, "_draft_active")),
		str(_flag(game, "_draft_done_flag")), str(_flag(game, "_beat_transition")),
		str(not (game.get("_pending_graft") as Dictionary).is_empty()),
		str((game.get("_tuto") as Node) != null), str(run.get("beat_index")),
		str(run.get("opening_draft_done")), str(run.get("ended"))])


func _run() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	print("[TDH] start (headless, tuto ACCEPTE + prise du draft d'ouverture)")

	# Snapshot save + prefs REELS (restaures a la fin, meme en echec).
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	var save_backup: String = FileAccess.get_file_as_string(SAVE_PATH) if had_save else ""
	var had_opts: bool = FileAccess.file_exists(OPTIONS_PATH)
	var opts_backup: String = FileAccess.get_file_as_string(OPTIONS_PATH) if had_opts else ""

	# Conditions PREMIER JOUEUR : chronique VIERGE (tuto propose) + reduced_motion=false (vrai timing
	# des tweens : un await de tween orphelin ne se masque pas) + tuto hints actifs.
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(OPTIONS_PATH)
	if cfg.has_section("chronique"):
		cfg.erase_section("chronique")
	cfg.set_value("a11y", "reduced_motion", false)
	cfg.save(OPTIONS_PATH)
	var mv: Script = load("res://scripts/game/merlin_visual.gd")
	if mv != null:
		mv.reduced_motion = false
		mv.tuto_hint_a_done = false
		mv.tuto_hint_b_done = false

	await _drive()

	# Restauration a l'octet pres.
	if had_opts:
		var fo: FileAccess = FileAccess.open(OPTIONS_PATH, FileAccess.WRITE)
		if fo != null:
			fo.store_string(opts_backup)
			fo.close()
	elif FileAccess.file_exists(OPTIONS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OPTIONS_PATH))
	if had_save:
		var fs: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if fs != null:
			fs.store_string(save_backup)
			fs.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	var passed: bool = _fails.is_empty()
	print("[TDH] DONE pass=%s fails=%d temps=%ds" % [str(passed), _fails.size(), int(_t())])
	for v in _fails:
		print("[TDH][RECAP] " + v)
	if passed:
		print("[TDH][PASS] tuto ACCEPTE + draft d'ouverture PRIS : le jeu repart (beat avance, choix reouvert)")
	quit(0 if passed else 1)


func _drive() -> void:
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		_fail("autoloads MerlinRun/MerlinScenario absents")
		return
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Gate tuto+draft", "Le sentier se referme derriere le Voyageur.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file(GAME_SCENE)
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		_fail("MerlinGame non chargee")
		return

	# --- Intro : accepter la quete. ---
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_intro_open"), 15.0):
		_fail("intro jamais ouverte")
		return
	game._accept_quest()
	print("[TDH] t=%.1f quete acceptee" % _t())

	# --- Proposition de guide -> ACCEPTER (« Guide-moi »). ---
	if not await _until(func() -> bool:
		if not is_instance_valid(game):
			return true
		var row: Node = game.get("_tuto_prompt_row") as Node
		return row != null and is_instance_valid(row), 15.0):
		_fail("proposition de guide jamais affichee")
		return
	# Cliquer « Guide-moi » via le VRAI bouton (chemin joueur), repli sur _on_tuto_answer(true).
	if not _accept_guide(game):
		if game.has_method("_on_tuto_answer"):
			game._on_tuto_answer(true)
		else:
			_fail("impossible d'accepter le guide")
			return
	print("[TDH] t=%.1f guide ACCEPTE" % _t())

	# --- Derouler le guide jusqu'a sa fin (probe_click par etape, deadline anti-hang). ---
	if not await _drive_tuto(game, run):
		return
	_dump(game, run, "guide_termine")

	# --- 1er _advance_to_next : ouvre le DRAFT D'OUVERTURE DECALE (B3). ---
	# Servir le typewriter/attente eventuels avant de pouvoir avancer.
	var dl_adv: int = Time.get_ticks_msec() + 20000
	while is_instance_valid(game) and not _flag(game, "_can_advance") and not _flag(game, "_draft_active") \
			and Time.get_ticks_msec() < dl_adv and not bool(run.get("ended")):
		if _tw_active(game) and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		await process_frame
	if is_instance_valid(game) and _flag(game, "_can_advance") and game.has_method("_advance_to_next"):
		game._advance_to_next()  # fire-and-forget (coroutine : le draft s'ouvre DEDANS)
		print("[TDH] t=%.1f _advance_to_next (ouvre le draft d'ouverture decale)" % _t())

	# --- Le draft d'ouverture doit s'ouvrir. ---
	if not await _until(func() -> bool:
		return not is_instance_valid(game) or _flag(game, "_draft_active") or bool(run.get("ended")), DRAFT_OPEN_DEADLINE_S):
		_fail("draft d'ouverture jamais ouvert apres le guide (opening_draft_done / has_graftable_action ?)")
		_dump(game, run, "no_draft")
		return
	if not is_instance_valid(game) or bool(run.get("ended")):
		_fail("scene liberee / run finie avant le draft d'ouverture")
		return
	_dump(game, run, "draft_ouvert")
	var beat_before: int = int(run.get("beat_index"))

	# --- PRENDRE la greffe : geste 1 (carte) puis geste 2 (toucher une tuile-verbe -> _on_graft_target). ---
	if not await _take_graft(game, run):
		return

	# --- ASSERTION CENTRALE : le jeu REPART (draft ferme + beat avance + choix reouvert) sous deadline. ---
	var ok_advance: bool = await _until(func() -> bool:
		if not is_instance_valid(game):
			return true
		if bool(run.get("ended")):
			return true
		# repart = draft ferme ET (beat a progresse OU le choix du beat est reouvert)
		return (not _flag(game, "_draft_active")) \
			and (int(run.get("beat_index")) > beat_before or _flag(game, "_choice_open")), ADVANCE_DEADLINE_S)
	if not ok_advance:
		_fail("SOFTLOCK — le jeu NE REPART PAS apres la prise du draft d'ouverture (draft=%s beat=%d->%s choix=%s can_adv=%s state=%s beat_trans=%s draft_done=%s) apres %ds" % [
			str(_flag(game, "_draft_active")), beat_before, str(run.get("beat_index")),
			str(_flag(game, "_choice_open")), str(_flag(game, "_can_advance")),
			str(game.get("_state")), str(_flag(game, "_beat_transition")),
			str(_flag(game, "_draft_done_flag")), int(ADVANCE_DEADLINE_S)])
		_dump(game, run, "SOFTLOCK")
		return
	print("[TDH] t=%.1f le jeu REPART — beat %d->%s choix=%s ended=%s" % [
		_t(), beat_before, str(run.get("beat_index")), str(_flag(game, "_choice_open")), str(run.get("ended"))])


# Clique « Guide-moi » dans _tuto_prompt_row (chemin de signal joueur). false si introuvable.
func _accept_guide(game: Node) -> bool:
	var row: Node = game.get("_tuto_prompt_row") as Node
	if row == null or not is_instance_valid(row):
		return false
	for ch in row.get_children():
		if ch is Button and str((ch as Button).text) == "Guide-moi":
			(ch as Button).pressed.emit()
			return true
	return false


func _tw_active(game: Node) -> bool:
	if not is_instance_valid(game):
		return false
	var tw: Tween = game.get("_tw") as Tween
	return tw != null and tw.is_valid()


# Deroule le guide : clic simule (probe_click) par etape jusqu'a liberation. Watchdog anti-hang.
func _drive_tuto(game: Node, run: Node) -> bool:
	if not await _until(func() -> bool:
		return not is_instance_valid(game) or (game.get("_tuto") as Node) != null, 12.0):
		_fail("guide accepte mais orchestrateur jamais cree")
		return false
	var tuto: Node = game.get("_tuto") as Node if is_instance_valid(game) else null
	if tuto == null or not is_instance_valid(tuto):
		_fail("orchestrateur du guide introuvable")
		return false
	var deadline: int = Time.get_ticks_msec() + int(TUTO_DEADLINE_S * 1000.0)
	var last_step: String = ""
	var last_change: int = Time.get_ticks_msec()
	while is_instance_valid(tuto) and is_instance_valid(game) and Time.get_ticks_msec() < deadline:
		if bool(run.get("ended")):
			_fail("run terminee PENDANT le guide (mort au beat 1 du guide ?)")
			return false
		var sid: String = str(tuto.get("step_id"))
		if sid != last_step:
			print("[TDH] t=%.1f guide etape : %s" % [_t(), sid])
			last_step = sid
			last_change = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_change > 90000:
			_fail("guide FIGE sur l'etape « %s » > 90s (softlock du guide)" % sid)
			return false
		if tuto.has_method("probe_click"):
			tuto.probe_click()
		await create_timer(0.2).timeout
	if is_instance_valid(tuto):
		_fail("guide jamais termine (> %ds)" % int(TUTO_DEADLINE_S))
		return false
	print("[TDH] t=%.1f guide termine" % _t())
	return true


# PREND la greffe d'ouverture : geste 1 (choisir une carte-greffe) puis geste 2 (toucher une tuile
# d'action eligible -> _on_graft_target). Retries : la garde F2 (500 ms post-ouverture) rejette les
# premiers gestes. Duck-typing pur.
func _take_graft(game: Node, run: Node) -> bool:
	var dl: int = Time.get_ticks_msec() + 20000
	var picked_card: bool = false
	while is_instance_valid(game) and _flag(game, "_draft_active") and Time.get_ticks_msec() < dl:
		var pending_empty: bool = (game.get("_pending_graft") as Dictionary).is_empty()
		if pending_empty and not picked_card:
			# Geste 1 : choisir une carte-greffe NON-talent (le talent s'applique en 1 geste, pas de cible).
			var cv: Node = _first_graft_card(game.get("_hand_box"), game)
			if cv != null and game.has_method("_on_draft_card"):
				game._on_draft_card(cv.get("card"))
				if not (game.get("_pending_graft") as Dictionary).is_empty():
					picked_card = true
					print("[TDH] t=%.1f greffe choisie (geste 1) — cible attendue (une tuile-verbe)" % _t())
		elif not pending_empty:
			# Geste 2 : toucher une tuile d'action eligible -> _on_action_tile (dispatch _draft_active).
			var av: Node = _first_eligible_tile(game, run)
			if av != null and game.has_method("_on_action_tile"):
				game._on_action_tile(av.get("card"))
				print("[TDH] t=%.1f tuile-verbe touchee (geste 2 -> _on_graft_target)" % _t())
		await create_timer(0.25).timeout
	if is_instance_valid(game) and _flag(game, "_draft_active") and not _flag(game, "_draft_done_flag"):
		# La greffe n'a pas pu se poser (aucune tuile n'a leve _draft_done_flag) : c'est deja un symptome.
		print("[TDH] t=%.1f AVERTISSEMENT : draft toujours ouvert apres 20s de tentatives de pose (draft_done=%s pending=%s)" % [
			_t(), str(_flag(game, "_draft_done_flag")), str(not (game.get("_pending_graft") as Dictionary).is_empty())])
	return true


# 1re carte-greffe NON-talent visible dans _hand_box (le talent n'a pas d'etape « cible »).
func _first_graft_card(node: Node, game: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.get("card") != null and node.has_signal("card_clicked"):
		var card: Object = node.get("card")
		var g: Dictionary = (game.get("_graft_by_id") as Dictionary).get(str(card.get("id")), {})
		if str(g.get("kind", "")) != "talent":
			return node
	for ch in node.get_children():
		var f: Node = _first_graft_card(ch, game)
		if f != null:
			return f
	return null


# 1re tuile d'action ELIGIBLE (grafts < cap) parmi les 5.
func _first_eligible_tile(game: Node, run: Node) -> Node:
	var cap_v: Variant = run.get("MAX_GRAFTS_PER_ACTION")
	var cap: int = int(cap_v) if cap_v != null else 3
	var views: Variant = game.get("_action_views")
	if views is Array:
		for v in (views as Array):
			if v is Node and is_instance_valid(v):
				var c: Object = (v as Node).get("card")
				if c != null and (c.get("grafts") as Array).size() < cap:
					return v
	return null
