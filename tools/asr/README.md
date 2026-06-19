# MERLIN ASR — voice input (Track 2 of plan Add-on 7)

Player speaks → mic captured in Godot (`addons/merlin_ai/voice_recognition.gd`) → POSTed to
this CPU microservice → text → fuzzy-matched to a card option. **Service-first**: running an ASR
model on-device in Godot is hard, so we host it (PC first, then VM/Oracle) and reach it over the
Cloudflare Tunnel — same pattern as the atelier backend.

## Run (PC, test now — no model needed)

```bash
ASR_BACKEND=stub python3 tools/asr/asr_server.py --port 8770
curl -s -X POST --data-binary @any.wav http://127.0.0.1:8770/transcribe   # -> {"text": "..."}
```

The **stub** backend rotates canned transcripts so the whole pipeline (mic → service → option
mapping) is testable with zero deps. Swap in a real backend when ready:

| `ASR_BACKEND` | install | note |
|---------------|---------|------|
| `stub` | — | rotating canned text; pipeline test |
| `faster-whisper` | `pip install faster-whisper` ; `ASR_MODEL=base` | robust CPU int8, multilingual (FR) |
| `sherpa-onnx` | `pip install sherpa-onnx` | streaming; for Nemotron ONNX exports (wire the recognizer) |
| `nemo` | `pip install nemo_toolkit[asr]` | `ASR_MODEL=nvidia/nemotron-speech-streaming-en-0.6b` (heavy) |

> The user's "Nemotron 0.6B" is `nvidia/nemotron-speech-streaming-en-0.6b` — an **ASR** model
> (English streaming). For French voice, `faster-whisper` (base/small) is the pragmatic CPU pick;
> use the `nemo`/`sherpa-onnx` backends for the Nemotron model itself.

## Godot wiring

Add a `VoiceCapture` audio bus with an `AudioEffectCapture`, attach `voice_recognition.gd` as a
node, set `asr_url` (the tunnel/loopback URL) + optional `asr_token`, then:

```gdscript
voice.voice_recognized.connect(func(text):
    var idx := VoiceRecognition.match_choice(text, current_card.options)  # -1 if no match
    if idx >= 0: _select_option(idx))
voice.start_listening()   # push-to-talk down
voice.stop_listening()    # push-to-talk up -> transcribe -> choice
```

`match_choice(text, options)` is pure/static and unit-tested (headless): it scores the share of
spoken content-words an option explains + a verb bonus (reflexive `s'` handled).

## Deploy 24/7 (VM/Oracle)

Mirror the cockpit deploy: venv + `merlin-asr.service` (loopback :8770) + a tunnel
(`TUNNEL_PORT=8770 bash infra/fleet/atelier/deploy/tunnel.sh named asr`). Put
`ASR_BACKEND`/`ASR_MODEL`/`ASR_TOKEN` in `/etc/merlin-asr.env` (0600, gitignored).

## Free / honest

- CPU, open models, 0 €. **On 1 GB VM, ASR + LLM together is very tight** → run one at a time,
  or host ASR on Oracle A1 when available. The Nemotron model is English-only; French needs Whisper.
