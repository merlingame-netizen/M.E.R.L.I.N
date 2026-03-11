"""Ollama adapter — local LLM HTTP API for M.E.R.L.I.N. (Qwen 3.5 via Ollama)."""

from __future__ import annotations

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

BASE_URL = "http://localhost:11434"
DEFAULT_MODEL = "qwen2.5:7b"

# ── Adapter ─────────────────────────────────────────────────────────────────


class OllamaAdapter(BaseAdapter):
    """Adapter for the Ollama local LLM HTTP API."""

    def __init__(self) -> None:
        super().__init__("ollama")

    # ── BaseAdapter interface ────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "list":     "List installed models (name, size, modified)",
            "ps":       "Show currently running/loaded models",
            "pull":     "Pull a model from the registry (requires model= kwarg)",
            "delete":   "Delete a local model (requires model= kwarg)",
            "chat":     "Single chat exchange (requires model= and messages= or prompt=)",
            "generate": "Raw completion (requires model= and prompt=)",
            "show":     "Show model details/metadata (requires model= kwarg)",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "list":
                return self._list()
            case "ps":
                return self._ps()
            case "pull":
                return self._pull(**kwargs)
            case "delete":
                return self._delete(**kwargs)
            case "chat":
                return self._chat(**kwargs)
            case "generate":
                return self._generate(**kwargs)
            case "show":
                return self._show(**kwargs)
            case _:
                raise NotImplementedError(action)

    # ── Actions ─────────────────────────────────────────────────────────────

    def _list(self) -> dict:
        """GET /api/tags — list installed models."""
        self.log("Fetching installed models from /api/tags …")
        resp = self._get("/api/tags")
        if resp is None:
            return self.error("Ollama unreachable at " + BASE_URL)
        models_raw = resp.get("models", [])
        models = [
            {
                "name": m.get("name", ""),
                "size_bytes": m.get("size", 0),
                "modified": m.get("modified_at", ""),
                "digest": m.get("digest", "")[:12] if m.get("digest") else "",
            }
            for m in models_raw
        ]
        self.log(f"Found {len(models)} model(s)")
        return self.ok({"models": models, "count": len(models)})

    def _ps(self) -> dict:
        """GET /api/ps — currently running/loaded models."""
        self.log("Fetching running models from /api/ps …")
        resp = self._get("/api/ps")
        if resp is None:
            return self.error("Ollama unreachable at " + BASE_URL)
        models = resp.get("models", [])
        self.log(f"Found {len(models)} running model(s)")
        return self.ok({"running": models, "count": len(models)})

    def _pull(self, model: str = DEFAULT_MODEL, **_kwargs: Any) -> dict:
        """POST /api/pull — pull a model (stream=false, timeout=300s)."""
        self.log(f"Pulling model '{model}' (this may take several minutes) …")
        resp = self._post("/api/pull", {"model": model, "stream": False}, timeout=300)
        if resp is None:
            return self.error(f"Failed to pull model '{model}' — Ollama unreachable or timeout")
        status = resp.get("status", "")
        self.log(f"Pull result: {status}")
        return self.ok({"model": model, "status": status, "response": resp})

    def _delete(self, model: str = "", **_kwargs: Any) -> dict:
        """DELETE /api/delete — remove a local model."""
        if not model:
            return self.error("delete action requires model= kwarg")
        self.log(f"Deleting model '{model}' …")
        resp = self._delete_req("/api/delete", {"model": model})
        if resp is None:
            return self.error(f"Failed to delete model '{model}' — Ollama unreachable")
        self.log(f"Model '{model}' deleted successfully")
        return self.ok({"model": model, "deleted": True})

    def _chat(
        self,
        model: str = DEFAULT_MODEL,
        messages: list | None = None,
        prompt: str = "",
        system: str = "",
        **_kwargs: Any,
    ) -> dict:
        """POST /api/chat — single chat exchange (stream=false, timeout=60s)."""
        if messages is None:
            if not prompt:
                return self.error("chat action requires messages= list or prompt= string")
            messages = [{"role": "user", "content": prompt}]
        if system:
            messages = [{"role": "system", "content": system}] + list(messages)

        self.log(f"Chatting with '{model}' ({len(messages)} message(s)) …")
        payload: dict[str, Any] = {"model": model, "messages": messages, "stream": False}
        resp = self._post("/api/chat", payload, timeout=60)
        if resp is None:
            return self.error(f"Chat with '{model}' failed — Ollama unreachable or timeout")

        msg = resp.get("message", {})
        content = msg.get("content", "")
        self.log(f"Response: {len(content)} chars, done={resp.get('done', False)}")
        return self.ok(
            {
                "model": model,
                "content": content,
                "role": msg.get("role", "assistant"),
                "done": resp.get("done", False),
                "eval_count": resp.get("eval_count"),
                "prompt_eval_count": resp.get("prompt_eval_count"),
            }
        )

    def _generate(
        self,
        model: str = DEFAULT_MODEL,
        prompt: str = "",
        system: str = "",
        **_kwargs: Any,
    ) -> dict:
        """POST /api/generate — raw completion (stream=false, timeout=60s)."""
        if not prompt:
            return self.error("generate action requires prompt= kwarg")

        self.log(f"Generating with '{model}' (prompt={len(prompt)} chars) …")
        payload: dict[str, Any] = {"model": model, "prompt": prompt, "stream": False}
        if system:
            payload["system"] = system
        resp = self._post("/api/generate", payload, timeout=60)
        if resp is None:
            return self.error(f"Generate with '{model}' failed — Ollama unreachable or timeout")

        response_text = resp.get("response", "")
        self.log(f"Response: {len(response_text)} chars, done={resp.get('done', False)}")
        return self.ok(
            {
                "model": model,
                "response": response_text,
                "done": resp.get("done", False),
                "eval_count": resp.get("eval_count"),
                "prompt_eval_count": resp.get("prompt_eval_count"),
                "context": resp.get("context"),
            }
        )

    def _show(self, model: str = "", **_kwargs: Any) -> dict:
        """POST /api/show — model details and metadata."""
        if not model:
            return self.error("show action requires model= kwarg")
        self.log(f"Fetching details for model '{model}' …")
        resp = self._post("/api/show", {"model": model})
        if resp is None:
            return self.error(f"Could not fetch details for '{model}' — Ollama unreachable")
        return self.ok(
            {
                "model": model,
                "modelfile": resp.get("modelfile", ""),
                "parameters": resp.get("parameters", ""),
                "template": resp.get("template", ""),
                "details": resp.get("details", {}),
            }
        )

    # ── HTTP helpers ─────────────────────────────────────────────────────────

    def _get(self, path: str, timeout: int = 10) -> dict | None:
        """Execute a GET request against the Ollama API."""
        try:
            import requests  # local import — optional dependency

            r = requests.get(BASE_URL + path, timeout=timeout)
            r.raise_for_status()
            return r.json()
        except Exception as exc:  # noqa: BLE001
            self.log(f"GET {path} failed: {exc}")
            return None

    def _post(self, path: str, payload: dict, timeout: int = 30) -> dict | None:
        """Execute a POST request against the Ollama API."""
        try:
            import requests

            r = requests.post(BASE_URL + path, json=payload, timeout=timeout)
            r.raise_for_status()
            # /api/pull with stream=false may return empty body on success
            if not r.content:
                return {}
            return r.json()
        except Exception as exc:  # noqa: BLE001
            self.log(f"POST {path} failed: {exc}")
            return None

    def _delete_req(self, path: str, payload: dict, timeout: int = 10) -> dict | None:
        """Execute a DELETE request against the Ollama API."""
        try:
            import requests

            r = requests.delete(BASE_URL + path, json=payload, timeout=timeout)
            r.raise_for_status()
            return r.json() if r.content else {}
        except Exception as exc:  # noqa: BLE001
            self.log(f"DELETE {path} failed: {exc}")
            return None
