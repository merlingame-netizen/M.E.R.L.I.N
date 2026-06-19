#!/usr/bin/env python3
"""MERLIN ASR microservice — speech-to-text over HTTP (CPU, free).

The game (Godot) captures the mic and POSTs audio here; the service returns text that
gets fuzzy-matched to a card option. Service-first by design: running NVIDIA Nemotron
streaming ASR (or Whisper) on-device in Godot is hard, so we host it as a small CPU
service (PC first, then VM/Oracle) reached over HTTP/tunnel — same pattern as the atelier
backend.

Backends (env ASR_BACKEND), in order of practicality on CPU:
  stub            no model — echoes a canned/looped transcript. Lets the FULL voice
                  pipeline (mic -> service -> choice mapping) be tested with zero deps.
  faster-whisper  pip install faster-whisper ; ASR_MODEL=base (CPU int8). Robust, multilang.
  sherpa-onnx     pip install sherpa-onnx ; for streaming models incl. Nemotron exports.
  nemo            pip install nemo_toolkit[asr] ; ASR_MODEL=nvidia/nemotron-... (heavy).

Endpoints:
  GET  /health                      -> {ok, backend, model, ready}
  POST /transcribe  (audio body)    -> {text, backend, ms}
       body = raw audio bytes (wav/flac/ogg) or form-file 'audio'; ?lang=fr optional.

Run:  ASR_BACKEND=stub python3 tools/asr/asr_server.py --port 8770
"""
from __future__ import annotations

import argparse
import io
import os
import time

from flask import Flask, Response, jsonify, request

BACKEND = os.environ.get("ASR_BACKEND", "stub")
MODEL = os.environ.get("ASR_MODEL", "base")
TOKEN = os.environ.get("ASR_TOKEN", "")  # optional shared-secret (x-asr-token)

_engine = {"ready": False, "transcribe": None, "err": ""}


def _load_backend():
    """Lazy-load the chosen backend; never crash the service if a model is missing."""
    if _engine["ready"] or _engine["err"]:
        return
    try:
        if BACKEND == "stub":
            canned = ["accepter l'offre", "écouter la forêt", "refuser et partir",
                      "observer les runes", "s'approcher du chêne"]
            i = {"n": 0}

            def t(_audio):
                s = canned[i["n"] % len(canned)]
                i["n"] += 1
                return s
            _engine.update(ready=True, transcribe=t)

        elif BACKEND == "faster-whisper":
            from faster_whisper import WhisperModel
            m = WhisperModel(MODEL, device="cpu", compute_type="int8")

            def t(audio):
                segs, _info = m.transcribe(io.BytesIO(audio), language=os.environ.get("ASR_LANG", "fr"))
                return " ".join(s.text for s in segs).strip()
            _engine.update(ready=True, transcribe=t)

        elif BACKEND == "sherpa-onnx":
            import sherpa_onnx  # noqa: F401
            raise RuntimeError("sherpa-onnx wiring is deployment-specific; configure the "
                               "recognizer for your model dir then implement transcribe().")

        elif BACKEND == "nemo":
            import nemo.collections.asr as nemo_asr
            m = nemo_asr.models.ASRModel.from_pretrained(MODEL)

            def t(audio):
                import tempfile
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as f:
                    f.write(audio)
                    f.flush()
                    out = m.transcribe([f.name])
                return (out[0] if out else "").strip()
            _engine.update(ready=True, transcribe=t)
        else:
            _engine["err"] = f"unknown ASR_BACKEND '{BACKEND}'"
    except Exception as e:  # missing dep / model -> service stays up, reports not-ready
        _engine["err"] = f"{type(e).__name__}: {e}"


def build_app() -> Flask:
    app = Flask(__name__)

    @app.before_request
    def _gate():
        if TOKEN and request.path == "/transcribe":
            if request.headers.get("x-asr-token", "") != TOKEN:
                return Response("unauthorized\n", 401)

    @app.route("/health")
    def health():
        _load_backend()
        return jsonify({"ok": True, "backend": BACKEND, "model": MODEL,
                        "ready": _engine["ready"], "error": _engine["err"]})

    @app.route("/transcribe", methods=["POST"])
    def transcribe():
        _load_backend()
        if not _engine["ready"]:
            return jsonify({"error": "backend not ready", "detail": _engine["err"],
                            "hint": f"pip install for '{BACKEND}' or use ASR_BACKEND=stub"}), 503
        if "audio" in request.files:
            audio = request.files["audio"].read()
        else:
            audio = request.get_data() or b""
        t0 = time.time()
        try:
            text = _engine["transcribe"](audio)
        except Exception as e:
            return jsonify({"error": str(e)}), 500
        return jsonify({"text": text, "backend": BACKEND, "ms": int((time.time() - t0) * 1000)})

    return app


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8770)
    ap.add_argument("--host", default="127.0.0.1")
    a = ap.parse_args()
    _load_backend()
    print(f"[asr] backend={BACKEND} model={MODEL} ready={_engine['ready']} err={_engine['err'] or '-'}")
    build_app().run(host=a.host, port=a.port, threaded=True)


if __name__ == "__main__":
    main()
