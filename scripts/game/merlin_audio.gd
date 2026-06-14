extends Node
## MerlinAudio — autoload central (BIBLE §22, R117).

const SFX_DIR: String = "res://audio/sfx/"
const SFX_IDS: Array = [
	"card_pick", "card_play", "card_discard", "deal", "button_tap",
	"gauge_up", "gauge_down", "corruption_tick", "seal_stamp",
	"beat_turn", "draft_reveal", "whisper_threshold",
	"stinger_echec", "stinger_partiel", "stinger_reussite", "stinger_eclatante",
	"quill_tick", "ink_wash",
]
const POOL_SIZE: int = 8
const DUCK_DB: float = -6.0
const DUCK_RETURN: float = 0.8
const PREFS_PATH: String = "user://options.cfg"

var _sfx_cache: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _duck_tw: Tween = null
var _fade_tw: Tween = null
var _corruption_level: int = 0

var master_vol: float = 0.8
var music_vol: float = 0.6
var sfx_vol: float = 0.45


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_prefs()
	_preload_sfx()
	_create_pool()
	_create_music_players()
	_apply_volumes()


func _preload_sfx() -> void:
	for id in SFX_IDS:
		var path: String = SFX_DIR + id + ".wav"
		if ResourceLoader.exists(path):
			_sfx_cache[id] = load(path)


func _create_pool() -> void:
	for i in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)


func _create_music_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = &"Music"
	_music_a.volume_db = -40.0
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = &"Music"
	_music_b.volume_db = -40.0
	add_child(_music_b)
	_active_music = _music_a


func play_sfx(id: String, pitch_scale: float = 1.0) -> void:
	if not _sfx_cache.has(id):
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % POOL_SIZE
	if p.playing:
		p.stop()
	p.stream = _sfx_cache[id]
	p.pitch_scale = pitch_scale
	p.volume_db = 0.0
	p.play()


func play_stinger(degree: String) -> void:
	var id: String = "stinger_" + degree
	play_sfx("seal_stamp")
	play_sfx(id, 1.0)
	_duck_music()


func _kill_music_tweens() -> void:
	if _duck_tw != null and _duck_tw.is_valid():
		_duck_tw.kill()
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()


func _duck_music() -> void:
	if _active_music == null or not _active_music.playing:
		return
	var restore_db: float = _music_vol_db()
	_kill_music_tweens()
	_duck_tw = create_tween()
	_duck_tw.tween_property(_active_music, "volume_db", restore_db + DUCK_DB, 0.05).set_trans(Tween.TRANS_QUAD)
	_duck_tw.tween_property(_active_music, "volume_db", restore_db, DUCK_RETURN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_music(stream: AudioStream, crossfade_dur: float = 1.5) -> void:
	if stream == null:
		return
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	var incoming: AudioStreamPlayer = _music_b if _active_music == _music_a else _music_a
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	var target_db: float = _music_vol_db()
	_fade_tw = create_tween().set_parallel(true)
	_fade_tw.tween_property(incoming, "volume_db", target_db, crossfade_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _active_music.playing:
		_fade_tw.tween_property(_active_music, "volume_db", -40.0, crossfade_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var old_player: AudioStreamPlayer = _active_music
		_fade_tw.chain().tween_callback(old_player.stop)
	_active_music = incoming


func stop_music(fade_dur: float = 0.5) -> void:
	if not _active_music.playing:
		return
	_kill_music_tweens()
	var player: AudioStreamPlayer = _active_music
	_fade_tw = create_tween()
	_fade_tw.tween_property(player, "volume_db", -40.0, fade_dur).set_trans(Tween.TRANS_SINE)
	_fade_tw.tween_callback(player.stop)


func fade_music(target_db: float, duration: float) -> void:
	if not _active_music.playing:
		return
	_kill_music_tweens()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_active_music, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func restore_music(duration: float = 0.6) -> void:
	if not _active_music.playing:
		return
	var target_db: float = _music_vol_db()
	_kill_music_tweens()
	_fade_tw = create_tween()
	_fade_tw.tween_property(_active_music, "volume_db", target_db, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func set_corruption_layer(level: int) -> void:
	_corruption_level = level
	var target_db: float = -8.0 + float(level) * 3.0
	var bus_idx: int = AudioServer.get_bus_index(&"Ambience")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, target_db)


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(StringName(bus_name))
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
	match bus_name:
		"Master": master_vol = linear
		"Music": music_vol = linear
		"SFX": sfx_vol = linear
	_save_prefs()


func _music_vol_db() -> float:
	return linear_to_db(maxf(music_vol, 0.001)) - 6.0


func _apply_volumes() -> void:
	set_bus_volume("Master", master_vol)
	set_bus_volume("Music", music_vol)
	set_bus_volume("SFX", sfx_vol)


func _load_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		master_vol = float(cfg.get_value("audio", "master", 0.8))
		music_vol = float(cfg.get_value("audio", "music", 0.6))
		sfx_vol = float(cfg.get_value("audio", "sfx", 0.45))


func _save_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value("audio", "master", master_vol)
	cfg.set_value("audio", "music", music_vol)
	cfg.set_value("audio", "sfx", sfx_vol)
	cfg.save(PREFS_PATH)
