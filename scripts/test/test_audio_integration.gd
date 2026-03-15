## =============================================================================
## Unit Tests -- AudioIntegration Signal-to-Audio Bridge
## =============================================================================
## Tests: signal wiring, SFX mapping, music transitions, life delta logic,
## ogham activation SFX, run end SFX, hub SFX, flow phase music, unwire safety.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## =============================================================================

extends RefCounted


# =============================================================================
# MOCK: SFXEngine — records play() calls without producing sound
# =============================================================================

class MockSFX extends SFXEngine:
	var played_sfx: Array[int] = []
	var play_count: int = 0

	func play(sfx_id: int, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
		played_sfx.append(sfx_id)
		play_count += 1

	func has_played(sfx_id: int) -> bool:
		return played_sfx.has(sfx_id)

	func last_played() -> int:
		if played_sfx.is_empty():
			return -1
		return played_sfx[played_sfx.size() - 1]

	func clear_history() -> void:
		played_sfx.clear()
		play_count = 0


# =============================================================================
# MOCK: MusicManagerV2 — records method calls
# =============================================================================

class MockMusic extends MusicManagerV2:
	var last_method: String = ""
	var last_biome: String = ""
	var last_fade_duration: float = 0.0
	var last_volume_db: float = -6.0
	var method_calls: Array[String] = []

	func set_biome_music(biome_id: String) -> void:
		last_method = "set_biome_music"
		last_biome = biome_id
		method_calls.append("set_biome_music:%s" % biome_id)

	func set_hub_music() -> void:
		last_method = "set_hub_music"
		method_calls.append("set_hub_music")

	func set_menu_music() -> void:
		last_method = "set_menu_music"
		method_calls.append("set_menu_music")

	func fade_out(duration: float = 1.0) -> void:
		last_method = "fade_out"
		last_fade_duration = duration
		method_calls.append("fade_out")

	func set_volume(volume_db: float) -> void:
		last_method = "set_volume"
		last_volume_db = volume_db
		method_calls.append("set_volume")

	func clear_history() -> void:
		last_method = ""
		last_biome = ""
		method_calls.clear()


# =============================================================================
# HELPERS
# =============================================================================

func _make_integration() -> AudioIntegration:
	return AudioIntegration.new()


func _make_sfx() -> MockSFX:
	return MockSFX.new()


func _make_music() -> MockMusic:
	return MockMusic.new()


func _make_run_controller() -> Run3DController:
	return Run3DController.new()


func _make_hub_screen() -> HubScreen:
	return HubScreen.new()


func _make_end_screen() -> EndRunScreen:
	return EndRunScreen.new()


func _make_flow_controller() -> GameFlowController:
	return GameFlowController.new()


func _cleanup(nodes: Array) -> void:
	for node in nodes:
		if node != null and node is Node:
			node.queue_free()


# =============================================================================
# RUN ALL
# =============================================================================

func run_all() -> Dictionary:
	var results: Dictionary = {}
	var methods: Array[String] = [
		"test_wire_run_connects_signals",
		"test_unwire_run_disconnects",
		"test_card_started_plays_card_draw",
		"test_card_ended_plays_card_flip",
		"test_life_heal_sfx_on_increase",
		"test_life_drain_sfx_on_decrease",
		"test_life_first_emission_no_sfx",
		"test_ogham_activate_sfx",
		"test_ogham_cooldown_sfx",
		"test_run_ended_death_plays_death",
		"test_run_ended_victory_plays_victory",
		"test_run_ended_fades_music",
		"test_hub_wire_starts_hub_music",
		"test_hub_run_requested_plays_click",
		"test_end_screen_wire_and_sfx",
		"test_flow_phase_hub_sets_hub_music",
		"test_flow_phase_menu_sets_menu_music",
		"test_flow_phase_run_fades_hub_music",
		"test_set_run_biome_music",
		"test_minigame_started_sfx_and_volume",
		"test_minigame_completed_positive",
		"test_minigame_completed_negative",
		"test_reputation_up_sfx",
		"test_reputation_down_sfx",
		"test_promise_sfx",
		"test_option_selected_sfx",
		"test_convergence_plays_karma_shift",
		"test_period_changed_plays_biome_transition",
		"test_unwire_all_clears_everything",
		"test_null_sfx_no_crash",
	]

	var pass_count: int = 0
	var fail_count: int = 0

	for method_name in methods:
		var result: bool = call(method_name)
		results[method_name] = result
		if result:
			pass_count += 1
		else:
			fail_count += 1
			push_error("[AudioIntegration] FAIL: %s" % method_name)

	print("[AudioIntegration] Tests: %d passed, %d failed, %d total" % [
		pass_count, fail_count, pass_count + fail_count
	])

	return results


# =============================================================================
# TEST: Wire run connects all signals
# =============================================================================

func test_wire_run_connects_signals() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	var wired: bool = ai.is_run_wired()

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return wired


# =============================================================================
# TEST: Unwire run disconnects signals
# =============================================================================

func test_unwire_run_disconnects() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	ai.unwire_run()

	var not_wired: bool = not ai.is_run_wired()

	# Emitting signal after unwire should not cause errors
	run.card_started.emit({})
	var no_play: bool = sfx.play_count == 0

	_cleanup([ai, run, sfx])
	return not_wired and no_play


# =============================================================================
# TEST: card_started emits CARD_DRAW
# =============================================================================

func test_card_started_plays_card_draw() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.card_started.emit({"type": "narrative"})

	var ok: bool = sfx.has_played(SFXEngine.SFX.CARD_DRAW)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: card_ended emits CARD_FLIP
# =============================================================================

func test_card_ended_plays_card_flip() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.card_ended.emit()

	var ok: bool = sfx.has_played(SFXEngine.SFX.CARD_FLIP)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: Life increase plays LIFE_HEAL
# =============================================================================

func test_life_heal_sfx_on_increase() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	# First emission initializes tracking (no SFX)
	run.life_changed.emit(50, 100)
	sfx.clear_history()

	# Second emission: life increased
	run.life_changed.emit(60, 100)

	var ok: bool = sfx.has_played(SFXEngine.SFX.LIFE_HEAL)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: Life decrease plays LIFE_DRAIN
# =============================================================================

func test_life_drain_sfx_on_decrease() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.life_changed.emit(50, 100)
	sfx.clear_history()

	run.life_changed.emit(40, 100)

	var ok: bool = sfx.has_played(SFXEngine.SFX.LIFE_DRAIN)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: First life emission does not play SFX
# =============================================================================

func test_life_first_emission_no_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.life_changed.emit(80, 100)

	# Should NOT play any life SFX on first emission
	var no_heal: bool = not sfx.has_played(SFXEngine.SFX.LIFE_HEAL)
	var no_drain: bool = not sfx.has_played(SFXEngine.SFX.LIFE_DRAIN)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return no_heal and no_drain


# =============================================================================
# TEST: Ogham activation plays OGHAM_ACTIVATE
# =============================================================================

func test_ogham_activate_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	# cooldown > 0 means ogham was just activated
	run.ogham_updated.emit("beith", 3)

	var ok: bool = sfx.has_played(SFXEngine.SFX.OGHAM_ACTIVATE)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: Ogham cooldown end plays OGHAM_COOLDOWN
# =============================================================================

func test_ogham_cooldown_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	# cooldown == 0 means ogham came off cooldown
	run.ogham_updated.emit("beith", 0)

	var ok: bool = sfx.has_played(SFXEngine.SFX.OGHAM_COOLDOWN)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: run_ended with death plays DEATH
# =============================================================================

func test_run_ended_death_plays_death() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.run_ended.emit("death", {})

	var ok: bool = sfx.has_played(SFXEngine.SFX.DEATH)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: run_ended with victory plays VICTORY
# =============================================================================

func test_run_ended_victory_plays_victory() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.run_ended.emit("convergence", {})

	var ok: bool = sfx.has_played(SFXEngine.SFX.VICTORY)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: run_ended fades music out
# =============================================================================

func test_run_ended_fades_music() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_run(run, sfx, music)
	run.run_ended.emit("death", {})

	var ok: bool = music.last_method == "fade_out"

	ai.unwire_all()
	_cleanup([ai, run, sfx, music])
	return ok


# =============================================================================
# TEST: Hub wire starts hub music
# =============================================================================

func test_hub_wire_starts_hub_music() -> bool:
	var ai: AudioIntegration = _make_integration()
	var hub: HubScreen = _make_hub_screen()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_hub(hub, sfx, music)

	var ok: bool = music.last_method == "set_hub_music"

	ai.unwire_all()
	_cleanup([ai, hub, sfx, music])
	return ok


# =============================================================================
# TEST: Hub run_requested plays MENU_CLICK
# =============================================================================

func test_hub_run_requested_plays_click() -> bool:
	var ai: AudioIntegration = _make_integration()
	var hub: HubScreen = _make_hub_screen()
	var sfx: MockSFX = _make_sfx()

	ai.wire_hub(hub, sfx)
	hub.run_requested.emit("broceliande", ["beith"])

	var ok: bool = sfx.has_played(SFXEngine.SFX.MENU_CLICK)

	ai.unwire_all()
	_cleanup([ai, hub, sfx])
	return ok


# =============================================================================
# TEST: End screen wire and hub_requested SFX
# =============================================================================

func test_end_screen_wire_and_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var end: EndRunScreen = _make_end_screen()
	var sfx: MockSFX = _make_sfx()

	ai.wire_end_screen(end, sfx)
	var wired: bool = ai.is_end_screen_wired()

	end.hub_requested.emit()
	var clicked: bool = sfx.has_played(SFXEngine.SFX.MENU_CLICK)

	ai.unwire_all()
	_cleanup([ai, end, sfx])
	return wired and clicked


# =============================================================================
# TEST: Flow phase "hub" sets hub music
# =============================================================================

func test_flow_phase_hub_sets_hub_music() -> bool:
	var ai: AudioIntegration = _make_integration()
	var flow: GameFlowController = _make_flow_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_flow(flow, sfx, music)
	music.clear_history()

	flow.phase_changed.emit("end_screen", "hub")

	var ok: bool = music.last_method == "set_hub_music"

	ai.unwire_all()
	_cleanup([ai, flow, sfx, music])
	return ok


# =============================================================================
# TEST: Flow phase "menu" sets menu music
# =============================================================================

func test_flow_phase_menu_sets_menu_music() -> bool:
	var ai: AudioIntegration = _make_integration()
	var flow: GameFlowController = _make_flow_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_flow(flow, sfx, music)
	music.clear_history()

	flow.phase_changed.emit("hub", "menu")

	var ok: bool = music.last_method == "set_menu_music"

	ai.unwire_all()
	_cleanup([ai, flow, sfx, music])
	return ok


# =============================================================================
# TEST: Flow phase "run" fades out hub music
# =============================================================================

func test_flow_phase_run_fades_hub_music() -> bool:
	var ai: AudioIntegration = _make_integration()
	var flow: GameFlowController = _make_flow_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_flow(flow, sfx, music)
	music.clear_history()

	flow.phase_changed.emit("hub", "run")

	var ok: bool = music.last_method == "fade_out"

	ai.unwire_all()
	_cleanup([ai, flow, sfx, music])
	return ok


# =============================================================================
# TEST: set_run_biome_music delegates to MusicManagerV2
# =============================================================================

func test_set_run_biome_music() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_run(run, sfx, music)
	music.clear_history()

	ai.set_run_biome_music("broceliande")

	var ok: bool = music.last_method == "set_biome_music" and music.last_biome == "broceliande"

	ai.unwire_all()
	_cleanup([ai, run, sfx, music])
	return ok


# =============================================================================
# TEST: Minigame started plays SFX and adjusts volume
# =============================================================================

func test_minigame_started_sfx_and_volume() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_run(run, sfx, music)
	ai.on_minigame_started()

	var sfx_ok: bool = sfx.has_played(SFXEngine.SFX.MINIGAME_START)
	var vol_ok: bool = music.last_method == "set_volume"

	ai.unwire_all()
	_cleanup([ai, run, sfx, music])
	return sfx_ok and vol_ok


# =============================================================================
# TEST: Minigame completed positive plays correct SFX
# =============================================================================

func test_minigame_completed_positive() -> bool:
	var ai: AudioIntegration = _make_integration()
	var sfx: MockSFX = _make_sfx()
	ai._sfx = sfx

	ai.on_minigame_completed(80)

	var end_ok: bool = sfx.has_played(SFXEngine.SFX.MINIGAME_END)
	var pos_ok: bool = sfx.has_played(SFXEngine.SFX.EFFECT_POSITIVE)
	var reveal_ok: bool = sfx.has_played(SFXEngine.SFX.SCORE_REVEAL)

	_cleanup([ai, sfx])
	return end_ok and pos_ok and reveal_ok


# =============================================================================
# TEST: Minigame completed negative plays EFFECT_NEGATIVE
# =============================================================================

func test_minigame_completed_negative() -> bool:
	var ai: AudioIntegration = _make_integration()
	var sfx: MockSFX = _make_sfx()
	ai._sfx = sfx

	ai.on_minigame_completed(30)

	var neg_ok: bool = sfx.has_played(SFXEngine.SFX.EFFECT_NEGATIVE)

	_cleanup([ai, sfx])
	return neg_ok


# =============================================================================
# TEST: Reputation up plays REP_UP
# =============================================================================

func test_reputation_up_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var sfx: MockSFX = _make_sfx()
	ai._sfx = sfx

	ai.on_reputation_changed(5)

	var ok: bool = sfx.has_played(SFXEngine.SFX.REP_UP)

	_cleanup([ai, sfx])
	return ok


# =============================================================================
# TEST: Reputation down plays REP_DOWN
# =============================================================================

func test_reputation_down_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var sfx: MockSFX = _make_sfx()
	ai._sfx = sfx

	ai.on_reputation_changed(-3)

	var ok: bool = sfx.has_played(SFXEngine.SFX.REP_DOWN)

	_cleanup([ai, sfx])
	return ok


# =============================================================================
# TEST: Promise SFX (create, fulfill, break)
# =============================================================================

func test_promise_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var sfx: MockSFX = _make_sfx()
	ai._sfx = sfx

	ai.on_promise_created()
	var create_ok: bool = sfx.has_played(SFXEngine.SFX.PROMISE_CREATE)

	ai.on_promise_fulfilled()
	var fulfill_ok: bool = sfx.has_played(SFXEngine.SFX.PROMISE_FULFILL)

	ai.on_promise_broken()
	var break_ok: bool = sfx.has_played(SFXEngine.SFX.PROMISE_BREAK)

	_cleanup([ai, sfx])
	return create_ok and fulfill_ok and break_ok


# =============================================================================
# TEST: Option selected plays OPTION_SELECT
# =============================================================================

func test_option_selected_sfx() -> bool:
	var ai: AudioIntegration = _make_integration()
	var sfx: MockSFX = _make_sfx()
	ai._sfx = sfx

	ai.on_option_selected()

	var ok: bool = sfx.has_played(SFXEngine.SFX.OPTION_SELECT)

	_cleanup([ai, sfx])
	return ok


# =============================================================================
# TEST: Convergence zone plays KARMA_SHIFT
# =============================================================================

func test_convergence_plays_karma_shift() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.convergence_zone_entered.emit(20)

	var ok: bool = sfx.has_played(SFXEngine.SFX.KARMA_SHIFT)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: Period changed plays BIOME_TRANSITION
# =============================================================================

func test_period_changed_plays_biome_transition() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var sfx: MockSFX = _make_sfx()

	ai.wire_run(run, sfx)
	run.period_changed.emit("zenith")

	var ok: bool = sfx.has_played(SFXEngine.SFX.BIOME_TRANSITION)

	ai.unwire_all()
	_cleanup([ai, run, sfx])
	return ok


# =============================================================================
# TEST: unwire_all clears all references
# =============================================================================

func test_unwire_all_clears_everything() -> bool:
	var ai: AudioIntegration = _make_integration()
	var run: Run3DController = _make_run_controller()
	var hub: HubScreen = _make_hub_screen()
	var end: EndRunScreen = _make_end_screen()
	var flow: GameFlowController = _make_flow_controller()
	var sfx: MockSFX = _make_sfx()
	var music: MockMusic = _make_music()

	ai.wire_run(run, sfx, music)
	ai.wire_hub(hub, sfx, music)
	ai.wire_end_screen(end, sfx)
	ai.wire_flow(flow, sfx, music)

	ai.unwire_all()

	var ok: bool = (
		not ai.is_run_wired()
		and not ai.is_hub_wired()
		and not ai.is_end_screen_wired()
		and not ai.is_flow_wired()
	)

	_cleanup([ai, run, hub, end, flow, sfx, music])
	return ok


# =============================================================================
# TEST: Null SFX does not crash
# =============================================================================

func test_null_sfx_no_crash() -> bool:
	var ai: AudioIntegration = _make_integration()
	# _sfx is null by default

	# These should not crash
	ai.on_option_selected()
	ai.on_reputation_changed(5)
	ai.on_minigame_started()
	ai.on_minigame_completed(80)
	ai.on_promise_created()

	_cleanup([ai])
	return true
