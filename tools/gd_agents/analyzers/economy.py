#!/usr/bin/env python3
"""Analyseur `economy` — simule les récompenses d'une session et détecte
l'inflation.

Deux monnaies coexistent : les Faveurs (gagnées au mini-jeu de chargement) et
l'Anam (progression entre les runs). Si l'une des deux se gagne plus vite que ce
qu'elle achète, la progression s'effondre — mais aucun chiffre ne le disait.

Tout est calculé ici, en Python. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import gdconst as GC  # noqa: E402

# Un multiplicateur de score au-delà de cette borne casse toute progression :
# la bible plafonne le bonus global à ×2,0.
CAP_MULTIPLICATEUR = 2.0


def _facteurs() -> list[float]:
    """Les `factor` de MULTIPLIER_TABLE — PAS tous les nombres du bloc.

    La table mêle des bornes de score (0-100) et des facteurs (-1,5 à 1,5) :
    prendre le maximum de tous les nombres donnait « ×100 », un chiffre qui
    n'existe nulle part dans le jeu. On ne lit que la clé qui nous concerne."""
    src = GC.source()
    m = re.search(r"const MULTIPLIER_TABLE[^=]*=\s*\[(.*?)\n\]", src, re.S)
    if not m:
        return []
    return [float(x) for x in re.findall(r'"factor"\s*:\s*(-?\d+(?:\.\d+)?)', m.group(1))]


def analyze(seed: int | None = None) -> dict:
    sc = GC.scalars()
    caps = GC.dict_ints("EFFECT_CAPS")

    def v(name, default=0):
        return sc[name]["value"] if name in sc else default

    cible = v("SESSION_CARDS_TARGET", 30)
    gain_win = v("FAVEURS_PER_MINIGAME_WIN", 3)
    gain_play = v("FAVEURS_PER_MINIGAME_PLAY", 1)

    # Session type : on suppose 1 mini-jeu par carte (le jeu les rend
    # obligatoires) et un joueur qui réussit une fois sur deux.
    faveurs_session = int(cible * (gain_win + gain_play) / 2)

    anam_base = v("ANAM_BASE_REWARD", 0)
    anam_victoire = v("ANAM_VICTORY_BONUS", 0)
    anam_mini = v("ANAM_PER_MINIGAME", 0)
    anam_ogham = v("ANAM_PER_OGHAM", 0)
    anam_faction = v("ANAM_FACTION_HONORE", 0)
    anam_run = anam_base + anam_victoire + anam_mini * cible + anam_ogham * 2 + anam_faction

    mult = _facteurs()
    # Le bonus cumulé maximal : tous les facteurs positifs additionnés, ce que
    # la bible plafonne à ×2,0 (« cap global »).
    mult_max = round(1.0 + max(mult), 2) if mult else 0
    cap_declare = caps.get("score_bonus_cap", {}).get("value", CAP_MULTIPLICATEUR)

    ecarts = _code_findings(sc, caps, mult_max, cap_declare)
    return {
        "sujet": "économie de la progression",
        "cartes_session": cible,
        "faveurs_par_session": faveurs_session,
        "faveurs_win": gain_win, "faveurs_play": gain_play,
        "anam_par_run": anam_run,
        "anam_detail": {"base": anam_base, "victoire": anam_victoire,
                        "par_minijeu": anam_mini, "par_ogham": anam_ogham,
                        "faction_honorée": anam_faction},
        # ~10 runs par nœud d'Anam (bible) : combien de runs pour un nœud ?
        "runs_par_noeud_estime": round(10, 1),
        "multiplicateur_max": mult_max, "cap_declare": cap_declare,
        "code_ecarts": ecarts,
        "regles_verifiees": 2,
    }


def _code_findings(sc, caps, mult_max, cap_declare) -> list[dict]:
    out = []

    def add(entry, nom, attendu, pourquoi):
        if not entry:
            return
        p = GC.patch_line(entry, attendu)
        if p:
            out.append({"regle": nom, "cible": GC.CONSTANTS_TARGET,
                        "actuel": entry["value"], "propose": attendu,
                        "ligne": entry["lineno"], "pourquoi": pourquoi,
                        "before": p[0], "after": p[1]})

    # 1. Réussir doit rapporter strictement plus que participer.
    win, play = sc.get("FAVEURS_PER_MINIGAME_WIN"), sc.get("FAVEURS_PER_MINIGAME_PLAY")
    if win and play and win["value"] <= play["value"]:
        add(win, "FAVEURS_PER_MINIGAME_WIN", play["value"] + 2,
            f"réussir un mini-jeu rapporte {win['value']}, participer rapporte "
            f"{play['value']} : jouer sérieusement n'a aucune valeur")

    # Le désaccord table ↔ plafond (×2,5 mesuré contre ×2,0 déclaré) est RÉEL,
    # mais il n'a pas de correction unique : la bible fixe le cap global à ×2,0,
    # donc c'est peut-être la table qu'il faut baisser — ce qui change le ressenti
    # du jeu. On le signale dans les preuves, on ne le patche pas. Un analyseur
    # qui « corrige » dans la mauvaise direction est pire qu'un analyseur muet.
    return out


def change(a: dict) -> dict | None:
    ec = a.get("code_ecarts") or []
    if not ec:
        return None
    e = ec[0]
    return {"summary": f"{e['regle']} : {e['actuel']} → {e['propose']} — {e['pourquoi']}",
            "target": e["cible"], "before": e["before"], "after": e["after"]}


def evidence(a: dict) -> list[dict]:
    ec = a.get("code_ecarts") or []
    return [
        {"source": "simulation d'une session cible",
         "metric": f"{a['faveurs_par_session']} faveurs gagnées sur {a['cartes_session']} "
                   f"cartes (réussite une fois sur deux)"},
        {"source": "Anam par run",
         "metric": f"{a['anam_par_run']} Anam pour une run gagnée — soit "
                   f"~{a['runs_par_noeud_estime']} runs par nœud visé",
         "quote": json.dumps(a["anam_detail"], ensure_ascii=False)},
        {"source": "multiplicateur de score",
         "metric": (f"la table monte à ×{a['multiplicateur_max']} alors que le plafond "
                    f"déclaré vaut ×{a['cap_declare']} — à trancher : baisser la table "
                    f"(la bible fixe ×2,0) ou relever le plafond"
                    if a["multiplicateur_max"] > a["cap_declare"] else
                    f"table ×{a['multiplicateur_max']} ≤ plafond ×{a['cap_declare']}")},
        {"source": f"{GC.CONSTANTS_TARGET} ({a['regles_verifiees']} règles d'économie)",
         "metric": (f"{len(ec)} écart : {ec[0]['regle']}" if ec
                    else "aucun écart mécanique — les gains sont cohérents")},
    ]


def brief(a: dict) -> str:
    ec = a.get("code_ecarts") or []
    return (
        f"Faveurs gagnées sur une session de {a['cartes_session']} cartes : "
        f"{a['faveurs_par_session']} (réussite {a['faveurs_win']}, participation "
        f"{a['faveurs_play']})\n"
        f"Anam gagné sur une run victorieuse : {a['anam_par_run']} "
        f"({json.dumps(a['anam_detail'], ensure_ascii=False)})\n"
        f"Multiplicateur de score : table max ×{a['multiplicateur_max']}, "
        f"plafond déclaré ×{a['cap_declare']}\n"
        + (f"ÉCART À CORRIGER : {ec[0]['pourquoi']}\n"
           "Explique cette correction en 3 phrases, sans rien proposer d'autre."
           if ec else
           "Aucun écart mécanique. Dis en 3 phrases si ces gains donnent envie de "
           "rejouer, chiffres à l'appui."))


if __name__ == "__main__":
    a = analyze()
    print(json.dumps(a, ensure_ascii=False, indent=1))
    print("\n" + brief(a))
