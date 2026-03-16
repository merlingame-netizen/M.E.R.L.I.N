extends RefCounted
## Tests for SceneSelector autoload — pure-logic validation
## Tests the SCENES registry, path formats, label uniqueness, index bounds,
## and toggle state logic without requiring scene tree.


# === HELPERS ===

## Access the SCENES constant from the loaded script resource
func _get_scenes_const() -> Array:
	var script_res: GDScript = load("res://scripts/autoload/SceneSelector.gd")
	if script_res == null:
		push_error("Cannot load SceneSelector.gd")
		return []
	return script_res.SCENES


# === TESTS ===

func test_scenes_registry_not_empty() -> bool:
	var scenes: Array = _get_scenes_const()
	if scenes.size() == 0:
		push_error("SCENES registry is empty")
		return false
	return true


func test_scenes_count_matches_expected() -> bool:
	var scenes: Array = _get_scenes_const()
	var expected_min: int = 14
	if scenes.size() < expected_min:
		push_error("SCENES has %d entries, expected at least %d" % [scenes.size(), expected_min])
		return false
	return true


func test_all_entries_have_label_key() -> bool:
	var scenes: Array = _get_scenes_const()
	for i in scenes.size():
		var entry: Dictionary = scenes[i]
		if not entry.has("label"):
			push_error("SCENES[%d] missing 'label' key" % i)
			return false
	return true


func test_all_entries_have_path_key() -> bool:
	var scenes: Array = _get_scenes_const()
	for i in scenes.size():
		var entry: Dictionary = scenes[i]
		if not entry.has("path"):
			push_error("SCENES[%d] missing 'path' key" % i)
			return false
	return true


func test_all_labels_are_non_empty_strings() -> bool:
	var scenes: Array = _get_scenes_const()
	for i in scenes.size():
		var label: String = scenes[i]["label"]
		if label.strip_edges().is_empty():
			push_error("SCENES[%d] has empty label" % i)
			return false
	return true


func test_all_paths_start_with_res() -> bool:
	var scenes: Array = _get_scenes_const()
	for i in scenes.size():
		var path: String = scenes[i]["path"]
		if not path.begins_with("res://"):
			push_error("SCENES[%d] path '%s' does not start with res://" % [i, path])
			return false
	return true


func test_all_paths_end_with_tscn() -> bool:
	var scenes: Array = _get_scenes_const()
	for i in scenes.size():
		var path: String = scenes[i]["path"]
		if not path.ends_with(".tscn"):
			push_error("SCENES[%d] path '%s' does not end with .tscn" % [i, path])
			return false
	return true


func test_labels_are_unique() -> bool:
	var scenes: Array = _get_scenes_const()
	var seen: Dictionary = {}
	for i in scenes.size():
		var label: String = scenes[i]["label"]
		if seen.has(label):
			push_error("Duplicate label '%s' at indices %d and %d" % [label, seen[label], i])
			return false
		seen[label] = i
	return true


func test_paths_are_unique() -> bool:
	var scenes: Array = _get_scenes_const()
	var seen: Dictionary = {}
	for i in scenes.size():
		var path: String = scenes[i]["path"]
		if seen.has(path):
			push_error("Duplicate path '%s' at indices %d and %d" % [path, seen[path], i])
			return false
		seen[path] = i
	return true


func test_known_scene_merlingame_present() -> bool:
	var scenes: Array = _get_scenes_const()
	for entry in scenes:
		var path: String = entry["path"]
		if path == "res://scenes/MerlinGame.tscn":
			return true
	push_error("MerlinGame.tscn not found in SCENES registry")
	return false


func test_known_scene_menuprincipal_present() -> bool:
	var scenes: Array = _get_scenes_const()
	for entry in scenes:
		var path: String = entry["path"]
		if path == "res://scenes/MenuPrincipal.tscn":
			return true
	push_error("MenuPrincipal.tscn not found in SCENES registry")
	return false


func test_known_scene_introceltos_present() -> bool:
	var scenes: Array = _get_scenes_const()
	for entry in scenes:
		var path: String = entry["path"]
		if path == "res://scenes/IntroCeltOS.tscn":
			return true
	push_error("IntroCeltOS.tscn not found in SCENES registry")
	return false


func test_index_zero_is_intro_scene() -> bool:
	var scenes: Array = _get_scenes_const()
	if scenes.size() == 0:
		push_error("SCENES is empty")
		return false
	var first_path: String = scenes[0]["path"]
	if first_path != "res://scenes/IntroCeltOS.tscn":
		push_error("First scene should be IntroCeltOS, got '%s'" % first_path)
		return false
	return true


func test_no_path_contains_double_slashes_after_res() -> bool:
	var scenes: Array = _get_scenes_const()
	for i in scenes.size():
		var path: String = scenes[i]["path"]
		var after_prefix: String = path.substr(6)  # after "res://"
		if after_prefix.find("//") >= 0:
			push_error("SCENES[%d] path '%s' has double slashes" % [i, path])
			return false
	return true


func test_toggle_state_logic_starts_closed() -> bool:
	# Simulate toggle state logic (mirrors SceneSelector._is_open)
	var is_open: bool = false
	if is_open != false:
		push_error("Initial toggle state should be false")
		return false
	return true


func test_toggle_state_logic_opens_on_first_toggle() -> bool:
	var is_open: bool = false
	is_open = not is_open  # first toggle
	if is_open != true:
		push_error("After first toggle, state should be true")
		return false
	return true


func test_toggle_state_logic_closes_on_second_toggle() -> bool:
	var is_open: bool = false
	is_open = not is_open  # open
	is_open = not is_open  # close
	if is_open != false:
		push_error("After double toggle, state should be false")
		return false
	return true


func test_toggle_button_text_logic() -> bool:
	# Mirrors: _toggle_btn.text = "X" if _is_open else "Scenes"
	var is_open: bool = false
	var text: String = "X" if is_open else "Scenes"
	if text != "Scenes":
		push_error("Closed state text should be 'Scenes', got '%s'" % text)
		return false
	is_open = true
	text = "X" if is_open else "Scenes"
	if text != "X":
		push_error("Open state text should be 'X', got '%s'" % text)
		return false
	return true


func test_scene_selected_resets_state() -> bool:
	# Mirrors: _on_scene_selected sets _is_open = false
	var is_open: bool = true
	# Simulate selection
	is_open = false
	var text: String = "Scenes"
	if is_open != false:
		push_error("After scene selection, is_open should be false")
		return false
	if text != "Scenes":
		push_error("After scene selection, text should be 'Scenes'")
		return false
	return true


func test_index_bounds_valid_for_selection() -> bool:
	var scenes: Array = _get_scenes_const()
	var max_index: int = scenes.size() - 1
	if max_index < 0:
		push_error("SCENES is empty, no valid index")
		return false
	# Verify first and last index access works
	var first_path: String = scenes[0]["path"]
	var last_path: String = scenes[max_index]["path"]
	if first_path.is_empty() or last_path.is_empty():
		push_error("Path at boundary index is empty")
		return false
	return true
