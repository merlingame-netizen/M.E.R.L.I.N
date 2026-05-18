// ═══════════════════════════════════════════════════════════════════════════
// MerlinEmbed — native llama.cpp-based embedding class for MERLIN
// ═══════════════════════════════════════════════════════════════════════════
// Phase 13 (Sprint 12.4 follow-up) per docs/10_llm/PHASE_13_NATIVE_EMBED.md.
//
// Removes the runtime HTTP dependency on Ollama for embeddings. Loads a
// dedicated embedding GGUF (nomic-embed-text-Q4_K_M.gguf, ~137 MB) via the
// llama.cpp embedding API (pooling_type=MEAN, embeddings=true) and returns
// L2-normalized 768-dim vectors as PackedFloat32Array, bit-compatible with
// the offline-baked vectors in data/ai/cards_index_broceliande.json.
//
// Sibling class to MerlinLLM (which handles causal generation). Separate
// instance because :
//   - Different GGUF, different context shape (n_ctx=512 vs 2048+)
//   - Pooling type LLAMA_POOLING_TYPE_MEAN (causal model uses NONE)
//   - Lifecycle is load-once-at-boot vs hot-reload-per-run
//
// GDScript usage (after rebuild):
//   var emb := ClassDB.instantiate("MerlinEmbed")
//   emb.load_model("res://addons/merlin_llm/models/nomic-embed-text-Q4_K_M.gguf")
//   var vec : PackedFloat32Array = emb.embed("druide dans la brume")
//   # vec.size() == 768, L2-normalised
// ═══════════════════════════════════════════════════════════════════════════

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include "llama.h"
#include <atomic>
#include <mutex>
#include <string>

class MerlinEmbed : public godot::RefCounted {
	GDCLASS(MerlinEmbed, godot::RefCounted)

private:
	llama_model *model = nullptr;
	llama_context *ctx = nullptr;
	int32_t n_embd = 0;          // embedding dimensionality from the model
	int32_t n_ctx = 512;         // context window for the embedder
	int32_t n_threads = 4;
	bool normalize_output = true;
	std::mutex embed_mutex;      // serialises embed() calls on a shared ctx
	static std::atomic<int> backend_refs;  // shared with MerlinLLM (llama backend init)
	godot::String model_path;

protected:
	static void _bind_methods();

public:
	MerlinEmbed();
	~MerlinEmbed();

	// Load the embedding GGUF. Returns OK on success.
	godot::Error load_model(godot::String path);

	// Embed `text` and return the L2-normalized PackedFloat32Array.
	// Empty array on failure (model not loaded, tokenise error, decode error).
	// Thread-safe : serialised internally via embed_mutex.
	godot::PackedFloat32Array embed(godot::String text);

	// Introspection helpers (matches the Python API shape).
	int get_dim() const { return n_embd; }
	bool is_loaded() const { return model != nullptr; }
	godot::String get_model_path() const { return model_path; }

	// Sampling / context configuration (light defaults are usually fine).
	void set_n_ctx(int32_t n) { if (n > 0) n_ctx = n; }
	void set_n_threads(int32_t n) { if (n > 0) n_threads = n; }
	void set_normalize_output(bool v) { normalize_output = v; }
};
