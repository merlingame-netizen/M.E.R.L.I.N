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
# Le codeur raisonne sur le palier DUR (gemma4:12b) : c'est le modèle choisi
# par Maxime pour sa compréhension. Il n'écrit pas le diff (décidé en amont),
# mais il juge la pertinence d'une mission avant de l'appliquer.
CODER_SHAPE = "judge"
# Périmètre RÉELLEMENT autorisé. La 3ᵉ entrée d'origine (`\.gd$`) ouvrait en fait
# TOUT le code du jeu, rendant la 2ᵉ décorative et le commentaire d'en-tête plus
# restrictif que le code. On s'en tient à ce qui est annoncé : les données, et le
# seul fichier de constantes d'équilibrage.
ALLOWED = (re.compile(r"^data/"),
           re.compile(r"^scripts/merlin/merlin_constants\.gd$"))


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


def _resolve(target: str) -> Path | None:
    """Chemin absolu du fichier à patcher, ou None s'il sort du périmètre.

    Une SEULE fonction décide, et elle rend le chemin qu'on utilisera vraiment.
    Avant, `_in_scope` testait `target.lstrip("./")` pendant que `_apply`
    utilisait le `target` d'origine : `AUTO / "/etc/x.gd"` donne `/etc/x.gd`,
    hors du worktree. On résout d'abord, on vérifie l'appartenance ensuite."""
    t = str(target or "").strip().lstrip("./")
    if not t or t.startswith("/") or ".." in Path(t).parts:
        return None
    if not any(rx.search(t) for rx in ALLOWED):
        return None
    try:
        path = (AUTO / t).resolve()
        # Le worktree lui-même doit exister pour que resolve() soit fiable.
        if not path.is_relative_to(AUTO.resolve()):
            return None
    except Exception:
        return None
    return path


def _in_scope(target: str) -> bool:
    """Conservé pour les tests et l'affichage — même décision que `_resolve`."""
    return _resolve(target) is not None


def _apply(change: dict) -> str | None:
    """Application déterministe before→after. Rend une erreur ou None."""
    target, before, after = change.get("target", ""), change.get("before"), change.get("after")
    if not (target and before and after):
        return "mission sans before/after — génération LLM non tentée (périmètre sûreté)"
    path = _resolve(target)
    if path is None:
        return f"cible hors périmètre autorisé : {target}"
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
    jobs, inertes = [], []
    for m in missions:
        src = PROP.ACCEPTED / f"{m.stem}.json"
        if not src.exists():
            inertes.append((m, None))
            continue
        try:
            prop = json.loads(src.read_text(encoding="utf-8"))
        except Exception:
            inertes.append((m, None))
            continue
        if prop.get("change", {}).get("before"):
            jobs.append((m, prop))
        else:
            inertes.append((m, prop))
    # Une mission sans patch ne partira JAMAIS : elle doit le dire une fois, sur
    # sa propre carte, au lieu d'attendre indéfiniment dans une file muette.
    for m, prop in inertes:
        if prop and prop.get("step") in (None, "acceptée"):
            PROP.add_step(prop["id"], "sans suite automatique",
                          "aucune ligne précise à remplacer : cette idée demande une "
                          "décision d'architecture, elle restera ici jusqu'à ton arbitrage")
    if not jobs:
        return (f"rien d'applicable — {len(missions)} mission(s) en file, "
                f"{len(inertes)} sans patch (décisions d'architecture), 0 correction mécanique")

    ref = _ref()
    err = _worktree_ready(ref)
    if err:
        return f"worktree indisponible — {err}"

    applied, skipped = [], []
    for m, prop in jobs[:5]:                      # 5 max par passage : prudence
        e = _apply(prop["change"])
        if e:
            PROP.add_step(prop["id"], "écartée", e)
            skipped.append((m.stem, e))
            continue
        PROP.add_step(prop["id"], "patchée",
                      f"{prop['change'].get('target')} modifié dans {BRANCH}")
        oks, verdict = _smoke_ok()
        if not oks:
            _git("checkout", "--", ".")           # on annule ce patch
            PROP.add_step(prop["id"], "smoke rouge",
                          f"{verdict} — patch annulé, le jeu reste intact")
            skipped.append((m.stem, f"smoke rouge ({verdict})"))
            continue
        # « smoke vert » et « smoke sauté » ne valent pas la même chose : ne pas
        # afficher la garantie qu'on n'a pas obtenue.
        PROP.add_step(prop["id"], "smoke sauté" if "absent" in verdict else "smoke vert",
                      verdict)
        _git("add", "-A")
        _git("commit", "-m",
             f"auto(nightly): {prop['title'][:60]}\n\nProposition {prop['id']} "
             f"acceptée — appliquée par le codeur local.")
        applied.append((prop["title"][:50], prop["id"]))
        DONE.mkdir(parents=True, exist_ok=True)
        m.rename(DONE / m.name)

    if applied:
        rc, out = _git("push", "-u", "origin", BRANCH, timeout=180)
        if rc != 0:
            for _t, pid in applied:
                PROP.add_step(pid, "poussée KO", out[:200])
            return f"{len(applied)} patch(s) appliqués mais push KO: {out[:100]}"
        for _t, pid in applied:
            PROP.add_step(pid, "poussée",
                          f"commit sur {BRANCH} — reste à intégrer dans {ref} (1 tap)")
        # La carte « Intégrer » : LE tap de Maxime qui fait bouger la branche du jeu.
        carte = PROP.make(
            "coder-local", "merge",
            f"Intégrer {len(applied)} patch(s) de la nuit dans {ref}",
            "Patchs appliqués sur auto/nightly, smoke vert sur chacun. "
            "Accepter fusionne dans la branche du jeu (la CI re-testera).",
            {"summary": "\n".join("· " + t for t, _ in applied),
             "target": f"{BRANCH} → {ref}"},
            f"MERGE:{BRANCH}:{ref}",
            impact={"axis": "intégration", "expected": f"+{len(applied)} patchs",
                    "risk": "med"},
            confidence=0.8)
        # Les propositions que ce merge fait aboutir : accepter la carte clôt
        # leur parcours d'un « fusionnée ». Sans ce lien, le fil s'arrête à
        # « poussée » et Maxime ne sait pas si c'est entré dans le jeu.
        carte["integrates"] = [pid for _t, pid in applied]
        PROP.write(carte)
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
