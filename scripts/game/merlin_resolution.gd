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

	# v11 (spec panel §D, CRITICAL) — ÉCLATANTE redéfinie : couverture PLEINE + coût 0 + le TRAIT
	# couvre ≥1 tag requis + (synergie +1 OU dé +1). Remplace l'ancien plafond « ≥2 cartes »
	# (structurellement toujours satisfait avec action+trait → 43-67 % d'éclatantes mesurées).
	# Porte UNIQUE : filtre aussi les promotions venues de _apply_synergy/dé. Cible soak : 8-15 %.
	if degree == ECLATANTE:
		var trait_covers: bool = false
		for i in range(1, played_cards.size()):
			for t in _card_tags(played_cards[i]):
				if (cov["covered"] as Array).has(MerlinTags.to_canon(str(t))):
					trait_covers = true
		if not (covered_n >= req_n and req_n > 0 and cost == 0 and trait_covers \
				and (synergy == 1 or die_mod == 1)):
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


# v11 (spec panel §D, CRITICAL unanime) — Synergie du geste ACTION + TRAIT :
#   +1 SI le trait apporte ≥1 tag NON-dupliqué dont la famille == famille CANONIQUE de l'action
#      ET le trait n'est pas corrompu (le trait « nourrit » le verbe) ;
#   −1 SI le trait est corrompu (tag Corrompu ou coût récurrent) ;
#    0 sinon. Les tags de base de l'action ne comptent JAMAIS entre eux.
# L'ancienne heuristique par familles donnait +1 permanent à toute action 2-tags mono-famille et
# −1 systématique au geste cross-famille normal (mesuré : 0 % d'échecs, 0 % de morts).
# Fallback legacy (probes/dicts sans action en [0]) : neutre — la synergie est un fait du PIVOT.
static func _synergy(played_cards: Array) -> int:
	if played_cards.size() < 2:
		return 0
	var action: Variant = played_cards[0]
	var fam: String = _card_family(action)
	if fam == "":
		return 0  # pas d'action en position [0] (harnais legacy) → neutre
	var action_canon: Array = []
	for t in _card_tags(action):
		action_canon.append(MerlinTags.to_canon(str(t)))
	var syn: int = 0
	for i in range(1, played_cards.size()):
		var tr: Variant = played_cards[i]
		if _is_corrupted_card(tr):
			return -1  # trait corrompu : le Murmure pollue le geste, sans appel
		for t in _card_tags(tr):
			var c: String = MerlinTags.to_canon(str(t))
			if not action_canon.has(c) and MerlinTags.family_of(c) == fam:
				syn = 1
	return syn


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


# v11 — famille canonique d'une ACTION ("" pour un trait/carte legacy — duck-typé comme le reste).
static func _card_family(c: Variant) -> String:
	if c is Object and "family" in c:
		return str(c.family)
	if c is Dictionary and c.has("family"):
		return str(c["family"])
	return ""


# v11 — trait corrompu = tag Corrompu OU coût récurrent (spec §C/§D).
static func _is_corrupted_card(c: Variant) -> bool:
	if _card_corruption(c) > 0:
		return true
	for t in _card_tags(c):
		if MerlinTags.is_corrupted_tag(str(t)):
			return true
	return false


static func _card_rarity(c: Variant) -> String:
	if c is Object and "rarity" in c:
		var r: String = str(c.rarity)
		return r if r != "" else "Commune"
	if c is Dictionary and c.has("rarity"):
		var rd: String = str(c["rarity"])
		return rd if rd != "" else "Commune"
	return "Commune"
