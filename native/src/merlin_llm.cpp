#include "merlin_llm.h"

#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <string>
#include <thread>
#include <vector>

using namespace godot;

std::atomic<int> MerlinLLM::backend_refs{0};

MerlinLLM::MerlinLLM() {
	if (backend_refs.fetch_add(1) == 0) {
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
	if (inference_thread.joinable()) {
		inference_thread.join();
	}
	if (ctx) {
		llama_free(ctx);
		ctx = nullptr;
	}
	if (model) {
		llama_free_model(model);
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
		llama_free_model(model);
		model = nullptr;
	}

	llama_model_params mp = llama_model_default_params();
	model = llama_load_model_from_file(path.utf8().get_data(), mp);

	if (!model) {
		UtilityFunctions::printerr("Failed to load model at: ", path);
		return ERR_CANT_OPEN;
	}

	llama_context_params cp = llama_context_default_params();
	cp.n_ctx = n_ctx;
	cp.n_threads = n_threads;
	cp.n_threads_batch = n_threads_batch;
	cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;  // Phase 6: ~10-15% speedup on prompt eval

	ctx = llama_new_context_with_model(model, cp);
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
	if (ctx == nullptr) {
		Dictionary response;
		response["error"] = String("Model not ready");
		if (callback.is_valid()) {
			callback.call(response);
		}
		return;
	}

	if (inference_thread.joinable()) {
		inference_thread.join();
	}

	is_generating.store(true);
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

			// Phase 6: KV cache prefix reuse — skip re-encoding shared system prompt
			llama_memory_t mem = llama_get_memory(ctx);
			int32_t common_prefix = 0;
			if (mem && !last_prompt_tokens.empty()) {
				const int32_t max_check = std::min(
					static_cast<int32_t>(last_prompt_tokens.size()),
					n_tok_final);
				for (int32_t i = 0; i < max_check; i++) {
					if (tokens[static_cast<size_t>(i)] == last_prompt_tokens[static_cast<size_t>(i)]) {
						common_prefix = i + 1;
					} else {
						break;
					}
				}
			}

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
				if (llama_decode(ctx, batch) != 0) {
					error_msg = "Prompt decode failed (prefix reuse)";
				}
			} else {
				// Full clear + decode (first call or no common prefix)
				if (mem) {
					llama_memory_clear(mem, true);
				}
				llama_batch batch = llama_batch_get_one(tokens.data(), n_tok_final);
				if (batch.logits) {
					batch.logits[batch.n_tokens - 1] = true;
				}
				if (llama_decode(ctx, batch) != 0) {
					error_msg = "Prompt decode failed";
				}
			}

			// Store tokens for next call's prefix comparison
			last_prompt_tokens.assign(tokens.begin(), tokens.begin() + n_tok_final);
		}

		llama_sampler * sampler = nullptr;
		if (!decode_failed && error_msg.empty()) {
			llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
			sampler = llama_sampler_chain_init(sparams);

			// Ordre recommandé pour llama.cpp: penalties -> top_k -> top_p -> temp
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

			// GBNF Grammar constrained decoding (Phase 30)
			if (!grammar_str.empty()) {
				llama_sampler_chain_add(sampler, llama_sampler_init_grammar(
					vocab,
					grammar_str.c_str(),
					grammar_root.c_str()
				));
			}

			llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
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
				llama_token tok = llama_sampler_sample(sampler, ctx, -1);
				if (tok == llama_vocab_eos(vocab) || tok == llama_vocab_eot(vocab)) {
					break;
				}

				char buf[256] = {};
				const int32_t n = llama_token_to_piece(vocab, tok, buf, static_cast<int32_t>(sizeof(buf)), 0, true);
				if (n > 0) {
					output.append(buf, n);
				}

				llama_sampler_accept(sampler, tok);

				llama_batch next = llama_batch_get_one(&tok, 1);
				if (next.logits) {
					next.logits[0] = true;
				}
				if (llama_decode(ctx, next) != 0) {
					decode_failed = true;
					break;
				}
				n_past += 1;
			}
		}

		if (sampler) {
			llama_sampler_free(sampler);
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
	grammar_str = p_grammar.utf8().get_data();
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
