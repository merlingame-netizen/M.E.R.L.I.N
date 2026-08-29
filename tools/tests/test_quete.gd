extends SceneTree
## Épreuve du squelette de quête, en conditions réelles de moteur.
##
##     godot --headless --path . --script res://tools/tests/test_quete.gd
##
## Elle NE MODIFIE RIEN : aucune écriture dans la chronique, aucun haut fait noté. Elle lit les
## données, exécute les calculs d'avancement et vérifie les invariants qui doivent tenir quel que
## soit l'état du joueur. Un parse check ne prouve que la syntaxe ; ceci prouve que le squelette
## répond.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DU SQUELETTE DE QUÊTE ===\n")

	var diag: Dictionary = MerlinQuete.diagnostic()
	print("DIAGNOSTIC")
	print("  chapitres           : %d" % int(diag.get("chapitres", 0)))
	print("  lieux               : %d" % int(diag.get("lieux", 0)))
	print("  traversées dorsale  : %d" % int(diag.get("traversees_dorsale", 0)))
	print("  lieux cités absents : %s" % str(diag.get("lieux_cites_mais_absents", [])))
	print("  chapitres bloqués faute de code : %s\n" % str(diag.get("chapitres_bloques_faute_de_code", {})))

	print("STRUCTURE")
	_verifier("douze chapitres", int(diag.get("chapitres", 0)) == 12,
		"trouvé %d" % int(diag.get("chapitres", 0)))
	_verifier("douze lieux", int(diag.get("lieux", 0)) == 12,
		"trouvé %d" % int(diag.get("lieux", 0)))
	_verifier("onze traversées de dorsale", int(diag.get("traversees_dorsale", 0)) == 11)
	_verifier("aucun chapitre ne cite un lieu absent",
		(diag.get("lieux_cites_mais_absents", []) as Array).is_empty(),
		str(diag.get("lieux_cites_mais_absents", [])))

	print("\nCATALOGUE DES HAUTS FAITS")
	var cat: Dictionary = MerlinHautsFaits.catalogue()
	var faits: Array = cat.get("hauts_faits", []) as Array
	_verifier("le catalogue se charge", not faits.is_empty())
	var sans_fiche: Array = []
	for n in range(1, 13):
		for v in MerlinHautsFaits.verrous_de(n):
			if MerlinHautsFaits.fiche_de(str(v)).is_empty():
				sans_fiche.append(str(v))
	_verifier("tout verrou de chapitre a sa fiche", sans_fiche.is_empty(), str(sans_fiche))
	_verifier("une clé inconnue est refusée sans planter",
		MerlinHautsFaits.fiche_de("clé_qui_n_existe_pas").is_empty())
	_verifier("un fait inconnu vaut faux", not MerlinHautsFaits.a("clé_qui_n_existe_pas"))

	print("\nAVANCEMENT")
	var av: Dictionary = MerlinQuete.avancement()
	print("  éclats %d/%d · chapitres %d/%d · palier %d « %s »" % [
		int(av.get("eclats", 0)), int(av.get("eclats_total", 0)),
		int(av.get("chapitres_acquis", 0)), int(av.get("chapitres_total", 0)),
		int(av.get("palier_n", 0)), str(av.get("palier_nom", ""))])
	print("  lieux ouverts : %s" % str(av.get("lieux_ouverts", [])))
	print("  chapitre courant : %d — %s (jouable: %s)" % [
		int(av.get("chapitre_courant", 0)), str(av.get("chapitre_courant_titre", "")),
		str(av.get("chapitre_courant_jouable", false))])

	_verifier("le palier de départ est ouvert d'entrée", int(av.get("palier_n", 0)) >= 1)
	_verifier("au moins un lieu est ouvert sans aucun éclat",
		not (av.get("lieux_ouverts", []) as Array).is_empty())
	_verifier("le chapitre courant est le premier non acquis",
		int(av.get("chapitre_courant", 0)) == int(av.get("chapitres_acquis", 0)) + 1
		or int(av.get("chapitre_courant", 0)) == 0)
	_verifier("la fin n'est pas atteignable sans les douze éclats",
		bool(av.get("fin_atteignable", true)) == (int(av.get("eclats", 0)) >= 12))

	print("\nVERROUS, CHAPITRE PAR CHAPITRE")
	var jouables: int = 0
	for n in range(1, 13):
		var c: Dictionary = MerlinQuete.chapitre(n)
		var ok: bool = MerlinQuete.jouable(n)
		if ok:
			jouables += 1
		var raisons: Array = MerlinQuete.pourquoi_bloque(n)
		print("  ch%-3d %-12s %-34s %s" % [n, str(c.get("lieu", "")),
			str(c.get("titre", "")).substr(0, 33),
			"JOUABLE" if ok else str(raisons)])
	_verifier("le chapitre 1 est jouable sur une chronique vierge",
		MerlinQuete.jouable(1) or int(av.get("chapitres_acquis", 0)) > 0,
		str(MerlinQuete.pourquoi_bloque(1)))
	_verifier("tout chapitre non jouable dit pourquoi",
		_tous_expliques(), "un chapitre bloqué sans raison")

	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)


func _tous_expliques() -> bool:
	for n in range(1, 13):
		if not MerlinQuete.jouable(n) and MerlinQuete.pourquoi_bloque(n).is_empty():
			return false
	return true
