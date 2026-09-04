extends SceneTree
## Épreuve de l'économie : l'argent ne vient que d'un événement qui en donne.
##
##     godot --headless --path . --script res://tools/tests/test_economie.gd
##
## POURQUOI ELLE EXISTE. Sur p74, la bourse est passée de 2 à 65 gwenneg en vingt beats sans qu'un
## seul événement en donne, et le Voyageur n'a rien acheté sur onze étals. L'argent s'accumulait
## parce qu'on RÉUSSISSAIT. Maxime a tranché : « l'argent s'amasse sur un monstre, une transaction,
## un trésor, une situation qui donne de l'argent ».
##
## Ce que l'épreuve refuse, et c'est exactement le défaut mesuré : qu'un beat réussi paie tout seul.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DE L'ÉCONOMIE ===\n")
	var run: Node = load("res://scripts/game/merlin_run.gd").new()

	# ── LE DEGRÉ NE PAIE PLUS
	for deg in ["echec", "partiel", "reussite", "eclatante"]:
		_verifier("le degré « %s » ne donne rien" % deg,
			int(run.gwenneg_gain_for_degree(deg)) == 0,
			"%d gwenneg" % int(run.gwenneg_gain_for_degree(deg)))

	# ── LE HASARD NON PLUS. Cent tirages : l'ancien butin tombait sur 60 % des réussites, donc
	#    un seul essai aurait pu passer par chance. Cent, non.
	var total: int = 0
	for i in range(100):
		total += int(run.roll_loot("reussite"))
	_verifier("cent réussites ne donnent rien", total == 0, "%d gwenneg sur 100 tirages" % total)

	# ── UN BEAT QUI DÉCLARE SON BUTIN PAIE, S'IL RÉUSSIT
	var coffre: Dictionary = {"butin": 7}
	_verifier("un butin déclaré tombe sur une réussite",
		int(run.butin_du_beat(coffre, "reussite")) == 7,
		"%d" % int(run.butin_du_beat(coffre, "reussite")))
	_verifier("il tombe aussi sur une éclatante",
		int(run.butin_du_beat(coffre, "eclatante")) == 7)
	# RATER LE COFFRE NE LE VIDE PAS : sans cette règle, un échec paierait comme une réussite et
	# l'argent redeviendrait automatique par un autre chemin.
	_verifier("un partiel ne donne pas le butin",
		int(run.butin_du_beat(coffre, "partiel")) == 0)
	_verifier("un échec ne donne pas le butin",
		int(run.butin_du_beat(coffre, "echec")) == 0)
	_verifier("un beat sans butin ne donne rien, même en éclatante",
		int(run.butin_du_beat({}, "eclatante")) == 0)
	_verifier("un butin négatif ne retire pas d'argent",
		int(run.butin_du_beat({"butin": -5}, "reussite")) == 0)

	# ── LA BOURSE NE BOUGE QUE QUAND ON L'Y POUSSE
	run.gwenneg = 10
	run.add_gwenneg(int(run.butin_du_beat({}, "reussite")))
	_verifier("une réussite sans événement laisse la bourse intacte", int(run.gwenneg) == 10,
		"%d" % int(run.gwenneg))
	_verifier("dépenser plus qu'on n'a est refusé", not bool(run.spend_gwenneg(50)))
	_verifier("et la bourse n'a pas bougé", int(run.gwenneg) == 10, "%d" % int(run.gwenneg))

	# ── CE QUI DONNE ENCORE DE L'ARGENT : la vente. C'est une transaction, donc elle reste.
	run.add_gwenneg(6)
	_verifier("une vente crédite bien la bourse", int(run.gwenneg) == 16, "%d" % int(run.gwenneg))

	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)
