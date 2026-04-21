## ═══════════════════════════════════════════════════════════════════════════════
## WalkEventController — LLM event bridge for 3D forest walk
## ═══════════════════════════════════════════════════════════════════════════════
## Triggers LLM-generated events during the walk based on timer/zone/POI.
## Wires MerlinStore + MerlinLlmAdapter → WalkEventOverlay → MerlinEffectEngine.
## Manages a prefetch buffer of pre-generated events for smooth gameplay.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const EVENT_INTERVAL_MIN: float = 45.0
const EVENT_INTERVAL_MAX: float = 90.0
const COOLDOWN_MIN: float = 20.0
const PREFETCH_BUFFER_SIZE: int = 2
const ZONE_TRIGGER_COOLDOWN: float = 10.0

# Fallback event when LLM is unavailable
const FALLBACK_EVENTS: Array[Dictionary] = [
	{
		"text": "Le brouillard se leve soudain entre les arbres millennaires.\nUne silhouette se dessine au loin.",
		"labels": ["Observer", "Approcher", "Fuir"],
		"effects": [
			["ADD_REPUTATION:druides:5", "ADD_TENSION:1"],
			["ADD_REPUTATION:niamh:5", "DAMAGE_LIFE:3"],
			["HEAL_LIFE:5"],
		],
	},
	{
		"text": "Une pierre gravee de runes pulse d'une lueur bleutee.\nLe sol tremble legerement sous tes pieds.",
		"labels": ["Toucher", "Dechiffrer", "Contourner"],
		"effects": [
			["ADD_REPUTATION:anciens:5", "HEAL_LIFE:5"],
			["ADD_REPUTATION:druides:5", "DAMAGE_LIFE:5"],
			["ADD_ANAM:3"],
		],
	},
	{
		"text": "Un korrigan surgit d'entre les racines, riant aux eclats.\nIl brandit un champignon luisant et te fixe du regard.",
		"labels": ["Negocier", "Attraper", "Ignorer"],
		"effects": [
			["ADD_REPUTATION:korrigans:5", "ADD_ANAM:2"],
			["DAMAGE_LIFE:5", "ADD_REPUTATION:korrigans:-5"],
			["ADD_TENSION:2"],
		],
	},
	{
		"text": "Un cerf blanc traverse le sentier, s'arretant pour te regarder.\nSes bois brillent comme de l'argent sous la lune.",
		"labels": ["Suivre", "Saluer", "Rester"],
		"effects": [
			["ADD_REPUTATION:niamh:5", "ADD_TENSION:1"],
			["ADD_REPUTATION:druides:3", "ADD_ANAM:2"],
			["HEAL_LIFE:5", "ADD_REPUTATION:anciens:3"],
		],
	},
	{
		"text": "La fontaine de Barenton bouillonne sans chaleur.\nDes visions du passe et de l'avenir se melent dans ses eaux.",
		"labels": ["Boire", "Plonger", "Mediter"],
		"effects": [
			["HEAL_LIFE:10", "ADD_REPUTATION:anciens:3"],
			["ADD_REPUTATION:ankou:5", "DAMAGE_LIFE:5"],
			["ADD_ANAM:5", "ADD_TENSION:1"],
		],
	},
]

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _store: Node  # MerlinStore
var _overlay: Node  # WalkEventOverlay (CanvasLayer)
var _hud: Node  # WalkHUD (CanvasLayer)
var _vfx: RefCounted  # BrocEventVfx

var _timer: float = 0.0
var _cooldown: float = 0.0
var _next_interval: float = 60.0
var _last_zone: int = -1
var _event_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _event_buffer: Array[Dictionary] = []
var _current_event: Dictionary = {}
var _prefetch_pending: bool = false
var _llm_available: bool = false
var _narrative_director: RefCounted  # BrocNarrativeDirector (passed via update)

# Run state
var _run_active: bool = false
var _cards_played: int = 0
var _story_log: Array[Dictionary] = []


func get_story_log() -> Array[Dictionary]:
	return _story_log


func get_cards_played() -> int:
	return _cards_played


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(store: Node, overlay: Node, hud: Node, vfx: RefCounted) -> void:
	_store = store
	_overlay = overlay
	_hud = hud
	_vfx = vfx
	_rng.randomize()
	# First event triggers quickly (8-15s) for immediate engagement
	_next_interval = _rng.randf_range(8.0, 15.0)

	# Connect overlay signals
	if _overlay.has_signal("choice_selected"):
		_overlay.choice_selected.connect(_on_choice_selected)
	if _overlay.has_signal("overlay_closed"):
		_overlay.overlay_closed.connect(_on_overlay_closed)

	# Check LLM availability
	if _store and _store.get("llm"):
		_llm_available = _store.llm.is_llm_ready() if _store.llm.has_method("is_llm_ready") else false

	_run_active = true
	_init_hud()
	print("[WalkEventController] Setup complete. LLM: %s" % ("available" if _llm_available else "fallback"))


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE (called every physics frame)
# ═══════════════════════════════════════════════════════════════════════════════

func update(delta: float, player_pos: Vector3, current_zone: int, narrative_director: RefCounted = null) -> void:
	if not _run_active:
		return

	# Store director ref for use in _trigger_event
	_narrative_director = narrative_director

	# Don't tick timer while overlay is active
	if _overlay and _overlay.is_active():
		return

	# VFX update
	if _vfx and _vfx.has_method("update"):
		_vfx.update(delta)

	# Cooldown
	_cooldown = maxf(_cooldown - delta, 0.0)

	# Zone change trigger
	if current_zone != _last_zone and _last_zone >= 0 and _cooldown <= 0.0:
		_last_zone = current_zone
		_trigger_event("zone_change", player_pos)
		return
	_last_zone = current_zone

	# Timer trigger
	_timer += delta
	if _timer >= _next_interval and _cooldown <= 0.0:
		_timer = 0.0
		_next_interval = _rng.randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX)
		_trigger_event("timer", player_pos)

	# Background prefetch
	if not _prefetch_pending and _event_buffer.size() < PREFETCH_BUFFER_SIZE:
		_prefetch_event()

	# HUD update
	_update_hud()


func trigger_poi_event(player_pos: Vector3) -> void:
	if _cooldown <= 0.0 and _overlay and not _overlay.is_active():
		_trigger_event("poi", player_pos)


# ═══════════════════════════════════════════════════════════════════════════════
# EVENT TRIGGER
# ═══════════════════════════════════════════════════════════════════════════════

func _trigger_event(trigger_type: String, player_pos: Vector3) -> void:
	if _overlay and _overlay.is_active():
		return

	var event: Dictionary = _get_next_event()
	if event.is_empty():
		return

	_current_event = event
	_cooldown = COOLDOWN_MIN
	_event_count += 1

	print("[WalkEventController] Event #%d (%s): %s" % [
		_event_count, trigger_type, event.get("text", "").substr(0, 60)])

	# Trigger VFX: use narrative director if available, else legacy keyword VFX
	if _narrative_director and _narrative_director.has_method("directive_from_text"):
		# Check for LLM scene_directive first
		var directive: Dictionary = event.get("scene_directive", {})
		if not directive.is_empty():
			_narrative_director.apply_directive(directive, player_pos)
		else:
			_narrative_director.directive_from_text(event.get("text", ""), player_pos)
	elif _vfx and _vfx.has_method("trigger_for_text"):
		_vfx.trigger_for_text(event.get("text", ""), player_pos)

	# Show overlay
	var text: String = event.get("text", "...")
	var labels: Array[String] = []
	for label in event.get("labels", ["A", "B", "C"]):
		labels.append(str(label))
	_overlay.show_event(text, labels)


func _get_next_event() -> Dictionary:
	# Try buffer first
	if _event_buffer.size() > 0:
		return _event_buffer.pop_front()
	# Fallback
	return _get_fallback_event()


func _get_fallback_event() -> Dictionary:
	var idx: int = _rng.randi_range(0, FALLBACK_EVENTS.size() - 1)
	return FALLBACK_EVENTS[idx].duplicate(true)


# ═══════════════════════════════════════════════════════════════════════════════
# LLM PREFETCH
# ═══════════════════════════════════════════════════════════════════════════════

func _prefetch_event() -> void:
	if not _llm_available or not _store:
		return
	if _prefetch_pending:
		return

	_prefetch_pending = true
	_do_prefetch()


func _do_prefetch() -> void:
	if not _store or not _store.get("llm"):
		_prefetch_pending = false
		return

	# Build context from current game state
	var context: Dictionary = _build_llm_context()

	# Generate card via existing pipeline (async)
	var result: Dictionary = await _store.llm.generate_card(context)

	# Guard: controller may have been stopped while awaiting
	if not _run_active:
		_prefetch_pending = false
		return

	if result.get("ok", false):
		var card: Dictionary = result.get("card", {})
		var event: Dictionary = _card_to_event(card)
		if not event.is_empty():
			_event_buffer.append(event)
			print("[WalkEventController] Prefetched event (buffer: %d)" % _event_buffer.size())

	_prefetch_pending = false


func _build_llm_context() -> Dictionary:
	if not _store or _store.state.is_empty():
		return {}

	var run: Dictionary = _store.state.get("run", {})

	return {
		"biome": run.get("biome", "foret_broceliande"),
		"day": run.get("day", 1),
		"season": run.get("season", "automne"),
		"tension": float(run.get("tension", 20)),
		"life_essence": int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)),
		"cards_played": _cards_played,
		"story_log": _story_log,
		"tags": run.get("tags", []),
	}


func _card_to_event(card: Dictionary) -> Dictionary:
	var text: String = str(card.get("text", ""))
	if text.is_empty():
		return {}

	var options: Array = card.get("options", [])
	var labels: Array[String] = []
	var effects: Array[Array] = []

	for opt in options:
		labels.append(str(opt.get("label", "...")))
		var opt_effects: Array[String] = []
		for eff in opt.get("effects", []):
			opt_effects.append(str(eff))
		effects.append(opt_effects)

	# Pad to 3 options
	while labels.size() < 3:
		labels.append("...")
		effects.append([])

	return {
		"text": text,
		"labels": labels,
		"effects": effects,
		"card_id": card.get("id", ""),
		"source": "llm",
	}


# ═══════════════════════════════════════════════════════════════════════════════
# CHOICE RESOLUTION
# ═══════════════════════════════════════════════════════════════════════════════

func _on_choice_selected(option: int) -> void:
	if _current_event.is_empty():
		return

	var effects_list: Array = _current_event.get("effects", [])
	var chosen_effects: Array = []
	if option >= 0 and option < effects_list.size():
		chosen_effects = effects_list[option]

	# Apply effects via store
	if _store and not chosen_effects.is_empty():
		var result: Dictionary = _store.effects.apply_effects(
			_store.state, chosen_effects, "WALK_EVENT")
		print("[WalkEventController] Applied effects: %s → %s" % [
			chosen_effects, result.get("applied", [])])

		# Emit state changed
		if _store.has_method("_emit_state_changed"):
			_store._emit_state_changed()

	# Log to story
	var labels: Array = _current_event.get("labels", [])
	var chosen_label: String = str(labels[option]) if option < labels.size() else "?"
	_story_log.append({
		"card_idx": _cards_played + 1,
		"text": _current_event.get("text", "").substr(0, 200),
		"choice": chosen_label,
		"option": option,
		"effects": chosen_effects,
	})
	_cards_played += 1

	# Check run end conditions
	_check_run_end()


func _on_overlay_closed() -> void:
	_current_event = {}
	# Refresh HUD after effects applied
	_update_hud()


# ═══════════════════════════════════════════════════════════════════════════════
# HUD
# ═══════════════════════════════════════════════════════════════════════════════

func _init_hud() -> void:
	if not _hud or not _store:
		return
	var run: Dictionary = _store.state.get("run", {})
	_hud.update_pv(int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)), int(run.get("life_max", MerlinConstants.LIFE_ESSENCE_MAX)))
	var meta: Dictionary = _store.state.get("meta", {})
	_hud.update_essences(int(meta.get("essences", 0)))


func _update_hud() -> void:
	if not _hud or not _store:
		return
	var run: Dictionary = _store.state.get("run", {})
	_hud.update_pv(int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)), int(run.get("life_max", MerlinConstants.LIFE_ESSENCE_MAX)))
	var meta: Dictionary = _store.state.get("meta", {})
	_hud.update_essences(int(meta.get("essences", 0)))


# ═══════════════════════════════════════════════════════════════════════════════
# RUN END CHECK
# ═══════════════════════════════════════════════════════════════════════════════

func _check_run_end() -> void:
	if not _store:
		return
	var run: Dictionary = _store.state.get("run", {})
	var life: int = int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START))
	if life <= 0:
		_run_active = false
		print("[WalkEventController] Run ended: life depleted")
		if _store.has_signal("run_ended"):
			_store.run_ended.emit({"reason": "life_depleted", "cards_played": _cards_played})

