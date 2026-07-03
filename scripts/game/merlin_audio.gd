extends Node
## MerlinAudio — autoload central (BIBLE §22, R117).

const SFX_DIR: String = "res://audio/sfx/"
const SFX_IDS: Array = [
	"card_pick", "card_play", "card_discard", "deal", "button_tap",
	"gauge_up", "gauge_down", "corruption_tick", "seal_stamp",
	"beat_turn", "draft_reveal", "whisper_threshold",
	"stinger_echec", "stinger_partiel", "stinger_reussite", "stinger_eclatante",
	"quill_tick", "ink_wash", "voice_blip",
]
const VOICE_POOL: int = 4
const POOL_SIZE: int = 8
const SFX_MIN_GAP_MS: int = 40   # anti-superposition : intervalle mini avant de rejouer un MÊME SFX
const DUCK_DB: float = -6.0
const DUCK_RETURN: float = 0.8
const PREFS_PATH: String = "user://options.cfg"

const STEM_BUS: StringName = &"Stems"
const STEM_FADE_DUR: float = 0.6
const STEM_SILENT_DB: float = -40.0

var _sfx_cache: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _duck_tw: Tween = null
var _fade_tw: Tween = null
var _corruption_level: int = 0

var _stem_players: Dictionary = {}
var _stem_tweens: Dictionary = {}
var _stem_active_mood: String = ""

var stem_moods: Dictionary = {
	"calm":    { "vocals": 0.3, "drums": 0.2, "bass": 0.4, "guitar": 0.6, "piano": 0.8, "other": 0.3 },
	"tension": { "vocals": 0.1, "drums": 0.5, "bass": 0.7, "guitar": 0.4, "piano": 0.3, "other": 0.8 },
	"resolve": { "vocals": 0.5, "drums": 0.8, "bass": 0.9, "guitar": 0.6, "piano": 0.4, "other": 0.2 },
	"corrupt": { "vocals": 0.1, "drums": 0.3, "bass": 0.6, "guitar": 0.2, "piano": 0.1, "other": 1.0 },
	"victory": { "vocals": 0.8, "drums": 0.7, "bass": 0.5, "guitar": 0.9, "piano": 1.0, "other": 0.2 },
}

var master_vol: float = 0.8
var music_vol: float = 0.6
var sfx_vol: float = 0.45
var voice_vol: float = 0.7   # v10.20 — volume de la voix procédurale de Merlin (R124)

var _voice_pool: Array[AudioStreamPlayer] = []
var _voice_idx: int = 0
var _sfx_last_ms: Dictionary = {}   # id → dernier ms de lecture (anti-double-fire)
var _voice_session: int = 0         # voix UNIQUE : seul le dernier locuteur sonne (anti-superposition)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_prefs()
	_preload_sfx()
	_create_pool()
	_create_voice_pool()
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
	# v10.20 — anti-superposition (user 2026-06-29) : un MÊME SFX ne se relance pas dans les SFX_MIN_GAP_MS
	# (évite les double-déclenchements quasi simultanés qui s'empilent). N'affecte pas la voix (play_voice).
	var now: int = Time.get_ticks_msec()
	if now - int(_sfx_last_ms.get(id, -10000)) < SFX_MIN_GAP_MS:
		return
	_sfx_last_ms[id] = now
	var p: AudioStreamPlayer = _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % POOL_SIZE
	if p.playing:
		p.stop()
	p.stream = _sfx_cache[id]
	p.pitch_scale = pitch_scale
	p.volume_db = 0.0
	p.play()


func _create_voice_pool() -> void:
	for i in VOICE_POOL:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"SFX"  # suit le bus SFX (donc master + sfx) ; voice_vol module en plus
		add_child(p)
		_voice_pool.append(p)


# v10.20 — Voix procédurale de Merlin : un blip par ~2 lettres, pitch = humeur (depuis MerlinSpeechBubble).
func play_voice(pitch_scale: float = 1.0) -> void:
	if voice_vol <= 0.01 or not _sfx_cache.has("voice_blip") or _voice_pool.is_empty():
		return
	var p: AudioStreamPlayer = _voice_pool[_voice_idx]
	_voice_idx = (_voice_idx + 1) % VOICE_POOL
	if p.playing:
		p.stop()
	p.stream = _sfx_cache["voice_blip"]
	p.pitch_scale = pitch_scale
	p.volume_db = linear_to_db(maxf(voice_vol, 0.001)) - 4.0  # voix feutrée (≠ SFX d'action)
	p.play()


func set_voice_vol(linear: float) -> void:
	voice_vol = clampf(linear, 0.0, 1.0)
	_save_prefs()


# Voix avec pitch dérivé de l'HUMEUR — source UNIQUE (bulle menu + prose in-game + intro + épilogue).
# user 2026-06-29 : « dans TOUTES les scenes où il parle il faut ce son ».
func play_voice_mood(mood: String = "neutral") -> void:
	var base: float = 0.95
	match mood:
		"surprise": base = 1.18
		"angry": base = 0.82
	play_voice(base * randf_range(0.94, 1.06))


# VOIX UNIQUE (user 2026-06-29 : « rien ne se superpose inutilement ») : un locuteur ouvre une session
# avant de parler ; quand un nouveau locuteur ouvre la sienne, les anciens deviennent muets. Garantit
# qu'UNE seule voix de Merlin sonne à la fois (jamais deux typewriters/bulles superposés).
func begin_voice() -> int:
	_voice_session += 1
	return _voice_session


func play_voice_session(session: int, mood: String = "neutral") -> void:
	if session != _voice_session:
		return  # un locuteur plus récent a pris la main → on ne superpose pas
	play_voice_mood(mood)


func play_stinger(degree: String) -> void:
	var id: String = "stinger_" + degree
	play_sfx("seal_stamp")
	play_sfx(id, 1.0)
	_duck_music()
	duck_stems()


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


# === v10.21 Wave A — NAPPE du pilier PNJ : canal UNIQUE (un seul pad à la fois, jamais superposé),
# fade-in 1.2s / fade-out 0.8s, bas volume (sous la musique). Boucle forcée sur l'AudioStreamWAV.
const PAD_DIR: String = "res://music/gameplay/"
const PAD_VOL_DB: float = -16.0
var _pad_player: AudioStreamPlayer = null
var _pad_id: String = ""
var _pad_tw: Tween = null


func play_pad(id: String) -> void:
	if id == _pad_id:
		return  # même nappe déjà en cours (anti-superposition, user 2026-06-29)
	var path: String = PAD_DIR + id + ".wav"
	if not ResourceLoader.exists(path):
		return
	if _pad_player == null:
		_pad_player = AudioStreamPlayer.new()
		_pad_player.bus = &"Music"
		add_child(_pad_player)
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_end = int((stream as AudioStreamWAV).data.size() / 2)  # frames 16-bit mono
	_pad_id = id
	if _pad_tw != null and _pad_tw.is_valid():
		_pad_tw.kill()
	_pad_player.stream = stream
	_pad_player.volume_db = -40.0
	_pad_player.play()
	_pad_tw = create_tween()
	_pad_tw.tween_property(_pad_player, "volume_db", PAD_VOL_DB, 1.2)


func stop_pad() -> void:
	if _pad_player == null or _pad_id == "":
		return
	_pad_id = ""
	if _pad_tw != null and _pad_tw.is_valid():
		_pad_tw.kill()
	_pad_tw = create_tween()
	_pad_tw.tween_property(_pad_player, "volume_db", -40.0, 0.8)
	_pad_tw.tween_callback(_pad_player.stop)


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
		voice_vol = float(cfg.get_value("audio", "voice", 0.7))


func _save_prefs() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value("audio", "master", master_vol)
	cfg.set_value("audio", "music", music_vol)
	cfg.set_value("audio", "sfx", sfx_vol)
	cfg.set_value("audio", "voice", voice_vol)
	cfg.save(PREFS_PATH)


# --- STEMS ADAPTIVE (Suno/Demucs pipeline) ---

func load_stems(folder: String) -> void:
	stop_stems_immediate()
	var dir := DirAccess.open(folder)
	if dir == null:
		push_warning("MerlinAudio: stems folder not found: " + folder)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and (fname.ends_with(".ogg") or fname.ends_with(".wav") or fname.ends_with(".mp3")):
			var stem_name := fname.get_basename()
			var player := AudioStreamPlayer.new()
			player.bus = STEM_BUS
			player.stream = load(folder.path_join(fname))
			player.volume_db = STEM_SILENT_DB
			add_child(player)
			_stem_players[stem_name] = player
		fname = dir.get_next()


func play_stems(mood: String = "calm") -> void:
	for player: AudioStreamPlayer in _stem_players.values():
		if not player.playing:
			player.play()
	set_stem_mood(mood)


func set_stem_mood(mood: String, fade_dur: float = STEM_FADE_DUR) -> void:
	if not stem_moods.has(mood):
		push_warning("MerlinAudio: unknown stem mood: " + mood)
		return
	_stem_active_mood = mood
	var levels: Dictionary = stem_moods[mood]
	for stem_name: String in _stem_players:
		var player: AudioStreamPlayer = _stem_players[stem_name]
		var target_linear: float = levels.get(stem_name, 0.0)
		var target_db: float = linear_to_db(maxf(target_linear, 0.001))
		if _stem_tweens.has(stem_name):
			var tw: Tween = _stem_tweens[stem_name]
			if tw != null and tw.is_valid():
				tw.kill()
		var tw := create_tween()
		tw.tween_property(player, "volume_db", target_db, fade_dur) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_stem_tweens[stem_name] = tw


func stop_stems(fade_dur: float = 0.5) -> void:
	for stem_name: String in _stem_players:
		var player: AudioStreamPlayer = _stem_players[stem_name]
		if player.playing:
			var tw := create_tween()
			tw.tween_property(player, "volume_db", STEM_SILENT_DB, fade_dur)
			tw.tween_callback(player.stop)
	_stem_active_mood = ""


func stop_stems_immediate() -> void:
	for stem_name: String in _stem_tweens:
		var tw: Tween = _stem_tweens[stem_name]
		if tw != null and tw.is_valid():
			tw.kill()
	_stem_tweens.clear()
	for player: AudioStreamPlayer in _stem_players.values():
		player.stop()
		player.queue_free()
	_stem_players.clear()
	_stem_active_mood = ""


func get_stem_mood() -> String:
	return _stem_active_mood


func is_stems_playing() -> bool:
	for player: AudioStreamPlayer in _stem_players.values():
		if player.playing:
			return true
	return false


func duck_stems() -> void:
	if _stem_players.is_empty():
		return
	for player: AudioStreamPlayer in _stem_players.values():
		if player.playing and player.volume_db > STEM_SILENT_DB:
			var tw := create_tween()
			tw.tween_property(player, "volume_db", player.volume_db + DUCK_DB, 0.05) \
				.set_trans(Tween.TRANS_QUAD)
			tw.tween_property(player, "volume_db", player.volume_db, DUCK_RETURN) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
