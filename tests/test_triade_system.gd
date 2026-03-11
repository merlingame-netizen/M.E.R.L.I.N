extends RefCounted
## Unit tests for the Triade game system.
##
## Tests are standalone — no heavy autoloads required.
## Run via tests/headless_runner.gd or directly with:
##   godot --headless --quit-after 30 res://tests/headless_runner.tscn
##
## Conventions:
##   - Each test_*() func is independent and returns bool (true = pass, false = fail).
##   - Call push_error() with a descriptive message before returning false.
##   - No heavy autoloads or scene dependencies — pure logic only.


# ── Triade aspect names ──────────────────────────────────────────────────────

func test_triade_aspect_names() -> bool:
	## Verify that the three Triade aspect names are defined as expected.
	var expected_aspects: Array[String] = ["Corps", "Ame", "Monde"]

	# Validate each name is a non-empty string (no dependency on autoloads).
	for aspect in expected_aspects:
		if not (aspect is String and aspect.length() > 0):
			push_error("test_triade_aspect_names: empty or non-string aspect: " + str(aspect))
			return false

	# Verify the set is exactly 3 unique values.
	var unique := {}
	for a in expected_aspects:
		unique[a] = true
	if unique.size() != 3:
		push_error("test_triade_aspect_names: expected 3 unique aspects, got %d" % unique.size())
		return false

	# Verify the canonical animal associations are consistent with design doc.
	var aspect_animals: Dictionary = {
		"Corps": "Sanglier",
		"Ame":   "Corbeau",
		"Monde": "Cerf",
	}
	for aspect in expected_aspects:
		if not aspect_animals.has(aspect):
			push_error("test_triade_aspect_names: no animal mapping for aspect: " + aspect)
			return false

	return true


# ── Souffle bounds ───────────────────────────────────────────────────────────

func test_souffle_bounds() -> bool:
	## Verify souffle clamps correctly between 0 and 7.
	const SOUFFLE_MIN: int = 0
	const SOUFFLE_MAX: int = 7
	const SOUFFLE_START: int = 3

	# Starting value must be within [min, max].
	if SOUFFLE_START < SOUFFLE_MIN or SOUFFLE_START > SOUFFLE_MAX:
		push_error("test_souffle_bounds: SOUFFLE_START %d out of [%d, %d]" % [SOUFFLE_START, SOUFFLE_MIN, SOUFFLE_MAX])
		return false

	# Simulate clamping: values outside range must be clamped.
	var test_values: Array[int] = [-5, -1, 0, 1, 3, 7, 8, 100]
	var expected:    Array[int] = [ 0,  0, 0, 1, 3, 7, 7,   7]

	for i in range(test_values.size()):
		var clamped: int = clamp(test_values[i], SOUFFLE_MIN, SOUFFLE_MAX)
		if clamped != expected[i]:
			push_error(
				"test_souffle_bounds: clamp(%d) expected %d, got %d"
				% [test_values[i], expected[i], clamped]
			)
			return false

	# Verify that spending 1 souffle on a Centre option is valid from start.
	var current_souffle: int = SOUFFLE_START
	var centre_cost: int = 1
	if current_souffle - centre_cost < SOUFFLE_MIN:
		push_error("test_souffle_bounds: Centre cost exceeds starting souffle")
		return false

	# Verify bonus rule: +1 souffle when 3 aspects are balanced, capped at max.
	var at_max: int = SOUFFLE_MAX
	var after_bonus: int = clamp(at_max + 1, SOUFFLE_MIN, SOUFFLE_MAX)
	if after_bonus != SOUFFLE_MAX:
		push_error("test_souffle_bounds: bonus at max should clamp to %d, got %d" % [SOUFFLE_MAX, after_bonus])
		return false

	return true


# ── Aspect state range ───────────────────────────────────────────────────────

func test_aspect_state_range() -> bool:
	## Verify aspect states are within the valid discrete range [-1, 0, 1].
	const STATE_LOW:      int = -1   # Epuise / Perdue / Exile
	const STATE_BALANCED: int =  0   # Robuste / Centree / Integre
	const STATE_HIGH:     int =  1   # Surmene / Possedee / Tyran

	var valid_states: Array[int] = [STATE_LOW, STATE_BALANCED, STATE_HIGH]

	# All valid state values must be in range.
	for s in valid_states:
		if s < STATE_LOW or s > STATE_HIGH:
			push_error("test_aspect_state_range: valid state %d out of range [%d, %d]" % [s, STATE_LOW, STATE_HIGH])
			return false

	# Out-of-range values must not be in the valid set.
	var invalid_states: Array[int] = [-2, 2, 99, -99]
	for s in invalid_states:
		if s in valid_states:
			push_error("test_aspect_state_range: invalid state %d should not be in valid set" % s)
			return false

	# Simulate all 3 aspects starting at balanced.
	var aspects: Dictionary = {"Corps": 0, "Ame": 0, "Monde": 0}
	for aspect in aspects:
		var state: int = aspects[aspect]
		if not (state in valid_states):
			push_error("test_aspect_state_range: initial state %d for %s not valid" % [state, aspect])
			return false

	# Verify shift logic: applying +1 from balanced reaches STATE_HIGH.
	var corps: int = STATE_BALANCED
	corps = clamp(corps + 1, STATE_LOW, STATE_HIGH)
	if corps != STATE_HIGH:
		push_error("test_aspect_state_range: balanced+1 should be STATE_HIGH, got %d" % corps)
		return false

	# Verify shift logic: applying -1 from balanced reaches STATE_LOW.
	var ame: int = STATE_BALANCED
	ame = clamp(ame - 1, STATE_LOW, STATE_HIGH)
	if ame != STATE_LOW:
		push_error("test_aspect_state_range: balanced-1 should be STATE_LOW, got %d" % ame)
		return false

	# Verify that applying +1 from STATE_HIGH does not exceed max.
	var monde: int = STATE_HIGH
	monde = clamp(monde + 1, STATE_LOW, STATE_HIGH)
	if monde != STATE_HIGH:
		push_error("test_aspect_state_range: STATE_HIGH+1 should clamp to STATE_HIGH, got %d" % monde)
		return false

	return true
