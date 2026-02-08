extends Control

# Minimal Test Merlin GBA: simple dialogue + knowledge test.

const SYSTEM_DIALOGUE := "Tu es Merlin, druide de Broceliande. Reponds en francais sans accents, ASCII uniquement. Une phrase courte (max 120 caracteres). Ton celtique, bienveillant, un peu espiegle. Pas d anglais, pas de balises, pas de tokens."
const SYSTEM_KNOWLEDGE := "Tu es un assistant factuel. Reponds en francais simple et court (max 110 caracteres). Si tu ne sais pas, dis-le. Pas d anglais, pas de balises."
# Restauré à 6 avec contexte 8192 tokens (aligné Colab)
const HISTORY_LIMIT := 6
# Animations celtiques en pixel art ASCII
const LOADING_FRAMES := [" *", " +", " o", " O", " @", " #"]
const TYPEWRITER_DELAY := 0.01
const SESSION_ID := "test_merlin_gba"
const PERSONA_PATH := "res://addons/merlin_llm/Comportement/prompts_merlin.json"
# Streaming maintenant OK avec contexte 8192 tokens
const STREAMING_MODE := true
const SESSION_CHANNEL := "dialogue"

# Systeme d'emotions
const EMOTIONS := {
	"bienveillant": {"emoji": "😊", "label": "Bienveillant", "keywords": ["ami", "voyageur", "bienvenu", "aide", "guide"]},
	"espiegle": {"emoji": "😏", "label": "Espiègle", "keywords": ["rire", "jeu", "enigme", "devinette", "astuce"]},
	"sage": {"emoji": "🧙", "label": "Sage", "keywords": ["sache", "connaissance", "ancien", "sagesse", "apprend"]},
	"inquiet": {"emoji": "😟", "label": "Préoccupé", "keywords": ["danger", "attention", "prudence", "garde", "menace"]},
	"mysterieux": {"emoji": "🌙", "label": "Mystérieux", "keywords": ["secret", "brume", "ombre", "voile", "cache"]}
}
const DEFAULT_EMOTION := "bienveillant"

@onready var llm_title: Label = $MainContainer/LeftPanel/LLMPanel/LLMVBox/TitleLabel
@onready var status_label: Label = $MainContainer/LeftPanel/LLMPanel/LLMVBox/StatusLabel
@onready var detail_label: Label = $MainContainer/LeftPanel/LLMPanel/LLMVBox/DetailLabel
@onready var progress_bar: ProgressBar = $MainContainer/LeftPanel/LLMPanel/LLMVBox/ProgressBar
@onready var reload_button: Button = $MainContainer/LeftPanel/LLMPanel/LLMVBox/ButtonsRow/ReloadButton
@onready var copy_button: Button = $MainContainer/LeftPanel/LLMPanel/LLMVBox/ButtonsRow/CopyButton
@onready var diag_button: Button = $MainContainer/LeftPanel/LLMPanel/LLMVBox/ButtonsRow/DiagButton
@onready var log_text: TextEdit = $MainContainer/LeftPanel/LLMPanel/LLMVBox/LogText

@onready var merlin_sprite: TextureRect = $MainContainer/LeftPanel/MerlinPanel/MerlinVBox/MerlinSprite
@onready var mood_label: Label = $MainContainer/LeftPanel/MerlinPanel/MerlinVBox/MoodLabel
@onready var debug_toggle: Button = $MainContainer/LeftPanel/DebugToggle

@onready var chat_text: RichTextLabel = $MainContainer/RightPanel/ChatPanel/ChatVBox/ChatScroll/ChatText
@onready var choices_container: VBoxContainer = $MainContainer/RightPanel/ChoicesPanel/ChoicesVBox
@onready var input_field: LineEdit = $MainContainer/RightPanel/InputPanel/InputHBox/InputField
@onready var send_button: Button = $MainContainer/RightPanel/InputPanel/InputHBox/SendButton
@onready var clear_button: Button = $MainContainer/RightPanel/InputPanel/InputHBox/ClearButton

var merlin_ai: Node = null
var current_emotion := DEFAULT_EMOTION
var history: Array = []
var is_busy := false
var chat_lines: Array[String] = []
var loading_timer: Timer = null
var loading_active := false
var loading_index := -1
var loading_tick := 0
var loading_stamp := ""
var typing_active := false
var persona_system_dialogue := ""
var persona_few_shot: Array = []
var initial_greeting_sent := false
var last_generated_choices: Array[String] = []
var last_merlin_response := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bind_merlin_ai()
	_bind_ui()
	_update_mood(DEFAULT_EMOTION)
	if llm_title:
		var title_text = "LLM Router: Llama 3.2 3B\nLLM Exec: Qwen 2.5 0.5B"
		if merlin_ai and merlin_ai.has_method("get_model_info"):
			var info: Dictionary = merlin_ai.get_model_info()
			var router_name = str(info.get("router", ""))
			var exec_name = str(info.get("executor", ""))
			if router_name != "" or exec_name != "":
				if router_name != "":
					router_name = router_name.get_file()
				if exec_name != "":
					exec_name = exec_name.get_file()
				title_text = "LLM Router: " + router_name + "\nLLM Exec: " + exec_name
		llm_title.text = title_text
	if chat_text:
		chat_text.bbcode_enabled = true
		chat_text.add_theme_color_override("default_color", Color(0.95, 0.92, 0.86))
		chat_text.add_theme_font_size_override("normal_font_size", 14)
	else:
		push_warning("ChatText introuvable dans TestMerlinGBA.")
	if input_field:
		input_field.editable = true
		input_field.grab_focus()
	_init_loading_timer()
	_load_persona()
	_run_diagnostic(false)
	# Salutation initiale de Merlin (async)
	_send_initial_greeting()

func _send_initial_greeting() -> void:
	if initial_greeting_sent:
		return
	initial_greeting_sent = true

	# Attendre un instant pour l'UI
	await get_tree().create_timer(0.3).timeout

	# Utiliser une salutation prédéfinie (INSTANTANÉ - 0ms, pas d'erreur llama_decode)
	var greetings := _get_predefined_greetings()
	var greeting := ""
	if greetings.size() > 0:
		greeting = greetings[randi() % greetings.size()]
	else:
		greeting = "Bienvenue en Broceliande, voyageur. Je suis Merlin."

	# Afficher avec effet typewriter
	await _append_chat_typewriter(_stamp() + " [b]Merlin:[/b] ", greeting)
	_push_history("assistant", greeting)

	# Detecter emotion et generer choix initiaux
	var detected_emotion = _detect_emotion(greeting)
	_update_mood(detected_emotion)
	_generate_quick_choices(greeting)

func _get_predefined_greetings() -> Array[String]:
	var result: Array[String] = []
	if FileAccess.file_exists(PERSONA_PATH):
		var file = FileAccess.open(PERSONA_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(data) == TYPE_DICTIONARY and data.has("greetings"):
				if data.greetings is Array:
					for g in data.greetings:
						if typeof(g) == TYPE_STRING:
							result.append(str(g))
	# Fallback greetings
	if result.is_empty():
		result = [
			"Bienvenue en Broceliande, voyageur.",
			"Ah, la brume te salue, ami des sentiers.",
			"Je t'attendais, ou presque.",
			"Sois le bienvenu, Voyageur."
		]
	return result

func _bind_merlin_ai() -> void:
	merlin_ai = get_node_or_null("/root/MerlinAI")
	if merlin_ai:
		merlin_ai.status_changed.connect(_on_llm_status_changed)
		if merlin_ai.has_signal("log_updated"):
			merlin_ai.log_updated.connect(_on_llm_log_updated)
		var status: Dictionary = merlin_ai.get_status()
		_on_llm_status_changed(str(status.status), str(status.detail), float(status.progress))
		if merlin_ai.has_method("get_log_text"):
			_on_llm_log_updated(merlin_ai.get_log_text())
	else:
		_on_llm_status_changed("Connexion: OFF", "MerlinAI introuvable", 0.0)

func _bind_ui() -> void:
	if debug_toggle:
		debug_toggle.pressed.connect(_on_debug_toggle)
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_text_submitted)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)
	if reload_button:
		reload_button.pressed.connect(_on_reload_pressed)
	if copy_button:
		copy_button.pressed.connect(_on_copy_pressed)
	if diag_button:
		diag_button.pressed.connect(_on_diag_pressed)
	if send_button:
		send_button.disabled = false
	if clear_button:
		clear_button.disabled = false

func _on_llm_status_changed(status_text: String, detail_text: String, progress_value: float) -> void:
	status_label.text = status_text
	detail_label.text = detail_text
	progress_bar.value = clampf(progress_value, 0.0, 100.0)

func _on_llm_log_updated(text: String) -> void:
	log_text.text = text
	log_text.scroll_vertical = log_text.get_line_count()

func _on_reload_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("reload_models"):
		merlin_ai.reload_models()

func _on_copy_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("get_log_text"):
		DisplayServer.clipboard_set(merlin_ai.get_log_text())

func _on_debug_toggle() -> void:
	if llm_title and llm_title.get_parent() and llm_title.get_parent().get_parent():
		var llm_panel = llm_title.get_parent().get_parent()
		llm_panel.visible = not llm_panel.visible

func _on_text_submitted(_text: String) -> void:
	await _on_send_pressed()

func _on_send_pressed() -> void:
	var text = input_field.text.strip_edges()
	if text == "":
		return
	input_field.text = ""
	await _send_message(text)

func _on_clear_pressed() -> void:
	history.clear()
	chat_lines.clear()
	if chat_text:
		chat_text.clear()
	_append_chat("[i]Historique efface.[/i]")

func _send_message(text: String) -> void:
	if is_busy:
		return
	if merlin_ai == null:
		_append_chat(_stamp() + " [color=red]MerlinAI indisponible.[/color]")
		return
	is_busy = true
	_set_input_busy(true)
	_append_chat(_stamp() + " [b]Vous:[/b] " + text)
	_start_loading()
	var system_prompt = SYSTEM_DIALOGUE
	if persona_system_dialogue != "":
		system_prompt = persona_system_dialogue

	# Détecter si c'est un choix suggéré (mérite une meilleure réponse)
	var is_suggested_choice = text in last_generated_choices
	var complex = _is_complex_request(text) or is_suggested_choice

	# Paramètres alignés avec Colab (contexte 8192 permet réponses longues)
	var params := {"temperature": 0.7, "top_p": 0.9, "max_tokens": 256, "top_k": 50, "repetition_penalty": 1.1}
	if is_suggested_choice:
		# Boost qualité pour choix: encore plus de tokens
		params.max_tokens = 384
	if complex:
		system_prompt += " Si la question demande des details, reponds: 'Bien sur, mon ami, les voici:' puis 3 a 10 points numerotes sur une ligne chacun."
		params.max_tokens = 512  # Aligné avec Colab

	var prompt = _build_prompt(text)
	var answer := ""
	var stream_error := ""
	if STREAMING_MODE and merlin_ai and merlin_ai.has_method("generate_with_system_stream"):
		var stream_result: Dictionary = await _stream_response(system_prompt, prompt, params, complex)
		answer = str(stream_result.get("answer", ""))
		stream_error = str(stream_result.get("error", ""))

		# Fallback: si streaming renvoie vide, essayer sans streaming avec plus de tokens
		if answer == "" or answer == "(reponse vide)":
			print("[WARN] Streaming returned empty, retrying without streaming")
			params.max_tokens = params.max_tokens + 80
			params.temperature = min(params.temperature + 0.15, 0.65)
			var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, prompt, params)
			answer = _clean_response(_extract_text(result), complex)
			if answer == "":
				answer = "(reponse vide)"
			if complex:
				var lines = _split_multiline(answer)
				if lines.size() == 0:
					lines = [answer]
				await _finish_loading(lines[0], true)
				for i in range(1, lines.size()):
					await get_tree().create_timer(0.12).timeout
					await _append_chat_typewriter(_stamp() + " [b]Merlin:[/b] ", lines[i])
				answer = "\n".join(lines)
			else:
				await _finish_loading(answer, true)
	else:
		var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, prompt, params)

		# Gestion spéciale des erreurs llama_decode (contexte plein)
		if result.has("error") and str(result.error).contains("decode"):
			_append_chat(_stamp() + " [color=orange]Contexte sature, reinitialisation...[/color]")
			history.clear()  # Vider l'historique pour libérer tokens
			if merlin_ai.has_method("clear_response_cache"):
				merlin_ai.clear_response_cache()
			# Retry avec historique vide
			var clean_prompt = "U: " + text
			result = await merlin_ai.generate_with_system(system_prompt, clean_prompt, params)

		answer = _clean_response(_extract_text(result), complex)

		# Détecter et corriger les répétitions
		if answer != "" and answer != "(reponse vide)" and _is_repetitive(answer, last_merlin_response):
			print("[WARN] Repetition detected, regenerating with boosted creativity...")
			params.temperature = min(params.temperature + 0.25, 0.85)
			params.top_p = 0.85
			result = await merlin_ai.generate_with_system(system_prompt, prompt, params)
			answer = _clean_response(_extract_text(result), complex)

		if answer == "":
			# Retry once with a bit more tokens if empty
			params.max_tokens = params.max_tokens + 50
			params.temperature = min(params.temperature + 0.1, 0.6)
			result = await merlin_ai.generate_with_system(system_prompt, prompt, params)
			answer = _clean_response(_extract_text(result), complex)
		if answer == "":
			answer = "(reponse vide)"
		if complex:
			var lines = _split_multiline(answer)
			if lines.size() == 0:
				lines = [answer]
			await _finish_loading(lines[0], true)
			for i in range(1, lines.size()):
				await get_tree().create_timer(0.12).timeout
				await _append_chat_typewriter(_stamp() + " [b]Merlin:[/b] ", lines[i])
			answer = "\n".join(lines)
		else:
			await _finish_loading(answer, true)
		if result.has("error"):
			_append_chat(_stamp() + " [color=red]Erreur LLM: " + str(result.error) + "[/color]")
	if stream_error != "":
		_append_chat(_stamp() + " [color=red]Erreur LLM: " + stream_error + "[/color]")
	_push_history("user", text)
	_push_history("assistant", answer)

	# Sauvegarder pour detection de répétition
	if answer != "" and answer != "(reponse vide)":
		last_merlin_response = answer

	# Systeme d'emotions et choix rapides
	var detected_emotion = _detect_emotion(answer)
	_update_mood(detected_emotion)

	# Generer les choix contextuels (INSTANTANÉ - 0ms)
	if answer != "" and answer != "(reponse vide)":
		_generate_quick_choices(answer)
	else:
		# Choix par défaut si pas de réponse
		_update_choice_buttons(["Bonjour", "Que faire ?", "Aide-moi", "Au revoir"])

	is_busy = false
	_set_input_busy(false)

func _build_prompt(latest: String) -> String:
	var lines: Array[String] = []
	for entry in _format_few_shot():
		lines.append(entry)
	var ctx = history
	if merlin_ai and merlin_ai.has_method("get_session_context"):
		ctx = merlin_ai.get_session_context(SESSION_ID, HISTORY_LIMIT, SESSION_CHANNEL)
	for item in ctx:
		var prefix = "M:" if item.role == "assistant" else "U:"
		lines.append(prefix + " " + item.content)
	lines.append("U: " + latest)
	return "\n".join(lines)

func _push_history(role: String, content: String) -> void:
	history.append({"role": role, "content": content})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT, history.size())
	if merlin_ai and merlin_ai.has_method("add_session_entry"):
		merlin_ai.add_session_entry(SESSION_ID, role, content, SESSION_CHANNEL)

func _extract_text(result: Dictionary) -> String:
	if result.has("error"):
		return "Erreur: " + str(result.error)
	if result.has("text"):
		return str(result.text).strip_edges()
	if result.has("lines") and result.lines is Array and result.lines.size() > 0:
		return str(result.lines[0]).strip_edges()
	return str(result).strip_edges()

func _append_chat(line: String) -> void:
	if chat_text == null:
		return
	chat_lines.append(line)
	_refresh_chat()

func _set_chat_line(index: int, line: String) -> void:
	if chat_text == null:
		return
	if index < 0 or index >= chat_lines.size():
		return
	chat_lines[index] = line
	_refresh_chat()

func _refresh_chat() -> void:
	if chat_text == null:
		return
	if chat_lines.size() > 200:
		var start = max(0, chat_lines.size() - 200)
		chat_lines = chat_lines.slice(start, chat_lines.size())
		if loading_index >= 0:
			loading_index = max(-1, loading_index - start)
	var joined = "\n".join(chat_lines)
	chat_text.clear()
	chat_text.parse_bbcode(joined)
	chat_text.scroll_to_line(chat_text.get_line_count())

func _stream_response(system_prompt: String, prompt: String, params: Dictionary, complex: bool) -> Dictionary:
	var stream_state := {"text": "", "got": false, "line_index": loading_index}
	var response_stamp := loading_stamp
	if response_stamp == "":
		response_stamp = _stamp()
	var on_chunk = func(chunk: String, done: bool) -> void:
		if done:
			return
		if chunk == "":
			return
		if not stream_state.got:
			stream_state.got = true
			loading_active = false
			if loading_timer:
				loading_timer.stop()
		stream_state.text += chunk
		var preview = _clean_stream_text(stream_state.text)
		if preview == "":
			preview = LOADING_FRAMES[loading_tick]
		var line = response_stamp + " [b]Merlin:[/b] " + preview
		if stream_state.line_index == -1:
			_append_chat(line)
			stream_state.line_index = chat_lines.size() - 1
			loading_index = stream_state.line_index
		else:
			_set_chat_line(stream_state.line_index, line)
	var result: Dictionary = await merlin_ai.generate_with_system_stream(system_prompt, prompt, params, on_chunk)
	loading_active = false
	if loading_timer:
		loading_timer.stop()
	var answer = _clean_response(_extract_text(result), complex)
	if answer == "" and stream_state.text != "":
		answer = _clean_response(_clean_stream_text(stream_state.text), complex)
	if answer == "":
		answer = "(reponse vide)"
	if stream_state.line_index == -1:
		_append_chat(response_stamp + " [b]Merlin:[/b] " + answer)
		stream_state.line_index = chat_lines.size() - 1
	if complex:
		var lines = _split_multiline(answer)
		if lines.size() == 0:
			lines = [answer]
		_set_chat_line(stream_state.line_index, response_stamp + " [b]Merlin:[/b] " + lines[0])
		for i in range(1, lines.size()):
			await get_tree().create_timer(0.08).timeout
			await _append_chat_typewriter(_stamp() + " [b]Merlin:[/b] ", lines[i])
		answer = "\n".join(lines)
	else:
		_set_chat_line(stream_state.line_index, response_stamp + " [b]Merlin:[/b] " + answer)
	loading_index = -1
	return {"answer": answer, "error": result.get("error", "")}

func _clean_response(text: String, allow_multi: bool = false) -> String:
	var cleaned = text

	# Remove ALL chat template tokens (aggressive cleaning)
	var tokens_to_remove = [
		"<|im_start|>", "<|im_end|>", "<|endoftext|>", "<|eot_id|>",
		"<|system|>", "<|user|>", "<|assistant|>",
		"<|start|>", "<|end|>", "<s>", "</s>",
		"[INST]", "[/INST]", "<<SYS>>", "<</SYS>>"
	]
	for token in tokens_to_remove:
		cleaned = cleaned.replace(token, "")

	# Remove any remaining < | > patterns
	var regex = RegEx.new()
	regex.compile("<\\|[^>]*\\|>")
	cleaned = regex.sub(cleaned, "", true)

	# Truncate if model leaks role markers or system prompts
	var stop_markers = [
		"Human:", "User:", "Assistant:", "System:",
		"<|", "Tu es MERLIN", "Tu es un assistant",
		"IDENTITE STRICTE", "Genere 4 reponses",
		"system", "assistant", "user",  # Mots-clés de fuite
		"IMPORTANT:", "UNIQUEMENT", "Format:",
		"temperature", "max_tokens", "top_p"  # Paramètres techniques
	]
	var earliest_stop = -1
	for marker in stop_markers:
		var idx = cleaned.find(marker)
		if idx != -1 and (earliest_stop == -1 or idx < earliest_stop):
			earliest_stop = idx
	if earliest_stop > 5:  # Au moins 5 caractères avant de tronquer
		cleaned = cleaned.substr(0, earliest_stop).strip_edges()

	# Clean line by line
	var lines = cleaned.split("\n")
	var kept: Array[String] = []
	for line in lines:
		var l = line.strip_edges()
		if l == "" or l.length() < 2:
			continue
		# Skip lines with meta content
		if l.begins_with("Human:") or l.begins_with("Assistant:") or l.begins_with("User:") or l.begins_with("System:"):
			l = l.substr(l.find(":") + 1).strip_edges()
		if l.contains("<") or l.contains(">") or l.contains("|"):
			continue
		kept.append(l)
	cleaned = " ".join(kept).strip_edges()
	if allow_multi:
		cleaned = _force_numbered_lines(cleaned)
	else:
		# Keep only the first sentence
		cleaned = _first_sentence(cleaned)
	# Hard cap length
	if cleaned.length() > 520 and allow_multi:
		cleaned = cleaned.substr(0, 520).strip_edges()
	elif cleaned.length() > 140:
		cleaned = cleaned.substr(0, 140).strip_edges()
	cleaned = _ascii_only(cleaned)
	if _looks_english(cleaned):
		cleaned = "Je parle en francais. Pose ta question, voyageur."
	return cleaned

func _force_numbered_lines(text: String) -> String:
	var out = text
	if not out.to_lower().begins_with("bien sur"):
		out = "Bien sur, mon ami, les voici: " + out

	# Ajouter des newlines avant les numéros (gérer cas avec et sans espace)
	for i in range(1, 10):
		# Cas 1: "voici:1)" -> "voici:\n1)"
		var pattern1 = ":%d)" % i
		var pattern2 = ".%d)" % i
		if out.find(pattern1) != -1:
			out = out.replace(pattern1, ":\n%d)" % i)
		if out.find(pattern2) != -1:
			out = out.replace(pattern2, ".\n%d)" % i)

		# Cas 2: " 1)" -> "\n1)"
		out = out.replace(" %d)" % i, "\n%d)" % i)
		out = out.replace(" %d." % i, "\n%d." % i)

		# Cas 3: "Respecte.1)" -> "Respecte.\n1)"
		var regex = RegEx.new()
		regex.compile("([a-z])%d\\)" % i)
		out = regex.sub(out, "$1\n%d)" % i, true)

	return out

func _clean_stream_text(text: String) -> String:
	var cleaned = text
	cleaned = cleaned.replace("<|im_start|>", "")
	cleaned = cleaned.replace("<|im_end|>", "")
	cleaned = cleaned.replace("<|endoftext|>", "")
	cleaned = cleaned.replace("<|eot_id|>", "")
	var role_markers = ["Human:", "User:", "Assistant:"]
	for marker in role_markers:
		var idx = cleaned.find(marker)
		if idx != -1:
			cleaned = cleaned.substr(0, idx).strip_edges()
	cleaned = cleaned.replace("\r", " ").strip_edges()
	cleaned = _ascii_only(cleaned)
	if cleaned.length() > 280:
		cleaned = cleaned.substr(0, 280).strip_edges()
	return cleaned

func _split_multiline(text: String) -> Array[String]:
	var parts = text.split("\n")
	var cleaned: Array[String] = []
	for p in parts:
		var line = p.strip_edges()
		if line == "":
			continue
		cleaned.append(line)
	return cleaned

func _first_sentence(text: String) -> String:
	# Check if text has numbered list (like "1)", "2)", etc)
	if text.find("1)") != -1 or text.find("2)") != -1 or text.find("1.") != -1:
		# Don't truncate numbered lists, return full text
		return text.strip_edges()

	var best_idx := -1
	for sep in [".", "!", "?"]:
		var idx = text.find(sep)
		if idx != -1:
			# Skip if it's a number followed by period (like "1.")
			if sep == "." and idx > 0:
				var prev_char = text[idx - 1]
				if prev_char >= '0' and prev_char <= '9':
					continue
			if best_idx == -1 or idx < best_idx:
				best_idx = idx
	if best_idx != -1:
		return text.substr(0, best_idx + 1).strip_edges()
	return text.strip_edges()

func _ascii_only(text: String) -> String:
	var out := ""
	for i in text.length():
		var code = text.unicode_at(i)
		if code >= 32 and code <= 126:
			out += text[i]
	return out

func _looks_english(text: String) -> bool:
	var lower = text.to_lower()
	var markers = [" the ", " and ", " you ", " your ", " can you", " article", "summary", "summarize", "renewable"]
	for m in markers:
		if lower.find(m) != -1:
			return true
	return false

func _is_repetitive(new_text: String, previous_text: String) -> bool:
	if previous_text == "" or new_text == "":
		return false
	# Vérifier si les 30 premiers caractères sont identiques
	var new_start = new_text.substr(0, min(30, new_text.length())).to_lower()
	var prev_start = previous_text.substr(0, min(30, previous_text.length())).to_lower()
	if new_start == prev_start:
		return true
	# Vérifier si plus de 60% des mots sont identiques
	var new_words = new_text.to_lower().split(" ", false)
	var prev_words = previous_text.to_lower().split(" ", false)
	var common = 0
	for word in new_words:
		if word in prev_words:
			common += 1
	var similarity = float(common) / float(max(new_words.size(), 1))
	return similarity > 0.6

func _detect_emotion(text: String) -> String:
	var lower = text.to_lower()
	var scores = {}
	for emotion_key in EMOTIONS.keys():
		var emotion = EMOTIONS[emotion_key]
		var score = 0
		for keyword in emotion.keywords:
			if lower.find(keyword) != -1:
				score += 1
		scores[emotion_key] = score
	var best_emotion = DEFAULT_EMOTION
	var best_score = 0
	for emotion_key in scores.keys():
		if scores[emotion_key] > best_score:
			best_score = scores[emotion_key]
			best_emotion = emotion_key
	return best_emotion

func _update_mood(emotion: String) -> void:
	if not EMOTIONS.has(emotion):
		emotion = DEFAULT_EMOTION
	current_emotion = emotion
	var emotion_data = EMOTIONS[emotion]
	if mood_label:
		mood_label.text = emotion_data.emoji + " " + emotion_data.label

func _generate_quick_choices(merlin_response: String) -> void:
	if not choices_container:
		print("[WARN] Cannot generate choices: choices_container is null")
		return

	# OPTIMISATION: Toujours utiliser les choix contextuels (INSTANTANÉ, 0ms)
	# Plus de génération LLM pour les choix = gain de 4+ secondes par interaction !
	var choices: Array[String] = _get_contextual_choices(merlin_response)
	print("[DEBUG] Using contextual choices (0ms): " + str(choices.size()) + " choices")
	_update_choice_buttons(choices)

func _get_contextual_choices(merlin_response: String) -> Array[String]:
	var lower = merlin_response.to_lower()
	var choices: Array[String] = []

	# Détection du contexte basée sur les mots-clés de Merlin
	if lower.find("pierre") != -1 or lower.find("cercle") != -1 or lower.find("rune") != -1:
		choices = [
			"Ou trouver cette pierre ?",
			"Que faire la-bas ?",
			"C'est dangereux ?",
			"Autre chose a savoir ?"
		]
	elif lower.find("brume") != -1 or lower.find("voile") != -1 or lower.find("ombre") != -1:
		choices = [
			"Comment traverser ?",
			"Quel danger guette ?",
			"Aide-moi a comprendre",
			"Et ensuite ?"
		]
	elif lower.find("combat") != -1 or lower.find("garde") != -1 or lower.find("ennemi") != -1:
		choices = [
			"Comment me battre ?",
			"Quelle tactique ?",
			"Ai-je une chance ?",
			"Que faire d'autre ?"
		]
	elif lower.find("quete") != -1 or lower.find("mission") != -1 or lower.find("tache") != -1:
		choices = [
			"Par ou commencer ?",
			"Quel est le but ?",
			"Des indices ?",
			"Merci Merlin"
		]
	elif lower.find("enigme") != -1 or lower.find("devinette") != -1 or lower.find("secret") != -1:
		choices = [
			"Donne un indice",
			"Je ne comprends pas",
			"La reponse est... ?",
			"Passe a autre chose"
		]
	elif lower.find("danger") != -1 or lower.find("attention") != -1 or lower.find("prudence") != -1:
		choices = [
			"Comment me proteger ?",
			"C'est grave ?",
			"Je fais quoi ?",
			"Merci du conseil"
		]
	elif lower.find("bienvenu") != -1 or lower.find("salue") != -1 or lower.find("bonjour") != -1:
		choices = [
			"Que puis-je faire ici ?",
			"J'ai besoin d'aide",
			"Raconte-moi une histoire",
			"Quelle est ta sagesse ?"
		]
	elif lower.find("perdu") != -1 or lower.find("egaré") != -1 or lower.find("chemin") != -1:
		choices = [
			"Ou aller maintenant ?",
			"Comment retrouver mon chemin ?",
			"Un repere ?",
			"Guide-moi"
		]
	else:
		# Choix génériques si aucun contexte spécifique détecté
		choices = [
			"Dis-m'en plus",
			"Que faire maintenant ?",
			"Je comprends",
			"Merci Merlin"
		]

	return choices

func _update_choice_buttons(choices: Array[String]) -> void:
	if not choices_container:
		print("[WARN] choices_container is null in _update_choice_buttons")
		return

	# Sauvegarder les choix générés pour detection plus tard
	last_generated_choices = choices.duplicate()

	# Remove old choice buttons (keep the label)
	for child in choices_container.get_children():
		if child is Button:
			child.queue_free()

	print("[DEBUG] Creating " + str(choices.size()) + " choice buttons")

	# Create new buttons
	for i in range(min(choices.size(), 4)):
		var choice_text = choices[i]
		var button = Button.new()
		button.text = choice_text
		button.custom_minimum_size = Vector2(0, 32)
		button.pressed.connect(func(): _on_choice_selected(choice_text))
		choices_container.add_child(button)
		print("[DEBUG] Added choice: " + choice_text)

func _on_choice_selected(choice_text: String) -> void:
	if input_field:
		input_field.text = choice_text
	_on_send_pressed()

func _load_persona() -> void:
	if not FileAccess.file_exists(PERSONA_PATH):
		return
	var file = FileAccess.open(PERSONA_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	# Utiliser la version complète maintenant que contexte = 8192 tokens
	if data.has("executor_system"):
		persona_system_dialogue = str(data.executor_system).strip_edges()
	elif data.has("executor_system_short"):
		persona_system_dialogue = str(data.executor_system_short).strip_edges()
	if data.has("few_shot") and data.few_shot is Array:
		persona_few_shot = data.few_shot

func _format_few_shot() -> Array[String]:
	var lines: Array[String] = []
	if persona_few_shot.is_empty():
		return lines
	# Restauré à 4 avec contexte 8192 tokens
	var max_examples = 4
	var count = 0
	for ex in persona_few_shot:
		if count >= max_examples:
			break
		if typeof(ex) != TYPE_DICTIONARY:
			continue
		if not ex.has("user") or not ex.has("assistant"):
			continue
		var u = _ascii_only(str(ex.user).strip_edges())
		var a = _ascii_only(str(ex.assistant).strip_edges())
		if u == "" or a == "":
			continue
		lines.append("U: " + u)
		lines.append("M: " + a)
		count += 1
	return lines

func _is_complex_request(text: String) -> bool:
	var t = text.to_lower()
	var keywords = ["regles", "explique", "expliquer", "details", "detail", "liste", "exemples", "plusieurs", "etapes", "comment", "pourquoi", "donne"]
	for k in keywords:
		if t.find(k) != -1:
			return true
	return t.length() > 70

func _stamp() -> String:
	var now = Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d]" % [now.hour, now.minute, now.second]

func _init_loading_timer() -> void:
	if loading_timer != null:
		return
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.35
	loading_timer.one_shot = false
	add_child(loading_timer)
	loading_timer.timeout.connect(_on_loading_tick)

func _start_loading() -> void:
	loading_active = true
	loading_tick = 0
	loading_stamp = _stamp()
	var line = loading_stamp + " [b]Merlin:[/b]" + LOADING_FRAMES[loading_tick]
	_append_chat(line)
	loading_index = chat_lines.size() - 1
	if loading_timer:
		loading_timer.start()

func _on_loading_tick() -> void:
	if not loading_active:
		return
	loading_tick = (loading_tick + 1) % LOADING_FRAMES.size()
	var line = loading_stamp + " [b]Merlin:[/b]" + LOADING_FRAMES[loading_tick]
	_set_chat_line(loading_index, line)

func _finish_loading(answer: String, typewriter: bool) -> void:
	loading_active = false
	if loading_timer:
		loading_timer.stop()
	if loading_index == -1:
		if typewriter:
			await _append_chat_typewriter(_stamp() + " [b]Merlin:[/b] ", answer)
		else:
			_append_chat(_stamp() + " [b]Merlin:[/b] " + answer)
	else:
		if typewriter:
			await _typewriter_on_line(loading_index, _stamp() + " [b]Merlin:[/b] ", answer)
		else:
			_set_chat_line(loading_index, _stamp() + " [b]Merlin:[/b] " + answer)
	loading_index = -1

func _append_chat_typewriter(prefix: String, text: String) -> void:
	_append_chat(prefix)
	var index = chat_lines.size() - 1
	await _typewriter_on_line(index, prefix, text)

func _typewriter_on_line(index: int, prefix: String, text: String) -> void:
	typing_active = true
	var shown = ""
	for i in text.length():
		shown += text[i]
		_set_chat_line(index, prefix + shown)
		await get_tree().create_timer(TYPEWRITER_DELAY).timeout
	typing_active = false

func _set_input_busy(flag: bool) -> void:
	if input_field:
		input_field.editable = not flag
	if send_button:
		send_button.disabled = flag

func _on_diag_pressed() -> void:
	_run_diagnostic(true)

func _run_diagnostic(verbose: bool) -> void:
	var lines: Array[String] = []
	lines.append("=== Diagnostic MerlinAI ===")
	lines.append("MerlinAI present: " + str(merlin_ai != null))
	if merlin_ai:
		var status: Dictionary = merlin_ai.get_status()
		lines.append("Status: " + str(status.get("status", "")))
		lines.append("Detail: " + str(status.get("detail", "")))
		lines.append("Ready: " + str(status.get("ready", false)))
		if merlin_ai.has_method("get_performance_stats"):
			var perf: Dictionary = merlin_ai.get_performance_stats()
			lines.append("\n=== Performance ===")
			lines.append("Last TTFT: " + str(perf.get("last_ttft_ms", 0)) + "ms")
			lines.append("Last Total: " + str(perf.get("last_total_ms", 0)) + "ms")
			lines.append("Avg TTFT: " + str(perf.get("avg_ttft_ms", "0.0")) + "ms")
			lines.append("Avg Total: " + str(perf.get("avg_total_ms", "0.0")) + "ms")
			lines.append("LLM Calls: " + str(perf.get("llm_calls", 0)))
		if merlin_ai.has_method("get_routing_stats"):
			var routing: Dictionary = merlin_ai.get_routing_stats()
			lines.append("\n=== Routing ===")
			lines.append("Fast hits: " + str(routing.get("fast_route_hits", 0)))
			lines.append("LLM routes: " + str(routing.get("llm_route_calls", 0)))
	var router_path = "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
	var exec_path = "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
	if merlin_ai and merlin_ai.has_method("get_model_info"):
		var info: Dictionary = merlin_ai.get_model_info()
		router_path = str(info.get("router", router_path))
		exec_path = str(info.get("executor", exec_path))
	lines.append("\n=== Models ===")
	lines.append("Router: " + str(FileAccess.file_exists(router_path)))
	lines.append("Executor: " + str(FileAccess.file_exists(exec_path)))
	if verbose:
		lines.append("\n=== Paths ===")
		lines.append(ProjectSettings.globalize_path(router_path))
		lines.append(ProjectSettings.globalize_path(exec_path))
	# Afficher dans le panneau log au lieu du chat
	if log_text:
		log_text.text = "\n".join(lines)
	else:
		_append_chat("\n".join(lines))
