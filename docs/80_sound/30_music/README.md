# Music (Dynamic, Merlin-Driven)

Purpose
- All music is governed by the supercomputer (Merlin).
- The system can accelerate, decelerate, or cut music based on mood, story state, and world conditions.

Core rules
- Merlin controls tempo and arrangement; the player never directly selects tracks.
- Tempo can accelerate or slow down smoothly with mood changes.
- Hard cut is allowed only on major events (oaths broken, revelations, critical failures).
- Transitions must be seamless (no gaps, no audible jumps).

State inputs (examples)
- merlin_mood: calm, wary, stern, amused, wounded, wrath
- trust_level: low/medium/high
- world_tension: low/medium/high
- time_of_day: dawn/day/dusk/night
- event_flags: oath_broken, oath_kept, anomaly, seasonal_event

Music behavior mapping (guidelines)
- calm: slow tempo, sparse arrangement, soft timbres.
- wary: moderate tempo, added pulse, subtle dissonance.
- stern: firm rhythm, mid-tempo, reduced melodic movement.
- amused: light rhythm, playful ornaments.
- wounded: low tempo, dark palette, minimal dynamics.
- wrath: fast tempo, percussive emphasis, higher intensity.

Tempo control
- Target tempo is derived from merlin_mood + world_tension.
- Allowed tempo range: 60-140 BPM (avoid extremes).
- Tempo changes ramp over 4-12 seconds unless hard cut is triggered.

Cuts and silences
- When Merlin cuts the music, keep a short (0.2-0.5s) tail fade.
- Silence can be used as tension but should not exceed 10 seconds unless scripted.

Implementation notes
- Music is layered: base + pulse + accent + danger layers.
- Layer activation is driven by merlin_mood and world_tension.
- One music bus controlled by Merlin; all other audio ducks under it when needed.
