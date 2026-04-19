## =============================================================================
## SFXEngine — Enum-based procedural audio engine for M.E.R.L.I.N.
## =============================================================================
## Type-safe API for game audio events. Pre-generates all sounds from
## SFXRecipes/SFXRecipesAmbient at startup. Manages an AudioStreamPlayer pool.
## Used by AudioIntegration as the primary sound interface.
## =============================================================================

extends Node
class_name SFXEngine

# =============================================================================
# SFX ENUM
# =============================================================================

enum SFX {
	CARD_DRAW,
	CARD_FLIP,
	OPTION_SELECT,
	MINIGAME_START,
	MINIGAME_END,
	SCORE_REVEAL,
	EFFECT_POSITIVE,
	EFFECT_NEGATIVE,
	OGHAM_ACTIVATE,
	OGHAM_COOLDOWN,
	LIFE_DRAIN,
	LIFE_HEAL,
	DEATH,
	VICTORY,
	REP_UP,
	REP_DOWN,
	ANAM_GAIN,
	WALK_STEP,
	BIOME_TRANSITION,
	MENU_CLICK,
	MENU_HOVER,
	PROMISE_CREATE,
	PROMISE_FULFILL,
	PROMISE_BREAK,
	KARMA_SHIFT,
	HUB_AMBIENT,
	RUN_AMBIENT,
}

# =============================================================================
# CONSTANTS
# =============================================================================

const POOL_SIZE: int = 8
const VOLUME_DB_MAX: float = 6.0
const VOLUME_DB_MIN: float = -80.0
const BUS_NAME: String = "SFX"

enum VolumeCategory { UI, TRANSITION, MAGIC, IMPACT, AMBIENT }

const CATEGORY_VOLUME: Dictionary = {
	VolumeCategory.UI: -10.0,
	VolumeCategory.TRANSITION: -8.0,
	VolumeCategory.MAGIC: -6.0,
	VolumeCategory.IMPACT: -7.0,
	VolumeCategory.AMBIENT: -12.0,
}

const SFX_VOLUME_MAP: Dictionary = {
	SFX.CARD_DRAW: VolumeCategory.TRANSITION,
	SFX.CARD_FLIP: VolumeCategory.TRANSITION,
	SFX.OPTION_SELECT: VolumeCategory.UI,
	SFX.MINIGAME_START: VolumeCategory.TRANSITION,
	SFX.MINIGAME_END: VolumeCategory.TRANSITION,
	SFX.SCORE_REVEAL: VolumeCategory.TRANSITION,
	SFX.EFFECT_POSITIVE: VolumeCategory.TRANSITION,
	SFX.EFFECT_NEGATIVE: VolumeCategory.TRANSITION,
	SFX.OGHAM_ACTIVATE: VolumeCategory.MAGIC,
	SFX.OGHAM_COOLDOWN: VolumeCategory.MAGIC,
	SFX.LIFE_DRAIN: VolumeCategory.TRANSITION,
	SFX.LIFE_HEAL: VolumeCategory.TRANSITION,
	SFX.DEATH: VolumeCategory.MAGIC,
	SFX.VICTORY: VolumeCategory.MAGIC,
	SFX.REP_UP: VolumeCategory.TRANSITION,
	SFX.REP_DOWN: VolumeCategory.TRANSITION,
	SFX.ANAM_GAIN: VolumeCategory.MAGIC,
	SFX.WALK_STEP: VolumeCategory.IMPACT,
	SFX.BIOME_TRANSITION: VolumeCategory.TRANSITION,
	SFX.MENU_CLICK: VolumeCategory.UI,
	SFX.MENU_HOVER: VolumeCategory.UI,
	SFX.PROMISE_CREATE: VolumeCategory.MAGIC,
	SFX.PROMISE_FULFILL: VolumeCategory.MAGIC,
	SFX.PROMISE_BREAK: VolumeCategory.MAGIC,
	SFX.KARMA_SHIFT: VolumeCategory.MAGIC,
	SFX.HUB_AMBIENT: VolumeCategory.AMBIENT,
	SFX.RUN_AMBIENT: VolumeCategory.AMBIENT,
}

# =============================================================================
# STATE
# =============================================================================

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _master_volume_db: float = 0.0
var _enabled: bool = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_rng.randomize()
	_create_player_pool()
	_generate_all_sounds()

func _create_player_pool() -> void:
	for i in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = 0.0
		if AudioServer.get_bus_index(BUS_NAME) >= 0:
			player.bus = BUS_NAME
		add_child(player)
		_players.append(player)

# =============================================================================
# PUBLIC API
# =============================================================================

func play(sfx_id: int) -> void:
	if not _enabled:
		return
	var stream: AudioStreamWAV = _cache.get(sfx_id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = _get_volume_db(sfx_id)
	player.pitch_scale = 1.0
	player.play()

func play_varied(sfx_id: int, variation: float = 0.1) -> void:
	if not _enabled:
		return
	var stream: AudioStreamWAV = _cache.get(sfx_id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_free_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = _get_volume_db(sfx_id)
	player.pitch_scale = 1.0 + _rng.randf_range(-variation, variation)
	player.play()

func stop_all() -> void:
	for p in _players:
		if p.playing:
			p.stop()

func has_sound(sfx_id: int) -> bool:
	return _cache.has(sfx_id)

func set_master_volume(db: float) -> void:
	_master_volume_db = clampf(db, VOLUME_DB_MIN, VOLUME_DB_MAX)

func get_master_volume() -> float:
	return _master_volume_db

func set_sfx_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		stop_all()

func is_sfx_enabled() -> bool:
	return _enabled

func get_pool_size() -> int:
	return _players.size()

func get_active_count() -> int:
	var count: int = 0
	for p in _players:
		if p.playing:
			count += 1
	return count

# =============================================================================
# PLAYER POOL
# =============================================================================

func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _get_volume_db(sfx_id: int) -> float:
	var cat: int = SFX_VOLUME_MAP.get(sfx_id, VolumeCategory.UI)
	var base_db: float = CATEGORY_VOLUME.get(cat, -10.0)
	return base_db + _master_volume_db

# =============================================================================
# SOUND GENERATION
# =============================================================================

func _generate_all_sounds() -> void:
	var recipes: SFXRecipes = SFXRecipes.new(_rng)
	var recipes_amb: SFXRecipesAmbient = SFXRecipesAmbient.new(_rng)

	_cache[SFX.CARD_DRAW] = recipes.gen_card_draw()
	_cache[SFX.CARD_FLIP] = recipes_amb.gen_card_reveal()
	_cache[SFX.OPTION_SELECT] = recipes_amb.gen_choice_select()
	_cache[SFX.MINIGAME_START] = recipes_amb.gen_minigame_start()
	_cache[SFX.MINIGAME_END] = recipes_amb.gen_minigame_success()
	_cache[SFX.SCORE_REVEAL] = recipes_amb.gen_result_reveal()
	_cache[SFX.EFFECT_POSITIVE] = recipes_amb.gen_confirm()
	_cache[SFX.EFFECT_NEGATIVE] = recipes_amb.gen_fail()
	_cache[SFX.OGHAM_ACTIVATE] = recipes.gen_skill_activate()
	_cache[SFX.OGHAM_COOLDOWN] = recipes.gen_ogham_chime()
	_cache[SFX.LIFE_DRAIN] = recipes_amb.gen_aspect_down()
	_cache[SFX.LIFE_HEAL] = recipes_amb.gen_success()
	_cache[SFX.DEATH] = recipes_amb.gen_dice_crit_fail()
	_cache[SFX.VICTORY] = recipes_amb.gen_dice_crit_success()
	_cache[SFX.REP_UP] = recipes_amb.gen_aspect_up()
	_cache[SFX.REP_DOWN] = recipes_amb.gen_aspect_down()
	_cache[SFX.ANAM_GAIN] = recipes.gen_magic_reveal()
	_cache[SFX.WALK_STEP] = recipes.gen_pixel_land()
	_cache[SFX.BIOME_TRANSITION] = recipes.gen_scene_transition()
	_cache[SFX.MENU_CLICK] = recipes.gen_click()
	_cache[SFX.MENU_HOVER] = recipes.gen_hover()
	_cache[SFX.PROMISE_CREATE] = recipes.gen_ogham_unlock()
	_cache[SFX.PROMISE_FULFILL] = recipes_amb.gen_perk_confirm()
	_cache[SFX.PROMISE_BREAK] = recipes_amb.gen_error()
	_cache[SFX.KARMA_SHIFT] = recipes_amb.gen_critical_alert()
	_cache[SFX.HUB_AMBIENT] = recipes_amb.gen_hub_enter()
	_cache[SFX.RUN_AMBIENT] = recipes_amb.gen_amb_broceliande()
