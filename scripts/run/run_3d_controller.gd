## ═══════════════════════════════════════════════════════════════════════════════
## Run 3D Controller — On-rails movement, card/minigame pauses, convergence
## ═══════════════════════════════════════════════════════════════════════════════
## Phase 6 (DEV_PLAN_V2.5). Wraps the 3D world scene and manages the run loop:
## walk → pause → card → minigame → resume → walk → ...
## Standalone (no MOS dependency). MOS hooks via signals.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name Run3DController

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS — Phase 6 → Phase 7 contract
# ═══════════════════════════════════════════════════════════════════════════════

signal life_changed(current: int, maximum: int)
signal currency_changed(amount: int)
signal ogham_updated(ogham_id: String, cooldown: int)
signal promises_updated(promises: Array)
signal period_changed(period: String)
signal card_started(card: Dictionary)
signal card_ended()
signal run_ended(reason: String, data: Dictionary)
signal convergence_zone_entered(card_index: int)

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

var _store: MerlinStore
var _card_system: MerlinCardSystem
var _effects: MerlinEffectEngine
var _transition: TransitionManager
var _spawner: CollectibleSpawner
var _minigame_system: MerlinMiniGameSystem
var _headless: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# RUN STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _run_state: Dictionary = {}
var _is_running: bool = false
var _is_paused: bool = false
var _walk_timer: float = 0.0
var _card_interval: float = 0.0
var _current_card: Dictionary = {}

# Ogham state — per-card tracking (bible pipeline step 3)
var _active_ogham_this_card: String = ""
var _ogham_activation_result: Dictionary = {}
var _ogham_cooldowns: Dictionary = {}
var _unlocked_oghams: Array = []

const WALK_SPEED: float = 3.0
const CARD_INTERVAL_MIN: float = 8.0
const CARD_INTERVAL_MAX: float = 14.0
const DRAIN_PER_CARD: int = MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(store: MerlinStore, card_system: MerlinCardSystem,
		effects: MerlinEffectEngine, transition: TransitionManager,
		spawner: CollectibleSpawner,
		minigame_system: MerlinMiniGameSystem = null,
		headless: bool = false) -> void:
	_store = store
	_card_system = card_system
	_effects = effects
	_transition = transition
	_spawner = spawner
	_minigame_system = minigame_system
	_headless = headless


# ═══════════════════════════════════════════════════════════════════════════════
# RUN LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(biome: String, ogham: String) -> void:
	_run_state = _card_system.init_run(biome, ogham)
	_run_state["life_essence"] = MerlinConstants.LIFE_ESSENCE_START
	_run_state["life_max"] = MerlinConstants.LIFE_ESSENCE_MAX
	_run_state["biome_currency"] = 0
	_run_state["period"] = "aube"

	_is_running = true
	_is_paused = false
	_walk_timer = 0.0
	_card_interval = _next_card_interval()

	# Initialize ogham state — 3 starters are always available
	_ogham_cooldowns = {}
	_unlocked_oghams = MerlinConstants.OGHAM_STARTER_SKILLS.duplicate()
	_active_ogham_this_card = ""
	_ogham_activation_result = {}

	# Emit initial state
	life_changed.emit(_run_state["life_essence"], _run_state["life_max"])
	currency_changed.emit(0)
	period_changed.emit("aube")
	ogham_updated.emit(ogham, 0)
	promises_updated.emit([])

	# Start collectible spawning
	if _spawner:
		_spawner.start_spawning(_run_state)


func stop_run(reason: String) -> void:
	_is_running = false
	_is_paused = false
	if _spawner:
		_spawner.stop_spawning()

	var data: Dictionary = {
		"card_index": int(_run_state.get("card_index", 0)),
		"life_essence": int(_run_state.get("life_essence", 0)),
		"biome": str(_run_state.get("biome", "")),
		"biome_currency": int(_run_state.get("biome_currency", 0)),
		"promises": _run_state.get("active_promises", []),
	}
	run_ended.emit(reason, data)


# ═══════════════════════════════════════════════════════════════════════════════
# GAME LOOP — called from _process()
# ═══════════════════════════════════════════════════════════════════════════════

func process_tick(delta: float) -> void:
	if not _is_running or _is_paused:
		return

	_walk_timer += delta

	# Update period
	var card_index: int = int(_run_state.get("card_index", 0))
	var new_period: String = MerlinStore.get_period(card_index)
	if new_period != str(_run_state.get("period", "")):
		_run_state["period"] = new_period
		period_changed.emit(new_period)

	# Time for a card?
	if _walk_timer >= _card_interval:
		_walk_timer = 0.0
		_card_interval = _next_card_interval()
		_trigger_card()


func _trigger_card() -> void:
	_is_paused = true

	# Reset per-card ogham state (step 3 is optional, player may not activate)
	_active_ogham_this_card = ""
	_ogham_activation_result = {}

	# Life drain
	var life: int = int(_run_state.get("life_essence", 0))
	life = maxi(life - DRAIN_PER_CARD, 0)
	_run_state["life_essence"] = life
	life_changed.emit(life, int(_run_state.get("life_max", 100)))

	# Check run end before card
	var end_check: Dictionary = _card_system.check_run_end(_run_state)
	if end_check.get("ended", false):
		stop_run(str(end_check.get("reason", "death")))
		return

	# Convergence zone signal
	if end_check.get("convergence_zone", false):
		convergence_zone_entered.emit(int(_run_state.get("card_index", 0)))

	# Check expired promises
	var promise_results: Array = _card_system.check_promises(_run_state)
	for result in promise_results:
		if result is Dictionary:
			_apply_trust_delta(int(result.get("trust_delta", 0)))
	if not promise_results.is_empty():
		promises_updated.emit(_run_state.get("active_promises", []))

	# Generate card
	if _transition:
		await _transition.fade_to_card(1.0)

	_current_card = await _card_system.generate_card(_run_state)
	card_started.emit(_current_card)


func on_card_choice(option_index: int) -> void:
	var card_type: String = str(_current_card.get("type", "narrative"))
	var options: Array = _current_card.get("options", [])

	# ─── Step 5-6: Minigame → Score ───────────────────────────────────
	var score: int = 75  # headless default (reussite_partielle per multiplier table)

	if card_type == "merlin_direct":
		# Merlin Direct: skip minigame, neutral score → multiplier 1.0
		score = 50
	else:
		# Detect lexical field from the chosen option
		var option_label: String = ""
		if option_index >= 0 and option_index < options.size():
			var option: Dictionary = options[option_index]
			option_label = str(option.get("label", ""))
		var lexical_field: String = _card_system.detect_lexical_field(option_label)
		var minigame_type: String = _card_system.select_minigame(lexical_field)

		if _headless:
			# Headless mode: fixed score 75 (reussite_partielle)
			score = 75
		elif _minigame_system != null:
			# Live mode: transition to minigame overlay, run, get score
			if _transition:
				await _transition.fade_to_minigame(0.5)

			var difficulty: int = _get_minigame_difficulty()
			var minigame_result: Dictionary = _minigame_system.run(
				minigame_type, difficulty
			)
			score = int(minigame_result.get("score", 75))
		else:
			# No minigame system available: fallback to fixed score
			push_warning("[Run3D] No MerlinMiniGameSystem — using default score 75")
			score = 75

	# ─── Step 7: Resolve card with score ──────────────────────────────
	var result: Dictionary = _card_system.resolve_card(
		_run_state, _current_card, option_index, score
	)
	if not result.get("ok", false):
		push_warning("[Run3D] Card resolution failed: %s" % str(result.get("error", "")))
		resume_after_card()
		return

	# Apply effects to run state
	var effects: Array = result.get("effects", [])

	# ─── Step 8: Ogham protection (luis/gort/eadhadh filter negatives) ──
	if not _active_ogham_this_card.is_empty():
		effects = MerlinEffectEngine.apply_ogham_protection(effects, _active_ogham_this_card)

	_apply_effects(effects)

	# Update promise tracking
	for eff in effects:
		if eff is Dictionary:
			var etype: String = str(eff.get("type", ""))
			match etype:
				"ADD_REPUTATION":
					_card_system.update_promise_tracking(_run_state, "faction_gain", eff)
				"HEAL_LIFE":
					_card_system.update_promise_tracking(_run_state, "healing", eff)
				"DAMAGE_LIFE":
					_card_system.update_promise_tracking(_run_state, "damage", eff)

	# Track minigame result
	if score >= 60 and card_type != "merlin_direct":
		_card_system.update_promise_tracking(_run_state, "minigame_win", {})

	# ─── Step 11: Cooldown -1 on all oghams ──────────────────────────
	_tick_ogham_cooldowns()

	card_ended.emit()
	resume_after_card()


func pause_for_card() -> void:
	_is_paused = true
	if _transition:
		_transition.disable_inputs()


func resume_after_card() -> void:
	if _transition:
		await _transition.fade_to_3d(1.0)
		_transition.enable_inputs()
	_is_paused = false
	_current_card = {}


func check_convergence(card_index: int, _tension: float) -> bool:
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var target_max: int = int(mos.get("target_cards_max", 25))
	return card_index >= target_max


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT APPLICATION
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_effects(effects: Array) -> void:
	for effect in effects:
		if not (effect is Dictionary):
			continue
		var etype: String = str(effect.get("type", ""))
		var amount: int = int(effect.get("amount", 0))

		match etype:
			"HEAL_LIFE":
				var life: int = int(_run_state.get("life_essence", 0))
				var life_max: int = int(_run_state.get("life_max", 100))
				life = mini(life + amount, life_max)
				_run_state["life_essence"] = life
				life_changed.emit(life, life_max)
			"DAMAGE_LIFE":
				var life: int = int(_run_state.get("life_essence", 0))
				life = maxi(life - amount, 0)
				_run_state["life_essence"] = life
				life_changed.emit(life, int(_run_state.get("life_max", 100)))
				if life <= 0:
					stop_run("death")
			"ADD_REPUTATION":
				var faction: String = str(effect.get("faction", ""))
				var rep_delta: Dictionary = _run_state.get("faction_rep_delta", {})
				rep_delta[faction] = float(rep_delta.get(faction, 0.0)) + float(amount)
				_run_state["faction_rep_delta"] = rep_delta
			"ADD_BIOME_CURRENCY":
				var currency: int = int(_run_state.get("biome_currency", 0)) + amount
				_run_state["biome_currency"] = currency
				currency_changed.emit(currency)


func _apply_trust_delta(delta: int) -> void:
	var trust: int = int(_run_state.get("trust_delta", 0)) + delta
	_run_state["trust_delta"] = trust


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM ACTIVATION — Pipeline step 3 (before choice)
# ═══════════════════════════════════════════════════════════════════════════════

## Called when HudController.ogham_activated is emitted.
## Validates the ogham can be used, deducts cost, applies step-3 effects,
## stores the activation result for step 8 (protection) and step 11 (cooldown).
## Bible v2.4: 1 ogham per card max, must be unlocked, not on cooldown.
func on_ogham_activated(ogham_id: String) -> void:
	# ── Guard: 1 ogham per card max ──
	if not _active_ogham_this_card.is_empty():
		push_warning("[Run3D] Ogham already activated this card: %s" % _active_ogham_this_card)
		return

	# ── Guard: must be available (unlocked + not on cooldown) ──
	if not _is_ogham_available(ogham_id):
		push_warning("[Run3D] Ogham not available: %s" % ogham_id)
		return

	# ── Guard: must have a card displayed ──
	if _current_card.is_empty():
		push_warning("[Run3D] No card displayed — cannot activate ogham")
		return

	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	if spec.is_empty():
		push_warning("[Run3D] Unknown ogham: %s" % ogham_id)
		return

	# ── Deduct anam cost (if any) ──
	var cost_anam: int = int(spec.get("cost_anam", 0))
	if cost_anam > 0:
		var current_anam: int = int(_run_state.get("anam_found", 0))
		if current_anam < cost_anam:
			push_warning("[Run3D] Not enough anam for %s (need %d, have %d)" % [ogham_id, cost_anam, current_anam])
			return
		_run_state["anam_found"] = current_anam - cost_anam

	# ── Activate: delegate to MerlinEffectEngine for step-3 effects ──
	_active_ogham_this_card = ogham_id
	_ogham_activation_result = _effects.activate_ogham(ogham_id, _run_state, _current_card)

	# ── Set cooldown immediately ──
	var cooldown_turns: int = int(spec.get("cooldown", 3))
	_ogham_cooldowns[ogham_id] = cooldown_turns

	# ── Sync run_state life/currency if effect engine modified them ──
	_sync_life_from_run_state()

	# ── Emit signal so HUD updates ──
	ogham_updated.emit(ogham_id, cooldown_turns)


## Returns list of ogham IDs the player can activate right now.
## Filters: must be unlocked (or starter), cooldown == 0.
func get_available_oghams() -> Array:
	var available: Array = []
	for ogham_id in MerlinConstants.OGHAM_FULL_SPECS:
		if _is_ogham_available(ogham_id):
			available.append(ogham_id)
	return available


## Returns the ogham activation result for this card (empty if none activated).
func get_ogham_activation_result() -> Dictionary:
	return _ogham_activation_result


## Check if a specific ogham can be activated.
func _is_ogham_available(ogham_id: String) -> bool:
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	if spec.is_empty():
		return false
	# Must be unlocked or a starter
	var is_starter: bool = bool(spec.get("starter", false))
	if not is_starter and not _unlocked_oghams.has(ogham_id):
		return false
	# Must not be on cooldown
	if int(_ogham_cooldowns.get(ogham_id, 0)) > 0:
		return false
	return true


## Returns current cooldown for an ogham (0 = ready).
func get_ogham_cooldown(ogham_id: String) -> int:
	return int(_ogham_cooldowns.get(ogham_id, 0))


## Step 11: Decrement all ogham cooldowns by 1 after each card resolution.
## Removes entries that reach 0. Emits ogham_updated for each changed ogham.
func _tick_ogham_cooldowns() -> void:
	var to_remove: Array = []
	for ogham_id in _ogham_cooldowns:
		var remaining: int = maxi(int(_ogham_cooldowns[ogham_id]) - 1, 0)
		_ogham_cooldowns[ogham_id] = remaining
		if remaining <= 0:
			to_remove.append(ogham_id)
		ogham_updated.emit(ogham_id, remaining)
	for ogham_id in to_remove:
		_ogham_cooldowns.erase(ogham_id)


## Unlock an ogham for this run (e.g. via UNLOCK_OGHAM effect).
func unlock_ogham(ogham_id: String) -> void:
	if not MerlinConstants.OGHAM_FULL_SPECS.has(ogham_id):
		push_warning("[Run3D] Cannot unlock unknown ogham: %s" % ogham_id)
		return
	if not _unlocked_oghams.has(ogham_id):
		_unlocked_oghams.append(ogham_id)


## Sync life/currency from _run_state after effect engine modifies state dict.
## The effect engine's activate_ogham writes to state["run"]["life_essence"] etc.
## We need to reflect those changes in our flat _run_state and emit signals.
func _sync_life_from_run_state() -> void:
	var life: int = int(_run_state.get("life_essence", 0))
	var life_max: int = int(_run_state.get("life_max", 100))
	life_changed.emit(life, life_max)
	var currency: int = int(_run_state.get("biome_currency", 0))
	currency_changed.emit(currency)


# ═══════════════════════════════════════════════════════════════════════════════
# COLLECTIBLE PICKUP (called by spawner)
# ═══════════════════════════════════════════════════════════════════════════════

func on_collectible_picked(type: String, amount: int) -> void:
	match type:
		"currency":
			var currency: int = int(_run_state.get("biome_currency", 0)) + amount
			_run_state["biome_currency"] = currency
			currency_changed.emit(currency)
		"anam_rare":
			# Rare anam pickup — stored separately
			_run_state["anam_found"] = int(_run_state.get("anam_found", 0)) + amount
		"heal":
			var life: int = int(_run_state.get("life_essence", 0))
			var life_max: int = int(_run_state.get("life_max", 100))
			life = mini(life + amount, life_max)
			_run_state["life_essence"] = life
			life_changed.emit(life, life_max)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_minigame_difficulty() -> int:
	# Difficulty scales with card_index: 1 early, up to 7 late-run
	var card_index: int = int(_run_state.get("card_index", 0))
	return clampi(1 + int(card_index / 5), 1, 7)


func _next_card_interval() -> float:
	return randf_range(CARD_INTERVAL_MIN, CARD_INTERVAL_MAX)


func get_run_state() -> Dictionary:
	return _run_state


func is_running() -> bool:
	return _is_running
