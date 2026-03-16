## ═══════════════════════════════════════════════════════════════════════════════
## LLM Adapter — Text Sanitization & Label Extraction
## ═══════════════════════════════════════════════════════════════════════════════
## Cleans LLM free-text output: meta-commentary stripping, label extraction,
## verb parsing, pronoun enforcement, markdown cleanup, minigame detection.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name LlmAdapterTextSanitizer


## Extract the first verb from a label for resolution text.
func extract_verb_from_label(label: String) -> String:
	var words := label.strip_edges().split(" ")
	if words.size() > 0:
		return words[0].to_lower()
	return "agir"


## Detect if the narrative text or option verbs suggest a minigame.
## Scans MerlinConstants.MINIGAME_CATALOGUE trigger words against text + verbs.
func detect_minigame(text: String, verbs: Array[String]) -> Dictionary:
	var combined := text.to_lower()
	for v in verbs:
		combined += " " + v.to_lower()

	var best_id := ""
	var best_hits: int = 0
	for mg_id in MerlinConstants.MINIGAME_CATALOGUE:
		var mg: Dictionary = MerlinConstants.MINIGAME_CATALOGUE[mg_id]
		var trigger_str: String = str(mg.get("trigger", ""))
		var triggers := trigger_str.split("|")
		var hits: int = 0
		for t in triggers:
			if combined.find(t.strip_edges()) >= 0:
				hits += 1
		if hits > best_hits:
			best_hits = hits
			best_id = mg_id

	if best_hits >= 2 and not best_id.is_empty():
		var mg: Dictionary = MerlinConstants.MINIGAME_CATALOGUE[best_id]
		return {"id": best_id, "name": str(mg.get("name", "")), "desc": str(mg.get("desc", ""))}
	return {}


## Build contextual resolution text for success or failure.
func build_result_text(verb: String, label: String, effect: Dictionary, is_success: bool) -> String:
	var effect_type: String = str(effect.get("type", ""))

	if is_success:
		var success_templates: Array[String] = [
			"Votre decision de %s porte ses fruits." % verb,
			"Vous reussissez a %s avec brio." % verb,
			"%s — un choix qui s'avere payant." % label,
			"Merlin sourit. Votre %s etait le bon choix." % verb,
		]
		var idx: int = (verb + label).hash() % success_templates.size()
		if idx < 0:
			idx = -idx % success_templates.size()
		var text: String = success_templates[idx]
		if effect_type == "HEAL_LIFE":
			text += " Vous recuperez de la vigueur."
		elif effect_type == "ADD_KARMA":
			text += " L'equilibre karmique penche en votre faveur."
		elif effect_type == "ADD_ANAM":
			text += " L'Anam afflue en vous, memoire des ancetres."
		return text
	else:
		var failure_templates: Array[String] = [
			"Malgre vos efforts, %s echoue." % verb,
			"Le destin en decide autrement — %s ne suffit pas." % verb,
			"%s — les consequences sont immediates." % label,
			"Merlin grimace. Ce n'etait pas le bon moment pour %s." % verb,
		]
		var fidx: int = (verb + label).hash() % failure_templates.size()
		if fidx < 0:
			fidx = -fidx % failure_templates.size()
		var text: String = failure_templates[fidx]
		if effect_type == "DAMAGE_LIFE":
			text += " La douleur se fait sentir."
		elif effect_type == "HEAL_LIFE":
			text += " L'esperance de guerison s'evanouit."
		return text


## Extract choice labels with verb + description from LLM free text output.
## Returns Array[Dictionary] with {verb: "AVANCER", desc: "Tu franchis..."}.
## Handles formats: "A) VERBE — desc", "A) verbe - desc", "A) verbe", etc.
## Pre-split step in sanitize_and_extract() ensures inline choices are on separate lines.
func extract_labels_from_text(text: String) -> Array[Dictionary]:
	var labels: Array[Dictionary] = []
	var rx := RegEx.new()

	# Broad pattern covering all known 1.5B output formats (A-D supported):
	# Handles: A) text, 1. text, 1 - A) text, **1 - A** text, 1 - text, - text
	rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Le\\s+choix\\s+|Action\\s+|Choix\\s+)?[A-D][):.\\]]\\s*:?|[1-4]\\s*[-.]\\s*(?:[A-D][):.\\]]\\s*:?\\s*)?|[1-4][.)]|[-*])\\*{0,2}[:\\s]+(.*)")
	var matches := rx.search_all(text)
	for m in matches:
		var raw_label := m.get_string(1).strip_edges()
		# Strip markdown bold markers
		raw_label = raw_label.replace("**", "").replace("*", "").strip_edges()
		# Accept empty labels (e.g. bare "B)") — they will be rejected by validation below
		if raw_label.length() > 200:
			continue

		# Try to split "VERBE — description" or "VERBE - description" or "VERBE : description"
		var split_data := split_verb_desc(raw_label)
		# Accept any non-empty verb (trust LLM creativity, no whitelist)
		var v: String = str(split_data.get("verb", "")).strip_edges()
		if not v.is_empty() and v.length() <= 20:
			# Normalize: keep only first word as verb
			var sp := v.find(" ")
			if sp > 0:
				v = v.substr(0, sp)
			# Reject determinants/prepositions (not verbs — indicates paragraph start, not choice)
			var v_upper := v.to_upper()
			# Also reject very short strings and strings with punctuation (garbage)
			if v_upper.length() < 3:
				print("[LlmAdapterTextSanitizer] Rejected too-short verb: '%s'" % v)
				continue
			# Reject quoted/punctuation-heavy strings
			if v.begins_with("\"") or v.begins_with("'") or v.begins_with("("):
				print("[LlmAdapterTextSanitizer] Rejected punctuation verb: '%s'" % v)
				continue
			if v_upper in ["LE", "LA", "LES", "UN", "UNE", "DES", "AU", "AUX",
					"DU", "DANS", "SUR", "SOUS", "PAR", "POUR", "VERS", "AVEC",
					"CE", "CET", "CETTE", "CES", "MON", "TON", "SON", "IL", "ELLE",
					"EN", "ET", "OU", "DE", "A", "Y", "QUI", "QUE", "DONT",
					# Conjunctions (not verbs — observed: "Puisque" extracted as verb)
					"PUISQUE", "CAR", "MAIS", "DONC", "OR", "NI",
					"QUAND", "LORSQUE", "SI", "COMME", "BIEN",
					"CEPENDANT", "TOUTEFOIS", "NEANMOINS", "ALORS",
					"PUIS", "AUSSI", "SURTOUT", "DEJA", "ENCORE",
					# Demonstratives / misc non-verbs
					"TOUT", "TOUS", "TOUTE", "TOUTES", "RIEN",
					"CHAQUE", "NOTRE", "VOTRE", "LEUR", "LEURS",
					"NOS", "VOS", "MES", "TES", "SES",
					# Non-action verbs / copulas
					"C'EST", "EST", "SONT", "ETRE", "AVOIR", "FAIT", "VA",
					# Question words (observed: "comment" extracted as verb)
					"COMMENT", "POURQUOI", "COMBIEN", "QUOI",
					# Proper nouns from game context
					"MERLIN", "ARTHUR", "MORGANE", "VIVIANE", "NIMUE",
					"BROCELIANDE", "CARNAC", "BRETAGNE",
					# Common non-verb nouns frequently extracted
					"TORCHE", "AUDACIEUX", "SOMBRE", "ANCIEN",
					"SITUATION", "SCENARIO", "DESCRIPTION"]:
				print("[LlmAdapterTextSanitizer] Rejected determinant as verb: '%s'" % v)
				continue
			# Reject only the 3 most overused verbs from Qwen 1.5B (cause 30%+ repetition).
			# All other verbs are accepted — LLM creativity over pool conformity.
			# FUIR, SUIVRE, CHERCHER, REGARDER etc. removed: used with enough variety.
			if v_upper in ["AVANCER", "OBSERVER", "CONTINUER"]:
				print("[LlmAdapterTextSanitizer] Rejected overused verb (top-3 Qwen 1.5B): '%s'" % v)
				continue
			labels.append({"verb": v_upper, "desc": str(split_data.get("desc", ""))})
		else:
			print("[LlmAdapterTextSanitizer] Rejected verb (empty or too long): '%s'" % v)

	# Fallback patterns when main regex finds fewer than 3 labels.
	# Handles Qwen 1.5B output formats not covered by the primary pattern.
	if labels.size() < 3:
		var rx_fallback := RegEx.new()
		# Pattern 1: markdown bold headers — **Choix A**: text | **Option 1**: text
		rx_fallback.compile("(?m)^\\s*\\*{1,2}(?:Choix|Option|Action)\\s*[A-D1-4]\\*{0,2}[:\\s]+\\*{0,2}(.*?)\\*{0,2}$")
		for m in rx_fallback.search_all(text):
			if labels.size() >= 3:
				break
			var raw: String = m.get_string(1).strip_edges().replace("**", "").replace("*", "").strip_edges()
			if raw.length() >= 2 and raw.length() <= 200:
				var sd := split_verb_desc(raw)
				var fv: String = str(sd.get("verb", "")).strip_edges()
				if not fv.is_empty() and fv.length() <= 20:
					labels.append({"verb": fv.to_upper(), "desc": str(sd.get("desc", ""))})
					print("[LlmAdapterTextSanitizer] Fallback bold-header label: '%s'" % fv)
		# Pattern 2: bullet lines — lines starting with - / * / > followed by content
		if labels.size() < 3:
			var rx_bullet := RegEx.new()
			rx_bullet.compile("(?m)^\\s*[-*>]\\s+(\\S[^\\n]{1,198})")
			for m in rx_bullet.search_all(text):
				if labels.size() >= 3:
					break
				var raw: String = m.get_string(1).strip_edges().replace("**", "").replace("*", "").strip_edges()
				if raw.length() >= 2:
					var sd := split_verb_desc(raw)
					var fv: String = str(sd.get("verb", "")).strip_edges()
					if not fv.is_empty() and fv.length() <= 20:
						labels.append({"verb": fv.to_upper(), "desc": str(sd.get("desc", ""))})
						print("[LlmAdapterTextSanitizer] Fallback bullet label: '%s'" % fv)

	# Limit to 3 labels (game uses 3 choices: Left/Center/Right)
	if labels.size() > 3:
		labels.resize(3)

	return labels


## Relaxed verb extraction: find French infinitive verbs from unstructured text.
## Used as last-resort fallback when extract_labels_from_text finds nothing.
## Looks for words ending in -er, -ir, -re that are likely infinitive verbs.
func extract_verbs_relaxed(text: String) -> Array[Dictionary]:
	var labels: Array[Dictionary] = []
	var rx := RegEx.new()
	# Match words that look like French infinitive verbs (capitalized or not)
	# Exclude common non-verb -er words: dernier, premier, cahier, etc.
	rx.compile("(?i)\\b([A-ZÀ-Ÿa-zà-ÿ]{3,15}(?:er|ir|re))\\b")
	var seen: Dictionary = {}
	for m in rx.search_all(text):
		var word: String = m.get_string(1).strip_edges()
		var upper: String = word.to_upper()
		# Skip common non-verb words ending in -er/-ir/-re
		if upper in ["DERNIER", "PREMIER", "ENTIER", "CAHIER", "SENTIER",
				"DERRIERE", "PIERRE", "LUMIERE", "MATIERE", "RIVIERE",
				"PRIERE", "MANIERE", "SORCIERE", "CLAIRIERE", "POUSSIERE",
				"FIER", "CHER", "CHAIR", "HIER", "HIVER",
				"PLAISIR", "DESIR", "AVENIR", "SOUVENIR",
				"DIRE", "FAIRE", "ETRE", "AVOIR", "OUTRE", "ENTRE", "CONTRE"]:
			continue
		if upper in seen:
			continue
		seen[upper] = true
		var desc := ""
		# Try to grab text after the verb on the same line
		var verb_pos: int = text.findn(word)
		if verb_pos >= 0:
			var line_end: int = text.find("\n", verb_pos)
			if line_end < 0:
				line_end = text.length()
			var after: String = text.substr(verb_pos + word.length(), line_end - verb_pos - word.length()).strip_edges()
			# Strip leading separators
			if after.begins_with("—") or after.begins_with("-") or after.begins_with(":"):
				after = after.substr(1).strip_edges()
			if after.length() >= 3 and after.length() <= 150:
				desc = after
		labels.append({"verb": upper, "desc": desc})
		if labels.size() >= 3:
			break
	if labels.size() > 0:
		print("[LlmAdapterTextSanitizer] Relaxed extraction found %d verbs" % labels.size())
	return labels


## Split a raw label into verb + description.
## Handles: "AVANCER — Tu franchis...", "Avancer - desc", "Avancer", "avancer"
func split_verb_desc(raw: String) -> Dictionary:
	# Try em-dash first, then regular dash, then colon
	for sep in [" — ", " – ", " - ", " : "]:
		var idx := raw.find(sep)
		if idx > 0 and idx < raw.length() - 3:
			var verb := raw.substr(0, idx).strip_edges()
			var desc := raw.substr(idx + sep.length()).strip_edges()
			if verb.length() >= 2 and verb.length() <= 30:
				return {"verb": verb.to_upper(), "desc": desc}

	# No separator found — whole string is verb (old format)
	var verb_only := raw.strip_edges()
	# Capitalize if it looks like a single verb (no spaces or short phrase)
	if verb_only.find(" ") < 0 or verb_only.length() < 20:
		return {"verb": verb_only.to_upper(), "desc": ""}
	# Long phrase without separator — use first word as verb
	var first_space := verb_only.find(" ")
	if first_space > 0:
		return {"verb": verb_only.substr(0, first_space).to_upper(), "desc": verb_only.substr(first_space + 1)}
	return {"verb": verb_only.to_upper(), "desc": ""}


## Get flat array of all unique verbs across all pools (SAFE + FRAGILE + CRITICAL).
func get_all_pool_verbs() -> Array[String]:
	var all_verbs: Array[String] = []
	for pool in [MerlinLlmAdapter.VERB_POOL_SAFE, MerlinLlmAdapter.VERB_POOL_FRAGILE, MerlinLlmAdapter.VERB_POOL_CRITICAL]:
		for triplet in pool:
			for v in triplet:
				var upper_v: String = str(v).to_upper()
				if upper_v not in all_verbs:
					all_verbs.append(upper_v)
	return all_verbs


## Check whether a label verb is in a pre-defined pool (analytics only).
## PRINCIPLE: LLM creativity over pool conformity.
## This function must NOT be used to gate label acceptance.
func validate_single_verb(label: Dictionary) -> bool:
	var verb: String = str(label.get("verb", "")).strip_edges().to_upper()
	if verb.is_empty():
		return false
	# Take only first word
	var space_idx := verb.find(" ")
	if space_idx > 0:
		verb = verb.substr(0, space_idx)
	var all_verbs := get_all_pool_verbs()
	var in_pool: bool = verb in all_verbs
	# Analytics log only — never use the return value to reject a label
	if not in_pool:
		print("[LlmAdapterTextSanitizer] Analytics: verb not in pools (creative): '%s'" % verb)
	return in_pool


## Strip meta-commentary and prompt leakage from raw LLM text.
## Returns cleaned text with choice markers pre-split onto separate lines.
func strip_meta_and_leakage(text: String) -> String:
	# Step 0: Pre-split inline choice markers into separate lines.
	var presplit_rx := RegEx.new()
	presplit_rx.compile("([.!?\"'\\)])\\s+([A-D1-4]\\)\\s)")
	text = presplit_rx.sub(text, "$1\n$2", true)
	var colon_presplit_rx := RegEx.new()
	colon_presplit_rx.compile("([:])\\s+([1-4]\\)\\s)")
	text = colon_presplit_rx.sub(text, "$1\n$2", true)

	# Step 1: Strip meta-commentary and prompt leakage lines
	var meta_words := ["choisissez", "cliquez", "cette carte", "le joueur", "choose", "click",
		"select an option", "options possibles", "voici trois", "voici les", "voici 3",
		"scene narrative", "ecrivez la scene", "ecris la scene", "format obligatoire",
		"verbe a l'infinitif", "verbe + complement", "verbes :", "[verbe",
		"style obligatoire", "regle stricte", "couplet", "cheminement:",
		"choix (verbes", "options (verbes",
		"choix a)", "choix b)", "choix c)", "choix a )", "choix b )", "choix c )",
		"format:", "style:", "complement", "infinitif", "majuscules",
		"tiret long", "2e personne", "exactement 3", "4-6 phrases",
		"en majuscules", "verbe en", "mini-jeu:",
		"chose a considerer", "choses a considerer",
		"le contexte indique", "contexte indique",
		"le joueur doit", "il faut que le joueur",
		"instructions:", "consignes:", "note:",
		"l'homme est en", "la situation est",
		"carte ambiante basee", "basee sur le scenario", "base sur le scenario",
		"voici une carte ambiante", "voici la carte ambiante",
		"programmation", "mauvaise programmation", "correction",
		"correctement fournie", "je m'excuse", "je suis desole",
		"en tant qu'ia", "en tant qu'intelligence", "bug", "debug",
		"code source", "cette reponse", "cette generation",
		"defaut de generation", "erreur de generation",
		"je ne peux pas", "je suis un modele", "je suis une ia",
		"jamais de meta", "jamais de commentaire", "pas de meta",
		"un seul mot", "a l'infinitif", "suggestions de verbes", "chaque verbe",
		"narre au present", "francais uniquement", "ton celtique",
		"vocabulaire celtique", "sensations du voyageur", "pas de dialogue",
		"verbe seul", "un mot", "trois lignes", "3 lignes",
		"3-4 phrases", "meta-commentaire",
		"je vais tenter", "je suis sur que", "j'ai deja vu",
		"vision poetique", "servir a ta cause", "visuelle que narrative",
		"aussi bien visuelle", "narration", "voici l'histoire",
		"voici le scenario", "voici une scene",
		"champs d'environnement", "champs d'", "environnement",
		"1 - a", "2 - b", "3 - c", "1- a", "2- b", "3- c",
		"option a", "option b", "option c",
		"choisis parmi", "choisis une",
		"voici la carte", "carte a explorer", "carte que tu as",
		"voici le texte", "voici les choix", "voici ta",
		"voici ton", "voici l'aventure",
		"voici mes choix", "mes choix :", "voici mes", "mes options",
		"voici tes choix", "tes choix :", "voici tes options",
		"les choix sont", "les options sont", "tu peux choisir",
		"decrochez le choix", "decrocher le choix", "choisir entre",
		"(a)", "(b)", "(c)", "chaudron de",
		"tendres choix", "(a/b/c)", "a/b/c"]
	var cleaned_lines: Array[String] = []
	for line in text.split("\n"):
		var lower := line.strip_edges().to_lower()
		if lower.is_empty():
			continue
		var is_meta := false
		for mw in meta_words:
			if lower.find(mw) >= 0:
				is_meta = true
				break
		# Also strip lines that are just labels like "A1)", "C3)", "1 -" at start
		if not is_meta:
			var label_only_rx := RegEx.new()
			label_only_rx.compile("^\\s*[a-dA-D]\\d\\)\\s*$")
			if label_only_rx.search(lower):
				is_meta = true
		# Strip short lines ending with colon (meta-text headers like "Voici mes choix :")
		if not is_meta and lower.ends_with(":") and lower.length() < 40:
			is_meta = true
		if not is_meta:
			cleaned_lines.append(line)
	text = "\n".join(cleaned_lines).strip_edges()

	# Step 1.5: Strip inline prompt leakage fragments (any bracketed content 2+ chars)
	var leak_rx := RegEx.new()
	leak_rx.compile("\\[[^\\]]{2,}\\]")
	text = leak_rx.sub(text, "", true).strip_edges()

	# Step 1.6: Strip self-referential AI sentences
	var self_ref_patterns := ["je m'excuse", "je suis desole", "en tant qu'ia",
		"en tant qu'intelligence artificielle", "je ne suis qu'un",
		"cette reponse", "cette generation", "mauvaise programmation"]
	var sr_cleaned: Array[String] = []
	for sr_line in text.split("\n"):
		var sr_lower := sr_line.strip_edges().to_lower()
		var sr_skip := false
		for srp in self_ref_patterns:
			if sr_lower.find(srp) >= 0:
				sr_skip = true
				break
		if not sr_skip:
			sr_cleaned.append(sr_line)
	text = "\n".join(sr_cleaned).strip_edges()

	return text


## Remove all choice/option lines from the narrative text.
func strip_choice_lines(text: String) -> String:
	var choice_rx := RegEx.new()
	choice_rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Le\\s+choix\\s+|Action\\s+|Choix\\s+)?[A-D][):.\\]]|[1-3]\\s*[-.]\\s*[A-D]?[):.\\s]|[1-3][.):]|[-*]\\s+\\*{0,2}[A-D][):.\\]]).*$")
	return choice_rx.sub(text, "", true)


## Strip "Scenario:" / "Situation:" echo from first 2 lines.
func strip_scenario_echo(text: String) -> String:
	var raw_lines := text.split("\n")
	if raw_lines.size() > 0:
		for si in mini(raw_lines.size(), 2):
			var sl := raw_lines[si].strip_edges().to_lower()
			if (sl.begins_with("scenario") or sl.begins_with("situation")) and (sl.find(":") >= 0 or sl.find(" :") >= 0):
				var colon_pos: int = sl.find(":")
				var after_colon: String = raw_lines[si].substr(colon_pos + 1).strip_edges()
				raw_lines[si] = after_colon
		text = "\n".join(raw_lines)
	return text


## Strip markdown artifacts (bold, headers, horizontal rules).
func strip_markdown(text: String) -> String:
	text = text.replace("**", "").replace("*", "")
	var md_cleaned: Array[String] = []
	for md_line in text.split("\n"):
		var trimmed := md_line.strip_edges()
		if trimmed.begins_with("###") or trimmed.begins_with("---"):
			var content := trimmed.trim_prefix("####").trim_prefix("###").strip_edges()
			if not content.is_empty():
				md_cleaned.append(content)
		else:
			md_cleaned.append(md_line)
	text = "\n".join(md_cleaned)

	# Strip short header-like lines (1-3 words, no narrative verb)
	var narrative_lines: Array[String] = []
	var header_rx := RegEx.new()
	header_rx.compile("^[\\p{Lu}][\\p{Ll}']+(?:\\s+[\\p{L}']+){0,2}\\s*:?$")
	for nl in text.split("\n"):
		var nt := nl.strip_edges()
		if not nt.is_empty() and nt.length() < 40 and header_rx.search(nt):
			continue
		narrative_lines.append(nl)
	return "\n".join(narrative_lines)


## Enforce text length: cap at ~350 chars, finishing at sentence boundary.
func enforce_length(text: String, max_chars: int = 350, min_cut: int = 120) -> String:
	text = text.strip_edges()
	if text.length() > max_chars:
		var cut_pos := max_chars
		for sep in [".", "!", "?"]:
			var idx := text.rfind(sep, max_chars)
			if idx > min_cut:
				cut_pos = idx + 1
				break
		text = text.substr(0, cut_pos).strip_edges()
	return text


## Replace wrong person pronouns with "tu" (2nd person).
func enforce_pronouns(text: String) -> String:
	var pronoun_fixes := [
		# nous/notre/nos → tu/ton/tes
		["nos pieds", "tes pieds"], ["nos yeux", "tes yeux"], ["nos mains", "tes mains"],
		["notre chemin", "ton chemin"], ["notre route", "ta route"], ["notre quete", "ta quete"],
		[" nos ", " tes "], [" notre ", " ton "],
		[" nous ", " tu "], ["Nous ", "Tu "],
		# 3rd person il/elle → tu (sentence-start patterns)
		["Il tourne ", "Tu tournes "], ["Il marche ", "Tu marches "],
		["Il entre ", "Tu entres "], ["Il avance ", "Tu avances "],
		["Il decouvre ", "Tu decouvres "], ["Il entend ", "Tu entends "],
		["Il sent ", "Tu sens "], ["Il voit ", "Tu vois "],
		["Il aperçoit ", "Tu aperçois "], ["Il s'approche ", "Tu t'approches "],
		["Il se retrouve ", "Tu te retrouves "], ["Il se penche ", "Tu te penches "],
		["Il fut ", "Tu fus "], ["Il était ", "Tu étais "],
		# "Le voyageur" → "Tu" (common 3rd person pattern)
		["Le voyageur ", "Tu "], ["le voyageur ", "tu "],
		# 1st person je → tu
		["Je suis ", "Tu es "], ["Je vois ", "Tu vois "],
		["Je sens ", "Tu sens "], ["Je marche ", "Tu marches "],
		["J'entends ", "Tu entends "], ["J'aperçois ", "Tu aperçois "],
		["Je decouvre ", "Tu decouvres "], ["Je m'approche ", "Tu t'approches "],
	]
	for fix in pronoun_fixes:
		text = text.replace(str(fix[0]), str(fix[1]))
	# Also strip "Il était une fois" fairy tale opening
	if text.begins_with("Il était une fois"):
		text = text.substr(text.find(".") + 1).strip_edges()
		if not text.begins_with("Tu"):
			text = "Tu " + text.substr(0, 1).to_lower() + text.substr(1)
	return text
