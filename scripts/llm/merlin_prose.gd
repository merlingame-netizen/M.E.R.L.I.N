class_name MerlinProse
extends RefCounted
## MerlinProse — boîte à outils de PROSE 100% PURE (extraction v10.13 Phase A4).
##
## Fonctions STATIQUES déplacées VERBATIM depuis merlin_scenario.gd (corps inchangés,
## renommées sans underscore). Aucune lecture d'autoload, de node ou d'état mutable :
## entrée → sortie, déterministe. → testable HORS-ARBRE (headless, sans scène ni LLM) :
##   MerlinProse.clean_prose("…"), MerlinProse.strip_scene_echo(prose, situ), etc.


# Coupe la prose à la dernière phrase COMPLÈTE : évite les troncatures mid-mot (« se dess… »)
# quand le modèle atteint le plafond de tokens, qui donnaient l'impression d'un blocage (user 2026-05-28).
static func clean_prose(s: String) -> String:
	var t: String = repair_accents(s.strip_edges())  # v11 (R156) : filet accents sur la prose LLM affichée
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
static func strip_scene_echo(prose: String, situation: String) -> String:
	if prose.is_empty() or situation.is_empty():
		return prose
	var situ_words: Dictionary = sig_words(situation)
	# Parmi les 3 PREMIERES phrases, retire celles qui CLONENT la situation (même paraphrasées, même
	# precedees d'une phrase de transition). Au-dela, on garde tout (le corps de l'issue). Robuste aux
	# paraphrases via recouvrement de mots significatifs (seuil 0.5).
	var sentences: Array = split_sentences(prose)
	var kept: Array = []
	for i in sentences.size():
		var s: String = str(sentences[i])
		if i < 3 and s.strip_edges().length() >= 12 and echo_ratio(s, situ_words) >= 0.5:
			continue  # clone de la situation → retiré
		kept.append(s)
	var p: String = " ".join(kept).strip_edges()
	# nettoie une ponctuation orpheline en tête (ex. « » » laissé par une phrase recopiée retirée)
	while p.length() > 0 and (" »\"',;:.!?-—".find(p[0]) != -1):
		p = p.substr(1)
	return p.strip_edges()


# Découpe un texte en phrases (sur . ! ? …), en conservant la ponctuation finale.
static func split_sentences(t: String) -> Array:
	var out: Array = []
	var cur: String = ""
	for i in t.length():
		var ch: String = t[i]
		cur += ch
		if ch == "." or ch == "!" or ch == "?" or ch == "…":
			out.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges().length() > 0:
		out.append(cur.strip_edges())
	return out


# Ensemble des mots significatifs (≥4 lettres) d'un texte, normalisés (minuscules, ponctuation → espace).
static func sig_words(t: String) -> Dictionary:
	var out: Dictionary = {}
	for w in norm(t).split(" ", false):
		if w.length() >= 4:
			out[w] = true
	return out


# Proportion des mots significatifs d'une phrase présents dans la situation (0.0–1.0).
static func echo_ratio(sentence: String, situ_words: Dictionary) -> float:
	var sig: int = 0
	var hit: int = 0
	for w in norm(sentence).split(" ", false):
		if w.length() >= 4:
			sig += 1
			if situ_words.has(w):
				hit += 1
	return float(hit) / float(max(sig, 1))


static func first_sentence(t: String) -> String:
	var s: String = t.strip_edges()
	for i in s.length():
		var ch: String = s[i]
		if ch == "." or ch == "!" or ch == "?" or ch == "…":
			return s.substr(0, i + 1)
	return s


# v11-N1 (R140) — garantit que l'ISSUE de résolution s'ouvre sur une ACTION en italique BBCode :
# la 1re phrase (le geste concret) est enveloppée dans [i]…[/i], le reste (la conséquence) reste
# hors italique. Robustesse : le prompt le DEMANDE, les fallbacks sont déjà à cette forme, mais Gemma
# peut oublier la balise → ce filet la pose. Balise déjà présente = respectée (juste équilibrée).
static func ensure_italic_action(s: String) -> String:
	var t: String = s.strip_edges()
	if t.is_empty():
		return t
	# Forme CORRECTE (ouvre en italique, exactement UNE paire fermée) → respectée telle quelle.
	if t.begins_with("[i]") and t.count("[i]") == 1 and t.count("[/i]") == 1:
		return t
	# Tout autre cas (aucune balise, balise mal placée en milieu de texte, non fermée, ou paires
	# multiples) → on NORMALISE : on retire toute balise puis on enveloppe la SEULE 1re phrase (le geste).
	# Robuste : jamais de span vide, jamais de balise déséquilibrée, jamais tout le bloc en italique.
	t = t.replace("[i]", "").replace("[/i]", "").strip_edges()
	if t.is_empty():
		return t
	var fs: String = first_sentence(t)
	if fs.strip_edges().length() < 4:
		return t  # pas de vraie phrase à isoler → laissé tel quel
	return "[i]" + fs.strip_edges() + "[/i]" + t.substr(fs.length())


static func norm(t: String) -> String:
	# minuscules + ponctuation → espace : comparaison par MOTS, robuste aux paraphrases.
	var s: String = t.strip_edges().to_lower()
	var out: String = ""
	for ch in s:
		if ch == " " or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ("àâäéèêëîïôöùûüçñ".find(ch) != -1):
			out += ch
		else:
			out += " "
	return out


# Extrait 5 étapes d'une réponse numérotée (« 1. … » … « 5. … »), sans regex. [] si format inattendu.
# `attendu` = combien de scènes on a demandées. Le défaut de 5 conserve le comportement des
# appelants historiques.
#
# LE PIÈGE, corrigé le 2026-08-18 : la dernière ligne exigeait CINQ étapes, sinon elle rendait un
# tableau VIDE. Quand l'arc s'est mis à s'écrire par tranches de quatre, le modèle produisait bien
# ses quatre scènes et le parseur les jetait — silencieusement, à chaque tentative. Constaté sur
# une partie : quatre générations d'arc lancées, quatre tableaux vides, zéro scène retenue.
#
# Désormais on rend ce qu'on a reçu, plafonné au nombre demandé. Une tranche incomplète n'est plus
# une perte totale : l'appelant avance du nombre de scènes REELLEMENT obtenues, donc rien ne se
# désaligne — les scènes manquantes repartent simplement dans la tranche suivante.
static func parse_arc(text: String, attendu: int = 5) -> Array:
	var out: Array = []
	for raw_line in text.split("\n"):
		var line: String = str(raw_line).strip_edges()
		if line.length() < 3:
			continue
		if not (line[0] >= "1" and line[0] <= "9"):
			continue  # une étape DOIT commencer par son numéro
		var i: int = 1
		while i < line.length() and line[i] in [".", ")", "-", ":", " ", "\t"]:
			i += 1
		var cleaned: String = clean_prose(line.substr(i).strip_edges())
		if cleaned.length() >= 12:
			out.append(cleaned)
	var n: int = maxi(1, attendu)
	return out.slice(0, n) if not out.is_empty() else []


# Garde uniquement les entrées {title, pitch} valides d'une sélection JSON extraite.
static func clean_selection(arr: Array) -> Array:
	var out: Array = []
	for item in arr:
		if item is Dictionary and item.has("title") and item.has("pitch"):
			# v11 (R156) : filet accents sur titre + pitch LLM (le pitch alimente aussi l'« ✦ Objectif »).
			var t: String = repair_accents(str(item["title"]).strip_edges())
			var p: String = repair_accents(str(item["pitch"]).strip_edges())
			if t.length() >= 2 and p.length() >= 5:
				out.append({"title": t, "pitch": p})
	return out


# v11 (R156, user 2026-07-14) — CORRECTION D'ACCENTS conservatrice de la sortie LLM AFFICHÉE.
# Gemma laisse parfois tomber un accent (vu : « repond » pour « répond » dans un objectif généré).
# Ce filet ne corrige QU'UNE liste CURÉE de mots français fréquents dont la forme SANS accent
# (1) n'est PAS un mot valide et (2) n'a QU'UNE seule graphie accentuée correcte → zéro ambiguïté.
# Exclus VOLONTAIREMENT : « a→à », « ou→où », « la→là », « sur→sûr », « cote→côté », « tache→tâche »,
# et tout mot à double accent -e/-é (« ecoute/écoute vs écouté », « revele/révèle vs révélé »).
# « meme→même » RETENU (registre celtique : le sens familier « meme » n'y apparaît jamais) ; « ca » ÉCARTÉ (collision sigle CA).
# Remplacement PAR MOT ENTIER (frontière = suite de lettres), casse préservée (minuscule/Capitale/MAJ).
# Appliqué dans clean_prose() (narration/issue/intro/ouverture LLM) et clean_selection() (titre+pitch,
# donc aussi l'objectif dérivé). Déterministe et pur → testable hors-arbre ; no-op sur texte déjà correct.
const _ACCENT_FIX: Dictionary = {
	"deja": "déjà", "voila": "voilà", "tres": "très", "apres": "après",
	"derriere": "derrière",
	"etre": "être", "etres": "êtres", "etait": "était", "etaient": "étaient", "etais": "étais",
	"meme": "même", "memes": "mêmes",
	"foret": "forêt", "forets": "forêts",
	"mystere": "mystère", "mysteres": "mystères",
	"lumiere": "lumière", "lumieres": "lumières",
	"verite": "vérité", "verites": "vérités",
	"creature": "créature", "creatures": "créatures",
	"etrange": "étrange", "etranges": "étranges",
	"presence": "présence", "presences": "présences",
	"reussite": "réussite", "reussir": "réussir", "reussi": "réussi",
	"repond": "répond", "repondit": "répondit", "repondre": "répondre",
	"repondu": "répondu", "repondait": "répondait", "repondent": "répondent",
}
const _WORD_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZàâäéèêëîïôöùûüÿçñœæÀÂÄÉÈÊËÎÏÔÖÙÛÜŸÇÑŒÆ"


static func repair_accents(text: String) -> String:
	if text.is_empty():
		return text
	var out: String = ""
	var n: int = text.length()
	var i: int = 0
	while i < n:
		var ch: String = text[i]
		if _WORD_CHARS.find(ch) == -1:
			out += ch
			i += 1
			continue
		# Accumuler un MOT (suite maximale de lettres) puis tenter une correction bornée au dictionnaire.
		var word: String = ""
		var j: int = i
		while j < n and _WORD_CHARS.find(text[j]) != -1:
			word += text[j]
			j += 1
		out += _fix_word(word)
		i = j
	return out


static func _fix_word(word: String) -> String:
	var low: String = word.to_lower()
	if not _ACCENT_FIX.has(low):
		return word
	var repl: String = str(_ACCENT_FIX[low])
	if word == low:
		return repl  # minuscule
	if word == word.to_upper():
		return repl.to_upper()  # MAJUSCULE
	# Capitale initiale (1re lettre majuscule, reste minuscule) : ex. « Repond » → « Répond ».
	if word.substr(0, 1) == word.substr(0, 1).to_upper() and word.substr(1) == word.substr(1).to_lower():
		return repl.substr(0, 1).to_upper() + repl.substr(1)
	return word  # casse mixte inattendue → prudence, on ne touche pas
