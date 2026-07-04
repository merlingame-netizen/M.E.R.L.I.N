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
	pushes_left_quest = MerlinResolution.PUSH_BUDGET_PER_QUEST
	intervention_beats = []
	pilier_interventions = 0
	blessed_tags = {}
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
	var di: int = int(res.get("integrite_delta", 0))
	var dc: int = int(res.get("corruption_delta", 0))
	# v10 dashboard : MAX_INTEGRITE peut être surchargé par TweaksOverlay (hot-reload).
	integrite = clampi(integrite + di, 0, _max_integrite())
	corruption = max(0, corruption + dc)
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
		"biome": biome,  # v10.22 : resume = même monde
		"pushes_left_quest": pushes_left_quest,  # Wave G (R130) : budget Pousser persisté (additif)
		"intervention_beats": intervention_beats, "pilier_interventions": pilier_interventions,
		"blessed_tags": blessed_tags,  # Wave I (R131) : planning + bénédictions persistés (R108)
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
	biome = str(data.get("biome", "foret"))  # v10.22 : défaut forêt (saves legacy)
	pushes_left_quest = int(data.get("pushes_left_quest", MerlinResolution.PUSH_BUDGET_PER_QUEST))  # Wave G (R130)
	intervention_beats = data.get("intervention_beats", [])  # Wave I (R131), défauts = saves legacy OK
	pilier_interventions = int(data.get("pilier_interventions", 0))
	blessed_tags = data.get("blessed_tags", {})
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
