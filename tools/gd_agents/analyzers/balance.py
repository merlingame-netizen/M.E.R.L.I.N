#!/usr/bin/env python3
"""Analyseur `balance` — mesure l'équilibrage du corpus de cartes.

Tout est calculé en Python : distribution des effets, couverture des factions,
diversité des verbes, dépassements de plafonds. Le LLM ne fait que rédiger la
proposition à partir de ces chiffres. Ne lève jamais.
"""
from __future__ import annotations

import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CANON = ROOT / "data" / "ai" / "lore_canon.json"
SOURCES = [ROOT / "data" / "ai" / "training" / "auto_corpus.jsonl",
           ROOT / "data" / "ai" / "training" / "curated_corpus.jsonl"]
FASTROUTE = ROOT / "data" / "ai" / "fastroute_cards.json"


def _cards() -> list[dict]:
    out = []
    for p in SOURCES:
        try:
            for line in p.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    rec = json.loads(line)
                    out.append(rec.get("card", rec))
        except Exception:
            continue
    try:
        out += json.loads(FASTROUTE.read_text(encoding="utf-8")).get("narrative", [])
    except Exception:
        pass
    return out


def analyze(seed: int | None = None) -> dict:
    cards = _cards()
    factions = collections.Counter()
    verbs = collections.Counter()
    amounts, types = [], collections.Counter()
    over = []
    for c in cards:
        for o in c.get("options", []) or []:
            if o.get("verb"):
                verbs[o["verb"]] += 1
            for e in o.get("effects", []) or []:
                t = e.get("type", "?")
                types[t] += 1
                if e.get("faction"):
                    factions[e["faction"]] += 1
                a = e.get("amount")
                if isinstance(a, (int, float)):
                    amounts.append(a)
                    if t == "ADD_REPUTATION" and abs(a) > 20:
                        over.append(f"{t} {a} (plafond ±20)")
                    if t == "DAMAGE_LIFE" and a > 15:
                        over.append(f"{t} {a} (plafond 15)")
    cov = {f: factions.get(f, 0) for f in
           ("druides", "anciens", "korrigans", "niamh", "ankou")}
    total_eff = sum(cov.values()) or 1
    faible = min(cov, key=cov.get)
    forte = max(cov, key=cov.get)
    ratio = round(cov[forte] / max(cov[faible], 1), 1)
    return {
        "cards": len(cards),
        "faction_counts": cov,
        "faction_faible": faible, "faction_forte": forte, "ratio": ratio,
        "part_faible": round(100 * cov[faible] / total_eff, 1),
        "verbes_distincts": len(verbs),
        "verbe_dominant": verbs.most_common(1)[0] if verbs else ("—", 0),
        "effets": dict(types.most_common(5)),
        "moyenne_amount": round(sum(amounts) / len(amounts), 1) if amounts else 0,
        "depassements": over[:4],
    }


def evidence(a: dict) -> list[dict]:
    return [
        {"source": "corpus + fastroute_cards.json",
         "metric": f"{a['cards']} cartes analysées, {a['verbes_distincts']} verbes distincts"},
        {"source": "distribution des factions",
         "metric": f"« {a['faction_faible']} » ne pèse que {a['part_faible']} % des effets "
                   f"(rapport {a['ratio']}:1 avec « {a['faction_forte']} »)",
         "quote": json.dumps(a["faction_counts"], ensure_ascii=False)},
        {"source": "plafonds d'équilibrage",
         "metric": (f"{len(a['depassements'])} dépassement(s)" if a["depassements"]
                    else "aucun dépassement de plafond"),
         "quote": " · ".join(a["depassements"])},
    ]


def brief(a: dict) -> str:
    v, n = a["verbe_dominant"]
    return (
        f"Cartes analysées : {a['cards']}\n"
        f"Répartition des effets par faction : {json.dumps(a['faction_counts'], ensure_ascii=False)}\n"
        f"Faction la moins servie : {a['faction_faible']} ({a['part_faible']} % des effets)\n"
        f"Faction la plus servie : {a['faction_forte']} (rapport {a['ratio']}:1)\n"
        f"Verbe le plus employé : {v} ({n} fois) sur {a['verbes_distincts']} verbes distincts\n"
        f"Types d'effets : {json.dumps(a['effets'], ensure_ascii=False)}\n"
        f"Dépassements de plafond : {' · '.join(a['depassements']) or 'aucun'}\n"
        "Rédige UNE recommandation d'équilibrage concrète et chiffrée.")


if __name__ == "__main__":
    a = analyze()
    print(json.dumps(a, ensure_ascii=False, indent=1))
    print("\n" + brief(a))
