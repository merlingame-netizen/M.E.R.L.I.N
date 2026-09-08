extends SceneTree
## Épreuve de l'arc troué : une tranche perdue ne coûte que ses beats, et rien ne se décale.
##
##     godot --headless --path . --script res://tools/tests/test_arc.gd
##
## POURQUOI ELLE EXISTE. L'arc narratif s'écrit par tranches de quatre beats. Jusqu'au 08/09, une
## tranche abandonnée faisait un `break` : toutes les suivantes mouraient avec elle. La nuit du
## 08/09 a mis ONZE beats sur seize au banc pour une seule tranche manquée — beats 5 à 15, le
## climax seul sauvé parce qu'il lit la dernière entrée de l'arc quelle qu'elle soit.
##
## LA CORRECTION A UN PIÈGE, et c'est lui que cette épreuve garde. En passant à la tranche suivante
## il faut réserver la place des beats perdus dans l'arc — sinon les scènes suivantes REMONTENT
## d'un cran et le beat 9 reçoit la scène écrite pour le beat 5. Un décalage silencieux est pire
## qu'un beat au banc : le banc se voit dans le verdict, le décalage ne se voit nulle part.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	print("=== ÉPREUVE DE L'ARC TROUÉ ===\n")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if sc == null:
		print("  (MerlinScenario absent : épreuve non applicable)")
		_finir()
		return

	# UN ARC AVEC UN TROU AU MILIEU : quatre scènes écrites, quatre places réservées, quatre écrites.
	# C'est exactement ce que la boucle produit quand la deuxième tranche est abandonnée.
	var arc: Array = ["scène un", "scène deux", "scène trois", "scène quatre",
		"", "", "", "",
		"scène neuf", "scène dix", "scène onze", "scène douze"]
	var tags: Array = []
	for i in arc.size():
		tags.append(["Sens", "Savoir"])
	sc._run_thread = {"title": "épreuve", "pitch": "", "last_gist": "", "bridge": "",
		"arc": arc, "arc_tags": tags, "arc_locked": false, "arc_du_modele": true,
		"intro_legende": "", "faction": "", "pilier": "", "pilier2": "", "pnj_recog": false}

	var vus: Array = []
	for n in [1, 2, 5, 6, 9, 12]:
		var beat: Dictionary = {"n": n, "qn": n, "qtotal": 12, "quest": 0,
			"quest_title": "épreuve", "type": "Exploration", "difficulte": 2}
		var situ: Dictionary = sc.build_situation(beat)
		vus.append({"n": n, "prov": str(situ.get("provenance", "")),
			"texte": str(situ.get("narration", ""))})

	# LES QUATRE BEATS PERDUS, ET EUX SEULS, VONT AU SECOURS.
	var au_banc: Array = []
	for v in vus:
		if str((v as Dictionary)["prov"]) == "secours":
			au_banc.append(int((v as Dictionary)["n"]))
	_verifier("seuls les beats de la tranche perdue vont au secours", au_banc == [5, 6], str(au_banc))

	# RIEN NE SE DÉCALE : le beat 9 lit la scène du beat 9, pas celle du beat 5.
	for attendu in [[1, "scène un"], [2, "scène deux"], [9, "scène neuf"], [12, "scène douze"]]:
		var n: int = int((attendu as Array)[0])
		var texte: String = str((attendu as Array)[1])
		var trouve: Dictionary = {}
		for v in vus:
			if int((v as Dictionary)["n"]) == n:
				trouve = v
		_verifier("le beat %d lit sa propre scène" % n,
			str(trouve.get("texte", "")).contains(texte),
			"« %s »" % str(trouve.get("texte", "")).substr(0, 50))

	# LA PROVENANCE DIT LA VÉRITÉ : ce qui vient de l'arc le dit, ce qui n'en vient pas aussi.
	var de_l_arc: int = 0
	for v in vus:
		if str((v as Dictionary)["prov"]) == "arc":
			de_l_arc += 1
	_verifier("quatre beats sur six viennent de l'arc", de_l_arc == 4, "%d" % de_l_arc)

	# LE COMPTEUR D'ABANDONS EXISTE ET VAUT DEUX : à un, on retrouverait le comportement d'avant.
	_verifier("on ne renonce qu'après deux abandons de suite",
		int(sc.ARC_ABANDONS_MAX) == 2, "%d" % int(sc.ARC_ABANDONS_MAX))
	_verifier("une tranche fait quatre beats", int(sc.ARC_TRANCHE) == 4, "%d" % int(sc.ARC_TRANCHE))

	_finir()


func _finir() -> void:
	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)
