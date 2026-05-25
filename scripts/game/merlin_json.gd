class_name MerlinJson
extends RefCounted
## Extraction + réparation JSON robuste (bible R61) — remplace le GBNF (cassé sur ce build
## gemma4, cf. task_plan v9.0 findings). On génère du JSON LIBRE et on parse/répare ici.

## Extrait le 1er objet JSON {…} d'un texte LLM (avec réparations). Retourne {} si échec total.
static func extract_obj(text: String) -> Dictionary:
	var v: Variant = _extract(text, "{", "}")
	if v is Dictionary:
		return v
	return {}


## Extrait le 1er tableau JSON [...] d'un texte LLM. Retourne [] si échec.
static func extract_array(text: String) -> Array:
	var v: Variant = _extract(text, "[", "]")
	if v is Array:
		return v
	return []


static func _extract(text: String, open_ch: String, close_ch: String) -> Variant:
	var cleaned: String = _strip_fences(text)
	var sub: String = _balanced_slice(cleaned, open_ch, close_ch)
	if sub.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(sub)
	if parsed != null:
		return parsed
	var repaired: String = _repair(sub)
	parsed = JSON.parse_string(repaired)
	return parsed


static func _strip_fences(text: String) -> String:
	var t: String = text
	t = t.replace("```json", "").replace("```JSON", "").replace("```", "")
	return t.strip_edges()


## Coupe la sous-chaîne du 1er open_ch à son close_ch équilibré (gère l'imbrication + les chaînes).
static func _balanced_slice(text: String, open_ch: String, close_ch: String) -> String:
	var start: int = text.find(open_ch)
	if start < 0:
		return ""
	var depth: int = 0
	var in_str: bool = false
	var escaped: bool = false
	for i in range(start, text.length()):
		var ch: String = text[i]
		if in_str:
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == "\"":
				in_str = false
			continue
		if ch == "\"":
			in_str = true
		elif ch == open_ch:
			depth += 1
		elif ch == close_ch:
			depth -= 1
			if depth == 0:
				return text.substr(start, i - start + 1)
	return text.substr(start, text.length() - start)


static func _repair(s: String) -> String:
	var t: String = s
	t = t.replace("“", "\"").replace("”", "\"")
	t = t.replace("‘", "'").replace("’", "'")
	t = _strip_trailing_commas(t)
	return t


static func _strip_trailing_commas(s: String) -> String:
	var out: String = ""
	var n: int = s.length()
	for i in n:
		var ch: String = s[i]
		if ch == ",":
			var j: int = i + 1
			while j < n and (s[j] == " " or s[j] == "\n" or s[j] == "\t" or s[j] == "\r"):
				j += 1
			if j < n and (s[j] == "}" or s[j] == "]"):
				continue
		out += ch
	return out
