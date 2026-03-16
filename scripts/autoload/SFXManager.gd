## ═══════════════════════════════════════════════════════════════════════════════
## SFXManager — Centralized Procedural Sound System for M.E.R.L.I.N.
## ═══════════════════════════════════════════════════════════════════════════════
## All sounds are procedurally generated — zero audio files required.
## Each sound is pre-generated at startup for instant playback.
## Usage: SFXManager.play("hover"), SFXManager.play("click"), etc.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const SAMPLE_RATE := 44100
const POOL_SIZE := 6  # Concurrent audio players

# Volume presets (linear 0.0-1.0, will be converted to dB)
const VOLUME := {
	"ui": 0.25,
	"ambient": 0.15,
	"impact": 0.30,
	"magic": 0.20,
	"transition": 0.22,
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _sounds: Dictionary = {}  # name -> AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _master_volume: float = 1.0


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_rng.randomize()
	_create_player_pool()
	_generate_all_sounds()


func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Play a named sound. Optional pitch_scale for variation.
func play(sound_name: String, pitch_scale: float = 1.0) -> void:
	if not _sounds.has(sound_name):
		return
	var player := _get_next_player()
	player.stream = _sounds[sound_name]
	player.pitch_scale = pitch_scale
	player.volume_db = linear_to_db(_get_volume_for(sound_name) * _master_volume)
	player.play()


## Play with random pitch variation (good for repeated sounds).
func play_varied(sound_name: String, variation: float = 0.1) -> void:
	var pitch := 1.0 + _rng.randf_range(-variation, variation)
	play(sound_name, pitch)


## Typewriter blip — very soft high click (used by MerlinBubble).
func play_ui_click() -> void:
	play("click", 1.3)


## Play biome-specific ambient sound (Phase 1 TransitionBiome — one per biome).
func play_biome_ambient(biome_key: String) -> void:
	play("amb_" + biome_key)


## Set master volume (0.0 to 1.0).
func set_master_volume(vol: float) -> void:
	_master_volume = clampf(vol, 0.0, 1.0)


func _get_next_player() -> AudioStreamPlayer:
	# Find a free player, or cycle through pool
	for i in range(POOL_SIZE):
		var idx := (_pool_index + i) % POOL_SIZE
		if not _pool[idx].playing:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# All busy — use round-robin (will cut oldest)
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	return player


func _get_volume_for(sound_name: String) -> float:
	# Map sound names to volume categories
	if sound_name in ["hover", "click", "slider_tick", "button_appear"]:
		return VOLUME.ui
	if sound_name in ["whoosh", "card_draw", "card_swipe", "scene_transition"]:
		return VOLUME.transition
	if sound_name in ["block_land", "pixel_land", "pixel_cascade", "pixel_scatter",
			"accum_explode", "dice_land", "dice_roll"]:
		return VOLUME.impact
	if sound_name in ["ogham_chime", "ogham_unlock", "bestiole_shimmer", "eye_open",
			"flash_boom", "magic_reveal", "skill_activate",
			"dice_crit_success", "dice_crit_fail", "critical_alert"]:
		return VOLUME.magic
	if sound_name in ["path_scratch", "landmark_pop", "mist_breath", "aspect_shift", "hub_enter"]:
		return VOLUME.ambient
	if sound_name.begins_with("amb_"):
		return VOLUME.ambient
	if sound_name in ["dice_shake", "minigame_tick", "error"]:
		return VOLUME.ui
	if sound_name in ["minigame_start", "minigame_success", "minigame_fail",
			"biome_reveal", "partir_fanfare"]:
		return VOLUME.transition
	if sound_name in ["camera_focus", "souffle_regen", "souffle_full", "perk_confirm"]:
		return VOLUME.magic
	return VOLUME.ui


# ═══════════════════════════════════════════════════════════════════════════════
# SOUND GENERATION — All procedural, no files
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_all_sounds() -> void:
	var recipes: SFXRecipes = SFXRecipes.new(_rng)
	var recipes_amb: SFXRecipesAmbient = SFXRecipesAmbient.new(_rng)
	var names: Array[String] = [
		"hover", "click", "slider_tick", "button_appear",
		"whoosh", "card_draw", "card_swipe", "scene_transition",
		"block_land", "pixel_land", "pixel_cascade", "pixel_scatter", "accum_explode",
		"ogham_chime", "ogham_unlock", "bestiole_shimmer", "eye_open",
		"flash_boom", "magic_reveal", "skill_activate",
		"path_scratch", "landmark_pop", "mist_breath",
		"aspect_shift", "aspect_up", "aspect_down",
		"boot_line", "boot_confirm", "convergence", "slit_glow",
		"choice_hover", "choice_select", "result_reveal", "question_transition",
		"dice_shake", "dice_roll", "dice_land", "dice_crit_success", "dice_crit_fail",
		"minigame_start", "minigame_success", "minigame_fail", "minigame_tick", "critical_alert",
		"souffle_regen", "souffle_full",
		"camera_focus", "error", "hub_enter", "perk_confirm", "biome_reveal", "partir_fanfare",
		"biome_dissolve",
		"amb_broceliande", "amb_landes", "amb_cotes", "amb_cercles",
		"amb_marais", "amb_collines", "amb_villages",
	]
	for snd_name in names:
		var method_name: String = "gen_" + snd_name
		if recipes.has_method(method_name):
			_sounds[snd_name] = recipes.call(method_name)
		elif recipes_amb.has_method(method_name):
			_sounds[snd_name] = recipes_amb.call(method_name)
