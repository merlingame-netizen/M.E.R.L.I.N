# VoxCPM Local Deployment — M.E.R.L.I.N.

> Neural TTS + voice cloning, deployed locally for the game (Merlin's voice) and
> any other project. Profile: **CPU-only, Windows-first, native venv + server**.
> Decided 2026-06-06. Branch `claude/voxcpm-local-deploy-V118n`.

This covers the backlog item the Game Design Bible flags as *non implémenté*:
**“Merlin speech-bar + TTS (`use_my_voice`)”** (Phase 2.1.5).

---

## 1. What VoxCPM is

[VoxCPM](https://github.com/OpenBMB/VoxCPM) is a tokenizer-free, diffusion-AR TTS
system from OpenBMB.

| Property | Value |
|---|---|
| Languages | 30, **including French** |
| Voice cloning | Zero-shot (`prompt_wav_path` + `prompt_text`) |
| Output | 48 kHz |
| License | Apache-2.0 (commercial OK) |
| Models | `openbmb/VoxCPM-0.5B` (light) · `openbmb/VoxCPM2` (2B, best) |
| Requirements | Python 3.10–3.12, PyTorch ≥ 2.5; GPU path needs CUDA 12+ & ~8 GB VRAM |

**CPU reality**: it runs on CPU but the real-time factor is well above 1.0 (a few
seconds of audio take longer than that to generate). Our deployment mitigates this
two ways: the lighter **0.5B** model by default, and a **disk cache** so any line
is synthesized once and replayed instantly thereafter.

---

## 2. Architecture

```
                         ┌──────────────────────────────┐
   Godot game  ─────────▶│  MerlinTTS autoload (GDScript)│
   (speech-bar)          │  HTTPRequest → WAV → play     │
                         └───────────────┬──────────────┘
                                         │ POST /synth
   CLI / other apps ─────────────────────┤ (localhost:8808)
   python tools/cli.py voxcpm ...         │
                                         ▼
                         ┌──────────────────────────────┐
                         │  VoxCPM server (FastAPI)      │
                         │  tools/voxcpm/server.py       │
                         │  • lazy model load            │
                         │  • device auto-detect (cpu)   │
                         │  • SHA-1 disk cache           │
                         │  • voice cloning              │
                         └───────────────┬──────────────┘
                                         ▼
                              voxcpm + torch  (.venv-voxcpm)
```

The server is the **only** component that loads the heavy model. Everything else
(the CLI adapter, the Godot autoload) is a light HTTP client — exactly the same
pattern as the existing Ollama integration.

---

## 3. Install (Windows)

```bat
:: CPU profile (default) — creates tools\voxcpm\.venv-voxcpm
tools\voxcpm\install.bat

:: GPU profile (if you ever move to an NVIDIA box):
tools\voxcpm\install.bat -Device cuda121 -Model openbmb/VoxCPM2 -Prefetch
```

What it does:
1. Finds a Python **3.10–3.12** interpreter (VoxCPM needs `<3.13`).
2. Creates the `.venv-voxcpm` virtual environment.
3. Installs the matching **torch** wheel (CPU index by default — avoids pulling a
   multi-GB CUDA build onto a CPU box).
4. Installs `voxcpm`, `fastapi`, `uvicorn`, `soundfile`, `numpy`.
5. With `-Prefetch`, downloads the model weights now instead of on first call.

### Linux / macOS

No `.sh` wrapper ships (Windows-first per the deploy decision), but it's three
commands:

```bash
python3 -m venv tools/voxcpm/.venv-voxcpm
tools/voxcpm/.venv-voxcpm/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu
tools/voxcpm/.venv-voxcpm/bin/pip install -r tools/voxcpm/requirements.txt
tools/voxcpm/.venv-voxcpm/bin/python tools/voxcpm/server.py
```

---

## 4. Run

```bat
tools\voxcpm\start.bat
```

Leave it running. It reads `tools/voxcpm/config.json` (copy from
`config.example.json`) for model/device/port; shell env vars override the file.

Configuration knobs (env `VOXCPM_*` or `config.json`):

| Key | Default | Meaning |
|---|---|---|
| `model` | `openbmb/VoxCPM-0.5B` | HF model id |
| `device` | `auto` | `auto` \| `cpu` \| `cuda` |
| `host` / `port` | `127.0.0.1` / `8808` | bind address |
| `cfg_value` | `2.0` | guidance strength |
| `inference_timesteps` | `10` | LocDiT steps (low = faster; good for CPU) |
| `normalize` | `false` | external text-normalization (extra deps) |

---

## 5. Use from the CLI

```bash
python tools/cli.py voxcpm status --human          # health: model, device, voices
python tools/cli.py voxcpm voices                   # registered reference voices
python tools/cli.py voxcpm synth --text "Bonjour."  # → ./voxcpm_out.wav
python tools/cli.py voxcpm synth --text "Salut" --voice merlin --out hello.wav
python tools/cli.py voxcpm speak --text "Approche." # synth + play
python tools/cli.py voxcpm add-voice --name merlin --audio sample.wav --text "Ma voix."
python tools/cli.py voxcpm models                   # known models + server's current
```

JSON by default (agent-native); add `--human` for pretty output. Exit code 0/1
for CI / AUTODEV pipelines, like every other CLI-Anything tool.

---

## 6. Use in the game

`MerlinTTS` is registered as a Godot autoload, so it's globally available:

```gdscript
# Anywhere — e.g. when the speech-bar reveals a Merlin line:
MerlinTTS.speak("Bonjour, jeune druide. La forêt t'attend.")

# With the cloned voice:
MerlinTTS.speak("Approche...", "merlin")

# React to playback (e.g. animate the speech-bar while speaking):
MerlinTTS.speech_started.connect(func(_t): sound_bar.start_speaking())
MerlinTTS.speech_finished.connect(func(): sound_bar.stop_speaking())

# Options toggle:
MerlinTTS.set_enabled(false)
```

Guarantees:
- **Graceful offline**: if the server isn't running, every call is a no-op. The
  game never blocks or errors on TTS.
- **Cache**: synthesized lines are stored in `user://voxcpm_cache/` and replay
  instantly — important on CPU.
- **Sequential**: requests are queued so lines don't overlap.

### Wiring it into the speech-bar

The autoload is the plumbing; the trigger lives wherever Merlin lines are shown.
To make Merlin actually speak, add one line next to the existing text reveal — for
example in the parchment/typewriter intro or the `MerlinSoundBar` flow:

```gdscript
MerlinTTS.speak(intro_text)            # default voice
MerlinTTS.speak(intro_text, MerlinTTS.default_voice)
```

Set `MerlinTTS.default_voice = "merlin"` once you've registered a `merlin.wav`
reference so all Merlin lines use the cloned voice. (This is left as an explicit
opt-in rather than auto-wired everywhere, since which lines should be voiced is a
game-design decision per Bible §21.)

---

## 7. Voice cloning (`use_my_voice`)

A voice is just a file pair under `tools/voxcpm/voices/`:

```
merlin.wav   # 3-15 s, single speaker, clean
merlin.txt   # (optional) exact transcript → "ultimate cloning" fidelity
```

Register via the CLI (`voxcpm add-voice`) or drop the files in manually. Then pass
`--voice merlin` (CLI) or `MerlinTTS.speak(text, "merlin")` (game).

Only clone voices you have the right to use. `.wav` files are git-ignored by
default; force-add a synthetic Merlin voice if you want it versioned.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `voxcpm status` → "server unreachable" | Start it: `tools\voxcpm\start.bat`. Check the port (8808). |
| First synth hangs ~minutes | Normal on first call (model download + CPU). Use `-Prefetch` at install, then it's just slow, not stuck. |
| `No Python 3.10-3.12 found` | Install one and re-run; VoxCPM doesn't support 3.13+. |
| Torch pulled a CUDA build on a CPU box | Reinstall with `-Device cpu` (uses the CPU wheel index). |
| Godot: no voice but no errors | Expected when server is down — `MerlinTTS` no-ops. Check `MerlinTTS.is_available()`. |
| Audio garbled in Godot | Ensure server returns PCM16 WAV (default). `AudioStreamWAV.load_from_buffer` needs Godot ≥ 4.4. |

---

## 9. Security & footprint

- Binds to **localhost** only by default — not exposed to the network.
- Model weights, the venv, the cache and generated audio are **git-ignored**.
- No API keys; everything runs offline after the initial model download.
