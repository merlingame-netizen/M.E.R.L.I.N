"""Base adapter — standard JSON contract for all CLI-Anything tool adapters."""

from __future__ import annotations

import logging
import time
from abc import ABC, abstractmethod
from typing import Any


class BaseAdapter(ABC):
    """
    Base class for all CLI-Anything tool adapters.

    Contract:
      - run(action, **kwargs) -> dict
      - All returns use ok() or error()
      - JSON output: { tool, action, status, data, logs, duration_ms }
    """

    def __init__(self, tool_name: str):
        self.tool_name = tool_name
        self._logs: list[str] = []
        self._start: float = 0.0
        logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
        self._logger = logging.getLogger(tool_name)

    # ── Public API ──────────────────────────────────────────────────────────

    def execute(self, action: str, **kwargs: Any) -> dict:
        """Entry point. Wraps run() with timing and error capture."""
        self._logs = []
        self._start = time.monotonic()
        try:
            result = self.run(action, **kwargs)
        except NotImplementedError:
            result = self.error(f"Unknown action '{action}' for {self.tool_name}")
        except Exception as exc:  # noqa: BLE001
            result = self.error(f"Unhandled exception: {exc}")
        return result

    @abstractmethod
    def run(self, action: str, **kwargs: Any) -> dict:
        """Implement in subclass. Call self.ok() or self.error() to return."""

    @abstractmethod
    def list_actions(self) -> dict[str, str]:
        """Return { action_name: description } for --help output."""

    def health_probe(self) -> tuple[str, dict]:
        """Return (action, kwargs) for a lightweight health check.

        Override in subclass to customize. Default: first action, no kwargs.
        """
        actions = self.list_actions()
        first_action = next(iter(actions), "help")
        return first_action, {}

    # ── Response helpers ────────────────────────────────────────────────────

    def ok(self, data: Any = None) -> dict:
        return self._envelope("ok", data)

    def error(self, msg: str, data: Any = None) -> dict:
        self.log(f"ERROR: {msg}")
        return self._envelope("error", data, error_msg=msg)

    def log(self, msg: str) -> None:
        self._logs.append(msg)
        self._logger.info(msg)

    # ── Internal ────────────────────────────────────────────────────────────

    @staticmethod
    def resolve_cmd(name: str) -> str:
        """Resolve a command name to full path (handles Windows PATH gaps).

        On Windows, subprocess may not find commands like npx/node if their
        directory isn't in Python's PATH. This checks common locations.
        """
        import shutil
        found = shutil.which(name)
        if found:
            return found
        # Common Windows install locations
        import os
        candidates = [
            os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "nodejs", f"{name}.cmd"),
            os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "nodejs", name),
            os.path.join(os.environ.get("APPDATA", ""), "npm", f"{name}.cmd"),
        ]
        from pathlib import Path
        for c in candidates:
            if Path(c).exists():
                return c
        return name  # fallback to bare name

    def _envelope(self, status: str, data: Any, error_msg: str | None = None) -> dict:
        duration_ms = int((time.monotonic() - self._start) * 1000)
        result: dict = {
            "tool": self.tool_name,
            "status": status,
            "data": data,
            "logs": list(self._logs),
            "duration_ms": duration_ms,
        }
        if error_msg:
            result["error"] = error_msg
        return result
