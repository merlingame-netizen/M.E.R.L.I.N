extends RefCounted
class_name DruMiniGameSystem

var _rng: DruRng

func set_rng(rng: DruRng) -> void:
	_rng = rng


func run(test_type: String, difficulty: int, modifiers: Dictionary = {}) -> Dictionary:
	var diff := clampi(difficulty, 1, 10)
	var base_threshold := 0.5 + (5 - diff) * 0.05
	var bonus := float(modifiers.get("bonus", 0.0))
	var threshold := clampf(base_threshold + bonus, 0.05, 0.95)
	var roll := _randf()
	var success := roll <= threshold
	var score := int(clampf(roll * 100.0, 0.0, 100.0))
	return {
		"type": test_type,
		"success": success,
		"score": score,
		"time_ms": int(_randf_range(450.0, 1800.0)),
	}


func _randf() -> float:
	if _rng != null:
		return _rng.randf()
	return randf()


func _randf_range(min_val: float, max_val: float) -> float:
	if _rng != null:
		return _rng.randf_range(min_val, max_val)
	return randf_range(min_val, max_val)
