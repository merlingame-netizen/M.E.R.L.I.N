#!/usr/bin/env python3
"""Réglages d'agents faits depuis le portail — HORS du dépôt.

Leçon (2026-08-12) : la première version écrivait directement dans le
`agents.json` versionné. Résultat : le moindre réglage depuis Parler créait une
modification locale sur la VM et **bloquait tous les déploiements** (git pull
refusé). Les réglages vivent donc dans ~/.config/merlin-agent-overrides.json,
et le manifeste du dépôt reste la base immuable.

    agents()          → manifeste + surcharges appliquées
    set_override(id, enabled=…, schedule=…)
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "agents.json"
OVERRIDES = Path.home() / ".config" / "merlin-agent-overrides.json"


def _load(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def overrides() -> dict:
    return _load(OVERRIDES, {})


def agents() -> list[dict]:
    """Le manifeste du dépôt, avec les réglages de Maxime appliqués par-dessus."""
    base = _load(MANIFEST, {}).get("agents", [])
    ov = overrides()
    for a in base:
        o = ov.get(a.get("id"), {})
        if "enabled" in o:
            a["enabled"] = bool(o["enabled"])
        if "schedule" in o:
            a["schedule"] = str(o["schedule"])
    return base


def set_override(agent_id: str, **fields) -> dict:
    """Pose un réglage. Ne touche JAMAIS le fichier versionné."""
    ov = overrides()
    cur = ov.get(agent_id, {})
    cur.update({k: v for k, v in fields.items() if v is not None})
    ov[agent_id] = cur
    OVERRIDES.parent.mkdir(parents=True, exist_ok=True)
    OVERRIDES.write_text(json.dumps(ov, ensure_ascii=False, indent=1), encoding="utf-8")
    return cur


if __name__ == "__main__":
    for a in agents():
        mark = " (réglé)" if a["id"] in overrides() else ""
        print(f"{a['id']:18s} {a['schedule']:16s} {'on ' if a['enabled'] else 'off'}{mark}")
