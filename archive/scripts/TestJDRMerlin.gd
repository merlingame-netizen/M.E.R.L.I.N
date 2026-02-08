extends Control

# JDR Merlin - interface JDR narrative pilotee par le LLM (sans fallback).

const HISTORY_LIMIT := 8

const SYSTEM_PROMPT := """Tu es Merlin l'Enchanteur, narrateur omniscient d'un JDR celtique (DRU).
Tonalite epique-celtique, mysterieuse, sensorielle. Tu restes bienveillant, espi gle, jamais cru.
Tu dois proposer 4 choix distincts:
1) Heroique/direct (souvent FOR/Combat)
2) Prudent/tactique (INT/DEX)
3) Social/diplomatique (CHA/SAG)
4) Alternatif/creatif (usage environnement/magie)

Regles rapides:
- Lancer un test si action risquee ou opposee.
- Test: 1d20 + mod attribut vs DD (10 facile, 15 moyen, 20 difficile, 25 tres difficile).
- Mentionne consequences success/ echec de maniere courte.

RETOURNE STRICTEMENT un JSON:
{
  "narration": "texte immersif",
  "status": "PV: x/y | PM: x/y | Conditions: ...",
  "options": [
	{"label": "...", "quote": "...", "type": "heroic|tactical|social|creative", "test": "FOR DD 15"},
	{"label": "...", "quote": "...", "type": "tactical", "test": ""},
	{"label": "...", "quote": "...", "type": "social", "test": ""},
	{"label": "...", "quote": "...", "type": "creative", "test": ""}
  ],
  "free_input_hint": "Saisie libre...",
  "events": ["event court optionnel", "..."],
  "xp": 0
}

Aucun texte hors JSON. Pas d'emojis. Pas de listes numerotees hors JSON."""

const CLASSES := [
	{"breton": "Draouiz", "classic": "Druide", "preset": {"FOR": 10, "DEX": 11, "CON": 11, "INT": 10, "SAG": 16, "CHA": 14}},
	{"breton": "Brezelour", "classic": "Guerrier", "preset": {"FOR": 16, "DEX": 12, "CON": 14, "INT": 8, "SAG": 10, "CHA": 12}},
	{"breton": "Barzh", "classic": "Barde", "preset": {"FOR": 10, "DEX": 12, "CON": 12, "INT": 10, "SAG": 12, "CHA": 16}},
	{"breton": "Skourier", "classic": "Eclaireur", "preset": {"FOR": 10, "DEX": 16, "CON": 12, "INT": 12, "SAG": 12, "CHA": 10}}
]
const ATTRS := ["FOR", "DEX", "CON", "INT", "SAG", "CHA"]
const TOTAL_POINTS := 72

const XP_TABLE := {
	1: 0,
	2: 300,
	3: 900,
	4: 2700,
	5: 6500,
	6: 14000,
	7: 23000,
	8: 34000,
	9: 48000,
	10: 64000
}

@onready var sheet_text: RichTextLabel = $MainVBox/Content/SheetPanel/SheetVBox/SheetText
@onready var journal_text: RichTextLabel = $MainVBox/Content/SheetPanel/SheetVBox/JournalText
@onready var narration_text: RichTextLabel = $MainVBox/Content/NarrationPanel/NarrationVBox/NarrationScroll/NarrationText
@onready var option_buttons: Array[Button] = [
	$MainVBox/OptionsPanel/OptionsVBox/OptionsButtons/Option1,
	$MainVBox/OptionsPanel/OptionsVBox/OptionsButtons/Option2,
	$MainVBox/OptionsPanel/OptionsVBox/OptionsButtons/Option3,
	$MainVBox/OptionsPanel/OptionsVBox/OptionsButtons/Option4
]
@onready var input_field: LineEdit = $MainVBox/InputPanel/InputField
@onready var send_button: Button = $MainVBox/InputPanel/SendButton
@onready var title_label: Label = $MainVBox/Header/Title
@onready var main_vbox: VBoxContainer = $MainVBox

@onready var llm_panel: PanelContainer = $LLMPanel
@onready var llm_status: Label = $LLMPanel/LLMVBox/LLMStatus
@onready var llm_detail: Label = $LLMPanel/LLMVBox/LLMDetail
@onready var llm_progress: ProgressBar = $LLMPanel/LLMVBox/LLMProgress
@onready var llm_reload_button: Button = $LLMPanel/LLMVBox/LLMReloadButton
@onready var router_temp: SpinBox = $LLMPanel/LLMVBox/RouterRow/RouterTemp
@onready var router_top_p: SpinBox = $LLMPanel/LLMVBox/RouterRow/RouterTopP
@onready var router_max: SpinBox = $LLMPanel/LLMVBox/RouterRow/RouterMax
@onready var exec_temp: SpinBox = $LLMPanel/LLMVBox/ExecutorRow/ExecTemp
@onready var exec_top_p: SpinBox = $LLMPanel/LLMVBox/ExecutorRow/ExecTopP
@onready var exec_max: SpinBox = $LLMPanel/LLMVBox/ExecutorRow/ExecMax
@onready var apply_params_button: Button = $LLMPanel/LLMVBox/ApplyParamsButton
@onready var llm_logs: TextEdit = $LLMPanel/LLMVBox/LLMLogs
@onready var copy_logs_button: Button = $LLMPanel/LLMVBox/CopyLogsButton

@onready var creation_panel: PanelContainer = $CreationPanel
@onready var name_field: LineEdit = $CreationPanel/CreationVBox/NameRow/NameField
@onready var class_option: OptionButton = $CreationPanel/CreationVBox/ClassRow/ClassOption
@onready var points_label: Label = $CreationPanel/CreationVBox/PointsRow/PointsLabel
@onready var start_button: Button = $CreationPanel/CreationVBox/StartRow/StartButton

@onready var stat_spins := {
	"FOR": $CreationPanel/CreationVBox/StatsGrid/StatFOR,
	"DEX": $CreationPanel/CreationVBox/StatsGrid/StatDEX,
	"CON": $CreationPanel/CreationVBox/StatsGrid/StatCON,
	"INT": $CreationPanel/CreationVBox/StatsGrid/StatINT,
	"SAG": $CreationPanel/CreationVBox/StatsGrid/StatSAG,
	"CHA": $CreationPanel/CreationVBox/StatsGrid/StatCHA
}

var merlin_ai: Node = null
var llm_ready := false
var is_thinking := false
var history: Array = []
var last_options: Array = []
var journal_entries: Array = []
var _thinking_time := 0.0

var player_state := {
	"name": "Aerin",
	"class": "Druide",
	"level": 1,
	"stats": {"FOR": 10, "DEX": 11, "CON": 11, "INT": 10, "SAG": 14, "CHA": 12},
	"hp": 10,
	"hp_max": 10,
	"pm": 3,
	"pm_max": 3,
	"xp": 0,
	"conditions": [],
	"inventory": ["Baton de druide", "Sacoche de composantes"],
	"quest": "L'Eveil (Acte I)"
}

func _ready() -> void:
	set_process(true)
	_init_fonts()
	_apply_theme()
	_init_buttons()
	_bind_merlin_ai()
	_update_sheet()
	_setup_character_creation()
	_set_jdr_enabled(false)
	main_vbox.visible = false
	creation_panel.visible = true
	llm_panel.z_index = 50
	llm_panel.z_as_relative = false
	llm_panel.top_level = true

func _process(delta: float) -> void:
	if is_thinking:
		_thinking_time += delta
		var wave = 0.5 + 0.5 * sin(_thinking_time * 3.0)
		_set_llm_status("LLM: Reflexion...", "Generation en cours", 20.0 + wave * 60.0)

func _init_fonts() -> void:
	var font_path = "res://resources/fonts/morris/MorrisRomanBlack.ttf"
	if ResourceLoader.exists(font_path):
		var font = load(font_path)
		title_label.add_theme_font_override("font", font)
		title_label.add_theme_font_size_override("font_size", 40)

func _bind_merlin_ai() -> void:
	if has_node("/root/MerlinAI"):
		merlin_ai = get_node("/root/MerlinAI")
	if merlin_ai:
		merlin_ai.status_changed.connect(_on_llm_status_changed)
		merlin_ai.ready_changed.connect(_on_llm_ready_changed)
		if merlin_ai.has_signal("log_updated"):
			merlin_ai.log_updated.connect(_on_llm_log_updated)
		if merlin_ai.has_method("get_log_text"):
			_on_llm_log_updated(merlin_ai.get_log_text())
		_sync_llm_from_ai()
	else:
		_set_llm_status("Connexion: OFF", "MerlinAI introuvable.", 0.0)

func _sync_llm_from_ai() -> void:
	if merlin_ai == null:
		llm_ready = false
		return
	if merlin_ai.has_method("ensure_ready"):
		merlin_ai.ensure_ready()
	var status: Dictionary = merlin_ai.get_status()
	llm_ready = bool(status.get("ready", false))
	_set_llm_status(str(status.get("status", "Connexion: ...")), str(status.get("detail", "")), float(status.get("progress", 0.0)))
	_update_points_label()
	_load_llm_params()

func _on_llm_status_changed(status_text: String, detail_text: String, progress_value: float) -> void:
	_set_llm_status(status_text, detail_text, progress_value)

func _on_llm_ready_changed(is_ready: bool) -> void:
	llm_ready = is_ready
	_update_points_label()

func _on_llm_reload_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("reload_models"):
		merlin_ai.reload_models()

func _on_llm_log_updated(text: String) -> void:
	if llm_logs:
		llm_logs.text = text
		llm_logs.scroll_vertical = llm_logs.get_line_count()

func _apply_theme() -> void:
	var panel_bg = StyleBoxFlat.new()
	panel_bg.bg_color = Color(0.08, 0.09, 0.12)
	panel_bg.border_color = Color(0.65, 0.52, 0.25)
	panel_bg.set_border_width_all(2)
	panel_bg.set_corner_radius_all(6)
	for panel in [ $MainVBox/Content/SheetPanel, $MainVBox/Content/NarrationPanel, $MainVBox/OptionsPanel, $CreationPanel, llm_panel ]:
		if panel:
			panel.add_theme_stylebox_override("panel", panel_bg)

	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.06, 0.07, 0.1)
	button_style.border_color = Color(0.65, 0.52, 0.25)
	button_style.set_border_width_all(2)
	button_style.set_corner_radius_all(6)
	var button_hover = button_style.duplicate()
	button_hover.bg_color = Color(0.12, 0.14, 0.2)
	var button_pressed = button_style.duplicate()
	button_pressed.bg_color = Color(0.12, 0.12, 0.16)
	for btn in option_buttons:
		_style_button(btn, button_style, button_hover, button_pressed)
	_style_button(send_button, button_style, button_hover, button_pressed)
	_style_button(start_button, button_style, button_hover, button_pressed)
	if llm_reload_button:
		_style_button(llm_reload_button, button_style, button_hover, button_pressed)
		llm_reload_button.custom_minimum_size = Vector2(0, 24)
	if apply_params_button:
		_style_button(apply_params_button, button_style, button_hover, button_pressed)
		apply_params_button.custom_minimum_size = Vector2(0, 24)
	if copy_logs_button:
		_style_button(copy_logs_button, button_style, button_hover, button_pressed)
		copy_logs_button.custom_minimum_size = Vector2(0, 24)

func _style_button(btn: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	btn.add_theme_color_override("font_hover_color", Color(0.98, 0.88, 0.45))
	btn.add_theme_color_override("font_pressed_color", Color(0.98, 0.88, 0.45))

func _setup_character_creation() -> void:
	for c in CLASSES:
		class_option.add_item("%s (%s)" % [c.breton, c.classic])
	name_field.text = player_state.name
	class_option.select(0)
	class_option.item_selected.connect(_on_class_selected)
	for a in ATTRS:
		var spin: SpinBox = stat_spins[a]
		spin.min_value = 8
		spin.max_value = 18
		spin.step = 1
		spin.value = 12
		spin.value_changed.connect(_on_stat_changed)
	_apply_class_preset(0)
	_update_points_label()
	start_button.pressed.connect(_on_start_pressed)

func _on_class_selected(index: int) -> void:
	_apply_class_preset(index)
	_update_points_label()

func _apply_class_preset(index: int) -> void:
	var idx = clampi(index, 0, CLASSES.size() - 1)
	var preset = CLASSES[idx].preset
	for a in ATTRS:
		if preset.has(a):
			stat_spins[a].value = int(preset[a])

func _on_stat_changed(_value: float) -> void:
	_update_points_label()

func _update_points_label() -> void:
	var sum = 0
	for a in ATTRS:
		sum += int(stat_spins[a].value)
	var remaining = TOTAL_POINTS - sum
	points_label.text = "Points restants: %d" % remaining
	start_button.disabled = remaining != 0 or not llm_ready

func _on_start_pressed() -> void:
	if not llm_ready:
		_set_llm_status("Connexion: OFF", "LLM non pret. Rechargez le modele.", 0.0)
		return
	var sum = 0
	var stats = {}
	for a in ATTRS:
		stats[a] = int(stat_spins[a].value)
		sum += stats[a]
	if sum != TOTAL_POINTS:
		return
	player_state.name = name_field.text.strip_edges() if name_field.text.strip_edges() != "" else player_state.name
	var sel = 0
	if class_option.has_method("get_selected_id"):
		sel = class_option.get_selected_id()
	else:
		sel = class_option.selected
	sel = clampi(sel, 0, CLASSES.size() - 1)
	player_state.class = "%s (%s)" % [CLASSES[sel].breton, CLASSES[sel].classic]
	player_state.stats = stats
	_update_sheet()
	creation_panel.visible = false
	main_vbox.visible = true
	_set_jdr_enabled(true)
	_start_session()

func _set_jdr_enabled(enabled: bool) -> void:
	for btn in option_buttons:
		btn.disabled = not enabled
	send_button.disabled = not enabled
	input_field.editable = enabled

func _init_buttons() -> void:
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_text_submitted)
	for i in range(option_buttons.size()):
		option_buttons[i].pressed.connect(_on_option_pressed.bind(i))
	if llm_reload_button:
		llm_reload_button.pressed.connect(_on_llm_reload_pressed)
	if apply_params_button:
		apply_params_button.pressed.connect(_on_apply_params_pressed)
	if copy_logs_button:
		copy_logs_button.pressed.connect(_on_copy_logs_pressed)

func _start_session() -> void:
	narration_text.clear()
	_append_narration("[i]Connexion au LLM... preparation de la narration.[/i]")
	_request_llm("Demarre la campagne Acte I. Situation initiale. Invite le heros a agir.")

func _on_send_pressed() -> void:
	var text = input_field.text.strip_edges()
	if text == "":
		return
	input_field.text = ""
	_request_llm(text)

func _on_text_submitted(_text: String) -> void:
	_on_send_pressed()

func _on_option_pressed(idx: int) -> void:
	if idx < 0 or idx >= last_options.size():
		return
	var opt = last_options[idx]
	var chosen = opt.get("label", "")
	var quote = opt.get("quote", "")
	var line = chosen
	if quote != "":
		line += " -- \"" + quote + "\""
	var test_info = _parse_test(str(opt.get("test", "")))
	if not test_info.is_empty():
		var test_result = _roll_test(test_info.attr, test_info.dd)
		_append_narration(test_result.text)
		line += " " + test_result.tag
	_request_llm(line)

func _request_llm(user_input: String) -> void:
	_sync_llm_from_ai()
	if not llm_ready or merlin_ai == null:
		_set_llm_status("Connexion: OFF", "LLM indisponible. Rechargez le modele.", 0.0)
		return
	if is_thinking:
		return
	is_thinking = true
	_thinking_time = 0.0
	_set_llm_status("LLM: Reflexion...", "Generation en cours", 15.0)
	_append_narration("\n[b]Vous[/b] : " + user_input)
	_append_journal("Vous: " + user_input)
	history.append({"role": "user", "content": user_input})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT, history.size())
	var prompt = _build_prompt(user_input)
	var response_json = await _generate_llm_json(prompt)
	if response_json == "":
		_set_llm_status("LLM: Erreur", "Reponse vide / timeout.", 0.0)
		is_thinking = false
		return
	_handle_llm_json(response_json)
	_set_llm_status("LLM: Pret", "Derniere reponse recue.", 100.0)
	is_thinking = false
	_thinking_time = 0.0

func _load_llm_params() -> void:
	if merlin_ai == null:
		return
	if merlin_ai.has_method("get_router_params"):
		var router = merlin_ai.get_router_params()
		router_temp.value = float(router.temperature)
		router_top_p.value = float(router.top_p)
		router_max.value = int(router.max_tokens)
	if merlin_ai.has_method("get_executor_params"):
		var exec = merlin_ai.get_executor_params()
		exec_temp.value = float(exec.temperature)
		exec_top_p.value = float(exec.top_p)
		exec_max.value = int(exec.max_tokens)

func _on_apply_params_pressed() -> void:
	if merlin_ai == null:
		return
	merlin_ai.set_router_params(router_temp.value, router_top_p.value, int(router_max.value))
	merlin_ai.set_executor_params(exec_temp.value, exec_top_p.value, int(exec_max.value))

func _on_copy_logs_pressed() -> void:
	if merlin_ai and merlin_ai.has_method("get_log_text"):
		DisplayServer.clipboard_set(merlin_ai.get_log_text())

func _build_prompt(user_input: String) -> String:
	var ctx = "ETAT JOUEUR:\n" + JSON.stringify(player_state) + "\n"
	ctx += "HISTORIQUE:\n"
	for h in history:
		ctx += h.role + ": " + h.content + "\n"
	ctx += "\nACTION JOUEUR:\n" + user_input + "\n"
	ctx += "Reponds au format JSON demande."
	return ctx

func _generate_llm_json(prompt: String) -> String:
	if merlin_ai == null:
		return ""
	_set_llm_status("LLM: Reflexion...", "Generation en cours", 15.0)
	var result: Dictionary = await merlin_ai.generate_with_system(SYSTEM_PROMPT, prompt, {
		"temperature": 0.8,
		"top_p": 0.9,
		"max_tokens": 700
	})
	if result.has("error"):
		return ""
	var text := ""
	if result.has("text"):
		text = str(result.text).strip_edges()
	elif result.has("lines") and result.lines.size() > 0:
		text = str(result.lines[0]).strip_edges()
	return text

func _handle_llm_json(response_json: String) -> void:
	var json = JSON.new()
	var parse = json.parse(response_json)
	if parse != OK:
		_append_narration("\n[b]Merlin[/b] : (reponse illisible) Reessayons.")
		_set_llm_status("LLM: Erreur JSON", "Reponse invalide.", 0.0)
		return
	if not (json.data is Dictionary):
		_append_narration("\n[b]Merlin[/b] : (format inattendu) Reessayons.")
		_set_llm_status("LLM: Erreur format", "Reponse invalide.", 0.0)
		return
	var data: Dictionary = json.data
	if data.has("narration"):
		_append_narration("\n[b]Merlin[/b] : " + str(data.narration))
		_append_journal("Merlin: " + str(data.narration))
	if data.has("status"):
		_update_status_line(str(data.status))
	if data.has("options"):
		_update_options(data.options)
	if data.has("free_input_hint"):
		input_field.placeholder_text = str(data.free_input_hint)
	if data.has("events") and data.events is Array:
		for ev in data.events:
			_append_journal("Evenement: " + str(ev))
	if data.has("xp"):
		var xp_gain = int(data.xp)
		if xp_gain != 0:
			_add_xp(xp_gain, "Narration")
	history.append({"role": "assistant", "content": str(data.get("narration", ""))})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT, history.size())

func _update_sheet() -> void:
	var stats = player_state.stats
	var lines = []
	lines.append("[b]Nom:[/b] %s" % player_state.name)
	lines.append("[b]Classe:[/b] %s   [b]Niv:[/b] %d" % [player_state.class, player_state.level])
	lines.append("")
	lines.append("[b]FOR[/b] %d  [b]DEX[/b] %d  [b]CON[/b] %d" % [stats.FOR, stats.DEX, stats.CON])
	lines.append("[b]INT[/b] %d  [b]SAG[/b] %d  [b]CHA[/b] %d" % [stats.INT, stats.SAG, stats.CHA])
	lines.append("")
	lines.append("[b]PV[/b] %d/%d   [b]PM[/b] %d/%d" % [player_state.hp, player_state.hp_max, player_state.pm, player_state.pm_max])
	lines.append("[b]XP[/b] %d  [b]Niv[/b] %d" % [player_state.xp, player_state.level])
	lines.append("[b]Quete:[/b] %s" % player_state.quest)
	lines.append("")
	lines.append("[b]Inventaire:[/b]")
	for item in player_state.inventory:
		lines.append("- " + item)
	sheet_text.text = "\n".join(lines)

func _update_status_line(status_text: String) -> void:
	# Mise a jour minimaliste (affichage uniquement).
	var clean = status_text.strip_edges()
	if clean != "":
		_append_narration("\n[i]" + clean + "[/i]")
		_parse_and_apply_status(clean)

func _parse_and_apply_status(line: String) -> void:
	var pv_re = RegEx.new()
	pv_re.compile("PV:\\s*(\\d+)\\/(\\d+)")
	var pm_re = RegEx.new()
	pm_re.compile("PM:\\s*(\\d+)\\/(\\d+)")
	var pv = pv_re.search(line)
	if pv:
		player_state.hp = int(pv.get_string(1))
		player_state.hp_max = int(pv.get_string(2))
	var pm = pm_re.search(line)
	if pm:
		player_state.pm = int(pm.get_string(1))
		player_state.pm_max = int(pm.get_string(2))
	_update_sheet()

func _update_options(opts: Array) -> void:
	last_options = opts
	for i in range(option_buttons.size()):
		if i < opts.size():
			var opt = opts[i]
			var label = str(opt.get("label", "Option %d" % (i + 1)))
			var quote = str(opt.get("quote", ""))
			var display = "Option %d: %s" % [i + 1, label]
			if quote != "":
				display += " - \"" + quote + "\""
			option_buttons[i].text = display
			option_buttons[i].disabled = false
		else:
			option_buttons[i].text = "Option %d: ..." % (i + 1)
			option_buttons[i].disabled = true

func _append_narration(text: String) -> void:
	narration_text.append_text(text + "\n")
	narration_text.scroll_to_line(narration_text.get_line_count())

func _append_journal(line: String) -> void:
	journal_entries.append(line)
	if journal_entries.size() > 50:
		journal_entries = journal_entries.slice(journal_entries.size() - 50, journal_entries.size())
	journal_text.text = "\n".join(journal_entries)
	journal_text.scroll_to_line(journal_text.get_line_count())

func _set_llm_status(status_text: String, detail_text: String, progress_value: float) -> void:
	if llm_status:
		llm_status.text = "Statut: " + status_text
	if llm_detail:
		llm_detail.text = detail_text
	if llm_progress:
		llm_progress.value = clampf(progress_value, 0.0, 100.0)

func _add_xp(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	player_state.xp += amount
	_append_journal("XP +" + str(amount) + " (" + reason + ")")
	_check_level_up()
	_update_sheet()

func _check_level_up() -> void:
	var level = player_state.level
	while level < 10:
		var next_xp = _xp_for_level(level + 1)
		if player_state.xp >= next_xp:
			level += 1
			player_state.level = level
			_append_journal("Niveau atteint: " + str(level))
		else:
			break

func _xp_for_level(level: int) -> int:
	if XP_TABLE.has(level):
		return XP_TABLE[level]
	return XP_TABLE[10]

func _parse_test(test_str: String) -> Dictionary:
	var clean = test_str.strip_edges()
	if clean == "":
		return {}
	var parts = clean.split(" ")
	if parts.size() < 3:
		return {}
	var attr = parts[0].to_upper()
	if not ATTRS.has(attr):
		return {}
	var dd = int(parts[2])
	return {"attr": attr, "dd": dd}

func _attribute_mod(attr: String) -> int:
	var score = int(player_state.stats.get(attr, 10))
	return int(floor((float(score) - 10.0) / 2.0))

func _roll_test(attr: String, dd: int) -> Dictionary:
	var roll = randi_range(1, 20)
	var mod = _attribute_mod(attr)
	var total = roll + mod
	var success = total >= dd
	var result_text = "[i]Test %s DD %d: 1d20=%d + mod(%+d) = %d -> %s[/i]" % [attr, dd, roll, mod, total, "SUCCES" if success else "ECHEC"]
	return {"text": result_text, "tag": "[TEST %s %d %d]" % [attr, dd, total], "success": success}

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
