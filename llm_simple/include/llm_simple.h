#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// Forward declarations pour éviter d'inclure llama.h dans le header
struct llama_model;
struct llama_context;
struct llama_sampler;

namespace godot {

class LLMSimple : public Node {
	GDCLASS(LLMSimple, Node)

private:
	llama_model* model;
	llama_context* ctx;
	llama_sampler* sampler;

	int n_ctx;
	bool is_loaded;
	String last_error;

protected:
	static void _bind_methods();

public:
	LLMSimple();
	~LLMSimple();

	// API Godot
	bool load_model(const String& model_path, int context_size = 8192);
	String generate(const String& prompt, int max_tokens = 256);
	void unload_model();

	// Getters
	bool is_model_loaded() const { return is_loaded; }
	String get_last_error() const { return last_error; }
	int get_context_size() const { return n_ctx; }

	// Configuration sampling
	void set_temperature(float temp);
	void set_top_k(int k);
	void set_top_p(float p);
	void set_repeat_penalty(float penalty);
};

} // namespace godot
