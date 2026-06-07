# Piper voices

Piper ONNX voice models live here (`<name>.onnx` + `<name>.onnx.json`). They are
git-ignored (60+ MB each) — the install script downloads them for you.

Default (Merlin = male French): **`fr_FR-tom-medium`**.

## Add / change a voice

`install.ps1` downloads `fr_FR-tom-medium` by default. To grab another French
voice manually (from the Piper voices repo on Hugging Face):

```powershell
$base = "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR"
# e.g. gilles (low, light) or upmc (multi-speaker)
Invoke-WebRequest "$base/gilles/low/fr_FR-gilles-low.onnx"      -OutFile fr_FR-gilles-low.onnx
Invoke-WebRequest "$base/gilles/low/fr_FR-gilles-low.onnx.json" -OutFile fr_FR-gilles-low.onnx.json
```

Then point the server at it: set `PIPER_MODEL=fr_FR-gilles-low` (env or
`config.json`), or pass `--voice fr_FR-gilles-low` per request.

Browse all voices: https://huggingface.co/rhasspy/piper-voices

## Robot voice

Merlin's "male robot" timbre is a server-side post-FX (ring-mod + bitcrush), not a
separate model — it works on top of any Piper voice. Tune it with
`VOXCPM_ROBOT_INTENSITY` (0..1) or the `robot_intensity` request field.
