## ═══════════════════════════════════════════════════════════════════════════
## ScenarioVariation — graine de variation + porte de nouveaute
## ═══════════════════════════════════════════════════════════════════════════
## Repond a une exigence de design : les scenarios sont generes a 100 % par le
## LLM, et AUCUN scenario ne doit ressembler a un autre, dans les limites du
## bornage de la bible.
##
## Le probleme mesure (2026-07-26) : injecter des scenarios de reference comme
## exemples produit mecaniquement de la ressemblance. Sur le corpus de 100
## references, on compte 18 libelles d'options distincts pour 8982 options, et
## 90 resumes de cartes distincts pour 2994 cartes. Le few-shot de CONTENU
## enseigne la copie.
##
## La reponse tient en deux mecanismes complementaires :
##
##   GRAINE DE VARIATION  — avant la generation, on tire une valeur par axe
##       (lieu, entite, pression, registre sensoriel, mecanisme du twist) et on
##       l'IMPOSE au LLM. Les valeurs recemment utilisees sont exclues. L'espace
##       couvert depasse 25 000 combinaisons, toutes a l'interieur du bornage.
##
##   PORTE DE NOUVEAUTE   — apres la generation, on compare le resultat aux
##       derniers scenarios joues. Trop proche : une regeneration avec une
##       graine differente. Toujours trop proche : on accepte et on journalise —
##       on ne bloque jamais le joueur pour un motif de style.
##
## Source des axes : data/ai/scenario_templates.json -> generation_contract.
## ═══════════════════════════════════════════════════════════════════════════
class_name ScenarioVariation
extends RefCounted

const TEMPLATES_PATH := "res://data/ai/scenario_templates.json"
const HISTORY_PATH := "user://scenario_variation_history.json"

## Nombre de scenarios pendant lesquels une valeur d'axe ne peut pas ressortir.
const COOLDOWN_SCENARIOS := 3

var _axes: Dictionary = {}          # nom d'axe -> Array de valeurs
var _history: Array = []            # [{axe: valeur, ...}, ...] du plus recent au plus ancien
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_load_axes()
	_load_history()


func _load_axes() -> void:
	var f := FileAccess.open(TEMPLATES_PATH, FileAccess.READ)
	if f == null:
		push_warning("[ScenarioVariation] contrat introuvable : %s" % TEMPLATES_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("[ScenarioVariation] contrat illisible")
		return
	var contract: Dictionary = (parsed as Dictionary).get("generation_contract", {})
	var axes: Dictionary = contract.get("axes_de_variation", {})
	for key in axes.keys():
		var k: String = str(key)
		if k.begins_with("_") or k == "regle_de_tirage":
			continue
		if axes[key] is Array:
			_axes[k] = (axes[key] as Array).duplicate()


func _load_history() -> void:
	if not FileAccess.file_exists(HISTORY_PATH):
		return
	var f := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		_history = parsed


func _save_history() -> void:
	var f := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_history.slice(0, 50)))
	f.close()


## Tire une graine : une valeur par axe, en evitant celles des N derniers
## scenarios. Si un axe est entierement en cooldown, on relache la contrainte
## pour cet axe plutot que d'echouer.
func draw_seed() -> Dictionary:
	var seed_dict: Dictionary = {}
	var recent: Array = _history.slice(0, COOLDOWN_SCENARIOS)
	for axis_name in _axes.keys():
		var values: Array = _axes[axis_name]
		if values.is_empty():
			continue
		var used: Array = []
		for h in recent:
			if h is Dictionary and (h as Dictionary).has(axis_name):
				used.append((h as Dictionary)[axis_name])
		var pool: Array = []
		for v in values:
			if not used.has(v):
				pool.append(v)
		if pool.is_empty():
			pool = values.duplicate()
		seed_dict[axis_name] = pool[_rng.randi_range(0, pool.size() - 1)]
	return seed_dict


## Enregistre la graine utilisee (a appeler une fois le scenario accepte).
func commit_seed(seed_dict: Dictionary) -> void:
	_history.insert(0, seed_dict.duplicate())
	_save_history()


## Bloc de prompt a injecter dans les appels creatifs (titres, intro, squelette).
## Formule en imperatif : ce sont des contraintes, pas des suggestions.
func format_seed_for_prompt(seed_dict: Dictionary) -> String:
	if seed_dict.is_empty():
		return ""
	var lines: Array = [
		"CONTRAINTES DE VARIATION (obligatoires — ce scenario doit differer de tous les precedents) :"
	]
	if seed_dict.has("lieu"):
		lines.append("  - Lieu central imposé : %s. N'utilise pas un autre decor principal." % str(seed_dict["lieu"]))
	if seed_dict.has("entite_centrale"):
		lines.append("  - Ce autour de quoi tourne le scenario : %s." % str(seed_dict["entite_centrale"]))
	if seed_dict.has("pression"):
		lines.append("  - Ce qui presse le voyageur : %s." % str(seed_dict["pression"]))
	if seed_dict.has("registre_sensoriel"):
		lines.append("  - Sens dominant de l'ecriture : %s. Ancre les descriptions dessus." % str(seed_dict["registre_sensoriel"]))
	if seed_dict.has("mecanisme_du_twist"):
		lines.append("  - Le retournement porte sur : %s." % str(seed_dict["mecanisme_du_twist"]))
	lines.append("  - N'emploie PAS les triplets d'options usuels (Affronter / Fuir / Apaiser,")
	lines.append("    Donner / Prendre / Echanger). Invente des actions propres a cette scene.")
	return "\n".join(lines)


## Similarite lexicale grossiere entre deux textes (indice de Jaccard sur les
## mots de plus de 3 lettres). Sert de garde-fou local quand les embeddings ne
## sont pas disponibles.
static func lexical_similarity(a: String, b: String) -> float:
	var wa: Dictionary = _content_words(a)
	var wb: Dictionary = _content_words(b)
	if wa.is_empty() and wb.is_empty():
		return 0.0
	var inter: int = 0
	for w in wa.keys():
		if wb.has(w):
			inter += 1
	var union: int = wa.size() + wb.size() - inter
	return float(inter) / float(union) if union > 0 else 0.0


static func _content_words(text: String) -> Dictionary:
	var out: Dictionary = {}
	var cleaned: String = text.to_lower()
	for ch in [",", ".", ";", ":", "!", "?", "«", "»", "\"", "(", ")", "—", "…"]:
		cleaned = cleaned.replace(ch, " ")
	for w in cleaned.split(" ", false):
		if w.length() > 3:
			out[w] = true
	return out


## Verdict de la porte de nouveaute face aux textes deja servis.
## Retourne {"accepte": bool, "similarite_max": float, "proche_de": String}.
func novelty_gate(candidate_text: String, previous_texts: Dictionary,
		threshold: float = 0.35) -> Dictionary:
	var worst: float = 0.0
	var closest: String = ""
	for key in previous_texts.keys():
		var sim: float = lexical_similarity(candidate_text, str(previous_texts[key]))
		if sim > worst:
			worst = sim
			closest = str(key)
	return {
		"accepte": worst <= threshold,
		"similarite_max": worst,
		"proche_de": closest,
	}
