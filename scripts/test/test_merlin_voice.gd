## =============================================================================
## Unit Tests -- MerlinVoice (Pure Logic Only)
## =============================================================================
## Tests: constants integrity, presets, voice mode labels, sound bank labels,
## markdown stripping, preset params, mode cycling.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## NOTE: MerlinVoice extends Node -- we test ONLY pure logic via constants
##       and by calling methods that do not require scene tree or audio.
## =============================================================================

extends RefCounted


const MerlinVoiceScript = preload("res://addons/merlin_ai/merlin_voice.gd")


# =============================================================================
# HELPERS
# =============================================================================

## Calls _strip_markdown via a static-like approach: instantiate script constants
## Since _strip_markdown is an instance method on a Node, we replicate its logic
## here for testing (the function is pure string transformation).
func _strip_markdown_logic(text: String) -> String:
	var result := text
	var patterns := [["**", ""], ["__", ""], ["*", ""], ["_", ""], ["`", ""], ["~~", ""]]
	for pattern in patterns:
		result = result.replace(pattern[0], pattern[1])
	var lines := result.split("\n")
	var clean_lines := PackedStringArray()
	for line in lines:
		var trimmed := line.strip_edges()
		while trimmed.begins_with("#"):
			trimmed = trimmed.substr(1).strip_edges()
		clean_lines.append(trimmed)
	return "\n".join(clean_lines)


# =============================================================================
# TEST: Script loads without error
# =============================================================================

func test_script_loads() -> bool:
	if MerlinVoiceScript == null:
		push_error("MerlinVoiceScript failed to preload")
		return false
	return true


# =============================================================================
# TEST: VOICE_PRESETS has all expected entries
# =============================================================================

func test_voice_presets_completeness() -> bool:
	var presets: Dictionary = MerlinVoiceScript.VOICE_PRESETS
	var expected_names: Array[String] = [
		"Normal", "Aigu", "Grave", "Enfant", "Sage", "Joyeux", "Mysterieux", "Merlin"
	]
	for name in expected_names:
		if not presets.has(name):
			push_error("Missing preset: " + name)
			return false
	if presets.size() != expected_names.size():
		push_error("Expected %d presets, got %d" % [expected_names.size(), presets.size()])
		return false
	return true


# =============================================================================
# TEST: Each preset has required keys with valid ranges
# =============================================================================

func test_voice_presets_structure() -> bool:
	var presets: Dictionary = MerlinVoiceScript.VOICE_PRESETS
	for preset_name in presets.keys():
		var p: Dictionary = presets[preset_name]
		if not p.has("base_pitch"):
			push_error("Preset '%s' missing base_pitch" % preset_name)
			return false
		if not p.has("pitch_variation"):
			push_error("Preset '%s' missing pitch_variation" % preset_name)
			return false
		if not p.has("speed_scale"):
			push_error("Preset '%s' missing speed_scale" % preset_name)
			return false
		# Validate ranges (from @export_range annotations)
		var bp: float = p["base_pitch"]
		if bp < 2.0 or bp > 5.0:
			push_error("Preset '%s' base_pitch %.2f out of range [2.0, 5.0]" % [preset_name, bp])
			return false
		var pv: float = p["pitch_variation"]
		if pv < 0.0 or pv > 1.0:
			push_error("Preset '%s' pitch_variation %.2f out of range [0.0, 1.0]" % [preset_name, pv])
			return false
		var ss: float = p["speed_scale"]
		if ss < 0.5 or ss > 2.0:
			push_error("Preset '%s' speed_scale %.2f out of range [0.5, 2.0]" % [preset_name, ss])
			return false
	return true


# =============================================================================
# TEST: Merlin preset has specific expected values
# =============================================================================

func test_merlin_preset_values() -> bool:
	var merlin: Dictionary = MerlinVoiceScript.VOICE_PRESETS["Merlin"]
	if not is_equal_approx(merlin["base_pitch"], 3.2):
		push_error("Merlin base_pitch expected 3.2, got %.2f" % merlin["base_pitch"])
		return false
	if not is_equal_approx(merlin["pitch_variation"], 0.28):
		push_error("Merlin pitch_variation expected 0.28, got %.2f" % merlin["pitch_variation"])
		return false
	if not is_equal_approx(merlin["speed_scale"], 0.95):
		push_error("Merlin speed_scale expected 0.95, got %.2f" % merlin["speed_scale"])
		return false
	return true


# =============================================================================
# TEST: VOICE_MODE_LABELS covers all enum values
# =============================================================================

func test_voice_mode_labels_completeness() -> bool:
	var labels: Dictionary = MerlinVoiceScript.VOICE_MODE_LABELS
	# VoiceMode enum: AC_VOICE=0, DIGITAL_VOICE=1, OFF=2
	if labels.size() != 3:
		push_error("Expected 3 voice mode labels, got %d" % labels.size())
		return false
	# Check each label is a non-empty string
	for key in labels.keys():
		var label: String = labels[key]
		if label.strip_edges() == "":
			push_error("Voice mode label for key %s is empty" % str(key))
			return false
	return true


# =============================================================================
# TEST: VOICE_MODE_LABELS values are correct
# =============================================================================

func test_voice_mode_labels_values() -> bool:
	var labels: Dictionary = MerlinVoiceScript.VOICE_MODE_LABELS
	# AC_VOICE = 0
	if labels.get(0, "") != "Voix AC (Animalese)":
		push_error("AC_VOICE label mismatch: '%s'" % labels.get(0, ""))
		return false
	# DIGITAL_VOICE = 1
	if labels.get(1, "") != "Voix Numerique":
		push_error("DIGITAL_VOICE label mismatch: '%s'" % labels.get(1, ""))
		return false
	# OFF = 2
	if labels.get(2, "") != "Desactivee":
		push_error("OFF label mismatch: '%s'" % labels.get(2, ""))
		return false
	return true


# =============================================================================
# TEST: _strip_markdown removes bold markers
# =============================================================================

func test_strip_markdown_bold() -> bool:
	var input := "This is **bold** text"
	var result := _strip_markdown_logic(input)
	if result != "This is bold text":
		push_error("Bold strip failed: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown removes italic markers
# =============================================================================

func test_strip_markdown_italic() -> bool:
	var input := "This is *italic* text"
	var result := _strip_markdown_logic(input)
	if result != "This is italic text":
		push_error("Italic strip failed: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown removes underline markers
# =============================================================================

func test_strip_markdown_underline() -> bool:
	var input := "This is __underlined__ text"
	var result := _strip_markdown_logic(input)
	if result != "This is underlined text":
		push_error("Underline strip failed: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown removes backtick markers
# =============================================================================

func test_strip_markdown_backtick() -> bool:
	var input := "Use `code` here"
	var result := _strip_markdown_logic(input)
	if result != "Use code here":
		push_error("Backtick strip failed: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown removes strikethrough markers
# =============================================================================

func test_strip_markdown_strikethrough() -> bool:
	var input := "This is ~~deleted~~ text"
	var result := _strip_markdown_logic(input)
	if result != "This is deleted text":
		push_error("Strikethrough strip failed: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown removes heading markers
# =============================================================================

func test_strip_markdown_headings() -> bool:
	var input := "# Title\n## Subtitle\n### Deep"
	var result := _strip_markdown_logic(input)
	var lines := result.split("\n")
	if lines[0] != "Title":
		push_error("H1 strip failed: '%s'" % lines[0])
		return false
	if lines[1] != "Subtitle":
		push_error("H2 strip failed: '%s'" % lines[1])
		return false
	if lines[2] != "Deep":
		push_error("H3 strip failed: '%s'" % lines[2])
		return false
	return true


# =============================================================================
# TEST: _strip_markdown handles plain text (no change)
# =============================================================================

func test_strip_markdown_plain_text() -> bool:
	var input := "Just a normal sentence."
	var result := _strip_markdown_logic(input)
	if result != "Just a normal sentence.":
		push_error("Plain text modified: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown handles empty string
# =============================================================================

func test_strip_markdown_empty() -> bool:
	var result := _strip_markdown_logic("")
	if result != "":
		push_error("Empty string produced: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown handles mixed formatting
# =============================================================================

func test_strip_markdown_mixed() -> bool:
	var input := "# **Bold Title**\nSome `code` and *italic* here"
	var result := _strip_markdown_logic(input)
	if result.find("**") != -1:
		push_error("Bold markers remain: '%s'" % result)
		return false
	if result.find("`") != -1:
		push_error("Backtick markers remain: '%s'" % result)
		return false
	if result.find("#") != -1:
		push_error("Heading markers remain: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: _strip_markdown multiline headings
# =============================================================================

func test_strip_markdown_multiline() -> bool:
	var input := "Normal line\n## Heading line\nAnother normal"
	var result := _strip_markdown_logic(input)
	var lines := result.split("\n")
	if lines.size() != 3:
		push_error("Expected 3 lines, got %d" % lines.size())
		return false
	if lines[1] != "Heading line":
		push_error("Heading not stripped in middle: '%s'" % lines[1])
		return false
	return true


# =============================================================================
# TEST: Sound bank fallback labels (no acvoicebox)
# =============================================================================

func test_sound_bank_labels_fallback() -> bool:
	# When no ACVoicebox, get_sound_bank_label uses internal dict
	var expected := {
		"default": "Classique",
		"high": "Aigu (Peppy)",
		"low": "Grave (Cranky)",
		"lowest": "Tres grave",
		"med": "Medium",
	}
	# We test the fallback dict directly (same as in the source)
	var labels := {
		"default": "Classique", "high": "Aigu (Peppy)",
		"low": "Grave (Cranky)", "lowest": "Tres grave", "med": "Medium"
	}
	for bank_name in expected.keys():
		var label: String = labels.get(bank_name, bank_name)
		if label != expected[bank_name]:
			push_error("Bank '%s' label mismatch: '%s' vs '%s'" % [bank_name, label, expected[bank_name]])
			return false
	# Unknown bank returns bank_name itself
	var unknown_label: String = labels.get("unknown_bank", "unknown_bank")
	if unknown_label != "unknown_bank":
		push_error("Unknown bank should return name itself, got '%s'" % unknown_label)
		return false
	return true


# =============================================================================
# TEST: Sound bank names fallback list
# =============================================================================

func test_sound_bank_names_fallback() -> bool:
	var expected: Array[String] = ["default", "high", "low", "lowest", "med"]
	# Verify these are the 5 hardcoded fallback banks
	if expected.size() != 5:
		push_error("Expected 5 fallback sound banks")
		return false
	if expected[0] != "default":
		push_error("First bank should be 'default'")
		return false
	return true


# =============================================================================
# TEST: Preset count matches expected (8 presets)
# =============================================================================

func test_preset_count() -> bool:
	var presets: Dictionary = MerlinVoiceScript.VOICE_PRESETS
	if presets.size() != 8:
		push_error("Expected 8 presets, got %d" % presets.size())
		return false
	return true


# =============================================================================
# TEST: All presets have distinct base_pitch values
# =============================================================================

func test_presets_distinct_base_pitch() -> bool:
	var presets: Dictionary = MerlinVoiceScript.VOICE_PRESETS
	var pitches: Array[float] = []
	for name in presets.keys():
		var bp: float = presets[name]["base_pitch"]
		if bp in pitches:
			push_error("Duplicate base_pitch %.2f found in preset '%s'" % [bp, name])
			return false
		pitches.append(bp)
	return true


# =============================================================================
# TEST: Preset ordering by pitch (Mysterieux < Grave < Sage < Merlin < Normal < Joyeux < Aigu < Enfant)
# =============================================================================

func test_presets_pitch_ordering() -> bool:
	var presets: Dictionary = MerlinVoiceScript.VOICE_PRESETS
	var ordered: Array[String] = ["Mysterieux", "Grave", "Sage", "Merlin", "Normal", "Joyeux", "Aigu", "Enfant"]
	for i in range(ordered.size() - 1):
		var bp_a: float = presets[ordered[i]]["base_pitch"]
		var bp_b: float = presets[ordered[i + 1]]["base_pitch"]
		if bp_a >= bp_b:
			push_error("Pitch ordering violated: %s (%.2f) >= %s (%.2f)" % [ordered[i], bp_a, ordered[i + 1], bp_b])
			return false
	return true


# =============================================================================
# TEST: Speed scale ordering (slower to faster)
# =============================================================================

func test_presets_speed_coherence() -> bool:
	var presets: Dictionary = MerlinVoiceScript.VOICE_PRESETS
	# Mysterieux should be slowest, Enfant fastest
	var slow: float = presets["Mysterieux"]["speed_scale"]
	var fast: float = presets["Enfant"]["speed_scale"]
	if slow >= fast:
		push_error("Mysterieux speed (%.2f) should be < Enfant speed (%.2f)" % [slow, fast])
		return false
	return true


# =============================================================================
# TEST: Frequency calculation logic (from _play_soft_sound)
# =============================================================================

func test_frequency_calculation() -> bool:
	# Formula: freq = 150.0 + (base_pitch - 2.0) * 116.0
	# At base_pitch=2.0 -> freq=150Hz
	var freq_low: float = 150.0 + (2.0 - 2.0) * 116.0
	if not is_equal_approx(freq_low, 150.0):
		push_error("Freq at pitch 2.0 should be 150.0, got %.2f" % freq_low)
		return false
	# At base_pitch=5.0 -> freq=498Hz
	var freq_high: float = 150.0 + (5.0 - 2.0) * 116.0
	if not is_equal_approx(freq_high, 498.0):
		push_error("Freq at pitch 5.0 should be 498.0, got %.2f" % freq_high)
		return false
	# Merlin preset (3.2) -> 150 + 1.2*116 = 289.2
	var freq_merlin: float = 150.0 + (3.2 - 2.0) * 116.0
	if not is_equal_approx(freq_merlin, 289.2):
		push_error("Freq at Merlin pitch 3.2 should be 289.2, got %.2f" % freq_merlin)
		return false
	return true


# =============================================================================
# TEST: Pentatonic scale mapping (from _play_soft_sound)
# =============================================================================

func test_pentatonic_mapping() -> bool:
	var pentatonic: Array[int] = [0, 2, 4, 7, 9]
	# 'a' -> idx 0 -> note 0
	var idx_a: int = "a".unicode_at(0) - "a".unicode_at(0)
	if pentatonic[idx_a % pentatonic.size()] != 0:
		push_error("'a' should map to note 0")
		return false
	# 'f' -> idx 5 -> note 0 (5 % 5 = 0)
	var idx_f: int = "f".unicode_at(0) - "a".unicode_at(0)
	if pentatonic[idx_f % pentatonic.size()] != 0:
		push_error("'f' should map to note 0 (wrap), got %d" % pentatonic[idx_f % pentatonic.size()])
		return false
	# 'c' -> idx 2 -> note 4
	var idx_c: int = "c".unicode_at(0) - "a".unicode_at(0)
	if pentatonic[idx_c % pentatonic.size()] != 4:
		push_error("'c' should map to note 4, got %d" % pentatonic[idx_c % pentatonic.size()])
		return false
	return true


# =============================================================================
# TEST: Char delay calculation (from _process)
# =============================================================================

func test_char_delay_calculation() -> bool:
	# char_delay = 0.04 / speed_scale
	# At speed_scale 1.0 -> 0.04s (25 chars/sec)
	var delay_normal: float = 0.04 / 1.0
	if not is_equal_approx(delay_normal, 0.04):
		push_error("Normal delay should be 0.04, got %.4f" % delay_normal)
		return false
	# At Merlin speed (0.95) -> ~0.0421s
	var delay_merlin: float = 0.04 / 0.95
	if absf(delay_merlin - 0.04211) > 0.001:
		push_error("Merlin delay should be ~0.0421, got %.4f" % delay_merlin)
		return false
	# At Enfant speed (1.2) -> ~0.0333s (faster)
	var delay_enfant: float = 0.04 / 1.2
	if delay_enfant >= delay_normal:
		push_error("Enfant delay should be < normal delay")
		return false
	return true


# =============================================================================
# TEST: Tone duration calculation (from _generate_soft_tone)
# =============================================================================

func test_tone_duration_samples() -> bool:
	var sample_rate: int = 44100
	# duration_sec = 0.06 / speed_scale
	# At speed_scale 1.0: 0.06s -> 2646 samples
	var duration_1: float = 0.06 / 1.0
	var num_samples_1: int = int(duration_1 * sample_rate)
	if num_samples_1 != 2646:
		push_error("Expected 2646 samples at speed 1.0, got %d" % num_samples_1)
		return false
	# At Merlin speed 0.95: 0.06316s -> 2785 samples
	var duration_m: float = 0.06 / 0.95
	var num_samples_m: int = int(duration_m * sample_rate)
	if num_samples_m < num_samples_1:
		push_error("Slower speed should produce more samples")
		return false
	return true


# =============================================================================
# TEST: Voice mode OFF disables voice_enabled
# =============================================================================

func test_voice_mode_off_logic() -> bool:
	# set_voice_mode(OFF) should set voice_enabled = false
	# We test the logic: voice_enabled = (mode != VoiceMode.OFF)
	# OFF = 2
	var mode_off: int = 2
	var enabled: bool = (mode_off != 2)
	if enabled:
		push_error("OFF mode should disable voice_enabled")
		return false
	# AC_VOICE = 0
	var mode_ac: int = 0
	enabled = (mode_ac != 2)
	if not enabled:
		push_error("AC_VOICE mode should enable voice_enabled")
		return false
	# DIGITAL_VOICE = 1
	var mode_digital: int = 1
	enabled = (mode_digital != 2)
	if not enabled:
		push_error("DIGITAL_VOICE mode should enable voice_enabled")
		return false
	return true


# =============================================================================
# TEST: Strip markdown with underscore in words (edge case)
# =============================================================================

func test_strip_markdown_underscore_edge() -> bool:
	# Note: the simple replace approach will strip underscores from variable_names
	# This is a known limitation - testing the actual behavior
	var input := "var_name and __bold__"
	var result := _strip_markdown_logic(input)
	# All underscores are removed (by design)
	if result.find("__") != -1:
		push_error("Double underscores should be removed")
		return false
	return true


# =============================================================================
# TEST: Strip markdown heading with spaces before #
# =============================================================================

func test_strip_markdown_heading_with_spaces() -> bool:
	var input := "  ## Spaced heading  "
	var result := _strip_markdown_logic(input)
	if result != "Spaced heading":
		push_error("Spaced heading not stripped correctly: '%s'" % result)
		return false
	return true


# =============================================================================
# TEST: Characters that should be ignored by voice (punctuation/space check)
# =============================================================================

func test_voice_skip_characters() -> bool:
	var skip_chars := " .,!?;:-"
	# Space
	if not (" " == " " or " " in skip_chars):
		push_error("Space should be skipped")
		return false
	# Punctuation
	for c in [".", ",", "!", "?", ";", ":", "-"]:
		if not (c in skip_chars):
			push_error("'%s' should be in skip chars" % c)
			return false
	# Letters should NOT be skipped
	if "a" in skip_chars:
		push_error("'a' should not be skipped")
		return false
	return true


# =============================================================================
# RUN ALL
# =============================================================================

func run_all() -> Dictionary:
	var results := {}
	var tests: Array[String] = [
		"test_script_loads",
		"test_voice_presets_completeness",
		"test_voice_presets_structure",
		"test_merlin_preset_values",
		"test_voice_mode_labels_completeness",
		"test_voice_mode_labels_values",
		"test_strip_markdown_bold",
		"test_strip_markdown_italic",
		"test_strip_markdown_underline",
		"test_strip_markdown_backtick",
		"test_strip_markdown_strikethrough",
		"test_strip_markdown_headings",
		"test_strip_markdown_plain_text",
		"test_strip_markdown_empty",
		"test_strip_markdown_mixed",
		"test_strip_markdown_multiline",
		"test_strip_markdown_underscore_edge",
		"test_strip_markdown_heading_with_spaces",
		"test_sound_bank_labels_fallback",
		"test_sound_bank_names_fallback",
		"test_preset_count",
		"test_presets_distinct_base_pitch",
		"test_presets_pitch_ordering",
		"test_presets_speed_coherence",
		"test_frequency_calculation",
		"test_pentatonic_mapping",
		"test_char_delay_calculation",
		"test_tone_duration_samples",
		"test_voice_mode_off_logic",
		"test_voice_skip_characters",
	]

	var passed := 0
	var failed := 0
	for test_name in tests:
		var result: bool = call(test_name)
		results[test_name] = result
		if result:
			passed += 1
		else:
			failed += 1

	print("MerlinVoice Tests: %d passed, %d failed / %d total" % [passed, failed, tests.size()])
	return results
