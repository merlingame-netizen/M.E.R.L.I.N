#!/usr/bin/env python3
"""Analyseur `content_gap` — choisit un trou de contenu documenté et le prépare.

Le canon (`data/ai/lore_canon.json`) liste lui-même ses lacunes dans `gaps`.
Cet analyseur n'invente rien : il choisit une lacune, rassemble le contexte
canonique nécessaire (biome, faction, PNJ, verbes autorisés du champ lexical
tiré), et rend des PREUVES chiffrées. Le LLM ne fera que rédiger la carte.

Sortie : dict d'évidences consommé par runner.py. Ne lève jamais.
"""
from __future__ import annotations

import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CANON = ROOT / "data" / "ai" / "lore_canon.json"
CORPUS = ROOT / "data" / "ai" / "training" / "auto_corpus.jsonl"
CURATED = ROOT / "data" / "ai" / "training" / "curated_corpus.jsonl"


def _canon() -> dict:
    try:
        return json.loads(CANON.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _existing_biome_counts() -> dict:
    """Combien de cartes déjà produites par biome — sert à viser le plus pauvre."""
    counts: dict[str, int] = {}
    for path in (CORPUS, CURATED):
        try:
            for line in path.read_text(encoding="utf-8").splitlines():
                if not line.strip():
                    continue
                rec = json.loads(line)
                card = rec.get("card", rec)
                b = str(card.get("biome") or "?")
                counts[b] = counts.get(b, 0) + 1
        except Exception:
            continue
    return counts


def analyze(seed: int | None = None) -> dict:
    """Rend les preuves + le brief. `seed` rend le choix reproductible en test."""
    rng = random.Random(seed)
    canon = _canon()
    gaps = canon.get("gaps") or []
    biomes = [b.get("name", "?") for b in canon.get("biomes", [])]
    factions = [f.get("name", "?") for f in canon.get("factions", [])]
    cons = canon.get("scenario_constraints", {})
    fields = cons.get("verbs_by_field", {})
    counts = _existing_biome_counts()

    # Cible : le biome nommé dans un gap, sinon le moins couvert par le corpus.
    gap = rng.choice(gaps) if gaps else ""
    target = next((b for b in biomes if b.split()[-1].lower() in gap.lower()), None)
    if not target and biomes:
        # Sans corpus, tous les compteurs valent 0 et min() rendrait toujours le
        # premier biome (Brocéliande, déjà le plus riche). On départage au hasard.
        lo = min(counts.get(b, 0) for b in biomes)
        target = rng.choice([b for b in biomes if counts.get(b, 0) == lo])

    field = rng.choice(list(fields)) if fields else "esprit"
    verbs = fields.get(field, [])[:8]
    faction = rng.choice(factions) if factions else "Les Druides de Bretagne"
    npcs = [n.get("name", "?") for n in canon.get("npcs", [])
            if target and target.lower() in json.dumps(n, ensure_ascii=False).lower()][:3]

    return {
        "gap": gap[:280],
        "biome": target or "Foret de Broceliande",
        "faction": faction,
        "lexical_field": field,
        "verbs": verbs,
        "npcs": npcs,
        "cards_for_biome": counts.get(target or "", 0),
        "cards_total": sum(counts.values()),
        "text_rule": cons.get("card_text", {}),
        "options_rule": cons.get("options_per_card", 3),
        "effect_caps": cons.get("effect_caps", {}),
        "forbidden": (cons.get("forbidden_words") or [])[:12],
    }


def evidence(a: dict) -> list[dict]:
    """Traduit l'analyse en preuves affichables dans la proposition."""
    return [
        {"source": "data/ai/lore_canon.json → gaps",
         "metric": f"lacune documentée sur « {a['biome']} »", "quote": a["gap"]},
        {"source": "auto_corpus.jsonl + curated_corpus.jsonl",
         "metric": f"{a['cards_for_biome']} carte(s) pour ce biome sur {a['cards_total']} au total"},
        {"source": "scenario_constraints.verbs_by_field",
         "metric": f"champ lexical tiré : {a['lexical_field']} ({len(a['verbs'])} verbes autorisés)"},
    ]


def brief(a: dict) -> str:
    """Le bloc de données envoyé au LLM. Court : le contexte est précieux."""
    npc = f"\nPNJ du biome : {', '.join(a['npcs'])}" if a["npcs"] else ""

    def _cap(k, v):                       # les caps sont des dicts {max, min}
        if isinstance(v, dict):
            lo, hi = v.get("min"), v.get("max", v.get("max_per_card"))
            return f"{k} entre {lo} et {hi}" if lo is not None else f"{k} ≤ {hi}"
        return f"{k} ≤ {v}"
    caps = ", ".join(_cap(k, v) for k, v in list(a["effect_caps"].items())[:4])
    return (
        f"Biome : {a['biome']}\n"
        f"Faction concernée : {a['faction']}\n"
        f"Champ lexical imposé : {a['lexical_field']}\n"
        f"Verbes AUTORISÉS (choisis-en 3, à l'infinitif) : {', '.join(a['verbs'])}{npc}\n"
        f"Lacune à combler : {a['gap']}\n"
        f"Contraintes : exactement {a['options_rule']} options ; texte de 2 à 4 phrases "
        f"françaises (40-120 mots) ; effets plafonnés ({caps}) ; "
        f"factions valides : druides, anciens, korrigans, niamh, ankou.\n"
        f"Mots interdits : {', '.join(a['forbidden'][:8])}."
    )


if __name__ == "__main__":
    a = analyze(seed=1)
    print(json.dumps(a, ensure_ascii=False, indent=1)[:900])
    print("\n--- brief ---\n" + brief(a))
