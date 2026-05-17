## ═══════════════════════════════════════════════════════════════════════════════
## Test Native Probe — does merlin_llm GDExtension load a Gemma 4 GGUF?
## ═══════════════════════════════════════════════════════════════════════════════
## Hard verdict for Phase 1: can the existing Jan-15 llama.dll handle the brand-
## new gemma4 architecture in unsloth's E2B GGUF, or does the C++ runtime need
## a rebuild against a recent llama.cpp commit?
##
## Steps:
##   1. Instantiate MerlinLLM (GDExtension class)
##   2. Call load_model on res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf
##   3. If load fails -> NO-GO (rebuild required)
##   4. If load OK   -> try a Gemma-formatted generation -> GO if non-empty output
##
## Exit code: 0 = GO (native runtime works on Gemma 4), 1 = NO-GO (rebuild needed),
##            2 = setup error (Extension missing etc.)
##
## Writes user://native_probe_result.json with the verdict + timings + raw output.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const MODEL_PATH := "res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf"
const RESULT_PATH := "user://native_probe_result.json"
# Forbidden in output (proves clean_response strip works on native path too)
const FORBIDDEN_TOKENS := [
	"<start_of_turn>", "</start_of_turn>",
	"<end_of_turn>",   "</end_of_turn>",
]
const GENERATE_TIMEOUT_MS := 90000


var _llm: RefCounted = null
var _result: Dictionary = {
	"phase": "init",
	"ext_loaded": false,
	"gguf_exists": false,
	"load_ok": false,
	"load_ms": 0,
	"generate_ok": false,
	"generate_ms": 0,
	"output_text": "",
	"output_len": 0,
	"leak_found": [],
	"errors": [],
	"verdict": "UNKNOWN",
}


func _ready() -> void:
	_log("═══════════════════════════════════════")
	_log("  NATIVE PROBE — merlin_llm + Gemma 4 GGUF")
	_log("═══════════════════════════════════════")

	# 1) GDExtension class available?
	_result.phase = "ext_check"
	if not ClassDB.class_exists("MerlinLLM"):
		_fail(2, "MerlinLLM class not registered (GDExtension load failed)")
		return
	_result.ext_loaded = true
	_log("MerlinLLM class registered")

	# 2) GGUF on disk?
	_result.gguf_exists = FileAccess.file_exists(MODEL_PATH)
	if not _result.gguf_exists:
		_fail(2, "GGUF missing at %s — download required" % MODEL_PATH)
		return
	var gguf_size: int = FileAccess.get_file_as_bytes(MODEL_PATH).size() if false else 0
	# Faster size check
	var f: FileAccess = FileAccess.open(MODEL_PATH, FileAccess.READ)
	if f:
		gguf_size = f.get_length()
		f.close()
	_log("GGUF present (%d bytes)" % gguf_size)

	# 3) Instantiate + load
	_result.phase = "load"
	var klass = ClassDB.instantiate("MerlinLLM")
	if klass == null:
		_fail(2, "ClassDB.instantiate(MerlinLLM) returned null")
		return
	_llm = klass
	_log("MerlinLLM instance created")

	# llama.cpp expects a native OS path, not Godot's res:// URI.
	var abs_path: String = ProjectSettings.globalize_path(MODEL_PATH)
	_log("Resolving %s -> %s" % [MODEL_PATH, abs_path])
	var t0: int = Time.get_ticks_msec()
	var err = _llm.load_model(abs_path)
	_result.load_ms = Time.get_ticks_msec() - t0
	if err != OK:
		_fail(1, "load_model returned error %s (probably unsupported architecture for Jan-15 llama.dll)" % str(err))
		return
	_result.load_ok = true
	_log("load_model OK in %dms" % _result.load_ms)

	# 4) Generate — Gemma turn format hand-rolled (no native chat template)
	_result.phase = "generate"
	if _llm.has_method("set_sampling_params"):
		_llm.set_sampling_params(0.7, 0.9, 80)
	if _llm.has_method("set_context_size"):
		_llm.set_context_size(1024)
	var prompt := "<start_of_turn>user\nReponds en une phrase druidique: nemeton.<end_of_turn>\n<start_of_turn>model\n"
	var done := {"ok": false, "text": "", "error": ""}
	var t1: int = Time.get_ticks_msec()
	_llm.generate_async(prompt, func(res: Dictionary) -> void:
		done.ok = bool(res.get("ok", false))
		done.text = String(res.get("text", ""))
		done.error = String(res.get("error", ""))
	)

	# Poll up to GENERATE_TIMEOUT_MS
	while not done.ok and done.error == "" and Time.get_ticks_msec() - t1 < GENERATE_TIMEOUT_MS:
		if _llm.has_method("poll_result"):
			_llm.poll_result()
		await get_tree().create_timer(0.1).timeout

	_result.generate_ms = Time.get_ticks_msec() - t1
	if not done.ok:
		_fail(1, "generate failed after %dms: %s" % [_result.generate_ms, done.error])
		return
	_result.output_text = done.text
	_result.output_len = done.text.length()
	_result.generate_ok = true
	for tok in FORBIDDEN_TOKENS:
		if done.text.find(tok) >= 0:
			_result.leak_found.append(tok)
	_log("Generated %d chars in %dms" % [_result.output_len, _result.generate_ms])
	_log("  -> %s" % done.text.substr(0, 200))

	# 5) Verdict
	if _result.load_ok and _result.generate_ok and _result.output_len >= 10:
		_result.verdict = "GO_NATIVE_OK"
	else:
		_result.verdict = "NO_GO_REBUILD"
	_result.phase = "done"
	_save()
	_log("═══════════════════════════════════════")
	_log("  VERDICT: %s" % _result.verdict)
	_log("═══════════════════════════════════════")
	get_tree().quit(0 if _result.verdict == "GO_NATIVE_OK" else 1)


func _fail(code: int, msg: String) -> void:
	_log("[FAIL] %s" % msg)
	_result.errors.append(msg)
	_result.verdict = "NO_GO_REBUILD" if code == 1 else "SETUP_ERROR"
	_save()
	get_tree().quit(code)


func _save() -> void:
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_result, "  "))
		f.close()


func _log(msg: String) -> void:
	print("[NATIVE-PROBE] %s" % msg)
