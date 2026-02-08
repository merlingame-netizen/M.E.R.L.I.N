class_name FastRoute
extends RefCounted

# Fast deterministic routing to avoid LLM calls on obvious inputs.

const PATTERNS := {
	"combat": {
		"keywords": [
			"attaque", "attaquer", "frappe", "frapper", "combat", "combattre",
			"tue", "tuer", "blesse", "blesser", "defend", "defendre", "defense",
			"esquive", "esquiver", "pare", "parer", "riposte", "contre-attaque",
			"degat", "degats", "coup", "epee", "hache", "arc", "fleche",
			"ennemi", "monstre", "creature", "adversaire", "cible"
		],
		"phrases": [
			"je frappe", "j'attaque", "je me defends", "je tire sur",
			"lance une attaque", "porte un coup", "vise la tete"
		],
		"excludes": ["comment attaquer", "regles de combat", "explique"]
	},
	"dialogue": {
		"keywords": [
			"parle", "parler", "dis", "dire", "demande", "demander",
			"salue", "saluer", "bonjour", "bonsoir", "merci", "pnj",
			"conversation", "discute", "discuter", "questionne", "interroge",
			"negocie", "negocier", "marchande", "marchander", "convainc"
		],
		"phrases": [
			"je dis", "je lui parle", "je demande a", "je salue",
			"parle avec", "discute avec", "je reponds"
		],
		"excludes": []
	},
	"exploration": {
		"keywords": [
			"explore", "explorer", "cherche", "chercher", "fouille", "fouiller",
			"examine", "examiner", "regarde", "regarder", "observe", "observer",
			"inspecte", "inspecter", "entre", "entrer", "sors", "sortir",
			"monte", "monter", "descends", "descendre", "ouvre", "ouvrir",
			"porte", "coffre", "piece", "salle", "couloir", "foret", "grotte",
			"direction", "nord", "sud", "est", "ouest", "gauche", "droite"
		],
		"phrases": [
			"je vais vers", "j'entre dans", "je fouille", "j'examine",
			"qu'est-ce qu'il y a", "je regarde autour", "j'ouvre la"
		],
		"excludes": ["comment explorer", "regles d'exploration"]
	},
	"inventaire": {
		"keywords": [
			"inventaire", "objet", "objets", "equipe", "equiper", "equipement",
			"prends", "prendre", "ramasse", "ramasser", "depose", "deposer",
			"utilise", "utiliser", "consomme", "consommer", "bois", "boire",
			"mange", "manger", "potion", "arme", "armure", "anneau", "amulette",
			"sac", "bourse", "or", "pieces", "achete", "acheter", "vends", "vendre"
		],
		"phrases": [
			"je prends", "j'equipe", "j'utilise", "je bois", "je mange",
			"dans mon sac", "mon inventaire", "je ramasse"
		],
		"excludes": ["regles inventaire", "comment utiliser"]
	},
	"magie": {
		"keywords": [
			"magie", "magique", "sort", "sorts", "sortilege", "enchantement",
			"ogham", "rune", "runes", "incantation", "invoque", "invoquer",
			"conjure", "conjurer", "lance", "lancer", "mana", "energie",
			"druide", "druidique", "benediction", "malediction", "aura",
			"feu", "glace", "foudre", "terre", "vent", "eau", "lumiere", "ombre"
		],
		"phrases": [
			"je lance", "j'invoque", "je conjure", "utilise la magie",
			"trace la rune", "active l'ogham", "incante"
		],
		"excludes": ["regles magie", "comment lancer", "explique la magie", "apprendre"]
	},
	"quete": {
		"keywords": [
			"quete", "quetes", "mission", "missions", "objectif", "objectifs",
			"journal", "accepte", "accepter", "refuse", "refuser", "abandonne",
			"termine", "terminer", "complete", "completer", "recompense",
			"livraison", "escorte", "recherche", "enquete"
		],
		"phrases": [
			"j'accepte la quete", "je refuse la mission", "mes quetes",
			"objectif suivant", "ou dois-je aller", "qui dois-je voir"
		],
		"excludes": ["regles quetes", "comment fonctionnent"]
	}
}

const META_PATTERNS := {
	"keywords": ["regle", "regles", "explique", "expliquer", "comment", "pourquoi",
		"aide", "aider", "tutoriel", "apprendre", "comprendre", "c'est quoi",
		"definition", "signifie", "veut dire"],
	"phrases": ["comment ca marche", "explique-moi", "c'est quoi", "qu'est-ce que",
		"comment faire pour", "aide-moi a comprendre"]
}

static func classify(input: String) -> Dictionary:
	var lower := input.to_lower().strip_edges()
	var result := {"category": "", "confidence": 0.0, "is_meta": false, "method": "none"}

	if _is_meta_question(lower):
		result.is_meta = true
		result.category = "dialogue"
		result.confidence = 0.8
		result.method = "meta_detection"
		return result

	var best_score := 0.0
	var best_category := ""

	for category in PATTERNS.keys():
		var score := _score_category(lower, PATTERNS[category])
		if score > best_score:
			best_score = score
			best_category = category

	if best_score >= 0.6:
		result.category = best_category
		result.confidence = best_score
		result.method = "pattern_match"
	elif best_score >= 0.3:
		result.category = best_category
		result.confidence = best_score
		result.method = "pattern_suggest"

	return result

static func _is_meta_question(input: String) -> bool:
	for keyword in META_PATTERNS.keywords:
		if input.contains(keyword):
			return true
	for phrase in META_PATTERNS.phrases:
		if input.contains(phrase):
			return true
	return false

static func _score_category(input: String, patterns: Dictionary) -> float:
	var score := 0.0
	var matches := 0

	for exclude in patterns.get("excludes", []):
		if input.contains(exclude):
			return 0.0

	for keyword in patterns.get("keywords", []):
		if input.contains(keyword):
			matches += 1
			score += 0.15

	for phrase in patterns.get("phrases", []):
		if input.contains(phrase):
			score += 0.4

	if matches >= 3:
		score += 0.2
	elif matches >= 2:
		score += 0.1

	return clampf(score, 0.0, 1.0)

static func debug_scores(input: String) -> Dictionary:
	var lower := input.to_lower().strip_edges()
	var scores := {}
	for category in PATTERNS.keys():
		scores[category] = _score_category(lower, PATTERNS[category])
	scores["_is_meta"] = _is_meta_question(lower)
	scores["_input"] = lower
	return scores
