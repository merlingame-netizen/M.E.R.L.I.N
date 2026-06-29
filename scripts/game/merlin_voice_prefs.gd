class_name MerlinVoicePrefs
extends RefCounted
## Préférence VOIX de Merlin (bulles au menu) — `user://options.cfg` section [voice], clé `enabled`.
## Statique, idiome ConfigFile (cf. merlin_visual.load_prefs). Lu par MerlinMenuVoice, écrit par
## MerlinOptions. Défaut = activé. (user 2026-06-29)

const PREFS_PATH: String = "user://options.cfg"
const SECTION: String = "voice"


static func is_enabled() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		return bool(cfg.get_value(SECTION, "enabled", true))
	return true


static func set_enabled(on: bool) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)  # préserve les autres sections (audio/a11y/chronique)
	cfg.set_value(SECTION, "enabled", on)
	cfg.save(PREFS_PATH)
