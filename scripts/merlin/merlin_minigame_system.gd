## MerlinMiniGameSystem — Headless minigame simulation per lexical field (Phase 33)
## Each of the 8 lexical fields has a dedicated scoring algorithm.
## Difficulty 1-10 affects score distribution. Returns {type, success, score, time_ms}.
## In headless mode, scoring is deterministic (seeded RNG). In live mode, these
## serve as the scoring backend before full UI overlays are wired.

extends RefCounted
class_name MerlinMiniGameSystem

signal minigame_completed(score: int)

## Recognized lexical fields (aligned with MerlinConstants.FIELD_MINIGAMES)
const VALID_FIELDS: Array[String] = [
	"chance", "bluff", "observation", "logique",
	"finesse", "vigueur", "esprit", "perception", "neutre",
]

## Success threshold: score >= 80 is a win (bible v2.4)
const SUCCESS_THRESHOLD: int = 80

var _rng: MerlinRng


func set_rng(rng: MerlinRng) -> void:
	_rng = rng


## Run a minigame for the given lexical field and difficulty.
## Returns {type: String, success: bool, score: int (0-100), time_ms: int}.
func run(test_type: String, difficulty: int, modifiers: Dictionary = {}) -> Dictionary:
	var diff: int = clampi(difficulty, 1, 10)
	var bonus: float = float(modifiers.get("bonus", 0.0))
	var field: String = test_type.to_lower().strip_edges()

	var raw_score: int = 0
	match field:
		"vigueur":
			raw_score = _play_vigueur(diff)
		"esprit":
			raw_score = _play_esprit(diff)
		"bluff":
			raw_score = _play_bluff(diff)
		"logique":
			raw_score = _play_logique(diff)
		"observation":
			raw_score = _play_observation(diff)
		"perception":
			raw_score = _play_perception(diff)
		"finesse":
			raw_score = _play_finesse(diff)
		"chance":
			raw_score = _play_chance(diff)
		"neutre":
			# Neutre maps to esprit scoring (apaisement/volonte minigames)
			raw_score = _play_esprit(diff)
		_:
			# Unknown type: fallback to generic roll
			raw_score = _play_generic(diff)

	# Apply modifier bonus (additive, capped 0-100)
	var final_score: int = clampi(raw_score + int(bonus * 100.0), 0, 100)
	var success: bool = final_score >= SUCCESS_THRESHOLD
	var time_ms: int = _simulate_time_ms(diff)

	minigame_completed.emit(final_score)

	return {
		"type": field,
		"success": success,
		"score": final_score,
		"time_ms": time_ms,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# FIELD-SPECIFIC SCORING ALGORITHMS
# Each produces a score 0-100. Higher difficulty = harder = lower average score.
# ═══════════════════════════════════════════════════════════════════════════════


## Vigueur — Rhythm/timing (tap on beat)
## Simulates N beats, each with a hit/miss probability.
## Higher difficulty = tighter timing window = fewer hits.
func _play_vigueur(difficulty: int) -> int:
	var beats: int = 4 + difficulty  # 5 to 14 beats
	var hit_chance: float = _difficulty_to_hit_chance(difficulty)
	var hits: int = 0
	for i in range(beats):
		if _randf() <= hit_chance:
			hits += 1
	# Perfect timing bonus: if all hit, add 10
	var base_score: int = int(float(hits) / float(beats) * 90.0)
	if hits == beats:
		base_score = mini(base_score + 10, 100)
	return clampi(base_score, 0, 100)


## Esprit — Word puzzle (anagram/scramble)
## Simulates letter-by-letter solving with chance of error.
## Higher difficulty = more letters = more chances to fail.
func _play_esprit(difficulty: int) -> int:
	var letters: int = 3 + difficulty  # 4 to 13 letters
	var solve_chance: float = _difficulty_to_hit_chance(difficulty)
	var solved: int = 0
	for i in range(letters):
		if _randf() <= solve_chance:
			solved += 1
	var pct: float = float(solved) / float(letters)
	# Bonus for complete solve
	if solved == letters:
		return 100
	return clampi(int(pct * 95.0), 0, 100)


## Bluff — Poker-face timing (hold steady)
## Simulates maintaining composure over N rounds of pressure.
## Each round: chance to crack. Score = how long you held.
func _play_bluff(difficulty: int) -> int:
	var rounds: int = 5 + difficulty  # 6 to 15 rounds
	var hold_chance: float = _difficulty_to_hit_chance(difficulty)
	var held: int = 0
	for i in range(rounds):
		if _randf() <= hold_chance:
			held += 1
		else:
			break  # cracked under pressure
	var pct: float = float(held) / float(rounds)
	if held == rounds:
		return 100
	return clampi(int(pct * 90.0), 0, 100)


## Logique — Pattern memory / rune deciphering (Simon-like sequence)
## Simulates memorizing and reproducing a sequence.
## Higher difficulty = longer sequence.
func _play_logique(difficulty: int) -> int:
	var sequence_len: int = 3 + difficulty  # 4 to 13 steps
	var recall_chance: float = _difficulty_to_hit_chance(difficulty)
	var correct: int = 0
	for i in range(sequence_len):
		if _randf() <= recall_chance:
			correct += 1
		else:
			break  # first error ends the round
	var pct: float = float(correct) / float(sequence_len)
	if correct == sequence_len:
		return 100
	return clampi(int(pct * 85.0 + 5.0), 0, 100)


## Observation — Spot-the-difference / hidden object
## Simulates finding N hidden items in a scene.
## Score is proportional to items found.
func _play_observation(difficulty: int) -> int:
	var items: int = 3 + int(difficulty * 0.8)  # 3 to 11 items
	var find_chance: float = _difficulty_to_hit_chance(difficulty)
	var found: int = 0
	for i in range(items):
		if _randf() <= find_chance:
			found += 1
	var pct: float = float(found) / float(items)
	# Partial credit: finding half is ~45 score
	return clampi(int(pct * 100.0), 0, 100)


## Perception — Prediction / tracking (guess next in sequence, follow sound)
## Simulates N prediction rounds with diminishing accuracy at higher difficulty.
func _play_perception(difficulty: int) -> int:
	var rounds: int = 4 + difficulty  # 5 to 14 rounds
	var predict_chance: float = _difficulty_to_hit_chance(difficulty)
	var correct: int = 0
	for i in range(rounds):
		if _randf() <= predict_chance:
			correct += 1
	var pct: float = float(correct) / float(rounds)
	return clampi(int(pct * 95.0 + 5.0 * _randf()), 0, 100)


## Finesse — Agility / stealth (dodge, sneak, balance)
## Simulates a sequence of agility checks with increasing difficulty.
## Later checks are harder (cumulative fatigue).
func _play_finesse(difficulty: int) -> int:
	var checks: int = 4 + difficulty  # 5 to 14 checks
	var base_chance: float = _difficulty_to_hit_chance(difficulty)
	var passed: int = 0
	for i in range(checks):
		# Fatigue: each subsequent check is slightly harder
		var fatigue: float = float(i) * 0.02
		if _randf() <= maxf(base_chance - fatigue, 0.1):
			passed += 1
	var pct: float = float(passed) / float(checks)
	if passed == checks:
		return 100
	return clampi(int(pct * 92.0), 0, 100)


## Chance — Pure luck (dice, coin, fortune wheel)
## Score is mostly random, difficulty barely affects it.
func _play_chance(difficulty: int) -> int:
	# Base roll: uniform 0-100
	var roll: float = _randf() * 100.0
	# Difficulty slightly shifts the center downward
	var shift: float = float(difficulty - 5) * 2.0  # -8 to +10
	return clampi(int(roll - shift), 0, 100)


## Generic fallback for unknown types
## Difficulty shifts the score distribution downward.
func _play_generic(difficulty: int) -> int:
	var roll: float = _randf() * 100.0
	var shift: float = float(difficulty - 5) * 3.0
	return clampi(int(roll - shift), 0, 100)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════


## Convert difficulty (1-10) to a hit/success probability (0.95 to 0.4).
## Difficulty 1 = easy (95% chance), difficulty 10 = very hard (40% chance).
func _difficulty_to_hit_chance(difficulty: int) -> float:
	# Linear interpolation: diff 1 → 0.95, diff 10 → 0.40
	var t: float = float(clampi(difficulty, 1, 10) - 1) / 9.0
	return lerpf(0.95, 0.40, t)


## Simulate plausible game duration in milliseconds.
## Harder games take longer (5-15 seconds range per bible).
func _simulate_time_ms(difficulty: int) -> int:
	var min_ms: float = 5000.0
	var max_ms: float = 15000.0
	var t: float = float(clampi(difficulty, 1, 10) - 1) / 9.0
	var base_ms: float = lerpf(min_ms, max_ms, t)
	# Add some variance
	return int(base_ms + _randf_range(-1000.0, 2000.0))


func _randf() -> float:
	if _rng != null:
		return _rng.randf()
	return randf()


func _randf_range(min_val: float, max_val: float) -> float:
	if _rng != null:
		return _rng.randf_range(min_val, max_val)
	return randf_range(min_val, max_val)
