"""Outlook adapter — thin subprocess wrapper around tools/outlook_mail.py."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from tools.adapters.base_adapter import BaseAdapter

PYTHON = "C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe"
SCRIPT = str(Path(__file__).parent.parent / "outlook_mail.py")


class OutlookAdapter(BaseAdapter):
    def __init__(self):
        super().__init__("outlook")

    # ── Action registry ──────────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "inbox":   "List recent inbox emails. kwargs: limit (int, default 10)",
            "search":  "Search emails. kwargs: query, from_addr, since (YYYY-MM-DD), limit (int)",
            "read":    "Read a specific email. kwargs: index (int)",
            "send":    "Create a new mail draft (always Display, never Send). kwargs: to, subject, body, attachments (list)",
            "reply":   "Open a reply draft. kwargs: index (int), body, reply_all (bool)",
            "forward": "Open a forward draft. kwargs: index (int), to, body",
        }

    # ── Dispatch ─────────────────────────────────────────────────────────────

    def run(self, action: str, **kwargs: Any) -> dict:
        builders = {
            "inbox":   self._build_inbox,
            "search":  self._build_search,
            "read":    self._build_read,
            "send":    self._build_send,
            "reply":   self._build_reply,
            "forward": self._build_forward,
        }
        if action not in builders:
            raise NotImplementedError
        cmd = [PYTHON, SCRIPT] + builders[action](**kwargs)
        return self._run(cmd, action)

    # ── CLI builders ─────────────────────────────────────────────────────────

    def _build_inbox(self, limit: int = 10, **_) -> list[str]:
        return ["inbox", "--count", str(limit)]

    def _build_search(self, query: str = "", from_addr: str = "",
                      since: str = "", limit: int = 20, **_) -> list[str]:
        args = ["search"]
        if query:
            args += ["--query", query]
        if from_addr:
            args += ["--from-addr", from_addr]
        if since:
            args += ["--since", since]
        args += ["--limit", str(limit)]
        return args

    def _build_read(self, index: int = 0, **_) -> list[str]:
        return ["read", "--index", str(index)]

    def _build_send(self, to: str = "", subject: str = "", body: str = "",
                    attachments: list[str] | None = None, **_) -> list[str]:
        args = ["new", "--to", to, "--subject", subject, "--body", body]
        if attachments:
            args += ["--attachments"] + list(attachments)
        return args

    def _build_reply(self, index: int = 0, body: str = "",
                     reply_all: bool = False, **_) -> list[str]:
        args = ["reply", "--index", str(index), "--body", body]
        if reply_all:
            args.append("--reply-all")
        return args

    def _build_forward(self, index: int = 0, to: str = "", body: str = "", **_) -> list[str]:
        return ["forward", "--index", str(index), "--to", to, "--body", body]

    # ── Subprocess runner ────────────────────────────────────────────────────

    def _run(self, cmd: list[str], action: str) -> dict:
        # Log action only — avoid PII (to/subject/body) in log stream
        self.log(f"Running: outlook_mail.py {action}")
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=60,
            )
        except subprocess.TimeoutExpired:
            return self.error("Outlook script timed out after 60s (COM hang?)")
        except Exception as exc:
            return self.error(f"Subprocess launch failed: {exc}")

        if proc.returncode != 0:
            stderr = proc.stderr.strip() or f"exit code {proc.returncode}"
            return self.error(stderr)

        try:
            data = json.loads(proc.stdout)
        except json.JSONDecodeError:
            return self.error(f"Invalid JSON from outlook_mail.py: {proc.stdout[:200]}")

        return self.ok(data)
