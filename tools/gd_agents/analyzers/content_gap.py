#!/usr/bin/env python3
"""Analyseur `content_gap` — choisit un trou de contenu documenté et le prépare.

Le canon (`data/ai/lore_canon.json`) liste lui-même ses lacunes dans `gaps`.
Cet analyseur n'invente rien : il choisit une lacune, rassemble le contexte
canonique nécessaire (biome, faction, PNJ, verbes autorisés), et rend des PREUVES
chiffrées. Le LLM ne fera que rédiger la carte.

DEUX SOURCES, ET C'EST VOULU (04/09). Le canon dit ce que le MONDE est — biomes, figures,
factions, interdits — et il est désormais dérivé du jeu, donc juste. Le FORMAT produit, lui,
est porté ici : une carte à trois options avec des effets plafonnés. Ce format a été abandonné
par le jeu au pivot v11, mais c'est le seul que `scenario_validator.validate_card` sache juger,
et une proposition non validée est refusée. Les constantes du format vivent donc dans cet
analyseur, avec leur date de péremption écrite noir sur blanc, plutôt que dans un canon qui
mentirait sur le jeu pour arranger un outil.

CE QUI RESTE FAUX, ET QU'AUCUN RÉGLAGE NE CORRIGE : le jeu écrit des BEATS (scène, geste, issue)
et cet atelier écrit des CARTES. Le corpus qu'il alimente entraîne donc le futur modèle sur une
unité de contenu que la production n'emploie plus. Le rendre utile demande de retarger la chaîne
entière — analyseur, prompt, validateur — sur le beat, ce qui est un chantier et pas un réglage.

Sortie : dict d'évidences consommé par runner.py. Ne lève jamais.
"""
from __future__ import annotations

import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CANON = ROOT / "data" / "ai" / "lore_canon.json"

# LE FORMAT DE CARTE, ET SA DATE DE PÉREMPTION. Ces valeurs décrivaient le jeu d'avant le pivot
# v11 ; elles restent parce que `scenario_validator.validate_card` ne sait juger que cette forme.
# Elles ne viennent plus du canon : celui-ci, dérivé du jeu depuis le 04/09, dit franchement que
# l'unité de contenu est le beat et que la carte à options n'existe plus.
FORMAT_CARTE = {
    "options": 3,
    "texte": {"phrases": [2, 4], "mots": [40, 120]},
    "caps": {"ADD_REPUTATION": {"max": 20, "min": -20}, "HEAL_LIFE": {"max": 18},
             "DAMAGE_LIFE": {"max": 15}, "ADD_BIOME_CURRENCY": {"max": 10},
             "effects_per_option": 3},
}
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

    # LES CINQ TUILES, TOUTES. `verbs_by_field` groupe désormais les tuiles par famille, et une
    # famille n'en compte souvent qu'une : tirer une famille puis en demander trois verbes
    # produisait « choisis-en 3 parmi : OBSERVER ». On donne les cinq, et la famille tirée n'est
    # plus qu'une couleur d'ambiance.
    field = rng.choice(list(fields)) if fields else "Perception"
    verbs = sorted({v for vs in fields.values() for v in vs}) or ["OBSERVER"]
    faction = rng.choice(factions) if factions else "druides"
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
        "text_rule": FORMAT_CARTE["texte"],
        "options_rule": FORMAT_CARTE["options"],
        "effect_caps": FORMAT_CARTE["caps"],
        "forbidden": (cons.get("forbidden_words") or [])[:12],
        # La prose des interdits dit ce qu'aucune liste de mots ne peut dire : le merveilleux
        # doit être concret, pas de magie qui brille, pas de prophétie. C'est elle qui tient.
        "forbidden_prose": str(cons.get("forbidden_prose", ""))[:400],
        "factions_valides": factions,
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
        # 60-100 et non 40-120 : mesuré sur 19 cartes d'affilée, le modèle vise la
        # borne basse annoncée et retombe ~15 % dessous — 34 à 38 mots pour une
        # consigne de 40. En demandant 60, il écrit 50-60 : dans la cible. La
        # borne du validateur (40-120) ne bouge pas ; c'est la CONSIGNE qui était
        # calibrée sur le résultat espéré au lieu du comportement observé.
        f"Contraintes : exactement {a['options_rule']} options ; texte de 2 à 4 phrases "
        f"françaises (60 à 100 mots — vise 80, un texte trop court est refusé) ; "
        f"effets plafonnés ({caps}) ; "
        # Les factions viennent du canon depuis le 04/09. Elles étaient écrites en dur et
        # nommaient « niamh » et « anciens », qui n'existent dans aucune donnée du jeu.
        f"factions valides : {', '.join(a['factions_valides'])}.\n"
        f"Mots interdits : {', '.join(a['forbidden'][:8])}.\n"
        f"Interdit aussi, et ça compte plus que la liste : {a['forbidden_prose']}"
    )


if __name__ == "__main__":
    a = analyze(seed=1)
    print(json.dumps(a, ensure_ascii=False, indent=1)[:900])
    print("\n--- brief ---\n" + brief(a))
