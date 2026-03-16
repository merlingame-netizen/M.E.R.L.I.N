## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — Card Generation Module
## ═══════════════════════════════════════════════════════════════════════════════
## Pre-run card generation via LLM, text processing, meta-text stripping,
## person conversion, and card saving.
## ═══════════════════════════════════════════════════════════════════════════════

class_name TransitionBiomeCards
extends RefCounted

const PRERUN_CARD_COUNT := 5
const PRERUN_CARDS_PATH := "user://temp_run_cards.json"

var _weather_module: TransitionBiomeWeather


func _init(weather_mod: TransitionBiomeWeather) -> void:
	_weather_module = weather_mod


func generate_prerun_card(index: int, merlin_ai: Node, biome_data: Dictionary, biome_key: String) -> Dictionary:
	## Generate one pre-run card via LLM only. Returns {} if LLM unavailable.
	if not merlin_ai or not merlin_ai.get("is_ready") or not merlin_ai.has_method("generate_with_system"):
		print("[TransitionBiome] LLM unavailable for card %d" % index)
		return {}
	var card: Dictionary = await _try_llm_prerun_card(index, merlin_ai, biome_data, biome_key)
	if not card.is_empty():
		return card
	# Retry once after brief delay
	await merlin_ai.get_tree().create_timer(0.5).timeout
	card = await _try_llm_prerun_card(index, merlin_ai, biome_data, biome_key)
	return card


func _try_llm_prerun_card(index: int, merlin_ai: Node, biome_data: Dictionary, biome_key: String) -> Dictionary:
	var biome_name: String = str(biome_data.get("name", "Broceliande"))

	var arc_roles: Array[String] = [
		"INTRODUCTION: Etablis le lieu, le danger et l'atmosphere. Le voyageur decouvre le biome.",
		"EXPLORATION: Le voyageur explore, la tension monte. Un indice subtil apparait.",
		"COMPLICATION: Un obstacle majeur se dresse. La situation se complexifie.",
		"CLIMAX: Le moment critique. Le choix du voyageur a des consequences lourdes.",
		"RETOURNEMENT: Une revelation inattendue. Rien n'est ce qu'il semblait etre.",
	]
	var arc_role: String = arc_roles[mini(index, arc_roles.size() - 1)]

	var system_prompt := (
		"Narration 2e personne (tu). Present. Francais. Foret celtique.\n"
		+ "INTERDIT: 'je suis', description du lieu, geographie, meta-commentaire.\n"
		+ "Decris ce que tu SENS: odeurs, sons, toucher, lumiere.\n"
		+ "La mousse craque sous tes pas. L'odeur de terre humide envahit tes narines.\n"
		+ "A) Avancer vers la lumiere\nB) Ecouter le murmure\nC) Reculer dans l'ombre"
	)
	var user_prompt := "%s en %s. Sensations (tu), 3-4 phrases, puis A) B) C) verbe." % [arc_role.split(":")[0], biome_name]

	var params := {"max_tokens": 200, "temperature": 0.7 + index * 0.02}
	var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, user_prompt, params)

	if result.has("error") or str(result.get("text", "")).length() < 20:
		return {}

	var raw_text: String = str(result.get("text", ""))
	raw_text = strip_meta_text(raw_text)

	var labels: Array[String] = []
	var sequel_hooks: Array[String] = []
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[§\\-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-Da-d]\\s*[):.\\]\\-/]|[1-4]\\s*[.)/])\\*{0,2}[:\\s]*(.+)")
	var matches := rx.search_all(raw_text)
	for m in matches:
		var full_label := m.get_string(1).strip_edges().replace("**", "").replace("*", "")
		if full_label.length() > 2 and full_label.length() < 120:
			var arrow_pos := full_label.find(" -> ")
			if arrow_pos > 0:
				labels.append(full_label.substr(0, arrow_pos).strip_edges())
				sequel_hooks.append(full_label.substr(arrow_pos + 4).strip_edges())
			else:
				labels.append(full_label)
				sequel_hooks.append("")

	var narrative := raw_text
	var rx_strip := RegEx.new()
	rx_strip.compile("(?m)^\\s*(?:[§\\-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-Da-d]\\s*[):.\\]\\-/]|[1-9]\\s*[.)/\\-]).*$")
	narrative = rx_strip.sub(narrative, "", true).strip_edges()
	narrative = narrative.replace("(tu)", "").replace("§", "")
	var rx_bare := RegEx.new()
	rx_bare.compile("(?m)^\\s*[A-C]\\s{1,3}[A-Z].*$")
	narrative = rx_bare.sub(narrative, "", true).strip_edges()
	var rx_inline := RegEx.new()
	rx_inline.compile("\\s[1-3]\\s*[/)]\\s*[A-Z][^.!?]{3,60}(?=[\\s.!?]|$)")
	narrative = rx_inline.sub(narrative, "", true).strip_edges()
	var rx_inline_abc := RegEx.new()
	rx_inline_abc.compile("\\s[A-C]\\)\\s*[A-Z][^.!?]{3,60}(?=[\\s.!?]|$)")
	narrative = rx_inline_abc.sub(narrative, "", true).strip_edges()
	var rx_dash_dialogue := RegEx.new()
	rx_dash_dialogue.compile("(?m)^\\s*-\\s*[\"'].*$")
	narrative = rx_dash_dialogue.sub(narrative, "", true).strip_edges()
	while narrative.contains("\n\n\n"):
		narrative = narrative.replace("\n\n\n", "\n\n")
	while narrative.contains("\n\n"):
		narrative = narrative.replace("\n\n", "\n")

	narrative = convert_first_to_second_person(narrative)

	var safe_labels: Array[String] = _filter_safe_labels(labels)
	labels = safe_labels

	if labels.size() < 3 or labels.count("") > 0:
		var fallback_pool: Array = [
			[tr("FALLBACK_CAUTIOUS"), tr("FALLBACK_OBSERVE"), tr("FALLBACK_ACT")],
			["Chercher un indice", "Attendre patiemment", "Invoquer les esprits"],
			["Escalader le rocher", "Contourner l'obstacle", "Briser le sceau"],
			["Negocier avec l'ombre", "Defier le gardien", "Fuir vers la clairiere"],
			["Toucher la rune", "Ecouter le vent", "Suivre le corbeau"],
		]
		var fb_triplet: Array = fallback_pool[mini(index, fallback_pool.size() - 1)]
		for fi in range(3):
			if fi >= labels.size():
				labels.append(fb_triplet[fi])
			elif labels[fi].is_empty():
				labels[fi] = fb_triplet[fi]
		if sequel_hooks.size() < 3:
			sequel_hooks = ["La prudence sera recompensee", "Le silence revele des secrets", "L'audace attire l'attention"]

	var base_amt: int = 3 + index
	var effect_pool: Array = [
		[{"type": "HEAL_LIFE", "amount": base_amt}],
		[{"type": "ADD_KARMA", "amount": clampi(base_amt / 2, 1, 3)}],
		[{"type": "DAMAGE_LIFE", "amount": base_amt}],
	]
	if index >= 3:
		effect_pool[2] = [{"type": "PROGRESS_MISSION", "step": 1}]

	var dc_hints: Array = [
		{"min": 4, "max": 8},
		{"min": 7, "max": 12},
		{"min": 10, "max": 16},
	]
	var risk_levels: Array[String] = ["faible", "moyen", "eleve"]

	var options: Array = []
	for j in range(3):
		var hook: String = sequel_hooks[j] if j < sequel_hooks.size() else ""
		var label_text: String = labels[j] if j < labels.size() else "Choix %d" % (j + 1)
		var opt: Dictionary = {
			"label": label_text,
			"effects": effect_pool[j],
			"sequel_hook": hook,
			"dc_hint": dc_hints[j],
			"risk_level": risk_levels[j],
			"result_success": "Votre %s s'avere payant." % label_text.split(" ")[0].to_lower(),
			"result_failure": "Malgre vos efforts, %s ne suffit pas." % label_text.split(" ")[0].to_lower(),
		}
		if j == 1:
			opt["cost"] = 1
		options.append(opt)

	var arc_phase: String = ["intro", "exploration", "complication", "climax", "twist"][mini(index, 4)]
	var arc_titles: Array[String] = ["L'Eveil du Sentier", "Echos dans la Brume", "Le Seuil de l'Ombre", "L'Heure du Choix", "Retournement du Destin"]
	var title: String = arc_titles[mini(index, 4)]

	var biome_vtags: Dictionary = {
		"broceliande": ["foret", "arbre", "mousse", "lumiere_filtree"],
		"landes": ["bruyere", "menhir", "vent", "horizon"],
		"cotes": ["falaise", "vague", "goeland", "embruns"],
		"villages": ["chaumiere", "chemin", "fumee", "pierre"],
		"cercles": ["menhir", "rune", "brume", "lune"],
		"marais": ["eau_sombre", "jonc", "brume", "luciole"],
		"collines": ["colline", "dolmen", "vent", "ciel"],
	}
	var biome_atags: Dictionary = {
		"broceliande": ["vent_feuillage", "oiseau"],
		"landes": ["vent_fort", "grillon"],
		"cotes": ["vagues", "vent_marin"],
		"villages": ["feu_craquement", "cloche"],
		"cercles": ["silence", "bourdonnement"],
		"marais": ["eau_clapotis", "grenouille"],
		"collines": ["vent_doux", "aigle"],
	}
	var vtags: Array = biome_vtags.get(biome_key, ["foret", "sentier"])
	var atags: Array = biome_atags.get(biome_key, ["vent_feuillage"])

	return {
		"id": "prerun_%d" % index,
		"title": title,
		"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 300)),
		"speaker": "Merlin",
		"type": "narrative",
		"biome": biome_key,
		"season": _weather_module.get_current_season(),
		"options": options,
		"visual_tags": vtags,
		"audio_tags": atags,
		"card_position": index + 1,
		"arc_phase": arc_phase,
		"result_success": "Le choix porte ses fruits, la foret repond a ton audace.",
		"result_failure": "Le sentier se referme, les ombres grondent autour de toi.",
		"tags": ["prerun", "llm_generated"],
	}


func _filter_safe_labels(labels: Array[String]) -> Array[String]:
	var reject_words: Array[String] = [
		"LA", "LE", "LES", "UN", "UNE", "DES", "VOTRE", "NOTRE", "SON", "SA", "SES",
		"JE", "TU", "IL", "ELLE", "NOUS", "VOUS", "ILS", "ELLES", "MON", "MA", "MES",
		"CE", "CET", "CETTE", "CES", "QUI", "QUE", "QUOI", "MERLIN",
		"CEST", "AVEC", "DANS", "POUR", "VERS", "ENTRE", "MAIS", "DONC",
		"CONTINUE", "CHOISI", "CHOISIS", "JUSQUAU", "JUSQUA",
		"PRISE", "VUE", "PLACE", "FIN", "LIEU", "VOIX",
		"VOULEZ", "CROYEZ", "DEVEZ", "POUVEZ", "SAVEZ",
	]
	var reject_suffixes: Array[String] = [
		"ANT", "ANTE", "ANTS",
		"IQUE", "IQUES",
		"TION", "TIONS",
		"MENT", "MENTS",
		"ENCE", "ENCES",
		"ISTE", "ISTES",
	]
	var safe_labels: Array[String] = []
	for lbl in labels:
		var clean_lbl := lbl.replace("\"", "").replace("'", "").strip_edges()
		var fw_raw: String = clean_lbl.split(" ", false)[0] if not clean_lbl.is_empty() else ""
		var first_word: String = fw_raw.split("'")[0] if "'" in fw_raw else fw_raw
		first_word = first_word.replace(")", "").replace("(", "").replace("-", "").strip_edges()
		var fw_full: String = fw_raw.replace(")", "").replace("(", "").replace("-", "").replace("'", "").strip_edges()
		var looks_merged: bool = fw_full.length() > 5 and (fw_full.begins_with("L") or fw_full.begins_with("D")) and not " " in clean_lbl.substr(0, 4)
		var has_bad_suffix: bool = false
		for suf in reject_suffixes:
			if fw_full.to_upper().ends_with(suf) and fw_full.length() > suf.length() + 2:
				has_bad_suffix = true
				break
		var is_bad: bool = (
			first_word.length() < 3
			or first_word.to_upper() in reject_words
			or fw_full.to_upper() in reject_words
			or looks_merged
			or has_bad_suffix
			or clean_lbl.begins_with("\"")
			or clean_lbl.begins_with("'")
			or "je suis" in clean_lbl.to_lower()
			or "merlin" in clean_lbl.to_lower()
			or "option" in clean_lbl.to_lower()
			or "tu as choisi" in clean_lbl.to_lower()
			or "tu choisis" in clean_lbl.to_lower()
			or " est " in clean_lbl.to_lower()
			or " sont " in clean_lbl.to_lower()
		)
		if is_bad:
			safe_labels.append("")
		else:
			if clean_lbl.length() > 45:
				var truncate_pos := clean_lbl.find(".", 5)
				if truncate_pos < 0 or truncate_pos > 45:
					truncate_pos = clean_lbl.find(",", 5)
				if truncate_pos > 5 and truncate_pos <= 45:
					clean_lbl = clean_lbl.substr(0, truncate_pos).strip_edges()
				else:
					clean_lbl = clean_lbl.substr(0, 40).strip_edges()
			safe_labels.append(clean_lbl)
	return safe_labels


func save_prerun_cards(cards: Array) -> void:
	if cards.is_empty():
		return
	var file := FileAccess.open(PRERUN_CARDS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cards, "\t"))
		file.close()
		print("[TransitionBiome] Saved %d pre-generated cards to %s" % [cards.size(), PRERUN_CARDS_PATH])


# ═══════════════════════════════════════════════════════════════════════════════
# TEXT PROCESSING — Meta-text stripping + person conversion
# ═══════════════════════════════════════════════════════════════════════════════

func strip_meta_text(text: String) -> String:
	var meta_words: Array[String] = [
		"decrochez le choix", "decrocher le choix", "choisir entre",
		"(a)", "(b)", "(c)", "chaudron de", "tendres choix", "(a/b/c)", "a/b/c",
		"regle stricte", "meta-commentaire", "vocabulaire celtique",
		"ecris une scene", "3 choix", "biome:", "carte:", "role:",
		"action a)", "action b)", "action c)",
		"scene narrative", "phrases)", "villageois]",
		"trois options", "trois choix", "je vais te donner",
		"je suis merlin", "je suis le druide", "je suis un druide",
		"je suis une voix", "je suis un ancien", "je suis le gardien",
		"voici les choix", "voici trois", "voici les options",
		"reprendre la scene", "scene precedente",
		"voici une introduction", "introduction detaillee",
		"voici ta reponse", "voici la reponse", "voici le resultat",
		"je suis pret", "je suis prete",
		"merlin est un", "merlin est le",
		"tu as choisi", "tu choisis", "ta reponse",
		"avec une voix", "d'une voix",
		"ensemble nous formons", "formons un arc",
		"c'est une situation", "situation difficile",
		"narration:", "narrateur:", "scenario:",
		"la roche tremble", "un grondement sourd", "escalader la paroi",
		"invoquer la pierre", "fuir vers le vallon",
		"la mousse craque", "odeur de terre humide", "envahit tes narines",
		"avancer vers la lumiere", "ecouter le murmure", "reculer dans l'ombre",
		"voulez!", "croyez!", "devez!", "pouvez!",
		"le lieu est", "le parc national", "il y a environ",
		"heures de train", "nord-ouest", "nord-est", "pays-bas",
		"les aventures d'", "se deroulent les",
		"voici une description", "description ambiante", "description contextuelle",
		"basee sur le scenario", "que vous avez", "scenario detaille",
		"bienvenue dans", "bienvenue en", "bienvenu a",
		"le pays du nord", "ce voyageur est", "ce voyageur",
		"sert de catalyseur", "met l'accent sur", "complication suivante",
		"la suite de l'histoire", "dans cette scene", "cette carte",
		"cette situation sert", "voici une complication", "voici un",
		"ce passage montre", "ce moment revele", "cela introduit",
		"verbe :", "verbe:", "b/c)", "a/b)", "a) ", "b) ", "c) ",
		"a/ ", "b/ ", "c/ ", "a/'", "b/'", "c/'",
		"force:", "force :", "option a", "option b", "option c",
		"tu es merlin", "tu es le druide", "tu es un druide",
		"tu es l'enchanteur", "merlin l'enchanteur",
		"voici ta carte", "entierement generee", "informations fournies",
		"premiere scene", "deuxieme scene", "troisieme scene",
		"point de depart", "genere en fonction",
		"titre poetique", "action en 1 phrase", "vers de complication",
		"action differente", "tu puis ai", "equipe principale",
		"la complication est", "causee par", "causée par",
		"est causee par", "est causée par",
		"voici la suggestion", "suggestion du scenario",
		"theme ambiant", "thème ambiant", "tags appropries", "tags appropriés",
		"pour le biome", "carte ambiante pour",
		"jour 1 de ce voyage", "jour 2 de ce voyage", "jour 3 de ce voyage",
		"phrase finale", "phrase initiale", "phrase de transition",
		"saison spring", "saison summer", "saison autumn", "saison winter",
		"saison :", "séance:", "seance:", "séance :",
		"cette scene", "cette scène", "the scene is",
		"- voyage en", "- exploration de", "- complication",
		"scene 1", "scene 2", "scene 3", "scene 4", "scene 5",
		"in the forest", "in the mist", "in the cave",
		"carte ambiante", "carte narrative", "carte ambiance",
		"carte événement", "carte evenement", "carte merlin",
		"carte promesse", "ambient card", "narrative card",
	]
	var result := text
	var rx_etape := RegEx.new()
	rx_etape.compile("(?im)^\\s*(?:[eé]tape|scene|sc[eè]ne|acte|chapitre|séance)\\s*(?:\\d+\\s*[:\\-]?|[:\\-])\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx_etape.sub(result, "", true)
	var rx_arc := RegEx.new()
	rx_arc.compile("(?im)^\\s*(?:complication|climax|resolution|introduction|exploration|twist|epilogue|prologue|transition|aurore druidique)\\s*:?\\s*(?:[A-Z][^\\n]{0,40}\\n)?")
	result = rx_arc.sub(result, "", true)
	var rx_md := RegEx.new()
	rx_md.compile("\\*\\*[^*]{0,60}\\*\\*:?")
	result = rx_md.sub(result, "", true)
	var rx_sp := RegEx.new()
	rx_sp.compile("(?im)^\\s*(?:INT|EXT|int|ext)\\.\\s*[A-ZÀ-Ü ]{2,50}\\s*[-–—]\\s*[A-ZÀ-Ü ]{2,20}\\s*\\n?")
	result = rx_sp.sub(result, "", true)
	var rx_bs := RegEx.new()
	rx_bs.compile("(?m)^\\s*\\\\\\s*.+$")
	result = rx_bs.sub(result, "", true)
	for mw in meta_words:
		var pos := result.to_lower().find(mw)
		while pos >= 0:
			var line_start := result.rfind("\n", pos)
			var line_end := result.find("\n", pos)
			if line_start < 0: line_start = 0
			if line_end < 0: line_end = result.length()
			var candidate: String = result.substr(0, line_start) + result.substr(line_end)
			if candidate.strip_edges().length() < 10:
				var sent_start := pos
				for ch in [".", ":", ";", "!"]:
					var ss := result.rfind(ch, pos)
					if ss >= 0 and ss > line_start:
						sent_start = ss + 1
						break
				if sent_start == pos:
					sent_start = line_start
				var sent_end := result.length()
				for ch in [".", ":", ";", "!"]:
					var se := result.find(ch, pos + mw.length())
					if se >= 0 and se < sent_end:
						sent_end = se + 1
				result = result.substr(0, sent_start) + result.substr(sent_end)
			else:
				result = candidate
			pos = result.to_lower().find(mw)
	var rx_arrow := RegEx.new()
	rx_arrow.compile("(?m)→\\s*choix\\s*:\\s*[A-ZÀ-Ü]+")
	result = rx_arrow.sub(result, "", true)
	while result.contains("\n\n\n"):
		result = result.replace("\n\n\n", "\n\n")
	return result.strip_edges()


func convert_first_to_second_person(text: String) -> String:
	var result := text
	var rx := RegEx.new()

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
	rx.compile("(?i)\\btu n'ai\\b")
	result = rx.sub(result, "tu n'as", true)
	rx.compile("(?i)\\btu ai\\b")
	result = rx.sub(result, "tu as", true)
	rx.compile("(?m)^tu\\b")
	result = rx.sub(result, "Tu", true)
	rx.compile("\\.\\s+tu\\b")
	var matches := rx.search_all(result)
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var matched_text: String = m.get_string()
		var capitalized: String = matched_text.substr(0, matched_text.length() - 2) + "Tu"
		result = result.substr(0, m.get_start()) + capitalized + result.substr(m.get_end())

	return result
