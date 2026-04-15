"""Dedupe tools/autodev/status/completed_archive.json.

Removes entries with identical (id, completed_at). Reports how many were dropped
and writes the deduplicated archive back in place. Idempotent.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ARCHIVE_PATH = Path(__file__).resolve().parents[1] / "status" / "completed_archive.json"


def dedupe(archive: list[dict] | dict) -> tuple[list[dict] | dict, int, int]:
    if isinstance(archive, dict):
        tasks = archive.get("archived_tasks") or archive.get("tasks") or []
        seen: set[tuple[str, str]] = set()
        out: list[dict] = []
        for t in tasks:
            key = (str(t.get("id", "")), str(t.get("completed_at", "")))
            if key in seen:
                continue
            seen.add(key)
            out.append(t)
        before = len(tasks)
        if "archived_tasks" in archive:
            archive["archived_tasks"] = out
        elif "tasks" in archive:
            archive["tasks"] = out
        else:
            archive["archived_tasks"] = out
        return archive, before, len(out)

    seen = set()
    out = []
    for t in archive:
        key = (str(t.get("id", "")), str(t.get("completed_at", "")))
        if key in seen:
            continue
        seen.add(key)
        out.append(t)
    return out, len(archive), len(out)


def main() -> int:
    if not ARCHIVE_PATH.exists():
        print(f"Archive not found: {ARCHIVE_PATH}", file=sys.stderr)
        return 1

    raw = json.loads(ARCHIVE_PATH.read_text(encoding="utf-8"))
    deduped, before, after = dedupe(raw)
    removed = before - after

    ARCHIVE_PATH.write_text(
        json.dumps(deduped, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"Before: {before} | After: {after} | Removed: {removed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
