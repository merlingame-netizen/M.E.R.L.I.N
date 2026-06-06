"""VoxCPM adapter — local neural TTS (voice cloning) for M.E.R.L.I.N.

Talks to the VoxCPM HTTP server (tools/voxcpm/server.py) over localhost, the same
way the Ollama adapter talks to the Ollama daemon. The heavy model lives in the
server's dedicated venv; this adapter is a thin, dependency-light HTTP client.

Start the server first:  tools\\voxcpm\\start.bat
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402

# ── Constants ───────────────────────────────────────────────────────────────

BASE_URL = os.environ.get("VOXCPM_URL", "http://127.0.0.1:8808")
VOICES_DIR = Path(
    os.environ.get("VOXCPM_VOICES_DIR", str(_ROOT / "voxcpm" / "voices"))
)
KNOWN_MODELS = {
    "openbmb/VoxCPM-0.5B": "Lighter 0.5B model — viable on CPU (with caching). Default.",
    "openbmb/VoxCPM2": "2B model — best quality, needs ~8 GB VRAM (CUDA 12+).",
}

# ── Adapter ─────────────────────────────────────────────────────────────────


class VoxCPMAdapter(BaseAdapter):
    """Adapter for the local VoxCPM TTS HTTP server."""

    def __init__(self) -> None:
        super().__init__("voxcpm")

    # ── BaseAdapter interface ────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "status":    "Server health: model, device, loaded, registered voices",
            "voices":    "List registered reference voices (use_my_voice)",
            "synth":     "Synthesize speech to a WAV file (requires text=; optional voice=, out=)",
            "speak":     "Synthesize and play immediately (requires text=; optional voice=)",
            "add-voice": "Register a reference voice (requires name= and audio=; optional text=)",
            "models":    "List known VoxCPM models + which one the server reports",
            "info":      "Show adapter config (URL, voices dir)",
        }

    def health_probe(self) -> tuple[str, dict]:
        return "status", {}

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "status":
                return self._status()
            case "voices":
                return self._voices()
            case "synth":
                return self._synth(**kwargs)
            case "speak":
                return self._synth(play=True, **kwargs)
            case "add-voice" | "add_voice" | "clone":
                return self._add_voice(**kwargs)
            case "models":
                return self._models()
            case "info":
                return self._info()
            case _:
                raise NotImplementedError(action)

    # ── Actions ─────────────────────────────────────────────────────────────

    def _status(self) -> dict:
        self.log(f"GET {BASE_URL}/health …")
        resp = self._get("/health")
        if resp is None:
            return self.error(
                f"VoxCPM server unreachable at {BASE_URL}. "
                f"Start it with: tools\\voxcpm\\start.bat"
            )
        return self.ok(resp)

    def _voices(self) -> dict:
        resp = self._get("/voices")
        if resp is None:
            # Fall back to scanning the local voices dir so this works offline.
            local = self._scan_local_voices()
            return self.ok({"voices": local, "source": "local_dir", "note": "server offline"})
        return self.ok(resp)

    def _synth(
        self,
        text: str = "",
        voice: str = "",
        out: str = "",
        cfg_value: Any = None,
        inference_timesteps: Any = None,
        play: bool = False,
        **_kwargs: Any,
    ) -> dict:
        if not text:
            return self.error("synth requires text= (the phrase to speak)")

        payload: dict[str, Any] = {"text": text, "voice": voice}
        if cfg_value is not None:
            payload["cfg_value"] = float(cfg_value)
        if inference_timesteps is not None:
            payload["inference_timesteps"] = int(inference_timesteps)

        self.log(f"POST {BASE_URL}/synth (text={len(text)} chars, voice={voice or '-'}) …")
        audio, cached, err = self._post_audio("/synth", payload)
        if audio is None:
            return self.error(
                f"Synthesis failed: {err}. Is the server running? (tools\\voxcpm\\start.bat). "
                f"First call also downloads the model and is slow on CPU."
            )

        out_path = Path(out).expanduser() if out else (Path.cwd() / "voxcpm_out.wav")
        try:
            out_path.write_bytes(audio)
        except Exception as exc:  # noqa: BLE001
            return self.error(f"Could not write {out_path}: {exc}")

        data = {
            "out": str(out_path),
            "bytes": len(audio),
            "cached": cached,
            "voice": voice or None,
        }
        if play:
            played = self._play(out_path)
            data["played"] = played
        self.log(f"Wrote {len(audio)} bytes → {out_path} (cached={cached})")
        return self.ok(data)

    def _add_voice(
        self,
        name: str = "",
        audio: str = "",
        text: str = "",
        **_kwargs: Any,
    ) -> dict:
        if not name or not audio:
            return self.error("add-voice requires name= and audio= (path to a wav sample)")
        src = Path(audio).expanduser()
        if not src.exists():
            return self.error(f"Audio sample not found: {src}")

        VOICES_DIR.mkdir(parents=True, exist_ok=True)
        dest_wav = VOICES_DIR / f"{name}.wav"
        try:
            import shutil

            shutil.copyfile(src, dest_wav)
        except Exception as exc:  # noqa: BLE001
            return self.error(f"Could not copy sample: {exc}")

        wrote_txt = False
        if text:
            try:
                (VOICES_DIR / f"{name}.txt").write_text(text, encoding="utf-8")
                wrote_txt = True
            except Exception as exc:  # noqa: BLE001
                self.log(f"transcript write failed: {exc}")

        self.log(f"Registered voice '{name}' → {dest_wav}")
        return self.ok({
            "name": name,
            "wav": str(dest_wav),
            "transcript_written": wrote_txt,
            "note": "ultimate cloning needs the transcript; reference-only works without it",
        })

    def _models(self) -> dict:
        server_model = None
        resp = self._get("/health")
        if resp:
            server_model = resp.get("model")
        return self.ok({
            "known": KNOWN_MODELS,
            "server_model": server_model,
            "hint": "Set VOXCPM_MODEL before starting the server to switch.",
        })

    def _info(self) -> dict:
        return self.ok({
            "url": BASE_URL,
            "voices_dir": str(VOICES_DIR),
            "voices_dir_exists": VOICES_DIR.exists(),
            "env": {
                "VOXCPM_URL": os.environ.get("VOXCPM_URL"),
                "VOXCPM_VOICES_DIR": os.environ.get("VOXCPM_VOICES_DIR"),
            },
        })

    # ── Helpers ──────────────────────────────────────────────────────────────

    def _scan_local_voices(self) -> list[dict]:
        if not VOICES_DIR.exists():
            return []
        out = []
        for wav in sorted(VOICES_DIR.glob("*.wav")):
            out.append({
                "name": wav.stem,
                "wav": str(wav),
                "has_transcript": wav.with_suffix(".txt").exists(),
            })
        return out

    def _play(self, path: Path) -> bool:
        """Best-effort local playback (Windows/macOS/Linux)."""
        import subprocess

        try:
            if sys.platform.startswith("win"):
                os.startfile(str(path))  # type: ignore[attr-defined]
            elif sys.platform == "darwin":
                subprocess.Popen(["afplay", str(path)])
            else:
                subprocess.Popen(["aplay", str(path)])
            return True
        except Exception as exc:  # noqa: BLE001
            self.log(f"playback failed: {exc}")
            return False

    def _get(self, path: str, timeout: int = 10) -> dict | None:
        try:
            import requests  # noqa: PLC0415

            r = requests.get(BASE_URL + path, timeout=timeout)
            r.raise_for_status()
            return r.json()
        except Exception as exc:  # noqa: BLE001
            self.log(f"GET {path} failed: {exc}")
            return None

    def _post_audio(self, path: str, payload: dict, timeout: int = 300):
        """POST JSON, expect audio/wav bytes back. Returns (bytes|None, cached, err)."""
        try:
            import requests  # noqa: PLC0415

            r = requests.post(BASE_URL + path, json=payload, timeout=timeout)
            if r.status_code != 200:
                try:
                    return None, False, r.json().get("error", r.text)
                except Exception:
                    return None, False, f"HTTP {r.status_code}"
            cached = r.headers.get("X-Voxcpm-Cached") == "1"
            return r.content, cached, None
        except Exception as exc:  # noqa: BLE001
            return None, False, str(exc)
