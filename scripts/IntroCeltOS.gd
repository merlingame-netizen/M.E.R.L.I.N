extends Control

## IntroCeltOS — Retro CRT Boot (amber/gold scanline reveal)
## Phase 1: CELTOS logo revealed line-by-line top-to-bottom (golden lines)
## Phase 2: Boot logs typed progressively (randomized each launch)
## Phase 3: SYSTEM READY + cursor blink, LLM prewarm for menu greeting
## No ScreenFrame, no SceneSelector during intro

# ═══════════════════════════════════════════════════════════════
# CELTOS pixel grid (23x5)
# ═══════════════════════════════════════════════════════════════
const LOGO_GRID := [
	[1,1,1,0,1,1,1,0,1,0,0,0,1,1,1,0,1,1,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,0,0],
	[1,0,0,0,1,1,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1],
	[1,1,1,0,1,1,1,0,1,1,1,0,0,1,0,0,1,1,1,0,1,1,1],
]

# ═══════════════════════════════════════════════════════════════
# Boot log pools — 12 picked randomly each launch
# ═══════════════════════════════════════════════════════════════
const BOOT_HEADER := "CELTOS v4.2 — INITIATING MEMORY NODES"

const BOOT_LOG_POOL := [
	"LOADING /dev/rune/18 ... [OK]",
	"MOUNTING SACRED_GROVES_PARTITION ... [OK]",
	"INITIALIZING FACTION_MATRIX (5 branches) ... [OK]",
	"LINKING /lib/merlin/arcana.so ... [OK]",
	"CHECKING LEYLINE INTEGRITY ... [OK]",
	"LOADING FASTROUTE_CARD_POOL (500+ entries) ... [OK]",
	"SPAWNING DAEMON: merlin-omniscient.service ... [OK]",
	"CALIBRATING ANAM_ACCUMULATOR ... [OK]",
	"BINDING BIOME_SHADERS to /dev/gpu ... [OK]",
	"VERIFYING DRUID_CONSENSUS_PROTOCOL ... [OK]",
	"SYNCING CAULDRON_STATE ... [OK]",
	"SCANNING BROCELIANDE_SECTOR_MAP ... [OK]",
	"LOADING /etc/celtic/rune_table.cfg ... [OK]",
	"MOUNTING ANAM_PERSISTENCE_LAYER ... [OK]",
	"INITIALIZING CONFIANCE_TRACKER (T0-T3) ... [OK]",
	"LINKING /lib/merlin/narrator.so ... [OK]",
	"CHECKING DRUID_MEMORY_POOL (4096 MB) ... [OK]",
	"LOADING MINIGAME_ENGINE (8 lexical fields) ... [OK]",
	"SPAWNING DAEMON: rag-context.service ... [OK]",
	"CALIBRATING MOS_CONVERGENCE_TARGET (20-25) ... [OK]",
	"BINDING CELTIC_AUDIO_PIPELINE ... [OK]",
	"VERIFYING RUNE_ACTIVATION_SLOTS (3 starters) ... [OK]",
	"SYNCING REPUTATION_CROSS_RUN_STATE ... [OK]",
	"SCANNING HUB_ANTRE_GEOMETRY ... [OK]",
	"LOADING /dev/faction/5 ... [OK]",
	"MOUNTING VERB_MATRIX_45_ENTRIES ... [OK]",
	"INITIALIZING PIXEL_TRANSITION_SHADER ... [OK]",
	"LINKING /lib/merlin/brain_swarm.so ... [OK]",
	"CHECKING SAVE_PROFILE_INTEGRITY ... [OK]",
	"LOADING BIOME_MATURITY_SCORES (8 biomes) ... [OK]",
]

const BOOT_FINAL := "SYSTEM READY — AWAITING PLAYER INVOCATION"

# ═══════════════════════════════════════════════════════════════
# Colors — Amber/gold retro (NOT green Fallout)
# ═══════════════════════════════════════════════════════════════
const GOLD := Color(0.90, 0.75, 0.30)
const GOLD_DIM := Color(0.55, 0.45, 0.18)
const GOLD_BRIGHT := Color(1.00, 0.85, 0.40)
const GOLD_FAINT := Color(0.55, 0.45, 0.18, 0.5)
const BG_BLACK := Color(0.02, 0.02, 0.02)

# Layout
const FONT_LOG := 13
const FONT_HEADER := 15
const FONT_KERNEL := 9
const FONT_SPINNER := 10
const LOG_COUNT := 12
const BLOCK_SIZE := 10.0
const BLOCK_GAP := 2.0

# ═══════════════════════════════════════════════════════════════
# LLM Prewarm — generates Merlin's menu greeting during boot
# ═══════════════════════════════════════════════════════════════
const MERLIN_GREETING_SYSTEM := """Tu es Merlin, un druide-IA bienveillant et enigmatique.
Tu accueilles le joueur sur le menu principal du jeu M.E.R.L.I.N.
Reponds en UNE SEULE phrase courte (max 20 mots), poetique et mystique.
Adapte ton message au contexte fourni (temps d'absence, date, saison, heure, derniere partie).
Exemples de ton:
- "Les etoiles m'ont souffle que tu reviendrais... bienvenue, voyageur."
- "Le solstice approche, et avec lui, de nouveaux mysteres."
- "Trois lunes sans nouvelles... les runes s'impatientaient."
Ne mets PAS de guillemets autour de ta reponse. Reponds directement."""

# --- UI nodes ---
var _background: ColorRect
var _header_label: Label
var _log_container: VBoxContainer
var _log_labels: Array[Label] = []
var _cursor_label: Label
var _spinner_label: Label
var _spinner_frame := 0

# --- State ---
var _warmup_done := false
var _transitioning := false
var _selected_logs: Array[String] = []
var _merlin_greeting := ""
var _llm_prewarm_done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Hide ScreenFrame and SceneSelector during intro
	_hide_autoload("ScreenFrame")
	_hide_autoload("SceneSelector")
	_pick_random_logs()
	_build_ui()
	_prewarm_llm()
	MusicManager.play_intro_music()
	_start_phase_1()


func _exit_tree() -> void:
	_transitioning = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore ScreenFrame and SceneSelector
	_show_autoload("ScreenFrame")
	_show_autoload("SceneSelector")


func _hide_autoload(autoload_name: String) -> void:
	var node := get_node_or_null("/root/" + autoload_name)
	if node and node is CanvasLayer:
		node.visible = false
	elif node and node is Control:
		node.visible = false


func _show_autoload(autoload_name: String) -> void:
	var node := get_node_or_null("/root/" + autoload_name)
	if node and node is CanvasLayer:
		node.visible = true
	elif node and node is Control:
		node.visible = true


func _pick_random_logs() -> void:
	var pool := BOOT_LOG_POOL.duplicate()
	pool.shuffle()
	_selected_logs.clear()
	for i in range(mini(LOG_COUNT, pool.size())):
		_selected_logs.append(pool[i])


# ═══════════════════════════════════════════════════════════════
# LLM PREWARM — Fires greeting generation in background
# ═══════════════════════════════════════════════════════════════

func _prewarm_llm() -> void:
	# Build context for Merlin's greeting
	var context_parts: Array[String] = []

	# Time context
	var now := Time.get_datetime_dict_from_system()
	var hour: int = now.get("hour", 12)
	var month: int = now.get("month", 1)
	var day: int = now.get("day", 1)
	var weekday: int = now.get("weekday", 0)

	var time_of_day := "matin" if hour < 12 else ("apres-midi" if hour < 18 else "soir")
	var season := _get_season(month, day)
	var day_names := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
	var day_name: String = day_names[weekday] if weekday < day_names.size() else "jour"
	context_parts.append("Il est %dh, %s %d/%d (%s, %s)." % [hour, day_name, day, month, time_of_day, season])

	# Last session timestamp from save
	var save_path := "user://merlin_profile.json"
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.data if json.data is Dictionary else {}
				var last_ts: int = int(data.get("timestamp", 0))
				if last_ts > 0:
					var now_ts: int = int(Time.get_unix_time_from_system())
					var diff_sec: float = float(now_ts - last_ts)
					var diff_hours: int = int(diff_sec / 3600.0)
					if diff_hours < 1:
						context_parts.append("Le joueur vient de jouer il y a moins d'une heure.")
					elif diff_hours < 24:
						context_parts.append("Le joueur a joue il y a %d heures." % diff_hours)
					elif diff_hours < 168:
						context_parts.append("Le joueur n'a pas joue depuis %d jours." % int(diff_hours / 24.0))
					else:
						context_parts.append("Le joueur n'a pas joue depuis %d semaines." % int(diff_hours / 168.0))
				# Check last run info
				var meta: Dictionary = data.get("meta", {})
				var total_runs: int = int(meta.get("total_runs", 0))
				var anam: int = int(meta.get("anam", 0))
				if total_runs > 0:
					context_parts.append("Il a fait %d aventures et accumule %d Anam." % [total_runs, anam])
					var faction_rep: Dictionary = meta.get("faction_rep", {})
					if not faction_rep.is_empty():
						var best_faction := ""
						var best_rep := 0.0
						for f in faction_rep:
							var rep: float = float(faction_rep[f])
							if rep > best_rep:
								best_rep = rep
								best_faction = f
						if best_faction != "" and best_rep > 30:
							context_parts.append("Sa faction preferee est %s (reputation %d)." % [best_faction, int(best_rep)])
	else:
		context_parts.append("C'est la toute premiere fois que le joueur lance le jeu.")

	var user_input: String = " ".join(context_parts)

	# Fire LLM generation in background (non-blocking)
	_llm_generate_greeting(user_input)


func _llm_generate_greeting(user_input: String) -> void:
	if not MerlinAI.is_ready:
		# Warmup first, then generate
		if MerlinAI.has_method("_warmup_generate"):
			await MerlinAI._warmup_generate()
		# Retry check — also guard against scene freed during await
		if _transitioning or not is_inside_tree():
			return
		if not MerlinAI.is_ready:
			_llm_prewarm_done = true
			_warmup_done = true
			return

	var result: Dictionary = await MerlinAI.generate_with_system(
		MERLIN_GREETING_SYSTEM,
		user_input,
		{"max_tokens": 60, "temperature": 0.8}
	)
	if _transitioning or not is_inside_tree():
		return
	if result.has("text") and str(result.text).strip_edges() != "":
		_merlin_greeting = str(result.text).strip_edges()
	_llm_prewarm_done = true
	_warmup_done = true


func _get_season(month: int, day: int) -> String:
	if month <= 2 or (month == 3 and day < 20) or month == 12:
		return "hiver"
	elif month <= 5 or (month == 6 and day < 21):
		return "printemps"
	elif month <= 8 or (month == 9 and day < 22):
		return "ete"
	return "automne"


# ═══════════════════════════════════════════════════════════════
# BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Pure black background
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = BG_BLACK
	add_child(_background)

	# Header label — starts near top (no logo above)
	var logs_start_y := vp.y * 0.08
	_header_label = Label.new()
	_header_label.text = BOOT_HEADER
	_header_label.position = Vector2(vp.x * 0.08, logs_start_y)
	_header_label.add_theme_font_size_override("font_size", FONT_HEADER)
	_header_label.add_theme_color_override("font_color", GOLD)
	_header_label.modulate.a = 0.0
	add_child(_header_label)

	# Log container
	_log_container = VBoxContainer.new()
	_log_container.position = Vector2(vp.x * 0.10, logs_start_y + 30)
	_log_container.add_theme_constant_override("separation", 3)
	add_child(_log_container)

	for i in range(_selected_logs.size()):
		var label := Label.new()
		label.text = ""
		label.add_theme_font_size_override("font_size", FONT_LOG)
		label.add_theme_color_override("font_color", GOLD_DIM)
		label.modulate.a = 0.0
		_log_container.add_child(label)
		_log_labels.append(label)

	# Final line + cursor
	_cursor_label = Label.new()
	_cursor_label.text = ""
	_cursor_label.add_theme_font_size_override("font_size", FONT_LOG)
	_cursor_label.add_theme_color_override("font_color", GOLD)
	_cursor_label.modulate.a = 0.0
	_log_container.add_child(_cursor_label)

	# Loading spinner (bottom-right)
	_spinner_label = Label.new()
	_spinner_label.text = ""
	_spinner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spinner_label.position = Vector2(vp.x - 80, vp.y - 30)
	_spinner_label.size = Vector2(60, 20)
	_spinner_label.add_theme_font_size_override("font_size", FONT_SPINNER)
	_spinner_label.add_theme_color_override("font_color", GOLD_FAINT)
	add_child(_spinner_label)


func _process(_delta: float) -> void:
	if _transitioning:
		return
	# Animate loading spinner bottom-right
	if not _warmup_done:
		var frames := ["|", "/", "-", "\\"]
		_spinner_frame = (_spinner_frame + 1) % (frames.size() * 3)
		_spinner_label.text = frames[int(_spinner_frame / 3.0)]
	else:
		_spinner_label.text = ""


# ============================================================
# PHASE 1 — Logo scanline reveal (top to bottom, golden lines)
# ============================================================

func _start_phase_1() -> void:
	# Skip logo — go straight to boot log lines
	_header_label.modulate.a = 1.0
	SFXManager.play("boot_line")
	_start_phase_2()


# ============================================================
# PHASE 2 — Boot log lines (typed progressively, randomized)
# ============================================================

func _start_phase_2() -> void:
	if _transitioning:
		return
	var tween := create_tween()

	# Show header
	tween.tween_property(_header_label, "modulate:a", 1.0, 0.12)
	tween.tween_callback(func() -> void: SFXManager.play("boot_line"))
	tween.tween_interval(0.25)

	# Type each log line progressively using tween (no loose timers)
	for i in range(_log_labels.size()):
		var label: Label = _log_labels[i]
		var line_text: String = _selected_logs[i]
		# Show command part
		tween.tween_callback(func() -> void:
			if not is_instance_valid(label):
				return
			var ok_idx := line_text.find(" ... [OK]")
			if ok_idx >= 0:
				label.text = line_text.substr(0, ok_idx) + " ..."
			else:
				label.text = line_text
			label.add_theme_color_override("font_color", GOLD_DIM)
			label.modulate.a = 1.0
		)
		tween.tween_interval(0.10)
		# Show [OK] and flash bright
		tween.tween_callback(func() -> void:
			if not is_instance_valid(label):
				return
			label.text = line_text
			label.add_theme_color_override("font_color", GOLD)
			SFXManager.play("boot_line")
		)
		tween.tween_interval(0.08)
		# Dim back
		tween.tween_callback(func() -> void:
			if not is_instance_valid(label):
				return
			label.add_theme_color_override("font_color", GOLD_DIM)
		)

	tween.tween_interval(0.3)
	tween.tween_callback(_start_phase_3)


# ============================================================
# PHASE 3 — SYSTEM READY + cursor blink, wait for LLM prewarm
# ============================================================

func _start_phase_3() -> void:
	if _transitioning:
		return
	_cursor_label.text = BOOT_FINAL
	_cursor_label.modulate.a = 1.0
	_cursor_label.add_theme_color_override("font_color", GOLD)
	SFXManager.play("boot_confirm")
	_blink_cursor()

	# Wait for LLM prewarm to finish (or timeout)
	var wait_start := Time.get_ticks_msec()
	while not _warmup_done:
		if _transitioning or not is_inside_tree():
			return
		if Time.get_ticks_msec() - wait_start > 15000:
			_warmup_done = true
			break
		await get_tree().create_timer(0.1).timeout

	if _transitioning or not is_inside_tree():
		return
	await get_tree().create_timer(1.0).timeout

	if _transitioning or not is_inside_tree():
		return
	_fade_and_transition()


func _blink_cursor() -> void:
	var blink_tween := create_tween().set_loops(8)
	var base_text := BOOT_FINAL
	blink_tween.tween_callback(func() -> void:
		if is_instance_valid(_cursor_label):
			_cursor_label.text = base_text + "\u2588"
	)
	blink_tween.tween_interval(0.35)
	blink_tween.tween_callback(func() -> void:
		if is_instance_valid(_cursor_label):
			_cursor_label.text = base_text
	)
	blink_tween.tween_interval(0.25)


func _fade_and_transition() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_transition_to_menu)


func _transition_to_menu() -> void:
	# Pass greeting to menu via a global or meta
	if _merlin_greeting != "":
		var game_mgr := get_node_or_null("/root/GameManager")
		if game_mgr:
			game_mgr.set_meta("merlin_greeting", _merlin_greeting)

	if PixelTransition.has_method("_force_complete"):
		PixelTransition._force_complete()
	PixelTransition.transition_to("res://scenes/Menu3DPC.tscn")
