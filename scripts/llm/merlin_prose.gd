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
	var t: String = s.strip_edges()
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
		if ch == "." or ch == "!" or ch == "?":
			return s.substr(0, i + 1)
	return s


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
static func parse_arc(text: String) -> Array:
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
	return out.slice(0, 5) if out.size() >= 5 else []


# Garde uniquement les entrées {title, pitch} valides d'une sélection JSON extraite.
static func clean_selection(arr: Array) -> Array:
	var out: Array = []
	for item in arr:
		if item is Dictionary and item.has("title") and item.has("pitch"):
			var t: String = str(item["title"]).strip_edges()
			var p: String = str(item["pitch"]).strip_edges()
			if t.length() >= 2 and p.length() >= 5:
				out.append({"title": t, "pitch": p})
	return out


# v10.17 (track LLM) — vrai si `parsed` est une sélection exploitable : Array de >=3 entrées
# {title>=2, pitch>=5}. Réutilise le MÊME critère que clean_selection (DRY) sans muter. Passé en
# Callable de validation à MerlinStructured.generate_object (retry-on-malformed).
static func is_valid_selection(parsed: Variant) -> bool:
	if not (parsed is Array):
		return false
	return clean_selection(parsed).size() >= 3
