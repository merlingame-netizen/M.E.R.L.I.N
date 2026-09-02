extends SceneTree
## Épreuve du journal des chroniques, en conditions réelles de moteur.
##
##     godot --headless --path . --script res://tools/tests/test_journal.gd
##
## Elle ÉCRIT VRAIMENT sur le disque, dans `user://chroniques`, puis nettoie ce qu'elle a créé —
## un test de stockage qui n'écrit pas ne prouve rien du stockage. Elle laisse intactes les
## chroniques qui existaient avant : elle ne supprime que les identifiants qu'elle a fabriqués.
##
## CE QU'ELLE VÉRIFIE, et pourquoi chacun compte :
##   ÉCRITURE AU FIL DE L'EAU  une partie interrompue doit rester lisible jusqu'au dernier beat.
##   RÉSOLUTION APPARIÉE       l'issue rejoint SA scène ; un décalage d'un beat mentirait sur ce
##                             qui a été joué, et c'est invisible à la lecture.
##   DOUBLE RÉSOLUTION         un beat résolu deux fois est une anomalie, pas une mise à jour.
##   INDEX                     la liste rend la plus récente en tête, et compte juste.
##   CLÉ INCONNUE              une lecture qui échoue rend un vide, elle ne plante pas.

var _rates: int = 0
var _crees: Array = []


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DU JOURNAL DES CHRONIQUES ===\n")
	var avant: int = MerlinJournal.liste().size()
	print("chroniques déjà présentes : %d\n" % avant)

	# ── UNE TRAVERSÉE COMPLÈTE
	MerlinJournal.ouvrir("La fin du rite", "foret")
	MerlinJournal.beat_pose(1, "Exploration", "Le Chœur chante à vingt pas.", "arc", 9, 7, 20, 0)
	MerlinJournal.beat_geste("OBSERVER", "La Patience")
	MerlinJournal.beat_resolu("reussite", "Vous restez dans les fougères et vous comptez.", 20, 0)
	MerlinJournal.beat_pose(2, "Rencontre", "Une femme sort du cercle.", "arc", 9, 9, 20, 1)
	MerlinJournal.beat_geste("PARLER", "La Franchise")
	MerlinJournal.beat_resolu("partiel", "Elle vous demande de dégager l'entrée.", 18, 2)
	var ouverte: Array = MerlinJournal.liste()
	# UNE TRAVERSÉE EN COURS EST DÉJÀ LISIBLE. C'est le contraire du premier jet : une partie
	# interrompue restait invisible dans la liste alors que son fichier existait, donc « tout
	# garder » excluait justement les parties qu'on voudrait comprendre.
	_verifier("une traversée EN COURS est déjà à l'index", ouverte.size() == avant + 1,
		"index à %d au lieu de %d" % [ouverte.size(), avant + 1])
	_verifier("une traversée en cours se lit comme interrompue",
		not ouverte.is_empty() and str((ouverte[0] as Dictionary).get("fin", "")) == "",
		str((ouverte[0] as Dictionary).get("fin", "?")) if not ouverte.is_empty() else "vide")

	MerlinJournal.clore("accomplissement", 18, 2, "Le rite s'achève.", ["le nom lu"], ["Aveline"])
	var apres: Array = MerlinJournal.liste()
	_verifier("la clôture ne crée pas une SECONDE ligne", apres.size() == avant + 1,
		"index à %d" % apres.size())
	if apres.is_empty():
		print("\nÉPREUVE ÉCHOUÉE (index vide)")
		quit(1)
		return

	var tete: Dictionary = apres[0]
	_crees.append(str(tete.get("id", "")))
	_verifier("la plus récente est en tête", str(tete.get("titre", "")) == "La fin du rite",
		str(tete.get("titre", "")))
	_verifier("l'index compte les beats", int(tete.get("beats", 0)) == 2,
		"%d beat(s)" % int(tete.get("beats", 0)))
	_verifier("l'index porte la fin", str(tete.get("fin", "")) == "accomplissement",
		str(tete.get("fin", "")))
	_verifier("l'index compte les signes de prose", int(tete.get("signes", 0)) > 80,
		"%d signes" % int(tete.get("signes", 0)))

	# ── LA CHRONIQUE ELLE-MÊME
	var q: Dictionary = MerlinJournal.lire(str(tete.get("id", "")))
	_verifier("la chronique se relit", not q.is_empty())
	var beats: Array = q.get("beats", []) as Array
	_verifier("les deux beats sont là", beats.size() == 2, "%d" % beats.size())
	if beats.size() == 2:
		var b1: Dictionary = beats[0]
		var b2: Dictionary = beats[1]
		# L'APPARIEMENT EST LE CŒUR : une issue rangée sous la mauvaise scène produit une
		# chronique qui se lit bien et qui ment.
		_verifier("l'issue du beat 1 est sous la scène du beat 1",
			str(b1.get("issue", "")).begins_with("Vous restez")
			and str(b1.get("scene", "")).begins_with("Le Chœur"))
		_verifier("l'issue du beat 2 est sous la scène du beat 2",
			str(b2.get("issue", "")).begins_with("Elle vous demande")
			and str(b2.get("scene", "")).begins_with("Une femme"))
		_verifier("le geste posé est gardé", str(b1.get("action", "")) == "OBSERVER"
			and str(b1.get("trait", "")) == "La Patience")
		_verifier("AUCUN beat n'a de geste vide",
			(func() -> bool:
				for x in beats:
					if str((x as Dictionary).get("action", "")) == "":
						return false
				return true).call(),
			"p93 en a chroniqué neuf de suite sans que l'épreuve le voie")
		_verifier("les jauges avant et après sont gardées",
			int(b2.get("integrite_avant", -1)) == 20 and int(b2.get("integrite_apres", -1)) == 18)
	_verifier("la fin est gardée",
		str((q.get("fin", {}) as Dictionary).get("type", "")) == "accomplissement")

	# ── UNE TRAVERSÉE INTERROMPUE : jamais close, mais lisible — c'est tout l'intérêt.
	MerlinJournal.ouvrir("Traversée interrompue", "cairn")
	MerlinJournal.beat_pose(1, "Exploration", "Le cairn se tait.", "arc", 9, 6, 20, 0)
	var apres_interrompue: Array = MerlinJournal.liste()
	_verifier("une traversée interrompue EST lisible dans la liste",
		apres_interrompue.size() == avant + 2, "%d" % apres_interrompue.size())
	_verifier("elle compte déjà son beat joué",
		not apres_interrompue.is_empty()
		and int((apres_interrompue[0] as Dictionary).get("beats", 0)) == 1,
		"%d beat(s)" % int((apres_interrompue[0] as Dictionary).get("beats", 0)))
	_crees.append(str((apres_interrompue[0] as Dictionary).get("id", "")))

	# ── DOUBLE RÉSOLUTION : la seconde ne doit rien écraser.
	MerlinJournal.beat_geste("AGIR", "L'Élan")
	MerlinJournal.beat_resolu("reussite", "PREMIÈRE issue.", 20, 0)
	MerlinJournal.beat_resolu("echec", "SECONDE issue, qui ne doit pas passer.", 5, 9)
	MerlinJournal.clore("mort", 0, 9)
	var l2: Array = MerlinJournal.liste()
	var q2: Dictionary = MerlinJournal.lire(str((l2[0] as Dictionary).get("id", "")))
	var bb: Array = q2.get("beats", []) as Array
	_verifier("une seconde résolution du même beat est refusée",
		not bb.is_empty() and str((bb[0] as Dictionary).get("issue", "")).begins_with("PREMIÈRE"),
		str((bb[0] as Dictionary).get("issue", "")) if not bb.is_empty() else "aucun beat")

	# ── CE QUI NE DOIT PAS PLANTER
	_verifier("une clé inconnue rend un vide", MerlinJournal.lire("clé_qui_n_existe_pas").is_empty())
	_verifier("un identifiant qui remonte les dossiers est refusé",
		MerlinJournal.lire("../options").is_empty())
	MerlinJournal.beat_geste("AGIR", "L'Élan")
	MerlinJournal.beat_resolu("reussite", "hors traversée", 1, 1)
	MerlinJournal.clore("mort", 0, 0)
	_verifier("noter hors traversée ne plante pas et n'indexe rien",
		MerlinJournal.liste().size() == avant + 2, "%d" % MerlinJournal.liste().size())

	_nettoyer(avant)
	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)


## Retire UNIQUEMENT ce que l'épreuve a créé. Effacer le dossier entier détruirait les chroniques
## de vraies parties — un test qui abîme les données qu'il vérifie n'a pas sa place dans un dépôt.
func _nettoyer(avant: int) -> void:
	var d: DirAccess = DirAccess.open(MerlinJournal.DOSSIER)
	if d == null:
		return
	for id in _crees:
		if id != "":
			d.remove("%s.json" % id)
	var lignes: Array = []
	var f: FileAccess = FileAccess.open(MerlinJournal.INDEX, FileAccess.READ)
	if f != null:
		var brut: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(brut) == TYPE_ARRAY:
			for l in (brut as Array):
				if not _crees.has(str((l as Dictionary).get("id", ""))):
					lignes.append(l)
	var g: FileAccess = FileAccess.open(MerlinJournal.INDEX, FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify(lignes, " "))
		g.close()
	print("\nnettoyage : %d chronique(s) de test retirée(s), index remis à %d"
		% [_crees.size(), MerlinJournal.liste().size()])
	if MerlinJournal.liste().size() != avant:
		print("  ATTENTION : l'index ne revient pas à son compte de départ (%d attendu)" % avant)
