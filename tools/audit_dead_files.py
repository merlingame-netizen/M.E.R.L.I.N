#!/usr/bin/env python3
"""Audit d'atteignabilite du projet Godot — qu'est-ce qui sert vraiment ?

Part de ce que le moteur charge au demarrage (`project.godot` : scene
principale + autoloads + presets d'export) et suit TOUTES les references
`res://` de proche en proche, a travers les `.tscn`, `.tres`, `.gd`, `.gdextension`
et les `preload`/`load`/`ResourceLoader` du code.

Ce qui n'est jamais atteint est signale — c'est le candidat a la suppression.
Rien n'est supprime ici : le script ne fait qu'etablir la liste, avec la raison.

Trois nuances importantes, sinon l'audit ment :
  - un fichier peut etre charge par CHEMIN CONSTRUIT ("res://data/%s.json" % id).
    Ces chemins-la ne sont pas resolvables statiquement : on collecte les
    fragments litteraux et on marque comme ATTEINT tout fichier dont le nom
    apparait dans une chaine du code.
  - les `class_name` sont resolus globalement par Godot sans preload : un script
    portant un class_name utilise ailleurs est ATTEINT.
  - les tests, outils et scenes de debug ne sont pas atteints depuis le jeu mais
    ne sont pas des dechets pour autant. Ils sont classes a part.

Usage :
  python tools/audit_dead_files.py
  python tools/audit_dead_files.py --report docs/AUDIT_MENAGE.md
"""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Extensions que le moteur charge et qui peuvent en referencer d'autres.
TRAVERSABLE = {".tscn", ".tres", ".gd", ".gdextension", ".godot", ".cfg", ".import"}
# Extensions de contenu (assets, donnees) — feuilles du graphe.
CONTENT = {".png", ".jpg", ".jpeg", ".svg", ".webp", ".ogg", ".wav", ".mp3",
           ".glb", ".gltf", ".obj", ".ttf", ".otf", ".json", ".gdshader",
           ".shader", ".translation", ".csv"}

RES_RE = re.compile(r'res://([A-Za-z0-9_\-./]+)')
# DirAccess.open("res://data/cards/rpg") : tout le repertoire est charge sans
# qu'aucun fichier ne soit nomme. C'est le cas du pool RPG de 810 cartes —
# l'ignorer faisait passer 20 Mo de contenu VIVANT pour du dechet.
DIRSCAN_RE = re.compile(r'DirAccess\.open\(\s*"res://([A-Za-z0-9_\-./]+)"')
CLASSNAME_RE = re.compile(r'^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)', re.M)
STRING_RE = re.compile(r'"([^"\n]{3,120})"')


def rel(p: Path) -> str:
    return p.relative_to(REPO).as_posix()


def scan_files() -> list[Path]:
    out = []
    for p in REPO.rglob("*"):
        if not p.is_file():
            continue
        parts = set(p.relative_to(REPO).parts)
        if ".git" in parts or "node_modules" in parts or ".godot" in parts:
            continue
        out.append(p)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    files = scan_files()
    by_rel = {rel(p): p for p in files}

    # ── 1. Index des class_name et des chaines litterales du code ────────────
    classnames: dict[str, str] = {}      # ClassName -> chemin du script
    literals: set[str] = set()           # toutes les chaines vues dans du code
    for p in files:
        if p.suffix not in {".gd", ".tscn", ".tres", ".cfg", ".godot", ".json"}:
            continue
        try:
            txt = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if p.suffix == ".gd":
            for m in CLASSNAME_RE.finditer(txt):
                classnames[m.group(1)] = rel(p)
        for m in STRING_RE.finditer(txt):
            literals.add(m.group(1))

    # ── 2. Parcours en largeur depuis les racines du moteur ──────────────────
    roots: list[str] = ["project.godot"]
    proj = (REPO / "project.godot").read_text(encoding="utf-8", errors="ignore")
    for m in RES_RE.finditer(proj):
        roots.append(m.group(1))
    for extra in ("export_presets.cfg", "default_bus_layout.tres", "icon.svg"):
        if extra in by_rel:
            roots.append(extra)

    reached: set[str] = set()
    why: dict[str, str] = {}
    queue = [r for r in roots if r in by_rel]
    for r in queue:
        reached.add(r)
        why[r] = "racine moteur (project.godot)"

    while queue:
        cur = queue.pop()
        p = by_rel.get(cur)
        if p is None or p.suffix not in TRAVERSABLE:
            continue
        try:
            txt = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        # references res:// explicites
        targets = {m.group(1) for m in RES_RE.finditer(txt)}
        # class_name utilises dans ce fichier -> le script qui les declare
        for name, script in classnames.items():
            if re.search(r'\b' + re.escape(name) + r'\b', txt):
                targets.add(script)
        for t in targets:
            if t in by_rel and t not in reached:
                reached.add(t)
                why[t] = f"reference depuis {cur}"
                queue.append(t)

    # ── 2bis. Repertoires ouverts en scan : tout leur contenu est atteint ────
    scanned_dirs: set[str] = set()
    for r in list(reached):
        p = by_rel.get(r)
        if p is None or p.suffix != ".gd":
            continue
        try:
            txt = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in DIRSCAN_RE.finditer(txt):
            scanned_dirs.add(m.group(1).rstrip("/"))
    for d in scanned_dirs:
        for r in by_rel:
            if r.startswith(d + "/"):
                if r not in reached:
                    reached.add(r)
                    why[r] = f"repertoire {d}/ ouvert en scan (DirAccess)"

    # ── 3. Rattrapage : fichiers nommes dans une chaine litterale ────────────
    # Couvre les chemins construits ("res://data/cards/%s.json" % pool).
    for r, p in by_rel.items():
        if r in reached:
            continue
        name = p.name
        stem = p.stem
        if any(name in lit or (len(stem) > 6 and stem in lit) for lit in literals):
            reached.add(r)
            why[r] = "nom cite dans une chaine du code (chemin construit)"

    # ── 4. Classement de ce qui n'est pas atteint ────────────────────────────
    CATEGORIES = [
        ("projet etranger", lambda r: r.startswith(("evg-alexandre/", "catboost_info/",
                                                    "tools/flight_tracker/"))),
        ("archive declaree", lambda r: r.startswith("archive/") or "/_archive/" in r
                                        or "/legacy/" in r),
        ("port web separe", lambda r: r.startswith("web-demo/")),
        ("outillage dev", lambda r: r.startswith(("tools/", "tests/", "scripts/test/",
                                                  "server/", "native/", "llm_simple/"))),
        ("documentation", lambda r: r.startswith("docs/") or r.endswith(".md")),
        ("sortie generee", lambda r: r.startswith(("output/", "logs/", ".octogent/"))),
    ]

    unreached = defaultdict(list)
    for r, p in sorted(by_rel.items()):
        if r in reached:
            continue
        for label, test in CATEGORIES:
            if test(r):
                unreached[label].append((r, p.stat().st_size))
                break
        else:
            unreached["contenu du jeu non atteint"].append((r, p.stat().st_size))

    # ── 5. Rapport ───────────────────────────────────────────────────────────
    L = ["# Audit de menage — ce qui sert, ce qui ne sert pas", ""]
    L.append("> Genere par `tools/audit_dead_files.py`. Le graphe part de "
             "`project.godot` (scene principale + autoloads) et suit toutes les "
             "references `res://`, les `class_name` et les noms cites dans des "
             "chaines. **Aucun fichier n'est supprime par ce script.**")
    L.append("")
    tot = len(by_rel)
    L.append(f"**{len(reached)} fichiers atteints** sur {tot} — "
             f"{tot - len(reached)} jamais references.")
    L.append("")
    L.append("| Categorie | Fichiers | Poids |")
    L.append("|---|---:|---:|")
    for label, items in sorted(unreached.items(), key=lambda kv: -sum(s for _, s in kv[1])):
        mo = sum(s for _, s in items) / (1024 * 1024)
        L.append(f"| {label} | {len(items)} | {mo:.1f} Mo |")
    L.append("")
    for label, items in sorted(unreached.items(), key=lambda kv: -sum(s for _, s in kv[1])):
        L.append(f"## {label} — {len(items)} fichiers")
        L.append("")
        for r, s in sorted(items, key=lambda x: -x[1])[:60]:
            L.append(f"- `{r}` ({s / 1024:.0f} Ko)")
        if len(items) > 60:
            L.append(f"- … et {len(items) - 60} autres")
        L.append("")

    txt = "\n".join(L)
    if args.report:
        Path(args.report).write_text(txt, encoding="utf-8")
        print(f"Rapport ecrit : {args.report}")
    print(f"{len(reached)}/{tot} fichiers atteints depuis project.godot")
    for label, items in sorted(unreached.items(), key=lambda kv: -sum(s for _, s in kv[1])):
        mo = sum(s for _, s in items) / (1024 * 1024)
        print(f"  {label:<32} {len(items):>5} fichiers  {mo:>7.1f} Mo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
