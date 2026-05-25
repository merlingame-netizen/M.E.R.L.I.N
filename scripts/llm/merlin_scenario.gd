extends Node
## MerlinScenario — pipeline de génération (autoload). Bible R6/R68/R101/R107.
##
## ARCHITECTURE (adaptée aux contraintes du build, cf. task_plan v9.0 findings) :
## - GBNF cassé sur ce gemma4 → on NE l'utilise pas.
## - Le CODE possède la STRUCTURE (beats, types, difficulté, required_tags = concepts-cœur).
## - Le LLM n'écrit que de la PROSE (sa force, pas de JSON fragile) : synopsis, narration, résolution.
## - Sélection = seul appel ~JSON, avec fallback procédural robuste.
## - Chaque étape a un FALLBACK procédural (R61 cascade) → une run se termine TOUJOURS.

const SYSTEM_PREFIX: String = "Tu es Merlin, maitre du jeu joueur et enigmatique de la foret de Broceliande (legende celtique). Tu t'adresses a un voyageur. REGLES: ecris en francais, ton merveilleux-inquietant (la feerie qui mord), bref et image. Ne nomme JAMAIS de simulation/IA/jeu (pas de 4e mur). Pas d'anglicismes. Reste dans Broceliande."

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

const SEL_FALLBACK: Array = [
	{"title": "Le Marché des Murmures", "pitch": "Des lanternes sans porteurs, des marchands sans visage. Ils troquent des choses qu'on ne devrait pas vendre — et l'un d'eux connaît déjà ton nom."},
	{"title": "Le Rite sans Fin", "pitch": "Au cœur de la forêt, des voix psalmodient un rite que nul ne comprend plus. Quelque chose attend que tu l'écoutes."},
	{"title": "La Fontaine qui Rêve", "pitch": "Une source noire où dorment des visages. L'un d'eux te ressemble, et il murmure ton avenir comme un souvenir."},
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _mn() -> Node:
	return get_node_or_null("/root/MerlinNative")


# --- 1) SÉLECTION : 3 scénarios (titre + pitch) ---
func generate_selection() -> Array:
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var usr: String = "Propose 3 scenarios brefs pour une aventure a Broceliande. Reponds UNIQUEMENT en JSON: [{\"title\":\"...\",\"pitch\":\"...\"},{...},{...}]. title = court et evocateur. pitch = 2 phrases (une accroche + un danger). Varie les tons."
		var res: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 220})
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


# --- 2) SQUELETTE : structure 5 beats (CODE) + synopsis (LLM, prose) ---
func generate_skeleton(title: String, pitch: String) -> Dictionary:
	var beats: Array = []
	var diffs: Array = [1, 2, 2, 2, 3]
	for i in BEAT_TYPES.size():
		beats.append({"n": i + 1, "type": BEAT_TYPES[i], "difficulte": diffs[i]})
	var synopsis: String = pitch
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var usr: String = "Scenario: \"%s\" — %s\nEcris un synopsis de 2 phrases (francais) qui pose l'enjeu, sans le resoudre." % [title, pitch]
		var res: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 90})
		if not res.has("error"):
			var s: String = str(res.get("text", "")).strip_edges()
			if s.length() >= 10:
				synopsis = s
	return {"title": title, "pitch": pitch, "synopsis": synopsis, "beats": beats, "total": beats.size()}


# --- 3) SITUATION : code choisit required_tags, LLM ecrit la narration (prose) ---
func generate_situation(beat: Dictionary, state: Dictionary) -> Dictionary:
	var btype: String = str(beat.get("type", "Exploration"))
	var diff: int = int(beat.get("difficulte", 1))
	var required: Array = _pick_tags(btype, diff)
	var narration: String = ""
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var hint: String = ", ".join(required)
		var resume: String = str(state.get("resume", ""))
		var ctx: String = (("Resume: " + resume + "\n") if resume != "" else "")
		var usr: String = "%sEcris UNE situation (type %s) a Broceliande, 2 phrases en francais, qui se termine sur une tension ouverte. Fais sentir, sans les nommer en liste, ces ressources utiles: %s." % [ctx, btype, hint]
		var res: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 80})
		if not res.has("error"):
			narration = str(res.get("text", "")).strip_edges()
	if narration.length() < 10:
		narration = _fallback_situation(btype, required)
	return {"narration": narration, "required_tags": required, "type": btype, "difficulte": diff}


func _pick_tags(btype: String, diff: int) -> Array:
	var pool: Array = TYPE_TAG_BIAS.get(btype, TYPE_TAG_BIAS["Exploration"]).duplicate()
	_shuffle(pool)
	var n: int = clampi(diff, 1, 3)
	var out: Array = []
	for i in min(n, pool.size()):
		out.append(pool[i])
	return out


func _fallback_situation(btype: String, _required: Array) -> String:
	match btype:
		"Rencontre": return "Une silhouette se détache des arbres et t'observe en silence. Elle attend de voir qui tu es vraiment."
		"Epreuve": return "Le chemin se ferme : ronces, pierres, une pente traîtresse. Il faudra de la force pour passer."
		"Dilemme": return "Deux voies s'ouvrent, et chacune réclame son prix. Aucune ne te laissera tout à fait intact."
		"Climax": return "L'air se fige ; la forêt retient son souffle. Ce que tu fais maintenant décidera de tout."
		_: return "La clairière s'ouvre devant toi, trop calme. Quelque chose t'y attend, qui te connaît déjà."


# --- 4) RÉSOLUTION : le code a calculé le degré ; le LLM NARRE (prose) ---
func narrate_resolution(situation: Dictionary, played_names: Array, res: Dictionary) -> String:
	var degree: String = str(res.get("degree", "reussite"))
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var cards: String = ", ".join(played_names)
		var deg_fr: Dictionary = {"echec": "un echec", "partiel": "un succes partiel (a un prix)", "reussite": "une reussite", "eclatante": "une reussite eclatante"}
		var usr: String = "Situation: %s\nLe voyageur a tente: %s. Resultat: %s.\nNarre l'issue en 2 phrases (francais), montre les consequences sans chiffres, enchaine vers la suite." % [str(situation.get("narration", "")), cards, deg_fr.get(degree, "une reussite")]
		var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 80})
		if not r.has("error"):
			var s: String = str(r.get("text", "")).strip_edges()
			if s.length() >= 10:
				return s
	return _fallback_resolution(degree)


func _fallback_resolution(degree: String) -> String:
	match degree:
		"echec": return "Rien ne répond à ton geste — ou pire, quelque chose s'en amuse. La forêt te repousse, et tu en sors meurtri."
		"partiel": return "Tu obtiens ce que tu voulais, mais la forêt prélève sa part. Une ombre te suit désormais."
		"eclatante": return "Tout s'accorde, comme si la forêt elle-même retenait son souffle pour toi. Le passage s'ouvre, lumineux."
		_: return "Ton geste trouve sa cible. La forêt cède, un instant, et te laisse avancer."


# --- 5) ÉPILOGUE (fin de run, R69) ---
func narrate_epilogue(end_type: String, _state: Dictionary) -> String:
	var mn: Node = _mn()
	if mn != null and mn.is_ready():
		var enj: Dictionary = {
			"accomplissement": "Le voyageur a traverse l'epreuve et entrevoit un fragment du Graal.",
			"mort": "Le voyageur succombe ; la foret le reprend.",
			"corrompu": "La Corruption l'emporte ; le voyageur se dissout dans la foret.",
		}
		var usr: String = "%s Ecris un epilogue de 3 phrases (francais), ton merveilleux-inquietant. Laisse entrevoir une suite." % enj.get(end_type, "Le voyage s'acheve.")
		var r: Dictionary = await mn.generate(SYSTEM_PREFIX, usr, {"creative": true, "max_tokens": 110})
		if not r.has("error"):
			var s: String = str(r.get("text", "")).strip_edges()
			if s.length() >= 10:
				return s
	return _fallback_epilogue(end_type)


func _fallback_epilogue(end_type: String) -> String:
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
