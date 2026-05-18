## ═══════════════════════════════════════════════════════════════════════════════
## Native MerlinEmbed probe — Phase 13 rebuild verification
## ═══════════════════════════════════════════════════════════════════════════════
## Mirrors scripts/test/test_native_probe.gd (Phase 4 GO_NATIVE_OK) but for the
## embedding surface added in Phase 13. Pass criteria:
##
##   1. ClassDB.class_exists("MerlinEmbed") == true       (rebuild registered the class)
##   2. nomic-embed-text-Q4_K_M.gguf present in models    (download script ran)
##   3. MerlinEmbed instance created                       (constructor + backend init)
##   4. load_model OK                                      (GGUF parsing + ctx init)
##   5. embed("test") returns 768-dim PackedFloat32Array
##   6. The vector is L2-normalised (||v|| close to 1.0 +/- 1e-3)
##   7. Two embeds of identical text are equal (determinism)
##
## Usage:
##   godot --headless --quit-after 30 res://scenes/TestNativeEmbedProbe.tscn
##
## VERDICT codes (echoed at the bottom):
##   GO_EMBED_OK       : all 7 checks pass
##   NO_CLASS          : class not registered (need to rebuild merlin_llm.dll)
##   NO_GGUF           : embedding model not downloaded
##   LOAD_FAIL         : load_model returned non-OK
##   EMBED_FAIL        : embed() returned empty array
##   DIM_MISMATCH      : returned vector is not 768-dim
##   NOT_NORMALIZED    : ||v|| not within tolerance of 1.0
##   NON_DETERMINISTIC : two identical inputs produced different vectors
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const GGUF_PATH := "res://addons/merlin_llm/models/nomic-embed-text-Q4_K_M.gguf"
const EXPECTED_DIM := 768
const NORM_TOLERANCE := 1e-3


func _ready() -> void:
	print("[NATIVE-EMBED-PROBE] ===============================================")
	print("[NATIVE-EMBED-PROBE]   Phase 13 - MerlinEmbed native probe")
	print("[NATIVE-EMBED-PROBE] ===============================================")

	# Step 1 : class registered ?
	if not ClassDB.class_exists("MerlinEmbed"):
		print("[NATIVE-EMBED-PROBE] MerlinEmbed class NOT registered")
		print("[NATIVE-EMBED-PROBE] Action: rebuild merlin_llm.dll with merlin_embed.cpp")
		_finish("NO_CLASS", 1)
		return
	print("[NATIVE-EMBED-PROBE] MerlinEmbed class registered PASS")

	# Step 2 : GGUF on disk ?
	var globalised := ProjectSettings.globalize_path(GGUF_PATH)
	if not FileAccess.file_exists(GGUF_PATH):
		print("[NATIVE-EMBED-PROBE] GGUF missing at %s" % globalised)
		print("[NATIVE-EMBED-PROBE] Action: pwsh -File addons/merlin_llm/models/download_nomic_embed.ps1")
		_finish("NO_GGUF", 2)
		return
	var file_size: int = FileAccess.get_file_as_bytes(GGUF_PATH).size()
	print("[NATIVE-EMBED-PROBE] GGUF present (%d bytes)" % file_size)

	# Step 3 : instantiate
	var emb = ClassDB.instantiate("MerlinEmbed")
	if emb == null:
		print("[NATIVE-EMBED-PROBE] ClassDB.instantiate returned null")
		_finish("INSTANTIATE_FAIL", 3)
		return
	print("[NATIVE-EMBED-PROBE] MerlinEmbed instance created PASS")

	# Step 4 : load model
	var t_load_start := Time.get_ticks_msec()
	var err = emb.load_model(GGUF_PATH)
	var t_load_ms := Time.get_ticks_msec() - t_load_start
	if err != OK:
		print("[NATIVE-EMBED-PROBE] load_model returned %s (took %d ms)" % [err, t_load_ms])
		_finish("LOAD_FAIL", 4)
		return
	print("[NATIVE-EMBED-PROBE] load_model OK in %d ms PASS" % t_load_ms)
	print("[NATIVE-EMBED-PROBE]   reported dim = %d" % emb.get_dim())

	if emb.get_dim() != EXPECTED_DIM:
		print("[NATIVE-EMBED-PROBE] dim mismatch : got %d, expected %d" % [emb.get_dim(), EXPECTED_DIM])
		_finish("DIM_MISMATCH", 5)
		return

	# Step 5 : embed a sample
	var t_embed_start := Time.get_ticks_msec()
	var vec: PackedFloat32Array = emb.embed("Une marche dans la brume druidique")
	var t_embed_ms := Time.get_ticks_msec() - t_embed_start
	if vec.is_empty():
		print("[NATIVE-EMBED-PROBE] embed() returned empty array")
		_finish("EMBED_FAIL", 6)
		return
	print("[NATIVE-EMBED-PROBE] embed() returned %d floats in %d ms PASS" % [vec.size(), t_embed_ms])
	if vec.size() != EXPECTED_DIM:
		print("[NATIVE-EMBED-PROBE] vec size mismatch : got %d, expected %d" % [vec.size(), EXPECTED_DIM])
		_finish("DIM_MISMATCH", 7)
		return

	# Step 6 : L2-normalised ?
	var sq_sum := 0.0
	for v in vec:
		sq_sum += v * v
	var norm := sqrt(sq_sum)
	print("[NATIVE-EMBED-PROBE] ||v|| = %f" % norm)
	if abs(norm - 1.0) > NORM_TOLERANCE:
		print("[NATIVE-EMBED-PROBE] vector NOT L2-normalised (||v||=%f, tol=%f)" % [norm, NORM_TOLERANCE])
		_finish("NOT_NORMALIZED", 8)
		return
	print("[NATIVE-EMBED-PROBE] L2-normalised PASS")

	# Step 7 : determinism
	var vec2: PackedFloat32Array = emb.embed("Une marche dans la brume druidique")
	var max_delta := 0.0
	for i in vec.size():
		max_delta = max(max_delta, abs(vec[i] - vec2[i]))
	print("[NATIVE-EMBED-PROBE] determinism : max |delta| = %g" % max_delta)
	if max_delta > 1e-5:
		print("[NATIVE-EMBED-PROBE] non-deterministic embedding (delta=%g)" % max_delta)
		_finish("NON_DETERMINISTIC", 9)
		return
	print("[NATIVE-EMBED-PROBE] deterministic PASS")

	_finish("GO_EMBED_OK", 0)


func _finish(verdict: String, exit_code: int) -> void:
	print("[NATIVE-EMBED-PROBE] VERDICT: %s" % verdict)
	get_tree().quit(exit_code)
