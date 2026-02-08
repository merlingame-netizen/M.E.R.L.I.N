# Bestiole SFX Pack (Non-verbal Only)

Goal
- Bestiole does not speak. It only emits small creature sounds (SFX).
- Sounds must be short, expressive, and tied to state changes.
- SFX should not carry dialogue content.

Core Principles
- Short: 80-350 ms per event.
- Soft peaks: avoid harsh transients.
- Variation: 3-5 variants per cue to prevent repetition.
- Pitch shift: random +/- 3 percent per play.
- Volume jitter: random +/- 2 dB per play.

Sound Families
- Chirps: light and friendly.
- Purrs: calm and content.
- Trills: curious or excited.
- Huffs: tired or annoyed.
- Whimpers: sad or hurt.
- Pops: playful or bounce.

State-Based Rules
- Mood high: chirps and soft trills.
- Mood medium: light purrs and neutral chirps.
- Mood low: whimpers, soft huffs.
- Energy low: fewer SFX, quieter.
- Cleanliness low: huffs, no trills.
- Bond high: longer purr tails.

Event Triggers (Examples)
- Taniere: feed item used -> Chirp (friendly).
- Taniere: play action success -> Pop + Chirp.
- Taniere: grooming -> Purr.
- Taniere: rest -> Long purr + fade.
- Taniere: bond increase -> Trill (bright).
- Taniere: bond decrease -> Whimper.
- Combat: support action -> Chirp (short).
- Combat: hit received -> Whimper (short).
- Combat: dodge -> Trill (quick).
- World: discovery -> Chirp (curious).
- World: night idle -> Soft purr loop (low volume).

Cooldown Rules
- Global cooldown: 2.0 s between SFX (avoid spam).
- Same cue cooldown: 6.0 s before same cue repeats.
- Burst limit: max 3 SFX within 5 seconds.

Mix Rules
- Ducking: Bestiole SFX ducks under Merlin voice by 3 dB.
- Do not overlap more than 2 Bestiole SFX at once.
- Stereo spread: slight random pan +/- 0.1.

SFX Metadata Template (JSON)
{
  "id": "bestiole_chirp_soft",
  "family": "chirp",
  "duration_ms": 180,
  "variants": 4,
  "pitch_jitter": 0.03,
  "gain_jitter_db": 2,
  "cooldown_s": 6,
  "tags": ["mood_high", "taniere", "friendly"]
}

Implementation Notes
- Use a small pool of WAVs and apply light pitch/volume jitter at runtime.
- Keep sample rate consistent with audio bus (22050 or 44100).
- SFX should be mono by default; pan in engine.
