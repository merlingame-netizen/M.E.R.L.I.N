#!/usr/bin/env python3
"""Mesure la DIVERSITÉ d'un ensemble de scénarios.

`validate_scenario_balance.py` vérifie qu'un scénario respecte la forme et
l'économie du contrat. Il ne dit rien de la question posée ici : **est-ce que
deux scénarios se ressemblent ?**

Un scénario peut être parfaitement conforme et n'être qu'une copie du
précédent. Comme les scénarios doivent être générés à 100 % par le LLM, la
diversité n'est pas un confort : c'est la raison d'être de la génération. Elle
doit donc être bornée et mesurée, exactement comme les dégâts ou les raretés.

Six axes, du plus grossier au plus fin :

  SÉMANTIQUE     cosinus entre embeddings (si disponibles) — deux scénarios qui
                 racontent la même chose autrement restent proches
  LEXICAL        recouvrement de vocabulaire entre intros/prémisses
  SITUATIONNEL   part de résumés de cartes distincts sur l'ensemble du corpus
  VERBAL         taille du vocabulaire d'actions offert au joueur
  STRUCTUREL     part de signatures distinctes (archétype/pôle/twist/longueur/arc)
  MOTIFS         entités et images récurrentes (le « chêne » de trop)

Usage :
  python tools/check_scenario_diversity.py
  python tools/check_scenario_diversity.py --file data/ai/scenario_golden_broceliande.json
  python tools/check_scenario_diversity.py --report docs/30_jdr/SCENARIO_DIVERSITY_REPORT.md
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TPL = REPO / "data/ai/scenario_templates.json"

# Mots outils français — exclus des mesures lexicales.
STOP = set("""le la les un une des du de d a à au aux et ou ni mais donc or car que qui
quoi dont où ce cet cette ces son sa ses ton ta tes mon ma mes leur leurs il elle ils
elles on nous vous je tu se sa te me lui y en est sont était être avoir as ai a ont
pour par sur sous dans avec sans vers chez entre plus moins très tout toute tous toutes
ne pas plus jamais rien deux trois comme quand si alors puis encore déjà là ici cela ça
te toi soi même autre autres fait faire dit dire va vais vas peut peux""".split())

WORD = re.compile(r"[a-zà-ÿœ]+", re.IGNORECASE)


def content_words(text: str) -> set:
    return {w.lower() for w in WORD.findall(text or "") if len(w) > 3 and w.lower() not in STOP}


def jaccard(a: set, b: set) -> float:
    return len(a & b) / len(a | b) if (a or b) else 0.0


def cosine(a: list, b: list) -> float:
    d = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return d / (na * nb) if na and nb else 0.0


class Axis:
    __slots__ = ("name", "measure", "target", "ok", "detail", "worst")

    def __init__(self, name, measure, target, ok, detail, worst=None):
        self.name, self.measure, self.target = name, measure, target
        self.ok, self.detail, self.worst = ok, detail, worst or []


# ─────────────────────────────────────────────────────────────── axes ──

def axis_semantic(scen: list, thr: dict, emb_path: Path) -> Axis:
    if not emb_path.exists():
        return Axis("sémantique", "—", f"< {thr['max_pair_cosine']}", True,
                    "embeddings absents — axe non mesuré")
    data = json.load(open(emb_path, encoding="utf-8"))
    recs = data.get("embeddings", [])
    known = {s["id"] for s in scen}
    recs = [r for r in recs if r.get("id") in known]
    if len(recs) < 2:
        return Axis("sémantique", "—", f"< {thr['max_pair_cosine']}", True,
                    "moins de 2 scénarios embarqués — axe non mesuré")
    titles = {s["id"]: s.get("title", "") for s in scen}
    pairs = []
    for i, j in itertools.combinations(range(len(recs)), 2):
        pairs.append((cosine(recs[i]["vector"], recs[j]["vector"]),
                      recs[i]["id"], recs[j]["id"]))
    pairs.sort(reverse=True)
    vals = [p[0] for p in pairs]
    mean = sum(vals) / len(vals)
    over = [p for p in pairs if p[0] > thr["max_pair_cosine"]]
    ok = not over and mean <= thr["max_mean_cosine"]
    worst = [f"{v:.3f} — « {titles.get(a, a)} » ≈ « {titles.get(b, b)} »"
             for v, a, b in pairs[:5]]
    return Axis("sémantique", f"moyenne {mean:.3f}, max {vals[0]:.3f}",
                f"moyenne ≤ {thr['max_mean_cosine']}, aucune paire > {thr['max_pair_cosine']}",
                ok, f"{len(over)} paire(s) au-dessus du seuil sur {len(pairs)}", worst)


def axis_lexical(scen: list, thr: dict) -> Axis:
    docs = {s["id"]: content_words(f"{s.get('intro','')} {s.get('premise','')}") for s in scen}
    titles = {s["id"]: s.get("title", "") for s in scen}
    ids = list(docs)
    if len(ids) < 2:
        return Axis("lexical", "—", "—", True, "un seul scénario — axe non mesuré")
    pairs = [(jaccard(docs[a], docs[b]), a, b) for a, b in itertools.combinations(ids, 2)]
    pairs.sort(reverse=True)
    vals = [p[0] for p in pairs]
    mean = sum(vals) / len(vals)
    over = [p for p in pairs if p[0] > thr["max_pair_jaccard"]]
    worst = [f"{v:.2f} — « {titles[a]} » ≈ « {titles[b]} »" for v, a, b in pairs[:5]]
    return Axis("lexical", f"Jaccard moyen {mean:.2f}, max {vals[0]:.2f}",
                f"aucune paire > {thr['max_pair_jaccard']}", not over,
                f"{len(over)} paire(s) au-dessus du seuil sur {len(pairs)}", worst)


def axis_situational(scen: list, thr: dict) -> Axis:
    sums = [c.get("summary", "") for s in scen for c in s.get("cards", [])]
    if not sums:
        return Axis("situationnel", "—", "—", True, "aucune carte")
    c = Counter(sums)
    ratio = len(c) / len(sums)
    worst = [f"×{n} — « {t[:70]}… »" for t, n in c.most_common(4) if n > 1]
    return Axis("situationnel", f"{len(c)}/{len(sums)} résumés distincts ({ratio:.0%})",
                f"≥ {thr['min_unique_summaries']:.0%}", ratio >= thr["min_unique_summaries"],
                f"{sum(n - 1 for n in c.values() if n > 1)} résumés dupliqués", worst)


def axis_verbal(scen: list, thr: dict) -> Axis:
    labels = [o.get("label", "") for s in scen for c in s.get("cards", []) for o in c.get("options", [])]
    verbs = [o.get("verb", "") for s in scen for c in s.get("cards", []) for o in c.get("options", [])]
    if not labels:
        return Axis("verbal", "—", "—", True, "aucune option")
    cl, cv = Counter(labels), Counter(v for v in verbs if v)
    ratio = len(cl) / len(labels)
    per_scen = thr["min_distinct_verbs_per_scenario"]
    need = max(per_scen, int(per_scen * math.sqrt(max(len(scen), 1))))
    ok = len(cv) >= need and ratio >= thr["min_unique_labels"]
    worst = [f"×{n} — « {t} »" for t, n in cl.most_common(4) if n > 1]
    return Axis("verbal",
                f"{len(cl)}/{len(labels)} libellés distincts ({ratio:.0%}), "
                f"{len(cv)} verbes distincts",
                f"libellés ≥ {thr['min_unique_labels']:.0%}, verbes ≥ {need}",
                ok, f"vocabulaire d'action offert au joueur", worst)


def axis_structural(scen: list, thr: dict) -> Axis:
    sigs = [(s.get("archetype_id"), s.get("pole_dominant"), s.get("twist_pattern"),
             s.get("length"), tuple(s.get("emotional_arc", [])[:6])) for s in scen]
    c = Counter(sigs)
    ratio = len(c) / len(sigs) if sigs else 1.0
    worst = [f"×{n} — {sig[0]} / {sig[1]} / {sig[2]} / {sig[3]} cartes"
             for sig, n in c.most_common(4) if n > 1]
    return Axis("structurel", f"{len(c)}/{len(sigs)} signatures distinctes ({ratio:.0%})",
                f"≥ {thr['min_unique_signatures']:.0%}", ratio >= thr["min_unique_signatures"],
                "archétype + pôle + twist + longueur + début d'arc", worst)


def axis_motifs(scen: list, thr: dict) -> Axis:
    # Un motif « présent dans 100 % des scénarios » n'a aucun sens sur un
    # échantillon de 1 ou 2 : la mesure n'est informative qu'à partir de 3.
    if len(scen) < 3:
        return Axis("motifs", "—", f"aucun motif > {thr['max_motif_share']:.0%}", True,
                    f"{len(scen)} scénario(s) — échantillon trop petit, axe non mesuré")
    words = Counter()
    for s in scen:
        seen = set()
        for c in s.get("cards", []):
            seen |= content_words(c.get("summary", ""))
        seen |= content_words(s.get("intro", ""))
        words.update(seen)          # présence par scénario, pas fréquence brute
    n = max(len(scen), 1)
    over = [(w, k) for w, k in words.most_common(30) if k / n > thr["max_motif_share"]]
    worst = [f"« {w} » dans {k}/{n} scénarios ({k/n:.0%})" for w, k in over[:6]]
    return Axis("motifs", f"{len(over)} motif(s) au-dessus du seuil",
                f"aucun motif dans plus de {thr['max_motif_share']:.0%} des scénarios",
                not over, "images et entités récurrentes", worst)


def run(scen: list, thr: dict, emb_path: Path) -> list:
    return [
        axis_semantic(scen, thr, emb_path),
        axis_lexical(scen, thr),
        axis_situational(scen, thr),
        axis_verbal(scen, thr),
        axis_structural(scen, thr),
        axis_motifs(scen, thr),
    ]


DEFAULT_THRESHOLDS = {
    "max_pair_cosine": 0.90,
    "max_mean_cosine": 0.75,
    "max_pair_jaccard": 0.35,
    "min_unique_summaries": 0.95,
    "min_unique_labels": 0.90,
    "min_distinct_verbs_per_scenario": 12,
    "min_unique_signatures": 0.80,
    "max_motif_share": 0.50,
}


def render(axes: list, scen: list, source: str) -> str:
    L = [f"# Diversité des scénarios — {source}", ""]
    L.append("> Généré par `tools/check_scenario_diversity.py`. Répond à une seule "
             "question : **deux scénarios se ressemblent-ils ?** La conformité au "
             "contrat (forme, économie) est mesurée séparément par "
             "`validate_scenario_balance.py`.")
    L.append("")
    L.append(f"{len(scen)} scénario(s) analysé(s).")
    L.append("")
    L.append("| Axe | Mesuré | Cible | Verdict |")
    L.append("|---|---|---|---|")
    for a in axes:
        L.append(f"| {a.name} | {a.measure} | {a.target} | {'PASS' if a.ok else '**FAIL**'} |")
    L.append("")
    for a in axes:
        if a.ok and not a.worst:
            continue
        L.append(f"## {a.name}")
        L.append("")
        L.append(f"{a.detail}")
        L.append("")
        for w in a.worst:
            L.append(f"- {w}")
        L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", default=str(REPO / "data/ai/scenarios_reference_broceliande.json"))
    ap.add_argument("--embeddings",
                    default=str(REPO / "data/ai/scenarios_reference_broceliande.embeddings.json"))
    ap.add_argument("--templates", default=str(TPL))
    ap.add_argument("--report", default=None)
    args = ap.parse_args()

    data = json.load(open(args.file, encoding="utf-8"))
    scen = data if isinstance(data, list) else list(data.get("scenarios", {}).values())

    thr = dict(DEFAULT_THRESHOLDS)
    try:
        tpl = json.load(open(args.templates, encoding="utf-8"))
        thr.update((tpl.get("diversity_contract") or {}).get("thresholds", {}))
    except Exception:
        pass

    axes = run(scen, thr, Path(args.embeddings))
    for a in axes:
        print(f"[{'PASS' if a.ok else 'FAIL'}] {a.name:<14} {a.measure}   (cible : {a.target})")
        for w in a.worst[:3]:
            print(f"         {w}")
    failed = [a for a in axes if not a.ok]
    print(f"\n=== {len(axes) - len(failed)}/{len(axes)} axes conformes ===")

    if args.report:
        Path(args.report).write_text(render(axes, scen, Path(args.file).name), encoding="utf-8")
        print(f"Rapport ecrit : {args.report}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
