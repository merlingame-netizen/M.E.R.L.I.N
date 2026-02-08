extends RefCounted
class_name MerlinSaveSystem

const CURRENT_VERSION := "0.1.0"
const SLOT_COUNT := 3
const SLOT_PATH := "user://merlin_save_slot_%d.json"

func save_slot(slot: int, payload: Dictionary) -> bool:
	if not _is_valid_slot(slot):
		return false
	var data := payload.duplicate(true)
	if not data.has("version"):
		data["version"] = CURRENT_VERSION
	var json_text := JSON.stringify(data)
	var file := FileAccess.open(SLOT_PATH % slot, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_text)
	file.close()
	return true


func load_slot(slot: int, default_state: Dictionary = {}) -> Dictionary:
	if not _is_valid_slot(slot):
		return {}
	var file := FileAccess.open(SLOT_PATH % slot, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return migrate(data, default_state)


func delete_slot(slot: int) -> void:
	if not _is_valid_slot(slot):
		return
	if FileAccess.file_exists(SLOT_PATH % slot):
		DirAccess.remove_absolute(SLOT_PATH % slot)


func slot_exists(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists(SLOT_PATH % slot)


func get_slot_info(slot: int) -> Dictionary:
	var data := load_slot(slot)
	if data.is_empty():
		return {}
	return {
		"version": data.get("version", ""),
		"timestamp": data.get("timestamp", 0),
		"phase": data.get("phase", ""),
	}


func migrate(payload: Dictionary, default_state: Dictionary = {}) -> Dictionary:
	var data := payload.duplicate(true)
	if not data.has("version"):
		data["version"] = CURRENT_VERSION
	if data["version"] != CURRENT_VERSION:
		data["version"] = CURRENT_VERSION
	if not default_state.is_empty():
		data = _merge_missing(default_state, data)
	return data


func _merge_missing(default_state: Dictionary, data: Dictionary) -> Dictionary:
	var merged := default_state.duplicate(true)
	for key in data:
		merged[key] = data[key]
	return merged


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT
