extends SceneTree
## Épreuve du sentier écrit : une quête de `data/scenarios/` se charge, se joue, et ses choix coûtent.
##
##     godot --headless --path . --script res://tools/tests/test_sentier.gd
##
## POURQUOI ELLE EXISTE. Les quêtes écrites à la main n'avaient jamais été jouables : seul le
## générateur les lisait, comme exemples pour le modèle. Elles deviennent du contenu (décision du
## 07/09), et trois choses peuvent casser en silence :
##   L'ACCENT. Le corpus écrit « Épreuve », le moteur connaît « Epreuve ». Un type non normalisé
##   rendrait l'Épreuve écrite moins chère que l'Épreuve générée, et le dé s'y dispenserait — la
##   liste blanche de v55 ne la reconnaîtrait pas.
##   LE PRIX. Une quête mal réglée pourrait tuer le Voyageur sur une proposition. La borne vit dans
##   le code, pas dans les données, et elle doit tenir même contre un dictionnaire écrit à la main.
##   LA BOURSE. Payer plus qu'on n'a doit prélever ce qu'on a, jamais descendre sous zéro — c'est le
##   défaut de p74 (bourse à 65 sans un seul événement) pris par l'autre bout.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DU SENTIER ÉCRIT ===\n")

	# ── LE CHARGEUR
	var cles: Array = MerlinSentier.liste()
	_verifier("les quêtes écrites sont listées", cles.size() >= 9, "%d" % cles.size())
	_verifier("le biome se filtre", MerlinSentier.liste_du_biome("falaises").has("le_compte_juste"),
		str(MerlinSentier.liste_du_biome("falaises")))
	_verifier("une clé inconnue ne rend rien, elle ne plante pas", MerlinSentier.charger("nexiste_pas").is_empty())
	_verifier("une clé qui remonte l'arborescence est refusée", MerlinSentier.lire("../../projet").is_empty())

	var s: Dictionary = MerlinSentier.charger("le_compte_juste")
	_verifier("le sentier se charge", not s.is_empty())
	if s.is_empty():
		_finir()
		return
	var beats: Array = s["beats"]
	_verifier("dix beats, dans l'ordre", beats.size() == 10 and int((beats[0] as Dictionary)["n"]) == 1
		and int((beats[9] as Dictionary)["n"]) == 10)
	_verifier("le biome et le titre suivent", str(s["biome"]) == "falaises" and str(s["title"]) == "Le Compte Juste")
	_verifier("la bourse de départ est reprise", int(s["bourse_depart"]) == 14, "%d" % int(s["bourse_depart"]))

	# ── L'ACCENT, le piège nommé dans l'en-tête
	var types: Array = []
	for b in beats:
		types.append(str((b as Dictionary)["type"]))
	_verifier("« Épreuve » est normalisée en « Epreuve »", types.has("Epreuve") and not types.has("Épreuve"),
		str(types))
	_verifier("le moteur connaît tous les types produits",
		_tous_connus(types), str(types))
	_verifier("un type inconnu retombe sur Exploration",
		MerlinSentier.type_normalise("Bal du samedi") == "Exploration")

	# ── LES DIFFICULTÉS, lues dans le DC écrit
	_verifier("le premier beat est doux (difficulté 1)", int((beats[0] as Dictionary)["difficulte"]) == 1)
	_verifier("le climax est dur (difficulté 3)", int((beats[9] as Dictionary)["difficulte"]) == 3)

	# ── LA PROSE EST DÉJÀ LÀ
	var sans_scene: Array = []
	for b in beats:
		if str((b as Dictionary).get("scene_ecrite", "")) == "":
			sans_scene.append(int((b as Dictionary)["n"]))
	_verifier("chaque beat porte sa scène écrite", sans_scene.is_empty(), str(sans_scene))
	var b2: Dictionary = beats[1]
	_verifier("la réplique n'est pas perdue : elle ouvre l'issue",
		str(b2["issue_ecrite"]).begins_with("« Monte-la-lui."), str(b2["issue_ecrite"]).substr(0, 40))

	# ── LES CHOIX
	var choix: Array = []
	for b in beats:
		if MerlinSentier.est_un_choix(b):
			choix.append(int((b as Dictionary)["n"]))
	_verifier("les deux beats de choix sont reconnus", choix == [5, 8], str(choix))
	var props: Array = MerlinSentier.propositions(beats[4])
	_verifier("trois propositions au beat 5", props.size() == 3, "%d" % props.size())
	var sans_prix: Array = []
	for p in props:
		if (p["cout"] as Dictionary).is_empty():
			sans_prix.append(str(p["texte"]))
	_verifier("aucune proposition n'est gratuite", sans_prix.is_empty(), str(sans_prix))
	_verifier("le prix se dit en clair",
		MerlinSentier.cout_en_clair({"integrite": -1}) == "−1 intégrité",
		MerlinSentier.cout_en_clair({"integrite": -1}))
	_verifier("une paire à l'ancienne reste lisible, sans prix",
		MerlinSentier.propositions({"special": {"genre": "choix",
			"options": [["a", "suite a"], ["b", "suite b"]]}}).size() == 2)

	# ── LA BORNE, contre une quête mal réglée
	var abusif: Dictionary = MerlinSentier.cout_borne({"integrite": 99, "corruption": 99, "gwenneg": 99})
	_verifier("l'intégrité ne coûte jamais plus de 2", int(abusif["integrite"]) == -2, str(abusif))
	_verifier("la corruption ne coûte jamais plus de 2", int(abusif["corruption"]) == 2)
	_verifier("le gwenneg ne coûte jamais plus de 6", int(abusif["gwenneg"]) == -6)
	_verifier("un coût vide reste vide", MerlinSentier.cout_borne({}).is_empty())
	_verifier("un coût qui n'est pas un dictionnaire ne plante pas",
		MerlinSentier.cout_borne("beaucoup").is_empty())

	# ── LE PAIEMENT, dans une vraie partie
	var run: Node = load("res://scripts/game/merlin_run.gd").new()
	run.new_run(s)
	_verifier("la traversée ouvre avec la bourse écrite", int(run.gwenneg) == 14, "%d" % int(run.gwenneg))
	var vierge: Node = load("res://scripts/game/merlin_run.gd").new()
	vierge.new_run({"title": "x", "beats": [{"n": 1, "type": "Exploration"}]})
	_verifier("une quête sans bourse écrite ouvre à zéro", int(vierge.gwenneg) == 0, "%d" % int(vierge.gwenneg))
	run.gwenneg = 14
	var integ0: int = int(run.integrite)
	var paye: Dictionary = run.payer_le_choix({"integrite": 1, "corruption": 1, "gwenneg": 6})
	_verifier("l'intégrité est prélevée", int(run.integrite) == integ0 - 1, "%d" % int(run.integrite))
	_verifier("la corruption monte", int(run.corruption) == 1, "%d" % int(run.corruption))
	_verifier("la bourse paie", int(run.gwenneg) == 8, "%d" % int(run.gwenneg))
	_verifier("le reçu dit ce qui a été prélevé", int(paye["gwenneg"]) == -6 and int(paye["integrite"]) == -1,
		str(paye))

	# UNE BOURSE TROP COURTE PAIE CE QU'ELLE A, et le reçu le dit. Descendre sous zéro ferait de la
	# bourse un compteur signé, et l'étal accepterait des achats impossibles.
	run.gwenneg = 3
	var court: Dictionary = run.payer_le_choix({"gwenneg": 6})
	_verifier("une bourse trop courte ne passe pas sous zéro", int(run.gwenneg) == 0, "%d" % int(run.gwenneg))
	_verifier("et le reçu dit ce qui a vraiment été pris", int(court["gwenneg"]) == -3, str(court))

	# UN COÛT ABUSIF PASSÉ EN DIRECT reste borné : la borne vit dans le code, pas dans les données.
	run.integrite = 10
	run.payer_le_choix({"integrite": 99})
	_verifier("un coût abusif est borné même hors du chargeur", int(run.integrite) == 8,
		"%d" % int(run.integrite))
	run.integrite = 1
	run.payer_le_choix({"integrite": 2})
	_verifier("l'intégrité ne descend pas sous zéro", int(run.integrite) == 0, "%d" % int(run.integrite))

	# ── LA RUNE LAISSÉE QUITTE LA TRAVERSÉE, pas seulement la main
	#
	# LE NOM EST CELUI DU JEU. La bible nomme dix runes (La Patience, La Franchise…), le code en
	# implémente seize sous d'autres noms (Le Regard Perçant, Le Cœur Franc…), et le corpus était
	# écrit dans le vocabulaire de la bible : un coût nommé « La Franchise » ne trouvait aucune
	# carte et ne prélevait rien, en silence. Maxime a tranché le 07/09 : le jeu gagne, le corpus
	# sera réécrit. L'épreuve emploie donc le nom réel, et vérifie qu'un nom inconnu ne ment pas.
	var run2: Node = load("res://scripts/game/merlin_run.gd").new()
	run2.new_run(s)
	var avant: int = _compter_rune(run2, "Le Cœur Franc")
	var recu: Dictionary = run2.payer_le_choix({"rune": "Le Cœur Franc"})
	_verifier("Le Cœur Franc était dans la traversée", avant > 0, "%d" % avant)
	# LE REÇU REND LE NOM QUE LE JOUEUR VOIT. La carte s'appelle « Le Cœur Franc » dans les données
	# et « Droiture » en haut de la carte : dire « vous laissez Le Cœur Franc » nommerait une chose
	# introuvable à l'écran. Vu à la capture du 08/09, où les cartes affichent Coutume et Adresse.
	_verifier("le reçu nomme la carte comme le joueur la voit",
		str(recu.get("rune", "")) == "Droiture", str(recu))
	var run3: Node = load("res://scripts/game/merlin_run.gd").new()
	run3.new_run(s)
	_verifier("le nom affiché ouvre la même porte",
		str(run3.payer_le_choix({"rune": "Droiture"}).get("rune", "")) == "Droiture")
	var run4: Node = load("res://scripts/game/merlin_run.gd").new()
	run4.new_run(s)
	_verifier("le nom de rune celte aussi",
		str(run4.payer_le_choix({"rune": "Gwiren"}).get("rune", "")) == "Droiture")
	_verifier("il ne revient ni en main, ni au paquet, ni à la défausse",
		_compter_rune(run2, "Le Cœur Franc") == 0, "%d restant(s)" % _compter_rune(run2, "Le Cœur Franc"))
	_verifier("la main reste pleine après le renoncement", (run2.hand as Array).size() == 4,
		"%d rune(s)" % (run2.hand as Array).size())
	_verifier("un nom que le jeu ne connaît pas ne prétend rien prendre",
		not run2.payer_le_choix({"rune": "La Franchise"}).has("rune"))
	_verifier("et il ne retire rien au paquet", (run2.deck as Array).size() + (run2.hand as Array).size()
		+ (run2.discard as Array).size() == 15, "%d cartes" % ((run2.deck as Array).size()
		+ (run2.hand as Array).size() + (run2.discard as Array).size()))

	# ── LE RÉSUMÉ, ce que le menu affiche (08/09) : titre, lieu, longueur, première ligne
	var r: Dictionary = MerlinSentier.resume("le_compte_juste")
	_verifier("le résumé porte le titre", str(r.get("titre", "")) == "Le Compte Juste", str(r))
	_verifier("le lieu est le nom que le joueur connaît",
		str(r.get("biome_nom", "")) == "Les Falaises du Bout-du-Monde", str(r.get("biome_nom", "")))
	_verifier("la longueur est comptée", int(r.get("beats", 0)) == 10, "%d" % int(r.get("beats", 0)))
	_verifier("l'ouverture est la première ligne du préambule, pas plus",
		str(r.get("ouverture", "")).begins_with("La terre s'arrête net") and not str(r.get("ouverture", "")).contains("\n"))
	_verifier("un sentier illisible n'a pas de résumé", MerlinSentier.resume("nexiste_pas").is_empty())
	_verifier("un biome inconnu rend son identifiant, pas une ligne vide",
		MerlinSentier.nom_du_biome("nulle_part") == "nulle_part")
	_verifier("chaque sentier listé a un résumé complet", _tous_resumes(), str(MerlinSentier.liste()))

	_finir()


## Un sentier sans titre, sans lieu ou sans ouverture ferait une ligne de menu à trous.
func _tous_resumes() -> bool:
	for cle in MerlinSentier.liste():
		var r: Dictionary = MerlinSentier.resume(str(cle))
		if r.is_empty() or str(r.get("titre", "")) == "" or str(r.get("biome_nom", "")) == "" \
			or int(r.get("beats", 0)) == 0 or str(r.get("ouverture", "")) == "":
			return false
	return true


func _finir() -> void:
	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)


## Le moteur ne connaît que cinq types : tout autre retombe au tier 1 en silence (MerlinResolution
## NATURE_BASE_TIER_BY_TYPE) et échappe à la liste blanche du geste sûr.
func _tous_connus(types: Array) -> bool:
	for t in types:
		if not MerlinResolution.NATURE_BASE_TIER_BY_TYPE.has(str(t)):
			return false
	return true


func _compter_rune(run: Node, nom: String) -> int:
	var n: int = 0
	for lot in [run.hand, run.deck, run.discard]:
		for c in (lot as Array):
			if c is Object and "card_name" in c and str(c.card_name) == nom:
				n += 1
	return n
