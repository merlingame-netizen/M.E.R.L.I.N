#!/usr/bin/env python3
"""Codeur LOCAL — applique les missions acceptées sur une branche auto/nightly.

Réalité assumée : à ~1 token/s, Gemma e4b ne « code » pas au moment d'agir.
Le diff est décidé EN AMONT (la proposition porte change.target/before/after) ;
ici on APPLIQUE de façon déterministe, on smoke, on pousse. Le LLM n'intervient
qu'en dernier recours, pour les missions sans before/after, et sous périmètre.

Périmètre autorisé SEUL (décision Maxime) :
  - data/**            (cartes, JSON, corpus)
  - scripts/**/merlin_constants.gd  (équilibrage)
  - *.gd : remplacement exact ≤ 30 lignes
Hors périmètre → la mission reste en file et une carte Décider l'explique.

Sécurité : travaille dans un WORKTREE dédié (~/workspace/merlin-auto), jamais
dans le clone joué ; pousse sur auto/nightly ; le merge dans la branche du jeu
reste un tap de Maxime (carte kind=merge).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gates            # noqa: E402
import proposals as PROP  # noqa: E402

MISSIONS = Path.home() / ".cache" / "merlin-missions" / "queue"
DONE = Path.home() / ".cache" / "merlin-missions" / "done"
GAME = Path.home() / "workspace" / "merlin-game"
AUTO = Path.home() / "workspace" / "merlin-auto"
BRANCH = "auto/nightly"
GODOT = Path.home() / "bin" / "godot"
MAX_PATCH_LINES = 30
ALLOWED = (re.compile(r"^data/"), re.compile(r"merlin_constants\.gd$"),
           re.compile(r"\.gd$"))


def _git(*args, cwd=AUTO, timeout=120) -> tuple[int, str]:
    p = subprocess.run(["git", "-C", str(cwd), *args],
                       capture_output=True, text=True, timeout=timeout)
    return p.returncode, (p.stdout + p.stderr).strip()


def _ref() -> str:
    conf = Path.home() / ".config" / "merlin-game.env"
    for line in conf.read_text().splitlines() if conf.exists() else []:
        if line.startswith("GAME_REF="):
            return line.split("=", 1)[1].strip()
    return "feat/practices-docs"


def _worktree_ready(ref: str) -> str | None:
    if not (GAME / ".git").exists():
        return "clone du jeu absent"
    if not AUTO.exists():
        rc, out = _git("worktree", "add", "-B", BRANCH, str(AUTO),
                       f"origin/{ref}", cwd=GAME, timeout=300)
        if rc != 0:
            return f"worktree KO: {out[:120]}"
    _git("fetch", "origin", ref, cwd=GAME, timeout=180)
    # la branche auto continue son histoire ; on la rebase sur le jeu à jour
    rc, out = _git("rebase", f"origin/{ref}")
    if rc != 0:
        _git("rebase", "--abort")
        return f"rebase impossible (conflit ?) : {out[:120]}"
    return None


def _in_scope(target: str) -> bool:
    t = target.lstrip("./")
    return any(rx.search(t) for rx in ALLOWED) and ".." not in t


def _apply(change: dict) -> str | None:
    """Application déterministe before→after. Rend une erreur ou None."""
    target, before, after = change.get("target", ""), change.get("before"), change.get("after")
    if not (target and before and after):
        return "mission sans before/after — génération LLM non tentée (périmètre sûreté)"
    if not _in_scope(target):
        return f"cible hors périmètre autorisé : {target}"
    path = AUTO / target
    if not path.exists():
        return f"fichier introuvable : {target}"
    if max(len(before.splitlines()), len(after.splitlines())) > MAX_PATCH_LINES:
        return f"patch > {MAX_PATCH_LINES} lignes — décision stratégique"
    text = path.read_text(encoding="utf-8")
    if before not in text:
        return "le texte à remplacer n'existe pas (le fichier a changé depuis la proposition)"
    if text.count(before) > 1:
        return "remplacement ambigu (plusieurs occurrences)"
    path.write_text(text.replace(before, after, 1), encoding="utf-8")
    return None


def _smoke_ok() -> tuple[bool, str]:
    """Boot headless de la scène principale du worktree — le juge minimal."""
    if not GODOT.exists():
        return True, "godot absent, smoke sauté"
    try:
        p = subprocess.run([str(GODOT), "--headless", "--path", str(AUTO),
                            "--quit-after", "4"], capture_output=True, text=True,
                           timeout=120)
        bad = (p.stdout + p.stderr).count("SCRIPT ERROR")
        return bad == 0, f"{bad} SCRIPT ERROR"
    except Exception as exc:
        return False, f"smoke KO: {exc}"


def run() -> str:
    ok, why = gates.chain_allowed()
    if not ok:
        return f"suspendu — {why}"
    missions = sorted(MISSIONS.glob("*.md")) if MISSIONS.exists() else []
    # Le codeur ne traite que les missions issues de propositions structurées.
    jobs = []
    for m in missions:
        src = PROP.ACCEPTED / f"{m.stem}.json"
        if src.exists():
            prop = json.loads(src.read_text(encoding="utf-8"))
            if prop.get("change", {}).get("before"):
                jobs.append((m, prop))
    if not jobs:
        return f"rien d'applicable ({len(missions)} mission(s) en file, aucune avec before/after)"

    ref = _ref()
    err = _worktree_ready(ref)
    if err:
        return f"worktree indisponible — {err}"

    applied, skipped = [], []
    for m, prop in jobs[:5]:                      # 5 max par passage : prudence
        e = _apply(prop["change"])
        if e:
            skipped.append((m.stem, e))
            continue
        oks, verdict = _smoke_ok()
        if not oks:
            _git("checkout", "--", ".")           # on annule ce patch
            skipped.append((m.stem, f"smoke rouge ({verdict})"))
            continue
        _git("add", "-A")
        _git("commit", "-m",
             f"auto(nightly): {prop['title'][:60]}\n\nProposition {prop['id']} "
             f"acceptée — appliquée par le codeur local.")
        applied.append(prop["title"][:50])
        DONE.mkdir(parents=True, exist_ok=True)
        m.rename(DONE / m.name)

    if applied:
        rc, out = _git("push", "-u", "origin", BRANCH, timeout=180)
        if rc != 0:
            return f"{len(applied)} patch(s) appliqués mais push KO: {out[:100]}"
        # La carte « Intégrer » : LE tap de Maxime qui fait bouger la branche du jeu.
        PROP.write(PROP.make(
            "coder-local", "merge",
            f"Intégrer {len(applied)} patch(s) de la nuit dans {ref}",
            "Patchs appliqués sur auto/nightly, smoke vert sur chacun. "
            "Accepter fusionne dans la branche du jeu (la CI re-testera).",
            {"summary": "\n".join("· " + t for t in applied),
             "target": f"{BRANCH} → {ref}"},
            f"MERGE:{BRANCH}:{ref}",
            impact={"axis": "intégration", "expected": f"+{len(applied)} patchs",
                    "risk": "med"},
            confidence=0.8))
    parts = []
    if applied:
        parts.append(f"{len(applied)} appliqué(s) → {BRANCH}")
    if skipped:
        parts.append(f"{len(skipped)} écarté(s) : " + "; ".join(
            f"{n} ({e[:40]})" for n, e in skipped[:2]))
    return " · ".join(parts) or "rien fait"


if __name__ == "__main__":
    try:
        print(run())
    except Exception as exc:
        print(f"échec codeur local: {type(exc).__name__}: {exc}"[:180])
        sys.exit(1)
