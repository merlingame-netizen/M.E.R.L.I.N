extends Node
class_name RAGManager

const HISTORY_PATH := "user://ai/memory/history.json"
const WORLD_STATE_PATH := "user://ai/memory/world_state.json"
const EVENTS_PATH := "user://ai/memory/events.json"
const MAX_HISTORY_ITEMS := 100

var history: Array = []
var world_state: Dictionary = {}
var actions_by_category: Dictionary = {}

func _ready() -> void:
	_ensure_storage()
	_load_history()
	_load_world_state()
	_load_actions()

func get_relevant_context(query: String, category: String) -> Dictionary:
	var context = {
		"recent_history": _get_recent_history(5),
		"relevant_history": _search_history(query, 3),
		"world_state_subset": _get_relevant_state(query),
		"available_actions": _get_actions_for_category(category)
	}
	return context

func _get_recent_history(count: int) -> Array:
	return history.slice(-count) if history.size() >= count else history

func _search_history(query: String, count: int) -> Array:
	var keywords = query.to_lower().split(" ")
	var scored: Array = []
	for item in history:
		var score = 0
		var text = (str(item.get("input", "")) + " " + str(item.get("response", ""))).to_lower()
		for kw in keywords:
			if kw.length() > 3 and text.contains(kw):
				score += 1
		if score > 0:
			scored.append({"item": item, "score": score})
	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored.slice(0, count).map(func(x): return x.item)

func _get_relevant_state(_query: String) -> Dictionary:
	return world_state

func _get_actions_for_category(category: String) -> Array:
	if actions_by_category.has(category):
		var value = actions_by_category[category]
		if value is Array:
			return value
		elif value is Dictionary:
			return value.values()
	return []

func add_to_history(input: String, response: String) -> void:
	history.append({
		"timestamp": Time.get_unix_time_from_system(),
		"input": input,
		"response": response
	})
	if history.size() > MAX_HISTORY_ITEMS:
		history = history.slice(-MAX_HISTORY_ITEMS)
	_save_history()

func update_world_state(key: String, value) -> void:
	world_state[key] = value
	_save_world_state()

func _load_actions() -> void:
	var path = "res://data/ai/config/actions.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY and data.has("categories"):
			actions_by_category = data.categories

func _save_history() -> void:
	var file = FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(history))
	file.close()

func _load_history() -> void:
	if FileAccess.file_exists(HISTORY_PATH):
		var file = FileAccess.open(HISTORY_PATH, FileAccess.READ)
		history = JSON.parse_string(file.get_as_text())
		file.close()

func _save_world_state() -> void:
	var file = FileAccess.open(WORLD_STATE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(world_state))
	file.close()

func _load_world_state() -> void:
	if FileAccess.file_exists(WORLD_STATE_PATH):
		var file = FileAccess.open(WORLD_STATE_PATH, FileAccess.READ)
		world_state = JSON.parse_string(file.get_as_text())
		file.close()

func _ensure_storage() -> void:
	var base_dir = "user://ai/memory"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
