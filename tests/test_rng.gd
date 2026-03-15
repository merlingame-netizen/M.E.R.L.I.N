extends RefCounted
## Unit Tests — MerlinRng
## Tests: determinism, range bounds, distribution, pick.

const Rng = preload("res://scripts/merlin/merlin_rng.gd")


func _make_rng(seed_val: int = 42) -> RefCounted:
	var r: RefCounted = Rng.new()
	r.set_seed(seed_val)
	return r


# ═══════════════════════════════════════════════════════════════════════════════
# DETERMINISM
# ═══════════════════════════════════════════════════════════════════════════════

func test_same_seed_same_sequence() -> bool:
	var r1: RefCounted = _make_rng(42)
	var r2: RefCounted = _make_rng(42)
	for i in range(100):
		var v1: float = r1.randf()
		var v2: float = r2.randf()
		if absf(v1 - v2) > 0.0001:
			push_error("Sequence diverged at step %d: %f vs %f" % [i, v1, v2])
			return false
	return true


func test_different_seeds_different_sequence() -> bool:
	var r1: RefCounted = _make_rng(42)
	var r2: RefCounted = _make_rng(99)
	var same_count: int = 0
	for i in range(20):
		if absf(r1.randf() - r2.randf()) < 0.0001:
			same_count += 1
	if same_count > 5:
		push_error("Different seeds produced too many identical values: %d/20" % same_count)
		return false
	return true


func test_seed_stored_correctly() -> bool:
	var r: RefCounted = _make_rng(12345)
	if r.get_seed() != (12345 & 0x7fffffff):
		push_error("Seed not stored correctly")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RANGE BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_randf_in_0_1() -> bool:
	var r: RefCounted = _make_rng(7)
	for i in range(1000):
		var v: float = r.randf()
		if v < 0.0 or v > 1.0:
			push_error("randf() out of range [0,1]: %f at step %d" % [v, i])
			return false
	return true


func test_randf_range_bounds() -> bool:
	var r: RefCounted = _make_rng(13)
	for i in range(500):
		var v: float = r.randf_range(5.0, 10.0)
		if v < 5.0 or v > 10.0:
			push_error("randf_range(5,10) out of bounds: %f" % v)
			return false
	return true


func test_randi_range_bounds() -> bool:
	var r: RefCounted = _make_rng(21)
	for i in range(500):
		var v: int = r.randi_range(0, 5)
		if v < 0 or v > 5:
			push_error("randi_range(0,5) out of bounds: %d" % v)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DISTRIBUTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_rand_bool_roughly_fair() -> bool:
	var r: RefCounted = _make_rng(42)
	var trues: int = 0
	var total: int = 1000
	for i in range(total):
		if r.rand_bool(0.5):
			trues += 1
	var ratio: float = float(trues) / float(total)
	if ratio < 0.35 or ratio > 0.65:
		push_error("rand_bool(0.5) should be ~50%%, got %.1f%%" % [ratio * 100.0])
		return false
	return true


func test_rand_bool_always_true() -> bool:
	var r: RefCounted = _make_rng(1)
	for i in range(100):
		if not r.rand_bool(1.0):
			push_error("rand_bool(1.0) should always be true")
			return false
	return true


func test_rand_bool_always_false() -> bool:
	var r: RefCounted = _make_rng(1)
	for i in range(100):
		if r.rand_bool(0.0):
			push_error("rand_bool(0.0) should always be false")
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PICK
# ═══════════════════════════════════════════════════════════════════════════════

func test_pick_from_list() -> bool:
	var r: RefCounted = _make_rng(42)
	var list: Array = ["a", "b", "c", "d"]
	for i in range(50):
		var val: Variant = r.pick(list)
		if val == null or not list.has(val):
			push_error("pick() returned invalid value: %s" % str(val))
			return false
	return true


func test_pick_from_empty() -> bool:
	var r: RefCounted = _make_rng(42)
	var val: Variant = r.pick([])
	if val != null:
		push_error("pick([]) should return null, got %s" % str(val))
		return false
	return true
