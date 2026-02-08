# Merlin Music Tempo Map

This document defines a stable tempo mapping for dynamic music. Tempo is driven by Merlin mood and world tension.
It is designed to be deterministic, easy to implement, and stable over time.

Principles
- Tempo changes are continuous (no jumps).
- A hard cut can override the tempo system for major events only.
- Tempo stays inside a safe range to avoid listener fatigue.

Inputs
- merlin_mood: calm, wary, stern, amused, wounded, wrath
- world_tension: low, medium, high

Base tempo by mood (BPM)
- calm: 72
- wary: 88
- stern: 96
- amused: 104
- wounded: 64
- wrath: 128

Tension modifiers (BPM)
- low: -6
- medium: 0
- high: +8

Final target tempo
- target_bpm = base_mood_bpm + tension_modifier
- clamp to [60..140]

Examples
- calm + low -> 66 BPM
- wary + high -> 96 BPM
- wrath + medium -> 128 BPM

Ramping rules
- Normal changes: ramp over 6-10 seconds (default 8).
- Fast changes: ramp over 3-5 seconds (event flagged).
- Hard cut: fade out in 0.2-0.5 seconds then silence or new cue.

Tempo smoothing (implementation hint)
- current_bpm = lerp(current_bpm, target_bpm, dt / ramp_duration)
- update per audio tick or every 0.25s
