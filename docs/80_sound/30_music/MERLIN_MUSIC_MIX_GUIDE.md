# Merlin Music Mix Guide

This guide defines stable mixing rules for the dynamic music system.

Goals
- Keep Merlin voice intelligible.
- Preserve a consistent loudness across moods.
- Avoid harsh transitions when tempo changes.

Bus routing (suggested)
- Master
  - Music (Merlin controlled)
  - Voice (Merlin TTS)
  - SFX (Bestiole and world)
  - UI

Loudness targets (relative)
- Music: -16 LUFS (baseline)
- Voice: -12 LUFS (priority)
- SFX: -18 LUFS (lower, with short peaks)
- UI: -20 LUFS

Ducking rules
- Voice ducks music by 3 dB during speech.
- Bestiole SFX ducks music by 1-2 dB for 0.3s.
- UI never ducks music.

Layer balance
- Base layer: always on when music is active.
- Pulse layer: active when world_tension >= medium.
- Accent layer: active when merlin_mood is amused or wary.
- Danger layer: active when merlin_mood is wrath or world_tension is high.

Transitions
- Layer crossfades over 1.5-2.5 seconds.
- Hard cut is allowed only when allow_cut is true.

Silence rule
- Silence longer than 10 seconds must be scripted or force_silence.
