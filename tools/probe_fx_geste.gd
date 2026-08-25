extends Control
## Sonde de la SEQUENCE DU GESTE (v46) — fusion -> phrase du geste -> de ou sceau.
##
## POURQUOI ELLE EXISTE. Le parse check ne dit rien d'une animation, et la partie temoin de la VM
## demande le moteur natif (absent hors ARM) plus une demi-heure. Entre les deux il n'y avait RIEN :
## la sequence v46 a ete ecrite, poussee et livree sans avoir jamais tourne. Cette sonde comble
## exactement ce trou — une VRAIE scene (donc les autoloads), sans une ligne de LLM, en ~10 s.
##
## `--script` ne suffit PAS : en mode script les autoloads ne sont pas enregistres (MerlinAudio
## vaut null), la coroutine de MerlinFx meurt en silence sur le premier appel, et l'attente ne
## rend jamais la main. Il faut une scene. C'est pour ca que ce fichier a un .tscn a cote.
##
##   godot --headless --path . res://tools/probe_fx_geste.tscn
##   rc=0 : la phrase s'affiche, se remplit entierement, la mise s'allume, la sequence se termine,
##          la ligne mecanique n'annonce jamais un de qui n'a pas roule, et le mouvement reduit
##          donne la phrase pleine d'emblee.

const RATIO_PLEIN: float = 0.999

var _t0: int = 0
var _fautes: Array = []
var _reduit_vue: bool = false
var _reduit_ratio_min: float = 2.0
var _fantome_texte: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_go()


func _go() -> void:
	await get_tree().process_frame
	var par_verbe: Dictionary = {}
	for a in MerlinCard.make_actions():
		par_verbe[a.card_name] = a
	var par_id: Dictionary = {}
	for c in MerlinCard.starter_traits():
		par_id[c.id] = c

	# Les deux branches de la phase 3 : le vrai jet, et le geste dispense de de (sceau).
	for cas in [
		{"nom": "avec de", "verbe": "OBSERVER", "trait": "pressentiment", "diff": 3, "talent": 0},
		{"nom": "sans jet", "verbe": "COMBATTRE", "trait": "main_de_fer", "diff": 2, "talent": 2},
	]:
		if not par_verbe.has(cas["verbe"]) or not par_id.has(cas["trait"]):
			_fautes.append("carte de test absente : %s / %s" % [cas["verbe"], cas["trait"]])
			continue
		var combo: Array = [par_verbe[cas["verbe"]], par_id[cas["trait"]]]
		var res: Dictionary = MerlinResolution.resolve(["Force", "Instinct"], combo, [], 8,
			[], int(cas["diff"]), int(cas["talent"]), 0, "Epreuve", 0)
		var phrase: String = str(res.get("phrase_geste", ""))
		var mise: String = str(res.get("mise", ""))
		print("--- %s : %s + %s ---" % [cas["nom"], cas["verbe"], par_id[cas["trait"]].card_name])
		print("  phrase : ", phrase)
		print("  mise   : %s (geste_sur=%s, de=%d)" % [mise, str(res["geste_sur"]), int(res["die"])])
		if phrase.strip_edges().is_empty():
			_fautes.append("%s : aucune phrase composee" % cas["nom"])
			continue
		if bool(res["geste_sur"]) != (int(res["die"]) == 0):
			_fautes.append("%s : geste_sur et de se contredisent" % cas["nom"])

		_t0 = Time.get_ticks_msec()
		# `card_views` vide : la sonde ne teste QUE la sequence du geste, pas le vol des cartes.
		# (La phase 2 cree alors un tween sans tweener — bruit connu, sans effet ici.)
		var fx: MerlinFx = MerlinFx.play(self, res, combo, [], func() -> bool: return true)
		_surveiller(fx, phrase, mise, str(cas["nom"]))
		await fx.run()
		print("  sequence complete en %d ms" % (Time.get_ticks_msec() - _t0))
		await get_tree().process_frame

	_verifier_ligne_meca(par_verbe, par_id)
	await _verifier_mouvement_reduit(par_verbe, par_id)
	await _verifier_fantome(par_verbe, par_id)

	if _fautes.is_empty():
		print("SONDE GESTE : OK")
		get_tree().quit(0)
	else:
		for f in _fautes:
			printerr("SONDE GESTE : ", f)
		get_tree().quit(1)


# v46 a change du TEXTE LU PAR LE JOUEUR : un geste sans de ne doit plus annoncer « 2d6 7 »
# (la face de repli), mensonge latent depuis v34 et rendu frequent par la dispense. On appelle la
# vraie methode du jeu sur une instance orpheline — elle ne lit que le dictionnaire de resolution.
func _verifier_ligne_meca(par_verbe: Dictionary, par_id: Dictionary) -> void:
	print("--- ligne mecanique ---")
	var jeu: Node = load("res://scripts/game/merlin_game.gd").new()
	if not jeu.has_method("_build_meca_line"):
		_fautes.append("ligne mecanique : _build_meca_line introuvable")
		jeu.free()
		return
	for cas in [
		{"verbe": "OBSERVER", "trait": "pressentiment", "diff": 3, "talent": 0},
		{"verbe": "COMBATTRE", "trait": "main_de_fer", "diff": 2, "talent": 2},
	]:
		var combo: Array = [par_verbe[cas["verbe"]], par_id[cas["trait"]]]
		var res: Dictionary = MerlinResolution.resolve(["Force", "Instinct"], combo, [], 8,
			[], int(cas["diff"]), int(cas["talent"]), 0, "Epreuve", 0)
		res["meca_verb"] = str(cas["verbe"])
		var ligne: String = str(jeu._build_meca_line(res, str(res["degree"])))
		print("  %s" % ligne)
		if bool(res["geste_sur"]):
			if ligne.contains("2d6"):
				_fautes.append("%s : la ligne annonce un 2d6 alors qu'aucun de n'a roule" % cas["verbe"])
			if not ligne.contains("Sans jet"):
				_fautes.append("%s : la ligne ne dit pas que le geste est sans jet" % cas["verbe"])
		elif not ligne.contains("2d6"):
			_fautes.append("%s : un vrai jet doit annoncer son 2d6" % cas["verbe"])
	jeu.free()


# Accessibilite : en mouvement reduit la phrase ne s'anime pas, elle est PLEINE d'emblee.
# Branche ecrite en v46 et jamais executee jusqu'ici.
func _verifier_mouvement_reduit(par_verbe: Dictionary, par_id: Dictionary) -> void:
	print("--- mouvement reduit ---")
	var avant: bool = MerlinVisual.reduced_motion
	MerlinVisual.reduced_motion = true
	var combo: Array = [par_verbe["PARLER"], par_id["langue_de_miel"]]
	var res: Dictionary = MerlinResolution.resolve(["Empathie"], combo, [], 8, [], 2, 0, 0, "Rencontre", 0)
	var phrase: String = str(res.get("phrase_geste", ""))
	_reduit_vue = false
	_reduit_ratio_min = 2.0
	var fx: MerlinFx = MerlinFx.play(self, res, combo, [], func() -> bool: return true)
	_suivre_reduit(fx, phrase)
	await fx.run()
	MerlinVisual.reduced_motion = avant
	if not _reduit_vue:
		_fautes.append("mouvement reduit : la phrase n'a jamais ete affichee")
	elif _reduit_ratio_min < RATIO_PLEIN:
		_fautes.append("mouvement reduit : la phrase s'anime encore (ratio min %.2f)" % _reduit_ratio_min)
	else:
		print("  phrase pleine des la premiere frame lue — OK")


# ATTENTION : en GDScript une lambda capture les locales par VALEUR. Un compteur ferme dans une
# lambda ne remonte JAMAIS — la sonde se mentirait a elle-meme. D'ou ces deux membres.
func _suivre_reduit(fx: MerlinFx, phrase: String) -> void:
	while is_instance_valid(fx) and fx.is_inside_tree():
		for n in fx.get_children():
			if n is Label and (n as Label).text == phrase:
				_reduit_vue = true
				_reduit_ratio_min = minf(_reduit_ratio_min, (n as Label).visible_ratio)
		await get_tree().process_frame


# v47 — LE FANTOME DE TUILE : quand la tuile d'action est passee a play(), une copie doit
# apparaitre dans le layer (node « FantomeTuile ») et porter le VERBE joue. Un faux Control
# tient lieu de tuile : la sonde n'a pas de HUD.
func _verifier_fantome(par_verbe: Dictionary, par_id: Dictionary) -> void:
	print("--- fantome de tuile ---")
	var faux: Control = Control.new()
	faux.size = Vector2(260.0, 116.0)
	faux.position = Vector2(40.0, 500.0)
	add_child(faux)
	var combo: Array = [par_verbe["OBSERVER"], par_id["regard_percant"]]
	var res: Dictionary = MerlinResolution.resolve(["Sens"], combo, [], 8, [], 2, 0, 0, "Exploration", 0)
	res["meca_verb"] = "OBSERVER"
	_fantome_texte = ""
	var toujours_pret: Callable = func() -> bool: return true
	var fx: MerlinFx = MerlinFx.play(self, res, combo, [], toujours_pret, Callable(), faux)
	_suivre_fantome(fx)
	await fx.run()
	faux.queue_free()
	if _fantome_texte == "":
		_fautes.append("fantome : jamais apparu dans le layer")
	elif _fantome_texte != "OBSERVER":
		_fautes.append("fantome : porte « %s » au lieu du verbe joue" % _fantome_texte)
	else:
		print("  fantome vu, verbe « %s » — OK" % _fantome_texte)


# Les compteurs sont des MEMBRES (jamais des locales fermees dans une lambda — capture par
# valeur). Suit le node du fantome tant que le layer vit.
func _suivre_fantome(fx: MerlinFx) -> void:
	while is_instance_valid(fx) and fx.is_inside_tree():
		var f: Node = fx.get_node_or_null("FantomeTuile")
		if f != null:
			for c in f.get_children():
				if c is Label:
					_fantome_texte = (c as Label).text
		await get_tree().process_frame


# Suit le Label de la phrase pendant toute la vie du layer : quand il apparait, jusqu'ou il se
# remplit, et si la mise s'allume. Un Label present mais jamais rempli = frappe cassee.
func _surveiller(fx: MerlinFx, phrase: String, mise: String, nom: String) -> void:
	var vu_a: int = -1
	var plein_a: int = -1
	var ratio_max: float = -1.0
	var mise_allumee: bool = false
	while is_instance_valid(fx) and fx.is_inside_tree():
		for n in fx.get_children():
			if not (n is Label):
				continue
			var l: Label = n
			if l.text == phrase:
				if vu_a < 0:
					vu_a = Time.get_ticks_msec() - _t0
				if l.visible_ratio >= RATIO_PLEIN and plein_a < 0:
					plein_a = Time.get_ticks_msec() - _t0
				ratio_max = maxf(ratio_max, l.visible_ratio)
			elif mise != "" and l.text == mise and l.modulate.a > 0.5:
				mise_allumee = true
		await get_tree().process_frame

	if vu_a < 0:
		_fautes.append("%s : la phrase n'a jamais ete affichee" % nom)
		return
	if ratio_max < RATIO_PLEIN:
		_fautes.append("%s : la phrase n'a jamais fini de s'ecrire (ratio max %.2f)" % [nom, ratio_max])
	if mise != "" and not mise_allumee:
		_fautes.append("%s : la mise ne s'est jamais allumee" % nom)
	print("  phrase a t+%d ms · pleine a t+%d ms · ratio max %.2f · mise allumee=%s"
		% [vu_a, plein_a, ratio_max, str(mise_allumee)])
