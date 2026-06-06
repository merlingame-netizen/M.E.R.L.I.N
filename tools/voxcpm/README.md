# VoxCPM local TTS — M.E.R.L.I.N.

Neural text-to-speech with **voice cloning**, running locally. Used for Merlin's
in-game voice (`use_my_voice`) and reusable from the CLI for any project.

- **Model**: [VoxCPM](https://github.com/OpenBMB/VoxCPM) — tokenizer-free TTS,
  30 languages **including French**, zero-shot voice cloning, 48 kHz, Apache-2.0.
- **Shape**: a small FastAPI server in a dedicated venv (like Ollama), driven by
  a CLI adapter and a Godot autoload.
- **Profile here**: **CPU-only** → lighter `VoxCPM-0.5B` + aggressive disk cache.

> Full guide: [`docs/VOXCPM_DEPLOYMENT.md`](../../docs/VOXCPM_DEPLOYMENT.md)

## Quick start (Windows)

```bat
:: 1. Install (CPU venv + voxcpm + deps). ~Several GB on first run.
tools\voxcpm\install.bat

:: 2. Start the server (stays running in this terminal).
tools\voxcpm\start.bat

:: 3. In another terminal — check it's alive:
python tools\cli.py voxcpm status --human

:: 4. Synthesize a line to a wav:
python tools\cli.py voxcpm synth --text "Bonjour, je suis Merlin." --out merlin.wav

:: 5. Play it right away:
python tools\cli.py voxcpm speak --text "Approche, jeune druide."
```

GPU machine instead? `tools\voxcpm\install.bat -Device cuda121 -Model openbmb/VoxCPM2 -Prefetch`

## Voice cloning (`use_my_voice`)

```bat
:: Register a 3-15s clean sample (transcript optional but improves fidelity):
python tools\cli.py voxcpm add-voice --name merlin --audio "C:\rec\sample.wav" --text "Ceci est ma voix."

:: Use it:
python tools\cli.py voxcpm synth --text "La forêt t'attend." --voice merlin --out out.wav
```

See [`voices/README.md`](voices/README.md) for sample guidelines.

## Files

| File | Role |
|---|---|
| `server.py` | FastAPI server: `/health`, `/voices`, `/synth`, `/v1/audio/speech`. Lazy model load, device auto-detect, SHA-1 disk cache, cloning. |
| `install.ps1` / `install.bat` | Create `.venv-voxcpm`, install torch (CPU/CUDA) + voxcpm + deps, optional model prefetch. |
| `start.ps1` / `start.bat` | Launch the server, seeding config from `config.json`. |
| `requirements.txt` | Server deps (torch installed separately by the script). |
| `config.example.json` | Copy to `config.json` to set model/device/port. |
| `voices/` | Reference voice samples for cloning (`<name>.wav` + optional `<name>.txt`). |
| `cache/` | Generated WAV cache (git-ignored). |

## OpenAI-compatible endpoint

```bash
curl -s http://127.0.0.1:8808/v1/audio/speech \
  -H "Content-Type: application/json" \
  -d '{"model":"voxcpm","input":"Hello from VoxCPM","voice":"merlin"}' --output speech.wav
```

Point any OpenAI-TTS client at `http://127.0.0.1:8808/v1`.

## Notes

- **First call is slow on CPU** (model download + high RTF). After that, the disk
  cache makes repeated lines instant.
- The server **lazy-loads** the model on the first `/synth`, so it boots fast and
  `python -c "import server"` works without the heavy wheels (handy for CI).
- In Godot, the `MerlinTTS` autoload no-ops gracefully when the server is down —
  the game never blocks on TTS.
