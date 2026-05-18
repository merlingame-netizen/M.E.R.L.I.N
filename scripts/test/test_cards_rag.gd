## ═══════════════════════════════════════════════════════════════════════════════
## Test harness for CardsRAG (Sprint 12.4 in-game port validation)
## ═══════════════════════════════════════════════════════════════════════════════
## Validates the kNN port without depending on the 50MB production index or
## Ollama by building a 6-card / 4-dim synthetic index on disk and exercising :
##   1. load_index : verify count + dim + L2-normalize applied
##   2. knn no filter : top-k by cosine, ordered desc
##   3. knn + filter type : only matching cards in result
##   4. knn + exclude_uids : excluded card absent from result
##   5. knn + dedup_summary : duplicate summary collapsed
##   6. knn + mmr_lambda : MMR picks return k distinct
##   7. compose_route_vec : returns L2-normalized vector of correct dim
##   8. Failure paths : wrong dim query returns empty
##
## Usage: godot --headless --quit-after 5 res://scenes/TestCardsRAG.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const CardsRAGScript = preload("res://addons/merlin_ai/cards_rag.gd")

const TEST_INDEX_PATH := "user://test_cards_index.json"
const DIM := 4

var _failures: int = 0


func _ready() -> void:
	print("[TEST] CardsRAG harness starting...")
	_write_synthetic_index()

	var rag: Node = CardsRAGScript.new()
	add_child(rag)

	_phase_1_load(rag)
	_phase_2_knn_basic(rag)
	_phase_3_knn_filter(rag)
	_phase_4_knn_exclude(rag)
	_phase_5_knn_dedup_summary(rag)
	_phase_6_knn_mmr(rag)
	_phase_7_compose_route(rag)
	_phase_8_failure_paths(rag)

	if _failures == 0:
		print("[TEST] ALL PHASES PASSED")
		get_tree().quit(0)
	else:
		printerr("[TEST] %d FAILURES" % _failures)
		get_tree().quit(1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  %s" % msg)
	else:
		printerr("  FAIL  %s" % msg)
		_failures += 1


func _write_synthetic_index() -> void:
	# 6 cards, 4-dim vectors with deliberate clustering :
	#   - cards 0+1+2 cluster near [1,0,0,0] (Liminal/fascination)
	#   - cards 3+4 near [0,1,0,0]           (Chaos/peur)
	#   - card 5 near [0,0,1,0]              (Ordre/sagesse)
	# Cards 1+2 share the same summary string (for dedup_summary test).
	var index := {
		"model": "test-embed",
		"dim": DIM,
		"status": "ok",
		"count": 6,
		"cards": [
			{
				"card_uid": "c1", "scenario_id": "s1", "card_id": "card_a",
				"type": "NARRATIVE", "rarity": "COMMUNE",
				"pole": "Liminal", "emotion": "fascination",
				"summary": "Une lueur danse au-dessus d'une racine.",
				"options": [],
				"vector": [0.95, 0.10, 0.05, 0.30],
			},
			{
				"card_uid": "c2", "scenario_id": "s1", "card_id": "card_b",
				"type": "NARRATIVE", "rarity": "COMMUNE",
				"pole": "Liminal", "emotion": "fascination",
				"summary": "Un seuil murmure dans la brume.",
				"options": [],
				"vector": [0.90, 0.20, 0.10, 0.20],
			},
			{
				"card_uid": "c3", "scenario_id": "s2", "card_id": "card_b",
				"type": "EVENT", "rarity": "RARE",
				"pole": "Liminal", "emotion": "fascination",
				"summary": "Un seuil murmure dans la brume.",
				"options": [],
				"vector": [0.85, 0.30, 0.10, 0.20],
			},
			{
				"card_uid": "c4", "scenario_id": "s3", "card_id": "card_c",
				"type": "NARRATIVE", "rarity": "COMMUNE",
				"pole": "Chaos", "emotion": "peur",
				"summary": "Le vent change. Le sentier devient hostile.",
				"options": [],
				"vector": [0.10, 0.95, 0.05, 0.15],
			},
			{
				"card_uid": "c5", "scenario_id": "s3", "card_id": "card_d",
				"type": "EVENT", "rarity": "EPIQUE",
				"pole": "Chaos", "emotion": "peur",
				"summary": "Une tempete s'abat sur la cime.",
				"options": [],
				"vector": [0.20, 0.90, 0.10, 0.05],
			},
			{
				"card_uid": "c6", "scenario_id": "s4", "card_id": "card_e",
				"type": "MERLIN_DIRECT", "rarity": "EPIQUE",
				"pole": "Ordre", "emotion": "sagesse",
				"summary": "Le chene parle. Sa voix est de pierre.",
				"options": [],
				"vector": [0.05, 0.10, 0.95, 0.15],
			},
		],
	}
	var f := FileAccess.open(TEST_INDEX_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "  ", false))
	f.close()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASES
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_1_load(rag: Node) -> void:
	print("[TEST] Phase 1 - load_index")
	var ok: bool = rag.load_index(TEST_INDEX_PATH)
	_assert(ok, "load_index returned true")
	_assert(rag.count() == 6, "count == 6 (got %d)" % rag.count())
	_assert(rag.dim() == DIM, "dim == %d (got %d)" % [DIM, rag.dim()])
	_assert(rag.model() == "test-embed", "model name preserved")


func _phase_2_knn_basic(rag: Node) -> void:
	print("[TEST] Phase 2 - kNN basic (cluster Liminal)")
	var q := _vec([1.0, 0.0, 0.0, 0.0])
	var hits: Array = rag.knn(q, 3)
	_assert(hits.size() == 3, "3 hits returned (got %d)" % hits.size())
	if hits.size() >= 1:
		# c1 and c2 have nearly-tied dim-0 components after L2 norm; either is OK.
		_assert(
			hits[0].card_uid in ["c1", "c2"],
			"top hit is in Liminal cluster (got %s)" % hits[0].card_uid,
		)
		_assert(float(hits[0].score) > 0.8, "top score > 0.8 (got %f)" % float(hits[0].score))
	if hits.size() >= 2:
		_assert(float(hits[0].score) >= float(hits[1].score), "score[0] >= score[1]")
	if hits.size() >= 3:
		_assert(float(hits[1].score) >= float(hits[2].score), "score[1] >= score[2]")


func _phase_3_knn_filter(rag: Node) -> void:
	print("[TEST] Phase 3 - kNN with filter type=EVENT")
	var q := _vec([1.0, 0.0, 0.0, 0.0])
	var hits: Array = rag.knn(q, 3, {"type": "EVENT"})
	_assert(hits.size() <= 2, "filter EVENT yields <=2 hits (got %d)" % hits.size())
	for h in hits:
		_assert(h.type == "EVENT", "all hits are type=EVENT")


func _phase_4_knn_exclude(rag: Node) -> void:
	print("[TEST] Phase 4 - kNN with exclude_uids")
	var q := _vec([1.0, 0.0, 0.0, 0.0])
	var hits: Array = rag.knn(q, 5, {}, ["c1"])
	for h in hits:
		_assert(h.card_uid != "c1", "c1 excluded from result")


func _phase_5_knn_dedup_summary(rag: Node) -> void:
	print("[TEST] Phase 5 - kNN dedup_summary collapses duplicates")
	var q := _vec([1.0, 0.0, 0.0, 0.0])
	var raw_hits: Array = rag.knn(q, 5)
	var raw_dup_count := 0
	for h in raw_hits:
		if h.summary == "Un seuil murmure dans la brume.":
			raw_dup_count += 1
	_assert(raw_dup_count == 2, "raw kNN sees 2 copies of dup summary (got %d)" % raw_dup_count)
	var dedup_hits: Array = rag.knn(q, 5, {}, [], -1.0, 32, true)
	var dedup_dup_count := 0
	for h in dedup_hits:
		if h.summary == "Un seuil murmure dans la brume.":
			dedup_dup_count += 1
	_assert(dedup_dup_count == 1, "dedup_summary collapses to 1 (got %d)" % dedup_dup_count)


func _phase_6_knn_mmr(rag: Node) -> void:
	print("[TEST] Phase 6 - kNN MMR returns k distinct")
	var q := _vec([0.5, 0.5, 0.5, 0.5])
	var hits: Array = rag.knn(q, 3, {}, [], 0.6, 6, false)
	_assert(hits.size() == 3, "MMR returns k=3")
	var uids := {}
	for h in hits:
		_assert(not uids.has(h.card_uid), "MMR hit %s is distinct" % h.card_uid)
		uids[h.card_uid] = true


func _phase_7_compose_route(rag: Node) -> void:
	print("[TEST] Phase 7 - compose_route_vec normalisation")
	var beat := _vec([1.0, 0.0, 0.0, 0.0])
	var intro := _vec([0.0, 0.0, 1.0, 0.0])
	var route: PackedFloat32Array = rag.compose_route_vec(beat, [], intro, [0.5, 0.0, 0.5])
	_assert(route.size() == DIM, "route vec has correct dim")
	var sq_sum := 0.0
	for v in route:
		sq_sum += v * v
	var norm := sqrt(sq_sum)
	_assert(abs(norm - 1.0) < 1e-4, "route vec is L2-normalized (norm=%f)" % norm)


func _phase_8_failure_paths(rag: Node) -> void:
	print("[TEST] Phase 8 - failure paths")
	var wrong_dim := PackedFloat32Array()
	wrong_dim.resize(DIM + 2)
	var hits: Array = rag.knn(wrong_dim, 3)
	_assert(hits.is_empty(), "wrong-dim query returns empty array")
	var q := _vec([1.0, 0.0, 0.0, 0.0])
	var hits2: Array = rag.knn(q, 1, {})
	_assert(hits2.size() == 1, "empty filter dict OK")


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _vec(values: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(values.size())
	for i in values.size():
		out[i] = float(values[i])
	return out
