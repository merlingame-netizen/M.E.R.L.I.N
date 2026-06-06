#!/usr/bin/env python3
"""
VoxCPM local TTS server — M.E.R.L.I.N.

A thin FastAPI wrapper around the VoxCPM tokenizer-free TTS model. Provides a
stable HTTP contract so the Godot game (autoload `MerlinTTS`), the CLI adapter
(`python tools/cli.py voxcpm ...`) and any other tool can request speech without
loading the model themselves.

Design notes
------------
* The model is **lazy-loaded** on first synthesis request, so the server boots
  instantly and `import server` works even without the heavy `voxcpm` / `torch`
  wheels installed (useful for syntax checks / CI).
* **Device auto-detect** (`auto` -> cuda if available else cpu). The user runs
  CPU-only, so CUDA is forced off when device == "cpu".
* **Disk cache** keyed by SHA-1 of (model, text, voice, params). On CPU the RTF
  is well above 1.0, so caching is essential — repeated lines play instantly.
* **Voice cloning** (`use_my_voice`): a "voice" is a wav file under
  `VOXCPM_VOICES_DIR/<name>.wav` with an optional transcript `<name>.txt`.
  When present, synthesis is conditioned on it (prompt_wav_path + prompt_text).

Endpoints
---------
  GET  /health                 -> status, model, device, loaded, voices
  GET  /voices                 -> list of registered reference voices
  POST /synth                  -> audio/wav bytes (or JSON+base64 with ?format=json)
  POST /v1/audio/speech        -> OpenAI-compatible speech endpoint (audio bytes)

Config (env vars, all optional)
-------------------------------
  VOXCPM_MODEL        default "openbmb/VoxCPM-0.5B"   (CPU-friendly; "openbmb/VoxCPM2" for GPU)
  VOXCPM_DEVICE       default "auto"                  (auto | cpu | cuda)
  VOXCPM_HOST         default "127.0.0.1"
  VOXCPM_PORT         default "8808"
  VOXCPM_VOICES_DIR   default "<this_dir>/voices"
  VOXCPM_CACHE_DIR    default "<this_dir>/cache"
  VOXCPM_CFG_VALUE    default "2.0"
  VOXCPM_TIMESTEPS    default "10"     (LocDiT steps; low = faster, good for CPU)
  VOXCPM_NORMALIZE    default "0"      (1 enables external text-normalization tool)

Run:  python tools/voxcpm/server.py          (or use start.ps1 / start.bat)
"""

# NOTE: deliberately NO `from __future__ import annotations` here. The FastAPI
# route handlers are nested inside build_app() and annotate params with `Request`
# (a name local to that function). With stringified annotations FastAPI can't
# resolve those local names against module globals and mis-reads them as query
# params, so we keep real (eagerly-evaluated) annotations. Requires Python 3.10+
# (which VoxCPM mandates anyway) for the `X | None` union syntax used below.

import hashlib
import io
import json
import os
import threading
import wave
from pathlib import Path
from typing import Any, Optional

# ── Configuration ─────────────────────────────────────────────────────────────

_HERE = Path(__file__).resolve().parent

MODEL_NAME = os.environ.get("VOXCPM_MODEL", "openbmb/VoxCPM-0.5B")
DEVICE_PREF = os.environ.get("VOXCPM_DEVICE", "auto").lower()
HOST = os.environ.get("VOXCPM_HOST", "127.0.0.1")
PORT = int(os.environ.get("VOXCPM_PORT", "8808"))
VOICES_DIR = Path(os.environ.get("VOXCPM_VOICES_DIR", str(_HERE / "voices")))
CACHE_DIR = Path(os.environ.get("VOXCPM_CACHE_DIR", str(_HERE / "cache")))
DEFAULT_CFG = float(os.environ.get("VOXCPM_CFG_VALUE", "2.0"))
DEFAULT_TIMESTEPS = int(os.environ.get("VOXCPM_TIMESTEPS", "10"))
DEFAULT_NORMALIZE = os.environ.get("VOXCPM_NORMALIZE", "0") not in ("0", "", "false", "False")

VOICES_DIR.mkdir(parents=True, exist_ok=True)
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# ── Lazy model holder ─────────────────────────────────────────────────────────

_model = None
_model_lock = threading.Lock()
_resolved_device = "cpu"
_sample_rate = 16000  # overwritten once the real model is loaded


def _resolve_device() -> str:
    """Pick the runtime device, honoring VOXCPM_DEVICE."""
    if DEVICE_PREF == "cpu":
        # Hard-force CPU so frameworks never grab a GPU.
        os.environ["CUDA_VISIBLE_DEVICES"] = ""
        return "cpu"
    try:
        import torch  # noqa: PLC0415

        if DEVICE_PREF == "cuda":
            return "cuda" if torch.cuda.is_available() else "cpu"
        # auto
        return "cuda" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


def _load_model() -> Any:
    """Lazy-load the VoxCPM model exactly once (thread-safe)."""
    global _model, _resolved_device, _sample_rate
    if _model is not None:
        return _model
    with _model_lock:
        if _model is not None:
            return _model
        _resolved_device = _resolve_device()
        from voxcpm import VoxCPM  # noqa: PLC0415 — heavy import, deferred

        # load_denoiser=False keeps memory low (important on CPU).
        try:
            model = VoxCPM.from_pretrained(MODEL_NAME, load_denoiser=False)
        except TypeError:
            # Older/newer signatures may not accept load_denoiser.
            model = VoxCPM.from_pretrained(MODEL_NAME)

        # Best-effort device move (some versions auto-place the model).
        try:
            if _resolved_device == "cpu" and hasattr(model, "tts_model"):
                inner = getattr(model.tts_model, "to", None)
                if callable(inner):
                    model.tts_model.to("cpu")
        except Exception:
            pass

        try:
            _sample_rate = int(model.tts_model.sample_rate)
        except Exception:
            _sample_rate = 16000

        _model = model
        return _model


# ── Voice registry ────────────────────────────────────────────────────────────

def _list_voices() -> list[dict]:
    """Reference voices = <name>.wav (+ optional <name>.txt transcript)."""
    voices = []
    for wav in sorted(VOICES_DIR.glob("*.wav")):
        txt = wav.with_suffix(".txt")
        transcript = ""
        if txt.exists():
            try:
                transcript = txt.read_text(encoding="utf-8").strip()
            except Exception:
                transcript = ""
        voices.append({
            "name": wav.stem,
            "wav": str(wav),
            "has_transcript": txt.exists(),
            "transcript": transcript,
        })
    return voices


def _resolve_voice(voice: str) -> Optional[dict]:
    if not voice:
        return None
    wav = VOICES_DIR / f"{voice}.wav"
    if not wav.exists():
        return None
    txt = wav.with_suffix(".txt")
    transcript = ""
    if txt.exists():
        try:
            transcript = txt.read_text(encoding="utf-8").strip()
        except Exception:
            transcript = ""
    return {"name": voice, "wav": str(wav), "transcript": transcript}


# ── Audio helpers ─────────────────────────────────────────────────────────────

def _wav_bytes_from_float(samples: Any, sample_rate: int) -> bytes:
    """Encode a float waveform (numpy array, range ~[-1,1]) to 16-bit PCM WAV.

    Uses soundfile if available (handles odd dtypes), else a stdlib wave fallback.
    Godot's AudioStreamWAV.load_from_buffer parses standard PCM16 WAV.
    """
    try:
        import numpy as np  # noqa: PLC0415
        import soundfile as sf  # noqa: PLC0415

        arr = np.asarray(samples, dtype="float32").reshape(-1)
        buf = io.BytesIO()
        sf.write(buf, arr, sample_rate, format="WAV", subtype="PCM_16")
        return buf.getvalue()
    except Exception:
        # stdlib fallback — clip + int16 encode
        import array
        import struct

        try:
            flat = [float(x) for x in samples]
        except TypeError:
            flat = list(samples)
        ints = array.array("h")
        for x in flat:
            v = max(-1.0, min(1.0, x))
            ints.append(int(v * 32767.0))
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sample_rate)
            w.writeframes(ints.tobytes())
        _ = struct  # keep import meaningful for linters
        return buf.getvalue()


def _cache_key(text: str, voice: str, cfg: float, timesteps: int, normalize: bool) -> str:
    payload = json.dumps(
        {"m": MODEL_NAME, "t": text, "v": voice, "c": cfg, "s": timesteps, "n": normalize},
        ensure_ascii=False,
        sort_keys=True,
    )
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def _synthesize(
    text: str,
    voice: str = "",
    cfg_value: Optional[float] = None,
    inference_timesteps: Optional[int] = None,
    normalize: Optional[bool] = None,
    use_cache: bool = True,
) -> tuple[bytes, bool]:
    """Return (wav_bytes, from_cache). Raises on model failure."""
    text = (text or "").strip()
    if not text:
        raise ValueError("text is empty")

    cfg = DEFAULT_CFG if cfg_value is None else float(cfg_value)
    steps = DEFAULT_TIMESTEPS if inference_timesteps is None else int(inference_timesteps)
    norm = DEFAULT_NORMALIZE if normalize is None else bool(normalize)

    key = _cache_key(text, voice, cfg, steps, norm)
    cache_file = CACHE_DIR / f"{key}.wav"
    if use_cache and cache_file.exists():
        return cache_file.read_bytes(), True

    model = _load_model()

    gen_kwargs: dict[str, Any] = {
        "text": text,
        "cfg_value": cfg,
        "inference_timesteps": steps,
        "normalize": norm,
    }
    resolved = _resolve_voice(voice)
    if resolved:
        # prompt_wav_path + prompt_text works across VoxCPM 0.5B and VoxCPM2
        # ("ultimate cloning"). prompt_text may be empty (reference-only mode).
        gen_kwargs["prompt_wav_path"] = resolved["wav"]
        if resolved["transcript"]:
            gen_kwargs["prompt_text"] = resolved["transcript"]

    # Be tolerant of signature differences between versions.
    try:
        wav = model.generate(**gen_kwargs)
    except TypeError:
        gen_kwargs.pop("normalize", None)
        wav = model.generate(**gen_kwargs)

    audio = _wav_bytes_from_float(wav, _sample_rate)
    if use_cache:
        try:
            cache_file.write_bytes(audio)
        except Exception:
            pass
    return audio, False


# ── FastAPI app ───────────────────────────────────────────────────────────────

def build_app():
    from fastapi import FastAPI, Query, Request, Response  # noqa: PLC0415
    from fastapi.responses import JSONResponse  # noqa: PLC0415

    app = FastAPI(title="VoxCPM TTS — M.E.R.L.I.N.", version="1.0")

    @app.get("/health")
    def health() -> dict:
        return {
            "status": "ok",
            "model": MODEL_NAME,
            "device": _resolved_device if _model is not None else f"{DEVICE_PREF} (pending)",
            "loaded": _model is not None,
            "sample_rate": _sample_rate if _model is not None else None,
            "voices": [v["name"] for v in _list_voices()],
            "cache_dir": str(CACHE_DIR),
            "voices_dir": str(VOICES_DIR),
        }

    @app.get("/voices")
    def voices() -> dict:
        return {"voices": _list_voices()}

    @app.post("/synth")
    async def synth(request: Request, format: str = Query("wav")) -> Response:
        try:
            body = await request.json()
        except Exception:
            body = {}
        text = body.get("text", "")
        voice = body.get("voice", "")
        try:
            audio, cached = _synthesize(
                text=text,
                voice=voice,
                cfg_value=body.get("cfg_value"),
                inference_timesteps=body.get("inference_timesteps"),
                normalize=body.get("normalize"),
                use_cache=body.get("cache", True),
            )
        except Exception as exc:  # noqa: BLE001
            return JSONResponse(status_code=500, content={"status": "error", "error": str(exc)})

        if format == "json":
            import base64

            return JSONResponse(content={
                "status": "ok",
                "cached": cached,
                "sample_rate": _sample_rate,
                "voice": voice,
                "audio_b64": base64.b64encode(audio).decode("ascii"),
            })
        headers = {"X-Voxcpm-Cached": "1" if cached else "0"}
        return Response(content=audio, media_type="audio/wav", headers=headers)

    @app.post("/v1/audio/speech")
    async def openai_speech(request: Request) -> Response:
        """OpenAI-compatible: {model, input, voice, response_format}."""
        try:
            body = await request.json()
        except Exception:
            body = {}
        text = body.get("input", "")
        voice = body.get("voice", "") or ""
        # OpenAI default voices (alloy/echo/...) aren't ours -> treat as default.
        if voice and _resolve_voice(voice) is None:
            voice = ""
        try:
            audio, cached = _synthesize(text=text, voice=voice)
        except Exception as exc:  # noqa: BLE001
            return JSONResponse(status_code=500, content={"error": {"message": str(exc)}})
        fmt = (body.get("response_format") or "wav").lower()
        media = "audio/wav" if fmt in ("wav", "pcm") else "audio/wav"
        return Response(content=audio, media_type=media, headers={"X-Voxcpm-Cached": "1" if cached else "0"})

    return app


def main() -> None:
    import uvicorn  # noqa: PLC0415

    print(f"[VoxCPM] model={MODEL_NAME} device={DEVICE_PREF} host={HOST} port={PORT}")
    print(f"[VoxCPM] voices_dir={VOICES_DIR}")
    print(f"[VoxCPM] cache_dir={CACHE_DIR}")
    print("[VoxCPM] model loads lazily on first /synth call.")
    uvicorn.run(build_app(), host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
    main()
