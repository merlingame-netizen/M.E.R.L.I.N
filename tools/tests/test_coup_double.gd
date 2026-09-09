extends SceneTree
## Épreuve du COUP DOUBLE (09/09, décision de Maxime : action + deux traits, une fois par sentier).
##
##     godot --headless --path . --script res://tools/tests/test_coup_double.gd
##
## CE QU'ELLE VÉRIFIE :
##   LA DIFFICULTÉ MONTE DE 3       même geste, DC 9 → 12.
##   L'ÉCLATANTE ARRIVE DÈS +4      là où le geste simple exige +7.
##   JAMAIS DE GESTE SÛR            un coup double se joue toujours au dé.
##   LES DEUX TRAITS COUVRENT       trois tags couverts à trois cartes.
##   UNE FOIS PAR SENTIER           coup_double_disponible bascule ; new_run le rend.
##   LE TALENT DOUBLE               +2 au lieu de +1 sur une réussite.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _geste(traits: Array) -> Array:
	var g: Array = [{"name": "OBSERVER", "family": "Perception", "tags": ["Sens"]}]
	for t in traits:
		g.append({"tags": t, "rarity": "Commune"})
	return g


func _init() -> void:
	print("=== ÉPREUVE DU COUP DOUBLE ===\n")
	var requis: Array = ["Force", "Agilité", "Endurance"]
	# Un jet de 7, deux tags couverts (+6), difficulté 2 (DC 9).
	var simple: Dictionary = MerlinResolution.resolve(requis, _geste([["Force"], ["Agilité"]]), [], 7, [], 2, 0, 0, "Epreuve", 0, false)
	var double: Dictionary = MerlinResolution.resolve(requis, _geste([["Force"], ["Agilité"]]), [], 7, [], 2, 0, 0, "Epreuve", 0, true)
	_verifier("la difficulté monte de 3", int(double["dc"]) == int(simple["dc"]) + 3,
		"%d → %d" % [int(simple["dc"]), int(double["dc"])])
	_verifier("le résultat porte le drapeau", bool(double.get("coup_double", false)))
	# Marge +4 : simple = réussite, double = éclatante. Jet 7 + 3 tags (+9) = 16 ; DC 12 → +4.
	var trois: Dictionary = MerlinResolution.resolve(requis, _geste([["Force"], ["Agilité", "Endurance"]]), [], 7, [], 2, 0, 0, "Epreuve", 0, true)
	_verifier("trois tags couverts à trois cartes", int(trois["covered_n"]) == 3 if trois.has("covered_n") else int(trois["margin"]) == 4,
		str(trois))
	_verifier("+4 de marge = éclatante au coup double", str(trois["degree"]) == "eclatante" and int(trois["margin"]) == 4,
		"%s / %d" % [str(trois["degree"]), int(trois["margin"])])
	var simple4: Dictionary = MerlinResolution.resolve(requis, _geste([["Force", "Agilité"]]), [], 10, [], 2, 0, 0, "Epreuve", 0, false)
	_verifier("+7 exigés sans coup double (10 + 6 contre 9 = +7 → éclatante ; +4 ne suffirait pas)",
		str(simple4["degree"]) == "eclatante" and int(simple4["margin"]) == 7, "%s / %d" % [str(simple4["degree"]), int(simple4["margin"])])
	var simple5: Dictionary = MerlinResolution.resolve(requis, _geste([["Force", "Agilité"]]), [], 7, [], 2, 0, 0, "Epreuve", 0, false)
	_verifier("+4 de marge sans coup double = réussite seulement", str(simple5["degree"]) == "reussite" and int(simple5["margin"]) == 4,
		"%s / %d" % [str(simple5["degree"]), int(simple5["margin"])])
	# Geste sûr : Exploration, difficulté 1, tout couvert → sûr en simple, au dé en double.
	# (deux tags couverts : 2 + 6 ≥ 6 — un seul tag ne suffit pas au jet minimal, 2 + 3 < 6)
	var sur_s: Dictionary = MerlinResolution.resolve(["Force", "Agilité"], _geste([["Force", "Agilité"]]), [], 5, [], 1, 0, 0, "Exploration", 0, false)
	var sur_d: Dictionary = MerlinResolution.resolve(["Force", "Agilité"], _geste([["Force"], ["Agilité"]]), [], 5, [], 1, 0, 0, "Exploration", 0, true)
	_verifier("le geste simple est sûr", bool(sur_s.get("geste_sur", false)), str(sur_s.get("geste_sur")))
	_verifier("le coup double se joue toujours au dé", not bool(sur_d.get("geste_sur", false)), str(sur_d.get("geste_sur")))
	# Une fois par sentier, et le talent double.
	var run: Node = load("res://scripts/game/merlin_run.gd").new()
	_verifier("disponible au départ", run.coup_double_disponible())
	run.coup_double_utilise = true
	_verifier("plus disponible une fois joué", not run.coup_double_disponible())
	var tp0: int = int(run.talent_points)
	run.gain_talent_points("reussite", true)
	_verifier("le talent double sur le coup", int(run.talent_points) - tp0 == 2 * int(run.TALENT_GAIN_BEAT),
		"%d" % (int(run.talent_points) - tp0))
	run.gain_talent_points("eclatante", false)
	_verifier("le talent simple reste simple", int(run.talent_points) - tp0 == 2 * int(run.TALENT_GAIN_BEAT) + int(run.TALENT_GAIN_ECLATANTE))
	run.free()
	print("\n%s" % ("ÉPREUVE PASSÉE (0 échec)" if _rates == 0 else "ÉPREUVE RATÉE (%d échec(s))" % _rates))
	quit(0 if _rates == 0 else 1)
