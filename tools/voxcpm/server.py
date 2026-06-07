#!/usr/bin/env python3
"""
Local TTS server — M.E.R.L.I.N.  (Piper default · VoxCPM optional)

A stable HTTP TTS service so the Godot game (autoload `MerlinTTS`), the CLI
adapter (`python tools/cli.py voxcpm ...`) and the browser test page all share one
contract — regardless of which engine synthesizes underneath.

Engines
-------
* **piper** (default) — fast on CPU (RTF ~0.5), French voices, tiny (~60 MB ONNX),
  no torch. Best fit for real-time, CPU-only machines. Preset voices (no cloning).
* **voxcpm** — neural voice cloning, French, but GPU-oriented (very slow on CPU).
  Keep for offline pre-generation / when a GPU is available.

Robot voice
-----------
An optional robotic post-FX (ring-modulation + bitcrush) turns Piper's male French
voice into a "male robot" — Merlin's voice for this project. On by default, tunable
per request (`robot`, `robot_intensity`) or via env.

Endpoints
---------
  GET  /                       -> the browser test page (test_voice.html)
  GET  /health                 -> engine, model, device, robot, voices
  GET  /voices                 -> available voices (piper: ONNX models; voxcpm: clones)
  POST /synth                  -> audio/wav bytes (or JSON+base64 with ?format=json)
  POST /v1/audio/speech        -> OpenAI-compatible speech endpoint

Config (env vars, all optional)
-------------------------------
  VOXCPM_ENGINE       default "piper"        (piper | voxcpm)
  VOXCPM_HOST/PORT    default 127.0.0.1 / 8808
  VOXCPM_CACHE_DIR    default "<dir>/cache"
  # Robot FX
  VOXCPM_ROBOT        default "1"            (1/0 — apply robot effect)
  VOXCPM_ROBOT_INTENSITY  default "0.7"      (0..1 dry/wet)
  VOXCPM_ROBOT_CARRIER    default "55"       (Hz ring-mod carrier)
  VOXCPM_ROBOT_BITS       default "6"        (bitcrush depth)
  # Piper
  PIPER_VOICES_DIR    default "<dir>/piper_voices"
  PIPER_MODEL         default "fr_FR-tom-medium"   (onnx stem in PIPER_VOICES_DIR)
  # VoxCPM
  VOXCPM_MODEL        default "openbmb/VoxCPM-0.5B"
  VOXCPM_DEVICE       default "auto"
  VOXCPM_VOICES_DIR   default "<dir>/voices"
  VOXCPM_CFG_VALUE/VOXCPM_TIMESTEPS/VOXCPM_NORMALIZE

Run:  python tools/voxcpm/server.py          (or use start.ps1 / start.bat)
"""

# NOTE: no `from __future__ import annotations` — FastAPI route handlers nested in
# build_app() annotate params with locally-imported types (Request); stringified
# annotations would break FastAPI's resolution. Requires Python 3.10+ (X | None).

import hashlib
import io
import json
import os
import threading
import wave
from pathlib import Path

# ── Configuration ─────────────────────────────────────────────────────────────

_HERE = Path(__file__).resolve().parent

ENGINE = os.environ.get("VOXCPM_ENGINE", "piper").lower()
HOST = os.environ.get("VOXCPM_HOST", "127.0.0.1")
PORT = int(os.environ.get("VOXCPM_PORT", "8808"))
CACHE_DIR = Path(os.environ.get("VOXCPM_CACHE_DIR", str(_HERE / "cache")))

# Robot FX
ROBOT_ENABLED = os.environ.get("VOXCPM_ROBOT", "1") not in ("0", "", "false", "False")
ROBOT_INTENSITY = float(os.environ.get("VOXCPM_ROBOT_INTENSITY", "0.7"))
ROBOT_CARRIER = float(os.environ.get("VOXCPM_ROBOT_CARRIER", "55"))
ROBOT_BITS = int(os.environ.get("VOXCPM_ROBOT_BITS", "6"))

# Piper
PIPER_VOICES_DIR = Path(os.environ.get("PIPER_VOICES_DIR", str(_HERE / "piper_voices")))
PIPER_MODEL = os.environ.get("PIPER_MODEL", "fr_FR-tom-medium")

# VoxCPM
VOXCPM_MODEL = os.environ.get("VOXCPM_MODEL", "openbmb/VoxCPM-0.5B")
VOXCPM_DEVICE = os.environ.get("VOXCPM_DEVICE", "auto").lower()
VOXCPM_VOICES_DIR = Path(os.environ.get("VOXCPM_VOICES_DIR", str(_HERE / "voices")))
VOXCPM_CFG = float(os.environ.get("VOXCPM_CFG_VALUE", "2.0"))
VOXCPM_TIMESTEPS = int(os.environ.get("VOXCPM_TIMESTEPS", "10"))
VOXCPM_NORMALIZE = os.environ.get("VOXCPM_NORMALIZE", "0") not in ("0", "", "false", "False")

CACHE_DIR.mkdir(parents=True, exist_ok=True)
PIPER_VOICES_DIR.mkdir(parents=True, exist_ok=True)
VOXCPM_VOICES_DIR.mkdir(parents=True, exist_ok=True)

# ── Lazy engine holders ───────────────────────────────────────────────────────

_lock = threading.Lock()
_piper_voices = {}          # name -> PiperVoice
_voxcpm_model = None
_voxcpm_device = "cpu"
_voxcpm_sr = 16000


# ── Piper engine ──────────────────────────────────────────────────────────────

def _piper_onnx_path(name):
    """Resolve a piper voice name to its .onnx path."""
    if name.endswith(".onnx"):
        p = Path(name)
        return p if p.is_absolute() else (PIPER_VOICES_DIR / p.name)
    return PIPER_VOICES_DIR / f"{name}.onnx"


def _load_piper(name):
    with _lock:
        if name in _piper_voices:
            return _piper_voices[name]
        from piper import PiperVoice  # noqa: PLC0415

        onnx = _piper_onnx_path(name)
        if not onnx.exists():
            raise FileNotFoundError(
                f"Piper voice '{name}' not found at {onnx}. "
                f"Download voices into {PIPER_VOICES_DIR} (install.ps1 does this)."
            )
        cfg = str(onnx) + ".json"
        cfg_arg = cfg if Path(cfg).exists() else None
        voice = PiperVoice.load(str(onnx), config_path=cfg_arg, use_cuda=False)
        _piper_voices[name] = voice
        return voice


def _piper_synth(text, voice_name):
    """Return (float32 mono samples in [-1,1], sample_rate)."""
    import numpy as np  # noqa: PLC0415

    voice = _load_piper(voice_name or PIPER_MODEL)
    chunks = list(voice.synthesize(text))
    if not chunks:
        return np.zeros(1, dtype="float32"), int(voice.config.sample_rate)
    arr = np.concatenate([c.audio_int16_array for c in chunks]).astype("float32") / 32768.0
    return arr, int(voice.config.sample_rate)


def _list_piper_voices():
    return sorted(p.stem for p in PIPER_VOICES_DIR.glob("*.onnx"))


# ── VoxCPM engine ─────────────────────────────────────────────────────────────

def _resolve_voxcpm_device():
    if VOXCPM_DEVICE == "cpu":
        os.environ["CUDA_VISIBLE_DEVICES"] = ""
        return "cpu"
    try:
        import torch  # noqa: PLC0415
        return "cuda" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


def _load_voxcpm():
    global _voxcpm_model, _voxcpm_device, _voxcpm_sr
    if _voxcpm_model is not None:
        return _voxcpm_model
    with _lock:
        if _voxcpm_model is not None:
            return _voxcpm_model
        _voxcpm_device = _resolve_voxcpm_device()
        from voxcpm import VoxCPM  # noqa: PLC0415

        try:
            model = VoxCPM.from_pretrained(VOXCPM_MODEL, load_denoiser=False)
        except TypeError:
            model = VoxCPM.from_pretrained(VOXCPM_MODEL)
        try:
            _voxcpm_sr = int(model.tts_model.sample_rate)
        except Exception:
            _voxcpm_sr = 16000
        _voxcpm_model = model
        return _voxcpm_model


def _resolve_voxcpm_voice(voice):
    if not voice:
        return None
    wav = VOXCPM_VOICES_DIR / f"{voice}.wav"
    if not wav.exists():
        return None
    txt = wav.with_suffix(".txt")
    transcript = txt.read_text(encoding="utf-8").strip() if txt.exists() else ""
    return {"wav": str(wav), "transcript": transcript}


def _voxcpm_synth(text, voice, cfg_value, inference_timesteps, normalize):
    import numpy as np  # noqa: PLC0415

    model = _load_voxcpm()
    gen = {
        "text": text,
        "cfg_value": VOXCPM_CFG if cfg_value is None else float(cfg_value),
        "inference_timesteps": VOXCPM_TIMESTEPS if inference_timesteps is None else int(inference_timesteps),
        "normalize": VOXCPM_NORMALIZE if normalize is None else bool(normalize),
    }
    ref = _resolve_voxcpm_voice(voice)
    if ref:
        gen["prompt_wav_path"] = ref["wav"]
        if ref["transcript"]:
            gen["prompt_text"] = ref["transcript"]
    try:
        wav = model.generate(**gen)
    except TypeError:
        gen.pop("normalize", None)
        wav = model.generate(**gen)
    return np.asarray(wav, dtype="float32").reshape(-1), _voxcpm_sr


def _list_voxcpm_voices():
    return sorted(p.stem for p in VOXCPM_VOICES_DIR.glob("*.wav"))


# ── Robot FX ──────────────────────────────────────────────────────────────────

def _apply_robot(samples, sr, intensity, carrier, bits):
    """Ring-modulation + bitcrush → 'male robot' timbre. intensity 0..1 dry/wet."""
    import numpy as np  # noqa: PLC0415

    x = np.asarray(samples, dtype="float32").reshape(-1)
    if x.size == 0 or intensity <= 0.0:
        return x
    t = np.arange(x.size, dtype="float32") / float(sr)
    ring = x * np.sin(2.0 * np.pi * carrier * t).astype("float32")
    levels = float(2 ** max(2, bits))
    crush = np.round(ring * levels) / levels
    wet = 0.6 * ring + 0.4 * crush
    out = (1.0 - intensity) * x + intensity * wet
    peak = float(np.max(np.abs(out))) or 1.0
    return (out / peak * 0.95).astype("float32")


# ── WAV encode ────────────────────────────────────────────────────────────────

def _wav_bytes(samples, sr):
    try:
        import numpy as np  # noqa: PLC0415
        import soundfile as sf  # noqa: PLC0415

        buf = io.BytesIO()
        sf.write(buf, np.asarray(samples, dtype="float32").reshape(-1), sr, format="WAV", subtype="PCM_16")
        return buf.getvalue()
    except Exception:
        import array

        ints = array.array("h")
        for v in samples:
            v = max(-1.0, min(1.0, float(v)))
            ints.append(int(v * 32767.0))
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(sr)
            w.writeframes(ints.tobytes())
        return buf.getvalue()


# ── Synthesis (engine dispatch + cache) ───────────────────────────────────────

def _cache_key(text, voice, robot, intensity, carrier, bits, extra):
    payload = json.dumps(
        {"e": ENGINE, "t": text, "v": voice, "r": robot, "ri": round(intensity, 3),
         "rc": carrier, "rb": bits, "x": extra},
        ensure_ascii=False, sort_keys=True,
    )
    return hashlib.sha1(payload.encode("utf-8")).hexdigest()


def synthesize(text, voice="", robot=None, robot_intensity=None,
               cfg_value=None, inference_timesteps=None, normalize=None, use_cache=True):
    """Return (wav_bytes, from_cache). Raises on engine failure."""
    text = (text or "").strip()
    if not text:
        raise ValueError("text is empty")

    do_robot = ROBOT_ENABLED if robot is None else bool(robot)
    intensity = ROBOT_INTENSITY if robot_intensity is None else float(robot_intensity)
    extra = {"cfg": cfg_value, "ts": inference_timesteps} if ENGINE == "voxcpm" else {}

    key = _cache_key(text, voice, do_robot, intensity, ROBOT_CARRIER, ROBOT_BITS, extra)
    cache_file = CACHE_DIR / f"{key}.wav"
    if use_cache and cache_file.exists():
        return cache_file.read_bytes(), True

    if ENGINE == "voxcpm":
        samples, sr = _voxcpm_synth(text, voice, cfg_value, inference_timesteps, normalize)
    else:
        samples, sr = _piper_synth(text, voice)

    if do_robot:
        samples = _apply_robot(samples, sr, intensity, ROBOT_CARRIER, ROBOT_BITS)

    audio = _wav_bytes(samples, sr)
    if use_cache:
        try:
            cache_file.write_bytes(audio)
        except Exception:
            pass
    return audio, False


def _list_voices():
    return _list_voxcpm_voices() if ENGINE == "voxcpm" else _list_piper_voices()


# ── FastAPI app ───────────────────────────────────────────────────────────────

def build_app():
    from fastapi import FastAPI, Query, Request, Response  # noqa: PLC0415
    from fastapi.responses import FileResponse, HTMLResponse, JSONResponse  # noqa: PLC0415
    from fastapi.middleware.cors import CORSMiddleware  # noqa: PLC0415

    app = FastAPI(title="MERLIN TTS (Piper/VoxCPM)", version="2.0")
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    _TEST_PAGE = _HERE / "test_voice.html"

    @app.get("/", include_in_schema=False)
    def index():
        if _TEST_PAGE.exists():
            return FileResponse(str(_TEST_PAGE), media_type="text/html")
        return HTMLResponse("<h1>MERLIN TTS</h1><p>Up. See <a href='/health'>/health</a>.</p>")

    @app.get("/health")
    def health():
        loaded = bool(_piper_voices) if ENGINE == "piper" else (_voxcpm_model is not None)
        model = PIPER_MODEL if ENGINE == "piper" else VOXCPM_MODEL
        device = "cpu" if ENGINE == "piper" else (_voxcpm_device if _voxcpm_model else f"{VOXCPM_DEVICE} (pending)")
        return {
            "status": "ok",
            "engine": ENGINE,
            "model": model,
            "device": device,
            "loaded": loaded,
            "robot": {"enabled": ROBOT_ENABLED, "intensity": ROBOT_INTENSITY,
                      "carrier_hz": ROBOT_CARRIER, "bits": ROBOT_BITS},
            "voices": _list_voices(),
            "cache_dir": str(CACHE_DIR),
        }

    @app.get("/voices")
    def voices():
        return {"engine": ENGINE, "voices": _list_voices()}

    def _do_synth(body):
        return synthesize(
            text=body.get("text", ""),
            voice=body.get("voice", ""),
            robot=body.get("robot"),
            robot_intensity=body.get("robot_intensity"),
            cfg_value=body.get("cfg_value"),
            inference_timesteps=body.get("inference_timesteps"),
            normalize=body.get("normalize"),
            use_cache=body.get("cache", True),
        )

    @app.post("/synth")
    async def synth(request: Request, format: str = Query("wav")):
        try:
            body = await request.json()
        except Exception:
            body = {}
        try:
            audio, cached = _do_synth(body)
        except Exception as exc:  # noqa: BLE001
            return JSONResponse(status_code=500, content={"status": "error", "error": str(exc)})
        if format == "json":
            import base64
            return JSONResponse(content={"status": "ok", "cached": cached,
                                         "audio_b64": base64.b64encode(audio).decode("ascii")})
        return Response(content=audio, media_type="audio/wav",
                        headers={"X-Voxcpm-Cached": "1" if cached else "0"})

    @app.post("/v1/audio/speech")
    async def openai_speech(request: Request):
        try:
            body = await request.json()
        except Exception:
            body = {}
        voice = body.get("voice", "") or ""
        if voice and voice not in _list_voices():
            voice = ""
        try:
            audio, cached = synthesize(text=body.get("input", ""), voice=voice)
        except Exception as exc:  # noqa: BLE001
            return JSONResponse(status_code=500, content={"error": {"message": str(exc)}})
        return Response(content=audio, media_type="audio/wav",
                        headers={"X-Voxcpm-Cached": "1" if cached else "0"})

    return app


def main():
    import uvicorn  # noqa: PLC0415

    print(f"[MERLIN-TTS] engine={ENGINE} host={HOST} port={PORT}")
    if ENGINE == "piper":
        print(f"[MERLIN-TTS] piper model={PIPER_MODEL} voices_dir={PIPER_VOICES_DIR}")
    else:
        print(f"[MERLIN-TTS] voxcpm model={VOXCPM_MODEL} device={VOXCPM_DEVICE}")
    print(f"[MERLIN-TTS] robot={'on' if ROBOT_ENABLED else 'off'} intensity={ROBOT_INTENSITY} cache={CACHE_DIR}")
    print(f"[MERLIN-TTS] test page: http://{HOST}:{PORT}/")
    uvicorn.run(build_app(), host=HOST, port=PORT, log_level="info")


if __name__ == "__main__":
    main()
