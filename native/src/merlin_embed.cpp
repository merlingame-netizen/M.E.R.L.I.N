// ═══════════════════════════════════════════════════════════════════════════
// MerlinEmbed implementation — Phase 13 native embed surface for MERLIN
// ═══════════════════════════════════════════════════════════════════════════
// Implements the contract declared in merlin_embed.h.
//
// llama.cpp embedding flow :
//   1. llama_backend_init / ggml_backend_load_all (shared with MerlinLLM via
//      a refcount static).
//   2. llama_model_load_from_file with default model params.
//   3. llama_init_from_model with cparams.embeddings = true and
//      cparams.pooling_type = LLAMA_POOLING_TYPE_MEAN so a sequence's
//      per-token outputs are collapsed into one vector.
//   4. llama_tokenize the input text.
//   5. Submit a single batch through llama_decode.
//   6. Pull the pooled embedding with llama_get_embeddings_seq(ctx, 0).
//   7. L2-normalise (if enabled) and return as PackedFloat32Array.
//
// API names match the Sprint 12.4(a) cards_rag.py / .gd vector schema so the
// vectors are bit-compatible with the pre-baked cards_index_broceliande.json.
// ═══════════════════════════════════════════════════════════════════════════

#include "merlin_embed.h"
#include "ggml-backend.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cmath>
#include <cstring>
#include <vector>

using namespace godot;

// Shared with MerlinLLM (declared extern there too). The backend should be
// initialised exactly once for the process even when multiple instances
// (causal + embedding) live side by side.
std::atomic<int> MerlinEmbed::backend_refs{0};


// ───────────────────────────────────────────────────────────────────────────
// Binding registration
// ───────────────────────────────────────────────────────────────────────────

void MerlinEmbed::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_model", "path"), &MerlinEmbed::load_model);
	ClassDB::bind_method(D_METHOD("embed", "text"), &MerlinEmbed::embed);
	ClassDB::bind_method(D_METHOD("get_dim"), &MerlinEmbed::get_dim);
	ClassDB::bind_method(D_METHOD("is_loaded"), &MerlinEmbed::is_loaded);
	ClassDB::bind_method(D_METHOD("get_model_path"), &MerlinEmbed::get_model_path);
	ClassDB::bind_method(D_METHOD("set_n_ctx", "n"), &MerlinEmbed::set_n_ctx);
	ClassDB::bind_method(D_METHOD("set_n_threads", "n"), &MerlinEmbed::set_n_threads);
	ClassDB::bind_method(D_METHOD("set_normalize_output", "v"), &MerlinEmbed::set_normalize_output);
}


// ───────────────────────────────────────────────────────────────────────────
// Lifecycle
// ───────────────────────────────────────────────────────────────────────────

MerlinEmbed::MerlinEmbed() {
	// Lazy backend init : only the first instance loads ggml backends.
	int prev = backend_refs.fetch_add(1);
	if (prev == 0) {
		ggml_backend_load_all();
		llama_backend_init();
	}
}

MerlinEmbed::~MerlinEmbed() {
	if (ctx) {
		llama_free(ctx);
		ctx = nullptr;
	}
	if (model) {
		llama_model_free(model);
		model = nullptr;
	}
	int prev = backend_refs.fetch_sub(1);
	if (prev == 1) {
		llama_backend_free();
	}
}


// ───────────────────────────────────────────────────────────────────────────
// load_model
// ───────────────────────────────────────────────────────────────────────────

Error MerlinEmbed::load_model(String path) {
	model_path = path;

	// Resolve res:// to an absolute path so llama.cpp can open it.
	String resolved = path;
	if (path.begins_with("res://") || path.begins_with("user://")) {
		resolved = ProjectSettings::get_singleton()->globalize_path(path);
	}

	if (!FileAccess::file_exists(resolved)) {
		ERR_PRINT(vformat("MerlinEmbed: GGUF file not found at %s", resolved));
		return ERR_FILE_NOT_FOUND;
	}

	llama_model_params mparams = llama_model_default_params();
	std::string utf8_path = resolved.utf8().get_data();
	model = llama_model_load_from_file(utf8_path.c_str(), mparams);
	if (!model) {
		ERR_PRINT(vformat("MerlinEmbed: failed to load model from %s", resolved));
		return ERR_CANT_OPEN;
	}

	llama_context_params cparams = llama_context_default_params();
	cparams.embeddings = true;
	cparams.pooling_type = LLAMA_POOLING_TYPE_MEAN;
	cparams.n_ctx = n_ctx;
	cparams.n_batch = n_ctx;
	cparams.n_ubatch = n_ctx;
	cparams.n_threads = n_threads;
	cparams.n_threads_batch = n_threads;

	ctx = llama_init_from_model(model, cparams);
	if (!ctx) {
		ERR_PRINT("MerlinEmbed: failed to initialise context");
		llama_model_free(model);
		model = nullptr;
		return ERR_CANT_CREATE;
	}

	n_embd = llama_n_embd(model);
	if (n_embd <= 0) {
		ERR_PRINT(vformat("MerlinEmbed: model reports n_embd=%d", n_embd));
		llama_free(ctx);
		llama_model_free(model);
		ctx = nullptr;
		model = nullptr;
		return ERR_INVALID_DATA;
	}

	UtilityFunctions::print(vformat(
		"[MerlinEmbed] Loaded %s (n_embd=%d, n_ctx=%d)",
		resolved, n_embd, n_ctx));
	return OK;
}


// ───────────────────────────────────────────────────────────────────────────
// embed
// ───────────────────────────────────────────────────────────────────────────

PackedFloat32Array MerlinEmbed::embed(String text) {
	PackedFloat32Array out;
	if (!model || !ctx) {
		ERR_PRINT("MerlinEmbed.embed: model not loaded");
		return out;
	}

	std::lock_guard<std::mutex> lock(embed_mutex);

	// Tokenise the input.
	std::string utf8 = text.utf8().get_data();
	const llama_vocab *vocab = llama_model_get_vocab(model);
	int n_tokens_estimate = static_cast<int>(utf8.size()) + 2;
	std::vector<llama_token> tokens(n_tokens_estimate);
	int n_tokens = llama_tokenize(
		vocab, utf8.c_str(), static_cast<int>(utf8.size()),
		tokens.data(), n_tokens_estimate,
		/*add_special=*/true, /*parse_special=*/true);
	if (n_tokens < 0) {
		// Output buffer too small : retry with the absolute size hint.
		tokens.resize(-n_tokens);
		n_tokens = llama_tokenize(
			vocab, utf8.c_str(), static_cast<int>(utf8.size()),
			tokens.data(), static_cast<int>(tokens.size()),
			true, true);
		if (n_tokens < 0) {
			ERR_PRINT("MerlinEmbed.embed: tokenisation failed");
			return out;
		}
	}
	tokens.resize(n_tokens);
	if (tokens.empty()) {
		ERR_PRINT("MerlinEmbed.embed: input produced 0 tokens");
		return out;
	}
	if (n_tokens > n_ctx) {
		// Truncate to context size ; for short query embeddings we don't
		// expect this branch in practice.
		tokens.resize(n_ctx);
		n_tokens = n_ctx;
	}

	// Reset KV cache for a clean single-sequence decode.
	llama_kv_self_clear(ctx);

	// Build a single-sequence batch.
	llama_batch batch = llama_batch_init(n_tokens, /*embd=*/0, /*n_seq_max=*/1);
	for (int i = 0; i < n_tokens; ++i) {
		batch.token[i] = tokens[i];
		batch.pos[i] = i;
		batch.n_seq_id[i] = 1;
		batch.seq_id[i][0] = 0;
		batch.logits[i] = (i == n_tokens - 1) ? 1 : 0;
	}
	batch.n_tokens = n_tokens;

	int decode_rc = llama_decode(ctx, batch);
	llama_batch_free(batch);
	if (decode_rc < 0) {
		ERR_PRINT(vformat("MerlinEmbed.embed: llama_decode rc=%d", decode_rc));
		return out;
	}

	const float *emb = llama_get_embeddings_seq(ctx, 0);
	if (!emb) {
		ERR_PRINT("MerlinEmbed.embed: no sequence embedding available");
		return out;
	}

	out.resize(n_embd);
	double sq_sum = 0.0;
	for (int i = 0; i < n_embd; ++i) {
		out[i] = emb[i];
		sq_sum += static_cast<double>(emb[i]) * static_cast<double>(emb[i]);
	}
	if (normalize_output) {
		double norm = std::sqrt(sq_sum);
		if (norm > 0.0) {
			for (int i = 0; i < n_embd; ++i) {
				out[i] = static_cast<float>(out[i] / norm);
			}
		}
	}
	return out;
}
