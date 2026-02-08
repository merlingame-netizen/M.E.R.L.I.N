# Merlin Music State Schema

This schema defines the data sent to the music system. It is designed for a deterministic pipeline.
All values are explicit to avoid hidden logic in the audio layer.

JSON schema (informal)
{
  "timestamp": "2026-02-01T12:34:56Z",
  "scene": "menu|taniere|adventure|combat|cutscene",
  "merlin_mood": "calm|wary|stern|amused|wounded|wrath",
  "world_tension": "low|medium|high",
  "trust_level": "low|medium|high",
  "time_of_day": "dawn|day|dusk|night",
  "event_flags": [
    "oath_kept",
    "oath_broken",
    "anomaly",
    "seasonal_event",
    "revelation_hint"
  ],
  "music": {
    "allow_cut": true,
    "force_silence": false,
    "intensity_bias": -1,
    "target_layer": "base|pulse|accent|danger",
    "bpm_override": 0
  }
}

Field rules
- timestamp: ISO string, used for logs only.
- scene: drives arrangement presets.
- merlin_mood: primary driver for tempo and timbre.
- world_tension: secondary driver for tempo and layering.
- trust_level: can soften or sharpen timbre.
- time_of_day: color palette only, not tempo.
- event_flags: can trigger cut or short stingers.

music object
- allow_cut: if false, never hard cut (only ramps).
- force_silence: if true, fade out and stay silent until cleared.
- intensity_bias: -2..+2, manual offset for layering.
- target_layer: optional; if set, pin to a layer group.
- bpm_override: if > 0, force this BPM (used for scripted moments).

Validation rules
- If force_silence is true, ignore bpm_override.
- If allow_cut is false, never hard cut even on oath_broken.
- bpm_override must be between 60 and 140 if set.
