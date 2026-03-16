## ═══════════════════════════════════════════════════════════════════════════════
## LLM Adapter — JSON Repair & Extraction
## ═══════════════════════════════════════════════════════════════════════════════
## Robust parsing of LLM output: multi-strategy JSON extraction, common error
## fixes, aggressive repair for truncated/malformed JSON, regex field extraction.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name LlmAdapterJsonRepair


func extract_json_from_response(raw: String) -> Dictionary:
	# Strategy 1: Find outermost { }
	var json_start := raw.find("{")
	var json_end := raw.rfind("}")
	if json_start == -1 or json_end == -1 or json_end <= json_start:
		# Strategy 4: Regex field extraction (no braces found)
		return _regex_extract_card_fields(raw)

	var json_text := raw.substr(json_start, json_end - json_start + 1)
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	# Strategy 2: Fix common LLM JSON errors then retry
	json_text = fix_common_json_errors(json_text)
	parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	# Strategy 3: Aggressive repair (truncation, nesting, escaping)
	json_text = aggressive_json_repair(json_text)
	parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	# Strategy 4: Regex field extraction (last resort)
	return _regex_extract_card_fields(raw)


func fix_common_json_errors(text: String) -> String:
	# Fix trailing commas before } or ]
	var rx := RegEx.new()
	rx.compile(",\\s*([}\\]])")
	text = rx.sub(text, "$1", true)

	# Fix single quotes to double quotes
	text = text.replace("'", "\"")

	# Fix unquoted keys: word: -> "word":
	rx = RegEx.new()
	rx.compile("([{,])\\s*([a-zA-Z_][a-zA-Z_0-9]*)\\s*:")
	text = rx.sub(text, "$1\"$2\":", true)

	return text


func aggressive_json_repair(text: String) -> String:
	## Step 3: Handle truncated JSON, bad nesting, escape issues.

	# Fix unescaped quotes inside strings (common nano-model error)
	# Replace \" inside values that have unmatched quotes
	var rx := RegEx.new()

	# Remove control characters that break JSON
	text = text.replace("\t", " ").replace("\r", "")

	# Fix truncated JSON: count brackets and close them
	var open_braces := text.count("{") - text.count("}")
	var open_brackets := text.count("[") - text.count("]")

	# Remove trailing incomplete key-value pairs (e.g., "key": )
	rx.compile(",\\s*\"[^\"]*\"\\s*:\\s*$")
	text = rx.sub(text, "", true)

	# Close any unclosed strings (odd number of unescaped quotes)
	var in_string := false
	var clean := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "\\" and in_string and i + 1 < text.length():
			clean += ch + text[i + 1]
			i += 2
			continue
		if ch == "\"":
			in_string = not in_string
		clean += ch
		i += 1
	if in_string:
		clean += "\""
	text = clean

	# Close unclosed brackets and braces
	for _j in range(open_brackets):
		text += "]"
	for _j in range(open_braces):
		text += "}"

	# Remove trailing commas added by closure
	rx.compile(",\\s*([}\\]])")
	text = rx.sub(text, "$1", true)

	return text


func _regex_extract_card_fields(raw: String) -> Dictionary:
	## Step 4: Extract card fields using regex when JSON parsing fails entirely.
	## Builds a card from detected text and option labels.
	var rx := RegEx.new()

	# Try to find "text" field value
	rx.compile("\"text\"\\s*:\\s*\"([^\"]+)\"")
	var text_match := rx.search(raw)
	if text_match == null:
		return {}

	var card_text: String = text_match.get_string(1)

	# Try to find option labels
	var labels: Array[String] = []
	rx.compile("\"label\"\\s*:\\s*\"([^\"]+)\"")
	var label_matches := rx.search_all(raw)
	for m in label_matches:
		labels.append(m.get_string(1))

	if labels.size() < 2:
		return {}

	# Try to find speaker
	rx.compile("\"speaker\"\\s*:\\s*\"([^\"]+)\"")
	var speaker_match := rx.search(raw)
	var speaker: String = speaker_match.get_string(1) if speaker_match else "merlin"

	var options: Array = []

	for idx in range(labels.size()):
		var opt: Dictionary = {"label": labels[idx], "effects": []}
		if idx == 1:
			opt["cost"] = 1
		# Try to pair with an effect
		# Default Vie/Karma/Reputation effects based on position
		var default_effects: Array = [
			{"type": "HEAL_LIFE", "amount": 5},
			{"type": "ADD_KARMA", "amount": 1},
			{"type": "DAMAGE_LIFE", "amount": 3},
		]
		opt["effects"].append(default_effects[idx % 3])
		options.append(opt)

	return {
		"text": card_text,
		"speaker": speaker,
		"options": options.slice(0, 3),
		"tags": ["llm_regex_repair"],
	}
