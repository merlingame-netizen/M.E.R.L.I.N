extends Node
## GameTimeManager — Global time manager providing normalized game time, seasons,
## moon phases, and Celtic festivals.
##
## Time is based on real system clock, mapped to game time.
## 1 real minute = 1 game hour (adjustable via time_scale).
## Reads system clock periodically, but also advances via _process for smooth
## normalized time progression.

# ─── Signals ────────────────────────────────────────────────────────────────
signal time_updated(normalized: float)
signal season_changed(season: String)
signal period_changed(new_period: String)

# ─── Time state ─────────────────────────────────────────────────────────────
## 0.0 = midnight, 0.5 = noon, 1.0 = next midnight
var current_time_normalized: float = 0.0

## Current season key: "printemps" | "ete" | "automne" | "hiver"
var current_season: String = "printemps"

## Current moon phase key
var moon_phase: String = "pleine"

## Active Celtic festival or "" if none
var active_festival: String = ""

## Game-time speed: 1.0 means 1 real minute = 1 game hour (24 game hours per 24 real minutes)
var time_scale: float = 1.0

# ─── Constants ──────────────────────────────────────────────────────────────
const SEASONS: Array[String] = ["printemps", "ete", "automne", "hiver"]

const MOON_PHASES: Array[String] = [
	"nouvelle",
	"croissant",
	"premier_quartier",
	"pleine",
	"dernier_quartier",
	"decroissant",
]

const CELTIC_FESTIVALS: Dictionary = {
	"samhain": {"season": "automne", "month": 10, "day": 31},
	"imbolc": {"season": "hiver", "month": 2, "day": 1},
	"beltane": {"season": "printemps", "month": 5, "day": 1},
	"lughnasadh": {"season": "ete", "month": 8, "day": 1},
}

## Period hour boundaries (24h, inclusive start)
const PERIOD_BOUNDARIES: Array[Dictionary] = [
	{"name": "nuit",        "start": 0},
	{"name": "aube",        "start": 5},
	{"name": "matin",       "start": 7},
	{"name": "midi",        "start": 11},
	{"name": "apres-midi",  "start": 14},
	{"name": "crepuscule",  "start": 18},
	{"name": "nuit",        "start": 21},
]

## Reputation bonuses by period/season (faction multipliers)
const BONUS_AUBE_DRUIDES: float = 0.10
const BONUS_CREPUSCULE_KORRIGANS: float = 0.10
const BONUS_NUIT_ANKOU: float = 0.15
const BONUS_HIVER_NIAMH: float = 0.20
const BONUS_PRINTEMPS_DRUIDES: float = 0.20
const BONUS_ETE_ANCIENS: float = 0.20
const BONUS_AUTOMNE_ANKOU: float = 0.30

## System clock re-sync interval
const SYNC_INTERVAL_SECONDS: float = 300.0

# ─── Private state ──────────────────────────────────────────────────────────
var _current_period: String = "jour"
var _current_hour: int = 12
var _current_month: int = 3
var _current_day: int = 15
var _sync_timer: Timer
var _moon_index: int = 3  # default = pleine


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_sync_from_system()
	_sync_timer = Timer.new()
	_sync_timer.wait_time = SYNC_INTERVAL_SECONDS
	_sync_timer.autostart = true
	_sync_timer.timeout.connect(_on_sync_timeout)
	add_child(_sync_timer)


func _process(delta: float) -> void:
	# Advance normalized time: 1 real minute = 1 game hour at time_scale=1.0
	# 1 game hour = 1/24 normalized. So per real second: (1/60) * (1/24) * time_scale
	var advance: float = delta * time_scale / (60.0 * 24.0)
	var old_normalized: float = current_time_normalized
	current_time_normalized = fmod(current_time_normalized + advance, 1.0)
	if current_time_normalized < 0.0:
		current_time_normalized += 1.0

	time_updated.emit(current_time_normalized)

	# Check if period changed based on game hour
	var game_hour: int = int(current_time_normalized * 24.0) % 24
	var new_period: String = _period_from_hour(game_hour)
	if new_period != _current_period:
		_current_period = new_period
		period_changed.emit(_current_period)

	# Detect midnight crossing for moon advance
	if old_normalized > 0.9 and current_time_normalized < 0.1:
		advance_moon()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func get_time_of_day() -> String:
	## Returns period name: "aube"/"matin"/"midi"/"apres-midi"/"crepuscule"/"nuit"
	return _current_period


func get_light_intensity() -> float:
	## Returns 0.0 (deep night) to 1.0 (noon), smooth sinusoidal curve.
	## Normalized time: 0.0 = midnight, 0.5 = noon.
	# Use a raised cosine: intensity = 0.5 * (1 - cos(2*PI*(t - 0.25)))
	# This gives 0 at t=0 (midnight), 1 at t=0.5 (noon)
	var t: float = current_time_normalized
	var raw: float = 0.5 * (1.0 - cos(TAU * t - PI))
	# Shift so midnight=0, noon=1: cos curve centered at 0.5
	# Actually: intensity = max(0, sin(PI * t)) gives 0 at 0 and 1, peak at 0.5
	# But sin(PI*0)=0, sin(PI*0.5)=1, sin(PI*1)=0 — perfect.
	var intensity: float = maxf(0.0, sin(PI * t))
	# Smooth clamp to avoid harsh transitions
	return clampf(intensity, 0.0, 1.0)


func set_season(new_season: String) -> void:
	## Manually set the season. Must be one of SEASONS.
	if new_season not in SEASONS:
		push_warning("[GameTimeManager] Invalid season: %s" % new_season)
		return
	if new_season == current_season:
		return
	current_season = new_season
	season_changed.emit(current_season)


func advance_moon() -> void:
	## Cycle to next moon phase.
	_moon_index = (_moon_index + 1) % MOON_PHASES.size()
	moon_phase = MOON_PHASES[_moon_index]


func check_festival() -> String:
	## Returns active Celtic festival name or "" if none.
	## Active = current system date matches festival date (+-1 day tolerance).
	for festival_id in CELTIC_FESTIVALS:
		var fest: Dictionary = CELTIC_FESTIVALS[festival_id]
		var fm: int = int(fest.get("month", 0))
		var fd: int = int(fest.get("day", 0))
		for offset in [-1, 0, 1]:
			var check_day: int = fd + offset
			var check_month: int = fm
			if check_day <= 0:
				check_month -= 1
				check_day = 28
			elif check_day > 31:
				check_month += 1
				check_day = 1
			if check_month == _current_month and check_day == _current_day:
				return festival_id
	return ""


func get_context_for_llm() -> Dictionary:
	## Returns a dictionary suitable for injection into LLM prompts.
	return {
		"time_of_day": get_time_of_day(),
		"time_normalized": current_time_normalized,
		"light_intensity": get_light_intensity(),
		"season": current_season,
		"moon_phase": moon_phase,
		"festival": active_festival,
		"reputation_bonus": _build_reputation_bonus(),
	}


func get_period() -> String:
	## Alias for get_time_of_day() — backward compatibility.
	return get_time_of_day()


func get_season() -> String:
	return current_season


func get_festival() -> String:
	return active_festival


func get_time_context() -> Dictionary:
	## Alias for get_context_for_llm() — backward compatibility.
	return get_context_for_llm()


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_sync_timeout() -> void:
	_sync_from_system()


func _sync_from_system() -> void:
	## Re-read system clock to anchor game time and update season/festival.
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	var new_hour: int = int(dt.get("hour", 12))
	var new_minute: int = int(dt.get("minute", 0))
	var new_month: int = int(dt.get("month", 3))
	var new_day: int = int(dt.get("day", 15))

	_current_hour = new_hour
	_current_month = new_month
	_current_day = new_day

	# Set normalized time from system clock
	current_time_normalized = (float(new_hour) + float(new_minute) / 60.0) / 24.0

	# Update season
	var new_season: String = _season_from_month(new_month)
	if new_season != current_season:
		current_season = new_season
		season_changed.emit(current_season)

	# Update period
	var new_period: String = _period_from_hour(new_hour)
	if new_period != _current_period:
		_current_period = new_period
		period_changed.emit(_current_period)

	# Update moon phase from real lunar cycle
	_moon_index = _moon_index_from_system(dt)
	moon_phase = MOON_PHASES[_moon_index]

	# Update festival
	active_festival = check_festival()


func _period_from_hour(hour: int) -> String:
	## Map hour (0-23) to period name using PERIOD_BOUNDARIES.
	var result: String = "nuit"
	for boundary in PERIOD_BOUNDARIES:
		if hour >= int(boundary["start"]):
			result = str(boundary["name"])
	return result


func _season_from_month(month: int) -> String:
	if month >= 12 or month <= 2:
		return "hiver"
	elif month >= 3 and month <= 5:
		return "printemps"
	elif month >= 6 and month <= 8:
		return "ete"
	else:
		return "automne"


func _moon_index_from_system(dt: Dictionary) -> int:
	## Calculate moon phase index from real date using synodic month (~29.53 days).
	## Reference: 2000-01-06 = new moon.
	var year: int = int(dt.get("year", 2026))
	var month: int = int(dt.get("month", 3))
	var day: int = int(dt.get("day", 15))
	var jd: int = _julian_day(year, month, day)
	var ref_jd: int = _julian_day(2000, 1, 6)
	var days_since: float = float(jd - ref_jd)
	var lunar_age: float = fmod(days_since, 29.53)
	if lunar_age < 0.0:
		lunar_age += 29.53
	# Map to 6 phases (our MOON_PHASES has 6 entries)
	var phase_idx: int = int(lunar_age / (29.53 / float(MOON_PHASES.size()))) % MOON_PHASES.size()
	return phase_idx


func _julian_day(y: int, m: int, d: int) -> int:
	@warning_ignore("integer_division")
	var a: int = (14 - m) / 12
	var yr: int = y + 4800 - a
	var mo: int = m + 12 * a - 3
	@warning_ignore("integer_division")
	return d + (153 * mo + 2) / 5 + 365 * yr + yr / 4 - yr / 100 + yr / 400 - 32045


func _build_reputation_bonus() -> Dictionary:
	var bonus: Dictionary = {
		"druides": 0.0,
		"anciens": 0.0,
		"korrigans": 0.0,
		"niamh": 0.0,
		"ankou": 0.0,
	}

	match _current_period:
		"aube":
			bonus["druides"] = BONUS_AUBE_DRUIDES
		"crepuscule":
			bonus["korrigans"] = BONUS_CREPUSCULE_KORRIGANS
		"nuit":
			bonus["ankou"] = BONUS_NUIT_ANKOU

	match current_season:
		"hiver":
			bonus["niamh"] = bonus["niamh"] + BONUS_HIVER_NIAMH
		"printemps":
			bonus["druides"] = bonus["druides"] + BONUS_PRINTEMPS_DRUIDES
		"ete":
			bonus["anciens"] = bonus["anciens"] + BONUS_ETE_ANCIENS
		"automne":
			bonus["ankou"] = bonus["ankou"] + BONUS_AUTOMNE_ANKOU

	return bonus
