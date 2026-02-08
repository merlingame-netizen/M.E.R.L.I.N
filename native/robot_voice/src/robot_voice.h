#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string.hpp>

class RobotVoice : public godot::RefCounted {
	GDCLASS(RobotVoice, godot::RefCounted)

private:
	float pitch = 1.45f;
	float volume = 0.85f;
	float chirp_strength = 0.06f;
	float chirp_hz = 1400.0f;
	float chirp_ms = 12.0f;
	int output_rate = 22050;

protected:
	static void _bind_methods();

public:
	RobotVoice();
	~RobotVoice();

	godot::PackedFloat32Array speak(godot::String text);
	void set_pitch(double p_pitch);
	double get_pitch() const;
	void set_volume(double p_volume);
	double get_volume() const;
	void set_output_rate(int p_rate);
	int get_output_rate() const;
	void set_chirp_strength(double p_value);
	double get_chirp_strength() const;
	void set_chirp_hz(double p_value);
	double get_chirp_hz() const;
	void set_chirp_ms(double p_value);
	double get_chirp_ms() const;
};
