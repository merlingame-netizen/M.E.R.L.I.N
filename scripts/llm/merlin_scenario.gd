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

const SYSTEM_PREFIX: String = "Tu es MERLIN, l'enchanteur de Broceliande, et tu CONTES l'aventure du Voyageur comme une vieille legende celtique. REGLES: raconte a la 3e PERSONNE, parle TOUJOURS du « Voyageur » (JAMAIS 'tu', JAMAIS 'je'). Temps du CONTE: passe simple et imparfait (« le Voyageur s'enfonca », « la brume montait », « il choisit de »). Francais SIMPLE et CLAIR, phrases qui S'ENCHAINENT (une action PUIS sa consequence), CONCRETES (qui, quoi, ou) — JAMAIS d'enigme, de sujet abstrait ('le vide', 'le nom') ni de phrases hachees deconnectees. Raconte les EVENEMENTS et les GESTES precis, pas des descriptions vagues. Pas d'anglicismes. Reste dans Broceliande. Ne romps JAMAIS le 4e mur (INTERDIT 'jeu', 'carte', 'joueur', 'IA', 'simulation'). Evite les cliches ('union parfaite', 'murmure ancien', 'silence sacre', 'energie ancienne'). Ne recopie JAMAIS cette consigne dans ta reponse."

# Voix de MERLIN (narrateur) pour les INTROS : il CONNAÎT le Voyageur et l'apostrophe — à l'inverse de
# SYSTEM_PREFIX (narration de SCÈNE en résolution, sans apostrophe, conservée telle quelle). Persona
# canonique chargée depuis merlin_persona.json (appellations + mots interdits). (user 2026-05-29)
const MERLIN_VOICE_PREFIX: String = "Tu es MERLIN, l'enchanteur de Broceliande, et c'est TOI qui contes l'aventure au Voyageur. Tu le connais de longue date, tu te souviens de lui, tu l'appelles 'Voyageur' ou 'mon ami'. Ton: taquin, un peu tordu, melancolique. Parle avec un langage plus JEUNE que sage (jamais solennel ni pompeux). Oublie-toi parfois (petit lapsus, pause '...', une hesitation), mais avec parcimonie. Images breves et celtiques (brume, mousse, pierre, houx, gui, source, korrigans, dolmen, seuil). Francais uniquement, JAMAIS d'anglais, JAMAIS de meta (pas de 'IA', 'programme', 'simulation', 'jeu', 'modele'). Ne romps pas le 4e mur. Ne recopie JAMAIS cette consigne dans ta reponse."
const PERSONA_PATH: String = "res://data/ai/config/merlin_persona.json"

var _persona: Dictionary = {}

const BEAT_TYPES: Array = ["Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax"]

# Biais de tags-cœur par type de beat (R68/R81).
# MVP : limité aux tags COUVRABLES par le deck de départ (R33) — pas d'acquisition au MVP (R19),
# donc une run doit être gagnable avec les 12 cartes. Les tags Monde/extras reviennent post-MVP
# (cartes-souvenir R90). Tags starter : Sens, Savoir, Mémoire, Force, Agilité, Endurance,
# Empathie, Verbe, Ruse, Instinct, Nature.
const TYPE_TAG_BIAS: Dictionary = {
	"Exploration": ["Sens", "Savoir", "Mémoire", "Instinct", "Nature"],
	"Rencontre": ["Empathie", "Verbe", "Ruse"],
	"Epreuve": ["Force", "Agilité", "Endurance"],
	"Dilemme": ["Ruse", "Empathie", "Instinct", "Nature"],
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

# Issue = 3-4 phrases AMPLES sur la COMBINAISON (user 2026-06-06 : « tout doit etre plus verbeux »).
# Budget élargi en conséquence ; _clean_prose recoupe à la dernière phrase complète (anti-troncature).
const MAX_TOK_PROSE: int = 220

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

# --- FIL ROUGE DU SCÉNARIO (continuité inter-beats, user 2026-06-06) ---
# Capturé au skeleton (titre + pitch = enjeu SPÉCIFIQUE du scénario), enrichi à chaque beat
# résolu (last_gist = résultat du beat précédent). Injecté dans le prompt d'issue pour que la
# prose (a) reste ancrée dans CE scénario et (b) enchaîne sur le beat d'avant — fini les beats
# orphelins « sans queue ni tête ». RAZ à chaque build_skeleton (= nouveau run).
var _run_thread: Dictionary = {"title": "", "pitch": "", "last_gist": ""}


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
	var p: String = MERLIN_VOICE_PREFIX
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


# --- 1) SÉLECTION : 3 scénarios (titre + pitch) — voix MERLIN (user 2026-05-29) ---
func generate_selection() -> Array:
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		# Le pitch reste un IMPERATIF tutoye SANS appellation (le wrapper Merlin de build_intro
		# l'apostrophe ensuite — eviter le double 'Voyageur' empile).
		var usr: String = "En tant que MERLIN, propose 3 aventures au Voyageur dans Broceliande. Reponds UNIQUEMENT en JSON: [{\"title\":\"...\",\"pitch\":\"...\"},{...},{...}]. title = court et evocateur. pitch = UNE seule phrase d'appel a l'aventure, imperatif tutoye SANS dire 'Voyageur' (ex: 'Infiltre le marche aux noms voles.', 'Poursuis le gobelin jusque dans la foret.', 'Va sonder la source qui ne ment pas.'). Varie les tons (enigmatique, taquin, sombre, intrigant)."
		var res: Dictionary = await mn.generate(_voice_prefix(), usr, {"creative": true, "max_tokens": 220, "label": "sélection (Merlin)"})
		if not res.has("error"):
			var arr: Array = MerlinJson.extract_array(str(res.get("text", "")))
			var clean: Array = _clean_selection(arr)
			if clean.size() >= 3:
				return clean.slice(0, 3)
	return SEL_FALLBACK.duplicate(true)


func _clean_selection(arr: Array) -> Array:
	var out: Array = []
	for item in arr:
		if item is Dictionary and item.has("title") and item.has("pitch"):
			var t: String = str(item["title"]).strip_edges()
			var p: String = str(item["pitch"]).strip_edges()
			if t.length() >= 2 and p.length() >= 5:
				out.append({"title": t, "pitch": p})
	return out


# --- 2) SQUELETTE : structure 5 beats (CODE). INSTANTANÉ — le pitch EST le synopsis. ---
# (L'ancien appel LLM « synopsis » coûtait ~58s pour un texte jamais affiché dans la boucle.)
func build_skeleton(title: String, pitch: String) -> Dictionary:
	# Fil rouge : RAZ + capture de l'enjeu spécifique (titre + pitch) pour toute la run.
	# arc = 5 situations LIÉES qui racontent UNE histoire (user 2026-06-07 : « décousu, ça doit se
	# suivre »). On pose un arc fallback cohérent INSTANTANÉ ; prepare_arc tente un arc LLM spécifique.
	var fb: Dictionary = _fallback_arc()
	_run_thread = {"title": title, "pitch": pitch, "last_gist": "", "arc": fb["arc"], "arc_tags": fb["tags"], "arc_locked": false}
	var beats: Array = []
	var diffs: Array = [1, 2, 2, 2, 3]
	for i in BEAT_TYPES.size():
		beats.append({"n": i + 1, "type": BEAT_TYPES[i], "difficulte": diffs[i]})
	return {"title": title, "pitch": pitch, "synopsis": pitch, "beats": beats, "total": beats.size()}


# --- 2bis) INTRO DE QUÊTE (pop-up à accepter) : développement complet + objectif. ---
# Procédural INSTANTANÉ (le pop-up s'ouvre sans attente) ; narrate_intro enrichit en fond.
# C'est MERLIN qui conte : il connaît le Voyageur et l'apostrophe (user 2026-05-29).
const _INTRO_WRAPPERS: Array = [
	"Ah, te revoilà, Voyageur. Ce sentier-là, je le connais — il ne mène plus qu'en avant, désormais. Ce que tu cherches t'attend au bout ; ce que tu crains aussi, je ne vais pas te mentir. Avance, mon ami : je marche entre les lignes, à ton côté.",
	"Tiens, mon Voyageur. La brume s'est écartée juste pour toi — ou pour me jouer un tour, avec elle on ne sait jamais. Le sentier se referme dans ton dos ; devant, ce que tu cherches et ce que tu crains, logés à la même enseigne. Allons. Je te suis, ou je te précède, l'un des deux.",
	"Écoute, Voyageur. Le bois a choisi de te laisser entrer — c'est rare, savoure. Ce que tu cherches t'attend au bout du sentier ; ce que tu crains aussi, mais ça, tu le savais déjà. Avance d'un pas tranquille, mon ami. Je veille. Enfin... je crois que je veille.",
]


func build_intro(scenario: Dictionary) -> Dictionary:
	var title: String = str(scenario.get("title", "l'aventure"))
	var pitch: String = str(scenario.get("pitch", ""))
	var wrap: String = str(_INTRO_WRAPPERS[_rng.randi_range(0, _INTRO_WRAPPERS.size() - 1)])
	var mem: String = _build_memory_hint()
	if mem != "":
		wrap += "\n\n(Et je me souviens, va : %s. On ne se refait pas, Voyageur.)" % mem
	var intro: String = ("%s\n\n%s" % [pitch, wrap]) if pitch.strip_edges() != "" else wrap
	# Objectif spécifique : on réutilise l'accroche-action du pitch (déjà un impératif concret).
	var p: String = pitch.strip_edges().trim_suffix(".")
	var objectif: String = ("%s — et revenir entier des cinq épreuves du sentier." % p) if p != "" else ("Mener « %s » à son terme, et revenir entier des cinq épreuves." % title)
	return {"intro": intro.strip_edges(), "objectif": objectif}


func narrate_intro(scenario: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var mem: String = _build_memory_hint()
	var mem_line: String = ("\nSouviens-toi du Voyageur : %s." % mem) if mem != "" else ""
	var usr: String = "Quete proposee au Voyageur: \"%s\" — %s%s\nEn tant que MERLIN qui conte une vieille legende, raconte en 3 a 4 phrases la LEGENDE derriere cette quete a Broceliande : ce qu'on raconte du lieu, ce qui s'y serait perdu ou cache, le danger qui y rode. Puis annonce que le Voyageur s'y engagea. COMMENCE en apostrophant le Voyageur (« Ecoute, Voyageur » ou « Approche, Voyageur »), puis bascule au recit. Francais, images celtiques concretes, pas d'anglicismes, pas de 4e mur. Termine sur une phrase complete." % [title, pitch, mem_line]
	var r: Dictionary = await mn.generate(_voice_prefix(), usr, {"creative": true, "max_tokens": 120, "label": "intro de quête (Merlin)"})
	if r.has("error"):
		return ""
	var s: String = _clean_prose(str(r.get("text", "")).strip_edges())
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
func narrate_opening(scenario: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var title: String = str(scenario.get("title", ""))
	var pitch: String = str(scenario.get("pitch", ""))
	var usr: String = ("Ouvre l'aventure « %s » a Broceliande (accroche : %s). Conte 3 a 4 phrases qui LANCENT l'histoire, a la 3e PERSONNE (« le Voyageur ») au temps du CONTE : plante le decor et l'atmosphere, fais sentir l'enjeu, finis sur ce qui le pousse au premier pas. Images celtiques concretes, SANS remplissage, pas de 4e mur. Commence l'histoire (ne la resume pas) et termine sur une phrase complete.") % [title, pitch]
	var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": MAX_TOK_PROSE, "label": "ouverture (histoire)"})
	if r.has("error"):
		return ""
	var s: String = _clean_prose(str(r.get("text", "")).strip_edges())
	return s if s.length() >= 10 else ""


# --- 3) SITUATION : le CODE choisit required_tags + une narration procédurale (INSTANT) ;
#         le LLM réécrit la narration en arrière-plan (tags STABLES). ---
func build_situation(beat: Dictionary) -> Dictionary:
	var btype: String = str(beat.get("type", "Exploration"))
	var diff: int = int(beat.get("difficulte", 1))
	# La situation ET ses tags requis viennent du MÊME index de l'arc pré-établi → scène ⇄ tags alignés
	# (user 2026-06-07 : « les tags ne correspondent pas à la scène »). Fallback générique si absent.
	# On VERROUILLE l'arc dès la 1re consommation → prepare_arc ne swappera plus (jamais 2 histoires mêlées).
	var idx: int = int(beat.get("n", 1)) - 1
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
	_run_thread["arc_locked"] = true
	return {
		"narration": narration,
		"required_tags": required,
		"type": btype,
		"difficulte": diff,
		"n": int(beat.get("n", 0)),
		"total": BEAT_TYPES.size(),
		"title": str(_run_thread.get("title", "")),
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


# Cue d'action par tag : oriente la scène générée vers CE que la force exige (alignement scène⇄tags).
const TAG_CUE: Dictionary = {
	"Sens": "voir, percevoir, remarquer un detail cache",
	"Savoir": "comprendre, deduire, reconnaitre un savoir ancien",
	"Mémoire": "se souvenir, lire le passe d'un lieu",
	"Force": "pousser, forcer, soulever ou briser",
	"Agilité": "se faufiler, esquiver, garder l'equilibre",
	"Endurance": "tenir bon, resister, encaisser sans ceder",
	"Empathie": "apaiser un etre, gagner sa confiance",
	"Verbe": "parler, convaincre, nommer",
	"Ruse": "tromper, detourner, trouver le point faible",
	"Instinct": "sentir le danger, suivre son intuition",
	"Nature": "parler aux betes et aux plantes, lire la foret",
}


# Arc LLM : 5 étapes liées, CHACUNE construite autour de ses 2 tags requis (req_tags) → la scène
# DEMANDE ces forces (scène ⇄ tags ⇄ cartes alignés). [] si moteur KO/format inattendu.
func narrate_arc(scenario: Dictionary, req_tags: Array) -> Array:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return []
	var title: String = str(scenario.get("title", "")).strip_edges()
	var pitch: String = str(scenario.get("pitch", "")).strip_edges()
	var roles: Array = [
		"arrivee : le Voyageur entre dans le lieu et DECOUVRE l'enjeu de la quete",
		"une rencontre (un etre, une voix) qui lui APPREND un bout de legende sur le but a atteindre",
		"un obstacle physique sur le chemin du but",
		"un choix a faire qui engage la suite",
		"la confrontation finale qui RESOUT la quete : le Voyageur atteint, obtient ou affronte ce que « %s » promet" % title,
	]
	var steps: String = ""
	for i in 5:
		var pair: Array = (req_tags[i] as Array) if (i < req_tags.size() and req_tags[i] is Array) else []
		var cues: PackedStringArray = []
		for t in pair:
			cues.append(str(TAG_CUE.get(str(t), str(t))))
		var cue_txt: String = " ET ".join(cues) if cues.size() > 0 else "agir"
		steps += "\nETAPE %d = %s ; ecris une scene ou il faut %s (c'est CE que le Voyageur devra faire)." % [i + 1, str(roles[i]), cue_txt]
	var usr: String = ("Conte une aventure en 5 ETAPES qui S'ENCHAINENT (chaque etape decoule de la precedente, une seule histoire suivie) pour la quete « %s » (%s) a Broceliande. 3e PERSONNE (« le Voyageur »), temps du CONTE (passe simple / imparfait)." % [title, pitch]) + steps + "\nChaque etape = 2 a 3 phrases CONCRETES (qui, quoi, ou), SANS abstraction, et FINIT sur l'instant ou le Voyageur doit agir (« Que decida le Voyageur ? »).\nEXEMPLE de MANIERE (pas le contenu) :\n1. Le Voyageur s'enfonca sous les fougeres ; le sous-bois s'obscurcit, et l'on peinait a voir. Que decida le Voyageur ?\n2. Au detour d'un tronc, le Voyageur croisa une creature blessee, paisible, allongee sur la mousse. Il se demandait que faire.\nFormat STRICT : une etape par ligne, prefixee « 1. » a « 5. », rien d'autre."
	var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 340, "label": "arc narratif (5 étapes)"})
	if r.has("error"):
		return []
	return _parse_arc(str(r.get("text", "")))


# Extrait 5 étapes d'une réponse numérotée (« 1. … » … « 5. … »), sans regex. [] si format inattendu.
func _parse_arc(text: String) -> Array:
	var out: Array = []
	for raw_line in text.split("\n"):
		var line: String = str(raw_line).strip_edges()
		if line.length() < 3:
			continue
		if not (line[0] >= "1" and line[0] <= "9"):
			continue  # une étape DOIT commencer par son numéro
		var i: int = 1
		while i < line.length() and line[i] in [".", ")", "-", ":", " ", "\t"]:
			i += 1
		var cleaned: String = _clean_prose(line.substr(i).strip_edges())
		if cleaned.length() >= 12:
			out.append(cleaned)
	return out.slice(0, 5) if out.size() >= 5 else []


# Lance la génération de l'arc en arrière-plan (fire-and-forget). Swappe l'arc fallback par l'arc LLM
# SEULEMENT si aucun beat n'a encore été présenté (arc_locked == false) → UNE seule histoire par run.
func prepare_arc(scenario: Dictionary) -> void:
	var title: String = str(scenario.get("title", ""))  # garde anti-race : ne swappe que si TOUJOURS ce scénario
	# Pré-pick les 2 tags requis par beat AVANT la génération → la scène est écrite AUTOUR (alignement),
	# et build_situation utilise ces mêmes tags pour la couverture. (user 2026-06-07 #1)
	var beats: Array = scenario.get("beats", [])
	var picked: Array = []
	for b in beats:
		picked.append(_pick_tags(str(b.get("type", "Exploration")), int(b.get("difficulte", 1))))
	if picked.size() != 5:
		return
	var arc: Array = await narrate_arc(scenario, picked)
	if arc.size() == 5 and not bool(_run_thread.get("arc_locked", false)) and str(_run_thread.get("title", "")) == title:
		_run_thread["arc"] = arc
		_run_thread["arc_tags"] = picked


# LLM réservé aux MOMENTS FORTS (Climax ou réussite éclatante) → réduit les rafales d'appels
# séquentiels qui stallent le moteur natif (générations en série). Ailleurs : procédural seul. (user 2026-05-29)
func is_strong_moment(situ_type: String, degree: String) -> bool:
	return situ_type == "Climax" or degree == "eclatante"


# --- 4) RÉSOLUTION : le code a calculé le degré (affiné par la synergie de la combinaison) ;
#         le LLM NARRE la COMBINAISON comme UN geste unifié (R63/R105), "" si échec. ---
func narrate_resolution(situation: Dictionary, played_cards: Array, res: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var degree: String = str(res.get("degree", "reussite"))
	var deg_fr: Dictionary = {"echec": "un echec", "partiel": "un succes a un prix", "reussite": "une reussite", "eclatante": "une reussite eclatante"}
	# v10.6 — directive d'ISSUE explicite par degré : la lecture du batch (HTML contrôle) montrait
	# que l'échec se lisait comme un succès. On force le ressenti du résultat. (user 2026-06-06)
	var deg_directive: Dictionary = {
		"echec": "Le geste ECHOUE : la foret RESISTE, repousse ou se referme ; rien n'est obtenu, ou pire quelque chose se retourne contre le Voyageur. MONTRE l'echec par des FAITS concrets (la voie reste fermee, un recul, une perte), ne DIS PAS 'echec'.",
		"partiel": "Demi-succes a un PRIX : quelque chose cede mais incomplet, et une ombre ou un cout suit aussitot. MONTRE-le par des FAITS (on avance un peu, mais quelque chose est pris en echange), ne DIS PAS 'partiel'.",
		"reussite": "REUSSITE franche : le geste porte, la voie s'ouvre, la foret cede. MONTRE-le par des FAITS, ne DIS PAS 'reussite'.",
		"eclatante": "Reussite ECLATANTE au-dela de l'espoir : la voie s'ouvre en grand, la lumiere monte, la foret cede sans resistance. MONTRE-le par des FAITS concrets, ne DIS JAMAIS 'memorable' ni 'reussite'.",
	}
	# v10.6 (user 2026-06-06 : « la combinaison ne s'établit pas dans le scénario ») — on passe le
	# SENS (évocation) de CHAQUE carte du combo de 2, et on demande explicitement de FAIRE SENTIR les
	# DEUX forces à l'œuvre, ancrées dans leurs images concrètes, fondues en un seul geste. Toujours
	# sans NOMMER les cartes (resté la consigne user 2026-05-29). → la prose reflète vraiment le combo.
	# Combo : on COLLECTE les 2 évocations, leurs ARCHETYPES (registre) + les tags joués.
	var evocs: Array = []
	var archs: Array = []
	var played_tags: Dictionary = {}
	for c in played_cards:
		if c is Object and "evocation" in c:
			var ev: String = str(c.evocation).strip_edges()
			if ev != "":
				evocs.append(ev)
		if c is Object and c.has_method("archetype"):
			archs.append(str(c.archetype()))
		if c is Object and "tags" in c:
			for t in c.tags:
				played_tags[str(t)] = true
	# Registre par archetype (user 2026-06-07 : « deux cartes de langage ne doivent pas donner une main
	# posee »). L'issue DOIT rester fidele a la NATURE des cartes → 2 cartes Social = issue VERBALE, etc.
	# Noms COURTS (la légende détaillée est dans la consigne, pas ici) → le modèle ne recopie plus la
	# description « FORCE du corps : il pousse » comme il le faisait. Dédupliqués (2 cartes meme registre = 1).
	var arch_reg: Dictionary = {
		"Social": "PAROLE", "Offensif": "FORCE", "Mystique": "PERCEPTION",
		"Défensif": "PROTECTION", "Corrompu": "OMBRE",
	}
	var registres: Array = []
	for a in archs:
		var r: String = str(arch_reg.get(a, "PERCEPTION"))
		if not registres.has(r):
			registres.append(r)
	var reg_hint: String = ""
	if registres.size() >= 1:
		reg_hint = " Registre attendu de l'action : " + " + ".join(PackedStringArray(registres)) + "."
	# Fusion : les évocations sont des DONNEES à TRADUIRE en gestes DU BON REGISTRE, pas une phrase citable.
	var combo: String = ""
	if evocs.size() >= 2:
		combo = "DEUX forces a fondre en UNE seule action concrete, DANS LEUR REGISTRE (TRADUIS-les, ne RECOPIE pas) -- force A = %s -- force B = %s" % [str(evocs[0]), str(evocs[1])]
	elif evocs.size() == 1:
		combo = "Une force a traduire en geste concret de son registre (ne recopie pas) = %s" % str(evocs[0])
	# Couverture (user 2026-06-06) : adéquation cartes ↔ tags requis. On décrit l'AJUSTEMENT
	# (les bonnes clés / les mauvaises), JAMAIS l'issue — c'est deg_directive qui POSSÈDE l'issue.
	# Évite la contradiction « rien obtenu » vs un degré de succès, ex. partiel à 0/2 (review MEDIUM).
	var required: Array = situation.get("required_tags", [])
	var covered: Array = []
	var missed: Array = []
	for t in required:
		if played_tags.has(str(t)):
			covered.append(str(t))
		else:
			missed.append(str(t))
	var cover_hint: String = ""
	if not required.is_empty():
		if missed.is_empty():
			cover_hint = " Les deux forces du Voyageur etaient EXACTEMENT celles que ce lieu reclamait."
		elif not covered.is_empty():
			cover_hint = " L'une des forces du Voyageur etait celle qu'il fallait, l'autre attendue MANQUAIT : la reussite reste INCOMPLETE (un manque, une lenteur, un reste qui suit) — ne la presente JAMAIS comme parfaite."
		else:
			cover_hint = " Aucune des forces du Voyageur n'etait celle que ce lieu reclamait : il repond a cote de ce qui etait demande."
	var syn: int = int(res.get("synergy", 0))
	var syn_hint: String = ""
	if syn > 0:
		syn_hint = " Les deux forces se fondent en un geste fluide."
	elif syn < 0:
		syn_hint = " Les deux forces tirent a hue et a dia (l'issue s'en ressent)."
	# Cohérence + variété (user 2026-06-07, critique passe profonde : toutes les issues finissaient en
	# « le chemin s'ouvre » et ignoraient le type de beat). On passe un FOCUS abstrait par type (sans
	# recopier le décor) → l'issue RÉSOUT ce que le beat posait, et la conclusion varie.
	var type_focus: Dictionary = {
		"Exploration": "ce qui etait cache se revele au Voyageur (ou se derobe a lui)",
		"Rencontre": "l'etre ou la voix d'en face reagit : il cede, se lie au Voyageur, ou se retourne contre lui",
		"Epreuve": "l'obstacle concret (ronces, pente, pierre) est franchi ou resiste au Voyageur",
		"Dilemme": "le Voyageur a TRANCHE : montre la voie qu'il choisit ET le prix immediat (ce qu'il gagne et ce qu'il abandonne), pas une simple ouverture de chemin",
		"Climax": "c'est le MOMENT DECISIF du sentier : l'issue pese lourd et marque une vraie BASCULE (triomphe ou chute), jamais une simple avancee de routine",
	}
	var ftype: String = str(situation.get("type", ""))
	var focus_hint: String = ""
	if type_focus.has(ftype):
		focus_hint = " Ce moment est une %s : l'issue doit faire avancer CELA (%s), pas se reduire a « le chemin s'ouvre »." % [ftype, str(type_focus[ftype])]
	# Fil rouge (user 2026-06-06) : identité du scénario (TITRE seul — le pitch se faisait recopier en
	# tête de prose, régression observée au probe) + position du beat + enchaînement avec le précédent.
	var ctx: String = ""
	var rt_title: String = str(_run_thread.get("title", "")).strip_edges()
	if rt_title != "":
		ctx += "Aventure : « %s »\n" % rt_title
	# (Position du beat retirée du prompt : le modèle la narrait — « Le moment cinq du sentier arriva ».
	#  Le type de beat passe déjà par focus_hint ; la continuité par last_gist.)
	var prev: String = str(_run_thread.get("last_gist", "")).strip_edges()
	if prev != "":
		ctx += "Juste avant, %s enchaine sans rompre le fil.\n" % prev
	# Longueur VARIABLE (user 2026-06-06 : « plus variable sur la longueur … quelquefois plus long
	# selon le déroulé ») : ample aux MOMENTS FORTS (Climax ou réussite éclatante), brève sinon.
	var long_form: bool = is_strong_moment(str(situation.get("type", "")), degree)
	var phrase_target: String = "4 a 5 phrases" if long_form else "2 a 3 phrases"
	var tok_budget: int = 260 if long_form else 150
	# v10.17 (user 2026-06-07) : on PASSE la situation + un EXEMPLE gold (few-shot in-context) pour que
	# l'issue RESOLVE la situation precise (pas un generique « le chemin s'ouvre ») en fondant les 2
	# forces, calee sur la prose cible. _strip_scene_echo reste le filet anti-recopiage.
	var situ_txt: String = str(situation.get("narration", "")).strip_edges()
	var ex: String = "EXEMPLE (imite la MANIERE, pas le contenu) — Situation: une dalle de pierre barrait le gue, le courant poussait fort. Forces fondues: « le corps plie sans rompre » + « la poigne qui ne tremble pas ». Issue (reussite): Le Voyageur choisit de caler ses pieds dans la vase et de pousser sans rompre. La dalle racla, bascula et libera le passage ; il franchit le gue, trempe mais debout."
	var usr: String = "%sCE QUI SE PASSAIT : %s\n%s%s\nISSUE = %s.%s%s%s%s\n%s\nRaconte l'issue en %s, a la 3e PERSONNE et au temps du CONTE (passe simple / imparfait). Ta TOUTE PREMIERE phrase DOIT commencer par « Le Voyageur choisit de » suivi de l'action concrete qui FOND les deux forces dans le registre attendu. (Sens des registres : PAROLE = il parle/convainc/ruse/charme ; FORCE = il agit physiquement, pousse/tient bon ; PERCEPTION = il voit/ressent/parle aux choses ; PROTECTION = il resiste/protege ; OMBRE = il appelle une force trouble a un prix.) Si c'est PAROLE, l'issue est VERBALE, JAMAIS un geste comme 'il pose la main'. TRADUIS les forces en actions ; n'ecris JAMAIS le mot 'registre' ni ces categories en majuscules ; ne CITE JAMAIS les formulations entre guillemets ; n'ecris JAMAIS 'fond deux gestes en un seul'. NE RE-DECRIS PAS la scene (le mur, le chemin, l'etre sont deja connus). PUIS raconte CE QUE CELA CAUSA : la consequence concrete qui RESOUT la situation (l'etre, l'obstacle ou le choix precis). Phrases LIEES et CONCRETES, sujets concrets (jamais 'le vide'/'le nom'). Fais clairement RESSENTIR le resultat (%s). LE RESULTAT PRIME sur les cartes : pour un echec, l'action est TENTEE mais elle ECHOUE (la porte reste close, l'obstacle resiste) ; pour un partiel, elle ne reussit qu'a demi avec un prix — ne narre JAMAIS un succes net si l'issue n'en est pas un, meme si une carte evoque la reussite. Varie la fin (pas toujours 'le chemin s'ouvre'). Pas de liste ni de chiffres. Termine sur une phrase complete." % [ctx, situ_txt, combo, reg_hint, deg_fr.get(degree, "une reussite"), str(deg_directive.get(degree, "")), cover_hint, syn_hint, focus_hint, ex, phrase_target, deg_fr.get(degree, "une reussite")]
	var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": tok_budget, "label": "issue (combinaison)"})
	if r.has("error"):
		return ""
	var s: String = _strip_scene_echo(_clean_prose(str(r.get("text", "")).strip_edges()), str(situation.get("narration", "")))
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
	# Moteur single-flight : on ne LANCE une pré-génération QUE si le moteur est libre. Sinon on ne
	# thrash pas (sans ça, des combos abandonnées occuperaient le moteur ~40s) — take_resolution
	# annulera la gen périmée et générera la combo finale au clic Résolution.
	var mn: Node = _mn()
	if mn == null or not mn.is_ready() or mn.is_busy():
		return
	_reso_epoch += 1
	var epoch: int = _reso_epoch
	_reso_sig = sig
	_reso_state = "running"
	var prose: String = await narrate_resolution(situation, played_cards, res)
	if epoch != _reso_epoch:
		# Périmé (seul invalidate_resolution bumpe l'epoch pendant notre await — le guard is_busy
		# empêche tout prefetch concurrent tant qu'on tient le moteur). Fix review HIGH 2026-06-06 :
		# reset state, sinon il reste « running » sur une sig abandonnée → un re-prefetch de la même
		# combo se croirait en vol (hung) et ne relancerait jamais.
		_reso_state = "idle"
		return
	if prose.length() >= 10:
		_reso_cache[sig] = prose
		_reso_state = "ready"
	else:
		_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)


# Récupère l'issue LLM au clic Résolution. Cache-hit instantané si la pré-génération a fini ;
# sinon attend la génération en vol (bornée par le timeout moteur natif) ; sinon génère maintenant.
# Renvoie "" si le moteur a vraiment échoué → l'appelant retombe sur le procédural (dernier recours).
func take_resolution(situation: Dictionary, played_cards: Array, res: Dictionary) -> String:
	var sig: String = _reso_signature(played_cards, res)
	if _reso_cache.has(sig):
		_remember_outcome(res)
		return str(_reso_cache[sig])
	# Génération de CETTE combo en vol ? On l'attend par polling (borné ~95s > GEN_TIMEOUT moteur).
	if _reso_sig == sig and _reso_state == "running":
		var deadline_ms: int = Time.get_ticks_msec() + 95000
		while _reso_state == "running" and Time.get_ticks_msec() < deadline_ms:
			await get_tree().process_frame
		if _reso_cache.has(sig):
			_remember_outcome(res)
			return str(_reso_cache[sig])
	# Pas de cache. Une gen PÉRIMÉE (autre combo) peut occuper le moteur single-flight → on l'annule
	# et on attend sa libération avant de générer la combo finale. Garantit "toujours LLM".
	# cancel_generation() signale la boucle de décode native (flag vérifié entre tokens, ~1/s) → la
	# libération arrive en ~1-2s ; 8s de marge couvre un drain lent sans figer le resolve. (review MEDIUM)
	var mn: Node = _mn()
	if mn != null and mn.is_busy():
		mn.cancel()
		var free_dl: int = Time.get_ticks_msec() + 8000
		while mn.is_busy() and Time.get_ticks_msec() < free_dl:
			await get_tree().process_frame
	# Génère maintenant et attend (le moteur devrait être libre).
	var prose: String = await narrate_resolution(situation, played_cards, res)
	if prose.length() >= 10:
		_reso_cache[sig] = prose
		_remember_outcome(res)
		return prose
	_remember_outcome(res)  # outcome réel même si la prose finit en procédural (continuité du beat suivant)
	return ""  # moteur KO → fallback procédural côté appelant


# Vrai si l'issue de cette combo est DÉJÀ en cache (pré-génération finie) → take_resolution sera
# instantané. L'appelant évite ainsi le flicker de l'overlay « Merlin assemble… » (review MEDIUM).
func is_resolution_ready(played_cards: Array, res: Dictionary) -> bool:
	return _reso_cache.has(_reso_signature(played_cards, res))


# Vide le cache d'issue à chaque nouveau beat (merlin_game._present_current_beat) : les ids de cartes
# se répètent entre beats (deck starter), sans ce reset une combo identique réafficherait la prose
# d'un beat antérieur. Bumpe l'epoch → toute pré-génération en vol devient périmée.
func invalidate_resolution() -> void:
	_reso_cache.clear()
	_reso_sig = ""
	_reso_state = "idle"
	_reso_epoch += 1


# Procédural de résolution (INSTANT, déterministe). Public : l'appelant l'affiche immédiatement.
func fallback_resolution(degree: String, situ_type: String = "") -> String:
	# Longueur VARIABLE même en procédural (user 2026-06-06) : aux MOMENTS FORTS (Climax / éclatante)
	# on sert le pool LONG → « plus long au climax » s'affiche EN JEU même quand l'issue LLM longue
	# timeoute (cas fréquent à ~1 tok/s). Sinon pool de routine (plus court).
	var src: Dictionary = RESO_FALLBACKS_LONG if is_strong_moment(situ_type, degree) else RESO_FALLBACKS
	var pool: Array = src.get(degree, src.get("reussite", []))
	if pool.is_empty():
		pool = RESO_FALLBACKS["reussite"]
	return str(pool[_rng.randi_range(0, pool.size() - 1)])


# Mémorise le RÉSULTAT du beat courant dans le fil rouge → le prompt d'issue du beat SUIVANT
# enchaîne dessus (continuité). Le degré est réel même si la prose finit en procédural.
func _remember_outcome(res: Dictionary) -> void:
	var degree: String = str(res.get("degree", "reussite"))
	var gist: Dictionary = {
		"echec": "le geste a echoue et la foret a repris le dessus ;",
		"partiel": "le geste n'a porte qu'a demi, en laissant un prix ;",
		"reussite": "le geste a porte et la voie s'est ouverte ;",
		"eclatante": "le geste a triomphe, eclatant et net ;",
	}
	_run_thread["last_gist"] = str(gist.get(degree, "le geste a porte ;"))


# Coupe la prose à la dernière phrase COMPLÈTE : évite les troncatures mid-mot (« se dess… »)
# quand le modèle atteint le plafond de tokens, qui donnaient l'impression d'un blocage (user 2026-05-28).
func _clean_prose(s: String) -> String:
	var t: String = s.strip_edges()
	if t.is_empty():
		return t
	var last: String = t.right(1)
	if last == "." or last == "!" or last == "?" or last == "…" or last == "»":
		return t
	var cut: int = -1
	for p in [".", "!", "?", "…", "»"]:
		cut = maxi(cut, t.rfind(p))
	if cut >= 10:  # seuil : ne couper que si on conserve une vraie phrase (≥10 car.), pas un fragment
		return t.substr(0, cut + 1).strip_edges()
	return t  # aucune ponctuation de fin exploitable → garder tel quel (rare)


# Filet anti-écho : si la prose LLM démarre en recopiant une phrase de la situation (déjà
# affichée à l'écran), on retire ces phrases. Le prompt ne passe plus le décor — ceci garde le coup.
func _strip_scene_echo(prose: String, situation: String) -> String:
	if prose.is_empty() or situation.is_empty():
		return prose
	var situ_words: Dictionary = _sig_words(situation)
	# Parmi les 3 PREMIERES phrases, retire celles qui CLONENT la situation (même paraphrasées, même
	# precedees d'une phrase de transition). Au-dela, on garde tout (le corps de l'issue). Robuste aux
	# paraphrases via recouvrement de mots significatifs (seuil 0.5).
	var sentences: Array = _split_sentences(prose)
	var kept: Array = []
	for i in sentences.size():
		var s: String = str(sentences[i])
		if i < 3 and s.strip_edges().length() >= 12 and _echo_ratio(s, situ_words) >= 0.5:
			continue  # clone de la situation → retiré
		kept.append(s)
	var p: String = " ".join(kept).strip_edges()
	# nettoie une ponctuation orpheline en tête (ex. « » » laissé par une phrase recopiée retirée)
	while p.length() > 0 and (" »\"',;:.!?-—".find(p[0]) != -1):
		p = p.substr(1)
	return p.strip_edges()


# Découpe un texte en phrases (sur . ! ? …), en conservant la ponctuation finale.
func _split_sentences(t: String) -> Array:
	var out: Array = []
	var cur: String = ""
	for i in t.length():
		var ch: String = t[i]
		cur += ch
		if ch == "." or ch == "!" or ch == "?" or ch == "…":
			out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges().length() > 0:
		out.append(cur.strip_edges())
	return out


# Ensemble des mots significatifs (≥4 lettres) d'un texte, normalisés (minuscules, ponctuation → espace).
func _sig_words(t: String) -> Dictionary:
	var out: Dictionary = {}
	for w in _norm(t).split(" ", false):
		if w.length() >= 4:
			out[w] = true
	return out


# Proportion des mots significatifs d'une phrase présents dans la situation (0.0–1.0).
func _echo_ratio(sentence: String, situ_words: Dictionary) -> float:
	var sig: int = 0
	var hit: int = 0
	for w in _norm(sentence).split(" ", false):
		if w.length() >= 4:
			sig += 1
			if situ_words.has(w):
				hit += 1
	return float(hit) / float(max(sig, 1))


func _first_sentence(t: String) -> String:
	var s: String = t.strip_edges()
	for i in s.length():
		var ch: String = s[i]
		if ch == "." or ch == "!" or ch == "?":
			return s.substr(0, i + 1)
	return s


func _norm(t: String) -> String:
	# minuscules + ponctuation → espace : comparaison par MOTS, robuste aux paraphrases.
	var s: String = t.strip_edges().to_lower()
	var out: String = ""
	for ch in s:
		if ch == " " or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ("àâäéèêëîïôöùûüçñ".find(ch) != -1):
			out += ch
		else:
			out += " "
	return out


# --- 5) ÉPILOGUE (fin de run, R69) : LLM, "" si échec → l'appelant garde le procédural. ---
# Voix MERLIN qui referme l'aventure pour le Voyageur, avec souvenir intra-run câblé (user 2026-05-29).
func narrate_epilogue(end_type: String, _state: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var enj: Dictionary = {
		"accomplissement": "le Voyageur a traverse l'epreuve et entrevoit un fragment du Graal",
		"mort": "le Voyageur a succombe ; la foret l'a repris",
		"corrompu": "la Corruption l'a emporte ; le Voyageur s'est dissous dans la foret",
	}
	var what: String = str(enj.get(end_type, "le voyage s'acheve"))
	var mem: String = _build_memory_hint()
	var mem_line: String = ("\nCe dont tu te souviens du Voyageur : %s." % mem) if mem != "" else ""
	var usr: String = "Fin de l'aventure : %s.%s\nEn tant que MERLIN qui le connaît, conte cet epilogue au Voyageur en 3 phrases : apostrophe-le ('Voyageur' ou 'mon ami'), evoque ce qu'il vient de vivre (ou ce dont tu te souviens), laisse entrevoir une suite. Termine sur une phrase complete." % [what, mem_line]
	var r: Dictionary = await mn.generate(_voice_prefix(), usr, {"creative": true, "max_tokens": 120, "label": "épilogue (Merlin)"})
	if r.has("error"):
		return ""
	var s: String = _clean_prose(str(r.get("text", "")).strip_edges())
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
