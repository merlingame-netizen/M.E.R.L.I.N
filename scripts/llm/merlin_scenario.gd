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

const SYSTEM_PREFIX: String = "Tu es le narrateur de la foret de Broceliande (legende celtique). REGLES: ecris en francais SIMPLE et CLAIR, en phrases qui S'ENCHAINENT — chaque phrase DECOULE de la precedente (une action, PUIS sa consequence), et l'ensemble se lit comme un petit PARAGRAPHE FLUIDE. INTERDIT une liste de phrases hachees, tres courtes et deconnectees les unes des autres (ex INTERDIT: 'Le geste glisse. Les autres tombent. Le vide ne touche rien.'). Mots de tous les jours. Raconte ce qui se passe CONCRETEMENT: le geste precis, ce qu'il provoque, le resultat visible. INTERDIT les sujets abstraits ou symboliques ('le vide', 'le nom', 'le geste') et toute enigme ou metaphore obscure. Ton feerique mais LISIBLE: on comprend l'action du premier coup. Raconte la SCENE et l'EFFET des actes en recit direct. INTERDIT les phrases a tiroir et les images abstraites (ex INTERDIT: 'le silence a une texture', 'l'air goute le souvenir', 'plus vieux que les sentiers', 'comme on oublie un nom'). N'APOSTROPHE JAMAIS le joueur: INTERDIT 'Ah voyageur', 'voyageur', 'mon ami', 'tu dois', et tout commentaire de maitre du jeu. Ne nomme JAMAIS simulation/IA/jeu (pas de 4e mur). Pas d'anglicismes. Reste dans Broceliande. Evite les formules creuses et clichees (INTERDIT: 'union parfaite', 'murmure ancien', 'silence sacre', 'energie ancienne', 'secrets anciens'). Ne recopie JAMAIS une consigne de cette instruction dans ta reponse."

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
	],
	"Rencontre": [
		"Une silhouette sort des arbres et te fixe, sans un mot. Elle attend de voir qui tu es.",
		"Quelque chose te barre la route, immobile. Son regard pèse lourd.",
		"Une voix te salue avant que tu voies personne. Elle connaît déjà ton pas.",
	],
	"Epreuve": [
		"La forêt bloque le passage : ronces, pierres, pente glissante. Rien ne cédera tout seul.",
		"Le chemin se dresse contre toi, hostile. Il faudra forcer pour avancer.",
		"Un vieil obstacle barre la route. Il faudra payer de tes bras ou de ta ruse.",
	],
	"Dilemme": [
		"Deux chemins s'ouvrent. Chacun a un prix, et aucun ne te laissera intact.",
		"Un choix se pose, sans détour. Quoi que tu fasses, la forêt s'en souviendra.",
		"Il faut trancher, là où il n'y a pas de bonne réponse. Ne pas choisir, c'est choisir aussi.",
	],
	"Climax": [
		"L'air se fige. La forêt retient son souffle. Ce qui vient ne se reprendra pas.",
		"Tout se joue ici, maintenant. Les murmures se taisent d'un coup.",
		"Le cœur de la forêt bat sous tes pieds. Ici se décide ce que tu deviens.",
	],
}

const RESO_FALLBACKS: Dictionary = {
	"echec": [
		"Tes deux gestes se mélangent mal et se gênent. La forêt refuse, te repousse, et te voilà plus loin de ton but. Dans l'ombre, quelque chose s'en amuse.",
		"Le mélange sonne faux, et le bois l'entend tout de suite. Ce que tu touches se dérobe, ce que tu tiens t'échappe. Tu repars les mains vides.",
		"Ton geste ne prend pas sur ce lieu. Le sentier se referme, indifférent, et te laisse en arrière. Ce faux pas, il faudra le payer.",
	],
	"partiel": [
		"Tes deux gestes s'unissent, mais de travers. Tu obtiens ce que tu voulais — en en laissant un morceau. Une ombre marche maintenant dans tes pas.",
		"Le geste fusionné n'ouvre la voie qu'à demi. Tu avances quand même, mais quelque chose t'a vu faire. Le prix viendra plus tard.",
		"Tu arraches ton dû, mais un reste te colle à la peau. La voie s'entrouvre, étroite, juste assez pour passer. La forêt n'oublie pas ce que tu as forcé.",
	],
	"reussite": [
		"Tes deux gestes se nouent en un seul, propre et juste. La forêt cède et te laisse avancer d'un pas plus sûr. Cette fois, le sentier ne réclame rien.",
		"Le geste fusionné touche juste du premier coup. Le chemin s'ouvre, sans éclat mais sans dette. Tu passes, entier.",
		"Les deux forces s'accordent, et le sentier te laisse passer. La route se dégage, nette. Tu avances sans rien laisser derrière toi.",
	],
	"eclatante": [
		"Tes deux gestes n'en font plus qu'un, si bien que la forêt elle-même retient son souffle. Le passage s'ouvre en grand, sans résistance. Un instant, tu es plus grand que toi-même.",
		"L'accord est total, et tout le bois le fête en silence. La voie se déroule devant toi comme un tapis, et rien ne te coûte. Pour une fois, la forêt donne plus qu'elle ne prend.",
	],
}

# Fallbacks LONGS (user 2026-06-06) — servis aux MOMENTS FORTS (Climax / éclatante). À ~1 tok/s, l'issue
# LLM longue timeoute souvent en jeu (take_resolution borné ~95s) → sans ces variantes, « plus long au
# climax » ne s'afficherait jamais. Le procédural prend donc le relais EN LONG sur ces moments-là.
const RESO_FALLBACKS_LONG: Dictionary = {
	"echec": [
		"Tes deux gestes s'élancent ensemble, mais au lieu de s'unir ils se brisent. La forêt ne se contente pas de refuser : elle reprend, elle efface, elle te repousse. Quelque chose, dans l'ombre, a vu ta tentative. Tu restes seul au bord, les mains vides.",
		"Le geste se retourne contre toi comme une bête mal tenue. Ce que tu touches se dérobe, ce que tu appelles ne vient pas. Le lieu se referme, lentement, sur ton échec. Tu paieras ce moment, tu le sais déjà.",
	],
	"partiel": [
		"Tes deux gestes portent, mais de travers. Quelque chose cède, quelque chose s'ouvre, et dans le même temps une ombre se glisse dans tes pas. Tu obtiens ce que tu voulais, et tu repars marqué. La forêt a pris autre chose, sans dire quoi.",
		"Le passage s'entrouvre à demi sous ton geste, juste assez pour t'y faufiler. Mais rien ici n'est gratuit : ce que tu forces te coûte un morceau. On t'a vu faire, on ne l'oubliera pas. Tu avances, à moitié vainqueur, à moitié débiteur.",
	],
	"reussite": [
		"Tes deux gestes se nouent enfin en un seul, large et juste, et le lieu cède dans un long soupir. La voie se dénoue devant toi, nette, comme si la forêt avait attendu ce moment. Tu passes, entier, plus sûr de ton pas. Le silence te suit comme un accord rare.",
		"Le geste fusionné touche sa cible du premier coup, et tout le bois l'accuse. Le chemin s'ouvre sans triomphe bruyant mais sans la moindre dette. Rien ne te retient plus. Tu franchis le seuil, et la forêt te laisse aller.",
	],
	"eclatante": [
		"Tes deux gestes n'en font soudain plus qu'un, si bien accordés que la forêt elle-même retient son souffle. Le seuil s'ouvre en grand, sans résistance, et tout au fond, sous les racines, quelque chose d'ancien s'incline. La voie se déroule comme un tapis. Un instant, bref et vertigineux, tu es plus grand que toi-même.",
		"L'accord est total, et le bois entier le fête en silence. Ce que tu viens de faire, peu l'ont fait avant toi. Le chemin devant n'est plus une épreuve mais un cadeau. Tu avances, porté, et derrière toi une voix très douce prononce ton nom.",
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
	_run_thread = {"title": title, "pitch": pitch, "last_gist": ""}
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
	var usr: String = "Quete proposee au Voyageur: \"%s\" — %s%s\nEn tant que MERLIN qui le connaît, conte-lui cette aventure en 3 phrases: salue ou taquine le Voyageur, plante le decor et l'enjeu a Broceliande, finis sur ce qui l'attend. Apostrophe-le ('Voyageur' ou 'mon ami'). Termine sur une phrase complete." % [title, pitch, mem_line]
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
	"À la lisière de Brocéliande s'ouvre un chemin que les cartes ne montrent pas. Les fougères s'écartent devant toi, comme si on t'attendait. Tu fais un pas, et le bois se referme doucement derrière toi.",
	"On parle peu de ce lieu, et toujours à voix basse. Devant toi, le sentier s'enfonce sous les arbres, sombre et silencieux. Ce que tu cherches t'attend au bout ; ce que tu crains aussi.",
	"La brume se lève sur une clairière que tu n'avais pas vue en arrivant. Tout est calme, trop calme, comme avant l'orage. Un premier pas, et la forêt ne te laissera plus repartir.",
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
	var usr: String = ("Ouvre l'aventure « %s » a Broceliande (accroche : %s). Ecris 3 a 4 phrases qui LANCENT l'histoire : plante le decor et l'atmosphere, fais sentir l'enjeu, finis sur ce qui pousse a faire le premier pas. Recit direct au present, sans apostropher le Voyageur, images celtiques concretes, SANS remplissage. Commence l'histoire (ne la resume pas) et termine sur une phrase complete.") % [title, pitch]
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
	var required: Array = _pick_tags(btype, diff)
	return {
		"narration": _fallback_situation(btype, required),
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
	# Combo : on COLLECTE les 2 évocations + les tags joués (UN seul passage, KISS).
	var evocs: Array = []
	var played_tags: Dictionary = {}
	for c in played_cards:
		if c is Object and "evocation" in c:
			var ev: String = str(c.evocation).strip_edges()
			if ev != "":
				evocs.append(ev)
		if c is Object and "tags" in c:
			for t in c.tags:
				played_tags[str(t)] = true
	# Fusion (user 2026-06-07) : les évocations sont données comme UNE matière à fondre, PAS une liste
	# « Force 1 / Force 2 » qui poussait le modèle à décrire les deux cartes l'une après l'autre.
	var combo: String = ""
	if evocs.size() >= 2:
		combo = "Il fond deux gestes en un seul : « %s » et « %s ». DECRIS leur effet FUSIONNE (un seul resultat ne du melange), JAMAIS l'un puis l'autre." % [str(evocs[0]), str(evocs[1])]
	elif evocs.size() == 1:
		combo = "Son geste : « %s »." % str(evocs[0])
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
			cover_hint = " Tes deux forces sont EXACTEMENT celles que ce lieu reclamait."
		elif not covered.is_empty():
			cover_hint = " L'une de tes forces est celle qu'il fallait, l'autre attendue MANQUE : la reussite reste INCOMPLETE (un manque, une lenteur, un reste qui suit) — ne la presente JAMAIS comme parfaite."
		else:
			cover_hint = " Aucune de tes forces n'etait celle que ce lieu reclamait : tu reponds a cote de ce qui etait demande."
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
		"Exploration": "ce qui etait cache se revele a toi (ou se derobe)",
		"Rencontre": "l'etre ou la voix d'en face reagit : il cede, se lie a toi, ou se retourne contre toi",
		"Epreuve": "l'obstacle concret (ronces, pente, pierre) est franchi ou te resiste",
		"Dilemme": "ton choix est tranche et sa consequence tombe aussitot",
		"Climax": "l'enjeu final du sentier bascule, dans un sens ou dans l'autre",
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
	var bn: int = int(situation.get("n", 0))
	if bn > 0:
		ctx += "Moment %d/%d du sentier (%s).\n" % [bn, int(situation.get("total", 5)), str(situation.get("type", ""))]
	var prev: String = str(_run_thread.get("last_gist", "")).strip_edges()
	if prev != "":
		ctx += "Juste avant, %s enchaine sans rompre le fil.\n" % prev
	# Longueur VARIABLE (user 2026-06-06 : « plus variable sur la longueur … quelquefois plus long
	# selon le déroulé ») : ample aux MOMENTS FORTS (Climax ou réussite éclatante), brève sinon.
	var long_form: bool = is_strong_moment(str(situation.get("type", "")), degree)
	var phrase_target: String = "4 a 5 phrases" if long_form else "2 a 3 phrases"
	var tok_budget: int = 260 if long_form else 150
	# Décor PAS passé au prompt (la scène est déjà affichée à l'écran) : le passer poussait le petit
	# modèle à le RECOPIER en ouverture (régression probe 2026-06-06). On démarre direct sur l'action ;
	# _strip_scene_echo reste le filet si le modèle replante quand même la scène. Cartes NON nommées.
	var usr: String = ("%sLe Voyageur agit. %s\nISSUE = %s. %s%s%s%s\nEcris " % [ctx, combo, deg_fr.get(degree, "une reussite"), str(deg_directive.get(degree, "")), cover_hint, syn_hint, focus_hint]) + phrase_target + " (francais) qui S'ENCHAINENT logiquement (cause PUIS consequence), comme un petit paragraphe FLUIDE et JAMAIS des phrases hachees et deconnectees, SANS remplissage. COMMENCE par l'EFFET dans le monde (ce qui change dans la foret, le lieu, ou l'etre en face) ; ne replante NI le decor NI le lieu deja decrits, et ne commence JAMAIS par 'les mains se joignent / se tendent / se melent' ni par une description du corps. Raconte UN SEUL effet FUSIONNE des deux gestes (jamais 'la premiere force... la seconde...', jamais l'un apres l'autre), DEROULE la consequence concrete qui en decoule, ET fais clairement RESSENTIR l'issue. VARIE la conclusion selon le moment, evite de toujours finir par 'le chemin s'ouvre'. Sujets CONCRETS (le Voyageur, la foret, le lieu, l'etre en face), jamais abstraits ('le vide', 'le nom'). Ne nomme pas les cartes, pas de liste, pas de chiffres, recit direct sans apostropher le Voyageur. Termine sur une phrase complete."
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
	var p: String = prose
	var situ_norm: String = _norm(situation)
	var guard: int = 0
	while guard < 2:  # retire au plus 2 phrases d'ouverture qui clonent la scène
		guard += 1
		var fs: String = _first_sentence(p)
		if fs.length() >= 12 and situ_norm.find(_norm(fs)) != -1:
			var rest: String = p.substr(fs.length()).strip_edges()
			if rest.length() >= 10:
				p = rest
				continue
		break
	return p


func _first_sentence(t: String) -> String:
	var s: String = t.strip_edges()
	for i in s.length():
		var ch: String = s[i]
		if ch == "." or ch == "!" or ch == "?":
			return s.substr(0, i + 1)
	return s


func _norm(t: String) -> String:
	return t.strip_edges().to_lower()


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
