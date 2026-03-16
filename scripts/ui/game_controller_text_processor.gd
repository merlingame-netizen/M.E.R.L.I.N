## ═══════════════════════════════════════════════════════════════════════════════
## Game Controller — Text Post-Processing Module
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_controller.gd (FIX 33-55).
## Handles meta-text stripping, person conversion, label dedup/sanitization.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name GameControllerTextProcessor

## Meta-text patterns to strip from LLM output (line-level removal).
const META_WORDS: Array[String] = [
	"decrochez le choix", "choisir entre", "(a)", "(b)", "(c)", "a/b/c",
	"regle stricte", "meta-commentaire", "vocabulaire celtique",
	"ecris une scene", "3 choix", "biome:", "carte:", "role:",
	"scene narrative", "trois options", "trois choix",
	"je suis merlin", "je suis le druide", "je suis un druide",
	"je suis une voix", "je suis un ancien", "je suis le gardien",
	"voici les choix", "voici trois", "voici les options",
	"voici une introduction", "voici ta reponse", "voici la reponse",
	"je suis pret", "merlin est un", "merlin est le",
	"tu as choisi", "avec une voix", "d'une voix",
	"ensemble nous formons", "c'est une situation",
	"narration:", "narrateur:", "scenario:",
	"voici une description", "description ambiante", "basee sur le scenario",
	"bienvenue dans", "bienvenue en", "ce voyageur est",
	"le lieu est", "le parc national", "heures de train",
	# FIX 38: Meta-text describing narrative structure
	"sert de catalyseur", "met l'accent sur", "complication suivante",
	"la suite de l'histoire", "dans cette scene", "cette carte",
	"cette situation sert", "voici une complication", "voici un",
	"ce passage montre", "ce moment revele", "cela introduit",
	# FIX 41: Prompt structure leaks (VERBE:, B/C, FORCE label)
	"verbe :", "verbe:", "b/c)", "a/b)", "a) ", "b) ", "c) ",
	"a/ ", "b/ ", "c/ ", "a/'", "b/'", "c/'",
	"force:", "force :", "option a", "option b", "option c",
	# FIX 43: Identity leaks (LLM assigns Merlin identity to player)
	"tu es merlin", "tu es le druide", "tu es un druide",
	"tu es l'enchanteur", "merlin l'enchanteur",
	# FIX 44: Card generation meta-text + scene structure
	"voici ta carte", "entierement generee", "informations fournies",
	"premiere scene", "deuxieme scene", "troisieme scene",
	"point de depart", "genere en fonction",
	# FIX 45: Prompt instruction leaks (raw template output)
	"titre poetique", "action en 1 phrase", "vers de complication",
	"action differente", "tu puis ai", "equipe principale",
	# FIX 46: Narrative structure leaks ("la complication est causee par...")
	"la complication est", "causee par", "causée par",
	"est causee par", "est causée par",
	# FIX 47: Scenario suggestion + tag description leaks
	"voici la suggestion", "suggestion du scenario",
	"theme ambiant", "thème ambiant", "tags appropries", "tags appropriés",
	"pour le biome", "carte ambiante pour",
	"jour 1 de ce voyage", "jour 2 de ce voyage", "jour 3 de ce voyage",
	# FIX 48: Option labeling leaks + "phrase finale"
	"phrase finale", "phrase initiale", "phrase de transition",
	# FIX 49: Arc prefix + season/session labels
	"saison spring", "saison summer", "saison autumn", "saison winter",
	"saison :", "séance:", "seance:", "séance :",
	# FIX 50: Screenplay format + "cette scene"
	"cette scene", "cette scène", "the scene is",
	# FIX 51: Dash-prefixed arc names
	"- voyage en", "- exploration de", "- complication",
	# FIX 52: "Scene N" without separator + "in the" English intro
	"scene 1", "scene 2", "scene 3", "scene 4", "scene 5",
	"in the forest", "in the mist", "in the cave",
	# FIX 55: Card type labels leaked from prompt
	"carte ambiante", "carte narrative", "carte ambiance",
	"carte événement", "carte evenement", "carte merlin",
	"carte promesse", "ambient card", "narrative card",
]

## Nouns/adjectives to reject as option labels (not action verbs).
const REJECTED_LABELS: Array[String] = [
	"l'air", "merveille", "chute", "parcours",
	"situation", "ombre", "lumiere", "silence", "nature",
	"foret", "chemin", "route", "pierre", "eau", "feu",
	"terre", "ciel", "nuit", "jour", "lune", "soleil",
	# FIX 41: Prompt structure words + invented suffixes
	"verbe", "force", "option", "choix", "action",
	"travaux", "travail",
	# FIX 45: Common nouns used as labels instead of verbs
	"vue", "lumieres", "lumières", "scene", "scène",
	"valuer", "titre", "merveille", "paradis",
	"complication", "introduction", "exploration",
	# FIX 48: More nouns seen in MC29
	"facette", "amour", "l'amour", "silence",
	"lumiere", "lumière", "ombre", "sentier",
	# FIX 51: Nouns seen in MC33
	"voyage", "recherche", "aventure", "mystere",
	"mystère", "destin", "histoire", "legende",
	"légende", "vision", "memoire", "mémoire",
	# FIX 53: Nouns seen in MC35
	"danger", "courage", "combat", "fuite",
	"secret", "enigme", "énigme", "tresor",
	"trésor", "refuge", "passage", "sentier",
	# FIX 54: Character/role nouns seen in MC36
	"guerrier", "guerriere", "guerrière",
	"druide", "chasseur", "voyageur",
	"gardien", "sorcier", "esprit",
	# FIX 55: English words + adjectives as labels
	"run", "fight", "hide", "go",
	"première", "premier", "dernière", "dernier",
	"ancienne", "ancien",
]

## Fallback action verbs for label replacement.
const FALLBACK_VERBS: Array[String] = [
	"Explorer", "Fuir", "Grimper", "Creuser",
	"Soigner", "Briser", "Chanter", "Mediter", "Nager",
	"Siffler", "Gravir", "Plonger", "Negocier", "Traquer",
]


func post_process_card_text(card: Dictionary) -> void:
	## FIX 33: Post-process card text before display.
	## Applies meta stripping, person conversion, label cleanup.
	if card.is_empty():
		return
	var text: String = str(card.get("text", ""))
	if text.is_empty():
		return

	var result: String = _strip_meta_and_convert_person(text)

	if result.length() >= 10:
		card["text"] = result

	# --- FIX 34+37: Deduplicate + sanitize option labels ---
	_sanitize_option_labels(card)


func _strip_meta_and_convert_person(text: String) -> String:
	## Strip meta-text lines and convert 1st/3rd person to 2nd person.
	var result: String = text
	var rx := RegEx.new()

	# Strip "Etape N:" / "Scene N -" / "Acte N:" / "Scene :" / "Scene 1" prefixes
	rx.compile("(?im)^\\s*(?:[eé]tape|scene|sc[eè]ne|acte|chapitre|séance)\\s*(?:\\d+\\s*[:\\-]?|[:\\-])\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx.sub(result, "", true)
	# FIX 36: Strip arc phase prefixes
	rx.compile("(?im)^\\s*(?:complication|climax|resolution|introduction|exploration|twist|epilogue|prologue|transition|aurore druidique)\\s*:?\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx.sub(result, "", true)
	# Strip markdown bold
	rx.compile("\\*\\*[^*]{0,60}\\*\\*:?")
	result = rx.sub(result, "", true)
	# FIX 50: Strip screenplay format headers
	rx.compile("(?im)^\\s*(?:INT|EXT|int|ext)\\.\\s*[A-ZÀ-Ü ]{2,50}\\s*[-–—]\\s*[A-ZÀ-Ü ]{2,20}\\s*\\n?")
	result = rx.sub(result, "", true)
	# FIX 46: Strip lines starting with backslash
	rx.compile("(?m)^\\s*\\\\\\s*.+$")
	result = rx.sub(result, "", true)

	# Strip lines containing meta-words
	for mw in META_WORDS:
		var pos: int = result.to_lower().find(mw)
		while pos >= 0:
			var line_start: int = result.rfind("\n", pos)
			var line_end: int = result.find("\n", pos)
			if line_start < 0: line_start = 0
			if line_end < 0: line_end = result.length()
			var candidate: String = result.substr(0, line_start) + result.substr(line_end)
			# FIX 47: If line-strip would destroy all text, use sentence-strip
			if candidate.strip_edges().length() < 10:
				var sent_start: int = pos
				for ch in [".", ":", ";", "!"]:
					var ss: int = result.rfind(ch, pos)
					if ss >= 0 and ss > line_start:
						sent_start = ss + 1
						break
				if sent_start == pos:
					sent_start = line_start
				var sent_end: int = result.length()
				for ch in [".", ":", ";", "!"]:
					var se: int = result.find(ch, pos + mw.length())
					if se >= 0 and se < sent_end:
						sent_end = se + 1
				result = result.substr(0, sent_start) + result.substr(sent_end)
			else:
				result = candidate
			pos = result.to_lower().find(mw)

	# FIX 47: Strip template arrows and ALL-CAPS option labels
	rx.compile("(?m)→\\s*choix\\s*:\\s*[A-ZÀ-Ü]+")
	result = rx.sub(result, "", true)

	# --- Person conversion: 1st->2nd (je->tu), vous->tu ---
	result = _convert_person(result, rx)

	# --- Capitalize "tu" at sentence start ---
	rx.compile("(?m)^tu\\b")
	result = rx.sub(result, "Tu", true)

	# Clean multiple blank lines
	while result.contains("\n\n\n"):
		result = result.replace("\n\n\n", "\n\n")
	result = result.strip_edges()

	return result


func _convert_person(text: String, rx: RegEx) -> String:
	## Convert 1st person and "vous" to 2nd person singular "tu".
	var result: String = text
	# FIX 40: Handle j'ai/j'avais/j'etais BEFORE generic j'->t'
	rx.compile("(?i)\\bj'ai\\b")
	result = rx.sub(result, "tu as", true)
	rx.compile("(?i)\\bj'avais\\b")
	result = rx.sub(result, "tu avais", true)
	rx.compile("(?i)\\bj'[eé]tais\\b")
	result = rx.sub(result, "tu étais", true)
	rx.compile("(?i)\\bj'aurai\\b")
	result = rx.sub(result, "tu auras", true)
	rx.compile("(?i)\\bj'")
	result = rx.sub(result, "t'", true)
	rx.compile("(?i)\\bje\\b")
	result = rx.sub(result, "tu", true)
	rx.compile("(?i)\\bm'")
	result = rx.sub(result, "t'", true)
	rx.compile("(?i)\\bme\\b")
	result = rx.sub(result, "te", true)
	rx.compile("(?i)\\bmoi\\b")
	result = rx.sub(result, "toi", true)
	rx.compile("(?i)\\bvous avez\\b")
	result = rx.sub(result, "tu as", true)
	rx.compile("(?i)\\bvous [eê]tes\\b")
	result = rx.sub(result, "tu es", true)
	rx.compile("(?i)\\bvous\\b")
	result = rx.sub(result, "tu", true)
	rx.compile("(?i)\\bvotre\\b")
	result = rx.sub(result, "ton", true)
	rx.compile("(?i)\\bvos\\b")
	result = rx.sub(result, "tes", true)
	rx.compile("(?i)\\bmes\\b")
	result = rx.sub(result, "tes", true)
	rx.compile("(?i)\\bmon\\b")
	result = rx.sub(result, "ton", true)
	rx.compile("(?i)\\bma\\b")
	result = rx.sub(result, "ta", true)
	# FIX 42: Fix avoir conjugation after "je"->"tu" conversion
	rx.compile("(?i)\\btu n'ai\\b")
	result = rx.sub(result, "tu n'as", true)
	rx.compile("(?i)\\btu ai\\b")
	result = rx.sub(result, "tu as", true)
	return result


func _sanitize_option_labels(card: Dictionary) -> void:
	## FIX 34+37: Deduplicate and sanitize option labels.
	var options: Array = card.get("options", [])
	if options.size() < 2:
		return

	var seen: Dictionary = {}
	var fb_idx: int = 0
	for i in range(options.size()):
		var lbl: String = str(options[i].get("label", "")).strip_edges()
		# FIX 44: Normalize Unicode dashes to ASCII hyphen
		lbl = lbl.replace("\u2010", "-").replace("\u2011", "-").replace("\u2012", "-").replace("\u2013", "-").replace("\u2014", "-")
		# FIX 53: Strip parentheses and brackets
		lbl = lbl.replace("(", "").replace(")", "").replace("[", "").replace("]", "").strip_edges()
		if lbl.length() > 0:
			lbl = lbl[0].to_upper() + lbl.substr(1)
		options[i]["label"] = lbl
		var lbl_lower: String = lbl.to_lower()
		var needs_replace := false
		# FIX 37: Reject malformed labels
		if lbl.length() < 3:
			needs_replace = true
		elif lbl.contains(")") or lbl.contains("(") or lbl.contains(":"):
			needs_replace = true
		# FIX 39: Reject pronoun-suffixed labels
		elif lbl.to_lower().ends_with("-tu") or lbl.to_lower().ends_with("-moi") \
				or lbl.to_lower().ends_with("-toi") or lbl.to_lower().ends_with("-nous") \
				or lbl.to_lower().ends_with("-vous") or lbl.to_lower().ends_with("-les") \
				or lbl.to_lower().ends_with("-la") or lbl.to_lower().ends_with("-le"):
			needs_replace = true
		# FIX 43: Reject truncated labels ending with dash
		elif lbl.ends_with("-"):
			needs_replace = true
		elif lbl_lower in seen:
			needs_replace = true
		elif lbl_lower in REJECTED_LABELS:
			needs_replace = true
		if needs_replace:
			while fb_idx < FALLBACK_VERBS.size():
				var fb_lower: String = FALLBACK_VERBS[fb_idx].to_lower()
				fb_idx += 1
				if fb_lower not in seen:
					options[i]["label"] = FALLBACK_VERBS[fb_idx - 1]
					seen[fb_lower] = true
					break
		else:
			seen[lbl_lower] = true
