class_name MerlinChronicle
extends RefCounted
## MerlinChronicle — mémoire CROSS-RUN persistée (`user://options.cfg`, section [chronique]).
## Statique, idiome ConfigFile (cf. merlin_audio._load_prefs / merlin_visual.load_prefs).
## Alimente la VOIX du menu (Merlin commente la dernière fois qu'on s'est vus + son palmarès).
## R… (user 2026-06-29) : « commentaires sur la dernière fois qu'il nous a vu ».

const PREFS_PATH: String = "user://options.cfg"
const SECTION: String = "chronique"

# Schéma + valeurs par défaut (sert aussi de gabarit de lecture).
const DEFAULTS: Dictionary = {
	"runs_played": 0, "wins": 0, "deaths": 0, "corrupted": 0,
	"last_end_type": "", "last_scenario_title": "",
	"last_integrite": 0, "last_corruption": 0,
	"last_run_iso": "", "last_seen_iso": "",
}


# Enregistre la fin d'un run : +1 run, +1 au palmarès de l'issue, mémorise la dernière aventure.
static func record_end(end_type: String, scenario_title: String, integrite: int, corruption: int) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)  # préserve les autres sections (audio/a11y)
	cfg.set_value(SECTION, "runs_played", int(cfg.get_value(SECTION, "runs_played", 0)) + 1)
	var key: String = ""
	match end_type:
		"accomplissement": key = "wins"
		"mort": key = "deaths"
		"corrompu": key = "corrupted"
	if key != "":
		cfg.set_value(SECTION, key, int(cfg.get_value(SECTION, key, 0)) + 1)
	cfg.set_value(SECTION, "last_end_type", end_type)
	cfg.set_value(SECTION, "last_scenario_title", scenario_title)
	cfg.set_value(SECTION, "last_integrite", integrite)
	cfg.set_value(SECTION, "last_corruption", corruption)
	cfg.set_value(SECTION, "last_run_iso", Time.get_datetime_string_from_system())
	cfg.save(PREFS_PATH)


# Horodate la VISITE courante (« la dernière fois qu'il nous a vus »). À appeler APRÈS read().
static func touch_seen() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value(SECTION, "last_seen_iso", Time.get_datetime_string_from_system())
	cfg.save(PREFS_PATH)


# Lit toute la chronique + calcule `days_since_seen` (jours entiers depuis la dernière visite, -1 si inconnu).
static func read() -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var out: Dictionary = DEFAULTS.duplicate(true)
	if cfg.load(PREFS_PATH) == OK:
		for k in DEFAULTS.keys():
			out[k] = cfg.get_value(SECTION, k, DEFAULTS[k])
	out["days_since_seen"] = _days_since(str(out.get("last_seen_iso", "")))
	return out


# Jours entiers écoulés depuis un timestamp ISO (-1 si vide/illisible, 0 si futur/aujourd'hui).
static func _days_since(iso: String) -> int:
	if iso.strip_edges().is_empty():
		return -1
	var then: int = int(Time.get_unix_time_from_datetime_string(iso))
	if then <= 0:
		return -1
	var now: int = int(Time.get_unix_time_from_system())
	var diff: int = now - then
	if diff <= 0:
		return 0
	return int(diff / 86400.0)
