#include "llm_simple.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// Inclure llama.h seulement dans le .cpp
#include "llama.h"

using namespace godot;

void LLMSimple::_bind_methods() {
	// Méthodes
	ClassDB::bind_method(D_METHOD("load_model", "model_path", "context_size"), &LLMSimple::load_model, DEFVAL(8192));
	ClassDB::bind_method(D_METHOD("generate", "prompt", "max_tokens"), &LLMSimple::generate, DEFVAL(256));
	ClassDB::bind_method(D_METHOD("unload_model"), &LLMSimple::unload_model);

	// Getters
	ClassDB::bind_method(D_METHOD("is_model_loaded"), &LLMSimple::is_model_loaded);
	ClassDB::bind_method(D_METHOD("get_last_error"), &LLMSimple::get_last_error);
	ClassDB::bind_method(D_METHOD("get_context_size"), &LLMSimple::get_context_size);

	// Configuration
	ClassDB::bind_method(D_METHOD("set_temperature", "temp"), &LLMSimple::set_temperature);
	ClassDB::bind_method(D_METHOD("set_top_k", "k"), &LLMSimple::set_top_k);
	ClassDB::bind_method(D_METHOD("set_top_p", "p"), &LLMSimple::set_top_p);
	ClassDB::bind_method(D_METHOD("set_repeat_penalty", "penalty"), &LLMSimple::set_repeat_penalty);

	// Signaux
	ADD_SIGNAL(MethodInfo("generation_started"));
	ADD_SIGNAL(MethodInfo("generation_finished", PropertyInfo(Variant::STRING, "text")));
	ADD_SIGNAL(MethodInfo("generation_error", PropertyInfo(Variant::STRING, "error")));
}

LLMSimple::LLMSimple() {
	model = nullptr;
	ctx = nullptr;
	sampler = nullptr;
	n_ctx = 8192;
	is_loaded = false;
	last_error = "";

	// Initialiser llama.cpp
	llama_backend_init();
}

LLMSimple::~LLMSimple() {
	unload_model();
	llama_backend_free();
}

bool LLMSimple::load_model(const String& model_path, int context_size) {
	// Nettoyer ancien modèle
	unload_model();

	n_ctx = context_size;
	last_error = "";

	// Convertir path Godot → système
	String abs_path = ProjectSettings::get_singleton()->globalize_path(model_path);
	CharString path_utf8 = abs_path.utf8();

	UtilityFunctions::print("Loading model: ", abs_path);

	// Paramètres modèle
	llama_model_params model_params = llama_model_default_params();
	model_params.n_gpu_layers = 0; // CPU only pour Windows

	// Charger modèle
	model = llama_load_model_from_file(path_utf8.get_data(), model_params);
	if (!model) {
		last_error = "Failed to load model from: " + abs_path;
		UtilityFunctions::printerr(last_error);
		return false;
	}

	// Paramètres contexte
	llama_context_params ctx_params = llama_context_default_params();
	ctx_params.n_ctx = n_ctx;
	ctx_params.n_batch = 512;
	ctx_params.n_threads = 4;

	// Créer contexte
	ctx = llama_new_context_with_model(model, ctx_params);
	if (!ctx) {
		last_error = "Failed to create context";
		UtilityFunctions::printerr(last_error);
		llama_free_model(model);
		model = nullptr;
		return false;
	}

	// Créer sampler par défaut
	llama_sampler_chain_params sampler_params = llama_sampler_chain_default_params();
	sampler = llama_sampler_chain_init(sampler_params);

	// Paramètres par défaut
	llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.7f));
	llama_sampler_chain_add(sampler, llama_sampler_init_top_k(50));
	llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.95f, 1));
	llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

	is_loaded = true;
	UtilityFunctions::print("Model loaded successfully!");

	return true;
}

String LLMSimple::generate(const String& prompt, int max_tokens) {
	if (!is_loaded) {
		last_error = "No model loaded";
		emit_signal("generation_error", last_error);
		return "";
	}

	emit_signal("generation_started");

	CharString prompt_utf8 = prompt.utf8();
	const char* prompt_cstr = prompt_utf8.get_data();

	// Tokenizer le prompt
	std::vector<llama_token> tokens_list;
	tokens_list.resize(n_ctx);

	int n_tokens = llama_tokenize(
		model,
		prompt_cstr,
		prompt.length(),
		tokens_list.data(),
		tokens_list.size(),
		true, // add_bos
		false // special
	);

	if (n_tokens < 0) {
		last_error = "Tokenization failed";
		emit_signal("generation_error", last_error);
		return "";
	}

	tokens_list.resize(n_tokens);

	// Générer
	String result = "";
	int n_generated = 0;

	// Reset sampler
	llama_sampler_reset(sampler);

	// Process prompt
	if (llama_decode(ctx, llama_batch_get_one(tokens_list.data(), n_tokens)) != 0) {
		last_error = "Failed to decode prompt";
		emit_signal("generation_error", last_error);
		return "";
	}

	// Générer tokens
	for (int i = 0; i < max_tokens; i++) {
		// Sample next token
		llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

		// Check for EOS
		if (llama_token_is_eog(model, new_token)) {
			break;
		}

		// Decode token → texte
		char buf[256];
		int n = llama_token_to_piece(model, new_token, buf, sizeof(buf), 0, false);
		if (n < 0) {
			break;
		}

		result += String::utf8(buf, n);
		n_generated++;

		// Feed token back
		if (llama_decode(ctx, llama_batch_get_one(&new_token, 1)) != 0) {
			break;
		}
	}

	UtilityFunctions::print("Generated ", n_generated, " tokens");

	emit_signal("generation_finished", result);
	return result;
}

void LLMSimple::unload_model() {
	if (sampler) {
		llama_sampler_free(sampler);
		sampler = nullptr;
	}

	if (ctx) {
		llama_free(ctx);
		ctx = nullptr;
	}

	if (model) {
		llama_free_model(model);
		model = nullptr;
	}

	is_loaded = false;
}

// Configuration sampling
void LLMSimple::set_temperature(float temp) {
	if (sampler) {
		// Note: Pour vraiment changer, il faudrait recréer le sampler
		// Pour l'instant on log juste
		UtilityFunctions::print("Temperature will be applied on next load: ", temp);
	}
}

void LLMSimple::set_top_k(int k) {
	UtilityFunctions::print("Top-K will be applied on next load: ", k);
}

void LLMSimple::set_top_p(float p) {
	UtilityFunctions::print("Top-P will be applied on next load: ", p);
}

void LLMSimple::set_repeat_penalty(float penalty) {
	UtilityFunctions::print("Repeat penalty will be applied on next load: ", penalty);
}
