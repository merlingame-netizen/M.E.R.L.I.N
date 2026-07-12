extends Node
## MerlinRun — état de run central (autoload). Bible R60 (état structuré), R64 (Corruption),
## R65 (Intégrité + économie de main), R69 (fins). 100% logique pure (pas de LLM ici).

signal gauges_changed(integrite: int, corruption: int)
signal corruption_threshold(level: int)
signal run_ended(end_type: String)

const START_INTEGRITE: int = 10
const MAX_INTEGRITE: int = 10
# v11 (pivot ACTION+TRAIT, spec panel §C) : main de 4 TRAITS, redraw COMPLET chaque beat en cycle
# vrai (les 16 traits vus en ~4 beats — les corrompus polluent réellement).
const HAND_SIZE: int = 4
const CORRUPTION_THRESHOLD_STEP: int = 5
const CORRUPTION_CAP: int = 18
const SAVE_PATH: String = "user://merlin_run.json"
# v11 (spec §J) : bump — les saves v10.x (deck de cartes 2-combo) sont INVALIDÉES proprement
# (load_run → false → le menu ne propose que Nouvelle Partie). JAMAIS de conversion mid-run (R108).
const SAVE_VERSION: int = 2
# v11 (R113 re-spécifié) : cap 1 trait corrompu par main (re-tirage silencieux de l'excédent).
const MAX_CORRUPTED_IN_HAND: int = 1
# v11-W3 (spec §E) : cap de greffes par action — 3 slots fixes (12 total, jamais saturé en pratique).
const MAX_GRAFTS_PER_ACTION: int = 3
# N3-V1 (2026-07-06) : bornes du momentum narratif (voir var momentum). Purement narratif (ton du pont).
const MOMENTUM_MIN: int = -3
const MOMENTUM_MAX: int = 3

# === v2-W2 (2026-07-05) — ARBRE DE TALENT IN-RUN : alimente le skill_mod du moteur d20 (W1) ===
# Talent PAR VERBE (PERCEVOIR/AGIR/PARLER/RESSENTIR), remis à zéro à chaque new_run (PAS de méta
# cross-run). Points gagnés au degré (réussite +1 / éclatante +2) ; alloués AU DRAFT via un NŒUD
# DE TALENT rendu comme une carte de greffe (zéro nouvel écran, R136). skill_mod d'une résolution =
# niveau de talent du VERBE de l'action jouée. Constantes de départ (À TUNER par le probe §K).
const TALENT_CAP: int = 5           # niveau max par verbe
const TALENT_COST: int = 2          # points de talent par +1 de niveau
const TALENT_GAIN_REUSSITE: int = 1 # points gagnés sur une réussite
const TALENT_GAIN_ECLATANTE: int = 2 # ... sur une éclatante
# Les 4 clés de verbe canoniques (== MerlinCard.card_name des actions). L'ordre est stable.
const TALENT_VERBS: Array = ["PERCEVOIR", "AGIR", "PARLER", "RESSENTIR"]

# v10.11 (user 2026-06-07) — Deck enrichi + Draft + Carte Destin (Slay the Spire allégé).
# Poids de rareté du draft (somme = 100) ; barème merlin-game-designer.
const DRAFT_WEIGHTS_NORMAL: Dictionary = {"Rare": 68, "Épique": 26, "Mythique": 6}
const DRAFT_WEIGHTS_LATE: Dictionary = {"Rare": 50, "Épique": 38, "Mythique": 12}  # proche climax : booste les hautes raretés
const HAND_CAP_EXTRA: int = 3  # DRAW peut dépasser HAND_SIZE de ce nombre (anti-débordement de l'éventail)

# Carte Destin : archétype dominant → « Voie » (nom + tag représentatif pour le glyphe + couleur famille).
const DESTIN_VOIES: Dictionary = {
	"Offensif": {"nom": "La Voie de Fer", "tag": "Force", "color": "A8703E"},
	"Défensif": {"nom": "La Voie de Pierre", "tag": "Équilibre", "color": "7FA6C9"},
	"Social": {"nom": "La Voie de Miel", "tag": "Verbe", "color": "B5C04F"},
	"Mystique": {"nom": "La Voie des Brumes", "tag": "Vision", "color": "C9A24B"},
	"Corrompu": {"nom": "La Voie de l'Ombre", "tag": "Emprise", "color": "7B4FA3"},
}
const DESTIN_TIER_LABELS: Dictionary = {
	"Commune": "Naissante", "Rare": "Affirmée", "Épique": "Dominante", "Mythique": "Absolue",
}

var integrite: int = START_INTEGRITE
var corruption: int = 0
var scenario: Dictionary = {}
var beat_index: int = 0
# v11 — les 4 ACTIONS permanentes (tuiles, jamais défaussées, greffables W3). deck/hand/discard
# ne contiennent plus QUE des TRAITS.
var actions: Array = []
var deck: Array = []
var hand: Array = []
var discard: Array = []
var summary: String = ""
var faits_marquants: Array = []
var pnj_rencontres: Array = []
var choix_cles: Array = []
var cartes_notables: Array = []
var archetype_scores: Dictionary = {}  # v10.11 : compteur des archétypes des cartes JOUÉES (→ Carte Destin)
var ended: bool = false
var end_type: String = ""
# v10.14 : degré du DERNIER beat résolu (pilote la ramification v1). Transient volontaire :
# le swap de variante a lieu AVANT le save → jamais nécessaire au resume (R108).
var last_degree: String = ""
# Wave D — l'offrande du pilier (beat Rencontre) a déjà été proposée cette run. Persisté (R108) : posé à
# l'OUVERTURE du modal → une offrande consommée n'est jamais re-proposée au resume / au replay de beat.
var pilier_offering_done: bool = false
# v1.0-V4a (BAL-11-B, review MEDIUM) — le draft d'OUVERTURE a été proposé (pris OU passé). Persisté
# (champ additif, défaut false) : un « Passer » au beat 0 n'est jamais re-proposé au resume
# (anti re-roll fishing — même contrat que pilier_offering_done).
var opening_draft_done: bool = false
# v10.22 — BIOME de la run (démo : "foret" | "falaises"). Choisi au menu (Nouvelle Partie), persisté
# (R108 : resume = même monde). Override test/harnais : env MERLIN_BIOME. Champ additif (saves legacy OK).
var biome: String = "foret"
# v10.21 (Wave G, R130) — budget « Pousser » restant pour la QUÊTE courante (1/quête, rechargé au répit).
var pushes_left_quest: int = 1
# v10.21 (Wave I, R131) — INTERVENTIONS du pilier : beats planifiés (à la Rencontre) + compteur (cap 2),
# persistés (R108). blessed_tags {card_id: tag} = bénédictions actives, consommées à la pose.
var intervention_beats: Array = []
var pilier_interventions: int = 0
var blessed_tags: Dictionary = {}
# v11-W3 (review M1) — DRAW de greffe : la pioche porte sur la MAIN SUIVANTE. Le redraw COMPLET
# par beat rendait une pioche immédiate MORTE (traits défaussés avant d'être jouables — coût
# affiché > valeur réelle, pilier ÉVIDENT violé). Persisté (champ additif, défaut 0) : le save de
# _advance_to_next précède le redraw du beat suivant (R108).
var next_draw_bonus: int = 0
# v2-W2 (2026-07-05) — ARBRE DE TALENT IN-RUN (alimente skill_mod du d20). talent = niveau par verbe ;
# talent_points = points non dépensés ; verb_usage = compteur de poses par verbe (cible du nœud de
# draft). TOUS réinitialisés à new_run (pas de save méta). Persistés (champs ADDITIFS, défauts safe
# au load — pas de bump SAVE_VERSION) : la prise d'un nœud est une progression réelle (R108).
var talent: Dictionary = {"PERCEVOIR": 0, "AGIR": 0, "PARLER": 0, "RESSENTIR": 0}
var talent_points: int = 0
var verb_usage: Dictionary = {"PERCEVOIR": 0, "AGIR": 0, "PARLER": 0, "RESSENTIR": 0}
# N3-V1 (2026-07-06) : MOMENTUM NARRATIF (colore le TON du pont inter-beats, ZÉRO impact §K/moteur).
# +1 par réussite/éclatante, -1 par échec/partiel, clampé [MOMENTUM_MIN, MOMENTUM_MAX]. Remis à zéro
# à new_run. Persisté (champ additif, défaut 0 au load : saves antérieures repartent neutres, pas de
# bump SAVE_VERSION). Le momentum MÉCANIQUE (impact sur le jet) est réservé à une Vague 2 distincte.
var momentum: int = 0
# P2 (2026-07-11) : TRAÇAGE DE RÉCOMPENSE (récap MerlinEnd, chantier 2 « la récompense visible »).
# corruption_max = pic de Corruption atteint sur la run (elle peut retomber via PURGE) ;
# degree_counts = distribution des degrés RÉSOLUS. PUREMENT DESCRIPTIFS : lus par end_recap()
# seulement, JAMAIS par le moteur §K (résolution/tags/difficulté intacts, soak iso). Remis à zéro à
# new_run, persistés ADDITIFS (défauts safe au load, pas de bump SAVE_VERSION).
var corruption_max: int = 0
var degree_counts: Dictionary = {"echec": 0, "partiel": 0, "reussite": 0, "eclatante": 0}


# Tags bénis portés par les cartes de ce combo (canal bonus de MerlinResolution.resolve, R131).
func blessed_bonus(combo: Array) -> Array:
	var out: Array = []
	for c in combo:
		if c is Object and c.get("id") != null and blessed_tags.has(str(c.id)):
			out.append(str(blessed_tags[str(c.id)]))
	return out


# Consomme les bénédictions des cartes jouées (une bénédiction sert UNE fois).
func consume_blessings(combo: Array) -> void:
	for c in combo:
		if c is Object and c.get("id") != null:
			blessed_tags.erase(str(c.id))


# v10.21 (R131) — mutation de corruption via API unique : jauges + seuils + fin (spec panel).
func add_corruption(n: int) -> void:
	corruption = maxi(0, corruption + n)
	corruption_max = maxi(corruption_max, corruption)  # P2 : pic pour le récap MerlinEnd (descriptif pur)
	emit_signal("gauges_changed", integrite, corruption)
	_check_corruption_threshold()


# Pioche N cartes hors résolution (don du Compagnon, R131) — respecte le cap de main.
func draw_extra(n: int) -> void:
	var cap: int = _hand_size() + HAND_CAP_EXTRA
	for i in n:
		if hand.size() >= cap:
			break
		if deck.is_empty():
			if discard.is_empty():
				break
			deck = discard.duplicate()
			discard = []
			_shuffle(deck)
		hand.append(deck.pop_back())
	_enforce_hand_caps()  # v11 (R113) : toute pioche mid-beat re-passe le cap ≤1 corrompu
var _last_threshold: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if OS.has_environment("MERLIN_BIOME"):  # v10.22 : override test/harnais (probe, autoplay, captures)
		biome = OS.get_environment("MERLIN_BIOME")


func new_run(p_scenario: Dictionary) -> void:
	# v10 dashboard : constantes lues via TweaksOverlay (hot-reload depuis mission-control). Default
	# = const local si TweaksOverlay absent ou clé non définie. (user 2026-05-31 /goal)
	integrite = _start_integrite()
	corruption = 0
	scenario = p_scenario.duplicate(true)
	beat_index = 0
	summary = ""
	faits_marquants = []
	pnj_rencontres = []
	choix_cles = []
	cartes_notables = []
	archetype_scores = {}
	ended = false
	end_type = ""
	_last_threshold = 0
	pilier_offering_done = false
	opening_draft_done = false
	pushes_left_quest = MerlinResolution.PUSH_BUDGET_PER_QUEST
	intervention_beats = []
	pilier_interventions = 0
	blessed_tags = {}
	next_draw_bonus = 0
	talent = {"PERCEVOIR": 0, "AGIR": 0, "PARLER": 0, "RESSENTIR": 0}  # v2-W2 : talent IN-RUN, remis à zéro
	talent_points = 0
	verb_usage = {"PERCEVOIR": 0, "AGIR": 0, "PARLER": 0, "RESSENTIR": 0}
	momentum = 0  # N3-V1 : le ton narratif repart neutre à chaque run
	corruption_max = 0  # P2 : traçage de récompense remis à zéro
	degree_counts = {"echec": 0, "partiel": 0, "reussite": 0, "eclatante": 0}
	actions = MerlinCard.make_actions()  # v11 : les 4 verbes fixes évolutifs
	deck = MerlinCard.starter_traits()   # v11 : 16 traits (12 canon retagués + 4 nouveaux)
	hand = []
	discard = []
	_shuffle(deck)
	draw_to_full()
	_enforce_hand_caps()
	emit_signal("gauges_changed", integrite, corruption)


func draw_to_full() -> void:
	var hs: int = _hand_size()
	while hand.size() < hs:
		if deck.is_empty():
			if discard.is_empty():
				break
			deck = discard.duplicate()
			discard = []
			_shuffle(deck)
		hand.append(deck.pop_back())


# v10 dashboard helpers : lit TweaksOverlay si présent (autoload registré APRÈS MerlinRun dans
# project.godot). v10.6 — guard `is_inside_tree()` : une instance MerlinRun créée HORS arbre
# (harness probe_combos/probe_prose via RunScript.new()) ferait planter get_node_or_null avec un
# chemin absolu. Hors arbre → on retombe sur les constantes locales (pas de tweaks dashboard).
func _tweaks_node() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/TweaksOverlay")


func _start_integrite() -> int:
	var to: Node = _tweaks_node()
	return to.get_int("START_INTEGRITE", START_INTEGRITE) if to != null and to.has_method("get_int") else START_INTEGRITE


func _hand_size() -> int:
	var to: Node = _tweaks_node()
	return to.get_int("HAND_SIZE", HAND_SIZE) if to != null and to.has_method("get_int") else HAND_SIZE


func _max_integrite() -> int:
	var to: Node = _tweaks_node()
	return to.get_int("MAX_INTEGRITE", MAX_INTEGRITE) if to != null and to.has_method("get_int") else MAX_INTEGRITE


func _corruption_cap() -> int:
	var to: Node = _tweaks_node()
	return to.get_int("CORRUPTION_CAP", CORRUPTION_CAP) if to != null and to.has_method("get_int") else CORRUPTION_CAP


# v10 dashboard : accès public aux constantes effectives (avec tweaks appliqués) pour le snapshot
# JSON du dashboard. Évite l'accès direct `run.MAX_INTEGRITE` qui n'est pas garanti depuis un
# autre autoload sans class_name. (user 2026-05-31 /goal)
func get_run_constants() -> Dictionary:
	return {
		"START_INTEGRITE": _start_integrite(),
		"HAND_SIZE": _hand_size(),
		"MAX_INTEGRITE": _max_integrite(),
		"CORRUPTION_CAP": _corruption_cap(),
	}


# v11 (pivot) — le geste = [ACTION, TRAIT]. L'action est PERMANENTE (jamais défaussée, jamais
# repiochée) ; seul le trait rejoint la défausse. Pas de repioche au slot : la main entière est
# redistribuée au beat suivant (redraw_hand, cycle vrai).
func play_and_discard(cards: Array) -> void:
	for c in cards:
		if c.is_action():
			var arch_a: String = c.archetype()  # la Carte Destin lit aussi le verbe dominant
			archetype_scores[arch_a] = int(archetype_scores.get(arch_a, 0)) + 1
			continue
		var idx: int = hand.find(c)
		if idx >= 0:
			hand.remove_at(idx)
		discard.append(c)
		if not cartes_notables.has(c.card_name):
			cartes_notables.append(c.card_name)
		var arch: String = c.archetype()  # v10.11 : alimente la Carte Destin (archétype dominant du run)
		archetype_scores[arch] = int(archetype_scores.get(arch, 0)) + 1


# v11 (spec §C) — REDRAW COMPLET au début de chaque beat, en CYCLE VRAI : défausse totale de la
# main, tirage sans remise, reshuffle quand le paquet s'épuise. Les 16 traits sont vus en ~4 beats ;
# les corrompus injectés aux seuils polluent réellement le cycle.
func redraw_hand() -> void:
	while not hand.is_empty():
		discard.append(hand.pop_back())
	draw_to_full()
	# v11-W3 (review M1) — bonus de pioche des greffes DRAW, consommé ICI : la main de ce beat
	# est élargie d'autant (borné par le cap de main dans _draw_extra).
	if next_draw_bonus > 0:
		_draw_extra(next_draw_bonus)
		next_draw_bonus = 0
	_enforce_hand_caps()


# v11 (R113 re-spécifié) — les 4 ACTIONS sont toujours jouables (soft-lock impossible PAR
# CONSTRUCTION) ; la main est bornée : ≤1 trait corrompu (re-tirage silencieux de l'excédent,
# l'excédent retourne SOUS le paquet) et ≥1 trait en main (filet états dégénérés).
func _enforce_hand_caps() -> void:
	var guard: int = 0
	while _corrupted_in_hand() > MAX_CORRUPTED_IN_HAND and guard < 32:
		guard += 1
		var swapped: bool = false
		for i in hand.size():
			if (hand[i] as MerlinCard).is_corrupted_trait():
				var rep: MerlinCard = _draw_one_clean()
				if rep == null:
					break  # plus rien de sain à tirer → on garde l'excédent (cycle saturé)
				deck.push_front(hand[i])  # sous le paquet — reviendra, mais pas cette main
				hand[i] = rep
				swapped = true
				break
		if not swapped:
			break
	if hand.is_empty():
		hand.append(MerlinCard.make(
			"secours_%d" % beat_index, "Souffle Errant", ["Instinct"],
			"Un souffle sans nom traverse la clairière et se range à ton côté.", 0))


func _corrupted_in_hand() -> int:
	var n: int = 0
	for c in hand:
		if (c as MerlinCard).is_corrupted_trait():
			n += 1
	return n


# Tire le prochain trait SAIN du paquet. Les corrompus croisés sont mis en TAMPON puis reposés
# sous le paquet À LA FIN — les reposer immédiatement empêchait le paquet de se vider, donc la
# défausse (pleine de traits sains) n'était jamais rebrassée : cap R113 violé (soak run#8/47/151/177).
func _draw_one_clean() -> MerlinCard:
	var rejected: Array = []
	var out: MerlinCard = null
	var guard: int = deck.size() + discard.size() + 2
	while guard > 0:
		guard -= 1
		var c: MerlinCard = _draw_one()
		if c == null:
			break
		if c.is_corrupted_trait():
			rejected.append(c)
		else:
			out = c
			break
	for r in rejected:
		deck.push_front(r)
	return out


func _draw_one() -> MerlinCard:
	if deck.is_empty():
		if discard.is_empty():
			return null
		deck = discard.duplicate()
		discard = []
		_shuffle(deck)
	return deck.pop_back() if not deck.is_empty() else null


# v11 (R113 re-spécifié) — INVARIANT : les 4 ACTIONS sont toujours jouables, la main porte ≥1
# TRAIT (filets dans _enforce_hand_caps). La run ne soft-lock JAMAIS (R93) — par construction.
func ensure_playable_hand() -> void:
	draw_to_full()
	_enforce_hand_caps()


# v10.11 — Effets actifs des cartes jouées (Rare+). Appelé APRÈS play_and_discard et AVANT apply_resolution
# (la mort est vérifiée par apply_resolution → un HEAL peut sauver in extremis). Renvoie un résumé pour l'UI.
func apply_card_effects(cards: Array) -> Dictionary:
	var heal: int = 0
	var purge: int = 0
	var draw: int = 0
	for c in cards:
		if c == null:
			continue
		match str(c.effect_type):
			"HEAL": heal += int(c.effect_value)
			"PURGE": purge += int(c.effect_value)
			"DRAW": draw += int(c.effect_value)
	if heal > 0:
		integrite = clampi(integrite + heal, 0, _max_integrite())
	if purge > 0:
		corruption = maxi(0, corruption - purge)
	if draw > 0:
		_draw_extra(draw)
	if heal > 0 or purge > 0:
		emit_signal("gauges_changed", integrite, corruption)
	return {"heal": heal, "purge": purge, "draw": draw}


func _draw_extra(n: int) -> void:
	var cap: int = _hand_size() + HAND_CAP_EXTRA
	for _i in n:
		if hand.size() >= cap:
			break
		var c: MerlinCard = _draw_one()
		if c == null:
			break
		hand.append(c)
	_enforce_hand_caps()  # v11 (R113) : l'effet DRAW aussi — jamais 2 corrompus en main


# v10.11 — Draft « 1 carte sur 3 » : tire n cartes DISTINCTES du pool enrichi, pondérées par rareté,
# en excluant celles déjà possédées (deck/main/défausse). Proche climax → poids hautes raretés.
# Cartes déjà possédées (deck + main + défausse), par id. Partagé par draft_choices ET pilier_offering (DRY).
func owned_ids() -> Dictionary:
	var owned: Dictionary = {}
	for c in deck:
		owned[c.id] = true
	for c in hand:
		owned[c.id] = true
	for c in discard:
		owned[c.id] = true
	return owned


# Wave D — offrande du pilier (beat Rencontre) : tire jusqu'à n cartes de la banque SIGNÉE du pilier, filtrées
# par owned_ids (jamais de doublon), mélangées via _rng (variance). Banque vide après filtre → [] (merlin_game
# SKIP le modal, jamais d'array vide). La sélection vit ici (RNG de la run), la banque dans MerlinCard.pilier_bank.
func pilier_offering(pilier: String, n: int = 2) -> Array:
	var bank: Array = MerlinCard.pilier_bank(pilier)
	var owned: Dictionary = owned_ids()
	var avail: Array = []
	for c in bank:
		if not owned.has(c.id):
			avail.append(c)
	# Mélange Fisher-Yates partiel (RNG de la run) puis prend les n premières → variance entre runs.
	for i in range(avail.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = avail[i]
		avail[i] = avail[j]
		avail[j] = tmp
	return avail.slice(0, mini(n, avail.size()))


func draft_choices(n: int = 3) -> Array:
	var pool: Array = MerlinCard.enriched_pool()
	var owned: Dictionary = owned_ids()
	var avail: Array = []
	for c in pool:
		if not owned.has(c.id):
			avail.append(c)
	var weights: Dictionary = DRAFT_WEIGHTS_LATE if _near_climax() else DRAFT_WEIGHTS_NORMAL
	var picks: Array = []
	var guard: int = 0
	while picks.size() < n and not avail.is_empty() and guard < 300:
		guard += 1
		var rar: String = _weighted_rarity(weights)
		var bucket: Array = []
		for c in avail:
			if c.rarity == rar:
				bucket.append(c)
		if bucket.is_empty():
			bucket = avail
		var pick: MerlinCard = bucket[_rng.randi_range(0, bucket.size() - 1)]
		picks.append(pick)
		avail.erase(pick)
	return picks


func _weighted_rarity(weights: Dictionary) -> String:
	var total: int = 0
	for k in weights:
		total += int(weights[k])
	if total <= 0:
		return "Rare"
	var r: int = _rng.randi_range(1, total)
	var acc: int = 0
	for k in weights:
		acc += int(weights[k])
		if r <= acc:
			return str(k)
	return "Rare"


func _near_climax() -> bool:
	# v10.14 — relatif à la QUÊTE courante (le draft booste les hautes raretés près de chaque
	# climax de quête). Fallback global pour les squelettes legacy sans qn/qtotal.
	var b: Dictionary = current_beat()
	if b.has("qtotal"):
		return int(b.get("qn", 1)) >= int(b.get("qtotal", 5)) - 1
	var total: int = int(scenario.get("total", 5))
	return beat_index >= total - 2


# Carte draftée ajoutée au BOUT du paquet (pioché au prochain tirage → gratification rapide sur run court).
func add_card_to_deck(card: MerlinCard) -> void:
	if card == null:
		return
	deck.append(card)
	if not cartes_notables.has(card.card_name):
		cartes_notables.append(card.card_name)


# === v11-W3 (spec §E) — GREFFES : le draft pose une greffe sur une ACTION (cap 3/action) ===

# Retrouve l'action par id — les ids action_* sont STABLES (survivent au resume R108).
func _action_by_id(action_id: String) -> MerlinCard:
	for a in actions:
		if a is MerlinCard and str((a as MerlinCard).id) == action_id:
			return a
	return null


# Ids des greffes DÉJÀ posées (toutes actions) — le draft les exclut (jamais de doublon).
func placed_graft_ids() -> Dictionary:
	var out: Dictionary = {}
	for a in actions:
		if not (a is MerlinCard):
			continue
		for g in (a as MerlinCard).grafts:
			if g is Dictionary:
				out[str((g as Dictionary).get("id", ""))] = true
	return out


# v1.0-V4a (GD-32-B) — nb TOTAL de greffes posées sur le build (contre-pression §E : tout beat de
# quête 3 passe à 3 requis dès total ≥ 3). Lu par merlin_scenario.effective_difficulty + le probe.
func total_grafts() -> int:
	var n: int = 0
	for a in actions:
		if a is MerlinCard:
			n += ((a as MerlinCard).grafts as Array).size()
	return n


# Y a-t-il encore une action greffable ? (les 4 pleines → le draft ne se déclenche plus)
func has_graftable_action() -> bool:
	for a in actions:
		if a is MerlinCard and ((a as MerlinCard).grafts as Array).size() < MAX_GRAFTS_PER_ACTION:
			return true
	return false


# Pose une greffe sur l'action ciblée. Cap 3/action → false si pleine. Le prix est ONE-SHOT à la
# pose (corr_cost via add_corruption — guardrail CRITICAL : jamais récurrent, l'action reste à
# corruption 0). N'APPELLE PAS save() : atomicité via le save unique de _advance_to_next (R108).
func apply_graft(action_id: String, graft: Dictionary) -> bool:
	var act: MerlinCard = _action_by_id(action_id)
	if act == null or graft.is_empty():
		return false
	if (act.grafts as Array).size() >= MAX_GRAFTS_PER_ACTION:
		return false
	act.grafts.append(graft.duplicate(true))
	act.refresh_from_grafts()  # dérivation unique : tags = base + greffés, rarity = f(nb greffes)
	var price: int = int(graft.get("corr_cost", 0))
	if price > 0:
		add_corruption(price)
	var gname: String = str(graft.get("name", ""))
	if gname != "" and not cartes_notables.has(gname):
		cartes_notables.append(gname)  # la greffe nourrit la mémoire du run (état LLM)
	return true


# À la pose du VERBE : consomme 1 charge de chaque greffe "charge" de l'action jouée (HEAL/PURGE/
# DRAW — mêmes règles qu'apply_card_effects ; DRAW pioche des TRAITS pour la main du beat SUIVANT,
# review M1 : le redraw complet rend toute pioche immédiate morte). Appelée par merlin_game.
# _on_resolve à côté d'apply_card_effects (AVANT le check de mort — un HEAL peut sauver).
func apply_graft_charges(action: MerlinCard) -> Dictionary:
	var heal: int = 0
	var purge: int = 0
	var draw: int = 0
	if action == null:
		return {"heal": 0, "purge": 0, "draw": 0}
	for g in action.grafts:
		if not (g is Dictionary) or str((g as Dictionary).get("kind", "")) != "charge":
			continue
		var gd: Dictionary = g
		if int(gd.get("charges", 0)) <= 0:
			continue  # greffe épuisée — le glyphe reste dessiné (compteur 0, estompé)
		gd["charges"] = int(gd.get("charges", 0)) - 1
		match str(gd.get("effect_type", "")):
			"HEAL": heal += int(gd.get("effect_value", 1))
			"PURGE": purge += int(gd.get("effect_value", 1))
			"DRAW": draw += int(gd.get("effect_value", 1))
	if heal > 0:
		integrite = clampi(integrite + heal, 0, _max_integrite())
	if purge > 0:
		corruption = maxi(0, corruption - purge)
	if draw > 0:
		next_draw_bonus += draw  # consommé par redraw_hand au beat suivant (cap main + R113 là-bas)
	if heal > 0 or purge > 0:
		emit_signal("gauges_changed", integrite, corruption)
	return {"heal": heal, "purge": purge, "draw": draw}


# v2-W3 (2026-07-05) — BONUS AU JET des greffes « roll » posées sur l'action jouée : somme des
# `amount` de chaque greffe kind=="roll". Alimente graft_bonus du moteur d20 (resolve, W1), passé par
# merlin_game aux DEUX call-sites (preview + résolution — R120 : mêmes args). 0 si carte non-action.
# Migration legacy (save v11 posée AVANT le pivot) : une greffe kind=="die" est TOLÉRÉE et comptée
# comme une roll d'amount ROLL_BONUS_DEFAULT (jamais de crash au load, jamais de bande inerte).
func graft_roll_bonus(action: Variant) -> int:
	if action == null or not (action is Object) or not (action.get("grafts") is Array):
		return 0
	var total: int = 0
	for g in (action.grafts as Array):
		if not (g is Dictionary):
			continue
		var kind: String = str((g as Dictionary).get("kind", ""))
		if kind == "roll":
			total += int((g as Dictionary).get("amount", MerlinCard.ROLL_BONUS_DEFAULT))
		elif kind == "die":  # legacy pré-pivot : proxy roll par défaut (compat save R108, jamais inerte)
			total += MerlinCard.ROLL_BONUS_DEFAULT
	return total


# Draft runtime v11-W3 : n greffes GÉNÉRIQUES distinctes (remplace draft_choices au runtime —
# l'ancienne fonction reste pour compat outillage mais n'est plus appelée par le jeu).
func graft_choices(n: int = 3) -> Array:
	return _graft_pick(MerlinCard.graft_banks(""), n)


# Offrande du pilier v11-W3 : n greffes de la banque SIGNÉE (remplace pilier_offering au runtime).
func pilier_graft_offering(pilier: String, n: int = 2) -> Array:
	return _graft_pick(MerlinCard.graft_banks(pilier), n)


# Tirage commun : filtre les greffes déjà posées (par id), mélange via le RNG de la run (variance
# entre runs, même pattern Fisher-Yates que pilier_offering), tronque à n. [] si banque épuisée.
func _graft_pick(bank: Array, n: int) -> Array:
	var placed: Dictionary = placed_graft_ids()
	var avail: Array = []
	for g in bank:
		if g is Dictionary and not placed.has(str((g as Dictionary).get("id", ""))):
			avail.append(g)
	for i in range(avail.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = avail[i]
		avail[i] = avail[j]
		avail[j] = tmp
	return avail.slice(0, mini(n, avail.size()))


# === v2-W2 (2026-07-05) — ARBRE DE TALENT : verbe joué, gain au degré, nœud de draft ===

# Clé de talent (verbe) d'une carte ACTION : son card_name (PERCEVOIR/AGIR/PARLER/RESSENTIR).
# Duck-typé (une carte de trait renvoie "" → jamais de talent). "" si non-action / clé inconnue.
func verb_of_action(card: Variant) -> String:
	if card == null:
		return ""
	if card is Object and card.has_method("is_action") and card.is_action():
		var v: String = str(card.card_name)
		return v if talent.has(v) else ""
	return ""


# === N5-C2 (2026-07-12) - MAÎTRISE PAR USAGE : le verbe JOUÉ monte en jet à mesure qu'on le pose ===
# verb_usage[verbe] (compteur de poses, déjà incrémenté par note_verb_played + persisté R108) donne
# un bonus de jet PAR PALIER, CANALISÉ dans skill_mod (même voie que le talent W2). Le total d20 garde
# ainsi EXACTEMENT ses 4 sources additives (skill_mod + graft_bonus + couverture + synergie) - pas de
# 5e terme → §K reste re-dérivable par mesure soak. Paliers dérivés de la LONGUEUR de run (~7-11 beats,
# build_chain_beats) : entrée à 3 poses (palier +1 en milieu de run pour un verbe favori), +2 à 6 poses
# (spécialisation nette, fin de run). Un jeu généraliste (~2 poses/verbe) ne franchit JAMAIS le 1er palier :
# la maîtrise récompense la SPÉCIALISATION. À TUNER par le probe §K (levier préféré si éclatante > 15% :
# ECLAT_MARGIN, pas DC - cf. spec game-designer N5).
const MASTERY_PALIERS: Dictionary = {0: 0, 3: 1, 6: 2}  # usage >= clé -> bonus (palier le plus haut qui matche)
const MASTERY_CAP: int = 2       # bonus de maîtrise max par verbe (canal skill_mod)


# Bonus de maîtrise pour un compteur d'usage donné : palier le plus haut atteint, plafonné MASTERY_CAP.
# Prend l'usage (int) et non le verbe → réutilisable pour comparer usage vs usage-1 (palier franchi ?).
func mastery_bonus_for(usage: int) -> int:
	var b: int = 0
	for k in MASTERY_PALIERS:
		if usage >= int(k):
			b = maxi(b, int(MASTERY_PALIERS[k]))
	return mini(b, MASTERY_CAP)


# Bonus de maîtrise COURANT du verbe (lu par la tuile + la ligne méca). 0 si verbe inconnu.
func verb_mastery_bonus(verb: String) -> int:
	if verb == "" or not verb_usage.has(verb):
		return 0
	return mastery_bonus_for(int(verb_usage.get(verb, 0)))


# N5-C2 - progression de maîtrise du verbe pour la JAUGE de tuile : {bonus, frac, at_cap, usage}.
# frac = progression [0,1] vers le PROCHAIN palier (1.0 au plafond). Purement descriptif (zéro §K).
func mastery_progress(verb: String) -> Dictionary:
	if verb == "" or not verb_usage.has(verb):
		return {"bonus": 0, "frac": 0.0, "at_cap": false, "usage": 0}
	var u: int = int(verb_usage.get(verb, 0))
	var bonus: int = mastery_bonus_for(u)
	if bonus >= MASTERY_CAP:
		return {"bonus": bonus, "frac": 1.0, "at_cap": true, "usage": u}
	# Seuils triés : palier courant (dernier <= u) et palier suivant → fraction de progression entre eux.
	var thresholds: Array = MASTERY_PALIERS.keys()
	thresholds.sort()
	var cur_t: int = 0
	var next_t: int = -1
	for k in thresholds:
		var ki: int = int(k)
		if u >= ki:
			cur_t = ki
		elif next_t < 0:
			next_t = ki
	if next_t < 0:
		return {"bonus": bonus, "frac": 1.0, "at_cap": true, "usage": u}
	var span: int = next_t - cur_t
	var frac: float = 0.0 if span <= 0 else clampf(float(u - cur_t) / float(span), 0.0, 1.0)
	return {"bonus": bonus, "frac": frac, "at_cap": false, "usage": u}


# skill_mod d'un geste : talent du verbe (nœud de draft W2) + MAÎTRISE par usage (N5-C2). 0 si carte
# non-action. Lu par merlin_game aux DEUX call-sites resolve (preview + résolution) - invariant R120.
func skill_mod_for(action_card: Variant) -> int:
	var v: String = verb_of_action(action_card)
	if v == "":
		return 0
	return int(talent.get(v, 0)) + mastery_bonus_for(int(verb_usage.get(v, 0)))


# Incrémente le compteur d'usage du VERBE joué (cible du nœud de talent au draft). Appelé quand un
# combo est posé (à côté de play_and_discard). No-op si la carte n'est pas une action canonique.
func note_verb_played(action_card: Variant) -> void:
	var v: String = verb_of_action(action_card)
	if v != "":
		verb_usage[v] = int(verb_usage.get(v, 0)) + 1


# Gain de points de talent au DEGRÉ (réussite +1 / éclatante +2 ; partiel/échec 0). Appelé là où le
# degré est appliqué (merlin_game._on_resolve / le probe), à côté d'apply_resolution.
func gain_talent_points(degree: String) -> void:
	if degree == MerlinResolution.REUSSITE:
		talent_points += TALENT_GAIN_REUSSITE
	elif degree == MerlinResolution.ECLATANTE:
		talent_points += TALENT_GAIN_ECLATANTE


# Y a-t-il un verbe encore améliorable (niveau < cap) ? Sinon le nœud de talent ne s'offre plus.
func has_upgradable_verb() -> bool:
	for v in TALENT_VERBS:
		if int(talent.get(v, 0)) < TALENT_CAP:
			return true
	return false


# Le nœud de talent peut-il s'offrir au draft ? Assez de points ET un verbe sous le cap.
func can_offer_talent_node() -> bool:
	return talent_points >= TALENT_COST and has_upgradable_verb()


# Verbe CIBLE du nœud de talent : le plus utilisé (argmax verb_usage) parmi ceux encore sous le cap ;
# à défaut d'usage, le verbe de plus BAS talent ; fallback final PERCEVOIR. Ordre TALENT_VERBS stable
# pour départager les ex æquo (déterministe : le jeu ET le probe voient la même cible).
func talent_node_target() -> String:
	var best_v: String = ""
	var best_n: int = -1
	for v in TALENT_VERBS:
		if int(talent.get(v, 0)) >= TALENT_CAP:
			continue  # déjà au cap → jamais ciblé
		var n: int = int(verb_usage.get(v, 0))
		if n > best_n:
			best_n = n
			best_v = v
	if best_v != "" and best_n > 0:
		return best_v
	# Aucun usage encore (best_n == 0) : cibler le verbe de plus BAS talent sous le cap.
	var low_v: String = ""
	var low_lvl: int = TALENT_CAP + 1
	for v in TALENT_VERBS:
		var lvl: int = int(talent.get(v, 0))
		if lvl < TALENT_CAP and lvl < low_lvl:
			low_lvl = lvl
			low_v = v
	if low_v != "":
		return low_v
	return best_v if best_v != "" else "PERCEVOIR"


# Construit le NŒUD DE TALENT (dict rendu comme une carte de greffe au draft). kind "talent" le
# distingue des greffes d'action (le rendu pose alors un liseré/badge talent, pas un slot de greffe).
func build_talent_node() -> Dictionary:
	var v: String = talent_node_target()
	return {
		"kind": "talent",
		"verb": v,
		"amount": 1,
		"name": "Renforcer %s" % v,
		"evocation": "Le geste se grave en toi ; %s te répond plus vite, plus sûr." % v,
	}


# Accepte le nœud de talent : monte le verbe d'1 (clampé au cap), consomme TALENT_COST points.
# L'appelant SAUVE après (progression réelle, R108 — comme les greffes). Renvoie false si refus
# (points insuffisants OU verbe déjà au cap) → le geste de draft reste ouvert.
func apply_talent_node(node: Dictionary) -> bool:
	if str(node.get("kind", "")) != "talent":
		return false
	var v: String = str(node.get("verb", ""))
	if not talent.has(v):
		return false
	if talent_points < TALENT_COST or int(talent.get(v, 0)) >= TALENT_CAP:
		return false
	talent[v] = mini(TALENT_CAP, int(talent.get(v, 0)) + int(node.get("amount", 1)))
	talent_points -= TALENT_COST
	return true


# --- Carte Destin (archétype dominant du run) ---

func dominant_archetype() -> String:
	var best: String = ""
	var best_n: int = -1
	for a in archetype_scores:
		var n: int = int(archetype_scores[a])
		if n > best_n:
			best_n = n
			best = str(a)
	return best


func _sorted_scores() -> Array:
	var vals: Array = []
	for a in archetype_scores:
		vals.append(int(archetype_scores[a]))
	vals.sort()
	vals.reverse()
	return vals


func total_cards_played() -> int:
	var s: int = 0
	for a in archetype_scores:
		s += int(archetype_scores[a])
	return s


func destiny_lead() -> int:
	var v: Array = _sorted_scores()
	if v.is_empty():
		return 0
	var second: int = int(v[1]) if v.size() > 1 else 0
	return int(v[0]) - second


func destiny_tier() -> String:
	var lead: int = destiny_lead()
	var v: Array = _sorted_scores()
	var top: int = int(v[0]) if not v.is_empty() else 0
	# Run = 5 beats × 2 cartes = 10 cartes max jouées → top>=8 implique déjà lead>=6 (dominance nette).
	if top >= 8 or lead >= 6:
		return "Mythique"
	if lead >= 4:
		return "Épique"
	if lead >= 2:
		return "Rare"
	return "Commune"


func destiny_snapshot() -> Dictionary:
	var arch: String = dominant_archetype()
	if arch == "" or total_cards_played() == 0:
		return {}
	var voie: Dictionary = DESTIN_VOIES.get(arch, DESTIN_VOIES["Mystique"])
	var tier: String = destiny_tier()
	return {
		"archetype": arch,
		"nom": str(voie["nom"]),
		"tag": str(voie["tag"]),
		"color": str(voie["color"]),
		"tier": tier,
		"tier_label": str(DESTIN_TIER_LABELS.get(tier, "Naissante")),
		"total": total_cards_played(),
	}


func apply_resolution(res: Dictionary) -> void:
	last_degree = str(res.get("degree", ""))  # v10.14 : mémorisé pour la ramification v1
	# N3-V1 : momentum NARRATIF (ton du pont), +1 réussite/éclatante, -1 échec/partiel, clampé.
	# Aucun effet mécanique : ne touche ni les deltas ci-dessous, ni la difficulté, ni les tags (§K).
	var mdeg: String = str(res.get("degree", ""))
	if mdeg == "reussite" or mdeg == "eclatante":
		momentum = clampi(momentum + 1, MOMENTUM_MIN, MOMENTUM_MAX)
	elif mdeg == "echec" or mdeg == "partiel":
		momentum = clampi(momentum - 1, MOMENTUM_MIN, MOMENTUM_MAX)
	if degree_counts.has(mdeg):  # P2 : distribution des degrés pour le récap MerlinEnd (descriptif pur)
		degree_counts[mdeg] = int(degree_counts[mdeg]) + 1
	var di: int = int(res.get("integrite_delta", 0))
	var dc: int = int(res.get("corruption_delta", 0))
	# v10 dashboard : MAX_INTEGRITE peut être surchargé par TweaksOverlay (hot-reload).
	integrite = clampi(integrite + di, 0, _max_integrite())
	corruption = max(0, corruption + dc)
	corruption_max = maxi(corruption_max, corruption)  # P2 : pic pour le récap MerlinEnd
	emit_signal("gauges_changed", integrite, corruption)
	_check_corruption_threshold()
	_check_end_after_resolution()


func _check_corruption_threshold() -> void:
	var lvl: int = int(corruption / CORRUPTION_THRESHOLD_STEP)
	if lvl > _last_threshold:
		_last_threshold = lvl
		_inject_corrupted_card()
		emit_signal("corruption_threshold", lvl)


func _inject_corrupted_card() -> void:
	var idx: int = corruption
	var c: MerlinCard = MerlinCard.make(
		"corrompu_%d" % idx, "Murmure Corrompu", ["Murmure", "Vide"],
		"Une voix sans bouche s'invite dans ta main. Elle veut que tu l'écoutes.", 1, "Glitch")
	discard.append(c)


func _check_end_after_resolution() -> void:
	if ended:
		return
	# v10 dashboard : CORRUPTION_CAP peut être surchargé via TweaksOverlay (hot-reload).
	if corruption >= _corruption_cap():
		_end("corrompu")
	elif integrite <= 0:
		_end("mort")


func advance_beat() -> void:
	var prev_quest: int = int(current_beat().get("quest", 0))
	beat_index += 1
	if ended:
		return
	var total: int = int(scenario.get("total", 5))
	if beat_index >= total:
		_end("accomplissement")
		return
	# v10.14 — « répit du sentier » (cascade) : Intégrité rendue à chaque transition de quête,
	# clampé au max (jamais d'over-heal). Amortit le partiel -2 sur les chaînes longues.
	# Tuning soak chaînes (mesures n=300) : +1 → 40% de morts greedy/chaotic ; +2 → 31% ;
	# +2 et BONUS +2 si Intégrité ≤ 4 (« le sentier accorde un souffle quand on en a besoin »,
	# amortisseur conditionnel du designer) → cible ≤20% sans rendre `optimal` invulnérable.
	if int(current_beat().get("quest", 0)) != prev_quest:
		var repit: int = 2
		if integrite <= 4:
			repit += 2
		integrite = clampi(integrite + repit, 0, _max_integrite())
		pushes_left_quest = MerlinResolution.PUSH_BUDGET_PER_QUEST  # v10.21 (R130) : le budget Pousser se recharge avec le répit
		emit_signal("gauges_changed", integrite, corruption)
	# v10.14 — Ramification v1 : à l'ARRIVÉE sur un beat à variante (avant-climax des quêtes
	# k>=4), si le degré précédent est échec/partiel, le beat BASCULE (Epreuve<->Dilemme),
	# IN PLACE dans le scenario — le save de l'appelant (juste après) persiste le beat basculé
	# → resume déterministe (R108). Découverte AU beat : l'UI ajoute l'indice micro-narratif.
	_maybe_swap_variant()


func _maybe_swap_variant() -> void:
	var beats: Array = scenario.get("beats", [])
	if beat_index < 0 or beat_index >= beats.size():
		return
	var beat: Dictionary = beats[beat_index]
	if not beat.has("variant_type") or bool(beat.get("swapped", false)):
		return
	if last_degree != MerlinResolution.ECHEC and last_degree != MerlinResolution.PARTIEL:
		return
	beat["type"] = str(beat["variant_type"])
	beat["swapped"] = true
	beats[beat_index] = beat


func _end(p_type: String) -> void:
	ended = true
	end_type = p_type
	emit_signal("run_ended", p_type)


func current_beat() -> Dictionary:
	var beats: Array = scenario.get("beats", [])
	if beat_index >= 0 and beat_index < beats.size():
		return beats[beat_index]
	return {}


func is_climax() -> bool:
	var total: int = int(scenario.get("total", 5))
	return beat_index >= total - 1


func to_state_dict() -> Dictionary:
	return {
		"jauges": {"integrite": integrite, "corruption": corruption},
		"scenario": {
			"titre": scenario.get("title", ""),
			# v10.14 — l'état LLM compte PAR QUÊTE (le récit en cours est celui de la quête).
			"quete": str(current_beat().get("quest_title", scenario.get("title", ""))),
			"beat_courant": int(current_beat().get("qn", beat_index + 1)),
			"total": int(current_beat().get("qtotal", int(scenario.get("total", 5)))),
		},
		"faits_marquants": faits_marquants.duplicate(),
		"pnj_rencontres": pnj_rencontres.duplicate(),
		"choix_cles": choix_cles.duplicate(),
		"cartes_notables_jouees": cartes_notables.duplicate(),
	}


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# --- Sauvegarde (R73 : auto-save par beat) ---

func save() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"integrite": integrite,
		"corruption": corruption,
		"scenario": scenario,
		"beat_index": beat_index,
		"actions": _cards_to_dicts(actions),  # v11 : les 4 verbes (greffes W3 comprises)
		"deck": _cards_to_dicts(deck), "hand": _cards_to_dicts(hand), "discard": _cards_to_dicts(discard),
		"summary": summary,
		"faits_marquants": faits_marquants,
		"pnj_rencontres": pnj_rencontres,
		"choix_cles": choix_cles,
		"cartes_notables": cartes_notables,
		"archetype_scores": archetype_scores,
		"last_threshold": _last_threshold,
		"pilier_offering_done": pilier_offering_done,  # Wave D : unicité de l'offrande au resume (R108)
		"opening_draft_done": opening_draft_done,  # v1.0-V4a : unicité du draft d'ouverture (additif)
		"biome": biome,  # v10.22 : resume = même monde
		"pushes_left_quest": pushes_left_quest,  # Wave G (R130) : budget Pousser persisté (additif)
		"intervention_beats": intervention_beats, "pilier_interventions": pilier_interventions,
		"blessed_tags": blessed_tags,  # Wave I (R131) : planning + bénédictions persistés (R108)
		"next_draw_bonus": next_draw_bonus,  # v11-W3 (M1) : pioche DRAW due à la main suivante (additif)
		"talent": talent, "talent_points": talent_points, "verb_usage": verb_usage,  # v2-W2 : talent IN-RUN (additif, R108)
		"momentum": momentum,  # N3-V1 : ton narratif du pont (additif, défaut 0 au load)
		"corruption_max": corruption_max, "degree_counts": degree_counts,  # P2 : traçage récap (additif, R108)
	}
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_run() -> bool:
	if not has_save():
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		return false
	# v11 (spec §J) — INVALIDATION PROPRE des saves pré-pivot : un deck 2-combo ne se convertit
	# pas en actions+traits mid-run (R108 rend la conversion inutile — on repart au menu).
	if int(data.get("version", 1)) < SAVE_VERSION:
		clear_save()
		return false
	integrite = int(data.get("integrite", START_INTEGRITE))
	corruption = int(data.get("corruption", 0))
	scenario = data.get("scenario", {})
	beat_index = int(data.get("beat_index", 0))
	summary = str(data.get("summary", ""))
	faits_marquants = data.get("faits_marquants", [])
	pnj_rencontres = data.get("pnj_rencontres", [])
	choix_cles = data.get("choix_cles", [])
	cartes_notables = data.get("cartes_notables", [])
	archetype_scores = data.get("archetype_scores", {})
	_last_threshold = int(data.get("last_threshold", 0))
	pilier_offering_done = bool(data.get("pilier_offering_done", false))  # Wave D : défaut false (saves legacy)
	opening_draft_done = bool(data.get("opening_draft_done", false))  # v1.0-V4a : défaut false (saves antérieures)
	biome = str(data.get("biome", "foret"))  # v10.22 : défaut forêt (saves legacy)
	pushes_left_quest = int(data.get("pushes_left_quest", MerlinResolution.PUSH_BUDGET_PER_QUEST))  # Wave G (R130)
	intervention_beats = data.get("intervention_beats", [])  # Wave I (R131), défauts = saves legacy OK
	pilier_interventions = int(data.get("pilier_interventions", 0))
	blessed_tags = data.get("blessed_tags", {})
	next_draw_bonus = int(data.get("next_draw_bonus", 0))  # v11-W3 (M1) : défaut 0 (saves W2/W3 précoces OK)
	# v2-W2 — talent IN-RUN (champs additifs) : défauts SAFE au load (saves pré-W2 → 4 verbes à 0).
	# _talent_dict garantit les 4 clés présentes même si le JSON est partiel/corrompu (robustesse R108).
	talent = _talent_dict(data.get("talent", {}))
	talent_points = int(data.get("talent_points", 0))
	verb_usage = _talent_dict(data.get("verb_usage", {}))
	momentum = clampi(int(data.get("momentum", 0)), MOMENTUM_MIN, MOMENTUM_MAX)  # N3-V1 : défaut 0 (saves antérieures neutres)
	corruption_max = maxi(int(data.get("corruption_max", corruption)), corruption)  # P2 : défaut = corruption courante (saves antérieures)
	degree_counts = _degree_dict(data.get("degree_counts", {}))  # P2 : 4 clés garanties (save partiel/legacy)
	actions = _dicts_to_cards(data.get("actions", []))
	if actions.is_empty():
		actions = MerlinCard.make_actions()  # filet : jamais de run sans les 4 verbes
	deck = _dicts_to_cards(data.get("deck", []))
	hand = _dicts_to_cards(data.get("hand", []))
	discard = _dicts_to_cards(data.get("discard", []))
	ended = false
	end_type = ""
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _cards_to_dicts(arr: Array) -> Array:
	var out: Array = []
	for c in arr:
		out.append(c.to_dict())
	return out


func _dicts_to_cards(arr: Array) -> Array:
	var out: Array = []
	for d in arr:
		if d is Dictionary:
			out.append(MerlinCard.from_dict(d))
	return out


# v2-W2 — normalise un dict de talent chargé : les 4 verbes canoniques TOUJOURS présents (valeur int),
# valeurs par défaut 0. JSON.parse rend des floats → int() explicite. Robuste à un save partiel/legacy.
func _talent_dict(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	var src: Dictionary = raw if raw is Dictionary else {}
	for v in TALENT_VERBS:
		out[v] = int(src.get(v, 0))
	return out
# P2 : normalise un dict de distribution de degres charge. 4 degres canoniques TOUJOURS presents
# (int), defaut 0. Meme robustesse que _talent_dict (save partiel/legacy sans crash).
func _degree_dict(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	var src: Dictionary = raw if raw is Dictionary else {}
	for d in ["echec", "partiel", "reussite", "eclatante"]:
		out[d] = int(src.get(d, 0))
	return out


# P2 (chantier 2, la recompense visible) : RECAP de fin de run pour MerlinEnd. 100% descriptif (lit
# l'etat deja accumule, ne mute rien, ne touche pas le moteur K). verbs_leveled = verbes montes au
# talent (ex. "PARLER x2"). beats = nb d'epreuves RESOLUES (somme des degres).
func end_recap() -> Dictionary:
	var verbs_leveled: Array = []
	for v in TALENT_VERBS:
		var lvl: int = int(talent.get(v, 0))
		if lvl > 0:
			verbs_leveled.append("%s ×%d" % [v, lvl])
	var beats: int = 0
	for d in degree_counts:
		beats += int(degree_counts[d])
	return {
		"beats": beats,
		"degrees": _degree_dict(degree_counts),
		"corruption_max": corruption_max,
		"grafts": total_grafts(),
		"verbs_leveled": verbs_leveled,
		"faits": faits_marquants.duplicate(),
		"cartes_notables": cartes_notables.duplicate(),
		"voie": destiny_snapshot(),
		"integrite": integrite,
		"corruption": corruption,
	}
