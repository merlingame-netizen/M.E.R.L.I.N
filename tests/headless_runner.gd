extends SceneTree
## Headless test runner — auto-discovers and executes all test_*.gd files.
##
## Output to stdout:
##   { "total": N, "passed": M, "failed": [...], "errors": [...] }
##
## Exit code: 0 if all tests pass, 1 if any fail or error.


const TEST_DIRS: Array[String] = ["res://tests/", "res://scripts/test/"]

var _total: int = 0
var _passed: int = 0
var _failed: Array[String] = []
var _errors: Array[String] = []


func _initialize() -> void:
	# Give the engine a frame to settle before running tests.
	await process_frame
	_run_all_tests()


func _run_all_tests() -> void:
	var test_files := _discover_test_files()
	for path in test_files:
		_run_file(path)
	_print_results()
	quit(1 if (_failed.size() > 0 or _errors.size() > 0) else 0)


func _discover_test_files() -> Array[String]:
	var results: Array[String] = []
	for test_dir in TEST_DIRS:
		var dir := DirAccess.open(test_dir)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.begins_with("test_") and fname.ends_with(".gd"):
				results.append(test_dir + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	if results.is_empty():
		_errors.append("No test files found in: " + ", ".join(TEST_DIRS))
	results.sort()
	return results


func _run_file(path: String) -> void:
	var script: Script = load(path)
	if script == null:
		_errors.append("Failed to load script: " + path)
		return

	# Skip scripts that don't extend RefCounted (e.g. GUT tests extending Node/Control)
	var base: Script = script
	var is_refcounted := false
	while base != null:
		if base.get_instance_base_type() == &"RefCounted":
			is_refcounted = true
			break
		base = base.get_base_script()
	if not is_refcounted:
		return

	var instance: RefCounted = script.new()
	var method_list := instance.get_method_list()

	for method_info in method_list:
		var method_name: String = method_info["name"]
		if not method_name.begins_with("test_"):
			continue
		_total += 1
		var label: String = path.get_file() + "::" + method_name
		_call_test(instance, method_name, label)


func _call_test(instance: RefCounted, method_name: String, label: String) -> void:
	# GDScript 4 does not expose a clean per-call error hook, so tests signal
	# failure by returning false. push_error() output is captured at the Python
	# layer by parsing "SCRIPT ERROR" / "ERROR" lines in combined stdout/stderr.
	var result: Variant = instance.call(method_name)
	if result is bool and result == false:
		_failed.append(label)
	else:
		_passed += 1


func _print_results() -> void:
	var report := {
		"total": _total,
		"passed": _passed,
		"failed": _failed,
		"errors": _errors,
	}
	# Print JSON to stdout so the Python adapter can parse it.
	print(JSON.stringify(report))
