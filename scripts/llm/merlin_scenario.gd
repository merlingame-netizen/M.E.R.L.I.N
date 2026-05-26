extends Node
## MerlinScenario — pipeline de génération (autoload). Bible R6/R68/R101/R107.
##
## ARCHITECTURE (adaptée aux contraintes du build, cf. task_plan v9.0 findings) :
## - GBNF cassé sur ce gemma4 → on NE l'utilise pas.
## - Le CODE possède la STRUCTURE (beats, types, difficulté, required_tags = concepts-cœur).
## - Le LLM n'écrit que de la PROSE (sa force, pas de JSON fragile) : synopsis, narration, résolution.
## - Sélection = seul appel ~JSON, avec fallback procédural robuste.
## - Chaque étape a un FALLBACK procédural (R61 cascade) → une run se termine TOUJOURS.

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

const SEL_FALLBACK: Array = [
	{"title": "Le Marché des Murmures", "pitch": "Des lanternes sans porteurs, des marchands sans visage. Ils troquent des choses qu'on ne devrait pas vendre — et l'un d'eux connaît déjà ton nom."},
	{"title": "Le Rite sans Fin", "pitch": "Au cœur de la forêt, des voix psalmodient un rite que nul ne comprend plus. Quelque chose attend que tu l'écoutes."},
	{"title": "La Fontaine qui Rêve", "pitch": "Une source noire où dorment des visages. L'un d'eux te ressemble, et il murmure ton avenir comme un souvenir."},
]

var _rng := RandomNumberGenerator.new()

# --- Prefetch / warmup async (R6 lookahead ; demande joueur « toujours faire tourner le LLM ») ---
var _sel_cache: Array = []
var _sel_state: String = "idle"   # idle / running / ready
var _sel_epoch: int = 0
var _situ_cache: Dictionary = {}  # {beat_n: situation}
var _situ_running_n: int = -1


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


# --- PREFETCH SITUATION (depuis le Jeu, pendant la lecture de l'issue) ---
func invalidate_situations() -> void:
	_situ_cache = {}
	_situ_running_n = -1


func prefetch_situation(beat: Dictionary, state: Dictionary) -> void:
	var n: int = int(beat.get("n", -1))
	if n < 0 or _situ_cache.has(n) or _situ_running_n == n:
		return
	var mn: Node = _mn()
	if mn == null or not mn.is_ready() or mn.is_busy():
		return  # ne pas entrer en contention avec la résolution
	_situ_running_n = n
	var situ: Dictionary = await generate_situation(beat, state)
	_situ_cache[n] = situ
	if _situ_running_n == n:
		_situ_running_n = -1


func take_situation(beat: Dictionary, state: Dictionary) -> Dictionary:
	var n: int = int(beat.get("n", -1))
	# Attend un prefetch en cours pour ce beat (poll, gardé sur running — F1/F2).
	while _situ_running_n == n and not _situ_cache.has(n):
		await get_tree().process_frame
	if _situ_cache.has(n):
		var s: Dictionary = _situ_cache[n]
		_situ_cache.erase(n)
		return s
	# Pas de cache : si le modèle est occupé, attend qu'il se libère (F2, anti-contention).
	var mn: Node = _mn()
	if mn != null:
		var guard: int = 0
		while mn.is_busy() and guard < 3000:
			await get_tree().process_frame
			guard += 1
	return await generate_situation(beat, state)


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
		var usr: String = "%sDecris UNE scene (type %s) a Broceliande: 2 phrases, recit direct SANS apostropher le joueur (pas de 'Ah voyageur'), finissant sur une tension ouverte. Fais sentir, sans les lister, ces ressources: %s." % [ctx, btype, hint]
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
		var usr: String = "Scene: %s\nActes tentes: %s. Issue: %s.\nNarre l'EFFET de ces actes INTEGRE a la scene, 2 phrases, recit direct SANS apostropher le joueur (pas de 'Ah voyageur') ni commentaire, sans chiffres, et enchaine vers la suite." % [str(situation.get("narration", "")), cards, deg_fr.get(degree, "une reussite")]
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
