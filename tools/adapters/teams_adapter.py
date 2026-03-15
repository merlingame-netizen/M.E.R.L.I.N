"""Teams adapter — read Teams messages from Power Automate exports + LevelDB cache."""

from __future__ import annotations

import json
import os
import re
import shutil
import tempfile
from pathlib import Path
from typing import Any

from adapters.base_adapter import BaseAdapter

# ── Constants ────────────────────────────────────────────────────────────────

_PA_TEAMS_DIR = Path(
    os.environ.get(
        "TEAMS_PA_DIR",
        os.path.expanduser(
            "~/OneDrive - orange.com/Bureau/Agents/Data/teams"
        ),
    )
)

_TEAMS_CACHE_BASE = Path(
    os.environ.get(
        "TEAMS_CACHE_DIR",
        os.path.expanduser(
            "~/AppData/Local/Packages/MSTeams_8wekyb3d8bbwe"
            "/LocalCache/Microsoft/MSTeams/EBWebView/WV2Profile_tfw"
            "/IndexedDB/https_teams.microsoft.com_0.indexeddb.leveldb"
        ),
    )
)

_CONTENT_PREVIEW_LEN = 500


# ── Adapter ──────────────────────────────────────────────────────────────────


class TeamsAdapter(BaseAdapter):
    """Read Teams messages from Power Automate JSON exports or LevelDB cache.

    Primary source: Power Automate exported JSON files in the teams data dir.
    Fallback: best-effort extraction from Teams UWP LevelDB cache (fragile).
    """

    def __init__(self) -> None:
        super().__init__("teams")

    def list_actions(self) -> dict[str, str]:
        return {
            "recent-chats": "Recent chat messages from exports (--limit=20)",
            "read-chat": "Read a specific chat file (--file)",
            "search-chats": "Search messages by text (--query, --limit=20)",
            "recent-channels": "Recent channel messages from exports (--limit=20)",
            "read-channel": "Read a specific channel file (--file)",
            "cache-scan": "Best-effort scan of Teams LevelDB cache (--limit=50)",
            "status": "Show data sources status and file counts",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "recent-chats": self._recent_chats,
            "read-chat": self._read_chat,
            "search-chats": self._search_chats,
            "recent-channels": self._recent_channels,
            "read-channel": self._read_channel,
            "cache-scan": self._cache_scan,
            "status": self._status,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError(action)
        return handler(**kwargs)

    def health_probe(self) -> tuple[str, dict]:
        return "status", {}

    # ── Power Automate source ────────────────────────────────────────────

    def _list_json_files(self, subdir: str = "") -> list[Path]:
        """List JSON files in the PA export directory, sorted by mtime desc."""
        base = _PA_TEAMS_DIR / subdir if subdir else _PA_TEAMS_DIR
        if not base.is_dir():
            return []
        files = sorted(base.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
        return files

    def _read_json_file(self, path: Path) -> dict | None:
        """Read and parse a single JSON export file."""
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            return data
        except (json.JSONDecodeError, OSError) as exc:
            self.log(f"Failed to read {path.name}: {exc}")
            return None

    def _format_pa_message(self, data: dict, filepath: Path) -> dict:
        """Normalize a Power Automate export to standard message format."""
        return {
            "sender": data.get("from", data.get("sender", "")),
            "content": (data.get("body", data.get("content", "")) or "")[:_CONTENT_PREVIEW_LEN],
            "timestamp": data.get("date", data.get("timestamp", "")),
            "subject": data.get("subject", ""),
            "channel": data.get("channel", data.get("channelName", "")),
            "chat_type": data.get("chatType", data.get("type", "unknown")),
            "source": "teams",
            "file": filepath.name,
        }

    def _recent_chats(self, limit: int | str = 20, **_: Any) -> dict:
        limit = int(limit)
        files = self._list_json_files("chats") or self._list_json_files()
        if not files:
            return self.ok({
                "messages": [],
                "count": 0,
                "note": f"No JSON files found in {_PA_TEAMS_DIR}. "
                        "Configure Power Automate to export Teams chats here, "
                        "or use 'cache-scan' for best-effort LevelDB extraction.",
            })
        messages = []
        for fp in files[:limit]:
            data = self._read_json_file(fp)
            if data:
                messages.append(self._format_pa_message(data, fp))
        self.log(f"Loaded {len(messages)} chat messages from Power Automate exports")
        return self.ok({"messages": messages, "count": len(messages)})

    def _read_chat(self, file: str = "", **_: Any) -> dict:
        if not file:
            return self.error("--file is required (filename from recent-chats)")
        path = _PA_TEAMS_DIR / file
        if not path.exists():
            # Try subdir
            path = _PA_TEAMS_DIR / "chats" / file
        if not path.exists():
            return self.error(f"File not found: {file}")
        data = self._read_json_file(path)
        if data is None:
            return self.error(f"Failed to parse: {file}")
        return self.ok(self._format_pa_message(data, path))

    def _search_chats(self, query: str = "", limit: int | str = 20, **_: Any) -> dict:
        if not query:
            return self.error("--query is required")
        limit = int(limit)
        query_lower = query.lower()
        files = self._list_json_files("chats") or self._list_json_files()
        matches = []
        for fp in files:
            data = self._read_json_file(fp)
            if data is None:
                continue
            searchable = json.dumps(data, ensure_ascii=False).lower()
            if query_lower in searchable:
                matches.append(self._format_pa_message(data, fp))
                if len(matches) >= limit:
                    break
        self.log(f"Search '{query}' matched {len(matches)} messages")
        return self.ok({"messages": matches, "count": len(matches), "query": query})

    def _recent_channels(self, limit: int | str = 20, **_: Any) -> dict:
        limit = int(limit)
        files = self._list_json_files("channels")
        if not files:
            return self.ok({
                "messages": [],
                "count": 0,
                "note": f"No channel exports found in {_PA_TEAMS_DIR / 'channels'}. "
                        "Configure Power Automate to export channel messages.",
            })
        messages = []
        for fp in files[:limit]:
            data = self._read_json_file(fp)
            if data:
                messages.append(self._format_pa_message(data, fp))
        self.log(f"Loaded {len(messages)} channel messages")
        return self.ok({"messages": messages, "count": len(messages)})

    def _read_channel(self, file: str = "", **_: Any) -> dict:
        if not file:
            return self.error("--file is required")
        path = _PA_TEAMS_DIR / "channels" / file
        if not path.exists():
            path = _PA_TEAMS_DIR / file
        if not path.exists():
            return self.error(f"File not found: {file}")
        data = self._read_json_file(path)
        if data is None:
            return self.error(f"Failed to parse: {file}")
        return self.ok(self._format_pa_message(data, path))

    # ── LevelDB cache scan (best-effort fallback) ────────────────────────

    def _cache_scan(self, limit: int | str = 50, **_: Any) -> dict:
        """Best-effort extraction of readable strings from Teams LevelDB cache.

        WARNING: This is fragile — Teams UWP uses Chromium IndexedDB with a
        custom comparator (idb_cmp1). We read raw .ldb/.log files and extract
        UTF-8/UTF-16 strings that look like message content.
        """
        limit = int(limit)
        if not _TEAMS_CACHE_BASE.is_dir():
            return self.error(
                f"Teams cache not found at {_TEAMS_CACHE_BASE}. "
                "Ensure Microsoft Teams (new) is installed."
            )

        self.log("Scanning Teams LevelDB cache (best-effort)...")

        # Read all .ldb and .log files
        raw_data = bytearray()
        try:
            for f in sorted(_TEAMS_CACHE_BASE.iterdir()):
                if f.suffix in (".ldb", ".log"):
                    raw_data.extend(f.read_bytes())
        except PermissionError:
            # Try copying to temp first
            self.log("Cache locked, copying to temp directory...")
            tmp = Path(tempfile.mkdtemp(prefix="teams_cache_"))
            try:
                for f in _TEAMS_CACHE_BASE.iterdir():
                    if f.suffix in (".ldb", ".log", "") and f.name.startswith(("0", "M", "C")):
                        shutil.copy2(f, tmp / f.name)
                for f in sorted(tmp.iterdir()):
                    if f.suffix in (".ldb", ".log"):
                        raw_data.extend(f.read_bytes())
            except Exception as exc:
                return self.error(f"Failed to copy cache: {exc}")
            finally:
                shutil.rmtree(tmp, ignore_errors=True)

        if not raw_data:
            return self.error("No data in Teams cache files")

        # Extract structured data: look for displayName, channel names, message content
        extracted = self._extract_from_raw(bytes(raw_data), limit)
        self.log(f"Extracted {len(extracted)} items from cache ({len(raw_data):,} bytes scanned)")
        return self.ok({
            "items": extracted,
            "count": len(extracted),
            "cache_size_bytes": len(raw_data),
            "source": "leveldb_cache",
            "note": "Best-effort extraction. Data may be incomplete or contain non-message content.",
        })

    def _extract_from_raw(self, data: bytes, limit: int) -> list[dict]:
        """Extract readable structures from raw LevelDB data."""
        items: list[dict] = []
        seen: set[str] = set()

        # Find displayName occurrences and extract nearby context
        for m in re.finditer(rb'displayName', data):
            if len(items) >= limit:
                break
            pos = m.start()
            # Window around the match
            window = data[pos:pos + 2000]

            # Extract UTF-8 strings near this marker
            strings = re.findall(rb'[\x20-\x7e\xc0-\xff]{15,300}', window)
            readable = []
            for s in strings:
                try:
                    decoded = s.decode("utf-8", errors="strict").strip()
                    if len(decoded) > 10:
                        readable.append(decoded)
                except (UnicodeDecodeError, ValueError):
                    pass

            if readable:
                key = readable[0][:50]
                if key not in seen:
                    seen.add(key)
                    items.append({
                        "type": "cache_fragment",
                        "context": readable[:5],
                        "offset": pos,
                    })

        # Also extract meeting IDs
        for m in re.finditer(rb'19:meeting_[A-Za-z0-9+/=]+@thread\.v2', data):
            if len(items) >= limit:
                break
            meeting_id = m.group().decode("utf-8", errors="replace")
            if meeting_id not in seen:
                seen.add(meeting_id)
                items.append({
                    "type": "meeting_thread",
                    "thread_id": meeting_id,
                    "offset": m.start(),
                })

        return items

    # ── Status ───────────────────────────────────────────────────────────

    def _status(self, **_: Any) -> dict:
        """Report data source status."""
        pa_exists = _PA_TEAMS_DIR.is_dir()
        pa_files = len(list(_PA_TEAMS_DIR.glob("**/*.json"))) if pa_exists else 0
        cache_exists = _TEAMS_CACHE_BASE.is_dir()
        cache_size = 0
        if cache_exists:
            for f in _TEAMS_CACHE_BASE.iterdir():
                if f.suffix in (".ldb", ".log"):
                    cache_size += f.stat().st_size

        return self.ok({
            "power_automate": {
                "path": str(_PA_TEAMS_DIR),
                "exists": pa_exists,
                "json_files": pa_files,
            },
            "leveldb_cache": {
                "path": str(_TEAMS_CACHE_BASE),
                "exists": cache_exists,
                "size_bytes": cache_size,
                "note": "Read-only best-effort. Uses custom Chromium comparator (idb_cmp1).",
            },
            "recommendation": (
                "Power Automate exports (primary) + LevelDB cache scan (fallback). "
                "Configure Power Automate flow to export Teams messages to: "
                f"{_PA_TEAMS_DIR}"
            ),
        })
