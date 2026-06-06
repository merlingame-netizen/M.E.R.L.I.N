# VoxCPM reference voices (`use_my_voice`)

Drop voice samples here to clone a voice. A "voice" named `merlin` is just:

```
tools/voxcpm/voices/merlin.wav     # 3-15 s of clean speech, mono, 16-48 kHz
tools/voxcpm/voices/merlin.txt     # (optional) exact transcript of the wav
```

Then synthesize with it:

```bash
python tools/cli.py voxcpm synth --text "Bonjour, je suis Merlin." --voice merlin --out merlin.wav
```

Or register one straight from a recording:

```bash
python tools/cli.py voxcpm add-voice --name merlin --audio "C:\path\to\sample.wav" --text "Ceci est ma voix."
```

## Tips for a good clone

- **3–15 seconds** of a single speaker, no music/noise, no long silences.
- Provide the **transcript** (`.txt`) for *ultimate cloning* quality — it lets
  VoxCPM align text↔audio (`prompt_wav_path` + `prompt_text`). Without it, the
  model still clones in reference-only mode, slightly less faithfully.
- Match the **target language** of what you'll synthesize (French for Merlin).
- 48 kHz output; the source sample can be any sample rate (it gets resampled).

## Privacy / git

`.wav` files are git-ignored by default. If you *want* to version a reference
voice (e.g. a synthetic Merlin voice, not a real person without consent), add it
explicitly: `git add -f tools/voxcpm/voices/merlin.wav`.

Only clone voices you have the right to use.
