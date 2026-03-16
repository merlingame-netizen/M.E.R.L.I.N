## ═══════════════════════════════════════════════════════════════════════════════
## Test MerlinRng — 25 deterministic PRNG unit tests
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: seed round-trip, masking, determinism, range bounds, distribution,
## randi, randi_range, rand_bool edge cases, pick edge cases.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error before false.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# SEED / GET_SEED
# ═══════════════════════════════════════════════════════════════════════════════

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


func test_seed_masking_strips_high_bit() -> bool:
	var rng := MerlinRng.new()
	# 0x7fffffff + 1 = 2147483648; after mask = 0
	var oversized: int = 0x7fffffff + 1
	rng.set_seed(oversized)
	var expected: int = oversized & 0x7fffffff
	if rng.get_seed() != expected:
		push_error("Seed masking: set %d, got %d, expected %d" % [oversized, rng.get_seed(), expected])
		return false
	return true


func test_seed_masking_max_valid_value() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(0x7fffffff)
	if rng.get_seed() != 0x7fffffff:
		push_error("set_seed(0x7fffffff) should store 0x7fffffff, got %d" % rng.get_seed())
		return false
	return true


func test_seed_zero_is_stored() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(0)
	if rng.get_seed() != 0:
		push_error("set_seed(0) stored %d, expected 0" % rng.get_seed())
		return false
	return true


func test_get_seed_advances_after_call() -> bool:
	# get_seed returns _state; _state advances after randf calls, not get_seed calls
	var rng := MerlinRng.new()
	rng.set_seed(100)
	var s1: int = rng.get_seed()
	var s2: int = rng.get_seed()
	if s1 != s2:
		push_error("get_seed() must be pure (no side effects): %d vs %d" % [s1, s2])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# randf
# ═══════════════════════════════════════════════════════════════════════════════

func test_randf_in_unit_interval() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(123)
	for i in range(1000):
		var v: float = rng.randf()
		if v < 0.0 or v > 1.0:
			push_error("randf() = %f outside [0,1] at sample %d" % [v, i])
			return false
	return true


func test_randf_advances_state() -> bool:
	# Two consecutive calls must not return the same value (overwhelmingly likely)
	var rng := MerlinRng.new()
	rng.set_seed(77)
	var v1: float = rng.randf()
	var v2: float = rng.randf()
	if is_equal_approx(v1, v2):
		push_error("randf() returned same value twice in a row: %f" % v1)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DETERMINISM
# ═══════════════════════════════════════════════════════════════════════════════

func test_determinism_same_seed_produces_same_sequence() -> bool:
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


func test_determinism_two_independent_instances() -> bool:
	var rng_a := MerlinRng.new()
	var rng_b := MerlinRng.new()
	rng_a.set_seed(9999)
	rng_b.set_seed(9999)
	for i in range(50):
		var va: float = rng_a.randf()
		var vb: float = rng_b.randf()
		if not is_equal_approx(va, vb):
			push_error("Two instances with same seed diverged at step %d: %f vs %f" % [i, va, vb])
			return false
	return true


func test_different_seeds_yield_different_sequences() -> bool:
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
		push_error("Seeds 100 and 200 produced identical 10-sample sequences")
		return false
	return true


func test_randi_range_produces_valid_values() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(555)
	for i in range(30):
		var v: int = rng.randi_range(0, 100)
		if v < 0 or v > 100:
			push_error("randi_range(0,100) produced %d at step %d" % [v, i])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# randf_range
# ═══════════════════════════════════════════════════════════════════════════════

func test_randf_range_respects_bounds() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(77)
	for i in range(1000):
		var v: float = rng.randf_range(10.0, 20.0)
		if v < 10.0 or v > 20.0:
			push_error("randf_range(10,20) = %f at sample %d" % [v, i])
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
	# Mean should be ~50; allow +/-10 with 1000 samples
	if absf(mean - 50.0) > 10.0:
		push_error("randf_range(0,100) mean=%f, expected ~50 (+-10)" % mean)
		return false
	return true


func test_randf_range_negative_values() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(321)
	for i in range(200):
		var v: float = rng.randf_range(-10.0, -1.0)
		if v < -10.0 or v > -1.0:
			push_error("randf_range(-10,-1) = %f at sample %d" % [v, i])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# randi
# ═══════════════════════════════════════════════════════════════════════════════

func test_randi_non_negative() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(55)
	for i in range(1000):
		var v: int = rng.randi()
		if v < 0:
			push_error("randi() = %d (negative) at sample %d" % [v, i])
			return false
	return true


func test_randi_bounded_by_int_max() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(88)
	# randi is int(randf() * 2147483647) so max is 2147483646
	for i in range(500):
		var v: int = rng.randi()
		if v > 2147483647:
			push_error("randi() = %d exceeds 2147483647 at sample %d" % [v, i])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# randi_range
# ═══════════════════════════════════════════════════════════════════════════════

func test_randi_range_respects_bounds() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(33)
	for i in range(1000):
		var v: int = rng.randi_range(5, 10)
		if v < 5 or v > 10:
			push_error("randi_range(5,10) = %d at sample %d" % [v, i])
			return false
	return true


func test_randi_range_min_equals_max() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(88)
	for i in range(50):
		var v: int = rng.randi_range(7, 7)
		if v != 7:
			push_error("randi_range(7,7) = %d at sample %d" % [v, i])
			return false
	return true


func test_randi_range_covers_all_values_in_range() -> bool:
	# With enough samples, every value in [0,4] should appear
	var rng := MerlinRng.new()
	rng.set_seed(42)
	var seen: Dictionary = {}
	for i in range(500):
		var v: int = rng.randi_range(0, 4)
		seen[v] = true
	for expected_val in range(5):
		if not seen.has(expected_val):
			push_error("randi_range(0,4) never produced %d in 500 samples" % expected_val)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# rand_bool
# ═══════════════════════════════════════════════════════════════════════════════

func test_rand_bool_one_always_true() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(22)
	for i in range(200):
		if not rng.rand_bool(1.0):
			push_error("rand_bool(1.0) returned false at sample %d" % i)
			return false
	return true


func test_rand_bool_half_produces_both_outcomes() -> bool:
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


func test_rand_bool_negative_chance_clamped_to_false() -> bool:
	# chance clamped to 0.0 — randf() > 0.0 almost always, so almost always false
	var rng := MerlinRng.new()
	rng.set_seed(11)
	var true_count: int = 0
	for i in range(200):
		if rng.rand_bool(-5.0):
			true_count += 1
	# Should behave as chance=0.0 (only true if randf()==0.0 exactly)
	if true_count > 5:
		push_error("rand_bool(-5.0) returned true %d times in 200 samples (expected ~0)" % true_count)
		return false
	return true


func test_rand_bool_above_one_clamped_to_always_true() -> bool:
	# chance clamped to 1.0 — always true
	var rng := MerlinRng.new()
	rng.set_seed(99)
	for i in range(200):
		if not rng.rand_bool(2.0):
			push_error("rand_bool(2.0) returned false at sample %d (should clamp to 1.0)" % i)
			return false
	return true


func test_rand_bool_default_is_half() -> bool:
	# Default chance=0.5, should produce both outcomes
	var rng := MerlinRng.new()
	rng.set_seed(314)
	var got_true: bool = false
	var got_false: bool = false
	for i in range(200):
		if rng.rand_bool():
			got_true = true
		else:
			got_false = true
		if got_true and got_false:
			return true
	push_error("rand_bool() default=0.5 did not produce both outcomes in 200 samples")
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# pick
# ═══════════════════════════════════════════════════════════════════════════════

func test_pick_empty_returns_null() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(77)
	var v: Variant = rng.pick([])
	if v != null:
		push_error("pick([]) returned %s, expected null" % str(v))
		return false
	return true


func test_pick_returns_element_from_list() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(66)
	var list: Array = ["a", "b", "c", "d"]
	for i in range(100):
		var v: Variant = rng.pick(list)
		if not list.has(v):
			push_error("pick() returned %s which is not in list at sample %d" % [str(v), i])
			return false
	return true


func test_pick_single_element_always_returns_it() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(555)
	var list: Array = ["only"]
	for i in range(50):
		var v: Variant = rng.pick(list)
		if v != "only":
			push_error("pick(['only']) returned %s at sample %d" % [str(v), i])
			return false
	return true


func test_pick_covers_all_elements_with_enough_samples() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(1111)
	var list: Array = [0, 1, 2, 3, 4]
	var seen: Dictionary = {}
	for i in range(500):
		var v: Variant = rng.pick(list)
		seen[v] = true
	for expected_val in list:
		if not seen.has(expected_val):
			push_error("pick([0..4]) never returned %d in 500 samples" % expected_val)
			return false
	return true


func test_pick_does_not_mutate_input_array() -> bool:
	var rng := MerlinRng.new()
	rng.set_seed(42)
	var list: Array = [10, 20, 30]
	var original_size: int = list.size()
	for i in range(20):
		rng.pick(list)
	if list.size() != original_size:
		push_error("pick() mutated the input array: size changed from %d to %d" % [original_size, list.size()])
		return false
	if list[0] != 10 or list[1] != 20 or list[2] != 30:
		push_error("pick() mutated the input array contents")
		return false
	return true
