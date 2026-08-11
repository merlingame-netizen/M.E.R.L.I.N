#!/usr/bin/env python3
"""Mémoire ABSOLUE du game design — append-only, rien ne s'efface jamais.

Chaque décision (acceptée, rejetée, auto-intégrée, fusionnée) et chaque note
de conversation devient une entrée horodatée. Les agents la reçoivent en
contexte : ce qui a été décidé ne se re-propose pas, ce qui a été rejeté ne
revient pas sous un autre nom.

Vit dans ~/merlin-memory/ (HORS .cache : jamais purgée par le garde-disque).
    design_memory.jsonl   le registre append-only
    chats/<id>.jsonl      les conversations du chat interne
Stdlib seule, ne lève jamais en lecture.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

BASE = Path.home() / "merlin-memory"
REGISTRY = BASE / "design_memory.jsonl"
CHATS = BASE / "chats"
KINDS = ("décision", "rejet", "contenu", "intégration", "note", "règle")


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def add(kind: str, title: str, detail: str = "", source: str = "", refs=None) -> dict:
    """Ajoute une entrée. Append-only : aucune API de suppression n'existe."""
    entry = {"t": _now(), "kind": kind if kind in KINDS else "note",
             "title": str(title)[:200], "detail": str(detail)[:800],
             "source": str(source)[:80], "refs": refs or []}
    BASE.mkdir(parents=True, exist_ok=True)
    with REGISTRY.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return entry


def entries(limit: int = 50, kind: str | None = None) -> list[dict]:
    try:
        out = [json.loads(x) for x in REGISTRY.read_text(encoding="utf-8").splitlines()
               if x.strip()]
    except Exception:
        return []
    if kind:
        out = [e for e in out if e.get("kind") == kind]
    return out[-limit:][::-1]


def count() -> int:
    try:
        return sum(1 for x in REGISTRY.open(encoding="utf-8") if x.strip())
    except Exception:
        return 0


def digest(max_chars: int = 900) -> str:
    """Condensé français pour les prompts : le design RETENU, récent d'abord."""
    lines = []
    for e in entries(limit=25):
        mark = {"décision": "✓", "rejet": "✗", "règle": "■", "intégration": "⇧",
                "contenu": "+", "note": "·"}.get(e["kind"], "·")
        lines.append(f"{mark} {e['title']}" + (f" — {e['detail'][:80]}" if e["detail"] else ""))
    text = "\n".join(lines)
    return text[:max_chars] if text else "(mémoire vide pour l'instant)"


# ── conversations du chat interne ────────────────────────────────────────────
def chat_append(conv: str, role: str, who: str, text: str) -> None:
    CHATS.mkdir(parents=True, exist_ok=True)
    with (CHATS / f"{conv}.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps({"t": _now(), "role": role, "who": who,
                            "text": str(text)[:4000]}, ensure_ascii=False) + "\n")


def chat_read(conv: str, limit: int = 40) -> list[dict]:
    try:
        rows = [json.loads(x) for x in
                (CHATS / f"{conv}.jsonl").read_text(encoding="utf-8").splitlines()
                if x.strip()]
        return rows[-limit:]
    except Exception:
        return []


def chat_list(limit: int = 12) -> list[dict]:
    try:
        out = []
        for f in sorted(CHATS.glob("*.jsonl"), key=lambda p: -p.stat().st_mtime)[:limit]:
            rows = chat_read(f.stem, limit=1)
            out.append({"conv": f.stem, "last": rows[-1]["text"][:80] if rows else "",
                        "mtime": int(f.stat().st_mtime)})
        return out
    except Exception:
        return []


if __name__ == "__main__":
    print(f"{count()} souvenir(s)\n" + digest())
