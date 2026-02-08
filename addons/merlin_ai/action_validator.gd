extends Node
class_name ActionValidator

var actions_schema: Dictionary = {}
var game_state_ref: Dictionary = {}

func _ready() -> void:
	_load_actions_schema()

func validate(action: Dictionary) -> Dictionary:
	var result = {"valid": false, "errors": []}
	if not action.has("type"):
		result.errors.append("Missing action type")
		return result
	var action_type = action.type
	if not actions_schema.has(action_type):
		result.errors.append("Unknown action type: " + str(action_type))
		return result
	var schema = actions_schema[action_type]
	if schema.has("params"):
		for param in schema.params:
			if not action.has("params") or not action.params.has(param):
				result.errors.append("Missing param: " + str(param))
	if schema.has("conditions"):
		for condition in schema.conditions:
			if not _check_condition(condition, action):
				result.errors.append("Condition failed: " + str(condition))
	result.valid = result.errors.is_empty()
	return result

func _check_condition(condition: String, action: Dictionary) -> bool:
	match condition:
		"target_in_range":
			return _check_target_in_range(str(action.params.get("target_id", "")))
		"has_mana":
			return int(game_state_ref.get("player_mana", 0)) > 0
		"spell_known":
			return action.params.get("spell_id", "") in game_state_ref.get("known_spells", [])
		_:
			return true

func _check_target_in_range(_target_id: String) -> bool:
	return true

func _load_actions_schema() -> void:
	var path = "res://data/ai/config/actions.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY and data.has("categories"):
			for cat in data.categories.keys():
				var items: Dictionary = data.categories[cat]
				for key in items.keys():
					actions_schema[key] = items[key]
