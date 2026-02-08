@tool
extends EditorPlugin

const MAX_LOG_BYTES := 200000
const MAX_TOTAL_BYTES := 600000
const LOG_EXTS := [".log", ".txt"]
const LOG_DIRS := ["user://logs", "user://"]
const FALLBACK_LOGS := [
	"user://editor.log",
	"user://editor_log.txt",
	"user://godot.log",
	"user://logs/editor.log",
	"user://logs/godot.log",
]

var dock: PanelContainer
var log_edit: TextEdit
var source_label: Label
var status_label: Label
var _last_log_path := ""
var _bottom_button: Button = null

func _enter_tree() -> void:
	dock = PanelContainer.new()
	dock.name = "Error Clipboard"
	dock.custom_minimum_size = Vector2(320, 260)
	
	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(root)
	
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)
	
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_on_refresh_pressed)
	header.add_child(refresh_btn)
	
	var copy_btn = Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(_on_copy_pressed)
	header.add_child(copy_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	header.add_child(clear_btn)
	
	var open_btn = Button.new()
	open_btn.text = "Open Folder"
	open_btn.pressed.connect(_on_open_folder_pressed)
	header.add_child(open_btn)
	
	source_label = Label.new()
	source_label.text = "Source: (not loaded)"
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(source_label)
	
	status_label = Label.new()
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)
	
	log_edit = TextEdit.new()
	log_edit.editable = false
	log_edit.wrap_mode = 1
	log_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(log_edit)
	
	_bottom_button = add_control_to_bottom_panel(dock, "Errors")
	_refresh_log()

func _exit_tree() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.free()
		dock = null
		_bottom_button = null

func _on_refresh_pressed() -> void:
	_refresh_log()

func _on_copy_pressed() -> void:
	if log_edit:
		DisplayServer.clipboard_set(log_edit.text)
		status_label.text = "Copied to clipboard."

func _on_clear_pressed() -> void:
	if log_edit:
		log_edit.text = ""
		status_label.text = "Cleared."

func _on_open_folder_pressed() -> void:
	if _last_log_path == "":
		return
	var global_path = ProjectSettings.globalize_path(_last_log_path)
	var folder = global_path.get_base_dir()
	OS.shell_open(folder)

func _refresh_log() -> void:
	var log_paths = _find_all_log_paths()
	if log_paths.is_empty():
		_last_log_path = ""
		source_label.text = "Source: (not found)"
		status_label.text = "Enable editor log file output or run the game once."
		log_edit.text = ""
		return
	
	var combined := ""
	var total := 0
	for path in log_paths:
		var text = _read_log_file(path)
		if text == "":
			continue
		var mtime = FileAccess.get_modified_time(path)
		var header = "\n---- " + path + " (" + str(mtime) + ") ----\n"
		combined += header + text
		total = combined.length()
		if total > MAX_TOTAL_BYTES:
			combined += "\n[...snip...]\n"
			break
	
	_last_log_path = log_paths[0]
	source_label.text = "Sources: " + str(log_paths.size())
	status_label.text = "Loaded " + str(combined.length()) + " chars."
	log_edit.text = combined
	log_edit.scroll_vertical = log_edit.get_line_count()

func _find_all_log_paths() -> Array[String]:
	var candidates: Array[String] = []
	for dir_path in LOG_DIRS:
		candidates.append_array(_collect_log_candidates(dir_path))
	
	for path in FALLBACK_LOGS:
		if FileAccess.file_exists(path):
			candidates.append(path)
	
	var unique: Array[String] = []
	for path in candidates:
		if not unique.has(path):
			unique.append(path)
	unique.sort_custom(func(a, b): return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b))
	return unique

func _collect_log_candidates(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower = file_name.to_lower()
			for ext in LOG_EXTS:
				if lower.ends_with(ext):
					results.append(dir_path.path_join(file_name))
					break
		file_name = dir.get_next()
	dir.list_dir_end()
	return results

func _read_log_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var length = file.get_length()
	var start = max(0, length - MAX_LOG_BYTES)
	file.seek(start)
	var text = file.get_as_text()
	if start > 0:
		return "[...snip...]\n" + text
	return text
