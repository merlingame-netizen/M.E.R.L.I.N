extends SceneTree
## RACONTER UNE PARTIE — le journal complet d'une run, pour la lire et la contrôler.
##
## POURQUOI. `tools/autoplay_run.gd` joue déjà une partie entière dans la vraie scène avec le
## modèle, mais il ne consigne que des jalons techniques (« quête acceptée », « draft passé ») :
## jamais le texte écrit, jamais le geste choisi, jamais les jauges. On pouvait donc prouver que
## le jeu ne plante pas, jamais montrer ce qu'il RACONTE. Cette sonde comble exactement ce trou.
##
## DEUX PHASES, et ce n'est pas un caprice : le choix du sentier se fait ENTRE les deux, par un
## humain qui a lu les trois propositions. Régénérer la sélection en phase B donnerait trois
## autres titres (l'angle est tiré au sort à chaque appel) — on jouerait donc autre chose que ce
## qui a été montré. La phase B RELIT le fichier de la phase A.
##
##   MERLIN_PHASE=selection MERLIN_SELECTION_OUT=/chemin/sel.json  godot --path . --script res://tools/probe_partie_journal.gd
##   MERLIN_PHASE=partie    MERLIN_SELECTION_IN=/chemin/sel.json MERLIN_PICK=1 \
##       MERLIN_JOURNAL_OUT=/chemin/journal.json MERLIN_SHOTS_DIR=/chemin/shots  godot --path . --script ...
##
## RÈGLE tools/ : DUCK-TYPING uniquement. Aucune référence class_name — en mode `--script` le
## harnais compile AVANT l'enregistrement des autoloads, et une réf statique casse tout.

const GAME_SCENE: String = "res://scenes/MerlinGame.tscn"
const NODE_TIMEOUT_MS: int = 15000
const LOAD_TIMEOUT_MS: int = 300000
const SEL_TIMEOUT_MS: int = 300000
const RUN_DEADLINE_S: float = 3000.0   # 12-15 beats, une narration écrite par beat sur CPU
const END_DEADLINE_S: float = 40.0
const SHOTS_MAX: int = 12
# Temps de « réflexion » du joueur entre la pose des cartes et le clic Résoudre. 25 s et non 8
# (mesuré 2026-08-18, partie de 18 beats) : dans une quête longue, l'arc s'écrit en fond entre
# les beats et évince le cache du prompt d'issue — l'issue repart alors à froid (~87 s), et la
# fenêtre 8 s de pose + 70 s de sustain la coupait à 9 s près, beat après beat. Un humain LIT la
# narration avant de poser (~20-40 s) : 25 s est la pose représentative, pas un maquillage — le
# harnais à 8 s jouait plus vite qu'aucun joueur réel.
const POSE_S: float = 25.0
# Temps de lecture de l'issue affichée, avant d'avancer au beat suivant.
const LECTURE_S: float = 18.0

var _journal: Dictionary = {}
var _shots_dir: String = ""
var _shots: int = 0
var _pick: int = 0


func _init() -> void:
	_main()


func _await_node(path: String, max_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	var n: Node = root.get_node_or_null(path)
	while n == null and (Time.get_ticks_msec() - t0) < max_ms:
		await create_timer(0.05).timeout
		n = root.get_node_or_null(path)
	return n


func _ecrire(chemin: String, contenu: String) -> void:
	if chemin == "":
		return
	var f: FileAccess = FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_string(contenu)
		f.close()
	else:
		push_warning("[JOURNAL] écriture impossible : %s" % chemin)


# Capture nommée. Plafonnée : au-delà d'une douzaine d'images le document devient un diaporama
# illisible, et c'est un compte rendu qu'on veut, pas un film.
func _cliche(nom: String) -> void:
	if _shots_dir == "" or _shots >= SHOTS_MAX:
		return
	await process_frame
	await process_frame
	var tex: Texture2D = root.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	_shots += 1
	var fichier: String = "%s/%02d_%s.png" % [_shots_dir, _shots, nom]
	if img.save_png(fichier) == OK:
		var liste: Array = _journal.get("cliches", [])
		liste.append({"nom": nom, "fichier": fichier})
		_journal["cliches"] = liste
		print("[JOURNAL] cliché %s" % fichier)


func _attendre_moteur(mn: Node) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not mn.is_ready() and (Time.get_ticks_msec() - t0) < LOAD_TIMEOUT_MS:
		if mn.has_method("boot_error") and str(mn.boot_error()) != "":
			print("[JOURNAL] moteur indisponible : %s" % str(mn.boot_error()))
			return false
		await create_timer(0.25).timeout
	if not mn.is_ready():
		print("[JOURNAL] modèle jamais chargé")
		return false
	print("[JOURNAL] modèle prêt en %.1f s" % [(Time.get_ticks_msec() - t0) / 1000.0])
	return true


func _main() -> void:
	await process_frame
	DisplayServer.window_set_title("MERLIN — JOURNAL DE PARTIE (ne pas fermer)")
	var phase: String = OS.get_environment("MERLIN_PHASE")
	if phase == "":
		phase = "selection"
	_shots_dir = OS.get_environment("MERLIN_SHOTS_DIR")

	var mn: Node = await _await_node("MerlinNative", NODE_TIMEOUT_MS)
	var sc: Node = await _await_node("MerlinScenario", NODE_TIMEOUT_MS)
	var run: Node = await _await_node("MerlinRun", NODE_TIMEOUT_MS)
	if mn == null or sc == null or run == null:
		print("[JOURNAL] autoloads absents")
		quit(2)
		return

	var biome: String = OS.get_environment("MERLIN_BIOME")
	if biome == "":
		biome = "foret"
	run.biome = biome

	if not await _attendre_moteur(mn):
		quit(3)
		return

	if phase == "selection":
		await _phase_selection(sc, run, biome)
	else:
		await _phase_partie(sc, run, biome)


# --- PHASE A : les trois sentiers, par le chemin exact du joueur -----------------------------
func _phase_selection(sc: Node, _run: Node, biome: String) -> void:
	var t0: int = Time.get_ticks_msec()
	sc.invalidate_selection()
	sc.warmup_and_prefetch_selection()
	while not sc.is_selection_ready() and not sc.is_selection_failed() \
			and (Time.get_ticks_msec() - t0) < SEL_TIMEOUT_MS:
		sc.ensure_selection_prefetch()
		await create_timer(0.25).timeout
	var d: Dictionary = {
		"biome": biome, "mur_ms": Time.get_ticks_msec() - t0,
		"t": Time.get_datetime_string_from_system(true), "sentiers": [],
	}
	if not sc.is_selection_ready():
		d["ok"] = false
		d["motif"] = str(sc.selection_motif()) if sc.has_method("selection_motif") else "délai dépassé"
		_ecrire(OS.get_environment("MERLIN_SELECTION_OUT"), JSON.stringify(d))
		print("[SELECTION_JSON] " + JSON.stringify(d))
		quit(1)
		return
	var sels: Array = await sc.take_selection()
	for s in sels:
		var e: Dictionary = s
		(d["sentiers"] as Array).append({"titre": str(e.get("title", "")), "pitch": str(e.get("pitch", ""))})
	d["ok"] = (d["sentiers"] as Array).size() >= 3
	_ecrire(OS.get_environment("MERLIN_SELECTION_OUT"), JSON.stringify(d))
	print("[SELECTION_JSON] " + JSON.stringify(d))
	quit(0 if bool(d["ok"]) else 1)


# --- PHASE B : la partie, beat par beat ------------------------------------------------------
func _phase_partie(sc: Node, run: Node, biome: String) -> void:
	var brut: String = FileAccess.get_file_as_string(OS.get_environment("MERLIN_SELECTION_IN"))
	var sel: Variant = JSON.parse_string(brut)
	if not (sel is Dictionary) or not ((sel as Dictionary).get("sentiers", []) is Array):
		print("[JOURNAL] sélection illisible — la phase A doit tourner d'abord")
		quit(2)
		return
	var sentiers: Array = (sel as Dictionary)["sentiers"]
	_pick = clampi(int(OS.get_environment("MERLIN_PICK")), 0, maxi(sentiers.size() - 1, 0))
	var choisi: Dictionary = sentiers[_pick]

	_journal = {
		"t": Time.get_datetime_string_from_system(true), "biome": biome,
		"sentiers": sentiers, "pick": _pick, "choisi": choisi,
		"motif_du_choix": OS.get_environment("MERLIN_PICK_RAISON"),
		"beats": [], "cliches": [], "incidents": [], "etals": [], "ok": false,
	}
	_sauver()

	run.clear_save()
	var skel: Dictionary = sc.build_skeleton(str(choisi.get("titre", "")), str(choisi.get("pitch", "")))
	run.new_run(skel)
	# L'OUVERTURE EST ATTENDUE : la scène de jeu ne charge pas tant que le modèle n'a pas écrit les
	# premières scènes. Sans ça la résolution du beat 1 prend le moteur mono-place et l'arc ne
	# l'obtient plus jamais — mesuré, « 0 scène(s) » à chaque essai.
	print("[JOURNAL] ouverture en cours d'écriture…")
	await sc.prepare_arc_ouverture(skel)
	sc.prepare_arc(skel)   # le reste de l'arc, en fond
	_journal["squelette"] = {
		"titre": str(skel.get("title", "")), "synopsis": str(skel.get("pitch", "")),
		"beats_prevus": (skel.get("beats", []) as Array).size(),
	}
	_sauver()
	print("[JOURNAL] sentier choisi (%d) : %s" % [_pick, str(choisi.get("titre", ""))])

	change_scene_to_file(GAME_SCENE)
	await create_timer(1.5).timeout
	var game: Node = current_scene
	if game == null or not str(game.scene_file_path).ends_with("MerlinGame.tscn"):
		_journal["erreur"] = "MerlinGame non chargée"
		_sauver()
		quit(1)
		return

	# Intro : le pop-up de quête, puis « Accepter » — le geste du joueur.
	if await _jusqua(func() -> bool: return not is_instance_valid(game) or game._intro_open, 90.0):
		if is_instance_valid(game) and game._intro_open:
			await _cliche("intro")
			_journal["intro"] = _texte_intro(game)
			# La provenance de l'intro est un fait de contrôle : légende du modèle, ou cadrage en
			# dur servi en secours. Le document l'affiche — même contrat que pour les issues.
			_journal["intro_du_modele"] = bool(sc.intro_du_modele()) if sc.has_method("intro_du_modele") else false
			game._accept_quest()
			print("[JOURNAL] quête acceptée")
			_sauver()

	await _boucle(game, run)

	# La fin : on attend MerlinEnd, mais son absence n'annule pas le journal — une partie coupée
	# doit laisser ce qu'elle a vécu.
	var fin_ok: bool = await _jusqua(func() -> bool:
		return current_scene != null and str(current_scene.name) == "MerlinEnd", END_DEADLINE_S)
	if fin_ok:
		await _cliche("fin")
	_journal["fin"] = {
		"atteinte": fin_ok, "type": str(run.end_type), "beats_joues": int(run.beat_index),
		"integrite": int(run.integrite), "corruption": int(run.corruption),
		"resume": str(run.summary),
		"faits_marquants": run.faits_marquants, "choix_cles": run.choix_cles,
		"pnj_rencontres": run.pnj_rencontres,
		"talent": run.talent, "usage_verbes": run.verb_usage,
	}
	_journal["ok"] = (_journal["beats"] as Array).size() > 0
	_sauver()
	print("[JOURNAL] terminé — %d beat(s), fin '%s' (PV=%d Corr=%d)"
			% [(_journal["beats"] as Array).size(), str(run.end_type),
				int(run.integrite), int(run.corruption)])
	quit(0 if bool(_journal["ok"]) else 1)


func _texte_intro(game: Node) -> String:
	# Duck-typing : on prend le premier RichTextLabel non vide du pop-up. Un accès nommé casserait
	# au moindre renommage, et l'intro n'est pas assez importante pour faire échouer un journal.
	var trouve: String = ""
	var pile: Array = [game]
	while not pile.is_empty() and trouve == "":
		var n: Node = pile.pop_back()
		if n is RichTextLabel and str((n as RichTextLabel).text).length() > 80:
			trouve = str((n as RichTextLabel).text)
		for c in n.get_children():
			pile.append(c)
	return trouve


# La boucle maîtresse, reprise de tools/autoplay_run.gd (mêmes branches, même duck-typing), avec
# le JOURNAL greffé dessus : à l'entrée d'un beat on note la situation, au geste on note le choix,
# à la résolution on note le degré et les jauges.
func _boucle(game: Node, run: Node) -> void:
	var beat_vu: int = -1
	var geste: int = 0
	var dl: int = Time.get_ticks_msec() + int(RUN_DEADLINE_S * 1000.0)
	while Time.get_ticks_msec() < dl:
		if not is_instance_valid(game):
			break
		if run.ended:
			break
		if game._interstitial_open:
			if game._tw != null and game._tw.is_valid():
				game._skip_typewriter()
			elif game._can_advance:
				game._end_interstitial()
			else:
				game._interstitial_skip = true
			await process_frame
			continue
		if game._tuto_prompt_row != null and is_instance_valid(game._tuto_prompt_row):
			await create_timer(0.3).timeout
			if is_instance_valid(game) and game._tuto_prompt_row != null \
					and is_instance_valid(game._tuto_prompt_row):
				var tb: Array = []
				for b in game._tuto_prompt_row.get_children():
					if b is Button:
						tb.append(b)
				if tb.size() >= 2:
					(tb[1] as Button).pressed.emit()
					_incident("guide de Merlin refusé")
			await process_frame
			continue
		if game._merchant_active:
			# v34 — l'étal du colporteur : politique d'achat du harnais + journal (offres, bourse).
			await create_timer(0.4).timeout
			if is_instance_valid(game) and game._merchant_active:
				await _visiter_etal(game, run)
			await process_frame
			continue
		if game._draft_active:
			await create_timer(0.4).timeout
			if is_instance_valid(game) and game._draft_active:
				var cv: Node = _trouver_carte(game._hand_box)
				if cv != null:
					game._on_draft_card(cv.card)
					if not (game._pending_graft as Dictionary).is_empty():
						await create_timer(0.3).timeout
						if is_instance_valid(game) and game._draft_active:
							for a in run.actions:
								if (a.get("grafts") as Array).size() < int(run.MAX_GRAFTS_PER_ACTION):
									game._on_action_tile(a)
									if game._draft_done_flag:
										_incident("greffe « %s » posée sur %s"
												% [str(cv.card.get("card_name")), str(a.get("card_name"))])
									break
				else:
					game._on_draft_skip()
					if game._draft_done_flag:
						_incident("draft passé")
			await process_frame
			continue
		if game._tw != null and game._tw.is_valid():
			game._skip_typewriter()
			await process_frame
			continue
		if game._pact_row != null and is_instance_valid(game._pact_row):
			await create_timer(0.3).timeout
			if is_instance_valid(game) and game._pact_row != null and is_instance_valid(game._pact_row):
				var pb: Array = []
				for b in game._pact_row.get_children():
					if b is Button:
						pb.append(b)
				if not pb.is_empty():
					(pb[0] as Button).pressed.emit()
					_incident("pacte : « %s »" % str((pb[0] as Button).text))
			await process_frame
			continue

		if game._state == 1:
			# ENTRÉE DU BEAT : la situation vient d'être écrite, on la fige avant tout geste.
			if int(run.beat_index) != beat_vu and not (game._current_situation as Dictionary).is_empty():
				beat_vu = int(run.beat_index)
				await _noter_entree(game, run, beat_vu)
			if game._choice_open and (run.hand as Array).size() >= 1:
				var acts: Array = run.actions
				if game._selected_action == null and not acts.is_empty():
					game._on_action_tile(acts[geste % acts.size()])
				elif game._selected_trait == null:
					game._on_trait_card(run.hand[geste % (run.hand as Array).size()])
					geste += 1
					# UNE POSE QUI DURE. La pré-génération de l'issue démarre quand les deux cartes
					# sont posées ; un harnais qui enchaîne dans la frame suivante ne lui laisse
					# ZÉRO seconde, et le secours est servi à tous les coups. Un joueur regarde sa
					# main, lit, hésite — on lui ressemble ici, sinon on ne mesure pas le jeu.
					await create_timer(POSE_S).timeout
				else:
					_noter_geste(game)
					game._on_resolve()
		elif game._state == 2 and game._can_advance:
			_noter_sortie(run)
			# LECTURE de l'issue avant d'avancer : un humain lit ce que Merlin a écrit (~15-30 s).
			# Avancer dans la frame suivante jetait la scène lookahead en cours d'écriture — la
			# première complète (42,9 s) est arrivée juste après la présentation du beat suivant.
			await create_timer(LECTURE_S).timeout
			if not is_instance_valid(game) or run.ended:
				continue
			game._advance_to_next()
		await process_frame
	_sauver()


func _noter_entree(game: Node, run: Node, idx: int) -> void:
	var situ: Dictionary = game._current_situation
	var mains: Array = []
	for c in run.hand:
		mains.append({"nom": str(c.get("card_name")), "tags": c.get("tags"),
				"rarete": str(c.get("rarity")), "corruption": int(c.get("corruption"))})
	var tuiles: Array = []
	for a in run.actions:
		tuiles.append({"nom": str(a.get("card_name")), "tags": a.get("tags")})
	(_journal["beats"] as Array).append({
		"index": idx + 1,
		"t_pres_ms": Time.get_ticks_msec(),
		"type": str(situ.get("type", "")),
		"provenance": str(situ.get("provenance", "")),
		"narration": str(situ.get("narration", "")),
		"tags_requis": situ.get("required_tags", []),
		"difficulte": int(situ.get("difficulte", 0)),
		"de": int(situ.get("die", 0)),
		"integrite_avant": int(run.integrite), "corruption_avant": int(run.corruption),
		"tuiles": tuiles, "main": mains,
	})
	print("[JOURNAL] beat %d (%s) — %s" % [idx + 1, str(situ.get("type", "")),
			str(situ.get("narration", "")).substr(0, 90)])
	_sauver()
	# Un cliché au premier beat : il montre l'écran de jeu complet, ce qu'aucun texte ne remplace.
	if idx == 0:
		await _cliche("beat_01")


# v34 — POLITIQUE D'ÉTAL du harnais : soigner si l'intégrité fatigue (≤6), purger si la
# corruption monte (≥10), sinon repartir — et tout consigner (offres, bourse, achats).
func _visiter_etal(game: Node, run: Node) -> void:
	var avant: int = int(run.gwenneg)
	var offres: Array = []
	for k in game._merchant_items:
		var it: Dictionary = game._merchant_items[k]
		offres.append("%s:%d" % [str(it.get("kind", "?")), int(it.get("price", 0))])
	var achats: Array = []
	for _essai in range(3):
		var voulu: String = ""
		if int(run.integrite) <= 8 and game._merchant_items.has("shop_heal"):
			voulu = "shop_heal"
		elif int(run.corruption) >= 8 and game._merchant_items.has("shop_purge"):
			voulu = "shop_purge"
		if voulu == "":
			break
		var prix: int = int((game._merchant_items[voulu] as Dictionary).get("price", 0))
		if int(run.gwenneg) < prix:
			break
		var cv: Node = _trouver_carte_id(game._hand_box, voulu)
		if cv == null:
			break
		game._on_draft_card(cv.card)
		achats.append("%s (%d gw)" % [voulu, prix])
		await create_timer(0.3).timeout
		if not is_instance_valid(game) or not game._merchant_active:
			break
	if is_instance_valid(game) and game._merchant_active:
		game._on_draft_skip()
	(_journal["etals"] as Array).append({"apres_beat": (_journal["beats"] as Array).size(),
		"gwenneg_avant": avant, "gwenneg_apres": int(run.gwenneg),
		"offres": offres, "achats": achats})
	_sauver()
	_incident("étal du colporteur : %d offre(s), achats %s, bourse %d→%d"
			% [offres.size(), str(achats), avant, int(run.gwenneg)])


# v34 — retrouve la VUE de carte dont l'id est exactement `id_voulu` (étal : shop_heal...).
func _trouver_carte_id(box: Node, id_voulu: String) -> Node:
	if box == null:
		return null
	for c in box.get_children():
		if not ("card" in c) or c.card == null:
			continue
		var cid: String = ""
		if c.card is Object and ("id" in c.card):
			cid = str(c.card.id)
		elif c.card is Dictionary:
			cid = str((c.card as Dictionary).get("id", ""))
		if cid == id_voulu:
			return c
	return null


func _noter_geste(game: Node) -> void:
	var b: Array = _journal["beats"]
	if b.is_empty():
		return
	var d: Dictionary = b[b.size() - 1]
	if d.has("geste"):
		return
	d["geste"] = {
		"action": str(game._selected_action.get("card_name")),
		"action_tags": game._selected_action.get("tags"),
		"trait": str(game._selected_trait.get("card_name")),
		"trait_tags": game._selected_trait.get("tags"),
	}


func _noter_sortie(run: Node) -> void:
	var b: Array = _journal["beats"]
	if b.is_empty():
		return
	var d: Dictionary = b[b.size() - 1]
	if d.has("degre"):
		return
	d["degre"] = str(run.last_degree)
	# v34 — le TEMPS de chaque beat (frise de la chronique) + les compteurs de la génération
	# d'issue (cerveau, durées) et le verdict mécanique (geste sûr, total/DC).
	d["t_res_ms"] = Time.get_ticks_msec()
	d["duree_beat_s"] = float(int(d["t_res_ms"]) - int(d.get("t_pres_ms", d["t_res_ms"]))) / 1000.0
	var mn_m: Node = root.get_node_or_null("/root/MerlinNative")
	if mn_m != null and mn_m.has_method("last_metrics"):
		d["gen"] = (mn_m.last_metrics() as Dictionary).duplicate()
	var g_res: Node = current_scene
	if g_res != null and ("_pending_res" in g_res) and g_res._pending_res is Dictionary:
		var pres: Dictionary = g_res._pending_res
		d["geste_sur"] = bool(pres.get("geste_sur", false))
		d["total"] = int(pres.get("total", 0))
		d["dc"] = int(pres.get("dc", 0))
	d["resolution"] = str(run.summary)
	# Le beat porte-t-il la marque du banc de secours ? La question décide de la valeur de tout le
	# document : une issue écrite en dur ne dit rien de ce que Merlin sait raconter.
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if sc != null and sc.has_method("secours_consomme"):
		d["secours"] = int(sc.secours_consomme()) > 0
	d["integrite_apres"] = int(run.integrite)
	d["corruption_apres"] = int(run.corruption)
	print("[JOURNAL]   → %s (PV %d→%d, Corr %d→%d)" % [str(run.last_degree),
			int(d.get("integrite_avant", 0)), int(run.integrite),
			int(d.get("corruption_avant", 0)), int(run.corruption)])
	_sauver()


func _incident(quoi: String) -> void:
	(_journal["incidents"] as Array).append({"beat": (_journal["beats"] as Array).size(), "quoi": quoi})
	print("[JOURNAL] incident : %s" % quoi)


# Écrit à CHAQUE étape, pas à la fin : une partie coupée — mort, délai, veilleur — doit laisser
# tout ce qu'elle a déjà vécu. Un journal qui ne survit qu'aux parties parfaites ne sert à rien.
func _sauver() -> void:
	_ecrire(OS.get_environment("MERLIN_JOURNAL_OUT"), JSON.stringify(_journal))


func _jusqua(pred: Callable, timeout_s: float) -> bool:
	var dl: int = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < dl:
		if pred.call():
			return true
		await process_frame
	return pred.call()


func _trouver_carte(node: Node) -> Node:
	if node.has_method("deal_in") and node.get("card") != null:
		return node
	for ch in node.get_children():
		var f: Node = _trouver_carte(ch)
		if f != null:
			return f
	return null
