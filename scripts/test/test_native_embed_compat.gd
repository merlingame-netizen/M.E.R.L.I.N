## ═══════════════════════════════════════════════════════════════════════════════
## Native MerlinEmbed compat verifier — Phase 13.5
## ═══════════════════════════════════════════════════════════════════════════════
## Validates that the C++ MerlinEmbed output is compatible with the offline
## Ollama-baked vectors in data/ai/cards_index_broceliande.json. Compatibility
## here is defined as :
##   1. Same dim (768)
##   2. High cosine similarity per-text (avg > 0.95, min > 0.90)
##   3. Same top-3 nearest neighbours when used as query against the index
##
## If the verifier reports compat OK, the existing baked index can keep being
## used. If not, the index must be regenerated against the native path via
## tools/embed_reference_cards.py (Sprint 10.1).
##
## Usage:
##   godot --headless --quit-after 90 res://scenes/TestNativeEmbedCompat.tscn
##
## Pre-req:
##   1. merlin_llm.dll rebuilt with merlin_embed.cpp (Phase 13.3)
##   2. nomic-embed-text-Q4_K_M.gguf at addons/merlin_llm/models/
##   3. cards_index_broceliande.json present (Phase 10.1 baked)
##
## VERDICT codes:
##   COMPAT_OK         : all 3 criteria pass
##   NO_NATIVE         : MerlinEmbed unavailable (no rebuild or GGUF)
##   NO_INDEX          : cards_index_broceliande.json missing
##   EMBED_FAIL        : native embed returned empty mid-test
##   LOW_SIMILARITY    : avg cosine < 0.95 OR min < 0.90
##   TOP3_DIVERGENT    : top-3 kNN differs from baked top-3
##
## Output : user://native_embed_compat_<ticks>.json
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const CardsRAGScript = preload("res://addons/merlin_ai/cards_rag.gd")

const INDEX_PATH := "res://data/ai/cards_index_broceliande.json"
const NUM_SAMPLES := 20
const MIN_AVG_COSINE := 0.95
const MIN_PER_SAMPLE_COSINE := 0.90
const REPORT_PATH_FMT := "user://native_embed_compat_%d.json"


func _ready() -> void:
	print("[NATIVE-EMBED-COMPAT] ===============================================")
	print("[NATIVE-EMBED-COMPAT]   Phase 13.5 - native vs baked compat check")
	print("[NATIVE-EMBED-COMPAT] ===============================================")

	# Pre-check: index file present?
	if not FileAccess.file_exists(INDEX_PATH):
		print("[NATIVE-EMBED-COMPAT] cards_index_broceliande.json missing at %s" % INDEX_PATH)
		print("[NATIVE-EMBED-COMPAT] Action: run python tools/embed_reference_cards.py")
		_finish("NO_INDEX", 2, {})
		return

	# Load the baked CardsRAG so we have access to the Ollama-source vectors.
	var rag: Node = CardsRAGScript.new()
	add_child(rag)
	var loaded: bool = rag.load_index(INDEX_PATH)
	if not loaded:
		print("[NATIVE-EMBED-COMPAT] CardsRAG.load_index failed")
		_finish("NO_INDEX", 2, {})
		return
	print("[NATIVE-EMBED-COMPAT] CardsRAG : %d baked vectors, dim=%d" % [rag.count(), rag.dim()])

	# Pre-check: native available?
	if not rag.is_native_embed_available():
		print("[NATIVE-EMBED-COMPAT] MerlinEmbed unavailable - rebuild + GGUF needed")
		_finish("NO_NATIVE", 1, {})
		return

	# Sample N cards from the baked index. Deterministic via simple stride.
	var n_total: int = rag.count()
	var stride: int = max(1, n_total / NUM_SAMPLES)
	var samples: Array = []
	for i in NUM_SAMPLES:
		var row_idx: int = (i * stride) % n_total
		samples.append(row_idx)

	# For each sample, re-embed its summary via native and compare to baked.
	var per_sample: Array = []
	var cosines: Array = []
	var all_top3_match: bool = true
	var t_total_start := Time.get_ticks_msec()

	for i in samples.size():
		var row: int = samples[i]
		var card: Dictionary = _get_card_at_row(rag, row)
		var summary: String = String(card.get("summary", ""))
		if summary.is_empty():
			continue
		var uid: String = String(card.get("card_uid", ""))
		var baked_vec: PackedFloat32Array = rag.card_vector_by_uid(uid)
		if baked_vec.is_empty():
			print("  WARN sample %d : baked vector missing for %s" % [i, uid])
			continue

		# Native embed.
		var t0 := Time.get_ticks_msec()
		var native_vec: PackedFloat32Array = rag.embed_query_native(summary)
		var embed_ms: int = Time.get_ticks_msec() - t0
		if native_vec.is_empty():
			print("  FAIL sample %d : native embed returned empty" % i)
			_finish("EMBED_FAIL", 4, {})
			return

		var dim_match: bool = native_vec.size() == baked_vec.size()
		var cos: float = _cosine(baked_vec, native_vec) if dim_match else 0.0
		cosines.append(cos)

		# Top-3 overlap : kNN query with the native vector vs naive top-3 against baked.
		var native_hits: Array = rag.knn(native_vec, 3)
		var baked_hits: Array = rag.knn(baked_vec, 3)
		var native_uids := {}
		for h in native_hits:
			native_uids[String(h.get("card_uid", ""))] = true
		var top3_overlap: int = 0
		for h in baked_hits:
			if native_uids.has(String(h.get("card_uid", ""))):
				top3_overlap += 1
		if top3_overlap < 3:
			all_top3_match = false

		per_sample.append({
			"card_uid": uid,
			"summary": summary.substr(0, 80),
			"cosine_sim": cos,
			"dim_match": dim_match,
			"top3_overlap": top3_overlap,
			"embed_ms": embed_ms,
		})
		print("  sample %2d  cos=%.4f  top3=%d/3  %dms  %s" % [
			i, cos, top3_overlap, embed_ms, summary.substr(0, 60)])

	var elapsed: int = Time.get_ticks_msec() - t_total_start
	var avg_cos: float = 0.0
	var min_cos: float = 1.0
	var max_cos: float = 0.0
	for c in cosines:
		avg_cos += float(c)
		if float(c) < min_cos:
			min_cos = float(c)
		if float(c) > max_cos:
			max_cos = float(c)
	if cosines.size() > 0:
		avg_cos /= cosines.size()

	var stats := {
		"n_samples": cosines.size(),
		"avg_cosine": avg_cos,
		"min_cosine": min_cos,
		"max_cosine": max_cos,
		"all_top3_match": all_top3_match,
		"total_ms": elapsed,
	}
	print("[NATIVE-EMBED-COMPAT] Stats : avg=%.4f min=%.4f max=%.4f top3_all=%s" % [
		avg_cos, min_cos, max_cos, all_top3_match])

	# Verdict
	var verdict: String = "COMPAT_OK"
	var exit_code: int = 0
	if avg_cos < MIN_AVG_COSINE or min_cos < MIN_PER_SAMPLE_COSINE:
		verdict = "LOW_SIMILARITY"
		exit_code = 5
	elif not all_top3_match:
		verdict = "TOP3_DIVERGENT"
		exit_code = 6

	var report := {
		"run_at": Time.get_datetime_string_from_system(),
		"model": "nomic-embed-text via MerlinEmbed",
		"n_samples": cosines.size(),
		"samples": per_sample,
		"stats": stats,
		"verdict": verdict,
		"thresholds": {"avg": MIN_AVG_COSINE, "per_sample": MIN_PER_SAMPLE_COSINE},
	}
	_finish(verdict, exit_code, report)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _get_card_at_row(rag: Node, row: int) -> Dictionary:
	# The rag node exposes _cards as a private field ; GDScript allows access
	# to underscore-prefixed members by convention only. Pull row N's
	# metadata directly.
	if "_cards" in rag and row < rag._cards.size():
		return rag._cards[row]
	return {}


func _cosine(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.size() == 0:
		return 0.0
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in a.size():
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	var denom: float = sqrt(na) * sqrt(nb)
	if denom == 0.0:
		return 0.0
	return float(dot / denom)


func _finish(verdict: String, exit_code: int, report: Dictionary) -> void:
	print("[NATIVE-EMBED-COMPAT] VERDICT: %s" % verdict)
	if not report.is_empty():
		var path: String = REPORT_PATH_FMT % Time.get_ticks_msec()
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "  ", false))
			f.close()
			print("[NATIVE-EMBED-COMPAT] Report written to %s" % ProjectSettings.globalize_path(path))
	get_tree().quit(exit_code)
