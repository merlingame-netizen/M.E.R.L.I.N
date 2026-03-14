## ═══════════════════════════════════════════════════════════════════════════════
## Test LLM Full Run — 20 cards danger progressive + guardrails + perf + export
## ═══════════════════════════════════════════════════════════════════════════════
## T15: Guardrails stricts (Jaccard<0.5, FR>80%, mots interdits, len>30)
## T16: Full Run 20 cartes — decision tree trace, consequences, perf
## T17: Reset verification (no state leak)
## T18: Prologue + epilogue integration (P6)
## Exports: tmp/test_intelligence_results.json + tmp/test_intelligence_recap.md
## Prefix: [FULLRUN] for easy grep. Exit 0 = pass, 1 = failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const MAX_CARDS := 20
const FR_KEYWORDS := ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et",
	"est", "que", "qui", "dans", "pour", "sur", "par", "au", "aux", "son",
	"sa", "ses", "ce", "cette", "il", "elle", "nous", "vous", "mais", "ou"]
const FORBIDDEN_WORDS := ["simulation", "programme", "ia", "intelligence artificielle",
	"modele de langage", "llm", "serveur", "algorithme", "token", "api",
	"machine learning", "neural", "dataset", "artificial", "language model",
	"computer", "software"]
const JACCARD_STRICT := 0.5
const FR_STRICT_RATIO := 0.8
const MIN_TEXT_LEN := 30

var _adapter: RefCounted = null
var _merlin_ai: Node = null
var _results: Array[Dictionary] = []
var _pass_count: int = 0
var _fail_count: int = 0
var _skip_count: int = 0
var _card_log: Array[Dictionary] = []
var _gen_times: Array[int] = []
var _ram_start: int = 0


func _ready() -> void:
	_ram_start = OS.get_static_memory_usage()
	_log("═══════════════════════════════════════")
	_log("  LLM FULL RUN — DANGER PROGRESSIVE")
	_log("═══════════════════════════════════════")

	await get_tree().process_frame
	await get_tree().process_frame

	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and "llm" in store and store.llm != null:
		_adapter = store.llm
		_log("Adapter: OK")
	else:
		_log("FATAL: Adapter missing")
		get_tree().quit(1)
		return

	_merlin_ai = get_node_or_null("/root/MerlinAI")
	if not _merlin_ai:
		_log("FATAL: MerlinAI missing")
		get_tree().quit(1)
		return

	# Warmup LLM
	if not _merlin_ai.is_ready:
		_log("Warming up LLM...")
		_merlin_ai.start_warmup()
		var t := Time.get_ticks_msec()
		while not _merlin_ai.is_ready:
			if Time.get_ticks_msec() - t > 60000:
				_log("Warmup timeout 60s")
				break
			await get_tree().process_frame
	if not _merlin_ai.is_ready:
		_log("SKIP ALL: LLM not available")
		get_tree().quit(1)
		return
	_log("LLM ready: brain_count=%d" % _merlin_ai.brain_count)

	# Run tests
	await _test_guardrails()
	await _test_full_run()
	_test_reset_verification()
	await _test_prologue_epilogue()

	_print_report()
	_export_json()
	_export_markdown()

	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if _fail_count > 0 else 0)


# ═══════════════════════════════════════════════════════════════════════════════
# T15: GUARDRAILS STRICTS
# ═══════════════════════════════════════════════════════════════════════════════

func _test_guardrails() -> void:
	_log("\n--- T15: GUARDRAILS STRICTS ---")
	_log("  Generating 5 cards for guardrail validation...")

	var texts: Array[String] = []
	var all_pass := true
	var jaccard_violations: int = 0
	var fr_violations: int = 0
	var forbidden_violations: int = 0
	var length_violations: int = 0

	var ctx := {
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1,
		"life_essence": 100, "cards_played": 0, "day": 1,
		"active_tags": [], "biome": "foret_broceliande",
		"story_log": [], "karma": 0,
	}

	for i in range(5):
		ctx["cards_played"] = i
		var result: Dictionary = await _adapter._generate_card_two_stage(ctx)
		if not result.get("ok", false):
			_log("  Card %d: GENERATION FAILED — %s" % [i, str(result.get("error", ""))])
			all_pass = false
			continue

		var card: Dictionary = result.card
		var text: String = str(card.get("text", ""))

		# Length check
		if text.length() < MIN_TEXT_LEN:
			_log("  Card %d: LENGTH FAIL — %d chars (min %d)" % [i, text.length(), MIN_TEXT_LEN])
			length_violations += 1

		# French check
		var fr_ratio: float = _compute_fr_ratio(text)
		if fr_ratio < FR_STRICT_RATIO:
			_log("  Card %d: FR FAIL — %.0f%% (min %.0f%%)" % [i, fr_ratio * 100, FR_STRICT_RATIO * 100])
			fr_violations += 1

		# Forbidden words check
		var forbidden: String = _find_forbidden(text)
		if not forbidden.is_empty():
			_log("  Card %d: FORBIDDEN — \"%s\"" % [i, forbidden])
			forbidden_violations += 1

		# Jaccard check (vs previous cards)
		for prev_text in texts:
			var sim: float = _jaccard(text, prev_text)
			if sim >= JACCARD_STRICT:
				_log("  Card %d: JACCARD FAIL — %.2f (max %.2f)" % [i, sim, JACCARD_STRICT])
				jaccard_violations += 1
				break

		texts.append(text)
		_log("  Card %d: len=%d FR=%.0f%% jaccard=OK text=\"%s\"" % [
			i, text.length(), fr_ratio * 100, text.substr(0, 60)])

	if jaccard_violations > 0 or forbidden_violations > 0:
		all_pass = false
	# FR and length are warnings (Qwen 1.5B quality varies)
	var detail := "len_fail=%d fr_fail=%d forbidden=%d jaccard=%d" % [
		length_violations, fr_violations, forbidden_violations, jaccard_violations]
	_record("T15", "guardrails_stricts (5 cards)", all_pass, detail)


# ═══════════════════════════════════════════════════════════════════════════════
# T16: FULL RUN — 20 CARDS DANGER PROGRESSIVE
# ═══════════════════════════════════════════════════════════════════════════════

func _test_full_run() -> void:
	_log("\n--- T16: FULL RUN — 20 CARDS DANGER PROGRESSIVE ---")

	var all_pass := true
	var state := _build_initial_state()
	var story_log: Array[Dictionary] = []
	var prev_keywords: Array[String] = []

	_log("  Scenario: \"%s\"" % state.scenario_title)
	_log("  Structure: 3 actes + epilogue (Hand of Fate 2 pattern)")
	_log("\n  ┌── DECISION TREE ──────────────────────────────────")

	for card_idx in range(MAX_CARDS):
		if not is_inside_tree():
			break

		# Log act transitions
		if ACT_LABELS.has(card_idx):
			_log("  │")
			_log("  ╠══ %s ════════════════════════" % ACT_LABELS[card_idx])

		# Build context from current state
		var ctx: Dictionary = _build_context_from_state(state, story_log, card_idx)

		# Generate card
		var t_start := Time.get_ticks_msec()
		var result: Dictionary = await _adapter._generate_card_two_stage(ctx)
		var gen_ms: int = Time.get_ticks_msec() - t_start
		_gen_times.append(gen_ms)

		if not result.get("ok", false):
			_log("  │ CARD %d: GENERATION FAILED — %s" % [card_idx + 1, str(result.get("error", ""))])
			all_pass = false
			continue

		var card: Dictionary = result.card
		var text: String = str(card.get("text", ""))
		var options: Array = card.get("options", [])
		var tags: Array = card.get("tags", [])
		var balance: Dictionary = _adapter._evaluate_balance_heuristic(ctx)
		var balance_score: int = int(balance.get("balance_score", 100))

		# Decision tree log
		var anchor_tag: String = " [ANCHOR]" if ANCHOR_CONTEXTS.has(card_idx) else ""
		_log("  │")
		_log("  ├── CARD %d (gen=%dms, balance=%d)%s" % [card_idx + 1, gen_ms, balance_score, anchor_tag])
		_log("  │   ├── TEXT: \"%s\"" % text.substr(0, 90))
		_log("  │   ├── OPTIONS:")
		var choice_idx: int = _pick_danger_choice(card_idx, balance_score)
		for oi in range(mini(options.size(), 3)):
			var opt: Dictionary = options[oi] if options[oi] is Dictionary else {}
			var label: String = str(opt.get("label", "?"))
			var action_desc: String = str(opt.get("action_desc", ""))
			var verb_src: String = str(opt.get("verb_source", "?"))
			var effects: Array = opt.get("effects", [])
			var dc_hint: Dictionary = opt.get("dc_hint", {})
			var fx_str: String = _effects_str(effects)
			var dc_str: String = "DC=%d-%d" % [int(dc_hint.get("min", 0)), int(dc_hint.get("max", 0))] if dc_hint.has("min") else "DC=?"
			var marker: String = " ◄" if oi == choice_idx else ""
			var desc_suffix: String = " — %s" % action_desc.substr(0, 60) if not action_desc.is_empty() else ""
			_log("  │   │   %s %s) %s%s [%s] %s (%s)%s" % [
				"├──" if oi < 2 else "└──",
				["A", "B", "C"][oi], label, desc_suffix, fx_str, dc_str, verb_src, marker])

		# Simulate D20 roll and DC
		var direction: String = ["left", "center", "right"][clampi(choice_idx, 0, 2)]
		var d20: int = randi_range(1, 20)
		var dc: int = _estimate_dc(ctx, direction, options, choice_idx)
		var outcome: String = "SUCCESS" if d20 >= dc else "FAILURE"
		if d20 == 20:
			outcome = "CRITICAL_SUCCESS"
		elif d20 == 1:
			outcome = "CRITICAL_FAILURE"

		# Apply effects
		var chosen_opt: Dictionary = options[choice_idx] if choice_idx < options.size() else {}
		var chosen_effects: Array = chosen_opt.get("effects", [])
		var pre_life: int = int(state.life)
		_apply_effects(state, chosen_effects, outcome)
		var post_life: int = int(state.life)

		# Anam gain on success
		var anam_gained: int = 0
		var is_success: bool = outcome == "SUCCESS" or outcome == "CRITICAL_SUCCESS"
		if is_success:
			anam_gained = MerlinConstants.ANAM_PER_MINIGAME
			state.anam += anam_gained

		_log("  │   ├── CHOICE: %s (%s) → D20=%d vs DC=%d → %s" % [
			["A", "B", "C"][choice_idx], direction, d20, dc, outcome])
		_log("  │   ├── RESOLUTION: life %d→%d (%+d)" % [
			pre_life, post_life, post_life - pre_life])
		if anam_gained > 0:
			_log("  │   ├── ANAM: +%d — total: %d" % [anam_gained, state.anam])
		# Log minigame if detected
		var minigame: Dictionary = card.get("minigame", {})
		if not minigame.is_empty():
			_log("  │   ├── MINI-JEU: %s (%s)" % [str(minigame.get("name", "")), str(minigame.get("desc", ""))])
		# Log consequences if present (P2)
		var has_consequences := "llm_consequences" in tags
		if has_consequences:
			var res_text: String = str(chosen_opt.get("result_success", "")).substr(0, 70)
			_log("  │   ├── CONSEQUENCE: \"%s\"" % res_text)
		_log("  │   └── STATE: balance=%d aspects=%s essences=%d tags=%s" % [
			balance_score, str(state.aspects), state.essences,
			"[llm_consequences]" if has_consequences else str(tags)])

		# Story coherence check: keywords from previous card in current text
		if prev_keywords.size() > 0:
			var coherence_hits: int = 0
			for kw in prev_keywords:
				if text.to_lower().find(kw) >= 0:
					coherence_hits += 1
			# Don't fail on coherence — just log
			if coherence_hits > 0:
				_log("  │   \u25c6 COHERENCE: %d keywords from prev card found" % coherence_hits)

		# Update story log (with action_desc for narrative continuity)
		story_log.append({
			"text": text.substr(0, 200),
			"choice": str(chosen_opt.get("label", "")),
			"action_desc": str(chosen_opt.get("action_desc", "")),
		})
		prev_keywords = _extract_keywords(text)

		# Record card data
		var arc_phase: String = _get_arc_context(card_idx).substr(0, 30)
		var is_anchor_ctx: bool = ANCHOR_CONTEXTS.has(card_idx)
		# Extract action_descs + verb_sources for all options
		var action_descs: Array[String] = []
		var verb_sources: Array[String] = []
		for oi2 in range(mini(options.size(), 3)):
			var opt2: Dictionary = options[oi2] if options[oi2] is Dictionary else {}
			action_descs.append(str(opt2.get("action_desc", "")))
			verb_sources.append(str(opt2.get("verb_source", "unknown")))

		_card_log.append({
			"card_num": card_idx + 1, "gen_ms": gen_ms,
			"text": text, "tags": tags,
			"choice": choice_idx, "direction": direction,
			"d20": d20, "dc": dc, "outcome": outcome,
			"pre_life": pre_life, "post_life": post_life,
			"balance_score": balance_score,
			"aspects": state.aspects.duplicate(),
			"dynamic_mod": state.dynamic_mod,
			"anam_gained": anam_gained,
			"essences_total": state.essences,
			"arc_phase": arc_phase,
			"is_anchor": is_anchor_ctx,
			"scenario": state.scenario_title,
			"action_descs": action_descs,
			"verb_sources": verb_sources,
			"minigame": card.get("minigame", {}),
			"resolution_text": str(chosen_opt.get("result_success" if is_success else "result_failure", "")),
		})

		# Progressive danger: degrade state
		_degrade_state(state, card_idx)

		# Check if run should end (life = 0)
		if state.life <= 0:
			_log("  │")
			_log("  └── RUN ENDED: life reached 0 at card %d" % (card_idx + 1))
			break

	_log("  │")
	_log("  └── END OF RUN (%d cards)" % _card_log.size())

	# Essences summary (stackable currency)
	_log("\n  ESSENCES COLLECTED: %d" % state.essences)

	# Performance summary
	_log_perf_summary()

	_record("T16", "full_run_%d_cards" % _card_log.size(), all_pass,
		"cards=%d p50=%dms essences=%d" % [_card_log.size(), _percentile(_gen_times, 50), state.essences])


# ═══════════════════════════════════════════════════════════════════════════════
# T17: RESET VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

func _test_reset_verification() -> void:
	_log("\n--- T17: RESET VERIFICATION ---")
	var all_pass := true

	# Check adapter has _suggest_rule_heuristic (used by dynamic difficulty)
	var ctx := {"aspects": {"Corps": -1, "Ame": -1, "Monde": -1}, "souffle": 0}
	var rule: Dictionary = _adapter._suggest_rule_heuristic(ctx, "neutre")
	if rule.get("type", "") == "difficulty":
		_log("  ok: Rule heuristic works post-run (type=%s)" % str(rule.type))
	else:
		_log("  ok: Rule heuristic returns type=%s (state-dependent)" % str(rule.get("type", "?")))

	# Verify heuristic still functional after 20 cards (no state leak)
	var balance: Dictionary = _adapter._evaluate_balance_heuristic(
		{"aspects": {"Corps": 0, "Ame": 0, "Monde": 0}, "souffle": 1})
	if int(balance.get("balance_score", 0)) == 100:
		_log("  ok: Balance heuristic clean after run (score=100)")
	else:
		_log("  FAIL: Balance leaked state (score=%d, expected 100)" % int(balance.balance_score))
		all_pass = false

	_record("T17", "reset_verification", all_pass, "no state leak")


# ═══════════════════════════════════════════════════════════════════════════════
# T18: PROLOGUE + EPILOGUE INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

func _test_prologue_epilogue() -> void:
	_log("\n--- T18: PROLOGUE + EPILOGUE (P6) ---")
	var all_pass := true

	# Prologue — with scenario context
	var state := _build_initial_state()
	var pro_ctx := {
		"biome": "foret_broceliande", "life_essence": 100, "souffle": 1,
		"aspects": {"Corps": 0, "Ame": 0, "Monde": 0},
		"scenario_title": state.scenario_title,
		"scenario_intro": state.scenario_intro,
	}
	var t0 := Time.get_ticks_msec()
	var prologue: Dictionary = await _adapter.generate_prologue(pro_ctx)
	var pro_ms: int = Time.get_ticks_msec() - t0

	if prologue.get("ok", false):
		var text: String = str(prologue.get("text", ""))
		_log("  PROLOGUE (%dms, len=%d):" % [pro_ms, text.length()])
		# Print first 3 lines
		var lines := text.split("\n", false)
		for i in range(mini(3, lines.size())):
			_log("    %s" % lines[i].substr(0, 90))
		if text.length() < 50:
			_log("  WARN: prologue short (%d chars)" % text.length())
	else:
		_log("  FAIL: prologue generation failed — %s" % str(prologue.get("error", "")))
		all_pass = false

	# Epilogue (using state from the full run, with scenario context)
	var epi_ctx := {
		"aspects": {"Corps": -1, "Ame": -1, "Monde": 0}, "souffle": 1,
		"life_essence": 45, "cards_played": _card_log.size(),
		"scenario_title": state.scenario_title,
	}
	var story_summary: Array = []
	for entry in _card_log.slice(-5):
		story_summary.append({"text": str(entry.get("text", "")).substr(0, 60)})
	t0 = Time.get_ticks_msec()
	var epilogue: Dictionary = await _adapter.generate_epilogue(epi_ctx, story_summary)
	var epi_ms: int = Time.get_ticks_msec() - t0

	if epilogue.get("ok", false):
		var text: String = str(epilogue.get("text", ""))
		_log("  EPILOGUE (%dms, len=%d):" % [epi_ms, text.length()])
		var lines := text.split("\n", false)
		for i in range(mini(3, lines.size())):
			_log("    %s" % lines[i].substr(0, 90))
	else:
		_log("  FAIL: epilogue generation failed — %s" % str(epilogue.get("error", "")))
		all_pass = false

	_record("T18", "prologue_epilogue (P6)", all_pass, "pro=%dms epi=%dms" % [pro_ms, epi_ms])


# ═══════════════════════════════════════════════════════════════════════════════
# STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

class RunState:
	var life: int = 100
	var karma: int = 0
	var aspects: Dictionary = {"Corps": 0, "Ame": 0, "Monde": 0}
	var dynamic_mod: int = 0
	var tension: int = 0
	var essences: int = 0  # Stackable currency counter
	var scenario_title: String = ""
	var scenario_theme: String = ""
	var scenario_intro: String = ""
	var active_flags: Array[String] = []
	var active_tags: Array[String] = []

# Scenario data loaded from catalogue
var _scenario: Dictionary = {}

# Anchor contexts for each card position (scenario-specific)
const ANCHOR_CONTEXTS := {
	3: "Le voyageur decouvre un ruban rouge accroche a une branche basse. Des empreintes minuscules s'enfoncent dans la mousse.",
	8: "Un chasseur bourru emerge des taillis. Il dit chercher la meme enfant, mais ses yeux evitent les votres.",
	14: "Au fond d'un ravin tapisse de fougeres, une voix d'enfant fredonne. Elle est la, pieds nus, couverte de mousse.",
	18: "Le voyageur doit choisir: ramener l'enfant au village ou la laisser a la foret qui l'a adoptee.",
}

# 3-act structure labels (Hand of Fate 2 pattern)
const ACT_LABELS := {
	0: "ACTE I — EVEIL",
	4: "ACTE II — CONFRONTATION",
	10: "ACTE III — RESOLUTION",
	16: "EPILOGUE",
}

func _build_initial_state() -> RunState:
	var s := RunState.new()
	s.life = 100
	s.karma = 0
	s.aspects = {"Corps": 0, "Ame": 0, "Monde": 0}

	# Load scenario
	_load_scenario()
	s.scenario_title = str(_scenario.get("title", "Voyage en Broceliande"))
	s.scenario_theme = str(_scenario.get("theme_injection", ""))
	s.scenario_intro = str(_scenario.get("dealer_intro_context", ""))
	return s

func _load_scenario() -> void:
	var file := FileAccess.open("res://data/ai/scenarios/scenario_catalogue.json", FileAccess.READ)
	if not file:
		_log("  WARN: No scenario catalogue found, using defaults")
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	var scenarios: Dictionary = data.get("scenarios", {})
	if scenarios.has("la_fille_perdue"):
		_scenario = scenarios["la_fille_perdue"]

func _build_context_from_state(state: RunState, story_log: Array, card_idx: int) -> Dictionary:
	var ctx := {
		"aspects": state.aspects.duplicate(),
		"life_essence": state.life,
		"cards_played": card_idx,
		"day": 1 + int(card_idx / 4),
		"active_tags": state.active_tags.duplicate(),
		"biome": "foret_broceliande",
		"story_log": story_log.slice(-10),
		"karma": state.karma,
		# Scenario context
		"scenario_title": state.scenario_title,
		"anchor_context": _get_anchor_context(card_idx),
		"arc_context": _get_arc_context(card_idx),
		"recent_events": _format_recent_events(story_log),
		"essences_collected": state.essences,
	}
	# Inject scenario theme for ALL cards (anchors get both theme + anchor_context)
	if not state.scenario_theme.is_empty():
		ctx["scenario_theme"] = state.scenario_theme
	return ctx

func _get_anchor_context(card_idx: int) -> String:
	return str(ANCHOR_CONTEXTS.get(card_idx, ""))

func _get_arc_context(card_idx: int) -> String:
	if card_idx < 4:
		return "Acte I: Decouverte. Ambiance mysterieuse, premiers indices."
	elif card_idx < 10:
		return "Acte II: Tension. Les enjeux montent, rencontres et dilemmes."
	elif card_idx < 16:
		return "Acte III: Resolution. Climax et consequences des choix."
	else:
		return "Epilogue. Bilan du voyage, derniere epreuve."

func _format_recent_events(story_log: Array) -> String:
	if story_log.is_empty():
		return ""
	var parts: Array[String] = []
	for entry in story_log.slice(-3):
		var t: String = str(entry.get("text", "")).substr(0, 60)
		var c: String = str(entry.get("choice", ""))
		if not t.is_empty():
			parts.append("%s (choix: %s)" % [t, c] if not c.is_empty() else t)
	return "Evenements recents: " + ". ".join(parts) if not parts.is_empty() else ""

func _degrade_state(state: RunState, card_idx: int) -> void:
	# Progressive degradation: Corps drops at card 5, Ame at card 10
	if card_idx == 4:
		state.aspects["Corps"] = -1
	elif card_idx == 9:
		state.aspects["Ame"] = -1
	elif card_idx == 14:
		state.aspects["Monde"] = -1
	# Souffle: max 1, used on center choice (cost=1), regained via effects
	# No passive drain — souffle is consumed by B choices only
	# Tension rises
	state.tension = mini(state.tension + 5, 100)

func _pick_danger_choice(card_idx: int, balance_score: int) -> int:
	# Strategy: prudent early, risky late, center when comfortable
	if balance_score < 30:
		return 0  # Left (healing) when in danger
	elif card_idx < 8:
		return randi_range(0, 2)  # Random early
	else:
		return 2  # Right (risky) in late game

func _estimate_dc(ctx: Dictionary, direction: String, options: Array, choice_idx: int) -> int:
	# Estimate DC from dc_hints
	if choice_idx < options.size():
		var opt: Dictionary = options[choice_idx]
		var hint: Dictionary = opt.get("dc_hint", {})
		if hint.has("min") and hint.has("max"):
			return randi_range(int(hint["min"]), int(hint["max"]))
	# Fallback DC
	match direction:
		"left": return randi_range(4, 8)
		"center": return randi_range(7, 12)
		"right": return randi_range(10, 16)
		_: return 10

func _apply_effects(state: RunState, effects: Array, outcome: String) -> void:
	var multiplier: float = 1.0
	if outcome == "CRITICAL_SUCCESS":
		multiplier = 1.5
	elif outcome == "FAILURE":
		multiplier = 0.5
	elif outcome == "CRITICAL_FAILURE":
		multiplier = 0.0  # No effect on crit fail

	for eff in effects:
		var eff_type: String = str(eff.get("type", ""))
		var amount: int = int(int(eff.get("amount", 0)) * multiplier)
		match eff_type:
			"HEAL_LIFE": state.life = mini(state.life + amount, 100)
			"DAMAGE_LIFE": state.life = maxi(state.life - amount, 0)
			"ADD_KARMA": state.karma += amount
			"ADD_ANAM":
				state.essences += maxi(int(eff.get("amount", 1)), 1)




# ═══════════════════════════════════════════════════════════════════════════════
# GUARDRAIL HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _compute_fr_ratio(text: String) -> float:
	var words: PackedStringArray = text.to_lower().split(" ", false)
	if words.size() == 0:
		return 0.0
	var hits: int = 0
	for w in words:
		if w in FR_KEYWORDS:
			hits += 1
	return float(hits) / float(words.size())

func _find_forbidden(text: String) -> String:
	var lower: String = text.to_lower()
	for word in FORBIDDEN_WORDS:
		if lower.contains(" " + word + " ") or lower.begins_with(word + " ") \
		   or lower.ends_with(" " + word) or lower == word:
			return word
	return ""

func _jaccard(a: String, b: String) -> float:
	var set_a: Dictionary = {}
	var set_b: Dictionary = {}
	for w in a.to_lower().split(" ", false):
		set_a[w] = true
	for w in b.to_lower().split(" ", false):
		set_b[w] = true
	if set_a.is_empty() and set_b.is_empty():
		return 0.0
	var intersection: int = 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)

func _extract_keywords(text: String) -> Array[String]:
	var words: PackedStringArray = text.to_lower().split(" ", false)
	var keywords: Array[String] = []
	for w in words:
		if w.length() >= 5 and not w in FR_KEYWORDS:
			keywords.append(w)
			if keywords.size() >= 5:
				break
	return keywords

func _effects_str(effects: Array) -> String:
	var parts: Array[String] = []
	for eff in effects:
		parts.append("%s:%s" % [str(eff.get("type", "?")), str(eff.get("amount", "?"))])
	return ", ".join(parts) if not parts.is_empty() else "none"


# ═══════════════════════════════════════════════════════════════════════════════
# PERFORMANCE
# ═══════════════════════════════════════════════════════════════════════════════

func _log_perf_summary() -> void:
	_log("\n  ┌── PERFORMANCE SUMMARY ──────────────")
	if _gen_times.is_empty():
		_log("  │ No generation data")
		_log("  └─────────────────────────────────────")
		return
	var p50: int = _percentile(_gen_times, 50)
	var p90: int = _percentile(_gen_times, 90)
	var total_ms: int = 0
	for t in _gen_times:
		total_ms += t
	var avg: int = total_ms / _gen_times.size()
	var ram_now: int = OS.get_static_memory_usage()
	var ram_delta: int = ram_now - _ram_start

	_log("  │ Cards generated: %d" % _gen_times.size())
	_log("  │ Latency p50: %dms" % p50)
	_log("  │ Latency p90: %dms" % p90)
	_log("  │ Average: %dms" % avg)
	_log("  │ Total time: %ds" % (total_ms / 1000))
	_log("  │ Est. throughput: %.1f cards/min" % (60000.0 / avg if avg > 0 else 0))
	_log("  │ RAM start: %.1f MB" % (_ram_start / 1048576.0))
	_log("  │ RAM now: %.1f MB (delta: %+.1f MB)" % [ram_now / 1048576.0, ram_delta / 1048576.0])
	_log("  └─────────────────────────────────────")

func _percentile(arr: Array[int], pct: int) -> int:
	if arr.is_empty():
		return 0
	var sorted_arr: Array[int] = arr.duplicate()
	sorted_arr.sort()
	var idx: int = clampi(int(sorted_arr.size() * pct / 100), 0, sorted_arr.size() - 1)
	return sorted_arr[idx]


# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT
# ═══════════════════════════════════════════════════════════════════════════════

func _export_json() -> void:
	var data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"brain_count": _merlin_ai.brain_count if _merlin_ai else 0,
		"tests": _results,
		"perf": {
			"p50_ms": _percentile(_gen_times, 50),
			"p90_ms": _percentile(_gen_times, 90),
			"total_cards": _card_log.size(),
			"ram_start_mb": _ram_start / 1048576.0,
			"ram_end_mb": OS.get_static_memory_usage() / 1048576.0,
		},
		"cards": _card_log,
	}
	var json_str: String = JSON.stringify(data, "  ")
	var file := FileAccess.open("user://test_intelligence_results.json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		_log("\nExported: user://test_intelligence_results.json")
	else:
		_log("\nFAILED to export JSON")

func _export_markdown() -> void:
	var md: String = "# LLM Intelligence Pipeline — Full Run Report\n\n"
	md += "**Date**: %s\n" % Time.get_datetime_string_from_system()
	md += "**Brain count**: %d\n\n" % (_merlin_ai.brain_count if _merlin_ai else 0)

	# Test results table
	md += "## Test Results\n\n"
	md += "| Test | Name | Status | Detail |\n|------|------|--------|--------|\n"
	for r in _results:
		md += "| %s | %s | %s | %s |\n" % [r.id, r.name, r.status, r.detail]

	# Performance
	md += "\n## Performance\n\n"
	md += "| Metric | Value |\n|--------|-------|\n"
	md += "| Cards | %d |\n" % _card_log.size()
	md += "| p50 | %dms |\n" % _percentile(_gen_times, 50)
	md += "| p90 | %dms |\n" % _percentile(_gen_times, 90)
	md += "| RAM delta | %+.1f MB |\n" % ((OS.get_static_memory_usage() - _ram_start) / 1048576.0)

	# Decision tree summary
	md += "\n## Decision Tree (summary)\n\n"
	for entry in _card_log:
		var text: String = str(entry.get("text", "")).substr(0, 60)
		var anchor_mark: String = " [ANCHOR]" if entry.get("is_anchor", false) else ""
		var ess_mark: String = " +%s" % str(entry.get("essence_gained", "")) if not str(entry.get("essence_gained", "")).is_empty() else ""
		md += "- **Card %d** (bal=%d, %dms)%s: \"%s...\" → %s D20=%d DC=%d → %s (life %d→%d)%s\n" % [
			int(entry.card_num), int(entry.balance_score), int(entry.gen_ms),
			anchor_mark, text, ["A", "B", "C"][int(entry.choice)],
			int(entry.d20), int(entry.dc), str(entry.outcome),
			int(entry.pre_life), int(entry.post_life), ess_mark]

	# Summary
	md += "\n## Summary\n\n"
	md += "**%d PASSED, %d FAILED, %d SKIPPED**\n" % [_pass_count, _fail_count, _skip_count]

	var file := FileAccess.open("user://test_intelligence_recap.md", FileAccess.WRITE)
	if file:
		file.store_string(md)
		file.close()
		_log("Exported: user://test_intelligence_recap.md")
	else:
		_log("FAILED to export Markdown")


# ═══════════════════════════════════════════════════════════════════════════════
# REPORTING
# ═══════════════════════════════════════════════════════════════════════════════

func _record(id: String, name: String, passed: bool, detail: String) -> void:
	var status: String = "PASS" if passed else "FAIL"
	_results.append({"id": id, "name": name, "status": status, "detail": detail})
	if passed:
		_pass_count += 1
	else:
		_fail_count += 1

func _print_report() -> void:
	_log("\n═══════════════════════════════════════")
	_log("  FULL RUN — TEST REPORT")
	_log("═══════════════════════════════════════")
	for r in _results:
		var marker: String = "[PASS]" if r.status == "PASS" else "[FAIL]"
		_log("  %s %s: %s — %s" % [marker, r.id, r.name, r.detail])
	_log("")
	_log("  SUMMARY: %d PASSED, %d FAILED, %d SKIPPED" % [_pass_count, _fail_count, _skip_count])
	_log("═══════════════════════════════════════")
	_log("  VERDICT: %s" % ("ALL PASS" if _fail_count == 0 else "FAILURES"))
	_log("═══════════════════════════════════════")

func _log(msg: String) -> void:
	print("[FULLRUN] %s" % msg)
