#!/usr/bin/env python3
"""Compilateur de fiches d'agents : `.claude/agents/*.md` → prompt système court.

Les 101 fiches du dépôt sont écrites pour des modèles cloud : longues, en prose
libre, avec des sections de méthode inutiles à l'exécution. Un e4b local a
4096 tokens de contexte qu'il faut réserver aux PREUVES, pas à la méthode.

Plutôt que de réécrire 101 fichiers à la main, on exploite leur structure
régulière : on garde `## Role`, `### IN SCOPE` et le bloc de sortie JSON s'il
existe ; on jette Auto-activation, Expertise, Workflow, Key References.

Cible : moins de 400 tokens (~1600 caractères). Au-delà, l'extraction est trop
laxiste et le budget de contexte part en méthode.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KEEP_HEADINGS = ("role", "in scope", "output", "output format", "sortie")
DROP_HEADINGS = ("auto-activation", "expertise", "workflow", "key references",
                 "out of scope", "references", "examples", "notes")
BUDGET_CHARS = 1600


def _sections(md: str) -> list[tuple[str, str]]:
    """Découpe en (titre normalisé, corps) sur les titres Markdown de niveau 2-3."""
    out, title, buf = [], "", []
    for line in md.splitlines():
        m = re.match(r"^#{2,3}\s+(.+?)\s*$", line)
        if m:
            if title or buf:
                out.append((title.lower(), "\n".join(buf).strip()))
            title, buf = m.group(1), []
        else:
            buf.append(line)
    if title or buf:
        out.append((title.lower(), "\n".join(buf).strip()))
    return out


def _clean(text: str) -> str:
    """Retire le front-matter YAML, les blocs de code non-JSON et les lignes vides."""
    text = re.sub(r"```(?!json)[a-z]*\n.*?```", "", text, flags=re.S)
    lines = [l.rstrip() for l in text.splitlines()]
    return "\n".join(l for l in lines if l.strip())


def compile_prompt(md_path: str | Path, extra: str = "") -> str:
    """Rend le prompt système compilé. Chemin relatif au dépôt ou absolu."""
    p = Path(md_path)
    if not p.is_absolute():
        p = ROOT / p
    raw = p.read_text(encoding="utf-8", errors="replace")
    raw = re.sub(r"^---\n.*?\n---\n", "", raw, flags=re.S)      # front-matter

    kept: list[str] = []
    for title, body in _sections(raw):
        t = title.strip()
        if any(t.startswith(d) for d in DROP_HEADINGS):
            continue
        if any(k in t for k in KEEP_HEADINGS) or not t:
            body = _clean(body)
            if body:
                kept.append(body if not t else f"{body}")
    text = "\n".join(kept).strip()

    # Le bloc JSON de sortie est prioritaire : c'est le contrat, il ne se coupe pas.
    schema = ""
    m = re.search(r"```json\n(.*?)```", raw, flags=re.S)
    if m:
        schema = m.group(1).strip()
        text = text.replace(m.group(0), "").strip()

    if extra:
        text = f"{text}\n{extra}".strip()
    room = BUDGET_CHARS - (len(schema) + 40 if schema else 0)
    if len(text) > room:
        text = text[:room].rsplit("\n", 1)[0] + " …"
    if schema:
        text += "\n\nRéponds UNIQUEMENT par un objet JSON de cette forme :\n" + schema
    return text


def est_tokens(text: str) -> int:
    """Estimation grossière (français ≈ 4 caractères/token)."""
    return len(text) // 4


if __name__ == "__main__":
    args = sys.argv[1:] or [".claude/agents/gd_difficulty.md"]
    for a in args:
        try:
            pr = compile_prompt(a)
            flag = "OK " if est_tokens(pr) < 400 else "GROS"
            print(f"{flag} {est_tokens(pr):4d} tokens  {a}")
            if "--show" in args:
                print("─" * 60); print(pr); print("─" * 60)
        except Exception as exc:
            print(f"ERR  {a}: {exc}")
