# MERLIN TTS — storyteller voice (homme mystérieux, fluide)

A real spoken narrator voice for Merlin (the procedural "Animalese"/digital voices are bips,
not a human voice). Service-first: the game (`merlin_voice.gd`, mode **Conteur (voix TTS)**)
POSTs narration text here and plays the returned WAV. Free + real-time on CPU via **Piper**.

## Run (PC, test now — no model needed)

```bash
TTS_BACKEND=stub python3 tools/tts/tts_server.py --port 8772
curl -s -X POST -H 'content-type: application/json' \
  -d '{"text":"Bienvenue, voyageur, dans les bois anciens."}' \
  http://127.0.0.1:8772/speak --output merlin.wav   # play merlin.wav
```

The **stub** returns a short tone so the whole game pipeline is testable with zero deps.

## The "Conteur" profile (deep, realistic — default)

The service ships a curated **`conteur`** voice profile (default `TTS_PROFILE=conteur`): a
ffmpeg DSP chain that deepens + warms any backend's output for a realistic storyteller —
subtle pitch ↓4 %, low-shelf bass (chest/warmth), a short room echo, rumble high-pass. The
game sends `profile:"conteur"` automatically. **Install `ffmpeg`** for the deepening (else the
raw voice is used). Profiles: `conteur` (default), `deep` (drier, ↓7 %), `mystery` (cavernous,
↓8 % + long reverb), `none`.

## Realism ladder (pick a backend)

**1. Piper — free, real-time, fluid (recommended first):**
```bash
pip install piper-tts
python -m piper.download_voices fr_FR-gilles-low      # deep male (or fr_FR-tom-medium)
TTS_BACKEND=piper TTS_VOICE=~/.local/share/piper/fr_FR-gilles-low.onnx \
  TTS_RATE=1.10 TTS_PROFILE=conteur python3 tools/tts/tts_server.py
```

**2. XTTS-v2 (Coqui) — most realistic free option, deep male, French:**
```bash
pip install TTS
# built-in deep male speaker "Damien Black" (or clone your own with TTS_SPEAKER_WAV=ref.wav)
TTS_BACKEND=coqui TTS_SPEAKER="Damien Black" TTS_PROFILE=conteur python3 tools/tts/tts_server.py
```
Heavier on CPU (a few seconds/line) but far more natural; results are cached by text.

**3. ElevenLabs — premium cloud (paid), most cinematic:**
```bash
TTS_BACKEND=elevenlabs ELEVEN_API_KEY=... ELEVEN_VOICE=<deep-male-id> python3 tools/tts/tts_server.py
```

Tune per request: `{"text":..., "rate":1.2, "profile":"deep"}`.

## Game wiring (already done)

`merlin_voice.gd` has a `VoiceMode.NARRATOR_TTS` (autoload `MerlinVoice`): on each narration it
POSTs to `tts_url` (`/speak`) and plays the WAV via `AudioStreamWAV.load_from_buffer` (Godot 4.4).
Select **Options → Voix → "Conteur (voix TTS)"**. Configure in `user://settings.cfg`:
`[voice] mode=3`, `tts_url=https://<tunnel-or-localhost:8772>`, `tts_token=...`.

## Deploy 24/7 (VM/Oracle)

Mirror the cockpit/ASR deploy: venv + `merlin-tts.service` (loopback :8772) + tunnel
(`TUNNEL_PORT=8772 bash infra/fleet/atelier/deploy/tunnel.sh named tts`). Env in
`/etc/merlin-tts.env` (0600, gitignored).

## Free / honest

- Piper is CPU real-time and small (~60 MB voice) — fluid even on weak PCs; on-device mobile is
  possible later via sherpa-onnx. **On the 1 GB VM, TTS + LLM + ASR together is too much** →
  host TTS on the PC (or Oracle A1). Caching by text hash avoids re-synth of repeated lines.
