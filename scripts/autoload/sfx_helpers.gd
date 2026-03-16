## =============================================================================
## SFXHelpers — Stream builder & waveform primitives for procedural audio
## =============================================================================
## Extracted from SFXManager.gd — shared by SFXRecipes.
## All functions are static to avoid state; RNG is passed in where needed.
## =============================================================================

class_name SFXHelpers
extends RefCounted

const SAMPLE_RATE := 44100


# =============================================================================
# STREAM BUILDER HELPERS
# =============================================================================

static func make_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func alloc_buffer(duration: float) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(int(SAMPLE_RATE * duration) * 2)
	return buf


static func write_sample(buf: PackedByteArray, index: int, value: float) -> void:
	var clamped := clampf(value, -1.0, 1.0)
	var sample_val := int(clamped * 32767.0)
	var byte_idx := index * 2
	if byte_idx + 1 < buf.size():
		buf[byte_idx] = sample_val & 0xFF
		buf[byte_idx + 1] = (sample_val >> 8) & 0xFF


static func sample_count(duration: float) -> int:
	return int(SAMPLE_RATE * duration)


# =============================================================================
# WAVEFORM HELPERS — Pixel/chiptune aesthetic
# =============================================================================

static func sq(freq: float, t: float) -> float:
	## Soft square wave — chiptune/pixel retro aesthetic.
	return clampf(sin(TAU * freq * t) * 8.0, -1.0, 1.0)


static func tri(freq: float, t: float) -> float:
	## Triangle wave — NES-style smooth chiptune tone.
	return 2.0 / PI * asin(clampf(sin(TAU * freq * t), -1.0, 1.0))


static func pulse(freq: float, t: float, duty: float = 0.25) -> float:
	## Pulse wave with configurable duty cycle — classic chiptune character.
	return 1.0 if fposmod(freq * t, 1.0) < duty else -1.0


# Celtic scale reference (D Dorian = D E F G A B C D):
# D3=147  E3=165  F3=175  G3=196  A3=220  B3=247  C4=262
# D4=294  E4=330  F4=349  G4=392  A4=440  B4=494  C5=523  D5=587  G5=784
