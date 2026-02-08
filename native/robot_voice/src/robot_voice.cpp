#include "robot_voice.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <flite/flite.h>

using namespace godot;

static bool flite_ready = false;
static cst_voice *flite_voice = nullptr;

static void ensure_flite_voice() {
	if (flite_ready) {
		return;
	}
	flite_init();
	flite_voice = flite_voice_select("slt");
	if (flite_voice == nullptr) {
		flite_voice = flite_voice_select("kal");
	}
	flite_ready = true;
}

RobotVoice::RobotVoice() {}
RobotVoice::~RobotVoice() {}

void RobotVoice::_bind_methods() {
	ClassDB::bind_method(D_METHOD("speak", "text"), &RobotVoice::speak);
	ClassDB::bind_method(D_METHOD("set_pitch", "pitch"), &RobotVoice::set_pitch);
	ClassDB::bind_method(D_METHOD("get_pitch"), &RobotVoice::get_pitch);
	ClassDB::bind_method(D_METHOD("set_volume", "volume"), &RobotVoice::set_volume);
	ClassDB::bind_method(D_METHOD("get_volume"), &RobotVoice::get_volume);
	ClassDB::bind_method(D_METHOD("set_output_rate", "rate"), &RobotVoice::set_output_rate);
	ClassDB::bind_method(D_METHOD("get_output_rate"), &RobotVoice::get_output_rate);
	ClassDB::bind_method(D_METHOD("set_chirp_strength", "value"), &RobotVoice::set_chirp_strength);
	ClassDB::bind_method(D_METHOD("get_chirp_strength"), &RobotVoice::get_chirp_strength);
	ClassDB::bind_method(D_METHOD("set_chirp_hz", "value"), &RobotVoice::set_chirp_hz);
	ClassDB::bind_method(D_METHOD("get_chirp_hz"), &RobotVoice::get_chirp_hz);
	ClassDB::bind_method(D_METHOD("set_chirp_ms", "value"), &RobotVoice::set_chirp_ms);
	ClassDB::bind_method(D_METHOD("get_chirp_ms"), &RobotVoice::get_chirp_ms);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "pitch"), "set_pitch", "get_pitch");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "volume"), "set_volume", "get_volume");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "output_rate"), "set_output_rate", "get_output_rate");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "chirp_strength"), "set_chirp_strength", "get_chirp_strength");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "chirp_hz"), "set_chirp_hz", "get_chirp_hz");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "chirp_ms"), "set_chirp_ms", "get_chirp_ms");
}

PackedFloat32Array RobotVoice::speak(String text) {
	PackedFloat32Array out;
	ensure_flite_voice();
	if (flite_voice == nullptr) {
		UtilityFunctions::push_warning("RobotVoice: flite voice not available.");
		return out;
	}

	CharString utf8 = text.utf8();
	cst_wave *wave = flite_text_to_wave(utf8.get_data(), flite_voice);
	if (wave == nullptr) {
		return out;
	}

	const int in_rate = wave->sample_rate;
	const int in_count = cst_wave_num_samples(wave);
	const int16_t *in_samples = cst_wave_samples(wave);

	if (in_count <= 0 || in_samples == nullptr) {
		delete_wave(wave);
		return out;
	}

	const float safe_pitch = pitch <= 0.01f ? 0.01f : pitch;
	const float rate_scale = static_cast<float>(output_rate) / static_cast<float>(in_rate);
	const int out_count = static_cast<int>((static_cast<float>(in_count) * rate_scale) / safe_pitch);
	if (out_count <= 0) {
		delete_wave(wave);
		return out;
	}

	out.resize(out_count);
	const float inv_scale = static_cast<float>(in_rate) / static_cast<float>(output_rate);
	const float chirp_len_s = chirp_ms * 0.001f;
	const int chirp_len = static_cast<int>(chirp_len_s * output_rate);
	const int chirp_period = static_cast<int>(0.18f * output_rate);

	for (int i = 0; i < out_count; i++) {
		float src = static_cast<float>(i) * safe_pitch * inv_scale;
		int idx = static_cast<int>(src);
		float frac = src - static_cast<float>(idx);
		if (idx >= in_count) {
			idx = in_count - 1;
			frac = 0.0f;
		}
		int idx2 = idx + 1;
		if (idx2 >= in_count) {
			idx2 = in_count - 1;
		}

		float s0 = static_cast<float>(in_samples[idx]) / 32768.0f;
		float s1 = static_cast<float>(in_samples[idx2]) / 32768.0f;
		float sample = (s0 + (s1 - s0) * frac) * volume;

		if (chirp_strength > 0.0f && chirp_period > 0) {
			int pos = i % chirp_period;
			if (pos < chirp_len) {
				float t = static_cast<float>(pos) / static_cast<float>(output_rate);
				sample += Math::sin(2.0f * Math_PI * chirp_hz * t) * chirp_strength;
			}
		}

		sample = Math::clamp(sample, -1.0f, 1.0f);
		out.set(i, sample);
	}

	delete_wave(wave);
	return out;
}

void RobotVoice::set_pitch(double p_pitch) { pitch = static_cast<float>(p_pitch); }
double RobotVoice::get_pitch() const { return pitch; }
void RobotVoice::set_volume(double p_volume) { volume = static_cast<float>(p_volume); }
double RobotVoice::get_volume() const { return volume; }
void RobotVoice::set_output_rate(int p_rate) { output_rate = p_rate; }
int RobotVoice::get_output_rate() const { return output_rate; }
void RobotVoice::set_chirp_strength(double p_value) { chirp_strength = static_cast<float>(p_value); }
double RobotVoice::get_chirp_strength() const { return chirp_strength; }
void RobotVoice::set_chirp_hz(double p_value) { chirp_hz = static_cast<float>(p_value); }
double RobotVoice::get_chirp_hz() const { return chirp_hz; }
void RobotVoice::set_chirp_ms(double p_value) { chirp_ms = static_cast<float>(p_value); }
double RobotVoice::get_chirp_ms() const { return chirp_ms; }
