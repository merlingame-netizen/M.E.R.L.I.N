extends Node
## MerlinRun — état de run central (autoload). Bible R60 (état structuré), R64 (Corruption),
## R65 (Intégrité + économie de main), R69 (fins). 100% logique pure (pas de LLM ici).

signal gauges_changed(integrite: int, corruption: int)
signal corruption_threshold(level: int)
signal run_ended(end_type: String)

const START_INTEGRITE: int = 10
const MAX_INTEGRITE: int = 10
const HAND_SIZE: int = 5
const CORRUPTION_THRESHOLD_STEP: int = 5
const CORRUPTION_CAP: int = 18
const SAVE_PATH: String = "user://merlin_run.json"
const SAVE_VERSION: int = 1

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
var _last_threshold: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


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
	deck = MerlinCard.starter_deck()
	hand = []
	discard = []
	_shuffle(deck)
	draw_to_full()
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


func play_and_discard(cards: Array) -> void:
	# La repioche prend le SLOT LIBÉRÉ (même index dans la main) au lieu d'être ajoutée
	# en bout de main → sinon la nouvelle carte file à droite de l'éventail (demande user 2026-05-27).
	for c in cards:
		var idx: int = hand.find(c)
		var rep: MerlinCard = _draw_one()  # tirer AVANT de défausser c (évite de re-piocher c)
		if idx >= 0:
			if rep != null:
				hand[idx] = rep
			else:
				hand.remove_at(idx)
		elif rep != null:
			hand.append(rep)
		discard.append(c)
		if not cartes_notables.has(c.card_name):
			cartes_notables.append(c.card_name)
		var arch: String = c.archetype()  # v10.11 : alimente la Carte Destin (archétype dominant du run)
		archetype_scores[arch] = int(archetype_scores.get(arch, 0)) + 1
	draw_to_full()  # filet : complète si le deck était vide à un tirage


func _draw_one() -> MerlinCard:
	if deck.is_empty():
		if discard.is_empty():
			return null
		deck = discard.duplicate()
		discard = []
		_shuffle(deck)
	return deck.pop_back() if not deck.is_empty() else null


# v10.13 (Fix 5) — INVARIANT : une main JOUABLE (≥ 2 cartes) à chaque début de beat. Filets en
# cascade : repioche normale → tirage direct de la défausse → injection de Communes neutres
# (pool total < 2, atteignable via TweaksOverlay HAND_SIZE=1 ou états dégénérés). La run ne
# soft-lock JAMAIS sur « impossible de composer un combo » (R93 : la run se termine toujours).
func ensure_playable_hand() -> void:
	draw_to_full()
	while hand.size() < 2 and not discard.is_empty():
		hand.append(discard.pop_back())
	var n: int = 0
	while hand.size() < 2:
		n += 1
		hand.append(MerlinCard.make(
			"secours_%d_%d" % [beat_index, n], "Souffle Errant", ["Instinct"],
			"Un souffle sans nom traverse la clairière et se range à ton côté.", 0))


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


# v10.11 — Draft « 1 carte sur 3 » : tire n cartes DISTINCTES du pool enrichi, pondérées par rareté,
# en excluant celles déjà possédées (deck/main/défausse). Proche climax → poids hautes raretés.
func draft_choices(n: int = 3) -> Array:
	var pool: Array = MerlinCard.enriched_pool()
	var owned: Dictionary = {}
	for c in deck:
		owned[c.id] = true
	for c in hand:
		owned[c.id] = true
	for c in discard:
		owned[c.id] = true
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
		"deck": _cards_to_dicts(deck), "hand": _cards_to_dicts(hand), "discard": _cards_to_dicts(discard),
		"summary": summary,
		"faits_marquants": faits_marquants,
		"pnj_rencontres": pnj_rencontres,
		"choix_cles": choix_cles,
		"cartes_notables": cartes_notables,
		"archetype_scores": archetype_scores,
		"last_threshold": _last_threshold,
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
