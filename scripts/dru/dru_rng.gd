extends RefCounted
class_name DruRng

var _state: int = 0

func set_seed(seed_value: int) -> void:
	_state = seed_value & 0x7fffffff


func get_seed() -> int:
	return _state


func randf() -> float:
	_state = (_state + 0x6D2B79F5) & 0x7fffffff
	var t: int = _state
	t = (t ^ (t >> 15)) * (1 | _state)
	t = (t + ((t ^ (t >> 7)) * (61 | t))) ^ t
	return float((t ^ (t >> 14)) & 0x7fffffff) / float(0x7fffffff)


func randf_range(min_val: float, max_val: float) -> float:
	return lerpf(min_val, max_val, randf())


func randi_range(min_val: int, max_val: int) -> int:
	return min_val + int(randf() * float(max_val - min_val + 1))


func rand_bool(chance: float = 0.5) -> bool:
	return randf() <= clampf(chance, 0.0, 1.0)


func pick(list: Array) -> Variant:
	if list.is_empty():
		return null
	return list[randi_range(0, list.size() - 1)]
