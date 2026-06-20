#!/usr/bin/env python3
"""MERLIN TTS microservice — a real storyteller voice (mysterious man), CPU, fluid.

Merlin's narration text -> POST here -> WAV audio the game plays. Service-first (same
pattern as the ASR service): the game (merlin_voice.gd NARRATOR_TTS mode) fetches audio
over HTTP/tunnel. Free + real-time on CPU via Piper; pluggable to premium cloud.

Backends (env TTS_BACKEND):
  stub        no model — a short procedural tone so the pipeline is testable with zero deps.
  piper       pip install piper-tts ; TTS_VOICE=/path/fr_FR-...onnx — fast neural CPU TTS.
              Recommended deep French male: fr_FR-tom-medium or fr_FR-gilles-low.
  elevenlabs  premium cloud "mysterious man" — ELEVEN_API_KEY + ELEVEN_VOICE (paid, optional).

"Mysterious man" shaping (env or per-request): rate (slower = graver/posé) + a ffmpeg
post-filter (pitch down ~8% + light reverb) when TTS_MYSTERY=1 and ffmpeg is present.

Endpoints:
  GET  /health                          -> {ok, backend, voice, ready, ffmpeg}
  POST /speak {text, rate?, mystery?}   -> audio/wav  (+ optional x-tts-token gate)
Run:  TTS_BACKEND=stub python3 tools/tts/tts_server.py --port 8772
"""
from __future__ import annotations

import argparse
import hashlib
import math
import os
import shutil
import struct
import subprocess
import tempfile
import wave

from flask import Flask, Response, jsonify, request

BACKEND = os.environ.get("TTS_BACKEND", "stub")
VOICE = os.environ.get("TTS_VOICE", "")          # piper .onnx path, or cloud voice id
TOKEN = os.environ.get("TTS_TOKEN", "")
RATE = float(os.environ.get("TTS_RATE", "1.10"))  # >1 = slower/graver (piper length_scale)
MYSTERY = os.environ.get("TTS_MYSTERY", "1") == "1"
PROFILE = os.environ.get("TTS_PROFILE", "conteur")  # conteur | deep | mystery | none
CACHE = os.environ.get("TTS_CACHE", os.path.join(tempfile.gettempdir(), "merlin-tts-cache"))
os.makedirs(CACHE, exist_ok=True)
HAS_FFMPEG = shutil.which("ffmpeg") is not None

# Curated DSP voice profiles (ffmpeg). aresample=44100 first makes asetrate rate-agnostic
# (pitch DOWN for depth, atempo restores the duration, bass shelf adds warmth/chest, a short
# room echo adds presence, highpass removes rumble). Tuned to stay natural, not robotic.
DSP_PROFILES = {
    "none": "",
    # default storyteller — warm, deep, realistic; subtle pitch ↓4%
    "conteur": "aresample=44100,asetrate=42336,atempo=1.0417,aresample=44100,"
               "bass=g=5:f=110,highpass=f=70,aecho=0.85:0.9:90:0.16",
    # deeper, drier — ↓7%, more chest, no reverb
    "deep": "aresample=44100,asetrate=41013,atempo=1.0753,aresample=44100,"
            "bass=g=7:f=100,highpass=f=65",
    # cavernous/dramatic — ↓8% + longer reverb tail
    "mystery": "aresample=44100,asetrate=40572,atempo=1.0870,aresample=44100,"
               "bass=g=6:f=120,highpass=f=60,aecho=0.8:0.88:140:0.26,aecho=0.9:0.9:320:0.14",
}

_engine = {"ready": False, "err": ""}
_coqui = None  # lazy XTTS model


# ── WAV helpers ──────────────────────────────────────────────────────────────
def _sine_wav(text: str, rate_hz: int = 22050) -> bytes:
    """Stub: a short, low, breathy tone (so the game pipeline is testable, audible)."""
    dur = min(0.25 + 0.03 * len(text.split()), 1.5)
    n = int(dur * rate_hz)
    frames = bytearray()
    for i in range(n):
        t = i / rate_hz
        env = math.exp(-t * 2.5)
        val = 0.25 * env * (math.sin(2 * math.pi * 110 * t) + 0.4 * math.sin(2 * math.pi * 55 * t))
        frames += struct.pack("<h", int(max(-1.0, min(1.0, val)) * 30000))
    buf = bytearray()
    import io
    bio = io.BytesIO()
    with wave.open(bio, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate_hz)
        w.writeframes(bytes(frames))
    return bio.getvalue()


def _dsp_filter(wav_in: bytes, profile: str) -> bytes:
    """Apply a curated DSP voice profile via ffmpeg (deep/realistic narrator). No-op if
    ffmpeg is absent or the profile is 'none'/unknown."""
    af = DSP_PROFILES.get(profile, "")
    if not (HAS_FFMPEG and af):
        return wav_in
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as fi:
            fi.write(wav_in)
            ipath = fi.name
        opath = ipath + ".out.wav"
        subprocess.run(["ffmpeg", "-y", "-i", ipath, "-af", af, opath],
                       capture_output=True, timeout=30, check=True)
        with open(opath, "rb") as f:
            out = f.read()
        os.remove(ipath)
        os.remove(opath)
        return out
    except Exception:
        return wav_in


# ── backends ─────────────────────────────────────────────────────────────────
def _synth(text: str, rate: float) -> bytes:
    if BACKEND == "stub":
        return _sine_wav(text)
    if BACKEND == "piper":
        if not VOICE or not os.path.exists(VOICE):
            raise RuntimeError("TTS_VOICE (piper .onnx) not found — set it or use TTS_BACKEND=stub")
        # piper reads text on stdin, writes WAV to stdout. length_scale = pace.
        out = subprocess.run(
            ["piper", "--model", VOICE, "--length_scale", str(rate), "--output_file", "-"],
            input=text.encode("utf-8"), capture_output=True, timeout=60)
        if out.returncode != 0 or not out.stdout:
            raise RuntimeError("piper failed: " + out.stderr.decode("utf-8", "ignore")[:160])
        return out.stdout
    if BACKEND == "coqui":
        # Most realistic free option (XTTS-v2): natural, French, deep built-in male speaker.
        # Heavier on CPU (a few s/line) but cached. pip install TTS.
        global _coqui
        if _coqui is None:
            from TTS.api import TTS as CoquiTTS
            _coqui = CoquiTTS(os.environ.get("TTS_MODEL", "tts_models/multilingual/multi-dataset/xtts_v2"),
                              gpu=False)
        out_path = tempfile.NamedTemporaryFile(suffix=".wav", delete=False).name
        kwargs = {"text": text, "file_path": out_path, "language": "fr"}
        spk_wav = os.environ.get("TTS_SPEAKER_WAV", "")
        if spk_wav and os.path.exists(spk_wav):
            kwargs["speaker_wav"] = spk_wav            # clone a deep reference voice
        else:
            kwargs["speaker"] = os.environ.get("TTS_SPEAKER", "Damien Black")  # deep male xtts speaker
        _coqui.tts_to_file(**kwargs)
        with open(out_path, "rb") as f:
            data = f.read()
        os.remove(out_path)
        return data
    if BACKEND == "elevenlabs":
        import urllib.request
        key = os.environ.get("ELEVEN_API_KEY", "")
        vid = os.environ.get("ELEVEN_VOICE", VOICE or "")
        if not key or not vid:
            raise RuntimeError("ELEVEN_API_KEY / ELEVEN_VOICE required")
        body = (b'{"text":' + _json_str(text) +
                b',"model_id":"eleven_multilingual_v2","voice_settings":{"stability":0.4,"similarity_boost":0.7}}')
        req = urllib.request.Request(
            f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=pcm_22050",
            data=body, headers={"xi-api-key": key, "content-type": "application/json", "accept": "audio/wav"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read()
    raise RuntimeError(f"unknown TTS_BACKEND '{BACKEND}'")


def _json_str(s: str) -> bytes:
    import json
    return json.dumps(s, ensure_ascii=False).encode("utf-8")


def speak(text: str, rate: float, profile: str) -> bytes:
    key = hashlib.sha1(f"{BACKEND}|{VOICE}|{rate}|{profile}|{text}".encode()).hexdigest()[:16]
    cpath = os.path.join(CACHE, key + ".wav")
    if os.path.exists(cpath):
        with open(cpath, "rb") as f:
            return f.read()
    wav = _synth(text, rate)
    wav = _dsp_filter(wav, profile)
    try:
        with open(cpath, "wb") as f:
            f.write(wav)
    except Exception:
        pass
    return wav


def build_app() -> Flask:
    app = Flask(__name__)

    @app.before_request
    def _gate():
        if TOKEN and request.path == "/speak":
            if request.headers.get("x-tts-token", "") != TOKEN:
                return Response("unauthorized\n", 401)

    @app.route("/health")
    def health():
        return jsonify({"ok": True, "backend": BACKEND, "voice": os.path.basename(VOICE) or VOICE,
                        "ready": BACKEND in ("stub", "coqui", "elevenlabs") or bool(VOICE),
                        "ffmpeg": HAS_FFMPEG, "profile": PROFILE, "profiles": list(DSP_PROFILES)})

    @app.route("/speak", methods=["POST"])
    def do_speak():
        body = request.get_json(silent=True) or {}
        text = str(body.get("text", "")).strip()
        if not text:
            return jsonify({"error": "text required"}), 400
        rate = float(body.get("rate", RATE))
        # profile override; legacy 'mystery':false -> no DSP. Default = TTS_PROFILE (conteur).
        profile = str(body.get("profile", PROFILE))
        if body.get("mystery") is False:
            profile = "none"
        try:
            wav = speak(text, rate, profile)
        except Exception as e:
            return jsonify({"error": str(e), "hint": "TTS_BACKEND=stub for a dep-free test"}), 503
        return Response(wav, mimetype="audio/wav")

    return app


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8772)
    ap.add_argument("--host", default="127.0.0.1")
    a = ap.parse_args()
    print(f"[tts] backend={BACKEND} voice={VOICE or '-'} rate={RATE} profile={PROFILE} ffmpeg={HAS_FFMPEG}")
    build_app().run(host=a.host, port=a.port, threaded=True)


if __name__ == "__main__":
    main()
