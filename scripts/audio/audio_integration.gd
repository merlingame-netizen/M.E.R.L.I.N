## =============================================================================
## AudioIntegration — Signal-to-audio bridge for all game systems
## =============================================================================
## Connects game signals (Run3D, Hub, EndScreen, GameFlow) to SFXEngine and
## MusicManagerV2 triggers. Centralizes all audio wiring in one place.
## Does NOT modify existing scripts — listens to their signals.
##
## Usage:
##   var audio_int: AudioIntegration = AudioIntegration.new()
##   audio_int.wire_run(run_controller, sfx_engine, music_manager)
##   audio_int.wire_hub(hub_screen, sfx_engine, music_manager)
##   audio_int.wire_end_screen(end_screen, sfx_engine)
##   audio_int.wire_flow(flow_controller, sfx_engine, music_manager)
## =============================================================================

extends Node
class_name AudioIntegration

# =============================================================================
# CONFIGURATION
# =============================================================================

const MUSIC_FADE_DURATION: float = 1.5
const MINIGAME_MUSIC_FADE: float = 0.8
const AMBIENT_VOLUME_DB: float = -12.0

# =============================================================================
# STATE — tracked references for safe disconnect
# =============================================================================

var _wired_run: Run3DController = null
var _wired_hub: HubScreen = null
var _wired_end_screen: EndRunScreen = null
var _wired_flow: GameFlowController = null

var _sfx: SFXEngine = null
var _music: MusicManagerV2 = null


# =============================================================================
# WIRE: RUN 3D CONTROLLER
# =============================================================================

## Connects Run3DController signals to SFX and music triggers.
## Call after the run controller is instantiated and ready.
func wire_run(run_controller: Run3DController, sfx: SFXEngine,
		music: MusicManagerV2 = null) -> void:
	unwire_run()
	if run_controller == null or sfx == null:
		push_warning("[AudioIntegration] wire_run: null run_controller or sfx")
		return

	_wired_run = run_controller
	_sfx = sfx
	_music = music

	run_controller.card_started.connect(_on_run_card_started)
	run_controller.card_ended.connect(_on_run_card_ended)
	run_controller.life_changed.connect(_on_run_life_changed)
	run_controller.ogham_updated.connect(_on_run_ogham_updated)
	run_controller.run_ended.connect(_on_run_ended)
	run_controller.period_changed.connect(_on_run_period_changed)
	run_controller.currency_changed.connect(_on_run_currency_changed)
	run_controller.convergence_zone_entered.connect(_on_run_convergence)


## Disconnect all run signals safely.
func unwire_run() -> void:
	if _wired_run == null:
		return
	_safe_disconnect(_wired_run.card_started, _on_run_card_started)
	_safe_disconnect(_wired_run.card_ended, _on_run_card_ended)
	_safe_disconnect(_wired_run.life_changed, _on_run_life_changed)
	_safe_disconnect(_wired_run.ogham_updated, _on_run_ogham_updated)
	_safe_disconnect(_wired_run.run_ended, _on_run_ended)
	_safe_disconnect(_wired_run.period_changed, _on_run_period_changed)
	_safe_disconnect(_wired_run.currency_changed, _on_run_currency_changed)
	_safe_disconnect(_wired_run.convergence_zone_entered, _on_run_convergence)
	_wired_run = null


# =============================================================================
# WIRE: HUB SCREEN
# =============================================================================

## Connects HubScreen signals to SFX and music triggers.
func wire_hub(hub_screen: HubScreen, sfx: SFXEngine,
		music: MusicManagerV2 = null) -> void:
	unwire_hub()
	if hub_screen == null or sfx == null:
		push_warning("[AudioIntegration] wire_hub: null hub_screen or sfx")
		return

	_wired_hub = hub_screen
	_sfx = sfx
	_music = music

	hub_screen.run_requested.connect(_on_hub_run_requested)
	hub_screen.talent_tree_requested.connect(_on_hub_talent_requested)
	hub_screen.quit_requested.connect(_on_hub_quit_requested)

	# Start hub music when wired
	if _music:
		_music.set_hub_music()


## Disconnect all hub signals safely.
func unwire_hub() -> void:
	if _wired_hub == null:
		return
	_safe_disconnect(_wired_hub.run_requested, _on_hub_run_requested)
	_safe_disconnect(_wired_hub.talent_tree_requested, _on_hub_talent_requested)
	_safe_disconnect(_wired_hub.quit_requested, _on_hub_quit_requested)
	_wired_hub = null


# =============================================================================
# WIRE: END RUN SCREEN
# =============================================================================

## Connects EndRunScreen signals to SFX triggers.
func wire_end_screen(end_screen: EndRunScreen, sfx: SFXEngine) -> void:
	unwire_end_screen()
	if end_screen == null or sfx == null:
		push_warning("[AudioIntegration] wire_end_screen: null end_screen or sfx")
		return

	_wired_end_screen = end_screen
	_sfx = sfx

	end_screen.hub_requested.connect(_on_end_hub_requested)


## Disconnect all end screen signals safely.
func unwire_end_screen() -> void:
	if _wired_end_screen == null:
		return
	_safe_disconnect(_wired_end_screen.hub_requested, _on_end_hub_requested)
	_wired_end_screen = null


# =============================================================================
# WIRE: GAME FLOW CONTROLLER
# =============================================================================

## Connects GameFlowController signals to music transitions.
func wire_flow(flow_controller: GameFlowController, sfx: SFXEngine,
		music: MusicManagerV2 = null) -> void:
	unwire_flow()
	if flow_controller == null or sfx == null:
		push_warning("[AudioIntegration] wire_flow: null flow_controller or sfx")
		return

	_wired_flow = flow_controller
	_sfx = sfx
	_music = music

	flow_controller.phase_changed.connect(_on_flow_phase_changed)


## Disconnect all flow signals safely.
func unwire_flow() -> void:
	if _wired_flow == null:
		return
	_safe_disconnect(_wired_flow.phase_changed, _on_flow_phase_changed)
	_wired_flow = null


# =============================================================================
# UNWIRE ALL — cleanup helper
# =============================================================================

## Disconnect everything. Call before freeing this node.
func unwire_all() -> void:
	unwire_run()
	unwire_hub()
	unwire_end_screen()
	unwire_flow()
	_sfx = null
	_music = null


# =============================================================================
# RUN SIGNAL HANDLERS
# =============================================================================

## Life tracking for delta-based SFX selection
var _last_life: int = -1

func _on_run_card_started(_card: Dictionary) -> void:
	_play_sfx(SFXEngine.SFX.CARD_DRAW)


func _on_run_card_ended() -> void:
	_play_sfx(SFXEngine.SFX.CARD_FLIP)


func _on_run_life_changed(current: int, _maximum: int) -> void:
	if _last_life < 0:
		# First emission — initialize without playing sound
		_last_life = current
		return

	var delta: int = current - _last_life
	_last_life = current

	if delta > 0:
		_play_sfx(SFXEngine.SFX.LIFE_HEAL)
	elif delta < 0:
		_play_sfx(SFXEngine.SFX.LIFE_DRAIN)


func _on_run_ogham_updated(ogham_id: String, cooldown: int) -> void:
	if cooldown > 0 and not ogham_id.is_empty():
		# Ogham was just activated (cooldown set > 0)
		_play_sfx(SFXEngine.SFX.OGHAM_ACTIVATE)
	elif cooldown == 0 and not ogham_id.is_empty():
		# Ogham came off cooldown
		_play_sfx(SFXEngine.SFX.OGHAM_COOLDOWN)


func _on_run_ended(reason: String, _data: Dictionary) -> void:
	_last_life = -1  # Reset life tracking for next run

	if reason == "death":
		_play_sfx(SFXEngine.SFX.DEATH)
	else:
		_play_sfx(SFXEngine.SFX.VICTORY)

	# Fade out run music
	if _music:
		_music.fade_out(MUSIC_FADE_DURATION)


func _on_run_period_changed(period: String) -> void:
	# Period transitions get a subtle biome transition SFX
	if not period.is_empty():
		_play_sfx(SFXEngine.SFX.BIOME_TRANSITION)


func _on_run_currency_changed(_amount: int) -> void:
	_play_sfx(SFXEngine.SFX.ANAM_GAIN)


func _on_run_convergence(_card_index: int) -> void:
	# Convergence zone — dramatic cue
	_play_sfx(SFXEngine.SFX.KARMA_SHIFT)


# =============================================================================
# HUB SIGNAL HANDLERS
# =============================================================================

func _on_hub_run_requested(_biome_id: String, _selected_oghams: Array) -> void:
	_play_sfx(SFXEngine.SFX.MENU_CLICK)
	# Music transition happens via flow phase_changed


func _on_hub_talent_requested() -> void:
	_play_sfx(SFXEngine.SFX.MENU_CLICK)


func _on_hub_quit_requested() -> void:
	_play_sfx(SFXEngine.SFX.MENU_CLICK)
	if _music:
		_music.fade_out(MUSIC_FADE_DURATION)


# =============================================================================
# END SCREEN SIGNAL HANDLERS
# =============================================================================

func _on_end_hub_requested() -> void:
	_play_sfx(SFXEngine.SFX.MENU_CLICK)


# =============================================================================
# FLOW SIGNAL HANDLERS — Music transitions per phase
# =============================================================================

func _on_flow_phase_changed(old_phase: String, new_phase: String) -> void:
	if _music == null:
		return

	match new_phase:
		"hub":
			_music.set_hub_music()
		"menu":
			_music.set_menu_music()
		"run":
			# Run music is set when biome is known (via wire_run biome signal).
			# For now, fade out hub music — biome music will start separately.
			if old_phase == "hub":
				_music.fade_out(MUSIC_FADE_DURATION)
		"end_screen":
			# End screen: music already faded out by run_ended handler.
			pass
		"talent_tree":
			# Keep hub music playing during talent tree.
			pass


# =============================================================================
# BIOME MUSIC — Call explicitly when biome is known during run start
# =============================================================================

## Set biome-specific music for the current run.
## Call this after start_run when the biome ID is known.
func set_run_biome_music(biome_id: String) -> void:
	if _music and not biome_id.is_empty():
		_music.set_biome_music(biome_id)


# =============================================================================
# MINIGAME AUDIO HELPERS
# =============================================================================

## Call before a minigame starts to play SFX and fade music.
func on_minigame_started() -> void:
	_play_sfx(SFXEngine.SFX.MINIGAME_START)
	if _music:
		_music.set_volume(_music._master_volume_db - 6.0)


## Call after a minigame completes to play SFX and restore music.
func on_minigame_completed(score: int) -> void:
	_play_sfx(SFXEngine.SFX.MINIGAME_END)

	if score >= 60:
		_play_sfx(SFXEngine.SFX.EFFECT_POSITIVE)
	else:
		_play_sfx(SFXEngine.SFX.EFFECT_NEGATIVE)

	_play_sfx(SFXEngine.SFX.SCORE_REVEAL)

	# Restore music volume
	if _music:
		_music.set_volume(_music._master_volume_db + 6.0)


# =============================================================================
# REPUTATION AUDIO — Call from effect application
# =============================================================================

## Play SFX for reputation change. Call from effect application code.
func on_reputation_changed(delta: int) -> void:
	if delta > 0:
		_play_sfx(SFXEngine.SFX.REP_UP)
	elif delta < 0:
		_play_sfx(SFXEngine.SFX.REP_DOWN)


# =============================================================================
# PROMISE AUDIO — Call from promise system
# =============================================================================

## Play SFX for promise events.
func on_promise_created() -> void:
	_play_sfx(SFXEngine.SFX.PROMISE_CREATE)


func on_promise_fulfilled() -> void:
	_play_sfx(SFXEngine.SFX.PROMISE_FULFILL)


func on_promise_broken() -> void:
	_play_sfx(SFXEngine.SFX.PROMISE_BREAK)


# =============================================================================
# OPTION SELECT — Call from card UI when player selects an option
# =============================================================================

## Play SFX when the player selects a card option.
func on_option_selected() -> void:
	_play_sfx(SFXEngine.SFX.OPTION_SELECT)


# =============================================================================
# INTERNALS
# =============================================================================

func _play_sfx(sfx_id: int) -> void:
	if _sfx == null:
		return
	_sfx.play(sfx_id)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


# =============================================================================
# QUERY — for testing and debugging
# =============================================================================

## Returns true if a run controller is currently wired.
func is_run_wired() -> bool:
	return _wired_run != null


## Returns true if a hub screen is currently wired.
func is_hub_wired() -> bool:
	return _wired_hub != null


## Returns true if an end screen is currently wired.
func is_end_screen_wired() -> bool:
	return _wired_end_screen != null


## Returns true if a flow controller is currently wired.
func is_flow_wired() -> bool:
	return _wired_flow != null


## Returns the last tracked life value (for testing delta logic).
func get_last_tracked_life() -> int:
	return _last_life


## Reset life tracking (call between runs).
func reset_life_tracking() -> void:
	_last_life = -1
