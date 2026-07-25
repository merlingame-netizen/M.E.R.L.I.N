extends Node
## MerlinScenario — pipeline de génération (autoload). Bible R6/R68/R101/R107.
##
## ARCHITECTURE (contraintes hardware : Gemma E2B ~1 tok/s CPU, single-flight) :
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


## v1.0-V4a (GD-32-B, contre-pression §E) — difficulté EFFECTIVE d'un beat : tout beat de la
## quête 3 (index 2) passe à 3 requis (composition 2+1 via REQ_*_BY_DIFF) dès que le build porte
## ≥ 3 greffes — la couverture pleine retombe là où le récit culmine. Statique pur (miroir probe).
static func effective_difficulty(beat: Dictionary, total_grafts: int) -> int:
	var d: int = int(beat.get("difficulte", 1))
	if int(beat.get("quest", 0)) >= 2 and total_grafts >= 3:
		d = maxi(d, 3)
	return d


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
# N5-C1 (2026-07-12, fix biome) - le secours est BIOME-AWARE : le LLM (~1 tok/s) ne gagne presque
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

# Narration procédurale = le texte VU par défaut (le LLM ≈1 tok/s ne gagne presque jamais la
# course contre la lecture du joueur). Donc 5 variantes/type, tirées au sort → variété cross-run
# (chaque type n'apparaît qu'1 fois par run). Ton « merveilleux-inquiétant » (bible §21).
# Scènes COURTES (user 2026-06-06 : « moins avant chaque choix de carte »). 1-2 phrases : poser le
# décor vite, laisser la place au geste. La VERBOSITÉ est réservée à l'ISSUE des moments forts.
# N2a (2026-07-05) — BIOME-AWARE : le LLM (~1 tok/s) ne finit presque jamais sa résolution dans la
# fenêtre du joueur → c'est TOUJOURS le secours qui s'affiche. Il DOIT donc coller au biome (mer /
# falaises en biome falaises, pas « au creux de la forêt »). SITU_FALLBACKS_BY_BIOME[biome][type] :
# la forêt garde ses banques ; les falaises ont leurs propres 5 variantes/type (mer/vent/phare/
# épaves/rochers/sel/écume/marée/mouettes), même forme (2e pers présent, PNJ actif, jamais « que faire »).
const SITU_FALLBACKS_BY_BIOME: Dictionary = {
	"foret": {
		"Exploration": [
			"La clairière s'ouvre devant vous, trop calme. Quelque chose vous attend là, tapi, sans se montrer.",
			"Le sentier disparaît sous les fougères. Pas un bruit, et pourtant on vous regarde, quelque part entre les troncs.",
			"Les arbres s'écartent sur un lieu sans nom. Une odeur de cendre froide flotte, et vos pas résonnent trop fort.",
			"Devant vous, les arbres s'espacent et laissent passer un peu de lumière. C'est trop ouvert, trop facile ; vous avancez quand même, l'échine tendue.",
			"Le sol devient mou sous vos pas, couvert de mousse épaisse. Quelque part tout près, une source coule sans qu'on la voie.",
		],
		"Rencontre": [
			"Une silhouette sort des arbres et se plante devant vous, sans un mot. Elle vous jauge, et attend de voir qui vous êtes.",
			"Une forme immobile vous barre la route. Son regard pèse lourd ; elle ne bougera pas la première.",
			"Une voix vous salue avant que vous ne voyiez personne. « Je connais ce pas », dit-elle, tout près.",
			"Un vieil homme est assis sur une pierre, comme s'il vous attendait. Il ne lève pas les yeux tout de suite, puis crache : « Vous n'auriez pas dû venir. »",
			"Deux yeux brillent entre les troncs, à hauteur d'enfant. Ils ne clignent pas, et une petite voix demande : « Tu viens jouer ? »",
		],
		"Epreuve": [
			"La forêt vous barre le passage : ronces, pierres, pente glissante. Rien ne cédera tout seul.",
			"Le chemin se dresse contre vous, hostile. Il faudra forcer pour avancer.",
			"Un vieil obstacle barre la route. Il faudra payer de vos bras ou de votre ruse.",
			"Un torrent coupe le chemin devant vous, rapide et froid. L'autre rive est juste là, hors d'atteinte.",
			"La pente monte d'un coup, raide et nue. Vos jambes brûlent rien qu'à la regarder.",
		],
		"Dilemme": [
			"Deux chemins s'ouvrent devant vous. Chacun a un prix, et aucun ne vous laissera intact.",
			"Un choix se pose, sans détour. Quoi que vous fassiez, la forêt s'en souviendra.",
			"Il faut trancher, là où il n'y a pas de bonne réponse. Ne rien choisir, c'est choisir aussi.",
			"Une bête blessée gît en travers du sentier, le flanc battant. La soigner coûte du temps ; l'achever, autre chose.",
			"Deux voix vous appellent en même temps, de deux côtés opposés. Vous ne pourrez en suivre qu'une.",
		],
		"Climax": [
			"L'air se fige. La forêt retient son souffle. Ce qui vient ne se reprendra pas.",
			"Tout se joue ici, maintenant. Les murmures se taisent d'un coup autour de vous.",
			"Le cœur de la forêt bat sous vos pieds. Ici se décide ce que vous devenez.",
			"Le sentier débouche sur un cercle de pierres dressées. Au centre, ce que vous êtes venu chercher vous attend.",
			"Tout le bois s'est tu d'un coup. Devant vous, la dernière porte ; derrière elle, la fin de l'histoire.",
		],
	},
	"falaises": {
		"Exploration": [
			"La corniche s'ouvre devant vous, battue de vent. En contrebas, la mer noire se referme sur les rochers sans un cri d'écume.",
			"Le sentier de sel longe le vide. Pas un bruit, sinon la marée qui monte, et pourtant on vous suit, quelque part parmi les épaves.",
			"Les rochers s'écartent sur une crique sans nom. Une odeur d'algue et de goudron froid flotte, et vos pas glissent sur la roche mouillée.",
			"Devant vous, la falaise s'abaisse et laisse voir la baie. C'est trop dégagé, trop offert au vent ; vous avancez quand même, l'échine tendue.",
			"Le sol devient spongieux sous vos pas, gorgé d'embruns. Tout près, sous la roche, la mer travaille une faille qu'on n'aperçoit pas.",
		],
		"Rencontre": [
			"Une silhouette surgit de derrière un rocher et se plante devant vous, sans un mot. Elle vous jauge, le dos à la mer, et attend de voir qui vous êtes.",
			"Un vieux gardien de phare vous barre le passage, une lanterne éteinte à la main. « La mer a repris trois barques cette lune », lâche-t-il en vous toisant.",
			"Une voix vous hèle avant que vous ne voyiez personne, portée par le vent. « Je connais ce pas », dit-elle, tout près, sous le fracas des vagues.",
			"Une pêcheuse est assise sur une épave échouée, comme si elle vous attendait. Elle ne lève pas les yeux tout de suite, puis crache : « Vous n'auriez pas dû descendre jusqu'ici. »",
			"Deux yeux brillent dans le renfoncement d'un rocher, à hauteur d'enfant. Ils ne clignent pas, et une petite voix demande, par-dessus l'écume : « Tu viens voir la marée ? »",
		],
		"Epreuve": [
			"La falaise vous barre le passage : roche à pic, embruns, pierres qui roulent. Rien ne cédera tout seul.",
			"Le sentier se dresse contre vous, taillé à même le roc et lustré de sel. Il faudra forcer pour avancer.",
			"Un vieil escalier de pierre descend vers la crique, une marche manque, et le vide appelle en dessous. Il faudra payer de vos bras ou de votre ruse.",
			"La marée montante coupe le passage devant vous, rapide et froide. L'autre rive de galets est juste là, hors d'atteinte.",
			"La paroi se dresse d'un coup, nue et suintante d'écume. Vos bras brûlent rien qu'à la regarder.",
		],
		"Dilemme": [
			"Deux sentiers s'ouvrent sur la corniche. Chacun a un prix, et aucun ne vous laissera intact.",
			"Un choix se pose, sans détour, face au large. Quoi que vous fassiez, la mer, en bas, en gardera le compte.",
			"Il faut trancher, là où il n'y a pas de bonne réponse. Rester sur le bord, c'est choisir aussi.",
			"Un phoque blessé gît en travers des galets, le flanc battant. Le remettre à l'eau coûte du temps ; l'abandonner, autre chose.",
			"Deux voix vous appellent en même temps, l'une du phare, l'autre de la grève. Vous ne pourrez en suivre qu'une.",
		],
		"Climax": [
			"L'air se fige. Le vent tombe d'un coup, et la mer retient son souffle. Ce qui vient ne se reprendra pas.",
			"Tout se joue ici, maintenant, au bord du vide. Les mouettes se taisent d'un coup au-dessus de vous.",
			"La houle bat la falaise sous vos pieds. Ici, sur le sel, se décide ce que vous devenez.",
			"Le sentier débouche au pied du vieux phare, sa porte de sel entrouverte. Au seuil, ce que vous êtes venu chercher vous attend.",
			"Toute la côte s'est tue d'un coup. Devant vous, la dernière marche au-dessus des flots ; derrière, la fin de l'histoire.",
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
# alors sur le seul last_gist du prompt LLM. Mais le LLM (~1 tok/s) perd la course >95% du temps → la
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
			],
			"elan": [
				"Même ce revers ne vous arrête pas, la sève et la terre dans vos veines, et vous rouvrez la marche entre les fûts,",
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
			],
			"elan": [
				"Même ce revers ne vous plie pas, le sel vif sur vos lèvres, et vous reprenez le fil de la falaise,",
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
			],
			"elan": [
				"Même à demi, ce que vous avez arraché vous porte, et le sous-bois s'ouvre plus franc devant vous,",
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
			],
			"elan": [
				"Même écorné, ce que vous tenez vous soulève, et la falaise s'ouvre plus large devant vos pas,",
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
			],
			"elan": [
				"Tout, depuis vos derniers pas, semble s'écarter devant vous, et le bois s'ouvre plus large à mesure que vous avancez,",
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
			],
			"elan": [
				"Une confiance neuve vous porte depuis vos derniers pas, et le vent lui-même semble vous pousser vers le large,",
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
			],
			"elan": [
				"Rien ne semble pouvoir vous arrêter, et le coeur de la forêt se déplie de lui-même devant vous,",
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
			],
			"elan": [
				"Rien ne semble pouvoir vous arrêter, et la falaise se penche d'elle-même pour vous livrer passage,",
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
var _sel_state: String = "idle"   # idle / running / ready
var _sel_epoch: int = 0

# --- Pré-génération RÉSOLUTION (v10.4, user 2026-06-06 : issue TOUJOURS LLM) ---
# Lancée pendant la pose des cartes (prefetch_resolution), récupérée au clic Résolution
# (take_resolution). Cache par signature de combinaison (ids cartes + degré) → un changement de
# combo supersède via epoch. Masque la latence ~1 tok/s du moteur natif.
var _reso_cache: Dictionary = {}   # signature -> prose
var _reso_sig: String = ""         # signature actuellement en génération
var _reso_state: String = "idle"   # idle / running / ready
var _reso_epoch: int = 0
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


func _on_tweaks_reloaded(_tweaks: Dictionary) -> void:
	# Hot-reload : on relit la persona de base puis on ré-applique l'overlay.
	_load_persona()


func _mn() -> Node:
	return get_node_or_null("/root/MerlinNative")


# v1.0-V4a (GD-32-B) — greffes posées sur le build RÉEL (0 hors-jeu : la contre-pression ne
# s'applique alors pas, la difficulté du beat reste celle du squelette).
func _live_total_grafts() -> int:
	if not is_inside_tree():
		return 0
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run != null and run.has_method("total_grafts"):
		return int(run.total_grafts())
	return 0


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
func warmup_and_prefetch_selection() -> void:
	_sel_epoch += 1
	var epoch: int = _sel_epoch
	_sel_cache = []
	_sel_state = "running"
	var sels: Array = await generate_selection()
	if epoch != _sel_epoch:
		return  # une nouvelle demande a pris le relais → résultat périmé (F3 epoch)
	_sel_cache = sels
	_sel_state = "ready"


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
	# v10/H2 (audit UX bible §21.1 ÉVIDENT) : budget borné 8 s pour ne pas geler le joueur sur
	# l'overlay « Merlin rêve trois sentiers… ». Si le prefetch n'est pas prêt à temps → fallback
	# instantané SEL_FALLBACK plutôt que d'attendre indéfiniment. (user 2026-05-31 /goal)
	var deadline_ms: int = Time.get_ticks_msec() + 8000
	while _sel_state == "running":
		if Time.get_ticks_msec() > deadline_ms:
			break  # n'attend plus le LLM — l'appelant retombe sur le fallback
		await get_tree().process_frame
	if _sel_state == "ready" and _sel_cache.size() >= 3:
		return _sel_cache.duplicate(true)
	if _sel_state == "running":
		return _sel_fallback_pool()  # encore en vol mais on a dépassé le budget
	return await generate_selection()


func invalidate_selection() -> void:
	_sel_epoch += 1
	_sel_cache = []
	_sel_state = "idle"


# v10.19 — sélection prête (3 titres LLM en cache) ? Utilisé par l'écran de sélection pour l'attente
# FORCÉE (titres « forcément générés », user 2026-06-29) au lieu du fallback 8 s.
func is_selection_ready() -> bool:
	return _sel_state == "ready" and _sel_cache.size() >= 3


# Garantit qu'une pré-génération de sélection est lancée. Robustesse : si le warmup du menu n'a pas
# tourné (modèle pas prêt à temps, menu déjà quitté), on relance dès que le moteur est dispo. No-op si
# déjà prête ou en vol.
func ensure_selection_prefetch() -> void:
	if _sel_state == "ready" or _sel_state == "running":
		return
	var mn: Node = _mn()
	if mn != null and mn.is_ready() and not mn.is_busy():
		warmup_and_prefetch_selection()


# --- 1) SÉLECTION : 3 scénarios (titre + pitch) — voix MERLIN (user 2026-05-29) ---
func generate_selection() -> Array:
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var p: Dictionary = MerlinPromptBuilder.selection(_voice_prefix(), _lieu_name())
		var res: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
		if not res.has("error"):
			var arr: Array = MerlinJson.extract_array(str(res.get("text", "")))
			var clean: Array = MerlinProse.clean_selection(arr)
			if clean.size() >= 3:
				return clean.slice(0, 3)
	return _sel_fallback_pool()


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
	_run_thread = {"title": title, "pitch": pitch, "last_gist": "", "bridge": "", "arc": fb["arc"], "arc_tags": fb["tags"], "arc_locked": false,
		"faction": str(fp["faction"]), "pilier": str(fp["pilier"]), "pilier2": str(fp["pilier2"]), "pnj_recog": recog}
	_fb_served = {}  # nouvelle run → toutes les variantes de fallback redeviennent disponibles
	_x1_used_by_quest = {}  # v1.0-V4a : la borne d'émission ×1 repart avec la run
	var nq: int = 2 if _rng.randf() < 0.4 else 3
	var quests: Array = [{"title": title, "pitch": pitch}]
	var pool: Array = _sel_fallback_pool()
	_shuffle(pool)
	for q in pool:
		if quests.size() >= nq:
			break
		if str(q["title"]) != title:
			quests.append({"title": str(q["title"]), "pitch": str(q["pitch"])})
	if quests.size() < nq:
		# Garde anti-race (review HIGH) : des titres DISTINCTS par quête sont requis — c'est le
		# verrou qui empêche un prepare_arc périmé d'écraser l'arc de la quête suivante.
		push_warning("MerlinScenario.build_skeleton: pool de quêtes insuffisant (%d/%d titres distincts)" % [quests.size(), nq])
	var beats: Array = build_chain_beats(quests, _rng)
	return {"title": title, "pitch": pitch, "synopsis": pitch, "beats": beats,
			"total": beats.size(), "quests": quests.size()}


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
		"last_gist": gist, "bridge": bridge, "arc": fb["arc"], "arc_tags": fb["tags"], "arc_locked": false,
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
	# v1.0-V4a (GD-32-B) — contre-pression §E : difficulté EFFECTIVE (quête 3 + ≥3 greffes → 3 requis).
	var diff: int = effective_difficulty(beat, _live_total_grafts())
	# La situation ET ses tags requis viennent du MÊME index de l'arc pré-établi → scène ⇄ tags alignés
	# (user 2026-06-07 : « les tags ne correspondent pas à la scène »). Fallback générique si absent.
	# On VERROUILLE l'arc dès la 1re consommation → prepare_arc ne swappera plus (jamais 2 histoires mêlées).
	# v10.14 — index PAR-QUÊTE (qn) et non global (n) : l'arc (5 entrées) couvre UNE quête.
	# Pour les quêtes courtes (k<5), la ligne de CLIMAX de l'arc tombe TOUJOURS sur le climax
	# de la quête (arc[4]) — l'histoire se referme, jamais tronquée au milieu.
	var idx: int = int(beat.get("qn", beat.get("n", 1))) - 1
	if btype == "Climax":
		idx = 4
	var arc: Array = _run_thread.get("arc", [])
	var arc_tags: Array = _run_thread.get("arc_tags", [])
	var narration: String = ""
	var required: Array = []
	if idx >= 0 and idx < arc.size() and str(arc[idx]).strip_edges() != "":
		narration = str(arc[idx])
	if idx >= 0 and idx < arc_tags.size() and (arc_tags[idx] is Array) and (arc_tags[idx] as Array).size() > 0:
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
		narration = _fallback_situation(btype, required)
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
	# N3-V1 (2026-07-06) : CLIMAX ANCRÉ SUR LE BUT. Le beat Climax NOMME ce que la quête promettait pour
	# le refermer (quest_title tissé en ouverture), voix MJ 2e personne présent. C'est l'ouverture du climax
	# (le pont porteur-de-résultat n'est PAS ajouté au climax, cf. plus bas). Titre vide (hors-jeu) : sauté.
	if btype == "Climax":
		var qt: String = str(beat.get("quest_title", _run_thread.get("title", ""))).strip_edges()
		if qt != "":
			var anchor: String = str(CLIMAX_ANCHORS[_rng.randi_range(0, CLIMAX_ANCHORS.size() - 1)]) % qt
			narration = anchor + " " + narration
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
		else:
			var bridge: String = str(_run_thread.get("bridge", "")).strip_edges()
			if bridge != "":
				# Le pont finit en virgule (amorce) → la situation en devient la suite : sa 1re lettre passe en
				# minuscule pour que « pont, situation » coule comme une phrase (évite « , Vous » bancal). On ne
				# touche QUE le 1er caractère (le reste, majuscules propres incluses, est préservé).
				if narration.length() > 0:
					narration = narration.substr(0, 1).to_lower() + narration.substr(1)
				narration = bridge + " " + narration
	return {
		"narration": narration,
		"required_tags": required,
		"type": btype,
		"difficulte": diff,
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


func _fallback_situation(btype: String, _required: Array) -> String:
	# N2a — banque du BIOME courant (run.biome, défaut "foret" hors-jeu).
	var by_type: Dictionary = SITU_FALLBACKS_BY_BIOME.get(_run_biome(), SITU_FALLBACKS_BY_BIOME["foret"])
	var pool: Array = by_type.get(btype, by_type["Exploration"])
	return str(pool[_rng.randi_range(0, pool.size() - 1)])


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
func prepare_arc(scenario: Dictionary) -> void:
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
	var arc_grafts: int = _live_total_grafts()
	var x1_local: Array = []
	for b in beats:
		var btype_a: String = str(b.get("type", "Exploration"))
		var diff_a: int = effective_difficulty(b, arc_grafts)  # GD-32-B : meilleure estimation à l'arc
		if arc_pool.is_empty():
			picked.append(_pick_tags(btype_a, diff_a))
		else:
			picked.append(pick_required_tags(btype_a, diff_a, arc_pool, _rng, x1_local))
	if picked.size() != 5:
		return  # arc LLM réservé aux quêtes de 5 beats (k<5 → fallback procédural, mapping climax→arc[4])
	var arc: Array = await narrate_arc(scenario, picked)
	if arc.size() == 5 and not bool(_run_thread.get("arc_locked", false)) and str(_run_thread.get("title", "")) == title:
		_run_thread["arc"] = arc
		_run_thread["arc_tags"] = picked


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
	var p: Dictionary = MerlinPromptBuilder.resolution(situation, played_cards, res, _run_thread)
	var r: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if r.has("error"):
		return ""
	var s: String = MerlinProse.strip_scene_echo(MerlinProse.clean_prose(str(r.get("text", "")).strip_edges()), str(situation.get("narration", "")))
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
	# v10.13 (Fix 3/8) : une gen PÉRIMÉE (combo abandonnée, arc, épilogue) qui occupe le moteur
	# single-flight est annulée À LA POSE (take_resolution ne bloque plus jamais au resolve).
	# Priorité moteur : la prose de résolution du beat courant passe devant tout le reste — c'est
	# la seule gen que le joueur attend activement.
	if mn.is_busy():
		mn.cancel()
		var free_dl: int = Time.get_ticks_msec() + 4000
		while mn.is_busy() and Time.get_ticks_msec() < free_dl:
			await get_tree().process_frame
		if epoch != _reso_epoch:
			return  # combo/beat changé pendant le drain — un prefetch plus récent a pris la main
		if mn.is_busy():
			_reso_state = "idle"
			return  # libération trop lente — le sustain servira le fallback si rien n'arrive
	# N4-BUG (review MEDIUM) : sig posé APRÈS le drain, dans le même geste que « running ».
	# Avant, _reso_sig était réécrit AVANT le drain pendant que _reso_state portait encore le
	# « running » du vol PRÉCÉDENT : is_resolution_incoming(nouvelle combo) matchait par
	# coïncidence (sig neuf + state périmé) pendant la fenêtre de drain (≤4 s). Invariant
	# restauré : sig+running = une génération RÉELLEMENT en vol pour cette signature.
	_reso_sig = sig
	_reso_state = "running"
	var prose: String = await narrate_resolution(situation, played_cards, res)
	if epoch != _reso_epoch:
		# Périmé (invalidate / prefetch plus récent a bumpé l'epoch pendant notre await). Ne remet
		# l'état à idle QUE s'il nous appartient encore (sinon on écraserait le « running » du vol
		# plus récent — la sig a alors changé). Fix review HIGH 2026-06-06 + v10.13.
		if _reso_sig == sig:
			_reso_state = "idle"
		return
	if prose.length() >= 10:
		_reso_cache[sig] = prose
		_reso_state = "ready"
	else:
		_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)


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
		return str(_reso_cache[sig])
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
	if is_resolution_incoming(played_cards, res):
		return true
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
			mn.cancel()
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
	# N3-V1 (2026-07-06) : PONT VISIBLE. Le LLM perd la course >95% du temps, donc on RESTAURE un pont
	# procédural (retiré en R140 car alors générique) mais désormais ANCRÉ (degré, biome, momentum). Posé
	# ici : build_situation le prépose à la narration du beat n>1 (fallback presque toujours affiché).
	_run_thread["bridge"] = _compose_bridge(degree, _run_biome())


# N3-V1 (2026-07-06) : MOMENTUM courant lu depuis la run (source de vérité /root/MerlinRun.momentum),
# duck-typé comme _run_biome. 0 hors-jeu (harnais : pas de run montée). Le pont neutre est alors servi.
func _run_momentum() -> int:
	if is_inside_tree():
		var run_m: Node = get_node_or_null("/root/MerlinRun")
		if run_m != null and (run_m.get("momentum") != null):
			return int(run_m.get("momentum"))
	return 0


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
