@tool
extends PanelContainer

const DEPLOYER := preload("res://addons/gd_script_deployer/core/deployer.gd")

const SOURCE_ZIP := 0
const SOURCE_DIR := 1

var _plugin: EditorPlugin
var _deployer: RefCounted

@onready var _source_type: OptionButton = $"Margin/Layout/SourceRow/SourceType"
@onready var _package_path: LineEdit = $"Margin/Layout/PackageRow/PackagePath"
@onready var _target_path: LineEdit = $"Margin/Layout/TargetRow/TargetPath"
@onready var _browse_package: Button = $"Margin/Layout/PackageRow/BrowsePackage"
@onready var _browse_target: Button = $"Margin/Layout/TargetRow/BrowseTarget"
@onready var _use_manifest: CheckBox = $"Margin/Layout/Options/UseManifest"
@onready var _create_backup: CheckBox = $"Margin/Layout/Options/CreateBackup"
@onready var _scan_button: Button = $"Margin/Layout/Actions/ScanButton"
@onready var _deploy_button: Button = $"Margin/Layout/Actions/DeployButton"
@onready var _log: TextEdit = $"Margin/Layout/Log"
@onready var _package_dialog: EditorFileDialog = $PackageDialog
@onready var _target_dialog: EditorFileDialog = $TargetDialog

func set_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _ready() -> void:
	_deployer = DEPLOYER.new()
	if _source_type == null:
		push_error("GDScriptDeployerDock: Missing UI nodes. Check deployer_dock.tscn.")
		return
	_setup_ui()


func _setup_ui() -> void:
	_source_type.clear()
	_source_type.add_item("Zip package", SOURCE_ZIP)
	_source_type.add_item("Folder", SOURCE_DIR)
	_source_type.select(SOURCE_ZIP)

	_package_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_target_dialog.access = EditorFileDialog.ACCESS_RESOURCES

	_target_path.text = "res://scripts"
	_use_manifest.button_pressed = true
	_create_backup.button_pressed = false
	_source_type.item_selected.connect(_on_source_type_changed)
	_browse_package.pressed.connect(_on_browse_package_pressed)
	_browse_target.pressed.connect(_on_browse_target_pressed)
	_scan_button.pressed.connect(_on_scan_pressed)
	_deploy_button.pressed.connect(_on_deploy_pressed)

	_package_dialog.file_selected.connect(_on_package_file_selected)
	_package_dialog.dir_selected.connect(_on_package_dir_selected)
	_target_dialog.dir_selected.connect(_on_target_dir_selected)

	_sync_package_dialog_mode()
	_log_line("Ready.")


func _on_source_type_changed(_index: int) -> void:
	_sync_package_dialog_mode()


func _sync_package_dialog_mode() -> void:
	_package_dialog.clear_filters()
	if _source_type.selected == SOURCE_ZIP:
		_package_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_package_dialog.add_filter("*.zip ; Zip package")
		_package_dialog.add_filter("*.gdpack ; GD pack")
		_package_path.placeholder_text = "res:// or C:/path/package.zip"
	else:
		_package_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		_package_path.placeholder_text = "res:// or C:/path/folder"


func _on_browse_package_pressed() -> void:
	_package_dialog.popup_centered_ratio(0.7)


func _on_browse_target_pressed() -> void:
	_target_dialog.popup_centered_ratio(0.7)


func _on_package_file_selected(path: String) -> void:
	_package_path.text = path


func _on_package_dir_selected(path: String) -> void:
	_package_path.text = path


func _on_target_dir_selected(path: String) -> void:
	_target_path.text = path


func _on_scan_pressed() -> void:
	_log_line("---- Scan ----")
	var plan = _deployer.scan(_package_path.text, _target_path.text, _use_manifest.button_pressed, Callable(self, "_log_line"))
	_report_messages(plan)
	if not plan["ok"]:
		_log_line("Scan failed.")
		return
	_log_line("Files planned: %d" % plan["files"].size())
	_log_file_list(plan["files"])


func _on_deploy_pressed() -> void:
	_log_line("---- Deploy ----")
	var plan = _deployer.scan(_package_path.text, _target_path.text, _use_manifest.button_pressed, Callable(self, "_log_line"))
	_report_messages(plan)
	if not plan["ok"]:
		_log_line("Deploy stopped: invalid plan.")
		return

	var result = _deployer.apply(plan, _create_backup.button_pressed, Callable(self, "_log_line"))
	_report_messages(result)
	if not result["ok"]:
		_log_line("Deploy failed.")
		return

	_log_line("Deploy complete. Files copied: %d" % result["copied"])
	_apply_autoloads(plan.get("autoloads", []))


func _apply_autoloads(autoloads: Array) -> void:
	if autoloads.is_empty():
		return
	if _plugin == null:
		_log_line("Autoloads skipped: plugin not set.")
		return
	var class_conflicts = _get_global_class_names()
	var changed := false
	for entry in autoloads:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var name = str(entry.get("name", "")).strip_edges()
		var path = str(entry.get("path", "")).strip_edges()
		if name == "" or path == "":
			_log_line("Skipped invalid autoload entry.")
			continue
		if ClassDB.class_exists(name) or class_conflicts.has(name.to_lower()):
			_log_line("Autoload name conflicts with global class: %s (skipped)" % name)
			continue
		var key = "autoload/%s" % name
		if ProjectSettings.has_setting(key):
			_log_line("Autoload already exists: %s" % name)
			continue
		_plugin.add_autoload_singleton(name, path)
		changed = true
		_log_line("Autoload added: %s -> %s" % [name, path])

	if changed:
		ProjectSettings.save()


func _get_global_class_names() -> Dictionary:
	var names := {}
	var classes = ProjectSettings.get_setting("global_script_classes", [])
	if typeof(classes) == TYPE_ARRAY:
		for entry in classes:
			if typeof(entry) == TYPE_DICTIONARY:
				var class_name_value = str(entry.get("class", "")).strip_edges()
				if class_name_value != "":
					names[class_name_value.to_lower()] = true
	return names


func _report_messages(result: Dictionary) -> void:
	for message in result.get("warnings", []):
		_log_line("WARN: %s" % message)
	for message in result.get("errors", []):
		_log_line("ERROR: %s" % message)


func _log_file_list(files: Array) -> void:
	var limit := 40
	for i in range(files.size()):
		if i >= limit:
			_log_line("... %d more" % (files.size() - limit))
			break
		var target = files[i].get("target", "")
		_log_line(" - %s" % target)


func _log_line(message: String) -> void:
	if _log == null:
		return
	_log.text += message + "\n"
	_log.scroll_vertical = _log.get_line_count()
