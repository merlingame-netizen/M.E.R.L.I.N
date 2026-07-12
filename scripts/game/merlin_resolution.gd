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
# v1.0-V4a (BAL-25) — l'éclatante REND +1 Intégrité (clampé au max par apply_resolution) : le
# sommet du geste répare, et amortit la spirale de morts mesurée (36,6 % → cible 10-25).
const INTEGRITE_DELTA: Dictionary = {
	ECHEC: -3, PARTIEL: -2, REUSSITE: 0, ECLATANTE: 1,
}
# v1.0-V4a LEVIER 8 (BAL-05-C) — barème d'ÉCHEC par difficulté : −2 en diff 1-2, −3 en diff 3
# (le climax reste létal ; PARTIEL −2 INCHANGÉ → le push R130 garde toute sa valeur d'échange).
# Précondition CDC consommée : la cause « génération » du taux d'échec est corrigée (BAL-03-A + L7).
const ECHEC_DELTA_BY_DIFF: Dictionary = {1: -2, 2: -2, 3: -3}
const PARTIEL_CORRUPTION_PRICE: int = 1  # le "succès à un prix" (R65)
# v10.21 (Wave G, R130) — « Pousser » : sur un PARTIEL, payer +1 Corruption transforme en RÉUSSITE.
# Le prix du partiel N'EST PAS remboursé (sinon push gratuit = stratégie dominante) : taux d'échange
# lisible, 1 Corruption contre l'Intégrité épargnée (−2). Budget : 1 push par QUÊTE.
const PUSH_PRICE: int = 1
const PUSH_BUDGET_PER_QUEST: int = 1

# === v2-W1 (2026-07-05) — MOTEUR d20-vs-DC (PIVOT CANON, supersède R135 « zéro chiffre »/R139/§K) ===
# total = die(1-20) + skill_mod + graft_bonus + COVER_PER_TAG*covered_n + synergy_bonus,
# comparé à un DC fixé par la difficulté. La MARGE (total − DC) donne le degré ; deux PLANCHERS
# durs : nat 20 (die==20) → éclatante · nat 1 (die==1) → échec (quels que soient les modificateurs).
# skill_mod (talent W2) et graft_bonus (greffes-jet W3) sont des PARAMÈTRES à défaut 0 en W1 :
# le jeu ET le probe passent 0 (§K re-dérivé sur la BASE = d20 + couverture + synergie).
# Leviers de balance §K (re-dérivés par mesure soak, v2-W1) — cf. tableau de la vague.
const DC_BY_DIFF: Dictionary = {1: 11, 2: 15, 3: 18}   # base {10,13,16} → L1 → L2 (voir §K)
const COVER_PER_TAG: int = 3    # +3 par tag requis couvert (2 requis → +6 plein / +3 partiel / 0 nul)
const SYN: int = 2              # synergie du geste : +SYN si +1, −SYN si −1, 0 sinon
# Largeur des bandes de marge (planchers depuis DC). PARTIEL = [DC−PARTIEL_LOW, DC−1] ;
# ÉCLATANTE = marge ≥ ECLAT_MARGIN. Échec strict sous PARTIEL_LOW.
const PARTIEL_LOW: int = 13     # DC−13 ≤ total ≤ DC−1 → partiel ; total < DC−13 → échec (L3, final)
const ECLAT_MARGIN: int = 9     # total ≥ DC+9 → éclatante (N5-C2 : 8→9, la maîtrise poussait éclatante à 14,8 % contre plafond 15 % - levier chirurgical §K, ne touche QUE le seuil éclatante, cf. spec game-designer N5)
# Dé « moyen » déterministe pour les vieux call-sites tools qui appellent resolve(..., die=0) :
# ~jet médian d'un d20 (ne plante pas, produit une base réaliste). Le jeu et le soak passent 1-20.
const DIE_FALLBACK: int = 10

# Ordre croissant des degrés — sert à borner l'affinage par synergie (hybride, user 2026-05-28).
const ORDER: Array = [ECHEC, PARTIEL, REUSSITE, ECLATANTE]


## played_cards : Array de MerlinCard (ou Dict {tags:Array, corruption:int}).
## antagonist_tags : tags qui sabotent si joués (R41/R66).
## die : face 1-20 PRÉ-TIRÉE par l'appelant (0 = pas de dé → DIE_FALLBACK, rétro-compatible probes tools).
## bonus_tags : tags bénis par un pilier (R131) — ajoutés à la couverture.
## diff : difficulté EFFECTIVE du beat → DC via DC_BY_DIFF. Défaut 2. Le jeu ET le soak passent la
## MÊME valeur sur TOUS les call-sites (preview, prefetch, résolution) — invariant R120.
## skill_mod : bonus de talent (W2, défaut 0). graft_bonus : bonus de greffe-jet (W3, défaut 0).
## Retourne {degree, label, integrite_delta, corruption_delta, coverage, eclatante_bonus, sabotaged,
##           synergy, die, die_mod, die_rarity, total, dc, margin, success}.
static func resolve(required: Array, played_cards: Array, antagonist_tags: Array = [], die: int = 0, bonus_tags: Array = [], diff: int = 2, skill_mod: int = 0, graft_bonus: int = 0) -> Dictionary:
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

	# Synergie du geste ACTION + TRAIT (+1/−1/0 — logique inchangée depuis v11).
	var synergy: int = _synergy(played_cards)

	# === MOTEUR d20 (v2-W1) — un SEUL nombre décide, la marge donne le degré ===
	var face: int = die if die >= 1 and die <= 20 else DIE_FALLBACK
	var synergy_bonus: int = SYN if synergy > 0 else (-SYN if synergy < 0 else 0)
	var total: int = face + skill_mod + graft_bonus + COVER_PER_TAG * covered_n + synergy_bonus
	var dc: int = int(DC_BY_DIFF.get(clampi(diff, 1, 3), DC_BY_DIFF[2]))
	var margin: int = total - dc

	var degree: String = _degree_from_margin(margin, face)

	# Sabotage par tag antagoniste (R66) : dégrade d'un cran — APRÈS le jet (garde son sens : même
	# un jet éclatant est amorti par un tag qui sabote la situation). Ne peut PAS annuler un nat 20 ?
	# → v2-W1 : le sabotage s'applique aussi au-dessus d'un nat 20 (le tag pollue le geste, R66).
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

	# Barème d'Intégrité : INTEGRITE_DELTA par degré (partiel −2, réussite 0, éclatante +1) ; seul
	# l'ÉCHEC est modulé par la difficulté (ECHEC_DELTA_BY_DIFF : −2 diff 1-2, −3 diff 3, L8).
	var integrite_delta: int = int(INTEGRITE_DELTA.get(degree, 0))
	if degree == ECHEC:
		integrite_delta = int(ECHEC_DELTA_BY_DIFF.get(clampi(diff, 1, 3), -3))

	# Clés de dé rétro-compat (merlin_fx.MerlinDice, merlin_game vignette) : die_rarity n'est plus
	# une bande d'action (le dé est un vrai d20) → "" ; die_mod = proxy « le sort a souri » (éclatante)
	# pour conserver le flash d'or existant sans réintroduire les bandes de rareté (W4 fera le visuel d20).
	# `success` est dérivé du degré FINAL (après sabotage) — un nat 20 sabordé jusqu'à partiel N'EST
	# PAS un succès (le halo W4 et tout futur lecteur lisent la vérité, pas le jet brut). (review M2)
	var success: bool = degree == REUSSITE or degree == ECLATANTE
	var die_mod: int = 1 if degree == ECLATANTE else 0

	return {
		"degree": degree,
		"label": LABELS.get(degree, degree),
		"integrite_delta": integrite_delta,
		"corruption_delta": corruption_delta,
		"card_cost": cost,
		"coverage": cov,
		"eclatante_bonus": degree == ECLATANTE,
		"sabotaged": sabotaged,
		"synergy": synergy,
		"die": die,
		"die_mod": die_mod,
		"die_rarity": "",
		"total": total,
		"dc": dc,
		"margin": margin,
		"success": success,
	}


# v2-W1 — degré par la MARGE (total − DC) + planchers nat 1 / nat 20. `face` est déjà normalisé en
# amont (1-20, ou DIE_FALLBACK si le call-site n'a pas de dé) → les planchers ne s'arment que sur un
# vrai jet 1/20 ; un call-site sans dé (fallback 10) passe donc par la marge, jamais par un plancher.
static func _degree_from_margin(margin: int, face: int) -> String:
	if face == 20:
		return ECLATANTE   # plancher nat 20 (avant toute lecture de marge)
	if face == 1:
		return ECHEC       # plancher nat 1
	if margin >= ECLAT_MARGIN:
		return ECLATANTE
	if margin >= 0:
		return REUSSITE
	if margin >= -(PARTIEL_LOW):
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
