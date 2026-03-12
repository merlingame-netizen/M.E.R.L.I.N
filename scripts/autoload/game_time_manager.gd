extends Node
## GameTimeManager — Singleton global cycle jour/nuit et saisons.
## Lit l'heure et la date système toutes les 5 minutes via Timer.
## Émet period_changed et season_changed lors des transitions.

# ─── Signals ────────────────────────────────────────────────────────────────
signal period_changed(new_period: String)   # "aube" | "jour" | "crepuscule" | "nuit"
signal season_changed(new_season: String)   # "hiver" | "printemps" | "ete" | "automne"

# ─── Constants ──────────────────────────────────────────────────────────────
const UPDATE_INTERVAL_SECONDS: float = 300.0  # 5 minutes

# Period hour boundaries (inclusive start, exclusive end)
const PERIOD_AUBE_START: int = 5
const PERIOD_JOUR_START: int = 8
const PERIOD_CREPUSCULE_START: int = 18
const PERIOD_NUIT_START: int = 21

# Reputation bonuses by period/season (as float multiplier, 0.0 = no bonus)
const BONUS_AUBE_DRUIDES: float = 0.10
const BONUS_CREPUSCULE_KORRIGANS: float = 0.10
const BONUS_NUIT_ANKOU: float = 0.15
const BONUS_HIVER_NIAMH: float = 0.20
const BONUS_PRINTEMPS_DRUIDES: float = 0.20
const BONUS_ETE_ANCIENS: float = 0.20
const BONUS_AUTOMNE_ANKOU: float = 0.30

# Festival months: Imbolc=Feb(2), Beltane=May(5), Lughnasadh=Aug(8), Samhain=Oct(10)
const FESTIVAL_MONTHS: Dictionary = {
	2: "Imbolc",
	5: "Beltane",
	8: "Lughnasadh",
	10: "Samhain",
}

# ─── Private state ───────────────────────────────────────────────────────────
var _current_period: String = "jour"
var _current_season: String = "printemps"
var _current_hour: int = 12
var _current_month: int = 3
var _timer: Timer


# ─── Lifecycle ───────────────────────────────────────────────────────────────
func _ready() -> void:
	_update_from_system()
	_timer = Timer.new()
	_timer.wait_time = UPDATE_INTERVAL_SECONDS
	_timer.autostart = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


# ─── Timer callback ──────────────────────────────────────────────────────────
func _on_timer_timeout() -> void:
	_update_from_system()


# ─── Public API ──────────────────────────────────────────────────────────────
func get_period() -> String:
	return _current_period


func get_season() -> String:
	return _current_season


func get_festival() -> String:
	return FESTIVAL_MONTHS.get(_current_month, "")


func get_time_context() -> Dictionary:
	return {
		"period": _current_period,
		"season": _current_season,
		"festival": get_festival(),
		"hour": _current_hour,
		"reputation_bonus": _build_reputation_bonus(),
	}


# ─── Private helpers ─────────────────────────────────────────────────────────
func _update_from_system() -> void:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var new_hour: int = int(dt.get("hour", 12))
	var new_month: int = int(dt.get("month", 3))

	var new_period: String = _period_from_hour(new_hour)
	var new_season: String = _season_from_month(new_month)

	_current_hour = new_hour
	_current_month = new_month

	if new_period != _current_period:
		_current_period = new_period
		period_changed.emit(_current_period)

	if new_season != _current_season:
		_current_season = new_season
		season_changed.emit(_current_season)


func _period_from_hour(hour: int) -> String:
	if hour >= PERIOD_AUBE_START and hour < PERIOD_JOUR_START:
		return "aube"
	elif hour >= PERIOD_JOUR_START and hour < PERIOD_CREPUSCULE_START:
		return "jour"
	elif hour >= PERIOD_CREPUSCULE_START and hour < PERIOD_NUIT_START:
		return "crepuscule"
	else:
		return "nuit"


func _season_from_month(month: int) -> String:
	if month >= 12 or month <= 2:
		return "hiver"
	elif month >= 3 and month <= 5:
		return "printemps"
	elif month >= 6 and month <= 8:
		return "ete"
	else:
		return "automne"


func _build_reputation_bonus() -> Dictionary:
	var bonus: Dictionary = {
		"druides": 0.0,
		"anciens": 0.0,
		"korrigans": 0.0,
		"niamh": 0.0,
		"ankou": 0.0,
	}

	# Period bonuses
	match _current_period:
		"aube":
			bonus["druides"] = BONUS_AUBE_DRUIDES
		"crepuscule":
			bonus["korrigans"] = BONUS_CREPUSCULE_KORRIGANS
		"nuit":
			bonus["ankou"] = BONUS_NUIT_ANKOU

	# Season bonuses (additive with period)
	match _current_season:
		"hiver":
			bonus["niamh"] = bonus["niamh"] + BONUS_HIVER_NIAMH
		"printemps":
			bonus["druides"] = bonus["druides"] + BONUS_PRINTEMPS_DRUIDES
		"ete":
			bonus["anciens"] = bonus["anciens"] + BONUS_ETE_ANCIENS
		"automne":
			bonus["ankou"] = bonus["ankou"] + BONUS_AUTOMNE_ANKOU

	return bonus
