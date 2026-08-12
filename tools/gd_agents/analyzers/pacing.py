#!/usr/bin/env python3
"""Analyseur `pacing` — simule une run entière et mesure le rythme.

Le calcul est intégralement en Python : durée de session, courbe de vie, tour où
le joueur meurt de la seule usure. Le LLM ne fait que commenter ces chiffres.

Comme `balance`, il distingue deux natures de constat :
  · l'écart MÉCANIQUE (une fenêtre de session incohérente, une victoire
    inatteignable avant la mort) a une correction unique → `change()` rend le
    couple before/after que le codeur applique ;
  · le reste est un signal de game design, qui reste une décision.

Ne lève jamais.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import gdconst as GC  # noqa: E402

# Marge de survie visée : après la carte de victoire, le joueur doit garder au
# moins ce pourcentage de sa barre s'il ne subit AUCUN dégât. Sinon la seule
# usure suffit à tuer, et le jeu devient une course contre la montre.
MARGE_MIN = 0.25


def analyze(seed: int | None = None) -> dict:
    sc = GC.scalars()

    def v(name, default=None):
        return sc[name]["value"] if name in sc else default

    vie = v("LIFE_ESSENCE_START", 100)
    drain = v("LIFE_ESSENCE_DRAIN_PER_CARD", 1)
    victoire = v("MIN_CARDS_FOR_VICTORY", 25)
    lo, hi = v("SESSION_CARDS_MIN", 25), v("SESSION_CARDS_MAX", 35)
    cible = v("SESSION_CARDS_TARGET", 30)
    secs = v("SESSION_SECONDS_PER_CARD", 18)
    soin = v("LIFE_ESSENCE_HEAL_PER_REST", 18)
    degat_event = v("LIFE_ESSENCE_EVENT_FAIL_DAMAGE", 6)

    # Simulation sans aucun dégât : la borne haute absolue de survie.
    cartes_max = int(vie / drain) if drain else 9999
    vie_a_la_victoire = vie - victoire * drain
    marge = round(vie_a_la_victoire / vie, 2) if vie else 0

    # Durée d'une session, en minutes, aux trois bornes.
    duree = {n: round(n * secs / 60) for n in (lo, cible, hi) if isinstance(n, int)}

    # Combien d'échecs d'événement le joueur peut-il encaisser avant de mourir
    # sur une run de longueur cible ? C'est la vraie mesure de tolérance.
    reste = vie - cible * drain
    echecs_tolerables = int(reste / degat_event) if degat_event else 999

    ecarts = _code_findings(sc, vie, drain, victoire, lo, hi, cible, marge)
    return {
        "sujet": "rythme de session",
        "vie_depart": vie, "drain": drain,
        "cartes_max_sans_degat": cartes_max,
        "victoire_a": victoire, "vie_a_la_victoire": vie_a_la_victoire,
        "marge_survie": marge, "marge_visee": MARGE_MIN,
        "fenetre": [lo, hi], "cible": cible,
        "duree_min": duree,
        "soin_repos": soin, "degat_event": degat_event,
        "echecs_tolerables": echecs_tolerables,
        "code_ecarts": ecarts,
        "regles_verifiees": 3,
    }


def _code_findings(sc, vie, drain, victoire, lo, hi, cible, marge) -> list[dict]:
    """Les seuls constats à correction unique."""
    out = []

    def add(nom, attendu, pourquoi):
        e = sc.get(nom)
        if not e:
            return
        p = GC.patch_line(e, attendu)
        if p:
            out.append({"regle": nom, "cible": GC.CONSTANTS_TARGET,
                        "actuel": e["value"], "propose": attendu,
                        "ligne": e["lineno"], "pourquoi": pourquoi,
                        "before": p[0], "after": p[1]})

    # 1. La fenêtre de session doit être ordonnée : min ≤ cible ≤ max.
    if isinstance(lo, int) and isinstance(hi, int) and lo > hi:
        add("SESSION_CARDS_MAX", lo,
            f"la borne haute ({hi}) est sous la borne basse ({lo}) : "
            "aucune longueur de session n'est valide")
    elif isinstance(cible, int) and isinstance(lo, int) and isinstance(hi, int) \
            and not (lo <= cible <= hi):
        add("SESSION_CARDS_TARGET", min(max(cible, lo), hi),
            f"la cible ({cible}) sort de la fenêtre [{lo}, {hi}]")

    # 2. La victoire doit rester atteignable avec la seule usure.
    if drain and vie and isinstance(victoire, int):
        plafond = int(vie * (1 - MARGE_MIN) / drain)
        if victoire > plafond:
            add("MIN_CARDS_FOR_VICTORY", plafond,
                f"à {drain} PV d'usure par carte, atteindre {victoire} cartes ne laisse "
                f"que {vie - victoire * drain} PV : le joueur meurt d'usure avant de "
                f"gagner, même sans subir un seul dégât")
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
        {"source": "simulation d'une run (aucun dégât subi)",
         "metric": f"le joueur tient {a['cartes_max_sans_degat']} cartes sur la seule usure "
                   f"({a['drain']} PV/carte sur {a['vie_depart']} PV)"},
        {"source": "marge à la victoire",
         "metric": f"il reste {a['vie_a_la_victoire']} PV en atteignant la carte "
                   f"{a['victoire_a']}, soit {int(a['marge_survie'] * 100)} % de la barre "
                   f"(visé : au moins {int(a['marge_visee'] * 100)} %)"},
        {"source": "durée réelle d'une session",
         "metric": " · ".join(f"{n} cartes ≈ {m} min" for n, m in a["duree_min"].items()),
         "quote": f"{a['echecs_tolerables']} échec(s) d'événement tolérable(s) "
                  f"sur une session cible"},
        {"source": f"{GC.CONSTANTS_TARGET} ({a['regles_verifiees']} règles de rythme)",
         "metric": (f"{len(ec)} écart : {ec[0]['regle']} vaut {ec[0]['actuel']}, "
                    f"devrait valoir {ec[0]['propose']}" if ec
                    else "aucun écart mécanique — le rythme est cohérent")},
    ]


def brief(a: dict) -> str:
    ec = a.get("code_ecarts") or []
    return (
        f"Barre de vie au départ : {a['vie_depart']} · usure {a['drain']} PV par carte\n"
        f"Sans subir un seul dégât, le joueur tient {a['cartes_max_sans_degat']} cartes\n"
        f"Victoire à {a['victoire_a']} cartes → il resterait {a['vie_a_la_victoire']} PV "
        f"({int(a['marge_survie'] * 100)} % de la barre)\n"
        f"Fenêtre de session : {a['fenetre'][0]}-{a['fenetre'][1]} cartes, cible {a['cible']}\n"
        f"Durées : {json.dumps(a['duree_min'])} minutes\n"
        f"Échecs d'événement tolérables sur une session cible : {a['echecs_tolerables']}\n"
        + (f"ÉCART À CORRIGER : {ec[0]['pourquoi']}\n"
           "Explique cette correction en 3 phrases, sans rien proposer d'autre."
           if ec else
           "Aucun écart mécanique. Dis en 3 phrases si ce rythme te paraît tenable, "
           "chiffres à l'appui."))


if __name__ == "__main__":
    a = analyze()
    print(json.dumps(a, ensure_ascii=False, indent=1))
    print("\n" + brief(a))
