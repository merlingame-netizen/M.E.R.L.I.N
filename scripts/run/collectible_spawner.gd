## ═══════════════════════════════════════════════════════════════════════════════
## Collectible Spawner — 3D event spawning during on-rails walk
## ═══════════════════════════════════════════════════════════════════════════════
## Phase 6 (DEV_PLAN_V2.5). Spawns collectibles at regular intervals via
## weighted random: currency, ogham_fragment, lore_inscription, healing_spring,
## spirit_echo, plus legacy events (plant, trap, rune, spirit, anam_rare).
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name CollectibleSpawner

signal collectible_spawned(type: String, position: Vector3)
signal collectible_picked(type: String, amount: int)
signal lore_discovered(inscription_id: String)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

const CURRENCY_INTERVAL_MIN: float = 3.0
const CURRENCY_INTERVAL_MAX: float = 5.0
const CURRENCY_AMOUNT_MIN: int = 1
const CURRENCY_AMOUNT_MAX: int = 2
const PICKUP_WINDOW: float = 1.5

const EVENT_CHANCE_PER_INTERVAL: float = 0.15
const EVENT_TYPES: Array[String] = ["plant", "trap", "rune", "spirit", "anam_rare"]
const EVENT_AMOUNTS: Dictionary = {
	"plant": 3,
	"trap": -5,
	"rune": 0,
	"spirit": 0,
	"anam_rare": 5,
}

# Weighted spawn table — weights must sum to 100
const SPAWN_WEIGHTS: Array[Dictionary] = [
	{"type": "currency",          "weight": 60},
	{"type": "lore_inscription",  "weight": 15},
	{"type": "spirit_echo",       "weight": 12},
	{"type": "healing_spring",    "weight": 8},
	{"type": "ogham_fragment",    "weight": 5},
]

const COLLECTIBLE_AMOUNTS: Dictionary = {
	"ogham_fragment": 5,     # +5 Anam
	"lore_inscription": 0,   # cosmetic — no numeric effect
	"healing_spring": 5,     # +5 life
	"spirit_echo": 1,        # +1 random faction rep
}

const FACTIONS: Array[String] = ["druides", "bardes", "guerriers", "artisans", "navigateurs"]

const LORE_POOL: Array[String] = [
	"inscription_beith", "inscription_luis", "inscription_fearn",
	"inscription_saille", "inscription_nion", "inscription_huath",
	"inscription_duir", "inscription_tinne", "inscription_coll",
	"inscription_quert", "inscription_muin", "inscription_gort",
]

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _spawning: bool = false
var _timer: float = 0.0
var _next_spawn: float = 0.0
var _run_state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _active_collectibles: Array = []


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func start_spawning(run_state: Dictionary) -> void:
	_run_state = run_state
	_spawning = true
	_timer = 0.0
	_next_spawn = _random_interval()
	_active_collectibles.clear()
	_rng.randomize()


func stop_spawning() -> void:
	_spawning = false
	_active_collectibles.clear()


func process_tick(delta: float) -> void:
	if not _spawning:
		return

	_timer += delta

	# Expire old collectibles
	_expire_collectibles(delta)

	# Spawn check
	if _timer >= _next_spawn:
		_timer = 0.0
		_next_spawn = _random_interval()
		_spawn_currency()

		# Chance for special event
		if _rng.randf() < EVENT_CHANCE_PER_INTERVAL:
			_spawn_event()


# ═══════════════════════════════════════════════════════════════════════════════
# SPAWNING
# ═══════════════════════════════════════════════════════════════════════════════

func spawn_currency(_frequency_range: Vector2 = Vector2(CURRENCY_INTERVAL_MIN, CURRENCY_INTERVAL_MAX)) -> void:
	_spawn_currency()


func spawn_event(type: String) -> void:
	if not EVENT_TYPES.has(type):
		push_warning("[Spawner] Unknown event type: %s" % type)
		return
	_create_collectible(type, int(EVENT_AMOUNTS.get(type, 0)))


func _spawn_currency() -> void:
	var amount: int = _rng.randi_range(CURRENCY_AMOUNT_MIN, CURRENCY_AMOUNT_MAX)
	_create_collectible("currency", amount)


func _spawn_event() -> void:
	var idx: int = _rng.randi_range(0, EVENT_TYPES.size() - 1)
	var type: String = EVENT_TYPES[idx]
	var amount: int = int(EVENT_AMOUNTS.get(type, 0))
	_create_collectible(type, amount)


func _create_collectible(type: String, amount: int) -> void:
	# Spawn position offset from player path (random lateral)
	var pos: Vector3 = Vector3(
		_rng.randf_range(-3.0, 3.0),
		0.0,
		_rng.randf_range(8.0, 15.0)
	)

	var collectible: Dictionary = {
		"type": type,
		"amount": amount,
		"position": pos,
		"lifetime": PICKUP_WINDOW,
		"picked": false,
	}
	_active_collectibles.append(collectible)
	collectible_spawned.emit(type, pos)


# ═══════════════════════════════════════════════════════════════════════════════
# PICKUP AND EXPIRY
# ═══════════════════════════════════════════════════════════════════════════════

func try_pickup(player_position: Vector3, pickup_radius: float = 2.0) -> Dictionary:
	for collectible in _active_collectibles:
		if collectible.get("picked", false):
			continue
		var cpos: Vector3 = collectible.get("position", Vector3.ZERO)
		if player_position.distance_to(cpos) <= pickup_radius:
			collectible["picked"] = true
			var type: String = str(collectible.get("type", ""))
			var amount: int = int(collectible.get("amount", 0))
			collectible_picked.emit(type, amount)
			return {"picked": true, "type": type, "amount": amount}
	return {"picked": false}


func _expire_collectibles(delta: float) -> void:
	var remaining: Array = []
	for collectible in _active_collectibles:
		var lifetime: float = float(collectible.get("lifetime", 0.0)) - delta
		if lifetime > 0.0 and not collectible.get("picked", false):
			collectible["lifetime"] = lifetime
			remaining.append(collectible)
	_active_collectibles = remaining


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _random_interval() -> float:
	return _rng.randf_range(CURRENCY_INTERVAL_MIN, CURRENCY_INTERVAL_MAX)


func get_active_count() -> int:
	return _active_collectibles.size()
