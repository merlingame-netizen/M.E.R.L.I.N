#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/callable.hpp>
#include "llama.h"
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class MerlinLLM : public godot::RefCounted {
	GDCLASS(MerlinLLM, godot::RefCounted)

private:
	llama_model *model = nullptr;
	llama_context *ctx = nullptr;
	std::thread inference_thread;
	std::atomic<bool> is_generating{false};
	std::atomic<bool> thread_active{false};  // true tant que le thread d'inférence VIT réellement (distinct de is_generating que cancel baisse trop tôt)
	std::atomic<bool> engine_dead{false};     // génération précédente bloquée → LLM désactivé proprement (anti-freeze du thread principal)
	std::mutex callback_mutex;
	godot::Callable pending_callback;
	std::mutex result_mutex;
	std::mutex stream_mutex;       // protège stream_buffer, écrit par le fil d'inférence
	std::string stream_buffer;     // texte écrit depuis le dernier poll_stream()
	std::string pending_text;
	std::string pending_error;
	bool pending_ready = false;
	// Compteurs de llama.cpp du DERNIER appel, protégés par result_mutex comme le texte : le
	// thread d'inférence les écrit, le thread principal les lit dans _emit_result.
	double perf_p_eval_ms = 0.0;   // temps d'évaluation du prompt
	double perf_eval_ms = 0.0;     // temps d'écriture
	int32_t perf_n_p_eval = 0;     // tokens de prompt évalués
	int32_t perf_n_eval = 0;       // tokens écrits
	static std::atomic<int> backend_refs;
	std::vector<llama_token> last_prompt_tokens;  // KV cache prefix reuse
	int32_t max_tokens = 256;
	int32_t n_threads = 4;
	int32_t n_threads_batch = 4;
	int32_t n_ctx = 2048;  // Optimized: 32768→2048 (KV cache 1.3GB→160MB, 3-4x speedup)
	float temperature = 0.7f;
	float top_p = 0.9f;
	int32_t top_k = 50;  // Nouveau: diversité sampling
	float repetition_penalty = 1.1f;  // Nouveau: anti-répétition
	std::string grammar_str;  // GBNF grammar for constrained decoding
	std::string grammar_root = "root";  // Grammar root rule name

protected:
	static void _bind_methods();

public:
	MerlinLLM();
	~MerlinLLM();

	godot::Error load_model(godot::String path);
	void generate_async(godot::String prompt, godot::Callable callback);
	bool poll_result();
	godot::String poll_stream();
	bool is_generating_now();
	void cancel_generation();
	void set_sampling_params(double p_temperature, double p_top_p, int32_t p_max_tokens);
	void set_advanced_sampling(int32_t p_top_k, double p_repetition_penalty);
	void set_grammar(godot::String p_grammar, godot::String p_root = "root");
	void clear_grammar();
	void set_context_size(int32_t p_n_ctx);
	void set_thread_count(int32_t p_gen_threads, int32_t p_batch_threads);
	godot::Dictionary get_model_info();

private:
	void _emit_result();
};
