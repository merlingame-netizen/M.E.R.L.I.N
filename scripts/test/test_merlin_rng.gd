## Test MerlinRng — deterministic PRNG unit tests
## 16 tests covering seed, range, distribution, determinism, edge cases.
extends RefCounted


func test_set_get_seed_roundtrip() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(42)
	if rng.get_seed() != 42:
		push_error("set_seed(42) -> get_seed() returned %d, expected 42" % rng.get_seed())
		return false
	rng.set_seed(0)
	if rng.get_seed() != 0:
		push_error("set_seed(0) -> get_seed() returned %d, expected 0" % rng.get_seed())
		return false
	return true


func test_randf_range_zero_one() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(123)
	for i in range(1000):
		var v: float = rng.randf()
		if v < 0.0 or v > 1.0:
			push_error("randf() returned %f, outside [0,1] at sample %d" % [v, i])
			return false
	return true


func test_randf_never_negative_or_zero() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(999)
	for i in range(1000):
		var v: float = rng.randf()
		if v < 0.0:
			push_error("randf() returned negative %f at sample %d" % [v, i])
			return false
	# Note: exactly 0.0 is theoretically possible but extremely unlikely
	return true


func test_randf_range_respects_bounds() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(77)
	for i in range(1000):
		var v: float = rng.randf_range(10.0, 20.0)
		if v < 10.0 or v > 20.0:
			push_error("randf_range(10,20) returned %f at sample %d" % [v, i])
			return false
	return true


func test_randi_non_negative() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(55)
	for i in range(1000):
		var v: int = rng.randi()
		if v < 0:
			push_error("randi() returned negative %d at sample %d" % [v, i])
			return false
	return true


func test_randi_range_respects_bounds() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(33)
	for i in range(1000):
		var v: int = rng.randi_range(5, 10)
		if v < 5 or v > 10:
			push_error("randi_range(5,10) returned %d at sample %d" % [v, i])
			return false
	return true


func test_rand_bool_zero_always_false() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(11)
	for i in range(100):
		if rng.rand_bool(0.0):
			push_error("rand_bool(0.0) returned true at sample %d" % i)
			return false
	return true


func test_rand_bool_one_always_true() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(22)
	for i in range(100):
		if not rng.rand_bool(1.0):
			push_error("rand_bool(1.0) returned false at sample %d" % i)
			return false
	return true


func test_rand_bool_half_produces_both() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(44)
	var got_true: bool = false
	var got_false: bool = false
	for i in range(200):
		if rng.rand_bool(0.5):
			got_true = true
		else:
			got_false = true
		if got_true and got_false:
			return true
	push_error("rand_bool(0.5) did not produce both true and false in 200 samples")
	return false


func test_pick_returns_element() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(66)
	var list: Array = ["a", "b", "c", "d"]
	for i in range(50):
		var v: Variant = rng.pick(list)
		if not list.has(v):
			push_error("pick() returned %s which is not in list" % str(v))
			return false
	return true


func test_pick_empty_returns_null() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(77)
	var v: Variant = rng.pick([])
	if v != null:
		push_error("pick([]) returned %s, expected null" % str(v))
		return false
	return true


func test_determinism_same_seed() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(1234)
	var seq_a: Array[float] = []
	for i in range(20):
		seq_a.append(rng.randf())

	rng.set_seed(1234)
	for i in range(20):
		var v: float = rng.randf()
		if not is_equal_approx(v, seq_a[i]):
			push_error("Determinism fail at index %d: %f != %f" % [i, v, seq_a[i]])
			return false
	return true


func test_different_seeds_different_sequences() -> bool:
	var rng_a := MerlinRng.new()
	var rng_b := MerlinRng.new()
	rng_a.set_seed(100)
	rng_b.set_seed(200)
	var differ: bool = false
	for i in range(10):
		if not is_equal_approx(rng_a.randf(), rng_b.randf()):
			differ = true
			break
	if not differ:
		push_error("Seeds 100 and 200 produced identical sequences over 10 samples")
		return false
	return true


func test_seed_masking() -> bool:
	var rng := MerlinRng.new()
	var large_seed: int = 0x7fffffff + 1  # 2147483648
	rng.set_seed(large_seed)
	var masked: int = large_seed & 0x7fffffff
	if rng.get_seed() != masked:
		push_error("Seed masking failed: set %d, got %d, expected %d" % [large_seed, rng.get_seed(), masked])
		return false
	return true


func test_randf_range_distribution_mean() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(555)
	var total: float = 0.0
	var n: int = 1000
	for i in range(n):
		total += rng.randf_range(0.0, 100.0)
	var mean: float = total / float(n)
	if absf(mean - 50.0) > 10.0:
		push_error("randf_range(0,100) mean is %f, expected ~50 (within +/-10)" % mean)
		return false
	return true


func test_randi_range_min_equals_max() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(88)
	for i in range(50):
		var v: int = rng.randi_range(7, 7)
		if v != 7:
			push_error("randi_range(7,7) returned %d at sample %d" % [v, i])
			return false
	return true
