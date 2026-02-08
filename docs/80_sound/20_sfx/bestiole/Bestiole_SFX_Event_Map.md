# Bestiole SFX Event Map

This map links game events to Bestiole SFX cues.
Bestiole never speaks. Use short non-verbal sounds only.

SFX families (ids)
- chirp: bestiole_chirp_soft_01..03
- purr: bestiole_purr_soft_01..03
- trill: bestiole_trill_bright_01..03
- huff: bestiole_huff_low_01..03
- whimper: bestiole_whimper_soft_01..03
- pop: bestiole_pop_play_01..03

Event -> SFX mapping
- taniere_feed_item -> bestiole_chirp_soft_01 (friendly)
- taniere_play_success -> bestiole_pop_play_01 + bestiole_chirp_soft_02
- taniere_groom -> bestiole_purr_soft_01
- taniere_rest_start -> bestiole_purr_soft_02 (fade)
- taniere_bond_up -> bestiole_trill_bright_01
- taniere_bond_down -> bestiole_whimper_soft_01
- combat_support_action -> bestiole_chirp_soft_03
- combat_hit_received -> bestiole_whimper_soft_02
- combat_dodge -> bestiole_trill_bright_02
- world_discovery -> bestiole_trill_bright_03 (short)
- world_night_idle -> bestiole_purr_soft_03 (loop low volume)
- world_threat_near -> bestiole_huff_low_01
- world_tired -> bestiole_huff_low_02

Notes
- Always respect global cooldowns from Bestiole_SFX_Pack.md.
- Use one cue per event unless explicitly listed as combo.
- For long loops (night idle), cap to 3-5 seconds max.
