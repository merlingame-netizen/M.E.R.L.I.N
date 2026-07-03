class_name MerlinResolution
extends RefCounted
## Moteur de résolution (bible R65/R66) — le CODE calcule le degré + les deltas ;
## le LLM ne fait que NARRER (R63/R105). 100% logique pure, déterministe, testable.

const ECHEC: String = "echec"
const PARTIEL: String = "partiel"
const REUSSITE: String = "reussite"
const ECLATANTE: String = "eclatante"

const LABELS: Dictionary = {
	ECHEC: "Échec", PARTIEL: "Partiel", REUSSITE: "Réussite", ECLATANTE: "Réussite éclatante",
}

# Deltas d'Intégrité par degré (R65). Corruption = somme coûts cartes + prix du partiel.
# v10.14 (cascade 2026-06-12) : PARTIEL durci -1 → -2 (cible soak : partiel 25-35%, morts 10-25%).
const INTEGRITE_DELTA: Dictionary = {
	ECHEC: -3, PARTIEL: -2, REUSSITE: 0, ECLATANTE: 0,
}
const PARTIEL_CORRUPTION_PRICE: int = 1  # le "succès à un prix" (R65)
# v10.21 (Wave G, R130) — « Pousser » : sur un PARTIEL, payer +1 Corruption transforme en RÉUSSITE.
# Le prix du partiel N'EST PAS remboursé (sinon push gratuit = stratégie dominante) : taux d'échange
# lisible, 1 Corruption contre l'Intégrité épargnée (−2). Budget : 1 push par QUÊTE.
const PUSH_PRICE: int = 1
const PUSH_BUDGET_PER_QUEST: int = 1

# v10.14 — Dé PRÉ-TIRÉ (4 bandes par rareté de la carte PRINCIPALE — cascade Wave1 2026-06-12).
# JAMAIS de malus (R20 quasi-déterministe) : la Commune ne bouge qu'1 fois sur 6 (+1),
# la Mythique GARANTIT +1. Le modificateur est clampé à la fourchette de couverture (comme la
# synergie). Le dé est tiré UNE fois par beat (build_situation) → preview = résolution finale.
# Tuning 2e passe (mesures soak 5×100, designer 2026-06-12) : Commune/Rare +1 cran généreuses
# pour ramener les archétypes joueur-plausible vers la cible (greedy/chaotic 47% → ~38-42%).
const DIE_BANDS: Dictionary = {
	"Commune":  [0, 0, 0, 0, 1, 1],
	"Rare":     [0, 0, 0, 1, 1, 1],
	"Épique":   [0, 0, 1, 1, 1, 1],
	"Mythique": [1, 1, 1, 1, 1, 1],
}

# Ordre croissant des degrés — sert à borner l'affinage par synergie (hybride, user 2026-05-28).
const ORDER: Array = [ECHEC, PARTIEL, REUSSITE, ECLATANTE]


## played_cards : Array de MerlinCard (ou Dict {tags:Array, corruption:int}).
## antagonist_tags : tags qui sabotent si joués (R41/R66).
## die : face 1-6 PRÉ-TIRÉE par l'appelant (0 = pas de dé, rétro-compatible probes).
## Retourne {degree, label, integrite_delta, corruption_delta, coverage, eclatante_bonus, sabotaged,
##           die, die_mod, die_rarity}.
static func resolve(required: Array, played_cards: Array, antagonist_tags: Array = [], die: int = 0, bonus_tags: Array = []) -> Dictionary:
	var played_tags: Array = []
	var cost: int = 0
	for c in played_cards:
		var tags: Array = _card_tags(c)
		for t in tags:
			played_tags.append(t)
		cost += _card_corruption(c)
	# v10.21 (Wave I, R131) — TAGS BÉNIS par une intervention de pilier : ajoutés à la couverture.
	# Passés par TOUS les call-sites (preview, prefetch, résolution) → invariant preview = résolution (R120).
	for bt in bonus_tags:
		played_tags.append(str(bt))

	var cov: Dictionary = MerlinTags.coverage(required, played_tags)
	var covered_n: int = cov["covered"].size()
	var req_n: int = covered_n + cov["missing"].size()

	var base_degree: String = _degree_from_coverage(covered_n, req_n, cov["extra"])

	# Hybride (user 2026-05-28) : la COHÉRENCE de la combinaison affine le degré DANS la fourchette
	# permise par la couverture (±1 cran, borné). Le code décide → instantané, non-bloquant ;
	# le LLM, lui, NARRE la combinaison (cf. merlin_scenario.narrate_resolution).
	var synergy: int = _synergy(played_cards)
	var degree: String = _apply_synergy(base_degree, synergy, covered_n, req_n)

	# v10.14 — Dé pré-tiré : bonus par bande de rareté de la carte PRINCIPALE, clampé à la même
	# fourchette de couverture que la synergie (jamais échec total → réussite). die=0 → neutre.
	var die_mod: int = 0
	var die_rarity: String = ""
	if die >= 1 and die <= 6 and not played_cards.is_empty():
		die_rarity = _card_rarity(played_cards[0])
		var band: Array = DIE_BANDS.get(die_rarity, DIE_BANDS["Commune"])
		die_mod = int(band[die - 1])
		if die_mod != 0:
			degree = _apply_synergy(degree, die_mod, covered_n, req_n)

	# Plafond éclatante (game design 2026-05-29) : l'éclatante récompense une VRAIE combinaison
	# SANS coût — jamais une carte seule, jamais une carte à coût (corruption > 0).
	if degree == ECLATANTE and (played_cards.size() < 2 or cost > 0):
		degree = REUSSITE

	# Sabotage par tag antagoniste (R66) : dégrade d'un cran — APRÈS la synergie (un combo
	# cohérent peut donc amortir une partie de la pénalité de sabotage).
	var sabotaged: bool = false
	if not antagonist_tags.is_empty():
		var ant_canon: Array = []
		for a in antagonist_tags:
			ant_canon.append(MerlinTags.to_canon(str(a)))
		for pt in played_tags:
			if ant_canon.has(MerlinTags.to_canon(str(pt))):
				sabotaged = true
				break
	if sabotaged:
		degree = _degrade(degree)

	var corruption_delta: int = cost
	if degree == PARTIEL:
		corruption_delta += PARTIEL_CORRUPTION_PRICE

	return {
		"degree": degree,
		"label": LABELS.get(degree, degree),
		"integrite_delta": int(INTEGRITE_DELTA.get(degree, 0)),
		"corruption_delta": corruption_delta,
		"card_cost": cost,
		"coverage": cov,
		"eclatante_bonus": degree == ECLATANTE,
		"sabotaged": sabotaged,
		"synergy": synergy,
		"die": die,
		"die_mod": die_mod,
		"die_rarity": die_rarity,
	}


static func _degree_from_coverage(covered_n: int, req_n: int, extra: Array) -> String:
	if req_n <= 0:
		return REUSSITE
	if covered_n >= req_n:
		# Tous couverts : éclatante si ≥1 tag pertinent (non-corrompu) en plus (R65).
		for e in extra:
			if not MerlinTags.is_corrupted_tag(str(e)):
				return ECLATANTE
		return REUSSITE
	if covered_n > 0:
		return PARTIEL
	return ECHEC


# Cohérence de la combinaison : +1 si ≥2 cartes partagent une famille de tags (geste focalisé),
# -1 si dispersé (familles toutes distinctes) ou corrompu sans cohésion, 0 sinon (1 carte / neutre).
static func _synergy(played_cards: Array) -> int:
	if played_cards.size() < 2:
		return 0
	var fams: Dictionary = {}
	var has_corrupt: bool = false
	for c in played_cards:
		for t in _card_tags(c):
			if MerlinTags.is_corrupted_tag(str(t)):
				has_corrupt = true
				continue
			var f: String = MerlinTags.family_of(str(t))
			if f != "":
				fams[f] = int(fams.get(f, 0)) + 1
	for f in fams:
		if int(fams[f]) >= 2:
			return 1  # au moins une famille renforcée → combinaison cohérente
	if has_corrupt:
		return -1
	# Dispersé : au moins autant de familles distinctes que de cartes (rien ne se renforce).
	# NB : une carte multi-tags compte plusieurs familles → un généraliste tend vers "dispersé"
	# quand aucune famille n'atteint 2 (le bonus de cohésion ci-dessus a priorité s'il s'applique).
	if fams.size() >= played_cards.size():
		return -1
	return 0


# Affine le degré par la synergie, BORNÉ à la fourchette permise par la couverture (jamais
# transformer un échec total en réussite, etc.). req_n == 0 → pas d'affinage (rien à couvrir).
static func _apply_synergy(base: String, synergy: int, covered_n: int, req_n: int) -> String:
	if synergy == 0 or req_n <= 0:
		return base
	var base_idx: int = ORDER.find(base)
	if base_idx == -1:
		push_error("MerlinResolution._apply_synergy: degré inconnu '%s'" % base)
		return base  # entrée inattendue → pas d'affinage (évite un degré silencieusement faux)
	var lo: int
	var hi: int
	if covered_n >= req_n:                       # couverture pleine
		lo = ORDER.find(REUSSITE)
		hi = ORDER.find(ECLATANTE)
	elif covered_n > 0:                          # partielle
		lo = ORDER.find(PARTIEL)
		hi = ORDER.find(REUSSITE)
	else:                                        # nulle
		lo = ORDER.find(ECHEC)
		hi = ORDER.find(PARTIEL)
	var idx: int = clampi(base_idx + synergy, lo, hi)
	return str(ORDER[idx])


static func _degrade(degree: String) -> String:
	match degree:
		ECLATANTE: return REUSSITE
		REUSSITE: return PARTIEL
		PARTIEL: return ECHEC
		_: return ECHEC


static func _card_tags(c: Variant) -> Array:
	if c is Object and "tags" in c:
		return c.tags
	if c is Dictionary and c.has("tags"):
		return c["tags"]
	return []


static func _card_corruption(c: Variant) -> int:
	if c is Object and "corruption" in c:
		return int(c.corruption)
	if c is Dictionary and c.has("corruption"):
		return int(c["corruption"])
	return 0


static func _card_rarity(c: Variant) -> String:
	if c is Object and "rarity" in c:
		var r: String = str(c.rarity)
		return r if r != "" else "Commune"
	if c is Dictionary and c.has("rarity"):
		var rd: String = str(c["rarity"])
		return rd if rd != "" else "Commune"
	return "Commune"
