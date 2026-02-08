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
		n_threads = std::max<int32_t>(2, static_cast<int32_t>(hw_threads));
		n_threads_batch = n_threads;
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

			llama_memory_t mem = llama_get_memory(ctx);
			if (mem) {
				llama_memory_clear(mem, true);
			}
			llama_batch batch = llama_batch_get_one(tokens.data(), static_cast<int32_t>(tokens.size()));
			if (batch.logits) {
				batch.logits[batch.n_tokens - 1] = true;
			}

			if (llama_decode(ctx, batch) != 0) {
				error_msg = "Prompt decode failed";
			}
		}

		llama_sampler * sampler = nullptr;
		if (!decode_failed && error_msg.empty()) {
			llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
			sampler = llama_sampler_chain_init(sparams);

			// Ordre recommandé pour llama.cpp: penalties -> top_k -> top_p -> temp
			if (repetition_penalty > 1.0f) {
				llama_sampler_chain_add(sampler, llama_sampler_init_penalties(
					/*n_vocab=*/llama_n_vocab(model),
					/*special_eos_id=*/llama_vocab_eos(vocab),
					/*linefeed_id=*/llama_vocab_nl(vocab),
					/*penalty_last_n=*/64,
					/*penalty_repeat=*/repetition_penalty,
					/*penalty_freq=*/0.0f,
					/*penalty_present=*/0.0f,
					/*penalize_nl=*/false,
					/*ignore_eos=*/false
				));
			}

			if (top_k > 0) {
				llama_sampler_chain_add(sampler, llama_sampler_init_top_k(top_k));
			}

			llama_sampler_chain_add(sampler, llama_sampler_init_top_p(top_p, 1));
			llama_sampler_chain_add(sampler, llama_sampler_init_temp(temperature));
			llama_sampler_chain_add(sampler, llama_sampler_init_greedy());
		}

		if (!decode_failed && error_msg.empty()) {
			int32_t n_past = static_cast<int32_t>(tokens.size());
			for (int i = 0; i < max_tokens; i++) {
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
	// Placeholder: llama.cpp does not expose cooperative cancel in this minimal wrapper.
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
