#!/usr/bin/env python3
"""Mesure la diversité entre PLUSIEURS runs réellement joués dans le moteur.

`check_scenario_diversity.py` mesure un corpus de scénarios sur disque.
Celui-ci mesure autre chose, et de plus décisif : **ce que le jeu produit
quand on le fait tourner plusieurs fois**. C'est la seule preuve qui vaille
pour l'exigence « aucun scénario ne doit ressembler à un autre » — pas le
contenu d'un fichier, mais la sortie de l'exécution.

Consomme un répertoire de transcripts (`MERLIN_TRANSCRIPT=<chemin>` sur chaque
run) et compare les runs entre eux :

  IDENTITÉ     titre du scénario, scénario du catalogue retenu
  PARCOURS     séquence exacte des cartes tirées
  TEXTE        recouvrement lexical entre les runs
  ACTIONS      vocabulaire d'options offert au joueur, tous runs confondus
  COUVERTURE   part du pool du biome réellement vue
  GRAINE       graines de variation tirées (lues dans les logs du moteur)

Usage :
  python tools/check_run_diversity.py --dir runs/
  python tools/check_run_diversity.py --dir runs/ --report docs/30_jdr/RUN_SERIES_REPORT.md
"""

from __future__ import annotations

import argparse
import itertools
import json
import re
from collections import Counter
from pathlib import Path

WORD = re.compile(r"[a-zà-ÿœ]+", re.IGNORECASE)
SEED_LINE = re.compile(r"graine de variation\s*:\s*(\{.*\})")
TITLE_LINE = re.compile(r"titre auto-choisi\s*:\s*(.+?)\s*$", re.MULTILINE)


def toks(s: str) -> set:
    return {w.lower() for w in WORD.findall(s or "") if len(w) > 4}


def jaccard(a: set, b: set) -> float:
    return len(a & b) / len(a | b) if (a or b) else 0.0


def load_runs(directory: Path) -> list:
    runs = []
    for f in sorted(directory.glob("*.json")):
        try:
            data = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        entries = data.get("entrees", [])
        cards = [e for e in entries if e.get("evenement") == "carte_affichee"]
        start = next((e for e in entries if e.get("evenement") == "debut_run"), {})
        end = next((e for e in entries if e.get("evenement") == "fin_run"), {})
        log = f.with_suffix(".log")
        seed, title = "", ""
        if log.exists():
            txt = log.read_text(encoding="utf-8", errors="replace")
            m = SEED_LINE.search(txt)
            if m:
                seed = m.group(1)
            t = TITLE_LINE.search(txt)
            if t:
                title = t.group(1).strip()
        runs.append({
            "nom": f.stem,
            "titre": title,
            "scenario": (start.get("hud") or {}).get("scenario_actif", ""),
            "graine": seed,
            "cartes": [c.get("carte_id", "") for c in cards],
            "textes": " ".join(c.get("texte", "") for c in cards),
            "labels": [o.get("label", "") for c in cards
                       for o in c.get("options_visibles", [])],
            "vie_finale": (end.get("hud") or {}).get("vie"),
            "anam": data.get("anam_gagne"),
        })
    return runs


def analyse(runs: list, pool_size: int) -> dict:
    n = len(runs)
    res = {"n": n}
    if n == 0:
        return res

    res["titres_distincts"] = len({r["titre"] for r in runs if r["titre"]})
    res["scenarios_distincts"] = len({r["scenario"] for r in runs if r["scenario"]})
    res["parcours_distincts"] = len({tuple(r["cartes"]) for r in runs})
    res["graines_distinctes"] = len({r["graine"] for r in runs if r["graine"]})
    res["graines_lues"] = sum(1 for r in runs if r["graine"])

    used = {c for r in runs for c in r["cartes"] if c}
    res["cartes_vues"] = len(used)
    res["pool"] = pool_size
    res["couverture"] = len(used) / pool_size if pool_size else 0.0

    labels = [l for r in runs for l in r["labels"]]
    res["labels_total"] = len(labels)
    res["labels_distincts"] = len(set(labels))

    pairs = []
    for a, b in itertools.combinations(runs, 2):
        pairs.append((jaccard(toks(a["textes"]), toks(b["textes"])), a["nom"], b["nom"]))
    pairs.sort(reverse=True)
    res["paires"] = pairs
    res["jaccard_moyen"] = sum(p[0] for p in pairs) / len(pairs) if pairs else 0.0
    res["jaccard_max"] = pairs[0][0] if pairs else 0.0

    seq = Counter(tuple(r["cartes"]) for r in runs)
    res["parcours_le_plus_frequent"] = seq.most_common(1)[0][1] if seq else 0
    return res


def verdict_lines(res: dict) -> list:
    n = res["n"]
    out = []

    def check(ok, label, detail):
        out.append((ok, label, detail))

    check(res["titres_distincts"] == n or res["titres_distincts"] == 0,
          f"Titres distincts : {res['titres_distincts']}/{n}",
          "chaque run devrait proposer un titre inédit")
    check(res["parcours_distincts"] == n,
          f"Parcours de cartes distincts : {res['parcours_distincts']}/{n}",
          f"le parcours le plus fréquent revient {res['parcours_le_plus_frequent']} fois")
    check(res["jaccard_max"] <= 0.35,
          f"Recouvrement lexical max entre runs : {res['jaccard_max']:.0%}",
          "au-delà de 35 %, deux runs racontent la même chose")
    check(res["couverture"] >= 0.8,
          f"Couverture du pool : {res['cartes_vues']}/{res['pool']} cartes vues ({res['couverture']:.0%})",
          "sur plusieurs runs, le joueur devrait voir l'essentiel du pool")
    check(res["graines_distinctes"] == res["graines_lues"] and res["graines_lues"] > 0,
          f"Graines de variation distinctes : {res['graines_distinctes']}/{res['graines_lues']} lues",
          "la graine doit différer à chaque scénario")
    return out


def render(res: dict, runs: list) -> str:
    L = ["# Diversité entre runs — mesurée sur l'exécution du jeu", ""]
    L.append("> Généré par `tools/check_run_diversity.py`. Ne mesure pas un fichier de "
             "scénarios : mesure ce que le moteur **produit réellement** quand on le fait "
             "tourner plusieurs fois de suite. C'est la seule preuve qui vaille pour "
             "l'exigence « aucun scénario ne doit ressembler à un autre ».")
    L.append("")
    L.append(f"{res['n']} runs joués en autoplay headless.")
    L.append("")
    L.append("## Verdict")
    L.append("")
    L.append("| Critère | Résultat |")
    L.append("|---|---|")
    for ok, label, detail in verdict_lines(res):
        L.append(f"| {label} | {'PASS' if ok else '**FAIL** — ' + detail} |")
    L.append("")
    L.append("## Runs")
    L.append("")
    L.append("| Run | Titre | Scénario | Cartes tirées | Vie | Anam |")
    L.append("|---|---|---|---|---:|---:|")
    for r in runs:
        L.append(f"| {r['nom']} | {r['titre'] or '—'} | {r['scenario'] or '—'} | "
                 f"`{' '.join(c.replace('fr_broceliande_', '') for c in r['cartes'])}` | "
                 f"{r['vie_finale']} | {r['anam']} |")
    L.append("")
    if res["paires"]:
        L.append("## Paires de runs les plus proches")
        L.append("")
        for v, a, b in res["paires"][:5]:
            L.append(f"- {v:.0%} — `{a}` ≈ `{b}`")
        L.append("")
    L.append("## Vocabulaire d'actions")
    L.append("")
    L.append(f"{res['labels_distincts']} libellés distincts sur {res['labels_total']} "
             f"options proposées au joueur, tous runs confondus.")
    L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--pool-size", type=int, default=12,
                    help="taille du pool de cartes du biome (defaut : 12 pour Broceliande)")
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    runs = load_runs(Path(args.dir))
    if not runs:
        print(f"Aucun transcript exploitable dans {args.dir}")
        return 2
    res = analyse(runs, args.pool_size)

    print(f"=== {res['n']} runs joues ===")
    for r in runs:
        seq = " ".join(c.replace("fr_broceliande_", "") for c in r["cartes"])
        print(f"  {r['nom']:<8} titre={r['titre'][:34]:<34} cartes=[{seq}] vie={r['vie_finale']}")
    print()
    for ok, label, detail in verdict_lines(res):
        print(f"[{'PASS' if ok else 'FAIL'}] {label}")
        if not ok:
            print(f"       {detail}")

    if args.report:
        Path(args.report).write_text(render(res, runs), encoding="utf-8")
        print(f"\nRapport ecrit : {args.report}")
    return 1 if any(not ok for ok, _, _ in verdict_lines(res)) else 0


if __name__ == "__main__":
    raise SystemExit(main())
