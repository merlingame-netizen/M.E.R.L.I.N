class_name MerlinChronicle
extends RefCounted
## MerlinChronicle — mémoire CROSS-RUN persistée (`user://options.cfg`, section [chronique]).
## Statique, idiome ConfigFile (cf. merlin_audio._load_prefs / merlin_visual.load_prefs).
## Alimente la VOIX du menu (Merlin commente la dernière fois qu'on s'est vus + son palmarès).
## R… (user 2026-06-29) : « commentaires sur la dernière fois qu'il nous a vu ».

const PREFS_PATH: String = "user://options.cfg"
const SECTION: String = "chronique"
# P2 (chantier 4, design F4 / CDC-GD-02) : total canonique d'eclats du Graal (denominateur N/12
# affiche a MerlinEnd + CHRONIQUES : ancre le but, sert l'argument de re-run). Purement descriptif.
const GRAAL_TOTAL: int = 12

# Schéma + valeurs par défaut (sert aussi de gabarit de lecture).
const DEFAULTS: Dictionary = {
	"runs_played": 0, "wins": 0, "deaths": 0, "corrupted": 0,
	"last_end_type": "", "last_scenario_title": "",
	"last_integrite": 0, "last_corruption": 0,
	"last_run_iso": "", "last_seen_iso": "",
	# v10.20.2 — mémoire de la dernière run pour la RÉCURRENCE des PNJ (le pilier te reconnaît) + l'allusion menu.
	"last_faction": "", "last_pilier": "",
	# P2 (2026-07-11, chantier 4) : 1er cran de meta NON-restrictif. graal_fragments = eclats du Graal
	# ramenes (+1 par fin accomplissement, cumule cross-run) ; last_voie = derniere Voie de la Carte
	# Destin (palmares CHRONIQUES). Additifs : les cfg anterieurs lisent les defauts (aucune migration).
	"graal_fragments": 0, "last_voie": "",
	# N4-TUTO (2026-07-11) : le GUIDE de première traversée. Proposé UNE fois (chronique vierge),
	# jamais relancé seul ; rejouable via Options (tuto_rearmed). Additif : les cfg antérieurs
	# lisent les défauts (aucune migration).
	"tuto_proposed": false, "tuto_done": false, "tuto_rearmed": false,
	# v43 — LE CARNET : les trois dernières traversées, en JSON. C'est la SEULE
	# source d'un passé pour le récit (bible §6 R166 : « échos des anciens runs »).
	"carnet": "",
}


# Enregistre la fin d'un run : +1 run, +1 au palmarès de l'issue, mémorise la dernière aventure + son PNJ.
static func record_end(end_type: String, scenario_title: String, integrite: int, corruption: int, faction: String = "", pilier: String = "", voie: String = "", entree: Dictionary = {}) -> void:
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
	cfg.set_value(SECTION, "last_faction", faction)
	cfg.set_value(SECTION, "last_pilier", pilier)
	# P2 (chantier 4a) : 1 eclat du Graal par fin accomplissement (cumul cross-run, additif).
	if end_type == "accomplissement":
		cfg.set_value(SECTION, "graal_fragments", int(cfg.get_value(SECTION, "graal_fragments", 0)) + 1)
	if voie != "":
		cfg.set_value(SECTION, "last_voie", voie)
	cfg.set_value(SECTION, "last_run_iso", Time.get_datetime_string_from_system())
	# v43 — LE CARNET : cette traversée rejoint les deux précédentes. Trois suffisent :
	# le récit doit pouvoir s'y référer, pas réciter une biographie.
	if not entree.is_empty():
		var pages: Array = carnet_lire()
		pages.push_front(entree)
		while pages.size() > 3:
			pages.pop_back()
		cfg.set_value(SECTION, "carnet", JSON.stringify(pages))
	cfg.save(PREFS_PATH)


# v43 — Le carnet, relu par le récit. Jamais d'exception : un carnet illisible
# vaut un carnet vide, et un carnet vide veut dire « première venue ».
static func carnet_lire() -> Array:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)
	var brut: String = str(cfg.get_value(SECTION, "carnet", ""))
	if brut.strip_edges() == "":
		return []
	var v: Variant = JSON.parse_string(brut)
	return (v as Array) if v is Array else []


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


# ── N4-TUTO : le guide de Merlin (première traversée) ─────────────────────────────────────────
# Contrat (revue design B2) : `tuto_proposed` est la condition PRIMAIRE (persistée en SYNCHRONE au
# clic de réponse, AVANT le lancement du guide) ; `runs_played == 0` n'est qu'un garde-fou
# secondaire. Un « Guide-moi » suivi d'un quit/crash ne re-propose donc JAMAIS tout seul.


# Faut-il proposer le guide ? Vague A (A4, 2026-07-12) : le guide est proposé à CHAQUE nouvelle
# partie (au beat 0), plus de one-shot sur `runs_played == 0`. Le ré-armement Options (« Revoir le
# guide ») reste honoré — redondant désormais, mais on n'ôte rien du contrat existant. Appelé
# UNIQUEMENT au beat 0 côté jeu (merlin_game._offer_tuto_or_begin) : jamais relancé en cours de partie.
static func should_offer_tuto() -> bool:
	return true


# Réponse donnée (accepté OU refusé) : consomme aussi le ré-armement Options.
static func mark_tuto_proposed() -> void:
	_set_tuto_flags({"tuto_proposed": true, "tuto_rearmed": false})


# Guide déroulé (complet ou écourté) : trace de chronique (matière pour la voix du menu).
static func mark_tuto_done() -> void:
	_set_tuto_flags({"tuto_done": true})


# Options « Revoir le guide de Merlin » : ré-arme la proposition pour la PROCHAINE run.
# Le guide ne se relance JAMAIS seul en cours de partie.
static func rearm_tuto() -> void:
	_set_tuto_flags({"tuto_rearmed": true})


static func _set_tuto_flags(flags: Dictionary) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PREFS_PATH)  # préserve les autres sections (audio/a11y/tuto hints)
	for k in flags.keys():
		cfg.set_value(SECTION, str(k), flags[k])
	cfg.save(PREFS_PATH)


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
