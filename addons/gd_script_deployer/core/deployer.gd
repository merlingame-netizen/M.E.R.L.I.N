@tool
extends RefCounted

const MANIFEST_NAME := "gd_script_package.json"
const SOURCE_ZIP := "zip"
const SOURCE_DIR := "dir"

func scan(package_path: String, target_root: String, use_manifest: bool, log_fn: Callable = Callable()) -> Dictionary:
	var result := {
		"ok": false,
		"errors": [],
		"warnings": [],
		"files": [],
		"autoloads": [],
		"manifest": {},
		"source_type": "",
		"package_path": _normalize_path(package_path),
		"target_root": _normalize_path(target_root),
	}

	if result["package_path"] == "":
		_append_error(result, "Package path is empty.")
		return result

	if result["target_root"] == "":
		_append_error(result, "Target root is empty.")
		return result

	if not _is_valid_target_root(result["target_root"]):
		_append_error(result, "Target root must start with res:// or user://.")
		return result

	if not _path_exists(result["package_path"]):
		_append_error(result, "Package path not found: %s" % result["package_path"])
		return result

	if _is_zip(result["package_path"]):
		result["source_type"] = SOURCE_ZIP
		_scan_zip(result, use_manifest, log_fn)
	else:
		result["source_type"] = SOURCE_DIR
		_scan_dir(result, use_manifest, log_fn)

	result["ok"] = result["errors"].is_empty() and not result["files"].is_empty()
	if result["ok"] and not log_fn.is_null():
		log_fn.call("Scan complete: %d file(s) ready." % result["files"].size())
	return result


func apply(plan: Dictionary, create_backup: bool, log_fn: Callable = Callable()) -> Dictionary:
	var result := {
		"ok": false,
		"errors": [],
		"warnings": [],
		"copied": 0,
		"backup_root": "",
	}

	if not plan.has("ok") or not plan["ok"]:
		_append_error(result, "Plan is not valid. Run scan first.")
		return result

	if plan["files"].is_empty():
		_append_error(result, "No files to deploy.")
		return result

	var backup_root := ""
	if create_backup:
		backup_root = "user://gd_script_deployer_backups/%s" % str(Time.get_unix_time_from_system())
		var backup_err = _ensure_dir(backup_root)
		if backup_err != OK:
			_append_error(result, "Failed to create backup folder: %s" % backup_root)
			return result
		result["backup_root"] = backup_root
		if not log_fn.is_null():
			log_fn.call("Backup enabled: %s" % backup_root)

	if plan["source_type"] == SOURCE_ZIP:
		_apply_zip(plan, backup_root, create_backup, result, log_fn)
	elif plan["source_type"] == SOURCE_DIR:
		_apply_dir(plan, backup_root, create_backup, result, log_fn)
	else:
		_append_error(result, "Unknown source type in plan.")
		return result

	result["ok"] = result["errors"].is_empty()
	return result


func _scan_zip(result: Dictionary, use_manifest: bool, log_fn: Callable) -> void:
	var zip := ZIPReader.new()
	var open_err := zip.open(result["package_path"])
	if open_err != OK:
		_append_error(result, "Failed to open zip: %s (error %d)" % [result["package_path"], open_err])
		return

	var files := zip.get_files()
	if files.is_empty():
		_append_error(result, "Zip package is empty.")
		zip.close()
		return

	var manifest := {}
	if use_manifest:
		manifest = _read_manifest_from_zip(zip, files, result, log_fn)
		result["manifest"] = manifest

	if not manifest.is_empty() and manifest.has("files"):
		_apply_manifest_files(result, manifest, log_fn, func(source: String) -> String:
			return source
		)
		_extract_autoloads(result, manifest)
	else:
		for entry in files:
			if entry.ends_with("/"):
				continue
			if not entry.to_lower().ends_with(".gd"):
				continue
			if _has_path_traversal(entry):
				_append_warning(result, "Skipped unsafe path in zip: %s" % entry)
				continue
			var target_path = result["target_root"].path_join(entry)
			result["files"].append({
				"source": entry,
				"target": target_path,
				"source_type": SOURCE_ZIP,
			})

	zip.close()

	if result["files"].is_empty():
		_append_warning(result, "No .gd files found in zip package.")


func _scan_dir(result: Dictionary, use_manifest: bool, log_fn: Callable) -> void:
	var base_dir: String = str(result["package_path"])
	if not _is_dir(base_dir):
		_append_error(result, "Package path is not a folder: %s" % base_dir)
		return

	var manifest := {}
	if use_manifest:
		manifest = _read_manifest_from_dir(base_dir, result, log_fn)
		result["manifest"] = manifest

	if not manifest.is_empty() and manifest.has("files"):
		_apply_manifest_files(result, manifest, log_fn, func(source: String) -> String:
			return base_dir.path_join(source)
		)
		_extract_autoloads(result, manifest)
	else:
		var collected := []
		_collect_gd_files(base_dir, base_dir, collected)
		for item in collected:
			var target_path = result["target_root"].path_join(item["relative"])
			result["files"].append({
				"source": item["source"],
				"target": target_path,
				"source_type": SOURCE_DIR,
			})

	if result["files"].is_empty():
		_append_warning(result, "No .gd files found in folder.")


func _apply_manifest_files(result: Dictionary, manifest: Dictionary, log_fn: Callable, source_resolver: Callable) -> void:
	var files = manifest.get("files", [])
	if typeof(files) != TYPE_ARRAY:
		_append_error(result, "Manifest 'files' must be an array.")
		return

	for entry in files:
		if typeof(entry) != TYPE_DICTIONARY:
			_append_warning(result, "Skipped invalid file entry in manifest.")
			continue
		var source = str(entry.get("source", "")).strip_edges()
		var target = str(entry.get("target", "")).strip_edges()
		if source == "" or target == "":
			_append_warning(result, "Skipped entry with empty source or target.")
			continue
		if _has_path_traversal(source) or _has_path_traversal(target):
			_append_warning(result, "Skipped unsafe path: %s -> %s" % [source, target])
			continue
		var resolved_target = _resolve_target_path(result["target_root"], target, result)
		if resolved_target == "":
			continue
		result["files"].append({
			"source": source_resolver.call(source),
			"target": resolved_target,
			"source_type": result["source_type"],
		})

	if not log_fn.is_null():
		log_fn.call("Manifest files: %d" % result["files"].size())


func _extract_autoloads(result: Dictionary, manifest: Dictionary) -> void:
	if not manifest.has("autoloads"):
		return
	var autoloads = manifest.get("autoloads", [])
	if typeof(autoloads) != TYPE_ARRAY:
		_append_warning(result, "Manifest 'autoloads' must be an array.")
		return
	for entry in autoloads:
		if typeof(entry) != TYPE_DICTIONARY:
			_append_warning(result, "Skipped invalid autoload entry.")
			continue
		var name = str(entry.get("name", "")).strip_edges()
		var path = str(entry.get("path", "")).strip_edges()
		if name == "" or path == "":
			_append_warning(result, "Skipped autoload entry with empty name or path.")
			continue
		if _has_path_traversal(path):
			_append_warning(result, "Skipped unsafe autoload path: %s" % path)
			continue
		var resolved_path = _resolve_target_path(result["target_root"], path, result)
		if resolved_path == "":
			continue
		result["autoloads"].append({
			"name": name,
			"path": resolved_path,
		})


func _apply_zip(plan: Dictionary, backup_root: String, create_backup: bool, result: Dictionary, log_fn: Callable) -> void:
	var zip := ZIPReader.new()
	var open_err := zip.open(plan["package_path"])
	if open_err != OK:
		_append_error(result, "Failed to open zip: %s (error %d)" % [plan["package_path"], open_err])
		return

	var zip_files := {}
	for name in zip.get_files():
		zip_files[name] = true

	for entry in plan["files"]:
		var source = entry["source"]
		var target = entry["target"]
		if not zip_files.has(source):
			_append_error(result, "Missing zip entry: %s" % source)
			continue
		var data: PackedByteArray = zip.read_file(source)
		if _prepare_target(target, backup_root, create_backup, result, log_fn) != OK:
			continue
		if _write_bytes(target, data) == OK:
			result["copied"] += 1
			if not log_fn.is_null():
				log_fn.call("Deployed: %s" % target)
		else:
			_append_error(result, "Failed to write: %s" % target)

	zip.close()


func _apply_dir(plan: Dictionary, backup_root: String, create_backup: bool, result: Dictionary, log_fn: Callable) -> void:
	for entry in plan["files"]:
		var source = entry["source"]
		var target = entry["target"]
		if _prepare_target(target, backup_root, create_backup, result, log_fn) != OK:
			continue
		if _copy_file(source, target) == OK:
			result["copied"] += 1
			if not log_fn.is_null():
				log_fn.call("Deployed: %s" % target)
		else:
			_append_error(result, "Failed to copy: %s" % source)


func _prepare_target(target: String, backup_root: String, create_backup: bool, result: Dictionary, log_fn: Callable) -> int:
	var dir_err = _ensure_dir(target.get_base_dir())
	if dir_err != OK:
		_append_error(result, "Failed to create target folder: %s" % target.get_base_dir())
		return dir_err

	if create_backup and FileAccess.file_exists(target):
		var relative = _safe_relative_path(target)
		var backup_path = backup_root.path_join(relative)
		var backup_dir_err = _ensure_dir(backup_path.get_base_dir())
		if backup_dir_err != OK:
			_append_error(result, "Failed to create backup folder: %s" % backup_path.get_base_dir())
			return backup_dir_err
		if _copy_file(target, backup_path) != OK:
			_append_warning(result, "Failed to backup: %s" % target)
		elif not log_fn.is_null():
			log_fn.call("Backup: %s" % backup_path)
	return OK


func _resolve_target_path(target_root: String, target: String, result: Dictionary) -> String:
	if target.begins_with("res://") or target.begins_with("user://"):
		return target
	if target.begins_with("/") or target.find(":") != -1:
		_append_warning(result, "Skipped unsupported target path: %s" % target)
		return ""
	if _has_path_traversal(target):
		_append_warning(result, "Skipped unsafe target path: %s" % target)
		return ""
	return target_root.path_join(target)


func _read_manifest_from_zip(zip: ZIPReader, files: PackedStringArray, result: Dictionary, log_fn: Callable) -> Dictionary:
	var manifest_path := ""
	for entry in files:
		if entry.get_file() != MANIFEST_NAME:
			continue
		if manifest_path == "" or entry.count("/") < manifest_path.count("/"):
			manifest_path = entry

	if manifest_path == "":
		return {}

	var raw = zip.read_file(manifest_path)
	if raw.is_empty():
		_append_warning(result, "Manifest is empty in zip: %s" % manifest_path)
		return {}
	var manifest = _parse_json(raw.get_string_from_utf8(), result)
	if not manifest.is_empty() and not log_fn.is_null():
		log_fn.call("Manifest loaded: %s" % manifest.get("name", MANIFEST_NAME))
	return manifest


func _read_manifest_from_dir(base_dir: String, result: Dictionary, log_fn: Callable) -> Dictionary:
	var manifest_path = base_dir.path_join(MANIFEST_NAME)
	if not FileAccess.file_exists(manifest_path):
		var found = _find_file_recursive(base_dir, MANIFEST_NAME)
		if found != "":
			manifest_path = found
		else:
			return {}

	var content = FileAccess.get_file_as_string(manifest_path)
	if content == "":
		_append_warning(result, "Manifest is empty: %s" % manifest_path)
		return {}

	var manifest = _parse_json(content, result)
	if not manifest.is_empty() and not log_fn.is_null():
		log_fn.call("Manifest loaded: %s" % manifest.get("name", MANIFEST_NAME))
	return manifest


func _parse_json(content: String, result: Dictionary) -> Dictionary:
	var json := JSON.new()
	var parse_err = json.parse(content)
	if parse_err != OK:
		_append_error(result, "Manifest JSON parse error: %s" % json.get_error_message())
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		_append_error(result, "Manifest JSON must be an object.")
		return {}
	return data


func _collect_gd_files(base_dir: String, current_dir: String, collected: Array) -> void:
	var dir = DirAccess.open(current_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full_path = current_dir.path_join(name)
		if dir.current_is_dir():
			_collect_gd_files(base_dir, full_path, collected)
		else:
			if name.to_lower().ends_with(".gd"):
				var relative = full_path.substr(base_dir.length() + 1)
				collected.append({
					"source": full_path,
					"relative": relative,
				})
		name = dir.get_next()
	dir.list_dir_end()


func _find_file_recursive(base_dir: String, file_name: String) -> String:
	var dir = DirAccess.open(base_dir)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full_path = base_dir.path_join(name)
		if dir.current_is_dir():
			var found = _find_file_recursive(full_path, file_name)
			if found != "":
				dir.list_dir_end()
				return found
		else:
			if name == file_name:
				dir.list_dir_end()
				return full_path
		name = dir.get_next()
	dir.list_dir_end()
	return ""


func _ensure_dir(path: String) -> int:
	if path == "":
		return OK
	if path.begins_with("res://") or path.begins_with("user://"):
		var base = "res://" if path.begins_with("res://") else "user://"
		var rel = path.trim_prefix(base)
		if rel.begins_with("/"):
			rel = rel.substr(1)
		var dir = DirAccess.open(base)
		if dir == null:
			return ERR_CANT_OPEN
		return dir.make_dir_recursive(rel)
	return DirAccess.make_dir_recursive_absolute(path)


func _copy_file(source_path: String, target_path: String) -> int:
	var file = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return ERR_FILE_CANT_READ
	var length = file.get_length()
	var data = file.get_buffer(length)
	file.close()
	return _write_bytes(target_path, data)


func _write_bytes(target_path: String, data: PackedByteArray) -> int:
	var file = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_buffer(data)
	file.close()
	return OK


func _normalize_path(path: String) -> String:
	var trimmed = path.strip_edges()
	if trimmed == "":
		return ""
	var normalized = trimmed.replace("\\", "/")
	if normalized == "res://" or normalized == "user://":
		return normalized
	return normalized.trim_suffix("/")


func _safe_relative_path(target_path: String) -> String:
	if target_path.begins_with("res://"):
		return target_path.trim_prefix("res://")
	if target_path.begins_with("user://"):
		return target_path.trim_prefix("user://")
	return target_path.get_file()


func _is_zip(path: String) -> bool:
	var lower = path.to_lower()
	return lower.ends_with(".zip") or lower.ends_with(".gdpack")


func _is_dir(path: String) -> bool:
	return DirAccess.open(path) != null


func _path_exists(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	return _is_dir(path)


func _is_valid_target_root(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")


func _has_path_traversal(path: String) -> bool:
	return path.find("..") != -1


func _append_error(result: Dictionary, message: String) -> void:
	result["errors"].append(message)


func _append_warning(result: Dictionary, message: String) -> void:
	result["warnings"].append(message)
