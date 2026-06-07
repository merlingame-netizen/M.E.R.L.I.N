# Local TTS — M.E.R.L.I.N. (Piper default · VoxCPM optional)

Local text-to-speech for Merlin's voice and any other use. One HTTP contract,
two engines behind it.

| Engine | Speed (CPU) | Voice cloning | Notes |
|---|---|---|---|
| **Piper** (default) | **fast** (RTF ~0.5) | no (preset voices) | French, ~60 MB, no torch. **Recommended for CPU.** |
| VoxCPM | very slow on CPU | yes | GPU-oriented. Keep for offline cloning / GPU boxes. |

**Merlin = male robot voice**: Piper's French male voice (`fr_FR-tom-medium`) + a
server-side robot FX (ring-mod + bitcrush). Tunable, cached, identical in game /
CLI / test page.

> Full guide: [`docs/VOXCPM_DEPLOYMENT.md`](../../docs/VOXCPM_DEPLOYMENT.md)

## Quick start (Windows, CPU)

```bat
:: 1. Install Piper + the French Merlin voice (no torch, ~60 MB):
tools\voxcpm\install.bat

:: 2. Start the server (stays running):
tools\voxcpm\start.bat

:: 3. Test in the browser (served by the server, no CORS hassle):
::    open  http://127.0.0.1:8808/
::    or from the CLI:
python tools\cli.py voxcpm speak --text "Je suis Merlin, gardien de Brocéliande."
```

## Robot voice controls

- Test page: checkbox **🤖 Voix de robot** + intensity slider.
- CLI: `python tools\cli.py voxcpm synth --text "..." --robot_intensity 0.9`
  or `--robot 0` to disable.
- Server defaults: `VOXCPM_ROBOT=1`, `VOXCPM_ROBOT_INTENSITY=0.7` (or `config.json`).

## Change Merlin's voice

Default `fr_FR-tom-medium` (male). Drop other Piper voices in `piper_voices/`
(see its README) and set `PIPER_MODEL` / pass `--voice <name>`.

## Optional: VoxCPM cloning

```bat
tools\voxcpm\install.bat -Engine voxcpm -Device cuda121   :: needs a GPU to be usable
```
Then `engine: "voxcpm"` in `config.json` and register a clone with
`voxcpm add-voice`. On CPU this is impractically slow — prefer offline batch use.

## Files

| File | Role |
|---|---|
| `server.py` | Multi-engine FastAPI server: `/`, `/health`, `/voices`, `/synth`, `/v1/audio/speech`. Robot FX + disk cache. |
| `install.ps1`/`.bat` | venv + Piper (default) or VoxCPM (`-Engine voxcpm`); downloads the Piper voice. |
| `start.ps1`/`.bat` | Launch the server (seeds engine/robot from `config.json`). |
| `requirements.txt` | Piper engine deps (no torch). |
| `requirements-voxcpm.txt` | Optional VoxCPM deps. |
| `test_voice.html` | Browser test UI (served at `/`). |
| `piper_voices/` | Piper ONNX voices (git-ignored; install downloads them). |
| `voices/` | VoxCPM reference clones (when using that engine). |
| `cache/` | Generated WAV cache (git-ignored). |
