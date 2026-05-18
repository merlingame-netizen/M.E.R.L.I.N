## ═══════════════════════════════════════════════════════════════════════════════
## Cards RAG v7.7.32 — In-memory kNN over the card-level embedding index
## ═══════════════════════════════════════════════════════════════════════════════
## Sprint 12.4 in-game port of tools/cards_rag.py (Phase 10.2, commit 7df44b7e).
## Sprint 12.4(B+C) drop runtime HTTP dependency on Ollama : add metadata-only
## retrieval and "compose from already-retrieved hits" path. See PHASE_13 doc
## for the native `embed()` plan (path A).
##
## Public API:
##   load_index(path)                              -> bool
##   knn(qvec, k, filters, exclude_uids, mmr_lambda, mmr_pool, dedup_summary)
##                                                 -> Array[Dictionary] of hits
##   knn_metadata(seed, k, filters, exclude_uids,
##                dedup_summary, weights)          -> Array[Dictionary] of hits
##                                                    (Path B - NO Ollama)
##   compose_route_vec_from_hits(hits, weights)    -> PackedFloat32Array
##                                                    (Path C - reuse stored vectors)
##   compose_route_vec(beat, choices, intro, w)    -> PackedFloat32Array
##   card_vector_by_uid(uid)                       -> PackedFloat32Array
##   embed_query_native(text)                      -> PackedFloat32Array
##                                                    (Path A - Phase 13 native
##                                                    MerlinEmbed via llama.cpp,
##                                                    no Ollama). Returns empty
##                                                    when rebuild/GGUF missing -
##                                                    callers should fall through
##                                                    to Path B or Path C.
##   is_native_embed_available()                   -> bool (Path A precheck)
##   await embed_query(text)                       -> PackedFloat32Array
##                                                    DEPRECATED. Only callable
##                                                    when MERLIN_USE_HTTP_EMBED=1
##                                                    env var is set. Use Path A
##                                                    (embed_query_native) instead.
##   count() / dim() / model()                     -> introspection getters
##
## Caller graph (Sprint 12.4 in-game):
##   - scenes/RuneCeremonyLoader.tscn  (lookahead pre-fetch, planned)
##   - scripts/board_narration/board_narration.gd  (per-beat retrieval, planned)
##   - tools/cards_rag.py continues independently for offline tooling.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name CardsRAG

const VERSION := "7.7.32"
const DEFAULT_INDEX_PATH := "res://data/ai/cards_index_broceliande.json"
const OLLAMA_BASE := "http://localhost:11434"
const EMBED_MODEL_DEFAULT := "nomic-embed-text"
const EMBED_TIMEOUT_S := 30.0
## Phase 13(a) — path to the embedding GGUF used by the native MerlinEmbed class.
## Downloaded via addons/merlin_llm/models/download_nomic_embed.ps1.
const NATIVE_EMBED_MODEL_PATH := "res://addons/merlin_llm/models/nomic-embed-text-Q4_K_M.gguf"


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _model: String = EMBED_MODEL_DEFAULT
var _dim: int = 0
var _count: int = 0
## Flat row-major matrix of L2-normalized vectors. Layout : N rows × dim cols.
## Access vector i via slice [i*_dim, (i+1)*_dim).
var _matrix: PackedFloat32Array = PackedFloat32Array()
## Metadata array, aligned with rows. Each entry = the card's non-vector fields.
var _cards: Array[Dictionary] = []
## HTTPRequest node for Ollama embed_query calls.
var _http: HTTPRequest = null
## Phase 13 — native MerlinEmbed instance. Lazy-loaded on first call to
## embed_query_native. nullptr if class not registered (rebuild missing) or
## GGUF unavailable.
var _native_embedder = null
## One-shot guard so we don't keep retrying a failed init on every call.
var _native_init_attempted: bool = false

signal index_loaded(count: int, dim: int)


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUCTION + LOADING
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Sprint 12.4(B) : HTTPRequest is no longer eagerly created. embed_query
	# constructs it lazily and only if MERLIN_USE_HTTP_EMBED=1 is set.
	pass


## Load + L2-normalize the index from a JSON file.
## Returns true on success.
func load_index(path: String = DEFAULT_INDEX_PATH) -> bool:
	var t_start := Time.get_ticks_msec()
	if not FileAccess.file_exists(path):
		push_error("CardsRAG: index not found at %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("CardsRAG: cannot open %s" % path)
		return false
	var raw_text := f.get_as_text()
	f.close()
	var read_ms := Time.get_ticks_msec() - t_start
	print("[CardsRAG] Read %d bytes in %d ms" % [raw_text.length(), read_ms])

	var parsed = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		push_error("CardsRAG: index JSON is not a dict")
		return false
	var index: Dictionary = parsed
	if index.get("status", "") != "ok":
		push_warning("CardsRAG: index status = %s" % index.get("status", "?"))

	_model = index.get("model", EMBED_MODEL_DEFAULT)
	_dim = int(index.get("dim", 0))
	var raw_cards: Array = index.get("cards", [])
	if _dim <= 0 or raw_cards.is_empty():
		push_error("CardsRAG: invalid dim=%d or empty cards" % _dim)
		return false

	# Build the matrix + cards array. Skip cards whose vector dim doesn't match.
	_matrix.resize(raw_cards.size() * _dim)  # upper bound, will trim
	_cards.clear()
	var write_idx := 0
	for i in raw_cards.size():
		var entry: Dictionary = raw_cards[i]
		var vec_raw = entry.get("vector", null)
		if not (vec_raw is Array) or vec_raw.size() != _dim:
			continue
		# L2 normalize on the fly so cosine = dot product later.
		var sq_sum := 0.0
		for x in vec_raw:
			sq_sum += float(x) * float(x)
		var norm := sqrt(sq_sum)
		if norm <= 0.0:
			norm = 1.0
		var base := write_idx * _dim
		for d in _dim:
			_matrix[base + d] = float(vec_raw[d]) / norm
		# Strip the vector from the metadata copy (saves memory).
		var meta := entry.duplicate(true)
		meta.erase("vector")
		_cards.append(meta)
		write_idx += 1
	# Trim the matrix to the actual loaded count.
	_matrix.resize(write_idx * _dim)
	_count = write_idx

	var total_ms := Time.get_ticks_msec() - t_start
	print("[CardsRAG] Loaded %d cards (%d-dim) in %d ms total" % [_count, _dim, total_ms])
	emit_signal("index_loaded", _count, _dim)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EMBEDDING (Ollama HTTP, async)
# ═══════════════════════════════════════════════════════════════════════════════

## DEPRECATED in Sprint 12.4(B). Use knn_metadata (Path B) or compose_route_vec_from_hits
## (Path C) instead. This method only fires when MERLIN_USE_HTTP_EMBED=1 env var
## is set, to honour the "no Ollama runtime dependency" directive. The native
## replacement is planned in PHASE_13_NATIVE_EMBED.md.
##
## Returns L2-normalized PackedFloat32Array. Empty array on failure or when
## the env var is not set.
func embed_query(text: String) -> PackedFloat32Array:
	if OS.get_environment("MERLIN_USE_HTTP_EMBED") != "1":
		push_warning("CardsRAG.embed_query: HTTP path disabled. Set MERLIN_USE_HTTP_EMBED=1 to opt-in, or use knn_metadata + compose_route_vec_from_hits (Sprint 12.4 B+C).")
		return PackedFloat32Array()
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = EMBED_TIMEOUT_S
		add_child(_http)
	var payload := JSON.stringify({"model": _model, "prompt": text})
	var headers := ["Content-Type: application/json"]
	var url := OLLAMA_BASE + "/api/embeddings"
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		push_error("CardsRAG: HTTPRequest start failed (%s)" % err)
		return PackedFloat32Array()
	var result: Array = await _http.request_completed
	# result = [result_code, response_code, headers, body]
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) >= 400:
		push_error("CardsRAG: Ollama embed failed (result=%s code=%s)" % [result[0], result[1]])
		return PackedFloat32Array()
	var body: PackedByteArray = result[3]
	var resp_text := body.get_string_from_utf8()
	var resp_parsed = JSON.parse_string(resp_text)
	if not (resp_parsed is Dictionary):
		push_error("CardsRAG: Ollama response is not a dict")
		return PackedFloat32Array()
	var vec_raw: Array = resp_parsed.get("embedding", [])
	if vec_raw.size() != _dim:
		push_warning("CardsRAG: embed dim mismatch got=%d expected=%d" % [vec_raw.size(), _dim])
	var out := PackedFloat32Array()
	out.resize(vec_raw.size())
	var sq_sum := 0.0
	for i in vec_raw.size():
		var v := float(vec_raw[i])
		out[i] = v
		sq_sum += v * v
	var norm := sqrt(sq_sum)
	if norm > 0.0:
		for i in out.size():
			out[i] = out[i] / norm
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# PATH A - NATIVE EMBED (MerlinEmbed C++ class, Phase 13)
# ═══════════════════════════════════════════════════════════════════════════════

## True if a native MerlinEmbed instance can be (or has been) initialised.
## Returns false when the rebuild is missing or the GGUF is not on disk.
func is_native_embed_available() -> bool:
	if _native_embedder != null:
		return true
	if not ClassDB.class_exists("MerlinEmbed"):
		return false
	if not FileAccess.file_exists(NATIVE_EMBED_MODEL_PATH):
		return false
	return true


## Embed text via the native llama.cpp MerlinEmbed class (Phase 13).
## Returns L2-normalised PackedFloat32Array of dim values, or empty array
## if the native path is unavailable (no rebuild / no GGUF / load failed).
##
## Caller pattern (Sprint 12.4(d) consumers like RuneCeremonyLoader) :
##   var v := rag.embed_query_native(text)
##   if v.is_empty():
##       # Fall back to Path B (metadata kNN) or Path C (compose_from_hits).
##       # Optionally retry with await rag.embed_query(text) if MERLIN_USE_HTTP_EMBED=1.
##       ...
func embed_query_native(text: String) -> PackedFloat32Array:
	if _native_embedder == null and not _native_init_attempted:
		_native_init_attempted = true
		_native_embedder = _init_native_embedder()
	if _native_embedder == null:
		return PackedFloat32Array()
	var vec: PackedFloat32Array = _native_embedder.embed(text)
	if vec.is_empty():
		push_warning("CardsRAG.embed_query_native: MerlinEmbed.embed returned empty")
	return vec


## Internal : create + load the MerlinEmbed instance. Returns null on failure.
func _init_native_embedder():
	if not ClassDB.class_exists("MerlinEmbed"):
		push_warning("CardsRAG.embed_query_native: MerlinEmbed class not registered (rebuild merlin_llm.dll)")
		return null
	if not FileAccess.file_exists(NATIVE_EMBED_MODEL_PATH):
		push_warning("CardsRAG.embed_query_native: GGUF missing at %s (run download_nomic_embed.ps1)" % NATIVE_EMBED_MODEL_PATH)
		return null
	var inst = ClassDB.instantiate("MerlinEmbed")
	if inst == null:
		push_error("CardsRAG.embed_query_native: ClassDB.instantiate returned null")
		return null
	# Reparent under the rag node so the instance lives as long as we do.
	if inst is Node:
		add_child(inst)
	var err = inst.load_model(NATIVE_EMBED_MODEL_PATH)
	if err != OK:
		push_error("CardsRAG.embed_query_native: load_model returned %s" % err)
		if inst is Node:
			inst.queue_free()
		return null
	# Verify dim matches the loaded index dim if we have one.
	if _dim > 0 and inst.get_dim() != _dim:
		push_warning(
			"CardsRAG.embed_query_native: native dim %d != index dim %d - retrieval may fail"
			% [inst.get_dim(), _dim]
		)
	return inst


# ═══════════════════════════════════════════════════════════════════════════════
# RETRIEVAL
# ═══════════════════════════════════════════════════════════════════════════════

## kNN search. Returns Array[Dictionary] of card-hit dicts ordered by score desc.
##
## Optional params (defaults match the Python API) :
##   filters       : {type, rarity, pole, emotion} - exact match against card field
##   exclude_uids  : Array[String] of card_uids to skip
##   mmr_lambda    : float [0,1] - if set, MMR re-rank top mmr_pool candidates
##   mmr_pool      : int - candidate pool size for MMR
##   dedup_summary : bool - if true, keep only top-scoring per unique summary string
func knn(
	query_vec: PackedFloat32Array,
	k: int = 5,
	filters: Dictionary = {},
	exclude_uids: Array = [],
	mmr_lambda: float = -1.0,
	mmr_pool: int = 32,
	dedup_summary: bool = false,
) -> Array:
	if _count == 0 or query_vec.size() != _dim:
		return []

	# Normalize query (defensive - embed_query already does it).
	var q := PackedFloat32Array()
	q.resize(_dim)
	var sq_sum := 0.0
	for i in _dim:
		var v := query_vec[i]
		q[i] = v
		sq_sum += v * v
	var qnorm := sqrt(sq_sum)
	if qnorm > 0.0:
		for i in _dim:
			q[i] = q[i] / qnorm

	# Compute dot products row by row (cosine since both sides L2-normalized).
	var scores := PackedFloat32Array()
	scores.resize(_count)
	for row in _count:
		var base := row * _dim
		var dot := 0.0
		for d in _dim:
			dot += _matrix[base + d] * q[d]
		scores[row] = float(dot)

	# Build sorted index list (descending score).
	var order: Array = []
	for i in _count:
		order.append(i)
	order.sort_custom(func(a, b): return scores[a] > scores[b])

	# Build candidate pool with filters + dedup + exclude_uids.
	var excl := {}
	for u in exclude_uids:
		excl[String(u)] = true
	var wanted_type := _coerce_set(filters.get("type"))
	var wanted_rarity := _coerce_set(filters.get("rarity"))
	var wanted_pole := _coerce_set(filters.get("pole"))
	if wanted_pole.is_empty():
		wanted_pole = _coerce_set(filters.get("pole_in"))
	var wanted_emotion := _coerce_set(filters.get("emotion"))

	var candidates: Array = []
	var seen_summaries := {}
	var candidate_limit: int = max(k, mmr_pool) if mmr_lambda >= 0.0 else k

	for idx in order:
		var card: Dictionary = _cards[idx]
		var uid := String(card.get("card_uid", ""))
		if excl.has(uid):
			continue
		if not wanted_type.is_empty() and not wanted_type.has(card.get("type", "")):
			continue
		if not wanted_rarity.is_empty() and not wanted_rarity.has(card.get("rarity", "")):
			continue
		if not wanted_pole.is_empty() and not wanted_pole.has(card.get("pole", "")):
			continue
		if not wanted_emotion.is_empty() and not wanted_emotion.has(card.get("emotion", "")):
			continue
		if dedup_summary:
			var summary := String(card.get("summary", "")).strip_edges()
			if seen_summaries.has(summary):
				continue
			seen_summaries[summary] = true
		candidates.append(idx)
		if candidates.size() >= candidate_limit:
			break

	var picked: Array
	if mmr_lambda >= 0.0 and candidates.size() > k:
		picked = _mmr_select(q, candidates, k, mmr_lambda)
	else:
		picked = candidates.slice(0, k)

	# Build hit dicts.
	var hits: Array = []
	for idx in picked:
		hits.append(_build_hit(int(idx), float(scores[idx])))
	return hits


## MMR (Maximal Marginal Relevance) re-ranking - matches Python _mmr_select.
##   score = lambda * sim(q, c) - (1 - lambda) * max sim(c, p)  for p in picked.
func _mmr_select(
	query_vec: PackedFloat32Array,
	candidate_indices: Array,
	k: int,
	lambda_: float,
) -> Array:
	var lam: float = clamp(lambda_, 0.0, 1.0)
	if candidate_indices.is_empty():
		return []

	# Pre-compute sim(q, c) for each candidate.
	var sim_q: Array = []
	for ci in candidate_indices:
		var base := int(ci) * _dim
		var dot := 0.0
		for d in _dim:
			dot += _matrix[base + d] * query_vec[d]
		sim_q.append(float(dot))

	# First pick : highest sim_q.
	var first_local: int = 0
	var best: float = float(sim_q[0])
	for i in sim_q.size():
		var cur: float = float(sim_q[i])
		if cur > best:
			best = cur
			first_local = i
	var picked_local: Array = [first_local]
	var remaining: Array = []
	for i in candidate_indices.size():
		if i != first_local:
			remaining.append(i)

	while not remaining.is_empty() and picked_local.size() < k:
		var best_remaining := -1
		var best_score: float = -INF
		for r in remaining:
			var redundancy: float = -INF
			var r_base := int(candidate_indices[r]) * _dim
			for p_local in picked_local:
				var p_base := int(candidate_indices[p_local]) * _dim
				var dot := 0.0
				for d in _dim:
					dot += _matrix[r_base + d] * _matrix[p_base + d]
				if dot > redundancy:
					redundancy = dot
			var score: float = lam * sim_q[r] - (1.0 - lam) * redundancy
			if score > best_score:
				best_score = score
				best_remaining = r
		if best_remaining < 0:
			break
		picked_local.append(best_remaining)
		remaining.erase(best_remaining)

	var out: Array = []
	for p_local in picked_local:
		out.append(candidate_indices[p_local])
	return out


## Build the hit Dictionary for index `idx` at score `score`.
func _build_hit(idx: int, score: float) -> Dictionary:
	var card: Dictionary = _cards[idx]
	return {
		"card_uid": card.get("card_uid", ""),
		"score": score,
		"scenario_id": card.get("scenario_id", ""),
		"card_id": card.get("card_id", ""),
		"type": card.get("type", ""),
		"rarity": card.get("rarity", ""),
		"pole": card.get("pole", ""),
		"emotion": card.get("emotion", ""),
		"summary": card.get("summary", ""),
		"options": card.get("options", []),
		"branch_label": card.get("branch_label", ""),
		"archetype_name": card.get("archetype_name", ""),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# ROUTE VECTOR COMPOSITION (mirrors Python compose_route_vec)
# ═══════════════════════════════════════════════════════════════════════════════

## Blend a beat vector with recent choice vectors and intro vector into a
## personalised query vector. Defaults : 0.5 * beat + 0.3 * mean(choices) + 0.2 * intro.
func compose_route_vec(
	beat_vec: PackedFloat32Array,
	recent_choice_vecs: Array = [],
	intro_vec: PackedFloat32Array = PackedFloat32Array(),
	weights: Array = [0.5, 0.3, 0.2],
) -> PackedFloat32Array:
	var w_beat: float = float(weights[0]) if weights.size() > 0 else 0.5
	var w_choice: float = float(weights[1]) if weights.size() > 1 else 0.3
	var w_intro: float = float(weights[2]) if weights.size() > 2 else 0.2

	if beat_vec.size() != _dim:
		return PackedFloat32Array()

	var out := PackedFloat32Array()
	out.resize(_dim)
	for i in _dim:
		out[i] = beat_vec[i] * w_beat

	if not recent_choice_vecs.is_empty():
		var n := recent_choice_vecs.size()
		for cvec in recent_choice_vecs:
			var c: PackedFloat32Array = cvec
			if c.size() != _dim:
				continue
			for i in _dim:
				out[i] += (c[i] * w_choice) / float(n)

	if intro_vec.size() == _dim:
		for i in _dim:
			out[i] += intro_vec[i] * w_intro

	# L2 normalize
	var sq_sum := 0.0
	for v in out:
		sq_sum += v * v
	var norm := sqrt(sq_sum)
	if norm > 0.0:
		for i in _dim:
			out[i] = out[i] / norm
	return out


# ═══════════════════════════════════════════════════════════════════════════════
# PATH B - METADATA-ONLY RETRIEVAL (no embeddings, no HTTP)
# ═══════════════════════════════════════════════════════════════════════════════

## Default weights for the metadata-score retrieval. The Monte-Carlo balance
## pass (Sprint 12.5e) confirmed these are the dominant discriminators after
## the pool's 97% string-duplication is collapsed.
const _META_WEIGHTS_DEFAULT := {
	"pole_match": 3.0,
	"emotion_match": 2.0,
	"type_match": 1.5,
	"rarity_match": 1.0,
	"archetype_match": 2.5,
	"faction_pref_match": 1.5,
}


## Metadata-only kNN. Given a `seed` Dictionary describing what you want
## (any subset of pole/emotion/type/rarity/archetype_hint/faction_pref/
## tag_history), returns the top-k cards by weighted metadata score.
## No Ollama, no HTTP, no embeddings - just the structured fields the pool
## already carries.
##
## Params:
##   seed           : Dictionary
##     pole          : "Ordre"|"Chaos"|"Liminal"|"Neutre"
##     emotion       : one of the 5 bible emotions
##     type          : "NARRATIVE"|"EVENT"|"MERLIN_DIRECT"
##     rarity        : "COMMUNE"|"RARE"|"EPIQUE"
##     archetype     : exact archetype_name string
##     faction_pref  : Dictionary[faction -> weight in 0..1] (player's lean)
##     tag_history   : Array[String] of tags already acquired (gates)
##   k              : int (default 5)
##   filters        : same shape as knn() filters
##   exclude_uids   : Array[String]
##   dedup_summary  : bool (default true - the right default for the dup-heavy pool)
##   weights        : optional override of _META_WEIGHTS_DEFAULT
##
## Returns Array[Dictionary] of hits with `metadata_score` field instead of `score`.
func knn_metadata(
	seed: Dictionary,
	k: int = 5,
	filters: Dictionary = {},
	exclude_uids: Array = [],
	dedup_summary: bool = true,
	weights: Dictionary = {},
) -> Array:
	if _count == 0:
		return []
	var w := _META_WEIGHTS_DEFAULT.duplicate()
	for key in weights.keys():
		w[key] = weights[key]

	var seed_pole := String(seed.get("pole", ""))
	var seed_emotion := String(seed.get("emotion", ""))
	var seed_type := String(seed.get("type", ""))
	var seed_rarity := String(seed.get("rarity", ""))
	var seed_archetype := String(seed.get("archetype", ""))
	var seed_faction_pref: Dictionary = seed.get("faction_pref", {})
	var seed_tag_history: Array = seed.get("tag_history", [])
	var tag_set := {}
	for t in seed_tag_history:
		tag_set[String(t)] = true

	# Compute scores for every card.
	var scored: Array = []
	scored.resize(_count)
	for i in _count:
		var card: Dictionary = _cards[i]
		var s := 0.0
		if seed_pole != "" and String(card.get("pole", "")) == seed_pole:
			s += float(w["pole_match"])
		if seed_emotion != "" and String(card.get("emotion", "")) == seed_emotion:
			s += float(w["emotion_match"])
		if seed_type != "" and String(card.get("type", "")) == seed_type:
			s += float(w["type_match"])
		if seed_rarity != "" and String(card.get("rarity", "")) == seed_rarity:
			s += float(w["rarity_match"])
		if seed_archetype != "" and String(card.get("archetype_name", "")) == seed_archetype:
			s += float(w["archetype_match"])
		# faction_pref : sum of player's lean on each option's primary_faction
		if not seed_faction_pref.is_empty():
			var options: Array = card.get("options", [])
			for opt in options:
				var faction := String(opt.get("primary_faction", ""))
				if seed_faction_pref.has(faction):
					s += float(seed_faction_pref[faction]) * float(w["faction_pref_match"])
		# Tiny tiebreaker so ordering is deterministic per seed contents.
		scored[i] = {"idx": i, "score": s, "uid": String(card.get("card_uid", ""))}

	# Sort desc by score, stable by uid for determinism.
	scored.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return String(a["uid"]) < String(b["uid"]))

	# Apply filters + exclude + dedup_summary.
	var excl := {}
	for u in exclude_uids:
		excl[String(u)] = true
	var wanted_type := _coerce_set(filters.get("type"))
	var wanted_rarity := _coerce_set(filters.get("rarity"))
	var wanted_pole := _coerce_set(filters.get("pole"))
	if wanted_pole.is_empty():
		wanted_pole = _coerce_set(filters.get("pole_in"))
	var wanted_emotion := _coerce_set(filters.get("emotion"))

	var hits: Array = []
	var seen_summaries := {}
	for entry in scored:
		var idx: int = entry["idx"]
		var card: Dictionary = _cards[idx]
		var uid := String(card.get("card_uid", ""))
		if excl.has(uid):
			continue
		if not wanted_type.is_empty() and not wanted_type.has(card.get("type", "")):
			continue
		if not wanted_rarity.is_empty() and not wanted_rarity.has(card.get("rarity", "")):
			continue
		if not wanted_pole.is_empty() and not wanted_pole.has(card.get("pole", "")):
			continue
		if not wanted_emotion.is_empty() and not wanted_emotion.has(card.get("emotion", "")):
			continue
		if dedup_summary:
			var summary := String(card.get("summary", "")).strip_edges()
			if seen_summaries.has(summary):
				continue
			seen_summaries[summary] = true
		var hit := _build_hit(idx, float(entry["score"]))
		hit["metadata_score"] = float(entry["score"])
		hits.append(hit)
		if hits.size() >= k:
			break
	return hits


# ═══════════════════════════════════════════════════════════════════════════════
# PATH C - ROUTE VECTOR FROM ALREADY-RETRIEVED HITS (no new embeddings)
# ═══════════════════════════════════════════════════════════════════════════════

## Compose a query vector from cards already in the index by averaging their
## stored vectors with `weights`. No Ollama, no embed_query - we reuse what
## was precomputed offline.
##
## `hits` : Array of Dictionaries that each contain at least a `card_uid` key.
##          Typically the output of knn_metadata or the player's chosen-card
##          history.
## `weights` : Array of floats parallel to `hits`. If shorter than `hits`,
##             missing entries default to 1.0. The resulting vector is
##             L2-normalised before return.
##
## Returns the composed PackedFloat32Array, or empty if no hit had a stored vector.
func compose_route_vec_from_hits(
	hits: Array,
	weights: Array = [],
) -> PackedFloat32Array:
	if hits.is_empty() or _dim == 0:
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	out.resize(_dim)
	var n_used := 0
	for i in hits.size():
		var uid := String(hits[i].get("card_uid", ""))
		if uid.is_empty():
			continue
		var row := _row_for_uid(uid)
		if row < 0:
			continue
		var w: float = 1.0
		if i < weights.size():
			w = float(weights[i])
		var base := row * _dim
		for d in _dim:
			out[d] += _matrix[base + d] * w
		n_used += 1
	if n_used == 0:
		return PackedFloat32Array()
	# L2 normalise
	var sq_sum := 0.0
	for v in out:
		sq_sum += v * v
	var norm := sqrt(sq_sum)
	if norm > 0.0:
		for d in _dim:
			out[d] = out[d] / norm
	return out


## Return the stored row vector for a card_uid, or empty PackedFloat32Array.
func card_vector_by_uid(uid: String) -> PackedFloat32Array:
	var row := _row_for_uid(uid)
	if row < 0:
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	out.resize(_dim)
	var base := row * _dim
	for d in _dim:
		out[d] = _matrix[base + d]
	return out


func _row_for_uid(uid: String) -> int:
	# Linear scan ; the index is loaded once at boot and used per-beat at
	# 4-6 ms anyway, so a 2-3 ms uid-to-row lookup is acceptable.
	# Sprint 13 will add a uid_to_row Dictionary if this becomes a hotspot.
	for i in _count:
		if String(_cards[i].get("card_uid", "")) == uid:
			return i
	return -1


# ═══════════════════════════════════════════════════════════════════════════════
# INTROSPECTION
# ═══════════════════════════════════════════════════════════════════════════════

func count() -> int:
	return _count


func dim() -> int:
	return _dim


func model() -> String:
	return _model


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Normalise a filter value (string or array) into a Dictionary acting as a set.
func _coerce_set(value) -> Dictionary:
	var out := {}
	if value == null:
		return out
	if value is String:
		if not String(value).is_empty():
			out[value] = true
		return out
	if value is Array:
		for item in value:
			var s := String(item)
			if not s.is_empty():
				out[s] = true
		return out
	out[String(value)] = true
	return out
