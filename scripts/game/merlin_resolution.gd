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

# === v46 (Maxime 2026-08-24) — LE DE SE DISPENSE : maitrise du verbe + rarete du trait ===
# « des fois juste une difficulte qui demande un niveau de competence dans la competence action
# ou en fonction de la rarete de la carte ». Un maitre ne se fait pas defaire par un mauvais de
# sur un geste de routine, et une carte rare porte son propre poids : les deux achetent de la
# MARGE sur le jet MINIMAL (2), JAMAIS sur le total d'un vrai jet. A talent 0 + trait Commune,
# MARGE_SURE = 0 -> le comportement v34 est STRICTEMENT inchange (zero regression mesuree).
# L'eclatante reste reservee aux VRAIS jets : dispenser le de ne peut JAMAIS produire un eclat.
const SEUIL_MAITRISE: int = 2   # talent (skill_mod) a partir duquel le verbe est maitrise
const MARGE_MAITRISE: int = 2   # ... vaut 2 points de de en moins a craindre
const MARGE_RARETE: Dictionary = {"Commune": 0, "Rare": 1, "Épique": 2, "Mythique": 3}

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
	var synergy_bonus: int = SYN if synergy > 0 else (-SYN if synergy < 0 else 0)
	var mods: int = skill_mod + graft_bonus + COVER_PER_TAG * covered_n + synergy_bonus
	var dc: int = int(DC_BY_DIFF.get(clampi(diff, 1, 3), DC_BY_DIFF[2])) + dc_bonus
	# v34 — GESTE SÛR (Maxime 2026-08-19) : si la réussite est acquise MÊME au jet minimal (2),
	# aucun dé — un sceau s'appose (merlin_fx). L'éclatante reste réservée aux VRAIS jets : le
	# risque est le seul chemin vers l'éclat. Déterministe (mêmes entrées → même verdict) →
	# R120 (preview = résolution) tient sans partager d'état. Le sabotage s'applique APRÈS,
	# comme pour un jet : même un geste sûr se laisse polluer par un tag antagoniste.
	# v46 : maitrise + rarete s'ajoutent au jet MINIMAL pour decider s'il faut encore jeter.
	# JAMAIS au Climax : le pic de la quete se joue au de, sinon l'eclatante devient
	# inatteignable la ou elle compte le plus (l'eclat n'existe que par le risque, v34).
	var m_sure: int = 0 if beat_type == "Climax" else marge_sure(played_cards, skill_mod)
	var geste_sur: bool = (2 + mods + m_sure) >= dc
	var face: int = die if die >= 2 and die <= 12 else DIE_FALLBACK
	var total: int = (2 + mods + m_sure) if geste_sur else (face + mods)
	var margin: int = total - dc

	var degree: String = REUSSITE if geste_sur else _degree_from_margin(margin, face)

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
		"die": 0 if geste_sur else die,
		"geste_sur": geste_sur,
		"marge_sure": m_sure,
		"mise": _mise(geste_sur, m_sure, dc, mods, skill_mod),
		"phrase_geste": phrase_du_geste(played_cards),
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


# v46 — MARGE SURE : ce que la maitrise du verbe et la rarete du trait retirent au risque du de.
# Talent 0 + trait Commune -> 0 (identique a v34). Statique et pur -> preview = resolution (R120).
static func marge_sure(played_cards: Array, skill_mod: int) -> int:
	var marge: int = MARGE_MAITRISE if skill_mod >= SEUIL_MAITRISE else 0
	var rare: int = 0
	for i in range(1, played_cards.size()):
		rare = maxi(rare, int(MARGE_RARETE.get(_card_rarity(played_cards[i]), 0)))
	return marge + rare


# Rarete d'une carte-like (duck-type), "Commune" si inconnue.
static func _card_rarity(c: Variant) -> String:
	if c is Object and "rarity" in c:
		return str(c.rarity)
	if c is Dictionary and c.has("rarity"):
		return str(c["rarity"])
	return "Commune"


# v46 — LA MISE, annoncee AVANT le de (Hands of Fate 2 montre la cible, il ne la cache pas).
# Dit l'ENJEU, jamais l'issue : un geste sans jet peut encore etre sabote par un tag antagoniste.
static func _mise(geste_sur: bool, m_sure: int, dc: int, mods: int, skill_mod: int) -> String:
	if not geste_sur:
		var s: String = ("+%d" % mods) if mods >= 0 else str(mods)
		return "Difficulté %d · vos atouts %s" % [dc, s]
	if m_sure > 0 and skill_mod >= SEUIL_MAITRISE:
		return "Sans jet · maîtrise du geste"
	if m_sure > 0:
		return "Sans jet · la carte porte le geste"
	return "Sans jet · le geste est acquis"


# === v46 — LA PHRASE DU GESTE, composee par le CODE (jamais par le modele) ===
# Le modele avait ecrit « en poussant vos mains sur leur pierre de basalte » sur un OBSERVER +
# Pressentiment. Le geste n'est pas une affaire de style : c'est le VERBE joue et la MANIERE du
# trait. Le code le DIT, en clair, avant le de — le modele n'ecrit plus que la SUITE. Deterministe
# (memes cartes -> meme phrase), zero generation, zero attente : c'est du temps DONNE au LLM.
const GESTE_SOCLE: Dictionary = {
	"OBSERVER": "Vous arrêtez votre regard sur ce qui vous fait face",
	"AGIR": "Vous avancez la main et vous faites le geste",
	"COMBATTRE": "Vous plantez vos appuis et vous frappez",
	"RÉVÉLER": "Vous laissez remonter ce que le lieu retient",
	"PARLER": "Vous parlez, la voix posée",
}

# La MANIERE : un tag canon (MerlinTags.to_canon, minuscule sans accent) -> une suite de phrase.
# Les 25 concepts-coeur des 6 familles sont couverts : aucun trait ne tombe a vide.
const GESTE_MANIERE: Dictionary = {
	"sens": "et rien ne vous échappe",
	"savoir": "avec ce que vous savez déjà de ces choses",
	"memoire": "en recoupant ce que vous avez déjà vu",
	"vigilance": "sans baisser la garde",
	"force": "et rien ne vous fera reculer",
	"agilite": "vite, avant qu'on ne vous arrête",
	"endurance": "et vous tiendrez aussi longtemps qu'il faudra",
	"finesse": "sans rien brusquer",
	"empathie": "en cherchant d'abord ce que l'autre craint",
	"verbe": "et vous trouvez les mots qu'il faut",
	"ruse": "sans montrer ce que vous cherchez vraiment",
	"autorite": "et personne ici ne vous contredira",
	"franchise": "sans rien arranger",
	"instinct": "et vous suivez ce que vous pressentez",
	"nature": "comme la forêt vous l'a appris",
	"vision": "et l'image vient avant les mots",
	"rituel": "et le rite ancien vous guide",
	"sacrifice": "en acceptant d'y laisser quelque chose",
	"equilibre": "sans rien rompre",
	"mystere": "sans chercher à tout comprendre",
	"vide": "et quelque chose manque, en vous",
	"glitch": "et le geste accroche, une fraction de seconde",
	"dissolution": "pendant que quelque chose se défait en vous",
	"murmure": "et une autre voix souffle en même temps",
	"emprise": "et quelque chose d'autre décide avec vous",
}


# played_cards[0] = l'ACTION (verbe), le reste = le/les TRAIT(s). "" si le call-site n'a pas
# d'action reconnue en [0] (harnais legacy) : MerlinFx saute alors la phrase, rythme inchange.
static func phrase_du_geste(played_cards: Array) -> String:
	if played_cards.is_empty():
		return ""
	var socle: String = str(GESTE_SOCLE.get(_card_name(played_cards[0]), ""))
	if socle == "":
		return ""
	# La maniere vient du tag du TRAIT que l'action ne porte PAS deja : c'est lui qui ajoute.
	var deja: Array = []
	for t0 in _card_tags(played_cards[0]):
		deja.append(MerlinTags.to_canon(str(t0)))
	var fam: String = _card_family(played_cards[0])
	# 1) le tag du trait qui NOURRIT le verbe (meme famille, non deja porte) : c'est la synergie.
	var maniere: String = _maniere(played_cards, deja, fam)
	if maniere == "":
		maniere = _maniere(played_cards, deja, "")   # 2) a defaut, tout tag qui AJOUTE
	if maniere == "":
		maniere = _maniere(played_cards, [], "")     # 3) repli : meme un tag double donne une maniere
	if maniere == "":
		return socle + "."
	return "%s, %s." % [socle, maniere]


# `famille` non vide = on n'accepte QUE le tag de cette famille (celui qui nourrit le verbe).
static func _maniere(played_cards: Array, exclus: Array, famille: String) -> String:
	for i in range(1, played_cards.size()):
		for tg in _card_tags(played_cards[i]):
			var c: String = MerlinTags.to_canon(str(tg))
			if not GESTE_MANIERE.has(c) or exclus.has(c):
				continue
			if famille != "" and MerlinTags.family_of(c) != famille:
				continue
			return str(GESTE_MANIERE[c])
	return ""


# Nom canonique d'une carte-like (duck-type). "" si inconnu.
static func _card_name(c: Variant) -> String:
	if c is Object and "card_name" in c:
		return str(c.card_name)
	if c is Dictionary and c.has("name"):
		return str(c["name"])
	return ""
