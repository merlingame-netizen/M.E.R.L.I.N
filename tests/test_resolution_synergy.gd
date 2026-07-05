extends RefCounted
## Unit Tests — MerlinResolution, MOTEUR d20-vs-DC (v2-W1, 2026-07-05).
## Le degré vient de la MARGE (total − DC) avec deux planchers durs (nat 1 → échec, nat 20 →
## éclatante). total = die + skill_mod + graft_bonus + COVER_PER_TAG×couverts + synergy_bonus.
## Le geste canonique = [ACTION (porte une famille), TRAIT] ; la synergie ne s'arme que sur une
## ACTION en position [0] (contrat v11). 100% déterministe (die passé explicitement).

const Reso = preload("res://scripts/game/merlin_resolution.gd")


func _trait(tags: Array) -> MerlinCard:
	return MerlinCard.make("id_" + str(tags.hash()), "Trait", tags, "évocation")


# Une ACTION porte une famille canonique (make_actions le fait) ; on la reconstruit ici pour tester
# la synergie du geste ACTION + TRAIT sans dépendre du pool complet.
func _action(family: String, tags: Array) -> MerlinCard:
	var c: MerlinCard = MerlinCard.make("act_" + family, family.to_upper(), tags, "verbe", 0, "Commune")
	c.family = family
	return c


# Plancher nat 1 : die==1 → échec, quels que soient couverture et modificateurs.
func test_nat1_floor_is_echec() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var t: MerlinCard = _trait(["Sens", "Savoir"])  # couverture pleine
	var res: Dictionary = Reso.resolve(["Sens", "Savoir"], [a, t], [], 1, [], 2)
	if str(res.get("degree")) != "echec":
		push_error("nat 1 doit forcer 'echec' (couverture pleine ignorée), obtenu '%s'" % str(res.get("degree")))
		return false
	return true


# Plancher nat 20 : die==20 → éclatante, même à diff 3 avec 0 tag couvert.
func test_nat20_floor_is_eclatante() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var t: MerlinCard = _trait(["Force"])  # ne couvre rien de ["Ruse","Vision"]
	var res: Dictionary = Reso.resolve(["Ruse", "Vision"], [a, t], [], 20, [], 3)
	if str(res.get("degree")) != "eclatante":
		push_error("nat 20 doit forcer 'eclatante' (0 couvert, diff 3), obtenu '%s'" % str(res.get("degree")))
		return false
	return true


# Couverture pleine + jet médian passe le DC (diff 2) → réussite ; le dict porte total/dc/margin/success.
func test_full_coverage_median_die_succeeds() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var t: MerlinCard = _trait(["Sens", "Savoir"])
	# total = 10 + COVER_PER_TAG*2 (+ synergy_bonus si le trait nourrit la famille). ≥ DC(15) → succès.
	var res: Dictionary = Reso.resolve(["Sens", "Savoir"], [a, t], [], 10, [], 2)
	var ok: bool = true
	if not bool(res.get("success", false)):
		push_error("couverture pleine + d10 doit réussir (total=%d dc=%d)" % [int(res.get("total", 0)), int(res.get("dc", 0))])
		ok = false
	if not (res.has("total") and res.has("dc") and res.has("margin") and res.has("success")):
		push_error("le dict doit porter total/dc/margin/success")
		ok = false
	if int(res.get("dc", 0)) != int(Reso.DC_BY_DIFF[2]):
		push_error("dc doit venir de DC_BY_DIFF[diff]")
		ok = false
	return ok


# 0 tag couvert + jet faible + DC élevé (diff 3) → échec (marge très négative, sous −PARTIEL_LOW).
func test_zero_coverage_low_die_fails() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var t: MerlinCard = _trait(["Force"])  # ne couvre pas ["Ruse","Vision"]
	# total = 2 + 0 couverture + synergy_bonus(0) = 2 ; DC diff 3 = 18 ; marge −16 < −PARTIEL_LOW → échec.
	var res: Dictionary = Reso.resolve(["Ruse", "Vision"], [a, t], [], 2, [], 3)
	if str(res.get("degree")) != "echec":
		push_error("0 couvert + d2 + diff 3 doit échouer (marge %d), obtenu '%s'" % [int(res.get("margin", 0)), str(res.get("degree"))])
		return false
	return true


# Synergie du geste : un TRAIT dont un tag nourrit la famille de l'ACTION → synergy +1 (bonus +SYN).
func test_synergy_plus_one_when_trait_feeds_action_family() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])   # famille Perception
	var t: MerlinCard = _trait(["Vigilance", "Mémoire"])            # Vigilance/Mémoire ∈ Perception
	var res: Dictionary = Reso.resolve(["Sens"], [a, t], [], 10, [], 2)
	if int(res.get("synergy", -99)) != 1:
		push_error("synergie attendue +1 (le trait nourrit la famille de l'action), obtenu %s" % str(res.get("synergy")))
		return false
	return true


# Trait corrompu → synergy −1 (malus −SYN) : le Murmure pollue le geste.
func test_synergy_minus_one_on_corrupted_trait() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var t: MerlinCard = _trait(["Murmure"])  # tag Corrompu
	var res: Dictionary = Reso.resolve(["Sens"], [a, t], [], 10, [], 2)
	if int(res.get("synergy", -99)) != -1:
		push_error("synergie attendue -1 (trait corrompu), obtenu %s" % str(res.get("synergy")))
		return false
	return true


# Sabotage antagoniste : un tag joué qui sabote dégrade le degré d'un cran (APRÈS le jet).
func test_sabotage_degrades_one_rank() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var t: MerlinCard = _trait(["Sens", "Savoir"])
	# Sans sabotage : couverture pleine + d15 (total 21 vs DC 15, marge +6) → réussite. Avec 'Savoir'
	# antagoniste → dégradé d'un cran → partiel. Prouve l'ordre du pipeline (jet d'abord, sabotage après).
	var base: Dictionary = Reso.resolve(["Sens", "Savoir"], [a, t], [], 15, [], 2)
	var sab: Dictionary = Reso.resolve(["Sens", "Savoir"], [a, t], ["Savoir"], 15, [], 2)
	var ok: bool = true
	if not bool(sab.get("sabotaged", false)):
		push_error("sabotage attendu (tag 'Savoir' joué et antagoniste)")
		ok = false
	var base_idx: int = Reso.ORDER.find(str(base.get("degree")))
	var sab_idx: int = Reso.ORDER.find(str(sab.get("degree")))
	if not (base_idx > 0 and sab_idx == base_idx - 1):
		push_error("sabotage doit dégrader d'exactement un cran (%s → %s)" % [str(base.get("degree")), str(sab.get("degree"))])
		ok = false
	return ok


# Barème d'échec par difficulté (nat 1 forcé) : −2 en diff 1-2, −3 en diff 3.
func test_echec_delta_by_diff() -> bool:
	var a: MerlinCard = _action("Perception", ["Sens", "Savoir"])
	var d1: int = int(Reso.resolve(["Sens"], [a], [], 1, [], 1).get("integrite_delta", 0))
	var d2: int = int(Reso.resolve(["Sens"], [a], [], 1, [], 2).get("integrite_delta", 0))
	var d3: int = int(Reso.resolve(["Sens"], [a], [], 1, [], 3).get("integrite_delta", 0))
	if not (d1 == -2 and d2 == -2 and d3 == -3):
		push_error("barème d'échec attendu −2/−2/−3 (diff 1/2/3), obtenu %d/%d/%d" % [d1, d2, d3])
		return false
	return true


# Call-site legacy sans dé (die=0) → fallback déterministe (DIE_FALLBACK) : ne plante pas, degré cohérent.
func test_no_die_uses_deterministic_fallback() -> bool:
	var t: MerlinCard = _trait(["Sens", "Savoir"])
	var res: Dictionary = Reso.resolve(["Sens", "Savoir"], [t], [], 0, [], 2)  # ancien contrat probes/tools
	var ok: bool = true
	# total = DIE_FALLBACK + COVER_PER_TAG*2 = 10 + 6 = 16 ≥ DC(15) → réussite (pas de plancher : die=0).
	if not bool(res.get("success", false)):
		push_error("die=0 doit tomber sur le fallback et réussir la couverture pleine (total=%d)" % int(res.get("total", 0)))
		ok = false
	if str(res.get("degree")) == "echec" or str(res.get("degree")) == "eclatante":
		push_error("die=0 ne doit JAMAIS armer un plancher nat1/nat20, obtenu '%s'" % str(res.get("degree")))
		ok = false
	return ok
