extends Node
## MerlinScenario — pipeline de génération (autoload). Bible R6/R68/R101/R107.
##
## ARCHITECTURE (contrainte hardware : moteur natif SINGLE-FLIGHT — une génération à la fois).
## Débit MESURÉ le 2026-08-15 sur la VM ARM : 4,31 tok/s (et non « ~1 tok/s », chiffre hérité
## d'Ollama qui n'avait jamais été vérifié et sur lequel des pans entiers de cette architecture
## ont pourtant été dimensionnés). Toute décision de course LLM-vs-joueur doit repartir du
## chiffre mesuré, jamais de celui-ci.
## - Le moteur ne peut PAS narrer chaque beat en temps réel (≈40-58s/gen, ~11 gens/run).
##   → Principe NON-BLOQUANT : le procédural (instantané, déjà bon) est la BASE ;
##     le LLM enrichit en arrière-plan et ne remplace QUE s'il finit avant que le
##     joueur n'avance (garde d'epoch côté scène, cf. merlin_game.gd). Une run est
##     jouable ET bonne avec ZÉRO appel LLM réussi — le LLM est du bonus.
## - GBNF cassé sur ce gemma4 → non utilisé. Le CODE possède la STRUCTURE
##   (beats, types, difficulté, required_tags) ; le LLM n'écrit que de la PROSE.
## - Sélection = seul ~JSON, pré-généré pendant l'idle du Menu (latence masquée).
##
## PRIORITÉ MOTEUR (v10.13 B0) — le moteur natif est SINGLE-FLIGHT ; hiérarchie des générations :
##   1. PROSE DE RÉSOLUTION du beat courant — la seule que le joueur attend activement.
##      prefetch_resolution PRÉEMPTE : cancel + drain de toute gen en vol à la pose (Fix 3/8).
##   2. ARC narratif (prepare_arc) — fire-and-forget, swap seulement si arc non verrouillé.
##   3. OUVERTURE (interstitiel « Merlin raconte », B3) — prefetch_opening, cache _opening_*.
##   4. ÉPILOGUE (merlin_end) — enrichissement de fond, jamais attendu.
## RÈGLE : une gen de priorité BASSE (opening, épilogue) ne se LANCE que si engine_idle() ;
## elle ne préempte JAMAIS. Seule la résolution (1) cancel ce qui occupe le moteur.

# A4 : les préfixes système (SYSTEM_PREFIX, MERLIN_VOICE_PREFIX, TAG_CUE, MAX_TOK_PROSE) et
# l'ASSEMBLAGE de tous les prompts vivent dans MerlinPromptBuilder (statique pur, prompts
# octet-identiques). Alias conservé ci-dessous : tools/probe_prose.gd lit `sc.SYSTEM_PREFIX`.
const SYSTEM_PREFIX: String = MerlinPromptBuilder.SYSTEM_PREFIX
const PERSONA_PATH: String = "res://data/ai/config/merlin_persona.json"

var _persona: Dictionary = {}

const BEAT_TYPES: Array = ["Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax"]

# v10.14 (cascade 2026-06-12) — patterns de quête par longueur k (2-5 beats). Chaque quête se
# referme sur son Climax ; seul le Climax de la DERNIÈRE quête est à difficulté 3.
const QUEST_PATTERNS: Dictionary = {
	2: ["Exploration", "Climax"],
	3: ["Exploration", "Epreuve", "Climax"],
	4: ["Exploration", "Rencontre", "Epreuve", "Climax"],
	5: ["Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax"],
}

# Chantier 2 (2026-07-25) — le marchand ne vit QU'aux beats "Rencontre" (QUEST_PATTERNS k>=4) : un
# run dont TOUTES les quêtes tirent k<=3 n'en a AUCUN (~25% des runs mesurés). GARANTIE : au moins
# MIN_RENCONTRE_PER_RUN beats "Rencontre" par run, cf. _ensure_min_rencontres (build_chain_beats).
const MIN_RENCONTRE_PER_RUN: int = 2

# Longueur de LA quête (décision Maxime : « entre 7 et 25 cartes jouées par quête »). Le haut de
# la fourchette est assumé : à 25 beats, une partie dépasse l'heure et demie sur la VM, chaque beat
# demandant au modèle une issue d'environ 35 s.
# Combien de scènes le modèle écrit d'un coup. Quatre : assez pour qu'il tienne un enchaînement,
# assez peu pour que la première tranche arrive vite (~40 s) et que la partie commence.
# Compteur des recours au banc de secours. Lu par la sonde de journal (et remis à zéro par elle)
# pour marquer les beats concernés dans le document : « écrit par le banc de secours ».
var _secours_derniers: int = 0
const ARC_TRANCHE: int = 4
# BUDGET À L'HORLOGE, et non plus un compte d'essais (revue adversariale 2026-08-18). Le moteur
# est mono-place et la résolution du beat courant passe TOUJOURS devant : elle annule une tranche
# en vol à chaque pose. Compter ces collisions comme des échecs brûlait le crédit en deux beats
# et condamnait toute la fin de quête au secours. Une collision n'est pas un échec : seul un
# moteur LIBRE qui rend un tableau vide en est un (deux suffisent à renoncer).
# 1 et non 2 : au palier 2 l'écriture passe à ~33 s et re-rate la fenêtre sous contention
# (4 secours sur 6 à la validation). Le palier 1 fait déjà réagir la scène (le chevalier se
# redresse) pour ~22 s d'écriture. Le 2 reste le preset « Riche » des Options.
# 2 de nouveau : sur le Vif (e2b, ~7 tok/s d'écriture), les 7-9 phrases tiennent dans la
# fenêtre — c'était l'écriture e4b qui la faisait déborder.
const RICHESSE_ISSUE: int = 1  # v34 : intermédiaire 3-5 phrases directes (Maxime — style HoF2)
const ARC_TRANCHE_BUDGET_S: float = 300.0
const ARC_ECHECS_REELS_MAX: int = 2
# Combien de temps on laisse le moteur finir ce qu'il fait avant de retenter. Une résolution
# coûte jusqu'à ~86 s quand son préfixe a été évincé par un prompt d'arc : 45 s faisaient
# retomber la retentative en plein milieu, comptée à tort comme un échec.
const ARC_ATTENTE_S: float = 90.0
const QUETE_BEATS_MIN: int = 8
const QUETE_BEATS_MAX: int = 25

# Biais de tags-cœur par type de beat (R68/R81).
# v11 (spec §F) : le biais ne définit plus le pool tirable — il ne fait que COLORER le tirage
# (les candidats du biais passent en premier). La source de vérité de ce qui est requérable est
# la WHITELIST build_tag_pool ci-dessous (tags de base des actions ∪ deck de traits ∪ greffes).
const TYPE_TAG_BIAS: Dictionary = {
	"Exploration": ["Sens", "Savoir", "Mémoire", "Instinct", "Nature"],
	"Rencontre": ["Empathie", "Verbe", "Ruse"],
	# v10.14 (cascade 2026-06-12) : pools Epreuve/Dilemme ÉLARGIS (mono-famille → 6 tags) pour que
	# la couverture pleine soit atteignable par un deck varié (cible : partiel 55.6% → 25-35%).
	# La famille d'origine reste dominante (3 entrées sur 6).
	"Epreuve": ["Force", "Agilité", "Endurance", "Instinct", "Nature", "Savoir"],
	"Dilemme": ["Ruse", "Empathie", "Instinct", "Nature", "Mémoire", "Force"],
	"Climax": ["Force", "Ruse", "Savoir", "Instinct"],
}


## === v11 (spec §F) — WHITELIST des required_tags générables ===
## Pool générable = {8 tags de BASE des 4 actions} ∪ {tags du deck de TRAITS courant} ∪ {tags
## GREFFÉS (W3 : run.actions[i].tags au-delà des 2 premiers)}. Statiques PURS : partagés par le
## jeu (via _current_tag_pool) et par le harnais tools/probe_soak.gd (zéro drift — guardrail
## « gate jamais aveugle »). Gardes : les tags Corrompus ne sont JAMAIS requis ; Sacrifice et
## Équilibre JAMAIS requis tant que non greffés ; tags ×1 (comptage dynamique) → 1 beat/quête.

# Composition des requis par difficulté. Difficulté = nb de tags requis HORS tags de base des
# actions (spec §F, littéral) ; le climax diff 3 passe à 3 requis (contre-pression §E).
# Table gatée : le recalibrage W2/W3 (2 passes soak 5×300) ajuste ICI sans toucher au flux.
const REQ_TOTAL_BY_DIFF: Dictionary = {1: 2, 2: 2, 3: 3}
# v1.0-V4a (BAL-13-A) — climax « 2+1 » : 2 requis hors-base + 1 tag de base sur 3 (le 3 hors-base
# rendait la couverture pleine du climax quasi impossible : 1,1 % mesuré pour une cible 45-55).
const REQ_GAP_BY_DIFF: Dictionary = {1: 1, 2: 2, 3: 2}
# Jamais requérables via le deck de traits — exclusifs aux greffes W3 (formes canon).
const GRAFT_ONLY_TAGS: Array = ["sacrifice", "equilibre"]


# Tags d'une carte-like, duck-typé (PAS `is MerlinCard` : la référence de classe cassait le
# chargement préchargé du soak — leçon v10.20.1).
static func _tags_of(c: Variant) -> Array:
	if c is Object and "tags" in c:
		return c.tags
	if c is Dictionary and c.has("tags"):
		return c["tags"]
	return []


## Construit le pool générable. Retourne (formes canon sauf `display`) :
##   base    : tags de base des actions (2 premiers de chaque verbe)
##   gap     : tags requérables HORS base (deck de traits + greffes, gardes appliquées)
##   x1      : tags de `gap` à exemplaire UNIQUE dans le deck de traits (émission 1 beat/quête)
##   allowed : set (Dictionary) canon de TOUT ce qui est requérable
##   display : canon → forme affichée (accentuée, pour l'UI et les prompts)
static func build_tag_pool(actions: Array, traits: Array) -> Dictionary:
	var base: Array = []
	var grafted: Array = []
	var display: Dictionary = {}
	for a in actions:
		var atags: Array = _tags_of(a)
		for ti in atags.size():
			var t: String = str(atags[ti])
			if MerlinTags.is_corrupted_tag(t):
				continue
			var c: String = MerlinTags.to_canon(t)
			if not display.has(c):
				display[c] = t
			if ti < 2:
				if not base.has(c):
					base.append(c)
			elif not grafted.has(c) and not base.has(c):
				grafted.append(c)  # W3 : tag greffé — requérable, compte comme hors-base
	var counts: Dictionary = {}  # canon → exemplaires dans le deck de traits
	for tr in traits:
		for t2v in _tags_of(tr):
			var t2: String = str(t2v)
			if MerlinTags.is_corrupted_tag(t2):
				continue  # un tag Corrompu n'est JAMAIS requis
			var c2: String = MerlinTags.to_canon(t2)
			counts[c2] = int(counts.get(c2, 0)) + 1
			if not display.has(c2):
				display[c2] = t2
	var gap: Array = []
	for c3 in counts:
		if base.has(c3) or grafted.has(c3):
			continue
		if GRAFT_ONLY_TAGS.has(c3):
			continue  # Sacrifice/Équilibre : jamais requis sans greffe (spec §F)
		gap.append(str(c3))
	for c4 in grafted:
		if not gap.has(c4):
			gap.append(str(c4))
	var x1: Array = []
	for c5 in gap:
		if int(counts.get(c5, 0)) == 1 and not grafted.has(c5):
			x1.append(str(c5))  # ex. Franchise/Mystère/Rituel au deck de départ (comptage dynamique)
	var allowed: Dictionary = {}
	for c6 in base:
		allowed[c6] = true
	for c7 in gap:
		allowed[c7] = true
	# v1.0-V4a LEVIER 7b — `grafted` exposé : pick_required_tags met les tags greffés EN TÊTE des
	# candidats gap (le build devient la clé de la couverture pleine — BAL-13-A, lookahead-safe).
	return {"base": base, "gap": gap, "x1": x1, "allowed": allowed, "display": display,
		"counts": counts, "grafted": grafted}


## Tirage STATIQUE et pur des tags requis d'un beat (partagé jeu ↔ harnais, zéro drift).
## Composition par difficulté (REQ_*_BY_DIFF), biais de type en tête, tags ×1 exclus s'ils ont
## déjà été émis dans la quête (`x1_used`, MUTÉ par append). Formes AFFICHÉES en sortie.
static func pick_required_tags(btype: String, diff: int, pool_info: Dictionary, rng: RandomNumberGenerator, x1_used: Array) -> Array:
	var d: int = clampi(diff, 1, 3)
	var total: int = int(REQ_TOTAL_BY_DIFF.get(d, 2))
	var gap_n: int = mini(int(REQ_GAP_BY_DIFF.get(d, 1)), total)
	var base: Array = []
	if pool_info.get("base") is Array:
		base = pool_info["base"]
	var gap: Array = []
	if pool_info.get("gap") is Array:
		gap = pool_info["gap"]
	var x1: Array = []
	if pool_info.get("x1") is Array:
		x1 = pool_info["x1"]
	var display: Dictionary = {}
	if pool_info.get("display") is Dictionary:
		display = pool_info["display"]
	var bias_canon: Dictionary = {}
	var bias_pool: Array = TYPE_TAG_BIAS.get(btype, TYPE_TAG_BIAS["Exploration"])
	for bt in bias_pool:
		bias_canon[MerlinTags.to_canon(str(bt))] = true
	# Candidats HORS-BASE : v1.0-V4a LEVIER 7b — les tags GREFFÉS passent EN TÊTE (le build paie :
	# jouer le verbe greffé couvre le requis — BAL-13-A, stable/lookahead-safe car les greffes sont
	# permanentes), puis le biais du type (couleur du beat), puis le reste du pool.
	var grafted: Array = []
	if pool_info.get("grafted") is Array:
		grafted = pool_info["grafted"]
	var gap_graft: Array = []
	var gap_bias: Array = []
	var gap_rest: Array = []
	for c in gap:
		if x1.has(c) and x1_used.has(c):
			continue  # tag ×1 déjà émis dans cette quête (émission bornée, spec §F)
		if grafted.has(c):
			gap_graft.append(c)
		elif bias_canon.has(c):
			gap_bias.append(c)
		else:
			gap_rest.append(c)
	_shuffle_rng(gap_graft, rng)
	_shuffle_rng(gap_bias, rng)
	_shuffle_rng(gap_rest, rng)
	var picked: Array = []  # canon
	for c in gap_graft + gap_bias + gap_rest:
		if picked.size() >= gap_n:
			break
		picked.append(c)
		if x1.has(c):
			x1_used.append(c)
	# Complète en tags de BASE (biais d'abord) jusqu'au total — filet si le pool hors-base manque.
	var base_bias: Array = []
	var base_rest: Array = []
	for c in base:
		if picked.has(c):
			continue
		if bias_canon.has(c):
			base_bias.append(c)
		else:
			base_rest.append(c)
	_shuffle_rng(base_bias, rng)
	_shuffle_rng(base_rest, rng)
	for c in base_bias + base_rest:
		if picked.size() >= total:
			break
		picked.append(c)
	if picked.is_empty():
		picked.append("sens")  # filet théorique — le pool d'actions n'est jamais vide en pratique
	var out: Array = []
	for c in picked:
		out.append(str(display.get(c, str(c).capitalize())))
	return out


## v11 (spec §F) — VALIDE des tags requis (arc LLM ou constantes) contre le pool générable :
## tout tag hors-pool est remplacé par le fallback du MÊME index (1er arc procédural canonique),
## lui-même re-vérifié in-pool. Filet ultime : 1er tag de base des actions. Dédoublonné.
static func validate_required_tags(required: Array, beat_idx: int, pool_info: Dictionary) -> Array:
	var allowed: Dictionary = {}
	if pool_info.get("allowed") is Dictionary:
		allowed = pool_info["allowed"]
	var display: Dictionary = {}
	if pool_info.get("display") is Dictionary:
		display = pool_info["display"]
	var base: Array = []
	if pool_info.get("base") is Array:
		base = pool_info["base"]
	var out: Array = []
	for j in required.size():
		var t: String = str(required[j])
		var c: String = MerlinTags.to_canon(t)
		if not allowed.has(c):
			# Fallback du même index : la paire du beat correspondant de l'arc procédural.
			var arc_tags: Array = FALLBACK_ARC_TAGS[0]
			var pair_v: Variant = arc_tags[clampi(beat_idx, 0, arc_tags.size() - 1)]
			var pair: Array = pair_v if pair_v is Array else []
			t = str(pair[j % pair.size()]) if not pair.is_empty() else ""
			c = MerlinTags.to_canon(t)
			if t == "" or not allowed.has(c):
				t = str(display.get(base[0], "Sens")) if not base.is_empty() else "Sens"
				c = MerlinTags.to_canon(t)
		var dup: bool = false
		for u in out:
			if MerlinTags.to_canon(str(u)) == c:
				dup = true
		if not dup:
			out.append(t)
	if out.is_empty() and not base.is_empty():
		out.append(str(display.get(base[0], "Sens")))
	return out


## Liste affichable du pool générable (ordre stable : base puis hors-base) — consommée par le
## prompt d'arc comme LISTE FERMÉE (contrainte dure, spec §F).
static func pool_display_list(pool_info: Dictionary) -> Array:
	var display: Dictionary = {}
	if pool_info.get("display") is Dictionary:
		display = pool_info["display"]
	var out: Array = []
	for key in ["base", "gap"]:
		var arr_v: Variant = pool_info.get(key)
		if arr_v is Array:
			for c in arr_v:
				out.append(str(display.get(c, str(c))))
	return out


## v2-W1 (BIBLE R165) — rampe de difficulté par quête/climax : dc_ramp_bonus AJOUTE au DC de
## résolution SEUL (DC_BY_DIFF[beat.difficulte] + dc_ramp_bonus(beat)) — la COMPOSITION des requis
## (REQ_TOTAL_BY_DIFF/REQ_GAP_BY_DIFF) reste pilotée par beat.difficulte BRUT, jamais mutée ici
## (remplace effective_difficulty, dont le rôle de muter la composition a disparu). Le VRAI Climax
## final (difficulte==3) est EXEMPT : il reste au plafond historique DC=12, zéro stacking.
const DC_RAMP_PER_QUEST: int = 1
const DC_RAMP_CLIMAX_BUMP: int = 1
const DC_RAMP_CEILING: int = 12   # = MerlinResolution.DC_BY_DIFF[3], garde-fou

static func dc_ramp_bonus(beat: Dictionary) -> int:
	var diff: int = int(beat.get("difficulte", 1))
	if diff == 3:
		return 0   # le VRAI Climax final est EXEMPT : il reste au plafond historique DC=12, zero stacking
	var quest_idx: int = int(beat.get("quest", 0))
	var bonus: int = DC_RAMP_PER_QUEST * quest_idx
	if str(beat.get("type", "")) == "Climax":
		bonus += DC_RAMP_CLIMAX_BUMP
	return mini(bonus, DC_RAMP_CEILING - int(MerlinResolution.DC_BY_DIFF.get(diff, 9)))


## v1.0-V4a (BAL-14-A) — vérifie qu'un jeu de requis (arc re-validé) respecte la composition §F du
## beat : total par difficulté, nb hors-base EXACT, zéro doublon, aucun ×1 déjà émis dans la quête.
## Échec → l'appelant re-tire via pick_required_tags (filet de présentation, zéro drift harnais).
static func composition_ok(required: Array, diff: int, pool_info: Dictionary, x1_used: Array) -> bool:
	var d: int = clampi(diff, 1, 3)
	var total: int = int(REQ_TOTAL_BY_DIFF.get(d, 2))
	var gap_n: int = mini(int(REQ_GAP_BY_DIFF.get(d, 1)), total)
	if required.size() != total:
		return false
	var base: Array = []
	if pool_info.get("base") is Array:
		base = pool_info["base"]
	var x1: Array = []
	if pool_info.get("x1") is Array:
		x1 = pool_info["x1"]
	var seen: Dictionary = {}
	var hors_base: int = 0
	for t in required:
		var c: String = MerlinTags.to_canon(str(t))
		if seen.has(c):
			return false
		seen[c] = true
		if not base.has(c):
			hors_base += 1
		if x1.has(c) and x1_used.has(c):
			return false  # tag ×1 déjà émis dans cette quête (émission bornée, spec §F)
	return hors_base == gap_n


## v1.0-V4a — consigne l'émission des tags ×1 d'un jeu de requis retenu (MUTE x1_used par append,
## même contrat que pick_required_tags). Appelé quand les tags d'arc validés sont conservés.
static func note_x1_emission(required: Array, pool_info: Dictionary, x1_used: Array) -> void:
	var x1: Array = []
	if pool_info.get("x1") is Array:
		x1 = pool_info["x1"]
	for t in required:
		var c: String = MerlinTags.to_canon(str(t))
		if x1.has(c) and not x1_used.has(c):
			x1_used.append(c)


static func _shuffle_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# Pitch = UNE ligne d'accroche-action (appel à l'aventure), pas un paragraphe.
# Le développement complet de la quête arrive dans l'INTRO (pop-up à accepter, voir build_intro).
# N5-C1 (2026-07-12, fix biome) - le secours est BIOME-AWARE : le LLM (4,31 tok/s mesuré) ne gagne presque
# jamais la course, donc ce secours s'affiche >95 % du temps ET sert de pool pour la chaîne de quêtes
# (build_skeleton). Il DOIT coller au biome choisi (mer/falaises en falaises, jamais Brocéliande).
# _sel_fallback_pool() pioche par _run_biome() aux 3 call-sites (take_selection, generate_selection,
# build_skeleton). Ton merveilleux-inquiétant, chaque pitch lisible en UNE lecture (action + enjeu).
const SEL_FALLBACK_BY_BIOME: Dictionary = {
	"foret": [
		{"title": "Le Marché des Murmures", "pitch": "Infiltre le marché où l'on troque des noms volés."},
		{"title": "Le Rite sans Fin", "pitch": "Interromps le rite que nul ne sait plus arrêter."},
		{"title": "La Fontaine qui Rêve", "pitch": "Sonde la source noire où dorment les visages."},
	],
	"falaises": [
		{"title": "Le Phare qui Compte", "pitch": "Rallume le phare mort avant que la mer ne réclame un nom de plus."},
		{"title": "Le Chant du Ressac", "pitch": "Suis le chant qui monte des vagues avant qu'il n'attire une âme de plus vers le fond."},
		{"title": "L'Épave qui Revient", "pitch": "Fouille l'épave qui n'aurait jamais dû revenir avec la marée."},
	],
}


# N5-C1 - pool de secours de sélection du biome COURANT (défaut foret hors-jeu / biome inconnu).
func _sel_fallback_pool() -> Array:
	var b: String = _run_biome()
	var pool: Variant = SEL_FALLBACK_BY_BIOME.get(b, SEL_FALLBACK_BY_BIOME["foret"])
	return (pool as Array).duplicate(true)

# Narration procédurale = le texte VU par défaut (le LLM, 4,31 tok/s mesuré, ne gagne presque jamais la
# course contre la lecture du joueur). Donc 5 variantes/type, tirées au sort → variété cross-run
# (chaque type n'apparaît qu'1 fois par run). Ton « merveilleux-inquiétant » (bible §21).
# Scènes COURTES (user 2026-06-06 : « moins avant chaque choix de carte »). 1-2 phrases : poser le
# décor vite, laisser la place au geste. La VERBOSITÉ est réservée à l'ISSUE des moments forts.
# N2a (2026-07-05) — BIOME-AWARE : le LLM (4,31 tok/s mesuré) ne finit presque jamais sa résolution dans la
# fenêtre du joueur → c'est TOUJOURS le secours qui s'affiche. Il DOIT donc coller au biome (mer /
# falaises en biome falaises, pas « au creux de la forêt »). SITU_FALLBACKS_BY_BIOME[biome][type] :
# la forêt garde ses banques ; les falaises ont leurs propres 5 variantes/type (mer/vent/phare/
# épaves/rochers/sel/écume/marée/mouettes), même forme (2e pers présent, PNJ actif, jamais « que faire »).
# R168 (chantier 4, 2026-07-28) — REGISTRE SIMPLIFIÉ : sobre et direct, phrases courtes, vocabulaire
# courant, UNE image simple par scène MAXIMUM (le merveilleux vient de ce qui arrive, pas des
# tournures). MOTS-INDICES : 2-3 mots-clés par entrée, marqués [kw]Mot[/kw] — résolus en BBCode coloré
# (couleur = famille du tag via MerlinTags, cf. _style_keywords) UNIQUEMENT à l'affichage (l'intensité
# gras/gras+italique dépend de la difficulté du beat, inconnue à l'écriture). Les mots choisis
# correspondent aux familles RÉELLEMENT probables du type de beat (TYPE_TAG_BIAS ci-dessus).
const SITU_FALLBACKS_BY_BIOME: Dictionary = {
	"foret": {
		"Exploration": [
			"La clairière s'ouvre, trop calme. Vos [kw]Sens[/kw] et votre [kw]Instinct[/kw] disent qu'on vous observe, caché entre les arbres.",
			"Le sentier se perd sous les fougères. Votre [kw]Instinct[/kw] vous pousse à ralentir : la [kw]Nature[/kw] du lieu a changé.",
			"Une odeur de cendre froide flotte dans l'air. Votre [kw]Mémoire[/kw] cherche d'où elle vient, mais votre [kw]Savoir[/kw] ne trouve rien.",
			"Les arbres s'écartent sur un endroit trop ouvert, trop facile. Votre [kw]Instinct[/kw] et vos [kw]Sens[/kw] du danger vous retiennent.",
			"Le sol devient mousseux. Une source coule tout près : votre [kw]Savoir[/kw] des bois et votre [kw]Nature[/kw] curieuse vous y mènent.",
		],
		"Rencontre": [
			"Une silhouette sort des arbres et vous barre la route, sans un mot. Un peu d'[kw]Empathie[/kw] ou de [kw]Ruse[/kw] pourrait la calmer.",
			"Une forme immobile vous observe, le regard lourd. Elle attend votre premier [kw]Verbe[/kw], ou un geste de [kw]Ruse[/kw].",
			"Une voix vous salue avant même que vous voyiez personne. « Je connais ce pas », dit-elle. Votre [kw]Verbe[/kw] et votre [kw]Empathie[/kw] décideront de la suite.",
			"Un vieil homme, assis sur une pierre, semble vous attendre. Il crache : « Vous n'auriez pas dû venir. » Un peu de [kw]Ruse[/kw], ou beaucoup d'[kw]Empathie[/kw], désarmerait sa colère.",
			"Deux yeux brillent entre les troncs, à hauteur d'enfant. Une petite voix demande : « Tu viens jouer ? » Votre [kw]Verbe[/kw] et votre [kw]Empathie[/kw] feront toute la différence.",
		],
		"Epreuve": [
			"La forêt vous barre le passage : ronces, pierres, pente glissante. Il faudra de la [kw]Force[/kw] ou de l'[kw]Agilité[/kw].",
			"Le chemin se dresse contre vous, hostile. Il faudra de l'[kw]Endurance[/kw] pour forcer le passage, ou du [kw]Savoir[/kw] pour le contourner.",
			"Un vieil obstacle barre la route. Votre [kw]Savoir[/kw] du terrain vaut peut-être mieux que la [kw]Force[/kw] brute.",
			"Un torrent coupe le chemin, rapide et froid. L'autre rive est là, hors d'atteinte sans [kw]Agilité[/kw] ni [kw]Instinct[/kw].",
			"La pente monte d'un coup, raide et nue. Vos jambes tiennent sur la seule [kw]Endurance[/kw], et votre [kw]Nature[/kw] robuste.",
		],
		"Dilemme": [
			"Deux chemins s'ouvrent devant vous. Chacun a un prix ; ni votre [kw]Instinct[/kw] ni votre [kw]Mémoire[/kw] ne tranchent pour vous.",
			"Un choix se pose, sans détour. Ni la [kw]Force[/kw] ni la [kw]Ruse[/kw] ne le rendront facile.",
			"Il faut trancher, là où il n'y a pas de bonne réponse. Votre [kw]Nature[/kw] et votre [kw]Ruse[/kw] tirent chacune de leur côté.",
			"Une bête blessée gît en travers du sentier. La soigner demande de l'[kw]Empathie[/kw] ; l'achever, de la [kw]Force[/kw].",
			"Deux voix vous appellent en même temps, de deux côtés opposés. Votre [kw]Mémoire[/kw] ne vous aide pas à choisir.",
		],
		"Climax": [
			"L'air se fige. Ce qui vient ne se reprendra pas. Votre [kw]Instinct[/kw] le sait déjà, et votre [kw]Force[/kw] se tend.",
			"Tout se joue ici, maintenant. Les murmures se taisent d'un coup ; votre [kw]Savoir[/kw] ne suffira peut-être pas seul.",
			"Le cœur de la forêt bat sous vos pieds. Votre [kw]Force[/kw] et votre [kw]Savoir[/kw] décident de la suite.",
			"Le sentier débouche sur un cercle de pierres dressées. Au centre, ce que vous cherchiez vous attend ; votre [kw]Ruse[/kw] et votre [kw]Instinct[/kw] vous y ont menés.",
			"Tout le bois s'est tu d'un coup. Devant vous, la dernière porte ; derrière elle, la fin de l'histoire. Votre [kw]Force[/kw] tremble un peu.",
		],
	},
	"falaises": {
		"Exploration": [
			"La corniche s'ouvre, battue de vent. Vos [kw]Sens[/kw] et votre [kw]Instinct[/kw] disent qu'on vous suit, entre les rochers.",
			"Le sentier de sel longe le vide. Votre [kw]Instinct[/kw] vous pousse à ralentir : la [kw]Nature[/kw] du lieu a changé.",
			"Une odeur d'algue et de goudron froid flotte. Votre [kw]Mémoire[/kw] cherche d'où elle vient, mais votre [kw]Savoir[/kw] ne trouve rien.",
			"La falaise s'abaisse sur la baie, trop dégagée. Votre [kw]Instinct[/kw] et vos [kw]Sens[/kw] du danger vous retiennent.",
			"Le sol devient spongieux, gorgé d'embruns. Une faille travaille la roche : votre [kw]Savoir[/kw] de la côte et votre [kw]Nature[/kw] curieuse vous guident.",
		],
		"Rencontre": [
			"Une silhouette surgit d'un rocher et vous barre la route, sans un mot. Un peu d'[kw]Empathie[/kw] ou de [kw]Ruse[/kw] pourrait la calmer.",
			"Un vieux gardien de phare vous barre le passage, lanterne éteinte. « La mer a repris trois barques cette lune », lâche-t-il. Votre [kw]Verbe[/kw] et votre [kw]Empathie[/kw] décideront de la suite.",
			"Une voix vous hèle avant que vous ne voyiez personne, portée par le vent. « Je connais ce pas », dit-elle. Votre [kw]Verbe[/kw] fera la différence, un peu de [kw]Ruse[/kw] aussi.",
			"Une pêcheuse, assise sur une épave échouée, semble vous attendre. Elle crache : « Vous n'auriez pas dû descendre. » Un peu de [kw]Ruse[/kw], ou beaucoup d'[kw]Empathie[/kw], désarmerait sa colère.",
			"Deux yeux brillent dans un renfoncement de roche, à hauteur d'enfant. Une petite voix demande, par-dessus l'écume : « Tu viens voir la marée ? » Votre [kw]Verbe[/kw] et votre [kw]Empathie[/kw] feront toute la différence.",
		],
		"Epreuve": [
			"La falaise vous barre le passage : roche à pic, embruns, pierres qui roulent. Il faudra de la [kw]Force[/kw] ou de l'[kw]Agilité[/kw].",
			"Le sentier, taillé dans le roc et lustré de sel, se dresse contre vous. Il faudra de l'[kw]Endurance[/kw], ou du [kw]Savoir[/kw] pour le contourner.",
			"Un vieil escalier de pierre descend vers la crique, une marche manque. Votre [kw]Savoir[/kw] du terrain vaut peut-être mieux que la [kw]Force[/kw] brute.",
			"La marée montante coupe le passage, rapide et froide. L'autre rive de galets est là, hors d'atteinte sans [kw]Agilité[/kw] ni [kw]Instinct[/kw].",
			"La paroi se dresse d'un coup, nue et suintante d'écume. Vos bras tiennent sur la seule [kw]Endurance[/kw], et votre [kw]Nature[/kw] robuste.",
		],
		"Dilemme": [
			"Deux sentiers s'ouvrent sur la corniche. Chacun a un prix ; ni votre [kw]Instinct[/kw] ni votre [kw]Mémoire[/kw] ne tranchent pour vous.",
			"Un choix se pose, sans détour, face au large. Ni la [kw]Force[/kw] ni la [kw]Ruse[/kw] ne le rendront facile.",
			"Il faut trancher, là où il n'y a pas de bonne réponse. Votre [kw]Nature[/kw] et votre [kw]Ruse[/kw] tirent chacune de leur côté.",
			"Un phoque blessé gît en travers des galets. Le remettre à l'eau demande de l'[kw]Empathie[/kw] ; l'abandonner, de la [kw]Force[/kw].",
			"Deux voix vous appellent en même temps, l'une du phare, l'autre de la grève. Votre [kw]Mémoire[/kw] ne vous aide pas à choisir.",
		],
		"Climax": [
			"L'air se fige, le vent tombe d'un coup. Ce qui vient ne se reprendra pas. Votre [kw]Instinct[/kw] le sait déjà, et votre [kw]Force[/kw] se tend.",
			"Tout se joue ici, maintenant, au bord du vide. Les mouettes se taisent d'un coup ; votre [kw]Savoir[/kw] ne suffira peut-être pas seul.",
			"La houle bat la falaise sous vos pieds. Votre [kw]Force[/kw] et votre [kw]Savoir[/kw] décident de la suite.",
			"Le sentier débouche au pied du vieux phare, sa porte entrouverte. Ce que vous cherchiez vous attend ; votre [kw]Ruse[/kw] et votre [kw]Instinct[/kw] vous y ont menés.",
			"Toute la côte s'est tue d'un coup. Devant vous, la dernière marche au-dessus des flots. Votre [kw]Force[/kw] tremble un peu.",
		],
	},
}

# N2a (2026-07-05) — RÉSOLUTION COMPOSÉE. Le secours de résolution ne reflétait NI la combinaison
# jouée NI le biome. Nouveau modèle : ACTION (registre dominant des cartes) + CONSÉQUENCE (degré ×
# biome). fallback_resolution(degree, situ_type, played_cards, biome) → "[i]" + action + "[/i] " +
# conséquence. Les banques RESO_FALLBACKS/_LONG ci-dessous restent le FILET NEUTRE (registre inconnu /
# hors-jeu) et l'ancre du gate probe (chaque entrée commence par « [i]Vous »).
#
# ACTION par REGISTRE dominant (arch_reg : Social→PAROLE, Offensif→FORCE, Mystique→PERCEPTION,
# Défensif→PROTECTION, Corrompu→OMBRE ; "" = registre indéterminé → neutre). 2e pers présent,
# commence TOUJOURS par « Vous ». Biome-AGNOSTIQUE (le geste du Voyageur ; le lieu vit dans la conséquence).
const RESO_ACTION_BY_REGISTRE: Dictionary = {
	"PAROLE": [
		"Vous pesez chaque mot et parlez d'une voix qui ne tremble pas.",
		"Vous cherchez le mot juste, celui qui désarme, et le laissez tomber au bon moment.",
		"Vous nouez la parole et le regard en un seul aplomb, sans hausser le ton.",
	],
	"FORCE": [
		"Vous calez vos pieds et poussez de tout votre poids, sans rompre l'effort.",
		"Vous engagez le corps entier dans le geste, muscles tendus jusqu'au bout.",
		"Vous frappez d'un seul élan, franc, là où il faut et quand il faut.",
	],
	"PERCEPTION": [
		"Vous fermez les yeux un instant, puis lisez ce que le lieu cache.",
		"Vous suivez le fil ténu des signes que nul autre ne voit, et remontez jusqu'à la faille.",
		"Vous laissez le regard se poser, patient, jusqu'à ce que le secret se découvre de lui-même.",
	],
	"PROTECTION": [
		"Vous vous campez sans reculer et tenez la garde, immobile comme la pierre.",
		"Vous encaissez le choc et refusez de céder d'un pouce, ancré dans le sol.",
		"Vous faites rempart de votre corps et laissez passer l'assaut sans plier.",
	],
	"OMBRE": [
		"Vous appelez tout bas la part sombre, et la laissez guider votre main.",
		"Vous ouvrez la porte à ce qui ronge, et vous en servez sans détourner les yeux.",
		"Vous nourrissez le geste d'une force qui vous coûte, et qui répond aussitôt.",
	],
	"": [
		"Vous rassemblez vos deux forces et agissez d'un seul élan.",
		"Vous unissez vos deux forces en un seul geste, sans hésiter.",
		"Vous engagez vos deux forces d'un même mouvement, jusqu'au bout.",
	],
}


# CONSÉQUENCE par (degré × biome) — le MONDE réagit selon R140 (échec = résiste/se ferme · partiel =
# cède à demi + prix · réussite = cède/ouvre · éclatante = se lie/donne plus). Imagery de biome :
# falaises = mer/vent/sel/écume/rochers/phare ; foret = bois/arbres/mousse/source. ~3 variantes/case.
const RESO_CONSEQ_BY_DEGREE_BIOME: Dictionary = {
	"echec": {
		"foret": [
			"Le bois ne cède rien ; ce que vous cherchiez se dérobe entre les troncs, et vous vous retrouvez plus loin du but qu'avant. Dans l'ombre, quelque chose paraît s'en amuser.",
			"Le sentier se referme, indifférent, et vous repousse en arrière ; la mousse étouffe même le bruit de votre effort. Ce faux pas-là, il vous faudra le payer.",
			"Le geste ne prend pas sur ce lieu : les arbres se resserrent, la brume avale votre élan, et vous repartez les mains vides.",
		],
		"falaises": [
			"La roche tient bon et vous repousse ; vous reculez d'un pas vers le vide, les mains vides, et l'écume, en bas, semble s'en réjouir.",
			"Le vent renvoie votre effort à la figure ; ce que vous cherchiez glisse sur le sel et vous échappe, et la mer, indifférente, se referme sur les rochers.",
			"Rien ne cède, sinon vous : la corniche vous rejette, les embruns brouillent vos yeux, et quelque part sous l'eau noire, on tient déjà le compte.",
		],
	},
	"partiel": {
		"foret": [
			"La voie s'entrouvre, étroite, juste assez pour passer ; mais le bois vous a vu faire, et le prix viendra plus tard. Une ombre, désormais, marche dans vos pas.",
			"Vous arrachez votre dû d'un seul effort, et un reste vous colle à la peau ; la forêt a pris sa part, en silence.",
			"Cela ne marche qu'à moitié : vous avancez, mais une dette se noue dans votre dos, sous les fougères, et se rappellera à vous.",
		],
		"falaises": [
			"La roche cède à demi ; vous passez, mais le vent arrache quelque chose de vous, et la mer, en bas, en garde le compte.",
			"Le passage s'ouvre à l'arraché, juste assez pour vous y glisser ; l'embrun vous marque le visage, et le sel garde la trace de ce que vous laissez là.",
			"Vous forcez la corniche, à moitié vainqueur : une prise vous file entre les doigts, et l'écume, en dessous, réclame déjà son dû.",
		],
	},
	"reussite": {
		"foret": [
			"Le lieu cède et vous laisse avancer d'un pas plus sûr ; cette fois, le sentier ne réclame rien, et le silence du bois vous accompagne.",
			"Ce qui résistait cède d'un coup ; la route se dégage sous les arbres, nette, et rien ne vous suit.",
			"La forêt recule, calme, et s'écarte devant vous ; le chemin s'ouvre sans éclat mais sans dette, et vous passez, entier.",
		],
		"falaises": [
			"La voie s'ouvre sur la corniche, nette ; le vent tombe d'un coup, et rien ne vous suit sur le sel.",
			"La roche vous livre passage sans discuter ; la mer, en bas, s'apaise, et vous gagnez la crique d'un pas plus sûr.",
			"Ce qui barrait la côte cède d'un coup ; l'écume se retire, le sentier de galets s'offre à vous, et vous passez, entier.",
		],
	},
	"eclatante": {
		"foret": [
			"La forêt elle-même retient son souffle ; le passage s'ouvre en grand, sans résistance, et l'espace d'un instant vous êtes plus grand que vous-même.",
			"Tout le bois le fête en silence ; la voie se déroule devant vous comme un tapis, et pour une fois la forêt donne plus qu'elle ne prend.",
			"La forêt se range de votre côté ; ce que vous cherchiez vient à vous sans que vous ayez à le prendre, et sous les racines, quelque chose d'ancien s'incline.",
		],
		"falaises": [
			"Tout cède d'un coup ; la mer elle-même retient son souffle, et le phare, un instant, se rallume pour vous seul.",
			"Le vent s'agenouille et la houle se fige ; la côte s'ouvre en grand devant vous, et pour une fois la mer rend plus qu'elle ne prend.",
			"La falaise entière semble se pencher vers vous ; ce que vous cherchiez remonte de l'écume et se pose dans votre main, et au loin une voix de sel prononce votre nom.",
		],
	},
}


# N3-V1 (2026-07-06) : PONT INTELLIGENT inter-beats. R140 avait SUPPRIMÉ le pont GÉNÉRIQUE (« Sa voie
# ouverte, le Voyageur s'enfonça plus avant ») car interchangeable/hors-sol ; la continuité reposait
# alors sur le seul last_gist du prompt LLM. Mais le LLM (4,31 tok/s mesuré) perd la course souvent → la
# situation de SECOURS s'affiche presque toujours SANS lien au beat précédent (playtest : « décroché en
# event »). Ce pont RESTAURE la continuité VISIBLE, mais ANCRÉ (jamais générique) : il PORTE le degré du
# beat qui s'achève ET l'imagery du BIOME → il ne pourrait pas apparaître ailleurs (test anti-R140). Il
# COLORE selon le MOMENTUM (ton neutre / sombre / élan). Voix MJ 2e personne PRÉSENT ; il finit sur une
# VIRGULE (amorce ouverte) → préposé à la situation, « pont + situation » coule en un paragraphe. Il dit
# l'EMPREINTE du résultat (sensation résiduelle), jamais l'action elle-même (déjà narrée par la résolution) ;
# il ne dit JAMAIS « poursuivez/continuez votre route/chemin » (le générique banni). Structure
# [degré][biome][ton] : "neutre" (3 variantes, cas majoritaire momentum -1..+1), "sombre" (momentum <= -2),
# "elan" (momentum >= +2). Ton absent pour un couple → fallback "neutre" (jamais de phrase cross-biome).
const BRIDGE_BY_DEGREE_BIOME: Dictionary = {
	"echec": {
		"foret": {
			"neutre": [
				"Le bois vous a refusé son passage, la mousse encore froide sous vos paumes, et vous cherchez une autre percée entre les arbres,",
				"Ce que vous avez tenté s'est refermé comme une ronce, et vous longez le mur d'arbres à la recherche d'une faille,",
				"Le refus du lieu vous colle à la peau, l'humus lourd sous vos pas, tandis que vous gagnez le couvert plus loin,",
			],
			"sombre": [
				"Chaque tronc semble se resserrer un peu plus depuis vos derniers pas, et c'est entre deux ombres que vous reprenez,",
				"Le bois retient son souffle autour de votre échec, et c'est sous des branches plus basses que vous avancez,",
				"Quelque chose a pris note de votre revers sous les fougères, et vous reprenez la marche sans lui tourner le dos,",
			],
			"elan": [
				"Même ce revers ne vous arrête pas, la sève et la terre dans vos veines, et vous rouvrez la marche entre les fûts,",
				"L'échec glisse sur vous comme la pluie sur l'écorce, et vous repartez d'un pas que rien n'entame,",
				"Vous laissez le revers derrière vous avec les feuilles mortes, et le bois vous rend déjà un chemin,",
			],
		},
		"falaises": {
			"neutre": [
				"Le refus du lieu encore cuisant, le vent vous pousse plus loin sur le sel,",
				"La roche ne vous a rien cédé, et l'écume ronge encore vos bottes quand vous reprenez la corniche,",
				"Ce que le bord vous a refusé pèse dans vos jambes, et vous longez l'à-pic un peu plus loin,",
			],
			"sombre": [
				"Le vent a tourné contre vous depuis un moment déjà, et c'est en aveugle presque que vous reprenez la corniche,",
				"La mer garde le compte de vos revers, et c'est sous un ciel plus bas que vous longez le bord,",
				"L'embrun vous gifle comme un rappel, et vous avancez sur le sel en surveillant l'à-pic,",
			],
			"elan": [
				"Même ce revers ne vous plie pas, le sel vif sur vos lèvres, et vous reprenez le fil de la falaise,",
				"L'échec s'envole avec les mouettes, et vous reprenez le bord d'un pas que le vent n'ébranle pas,",
				"Ce que la roche vous a refusé aiguise votre prise, et vous repartez le long du vide, plus sûr qu'avant,",
			],
		},
	},
	"partiel": {
		"foret": {
			"neutre": [
				"Il vous en a coûté, mais la source retrouvée murmure encore derrière vous quand vous reprenez entre les troncs,",
				"À moitié payé, à moitié gagné, l'odeur de résine vous suit tandis que vous vous enfoncez plus avant,",
				"Le prix payé et la voie entrouverte, vous vous enfoncez dans la mousse vers l'ombre suivante,",
			],
			"sombre": [
				"Ce demi-gain a un goût de dette, et le bois se fait plus noir à chaque pas que vous risquez plus loin,",
				"Ce que vous avez payé chuchote encore sous la mousse, et vous avancez entre des troncs qui se souviennent,",
				"La moitié gagnée pèse comme la moitié perdue, et c'est dans un sous-bois plus sourd que vous continuez,",
			],
			"elan": [
				"Même à demi, ce que vous avez arraché vous porte, et le sous-bois s'ouvre plus franc devant vous,",
				"Le prix payé vous semble léger dans l'air vert, et vous enjambez les racines d'un pas gagnant,",
				"Ce demi-succès chante encore dans vos mains, et la forêt vous fait déjà signe plus loin,",
			],
		},
		"falaises": {
			"neutre": [
				"Ce que la mer vous a pris pèse encore, mais vous reprenez la corniche battue de vent,",
				"À demi vainqueur du vertige, le sel sec sur vos lèvres, vous longez le bord un peu plus loin,",
				"La prise à moitié tenue, l'embrun froid dans le cou, vous gagnez la roche suivante,",
			],
			"sombre": [
				"Ce demi-gain sent la marée qui monte, et le vent se fait mauvais à mesure que vous avancez sur le sel,",
				"Ce que la mer vous a laissé, elle compte le reprendre, et vous serrez la corniche sous un ciel qui charge,",
				"La moitié arrachée pèse dans votre sac comme une pierre mouillée, et vous longez l'à-pic sans quitter l'eau des yeux,",
			],
			"elan": [
				"Même écorné, ce que vous tenez vous soulève, et la falaise s'ouvre plus large devant vos pas,",
				"Le demi-gain claque au vent comme une voile, et vous gagnez la roche suivante d'un pas assuré,",
				"Ce que vous avez pris à la mer vous rend plus vif, et le bord du monde se laisse longer sans mordre,",
			],
		},
	},
	"reussite": {
		"foret": {
			"neutre": [
				"Porté par ce qui vient de céder, vous gagnez le coeur du bois,",
				"La forêt vous laisse passer, presque complice, et la lumière change entre les feuilles quand vous avancez,",
				"La voie franchie sans dette, l'air vert et calme dans vos poumons, vous vous enfoncez plus avant,",
			],
			"sombre": [
				"La voie s'est ouverte, mais quelque chose vous suit sous les fougères tandis que vous reprenez,",
				"Vous avez gagné, et pourtant le bois s'est tu d'un coup, comme s'il attendait la suite,",
				"Le passage est à vous, mais les ombres entre les fûts marchent au même pas que vous,",
			],
			"elan": [
				"Tout, depuis vos derniers pas, semble s'écarter devant vous, et le bois s'ouvre plus large à mesure que vous avancez,",
				"La victoire court devant vous de branche en branche, et vous suivez son sillage au cœur du bois,",
				"Porté par ce qui vient de plier, vous fendez le sous-bois comme si les racines se rangeaient d'elles-mêmes,",
			],
		},
		"falaises": {
			"neutre": [
				"Le vent semble se ranger derrière vous, et vous gagnez le promontoire dans l'odeur du sel,",
				"La falaise vous a laissés passer sans vous prendre, et l'horizon s'élargit tandis que vous avancez,",
				"La corniche franchie sans prix, l'embrun clair sur le visage, vous poussez vers la roche suivante,",
			],
			"sombre": [
				"La voie s'est ouverte, mais l'eau noire, en bas, garde l'oeil sur vous quand vous reprenez le bord,",
				"Vous avez gagné, et pourtant la mer s'est faite trop calme, comme avant un mauvais coup,",
				"Le passage est acquis, mais le vent porte une odeur d'orage tandis que vous longez le vide,",
			],
			"elan": [
				"Une confiance neuve vous porte depuis vos derniers pas, et le vent lui-même semble vous pousser vers le large,",
				"La victoire claque dans votre dos comme une cape, et la corniche défile sous vos pas sans un faux appui,",
				"Porté par ce qui vient de céder, vous suivez le fil du bord comme si le vide lui-même vous portait,",
			],
		},
	},
	"eclatante": {
		"foret": {
			"neutre": [
				"Ce que vous venez d'accomplir résonne encore sous l'écorce, et le bois entier semble s'incliner sur votre passage,",
				"Les arbres eux-mêmes paraissent se souvenir de vous, et un chemin franc s'ouvre où il n'y en avait pas,",
				"L'éclat de votre geste court de racine en racine, et la forêt vous ouvre sa profondeur,",
			],
			"sombre": [
				"Votre éclat a réveillé quelque chose : le bois s'incline, mais une ombre neuve marche à côté de vous,",
				"Un tel éclat ne passe pas inaperçu ici, et vous sentez des regards anciens peser entre les troncs,",
				"Le bois plie devant votre gloire, mais son silence a le poids d'une dette qu'on vous fera payer,",
			],
			"elan": [
				"Rien ne semble pouvoir vous arrêter, et le coeur de la forêt se déplie de lui-même devant vous,",
				"Votre éclat court plus vite que vous de cime en cime, et le bois entier vous fait cortège,",
				"Ce que vous venez d'accomplir vous précède comme une lumière, et les fûts s'écartent sur votre passage,",
			],
		},
		"falaises": {
			"neutre": [
				"Ce que vous venez d'arracher à la roche résonne jusqu'au phare, et la mer elle-même semble reculer,",
				"Les rochers paraissent vous reconnaître, et un sentier net s'ouvre devant vous au bord du vide,",
				"L'éclat de votre geste court sur l'écume, et la côte entière s'ouvre devant vous,",
			],
			"sombre": [
				"Votre éclat a réveillé la mer : elle recule devant vous, mais une voix de sel prononce déjà votre nom,",
				"Un tel éclat s'entend jusqu'au fond de l'eau, et quelque chose d'ancien remonte pour voir qui ose,",
				"La côte s'incline devant votre gloire, mais l'écume écrit votre nom sur la roche comme une promesse due,",
			],
			"elan": [
				"Rien ne semble pouvoir vous arrêter, et la falaise se penche d'elle-même pour vous livrer passage,",
				"Votre éclat roule sur l'écume comme un tonnerre clair, et la côte entière vous fait passage,",
				"Ce que vous venez d'arracher au vide vous précède, et le vent lui-même dégage la corniche devant vous,",
			],
		},
	},
}


# N3-V1 (2026-07-06) : ANCRAGE DU CLIMAX sur le but de quête. %s = quest_title. Préposé à la situation
# du beat Climax (build_situation) pour que le climax NOMME ce que la quête promettait et le referme. Voix
# MJ 2e personne présent, court (1 phrase). Le dernier climax du run = culmination de la chaîne de quêtes.
const CLIMAX_ANCHORS: Array = [
	"Au bout, ce que « %s » promettait vous attend enfin.",
	"Tout ce qui vous a mené jusqu'ici n'était qu'un chemin vers « %s », et le voici.",
]


# N5-C4 (2026-07-12) - au 1er beat d'une NOUVELLE quête de la chaîne, le pont d'issue (qui ne parle que
# du beat précédent) ne suffit pas : sans ça le joueur enchaîne sur une quête dont il ignore et le titre
# et le pitch (playtest : « discours trop énigmatique »). On cite le pitch de la nouvelle quête comme une
# parole de Merlin rapportée (même procédé que CLIMAX_ANCHORS). %s = quest_pitch (ou quest_title en repli).
# Registre VOUS de la narration ; la citation entre guillemets absorbe le tutoiement propre au pitch.
const QUEST_TRANSITION_ANCHORS: Array = [
	"Vous entendez encore la voix de Merlin, quelque part derrière vous : « %s ».",
	"Une seule phrase de Merlin vous accompagne dans ce nouveau chapitre : « %s ».",
	"Ce que Merlin vous a chargé de faire résonne encore en vous : « %s ».",
]


# Filet NEUTRE (registre inconnu / hors-jeu) + ancre du gate probe : chaque entrée s'ouvre sur « [i]Vous ».
# Utilisé tel quel par fallback_resolution quand aucune carte n'est passée (harnais legacy 2 args).
const RESO_FALLBACKS: Dictionary = {
	"echec": [
		"[i]Vous rassemblez vos deux forces et agissez d'un seul élan.[/i] Mais les deux se gênent, et le lieu vous repousse ; ce que vous cherchiez se dérobe, et vous vous retrouvez plus loin du but qu'avant. Dans l'ombre, quelque chose paraît s'en amuser.",
		"[i]Vous engagez vos deux forces d'un même mouvement.[/i] Le geste ne prend pas sur ce lieu : le passage se referme, indifférent, et vous laisse en arrière. Ce faux pas-là, il vous faudra le payer.",
		"[i]Vous jetez vos deux forces dans la brèche.[/i] Elles partent de travers et s'annulent ; rien ne bouge, sinon vous qu'on repousse. Vous avez perdu du terrain, et un peu de vous-même avec.",
	],
	"partiel": [
		"[i]Vous unissez vos deux forces, mais de travers.[/i] Vous obtenez ce que vous vouliez, en en laissant un morceau. Une ombre, désormais, marche dans vos pas.",
		"[i]Vous forcez le geste jusqu'au bout.[/i] La voie s'entrouvre, étroite, juste assez pour passer ; mais quelque chose vous a vu faire, et le prix viendra plus tard.",
		"[i]Vous mêlez vos deux forces tant bien que mal.[/i] Cela ne marche qu'à moitié : vous avancez, mais une dette se noue dans votre dos, et se rappellera à vous.",
	],
	"reussite": [
		"[i]Vous nouez vos deux forces en un seul geste, net et juste.[/i] Le lieu cède et vous laisse avancer d'un pas plus sûr ; cette fois, la voie ne réclame rien.",
		"[i]Vous portez le geste du premier coup.[/i] Le chemin s'ouvre, sans éclat mais sans dette, et vous passez, entier.",
		"[i]Vous accordez vos deux forces d'un même souffle.[/i] Ce qui résistait cède d'un coup ; la route se dégage, nette, et rien ne vous suit.",
	],
	"eclatante": [
		"[i]Vous fondez vos deux forces en une seule, parfaitement.[/i] Le lieu lui-même retient son souffle ; le passage s'ouvre en grand, sans résistance, et l'espace d'un instant vous êtes plus grand que vous-même.",
		"[i]Vous liez vos deux forces d'un geste si juste que tout cède.[/i] Le monde semble se ranger de votre côté ; ce que vous cherchiez vient à vous sans que vous ayez à le prendre.",
	],
}

# Fallbacks LONGS (user 2026-06-06) — servis aux MOMENTS FORTS (Climax / éclatante) quand aucune carte
# n'est passée (filet neutre). En jeu, la composition ajoute une 2e phrase de conséquence à ces moments
# (voir fallback_resolution). Chaque entrée s'ouvre sur « [i]Vous » (ancre du gate probe).
const RESO_FALLBACKS_LONG: Dictionary = {
	"echec": [
		"[i]Vous lancez vos deux forces ensemble, de toute votre volonté.[/i] Mais au lieu de s'unir, elles se brisent. Le lieu ne se contente pas de refuser : il reprend, il efface, il vous repousse. Quelque chose, dans l'ombre, a vu votre tentative. Vous restez seul au bord, les mains vides.",
		"[i]Vous engagez vos deux forces d'un même élan désespéré.[/i] Le geste se retourne contre vous comme une bête mal tenue ; ce que vous touchez se dérobe, ce que vous appelez ne vient pas. Le lieu se referme lentement sur votre échec. Vous paierez ce moment, vous le savez déjà.",
	],
	"partiel": [
		"[i]Vous unissez vos deux forces et poussez jusqu'au bout.[/i] Quelque chose cède, quelque chose s'ouvre, et dans le même temps une ombre se glisse dans vos pas. Vous obtenez ce que vous vouliez, et repartez marqué. Le lieu a pris autre chose, sans dire quoi.",
		"[i]Vous forcez le passage d'un dernier effort.[/i] Il s'entrouvre à demi, juste assez pour vous y faufiler ; mais rien ici n'est gratuit, et ce que vous forcez vous coûte un morceau. On vous a vu faire, on ne l'oubliera pas. Vous avancez, à moitié vainqueur, à moitié débiteur.",
	],
	"reussite": [
		"[i]Vous nouez enfin vos deux gestes en un seul, large et juste.[/i] Le lieu cède dans un long soupir ; la voie se dénoue devant vous, nette, comme si le monde avait attendu ce moment. Vous passez, entier, plus sûr de votre pas, et le silence vous suit comme un accord rare.",
		"[i]Vous portez le geste fondu droit sur sa cible.[/i] Tout le lieu l'accuse ; le chemin s'ouvre sans triomphe bruyant mais sans la moindre dette. Rien ne vous retient plus : vous franchissez le seuil, et le monde vous laisse aller.",
	],
	"eclatante": [
		"[i]Vous fondez soudain vos deux gestes en un seul, si bien accordés que le lieu retient son souffle.[/i] Le seuil s'ouvre en grand, sans résistance, et tout au fond, quelque chose d'ancien s'incline. La voie se déroule comme un tapis. L'espace d'un instant, bref et vertigineux, vous êtes plus grand que vous-même.",
		"[i]Vous liez vos deux forces dans un accord total.[/i] Le lieu entier le fête en silence ; ce que vous venez d'accomplir, peu l'ont fait avant vous. Le chemin devant n'est plus une épreuve mais un cadeau. Vous avancez, porté, et derrière vous une voix très douce prononce votre nom.",
	],
}

var _rng := RandomNumberGenerator.new()

# --- Warmup async sélection (R6 ; « toujours faire tourner le LLM » côté Menu) ---
var _sel_cache: Array = []
# idle / running / ready / failed. « ready » signifie STRICTEMENT « le MODÈLE a écrit les trois
# titres » (user 2026-08-15 : plus jamais de titres en dur à la sélection). Avant ce contrat, un
# secours mis en cache passait pour une réussite : is_selection_ready() répondait oui, l'attente
# de l'écran ressortait aussitôt, et ensure_selection_prefetch() ne réessayait plus jamais — une
# seule panne au menu condamnait la partie entière aux trois titres écrits en dur.
var _sel_state: String = "idle"
var _sel_epoch: int = 0
# Essais du modèle pour CETTE sélection. Au-delà, l'état passe à « failed » et l'écran rend la
# main au menu au lieu de servir un secours (user : « réessayer, puis le menu »).
var _sel_attempts: int = 0
# POURQUOI le modèle a renoncé. Vide tant que tout va bien. Sans lui, `failed` ne dit rien :
# Maxime voit un retour au menu, moi un état sans motif, et le diagnostic repart de zéro à
# chaque fois. Même remède que `boot_error()` côté moteur — nommer la panne plutôt que la subir.
var _sel_motif: String = ""
const SEL_MAX_ATTEMPTS: int = 2

# --- Pré-génération RÉSOLUTION (v10.4, user 2026-06-06 : issue TOUJOURS LLM) ---
# Lancée pendant la pose des cartes (prefetch_resolution), récupérée au clic Résolution
# (take_resolution). Cache par signature de combinaison (ids cartes + degré) → un changement de
# combo supersède via epoch. Masque la latence ~1 tok/s du moteur natif.
var _reso_cache: Dictionary = {}   # signature -> prose
var _reso_sig: String = ""         # signature actuellement en génération
var _reso_state: String = "idle"   # idle / running / ready
var _reso_epoch: int = 0
var _reso_retry_sig: String = ""  # v35.5 — signature déjà re-essayée après une gen VIDE (1 seul re-essai)
var _reso_revous_sig: String = ""  # v40 — signature déjà re-essayée (première phrase sans « Vous »)
var _reso_reserve: Dictionary = {}  # v43 — prose valide mise de côté avant un re-essai
# N4-BUG #2a (2026-07-11) : prefetch demandé AVANT que le modèle soit chargé (cold start) :
# mémorisé ici puis RELANCÉ à model_ready. Sans ça, prefetch_resolution sortait en silence,
# _reso_state restait « idle » pour toujours et le sustain de fusion attendait son cap ~12 s
# en vain (100 % repro sur la 1re résolution à froid, mesuré 14,4-14,7 s clic→issue).
var _pending_prefetch: Dictionary = {}  # {situation, cards, res, epoch} ; vidé si périmé/consommé

# --- Pré-génération OUVERTURE (v10.13 B0/B3) — pattern _sel_* ---
# Lancée à l'ouverture du pop-up d'intro (merlin_game._show_intro_popup) SI le moteur est idle ;
# consommée par l'interstitiel « Merlin raconte » (take_opening, cache-only). Priorité moteur 3.
var _opening_cache: String = ""
var _opening_state: String = "idle"   # idle / running / ready
var _opening_epoch: int = 0

# --- FIL ROUGE DU SCÉNARIO (continuité inter-beats, user 2026-06-06) ---
# Capturé au skeleton (titre + pitch = enjeu SPÉCIFIQUE du scénario), enrichi à chaque beat
# résolu (last_gist = résultat du beat précédent). Injecté dans le prompt d'issue pour que la
# prose (a) reste ancrée dans CE scénario et (b) enchaîne sur le beat d'avant — fini les beats
# orphelins « sans queue ni tête ». RAZ à chaque build_skeleton (= nouveau run).
var _run_thread: Dictionary = {"title": "", "pitch": "", "last_gist": ""}
var _fb_served: Dictionary = {}  # anti-répétition intra-run des fallbacks d'issue : "degré|pool" → [index servis]
# v1.0-V4a (BAL-14-A) — émission des tags ×1 bornée à 1 beat/quête AU RUNTIME : quest_idx → [canon].
# Transient volontaire (RAZ au build_skeleton) : au resume la borne repart de zéro — acceptable,
# rien n'est rejoué (seuls les beats FUTURS re-tirent), même contrat que le dé de build_situation.
var _x1_used_by_quest: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_load_persona()
	# v10 dashboard : re-fusionne la persona quand TweaksOverlay détecte un changement live.
	var to: Node = get_node_or_null("/root/TweaksOverlay")
	if to != null and to.has_signal("tweaks_reloaded"):
		to.tweaks_reloaded.connect(_on_tweaks_reloaded)
	# AMORÇAGE : faire lire sa voix à Merlin dès que le modèle est là, pendant que le joueur
	# regarde encore le menu. Mesuré le 2026-08-18 : la lecture du prompt coûte 26,9 s en jeu
	# sur les 65,4 s d'une sélection, et la voix en est la plus grosse part. La payer ici, c'est
	# la payer dans un temps qui ne coûte rien au joueur — le cache la retient ensuite.
	var mn: Node = _mn()
	if mn != null:
		if mn.is_ready():
			_amorcer()
		elif mn.has_signal("model_ready"):
			mn.model_ready.connect(_amorcer, CONNECT_ONE_SHOT)


# Silencieux et sans conséquence : si l'amorçage ne se fait pas, la sélection paie simplement la
# lecture complète, comme avant. Un préchauffage raté ne doit jamais devenir une panne visible.
func _amorcer() -> void:
	var mn: Node = _mn()
	if mn == null or not mn.has_method("amorcer_prefixe"):
		return
	await mn.amorcer_prefixe(_voice_prefix())
	# Le VIF amorce la TÊTE D'ISSUE (~600 tokens de règles) : lue une fois ici, dans le temps du
	# menu, elle reste chaude dans SON cache toute la session — chaque issue ne paiera plus que
	# sa queue variable (~350 tokens, ~8 s au lieu de ~50 à froid).
	if mn.has_method("est_vif_pret"):
		if mn.est_vif_pret():
			_amorcer_vif(mn)
		elif mn.has_signal("vif_ready"):
			mn.vif_ready.connect(_amorcer_vif.bind(mn), CONNECT_ONE_SHOT)


# RÉSILIENT, et non one-shot-perdu (revue adversariale 2026-08-19) : `vif_ready` tombe souvent
# pendant qu'une génération occupe le moteur mono-place — amorcer_prefixe rendait alors la main
# en silence, la connexion one-shot était consommée, et la tête d'issue n'était jamais mise en
# cache : la première issue payait la lecture à froid. Ici on ATTEND la place, borné.
# IDEMPOTENT (v31.1) : l'ouverture appelle aussi cet amorçage sous le voile — deux chemins,
# une seule lecture de la tête.
var _vif_amorce_fait: bool = false


func _amorcer_vif(mn: Node) -> void:
	if _vif_amorce_fait:
		return
	var dl: int = Time.get_ticks_msec() + 120000
	while mn.is_busy() and Time.get_ticks_msec() < dl:
		await get_tree().create_timer(0.5).timeout
	if _vif_amorce_fait:
		return  # amorcé par l'autre chemin pendant notre attente
	if mn.est_vif_pret() and not mn.is_busy():
		await mn.amorcer_prefixe(MerlinPromptBuilder.SYSTEM_PREFIX, "vif",
				MerlinPromptBuilder.tete_issue(RICHESSE_ISSUE))
		_vif_amorce_fait = true


func _on_tweaks_reloaded(_tweaks: Dictionary) -> void:
	# Hot-reload : on relit la persona de base puis on ré-applique l'overlay.
	_load_persona()


func _mn() -> Node:
	return get_node_or_null("/root/MerlinNative")


# v1.0-V4a (BAL-14-A/TEC-17-A) — pool générable du RUN RÉEL (actions greffées + deck de traits
# courant), calculé AU MOMENT de l'appel — jamais figé au squelette (les greffes font évoluer le
# pool). {} hors-jeu (hors arbre / run absente / run jamais initialisée) : les harnais prose et
# scénario gardent alors le chemin legacy (_pick_tags / arc brut).
func _live_pool_info() -> Dictionary:
	if not is_inside_tree():
		return {}
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run == null:
		return {}
	var acts_v: Variant = run.get("actions")
	if not (acts_v is Array) or (acts_v as Array).is_empty():
		return {}
	var traits_all: Array = []
	for key in ["deck", "hand", "discard"]:
		var arr_v: Variant = run.get(key)
		if arr_v is Array:
			traits_all += (arr_v as Array)
	return build_tag_pool(acts_v, traits_all)


# v10.13 (B0) — vrai si le moteur natif est prêt ET libre. Gate des générations de priorité
# basse (opening, épilogue) : elles ne se lancent que sur un moteur idle, jamais en préemption.
func engine_idle() -> bool:
	var mn: Node = _mn()
	return mn != null and mn.is_ready() and not mn.is_busy()


# --- PERSONA MERLIN (câblage de l'existant : data/ai/config/merlin_persona.json) ---
func _load_persona() -> void:
	if not FileAccess.file_exists(PERSONA_PATH):
		return
	var f: FileAccess = FileAccess.open(PERSONA_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if data is Dictionary:
		_persona = data
	else:
		push_warning("MerlinScenario: merlin_persona.json illisible ou non-Dictionary — voix par défaut.")
	# v10 dashboard : surcharge live depuis TweaksOverlay.get_persona_overlay() (édité par
	# mission-control). Fusion non-destructive : arrays APPEND (les appellations de l'overlay
	# enrichissent la base, ne la remplacent pas — review HIGH+MEDIUM 2026-06-05), scalaires/dicts
	# en REMPLACEMENT (un executor_system overlay non-vide override la base). (user 2026-05-31 /goal)
	var to: Node = get_node_or_null("/root/TweaksOverlay")
	if to != null and to.has_method("get_persona_overlay"):
		var ov: Dictionary = to.get_persona_overlay()
		for k in ov.keys():
			var ov_val: Variant = ov[k]
			var base_val: Variant = _persona.get(k, null)
			if base_val is Array and ov_val is Array:
				_persona[k] = (base_val as Array) + (ov_val as Array)  # append : base + overlay
			else:
				_persona[k] = ov_val  # scalaire/dict : remplacement direct


func _csv(arr: Variant, limit: int = 999) -> String:
	var parts: PackedStringArray = []
	if arr is Array:
		var a: Array = arr
		for i in int(min(a.size(), limit)):
			parts.append(str(a[i]))
	return ", ".join(parts)


# Préfixe voix Merlin enrichi par la persona (appellations + mots interdits) — le JSON reste la source
# de vérité ; si absent, on retombe sur la constante seule (robuste).
func _voice_prefix() -> String:
	var p: String = MerlinPromptBuilder.MERLIN_VOICE_PREFIX
	var apps: Variant = _persona.get("appellations", [])
	if apps is Array and (apps as Array).size() > 0:
		p += " Appellations possibles: %s." % _csv(apps)
	var forb: Variant = _persona.get("forbidden_words", [])
	if forb is Array and (forb as Array).size() > 0:
		p += " Mots STRICTEMENT interdits: %s." % _csv(forb)
	return p


# Mémoire intra-run (R60) que Merlin peut « se souvenir » : vide en run neuf (new_run RAZ), peuplée sur
# run repris (load_run) / beats avancés. Câble l'existant — pas de profil cross-run sur cette branche.
func _build_memory_hint() -> String:
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run == null:
		return ""
	var notes: PackedStringArray = []
	var cartes: Variant = run.get("cartes_notables")
	if cartes is Array and (cartes as Array).size() > 0:
		notes.append("il a marqué la forêt avec %s" % _csv(cartes, 3))
	var pnj: Variant = run.get("pnj_rencontres")
	if pnj is Array and (pnj as Array).size() > 0:
		notes.append("il a croisé %s" % _csv(pnj, 3))
	var choix: Variant = run.get("choix_cles")
	if choix is Array and (choix as Array).size() > 0:
		notes.append("il a choisi %s" % _csv(choix, 2))
	return " ; ".join(notes)


# --- WARMUP + PREFETCH SÉLECTION (depuis le Menu) ---
# Ne met en cache QUE ce que le modèle a écrit. Un échec ne devient jamais un « ready » :
# il consomme un essai et rouvre la porte à une nouvelle tentative, ou déclare forfait.
func warmup_and_prefetch_selection() -> void:
	_sel_epoch += 1
	var epoch: int = _sel_epoch
	_sel_cache = []
	_sel_state = "running"
	_sel_attempts += 1
	var res: Dictionary = await _generate_selection_sourced()
	if epoch != _sel_epoch:
		return  # une nouvelle demande a pris le relais → résultat périmé (F3 epoch)
	if bool(res.get("du_modele", false)):
		_sel_cache = res.get("titres", [])
		_sel_state = "ready"
		return
	# Le modèle n'a rien produit d'exploitable. On NE garde rien : servir le secours ici, c'est
	# ce qui rendait la panne invisible et définitive.
	_sel_cache = []
	_sel_motif = str(res.get("motif", "raison inconnue"))
	# Un refus TRANSITOIRE (moteur occupé) rend son crédit : il n'a rien prouvé sur la capacité
	# du modèle à écrire. Sans ça, une collision d'une seconde avec la voix du menu consommait
	# un des deux essais, et le moindre incident suivant renvoyait le joueur au menu.
	if bool(res.get("transitoire", false)):
		_sel_attempts = maxi(0, _sel_attempts - 1)
	_sel_state = "failed" if _sel_attempts >= SEL_MAX_ATTEMPTS else "idle"


func take_selection() -> Array:
	# v10 dashboard : forçage de scénario via TweaksOverlay.get_scenario_force() — si la dashboard
	# Gameplay Live a sélectionné un titre, on renvoie ce seul scénario (le joueur le voit + accepte).
	# (user 2026-05-31 /goal — wire de l'option qui était cosmétique avant la review)
	var to: Node = get_node_or_null("/root/TweaksOverlay")
	if to != null and to.has_method("get_scenario_force"):
		var force: Dictionary = to.get_scenario_force()
		var forced_title: String = str(force.get("title", ""))
		if forced_title != "":
			return [{"title": forced_title, "pitch": "Sentier choisi depuis le dashboard."}]
	# Simple RÉCUPÉRATEUR : il rend ce que le modèle a écrit, ou rien. L'ancien budget de 8 s
	# servait le secours en douce quand la génération courait encore — c'était la seconde porte
	# par laquelle les titres en dur atteignaient l'écran, sans que personne le voie. L'attente
	# et le renoncement appartiennent désormais à l'écran de sélection, qui les rend visibles.
	if _sel_state == "ready" and _sel_cache.size() >= 3:
		return _sel_cache.duplicate(true)
	return []


func invalidate_selection() -> void:
	_sel_epoch += 1
	_sel_cache = []
	_sel_state = "idle"
	_sel_attempts = 0  # nouvelle sélection = nouveau crédit d'essais
	_sel_motif = ""


# v10.19 — sélection prête ? Vrai UNIQUEMENT si les trois titres viennent du modèle : c'est ce que
# l'attente de l'écran interroge pour savoir si elle peut s'arrêter.
func is_selection_ready() -> bool:
	return _sel_state == "ready" and _sel_cache.size() >= 3


# Pourquoi la sélection a échoué — chaîne vide si tout va bien. Lu par l'écran de renoncement.
func selection_motif() -> String:
	return _sel_motif


# Le modèle a épuisé ses essais : l'écran doit renoncer et rendre la main au menu.
func is_selection_failed() -> bool:
	return _sel_state == "failed"


# Numéro de l'essai en cours (1 = premier, 2 = seconde tentative). Lu par l'écran pour dire au
# joueur que Merlin s'y reprend, plutôt que de le laisser devant une animation muette.
func selection_attempt() -> int:
	return _sel_attempts


# Garantit qu'une pré-génération de sélection est lancée. Robustesse : si le warmup du menu n'a pas
# tourné (modèle pas prêt à temps, menu déjà quitté), on relance dès que le moteur est dispo. No-op
# si déjà prête, en vol, ou si les essais sont épuisés (« failed » — sinon on réessaierait sans fin).
func ensure_selection_prefetch() -> void:
	if _sel_state == "ready" or _sel_state == "running" or _sel_state == "failed":
		return
	var mn: Node = _mn()
	if mn != null and mn.is_ready() and not mn.is_busy():
		warmup_and_prefetch_selection()


# --- 1) SÉLECTION : 3 scénarios (titre + pitch) — voix MERLIN (user 2026-05-29) ---
# Renvoie {titres: Array, du_modele: bool}. La PROVENANCE est le cœur du contrat : sans elle,
# l'appelant ne peut pas distinguer une réussite d'un secours, et c'est précisément cette
# confusion qui mettait les titres en dur en cache comme s'ils étaient l'œuvre de Merlin.
func _generate_selection_sourced() -> Dictionary:
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		# La MATIÈRE du biome (bible §22) + les titres déjà vus + un angle tiré au sort. Ces trois
		# entrées sont ce qui rend une partie différente de la précédente : l'extension échantillonne
		# en greedy (déterministe, mesuré 2026-08-15), donc à prompt identique la sortie est
		# identique. Faire varier le PROMPT est le seul levier tant que le C++ n'est pas recompilé.
		var p: Dictionary = MerlinPromptBuilder.selection(
				_voice_prefix(), _run_biome(), titres_deja_vus(), _tirer_angle())
		var res: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
		if res.has("error"):
			# Le moteur lui-même a rendu la main : délai dépassé (GEN_TIMEOUT_MS), annulation,
			# modèle absent, ou simplement OCCUPÉ. Sa raison est plus précise que tout ce qu'on
			# pourrait deviner ici.
			#
			# « transitoire » distingue « pas maintenant » de « ça ne marchera pas ». Un moteur
			# occupé n'est PAS un échec du modèle : réessayer dans deux secondes suffit. Le
			# compter comme un essai brûlait la moitié du crédit sur une simple collision — et
			# c'est exactement ce qui arrive quand la voix du menu tient encore le moteur au
			# moment du tap sur le biome.
			var err: String = str(res["error"])
			return {"titres": _sel_fallback_pool(), "du_modele": false,
					"transitoire": err.contains("deja en cours") or err.contains("non pret"),
					"motif": "le moteur a rendu une erreur : %s" % err}
		var brut: String = str(res.get("text", ""))
		var arr: Array = MerlinJson.extract_array(brut)
		var clean: Array = MerlinProse.clean_selection(arr)
		if clean.size() >= 3:
			var trois: Array = clean.slice(0, 3)
			_memoriser_titres(trois)
			return {"titres": trois, "du_modele": true}
		# Le modèle a PARLÉ mais on n'a pas su le relire. On distingue les deux cas, parce qu'ils
		# se réparent différemment : rien d'exploitable = prompt à revoir ; trop peu d'entrées =
		# le modèle a compris mais n'en a pas produit assez. Un extrait du brut part dans les logs
		# — sans lui, corriger un prompt revient à deviner ce que le modèle a répondu.
		var motif: String = ("réponse illisible : aucun tableau JSON trouvé" if arr.is_empty()
				else "seulement %d entrée(s) exploitable(s) sur 3" % clean.size())
		push_warning("[MerlinScenario] sélection — %s · début de la réponse : %s"
				% [motif, brut.substr(0, 220)])
		return {"titres": _sel_fallback_pool(), "du_modele": false, "motif": motif}
	return {"titres": _sel_fallback_pool(), "du_modele": false,
			"motif": "moteur indisponible (%s)" % (mn.boot_error() if mn != null else "autoload absent")}


# --- MÉMOIRE DES TITRES DÉJÀ PROPOSÉS (anti-répétition entre PARTIES) ---
# Persistée sur disque : la répétition qui dérange n'est pas celle d'une même session — c'est
# celle qu'on retrouve en relançant le jeu le lendemain. Un tableau en mémoire seule ne
# protégerait de rien. Fichier séparé du profil : aucune sauvegarde existante n'est touchée,
# et le perdre ne coûte qu'un peu de répétition (jamais une progression).
const TITRES_VUS_PATH: String = "user://merlin_titres_vus.json"
# 6 et non 24 (mesuré 2026-08-15) : chaque titre mémorisé s'ajoute au prompt À ÉVALUER avant
# chaque génération. À 24, la sélection dépassait les 90 s du délai interne du moteur, qui
# l'annulait — le joueur voyait alors « Merlin réfléchit » puis un retour au menu, et le défaut
# EMPIRAIT à chaque partie jouée puisque la liste grandissait. Six suffisent à éviter la
# répétition immédiate, qui est la seule qu'on remarque.
const TITRES_VUS_MAX: int = 6
var _titres_vus: Array = []
var _titres_vus_charges: bool = false

# Angles imposés : la variation ne peut pas venir du tirage (greedy), elle vient donc d'ici.
# Volontairement des ENJEUX, pas des tons : un ton change l'habillage, un enjeu change l'histoire.
const ANGLES: Array = [
	"une dette qu'on vient reclamer", "une disparition recente", "un serment rompu",
	"un objet rendu par erreur", "une frontiere deplacee", "un marche qui se retourne",
	"une hospitalite piegee", "un retour qu'on n'attendait plus", "un savoir qu'on veut taire",
	"une reparation impossible", "un temoin qui se retracte", "un heritage conteste",
]


func _charger_titres_vus() -> void:
	if _titres_vus_charges:
		return
	_titres_vus_charges = true
	if not FileAccess.file_exists(TITRES_VUS_PATH):
		return
	var f: FileAccess = FileAccess.open(TITRES_VUS_PATH, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if d is Array:
		_titres_vus = d


func titres_deja_vus() -> Array:
	_charger_titres_vus()
	return _titres_vus.duplicate()


func _memoriser_titres(sels: Array) -> void:
	_charger_titres_vus()
	for s in sels:
		var t: String = str((s as Dictionary).get("title", ""))
		if t != "" and not _titres_vus.has(t):
			_titres_vus.append(t)
	while _titres_vus.size() > TITRES_VUS_MAX:
		_titres_vus.pop_front()
	var f: FileAccess = FileAccess.open(TITRES_VUS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_titres_vus))
		f.close()


# Angle tiré AU HASARD VRAI (randi, pas _rng) : _rng est seedé pour rendre les runs rejouables,
# et s'en servir ici ferait revenir le même angle à chaque nouvelle partie — exactement ce qu'on
# cherche à éviter.
func _tirer_angle() -> String:
	return str(ANGLES[randi() % ANGLES.size()])


# Conservée pour les harnais de mesure (probe_native_bench), qui veulent le comportement brut
# « rends-moi quelque chose » sans la machine à états. Le JEU passe par _generate_selection_sourced.
func generate_selection() -> Array:
	var res: Dictionary = await _generate_selection_sourced()
	return res.get("titres", [])


# --- 2) SQUELETTE : CHAÎNE de quêtes (CODE). INSTANTANÉ — le pitch EST le synopsis. ---
# v10.14 (cascade) : un run = 2-3 quêtes (40%/60%) de 2-5 beats. Quête 1 = le scénario choisi ;
# quêtes suivantes = pitchs du pool de sélection (titres différents). Signature INCHANGÉE.
# v10.20.2 — tirage pondéré faction + pilier PNJ (fil rouge de la run). Corrompus RARE ; L'Enfant = wildcard.
const FACTION_KEYS: Array = ["druides", "creatures", "chevalerie", "corrompus"]
const FACTION_WEIGHTS: Array = [30, 30, 30, 8]  # Corrompus rare (user 2026-06-30)
const FACTION_PILIER: Dictionary = {"druides": "choeur", "creatures": "etre", "chevalerie": "chevalier", "corrompus": "compagnon"}


func _draw_faction_pilier() -> Dictionary:
	# Override de test (capture/QA d'une faction précise), comme MERLIN_SEASON pour la saison.
	if OS.has_environment("MERLIN_FACTION"):
		var fko: String = OS.get_environment("MERLIN_FACTION")
		if FACTION_PILIER.has(fko):
			return {"faction": fko, "pilier": str(FACTION_PILIER[fko]), "pilier2": ""}
	var total: int = 0
	for w in FACTION_WEIGHTS:
		total += int(w)
	var r: int = _rng.randi_range(1, total)
	var acc: int = 0
	var fk: String = "druides"
	for i in FACTION_KEYS.size():
		acc += int(FACTION_WEIGHTS[i])
		if r <= acc:
			fk = str(FACTION_KEYS[i])
			break
	var enfant: String = "enfant" if _rng.randf() < 0.12 else ""  # L'Enfant : wildcard rare, hors faction
	return {"faction": fk, "pilier": str(FACTION_PILIER.get(fk, "choeur")), "pilier2": enfant}


# Getters lus par merlin_game à la fin du run → mémorisés dans la chronique (récurrence PNJ cross-run).
func current_faction() -> String:
	return str(_run_thread.get("faction", ""))


func current_pilier() -> String:
	return str(_run_thread.get("pilier", ""))


# Wave D — pilier secondaire (wildcard L'Enfant, ~12%). Lu par merlin_game pour l'offrande : présent → l'Enfant
# fait l'offrande (exception inquiétante) en surcharge du pilier de faction.
func current_pilier2() -> String:
	return str(_run_thread.get("pilier2", ""))


func build_skeleton(title: String, pitch: String) -> Dictionary:
	# Fil rouge : RAZ + capture de l'enjeu spécifique (titre + pitch) — l'arc couvre la QUÊTE 1 ;
	# begin_quest rebascule le fil à chaque transition (last_gist traverse les quêtes).
	var fb: Dictionary = _fallback_arc()
	var fp: Dictionary = _draw_faction_pilier()  # v10.20.2 : faction + pilier PNJ de la run (fil rouge)
	# Récurrence : si le pilier tiré est CELUI de la run précédente (chronique), il RECONNAÎT le Voyageur.
	var recog: bool = str(fp["pilier"]) != "" and str(fp["pilier"]) == str(MerlinChronicle.read().get("last_pilier", ""))
	_run_thread = {"title": title, "pitch": pitch, "last_gist": "", "bridge": "", "arc": fb["arc"], "arc_tags": fb["tags"], "arc_locked": false, "arc_du_modele": false, "intro_legende": "",
		"faction": str(fp["faction"]), "pilier": str(fp["pilier"]), "pilier2": str(fp["pilier2"]), "pnj_recog": recog}
	_fb_served = {}  # nouvelle run → toutes les variantes de fallback redeviennent disponibles
	_scene_cache = {}
	_scene_jit_qn = -1
	_x1_used_by_quest = {}  # v1.0-V4a : la borne d'émission ×1 repart avec la run
	# UNE SEULE QUÊTE PAR PARTIE (décision Maxime, réaffirmée le 2026-08-18).
	#
	# CE QUI SE PASSAIT AVANT : la partie enchaînait 2 à 3 quêtes, et les supplémentaires étaient
	# tirées de `_sel_fallback_pool()` — la banque de titres ÉCRITS EN DUR. Le joueur choisissait
	# donc un sentier et se retrouvait à jouer, après lui, une ou deux quêtes que personne n'avait
	# choisies et que le modèle n'avait pas écrites. Il ne pouvait pas y avoir de fil conducteur :
	# il y en avait trois, dont deux importés.
	#
	# Désormais : le sentier choisi EST l'histoire, du premier beat au dernier.
	# MERLIN_BEATS force la longueur — pour le DIAGNOSTIC uniquement. Une quête de 8 à 25 beats à
	# ~45 s le beat coûte une heure par vérification ; à 4 beats elle en coûte cinq minutes, et
	# c'est ce qu'il faut pour voir l'arc s'écrire ou renoncer. Même patron que MERLIN_BIOME et
	# MERLIN_MODELE : une variable, un repli, aucun effet en partie normale.
	var n_beats: int = _rng.randi_range(QUETE_BEATS_MIN, QUETE_BEATS_MAX)
	if OS.has_environment("MERLIN_BEATS"):
		var force: int = int(OS.get_environment("MERLIN_BEATS"))
		if force >= 3:
			n_beats = force
			print("[MerlinScenario] longueur forcée par MERLIN_BEATS : %d beats" % n_beats)
	var beats: Array = build_quest_beats(title, pitch, n_beats, _rng)
	return {"title": title, "pitch": pitch, "synopsis": pitch, "beats": beats,
			"total": beats.size(), "quests": 1}


# COURBE DRAMATIQUE À N BEATS. `QUEST_PATTERNS` plafonnait à 5 : au-delà, il n'existait rien, et
# c'est pour ça que la partie était découpée en plusieurs quêtes courtes. On construit ici la même
# forme — ouverture, alternance montées/revers, dilemme d'avant-fin, climax — étirée sur N.
#
# La règle tient en trois lignes : le premier beat est une Exploration douce (difficulté 1), le
# dernier est le Climax (difficulté 3), et entre les deux on alterne en gardant une Rencontre tous
# les trois beats environ — c'est elle qui porte les PNJ et le marchand.
static func build_quest_beats(title: String, pitch: String, n_beats: int,
		rng: RandomNumberGenerator) -> Array:
	var n: int = maxi(3, n_beats)
	var corps: Array = ["Rencontre", "Epreuve", "Exploration", "Dilemme", "Epreuve", "Rencontre"]
	var beats: Array = []
	for i in n:
		var btype: String = "Exploration"
		var diff: int = 2
		if i == 0:
			diff = 1
		elif i == n - 1:
			btype = "Climax"
			diff = 3
		elif i == n - 2:
			btype = "Dilemme"   # le pas de côté juste avant la fin : on choisit avant d'affronter
		else:
			btype = str(corps[(i - 1) % corps.size()])
		var beat: Dictionary = {
			"n": i + 1, "qn": i + 1, "qtotal": n, "quest": 0,
			"quest_title": title, "quest_pitch": pitch,
			"type": btype, "difficulte": diff,
		}
		if i == n - 2:
			beat["variant_type"] = "Epreuve"   # ramification : le revers précédent peut la durcir
		beats.append(beat)
	_ensure_min_rencontres(beats, rng)
	return beats


# STATIQUE PURE (réutilisée par les harnais avec leur rng seedé) : concatène les beats des
# quêtes. Chaque beat porte {n global, qn, qtotal, quest, quest_title, quest_pitch, type,
# difficulte}. Difficulté : 1 au tout premier beat, 3 au Climax FINAL, 2 partout ailleurs.
# Ramification v1 : l'avant-climax des quêtes k>=4 porte une VARIANTE (Epreuve<->Dilemme),
# basculée par MerlinRun à l'arrivée si le degré précédent est échec/partiel.
static func build_chain_beats(quests: Array, rng: RandomNumberGenerator) -> Array:
	var beats: Array = []
	var n: int = 0
	for qi in quests.size():
		var k: int = rng.randi_range(2, 5)
		var pattern: Array = QUEST_PATTERNS[k]
		for j in pattern.size():
			n += 1
			var btype: String = str(pattern[j])
			var diff: int = 2
			if n == 1:
				diff = 1
			elif btype == "Climax" and qi == quests.size() - 1:
				diff = 3
			var beat: Dictionary = {
				"n": n, "qn": j + 1, "qtotal": pattern.size(), "quest": qi,
				"quest_title": str(quests[qi].get("title", "")),
				"quest_pitch": str(quests[qi].get("pitch", "")),
				"type": btype, "difficulte": diff,
			}
			if pattern.size() >= 4 and j == pattern.size() - 2:
				beat["variant_type"] = "Dilemme" if btype == "Epreuve" else "Epreuve"
			beats.append(beat)
	_ensure_min_rencontres(beats, rng)
	return beats


# Chantier 2 (garantie marchand) : GARANTIT au moins MIN_RENCONTRE_PER_RUN beats "Rencontre" au
# global du run. Si le tirage naturel (QUEST_PATTERNS) n'en a pas produit assez, mute IN PLACE un
# beat en Rencontre : JAMAIS le 1er beat du run (n==1), JAMAIS un Climax (aucune exception). Source
# de mutation en 3 PALIERS (le plus proche de l'esprit "Epreuve mediane" d'abord, elargi seulement
# si le tirage naturel n'a produit AUCUNE Epreuve exploitable, cas k=2 sans quete ni Epreuve ni
# Rencontre) : 1) Epreuve, 2) Dilemme (variante avant-climax des quetes k=5), 3) Exploration
# (ouverture d'une quete NON initiale, n>1). PREFERE une quete qui n'a pas deja de Rencontre
# (l'alternance offrande/marchand nait alors naturellement, cf. merlin_game._advance_to_next).
# rng DEJA passe (deterministe, avant tout save), n'affecte aucun tirage de tags/difficulte en aval.
# Residuel mathematique honnete : un run a 2 quetes toutes deux k=2 (4 beats : Exploration/Climax
# x2) n'a qu'UN SEUL beat eligible (n=3, Exploration de la 2e quete) : MIN_RENCONTRE_PER_RUN=2 y est
# structurellement inatteignable SANS toucher le 1er beat ou un Climax (jamais fait ici), mesure et
# rapporte honnetement au soak (Economie), pas maquille.
const _MUTATION_TIERS: Array = ["Epreuve", "Dilemme", "Exploration"]


static func _ensure_min_rencontres(beats: Array, rng: RandomNumberGenerator) -> void:
	var quests_with_rencontre: Dictionary = {}
	var count: int = 0
	for b in beats:
		if str(b.get("type", "")) == "Rencontre":
			count += 1
			quests_with_rencontre[int(b.get("quest", -1))] = true
	while count < MIN_RENCONTRE_PER_RUN:
		var candidates: Array = []
		for tier_type in _MUTATION_TIERS:
			for i in beats.size():
				var b2: Dictionary = beats[i]
				if int(b2.get("n", 0)) <= 1:
					continue  # jamais le 1er beat du run
				if str(b2.get("type", "")) != str(tier_type):
					continue
				candidates.append(i)
			if not candidates.is_empty():
				break  # palier suivant SEULEMENT si celui-ci n'a rien produit
		if candidates.is_empty():
			break  # garde defensive : residuel mathematique (cf. commentaire), mesure au soak, jamais un softlock
		var preferred: Array = []
		for i in candidates:
			if not quests_with_rencontre.has(int((beats[i] as Dictionary).get("quest", -1))):
				preferred.append(i)
		var pool: Array = preferred if not preferred.is_empty() else candidates
		var pick_i: int = int(pool[rng.randi_range(0, pool.size() - 1)])
		var beat: Dictionary = beats[pick_i]
		beat["type"] = "Rencontre"
		beat.erase("variant_type")  # une Rencontre ne porte jamais de variante avant-climax (R159-safe)
		beats[pick_i] = beat
		quests_with_rencontre[int(beat.get("quest", -1))] = true
		count += 1


# Vue PAR-QUÊTE du scénario (title/pitch/beats de la quête) — consommée par prepare_arc
# (l'arc narratif est PAR QUÊTE) et par begin_quest.
func quest_view(scenario: Dictionary, quest_idx: int) -> Dictionary:
	var qbeats: Array = []
	for b in scenario.get("beats", []):
		if int(b.get("quest", 0)) == quest_idx:
			qbeats.append(b)
	if qbeats.is_empty():
		return {"title": str(scenario.get("title", "")), "pitch": str(scenario.get("pitch", "")),
				"beats": scenario.get("beats", []), "total": int(scenario.get("total", 5))}
	return {
		"title": str(qbeats[0].get("quest_title", scenario.get("title", ""))),
		"pitch": str(qbeats[0].get("quest_pitch", scenario.get("pitch", ""))),
		"beats": qbeats, "total": qbeats.size(),
	}


# v10.14 — bascule du fil narratif sur la quête suivante (transition de chaîne) : nouveau
# fallback d'arc, arc DÉVERROUILLÉ (prepare_arc LLM peut le remplacer), et le fil rouge
# (last_gist) TRAVERSE les quêtes — la continuité du récit survit à la transition.
func begin_quest(scenario: Dictionary, quest_idx: int) -> void:
	var qv: Dictionary = quest_view(scenario, quest_idx)
	var fb: Dictionary = _fallback_arc()
	var gist: String = str(_run_thread.get("last_gist", ""))
	# N3-V1 : le PONT traverse les quêtes comme last_gist → le 1er beat de la quête suivante s'ouvre sur
	# le pont porteur du dernier résultat (continuité par-delà la frontière de quête, playtest N3).
	var bridge: String = str(_run_thread.get("bridge", ""))
	# v10.20.2 : la faction + le pilier PNJ (fil rouge) sont RUN-wide → ils survivent à la transition de quête.
	var faction: String = str(_run_thread.get("faction", ""))
	var pilier: String = str(_run_thread.get("pilier", ""))
	var pilier2: String = str(_run_thread.get("pilier2", ""))
	var recog: bool = bool(_run_thread.get("pnj_recog", false))
	_run_thread = {"title": str(qv.get("title", "")), "pitch": str(qv.get("pitch", "")),
		"last_gist": gist, "bridge": bridge, "arc": fb["arc"], "arc_tags": fb["tags"], "arc_locked": false, "arc_du_modele": false, "intro_legende": "",
		"faction": faction, "pilier": pilier, "pilier2": pilier2, "pnj_recog": recog}
	prepare_arc(qv)  # fire-and-forget — l'arc LLM remplace le fallback s'il gagne la course


# --- 2bis) INTRO DE QUÊTE (pop-up à accepter) : développement complet + objectif. ---
# Procédural INSTANTANÉ (le pop-up s'ouvre sans attente) ; narrate_intro enrichit en fond.
# C'est MERLIN qui conte : il connaît le Voyageur et l'apostrophe (user 2026-05-29).
const _INTRO_WRAPPERS: Array = [
	"Ah, te revoilà, Voyageur. Ce sentier-là, je le connais : il ne mène plus qu'en avant, désormais. Ce que tu cherches t'attend au bout ; ce que tu crains aussi, je ne vais pas te mentir. Avance, mon ami : je marche entre les lignes, à ton côté.",
	"Tiens, mon Voyageur. La brume s'est écartée juste pour toi, ou pour me jouer un tour, avec elle on ne sait jamais. Le sentier se referme dans ton dos ; devant, ce que tu cherches et ce que tu crains, logés à la même enseigne. Allons. Je te suis, ou je te précède, l'un des deux.",
	"Écoute, Voyageur. Le bois a choisi de te laisser entrer : c'est rare, savoure. Ce que tu cherches t'attend au bout du sentier ; ce que tu crains aussi, mais ça, tu le savais déjà. Avance d'un pas tranquille, mon ami. Je veille. Enfin... je crois que je veille.",
]



# v10.22 — nom du LIEU du conte selon le biome de la run (prompts cohérents avec le monde choisi).
func _lieu_name() -> String:
	var run_l: Node = get_node_or_null("/root/MerlinRun")
	return "les Falaises du Bout-du-Monde" if (run_l != null and str(run_l.biome) == "falaises") else "Broceliande"


# N2a — biome COURANT de la run (source de vérité : /root/MerlinRun.biome), duck-typé. Défaut "foret"
# hors-jeu (harnais probe_soak/probe_prose : pas de run montée) → les banques falaises ne cassent pas
# soak. Argument explicite `biome` non-vide → il prime (permet aux self-tests de forcer une casse).
func _run_biome(biome: String = "") -> String:
	if biome != "":
		return biome
	if is_inside_tree():
		var run_b: Node = get_node_or_null("/root/MerlinRun")
		if run_b != null and str(run_b.biome) != "":
			return str(run_b.biome)
	return "foret"


# v10.22 (user : « remplace le sentier s'ouvre par un préambule qui explique ce qu'on fait là ») —
# PRÉAMBULE LORE en 3 paragraphes : §1 qui tu es · §2 le LIEU t'a appelé (par biome) · §3 ce que Merlin
# attend + le titre de la quête. Banques procédurales, anti-répétition intra-session via _fb_served.
const PREAMBULE_QUI: Array = [
	"Tu es le Voyageur, celui qui marche sans bannière ni serment, et que les chemins reconnaissent. Tu as laissé derrière toi un monde qui ne pose plus de questions ; ici, chaque pierre en pose une.",
	"On ne t'a pas donné de nom en ces terres : Voyageur suffit. Tu portes douze forces anciennes en guise de bagage (perception, corps, parole, intuition), et c'est tout ce que ce lieu te laissera garder.",
	"Tu marches depuis des jours, Voyageur, sans savoir qui de toi ou du chemin a choisi l'autre. Les tiens ne se souviennent déjà plus de ton départ ; ce pays, lui, semblait t'attendre.",
]
const PREAMBULE_LIEU: Dictionary = {
	"foret": [
		"Brocéliande n'est pas une forêt : c'est une mémoire qui pousse. Les arbres y gardent le compte des promesses tenues et brisées, et la brume ne s'écarte que devant ceux qu'elle veut éprouver. Cette nuit, elle s'est écartée devant toi.",
		"On dit que Brocéliande rêve, et que ses rêves ont des sentiers. Y entrer, c'est marcher dans la pensée d'une chose très vieille : les korrigans s'y moquent, les pierres y murmurent, et rien n'y est donné sans dette.",
		"La forêt t'a appelé comme elle appelle les orages : sans un mot, par simple gravité. Sous ses frondaisons vivent quatre puissances qui se disputent son cœur, et la Corruption, patiente, qui les écoute toutes.",
	],
	"falaises": [
		"Les Falaises du Bout-du-Monde tombent dans une mer qui ne rend rien. Le vieux phare n'y guide plus personne : il compte les navires que l'écume a pris, et les esprits du sel remontent la nuit lécher ses pierres. C'est ici que ton chemin s'arrête, ou commence.",
		"Ici, la terre s'achève en à-pic et la mer parle une langue d'avant les hommes. Les goélands portent des messages que nul ne lit plus, et l'embrun grave sur la roche des noms que la marée efface. Le tien vient d'y apparaître.",
		"On ne vient pas aux Falaises : on y échoue, comme les épaves. Le vent y use les serments plus vite que la pierre, et quelque chose, sous l'eau noire, garde le compte de ceux qui se penchent trop près du bord.",
	],
}
const PREAMBULE_ATTENTE: Array = [
	"Je suis Merlin, gardien de ce seuil et ta seule constante dans ce qui vient. Je ne peux pas marcher à ta place, mais je peux te dire ce que le lieu exige de toi : %s.",
	"Moi, Merlin, je veille sur ce passage depuis plus de lunes que tu n'as de souvenirs. Je te prêterai ma voix et mes yeux ; le reste t'appartient. Voici ce que tu dois faire : %s.",
	"Merlin, on m'appelle, et je t'observais bien avant que tu n'arrives. Chaque geste que tu poseras, je le lirai ; chaque prix, tu le paieras. Ce qu'il te faut accomplir, dès maintenant : %s.",
]


func _pick_preamble(pool: Array, key: String) -> String:
	var served: Array = _fb_served.get(key, [])
	if served.size() >= pool.size():
		served = []
	var avail: Array = []
	for i in pool.size():
		if not served.has(i):
			avail.append(i)
	var idx: int = int(avail[_rng.randi_range(0, avail.size() - 1)])
	served.append(idx)
	_fb_served[key] = served
	return str(pool[idx])


# P3 (chantier 4) — PRÉAMBULE DU MONDE : ouverture courte (voix Merlin, merveilleux-inquiétant) qui
# plante Brocéliande et l'enjeu du Graal, et relie le compteur de Fragments (méta P2/R151, source
# MerlinChronicle). DISTINCT du préambule de BIOME (PREAMBULE_LIEU) : le monde D'ABORD, le lieu ENSUITE.
# Composé UNE fois par run (build_intro, §0). Zéro tiret cadratin.
func world_preamble() -> String:
	var frag: int = int(MerlinChronicle.read().get("graal_fragments", 0))
	var total: int = int(MerlinChronicle.GRAAL_TOTAL)
	var reste: int = maxi(total - frag, 0)
	var compte: String
	if frag <= 0:
		compte = "Tu n'en as encore arraché aucun ; les %d dorment toujours dans la nuit." % total
	elif reste <= 0:
		compte = "Tu les as presque tous rassemblés, et pourtant la brume ne rend jamais vraiment tout."
	elif frag == 1:
		compte = "Un seul éclat repose déjà entre tes mains ; %d se dérobent encore." % reste
	else:
		# Accord singulier/pluriel : un seul reste manquant → « se dérobe » (revue narrative BLOCKER 2).
		var verbe: String = "se dérobe" if reste == 1 else "se dérobent"
		compte = "Tu en as déjà ravi %d à l'oubli ; %d %s encore." % [frag, reste, verbe]
	# Brocéliande = réalme MYTHIQUE d'origine du Graal (on ne dit jamais « tu es DANS Brocéliande » :
	# la run peut se dérouler aux Falaises) ; « jusque sur ces terres » relie les éclats au biome courant.
	return "Écoute-moi bien, Voyageur, car cette nuit ne se répétera pas. Au cœur de Brocéliande dort le Graal, brisé en mille éclats que le monde a laissés filer jusque sur ces terres. Chaque traversée peut t'en rendre un, si tu survis à ce que le sentier réclame. %s" % compte


# Vague A (A4, 2026-07-12) — CADRAGE COURT du monde : 2 phrases (voix Merlin, merveilleux-inquiétant)
# affichées dans la capsule Z3 À LA PLACE du long préambule §0-§3 de build_intro, quand le joueur
# n'ouvre PAS le guide animé. Plante le LIEU et son enjeu en deux souffles, sans monologue. Zéro tiret
# cadratin (U+2014). Défaut foret (biome inconnu / hors-jeu, via _run_biome). Le titre + l'objectif de
# la quête restent portés par le pop-up d'ouverture ; ceci ne fait que camper le monde en deux phrases.
const WORLD_SETUP_SHORT: Dictionary = {
	"foret": "Nous voici à Brocéliande, Voyageur, là où la brume garde le compte des promesses et des dettes. Avance : le sentier ne s'ouvre qu'à ceux qu'il a choisi d'éprouver.",
	"falaises": "Nous voici aux Falaises du Bout-du-Monde, Voyageur, là où la terre s'achève et où la mer ne rend rien. Avance : sous l'eau noire, quelque chose compte déjà tes pas.",
}


# La légende d'intro écrite par le modèle pendant « Merlin rêve » — chaîne vide si elle n'a pas
# été écrite (le pop-up sert alors le cadrage en dur, et le journal le marque).
func quest_intro() -> String:
	return str(_run_thread.get("intro_legende", ""))


func intro_du_modele() -> bool:
	return str(_run_thread.get("intro_legende", "")) != ""


func world_setup_short(biome: String = "") -> String:
	var b: String = _run_biome(biome)
	return str(WORLD_SETUP_SHORT.get(b, WORLD_SETUP_SHORT["foret"]))


func build_intro(scenario: Dictionary) -> Dictionary:
	var title: String = str(scenario.get("title", "l'aventure"))
	var pitch: String = str(scenario.get("pitch", ""))
	var biome: String = str(scenario.get("biome", ""))
	if biome == "":  # le squelette ne porte pas toujours le biome → source de vérité = la run (v10.22)
		var run_b: Node = get_node_or_null("/root/MerlinRun")
		biome = str(run_b.biome) if run_b != null else "foret"
	var lieu_pool: Array = PREAMBULE_LIEU.get(biome, PREAMBULE_LIEU["foret"])
	# N5-C4 - le §3 (ATTENTE) nomme désormais l'ACTION concrète (le pitch), plus le titre poétique : le
	# joueur sait ce qu'il doit FAIRE dès le pop-up d'intro (playtest « discours trop énigmatique »).
	var p: String = pitch.strip_edges().trim_suffix(".")
	var stake: String = p if p != "" else ("mener « %s » à son terme" % title)
	# P3 (chantier 4) : §0 = préambule du MONDE (Graal), PUIS §1 qui tu es · §2 le lieu (biome) · §3 attente.
	var intro: String = "%s\n\n%s\n\n%s\n\n%s" % [
		world_preamble(),
		_pick_preamble(PREAMBULE_QUI, "pre_qui"),
		_pick_preamble(lieu_pool, "pre_lieu|" + biome),
		_pick_preamble(PREAMBULE_ATTENTE, "pre_attente") % stake,
	]
	var mem: String = _build_memory_hint()
	if mem != "":
		intro += "\n\n(Et je me souviens, va : %s. On ne se refait pas, Voyageur.)" % mem
	# v10.14 - le run est une CHAÎNE de quêtes : l'objectif ne promet plus « cinq épreuves ». La ligne
	# « ✦ Objectif » RÉPÈTE le pitch sous le §3 (renforcement voulu, pas confusion).
	var objectif: String = ("%s, et revenir entier des épreuves du sentier." % p) if p != "" else ("Mener « %s » à son terme, et revenir entier du sentier." % title)
	return {"intro": intro.strip_edges(), "objectif": objectif}


func narrate_intro(scenario: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var p: Dictionary = MerlinPromptBuilder.intro(_voice_prefix(), scenario, _build_memory_hint(), _lieu_name())
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return ""
	var s: String = MerlinProse.clean_prose(str(r.get("text", "")).strip_edges())
	return s if s.length() >= 10 else ""


# --- 2ter) OUVERTURE NARRATIVE (user 2026-06-06 : « il faut bien une introduction à l'histoire ») ---
# Distincte du pop-up MERLIN (build_intro) : c'est la NARRATION DE SCÈNE qui lance le récit — plante
# décor + atmosphère + enjeu et donne envie du 1er pas, AVANT le Beat 1. Procédural verbeux INSTANTANÉ
# (3-4 phrases) ; narrate_opening enrichit en arrière-plan. Voix narrateur (SYSTEM_PREFIX), pas d'apostrophe.
const OPENING_FRAMES: Array = [
	"À la lisière de Brocéliande s'ouvre un chemin que les hommes ont oublié. Les fougères s'écartent devant vous, comme si l'on vous attendait. Vous faites un pas, et le bois se referme doucement dans votre dos.",
	"On parle peu de ce lieu, et toujours à voix basse. Devant vous, le sentier s'enfonce sous les arbres, sombre et silencieux. Ce que vous cherchez vous attend au bout ; ce que vous craignez aussi.",
	"La brume se lève sur une clairière que vous n'aviez pas vue en arrivant. Tout y est calme, trop calme, comme avant l'orage. Vous faites un premier pas, et la forêt ne vous laissera plus repartir.",
]


# Ouverture procédurale (INSTANT) : cadre verbeux + l'accroche spécifique du scénario (pitch).
func build_opening(scenario: Dictionary, with_pitch: bool = true) -> String:
	var frame: String = str(OPENING_FRAMES[_rng.randi_range(0, OPENING_FRAMES.size() - 1)])
	var pitch: String = str(scenario.get("pitch", "")).strip_edges()
	# with_pitch=false quand l'accroche est déjà affichée ailleurs (ex. pop-up Merlin build_intro).
	if with_pitch and pitch != "":
		return "%s\n\n%s" % [frame, pitch]
	return frame


# Ouverture LLM (arrière-plan) : lance VRAIMENT l'histoire de CE scénario en 3-4 phrases. "" si moteur KO.
# v10.13 (B0) : priorité BASSE — ne se lance que si le moteur est idle (jamais de préemption).
func narrate_opening(scenario: Dictionary) -> String:
	if not engine_idle():
		return ""
	var mn: Node = _mn()
	var p: Dictionary = MerlinPromptBuilder.opening(scenario, _lieu_name())
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return ""
	var s: String = MerlinProse.clean_prose(str(r.get("text", "")).strip_edges())
	return s if s.length() >= 10 else ""


# v10.13 (B0/B3) — Pré-génère l'ouverture en arrière-plan (pattern _sel_*). RAZ inconditionnelle
# du cache (l'ouverture est PAR-SCÉNARIO — jamais servir celle d'un run précédent), puis lance
# narrate_opening SEULEMENT si le moteur est idle (priorité basse : l'arc/la résolution passent
# devant). L'interstitiel « Merlin raconte » consommera via take_opening (cache-only).
func prefetch_opening(scenario: Dictionary) -> void:
	_opening_epoch += 1
	var epoch: int = _opening_epoch
	_opening_cache = ""
	_opening_state = "idle"
	if not engine_idle():
		return  # moteur occupé (arc/intro en vol) → l'interstitiel servira le procédural
	_opening_state = "running"
	var prose: String = await narrate_opening(scenario)
	if epoch != _opening_epoch:
		return  # un prefetch plus récent a pris la main — résultat périmé, ne rien écraser
	if prose.length() >= 10:
		_opening_cache = prose
		_opening_state = "ready"
	else:
		_opening_state = "idle"  # échec/cancel moteur → l'appelant retombe sur build_opening


# Récupère l'ouverture pré-générée — CACHE-ONLY, ne bloque jamais ("" si pas prête : l'appelant
# sert build_opening procédural). Contrat identique à take_resolution (v10.13 Fix 3).
func take_opening() -> String:
	return _opening_cache


# Vrai si l'ouverture LLM est prête à afficher (l'interstitiel saute alors l'attente animée).
func is_opening_ready() -> bool:
	return _opening_state == "ready" and _opening_cache.length() >= 10


# Vrai si une gen d'ouverture est EN VOL — l'appelant ne doit alors PAS relancer prefetch_opening
# (sa RAZ inconditionnelle écraserait la gen en cours). (review HIGH B3)
func is_opening_pending() -> bool:
	return _opening_state == "running"


# --- 3) SITUATION : le CODE choisit required_tags + une narration procédurale (INSTANT) ;
#         le LLM réécrit la narration en arrière-plan (tags STABLES). ---
func build_situation(beat: Dictionary) -> Dictionary:
	var btype: String = str(beat.get("type", "Exploration"))
	# v2-W1 (R165) — composition des requis PILOTÉE par la difficulté BRUTE du beat (jamais mutée) ;
	# la rampe de difficulté ne touche QUE le DC de résolution (dc_ramp_bonus, ci-dessous).
	var diff: int = int(beat.get("difficulte", 1))
	# La situation ET ses tags requis viennent du MÊME index de l'arc pré-établi → scène ⇄ tags alignés
	# (user 2026-06-07 : « les tags ne correspondent pas à la scène »). Fallback générique si absent.
	# On VERROUILLE l'arc dès la 1re consommation → prepare_arc ne swappera plus (jamais 2 histoires mêlées).
	# v10.14 — index PAR-QUÊTE (qn) et non global (n) : l'arc (5 entrées) couvre UNE quête.
	# Pour les quêtes courtes (k<5), la ligne de CLIMAX de l'arc tombe TOUJOURS sur le climax
	# de la quête (arc[4]) — l'histoire se referme, jamais tronquée au milieu.
	var idx: int = int(beat.get("qn", beat.get("n", 1))) - 1
	var arc: Array = _run_thread.get("arc", [])
	# Le CLIMAX prend la DERNIÈRE scène écrite : c'est elle qui referme l'histoire. L'index était
	# figé à 4 du temps où l'arc comptait toujours cinq entrées ; avec une quête unique de 8 à 25
	# beats, il désignait le cinquième beat et la conclusion tombait au milieu de la partie.
	if btype == "Climax" and not arc.is_empty():
		idx = arc.size() - 1
	var arc_tags: Array = _run_thread.get("arc_tags", [])
	var narration: String = ""
	var required: Array = []
	var provenance: String = "secours"
	# LOOKAHEAD D'ABORD : une scène écrite en connaissant l'issue précédente bat toujours une
	# scène pré-écrite à l'aveugle — c'est elle qui fait s'enchaîner les beats.
	# v35 — la scène lookahead se lit DANS le beat (fix racine : les clés de cache ne
	# coïncidaient jamais). Le cache par qn reste en second regard (harnais hors-jeu).
	var qn_beat: int = int(beat.get("qn", beat.get("n", 1)))
	if str(beat.get("scene_lookahead", "")) != "":
		narration = str(beat.get("scene_lookahead", ""))
		required = (beat.get("scene_lookahead_tags", []) as Array).duplicate()
		provenance = "lookahead"
	elif _scene_cache.has(qn_beat):
		var entree: Dictionary = _scene_cache[qn_beat]
		narration = str(entree.get("texte", ""))
		required = (entree.get("tags", []) as Array).duplicate()
		provenance = "lookahead"
	if narration == "" and idx >= 0 and idx < arc.size() and str(arc[idx]).strip_edges() != "":
		narration = str(arc[idx])
		provenance = "arc"
	if required.is_empty() and idx >= 0 and idx < arc_tags.size() and (arc_tags[idx] is Array) and (arc_tags[idx] as Array).size() > 0:
		required = (arc_tags[idx] as Array).duplicate()
	# v1.0-V4a (BAL-14-A/TEC-17-A) — WHITELIST branchée au JEU RÉEL : le pool générable est calculé
	# ICI, au moment de la présentation (les greffes l'ont fait évoluer depuis le squelette). Les
	# tags de l'arc (LLM ou fallback) sont RE-VALIDÉS contre ce pool (remplacement même index), puis
	# la composition §F est vérifiée (total + hors-base par difficulté, ×1 borné 1 beat/quête) ;
	# toute entorse → re-tirage pick_required_tags — MÊME chemin statique que le harnais probe_soak
	# (zéro drift). Les requis ne changent plus après ce point (R120 : preview = résolution).
	var pool_info: Dictionary = _live_pool_info()
	if not pool_info.is_empty():
		var quest_idx: int = int(beat.get("quest", 0))
		if not _x1_used_by_quest.has(quest_idx):
			_x1_used_by_quest[quest_idx] = []
		var x1_used: Array = _x1_used_by_quest[quest_idx]
		if not required.is_empty():
			required = validate_required_tags(required, idx, pool_info)
			if composition_ok(required, diff, pool_info, x1_used):
				note_x1_emission(required, pool_info, x1_used)
			else:
				required = []  # composition hors-spec (arc const / pool ayant bougé) → re-tirage
		if required.is_empty():
			required = pick_required_tags(btype, diff, pool_info, _rng, x1_used)
	elif required.is_empty():
		required = _pick_tags(btype, diff)  # filet harnais hors-jeu (probe_prose/probe_scenario)
	if narration == "":
		narration = _fallback_situation(btype, required, diff)
	_run_thread["arc_locked"] = true
	# v11-N1 (R140) — filet : toute clause meta qui prend le joueur par la main est bannie PARTOUT (banques
	# réécrites, prompts au « Vous » présent) ; ici on nettoie ce qui viendrait d'un arc LLM ancien ou d'une
	# habitude du modèle (3e personne héritée ou « que faire »).
	for _banned in [
		" Que décida le Voyageur ?", "Que décida le Voyageur ?", " Que décida-t-il ?", "Que décida-t-il ?",
		" Le Voyageur se demandait que faire.", "Le Voyageur se demandait que faire.",
		" Il se demandait que faire.", "Il se demandait que faire.",
		" Vous vous demandez que faire.", "Vous vous demandez que faire.",
	]:
		narration = narration.replace(str(_banned), "")
	narration = narration.strip_edges()
	# v49 — LA SCENE SEULE, sans pont ni ancrage : c'est elle, et elle seule, que le filet
	# anti-echo doit comparer a l'issue. Les coutures posees par le CODE ne sont pas de la
	# prose du modele, et les compter gonflait l'echo de TOUTES les phrases de l'issue —
	# en frappant d'abord celles qui nomment ce qui precede, c'est-a-dire la continuite meme.
	var narration_seule: String = narration
	# N3-V1 (2026-07-06) : CLIMAX ANCRÉ SUR LE BUT. Le beat Climax NOMME ce que la quête promettait pour
	# le refermer (quest_title tissé en ouverture), voix MJ 2e personne présent. C'est l'ouverture du climax
	# (le pont porteur-de-résultat n'est PAS ajouté au climax, cf. plus bas). Titre vide (hors-jeu) : sauté.
	if btype == "Climax":
		var qt: String = str(beat.get("quest_title", _run_thread.get("title", ""))).strip_edges()
		if qt != "":
			var anchor: String = str(CLIMAX_ANCHORS[_rng.randi_range(0, CLIMAX_ANCHORS.size() - 1)]) % qt
			narration = anchor + " " + narration
		# v49 — LE CLIMAX PORTAIT ZERO TRACE de ce qui venait de se passer : le pont l'exclut
		# explicitement (plus bas) et le lookahead retournait dessus. C'est pourtant le beat ou
		# la continuite compte le plus. Le FIL CONCRET, lui, y entre — en tete, avant l'ancrage
		# au but, parce qu'il raconte d'ou l'on vient et l'ancrage dit ou l'on arrive.
		var fil_cl: String = str(_run_thread.get("last_fil", "")).strip_edges()
		if fil_cl != "" and int(beat.get("n", 1)) > 1:
			narration = fil_cl + " " + narration
	# N3-V1 : PONT VISIBLE inter-beats. Pour tout beat n>1 NON-Climax (pont posé par note_outcome du beat
	# précédent, traverse les quêtes comme last_gist), on prépose le pont ANCRÉ (degré, biome, momentum) à la
	# narration : « pont + situation » coule en un paragraphe qui RÉFÉRENCE le beat précédent (playtest N3). Le
	# Climax est EXCLU : son ouverture est déjà l'ancrage au but (ci-dessus) ; empiler pont + ancrage serait
	# lourd et bancal (pont finit en virgule, ancrage est une phrase pleine). Beat 1 ou pont vide : situation seule.
	if int(beat.get("n", 1)) > 1 and btype != "Climax":
		# N5-C4 - 1er beat d'une NOUVELLE quête (qn==1, quest>0) : le pont d'issue ne parle que du beat
		# précédent → on ANNONCE d'abord l'objectif de la nouvelle quête (cite le pitch, voix de Merlin
		# rapportée) pour que le joueur ne change jamais de but sans en être informé (playtest N5).
		var is_new_quest_opening: bool = int(beat.get("qn", 1)) == 1 and int(beat.get("quest", 0)) > 0
		if is_new_quest_opening:
			var qpitch: String = str(beat.get("quest_pitch", "")).strip_edges().trim_suffix(".")
			var qtitle: String = str(beat.get("quest_title", ""))
			var quoted: String = qpitch if qpitch != "" else qtitle
			if quoted != "":
				var qanchor: String = str(QUEST_TRANSITION_ANCHORS[_rng.randi_range(0, QUEST_TRANSITION_ANCHORS.size() - 1)]) % quoted
				narration = qanchor + " " + narration
		elif provenance != "lookahead":
			# v35 — une scène lookahead ENCHAÎNE d'elle-même (écrite en connaissant l'issue) :
			# aucun pont ne s'y prépose (la suite logique, pas l'écho — Maxime 2026-08-20).
			var bridge: String = str(_run_thread.get("bridge", "")).strip_edges()
			if bridge != "":
				# Le pont finit en virgule (amorce) → la situation en devient la suite : sa 1re lettre passe en
				# minuscule pour que « pont, situation » coule comme une phrase (évite « , Vous » bancal). On ne
				# touche QUE le 1er caractère (le reste, majuscules propres incluses, est préservé).
				# v49 — le pont peut desormais etre une PHRASE PLEINE (le fil concret, qui finit
				# par un point). On ne force la minuscule que pour l'amorce MECANIQUE, qui elle
				# finit en virgule : « pont, situation » coule, « phrase. situation » aussi.
				if bridge.ends_with(",") and narration.length() > 0:
					narration = narration.substr(0, 1).to_lower() + narration.substr(1)
				narration = bridge + " " + narration
	return {
		"provenance": provenance,
		"narration": narration,
		# v49 — la narration SANS les coutures du code (pont, ancrage de Climax, annonce de
		# quete) : c'est la reference du filet anti-echo, voir narrate_resolution.
		"narration_seule": narration_seule,
		"required_tags": required,
		"type": btype,
		"difficulte": diff,
		# v2-W1 (R165) — rampe de difficulté : bonus de DC FIGÉ ICI (même dictionnaire que "difficulte")
		# → preview (_update_preview) et résolution (_on_resolve) lisent la MÊME valeur (R120).
		"dc_bonus": dc_ramp_bonus(beat),
		"n": int(beat.get("n", 0)),
		# v10.14 — la narration et le HUD comptent PAR QUÊTE (qn/qtotal) ; quest_title alimente
		# le header. "total" reste la longueur de la quête courante (consommé par les prompts).
		"qn": int(beat.get("qn", beat.get("n", 0))),
		"qtotal": int(beat.get("qtotal", BEAT_TYPES.size())),
		"quest": int(beat.get("quest", 0)),
		"quest_title": str(beat.get("quest_title", _run_thread.get("title", ""))),
		"total": int(beat.get("qtotal", BEAT_TYPES.size())),
		"title": str(_run_thread.get("title", "")),
		# v2-W1 — dé PRÉ-TIRÉ du beat : d20 (moteur d20-vs-DC, MerlinResolution). Tiré ICI une
		# seule fois → preview et résolution finale partagent le même dé (anti cache-miss prose, R120).
		# NON persisté : rebuild au resume = re-tirage, acceptable (rien n'est joué avant le save).
		# Le champ reste "die" ; le visuel du dé reste d6 (projeté) jusqu'à W4.
		"die": MerlinResolution.roll_2d6(_rng),  # R158 : 2d6 (cloche 2-12) remplace le d20 plat
		# Vague Economie V1 — Coup de Pouce : 2e 2d6 PRÉ-TIRÉ, GRATUIT, pour CHAQUE beat (même
		# discipline que "die" ci-dessus), quelle que soit la charge soit armée ou non. Si la charge
		# Coup de Pouce est armée (MerlinRun.consume_coup_de_pouce_if_armed), l'appelant applique
		# face effective = max(die, face_adv) — jamais de tirage "à la demande" (R120).
		"face_adv": MerlinResolution.roll_2d6(_rng),
	}


func _pick_tags(btype: String, _diff: int) -> Array:
	# v10.6 (user 2026-06-06) : TOUJOURS 2 tags requis/beat → un combo de 2 cartes bien choisi les
	# couvre exactement (geste canonique). L'ancienne logique 1-3 selon difficulté est abandonnée
	# pour rendre le lien combo↔scénario évident et cohérent avec la règle « 2 cartes ».
	var pool: Array = TYPE_TAG_BIAS.get(btype, TYPE_TAG_BIAS["Exploration"]).duplicate()
	_shuffle(pool)
	var out: Array = []
	for i in min(2, pool.size()):
		out.append(pool[i])
	return out


func _fallback_situation(btype: String, _required: Array, diff: int = 2) -> String:
	# N2a — banque du BIOME courant (run.biome, défaut "foret" hors-jeu).
	var by_type: Dictionary = SITU_FALLBACKS_BY_BIOME.get(_run_biome(), SITU_FALLBACKS_BY_BIOME["foret"])
	var pool: Array = by_type.get(btype, by_type["Exploration"])
	var raw: String = str(pool[_rng.randi_range(0, pool.size() - 1)])
	return _style_keywords(raw, diff)  # R168 (chantier 4) : marqueurs [kw] -> BBCode coloré + gras


# R168 (chantier 4) — transforme les marqueurs [kw]Mot[/kw] des banques de secours en BBCode coloré
# (couleur = famille du tag, MerlinTags.color_of) ; intensité = difficulté du beat (gras aux
# difficultés I-II, gras+italique à la difficulté III). Généré par le CODE, jamais par le LLM
# (les banques LLM/arc ne portent pas ces marqueurs — seul le filet procédural en profite).
func _style_keywords(text: String, diff: int) -> String:
	var out: String = text
	var start: int = out.find("[kw]")
	while start >= 0:
		var end: int = out.find("[/kw]", start)
		if end < 0:
			break
		var word: String = out.substr(start + 4, end - (start + 4))
		var inner: String = ("[b][i]%s[/i][/b]" % word) if diff >= 3 else ("[b]%s[/b]" % word)
		var replacement: String = "[color=#%s]%s[/color]" % [MerlinTags.color_of(word), inner]
		out = out.substr(0, start) + replacement + out.substr(end + 5)
		start = out.find("[kw]", start + replacement.length())
	return out


# --- ARC NARRATIF (user 2026-06-07 : « décousu, ça doit se suivre, plus direct ») ---
# 5 situations LIÉES qui racontent UNE histoire (début→fin) au lieu de tirages génériques par type.
# Ordre = [Exploration, Rencontre, Epreuve, Dilemme, Climax]. Style DIRECT et CONCRET.
# N2a (2026-07-05) — BIOME-AWARE : FALLBACK_ARCS_BY_BIOME[biome] = 4 arcs ×5 étapes. Les DEUX biomes
# partagent FALLBACK_ARC_TAGS (tags par étape, biome-AGNOSTIQUES) : seule la NARRATION change entre
# forêt et falaises, jamais la structure de tags (scène ⇄ tags ⇄ cartes reste aligné). _fallback_arc
# lit run.biome ; l'index d'arc tiré indexe le MÊME tuple de tags dans les deux biomes.
const FALLBACK_ARCS_BY_BIOME: Dictionary = {
	"foret": [
		[
			"Le sentier s'enfonce sous les arbres et se referme derrière vous. Vous n'êtes pas seul : un pas léger vous suit, à distance, et s'arrête quand vous vous arrêtez.",
			"Une vieille femme est assise sur une souche, là où le chemin se divise. « Je vous attendais », dit-elle sans se lever, et ses doigts ne cessent de tresser une cordelette d'herbe.",
			"Plus loin, un pont de corde enjambe un ravin ; plusieurs planches manquent, et le bois craque à chaque rafale.",
			"Sur l'autre rive, le chemin se sépare en deux : à gauche des torches au loin, à droite le silence et une odeur de fumée. La femme, derrière vous, murmure qu'un seul mène quelque part.",
			"Au bout vous attend une porte de pierre entrouverte. Ce que vous cherchez est derrière, et le pas qui vous suivait vient de s'arrêter, juste là.",
		],
		[
			"Vous suivez le bruit d'une eau qui coule, jusqu'à une source noire et parfaitement immobile au creux de la forêt.",
			"Un enfant accroupi au bord vous fixe sans peur. « Elle dort, ne la réveille pas », souffle-t-il en montrant l'eau, un doigt sur les lèvres.",
			"Le seul passage longe la source sur une corniche étroite et glissante ; un faux pas, et c'est la chute dans l'eau noire.",
			"Une grosse racine barre la route : la couper réveillerait quelque chose, l'enjamber prendrait un temps que vous n'avez pas. L'enfant vous observe, curieux de votre choix.",
			"L'eau se met à bouger : ce que vous êtes venu chercher remonte lentement vers la surface, et vous regarde.",
		],
		[
			"Vous arrivez devant un village de huttes vides, les feux encore tièdes : tout le monde est parti en hâte, sans rien emporter.",
			"Un vieil homme sort d'une hutte, une serpe à la main. « Ils ont fui ce qui descend des collines », lâche-t-il en vous jaugeant, la lame basse mais prête.",
			"La seule sortie passe par un éboulis de pierres branlantes, où le moindre faux mouvement peut tout faire glisser.",
			"Deux traces fraîches partent de l'éboulis : des sabots vers la rivière, des pas nus vers la grotte. Le vieil homme, sur le seuil, ne dit pas laquelle suivre.",
			"Au bout de la trace, la chose des collines vous attend, dos à vous. Elle sait déjà que vous êtes là.",
		],
		[
			"Vous suivez une rigole d'eau noire entre les fougères, jusqu'à une source ronde et immobile où flottent des visages qui ne sont pas le vôtre.",
			"Une femme se tient pieds nus dans la source, sans se retourner. « Vous cherchez un visage, vous aussi », dit-elle, et l'eau ne ride pas autour de ses chevilles.",
			"Le sentier englouti reprend sous l'eau, barré par une dalle de pierre tombée en travers ; le courant froid pousse fort contre vos jambes.",
			"De l'autre côté, deux galeries s'enfoncent : l'une fleurant bon, l'autre froide comme une cave, et dans chacune une voix d'enfant appelle. La femme, derrière vous, retient son souffle.",
			"La galerie débouche sous la source, le monde à l'envers : l'eau noire au-dessus de votre tête, et au centre, votre propre visage.",
		],
	],
	"falaises": [
		[
			"Vous longez le bord de la falaise ; en contrebas, la mer noire se referme sur les rochers sans un bruit d'écume. Un pas vous suit, à distance, et s'arrête quand vous vous arrêtez.",
			"Un vieux gardien de phare surgit d'une cabane de pierre, une lanterne éteinte à la main. « La mer a repris trois barques cette lune », lâche-t-il en vous jaugeant.",
			"Le seul passage descend par un escalier taillé dans le roc, glissant d'embruns ; une marche manque, et le vide appelle en dessous.",
			"Sur la corniche, le sentier se sépare : à gauche des feux de veille au loin, à droite le silence et l'odeur d'algue. Le gardien, derrière vous, murmure qu'un seul mène au phare.",
			"Au bout, une porte de sel entrouverte bat au vent. Ce que vous cherchez est derrière, et le pas qui vous suivait vient de s'arrêter, juste là.",
		],
		[
			"Vous suivez le fracas d'une eau qui frappe le roc, jusqu'à une crique noire et parfaitement immobile, à l'abri du vent.",
			"Un enfant accroupi sur les galets vous fixe sans peur. « Elle dort sous la vague, ne la réveille pas », souffle-t-il en montrant l'eau, un doigt sur les lèvres.",
			"Le seul passage longe la crique sur une corniche étroite et lustrée de sel ; un faux pas, et c'est la chute dans l'eau noire.",
			"Une chaîne d'ancre rouillée barre la route : la briser réveillerait quelque chose, la contourner prendrait un temps que vous n'avez pas. L'enfant vous observe, curieux de votre choix.",
			"L'eau se met à bouger : ce que vous êtes venu chercher remonte lentement de l'écume, et vous regarde.",
		],
		[
			"Vous arrivez devant un hameau de pêcheurs désert, les feux de grève encore tièdes : tout le monde est parti en hâte, sans rien emporter.",
			"Un vieux pêcheur sort d'une cabane, une gaffe à la main. « Ils ont fui ce qui remonte de la mer », lâche-t-il en vous jaugeant, la pointe basse mais prête.",
			"La seule sortie passe par un éboulis de rochers branlants au-dessus des flots, où le moindre faux mouvement peut tout faire glisser.",
			"Deux traces fraîches partent de l'éboulis : des pas mouillés vers la grève, des pas nus vers la grotte marine. Le pêcheur, sur le seuil, ne dit pas laquelle suivre.",
			"Au bout de la trace, la chose de la mer vous attend, dos à vous. Elle sait déjà que vous êtes là.",
		],
		[
			"Vous suivez une coulée d'eau noire entre les rochers, jusqu'à un bassin de marée rond et immobile où flottent des visages qui ne sont pas le vôtre.",
			"Une femme se tient pieds nus dans le bassin, sans se retourner. « Vous cherchez un visage, vous aussi », dit-elle, et l'eau ne ride pas autour de ses chevilles.",
			"Le sentier noyé reprend sous l'eau, barré par une dalle de roche tombée en travers ; le courant froid de la marée pousse fort contre vos jambes.",
			"De l'autre côté, deux failles s'enfoncent : l'une tiède d'air marin, l'autre froide comme une cave, et dans chacune une voix d'enfant appelle. La femme, derrière vous, retient son souffle.",
			"La faille débouche sous le bassin, le monde à l'envers : l'eau noire au-dessus de votre tête, et au centre, votre propre visage.",
		],
	],
}


# Tags requis par étape, ALIGNÉS sur chaque situation des FALLBACK_ARCS_BY_BIOME (même index) → ce que
# la scène demande == les cartes à jouer (user 2026-06-07 : « les combos doivent faire sens »). Tags du
# deck starter. PARTAGÉ par les DEUX biomes (biome-agnostique) : l'index d'arc mappe le même tuple ici.
const FALLBACK_ARC_TAGS: Array = [
	[["Sens", "Instinct"], ["Empathie", "Verbe"], ["Agilité", "Endurance"], ["Instinct", "Ruse"], ["Force", "Instinct"]],
	[["Sens", "Nature"], ["Empathie", "Verbe"], ["Agilité", "Endurance"], ["Ruse", "Instinct"], ["Nature", "Force"]],
	[["Sens", "Savoir"], ["Empathie", "Verbe"], ["Agilité", "Endurance"], ["Instinct", "Savoir"], ["Force", "Ruse"]],
	[["Sens", "Mémoire"], ["Empathie", "Verbe"], ["Force", "Endurance"], ["Instinct", "Ruse"], ["Nature", "Savoir"]],
]


func _fallback_arc() -> Dictionary:
	# N2a — arc du BIOME courant (run.biome, défaut "foret" hors-jeu) ; les tags restent partagés.
	var arcs: Array = FALLBACK_ARCS_BY_BIOME.get(_run_biome(), FALLBACK_ARCS_BY_BIOME["foret"])
	var i: int = _rng.randi_range(0, arcs.size() - 1)
	return {"arc": (arcs[i] as Array).duplicate(), "tags": (FALLBACK_ARC_TAGS[i] as Array).duplicate(true)}


# Arc LLM : 5 étapes liées, CHACUNE construite autour de ses tags requis (req_tags, 2-3 par beat
# selon la difficulté v1.0-V4a) → la scène DEMANDE ces forces (scène ⇄ tags ⇄ cartes alignés).
# [] si moteur KO/format inattendu.
# (A4 : prompt assemblé par MerlinPromptBuilder.arc, parsing par MerlinProse.parse_arc.)
func narrate_arc(scenario: Dictionary, req_tags: Array) -> Array:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return []
	# v10.20.2 — couleur de faction + pilier PNJ (fil rouge) injectés dans l'arc → le LLM les tisse.
	var fblock: String = MerlinPromptBuilder.faction_pilier_block(
		str(_run_thread.get("faction", "")), str(_run_thread.get("pilier", "")),
		str(_run_thread.get("pilier2", "")), bool(_run_thread.get("pnj_recog", false)))
	# v1.0-V4a (spec §F) — le pool générable est injecté comme LISTE FERMÉE dans le prompt d'arc :
	# les scènes ne demandent que des forces atteignables ([] hors-jeu → prompt legacy inchangé).
	var p: Dictionary = MerlinPromptBuilder.arc(scenario, req_tags, fblock, _lieu_name(),
		pool_display_list(_live_pool_info()))
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return []
	return MerlinProse.parse_arc(str(r.get("text", "")))


# Lance la génération de l'arc en arrière-plan (fire-and-forget). Swappe l'arc fallback par l'arc LLM
# SEULEMENT si aucun beat n'a encore été présenté (arc_locked == false) → UNE seule histoire par run.
# L'OUVERTURE, ATTENDUE — et non lancée en fond.
#
# CE QUE LA TRACE A MONTRÉ (2026-08-18) : « arc : 4 beats, 4 jeux de tags, verrou=false, titre=Le
# Souffle du Vieux Druide » puis « arc tranche 1-4 essai 1 : 0 scène(s) ». Les trois portes étaient
# ouvertes, la génération était bien tentée — et le moteur refusait.
#
# La raison est une course que j'avais créée. Le moteur est mono-place. L'arc partait en
# arrière-plan au moment même où la scène de jeu chargeait ; le premier beat s'affichait, le
# joueur posait ses cartes, et la résolution — la seule génération que quelqu'un attend
# activement — prenait la main. L'arc, poli, attendait son tour et ne l'obtenait jamais : à chaque
# beat une nouvelle résolution repassait devant.
#
# La première tranche est donc désormais ATTENDUE, avant que la scène de jeu n'existe. C'est ce
# que « l'ouverture d'abord » voulait dire : rien ne se joue tant que l'histoire n'a pas commencé
# à s'écrire. Le reste de l'arc continue en fond, où l'attente polie a du sens.
func prepare_arc_ouverture(scenario: Dictionary) -> void:
	await _prepare_arc(scenario, 1)
	# LA LÉGENDE D'INTRO, dans la même phase attendue. Le pop-up d'intro n'affichait que deux
	# phrases écrites en dur plus le pitch recopié : la fonction LLM existait (_bg_intro) mais
	# n'était jamais appelée, et non-bloquante elle n'aurait jamais gagné la course de toute
	# façon. Ici le moteur vient de finir la première tranche d'arc : il est libre, le joueur
	# regarde encore « Merlin rêve », c'est le moment exact où cette génération ne coûte rien.
	await _laisser_le_moteur_finir()
	var legende: String = await narrate_intro(scenario)
	if legende != "" and str(_run_thread.get("title", "")) == str(scenario.get("title", "")):
		_run_thread["intro_legende"] = legende
		print("[MerlinScenario] intro — légende écrite (%d car.)" % legende.length())
	else:
		push_warning("[MerlinScenario] intro — légende NON écrite : le pop-up servira le cadrage en dur")
	# LA TÊTE D'ISSUE EN DERNIER (v31.2) : l'intro tourne sur le Vif et ÉVINCE la tête de son
	# cache — mesuré : première issue à 1450 tok réévalués (104 s, secours) quand la deuxième,
	# tête recachée, tombe à 414 tok (28 s, servie). On amène donc la tête APRÈS l'intro ;
	# cache intact, le préfixe se réutilise et cet appel ne coûte presque rien.
	await _laisser_le_moteur_finir()
	var mn_v: Node = _mn()
	if mn_v != null and mn_v.has_method("est_vif_pret") and mn_v.est_vif_pret() and not mn_v.is_busy():
		await mn_v.amorcer_prefixe(MerlinPromptBuilder.SYSTEM_PREFIX, "vif",
				MerlinPromptBuilder.tete_issue(RICHESSE_ISSUE))
		_vif_amorce_fait = true


func prepare_arc(scenario: Dictionary) -> void:
	await _prepare_arc(scenario, 0)


# Garde anti-réentrance : un saut du voile d'ouverture laisse la première tranche en vol pendant
# que la suite est demandée — deux chantiers concurrents écriraient les mêmes scènes deux fois.
var _arc_chantier: bool = false

# La tranche d'arc en vol vient d'être cédée au lookahead (préemption v31.1) : son retour vide
# est une collision assumée, PAS un échec du modèle — le compteur d'échecs réels n'y touche pas.
var _arc_cede_au_fil: bool = false

# --- SCÈNES EN LOOKAHEAD (bible §« lookahead », /goal Maxime 2026-08-18) ---
# La scène N+1 écrite APRÈS l'issue N, en la connaissant. L'arc pré-écrit par tranches ne peut
# pas savoir ce que la résolution du joueur a fait — c'est l'incohérence constatée (« les beats
# ne s'enchaînent pas logiquement par rapport à ce qui a été fait »). Le cache est indexé par
# `qn` (1-based) et porte {texte, tags} : la scène et ses requis restent ALIGNÉS, comme pour
# l'arc. Une entrée n'est JAMAIS servie pour un beat déjà présenté (garde dans le prefetch).
var _scene_cache: Dictionary = {}
var _scene_jit_qn: int = -1   # scène en cours d'écriture (anti-doublon)


# Lancée par le jeu juste après l'AFFICHAGE de l'issue : c'est la fenêtre où le joueur lit —
# la seule où le moteur mono-place est libre sans que personne n'attende. Fire-and-forget,
# silencieux : si la scène n'est pas prête à la présentation du beat, l'arc ou le secours la
# couvrent — et le journal dira la provenance.
func prefetch_scene_suivante(run_node: Node) -> void:
	var beats: Array = (run_node.scenario as Dictionary).get("beats", [])
	var prochain: int = int(run_node.beat_index) + 1
	if prochain >= beats.size():
		return  # pas de beat suivant : la quête se referme
	var beat: Dictionary = beats[prochain]
	var qn: int = int(beat.get("qn", prochain + 1))
	if str(beat.get("scene_lookahead", "")) != "" or _scene_cache.has(qn) or _scene_jit_qn == qn:
		return
	var btype: String = str(beat.get("type", "Exploration"))
	if btype == "Climax":
		return  # le climax garde la scène de clôture de l'arc — c'est elle qui referme l'histoire
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return
	_scene_jit_qn = qn
	# PRIORITÉ DU FIL (validation 6 beats du 2026-08-19 : 0 lookahead servie — l'arc écrivait
	# ses tranches en continu et le `return` silencieux d'ici cédait à chaque fois). La règle
	# décidée : issue > lookahead > arc. Une issue en vol se RESPECTE (on attend qu'elle rende
	# la place) ; une tranche d'arc se PRÉEMPTE — pour l'arc, une collision n'est pas un échec,
	# son budget d'horloge la fera revenir quand le moteur sera libre.
	# v33 — la voie CONTEUR seulement : le Vif peut streamer une issue en même temps,
	# elle ne nous concerne pas. Attente bornée, jamais d'annulation (v31.2).
	var conteur_pris: bool = mn.est_occupe("conteur") if mn.has_method("est_occupe") else mn.is_busy()
	if conteur_pris:
		var dl_moteur: int = Time.get_ticks_msec() + 30000
		while (mn.est_occupe("conteur") if mn.has_method("est_occupe") else mn.is_busy()) and Time.get_ticks_msec() < dl_moteur:
			await get_tree().create_timer(0.5).timeout
		if (mn.est_occupe("conteur") if mn.has_method("est_occupe") else mn.is_busy()):
			_scene_jit_qn = -1
			return  # la place n'a pas été rendue à temps : l'arc couvrira ce beat
	var titre: String = str(_run_thread.get("title", ""))
	# Les tags d'abord, la scène AUTOUR (même principe que l'arc : scène ⇄ tags alignés).
	var pool_info: Dictionary = _live_pool_info()
	var tags: Array = []
	if not pool_info.is_empty():
		var quest_idx: int = int(beat.get("quest", 0))
		if not _x1_used_by_quest.has(quest_idx):
			_x1_used_by_quest[quest_idx] = []
		tags = pick_required_tags(btype, int(beat.get("difficulte", 2)), pool_info, _rng,
				_x1_used_by_quest[quest_idx])
	var fblock: String = MerlinPromptBuilder.faction_pilier_block(
		str(_run_thread.get("faction", "")), str(_run_thread.get("pilier", "")),
		str(_run_thread.get("pilier2", "")), bool(_run_thread.get("pnj_recog", false)))
	var precedent: String = str(_run_thread.get("last_scene", ""))
	# v35.4 — au resolve, l'issue n'est pas encore écrite : sa SUBSTANCE (le gist — geste
	# réel + résultat) vient d'être posée par note_outcome et suffit à enchaîner la scène.
	var issue_prec: String = str(_run_thread.get("last_gist", ""))
	if issue_prec.strip_edges() == "":
		issue_prec = str(_run_thread.get("last_issue", ""))
	var total: int = beats.size()
	var pj: Dictionary = MerlinPromptBuilder.scene_jit(
		{"title": titre, "pitch": str(_run_thread.get("pitch", ""))},
		btype, qn - 1, total, tags, precedent, issue_prec, fblock, _lieu_name(),
		pool_display_list(pool_info))
	var r: Dictionary = await mn.generate(str(pj["system"]), str(pj["user"]), pj["opts"])
	_scene_jit_qn = -1
	if r.has("error"):
		print("[MerlinScenario] lookahead — scène %d ANNULÉE (%s)" % [qn, str(r.get("error", "?"))])
		return  # annulée par une pose (priorité correcte) ou moteur en défaut : l'arc couvrira
	var texte: String = MerlinProse.clean_prose(str(r.get("text", "")).strip_edges())
	if texte.length() < 30:
		print("[MerlinScenario] lookahead — scène %d REJETÉE (trop courte : %d car.)" % [qn, texte.length()])
		return
	if str(_run_thread.get("title", "")) != titre:
		return  # nouvelle partie pendant l'écriture
	# Trop tard ? Le beat visé (index 0-based qn-1) est consommé quand le jeu le PRÉSENTE, juste
	# après l'avancée. Si le run l'a atteint ou dépassé pendant notre écriture, la scène ne sera
	# jamais lue : on la jette plutôt que de laisser croire au cache qu'elle a servi.
	if int(run_node.beat_index) >= qn - 1:
		print("[MerlinScenario] lookahead — scène %d JETÉE (trop tard : beat_index=%d)" % [qn, int(run_node.beat_index)])
		return
	_scene_cache[qn] = {"texte": texte, "tags": tags}
	# v35 — LA SCÈNE VIT DANS LE BEAT : le cache latéral par qn ne coïncidait JAMAIS avec la
	# clé relue par build_situation (0 lookahead servie en 4 parties — le bug racine de
	# « pourquoi une hutte ensuite ? »). Le beat est une RÉFÉRENCE du scénario de la run :
	# ce qu'on y écrit, la présentation le retrouve — sans aucune clé à accorder.
	beat["scene_lookahead"] = texte
	beat["scene_lookahead_tags"] = (tags as Array).duplicate() if tags is Array else []
	print("[MerlinScenario] lookahead — scène %d prête (%d car.)" % [qn, texte.length()])


func _prepare_arc(scenario: Dictionary, tranches_max: int) -> void:
	if _arc_chantier:
		return
	_arc_chantier = true
	await _prepare_arc_corps(scenario, tranches_max)
	_arc_chantier = false


func _prepare_arc_corps(scenario: Dictionary, tranches_max: int) -> void:
	# v10.14 — chain-aware : si le scénario est une CHAÎNE (beats multi-quêtes), l'arc couvre la
	# quête du PREMIER beat (les suivantes passent par begin_quest). Appelants inchangés.
	var beats_all: Array = scenario.get("beats", [])
	if not beats_all.is_empty() and (beats_all[0] is Dictionary) and (beats_all[0] as Dictionary).has("quest"):
		var q0: int = int((beats_all[0] as Dictionary).get("quest", 0))
		scenario = quest_view(scenario, q0)
	var title: String = str(scenario.get("title", ""))  # garde anti-race : ne swappe que si TOUJOURS ce scénario
	# Pré-pick les tags requis par beat AVANT la génération → la scène est écrite AUTOUR (alignement),
	# et build_situation utilise ces mêmes tags pour la couverture. (user 2026-06-07 #1)
	# v1.0-V4a (BAL-14-A) — tirage dans le POOL GÉNÉRABLE du run réel (même chemin statique que le
	# harnais) ; borne ×1 LOCALE à l'arc (la borne par quête fait foi à la présentation, qui
	# re-valide — le pool aura pu bouger avec les greffes). Pool indisponible → legacy _pick_tags.
	var beats: Array = scenario.get("beats", [])
	var picked: Array = []
	var arc_pool: Dictionary = _live_pool_info()
	var x1_local: Array = []
	for b in beats:
		var btype_a: String = str(b.get("type", "Exploration"))
		# v2-W1 (R165) — composition pilotée par la difficulté BRUTE (la rampe ne touche que le DC).
		var diff_a: int = int(b.get("difficulte", 1))
		if arc_pool.is_empty():
			picked.append(_pick_tags(btype_a, diff_a))
		else:
			picked.append(pick_required_tags(btype_a, diff_a, arc_pool, _rng, x1_local))
	# LA GARDE DES CINQ BEATS A SAUTÉ (2026-08-18). Elle disait : « arc LLM réservé aux quêtes de
	# 5 beats ». Or le tirage donnait 2 à 5 beats par quête : quatre fois sur cinq, cette ligne
	# renvoyait AVANT d'appeler le modèle, et toute la partie se jouait sur l'arc procédural. Le
	# fil rouge que Maxime cherchait n'a donc, très probablement, jamais été écrit une seule fois.
	#
	# Désormais l'arc couvre la quête ENTIÈRE, écrite par TRANCHES : la première est attendue (elle
	# porte l'ouverture, celle qui pose la situation), les suivantes s'écrivent pendant qu'on joue
	# les précédentes. Chaque tranche reçoit le résumé de ce qui précède — sans quoi le fil se
	# romprait exactement là où on cherche à le tenir.
	# CHAQUE RENONCEMENT SE NOMME. Deux parties de suite se sont jouées sans une seule tranche
	# d'arc, sans erreur au journal et sans trace : impossible de savoir laquelle de ces trois
	# portes s'était refermée. La leçon est déjà écrite en mémoire (« un composant qui renonce
	# doit le DIRE ») — elle s'applique ici.
	print("[MerlinScenario] arc : %d beats, %d jeux de tags, verrou=%s, titre=%s" % [
		beats.size(), picked.size(), str(_run_thread.get("arc_locked", false)),
		str(_run_thread.get("title", ""))])
	if picked.is_empty():
		push_warning("[MerlinScenario] arc abandonné : aucun jeu de tags (0 beat exploitable)")
		return
	if bool(_run_thread.get("arc_locked", false)):
		push_warning("[MerlinScenario] arc abandonné : le fil est déjà verrouillé (un beat a été présenté avant)")
		return
	if str(_run_thread.get("title", "")) != title:
		push_warning("[MerlinScenario] arc abandonné : le fil porte « %s », on écrivait pour « %s »"
				% [str(_run_thread.get("title", "")), title])
		return
	var total: int = beats.size()
	# ON REPREND OÙ L'OUVERTURE S'EST ARRÊTÉE. `prepare_arc_ouverture` écrit la première tranche et
	# rend la main ; l'appel qui suit doit continuer, pas recommencer — sinon il réécrirait les
	# scènes déjà en place et le joueur verrait le début de son histoire changer sous ses yeux.
	var arc_complet: Array = (_run_thread.get("arc", []) as Array).duplicate()
	var tags_complets: Array = (_run_thread.get("arc_tags", []) as Array).duplicate(true)
	# Le repli procédural compte 5 entrées et n'appartient à personne : on ne le prend pour un
	# début d'histoire que si une vraie tranche a déjà été publiée.
	if not bool(_run_thread.get("arc_du_modele", false)):
		arc_complet = []
		tags_complets = []
	var debut: int = arc_complet.size()
	var faites: int = 0
	while debut < total:
		# `tranches_max` > 0 : on ne fait que ce nombre de tranches et on rend la main (l'ouverture
		# est attendue par l'appelant, le reste suivra en fond).
		if tranches_max > 0 and faites >= tranches_max:
			return
		var fin: int = mini(debut + ARC_TRANCHE, total)
		var types_tranche: Array = []
		var tags_tranche: Array = []
		for i in range(debut, fin):
			types_tranche.append(str((beats[i] as Dictionary).get("type", "Exploration")))
			tags_tranche.append(picked[i] if i < picked.size() else [])
		var precedent: String = _resume_arc(arc_complet)
		# v41 — L'ARC SE TAIT PENDANT LE PREMIER BEAT. v39 empêche de LANCER une tranche
		# pendant une issue, mais une tranche DÉJÀ EN VOL continue : au beat 1 elle démarre
		# pendant la pose et l'issue tombe dedans (p58 : 70 tok en 38,2 s = 1,83 tok/s contre
		# 8+ seule, beat 1 à 68 s contre 40 s de moyenne). L'ouverture garde sa priorité
		# (debut == 0) ; ensuite l'arc attend la résolution du premier beat — aucune
		# annulation (leçon v31.1), et il lui reste cinq beats pour rattraper.
		if debut > 0:
			var run_a: Node = get_node_or_null("/root/MerlinRun")
			var dl_b1: int = Time.get_ticks_msec() + 180000
			while run_a != null and is_instance_valid(run_a) and not run_a.ended \
					and int(run_a.beat_index) <= 0 and Time.get_ticks_msec() < dl_b1:
				await get_tree().create_timer(1.0).timeout
			if str(_run_thread.get("title", "")) != title:
				return  # nouvelle partie pendant l'attente du premier beat
		# PATIENCE, ET NON ABANDON. Le moteur est mono-place et la résolution du beat courant passe
		# toujours devant : elle peut annuler cette tranche à chaque pose de cartes. On retente
		# donc dans un BUDGET d'horloge, et seul un moteur LIBRE qui rend vide compte comme un
		# échec réel — une collision n'a rien prouvé sur la capacité du modèle à écrire.
		var morceau: Array = []
		var echecs_reels: int = 0
		var dl_tranche: int = Time.get_ticks_msec() + int(ARC_TRANCHE_BUDGET_S * 1000.0)
		while morceau.is_empty() and echecs_reels < ARC_ECHECS_REELS_MAX \
				and Time.get_ticks_msec() < dl_tranche:
			await _laisser_le_moteur_finir()
			if str(_run_thread.get("title", "")) != title:
				return  # nouvelle partie pendant l'attente : cet arc n'a plus de destinataire
			var mn_a: Node = _mn()
			# v35 — une scène lookahead qui attend d'écrire passe DEVANT l'arc (inversion de
			# file, jamais d'annulation — leçon v31.1) : l'arc cède son tour, pas sa tranche.
			# v39 — L'ARC S'EFFACE devant toute ISSUE en vol : le joueur attend l'issue, pas
			# l'arc. En duo les deux voies rampent (p56 : issue du beat 1 à 2,7 tok/s pendant
			# les tranches, 8-9 tok/s seule dès le beat 2) : l'arc repatiente aussi tant que
			# le Vif écrit — il rattrape pendant les lectures, son budget d'horloge le couvre.
			if _scene_jit_qn != -1 \
					or mn_a == null or not mn_a.is_ready() \
					or (mn_a.est_occupe("conteur") if mn_a.has_method("est_occupe") else mn_a.is_busy()) \
					or _reso_state == "running" \
					or (mn_a.has_method("est_occupe") and mn_a.est_occupe("vif")):
				await get_tree().create_timer(1.0).timeout
				continue  # scène lookahead, issue en vol ou voie occupée : on repatiente
			morceau = await narrate_arc_tranche(scenario, tags_tranche, types_tranche,
					debut, total, precedent)
			if morceau.is_empty() and _arc_cede_au_fil:
				_arc_cede_au_fil = false
				print("[MerlinScenario] arc tranche %d-%d : cédée au lookahead (collision, pas un échec)"
						% [debut + 1, fin])
			elif morceau.is_empty():
				echecs_reels += 1
				print("[MerlinScenario] arc tranche %d-%d : échec réel %d/%d"
						% [debut + 1, fin, echecs_reels, ARC_ECHECS_REELS_MAX])
			else:
				print("[MerlinScenario] arc tranche %d-%d : %d scène(s)"
						% [debut + 1, fin, morceau.size()])
		if str(_run_thread.get("title", "")) != title:
			return
		if morceau.is_empty():
			# Épuisé pour de bon : on garde ce qui est écrit, le reste ira au secours — et on le DIT.
			push_warning("[MerlinScenario] arc — tranche %d-%d abandonnée (budget ou échecs épuisés) : le secours prendra ces scènes"
					% [debut + 1, fin])
			break
		for i in morceau.size():
			arc_complet.append(morceau[i])
			tags_complets.append(tags_tranche[i] if i < tags_tranche.size() else [])
		# Publication INCRÉMENTALE : la tranche 1 doit servir dès qu'elle existe, sans attendre la
		# dernière. `arc_locked` ne bloque que le remplacement d'une histoire par une AUTRE.
		_run_thread["arc"] = arc_complet.duplicate()
		_run_thread["arc_tags"] = tags_complets.duplicate(true)
		_run_thread["arc_du_modele"] = true
		# On avance du nombre de scènes REELLEMENT reçues, pas de la taille demandée : si le modèle
		# n'en a écrit que trois sur quatre, la quatrième repart dans la tranche suivante au lieu
		# d'être perdue — et surtout l'index de chaque scène reste collé à son beat.
		debut += morceau.size()
		faites += 1


# Ce qu'on rappelle au modèle avant d'écrire la tranche suivante : les deux dernières scènes
# suffisent — tout l'arc gonflerait le prompt (et le prompt coûte la moitié du temps, mesuré).
# Nombre de recours au secours depuis le dernier appel, et remise à zéro. La sonde de journal
# l'interroge après chaque beat : si le compteur a bougé, ce beat porte la marque.
# L'issue TELLE QU'AFFICHÉE (prose du modèle ou secours) : posée par le jeu après l'affichage,
# consommée par le lookahead de la scène suivante.
func note_issue_affichee(prose: String) -> void:
	var p_txt: String = prose.strip_edges()
	# v49 — ON GARDE LA FIN, PAS LE DEBUT. La phrase-crochet vit a la FIN de l'issue : le
	# couperet des 420 PREMIERS caracteres la perdait sur quatre issues sur six (501, 588,
	# 539, 494 caracteres). C'etait exactement la phrase qui portait la continuite.
	_run_thread["last_issue"] = p_txt.substr(maxi(0, p_txt.length() - 420))
	# LE FIL CONCRET. On ne demande RIEN de plus au modele : la phrase existe deja (regle de
	# la tete d'issue), le code cessait seulement de la lire. Fil vide -> le pont mecanique
	# pose par note_outcome reste en place : ce chemin ne peut jamais regresser sous l'existant.
	var fil: String = _extraire_fil(p_txt)
	_run_thread["last_fil"] = fil
	if fil != "":
		_run_thread["bridge"] = fil


func secours_consomme() -> int:
	var n: int = _secours_derniers
	_secours_derniers = 0
	return n


# Laisse le moteur terminer sa tâche en cours. L'arc est le consommateur PATIENT : la résolution
# du beat courant est la seule que le joueur attend activement, elle passe donc toujours devant.
func _laisser_le_moteur_finir() -> void:
	var mn: Node = _mn()
	if mn == null:
		return
	var dl: int = Time.get_ticks_msec() + int(ARC_ATTENTE_S * 1000.0)
	while (not mn.is_ready() or mn.is_busy()) and Time.get_ticks_msec() < dl:
		await get_tree().create_timer(0.5).timeout


func _resume_arc(arc: Array) -> String:
	if arc.is_empty():
		return ""
	var debut: int = maxi(0, arc.size() - 2)
	var bouts: PackedStringArray = []
	for i in range(debut, arc.size()):
		bouts.append(str(arc[i]).strip_edges())
	return " ".join(bouts)


# Une tranche d'arc écrite par le modèle. Rend [] si le moteur n'est pas là ou a échoué : le
# secours prendra le relais, et il sera NOMMÉ dans le journal.
func narrate_arc_tranche(scenario: Dictionary, req_tags: Array, types: Array, debut: int,
		total: int, precedent: String) -> Array:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return []
	var fblock: String = MerlinPromptBuilder.faction_pilier_block(
		str(_run_thread.get("faction", "")), str(_run_thread.get("pilier", "")),
		str(_run_thread.get("pilier2", "")), bool(_run_thread.get("pnj_recog", false)))
	var p: Dictionary = MerlinPromptBuilder.arc_tranche(scenario, req_tags, types, debut, total,
			precedent, fblock, _lieu_name(), pool_display_list(_live_pool_info()))
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return []
	return MerlinProse.parse_arc(str(r.get("text", "")), types.size())


# LLM réservé aux MOMENTS FORTS (Climax ou réussite éclatante) → réduit les rafales d'appels
# séquentiels qui stallent le moteur natif (générations en série). Ailleurs : procédural seul. (user 2026-05-29)
# A4 : source de vérité déplacée dans MerlinPromptBuilder (qui en a besoin pour phrase_target/tok_budget) ;
# l'API publique reste ici (consommée par fallback_resolution + tools/probe_prose + probe_fallback_len).
func is_strong_moment(situ_type: String, degree: String) -> bool:
	return MerlinPromptBuilder.is_strong_moment(situ_type, degree)


# --- 4) RÉSOLUTION : le code a calculé le degré (affiné par la synergie de la combinaison) ;
#         le LLM NARRE la COMBINAISON comme UN geste unifié (R63/R105), "" si échec. ---
func narrate_resolution(situation: Dictionary, played_cards: Array, res: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	# A4 : TOUT l'assemblage du prompt (deg_fr/directives/registres/cover_hint/ctx/exemple + budget
	# tokens long_form) vit dans MerlinPromptBuilder.resolution — le fil rouge _run_thread y est
	# passé en argument (le builder ne lit aucun autoload).
	# Richesse 2 par défaut (laboratoire du 2026-08-18, jugé sur pièce) : au palier 2, TOUS les
	# personnages nommés de la scène réagissent — la pierre se fissure, le chevalier cesse de
	# prier, les druides s'interrompent — pour un coût quasi identique (47 → 51 s, l'évaluation
	# domine). « Les résolutions sont trop légères » : c'est ce palier qui répond.
	var p: Dictionary = MerlinPromptBuilder.resolution(situation, played_cards, res, _run_thread, RICHESSE_ISSUE)
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return ""
	# v49 — le filet compare a la SCENE SEULE. Depuis P2 la narration COMMENCE par une vraie
	# phrase de prose (le fil du beat precedent) : la laisser dans la reference gonflait
	# mecaniquement le recouvrement de toutes les phrases de l'issue, et supprimait en
	# priorite celles qui reprennent ce qui precede — exactement la continuite recherchee.
	var s: String = MerlinProse.strip_scene_echo(MerlinProse.clean_prose(str(r.get("text", "")).strip_edges()), str(situation.get("narration_seule", situation.get("narration", ""))))
	return s if s.length() >= 10 else ""


# --- v10.4 — PRÉ-GÉNÉRATION + RÉCUPÉRATION de l'issue LLM (user 2026-06-06) ---

# Signature d'une combinaison : ids des cartes (ordre = la 1ère est l'action principale) + degré.
# Deux combos identiques (mêmes cartes, même ordre) → même signature → réutilise le cache.
func _reso_signature(played_cards: Array, res: Dictionary) -> String:
	var ids: PackedStringArray = []
	for c in played_cards:
		ids.append(str(c.id) if (c is Object and "id" in c) else "?")
	return "|".join(ids) + "::" + str(res.get("degree", ""))


# Lancée pendant la pose des cartes (merlin_game._update_preview). Génère en arrière-plan l'issue
# pour la combinaison courante. Dédupe : si la même combo est déjà en cours/prête, ne relance pas.
# Un changement de combo bumpe _reso_epoch → la génération en vol devient périmée (résultat ignoré).
func prefetch_resolution(situation: Dictionary, played_cards: Array, res: Dictionary) -> void:
	if played_cards.is_empty():
		return
	var sig: String = _reso_signature(played_cards, res)
	if sig == _reso_sig and (_reso_state == "running" or _reso_state == "ready"):
		return  # déjà en génération ou prêt pour cette combo exacte
	if _reso_cache.has(sig):
		return  # déjà en cache
	var mn: Node = _mn()
	if mn == null:
		return
	if not mn.is_ready():
		# N4-BUG #2a : modèle en cours de chargement (cold start) : mémorise la demande et
		# relance-la quand model_ready tombe (émis sur le thread principal, merlin_native._finish_load).
		# Epoch mémorisé : un invalidate_resolution / prefetch frais la rend périmée (jamais rejouée).
		_pending_prefetch = {"situation": situation, "cards": played_cards, "res": res, "epoch": _reso_epoch}
		if mn.has_signal("model_ready") and not mn.is_connected("model_ready", _relaunch_pending_prefetch):
			mn.connect("model_ready", _relaunch_pending_prefetch, CONNECT_ONE_SHOT)
		return
	_pending_prefetch = {}  # modèle prêt : ce prefetch frais supersède toute demande mémorisée
	_reso_epoch += 1
	var epoch: int = _reso_epoch
	# v38 — la garde de pose v37/v37.1 est retirée avec le chaînage lookahead : elle
	# retardait les issues (46-60 s, 1 SECOURS à p55) sans jamais sauver une scène.
	# v10.13 (Fix 3/8) : une gen PÉRIMÉE (combo abandonnée, arc, épilogue) qui occupe le moteur
	# single-flight est annulée À LA POSE (take_resolution ne bloque plus jamais au resolve).
	# Priorité moteur : la prose de résolution du beat courant passe devant tout le reste — c'est
	# la seule gen que le joueur attend activement.
	# v33 — on ne draine que SA voie (vif) : le Conteur continue d'écrire scènes et arc
	# pendant que l'issue se prépare. Compat mono-voie si le natif n'a pas est_occupe.
	var vif_pris: bool = mn.est_occupe("vif") if mn.has_method("est_occupe") else mn.is_busy()
	if vif_pris:
		if mn.has_method("est_occupe"):
			mn.cancel("vif")
		else:
			mn.cancel()
		# v44 — VINGT SECONDES, PAS QUATRE. Ce drain sert surtout au cas du PACTE : la
		# conversion acceptée change la couverture, donc le degré, donc la signature de
		# l'issue — il faut annuler le texte en cours et réécrire. Or une annulation ne
		# prend qu'entre deux tokens : en pleine évaluation de prompt (976 tokens, 94 s
		# mesurés à p63) la voie reste occupée bien au-delà de 4 s, le drain expirait, et
		# PLUS RIEN n'était relancé : le banc servait. Trois parties, trois bancs, toujours
		# au beat du pacte (p40, p59, p63). Le prefetch est en fond : attendre ne coûte
		# rien au joueur, le stream reste sa garantie d'affichage.
		var free_dl: int = Time.get_ticks_msec() + 20000
		while (mn.est_occupe("vif") if mn.has_method("est_occupe") else mn.is_busy()) and Time.get_ticks_msec() < free_dl:
			await get_tree().process_frame
		if epoch != _reso_epoch:
			return  # combo/beat changé pendant le drain — un prefetch plus récent a pris la main
		if (mn.est_occupe("vif") if mn.has_method("est_occupe") else mn.is_busy()):
			_reso_state = "idle"
			return  # libération trop lente — le stream au resolve prendra le relais
	# N4-BUG (review MEDIUM) : sig posé APRÈS le drain, dans le même geste que « running ».
	# Avant, _reso_sig était réécrit AVANT le drain pendant que _reso_state portait encore le
	# « running » du vol PRÉCÉDENT : is_resolution_incoming(nouvelle combo) matchait par
	# coïncidence (sig neuf + state périmé) pendant la fenêtre de drain (≤4 s). Invariant
	# restauré : sig+running = une génération RÉELLEMENT en vol pour cette signature.
	_reso_sig = sig
	_reso_state = "running"
	print("[MerlinScenario] issue — génération lancée pour %s" % sig)
	var prose: String = await narrate_resolution(situation, played_cards, res)
	if epoch != _reso_epoch:
		# Périmé (invalidate / prefetch plus récent a bumpé l'epoch pendant notre await). Ne remet
		# l'état à idle QUE s'il nous appartient encore (sinon on écraserait le « running » du vol
		# plus récent — la sig a alors changé). Fix review HIGH 2026-06-06 + v10.13.
		if _reso_sig == sig:
			_reso_state = "idle"
		return
	if prose.length() >= 10:
		# v40 — LA PREMIÈRE PHRASE APPARTIENT AU VOYAGEUR : si elle ne commence pas par
		# « Vous » (dérive ~1 beat/partie : scène recopiée ou PNJ en tête), UN re-essai —
		# même contrat que le moteur muet (v35.5), jamais deux pour la même combinaison.
		var _t0: String = prose.strip_edges().trim_prefix("[i]").strip_edges()
		_t0 = _t0.trim_prefix("*").strip_edges()
		if not _t0.begins_with("Vous") and _reso_revous_sig != sig and mn.is_ready():
			_reso_revous_sig = sig
			# v43 — ON NE JETTE JAMAIS UN TEXTE VALIDE : celui-ci n'est qu'imparfait. Il
			# part en réserve et ressortira si la seconde écriture échoue (p59 : un raté
			# est devenu un banc uniquement parce que la première version avait disparu).
			_reso_reserve[sig] = prose
			_reso_state = "idle"
			print("[MerlinScenario] issue — re-essai (première phrase sans « Vous ») pour %s" % sig)
			prefetch_resolution(situation, played_cards, res)
			return
		_reso_cache[sig] = prose
		_reso_state = "ready"
		print("[MerlinScenario] issue — prête au cache pour %s (%d car.)" % [sig, prose.length()])
		# v38 — chaînage lookahead retiré (voir merlin_game) ; last_issue reste nourri
		# pour les ponts d'action et le fil du récit.
		_run_thread["last_issue"] = prose.strip_edges().substr(0, 420)
	elif _reso_reserve.has(sig):
		# v43 — la seconde écriture n'a rien donné : la réserve vaut mille fois le banc.
		_reso_cache[sig] = _reso_reserve[sig]
		_reso_state = "ready"
		print("[MerlinScenario] issue — re-essai vide : la réserve est servie pour %s" % sig)
	else:
		_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)
		print("[MerlinScenario] issue — génération VIDE pour %s" % sig)
		# v35.5 — moteur MUET (vivant mais 0 texte — p40 : 1 token en 33,8 s) : UN re-essai
		# immédiat avant que le banc n'ait le droit de servir. « running » est reposé dans le
		# même geste synchrone : le stream du resolve ne voit jamais passer l'« idle ».
		if _reso_retry_sig != sig and mn.is_ready():
			_reso_retry_sig = sig
			print("[MerlinScenario] issue — re-essai (moteur muet) pour %s" % sig)
			prefetch_resolution(situation, played_cards, res)


# N4-BUG #2a : relance le prefetch mémorisé quand le modèle vient de charger (one-shot, connecté
# par prefetch_resolution au cold start). Ignoré si périmé : invalidate_resolution (nouveau beat)
# ou un prefetch frais (modèle prêt) a bumpé l'epoch / vidé la demande.
func _relaunch_pending_prefetch() -> void:
	if _pending_prefetch.is_empty():
		return
	var p: Dictionary = _pending_prefetch
	_pending_prefetch = {}
	if int(p.get("epoch", -1)) != _reso_epoch:
		return  # résolution périmée (le jeu a avancé pendant le chargement du modèle)
	var situ: Dictionary = p.get("situation", {})
	var cards: Array = p.get("cards", [])
	var res: Dictionary = p.get("res", {})
	prefetch_resolution(situ, cards, res)


# Récupère l'issue LLM au clic Résolution — v10.13 (Fix 3) : NE BLOQUE PLUS JAMAIS. Contrat :
# toute l'attente appartient au SUSTAIN animé de la fusion (cap 20s + clic-skip). Ici : cache-hit
# → prose ; sinon "" → l'appelant sert le fallback procédural immédiatement. La continuité du fil
# rouge est assurée par note_outcome() (appelé inconditionnellement par l'appelant, Fix 4).
func take_resolution(_situation: Dictionary, played_cards: Array, res: Dictionary) -> String:
	_pending_prefetch = {}  # N4-BUG #2a : résolution servie ; une relance tardive serait du gâchis moteur
	var sig: String = _reso_signature(played_cards, res)
	if _reso_cache.has(sig):
		print("[MerlinScenario] issue — servie du cache pour %s" % sig)
		return str(_reso_cache[sig])
	print("[MerlinScenario] issue — cache VIDE pour %s (état=%s, vol pour=%s)" % [sig, _reso_state, _reso_sig])
	return ""


# Vrai si l'issue de cette combo est DÉJÀ en cache (pré-génération finie) → take_resolution sera
# instantané. L'appelant évite ainsi le flicker de l'overlay « Merlin assemble… » (review MEDIUM).
func is_resolution_ready(played_cards: Array, res: Dictionary) -> bool:
	return _reso_cache.has(_reso_signature(played_cards, res))


# N4-BUG #2b : vrai si la prose de CETTE combo peut encore arriver pendant le sustain : déjà en
# cache, ou génération EN VOL pour sa signature exacte. Tout le reste est une attente VAINE :
# state « idle » (rien en vol ; take_resolution ne génère jamais, seul prefetch_resolution
# remplit le cache et il ne peut plus être appelé pendant la fusion), moteur absent / modèle pas
# chargé (cold start, model_failed), moteur occupé par une AUTRE gen (arc/lookahead : drain de
# 4 s échoué à la pose, state retombé « idle »), ou gen en vol pour une autre combo. Le sustain
# de fusion s'appuie dessus (prédicat injecté par merlin_game._on_resolve) pour servir le
# fallback composé immédiatement (~2-3 s de fusion au lieu du cap ~12 s : 14,4-14,7 s
# clic→issue mesurés avant fix). Une gen en vol pour LA combo garde sa fenêtre entière.
func is_resolution_incoming(played_cards: Array, res: Dictionary) -> bool:
	var sig: String = _reso_signature(played_cards, res)
	if _reso_cache.has(sig):
		return true
	return _reso_state == "running" and _reso_sig == sig


# N4-BUG #2b : décision d'attente prise UNE FOIS, AU CLIC Résoudre (sticky). Si l'attente est
# VAINE au clic, la demande mémorisée (#2a) est abandonnée du MÊME geste : sans ça, model_ready
# tombant PENDANT la fusion relançait une gen qui confisquait la fenêtre du sustain (re-mesuré
# 14,6 s : la prose ne peut jamais arriver dans le cap ~12 s à ~3 tok/s) et occupait le moteur
# single-flight au détriment de l'arc/du lookahead. La relance #2a ne sert donc que la POSE.
func begin_resolution_wait(played_cards: Array, res: Dictionary) -> bool:
	var sig: String = _reso_signature(played_cards, res)
	if is_resolution_incoming(played_cards, res):
		print("[MerlinScenario] issue — attente engagée pour %s (cache=%s, vol=%s)"
				% [sig, str(_reso_cache.has(sig)), str(_reso_state == "running" and _reso_sig == sig)])
		return true
	print("[MerlinScenario] issue — attente VAINE pour %s (état=%s, vol pour=%s)"
			% [sig, _reso_state, _reso_sig])
	_pending_prefetch = {}
	return false


# Vide le cache d'issue à chaque nouveau beat (merlin_game._present_current_beat) : les ids de cartes
# se répètent entre beats (deck starter), sans ce reset une combo identique réafficherait la prose
# d'un beat antérieur. Bumpe l'epoch → toute pré-génération en vol devient périmée.
func invalidate_resolution() -> void:
	# v10.13 (Fix 8) : une gen de prose encore en vol au changement de beat occuperait le moteur
	# single-flight jusqu'à 90s → le prefetch du nouveau beat serait silencieusement sauté (guard
	# is_busy) et le sustain plafonnerait À CHAQUE beat. Annulation → moteur libre en ~1-2s.
	if _reso_state == "running":
		var mn: Node = _mn()
		if mn != null and mn.is_busy():
			# v33 — seule la voie du Vif porte les issues : on n'annule qu'elle.
			if mn.has_method("est_occupe"):
				mn.cancel("vif")
			else:
				mn.cancel()
	elif _scene_jit_qn != -1:
		# UNE SCÈNE LOOKAHEAD EN VOL N'EST PAS ANNULÉE au changement de beat (2026-08-19).
		# L'annulation générale tuait la scène N+1 en cours d'écriture À CHAQUE présentation :
		# zéro scène lookahead servie sur deux validations entières, toutes écrites pour rien.
		# La laisser vivre ne coûte rien au beat qui se présente (il a l'arc) ; elle servira au
		# joueur qui lit à son rythme — le prefetch d'issue à la pose la coupera s'il le faut,
		# c'est LUI le prioritaire, pas la présentation.
		pass
	_reso_cache.clear()
	_reso_sig = ""
	_reso_state = "idle"
	_reso_epoch += 1
	_pending_prefetch = {}  # N4-BUG #2a : nouveau beat ; la demande mémorisée au cold start est périmée


# N2a — arch_reg : archétype de carte → REGISTRE (miroir de MerlinPromptBuilder.resolution ; dupliqué
# ici pour rester statique/duck-typé sans dépendre du builder). Clé "" du bank = registre indéterminé.
const _ARCH_REG: Dictionary = {
	"Social": "PAROLE", "Offensif": "FORCE", "Mystique": "PERCEPTION",
	"Défensif": "PROTECTION", "Corrompu": "OMBRE",
}


# N2a — REGISTRE dominant d'une combinaison : 1er archétype résolu des cartes jouées (l'action
# principale est played_cards[0], contrat resolve R20). "" si aucune carte / archétype inconnu.
# Duck-typé (has_method("archetype")) — jamais `is MerlinCard` (leçon soak v10.20.1).
func _dominant_registre(played_cards: Array) -> String:
	for c in played_cards:
		if c is Object and c.has_method("archetype"):
			var reg: String = str(_ARCH_REG.get(str(c.archetype()), ""))
			if reg != "":
				return reg
	return ""


# N2a — tire une entrée d'un pool avec anti-répétition intra-run (_fb_served par `key`) ; pool épuisé
# → RAZ. Factorisé (l'action ET la conséquence composée partagent ce mécanisme).
func _pick_served(pool: Array, key: String) -> String:
	if pool.is_empty():
		return ""
	var served: Array = _fb_served.get(key, [])
	if served.size() >= pool.size():
		served = []
	var avail: Array = []
	for i in pool.size():
		if not served.has(i):
			avail.append(i)
	var idx: int = int(avail[_rng.randi_range(0, avail.size() - 1)])
	served.append(idx)
	_fb_served[key] = served
	return str(pool[idx])


# Procédural de résolution (INSTANT, déterministe). Public : l'appelant l'affiche immédiatement.
# N2a (2026-07-05) — signature ADDITIVE (played_cards, biome) : l'issue de secours COMPOSE désormais
#   [i] ACTION (registre dominant des cartes) [/i] + CONSÉQUENCE (degré × biome).
# Les anciens appelants (harnais probe_* : 1-2 args) → played_cards vide → filet NEUTRE RESO_FALLBACKS
# (rétro-compat parfaite). En jeu, merlin_game passe la combinaison + le biome → l'issue reflète le geste.
func fallback_resolution(degree: String, situ_type: String = "", played_cards: Array = [], biome: String = "") -> String:
	# LE SECOURS SE DÉCLARE (2026-08-18). Il servait en silence à chaque beat, et le joueur lisait
	# des phrases écrites en dur en croyant lire Merlin — c'est exactement ce que Maxime a fini par
	# repérer à l'œil nu. Un filet est légitime ; un filet invisible ne l'est pas.
	_secours_derniers += 1
	push_warning("[MerlinScenario] issue servie par le BANC DE SECOURS (degré %s, beat %s) — le modèle n'a pas rendu à temps"
			% [degree, situ_type])
	var strong: bool = is_strong_moment(situ_type, degree)
	# Sans carte (harnais legacy) : filet neutre pré-écrit (déjà « [i]Vous … [/i] conséquence »).
	if played_cards.is_empty():
		var src: Dictionary = RESO_FALLBACKS_LONG if strong else RESO_FALLBACKS
		var pool0: Array = src.get(degree, src.get("reussite", []))
		if pool0.is_empty():
			pool0 = RESO_FALLBACKS["reussite"]
		return _pick_served(pool0, degree + ("|L" if strong else "|S"))
	# En jeu : COMPOSITION. ACTION selon le registre dominant ; CONSÉQUENCE selon (degré × biome).
	var reg: String = _dominant_registre(played_cards)
	var act_pool: Array = RESO_ACTION_BY_REGISTRE.get(reg, RESO_ACTION_BY_REGISTRE[""])
	if act_pool.is_empty():
		act_pool = RESO_ACTION_BY_REGISTRE[""]
	var action: String = _pick_served(act_pool, "act|" + reg)
	var bio: String = _run_biome(biome)
	var by_bio: Dictionary = RESO_CONSEQ_BY_DEGREE_BIOME.get(degree, RESO_CONSEQ_BY_DEGREE_BIOME["reussite"])
	var conseq_pool: Array = by_bio.get(bio, by_bio.get("foret", []))
	if conseq_pool.is_empty():
		conseq_pool = RESO_CONSEQ_BY_DEGREE_BIOME["reussite"]["foret"]
	var conseq: String = _pick_served(conseq_pool, "cons|%s|%s" % [degree, bio])
	# Moment fort (Climax / éclatante) → conséquence PLUS AMPLE : on greffe une 2e conséquence du même
	# (degré × biome) pour le souffle attendu, sans banque _LONG dédiée (anti-répétition partagé).
	if strong:
		var conseq2: String = _pick_served(conseq_pool, "cons|%s|%s" % [degree, bio])
		if conseq2 != "" and conseq2 != conseq:
			conseq = conseq + " " + conseq2
	# Composition finale : commence DÉJÀ par « [i]Vous … [/i] » → ensure_italic_action (appelé ensuite
	# par merlin_game) reconnaît la forme correcte (1 seule paire ouvrante) et NE double pas l'italique.
	return "[i]" + action + "[/i] " + conseq


# Mémorise le RÉSULTAT du beat courant dans le fil rouge → le prompt d'issue du beat SUIVANT
# enchaîne dessus (continuité). Public (v10.13 Fix 4) : appelé INCONDITIONNELLEMENT par
# merlin_game._on_resolve — le degré est réel même quand la prose finit en procédural.
# v10.20.1 (user 2026-06-30 : « continuité dans les événements, en fonction de ce que l'on fait ») :
# le gist devient SPÉCIFIQUE — ce que le Voyageur a VRAIMENT fait (registre des cartes jouées) + l'issue.
# → le prompt d'issue du beat SUIVANT enchaîne sur l'action réelle, ET un PONT procédural relie la
# situation suivante au résultat (plus de saut « rocher lumineux → chevreuil égaré »).
func note_outcome(res: Dictionary, _situation: Dictionary = {}, played_cards: Array = []) -> void:
	# Mémoire du LOOKAHEAD : la scène qui vient de se jouer et son issue TELLE QU'ÉCRITE — c'est
	# ce que la scène suivante recevra pour en découler visiblement.
	_run_thread["last_scene"] = str(_situation.get("narration", ""))
	var degree: String = str(res.get("degree", "reussite"))
	# Registre de l'ACTION depuis les archétypes des cartes jouées (ce que le geste FUT vraiment).
	# v11-N1 (R140) — gist en 2e personne (passé composé : le beat qui vient de s'achever), consommé
	# « Juste avant : … » par le prompt d'issue du beat suivant. ASCII (prompt LLM, comme le reste).
	var reg_map: Dictionary = {
		"Social": "avez trouve les mots", "Offensif": "avez agi de tout votre corps",
		"Mystique": "avez vu ce qui se cachait", "Défensif": "avez tenu bon sans ceder", "Corrompu": "avez appele l'ombre",
	}
	var regs: Array = []
	for c in played_cards:
		# duck-typing (PAS `is MerlinCard`) : évite une dépendance de classe sur MerlinCard qui cassait le
		# chargement de merlin_scenario (autoload + preload soak) → soak 0/200. v10.20.1 fix.
		if c is Object and c.has_method("archetype"):
			var r: String = str(reg_map.get(c.archetype(), ""))
			if r != "" and not regs.has(r):
				regs.append(r)
	var action: String = " et ".join(PackedStringArray(regs)) if regs.size() > 0 else "avez agi"
	var result_map: Dictionary = {
		"echec": "mais le lieu a resiste", "partiel": "et n'avez obtenu qu'a demi, en laissant un prix",
		"reussite": "et la voie s'est ouverte", "eclatante": "et tout a cede d'un coup",
	}
	var result: String = str(result_map.get(degree, "et la voie s'est ouverte"))
	# last_gist (ASCII) alimente le prompt du beat suivant (« Juste avant : … ») quand le LLM gagne la course.
	_run_thread["last_gist"] = "vous %s, %s" % [action, result]
	# v35 — LE PONT DIT L'ACTION, jamais le degré (Maxime 2026-08-20 : « ne pas faire écho au
	# degré de réussite mais une suite logique à l'action »). Geste réel + locomotion neutre.
	_run_thread["bridge"] = _compose_pont_action(action, _run_biome())


# N3-V1 (2026-07-06) : MOMENTUM courant lu depuis la run (source de vérité /root/MerlinRun.momentum),
# duck-typé comme _run_biome. 0 hors-jeu (harnais : pas de run montée). Le pont neutre est alors servi.
func _run_momentum() -> int:
	if is_inside_tree():
		var run_m: Node = get_node_or_null("/root/MerlinRun")
		if run_m != null and (run_m.get("momentum") != null):
			return int(run_m.get("momentum"))
	return 0


# v35 — locomotions de biome NEUTRES (aucun écho du degré) pour le pont d'action.
const LOCOMOTION_BY_BIOME: Dictionary = {
	"foret": [
		"vous reprenez entre les troncs,",
		"vous vous enfoncez plus avant sous le couvert,",
		"vous suivez le sentier qui se poursuit sous les branches,",
	],
	"falaises": [
		"vous longez la corniche,",
		"vous reprenez le fil du bord,",
		"vous gagnez la roche suivante,",
	],
}


# v35 — le pont reconstruit sur l'ACTION réelle : « Vous avez trouvé les mots ; vous reprenez
# entre les troncs, ». Le degré n'y apparaît jamais. Gist vide (1er beat) → ancien banc.
# === v49 — L'EXTRACTION DU FIL ==============================================================
#
# La derniere phrase de l'issue est, par construction (regle de la tete d'issue), celle qui
# NOMME ce qui vient de reagir et ouvre la suite. C'est elle qui doit ouvrir le beat suivant.
# On la prend, on la valide, et on refuse plutot que de servir une phrase qui deviendrait fausse
# une fois transplantee ailleurs. Refuser rend simplement le pont mecanique : jamais pire
# qu'avant.
const FIL_PRONOMS: Array = ["il ", "elle ", "ils ", "elles ", "cela ", "ceci ", "celui ",
	"celle ", "c'est ", "on "]
const FIL_ABSTRAIT: Array = ["silence", "brume", "presence", "présence", "lumiere", "lumière",
	"ombre", "air", "vent", "chaleur", "odeur", "surface", "forme", "masse", "obscurite"]


func _extraire_fil(prose: String) -> String:
	var txt: String = prose.replace("[i]", "").replace("[/i]", "").strip_edges()
	# v49.2 — LES SCORIES DE MISE EN FORME. Le modele seme des asterisques et des soulignes
	# dans sa prose ; le fil les transportait tels quels en TETE de la scene suivante (p73,
	# deux enchainements sur cinq : « * Le Chevalier tend sa main gantee vers vous. »).
	for _sc in ["*", "_", "`", "#"]:
		txt = txt.replace(str(_sc), "")
	txt = txt.strip_edges()
	var phrases: Array = MerlinProse.split_sentences(txt)
	# v49.2 — JAMAIS LA PHRASE DU GESTE. La premiere phrase de l'issue est, par contrat, celle
	# du geste (en italique) : elle dit ce que le Voyageur vient de FAIRE, pas ce qui l'attend.
	# Transplantee en ouverture du beat suivant, elle rejoue le passe au lieu de l'ouvrir —
	# p73 beat 2 : « Vous plantez vos appuis dans la terre molle et vous frappez... »
	var _premiere: int = 1 if phrases.size() > 1 else 0
	for i in range(phrases.size() - 1, _premiere - 1, -1):
		var s: String = str(phrases[i]).strip_edges()
		# Parole rapportee : on garde ce qui PRECEDE le deux-points. Le tutoiement d'un PNJ ne
		# doit jamais devenir la voix du narrateur au beat suivant.
		var dp: int = s.find(" : ")
		if dp > 20:
			s = s.substr(0, dp).strip_edges() + "."
		if s.length() < 20 or s.length() > 200:
			continue
		var bas: String = s.to_lower()
		if bas.begins_with("tu ") or bas.contains(" tu ") or bas.contains(" t'"):
			continue  # voix cassee une fois transplantee
		# v49.2 — LE FIL DIT LE MONDE, PAS LE VOYAGEUR. « Vous sentez l'humidite sur vos
		# vetements. » ouvrait le Climax de p73 : c'est l'etat du heros, pas ce qui l'attend.
		# Un fil doit NOMMER ce qui reagit — un etre, une bete, un objet.
		if bas.begins_with("vous "):
			continue
		var amorce_pronom: bool = false
		for pr in FIL_PRONOMS:
			if bas.begins_with(str(pr)):
				amorce_pronom = true
		if amorce_pronom:
			continue  # un pronom sans antecedent ne veut plus rien dire au beat suivant
		var mots: PackedStringArray = bas.split(" ", false)
		if mots.size() > 1 and FIL_ABSTRAIT.has(str(mots[1]).trim_suffix(",")):
			continue  # « La brume se retire » n'est pas un fil : rien n'y est nomme
		return s
	return ""


func _compose_pont_action(action: String, biome: String) -> String:
	if action.strip_edges() == "":
		return _compose_bridge("reussite", biome)
	var affichage: Dictionary = {
		"avez trouve les mots": "avez trouvé les mots",
		"avez tenu bon sans ceder": "avez tenu bon sans céder",
		"avez appele l'ombre": "avez appelé l'ombre",
	}
	# v49 — l'accent PAR REGISTRE, avant la jointure. note_outcome joint d'abord les registres
	# par « et », si bien que la cle composite ne matchait jamais la table et que l'ASCII
	# passait a l'ecran (« avez trouve les mots »).
	var parts: PackedStringArray = []
	for _r in action.split(" et "):
		parts.append(str(affichage.get(str(_r), str(_r))))
	var act_aff: String = " et ".join(parts)
	var pool: Array = LOCOMOTION_BY_BIOME.get(biome, LOCOMOTION_BY_BIOME["foret"])
	# v49 — anti-repetition : trois locomotions seulement pour la foret, et un tirage pur
	# rendait deux ponts identiques mot pour mot dans la meme partie. _pick_served existe.
	var loco: String = _pick_served(pool, "loco_%s" % biome)
	return "Vous %s ; %s" % [act_aff, loco]


# N3-V1 : TON du pont selon le momentum (bornes MerlinRun : sombre <= -2, élan >= +2, neutre entre).
func _bridge_tone(momentum: int) -> String:
	if momentum <= -2:
		return "sombre"
	if momentum >= 2:
		return "elan"
	return "neutre"


# N3-V1 : COMPOSE le pont inter-beats (degré, biome, ton du momentum). Anti-répétition intra-run via
# _pick_served (clé par degré|biome|ton). Ton absent pour un couple : fallback "neutre" ; couple absent
# (degré/biome inconnu) : "" (build_situation sert alors la seule situation, jamais de générique cross-biome).
func _compose_bridge(degree: String, biome: String) -> String:
	var by_biome: Dictionary = BRIDGE_BY_DEGREE_BIOME.get(degree, {})
	# Biome absent du dict : "" (jamais de fallback cross-biome, cf. garantie ci-dessus). _run_biome
	# renvoie toujours "foret"/"falaises" (défaut "foret") → en pratique la clé est présente.
	var by_tone: Dictionary = by_biome.get(biome, {})
	if by_tone.is_empty():
		return ""
	var tone: String = _bridge_tone(_run_momentum())
	var pool: Array = by_tone.get(tone, [])
	if pool.is_empty():
		pool = by_tone.get("neutre", [])  # ton extrême non écrit pour ce couple : neutre (jamais cross-biome)
		tone = "neutre"
	if pool.is_empty():
		return ""
	return _pick_served(pool, "bridge|%s|%s|%s" % [degree, biome, tone])


# A4 : helpers de prose (_clean_prose, _strip_scene_echo, _split_sentences, _sig_words,
# _echo_ratio, _first_sentence, _norm, _parse_arc, _clean_selection) déplacés VERBATIM dans
# MerlinProse (statique 100% pur, renommés sans underscore) — testables hors-arbre.


# P2 (2026-07-11, chantier 3 NAR-05) : BANQUE D'ÉPILOGUES par [fin][biome][ton]. Même esprit que
# BRIDGE_BY_DEGREE_BIOME (degré x biome x ton) : le LLM (~1 tok/s) perd la course >95% du temps, donc
# l'épilogue AFFICHÉ est presque toujours le secours. Il DOIT donc coller au BIOME (forêt/falaises) et
# à la FIN (accomplissement/mort/corrompu), et se TEINTER du momentum final (neutre / sombre <= -2 /
# élan >= +2). Voix de MERLIN au Voyageur, 2e personne présent, ton merveilleux-inquiétant. La coda
# LLM (narrate_epilogue) garde la priorité quand elle gagne (merlin_end._bg_epilogue).
const EPILOGUE_BY_END_BIOME: Dictionary = {
	"accomplissement": {
		"foret": {
			"neutre": [
				"Tu franchis le dernier seuil, Voyageur, et la forêt te laisse repartir. Au loin tremble un éclat qui pourrait être le Graal, ou seulement la rosée sur tes cils. Reviens vers moi, mon ami : la brume gardera ta place au chaud.",
				"Voilà, mon ami, le bois se referme derrière toi sans un bruit, comme on repose un secret. Tu emportes un fragment de lumière que Brocéliande croyait avoir perdu. Je t'attendrai sous les mêmes fougères.",
			],
			"elan": [
				"Tu sors du bois la tête haute, Voyageur, et les arbres eux-mêmes s'écartent pour te saluer. Ce que tu as pris cette nuit, peu l'ont arraché à la forêt. Va, mon ami, et sache que je suis un peu fier.",
			],
			"sombre": [
				"Tu franchis le seuil, Voyageur, mais tu ne repars pas tout à fait entier. La forêt t'a laissé passer, et elle a gardé quelque chose de toi entre ses racines. L'éclat que tu emportes a un prix que tu paieras plus tard.",
			],
		},
		"falaises": {
			"neutre": [
				"Tu quittes la corniche, Voyageur, et le vent tombe d'un coup, comme s'il te laissait enfin la paix. Au ras des flots brille un éclat qui pourrait être le Graal, ou l'écume sous la lune. Reviens vers moi, mon ami.",
				"Voilà, la mer s'apaise et te rend le passage, mon Voyageur. Tu emportes de ces falaises un fragment que le sel n'a pas su ronger. Le phare mort, un instant, semble te suivre des yeux.",
			],
			"elan": [
				"Tu redresses les épaules face au large, Voyageur, et la houle elle-même s'incline. Ce que tu as arraché à la roche cette nuit, la mer ne le reprendra pas. Va, mon ami : j'ai vu peu de traversées aussi franches.",
			],
			"sombre": [
				"Tu quittes le bord, Voyageur, mais la mer, en bas, garde l'oeil sur toi. Tu passes, oui, et une voix de sel a déjà prononcé ton nom. L'éclat que tu emportes pèse plus lourd qu'il n'en a l'air.",
			],
		},
	},
	"mort": {
		"foret": {
			"neutre": [
				"Tu t'allonges dans la mousse, mon Voyageur, et la forêt se referme sur toi comme une paupière, sans rancune, juste fatiguée. Mais un murmure se réveille toujours, quelque part. Je veille, mon ami.",
				"Te voilà rendu, Voyageur. Le bois te reprend doucement, feuille après feuille, et fait de toi une racine de plus. Ne crains rien : rien ne se perd tout à fait sous ces arbres, pas même toi.",
			],
			"elan": [
				"Tu tombes le geste encore levé, Voyageur, et la forêt retient son souffle devant ta chute. Tu t'es battu jusqu'au dernier pas. Repose-toi sous la mousse, mon ami : on se souviendra de cet élan.",
			],
			"sombre": [
				"Tu t'effondres, et l'ombre que tu traînais se referme enfin sur toi, mon Voyageur. La forêt ne pleure pas ; elle avait prévu ta place depuis longtemps. Dors. Je garderai ton nom, même si personne d'autre ne le fait.",
			],
		},
		"falaises": {
			"neutre": [
				"Tu glisses vers les galets, Voyageur, et la mer se referme sur toi sans un cri, comme elle l'a fait de tant d'autres. Le vent porte encore ton nom un instant, puis se tait. Je veille, mon ami.",
				"Te voilà rendu au sel, mon Voyageur. La marée t'emporte doucement là où le phare ne s'allume plus. Ne crains rien : la côte garde tous ses noyés, et toi avec eux.",
			],
			"elan": [
				"Tu tombes face au large, le geste encore ouvert, Voyageur, et la houle s'arrête un instant pour te regarder partir. Tu as tenu jusqu'au bord. Repose sur les galets, mon ami : la mer respecte ce genre de courage.",
			],
			"sombre": [
				"Tu cèdes enfin, et l'eau noire que tu sentais monter t'accueille sans surprise, mon Voyageur. Elle attendait son dû depuis le premier pas. Dors sous l'écume. Je garderai ton nom contre le vent.",
			],
		},
	},
	"corrompu": {
		"foret": {
			"neutre": [
				"Tu cesses de lutter, Voyageur, et c'est presque doux, je l'ai vu cent fois. La forêt t'accueille parmi les siens, et déjà quelque part un autre marche en t'entendant. Je suis désolé. Et une part de moi, je l'avoue, n'est pas surprise.",
				"Tu ouvres enfin la porte que tu tenais fermée, mon ami, et l'ombre entre en toi comme chez elle. Tu ne marches plus vers le Graal : tu deviens ce que la forêt cache aux autres. Adieu, Voyageur. Ou plutôt, à bientôt, sous une autre forme.",
			],
			"elan": [
				"Tu embrasses l'ombre en pleine course, Voyageur, sans même ralentir, et Brocéliande frissonne de te voir si sûr. Ce que tu deviens fera de belles histoires pour effrayer les enfants. Va. Une part de moi t'admire encore.",
			],
			"sombre": [
				"Tu sombres sans un cri, mon Voyageur, et la forêt referme sur toi une nuit qui ne connaît plus l'aube. Ce que tu étais s'efface, feuille à feuille. Je me souviendrai de qui tu fus, avant. C'est tout ce qu'il me reste à t'offrir.",
			],
		},
		"falaises": {
			"neutre": [
				"Tu cesses de lutter, Voyageur, et le vent te porte sans résistance, presque tendre. La côte t'accueille parmi ses ombres, et déjà l'écume murmure ton nouveau nom. Je suis désolé. Et une part de moi, je l'avoue, n'est pas surprise.",
				"Tu laisses la mer entrer en toi, mon ami, et le sel prend la place de ce que tu étais. Tu ne cherches plus le Graal : tu deviens la marée qui l'engloutit. Adieu, Voyageur. Ou plutôt, à bientôt, dans le ressac.",
			],
			"elan": [
				"Tu te tournes vers l'ombre le pas assuré, Voyageur, face au large, et la houle applaudit tout bas. Ce que tu deviens, les gardiens de phare le chuchoteront longtemps. Va. Une part de moi t'admire encore.",
			],
			"sombre": [
				"Tu sombres sans un cri sous l'eau noire, mon Voyageur, et la mer referme sur toi une nuit sans phare. Ce que tu étais se dissout dans le sel. Je me souviendrai de qui tu fus, avant. C'est tout ce qu'il me reste.",
			],
		},
	},
}


# --- 5) ÉPILOGUE (fin de run, R69) : LLM, "" si échec → l'appelant garde le procédural. ---
# Voix MERLIN qui referme l'aventure pour le Voyageur, avec souvenir intra-run câblé (user 2026-05-29).
func narrate_epilogue(end_type: String, _state: Dictionary) -> String:
	# v10.13 (B0) : priorité BASSE — ne se lance que si le moteur est idle ("" → procédural conservé).
	if not engine_idle():
		return ""
	var mn: Node = _mn()
	var p: Dictionary = MerlinPromptBuilder.epilogue(_voice_prefix(), end_type, _build_memory_hint())
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return ""
	var s: String = MerlinProse.clean_prose(str(r.get("text", "")).strip_edges())
	return s if s.length() >= 10 else ""


# P2 (chantier 3 NAR-05) : COMPOSE l'épilogue de secours par [fin][biome][ton du momentum]. Miroir de
# _compose_bridge (anti-répétition intra-run via _pick_served). Biome absent : repli forêt ; ton absent
# pour un couple : repli neutre ; couple/fin inconnus : "" (fallback_epilogue sert alors le filet dur).
func _compose_epilogue(end_type: String, biome: String) -> String:
	var by_biome: Dictionary = EPILOGUE_BY_END_BIOME.get(end_type, {})
	if by_biome.is_empty():
		return ""
	var by_tone: Dictionary = by_biome.get(biome, by_biome.get("foret", {}))
	if by_tone.is_empty():
		return ""
	var tone: String = _bridge_tone(_run_momentum())
	var pool: Array = by_tone.get(tone, [])
	if pool.is_empty():
		pool = by_tone.get("neutre", [])
		tone = "neutre"
	if pool.is_empty():
		return ""
	return _pick_served(pool, "epilogue|%s|%s|%s" % [end_type, biome, tone])


func fallback_epilogue(end_type: String) -> String:
	# Voix MERLIN (user 2026-05-29) : utilisé si le LLM échoue/timeout ; doit tenir seul.
	# P2 (chantier 3) : d'abord la banque biome/momentum-aware ; filet dur ci-dessous si couple absent.
	var composed: String = _compose_epilogue(end_type, _run_biome())
	if composed != "":
		return composed
	match end_type:
		"mort": return "Tu pars dans la mousse, mon Voyageur. La forêt se referme sur toi comme une paupière, sans rancune, juste fatiguée de te voir. Mais un murmure se réveille toujours, mon ami. Je veille."
		"corrompu": return "Tu cesses de lutter, Voyageur, et c'est presque doux, je l'ai vu cent fois. La forêt t'accueille parmi les siens ; quelque part déjà, un autre marche en t'entendant. Je suis désolé. Et un peu fier, je l'admets."
		_: return "Tu franchis le dernier seuil, Voyageur. Au loin brille un éclat qui pourrait être le Graal, ou ton reflet dans tes yeux fatigués, je ne saurais dire. La forêt te laisse repartir, pour cette fois. Reviens vers moi, mon ami."


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
