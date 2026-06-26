class_name MerlinStructured
extends RefCounted
## v10.17 (track LLM, inspiré NobodyWho) — generate_object() : génération STRUCTURÉE robuste.
## Comble les gaps NobodyWho « retry-on-malformed » + « enforce + parse + valide + retry » SANS
## toucher generate()/generate_raw() (single-flight `_busy`, nonce `_gen_id`, timeout/cancel restent
## OCTET-IDENTIQUES). Reçoit le node MerlinNative en ARGUMENT (zéro lecture d'autoload — même
## discipline que MerlinPromptBuilder). Les await generate() sont SÉQUENTIELS (jamais 2 en vol) →
## le single-flight de MerlinNative gère tout.
##
## Boucle (MAX_RETRIES+1 essais) : régime structuré (temp basse) → await mn.generate() → MerlinJson
## extract+repair → validation par Callable fournie → ok ? {data} : retry. La grammaire est passée
## best-effort via opts (chemin déjà supporté par generate_raw) mais reste DÉSACTIVÉE par défaut
## (MerlinGrammar.USE_GBNF = false, GBNF cassé gemma4) : la robustesse vient du parse+repair+retry.
## Au DERNIER essai, la grammaire est toujours RELÂCHÉE (JSON libre garanti). Sur échec total →
## {error} et l'appelant garde son fallback procédural existant (contrat inchangé).

const MAX_RETRIES: int = 1  # 2 essais total — borne la latence (~1 tok/s) sous la deadline 8s sélection


## mn : node MerlinNative (doit exposer generate()). validate : Callable(parsed) -> bool (champs OK ?).
## want_array : true → on attend un Array JSON (ex. sélection), false → un objet {…}.
## Retourne {"data": Variant} (Array ou Dictionary) ou {"error": String}.
static func generate_object(mn: Node, system: String, user: String, opts: Dictionary,
		grammar_name: String, validate: Callable, want_array: bool = false) -> Dictionary:
	if mn == null or not mn.has_method("generate"):
		return {"error": "structured: moteur indisponible"}
	for i in range(MAX_RETRIES + 1):
		var o: Dictionary = opts.duplicate(true)
		o["creative"] = false  # régime structuré (TEMP_STRUCTURED 0.45) — déterminisme accru
		# Grammaire best-effort SAUF au dernier essai (relâche → JSON 100% libre, identique à l'existant).
		# OFF par défaut : MerlinGrammar.has() == false tant que USE_GBNF == false → erase systématique.
		if i < MAX_RETRIES and MerlinGrammar.has(grammar_name):
			o["grammar"] = MerlinGrammar.get_grammar(grammar_name)
			o["grammar_root"] = "root"
		else:
			o.erase("grammar")
			o.erase("grammar_root")
		o["label"] = "%s (essai %d/%d)" % [grammar_name, i + 1, MAX_RETRIES + 1]
		var res: Dictionary = await mn.generate(system, user, o)
		if res.has("error"):
			continue  # erreur/timeout moteur → réessaie (ou sort si dernier essai)
		var text: String = str(res.get("text", ""))
		var parsed: Variant
		if want_array:
			parsed = MerlinJson.extract_array(text)
			if (parsed as Array).is_empty():
				continue
		else:
			parsed = MerlinJson.extract_obj(text)
			if (parsed as Dictionary).is_empty():
				continue
		if validate.is_valid() and not bool(validate.call(parsed)):
			continue  # champs invalides → réessaie
		return {"data": parsed}
	return {"error": "structured: epuise apres %d essais" % (MAX_RETRIES + 1)}
