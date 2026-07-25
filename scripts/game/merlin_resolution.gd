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

# === R158 (2026-07-14) : CORRUPTION/SANTE AUTOMATIQUE = NATURE de l'evenement x DEGRE x GESTE ===
# Le cout de carte, le prix du partiel et le « Pousser » sont SUPPRIMES : la corruption et la sante
# ne se « payent » plus a la main, elles DECOULENT de la scene. Nature de l'evenement (tier 0-3) x
# degre FINAL -> deltas de base ; un geste sombre/risque (carte corrompue jouee, ou COMBATTRE sur
# une scene paisible) AMPLIFIE. Barème game-designer (spec Phase 0 B.3/B.4), a tuner au soak (§K).
const NATURE_BASE_TIER_BY_TYPE: Dictionary = {
	"Exploration": 0, "Rencontre": 1, "Epreuve": 2, "Dilemme": 2, "Climax": 2,
}
const NATURE_ESCALATE_FAMILY: String = "Monde"  # tag Monde requis (Rituel/Sacrifice/Equilibre/Mystere) -> +1 tier
# {tier -> {degre -> [dIntegrite, dCorruption]}}. Corruption clampee >= 0 par apply_resolution.
const NATURE_DELTA: Dictionary = {
	0: {ECHEC: [-2, 0], PARTIEL: [-1, 0], REUSSITE: [0, 0], ECLATANTE: [1, 0]},
	1: {ECHEC: [-2, 1], PARTIEL: [-1, 0], REUSSITE: [0, 0], ECLATANTE: [1, 0]},
	2: {ECHEC: [-3, 2], PARTIEL: [-2, 1], REUSSITE: [0, 0], ECLATANTE: [1, -1]},
	3: {ECHEC: [-3, 3], PARTIEL: [-3, 2], REUSSITE: [0, 1], ECLATANTE: [1, -1]},
}
# Geste sombre/risque : ajoute UNE fois (spec B.4). Amplifie la perte de sante ET la corruption.
const GESTE_INTEGRITE_DELTA: int = 0   # R158 tune-loop : le geste sombre CORROMPT (ne blesse pas) : sinon corrompu meurt avant de se corrompre
const GESTE_CORRUPTION_DELTA: int = 1

# === R158 (2026-07-14) : MOTEUR 2d6-vs-DC (supersede le d20 du pivot v2-W1) ===
# total = die(2d6, 2-12) + skill_mod + graft_bonus + COVER_PER_TAG*covered_n + synergy_bonus,
# comparé à un DC fixé par la difficulté. La MARGE (total − DC) donne le degré ; deux PLANCHERS
# durs : boxcars (die==12) → éclatante · snake eyes (die==2) → échec (quels que soient les modificateurs).
# skill_mod (talent W2) et graft_bonus (greffes-jet W3) sont des PARAMÈTRES à défaut 0 en W1 :
# le jeu ET le probe passent 0 (§K re-dérivé sur la BASE = d20 + couverture + synergie).
# Leviers de balance §K (re-dérivés par mesure soak, v2-W1) — cf. tableau de la vague.
const DC_BY_DIFF: Dictionary = {1: 6, 2: 9, 3: 12}   # R158 (2d6) : full-cover + face median (7) ~ reussite (spec C)   # base {10,13,16} → L1 → L2 (voir §K)
const COVER_PER_TAG: int = 3    # +3 par tag requis couvert (2 requis → +6 plein / +3 partiel / 0 nul)
const SYN: int = 1              # R158 (2d6) : synergie reduite (span du de 19 -> 10, spec C).  Ancien commentaire : synergie du geste : +SYN si +1, −SYN si −1, 0 sinon
# Largeur des bandes de marge (planchers depuis DC). PARTIEL = [DC−PARTIEL_LOW, DC−1] ;
# ÉCLATANTE = marge ≥ ECLAT_MARGIN. Échec strict sous PARTIEL_LOW.
const PARTIEL_LOW: int = 5      # R158 (2d6) : marge [-5,-1] = partiel ; < -5 = echec (spec C).  Ancien commentaire : DC−13 ≤ total ≤ DC−1 → partiel ; total < DC−13 → échec (L3, final)
const ECLAT_MARGIN: int = 8    # R158 (2d6) : marge >= 7 = eclatante (spec C).  Ancien commentaire : total ≥ DC+9 → éclatante (N5-C2 : 8→9, la maîtrise poussait éclatante à 14,8 % contre plafond 15 % - levier chirurgical §K, ne touche QUE le seuil éclatante, cf. spec game-designer N5)
# Dé « moyen » déterministe pour les vieux call-sites tools qui appellent resolve(..., die=0) :
# ~jet médian d'un d20 (ne plante pas, produit une base réaliste). Le jeu et le soak passent 2-12.
const DIE_FALLBACK: int = 7   # R158 : moyenne de 2d6 (call-sites tools sans de)

# Ordre croissant des degrés — sert à borner l'affinage par synergie (hybride, user 2026-05-28).
const ORDER: Array = [ECHEC, PARTIEL, REUSSITE, ECLATANTE]


## played_cards : Array de MerlinCard (ou Dict {tags:Array, corruption:int}).
## antagonist_tags : tags qui sabotent si joués (R41/R66).
## die : somme 2d6 (2-12) PRE-TIREE par l'appelant (0 = pas de dé → DIE_FALLBACK, rétro-compatible probes tools).
## bonus_tags : tags bénis par un pilier (R131) — ajoutés à la couverture.
## diff : difficulté BRUTE du beat (beat.difficulte, jamais mutée) → DC de BASE via DC_BY_DIFF.
## Défaut 2. Le jeu ET le soak passent la MÊME valeur sur TOUS les call-sites (preview, prefetch,
## résolution) — invariant R120.
## skill_mod : bonus de talent (W2, défaut 0). graft_bonus : bonus de greffe-jet (W3, défaut 0).
## dc_bonus : rampe de difficulté par quête/climax (v2-W1, R165, MerlinScenario.dc_ramp_bonus) —
## AJOUTÉ au DC de base, jamais à la composition des requis. Défaut 0 (zéro régression legacy).
## Retourne {degree, label, integrite_delta, corruption_delta, coverage, eclatante_bonus, sabotaged,
##           synergy, die, die_mod, die_rarity, total, dc, margin, success}.
static func resolve(required: Array, played_cards: Array, antagonist_tags: Array = [], die: int = 0, bonus_tags: Array = [], diff: int = 2, skill_mod: int = 0, graft_bonus: int = 0, beat_type: String = "", dc_bonus: int = 0) -> Dictionary:
	var played_tags: Array = []
	for c in played_cards:
		var tags: Array = _card_tags(c)
		for t in tags:
			played_tags.append(t)
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
	var face: int = die if die >= 2 and die <= 12 else DIE_FALLBACK
	var synergy_bonus: int = SYN if synergy > 0 else (-SYN if synergy < 0 else 0)
	var total: int = face + skill_mod + graft_bonus + COVER_PER_TAG * covered_n + synergy_bonus
	var dc: int = int(DC_BY_DIFF.get(clampi(diff, 1, 3), DC_BY_DIFF[2])) + dc_bonus
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

	# R158 : deltas AUTOMATIQUES = nature de l'evenement (type de beat + tags Monde requis) x degre
	# FINAL (post-sabotage), amplifies par un geste sombre/risque. Le cout de carte et le prix du
	# partiel ont disparu : la corruption n'est plus jamais « payee » a la main (spec Phase 0 B).
	var nature: int = nature_tier(beat_type, required)
	var ndelta: Array = _nature_delta(nature, degree)
	var corruption_delta: int = int(ndelta[1])

	# Barème d'Intégrité : INTEGRITE_DELTA par degré (partiel −2, réussite 0, éclatante +1) ; seul
	# l'ÉCHEC est modulé par la difficulté (ECHEC_DELTA_BY_DIFF : −2 diff 1-2, −3 diff 3, L8).
	var integrite_delta: int = int(ndelta[0])
	if _is_dark_geste(played_cards, nature):
		integrite_delta += GESTE_INTEGRITE_DELTA
		corruption_delta += GESTE_CORRUPTION_DELTA

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
		"nature": nature,
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


# === Vague Economie V1 (in-run) — Coup de Pouce = AVANTAGE, JAMAIS un +N additif ===
# Pre-tire 2 sommes 2d6 INDEPENDANTES (die + face_adv) et garde la MEILLEURE. Ne touche NI
# DC_BY_DIFF, NI COVER_PER_TAG, NI SYN, NI PARTIEL_LOW, NI ECLAT_MARGIN (constantes fraichement
# calibrees, R158) : c'est un simple pre-tirage de dé, au même titre que merlin_scenario.gd (die +
# face_adv, PRE-TIRES ENSEMBLE, une seule fois par beat). Respecte R120 : `die` et `face_adv` sont
# PRE-TIRES ordinaires, stockés UNE fois par l'appelant (beat["die"]/beat["face_adv"]) et partagés
# tels quels entre preview/résolution/soak — resolve() ne change pas et ignore d'où vient `die`.
# R120 (2026-07-25) : l'ancien resolve_with_advantage(rng) tirait le dé AU MOMENT DE L'USAGE (hors
# sémantique pré-tirée, cache-miss possible entre preview et résolution) — SUPPRIMÉ. Le MAX(die,
# face_adv) se calcule désormais EN AMONT de resolve(), par l'appelant (merlin_game.gd/probe_soak.gd),
# à partir des DEUX valeurs pré-tirées de CE beat, si la charge Coup de Pouce est armée
# (MerlinRun.consume_coup_de_pouce_if_armed) — une seule vérité, aucun tirage caché dans le moteur.
static func roll_2d6(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, 6) + rng.randi_range(1, 6)


# v2-W1 — degré par la MARGE (total − DC) + planchers nat 1 / nat 20. `face` est déjà normalisé en
# amont (1-20, ou DIE_FALLBACK si le call-site n'a pas de dé) → les planchers ne s'arment que sur un
# vrai jet 1/20 ; un call-site sans dé (fallback 10) passe donc par la marge, jamais par un plancher.
static func _degree_from_margin(margin: int, face: int) -> String:
	if face == 12:
		return ECLATANTE   # R158 : « boxcars » 2d6 -> plancher eclatante (quels que soient les mods)
	if face == 2:
		return ECHEC       # R158 : « snake eyes » 2d6 -> plancher echec
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


# R158 : tier de NATURE de l'evenement. Base par type de beat, +1 (cap 3) si un tag Monde est requis
# (Rituel/Sacrifice/Equilibre/Mystere) : une scene qui touche au « Monde » corrompt davantage.
# Statique/pur : le jeu ET le soak passent le meme beat_type -> meme nature (invariant R120).
static func nature_tier(beat_type: String, required: Array) -> int:
	var tier: int = int(NATURE_BASE_TIER_BY_TYPE.get(beat_type, 1))
	for t in required:
		if MerlinTags.family_of(str(t)) == NATURE_ESCALATE_FAMILY:
			return mini(tier + 1, 3)
	return tier


# R158 : cellule [dIntegrite, dCorruption] pour (tier, degre). Repli neutre si clef absente.
static func _nature_delta(tier: int, degree: String) -> Array:
	var by_deg: Dictionary = NATURE_DELTA.get(clampi(tier, 0, 3), NATURE_DELTA[1])
	var cell: Variant = by_deg.get(degree, [0, 0])
	return cell if cell is Array else [0, 0]


# R158 : le geste est-il sombre/risque ? (carte corrompue jouee OU COMBATTRE sur scene paisible).
# Amplifie la perte de sante ET la corruption une seule fois (spec B.4). played_cards[0] = action.
static func _is_dark_geste(played_cards: Array, tier: int) -> bool:
	for i in range(1, played_cards.size()):
		if _is_corrupted_card(played_cards[i]):
			return true
	if played_cards.size() > 0 and _card_family(played_cards[0]) == "Corps" \
			and _card_name(played_cards[0]) == "COMBATTRE" and tier <= 1:
		return true
	return false


# Nom canonique d'une carte-like (duck-type). "" si inconnu.
static func _card_name(c: Variant) -> String:
	if c is Object and "card_name" in c:
		return str(c.card_name)
	if c is Dictionary and c.has("name"):
		return str(c["name"])
	return ""
