extends SceneTree
## probe_economie_ui.gd — sonde headless self-test des chemins INTERACTIFS de la Vague Economie V1
## (marchand aux beats Rencontre, achats Gwenneg/Promesse, reclamation de dette, priorite des
## slots Rencontre, race de swap sur la zone marchande). La vague est implementee mais SEULS ses
## chemins statiques etaient verifies (lecture) : cette sonde EXERCE les vrais chemins de signaux
## (card_clicked / action_clicked / pressed), le meme profil de risque que le softlock R159
## (chemin interactif jamais clique en conditions reelles).
##
## Modeles suivis : tools/probe_first_choice.gd (chemins de signaux reels, duck-typing, watchdogs
## bornes par Time.get_ticks_msec()) et tools/probe_swapzone_test.gd (mecanisme MerlinVisual.swap_zone,
## classe de bug R148 : un swap relance qui tue le tween precedent NE DOIT jamais perdre son build).
##
## Portee couverte EN CONDITIONS REELLES (via _advance_to_next/_resolve_btn/signaux) :
##   1. Ouverture/fermeture de la vitrine sur un vrai beat Rencontre + reouverture du choix suivant.
##   2. Achat en Gwenneg (1 geste) : bourse debitee, vitrine refermee.
##   3. Achat refuse faute de Gwenneg : zero mutation d'etat, vitrine reste ouverte.
##   4bis. Cablage REEL de l'avantage : la charge armee par l'item 4 est CONSOMMEE (compteur
##      coup_de_pouce_exercised) exactement au beat suivant resolu (chantier 1, 2026-07-25).
##   5. Beat de reclamation : refus explicite (dette soldee, Corruption +2, le jeu continue).
##   6. Priorite : le beat de reclamation n'ouvre NI offrande de pilier NI vitrine (une seule prise).
## Portee couverte en APPEL DIRECT ISOLE (documente explicitement, cf. rapport) :
##   4. Achat en Promesse (2 gestes, annulation "Garder" ET acceptation) : la spec ne garantit qu'UN
##      beat Rencontre naturel tot dans une petite quete (deja consomme par le test 2/3) ; on rouvre
##      la vitrine via un appel direct a _present_merchant_stall() (fonction REELLE du jeu, hors
##      gating du type de beat) pour exercer le Coup de Pouce sans jouer une quete entiere.
##   7. Deux swaps rapproches sur la zone marchande (classe R148/R159) : deux appels non-attendus
##      de _present_merchant_stall() coup sur coup, dans la fenetre de fade-out du swap.
## NON exerce en direct (documente honnetement dans le rapport) : le reglement NORMAL de la dette
## par resolution de cartes (settle_debt) — necessiterait un 2e cycle complet de dette (2e quete,
## le cap Coup de Pouce/quete empeche un raccourci sans rejouer une quete entiere). Verifie par
## lecture statique de merlin_run.gd::settle_debt uniquement.
##
## Duck-typing OBLIGATOIRE (aucune ref class_name du jeu). Sortie : lignes [ECO] ; verdict final
## [ECO][PASS] / [ECO][FAIL]. Exit 0 = pass, 1 = fail. N'ecrit JAMAIS dans user://merlin_run.json
## (sauvegarde et prefs REELS sauvegardes puis restaures, meme contrat que probe_first_choice.gd).
##   Godot --headless --path . --script res://tools/probe_economie_ui.gd

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const STEP_TIMEOUT_S: float = 30.0
const RESOLVE_TIMEOUT_S: float = 90.0
const CHOICE_TIMEOUT_S: float = 60.0

var _t0: int = 0
var _fails: PackedStringArray = []


func _init() -> void:
	_main()


func _t() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[ECO][FAIL] " + msg)


func _ok(msg: String) -> void:
	print("[ECO][OK] t=%.1f %s" % [_t(), msg])


# _flag SAFE : get() d'un champ retire renvoie null -> bool(null) PLANTE (lecon probe_first_choice).
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
	DisplayServer.window_set_title("MERLIN PROBE ECONOMIE UI — NE PAS FERMER")
	print("[ECO] start")

	var save_path: String = "user://merlin_run.json"
	var had_save: bool = FileAccess.file_exists(save_path)
	var save_backup: String = FileAccess.get_file_as_string(save_path) if had_save else ""
	var prefs_path: String = "user://options.cfg"
	var had_prefs: bool = FileAccess.file_exists(prefs_path)
	var prefs_backup: String = FileAccess.get_file_as_string(prefs_path) if had_prefs else ""

	var mv: Script = load("res://scripts/game/merlin_visual.gd")
	if mv != null:
		mv.reduced_motion = false
		mv.tuto_hint_a_done = false
		mv.tuto_hint_b_done = false

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
	print("[ECO] DONE pass=%s fails=%d temps=%ds" % [str(passed), _fails.size(), int(_t())])
	for v in _fails:
		print("[ECO][RECAP] " + v)
	if passed:
		print("[ECO][PASS] chemins interactifs de la Vague Economie V1 : aucun softlock detecte")
	else:
		print("[ECO][FAIL] %d invariant(s) casse(s) — voir RECAP" % _fails.size())
	quit(0 if passed else 1)


func _play(run: Node, sc: Node) -> bool:
	run.clear_save()
	var skel: Dictionary = sc.build_skeleton("Sonde economie", "Un marchand attend au detour du sentier.")
	run.new_run(skel)
	sc.prepare_arc(skel)
	change_scene_to_file(GAME_SCENE)
	await create_timer(1.2).timeout
	var game: Node = current_scene
	if game == null or not game.scene_file_path.ends_with("MerlinGame.tscn"):
		_fail("MerlinGame non chargee")
		return false

	# --- Intro + guide : chemin joueur minimal (decline), identique a probe_first_choice.gd. ---
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_intro_open"), 15.0):
		_fail("intro jamais ouverte")
		return false
	game._accept_quest()
	if not await _until(func() -> bool:
			if not is_instance_valid(game):
				return true
			var row: Node = game.get("_tuto_prompt_row") as Node
			return row != null and is_instance_valid(row), 15.0):
		_fail("proposition de guide jamais affichee")
		return false
	if not is_instance_valid(game):
		_fail("scene liberee avant la proposition de guide")
		return false
	if not _answer_tuto(game, false):
		_fail("bouton 'Je connais le chemin' introuvable")
		return false
	print("[ECO] t=%.1f intro acceptee, guide decline" % _t())

	# Credit large et deliberement isole (documente) : la spec ne credite le Gwenneg qu'au degre
	# resolu ; on force pour pouvoir exercer TOUS les prix (info/soin/greffe) sans jouer 10 beats.
	run.add_gwenneg(200)

	await _pass_draft(game)  # draft d'ouverture (greffe) : hors perimetre de cette sonde, on le passe

	# --- Beat 0 (Exploration, pattern verrouille : QUEST_PATTERNS demarre TOUJOURS par Exploration). ---
	if not await _resolve_current_beat(game, run, "beat0 (Exploration)"):
		return false
	await _pass_draft(game)

	# --- Beats jusqu'a la 1ere Rencontre : chantier 2 (2026-07-25) GARANTIT >= MIN_RENCONTRE_PER_RUN
	# beats "Rencontre" par run, mais PAS leur POSITION (k par quete reste tire) — on resout donc en
	# boucle jusqu'a tomber sur un beat "Rencontre" (cap anti-hang), au lieu de supposer beat n=2. ---
	var guard_r: int = 0
	while str(run.current_beat().get("type", "")) != "Rencontre" and guard_r < 10 \
			and is_instance_valid(game) and not bool(run.get("ended")):
		guard_r += 1
		if not await _resolve_current_beat(game, run, "beat_pre_rencontre#%d" % guard_r):
			return false
		await _pass_draft(game)
	if not is_instance_valid(game) or bool(run.get("ended")):
		_fail("chantier 2 : run terminee avant d'atteindre un beat Rencontre (garantie non observee)")
		return false
	if str(run.current_beat().get("type", "")) != "Rencontre":
		_fail("chantier 2 : aucun beat Rencontre atteint apres %d beats (garantie non observee)" % guard_r)
		return false

	# force pilier_offering_done pour GARANTIR le marchand (isole, documente : sans ce forcage,
	# l'offrande de pilier concurrente aurait pu consommer le slot Rencontre a sa place —
	# comportement legitime du jeu, pas un bug).
	run.pilier_offering_done = true
	if not await _resolve_current_beat(game, run, "beat_rencontre (marchand attendu)"):
		return false

	# === INVARIANT 1 (central, anti-softlock) : la vitrine s'ouvre sur le beat Rencontre. ===
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_merchant_active"), CHOICE_TIMEOUT_S):
		_fail("invariant 1 : vitrine marchande JAMAIS ouverte apres le beat Rencontre")
		return false
	if not is_instance_valid(game):
		_fail("scene liberee a l'ouverture de la vitrine")
		return false
	_ok("vitrine ouverte apres le beat Rencontre (invariant 1, moitie 1/2)")

	# Fenetre courte pour forcer gwenneg=0 AVANT que le timer d'affordabilite (stagger) ne s'evalue,
	# afin que le test 3 (refus faute de fonds) porte sur un etat correctement estompe.
	run.gwenneg = 0
	await create_timer(1.3).timeout  # laisse _apply_merchant_affordability() s'executer avec gwenneg=0

	var heal_view: Node = _merchant_view_for_id(game, "shop_heal")
	if heal_view == null:
		_fail("item 2/3 : carte shop_heal introuvable dans la vitrine")
		return false

	# --- ITEM 3 : achat refuse faute de Gwenneg (estompe visuelle + zero mutation logique). ---
	var hv_ctrl: Control = heal_view as Control
	if hv_ctrl != null and (hv_ctrl.modulate.a >= 0.9 or hv_ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE):
		_fail("item 3 : carte shop_heal PAS estompee a 0 Gwenneg (alpha=%.2f mouse_filter=%d)" % [
			hv_ctrl.modulate.a, hv_ctrl.mouse_filter])
	else:
		_ok("item 3 : carte shop_heal correctement estompee/non cliquable a 0 Gwenneg")
	var gw_before_refus: int = int(run.get("gwenneg"))
	heal_view.emit_signal("card_clicked", heal_view.get("card"))
	await create_timer(0.4).timeout
	if int(run.get("gwenneg")) != gw_before_refus or _flag(game, "_draft_done_flag"):
		_fail("item 3 : mutation d'etat detectee malgre fonds insuffisants (gwenneg %d->%d, draft_done=%s)" % [
			gw_before_refus, int(run.get("gwenneg")), str(_flag(game, "_draft_done_flag"))])
	elif not _flag(game, "_merchant_active"):
		_fail("item 3 : la vitrine s'est refermee alors que l'achat aurait du etre refuse")
	else:
		_ok("item 3 : achat a 0 Gwenneg refuse (zero mutation, vitrine toujours ouverte)")

	# --- ITEM 2 : achat en Gwenneg (1 geste) : credit puis achat -> bourse debitee, vitrine refermee. ---
	run.add_gwenneg(200)
	var gw_before_achat: int = int(run.get("gwenneg"))
	heal_view.emit_signal("card_clicked", heal_view.get("card"))
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_draft_done_flag"), STEP_TIMEOUT_S):
		_fail("item 2 : achat Soin n'a jamais referme la vitrine (draft_done_flag)")
		return false
	if int(run.get("gwenneg")) != gw_before_achat - int(run.HEAL_PRICE):
		_fail("item 2 : bourse mal debitee (avant=%d apres=%d prix=%d)" % [
			gw_before_achat, int(run.get("gwenneg")), int(run.HEAL_PRICE)])
	else:
		_ok("item 2 : achat Soin reussi, bourse debitee de %d Gwenneg" % int(run.HEAL_PRICE))
	if not await _until(func() -> bool: return not is_instance_valid(game) or not _flag(game, "_merchant_active"), STEP_TIMEOUT_S):
		_fail("item 2 : _merchant_active reste vrai apres l'achat (vitrine non refermee)")
		return false

	# === INVARIANT 1 (moitie 2/2) : l'etat de beat repart, le choix suivant se rouvre. ===
	await _pass_draft(game)  # un draft de transition de quete peut suivre la vitrine (spec)
	if not await _until(func() -> bool: return not is_instance_valid(game) or bool(run.get("ended")) or _flag(game, "_choice_open"), CHOICE_TIMEOUT_S):
		_fail("invariant 1 : le choix du beat suivant ne s'est JAMAIS rouvert apres la vitrine")
		return false
	_ok("invariant 1 CONFIRME : vitrine ouverte -> fermee -> choix suivant rouvert (aucun softlock)")

	# === ITEM 4 : achat en Promesse (2 gestes). Appel direct isole (documente en tete de fichier) :
	# le seul beat Rencontre naturel deja atteint est consomme (items 2/3) ; on rouvre la vitrine via
	# _present_merchant_stall() (fonction REELLE) une fois le flux naturel completement retombe. ===
	if not is_instance_valid(game) or bool(run.get("ended")):
		print("[ECO] item4 : run terminee avant le test Coup de Pouce (tolere, run trop courte)")
	else:
		if not await _item4_coup_de_pouce(game, run):
			return false

	# === ITEM 5/6 : beat de reclamation (refus explicite) + priorite (aucun autre slot Rencontre). ===
	if is_instance_valid(game) and not bool(run.get("ended")):
		if not await _item5_6_debt_reclamation(game, run):
			return false
	else:
		print("[ECO] item5/6 : run terminee avant le test de reclamation (tolere)")

	# === ITEM 7 : deux swaps rapproches sur la zone marchande (classe R148/R159). ===
	if is_instance_valid(game):
		await _stress_double_swap(game, run)

	return _fails.is_empty()


func _item4_coup_de_pouce(game: Node, run: Node) -> bool:
	print("[ECO] item4 : reouverture DIRECTE de la vitrine (_present_merchant_stall) pour le Coup de Pouce")
	game._present_merchant_stall()
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_merchant_active"), STEP_TIMEOUT_S):
		_fail("item4 : 2e vitrine (forcee) jamais ouverte")
		return false
	await create_timer(1.3).timeout
	var cdp_view: Node = _merchant_view_for_id(game, "shop_cdp")
	if cdp_view == null:
		_fail("item4 : carte shop_cdp introuvable (Coup de Pouce jamais propose)")
		return false

	# 4a. 1er geste : clic shop_cdp -> vitrine se referme, le pacte s'ouvre (Z4).
	cdp_view.emit_signal("card_clicked", cdp_view.get("card"))
	if not await _until(func() -> bool: return not is_instance_valid(game) or (game.get("_pact_row") as Node) != null, STEP_TIMEOUT_S):
		_fail("item4 : pacte Coup de Pouce jamais arme apres le 1er geste")
		return false
	await create_timer(0.3).timeout

	# 4b. Annulation via "Garder" : AUCUNE dette inscrite, AUCUN Gwenneg debite.
	var gw_before_cancel: int = int(run.get("gwenneg"))
	if not _click_pact_button_prefix(game, "Garder"):
		_fail("item4 : bouton 'Garder' introuvable (annulation)")
		return false
	await create_timer(0.3).timeout
	var debts_cancel: Array = run.get("pending_debts") as Array
	if not debts_cancel.is_empty() or int(run.get("gwenneg")) != gw_before_cancel:
		_fail("item4 : annulation 'Garder' a quand meme mute l'etat (dette=%d gwenneg %d->%d)" % [
			debts_cancel.size(), gw_before_cancel, int(run.get("gwenneg"))])
	else:
		_ok("item4 : annulation 'Garder' -> zero dette, zero debit")

	# 4c. Reprise : 3e vitrine forcee, on ACCEPTE cette fois.
	game._present_merchant_stall()
	if not await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_merchant_active"), STEP_TIMEOUT_S):
		_fail("item4 : 3e vitrine (forcee) jamais ouverte pour l'acceptation")
		return false
	await create_timer(1.3).timeout
	cdp_view = _merchant_view_for_id(game, "shop_cdp")
	if cdp_view == null:
		_fail("item4 : carte shop_cdp introuvable au 2e essai (cap deja consomme ?)")
		return false
	cdp_view.emit_signal("card_clicked", cdp_view.get("card"))
	if not await _until(func() -> bool: return not is_instance_valid(game) or (game.get("_pact_row") as Node) != null, STEP_TIMEOUT_S):
		_fail("item4 : pacte Coup de Pouce jamais arme (2e essai)")
		return false
	await create_timer(0.3).timeout
	var gw_before_accept: int = int(run.get("gwenneg"))
	if not _click_pact_button_prefix(game, "Ceder ton nom"):
		_fail("item4 : bouton d'acceptation du Coup de Pouce introuvable")
		return false
	await create_timer(0.3).timeout
	var debts_accept: Array = run.get("pending_debts") as Array
	if debts_accept.size() != 1:
		_fail("item4 : acceptation n'a pas inscrit UNE dette (size=%d)" % debts_accept.size())
		return false
	if int(run.get("gwenneg")) != gw_before_accept:
		_fail("item4 : acceptation a debite du Gwenneg (%d->%d) alors que c'est une PROMESSE" % [
			gw_before_accept, int(run.get("gwenneg"))])
		return false
	_ok("item4 : Coup de Pouce accepte -> 1 dette inscrite, ZERO Gwenneg debite")
	return true


func _item5_6_debt_reclamation(game: Node, run: Node) -> bool:
	# Force l'echeance de la Promesse (sans attendre 2-4 beats RNG) : mutation d'une dictionnaire
	# de donnees pure, aucun appel de fonction du jeu court-circuite -> _tick_pending_debts() (appelee
	# DANS advance_beat(), au flux NATUREL du prochain beat resolu) fera le reste.
	var debts: Array = run.get("pending_debts") as Array
	if debts.is_empty():
		print("[ECO] item5/6 : aucune dette active (item4 non concluant) -> test de reclamation ignore")
		return true

	# === ITEM 4bis (chantier 1, cablage reel) : la charge Coup de Pouce ARMEE par item4 doit
	# BOOSTER (max(die, face_adv)) puis se CONSOMMER exactement une fois au PROCHAIN beat resolu —
	# precisement celui resolu juste apres (dette forcee a echoir APRES lui, ci-dessous). ===
	var cdp_armed_before: bool = bool(run.get("coup_de_pouce_armed"))
	var cdp_exercised_before: int = int(run.get("coup_de_pouce_exercised"))
	var d: Dictionary = debts[0]
	d["beats_remaining"] = 0
	debts[0] = d
	run.pending_debts = debts

	if _flag(game, "_merchant_active") or _flag(game, "_draft_active"):
		_fail("item5/6 : une vitrine/draft forcee est restee active avant le beat suivant")
		return false

	if not await _resolve_current_beat(game, run, "beat2 (dette programmee a echoir)"):
		return false

	if cdp_armed_before and is_instance_valid(game) and not bool(run.get("ended")):
		if bool(run.get("coup_de_pouce_armed")):
			_fail("item4bis : la charge Coup de Pouce est RESTEE armee apres resolution (jamais consommee)")
		elif int(run.get("coup_de_pouce_exercised")) != cdp_exercised_before + 1:
			_fail("item4bis : compteur coup_de_pouce_exercised non incremente (avant=%d apres=%d)" % [
				cdp_exercised_before, int(run.get("coup_de_pouce_exercised"))])
		else:
			_ok("item4bis : Coup de Pouce EXERCE au beat suivant (consomme exactement 1 fois, compteur verifie)")
	elif not cdp_armed_before:
		print("[ECO] item4bis : charge non armee avant ce beat (item4 non concluant) -> assertion ignoree")
	await _pass_draft(game)  # draft standard (reussite/transition de quete) eventuel apres "beat2" : le passer

	# La mutation cible le PREMIER beat ELIGIBLE (Rencontre/Epreuve) trouve par RECHERCHE GLOBALE en
	# avant (merlin_run._maybe_mutate_debt_reclamation, scan complet des qu'echeance atteinte) — PAS
	# forcement le tout prochain beat : un beat "Exploration"/"Dilemme"/"Climax" de transition n'est
	# jamais eligible et s'intercale normalement (drafts standards tolere via _pass_draft). On avance
	# donc en boucle jusqu'a atteindre le beat DEJA mute (cap anti-hang) ; SEULE la derniere
	# transition (celle qui REVELE le beat de reclamation) doit etre exempte de tout draft/vitrine
	# concurrent (item 6, verifie par _wait_choice_no_priority_violation une fois arrive).
	var guard_d: int = 0
	while str(run.current_beat().get("type", "")) != str(run.DEBT_RECLAMATION_TYPE) and guard_d < 10 \
			and is_instance_valid(game) and not bool(run.get("ended")):
		guard_d += 1
		if not await _resolve_current_beat(game, run, "beat_pre_reclamation#%d" % guard_d):
			return false
		await _pass_draft(game)
	if not is_instance_valid(game) or bool(run.get("ended")):
		print("[ECO] item5/6 : run terminee avant l'ouverture du beat de reclamation (tolere)")
		return true

	# Attend le choix suivant TOUT EN detectant une violation de priorite (item 6) : si un draft/
	# vitrine s'ouvre alors que le beat a mute en reclamation, c'est ferme (anti-hang) et signale.
	if not await _wait_choice_no_priority_violation(game, CHOICE_TIMEOUT_S):
		_fail("item5/6 : le choix suivant ne s'est jamais rouvert (softlock potentiel apres la mutation)")
		return false
	if not is_instance_valid(game) or bool(run.get("ended")):
		print("[ECO] item5/6 : run terminee avant l'ouverture du beat de reclamation (tolere)")
		return true

	var beat_type_now: String = str(run.current_beat().get("type", ""))
	if beat_type_now != str(run.DEBT_RECLAMATION_TYPE):
		_fail("item5 : le beat de reclamation n'a jamais ete atteint apres %d beats (type='%s')" % [guard_d, beat_type_now])
		return false
	_ok("item5/6 : beat mute en reclamation ('%s') apres %d beat(s) intermediaire(s), priorite structurellement respectee" % [beat_type_now, guard_d])

	var btn: Button = game.get("_debt_refuse_btn") as Button
	if btn == null or not is_instance_valid(btn):
		_fail("item5 : bouton 'Refuser' introuvable sur le beat de reclamation")
		return false
	var corr_before: int = int(run.get("corruption"))
	btn.pressed.emit()
	if not await _until(func() -> bool: return not is_instance_valid(game) or bool(run.get("ended")) or (int(game.get("_state")) == 2 and _flag(game, "_can_advance")), RESOLVE_TIMEOUT_S):
		_fail("item5 : SOFTLOCK apres 'Refuser' — issue jamais ecrite (_can_advance jamais pose)")
		return false
	if not is_instance_valid(game) or bool(run.get("ended")):
		print("[ECO] item5 : run terminee juste apres le refus (tolere)")
		return true
	var debts_after: Array = run.get("pending_debts") as Array
	if not debts_after.is_empty():
		_fail("item5 : dette TOUJOURS active apres refus explicite")
	elif int(run.get("corruption")) - corr_before != 2:
		_fail("item5 : Corruption +2 attendue apres refus, delta obtenu=%d" % (int(run.get("corruption")) - corr_before))
	else:
		_ok("item5 : refus explicite -> dette soldee, Corruption +2")

	game._advance_to_next()
	if not await _until(func() -> bool: return not is_instance_valid(game) or bool(run.get("ended")) or _flag(game, "_choice_open") or _flag(game, "_draft_active"), CHOICE_TIMEOUT_S):
		_fail("item5 : le jeu ne CONTINUE PAS apres le refus (aucun etat suivant atteint — softlock)")
	else:
		_ok("item5 : le jeu continue normalement apres le refus explicite")
	return true


# Comme _pass_draft, mais SIGNALE (sans stopper) toute ouverture de draft/vitrine rencontree en
# chemin — utilise UNIQUEMENT sur le beat de reclamation, ou aucun des deux ne doit apparaitre.
func _wait_choice_no_priority_violation(game: Node, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	var flagged: bool = false
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game):
			return true
		if _flag(game, "_merchant_active") or _flag(game, "_draft_active"):
			if not flagged:
				flagged = true
				_fail("item6 : un draft/vitrine s'est ouvert sur le beat de reclamation (priorite violee)")
			if game.has_method("_on_draft_skip"):
				game._on_draft_skip()
		if _flag(game, "_choice_open") or bool((game.get("_state") if is_instance_valid(game) else 0)):
			pass
		if _flag(game, "_choice_open"):
			return true
		await process_frame
	return _flag(game, "_choice_open")


# Deux appels non-attendus de _present_merchant_stall() coup sur coup (fenetre de fade-out du
# swap_zone, classe R148/R159) : verifie l'absence de blocage et la coherence du contenu final.
func _stress_double_swap(game: Node, run: Node) -> void:
	if bool(run.get("ended")):
		print("[ECO] item7 : run terminee, stress swap ignore")
		return
	print("[ECO] item7 : deux swaps rapproches sur la zone marchande (stress R148/R159)")
	game._present_merchant_stall()
	await create_timer(0.05).timeout  # dans la fenetre de fade-out (0.18s) du 1er swap
	game._present_merchant_stall()
	await create_timer(0.8).timeout   # laisse tweens/deal_in du 2e appel se stabiliser
	if not is_instance_valid(game):
		print("[ECO] item7 : scene liberee pendant le stress (tolere)")
		return

	var items: Dictionary = game.get("_merchant_items") as Dictionary
	var hb: Node = game.get("_hand_box")
	var views: int = 0
	var coherent: bool = true
	if hb != null and is_instance_valid(hb):
		for c in hb.get_children():
			var card: Object = c.get("card")
			if card != null:
				views += 1
				if not items.has(str(card.id)):
					coherent = false
	if views == 0:
		_fail("item7 : AUCUNE carte visible apres le double swap (build perdu — classe R148)")
	elif not coherent:
		_fail("item7 : carte(s) visible(s) hors du dernier _merchant_items (contenu incoherent apres double swap)")
	else:
		_ok("item7 : %d carte(s) coherentes visibles apres le double swap rapproche" % views)

	# Fermeture forcee (teardown de sonde, documente) : deverrouille les 2 boucles await paralleles
	# encore en attente d'un pick (aucune carte n'a ete cliquee volontairement dans ce test).
	game.set("_draft_done_flag", true)
	if not await _until(func() -> bool: return not is_instance_valid(game) or not _flag(game, "_merchant_active"), 8.0):
		_fail("item7 : _merchant_active reste bloque a true apres fermeture forcee (softlock potentiel)")
	else:
		_ok("item7 : etat marchand se stabilise (_merchant_active=false) apres le stress")


# Clique le bouton « Guide-moi » (accept) ou « Je connais le chemin » (decline).
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


# Passe un draft (greffe/offrande) s'il est ouvert. No-op sinon. Hors perimetre de cette sonde :
# on ne prend jamais la greffe, on ferme uniquement (le draft de greffe est couvert par probe_draft.gd).
func _pass_draft(game: Node) -> void:
	var saw: bool = await _until(func() -> bool: return not is_instance_valid(game) or _flag(game, "_draft_active"), 6.0)
	if not (saw and is_instance_valid(game) and _flag(game, "_draft_active")):
		return
	await create_timer(0.6).timeout
	var dl: int = Time.get_ticks_msec() + 15000
	while is_instance_valid(game) and _flag(game, "_draft_active") and Time.get_ticks_msec() < dl:
		if game.has_method("_on_draft_skip"):
			game._on_draft_skip()
		await create_timer(0.3).timeout
	if is_instance_valid(game) and _flag(game, "_draft_active"):
		_fail("draft impossible a fermer (15s) — softlock potentiel au draft")


# Resolution reelle d'un beat : tuile d'action + carte-trait + Resoudre (chemins de signaux),
# puis _advance_to_next() (meme contrat que probe_first_choice._real_resolution, generalise
# a n'importe quel beat de la boucle, pas seulement le tout premier).
func _resolve_current_beat(game: Node, run: Node, label: String) -> bool:
	if not await _until(func() -> bool: return not is_instance_valid(game) or bool(run.get("ended")) or _flag(game, "_choice_open"), CHOICE_TIMEOUT_S):
		_fail("%s : choix jamais ouvert" % label)
		return false
	if not is_instance_valid(game) or bool(run.get("ended")):
		print("[ECO] %s : run terminee avant resolution (tolere)" % label)
		return true

	var acts: Array = run.get("actions") as Array
	var hand: Array = run.get("hand") as Array
	if acts.is_empty() or hand.is_empty():
		_fail("%s : actions(%d)/main(%d) vides au choix" % [label, acts.size(), hand.size()])
		return false

	var av: Node = _action_view_for(game, acts[0])
	if av != null and av.has_signal("action_clicked"):
		av.emit_signal("action_clicked", acts[0])
	elif game.has_method("_on_action_tile"):
		game._on_action_tile(acts[0])
	await create_timer(0.3).timeout

	var cv: Node = _card_view_in(game.get("_hand_box"), hand[0])
	if cv != null and cv.has_signal("card_clicked"):
		cv.emit_signal("card_clicked", hand[0])
	elif game.has_method("_on_trait_card"):
		game._on_trait_card(hand[0])
	await create_timer(0.3).timeout

	var btn: Button = game.get("_resolve_btn") as Button
	if btn == null or not is_instance_valid(btn):
		_fail("%s : bouton Resoudre introuvable" % label)
		return false
	if btn.disabled:
		_fail("%s : bouton Resoudre DESARME malgre paire complete" % label)
		return false
	btn.pressed.emit()

	var t_res: int = Time.get_ticks_msec()
	while true:
		if not is_instance_valid(game):
			print("[ECO] %s : scene liberee pendant la resolution (tolere)" % label)
			return true
		if bool(run.get("ended")):
			print("[ECO] %s : run terminee pendant la resolution (tolere)" % label)
			return true
		if int(game.get("_state")) == 2 and _flag(game, "_can_advance"):
			game._advance_to_next()
			return true
		var el: float = float(Time.get_ticks_msec() - t_res) / 1000.0
		if el >= RESOLVE_TIMEOUT_S:
			_fail("%s : SOFTLOCK — _can_advance jamais pose %ds apres Resoudre" % [label, int(RESOLVE_TIMEOUT_S)])
			return false
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


func _click_pact_button_prefix(game: Node, prefix: String) -> bool:
	var row: Node = game.get("_pact_row") as Node
	if row == null or not is_instance_valid(row):
		return false
	for ch in row.get_children():
		if ch is Button and str((ch as Button).text).begins_with(prefix):
			(ch as Button).pressed.emit()
			return true
	return false


func _merchant_view_for_id(game: Node, id: String) -> Node:
	return _find_card_view_by_id(game.get("_hand_box"), id)


func _find_card_view_by_id(node: Node, id: String) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	var c: Object = node.get("card")
	if c != null and str(c.id) == id and node.has_signal("card_clicked"):
		return node
	for ch in node.get_children():
		var f: Node = _find_card_view_by_id(ch, id)
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
