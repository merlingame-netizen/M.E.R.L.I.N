#include "merlin_llm.h"

#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "ggml-backend.h"   // b9196: dynamic CPU backend discovery (ggml-cpu-*.dll)

#include <algorithm>
#include <cstdio>    // diagnostic: fprintf(stderr) crash tracing (MERLIN_LLM_TRACE)
#include <cstdlib>   // diagnostic: getenv
#include <exception> // catch std::exception thrown by llama.cpp grammar accept (empty-stack)
#include <string>
#include <thread>
#include <vector>

using namespace godot;

std::atomic<int> MerlinLLM::backend_refs{0};

MerlinLLM::MerlinLLM() {
	if (backend_refs.fetch_add(1) == 0) {
		// b9196 API: must explicitly load arch-specific ggml-cpu-*.dll backends
		// before llama_backend_init. Pre-b9196 builds shipped a single
		// ggml-cpu.dll that auto-registered; b9196 splits it into 15+ variants.
		ggml_backend_load_all();
		llama_backend_init();
	}
	const uint32_t hw_threads = std::thread::hardware_concurrency();
	if (hw_threads > 0) {
		// Gen threads = half cores (leaves CPU for game), batch = all cores (prompt eval)
		n_threads = std::max<int32_t>(2, static_cast<int32_t>(hw_threads / 2));
		n_threads_batch = std::max<int32_t>(2, static_cast<int32_t>(hw_threads));
	}
}

MerlinLLM::~MerlinLLM() {
	if (inference_thread.joinable() && thread_active.load()) {
		// Thread d'inférence bloqué : le détacher (ne JAMAIS join → pas de freeze au quit) et NE RIEN
		// libérer (le thread détaché tient encore ctx/model/backend) → fuite acceptée (le process quitte).
		inference_thread.detach();
		return;
	}
	if (inference_thread.joinable()) {
		inference_thread.join();
	}
	if (ctx) {
		llama_free(ctx);
		ctx = nullptr;
	}
	if (model) {
		llama_model_free(model);   // b9196 rename (was llama_free_model)
		model = nullptr;
	}
	if (backend_refs.fetch_sub(1) == 1) {
		llama_backend_free();
	}
}

void MerlinLLM::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_model", "path"), &MerlinLLM::load_model);
	ClassDB::bind_method(D_METHOD("generate_async", "prompt", "callback"), &MerlinLLM::generate_async);
	ClassDB::bind_method(D_METHOD("poll_result"), &MerlinLLM::poll_result);
	ClassDB::bind_method(D_METHOD("is_generating_now"), &MerlinLLM::is_generating_now);
	ClassDB::bind_method(D_METHOD("cancel_generation"), &MerlinLLM::cancel_generation);
	ClassDB::bind_method(D_METHOD("set_sampling_params", "temperature", "top_p", "max_tokens"), &MerlinLLM::set_sampling_params);
	ClassDB::bind_method(D_METHOD("set_advanced_sampling", "top_k", "repetition_penalty"), &MerlinLLM::set_advanced_sampling);
	ClassDB::bind_method(D_METHOD("set_grammar", "grammar", "root"), &MerlinLLM::set_grammar, DEFVAL("root"));
	ClassDB::bind_method(D_METHOD("clear_grammar"), &MerlinLLM::clear_grammar);
	ClassDB::bind_method(D_METHOD("set_context_size", "n_ctx"), &MerlinLLM::set_context_size);
	ClassDB::bind_method(D_METHOD("set_thread_count", "gen_threads", "batch_threads"), &MerlinLLM::set_thread_count);
	ClassDB::bind_method(D_METHOD("get_model_info"), &MerlinLLM::get_model_info);
	ClassDB::bind_method(D_METHOD("_emit_result"), &MerlinLLM::_emit_result);
}

Error MerlinLLM::load_model(String path) {
	if (ctx) {
		llama_free(ctx);
		ctx = nullptr;
	}
	if (model) {
		llama_model_free(model);   // b9196 rename (was llama_free_model)
		model = nullptr;
	}

	llama_model_params mp = llama_model_default_params();
	model = llama_model_load_from_file(path.utf8().get_data(), mp);   // b9196 rename

	if (!model) {
		UtilityFunctions::printerr("Failed to load model at: ", path);
		return ERR_CANT_OPEN;
	}

	llama_context_params cp = llama_context_default_params();
	cp.n_ctx = n_ctx;
	cp.n_threads = n_threads;
	cp.n_threads_batch = n_threads_batch;
	cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED;  // b9305: AUTO resolves to ENABLED on this build, which (a) ~2x slows CPU gen (0.7 tok/s) and (b) silently crashes the SWA/Gated-Delta-Net + GBNF grammar-decode path on gemma4. DISABLED uses the plain O(n^2) attention — fine for our short prompts and stable under grammar constraints.

	ctx = llama_init_from_model(model, cp);   // b9196 rename (was llama_new_context_with_model)
	if (!ctx) {
		UtilityFunctions::printerr("Failed to create llama context");
		return ERR_CANT_CREATE;
	}

	return OK;
}

void MerlinLLM::generate_async(String prompt, Callable callback) {
	if (is_generating.load()) {
		Dictionary response;
		response["error"] = String("Already generating");
		if (callback.is_valid()) {
			callback.call(response);
		}
		return;
	}
	if (engine_dead.load()) {
		Dictionary response;
		response["error"] = String("LLM disabled (previous generation stuck; restart to recover)");
		if (callback.is_valid()) {
			callback.call(response);
		}
		return;
	}
	if (ctx == nullptr) {
		Dictionary response;
		response["error"] = String("Model not ready");
		if (callback.is_valid()) {
			callback.call(response);
		}
		return;
	}

	if (inference_thread.joinable()) {
		if (thread_active.load()) {
			// Thread précédent ENCORE VIVANT (wedge après un cancel) : ne JAMAIS join sur le thread
			// principal (ça figerait le jeu). On le détache et on désactive le moteur — le contexte
			// llama est tenu par ce thread bloqué, aucune nouvelle génération n'est sûre.
			inference_thread.detach();
			engine_dead.store(true);
			Dictionary response;
			response["error"] = String("Previous generation stuck; LLM disabled (restart to recover)");
			if (callback.is_valid()) {
				callback.call(response);
			}
			return;
		}
		inference_thread.join();  // thread terminé → join instantané (simple cleanup)
	}

	is_generating.store(true);
	thread_active.store(true);
	{
		std::lock_guard<std::mutex> lock(callback_mutex);
		pending_callback = callback;
	}
	{
		std::lock_guard<std::mutex> lock(result_mutex);
		pending_ready = false;
		pending_text.clear();
		pending_error.clear();
	}

	std::string prompt_utf8 = prompt.utf8().get_data();
	inference_thread = std::thread([this, prompt_utf8]() {
		std::string output;
		std::string error_msg;
		bool decode_failed = false;
		llama_sampler * sampler = nullptr;  // declared before try{} so the catch can free it on a thrown exception

		try {

		const llama_vocab * vocab = llama_model_get_vocab(model);
		const int32_t ctx_len = n_ctx;

		const int32_t prompt_cap = static_cast<int32_t>(prompt_utf8.size()) + 8;
		const int32_t token_cap = std::max(ctx_len, prompt_cap);
		std::vector<llama_token> tokens(static_cast<size_t>(token_cap));
		const int32_t n_tok = llama_tokenize(
			vocab,
			prompt_utf8.c_str(),
			static_cast<int32_t>(prompt_utf8.size()),
			tokens.data(),
			static_cast<int32_t>(tokens.size()),
			true,
			false);

		if (n_tok < 0) {
			error_msg = "Failed to tokenize prompt";
		}

		if (error_msg.empty()) {
			int32_t n_tok_final = n_tok;
			if (ctx_len > 0 && n_tok_final > (ctx_len - 4)) {
				const int32_t keep = std::max<int32_t>(ctx_len - 4, 1);
				const int32_t drop = n_tok_final - keep;
				tokens.erase(tokens.begin(), tokens.begin() + drop);
				n_tok_final = keep;
			}
			tokens.resize(static_cast<size_t>(n_tok_final));

			// Phase 6 KV cache prefix reuse — DISABLED v7.7.26 due to a stale-state
			// bug : last_prompt_tokens stores only the PROMPT tokens but the KV cache
			// also contains generated tokens from the previous call, so the prefix
			// match is incoherent with the actual cache contents. On the second call
			// this corrupts the cache and llama_decode hangs indefinitely on Gemma 4
			// E2B. Force full clear + decode every call until the tracker is fixed
			// to also append generated tokens (see code-review HIGH #1).
			llama_memory_t mem = llama_get_memory(ctx);
			int32_t common_prefix = 0;
			(void)last_prompt_tokens;  // intentionally unused while reuse is disabled

			if (common_prefix > 0 && mem) {
				// Remove only the diverging KV entries, keep the common prefix
				llama_memory_seq_rm(mem, 0, common_prefix, -1);
				// Decode only the new (non-cached) tokens
				llama_batch batch = llama_batch_get_one(
					tokens.data() + common_prefix,
					n_tok_final - common_prefix);
				if (batch.logits && batch.n_tokens > 0) {
					batch.logits[batch.n_tokens - 1] = true;
				}
				// b9196: llama_decode positive return codes are non-fatal (1 = KV slot miss).
				// Only treat ret < 0 as fatal. Pre-b9196 we wrongly treated != 0 as fatal,
				// which caused a silent stall on Gemma 4 (larger KV footprint triggers ret=1
				// on first decode of a large prompt).
				const int32_t ret = llama_decode(ctx, batch);
				if (ret < 0) {
					error_msg = "Prompt decode failed (prefix reuse, fatal)";
				}
			} else {
				// Full clear + decode (first call or no common prefix)
				if (mem) {
					llama_memory_clear(mem, true);
					last_prompt_tokens.clear();  // keep cache + tracker in sync
				}
				llama_batch batch = llama_batch_get_one(tokens.data(), n_tok_final);
				if (batch.logits) {
					batch.logits[batch.n_tokens - 1] = true;
				}
				// b9196: see comment above — ret < 0 only.
				const int32_t ret = llama_decode(ctx, batch);
				if (ret < 0) {
					error_msg = "Prompt decode failed (fatal)";
				}
			}

			// Store tokens for next call's prefix comparison
			last_prompt_tokens.assign(tokens.begin(), tokens.begin() + n_tok_final);
		}

		sampler = nullptr;
		if (!decode_failed && error_msg.empty()) {
			llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
			sampler = llama_sampler_chain_init(sparams);

			// GBNF grammar FIRST (Phase 31 — skeleton-crash fix). The grammar must
			// constrain the FULL distribution before top_k/top_p truncate it. Adding
			// it AFTER top_k could leave zero grammatically-valid tokens, which makes
			// llama_sampler_sample crash silently (the skeleton crash : titres/intro
			// without grammar pass, the GBNF skeleton at 170 & 240 tok both died here).
			if (!grammar_str.empty()) {
				llama_sampler * gsmpl = llama_sampler_init_grammar(
					vocab,
					grammar_str.c_str(),
					grammar_root.c_str()
				);
				if (std::getenv("MERLIN_LLM_TRACE") != nullptr) {
					std::fprintf(stderr, "[LLMTRACE] grammar_init ptr=%p glen=%zu root=%s first48=%.48s\n",
						(void *)gsmpl, grammar_str.size(), grammar_root.c_str(), grammar_str.c_str());
					std::fflush(stderr);
				}
				llama_sampler_chain_add(sampler, gsmpl);
			}

			// Then the usual chain on the grammar-filtered logits: penalties -> top_k -> top_p -> temp
			if (repetition_penalty > 1.0f) {
				llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
					/*penalty_last_n=*/64,
					/*penalty_repeat=*/repetition_penalty,
					/*penalty_freq=*/0.0f,
					/*penalty_present=*/0.0f
				));
			}

			if (top_k > 0) {
				llama_sampler_chain_add(sampler, llama_sampler_init_top_k(top_k));
			}

			llama_sampler_chain_add(sampler, llama_sampler_init_top_p(top_p, 1));
			llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));

			llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
		}

		// Diagnostic: env-gated, flushed stderr trace to pin the silent GBNF-decode crash.
		// The last [LLMTRACE] line printed before a hard process death pins the exact
		// crashing call (sample / accept / decode) + iteration + token id. Set
		// MERLIN_LLM_TRACE=1 to enable. No-op otherwise.
		const bool llm_trace = (std::getenv("MERLIN_LLM_TRACE") != nullptr);
		if (llm_trace) {
			std::fprintf(stderr, "[LLMTRACE] loop-start max=%d grammar=%d glen=%zu root=%s eos=%d eot=%d\n",
				max_tokens, (int)!grammar_str.empty(), grammar_str.size(), grammar_root.c_str(),
				(int)llama_vocab_eos(vocab), (int)llama_vocab_eot(vocab));
			std::fflush(stderr);
		}

		if (!decode_failed && error_msg.empty()) {
			int32_t n_past = static_cast<int32_t>(tokens.size());
			for (int i = 0; i < max_tokens; i++) {
				// Cooperative cancel: check if cancel_generation() was called
				if (!is_generating.load()) {
					break;
				}
				if (ctx_len > 0 && n_past >= (ctx_len - 1)) {
					break;
				}
				if (llm_trace) { std::fprintf(stderr, "[LLMTRACE] i=%d pre-sample n_past=%d\n", i, n_past); std::fflush(stderr); }
				llama_token tok = llama_sampler_sample(sampler, ctx, -1);
				if (llm_trace) { std::fprintf(stderr, "[LLMTRACE] i=%d post-sample tok=%d\n", i, (int)tok); std::fflush(stderr); }
				if (tok == llama_vocab_eos(vocab) || tok == llama_vocab_eot(vocab)) {
					break;
				}

				char buf[256] = {};
				const int32_t n = llama_token_to_piece(vocab, tok, buf, static_cast<int32_t>(sizeof(buf)), 0, true);
				if (n > 0) {
					output.append(buf, n);
				}
				if (llm_trace) {
					unsigned char b0 = (n > 0) ? (unsigned char)buf[0] : 0;
					unsigned char b1 = (n > 1) ? (unsigned char)buf[1] : 0;
					std::fprintf(stderr, "[LLMTRACE] i=%d tok=%d piece_n=%d piece='%.*s' hex=%02x,%02x pre-accept\n",
						i, (int)tok, (int)n, (n > 0 ? n : 0), (n > 0 ? buf : ""), b0, b1);
					std::fflush(stderr);
				}

				llama_sampler_accept(sampler, tok);
				if (llm_trace) { std::fprintf(stderr, "[LLMTRACE] i=%d post-accept pre-decode\n", i); std::fflush(stderr); }

				llama_batch next = llama_batch_get_one(&tok, 1);
				if (next.logits) {
					next.logits[0] = true;
				}
				// b9196: ret < 0 only is fatal. ret == 1 means KV slot miss; for the
				// per-token loop we still need to stop because we can't reasonably retry
				// a single token without resetting state. Set a clearer error.
				const int32_t ret = llama_decode(ctx, next);
				if (llm_trace) { std::fprintf(stderr, "[LLMTRACE] i=%d post-decode ret=%d\n", i, (int)ret); std::fflush(stderr); }
				if (ret < 0) {
					decode_failed = true;
					break;
				} else if (ret == 1) {
					error_msg = "KV cache full during generation";
					decode_failed = true;
					break;
				}
				n_past += 1;
			}
		}

		if (sampler) {
			llama_sampler_free(sampler);
			sampler = nullptr;
		}
		} catch (const std::exception & e) {
			// llama.cpp grammar accept throws std::runtime_error ("Unexpected empty
			// grammar stack after accepting piece") when a sampled token empties the
			// grammar stack. Uncaught inside this std::thread it calls std::terminate()
			// and kills the whole game process silently (no GGML_ASSERT, no stderr).
			// Convert it into a graceful error so the GDScript side can fall back.
			error_msg = std::string("LLM exception: ") + e.what();
			if (sampler) { llama_sampler_free(sampler); sampler = nullptr; }
			std::fprintf(stderr, "[MerlinLLM] EXCEPTION in inference thread: %s\n", e.what());
			std::fflush(stderr);
		} catch (...) {
			error_msg = "LLM unknown exception in inference thread";
			if (sampler) { llama_sampler_free(sampler); sampler = nullptr; }
			std::fprintf(stderr, "[MerlinLLM] UNKNOWN EXCEPTION in inference thread\n");
			std::fflush(stderr);
		}

		if (decode_failed && error_msg.empty()) {
			error_msg = "llama_decode failed";
		}

		is_generating.store(false);

		{
			std::lock_guard<std::mutex> lock(result_mutex);
			pending_ready = true;
			if (!error_msg.empty()) {
				pending_error = error_msg;
				pending_text.clear();
			} else {
				pending_text = output;
				pending_error.clear();
			}
		}
		thread_active.store(false);  // le thread a TERMINÉ proprement → join() ultérieur sûr/instantané
	});
}

bool MerlinLLM::poll_result() {
	bool ready = false;
	{
		std::lock_guard<std::mutex> lock(result_mutex);
		ready = pending_ready;
	}
	if (!ready) {
		return false;
	}
	_emit_result();
	return true;
}


void MerlinLLM::_emit_result() {
	Callable cb;
	Dictionary result;
	std::string text;
	std::string error_msg;
	{
		std::lock_guard<std::mutex> lock(callback_mutex);
		cb = pending_callback;
		pending_callback = Callable();
	}
	{
		std::lock_guard<std::mutex> lock(result_mutex);
		text = pending_text;
		error_msg = pending_error;
		pending_text.clear();
		pending_error.clear();
		pending_ready = false;
	}
	if (!error_msg.empty()) {
		result["error"] = String::utf8(error_msg.c_str());
	} else {
		result["text"] = String::utf8(text.c_str());
	}
	if (cb.is_valid()) {
		cb.call(result);
	}
}


bool MerlinLLM::is_generating_now() {
	return is_generating.load();
}

void MerlinLLM::cancel_generation() {
	// Cooperative cancel: token loop checks is_generating flag each iteration
	is_generating.store(false);
}

void MerlinLLM::set_sampling_params(double p_temperature, double p_top_p, int32_t p_max_tokens) {
	temperature = std::clamp(static_cast<float>(p_temperature), 0.1f, 2.0f);
	top_p = std::clamp(static_cast<float>(p_top_p), 0.05f, 1.0f);
	if (p_max_tokens > 0) {
		max_tokens = p_max_tokens;
	}
}

void MerlinLLM::set_advanced_sampling(int32_t p_top_k, double p_repetition_penalty) {
	top_k = std::clamp(p_top_k, 0, 100);
	repetition_penalty = std::clamp(static_cast<float>(p_repetition_penalty), 1.0f, 2.0f);
}

void MerlinLLM::set_grammar(String p_grammar, String p_root) {
	// Strip full-line GBNF comments (optional leading space/tab then '#') before
	// storing. llama.cpp's parser is meant to handle '#' comments, but comment text
	// with multi-byte UTF-8 (em-dash, accented FR) is a parse variable we remove so
	// only the pure rule grammar reaches llama_sampler_init_grammar.
	const std::string raw = p_grammar.utf8().get_data();
	std::string cleaned;
	cleaned.reserve(raw.size());
	size_t i = 0;
	const size_t n = raw.size();
	while (i < n) {
		size_t line_end = raw.find('\n', i);
		if (line_end == std::string::npos) {
			line_end = n;
		}
		size_t j = i;
		while (j < line_end && (raw[j] == ' ' || raw[j] == '\t' || raw[j] == '\r')) {
			j++;
		}
		const bool is_comment_line = (j < line_end && raw[j] == '#');
		if (!is_comment_line) {
			cleaned.append(raw, i, line_end - i);
			cleaned.push_back('\n');
		}
		i = (line_end < n) ? line_end + 1 : n;
	}
	grammar_str = cleaned;
	grammar_root = p_root.utf8().get_data();
}

void MerlinLLM::clear_grammar() {
	grammar_str.clear();
	grammar_root = "root";
}

void MerlinLLM::set_context_size(int32_t p_n_ctx) {
	// Must be called BEFORE load_model (context is created during load)
	n_ctx = std::clamp(p_n_ctx, static_cast<int32_t>(512), static_cast<int32_t>(32768));
}

void MerlinLLM::set_thread_count(int32_t p_gen_threads, int32_t p_batch_threads) {
	n_threads = std::max<int32_t>(1, p_gen_threads);
	n_threads_batch = std::max<int32_t>(1, p_batch_threads);
	// If context exists, update thread counts for next generation
	if (ctx) {
		llama_set_n_threads(ctx, n_threads, n_threads_batch);
	}
}

Dictionary MerlinLLM::get_model_info() {
	Dictionary info;
	info["n_ctx"] = n_ctx;
	info["n_threads"] = n_threads;
	info["n_threads_batch"] = n_threads_batch;
	info["max_tokens"] = max_tokens;
	info["model_loaded"] = (model != nullptr);
	if (model) {
		info["vocab_size"] = static_cast<int64_t>(llama_model_n_params(model));
		info["n_embd"] = llama_model_n_embd(model);
	}
	return info;
}
