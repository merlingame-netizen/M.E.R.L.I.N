# 80_sound

Purpose
- All sound-related docs live here. Do not place voice, SFX, or music docs outside this folder.

Structure
- 10_voice: voice system and Merlin robot voice pipeline
- 20_sfx: SFX rules and packs (Bestiole)
- 30_music: dynamic music rules governed by Merlin

Music docs
- 30_music/README.md: core rules for Merlin-controlled music
- 30_music/MERLIN_MUSIC_TEMPO_MAP.md: stable tempo mapping
- 30_music/MERLIN_MUSIC_STATE_SCHEMA.md: JSON schema for music state
- 30_music/MERLIN_MUSIC_MIX_GUIDE.md: bus routing and ducking rules

Notes
- Bestiole uses non-verbal SFX only (see 20_sfx).
- Merlin is the only TTS voice (see 10_voice).
