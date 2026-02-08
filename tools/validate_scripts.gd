@tool
extends EditorScript
## Script Validator Tool
## Run from Editor: Script > Run (Ctrl+Shift+X)
## Scans all .gd files for common type inference issues

const SCRIPTS_PATH := "res://scripts/"

func _run() -> void:
	print("=" .repeat(60))
	print("GDScript Validator - Scanning for type inference issues...")
	print("=" .repeat(60))

	var errors: Array[String] = []
	var warnings: Array[String] = []

	# Scan all scripts
	var scripts := _find_all_scripts(SCRIPTS_PATH)
	print("Found %d scripts to validate" % scripts.size())

	for script_path in scripts:
		var issues := _validate_script(script_path)
		errors.append_array(issues.errors)
		warnings.append_array(issues.warnings)

	# Report
	print("")
	print("=" .repeat(60))
	print("VALIDATION RESULTS")
	print("=" .repeat(60))

	if errors.is_empty() and warnings.is_empty():
		print("All scripts passed validation!")
	else:
		if not errors.is_empty():
			print("")
			print("ERRORS (%d):" % errors.size())
			for err in errors:
				print("  - %s" % err)

		if not warnings.is_empty():
			print("")
			print("WARNINGS (%d):" % warnings.size())
			for warn in warnings:
				print("  - %s" % warn)

	print("")
	print("=" .repeat(60))


func _find_all_scripts(path: String) -> Array[String]:
	var scripts: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return scripts

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			scripts.append_array(_find_all_scripts(full_path))
		elif file_name.ends_with(".gd"):
			scripts.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	return scripts


func _validate_script(path: String) -> Dictionary:
	var result := {"errors": [] as Array[String], "warnings": [] as Array[String]}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.errors.append("%s: Cannot open file" % path)
		return result

	var line_num := 0
	while not file.eof_reached():
		line_num += 1
		var line := file.get_line()

		# Check for problematic patterns
		_check_const_indexing(path, line_num, line, result)
		_check_dict_access(path, line_num, line, result)
		_check_expression_inference(path, line_num, line, result)

	file.close()
	return result


func _check_const_indexing(path: String, line_num: int, line: String, result: Dictionary) -> void:
	# Pattern: var x := CONST_NAME[
	var regex := RegEx.new()
	regex.compile(r"var\s+\w+\s*:=\s*[A-Z_]+\[")
	if regex.search(line):
		result.errors.append("%s:%d - Const array/dict indexing needs explicit type" % [path, line_num])


func _check_dict_access(path: String, line_num: int, line: String, result: Dictionary) -> void:
	# Pattern: var x := some_dict[key] or var x := some_array[index]
	# Only flag if it looks like a variable (lowercase) followed by [
	var regex := RegEx.new()
	regex.compile(r"var\s+\w+\s*:=\s*\w+\.\w+\[")
	if regex.search(line):
		result.warnings.append("%s:%d - Dictionary/array member access may need explicit type" % [path, line_num])


func _check_expression_inference(path: String, line_num: int, line: String, result: Dictionary) -> void:
	# Pattern: var x := (expression with %)
	# String formatting can cause inference issues
	var regex := RegEx.new()
	regex.compile(r'var\s+\w+\s*:=\s*"[^"]*"\s*%')
	if regex.search(line):
		result.warnings.append("%s:%d - String format expression may need explicit type" % [path, line_num])
