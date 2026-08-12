#!/usr/bin/env python3
"""Analyseur `audit` — écarts entre la bible et le code réel.

La bible (`docs/GAME_DESIGN_BIBLE.md`) déclare des systèmes SUPPRIMÉS. Le code,
lui, continue parfois de les porter : constantes, champs de sauvegarde, branches
mortes. Personne ne le mesurait — l'écart grandissait en silence.

C'est un compte de greps, pas un raisonnement : il tourne sur le plus petit
palier de modèle (le LLM ne fait que rédiger le constat). Aucune correction
n'est proposée automatiquement — retirer un système mort touche à l'architecture,
c'est une décision de Maxime. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import gdconst as GC  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]

# Systèmes déclarés SUPPRIMÉS dans la bible (§ « Systemes SUPPRIMES ») et le
# motif qui trahit leur survie dans le code. Liste explicite : on ne devine pas.
MORTS = {
    "Triade": r"\btriade\b",
    "Souffle": r"\bsouffle\b",
    "4 Jauges": r"\bjauges?\b",
    "Bestiole": r"\bbestiole\b",
    "Awen": r"\bawen\b",
    "D20": r"\bd20\b",
    "Flux": r"\bflux\b",
    "Decay de réputation": r"\b(decay|reputation_decay)\b",
}


def _sources() -> list[Path]:
    """Le code du jeu, là où il se trouve vraiment (clone du jeu si présent)."""
    base = GC.CONSTANTS.parents[2] if GC.CONSTANTS.exists() else ROOT
    out = []
    for sub in ("scripts", "addons/merlin_ai"):
        d = base / sub
        if d.exists():
            out += sorted(d.rglob("*.gd"))
    return out


def analyze(seed: int | None = None) -> dict:
    fichiers = _sources()
    textes = {}
    for p in fichiers:
        try:
            textes[p] = p.read_text(encoding="utf-8", errors="replace").lower()
        except Exception:
            continue

    survivants = []
    for nom, motif in MORTS.items():
        rx = re.compile(motif, re.I)
        touches, total = [], 0
        for p, t in textes.items():
            n = len(rx.findall(t))
            if n:
                total += n
                touches.append((str(p.relative_to(p.parents[len(p.parents) - 1])
                                    if False else p.name), n))
        if total:
            touches.sort(key=lambda x: -x[1])
            survivants.append({"systeme": nom, "occurrences": total,
                               "fichiers": len(touches),
                               "principaux": touches[:3]})
    survivants.sort(key=lambda s: -s["occurrences"])

    # Deux registres de paliers de modèle coexistent (JSON d'outillage et
    # GDScript du jeu) : divergence = le jeu et les agents ne parlent pas du
    # même modèle. Doublon connu, qu'on mesure au lieu de le subir.
    tiers_json, tiers_gd = _tiers()

    return {
        "sujet": "cohérence bible ↔ code",
        "fichiers_analyses": len(textes),
        "systemes_morts_declares": len(MORTS),
        "survivants": survivants[:6],
        "survivants_n": len(survivants),
        "occurrences_totales": sum(s["occurrences"] for s in survivants),
        "tiers_json": tiers_json, "tiers_gd": tiers_gd,
        "tiers_divergent": bool(tiers_json and tiers_gd
                                and set(tiers_json) != set(tiers_gd)),
        # L'audit ne patche jamais : retirer un système mort est structurel.
        "code_ecarts": [],
        "regles_verifiees": len(MORTS) + 1,
    }


def _tiers() -> tuple[list[str], list[str]]:
    js, gd = [], []
    try:
        d = json.loads((ROOT / "data/ai/config/model_tiers.json").read_text(encoding="utf-8"))
        js = [t.get("tag") for t in d.get("tiers", []) if t.get("tag")]
    except Exception:
        pass
    try:
        base = GC.CONSTANTS.parents[2] if GC.CONSTANTS.exists() else ROOT
        src = (base / "addons/merlin_ai/brain_swarm_config.gd").read_text(encoding="utf-8")
        gd = sorted(set(re.findall(r'"(gemma[0-9][^"]*)"', src)))
    except Exception:
        pass
    return js, gd


def change(a: dict) -> None:
    """Aucun patch automatique : voir le docstring du module."""
    return None


def evidence(a: dict) -> list[dict]:
    s = a["survivants"]
    return [
        {"source": f"{a['fichiers_analyses']} fichiers GDScript du jeu",
         "metric": f"{a['systemes_morts_declares']} systèmes déclarés supprimés par la bible "
                   f"sont recherchés dans le code"},
        {"source": "systèmes supprimés encore présents",
         "metric": (f"{a['survivants_n']} système(s) survivent, "
                    f"{a['occurrences_totales']} occurrence(s) au total" if s
                    else "aucun système supprimé ne subsiste dans le code"),
         "quote": " · ".join(f"{x['systeme']} ({x['occurrences']}× dans "
                             f"{x['fichiers']} fichiers)" for x in s[:4])},
        {"source": "registres de paliers de modèle",
         "metric": ("les deux registres divergent : le jeu et les agents ne visent "
                    "pas les mêmes modèles" if a["tiers_divergent"]
                    else "les deux registres de modèles concordent"),
         "quote": f"outillage {a['tiers_json']} · jeu {a['tiers_gd']}"},
    ]


def brief(a: dict) -> str:
    lignes = "\n".join(
        f"  - {x['systeme']} : {x['occurrences']} occurrences dans {x['fichiers']} fichiers "
        f"(surtout {', '.join(n for n, _ in x['principaux'])})"
        for x in a["survivants"]) or "  (aucun)"
    return (
        f"Fichiers de code analysés : {a['fichiers_analyses']}\n"
        f"Systèmes déclarés SUPPRIMÉS par la bible mais encore présents dans le code :\n"
        f"{lignes}\n"
        f"Registres de modèles : outillage {a['tiers_json']} · jeu {a['tiers_gd']}"
        f" ({'divergents' if a['tiers_divergent'] else 'concordants'})\n"
        "Dis en 3 phrases lequel de ces vestiges coûte le plus cher à garder, et "
        "pourquoi. Ne propose pas de plan de suppression : nomme la priorité.")


if __name__ == "__main__":
    a = analyze()
    print(json.dumps(a, ensure_ascii=False, indent=1))
    print("\n" + brief(a))
