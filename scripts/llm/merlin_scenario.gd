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

const SYSTEM_PREFIX: String = "Tu es le narrateur de la foret de Broceliande (legende celtique). REGLES: ecris en francais, ton merveilleux-inquietant (la feerie qui mord), bref et image (2 phrases). Raconte la SCENE et l'EFFET des actes en recit direct. N'APOSTROPHE JAMAIS le joueur: INTERDIT 'Ah voyageur', 'voyageur', 'mon ami', 'tu dois', et tout commentaire de maitre du jeu. Ne nomme JAMAIS simulation/IA/jeu (pas de 4e mur). Pas d'anglicismes. Reste dans Broceliande."

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
	{"title": "Le Marché des Murmures", "pitch": "Infiltrez le marché où l'on troque des noms volés."},
	{"title": "Le Rite sans Fin", "pitch": "Interrompez le rite que nul ne sait plus arrêter."},
	{"title": "La Fontaine qui Rêve", "pitch": "Sondez la source noire où dorment les visages."},
]

# Narration procédurale = le texte VU par défaut (le LLM ≈1 tok/s ne gagne presque jamais la
# course contre la lecture du joueur). Donc 3 variantes/type, tirées au sort → variété cross-run
# (chaque type n'apparaît qu'1 fois par run). Ton « merveilleux-inquiétant » (bible §21).
const SITU_FALLBACKS: Dictionary = {
	"Exploration": [
		"La clairière s'ouvre devant toi, trop calme. Quelque chose t'y attend, qui te connaît déjà.",
		"Le sentier se perd sous les fougères, et le silence a une texture. On t'observe sans se montrer.",
		"Les arbres s'écartent sur un lieu que nulle carte ne nomme. L'air y goûte le souvenir et la cendre.",
	],
	"Rencontre": [
		"Une silhouette se détache des arbres et t'observe sans un mot. Elle attend de voir qui tu es vraiment.",
		"Quelqu'un — ou quelque chose — se tient sur ton chemin, immobile. Son regard pèse plus lourd que le silence.",
		"Une voix te salue avant que tu n'aies vu personne. Elle connaît ton pas, et cela ne présage rien de bon.",
	],
	"Epreuve": [
		"La forêt referme le passage : ronces, pierre et pente traître, dressées contre toi comme un jugement.",
		"Le chemin se cabre, hostile. Rien ici ne cède sans qu'on le lui arrache.",
		"Un obstacle barre la route, plus vieux que les sentiers. Il faudra payer de son corps ou de sa ruse.",
	],
	"Dilemme": [
		"Deux voies s'ouvrent, et chacune réclame son prix. Aucune ne te laissera tout à fait intact.",
		"Un choix se pose, nu et sans recours. Quoi que tu décides, la forêt s'en souviendra.",
		"On te demande de trancher là où il n'existe pas de bonne réponse. L'hésitation, elle aussi, est une réponse.",
	],
	"Climax": [
		"L'air se fige ; la forêt retient son souffle. Ce qui vient maintenant ne se reprend pas.",
		"Tout converge en ce seuil où les murmures se taisent. L'instant te regarde, et attend.",
		"Le cœur de la forêt bat sous tes pieds, énorme et patient. Ici se décide ce que tu seras devenu.",
	],
}

const RESO_FALLBACKS: Dictionary = {
	"echec": [
		"Rien ne répond à ton geste — ou pire, quelque chose s'en amuse. La forêt te repousse, et tu en sors meurtri.",
		"Le sort se retourne : ce que tu touches se dérobe, et la forêt prend plus qu'elle ne donne.",
	],
	"partiel": [
		"Tu obtiens ce que tu voulais, mais la forêt prélève sa part. Une ombre te suit désormais.",
		"La voie s'entrouvre, à demi. Quelque chose t'a vu faire, et ne l'oubliera pas.",
	],
	"reussite": [
		"Ton geste trouve sa cible. La forêt cède, un instant, et te laisse avancer.",
		"Ce que tu tentes s'accomplit ; le sentier se dénoue devant toi, prudent mais ouvert.",
	],
	"eclatante": [
		"Tout s'accorde, comme si la forêt elle-même retenait son souffle pour toi. Le seuil s'ouvre, et quelque chose d'ancien s'incline.",
		"La forêt te reconnaît enfin. Les murmures se font promesse, et la voie devant toi se déploie sans résistance.",
	],
}

# Sortie courte : 2 phrases tiennent largement sous 64 tokens, et une gen plus courte
# finit plus tôt → davantage d'enrichissements LLM arrivent à temps (avant que le joueur n'avance).
const MAX_TOK_PROSE: int = 64

var _rng := RandomNumberGenerator.new()

# --- Warmup async sélection (R6 ; « toujours faire tourner le LLM » côté Menu) ---
var _sel_cache: Array = []
var _sel_state: String = "idle"   # idle / running / ready
var _sel_epoch: int = 0


func _ready() -> void:
	_rng.randomize()


func _mn() -> Node:
	return get_node_or_null("/root/MerlinNative")


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
	# Attend la fin d'un prefetch en cours par POLLING (pas d'await signal → pas de race, F1).
	while _sel_state == "running":
		await get_tree().process_frame
	if _sel_state == "ready" and _sel_cache.size() >= 3:
		return _sel_cache.duplicate(true)
	return await generate_selection()


func invalidate_selection() -> void:
	_sel_epoch += 1
	_sel_cache = []
	_sel_state = "idle"


# --- 1) SÉLECTION : 3 scénarios (titre + pitch) ---
func generate_selection() -> Array:
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var usr: String = "Propose 3 scenarios brefs pour une aventure a Broceliande. Reponds UNIQUEMENT en JSON: [{\"title\":\"...\",\"pitch\":\"...\"},{...},{...}]. title = court et evocateur. pitch = UNE seule phrase d'appel a l'aventure, imperatif et concret (ex: 'Infiltrez le marche aux noms voles.', 'Poursuivez le gobelin jusque dans la foret.'). Varie les tons."
		var res: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 220, "label": "sélection (3 scénarios)"})
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
	var beats: Array = []
	var diffs: Array = [1, 2, 2, 2, 3]
	for i in BEAT_TYPES.size():
		beats.append({"n": i + 1, "type": BEAT_TYPES[i], "difficulte": diffs[i]})
	return {"title": title, "pitch": pitch, "synopsis": pitch, "beats": beats, "total": beats.size()}


# --- 2bis) INTRO DE QUÊTE (pop-up à accepter) : développement complet + objectif. ---
# Procédural INSTANTANÉ (le pop-up s'ouvre sans attente) ; narrate_intro enrichit en fond.
func build_intro(scenario: Dictionary) -> Dictionary:
	var title: String = str(scenario.get("title", "l'aventure"))
	var pitch: String = str(scenario.get("pitch", ""))
	var intro: String = "%s\n\nLa forêt de Brocéliande se referme derrière toi, et le sentier ne mène plus qu'en avant. Ce que tu cherches t'attend au bout — et ce que tu crains, aussi." % pitch
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
	var usr: String = "Quete: \"%s\" — %s\nEcris une introduction de 3 phrases (francais) qui pose le decor et l'enjeu de cette quete a Broceliande, ton merveilleux-inquietant, recit direct SANS apostropher le joueur. Termine sur ce qui est en jeu." % [title, pitch]
	var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 110, "label": "intro de quête"})
	if r.has("error"):
		return ""
	var s: String = str(r.get("text", "")).strip_edges()
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
	}


func _pick_tags(btype: String, diff: int) -> Array:
	var pool: Array = TYPE_TAG_BIAS.get(btype, TYPE_TAG_BIAS["Exploration"]).duplicate()
	_shuffle(pool)
	var n: int = clampi(diff, 1, 3)
	var out: Array = []
	for i in min(n, pool.size()):
		out.append(pool[i])
	return out


func _fallback_situation(btype: String, _required: Array) -> String:
	var pool: Array = SITU_FALLBACKS.get(btype, SITU_FALLBACKS["Exploration"])
	return str(pool[_rng.randi_range(0, pool.size() - 1)])


# --- 4) RÉSOLUTION : le code a calculé le degré ; le LLM NARRE (prose), "" si échec. ---
func narrate_resolution(situation: Dictionary, played_names: Array, res: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var degree: String = str(res.get("degree", "reussite"))
	var cards: String = ", ".join(played_names)
	var deg_fr: Dictionary = {"echec": "un echec", "partiel": "un succes partiel (a un prix)", "reussite": "une reussite", "eclatante": "une reussite eclatante"}
	var usr: String = "Scene: %s\nActes tentes: %s. Issue: %s.\nNarre l'EFFET de ces actes INTEGRE a la scene, 2 phrases, recit direct SANS apostropher le joueur (pas de 'Ah voyageur') ni commentaire, sans chiffres, et enchaine vers la suite." % [str(situation.get("narration", "")), cards, deg_fr.get(degree, "une reussite")]
	var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": MAX_TOK_PROSE, "label": "issue (effet des choix)"})
	if r.has("error"):
		return ""
	var s: String = str(r.get("text", "")).strip_edges()
	return s if s.length() >= 10 else ""


# Procédural de résolution (INSTANT, déterministe). Public : l'appelant l'affiche immédiatement.
func fallback_resolution(degree: String) -> String:
	var pool: Array = RESO_FALLBACKS.get(degree, RESO_FALLBACKS["reussite"])
	return str(pool[_rng.randi_range(0, pool.size() - 1)])


# --- 5) ÉPILOGUE (fin de run, R69) : LLM, "" si échec → l'appelant garde le procédural. ---
func narrate_epilogue(end_type: String, _state: Dictionary) -> String:
	var mn: Node = _mn()
	if mn == null or not mn.is_ready():
		return ""
	var enj: Dictionary = {
		"accomplissement": "Le voyageur a traverse l'epreuve et entrevoit un fragment du Graal.",
		"mort": "Le voyageur succombe ; la foret le reprend.",
		"corrompu": "La Corruption l'emporte ; le voyageur se dissout dans la foret.",
	}
	var usr: String = "%s Ecris un epilogue de 3 phrases (francais), ton merveilleux-inquietant. Laisse entrevoir une suite." % enj.get(end_type, "Le voyage s'acheve.")
	var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 96, "label": "épilogue"})
	if r.has("error"):
		return ""
	var s: String = str(r.get("text", "")).strip_edges()
	return s if s.length() >= 10 else ""


func fallback_epilogue(end_type: String) -> String:
	match end_type:
		"mort": return "La forêt se referme sur toi comme une paupière. Tu n'es plus qu'un murmure parmi les racines — mais un murmure se réveille toujours."
		"corrompu": return "Tu cesses de lutter, et c'est presque doux. La forêt t'accueille parmi les siens ; quelque part, un autre voyageur entend déjà ton appel."
		_: return "Tu franchis le dernier seuil. Au loin brille un éclat qui pourrait être le Graal — ou son reflet dans tes yeux fatigués. La forêt te laisse repartir, pour cette fois."


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
