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
import re
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


# La signature d'une panne d'outillage. Ces entrées ont été gravées quand
# accepter une proposition ratée gravait son titre : la mémoire s'est remplie de
# vingt « analyse seule — JSON illisible ». On ne les EFFACE pas (rien ne
# s'efface jamais, c'est le principe du registre), mais on ne les montre plus et
# on ne les sert plus aux agents : ce ne sont pas des décisions de design.
_BRUIT = re.compile(
    r"(JSON illisible|LLM indisponible|analyse seule|rédaction automatique a échoué"
    r"|validateur indisponible|^```)", re.I)


def entries(limit: int = 50, kind: str | None = None, tout: bool = False) -> list[dict]:
    try:
        out = [json.loads(x) for x in REGISTRY.read_text(encoding="utf-8").splitlines()
               if x.strip()]
    except Exception:
        return []
    if kind:
        out = [e for e in out if e.get("kind") == kind]
    if not tout:
        out = [e for e in out
               if not _BRUIT.search(f"{e.get('title','')} {e.get('detail','')}")]
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


def reponses_de_maxime(agent: str, limit: int = 5, max_chars: int = 400) -> str:
    """Ce que Maxime a répondu À CET AGENT, dans ses mots à lui.

    C'est la seule trace d'intention humaine du système. Un agent qui la relit
    cesse de re-proposer ce qui vient d'être refusé « pas maintenant », et sait
    sur quoi son auteur l'attend. Rend une chaîne vide s'il n'y a rien : on
    n'occupe pas le contexte pour dire qu'on n'a rien à dire."""
    suffixe = f"/{agent}"
    lignes = []
    for e in entries(limit=120):
        src = str(e.get("source", ""))
        if not (src.startswith("maxime") and src.endswith(suffixe)):
            continue
        detail = str(e.get("detail", "")).strip()
        if not detail or detail.startswith("auto "):
            continue
        mark = "✗" if e.get("kind") == "rejet" else "✓"
        lignes.append(f"{mark} « {detail[:110]} » (à propos de : {e['title'][:60]})")
        if len(lignes) >= limit:
            break
    return "\n".join(lignes)[:max_chars]


# ── conversations du chat interne ────────────────────────────────────────────
import contextlib
import os


@contextlib.contextmanager
def _verrou(conv: str):
    """Verrou par conversation — PRÉALABLE DUR à plusieurs agents qui écrivent.

    `chat_mark_action_done` lit tout le fichier, le modifie et le RÉÉCRIT. Avec
    un seul écrivain par jour (le conseil du matin), c'était inoffensif. Dès que
    plusieurs agents peuvent ouvrir un fil, un message écrit pendant cette
    séquence disparaît sans laisser de trace. Le verrou est posé sur un fichier
    à part : `chats/` ne doit contenir QUE des `.jsonl`, sinon `chat_list()` les
    prendrait pour des conversations."""
    CHATS.mkdir(parents=True, exist_ok=True)
    lock = BASE / ".locks"
    lock.mkdir(parents=True, exist_ok=True)
    f = (lock / f"{conv}.lock").open("a+")
    try:
        try:
            import fcntl
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        except Exception:
            pass                      # pas de fcntl : on continue sans verrou
        yield
    finally:
        with contextlib.suppress(Exception):
            f.close()


def chat_append(conv: str, role: str, who: str, text: str, actions=None) -> None:
    row = {"t": _now(), "role": role, "who": who, "text": str(text)[:4000]}
    if actions:
        row["actions"] = actions          # boutons proposés par le conseiller
    with _verrou(conv):
        with (CHATS / f"{conv}.jsonl").open("a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def chat_mark_action_done(conv: str, action_id: str) -> None:
    """Marque une action exécutée (append-only : on réécrit le fichier)."""
    with _verrou(conv):
        try:
            rows = [json.loads(x) for x in
                    (CHATS / f"{conv}.jsonl").read_text(encoding="utf-8").splitlines()
                    if x.strip()]
        except Exception:
            return
        for r in rows:
            for a in r.get("actions", []):
                if a.get("id") == action_id:
                    a["done"] = True
        (CHATS / f"{conv}.jsonl").write_text(
            "\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n",
            encoding="utf-8")


def chat_find_action(conv: str, action_id: str) -> dict | None:
    """Retrouve une action par id — le backend ne fait JAMAIS confiance au front."""
    for r in chat_read(conv, limit=200):
        for a in r.get("actions", []):
            if a.get("id") == action_id:
                return a
    return None


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
            dernier = rows[-1] if rows else {}
            out.append({"conv": f.stem, "id": f.stem,
                        "last": str(dernier.get("text", ""))[:80],
                        # Le texte ENTIER du dernier message. `last` reste court
                        # pour les listes ; les 80 caractères étaient la vraie
                        # cause des messages d'agents coupés au milieu d'un mot
                        # — la carte, elle, doit pouvoir tout montrer.
                        "last_full": str(dernier.get("text", ""))[:4000],
                        "actions": dernier.get("actions") or [],
                        # QUI a parlé en dernier : sans ça, impossible de savoir
                        # si un fil attend une réponse de Maxime ou d'un agent.
                        "role": dernier.get("role", ""), "who": dernier.get("who", ""),
                        "t": dernier.get("t", ""),
                        "mtime": int(f.stat().st_mtime)})
        return out
    except Exception:
        return []


if __name__ == "__main__":
    print(f"{count()} souvenir(s)\n" + digest())
