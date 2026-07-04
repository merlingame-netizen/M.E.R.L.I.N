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

# Biais de tags-cœur par type de beat (R68/R81).
# MVP : limité aux tags COUVRABLES par le deck de départ (R33) — pas d'acquisition au MVP (R19),
# donc une run doit être gagnable avec les 12 cartes. Les tags Monde/extras reviennent post-MVP
# (cartes-souvenir R90). Tags starter : Sens, Savoir, Mémoire, Force, Agilité, Endurance,
# Empathie, Verbe, Ruse, Instinct, Nature.
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

# Pitch = UNE ligne d'accroche-action (appel à l'aventure), pas un paragraphe.
# Le développement complet de la quête arrive dans l'INTRO (pop-up à accepter, voir build_intro).
const SEL_FALLBACK: Array = [
	{"title": "Le Marché des Murmures", "pitch": "Infiltre le marché où l'on troque des noms volés."},
	{"title": "Le Rite sans Fin", "pitch": "Interromps le rite que nul ne sait plus arrêter."},
	{"title": "La Fontaine qui Rêve", "pitch": "Sonde la source noire où dorment les visages."},
]

# Narration procédurale = le texte VU par défaut (le LLM ≈1 tok/s ne gagne presque jamais la
# course contre la lecture du joueur). Donc 3 variantes/type, tirées au sort → variété cross-run
# (chaque type n'apparaît qu'1 fois par run). Ton « merveilleux-inquiétant » (bible §21).
# Scènes COURTES (user 2026-06-06 : « moins avant chaque choix de carte »). 1-2 phrases : poser le
# décor vite, laisser la place au geste. La VERBOSITÉ est réservée à l'ISSUE des moments forts.
const SITU_FALLBACKS: Dictionary = {
	"Exploration": [
		"La clairière s'ouvre devant toi, trop calme. Quelque chose t'attend là, caché.",
		"Le sentier disparaît sous les fougères. Pas un bruit. On te regarde sans se montrer.",
		"Les arbres s'écartent sur un lieu sans nom. Une odeur de cendre froide flotte dans l'air.",
		"Devant toi, les arbres s'espacent et laissent passer un peu de lumière. C'est trop ouvert, trop facile. Tu avances quand même.",
		"Le sol devient mou sous tes pas, couvert de mousse épaisse. Quelque part, une source coule sans qu'on la voie.",
	],
	"Rencontre": [
		"Une silhouette sort des arbres et te fixe, sans un mot. Elle attend de voir qui tu es.",
		"Quelque chose te barre la route, immobile. Son regard pèse lourd.",
		"Une voix te salue avant que tu voies personne. Elle connaît déjà ton pas.",
		"Un vieil homme est assis sur une pierre, comme s'il t'attendait. Il ne lève pas les yeux tout de suite.",
		"Deux yeux brillent entre les troncs, à hauteur d'enfant. Ils ne clignent pas.",
	],
	"Epreuve": [
		"La forêt bloque le passage : ronces, pierres, pente glissante. Rien ne cédera tout seul.",
		"Le chemin se dresse contre toi, hostile. Il faudra forcer pour avancer.",
		"Un vieil obstacle barre la route. Il faudra payer de tes bras ou de ta ruse.",
		"Un torrent coupe le chemin, rapide et froid. L'autre rive est juste là, hors d'atteinte.",
		"La pente monte d'un coup, raide et nue. Tes jambes brûlent rien qu'à la regarder.",
	],
	"Dilemme": [
		"Deux chemins s'ouvrent. Chacun a un prix, et aucun ne te laissera intact.",
		"Un choix se pose, sans détour. Quoi que tu fasses, la forêt s'en souviendra.",
		"Il faut trancher, là où il n'y a pas de bonne réponse. Ne pas choisir, c'est choisir aussi.",
		"Une bête blessée gît en travers du sentier. La soigner coûte du temps ; l'achever, autre chose.",
		"Deux voix t'appellent en même temps, de deux côtés opposés. Tu ne pourras en suivre qu'une.",
	],
	"Climax": [
		"L'air se fige. La forêt retient son souffle. Ce qui vient ne se reprendra pas.",
		"Tout se joue ici, maintenant. Les murmures se taisent d'un coup.",
		"Le cœur de la forêt bat sous tes pieds. Ici se décide ce que tu deviens.",
		"Le sentier débouche sur un cercle de pierres dressées. Au centre, ce que tu es venu chercher t'attend.",
		"Tout le bois s'est tu d'un coup. Devant toi, la dernière porte, et derrière elle, la fin de l'histoire.",
	],
}

const RESO_FALLBACKS: Dictionary = {
	"echec": [
		"Le Voyageur tenta de mêler ses deux forces, mais elles se gênèrent l'une l'autre. La forêt refusa, le repoussa, et il se retrouva plus loin de son but qu'avant. Dans l'ombre, quelque chose parut s'en amuser.",
		"Le mélange sonna faux, et le bois l'entendit aussitôt. Ce que le Voyageur toucha se déroba, ce qu'il crut tenir lui échappa, et il repartit les mains vides.",
		"Le geste ne prit pas sur ce lieu. Le sentier se referma, indifférent, et le laissa en arrière. Ce faux pas-là, il lui faudrait le payer.",
		"Les deux forces du Voyageur partirent de travers et s'annulèrent. Rien ne bougea, sinon lui qu'on repoussa en arrière. Il avait perdu du terrain, et un peu de lui-même avec.",
		"Le mélange rata, et la forêt le sentit. Elle se referma d'un coup, sèche, et le laissa dehors. Le Voyageur repartit sans rien, le cœur plus lourd.",
	],
	"partiel": [
		"Le Voyageur unit ses deux forces, mais de travers. Il obtint ce qu'il voulait — en en laissant un morceau. Une ombre, désormais, marchait dans ses pas.",
		"Le geste fusionné n'ouvrit la voie qu'à demi. Le Voyageur avança tout de même, mais quelque chose l'avait vu faire. Le prix viendrait plus tard.",
		"Le Voyageur arracha son dû, mais un reste lui colla à la peau. La voie s'entrouvrit, étroite, juste assez pour passer. La forêt n'oublia pas ce qu'il avait forcé.",
		"Ses deux forces portèrent à demi. Le Voyageur passa, et quelque chose resta accroché à lui. La forêt avait pris sa part, en silence.",
		"Le mélange ne marcha qu'à moitié. Le Voyageur obtint ce qu'il voulait, mais une dette se noua dans son dos. Elle se rappellerait à lui plus tard.",
	],
	"reussite": [
		"Le Voyageur noua ses deux forces en un seul geste, net et juste. La forêt céda et le laissa avancer d'un pas plus sûr. Cette fois, le sentier ne réclama rien.",
		"Le geste fusionné porta du premier coup. Le chemin s'ouvrit, sans éclat mais sans dette, et le Voyageur passa, entier.",
		"Les deux forces s'accordèrent, et le sentier le laissa passer. La route se dégagea, nette. Le Voyageur avança sans rien laisser derrière lui.",
		"Ses deux gestes s'emboîtèrent, et ce qui résistait céda d'un coup. Le Voyageur reprit sa marche, plus sûr, et rien ne le suivit.",
		"Le mélange porta juste. La forêt recula, calme, et s'écarta devant le Voyageur. Cette fois, il ne paya rien.",
	],
	"eclatante": [
		"Les deux forces du Voyageur n'en firent plus qu'une, si bien que la forêt elle-même retint son souffle. Le passage s'ouvrit en grand, sans résistance, et l'espace d'un instant il fut plus grand que lui-même.",
		"L'accord fut total, et tout le bois le fêta en silence. La voie se déroula devant le Voyageur comme un tapis, et rien ne lui coûta. Pour une fois, la forêt donna plus qu'elle ne prit.",
		"Les deux forces se fondirent à la perfection, et tout céda devant le Voyageur sans le moindre effort. La forêt sembla se ranger de son côté ; rien ne pouvait plus l'arrêter.",
		"L'accord fut si juste que le bois entier s'inclina. Ce que le Voyageur cherchait vint à lui sans qu'il eût à le prendre, et la forêt, pour une fois, donna plus qu'elle ne réclama.",
	],
}

# Fallbacks LONGS (user 2026-06-06) — servis aux MOMENTS FORTS (Climax / éclatante). À ~1 tok/s, l'issue
# LLM longue timeoute souvent en jeu (take_resolution borné ~95s) → sans ces variantes, « plus long au
# climax » ne s'afficherait jamais. Le procédural prend donc le relais EN LONG sur ces moments-là.
const RESO_FALLBACKS_LONG: Dictionary = {
	"echec": [
		"Les deux forces du Voyageur s'élancèrent ensemble, mais au lieu de s'unir elles se brisèrent. La forêt ne se contenta pas de refuser : elle reprit, elle effaça, elle le repoussa. Quelque chose, dans l'ombre, avait vu sa tentative. Il resta seul au bord, les mains vides.",
		"Le geste se retourna contre le Voyageur comme une bête mal tenue. Ce qu'il toucha se déroba, ce qu'il appela ne vint pas. Le lieu se referma, lentement, sur son échec. Il paierait ce moment, il le savait déjà.",
	],
	"partiel": [
		"Les deux forces du Voyageur portèrent, mais de travers. Quelque chose céda, quelque chose s'ouvrit, et dans le même temps une ombre se glissa dans ses pas. Il obtint ce qu'il voulait, et repartit marqué. La forêt avait pris autre chose, sans dire quoi.",
		"Le passage s'entrouvrit à demi sous le geste du Voyageur, juste assez pour s'y faufiler. Mais rien ici n'était gratuit : ce qu'il força lui coûta un morceau. On l'avait vu faire, on ne l'oublierait pas. Il avança, à moitié vainqueur, à moitié débiteur.",
	],
	"reussite": [
		"Les deux gestes du Voyageur se nouèrent enfin en un seul, large et juste, et le lieu céda dans un long soupir. La voie se dénoua devant lui, nette, comme si la forêt avait attendu ce moment. Il passa, entier, plus sûr de son pas, et le silence le suivit comme un accord rare.",
		"Le geste fusionné toucha sa cible du premier coup, et tout le bois l'accusa. Le chemin s'ouvrit sans triomphe bruyant mais sans la moindre dette. Rien ne retenait plus le Voyageur : il franchit le seuil, et la forêt le laissa aller.",
	],
	"eclatante": [
		"Les deux gestes du Voyageur n'en firent soudain plus qu'un, si bien accordés que la forêt elle-même retint son souffle. Le seuil s'ouvrit en grand, sans résistance, et tout au fond, sous les racines, quelque chose d'ancien s'inclina. La voie se déroula comme un tapis. L'espace d'un instant, bref et vertigineux, il fut plus grand que lui-même.",
		"L'accord fut total, et le bois entier le fêta en silence. Ce que le Voyageur venait d'accomplir, peu l'avaient fait avant lui. Le chemin devant n'était plus une épreuve mais un cadeau. Il avança, porté, et derrière lui une voix très douce prononça son nom.",
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
		return SEL_FALLBACK.duplicate(true)  # encore en vol mais on a dépassé le budget
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
		var p: Dictionary = MerlinPromptBuilder.selection(_voice_prefix())
		var res: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
		if not res.has("error"):
			var arr: Array = MerlinJson.extract_array(str(res.get("text", "")))
			var clean: Array = MerlinProse.clean_selection(arr)
			if clean.size() >= 3:
				return clean.slice(0, 3)
	return SEL_FALLBACK.duplicate(true)


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
	var nq: int = 2 if _rng.randf() < 0.4 else 3
	var quests: Array = [{"title": title, "pitch": pitch}]
	var pool: Array = SEL_FALLBACK.duplicate(true)
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
	return beats


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
	var bridge: String = str(_run_thread.get("bridge", ""))  # v10.20.1 : le pont TRAVERSE les quêtes
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
	"Ah, te revoilà, Voyageur. Ce sentier-là, je le connais — il ne mène plus qu'en avant, désormais. Ce que tu cherches t'attend au bout ; ce que tu crains aussi, je ne vais pas te mentir. Avance, mon ami : je marche entre les lignes, à ton côté.",
	"Tiens, mon Voyageur. La brume s'est écartée juste pour toi — ou pour me jouer un tour, avec elle on ne sait jamais. Le sentier se referme dans ton dos ; devant, ce que tu cherches et ce que tu crains, logés à la même enseigne. Allons. Je te suis, ou je te précède, l'un des deux.",
	"Écoute, Voyageur. Le bois a choisi de te laisser entrer — c'est rare, savoure. Ce que tu cherches t'attend au bout du sentier ; ce que tu crains aussi, mais ça, tu le savais déjà. Avance d'un pas tranquille, mon ami. Je veille. Enfin... je crois que je veille.",
]


# v10.22 (user : « remplace le sentier s'ouvre par un préambule qui explique ce qu'on fait là ») —
# PRÉAMBULE LORE en 3 paragraphes : §1 qui tu es · §2 le LIEU t'a appelé (par biome) · §3 ce que Merlin
# attend + le titre de la quête. Banques procédurales, anti-répétition intra-session via _fb_served.
const PREAMBULE_QUI: Array = [
	"Tu es le Voyageur — celui qui marche sans bannière ni serment, et que les chemins reconnaissent. Tu as laissé derrière toi un monde qui ne pose plus de questions ; ici, chaque pierre en pose une.",
	"On ne t'a pas donné de nom en ces terres : Voyageur suffit. Tu portes douze forces anciennes en guise de bagage — perception, corps, parole, intuition — et c'est tout ce que ce lieu te laissera garder.",
	"Tu marches depuis des jours, Voyageur, sans savoir qui de toi ou du chemin a choisi l'autre. Les tiens ne se souviennent déjà plus de ton départ ; ce pays, lui, semblait t'attendre.",
]
const PREAMBULE_LIEU: Dictionary = {
	"foret": [
		"Brocéliande n'est pas une forêt : c'est une mémoire qui pousse. Les arbres y gardent le compte des promesses tenues et brisées, et la brume ne s'écarte que devant ceux qu'elle veut éprouver. Cette nuit, elle s'est écartée devant toi.",
		"On dit que Brocéliande rêve, et que ses rêves ont des sentiers. Y entrer, c'est marcher dans la pensée d'une chose très vieille — les korrigans s'y moquent, les pierres y murmurent, et rien n'y est donné sans dette.",
		"La forêt t'a appelé comme elle appelle les orages : sans un mot, par simple gravité. Sous ses frondaisons vivent quatre puissances qui se disputent son cœur — et la Corruption, patiente, qui les écoute toutes.",
	],
	"falaises": [
		"Les Falaises du Bout-du-Monde tombent dans une mer qui ne rend rien. Le vieux phare n'y guide plus personne : il compte les navires que l'écume a pris, et les esprits du sel remontent la nuit lécher ses pierres. C'est ici que ton chemin s'arrête — ou commence.",
		"Ici, la terre s'achève en à-pic et la mer parle une langue d'avant les hommes. Les goélands portent des messages que nul ne lit plus, et l'embrun grave sur la roche des noms que la marée efface. Le tien vient d'y apparaître.",
		"On ne vient pas aux Falaises : on y échoue, comme les épaves. Le vent y use les serments plus vite que la pierre, et quelque chose, sous l'eau noire, garde le compte de ceux qui se penchent trop près du bord.",
	],
}
const PREAMBULE_ATTENTE: Array = [
	"Je suis Merlin — gardien de ce seuil, et ta seule constante dans ce qui vient. Je ne peux pas marcher à ta place, mais je peux nommer ce que tu affrontes. Voici ce que le lieu exige de toi : « %s ».",
	"Moi, Merlin, je veille sur ce passage depuis plus de lunes que tu n'as de souvenirs. Je te prêterai ma voix et mes yeux — le reste t'appartient. Ta quête a un nom, et le voici : « %s ».",
	"Merlin, on m'appelle — et je t'observais bien avant que tu n'arrives. Chaque geste que tu poseras, je le lirai ; chaque prix, tu le paieras. Ce qui t'attend porte un nom : « %s ».",
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


func build_intro(scenario: Dictionary) -> Dictionary:
	var title: String = str(scenario.get("title", "l'aventure"))
	var pitch: String = str(scenario.get("pitch", ""))
	var biome: String = str(scenario.get("biome", "foret"))
	var lieu_pool: Array = PREAMBULE_LIEU.get(biome, PREAMBULE_LIEU["foret"])
	var intro: String = "%s\n\n%s\n\n%s" % [
		_pick_preamble(PREAMBULE_QUI, "pre_qui"),
		_pick_preamble(lieu_pool, "pre_lieu|" + biome),
		_pick_preamble(PREAMBULE_ATTENTE, "pre_attente") % title,
	]
	var mem: String = _build_memory_hint()
	if mem != "":
		intro += "\n\n(Et je me souviens, va : %s. On ne se refait pas, Voyageur.)" % mem
	# Objectif spécifique : on réutilise l'accroche-action du pitch (déjà un impératif concret).
	var p: String = pitch.strip_edges().trim_suffix(".")
	# v10.14 — le run est une CHAÎNE de quêtes : l'objectif ne promet plus « cinq épreuves ».
	var objectif: String = ("%s — et revenir entier des épreuves du sentier." % p) if p != "" else ("Mener « %s » à son terme, et revenir entier du sentier." % title)
	return {"intro": intro.strip_edges(), "objectif": objectif}


func narrate_intro(scenario: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var p: Dictionary = MerlinPromptBuilder.intro(_voice_prefix(), scenario, _build_memory_hint())
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
	"À la lisière de Brocéliande s'ouvrait un chemin que les hommes avaient oublié. Les fougères s'écartèrent devant le Voyageur, comme si on l'attendait. Il fit un pas, et le bois se referma doucement derrière lui.",
	"On parlait peu de ce lieu, et toujours à voix basse. Devant le Voyageur, le sentier s'enfonçait sous les arbres, sombre et silencieux. Ce qu'il cherchait l'attendait au bout ; ce qu'il craignait aussi.",
	"La brume se leva sur une clairière que le Voyageur n'avait pas vue en arrivant. Tout y était calme, trop calme, comme avant l'orage. Il fit un premier pas, et la forêt ne le laisserait plus repartir.",
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
	var p: Dictionary = MerlinPromptBuilder.opening(scenario)
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
	var diff: int = int(beat.get("difficulte", 1))
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
	if required.is_empty():
		required = _pick_tags(btype, diff)
	if narration == "":
		narration = _fallback_situation(btype, required)
	# v10.20.1 — PONT de continuité : la situation s'OUVRE sur ce que le Voyageur vient de faire (degré du
	# beat précédent). Tue le saut abrupt « rocher → chevreuil ». Pas au 1er beat de la run (rien avant).
	var bridge: String = str(_run_thread.get("bridge", ""))
	if int(beat.get("n", 1)) > 1 and bridge != "":
		narration = bridge + " " + narration
	_run_thread["arc_locked"] = true
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
		# v10.14 — dé PRÉ-TIRÉ du beat (bandes par rareté dans MerlinResolution). Tiré ICI une
		# seule fois → preview et résolution finale partagent le même dé (anti cache-miss prose).
		# NON persisté : rebuild au resume = re-tirage, acceptable (rien n'est joué avant le save).
		"die": _rng.randi_range(1, 6),
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
	var pool: Array = SITU_FALLBACKS.get(btype, SITU_FALLBACKS["Exploration"])
	return str(pool[_rng.randi_range(0, pool.size() - 1)])


# --- ARC NARRATIF (user 2026-06-07 : « décousu, ça doit se suivre, plus direct ») ---
# 5 situations LIÉES qui racontent UNE histoire (début→fin) au lieu de tirages génériques par type.
# Ordre = [Exploration, Rencontre, Epreuve, Dilemme, Climax]. Style DIRECT et CONCRET.
const FALLBACK_ARCS: Array = [
	[
		"Le sentier s'enfonça sous les arbres et se referma derrière le Voyageur. Il n'était pas seul : un pas léger le suivait, à distance. Que décida le Voyageur ?",
		"Une vieille femme attendait, assise sur une souche, là où le chemin se divisait. « Je t'attendais », dit-elle sans se lever. Le Voyageur se demandait que faire.",
		"Plus loin, un pont de corde enjambait un ravin, mais plusieurs planches manquaient et le bois craquait sous le vent. Que décida le Voyageur ?",
		"Sur l'autre rive, le chemin se sépara en deux : à gauche des torches au loin, à droite le silence et une odeur de fumée. Que décida-t-il ?",
		"Au bout l'attendait une porte de pierre entrouverte. Ce qu'il cherchait était derrière — et le pas qui le suivait venait de s'arrêter, juste là. Que décida le Voyageur ?",
	],
	[
		"Le Voyageur suivit le bruit d'une eau qui coulait, jusqu'à une source noire et parfaitement immobile au creux de la forêt. Que décida le Voyageur ?",
		"Un enfant accroupi au bord le fixait sans peur. « Elle dort, ne la réveille pas », murmura-t-il en montrant l'eau. Le Voyageur se demandait que faire.",
		"Le seul passage longeait la source sur une corniche étroite et glissante ; un faux pas, et c'était la chute dans l'eau noire. Que décida le Voyageur ?",
		"Une grosse racine barrait la route : la couper réveillerait quelque chose, l'enjamber prendrait un temps qu'il n'avait pas. Que décida-t-il ?",
		"L'eau se mit à bouger : ce qu'il était venu chercher remontait lentement vers la surface, et le regardait. Que décida le Voyageur ?",
	],
	[
		"Le Voyageur arriva devant un village de huttes vides, les feux encore tièdes : tout le monde était parti en hâte, sans rien emporter. Que décida le Voyageur ?",
		"Un vieil homme sortit d'une hutte, une serpe à la main. « Ils ont fui ce qui descend des collines », dit-il en le jaugeant. Le Voyageur se demandait que faire.",
		"La seule sortie passait par un éboulis de pierres branlantes, où le moindre faux mouvement pouvait tout faire glisser. Que décida le Voyageur ?",
		"Deux traces fraîches partaient de l'éboulis : des sabots vers la rivière, des pas nus vers la grotte. Il ne pouvait en suivre qu'une. Que décida-t-il ?",
		"Au bout de la trace, la chose des collines l'attendait, dos à lui. Elle savait déjà qu'il était là. Que décida le Voyageur ?",
	],
	[
		"Le Voyageur suivit une rigole d'eau noire entre les fougères, jusqu'à une source ronde et immobile où flottaient des visages qui n'étaient pas le sien. Que décida le Voyageur ?",
		"Une femme se tenait pieds nus dans la source, sans se retourner. « Tu cherches un visage, toi aussi », dit-elle. Le Voyageur se demandait que faire.",
		"Le sentier englouti reprenait sous l'eau, barré par une dalle de pierre tombée en travers, et le courant froid poussait fort contre ses jambes. Que décida le Voyageur ?",
		"De l'autre côté, deux galeries s'enfonçaient : l'une fleurant bon, l'autre froide comme une cave, et dans chacune une voix d'enfant appelait. Que décida-t-il ?",
		"La galerie déboucha sous la source, le monde à l'envers : l'eau noire au-dessus de sa tête, et au centre, son propre visage. Que décida le Voyageur ?",
	],
]


# Tags requis par étape, ALIGNÉS sur chaque situation des FALLBACK_ARCS (même index) → ce que la scène
# demande == les cartes à jouer (user 2026-06-07 : « les combos doivent faire sens »). Tags du deck starter.
const FALLBACK_ARC_TAGS: Array = [
	[["Sens", "Instinct"], ["Empathie", "Verbe"], ["Agilité", "Endurance"], ["Instinct", "Ruse"], ["Force", "Instinct"]],
	[["Sens", "Nature"], ["Empathie", "Verbe"], ["Agilité", "Endurance"], ["Ruse", "Instinct"], ["Nature", "Force"]],
	[["Sens", "Savoir"], ["Empathie", "Verbe"], ["Agilité", "Endurance"], ["Instinct", "Savoir"], ["Force", "Ruse"]],
	[["Sens", "Mémoire"], ["Empathie", "Verbe"], ["Force", "Endurance"], ["Instinct", "Ruse"], ["Nature", "Savoir"]],
]


func _fallback_arc() -> Dictionary:
	var i: int = _rng.randi_range(0, FALLBACK_ARCS.size() - 1)
	return {"arc": (FALLBACK_ARCS[i] as Array).duplicate(), "tags": (FALLBACK_ARC_TAGS[i] as Array).duplicate(true)}


# Arc LLM : 5 étapes liées, CHACUNE construite autour de ses 2 tags requis (req_tags) → la scène
# DEMANDE ces forces (scène ⇄ tags ⇄ cartes alignés). [] si moteur KO/format inattendu.
# (A4 : prompt assemblé par MerlinPromptBuilder.arc, parsing par MerlinProse.parse_arc.)
func narrate_arc(scenario: Dictionary, req_tags: Array) -> Array:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return []
	# v10.20.2 — couleur de faction + pilier PNJ (fil rouge) injectés dans l'arc → le LLM les tisse.
	var fblock: String = MerlinPromptBuilder.faction_pilier_block(
		str(_run_thread.get("faction", "")), str(_run_thread.get("pilier", "")),
		str(_run_thread.get("pilier2", "")), bool(_run_thread.get("pnj_recog", false)))
	var p: Dictionary = MerlinPromptBuilder.arc(scenario, req_tags, fblock)
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
	# Pré-pick les 2 tags requis par beat AVANT la génération → la scène est écrite AUTOUR (alignement),
	# et build_situation utilise ces mêmes tags pour la couverture. (user 2026-06-07 #1)
	var beats: Array = scenario.get("beats", [])
	var picked: Array = []
	for b in beats:
		picked.append(_pick_tags(str(b.get("type", "Exploration")), int(b.get("difficulte", 1))))
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
	if mn == null or not mn.is_ready():
		return
	_reso_epoch += 1
	var epoch: int = _reso_epoch
	_reso_sig = sig
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


# Récupère l'issue LLM au clic Résolution — v10.13 (Fix 3) : NE BLOQUE PLUS JAMAIS. Contrat :
# toute l'attente appartient au SUSTAIN animé de la fusion (cap 20s + clic-skip). Ici : cache-hit
# → prose ; sinon "" → l'appelant sert le fallback procédural immédiatement. La continuité du fil
# rouge est assurée par note_outcome() (appelé inconditionnellement par l'appelant, Fix 4).
func take_resolution(_situation: Dictionary, played_cards: Array, res: Dictionary) -> String:
	var sig: String = _reso_signature(played_cards, res)
	if _reso_cache.has(sig):
		return str(_reso_cache[sig])
	return ""


# Vrai si l'issue de cette combo est DÉJÀ en cache (pré-génération finie) → take_resolution sera
# instantané. L'appelant évite ainsi le flicker de l'overlay « Merlin assemble… » (review MEDIUM).
func is_resolution_ready(played_cards: Array, res: Dictionary) -> bool:
	return _reso_cache.has(_reso_signature(played_cards, res))


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


# Procédural de résolution (INSTANT, déterministe). Public : l'appelant l'affiche immédiatement.
func fallback_resolution(degree: String, situ_type: String = "") -> String:
	# Longueur VARIABLE même en procédural (user 2026-06-06) : aux MOMENTS FORTS (Climax / éclatante)
	# on sert le pool LONG → « plus long au climax » s'affiche EN JEU même quand l'issue LLM longue
	# timeoute (cas fréquent à ~1 tok/s). Sinon pool de routine (plus court).
	var strong: bool = is_strong_moment(situ_type, degree)
	var src: Dictionary = RESO_FALLBACKS_LONG if strong else RESO_FALLBACKS
	var pool: Array = src.get(degree, src.get("reussite", []))
	if pool.is_empty():
		pool = RESO_FALLBACKS["reussite"]
	# Anti-générique (QA captures 2026-06-30 : même fallback « partiel » servi 2× mot pour mot dans une
	# run) : mémoire intra-run des variantes servies par (degré, pool) — on ne repioche que parmi les
	# AUTRES ; pool épuisé → RAZ. « partiel » = ~47 % des issues, la répétition se voyait vite.
	var key: String = degree + ("|L" if strong else "|S")
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
	var reg_map: Dictionary = {
		"Social": "trouva les mots", "Offensif": "agit de tout son corps",
		"Mystique": "vit ce qui se cachait", "Défensif": "tint bon sans céder", "Corrompu": "appela l'ombre",
	}
	var regs: Array = []
	for c in played_cards:
		# duck-typing (PAS `is MerlinCard`) : évite une dépendance de classe sur MerlinCard qui cassait le
		# chargement de merlin_scenario (autoload + preload soak) → soak 0/200. v10.20.1 fix.
		if c is Object and c.has_method("archetype"):
			var r: String = str(reg_map.get(c.archetype(), ""))
			if r != "" and not regs.has(r):
				regs.append(r)
	var action: String = " et ".join(PackedStringArray(regs)) if regs.size() > 0 else "agit"
	var result_map: Dictionary = {
		"echec": "mais la foret resista", "partiel": "et n'obtint qu'a demi, en laissant un prix",
		"reussite": "et la voie s'ouvrit", "eclatante": "et tout ceda d'un coup",
	}
	var result: String = str(result_map.get(degree, "et la voie s'ouvrit"))
	# Gist SPÉCIFIQUE (consommé « Juste avant, … » par le prompt d'issue du beat suivant).
	_run_thread["last_gist"] = "le Voyageur %s %s" % [action, result]
	# PONT de transition (degré) prepend à la SITUATION suivante (procédurale) → enchaînement, plus de saut.
	var bridge_map: Dictionary = {
		"echec": "Le revers dans le dos, le Voyageur ne renonca pas et s'enfonca plus loin.",
		"partiel": "Le prix encore sur les epaules, le Voyageur reprit le sentier.",
		"reussite": "Sa voie ouverte, le Voyageur s'enfonca plus avant.",
		"eclatante": "Porte par son elan, le Voyageur poursuivit, sur de lui.",
	}
	_run_thread["bridge"] = str(bridge_map.get(degree, "Le Voyageur poursuivit sa route."))


# A4 : helpers de prose (_clean_prose, _strip_scene_echo, _split_sentences, _sig_words,
# _echo_ratio, _first_sentence, _norm, _parse_arc, _clean_selection) déplacés VERBATIM dans
# MerlinProse (statique 100% pur, renommés sans underscore) — testables hors-arbre.


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


func fallback_epilogue(end_type: String) -> String:
	# Voix MERLIN (user 2026-05-29) — utilisé si le LLM échoue/timeout ; doit tenir seul.
	match end_type:
		"mort": return "Tu pars dans la mousse, mon Voyageur. La forêt se referme sur toi comme une paupière — sans rancune, juste fatiguée de te voir. Mais un murmure se réveille toujours, mon ami. Je veille."
		"corrompu": return "Tu cesses de lutter, Voyageur, et c'est presque doux — je l'ai vu cent fois. La forêt t'accueille parmi les siens ; quelque part déjà, un autre marche en t'entendant. Je suis désolé. Et un peu fier, je l'admets."
		_: return "Tu franchis le dernier seuil, Voyageur. Au loin brille un éclat qui pourrait être le Graal — ou ton reflet dans tes yeux fatigués, je ne saurais dire. La forêt te laisse repartir, pour cette fois. Reviens-moi, mon ami."


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
