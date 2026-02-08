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

class MerlinLLM : public godot::RefCounted {
	GDCLASS(MerlinLLM, godot::RefCounted)

private:
	llama_model *model = nullptr;
	llama_context *ctx = nullptr;
	std::thread inference_thread;
	std::atomic<bool> is_generating{false};
	std::mutex callback_mutex;
	godot::Callable pending_callback;
	std::mutex result_mutex;
	std::string pending_text;
	std::string pending_error;
	bool pending_ready = false;
	static std::atomic<int> backend_refs;
	int32_t max_tokens = 256;
	int32_t n_threads = 4;
	int32_t n_threads_batch = 4;
	int32_t n_ctx = 8192;  // Augmenté de 2048 à 8192 (aligné avec Colab)
	float temperature = 0.7f;
	float top_p = 0.9f;
	int32_t top_k = 50;  // Nouveau: diversité sampling
	float repetition_penalty = 1.1f;  // Nouveau: anti-répétition

protected:
	static void _bind_methods();

public:
	MerlinLLM();
	~MerlinLLM();

	godot::Error load_model(godot::String path);
	void generate_async(godot::String prompt, godot::Callable callback);
	bool poll_result();
	bool is_generating_now();
	void cancel_generation();
	void set_sampling_params(double p_temperature, double p_top_p, int32_t p_max_tokens);
	void set_advanced_sampling(int32_t p_top_k, double p_repetition_penalty);

private:
	void _emit_result();
};
