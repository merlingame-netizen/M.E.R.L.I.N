"""Magic adapter — 21st.dev (Magic) component generation via stdio-MCP bridge.

Part of the "UI UX Pro Max" max pack. Bridges the CLI to the official
`@21st-dev/magic` MCP server (the same node binary configured in
`.claude/claude_desktop_config.json`), so `python tools/cli.py magic ...`
works agent-native (JSON-first) without needing an interactive MCP session.

Actions
-------
  component-builder  Generate / refine a UI component from a description
  inspiration        Browse 21st.dev component inspiration for a query
  refiner            Refine an existing component (improve design/UX)
  logo-search        Search company / brand logos (SVG / TSX / JSX)
  list-tools         Discover the tools exposed by the Magic MCP server

Auth
----
  Reads `TWENTYFIRST_API_KEY` from the environment (passed to the server as
  `API_KEY`, matching the claude_desktop_config.json convention).

Transport
---------
  Speaks JSON-RPC 2.0 over stdio to the Magic server: initialize → (optional
  tools/list) → tools/call. No REST endpoint guessing — it talks the MCP
  protocol to the canonical server, so it tracks upstream changes.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402

# Canonical 21st.dev Magic MCP tool names, mapped from friendly CLI actions.
# If the server renames a tool, list-tools + fuzzy fallback still resolves it.
_TOOL_MAP: dict[str, str] = {
    "component-builder": "21st_magic_component_builder",
    "inspiration":       "21st_magic_component_inspiration",
    "refiner":           "21st_magic_component_refiner",
    "logo-search":       "logo_search",
}

_CONFIG_CANDIDATES = [
    _ROOT.parent / ".claude" / "claude_desktop_config.json",   # repo .claude/
    Path.home() / ".claude" / "claude_desktop_config.json",
    Path(os.environ.get("APPDATA", "")) / "Claude" / "claude_desktop_config.json",
]

_RPC_TIMEOUT = 120  # seconds — generation can be slow


class MagicAdapter(BaseAdapter):
    """Adapter for 21st.dev Magic component generation (stdio-MCP bridge)."""

    def __init__(self) -> None:
        super().__init__("magic")

    # ── Health ────────────────────────────────────────────────────────────
    def health_probe(self) -> tuple[str, dict]:
        return "list-tools", {}

    def list_actions(self) -> dict[str, str]:
        return {
            "component-builder": "Generate/refine a UI component (--query 'desc', [--context '...'])",
            "inspiration":       "Browse component inspiration for a query (--query 'desc')",
            "refiner":           "Refine an existing component (--query 'desc', [--code '...'])",
            "logo-search":       "Search brand logos (--query 'react', [--format svg|tsx|jsx])",
            "list-tools":        "List tools exposed by the Magic MCP server",
        }

    # ── Dispatch ──────────────────────────────────────────────────────────
    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "component-builder": self._component_builder,
            "inspiration":       self._inspiration,
            "refiner":           self._refiner,
            "logo-search":       self._logo_search,
            "list-tools":        self._list_tools,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError(action)
        return handler(**kwargs)

    # ── Actions ───────────────────────────────────────────────────────────
    def _component_builder(self, query: str = "", context: str = "", **_: Any) -> dict:
        if not query:
            return self.error("--query is required (component description)")
        args: dict[str, Any] = {
            "message": query,
            "searchQuery": query,
            "standaloneRequestQuery": query,
        }
        if context:
            args["context"] = context
        return self._call("component-builder", args)

    def _inspiration(self, query: str = "", **_: Any) -> dict:
        if not query:
            return self.error("--query is required (what to get inspiration for)")
        return self._call("inspiration", {"message": query, "searchQuery": query})

    def _refiner(self, query: str = "", code: str = "", **_: Any) -> dict:
        if not query:
            return self.error("--query is required (what to refine / improve)")
        args: dict[str, Any] = {"userMessage": query, "context": query}
        if code:
            args["currentCode"] = code
        return self._call("refiner", args)

    def _logo_search(self, query: str = "", format: str = "TSX", **_: Any) -> dict:
        if not query:
            return self.error("--query is required (brand/company name)")
        fmt = (format or "TSX").upper()
        if fmt not in ("SVG", "TSX", "JSX"):
            fmt = "TSX"
        queries = [q.strip() for q in query.split(",") if q.strip()] or [query]
        return self._call("logo-search", {"queries": queries, "format": fmt})

    def _list_tools(self, **_: Any) -> dict:
        server = self._resolve_server()
        if server is None:
            return self.error(
                "Magic MCP server not configured. Add a 'magic' entry to "
                "claude_desktop_config.json or install '@21st-dev/magic'."
            )
        try:
            tools = self._mcp_session(server, list_only=True)
        except Exception as exc:  # noqa: BLE001
            return self.error(f"MCP session failed: {exc}")
        return self.ok({"tools": tools})

    # ── MCP bridge ────────────────────────────────────────────────────────
    def _call(self, action: str, arguments: dict[str, Any]) -> dict:
        if not os.environ.get("TWENTYFIRST_API_KEY") and not os.environ.get("API_KEY"):
            self.log("WARN: TWENTYFIRST_API_KEY not set — the Magic server may reject the call.")
        server = self._resolve_server()
        if server is None:
            return self.error(
                "Magic MCP server not configured. Add a 'magic' entry to "
                "claude_desktop_config.json or install '@21st-dev/magic' "
                "(npm i -g @21st-dev/magic)."
            )
        tool_name = _TOOL_MAP.get(action, action)
        try:
            result = self._mcp_session(server, tool_name=tool_name, arguments=arguments)
        except Exception as exc:  # noqa: BLE001
            return self.error(f"MCP call '{tool_name}' failed: {exc}")
        return self.ok(result)

    def _resolve_server(self) -> dict | None:
        """Return {command, args, env} for the Magic MCP server, or None."""
        for cfg_path in _CONFIG_CANDIDATES:
            try:
                if not cfg_path or not cfg_path.is_file():
                    continue
                cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
            except Exception:  # noqa: BLE001
                continue
            entry = (cfg.get("mcpServers") or {}).get("magic")
            if entry and entry.get("command"):
                self.log(f"Magic server from {cfg_path}")
                return {
                    "command": self.resolve_cmd(entry["command"]),
                    "args": list(entry.get("args") or []),
                    "env": self._expand_env(entry.get("env") or {}),
                }
        # Fallback: official package via npx (must be installed/available).
        self.log("Magic server not in config — falling back to 'npx -y @21st-dev/magic'.")
        return {
            "command": self.resolve_cmd("npx"),
            "args": ["-y", "@21st-dev/magic@latest"],
            "env": {"API_KEY": os.environ.get("TWENTYFIRST_API_KEY", "")},
        }

    @staticmethod
    def _expand_env(env: dict[str, str]) -> dict[str, str]:
        out: dict[str, str] = {}
        for k, v in env.items():
            out[k] = os.path.expandvars(v) if isinstance(v, str) else v
        # Ensure API_KEY is populated from TWENTYFIRST_API_KEY if templated/empty.
        if not out.get("API_KEY"):
            out["API_KEY"] = os.environ.get("TWENTYFIRST_API_KEY", out.get("API_KEY", ""))
        return out

    def _mcp_session(
        self,
        server: dict,
        *,
        tool_name: str | None = None,
        arguments: dict | None = None,
        list_only: bool = False,
    ) -> Any:
        """Minimal JSON-RPC 2.0 stdio MCP client: initialize → list/call."""
        env = {**os.environ, **(server.get("env") or {})}
        cmd = [server["command"], *server.get("args", [])]
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            text=True,
            bufsize=1,
        )
        stderr_buf: list[str] = []

        def _drain_stderr() -> None:
            assert proc.stderr is not None
            for line in proc.stderr:
                stderr_buf.append(line)

        t = threading.Thread(target=_drain_stderr, daemon=True)
        t.start()

        try:
            self._send(proc, 1, "initialize", {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "merlin-cli-magic", "version": "1.0"},
            })
            self._read_until(proc, 1)
            self._notify(proc, "notifications/initialized", {})

            tools = self._list_server_tools(proc)
            if list_only:
                return [t.get("name") for t in tools]

            resolved = self._resolve_tool(tool_name or "", tools)
            self._send(proc, 2, "tools/call", {"name": resolved, "arguments": arguments or {}})
            resp = self._read_until(proc, 2)
            if "error" in resp:
                raise RuntimeError(resp["error"])
            return self._flatten_content(resp.get("result", {}))
        finally:
            try:
                proc.stdin and proc.stdin.close()
                proc.terminate()
                proc.wait(timeout=5)
            except Exception:  # noqa: BLE001
                proc.kill()
            if stderr_buf:
                self.log("server stderr: " + "".join(stderr_buf)[-500:].strip())

    def _list_server_tools(self, proc: subprocess.Popen) -> list[dict]:
        self._send(proc, 99, "tools/list", {})
        resp = self._read_until(proc, 99)
        return list((resp.get("result") or {}).get("tools") or [])

    @staticmethod
    def _resolve_tool(name: str, tools: list[dict]) -> str:
        names = [t.get("name", "") for t in tools]
        if name in names:
            return name
        key = name.lower().replace("_", "").replace("-", "")
        for n in names:
            if n.lower().replace("_", "").replace("-", "") == key:
                return n
        # Fuzzy: substring on the meaningful token (e.g. "builder", "logo").
        token = name.split("_")[-1].split("-")[-1].lower()
        for n in names:
            if token and token in n.lower():
                return n
        return name  # let the server reject it with a clear error

    # ── JSON-RPC plumbing ─────────────────────────────────────────────────
    @staticmethod
    def _send(proc: subprocess.Popen, msg_id: int, method: str, params: dict) -> None:
        assert proc.stdin is not None
        payload = {"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params}
        proc.stdin.write(json.dumps(payload) + "\n")
        proc.stdin.flush()

    @staticmethod
    def _notify(proc: subprocess.Popen, method: str, params: dict) -> None:
        assert proc.stdin is not None
        proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": method, "params": params}) + "\n")
        proc.stdin.flush()

    @staticmethod
    def _read_until(proc: subprocess.Popen, msg_id: int) -> dict:
        """Read newline-delimited JSON-RPC until the matching id arrives."""
        assert proc.stdout is not None
        import time as _t
        deadline = _t.monotonic() + _RPC_TIMEOUT
        while _t.monotonic() < deadline:
            line = proc.stdout.readline()
            if not line:
                if proc.poll() is not None:
                    raise RuntimeError("Magic server exited before responding")
                continue
            line = line.strip()
            if not line or not line.startswith("{"):
                continue  # skip banners / non-JSON noise
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            if msg.get("id") == msg_id:
                return msg
            # else: notification or other id — keep reading
        raise TimeoutError(f"No response for id={msg_id} within {_RPC_TIMEOUT}s")

    @staticmethod
    def _flatten_content(result: dict) -> Any:
        """Normalize MCP tool result content into plain JSON-friendly data."""
        content = result.get("content")
        if not isinstance(content, list):
            return result
        parts: list[Any] = []
        for item in content:
            if not isinstance(item, dict):
                parts.append(item)
            elif item.get("type") == "text":
                txt = item.get("text", "")
                try:
                    parts.append(json.loads(txt))
                except (json.JSONDecodeError, TypeError):
                    parts.append(txt)
            else:
                parts.append(item)
        if len(parts) == 1:
            return parts[0]
        return parts
