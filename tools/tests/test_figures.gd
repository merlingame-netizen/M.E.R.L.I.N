extends SceneTree
## Épreuve des figures qui se souviennent (09/09, décision de Maxime : « figures persistantes »).
##
##     godot --headless --path . --script res://tools/tests/test_figures.gd
##
## CE QU'ELLE VÉRIFIE :
##   LA DISPOSITION BOUGE AVEC LE GESTE  aide → allié, échec → méfiant, COMBATTRE → toujours plus bas.
##   ELLE EST BORNÉE                     jamais au-delà de ±3.
##   LE PORTRAIT ET LES PROMPTS LISENT   figure_memoire vide pour une figure neuve, pleine ensuite ;
##                                       figures_resume nomme l'être, la disposition et le moment.
##   LA PAROLE OUVRE LA BONNE FIGURE     extraire_parole reconnaît le tempérament en couleur.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DES FIGURES QUI SE SOUVIENNENT ===\n")
	var RunScript: GDScript = load("res://scripts/game/merlin_run.gd")
	var run: Node = RunScript.new()
	_verifier("une figure neuve n'a pas de mémoire", run.figure_memoire("kado") == "")
	_verifier("rien à rappeler au départ", run.figures_resume() == "")
	run.figure_vue("kado", "Kado le Cordier", 2)
	_verifier("vue, pas encore jugée : toujours pas de mémoire", run.figure_memoire("kado") == "",
		run.figure_memoire("kado"))
	var d: int = run.figure_reagit("kado", "reussite", "PARLER", 2)
	_verifier("une réussite en parlant : bien disposé", d == 1 and run.figure_memoire("kado") == "bien disposé · votre aide",
		"%d / %s" % [d, run.figure_memoire("kado")])
	d = run.figure_reagit("kado", "eclatante", "OBSERVER", 4)
	_verifier("une éclatante de plus : allié", d == 3 and RunScript.disposition_label(d) == "allié", str(d))
	d = run.figure_reagit("kado", "eclatante", "AGIR", 5)
	_verifier("bornée à +3", d == 3, str(d))
	var resume: String = run.figures_resume()
	_verifier("le résumé nomme l'être, la disposition et le moment",
		resume.begins_with("Kado le Cordier : allié (votre aide, moment 5)"), resume)
	d = run.figure_reagit("kado", "reussite", "COMBATTRE", 6)
	_verifier("COMBATTRE fait baisser même en réussissant", d == 2 and run.figure_memoire("kado").ends_with("un affrontement"),
		"%d / %s" % [d, run.figure_memoire("kado")])
	run.figure_reagit("lavandiere", "echec", "PARLER", 3)
	_verifier("un échec devant une figure inconnue jusque-là : méfiante",
		run.figure_memoire("lavandiere") == "méfiant · un échec devant elle", run.figure_memoire("lavandiere"))
	for i in 5:
		run.figure_reagit("lavandiere", "echec", "COMBATTRE", 3 + i)
	_verifier("bornée à −3 : hostile", int((run.figures["lavandiere"] as Dictionary)["disposition"]) == -3
		and run.figure_memoire("lavandiere").begins_with("hostile"), run.figure_memoire("lavandiere"))
	_verifier("une figure inconnue ne s'inscrit pas", run.figure_reagit("inconnu", "reussite", "PARLER") == 0
		and not run.figures.has("inconnu"))
	_verifier("le résumé sépare les êtres par un point-virgule", run.figures_resume().count(" ; ") == 1, run.figures_resume())
	# Le tempérament en couleur (portrait)
	_verifier("la menace est rouge", MerlinPortrait.temperament("menaçant") == MerlinVisual.EYE_ANGRY)
	_verifier("la supplique est violette", MerlinPortrait.temperament("suppliante") == MerlinVisual.VIOLET)
	_verifier("la douceur est verte", MerlinPortrait.temperament("soulagé") == MerlinVisual.GREEN)
	_verifier("le reste est d'or", MerlinPortrait.temperament("sec") == MerlinVisual.GOLD)
	run.free()
	print("\n%s" % ("ÉPREUVE PASSÉE (0 échec)" if _rates == 0 else "ÉPREUVE RATÉE (%d échec(s))" % _rates))
	quit(0 if _rates == 0 else 1)
