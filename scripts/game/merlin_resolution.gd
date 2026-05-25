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
const INTEGRITE_DELTA: Dictionary = {
	ECHEC: -3, PARTIEL: -1, REUSSITE: 0, ECLATANTE: 0,
}
const PARTIEL_CORRUPTION_PRICE: int = 1  # le "succès à un prix" (R65)


## played_cards : Array de MerlinCard (ou Dict {tags:Array, corruption:int}).
## antagonist_tags : tags qui sabotent si joués (R41/R66).
## Retourne {degree, label, integrite_delta, corruption_delta, coverage, eclatante_bonus, sabotaged}.
static func resolve(required: Array, played_cards: Array, antagonist_tags: Array = []) -> Dictionary:
	var played_tags: Array = []
	var cost: int = 0
	for c in played_cards:
		var tags: Array = _card_tags(c)
		for t in tags:
			played_tags.append(t)
		cost += _card_corruption(c)

	var cov: Dictionary = MerlinTags.coverage(required, played_tags)
	var covered_n: int = cov["covered"].size()
	var req_n: int = covered_n + cov["missing"].size()

	var degree: String = _degree_from_coverage(covered_n, req_n, cov["extra"])

	# Sabotage par tag antagoniste (R66) : dégrade d'un cran.
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
