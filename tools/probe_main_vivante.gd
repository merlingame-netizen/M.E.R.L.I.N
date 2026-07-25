extends SceneTree
## probe_main_vivante.gd (R168, R159) — sonde INTERACTIVE dediee : exerce REELLEMENT les chemins
## cliquables neufs de la vague « main vivante » (repioche + conversion), sur le modele de
## probe_first_choice.gd (chemins de SIGNAUX reels : card_clicked/action_clicked/pressed, jamais
## _on_resolve() en direct). Lecon R159 : tout chemin cliquable neuf DOIT avoir sa sonde.
##
## Quatre exercices (1 lancement, sequentiel) :
##   0) TEST NEGATIF (decision coordinateur 2026-07-28, CONDITION D'URGENCE) : si une carte de la
##      main COMPLETE couvre deja la nature visee, l'offre de conversion ne doit JAMAIS apparaitre,
##      meme si le combo SELECTIONNE ne la couvre pas lui-meme. Cherche un requis couvert par UNE
##      carte de la main mais pas par une autre, selectionne la carte NON couvrante + une action qui
##      ne couvre pas non plus, verifie l'ABSENCE d'offre. Info (non-fatal) si non constructible sur
##      ce beat precis (composition de main dependante du RNG).
##   1) REPIOCHE : selectionne un trait, clique l'affordance ↺ Repiocher (Z5), verifie que la main
##      change (carte remplacee), que run.redraw_used_this_beat passe a true et que l'affordance
##      redevient invisible/desarmee ensuite (budget consomme).
##   2) CONVERSION (1er usage, cout attendu 1) : force un combo action+trait qui NE couvre PAS un
##      requis ET dont AUCUNE carte de la main ne le couvre non plus (condition d'urgence reunie),
##      verifie que l'offre « Compter comme X (+1 Corruption) » apparait (grammaire
##      _build_pact_choice), clique Accepter via le VRAI bouton, verifie Corruption +1, le compteur
##      run.conversions_this_run == 1 et le badge de benediction sur l'action.
##   3) COUT CROISSANT (2e usage) : resout le beat (clic Resoudre reel) puis avance au beat suivant,
##      refait une conversion (meme condition d'urgence) — verifie que le libelle affiche bien
##      « +2 Corruption » et que la Corruption augmente exactement de 2 (pas 1).
##
## Godot --headless --path . --script res://tools/probe_main_vivante.gd
## Sortie : lignes [MV] ; verdict final [MV][PASS] / [MV][FAIL]. Exit 0 = pass, 1 = fail.

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const STEP_TIMEOUT_S: float = 30.0

var _t0: int = 0
var _fails: PackedStringArray = []


func _init() -> void:
	_main()


func _t() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[MV][FAIL] " + msg)


func _until(pred: Callable, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return bool(pred.call())


func _main() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec()
	DisplayServer.window_set_title("MERLIN PROBE MAIN-VIVANTE (R168) - NE PAS FERMER")
	print("[MV] start")

	# Preserve save + prefs REELS du joueur (pattern probe_first_choice.gd), restaures a la fin.
	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""

	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		_fail("autoloads MerlinRun/MerlinScenario absents")
		_finish(had_save, save_backup, save_path, run)
		return

	var ok: bool = await _play(run, sc)
	if not ok and _fails.is_empty():
		_fail("echec sans verdict explicite (voir log)")
	_finish(had_save, save_backup, save_path, run)


func _finish(had_save: bool, save_backup: String, save_path: String, run: Node) -> void:
	if had_save:
		var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(save_backup)
			f.close()
	elif run != null and run.has_method("clear_save"):
		run.clear_save()
	var passed: bool = _fails.is_empty()
	print("[MV] DONE pass=%s fails=%d temps=%ds" % [str(passed), _fails.size(), int(_t())])
	for v in _fails:
		print("[MV][RECAP] " + v)
	if passed:
		print("[MV][PASS] test negatif + repioche + conversion (urgence, cout croissant) : chemins cliquables reels verifies")
	quit(0 if passed else 1)


func _play(run: Node, sc: Node) -> bool:
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Sonde main-vivante", "Le sentier se referme derriere le Voyageur.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file(GAME_SCENE)
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		_fail("MerlinGame non chargee")
		return false

	game._accept_quest()
	if not await _answer_tuto_prompt(game):
		return false
	await _pass_draft(game, run)
	if not await _reach_choice(game, run):
		return false
	await _dismiss_pending_pilier_pact(game)

	# 0) TEST NEGATIF (condition d'urgence) : une carte couvrante en main -> jamais d'offre.
	var neg_setup: Dictionary = _find_negative_setup(game, run)
	if neg_setup.is_empty():
		print("[MV] test negatif : aucune main (couvrante + non-couvrante pour un meme requis) sur ce beat, ignore (info, depend du tirage)")
	else:
		if not await _exercise_negative_no_offer(game, run, neg_setup):
			return false
		# Deselectionne la carte ET l'action utilisees par le test negatif (toggle) avant de
		# poursuivre : la suite choisit ses propres cartes ; une selection residuelle (surtout
		# l'action, jamais reselectionnee par _exercise_redraw) fausserait sinon le clic suivant en
		# le transformant en DESELECTION si _find_emergency_target retombe sur la meme action.
		if game.has_method("_on_trait_card"):
			game._on_trait_card(neg_setup["trait"])
		if game.has_method("_on_action_tile"):
			game._on_action_tile(neg_setup["action"])
		await create_timer(0.2).timeout

	if not await _exercise_redraw(game, run):
		return false
	# 1er usage : cout attendu 1 (conversions_this_run 0 -> 1). Certains beats n'ont AUCUN requis
	# eligible a l'urgence (main/benedictions couvrent tout, cas legitime selon le tirage) : retente
	# sur les beats suivants au besoin (_do_conversion_with_retry).
	if not await _do_conversion_with_retry(game, run, 1):
		return false
	# Chantier « cout croissant » : avance au beat suivant et refait une conversion — le 2e usage
	# DOIT couter 2 (conversions_this_run 1 -> 2). Meme condition d'urgence appliquee.
	if not await _resolve_and_advance(game, run):
		return false
	return await _do_conversion_with_retry(game, run, 2)


# La proposition de guide (should_offer_tuto()==true a chaque partie, cf. probe_first_choice.gd)
# doit etre TRANCHEE avant que le beat 1 ne s'ouvre. On decline ("Je connais le chemin") : la sonde
# joue elle-meme le beat, chemin le plus direct vers les exercices repioche/conversion.
func _answer_tuto_prompt(game: Node) -> bool:
	var saw: bool = await _until(func() -> bool:
		if not is_instance_valid(game):
			return true
		var row: Node = game.get("_tuto_prompt_row") as Node
		return row != null and is_instance_valid(row), 15.0)
	if not is_instance_valid(game):
		_fail("scene liberee avant la proposition de guide")
		return false
	if not saw:
		_fail("proposition de guide jamais affichee (should_offer_tuto/_build_tuto_prompt ?)")
		return false
	var row: Node = game.get("_tuto_prompt_row") as Node
	if row == null or not is_instance_valid(row):
		_fail("_tuto_prompt_row disparu avant le clic")
		return false
	var clicked: bool = false
	for ch in row.get_children():
		if ch is Button and str((ch as Button).text) == "Je connais le chemin":
			(ch as Button).pressed.emit()
			clicked = true
			break
	if not clicked:
		_fail("bouton « Je connais le chemin » introuvable")
		return false
	print("[MV] t=%.1f guide decline" % _t())
	return true


# Passe tout draft/vitrine ouvert (chemin joueur standard, cf. probe_first_choice.gd).
func _pass_draft(game: Node, run: Node) -> void:
	var saw: bool = await _until(func() -> bool: return not is_instance_valid(game) or bool(game.get("_draft_active")), 6.0)
	if not (saw and is_instance_valid(game) and bool(game.get("_draft_active"))):
		return
	await create_timer(0.7).timeout
	var dl: int = Time.get_ticks_msec() + 15000
	while is_instance_valid(game) and bool(game.get("_draft_active")) and Time.get_ticks_msec() < dl:
		if game.has_method("_on_draft_skip"):
			game._on_draft_skip()
		await create_timer(0.3).timeout


func _reach_choice(game: Node, run: Node) -> bool:
	var dl: int = Time.get_ticks_msec() + int(STEP_TIMEOUT_S * 3.0 * 1000.0)
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game) or bool(run.get("ended")):
			_fail("scene liberee / run finie avant le choix (softlock ou fin de run prematuree)")
			return false
		if bool(game.get("_draft_active")) and game.has_method("_on_draft_skip"):
			game._on_draft_skip()
			await create_timer(0.25).timeout
			continue
		if bool(game.get("_choice_open")):
			break
		var tw: Tween = game.get("_tw") as Tween
		if tw != null and tw.is_valid() and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		await process_frame
	if not bool(game.get("_choice_open")):
		_fail("choix jamais ouvert (softlock pre-resolution)")
		return false
	print("[MV] t=%.1f choix ouvert" % _t())
	return true


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


func _action_view_for(game: Node, card: Object) -> Node:
	var views: Variant = game.get("_action_views")
	if views is Array:
		for v in (views as Array):
			if v is Node and is_instance_valid(v) and (v as Node).get("card") == card:
				return v
	return null


# --- Exercice 1 : REPIOCHE (chantier 1, Z5) ---
func _exercise_redraw(game: Node, run: Node) -> bool:
	var hand: Array = run.get("hand") as Array
	if hand.is_empty():
		_fail("main vide au choix (repioche non testable)")
		return false
	var target_card: Object = hand[0]
	var target_id: String = str(target_card.id)
	var cv: Node = _card_view_in(game.get("_hand_box"), target_card)
	if cv != null and cv.has_signal("card_clicked"):
		cv.emit_signal("card_clicked", target_card)
	elif game.has_method("_on_trait_card"):
		game._on_trait_card(target_card)
	await create_timer(0.3).timeout
	if game.get("_selected_trait") != target_card:
		_fail("selection de trait non prise (repioche non testable)")
		return false

	var btn: Button = game.get("_redraw_btn") as Button
	if btn == null or not is_instance_valid(btn):
		_fail("bouton de repioche introuvable (_redraw_btn)")
		return false
	if not btn.visible:
		_fail("bouton de repioche INVISIBLE malgre trait selectionne + budget disponible (pilier MINIMAL viole)")
		return false
	print("[MV] t=%.1f affordance repioche visible" % _t())
	btn.pressed.emit()  # chemin de signal reel (jamais run.redraw_one() en direct)
	await create_timer(0.4).timeout

	if not bool(run.get("redraw_used_this_beat")):
		_fail("run.redraw_used_this_beat toujours false apres le clic (repioche non appliquee)")
		return false
	var new_hand: Array = run.get("hand") as Array
	var still_there: bool = false
	for c in new_hand:
		if str(c.id) == target_id:
			still_there = true
			break
	if still_there:
		_fail("la carte repiochee est encore dans la main (defausse/repioche non effectuee)")
		return false
	if is_instance_valid(btn) and btn.visible:
		_fail("bouton de repioche encore VISIBLE apres consommation du budget (1x/beat viole)")
		return false
	print("[MV] t=%.1f repioche appliquee (budget consomme, affordance masquee)" % _t())
	return true


# Vrai si `card` porte le tag `tag_canon` (deja normalise via TagsScript.to_canon).
func _covers_tag(card: Object, tag_canon: String, TagsScript: Variant) -> bool:
	if card == null or not (card.get("tags") is Array):
		return false
	for t in (card.tags as Array):
		if TagsScript.to_canon(str(t)) == tag_canon:
			return true
	return false


# --- Exercice 0 : TEST NEGATIF (condition d'urgence, decision coordinateur 2026-07-28) ---
# Cherche un requis R du beat courant tel que : au moins 1 carte de la main le COUVRE, ET au moins
# 1 AUTRE carte de la main ne le couvre PAS. Retourne {} si aucun requis n'a cette double propriete
# sur la main courante (depend du tirage — pas un echec de cablage, juste rien a tester ici).
func _find_negative_setup(game: Node, run: Node) -> Dictionary:
	var reqs: Array = (game.get("_current_situation") as Dictionary).get("required_tags", [])
	var hand: Array = run.get("hand") as Array
	var acts: Array = run.get("actions") as Array
	if reqs.is_empty() or hand.size() < 2 or acts.is_empty():
		return {}
	var TagsScript := load("res://scripts/game/merlin_tags.gd")
	for r in reqs:
		var r_canon: String = TagsScript.to_canon(str(r))
		var covering: Object = null
		var noncovering: Object = null
		for t in hand:
			if _covers_tag(t, r_canon, TagsScript):
				if covering == null:
					covering = t
			else:
				if noncovering == null:
					noncovering = t
		if covering == null or noncovering == null:
			continue
		for a in acts:
			if not _covers_tag(a, r_canon, TagsScript):
				return {"tag": str(r), "action": a, "trait": noncovering, "covering_trait": covering}
	return {}


# Selectionne action+trait NE COUVRANT PAS le requis vise (alors qu'une AUTRE carte de la main le
# couvre) : l'offre de conversion ne doit JAMAIS apparaitre POUR CETTE NATURE (main.can_convert_tag ==
# false). Si le beat a un 2e requis genuinement decouvert par la main entiere, une offre LEGITIME
# pour CETTE AUTRE nature peut apparaitre (ce n'est pas une violation) : on ne blame que la nature
# ciblee par ce test, jamais "un convert quelconque".
func _exercise_negative_no_offer(game: Node, run: Node, setup: Dictionary) -> bool:
	var a: Object = setup["action"]
	var t: Object = setup["trait"]
	var av: Node = _action_view_for(game, a)
	if av != null and av.has_signal("action_clicked"):
		av.emit_signal("action_clicked", a)
	elif game.has_method("_on_action_tile"):
		game._on_action_tile(a)
	await create_timer(0.2).timeout
	var cv: Node = _card_view_in(game.get("_hand_box"), t)
	if cv != null and cv.has_signal("card_clicked"):
		cv.emit_signal("card_clicked", t)
	elif game.has_method("_on_trait_card"):
		game._on_trait_card(t)
	await create_timer(0.7).timeout  # laisse _update_preview -> _maybe_offer_convert tourner
	if is_instance_valid(game) and str(game.get("_pact_active_pk")) == "convert" and str(game.get("_convert_offer_tag")) == str(setup["tag"]):
		_fail("offre de conversion affichee pour '%s' malgre une carte COUVRANTE en main (condition d'urgence violee)" % str(setup["tag"]))
		return false
	print("[MV] t=%.1f test negatif OK : aucune offre pour '%s' (une autre carte de la main la couvre deja)" % [_t(), str(setup["tag"])])
	return true


# Vrai si `a` couvre effectivement `tag_canon` UNE FOIS la benediction de pilier (blessed_tags,
# R131 - auto-appliquee par choeur/chevalier/enfant, SANS pacte, avant meme l'ouverture du choix)
# prise en compte : c'est EXACTEMENT ce que lit MerlinResolution.resolve() via run.blessed_bonus,
# donc le predicat que doit utiliser la sonde pour predire fidelement "missing" (sinon un requis
# beni automatiquement au beat 2 semble encore "eligible" a l'urgence alors qu'il est deja couvert).
func _action_effective_covers(a: Object, tag_canon: String, run: Node, TagsScript: Variant) -> bool:
	if _covers_tag(a, tag_canon, TagsScript):
		return true
	var blessed: Dictionary = run.get("blessed_tags") as Dictionary
	var bt: Variant = blessed.get(str(a.get("id")), "")
	return str(bt) != "" and TagsScript.to_canon(str(bt)) == tag_canon


# Cherche un requis R du beat courant tel que : AUCUNE carte de la main COMPLETE ne le couvre
# (condition d'urgence, decision coordinateur 2026-07-28), et une action existe qui ne le couvre pas
# non plus, benediction de pilier comprise (sinon la couverture du combo serait deja pleine — pas de
# "missing" a convertir). Retourne {} si aucun requis n'est eligible (rare, mais possible selon le
# tirage : la main ou les benedictions de pilier peuvent deja tout couvrir).
func _find_emergency_target(game: Node, run: Node) -> Dictionary:
	var reqs: Array = (game.get("_current_situation") as Dictionary).get("required_tags", [])
	var hand: Array = run.get("hand") as Array
	var acts: Array = run.get("actions") as Array
	if reqs.is_empty() or hand.is_empty() or acts.is_empty():
		return {}
	var TagsScript := load("res://scripts/game/merlin_tags.gd")
	for r in reqs:
		var r_canon: String = TagsScript.to_canon(str(r))
		var hand_covers: bool = false
		for t in hand:
			if _covers_tag(t, r_canon, TagsScript):
				hand_covers = true
				break
		if hand_covers:
			continue  # la main PEUT repondre : pas d'urgence pour cette nature (attendu, R168)
		for a in acts:
			if not _action_effective_covers(a, r_canon, run, TagsScript):
				return {"tag": str(r), "action": a, "trait": hand[0]}
	return {}


# --- Exercice 1/2 : CONVERSION (chantier 2, grammaire _build_pact_choice), condition d'urgence,
# COUT CROISSANT --- expected_cost = N attendu (1er usage de la run = 1, 2e usage = 2).
func _do_one_conversion(game: Node, run: Node, expected_cost: int) -> bool:
	var setup: Dictionary = _find_emergency_target(game, run)
	if setup.is_empty():
		_fail("aucun requis eligible a l'urgence sur ce beat (main couvre tout, conversion non testable, cout attendu %d)" % expected_cost)
		return false
	var pick_a: Object = setup["action"]
	var pick_t: Object = setup["trait"]

	var av: Node = _action_view_for(game, pick_a)
	if av != null and av.has_signal("action_clicked"):
		av.emit_signal("action_clicked", pick_a)
	elif game.has_method("_on_action_tile"):
		game._on_action_tile(pick_a)
	await create_timer(0.2).timeout
	var cv: Node = _card_view_in(game.get("_hand_box"), pick_t)
	if cv != null and cv.has_signal("card_clicked"):
		cv.emit_signal("card_clicked", pick_t)
	elif game.has_method("_on_trait_card"):
		game._on_trait_card(pick_t)
	await create_timer(0.4).timeout

	if not await _until(func() -> bool:
		return not is_instance_valid(game) or (str(game.get("_pact_active_pk")) == "convert" and game.get("_pact_row") != null), 6.0):
		_fail("offre de conversion jamais affichee malgre requis '%s' non couvert par la main (cout attendu %d)" % [str(setup["tag"]), expected_cost])
		return false

	var conv_before: int = int(run.get("conversions_this_run"))
	var next_cost: int = int(run.call("next_convert_cost"))
	if next_cost != expected_cost:
		_fail("run.next_convert_cost()=%d attendu %d AVANT le clic (conversions_this_run=%d)" % [next_cost, expected_cost, conv_before])
		return false

	var pact: Node = game.get("_pact_row") as Node
	if pact == null or not is_instance_valid(pact):
		_fail("_pact_row disparu avant le clic (cout attendu %d)" % expected_cost)
		return false
	var btn_text: String = ""
	var btn_found: Button = null
	for b in pact.get_children():
		if b is Button and str((b as Button).text).begins_with("Compter comme"):
			btn_found = b as Button
			btn_text = str((b as Button).text)
			break
	if btn_found == null:
		_fail("bouton « Compter comme » introuvable dans _pact_row (cout attendu %d)" % expected_cost)
		return false
	var expected_label: String = "+%d Corruption" % expected_cost
	if not btn_text.contains(expected_label):
		_fail("libelle du bouton ne montre pas « %s » (texte='%s')" % [expected_label, btn_text])
		return false
	print("[MV] t=%.1f offre de conversion affichee (nature=%s, %s)" % [_t(), str(game.get("_convert_offer_tag")), btn_text])

	var corr_before: int = int(run.get("corruption"))
	btn_found.pressed.emit()  # chemin de signal reel (jamais run.convert_card() en direct)
	await create_timer(0.4).timeout

	if not bool(run.get("convert_used_this_beat")):
		_fail("run.convert_used_this_beat toujours false apres le clic (conversion non appliquee, cout attendu %d)" % expected_cost)
		return false
	var corr_after: int = int(run.get("corruption"))
	if corr_after != corr_before + expected_cost:
		_fail("Corruption +%d attendue apres conversion (avant=%d apres=%d)" % [expected_cost, corr_before, corr_after])
		return false
	var conv_after: int = int(run.get("conversions_this_run"))
	if conv_after != conv_before + 1:
		_fail("conversions_this_run attendu %d, obtenu %d" % [conv_before + 1, conv_after])
		return false
	var blessed: Dictionary = run.get("blessed_tags") as Dictionary
	if not blessed.has(str(pick_a.id)):
		_fail("blessed_tags ne porte pas l'id de l'action convertie (feedforward absent, cout attendu %d)" % expected_cost)
		return false
	print("[MV] t=%.1f conversion #%d appliquee (Corruption %d -> %d, cout=%d, badge pose)" % [
		_t(), conv_after, corr_before, corr_after, expected_cost])
	return true


# Selectionne la 1re action + la 1re carte de main disponibles, sans se soucier de couverture
# (utilise pour "passer" un beat qui n'offre pas de requis eligible a l'urgence, cf. ci-dessous).
func _select_first_available_combo(game: Node, run: Node) -> void:
	var acts: Array = run.get("actions") as Array
	var hand: Array = run.get("hand") as Array
	if acts.is_empty() or hand.is_empty():
		return
	var a: Object = acts[0]
	var t: Object = hand[0]
	var av: Node = _action_view_for(game, a)
	if av != null and av.has_signal("action_clicked"):
		av.emit_signal("action_clicked", a)
	elif game.has_method("_on_action_tile"):
		game._on_action_tile(a)
	var cv: Node = _card_view_in(game.get("_hand_box"), t)
	if cv != null and cv.has_signal("card_clicked"):
		cv.emit_signal("card_clicked", t)
	elif game.has_method("_on_trait_card"):
		game._on_trait_card(t)


# Un usage de conversion (cout attendu N) exige un beat avec au moins un requis ELIGIBLE a
# l'urgence (main ET benedictions de pilier ne le couvrent pas deja) — pas garanti sur CHAQUE beat
# selon le tirage (main genereuse, ou pilier qui benit justement le bon tag). Si le beat courant n'en
# a aucun, on le resout normalement (n'importe quelle paire) et on retente sur le suivant, jusqu'a
# 4 tentatives, avant d'abandonner avec un echec explicite (le cablage doit rester verifiable).
func _do_conversion_with_retry(game: Node, run: Node, expected_cost: int) -> bool:
	var attempts: int = 0
	while attempts < 4:
		attempts += 1
		if not _find_emergency_target(game, run).is_empty():
			return await _do_one_conversion(game, run, expected_cost)
		print("[MV] t=%.1f beat #%d sans requis eligible a l'urgence (tirage) : resolu normalement, on retente (cout attendu %d)" % [_t(), attempts, expected_cost])
		_select_first_available_combo(game, run)
		await create_timer(0.3).timeout
		if not await _resolve_and_advance(game, run):
			return false
		if bool(run.get("ended")):
			print("[MV] t=%.1f run terminee avant d'avoir pu tester le cout %d (tolere)" % [_t(), expected_cost])
			return true
	_fail("aucun beat eligible a l'urgence apres %d tentatives (cout %d de conversion non testable)" % [attempts, expected_cost])
	return false


# Resout le beat courant via le VRAI bouton Resoudre, sert les eventuels pactes qui surgissent
# (chemin generique, comme probe_first_choice.gd), puis avance au beat suivant et rouvre le choix.
# Necessaire pour tester le 2e usage de la conversion (le cap 1/beat force a changer de beat).
func _resolve_and_advance(game: Node, run: Node) -> bool:
	var btn: Button = game.get("_resolve_btn") as Button
	if btn == null or not is_instance_valid(btn):
		_fail("bouton Resoudre introuvable (impossible d'avancer au beat suivant)")
		return false
	if btn.disabled:
		_fail("bouton Resoudre DESARME apres la 1re conversion (paire encore complete attendue)")
		return false
	btn.pressed.emit()  # chemin de signal reel (jamais _on_resolve() en direct)
	var dl: int = Time.get_ticks_msec() + int(STEP_TIMEOUT_S * 3.0 * 1000.0)
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game):
			_fail("scene liberee pendant la resolution (impossible de tester le cout croissant)")
			return false
		if bool(run.get("ended")):
			print("[MV] t=%.1f run terminee pendant la resolution (tolere, 2e cout non testable)" % _t())
			return true
		if int(game.get("_state")) == 2 and bool(game.get("_can_advance")):
			break
		var tw: Tween = game.get("_tw") as Tween
		if tw != null and tw.is_valid() and game.has_method("_skip_typewriter"):
			game._skip_typewriter()
		var pact: Node = game.get("_pact_row") as Node
		if pact != null and is_instance_valid(pact):
			for pb in pact.get_children():
				if pb is Button:
					(pb as Button).pressed.emit()
					break
		await process_frame
	if not (is_instance_valid(game) and int(game.get("_state")) == 2 and bool(game.get("_can_advance"))):
		_fail("issue jamais ecrite apres Resoudre (softlock, impossible de tester le cout croissant)")
		return false
	print("[MV] t=%.1f beat resolu, avance au suivant" % _t())
	if game.has_method("_advance_to_next"):
		game._advance_to_next()
	await _pass_draft(game, run)
	if not await _reach_choice(game, run):
		return false
	await _dismiss_pending_pilier_pact(game)
	return true


# Sert un eventuel pacte PILIER (etre/compagnon, planifie par _maybe_intervention en debut de beat)
# qui occuperait deja le slot Z4 a l'ouverture du choix : le refuse (2e bouton, jamais d'engagement
# de Corruption non voulu par la sonde) pour laisser la place a l'offre de conversion testee ensuite.
# _maybe_offer_convert refuse de construire son offre tant qu'un AUTRE pacte occupe le slot
# (_pact_active_pk != "" et != "convert") - sans ce service, l'exercice deviendrait FLAKY selon que
# le RNG de la run planifie ou non une intervention a ce beat precis. No-op si aucun pacte present.
func _dismiss_pending_pilier_pact(game: Node) -> void:
	if not is_instance_valid(game):
		return
	var pk: String = str(game.get("_pact_active_pk"))
	if pk == "" or pk == "convert":
		return
	var pact: Node = game.get("_pact_row") as Node
	if pact == null or not is_instance_valid(pact):
		return
	var buttons: Array = []
	for b in pact.get_children():
		if b is Button:
			buttons.append(b)
	if buttons.is_empty():
		return
	var choice: Button = buttons[1] if buttons.size() >= 2 else buttons[0]  # 2e bouton = Refuser/Garder
	choice.pressed.emit()
	print("[MV] pacte pilier '%s' present au beat, refuse (2e bouton) pour laisser la place a l'exercice" % pk)
	await create_timer(0.3).timeout
