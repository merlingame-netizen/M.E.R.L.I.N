extends SceneTree
## probe_first_choice.gd (R159) — GATE ANTI-REGRESSION du softlock « le gameplay se bloque des le
## premier choix ». Ferme le trou que l'autoplay/soak/tuto-capture NE couvraient PAS : le VRAI
## premier choix interactif d'un joueur en conditions PREMIER JOUEUR (reduced_motion=FALSE, tuto
## PROPOSE a chaque partie via should_offer_tuto()==true).
##
## Contrairement a autoplay_run/probe_bugres (qui appellent _on_resolve en direct et NE cliquent
## jamais la proposition de guide), cette sonde :
##   1. force reduced_motion=false + tuto hints actifs (le PIRE cas d'animation, celui du joueur reel),
##   2. REPOND a la proposition de guide via le VRAI bouton (accept | decline), chemin du joueur,
##   3. joue une VRAIE resolution : clic tuile d'action (via action_clicked), clic carte-trait (via
##      card_clicked) puis clic Resoudre (via _resolve_btn.pressed), le chemin de signaux reel,
##   4. ASSERTE que l'issue s'ecrit : _state==2 && _can_advance sous RESOLVE_TIMEOUT_S, sinon SOFTLOCK.
##
## Deux modes (2 lancements) :
##   --tuto=decline : « Je connais le chemin » -> le joueur joue lui-meme le beat 1 (chemin non teste
##                    avant R159 — c'est CELUI du softlock rapporte).
##   --tuto=accept  : « Guide-moi » -> le guide joue le beat 1, on le deroule au clic (probe_click),
##                    puis on reprend la main et on joue une VRAIE resolution au beat 2.
##
## Duck-typing OBLIGATOIRE (aucune ref class_name du jeu) — lecon autoplay 2026-06-30.
##   Godot --path . --script res://tools/probe_first_choice.gd -- --tuto=decline
##   Godot --path . --script res://tools/probe_first_choice.gd -- --tuto=accept
## Sortie : lignes [FC] ; verdict final [FC][PASS] / [FC][FAIL]. Exit 0 = pass, 1 = fail.

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const RESOLVE_TIMEOUT_S: float = 90.0   # softlock si _can_advance jamais pose apres Resoudre
const CHOICE_TIMEOUT_S: float = 60.0    # softlock si le choix n'ouvre jamais (beat jamais presente)
const STEP_TIMEOUT_S: float = 30.0

var _mode: String = "decline"
var _wait_llm: bool = false   # --wait-llm=1 : attendre MerlinNative.is_ready() AVANT de resoudre
                              # (fidele au joueur reel qui a lu l'intro/tuto -> chemin LLM, pas fallback)
var _real_input: bool = false # --real-input=1 : clics via Viewport.push_input (hit-testing + mouse
                              # filters REELS), pas emit_signal. Detecte un overlay qui avale les clics.
var _take_draft: bool = false # --take-draft=1 : PRENDRE le draft d'ouverture (carte-greffe + tuile),
                              # le vrai « premier choix » ; sinon on le passe.
var _cap_board: bool = false  # --cap-board=1 : capture le plateau au moment ou le choix s'ouvre (QA visuel tuiles)
var _t0: int = 0
var _fails: PackedStringArray = []


func _init() -> void:
	_main()


func _t() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


# _flag SAFE : get() d'un champ retire renvoie null -> bool(null) PLANTE (« Nonexistent 'bool'
# constructor »). On normalise null -> false (lecon : probe_bugres_fast lisait _push_pending retire).
func _flag(n: Node, prop: String) -> bool:
	if not is_instance_valid(n):
		return false
	var v: Variant = n.get(prop)
	return v != null and bool(v)


func _tw_active(game: Node) -> bool:
	if not is_instance_valid(game):
		return false
	var tw: Tween = game.get("_tw") as Tween
	return tw != null and tw.is_valid()


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[FC][FAIL] " + msg)


func _until(pred: Callable, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return bool(pred.call())


func _main() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = str(a)
		if s.begins_with("--tuto="):
			_mode = s.trim_prefix("--tuto=")
		elif s.begins_with("--wait-llm="):
			_wait_llm = s.trim_prefix("--wait-llm=") == "1"
		elif s.begins_with("--real-input="):
			_real_input = s.trim_prefix("--real-input=") == "1"
		elif s.begins_with("--take-draft="):
			_take_draft = s.trim_prefix("--take-draft=") == "1"
		elif s.begins_with("--cap-board="):
			_cap_board = s.trim_prefix("--cap-board=") == "1"
	await process_frame
	_t0 = Time.get_ticks_msec()
	DisplayServer.window_set_title("MERLIN GATE FIRST-CHOICE (%s) — NE PAS FERMER" % _mode)
	print("[FC] start mode=%s" % _mode)

	# Preserve save + prefs REELS du joueur (pattern autoplay_run.gd), restaures a la fin.
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""
	var prefs_path: String = "user://options.cfg"
	var had_prefs: bool = FileAccess.file_exists(prefs_path)
	var prefs_backup: String = FileAccess.get_file_as_string(prefs_path) if had_prefs else ""

	# Conditions PREMIER JOUEUR en MEMOIRE (statics via load() runtime, pas de ref parse-time).
	var mv: Script = load("res://scripts/game/merlin_visual.gd")
	if mv != null:
		mv.reduced_motion = false
		mv.tuto_hint_a_done = false
		mv.tuto_hint_b_done = false
		print("[FC] prefs memoire forcees : reduced_motion=false, tuto hints actifs")

	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		_fail("autoloads MerlinRun/MerlinScenario absents")
		_finish(had_save, save_backup, save_path, had_prefs, prefs_backup, prefs_path, run)
		return

	var ok: bool = await _play(run, sc)
	if not ok and _fails.is_empty():
		_fail("echec sans verdict explicite (voir log)")
	_finish(had_save, save_backup, save_path, had_prefs, prefs_backup, prefs_path, run)


func _finish(had_save: bool, save_backup: String, save_path: String,
		had_prefs: bool, prefs_backup: String, prefs_path: String, run: Node) -> void:
	if had_prefs:
		var fp: FileAccess = FileAccess.open(prefs_path, FileAccess.WRITE)
		if fp != null:
			fp.store_string(prefs_backup)
			fp.close()
	elif FileAccess.file_exists(prefs_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs_path))
	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
	elif run != null and run.has_method("clear_save"):
		run.clear_save()
	var passed: bool = _fails.is_empty()
	print("[FC] DONE mode=%s pass=%s fails=%d temps=%ds" % [_mode, str(passed), _fails.size(), int(_t())])
	for v in _fails:
		print("[FC][RECAP] " + v)
	if passed:
		print("[FC][PASS] mode=%s : premier choix interactif OK (issue ecrite, aucun softlock)" % _mode)
	quit(0 if passed else 1)


func _play(run: Node, sc: Node) -> bool:
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Gate first-choice %s" % _mode, "Le sentier se referme derriere le Voyageur.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file(GAME_SCENE)
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		_fail("MerlinGame non chargee")
		return false

	# --- Intro : Accepter (chemin joueur). ---
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_intro_open"), 15.0):
		_fail("intro jamais ouverte")
		return false
	game._accept_quest()
	print("[FC] t=%.1f quete acceptee" % _t())

	# --- Proposition de guide (should_offer_tuto()==true a chaque partie). ---
	var saw_prompt: bool = await _until(func() -> bool:
		if not is_instance_valid(game):
			return true
		var row: Node = game.get("_tuto_prompt_row") as Node
		return row != null and is_instance_valid(row), 15.0)
	if not is_instance_valid(game):
		_fail("scene liberee avant la proposition de guide")
		return false
	if not saw_prompt:
		_fail("proposition de guide jamais affichee (should_offer_tuto/_build_tuto_prompt ?)")
		return false
	print("[FC] t=%.1f proposition de guide affichee" % _t())

	# Repondre via le VRAI bouton (chemin de signaux du joueur).
	var want_accept: bool = _mode == "accept"
	if not _answer_tuto(game, want_accept):
		_fail("bouton de proposition (%s) introuvable" % ("Guide-moi" if want_accept else "Je connais le chemin"))
		return false
	print("[FC] t=%.1f guide %s" % [_t(), "ACCEPTE" if want_accept else "DECLINE"])

	if want_accept:
		# Le guide joue le beat 1 lui-meme : on le deroule au clic simule jusqu'a sa fin.
		if not await _drive_tuto(game):
			return false
		# Reprise en main : le premier clic sert le draft d'ouverture decale (B3) puis le beat suit.
		if _flag(game, "_can_advance") and game.has_method("_advance_to_next"):
			game._advance_to_next()
		await _pass_draft(game, run)

	# --- Beat jouable : le choix doit s'ouvrir (situation entierement ecrite). ---
	await _pass_draft(game, run)   # draft d'ouverture (chemin decline) ou eventuel draft post-guide
	if not await _reach_choice(game, run):
		return false

	# --- VRAIE resolution interactive : tuile d'action + carte-trait + Resoudre (chemins de signaux). ---
	if not await _real_resolution(game, run, sc):
		return false

	var faits: Array = run.get("faits_marquants") as Array
	var last_fait: String = str(faits[-1]) if faits != null and faits.size() > 0 else "(?)"
	print("[FC] t=%.1f resolution interactive aboutie — DEGRE[%s] integrite=%d corruption=%d ended=%s" % [
		_t(), last_fait, int(run.get("integrite")), int(run.get("corruption")), str(run.get("ended"))])
	return true


# Clique le bouton « Guide-moi » (accept) ou « Je connais le chemin » (decline) de _tuto_prompt_row.
func _answer_tuto(game: Node, accept: bool) -> bool:
	var row: Node = game.get("_tuto_prompt_row") as Node
	if row == null or not is_instance_valid(row):
		return false
	var want: String = "Guide-moi" if accept else "Je connais le chemin"
	for ch in row.get_children():
		if ch is Button and str((ch as Button).text) == want:
			(ch as Button).pressed.emit()
			return true
	return false


# Deroule le guide : clic simule (probe_click) jusqu'a ce que _tuto se libere. Watchdog par etape.
func _drive_tuto(game: Node) -> bool:
	var ok_tuto: bool = await _until(func() -> bool:
		return not is_instance_valid(game) or (game.get("_tuto") as Node) != null, 10.0)
	var tuto: Node = game.get("_tuto") as Node if is_instance_valid(game) else null
	if not ok_tuto or tuto == null or not is_instance_valid(tuto):
		_fail("guide accepte mais orchestrateur jamais cree")
		return false
	var deadline: int = Time.get_ticks_msec() + 180000
	var last_step: String = ""
	var last_change: int = Time.get_ticks_msec()
	while is_instance_valid(tuto) and is_instance_valid(game) and Time.get_ticks_msec() < deadline:
		var sid: String = str(tuto.get("step_id"))
		if sid != last_step:
			last_step = sid
			last_change = Time.get_ticks_msec()
			print("[FC] t=%.1f guide etape : %s" % [_t(), sid])
		elif Time.get_ticks_msec() - last_change > int(RESOLVE_TIMEOUT_S * 1000.0):
			_fail("guide FIGE sur l'etape « %s » > %ds (softlock du guide)" % [sid, int(RESOLVE_TIMEOUT_S)])
			return false
		if tuto.has_method("probe_click"):
			tuto.probe_click()
		await create_timer(0.25).timeout
	if is_instance_valid(tuto):
		_fail("guide jamais termine (deroulement > 180s)")
		return false
	print("[FC] t=%.1f guide termine" % _t())
	return true


# Passe OU prend un draft de greffe s'il est ouvert (chemin joueur). No-op sinon.
# _take_draft : clic carte-greffe puis clic tuile d'action (2 gestes) — la VRAIE « premier choix »
# d'un joueur qui decline le guide, non couverte par autoplay en input reel.
func _pass_draft(game: Node, run: Node) -> void:
	var saw: bool = await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_draft_active"), 6.0)
	if not (saw and is_instance_valid(game) and _flag(game, "_draft_active")):
		return
	# Garde F2 : la pose est refusee < 500 ms apres l'ouverture (anti-pick-aveugle). On patiente.
	await create_timer(0.7).timeout
	var dl: int = Time.get_ticks_msec() + 15000
	while is_instance_valid(game) and _flag(game, "_draft_active") and Time.get_ticks_msec() < dl:
		if _take_draft and (game.get("_pending_graft") as Dictionary).is_empty():
			# Etape 1 : choisir une carte-greffe (clic sur la vue dans _hand_box).
			var cv: Node = _first_card_view(game.get("_hand_box"))
			if cv is Control and _real_input:
				await _click_control(cv as Control)
			elif cv != null and cv.has_signal("card_clicked"):
				cv.emit_signal("card_clicked", cv.get("card"))
		elif _take_draft and not (game.get("_pending_graft") as Dictionary).is_empty():
			# Etape 2 : toucher une tuile d'action ELIGIBLE (grafts < cap) pour recevoir la greffe.
			var av: Node = _first_eligible_tile(game, run)
			if av is Control and _real_input:
				await _click_control(av as Control)
			elif av != null and av.has_signal("action_clicked"):
				av.emit_signal("action_clicked", av.get("card"))
		elif not _take_draft and game.has_method("_on_draft_skip"):
			game._on_draft_skip()
		await create_timer(0.30).timeout
	if is_instance_valid(game) and _flag(game, "_draft_active"):
		_fail("draft impossible a %s (15s) — softlock au draft d'ouverture (premier choix)" % (
			"prendre" if _take_draft else "fermer"))
	elif _take_draft:
		print("[FC] t=%.1f draft d'ouverture PRIS (carte-greffe + tuile, input %s)" % [
			_t(), "reel" if _real_input else "signal"])


func _first_card_view(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.get("card") != null and node.has_signal("card_clicked"):
		return node
	for ch in node.get_children():
		var f: Node = _first_card_view(ch)
		if f != null:
			return f
	return null


func _first_eligible_tile(game: Node, run: Node) -> Node:
	var cap: int = int(run.get("MAX_GRAFTS_PER_ACTION")) if run.get("MAX_GRAFTS_PER_ACTION") != null else 3
	var views: Variant = game.get("_action_views")
	if views is Array:
		for v in (views as Array):
			if v is Node and is_instance_valid(v):
				var c: Object = (v as Node).get("card")
				if c != null and (c.get("grafts") as Array).size() < cap:
					return v
	return null


# Attend l'ouverture du choix (beat presente, situation ecrite). Skippe le typewriter comme un joueur.
func _reach_choice(game: Node, run: Node) -> bool:
	var dl: int = Time.get_ticks_msec() + int(CHOICE_TIMEOUT_S * 1000.0)
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game) or bool(run.get("ended")):
			_fail("scene liberee / run finie avant le choix du beat 1")
			return false
		if _flag(game, "_draft_active") and game.has_method("_on_draft_skip"):
			game._on_draft_skip()
			await create_timer(0.25).timeout
			continue
		if _flag(game, "_choice_open"):
			break
		if _tw_active(game) and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		await process_frame
	if not _flag(game, "_choice_open"):
		_fail("choix JAMAIS ouvert apres %ds (softlock pre-resolution : beat jamais presente)" % int(CHOICE_TIMEOUT_S))
		return false
	print("[FC] t=%.1f choix ouvert (beat presente) — state=%s" % [_t(), str(game.get("_state"))])
	if _cap_board:
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img != null:
			var p: String = ProjectSettings.globalize_path("res://output/captures/glyphs/") + "board_tiles.png"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://output/captures/glyphs/"))
			img.save_png(p)
			print("[FC] capture board -> %s" % p)
	return true


# VRAIE resolution : tuile d'action (action_clicked) + carte-trait (card_clicked) + Resoudre
# (_resolve_btn.pressed) — les 3 chemins de SIGNAUX que le joueur declenche, jamais _on_resolve en direct.
func _real_resolution(game: Node, run: Node, _sc: Node) -> bool:
	var acts: Array = run.get("actions") as Array
	var hand: Array = run.get("hand") as Array
	if acts.is_empty() or hand.is_empty():
		_fail("actions(%d)/main(%d) vides au choix" % [acts.size(), hand.size()])
		return false

	# Fidelite joueur reel : le joueur a lu -> le modele est PRET quand il resout (chemin LLM,
	# dice + sustain + typewriter de longue prose), jamais le fallback procedural instantane.
	if _wait_llm:
		var okw: bool = await _until(func() -> bool:
			var mn: Node = root.get_node_or_null("/root/MerlinNative")
			return mn != null and mn.has_method("is_ready") and mn.is_ready(), 180.0)
		print("[FC] t=%.1f modele LLM pret=%s (chemin resolution LLM force)" % [_t(), str(okw)])

	# Tuile d'action.
	var av: Node = _action_view_for(game, acts[0])
	if _real_input and av is Control:
		var hov: String = _hovered_name(av as Control)
		print("[FC] tuile action : survol reel = %s (attendu : la tuile ou un enfant)" % hov)
		await _click_control(av as Control)
	elif av != null and av.has_signal("action_clicked"):
		av.emit_signal("action_clicked", acts[0])   # chemin _on_gui_input -> _on_action_tile
	elif game.has_method("_on_action_tile"):
		game._on_action_tile(acts[0])   # repli
	await create_timer(0.4).timeout

	# Carte-trait.
	var cv: Node = _card_view_in(game.get("_hand_box"), hand[0])
	if _real_input and cv is Control:
		var hov2: String = _hovered_name(cv as Control)
		print("[FC] carte-trait : survol reel = %s (attendu : la carte ou un enfant)" % hov2)
		await _click_control(cv as Control)
	elif cv != null and cv.has_signal("card_clicked"):
		cv.emit_signal("card_clicked", hand[0])   # chemin _on_gui_input -> _on_trait_card
	elif game.has_method("_on_trait_card"):
		game._on_trait_card(hand[0])   # repli
	await create_timer(0.5).timeout

	if game.get("_selected_action") == null or game.get("_selected_trait") == null:
		_fail("selection incomplete apres clic tuile+carte (action=%s trait=%s)" % [
			str(game.get("_selected_action") != null), str(game.get("_selected_trait") != null)])
		return false

	# Bouton Resoudre : doit etre ARME (pas disabled), sinon le joueur ne peut pas resoudre.
	var btn: Button = game.get("_resolve_btn") as Button
	if btn == null or not is_instance_valid(btn):
		_fail("bouton Resoudre introuvable")
		return false
	if btn.disabled:
		_fail("bouton Resoudre DESARME malgre paire complete (le joueur ne peut pas resoudre)")
		return false
	if _real_input:
		var hovb: String = _hovered_name(btn)
		print("[FC] t=%.1f CLIC RESOUDRE (input reel) — survol = %s" % [_t(), hovb])
		await _click_control(btn)
	else:
		print("[FC] t=%.1f CLIC RESOUDRE (chemin signal pressed)" % _t())
		btn.pressed.emit()   # chemin de signal reel (jamais _on_resolve() en direct)

	# --- Watchdog : issue ecrite (_state==2 && _can_advance) sinon SOFTLOCK diagnostique. ---
	var t_res: int = Time.get_ticks_msec()
	while true:
		if not is_instance_valid(game):
			print("[FC] t=%.1f scene liberee pendant la resolution (fin de run mid-resolve — tolere)" % _t())
			return true
		if bool(run.get("ended")):
			print("[FC] t=%.1f run TERMINEE pendant la resolution (mort/corruption — tolere)" % _t())
			return true
		if int(game.get("_state")) == 2 and _flag(game, "_can_advance"):
			return true
		var el: float = float(Time.get_ticks_msec() - t_res) / 1000.0
		if el >= RESOLVE_TIMEOUT_S:
			var st_l: RichTextLabel = game.get("_situation_text") as RichTextLabel
			_fail("SOFTLOCK — _can_advance jamais pose %ds apres Resoudre (state=%s can_adv=%s tw=%s vis=%d)" % [
				int(RESOLVE_TIMEOUT_S), str(game.get("_state")), str(_flag(game, "_can_advance")),
				str(_tw_active(game)), (st_l.visible_characters if st_l != null else -1)])
			return false
		# Servir les modaux comme un joueur : skip typewriter, pacte tranche.
		if _tw_active(game) and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
			await process_frame
			continue
		var pact: Node = game.get("_pact_row") as Node
		if pact != null and is_instance_valid(pact):
			await create_timer(0.3).timeout
			pact = game.get("_pact_row") as Node
			if is_instance_valid(pact):
				for pb in pact.get_children():
					if pb is Button:
						(pb as Button).pressed.emit()
						break
			await process_frame
			continue
		await process_frame
	return true


# Nom du Control REELLEMENT survole au centre d'un Control cible (revele un overlay qui le couvre).
# Warp mouse + motion event -> gui_get_hovered_control. "" si rien, "<autre>" si ce n'est pas la cible.
func _hovered_name(target: Control) -> String:
	var vp: Viewport = root
	var c: Vector2 = target.get_global_rect().get_center()
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.position = c
	mm.global_position = c
	vp.push_input(mm)
	var hov: Control = vp.gui_get_hovered_control()
	if hov == null:
		return "(aucun)"
	# Le survol attendu = la cible OU un de ses descendants (les enfants IGNORE laissent passer au parent).
	var n: Node = hov
	while n != null:
		if n == target:
			return "%s [CIBLE OK]" % hov.get_class()
		n = n.get_parent()
	return "%s '%s' [!= CIBLE : overlay ?]" % [hov.get_class(), hov.name]


# Clic REEL au centre d'un Control : motion + press + release via Viewport.push_input (hit-testing
# + mouse filters reels). Un overlay STOP au-dessus avalerait ces evenements (le joueur reste coince).
func _click_control(target: Control) -> void:
	var vp: Viewport = root
	var c: Vector2 = target.get_global_rect().get_center()
	var mm: InputEventMouseMotion = InputEventMouseMotion.new()
	mm.position = c
	mm.global_position = c
	vp.push_input(mm)
	await process_frame
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = c
	press.global_position = c
	vp.push_input(press)
	await process_frame
	var rel: InputEventMouseButton = InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = c
	rel.global_position = c
	vp.push_input(rel)
	await process_frame


# Trouve la MerlinActionView correspondant a une carte-action (duck-type via _action_views).
func _action_view_for(game: Node, card: Object) -> Node:
	var views: Variant = game.get("_action_views")
	if views is Array:
		for v in (views as Array):
			if v is Node and is_instance_valid(v) and (v as Node).get("card") == card:
				return v
	return null


# Trouve la MerlinCardView d'une carte-trait dans _hand_box (duck-type : node avec .card).
func _card_view_in(node: Node, card: Object) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.get("card") == card and node.has_signal("card_clicked"):
		return node
	for ch in node.get_children():
		var f: Node = _card_view_in(ch, card)
		if f != null:
			return f
	return null
