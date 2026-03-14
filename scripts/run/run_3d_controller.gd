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

# ═══════════════════════════════════════════════════════════════════════════════
# RUN STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _run_state: Dictionary = {}
var _is_running: bool = false
var _is_paused: bool = false
var _walk_timer: float = 0.0
var _card_interval: float = 0.0
var _current_card: Dictionary = {}

const WALK_SPEED: float = 3.0
const CARD_INTERVAL_MIN: float = 8.0
const CARD_INTERVAL_MAX: float = 14.0
const DRAIN_PER_CARD: int = MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(store: MerlinStore, card_system: MerlinCardSystem,
		effects: MerlinEffectEngine, transition: TransitionManager,
		spawner: CollectibleSpawner) -> void:
	_store = store
	_card_system = card_system
	_effects = effects
	_transition = transition
	_spawner = spawner


# ═══════════════════════════════════════════════════════════════════════════════
# RUN LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func start_run(biome: String, ogham: String) -> void:
	_run_state = _card_system.init_run(biome, ogham)
	_run_state["life"] = MerlinConstants.LIFE_ESSENCE_START
	_run_state["life_max"] = MerlinConstants.LIFE_ESSENCE_MAX
	_run_state["biome_currency"] = 0
	_run_state["period"] = "aube"

	_is_running = true
	_is_paused = false
	_walk_timer = 0.0
	_card_interval = _next_card_interval()

	# Emit initial state
	life_changed.emit(_run_state["life"], _run_state["life_max"])
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
		"life": int(_run_state.get("life", 0)),
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

	# Life drain
	var life: int = int(_run_state.get("life", 0))
	life = maxi(life - DRAIN_PER_CARD, 0)
	_run_state["life"] = life
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


func on_card_choice(option_index: int, score: int) -> void:
	var card_type: String = str(_current_card.get("type", "narrative"))

	# Merlin Direct: skip minigame, effects ×1.0
	if card_type == "merlin_direct":
		score = 50  # neutral score, multiplier 1.0

	var result: Dictionary = _card_system.resolve_card(_run_state, _current_card, option_index, score)
	if not result.get("ok", false):
		push_warning("[Run3D] Card resolution failed: %s" % str(result.get("error", "")))
		resume_after_card()
		return

	# Apply effects to run state
	var effects: Array = result.get("effects", [])
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
				var life: int = int(_run_state.get("life", 0))
				var life_max: int = int(_run_state.get("life_max", 100))
				life = mini(life + amount, life_max)
				_run_state["life"] = life
				life_changed.emit(life, life_max)
			"DAMAGE_LIFE":
				var life: int = int(_run_state.get("life", 0))
				life = maxi(life - amount, 0)
				_run_state["life"] = life
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
			var life: int = int(_run_state.get("life", 0))
			var life_max: int = int(_run_state.get("life_max", 100))
			life = mini(life + amount, life_max)
			_run_state["life"] = life
			life_changed.emit(life, life_max)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _next_card_interval() -> float:
	return randf_range(CARD_INTERVAL_MIN, CARD_INTERVAL_MAX)


func get_run_state() -> Dictionary:
	return _run_state


func is_running() -> bool:
	return _is_running
