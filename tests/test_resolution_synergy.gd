extends RefCounted
## Unit Tests — MerlinResolution, synergie / degré HYBRIDE.
## La cohérence de la COMBINAISON (familles de tags) affine le degré DANS la fourchette
## bornée par la couverture (instantané, déterministe). Demande user 2026-05-28.

const Reso = preload("res://scripts/game/merlin_resolution.gd")


func _card(tags: Array) -> MerlinCard:
	return MerlinCard.make("id_" + str(tags.hash()), "Carte", tags, "évocation")


# Combo cohérent (2 cartes famille Perception) sur couverture PARTIELLE → remonte à réussite.
func test_coherent_combo_upgrades_partial() -> bool:
	var c1: MerlinCard = _card(["Sens", "Savoir"])
	var c2: MerlinCard = _card(["Mémoire", "Savoir"])
	var res: Dictionary = Reso.resolve(["Sens", "Savoir", "Force"], [c1, c2])
	var ok: bool = true
	if int(res.get("synergy", -99)) != 1:
		push_error("Synergie attendue +1 (combo cohérent), obtenu %s" % str(res.get("synergy")))
		ok = false
	elif str(res.get("degree")) != "reussite":
		push_error("Degré attendu 'reussite' (partiel remonté par synergie), obtenu '%s'" % str(res.get("degree")))
		ok = false
	return ok


# Synergie BORNÉE : combo cohérent (syn=+1) mais ZÉRO couverture → AU MIEUX 'partiel'
# (le +1 remonte 'echec' jusqu'au plafond de la fourchette nulle, jamais au-delà).
func test_synergy_bounded_by_coverage() -> bool:
	var c1: MerlinCard = _card(["Sens"])
	var c2: MerlinCard = _card(["Sens", "Savoir"])
	var res: Dictionary = Reso.resolve(["Force"], [c1, c2])
	if str(res.get("degree")) != "partiel":
		push_error("Degré attendu 'partiel' (synergie bornée par couverture nulle), obtenu '%s'" % str(res.get("degree")))
		return false
	return true


# Combo dispersé (familles toutes différentes) → pas de bonus (synergie -1, degré inchangé).
func test_scattered_combo_no_bonus() -> bool:
	var c1: MerlinCard = _card(["Sens"])    # Perception
	var c2: MerlinCard = _card(["Force"])   # Corps
	var res: Dictionary = Reso.resolve(["Sens", "Force", "Empathie"], [c1, c2])
	var ok: bool = true
	if int(res.get("synergy", -99)) != -1:
		push_error("Synergie attendue -1 (dispersé), obtenu %s" % str(res.get("synergy")))
		ok = false
	elif str(res.get("degree")) != "partiel":
		push_error("Degré attendu 'partiel' (dispersé, pas de bonus), obtenu '%s'" % str(res.get("degree")))
		ok = false
	return ok


# Une seule carte → pas de synergie (0), degré = couverture pure (pleine sans extra → réussite).
func test_single_card_neutral_synergy() -> bool:
	var c1: MerlinCard = _card(["Sens", "Savoir"])
	var res: Dictionary = Reso.resolve(["Sens", "Savoir"], [c1])
	var ok: bool = true
	if int(res.get("synergy", -99)) != 0:
		push_error("Synergie attendue 0 (carte seule), obtenu %s" % str(res.get("synergy")))
		ok = false
	elif str(res.get("degree")) != "reussite":
		push_error("Degré attendu 'reussite' (couverture pleine sans extra), obtenu '%s'" % str(res.get("degree")))
		ok = false
	return ok


# Sabotage APRÈS synergie : combo cohérent + couverture pleine → éclatante, puis tag antagoniste
# dégrade d'un cran → réussite (documente l'ordre du pipeline : synergie d'abord, sabotage ensuite).
func test_sabotage_degrades_after_synergy() -> bool:
	var c1: MerlinCard = _card(["Sens", "Savoir"])
	var c2: MerlinCard = _card(["Mémoire", "Savoir"])
	var res: Dictionary = Reso.resolve(["Sens", "Savoir"], [c1, c2], ["Savoir"])
	var ok: bool = true
	if not bool(res.get("sabotaged", false)):
		push_error("Sabotage attendu (tag 'Savoir' joué et antagoniste)")
		ok = false
	elif str(res.get("degree")) != "reussite":
		push_error("Degré attendu 'reussite' (éclatante par synergie, dégradée par sabotage), obtenu '%s'" % str(res.get("degree")))
		ok = false
	return ok


# Plafond éclatante (game design 2026-05-29) : une SEULE carte ne donne jamais d'éclatante
# (l'éclatante récompense une vraie COMBINAISON), même en couverture pleine + extra.
func test_single_card_never_eclatante() -> bool:
	var c: MerlinCard = MerlinCard.make("x", "X", ["Nature", "Instinct"], "")  # couvre Nature + extra Instinct
	var res: Dictionary = Reso.resolve(["Nature"], [c])
	if str(res.get("degree")) != "reussite":
		push_error("1 carte ne doit jamais donner éclatante (plafond réussite), obtenu '%s'" % str(res.get("degree")))
		return false
	return true


# Plafond éclatante : une carte à COÛT (corruption>0) ne donne pas d'éclatante « gratuite ».
func test_cost_card_caps_eclatante() -> bool:
	var c1: MerlinCard = MerlinCard.make("a", "A", ["Nature"], "")        # propre
	var c2: MerlinCard = MerlinCard.make("b", "B", ["Instinct"], "", 1)   # carte à coût (corruption 1)
	var res: Dictionary = Reso.resolve(["Nature"], [c1, c2])
	if str(res.get("degree")) != "reussite":
		push_error("Une carte à coût ne doit pas donner éclatante, obtenu '%s'" % str(res.get("degree")))
		return false
	return true
