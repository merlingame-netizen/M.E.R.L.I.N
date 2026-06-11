# -*- coding: utf-8 -*-
"""Generate the MERLIN main theme (ambient celtic slow) with MusicGen.

Outputs a seamless-loop WAV at music/theme/merlin_main_theme.wav.
CPU-only friendly (facebook/musicgen-small). Bible ref: docs/BIBLE.md §22 (R117 Audio —
menu = theme celtique lent, boucle crossfade equal-power).
"""
import sys
import time
from pathlib import Path

import numpy as np

PROJECT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT / "music" / "theme"
OUT_WAV = OUT_DIR / "merlin_main_theme.wav"

PROMPT = (
    "slow ambient celtic theme, ethereal celtic harp arpeggios, soft low whistle "
    "melody, deep mystical drone pad, druidic forest atmosphere, meditative, "
    "melancholic, sparse, fantasy game main menu music, very slow tempo"
)

DURATION_S = 30          # musicgen-small ceiling ~30s
TOKENS_PER_S = 50        # 50 audio tokens per second
CROSSFADE_S = 2.5        # tail->head crossfade for seamless looping


def log(msg: str) -> None:
    print(f"[musicgen {time.strftime('%H:%M:%S')}] {msg}", flush=True)


def make_seamless_loop(audio: np.ndarray, sr: int, fade_s: float) -> np.ndarray:
    """Equal-power crossfade of the tail into the head so the loop point is inaudible."""
    n_fade = int(sr * fade_s)
    if n_fade * 2 >= audio.shape[-1]:
        return audio
    head = audio[:n_fade]
    tail = audio[-n_fade:]
    t = np.linspace(0.0, 1.0, n_fade, dtype=np.float32)
    fade_in = np.sin(t * np.pi / 2.0) ** 2
    fade_out = np.cos(t * np.pi / 2.0) ** 2
    blended = tail * fade_out + head * fade_in
    return np.concatenate([blended, audio[n_fade:-n_fade]])


def main() -> int:
    log("loading model facebook/musicgen-small (CPU)...")
    import torch
    from transformers import AutoProcessor, MusicgenForConditionalGeneration

    torch.manual_seed(420)  # reproducible take
    processor = AutoProcessor.from_pretrained("facebook/musicgen-small")
    model = MusicgenForConditionalGeneration.from_pretrained("facebook/musicgen-small")
    model.eval()
    log(f"model loaded, generating {DURATION_S}s of audio (this is slow on CPU)...")

    inputs = processor(text=[PROMPT], padding=True, return_tensors="pt")
    t0 = time.time()
    with torch.no_grad():
        audio_values = model.generate(
            **inputs,
            do_sample=True,
            guidance_scale=3.0,
            top_k=250,
            max_new_tokens=DURATION_S * TOKENS_PER_S,
        )
    log(f"generation done in {time.time() - t0:.0f}s")

    sr = model.config.audio_encoder.sampling_rate  # 32000
    audio = audio_values[0, 0].cpu().numpy().astype(np.float32)

    # Normalize to ~-1 dBFS headroom, then loop-blend.
    peak = float(np.max(np.abs(audio)))
    if peak > 0:
        audio = audio * (0.89 / peak)
    audio = make_seamless_loop(audio, sr, CROSSFADE_S)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    import scipy.io.wavfile as wavfile
    wavfile.write(str(OUT_WAV), sr, (audio * 32767.0).astype(np.int16))
    log(f"written {OUT_WAV} ({OUT_WAV.stat().st_size / 1e6:.1f} MB, {len(audio) / sr:.1f}s @ {sr} Hz)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
