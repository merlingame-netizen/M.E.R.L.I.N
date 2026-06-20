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
    # default storyteller — deep, warm, realistic; pitch ↓1 semitone (~-5.6%), bass chest, room.
    "conteur": "aresample=44100,asetrate=41624,atempo=1.0595,aresample=44100,"
               "bass=g=6:f=110,highpass=f=70,aecho=0.85:0.9:90:0.16",
    # markedly deep — ↓3 semitones, more chest, dry.
    "deep": "aresample=44100,asetrate=37084,atempo=1.1892,aresample=44100,"
            "bass=g=7:f=100,highpass=f=65",
    # cavernous/dramatic — ↓4 semitones + long reverb tail.
    "mystery": "aresample=44100,asetrate=35002,atempo=1.2599,aresample=44100,"
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
# Return (audio_bytes, mime). "Same voice across languages" needs a single-speaker
# MULTILINGUAL backend: coqui/XTTS (local) or edge (free cloud male multilingual voice).
def _synth(text: str, rate: float, lang: str) -> tuple[bytes, str]:
    if BACKEND == "stub":
        return _sine_wav(text), "audio/wav"
    if BACKEND == "piper":
        # NOTE: piper voices are per-language (different speaker per language) — not "same
        # voice across languages". Use coqui/edge for a consistent multilingual narrator.
        if not VOICE or not os.path.exists(VOICE):
            raise RuntimeError("TTS_VOICE (piper .onnx) not found — set it or use TTS_BACKEND=stub")
        out = subprocess.run(
            ["piper", "--model", VOICE, "--length_scale", str(rate), "--output_file", "-"],
            input=text.encode("utf-8"), capture_output=True, timeout=60)
        if out.returncode != 0 or not out.stdout:
            raise RuntimeError("piper failed: " + out.stderr.decode("utf-8", "ignore")[:160])
        return out.stdout, "audio/wav"
    if BACKEND == "coqui":
        # XTTS-v2: ONE speaker, ~16 languages -> the SAME deep voice in every language.
        global _coqui
        if _coqui is None:
            from TTS.api import TTS as CoquiTTS
            _coqui = CoquiTTS(os.environ.get("TTS_MODEL", "tts_models/multilingual/multi-dataset/xtts_v2"),
                              gpu=False)
        out_path = tempfile.NamedTemporaryFile(suffix=".wav", delete=False).name
        kwargs = {"text": text, "file_path": out_path, "language": (lang or "fr")}
        spk_wav = os.environ.get("TTS_SPEAKER_WAV", "")
        if spk_wav and os.path.exists(spk_wav):
            kwargs["speaker_wav"] = spk_wav            # clone a deep reference (same in all langs)
        else:
            kwargs["speaker"] = os.environ.get("TTS_SPEAKER", "Damien Black")  # deep male xtts speaker
        _coqui.tts_to_file(**kwargs)
        with open(out_path, "rb") as f:
            data = f.read()
        os.remove(out_path)
        return data, "audio/wav"
    if BACKEND == "edge":
        # edge-tts: free, no key. A *Multilingual* male voice speaks any language with the
        # SAME timbre (e.g. fr-FR-RemyMultilingualNeural / en-US-BrianMultilingualNeural).
        import asyncio
        import edge_tts
        voice = VOICE or os.environ.get("TTS_EDGE_VOICE", "fr-FR-RemyMultilingualNeural")

        async def _gen() -> bytes:
            buf = b""
            async for chunk in edge_tts.Communicate(text, voice).stream():
                if chunk["type"] == "audio":
                    buf += chunk["data"]
            return buf
        return asyncio.run(_gen()), "audio/mpeg"  # MP3 (browser <audio> plays it directly)
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
            return r.read(), "audio/wav"
    raise RuntimeError(f"unknown TTS_BACKEND '{BACKEND}'")


def _json_str(s: str) -> bytes:
    import json
    return json.dumps(s, ensure_ascii=False).encode("utf-8")


def speak(text: str, rate: float, profile: str, lang: str) -> tuple[bytes, str]:
    ext = "mp3" if BACKEND == "edge" else "wav"
    key = hashlib.sha1(f"{BACKEND}|{VOICE}|{rate}|{profile}|{lang}|{text}".encode()).hexdigest()[:16]
    cpath = os.path.join(CACHE, key + "." + ext)
    mime = "audio/mpeg" if ext == "mp3" else "audio/wav"
    if os.path.exists(cpath):
        with open(cpath, "rb") as f:
            return f.read(), mime
    audio, mime = _synth(text, rate, lang)
    if mime == "audio/wav":  # DSP profiles operate on WAV (ffmpeg)
        audio = _dsp_filter(audio, profile)
    try:
        with open(cpath, "wb") as f:
            f.write(audio)
    except Exception:
        pass
    return audio, mime


_CONSOLE_HTML = """<!doctype html><html lang=fr><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1"><title>MERLIN — Voix Conteur (test)</title>
<style>
 body{margin:0;background:#0d1117;color:#e6edf3;font:15px/1.6 ui-monospace,Menlo,Consolas,monospace}
 .wrap{max-width:760px;margin:0 auto;padding:22px}
 h1{font-size:19px} .mut{color:#8b949e;font-size:13px}
 label{display:block;margin:14px 0 5px;color:#8b949e;text-transform:uppercase;font-size:11px;letter-spacing:1px}
 textarea,select,input{width:100%;box-sizing:border-box;background:#161b22;color:#e6edf3;border:1px solid #30363d;border-radius:8px;padding:11px;font:inherit}
 textarea{min-height:90px} .row{display:flex;gap:12px;flex-wrap:wrap} .row>div{flex:1;min-width:150px}
 button{margin-top:16px;background:#58a6ff;color:#0d1117;border:0;border-radius:8px;padding:13px 20px;font-weight:700;font:inherit;cursor:pointer;min-height:46px}
 button:disabled{opacity:.5} audio{width:100%;margin-top:16px} .badge{font-size:12px;padding:3px 9px;border-radius:20px;background:#21262d}
 .ok{color:#2ea043} .err{color:#f85149} code{color:#a371f7}
</style></head><body><div class=wrap>
 <h1>🜨 MERLIN — Voix du Conteur (test localhost)</h1>
 <div class=mut id=health>…</div>
 <label>Langue (même voix dans toutes — backend multilingue)</label>
 <select id=lang onchange=fill()>
  <option value=fr>Français</option><option value=en>English</option><option value=es>Español</option>
  <option value=it>Italiano</option><option value=de>Deutsch</option><option value=pt>Português</option>
  <option value=zh>中文</option><option value=ja>日本語</option>
 </select>
 <label>Texte</label><textarea id=txt></textarea>
 <div class=row>
  <div><label>Profil (profondeur)</label><select id=prof>
   <option value=conteur>Conteur (−1 ½t, défaut)</option><option value=deep>Deep (−3 ½t)</option>
   <option value=mystery>Mystery (−4 ½t)</option><option value=none>Aucun (brut)</option></select></div>
  <div><label>Débit <span id=rv>1.10</span></label><input id=rate type=range min=0.8 max=1.4 step=0.02 value=1.10 oninput="rv.textContent=this.value"></div>
 </div>
 <button id=go onclick=speak()>▶ Parler</button> <span id=st class=mut></span>
 <audio id=au controls></audio>
 <p class=mut>Critères : <b>voix grave réaliste (Conteur)</b> · <b>même voix multilingue</b> (XTTS « Damien Black » ou edge-tts <code>*MultilingualNeural</code>) · CPU/gratuit.</p>
</div><script>
 const S={fr:"Bienvenue, voyageur. Les bois de Brocéliande se souviennent de ton nom.",
  en:"Welcome, traveler. The woods of Brocéliande remember your name.",
  es:"Bienvenido, viajero. Los bosques de Brocéliande recuerdan tu nombre.",
  it:"Benvenuto, viaggiatore. I boschi di Brocéliande ricordano il tuo nome.",
  de:"Willkommen, Reisender. Die Wälder von Brocéliande erinnern sich an deinen Namen.",
  pt:"Bem-vindo, viajante. As florestas de Brocéliande lembram o teu nome.",
  zh:"欢迎你，旅人。布罗塞利安德的森林记得你的名字。",ja:"ようこそ、旅人よ。ブロセリアンドの森はあなたの名を覚えている。"};
 function fill(){txt.value=S[lang.value]||S.fr}
 async function speak(){go.disabled=true;st.textContent="…";st.className="mut";
  try{const r=await fetch("/speak",{method:"POST",headers:{"content-type":"application/json"},
   body:JSON.stringify({text:txt.value,lang:lang.value,profile:prof.value,rate:parseFloat(rate.value)})});
   if(!r.ok){const e=await r.json();st.textContent="✗ "+(e.error||r.status);st.className="err";go.disabled=false;return}
   au.src=URL.createObjectURL(await r.blob());au.play();st.textContent="✓";st.className="ok"}
  catch(e){st.textContent="✗ "+e;st.className="err"} go.disabled=false}
 fetch("/health").then(r=>r.json()).then(h=>{health.innerHTML=
   `backend <b>${h.backend}</b> · même voix multilingue: <b class=${h.same_voice_all_langs?'ok':'err'}>${h.same_voice_all_langs?'oui':'non (utilise coqui/edge)'}</b> · ffmpeg ${h.ffmpeg?'✓':'✗'} · profil ${h.profile}`});
 fill();
</script></body></html>"""


def build_app() -> Flask:
    app = Flask(__name__)

    @app.before_request
    def _gate():
        if TOKEN and request.path == "/speak":
            if request.headers.get("x-tts-token", "") != TOKEN:
                return Response("unauthorized\n", 401)

    @app.route("/")
    def console():
        return Response(_CONSOLE_HTML, mimetype="text/html")

    @app.route("/health")
    def health():
        multilingual = BACKEND in ("coqui", "edge", "elevenlabs")
        return jsonify({"ok": True, "backend": BACKEND, "voice": os.path.basename(VOICE) or VOICE,
                        "ready": BACKEND in ("stub", "coqui", "edge", "elevenlabs") or bool(VOICE),
                        "ffmpeg": HAS_FFMPEG, "profile": PROFILE, "profiles": list(DSP_PROFILES),
                        "multilingual": multilingual, "same_voice_all_langs": multilingual})

    @app.route("/speak", methods=["POST"])
    def do_speak():
        body = request.get_json(silent=True) or {}
        text = str(body.get("text", "")).strip()
        if not text:
            return jsonify({"error": "text required"}), 400
        rate = float(body.get("rate", RATE))
        lang = str(body.get("lang", os.environ.get("TTS_LANG", "fr")))
        profile = str(body.get("profile", PROFILE))
        if body.get("mystery") is False:
            profile = "none"
        try:
            audio, mime = speak(text, rate, profile, lang)
        except Exception as e:
            return jsonify({"error": str(e), "hint": "TTS_BACKEND=stub for a dep-free test"}), 503
        return Response(audio, mimetype=mime)

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
