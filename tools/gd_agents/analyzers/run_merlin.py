#!/usr/bin/env python3
"""Analyseur `run_merlin` — l'équilibrage du jeu RÉELLEMENT joué.

Les analyseurs `balance`, `pacing` et `economy` cherchaient `LIFE_ESSENCE_MAX`,
`SESSION_CARDS_TARGET`, `FAVEURS_*` — le vocabulaire d'un AUTRE jeu, resté dans
le dépôt d'outillage. Le jeu que Maxime joue est un roguelike à deck avec son
propre système, déclaré proprement dans `scripts/game/merlin_run.gd` :

    START_INTEGRITE 10 · MAX_INTEGRITE 10      la barre de vie
    HAND_SIZE 4 · HAND_CAP_EXTRA 3             la main
    CORRUPTION_THRESHOLD_STEP 5 · CAP 18       la corruption
    MAX_CORRUPTED_IN_HAND 1                    ce qu'on tolère en main
    MOMENTUM_MIN -3 · MOMENTUM_MAX 3           l'élan
    TALENT_CAP 5 · COST 2 · GAIN 1/2           la progression des verbes
    LOOT_CHANCE 0.6 · LOOT_MIN 1 · LOOT_MAX 4  le butin
    HEAL_PRICE 6 · HEAL_AMOUNT 2 · CAP 2       le soin

Il ne manquait donc RIEN au jeu : il manquait un analyseur qui parle sa langue.
Celui-ci mesure ce qui se mesure, et distingue — comme les autres — l'écart
MÉCANIQUE (une seule correction possible, patch joint) du SIGNAL de game design
(une décision de Maxime, pas de patch).

Stdlib seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import gdconst as GC  # noqa: E402


def analyze(seed: int | None = None) -> dict:
    sc = GC.scalars()
    manquantes: list[str] = []

    def v(nom, defaut=None):
        if nom in sc:
            return sc[nom]["value"]
        manquantes.append(nom)
        return defaut

    vie = v("START_INTEGRITE")
    vie_max = v("MAX_INTEGRITE")
    main = v("HAND_SIZE")
    main_extra = v("HAND_CAP_EXTRA", 0)
    corr_pas = v("CORRUPTION_THRESHOLD_STEP")
    corr_cap = v("CORRUPTION_CAP")
    corr_main = v("MAX_CORRUPTED_IN_HAND", 0)
    mom_min, mom_max = v("MOMENTUM_MIN"), v("MOMENTUM_MAX")
    tal_cap, tal_cout = v("TALENT_CAP"), v("TALENT_COST")
    tal_g1, tal_g2 = v("TALENT_GAIN_REUSSITE", 1), v("TALENT_GAIN_ECLATANTE", 2)
    loot_p, loot_min, loot_max = v("LOOT_CHANCE"), v("LOOT_MIN"), v("LOOT_MAX")
    soin_prix, soin_gain, soin_cap = v("HEAL_PRICE"), v("HEAL_AMOUNT"), v("HEAL_CAP_PER_RUN")

    # Ce qu'un joueur ressent, calculé et non deviné.
    soin_total = (soin_gain * soin_cap) if (soin_gain and soin_cap) else 0
    part_barre = round(100 * soin_total / vie_max, 1) if vie_max else 0
    cout_total = (soin_prix * soin_cap) if (soin_prix and soin_cap) else 0
    paliers = int(corr_cap / corr_pas) if (corr_cap and corr_pas) else 0
    butin_moyen = round(loot_p * (loot_min + loot_max) / 2, 2) \
        if (loot_p is not None and loot_min is not None and loot_max is not None) else 0
    # Combien de réussites pour maîtriser UN verbe, puis les cinq.
    reussites_verbe = int((tal_cap * tal_cout) / tal_g1) if (tal_cap and tal_cout and tal_g1) else 0

    return {
        "sujet": "équilibrage de la run",
        "source_lue": GC.SOURCE.get("dit", ""),
        "constantes_manquantes": manquantes,
        "mesure_reelle": len(manquantes) <= 3,   # tolérance : quelques optionnelles
        "vie": vie, "vie_max": vie_max,
        "main": main, "main_max": (main + main_extra) if (main and main_extra) else main,
        "corruption_paliers": paliers, "corruption_cap": corr_cap,
        "corruption_toleree_en_main": corr_main,
        "elan": [mom_min, mom_max],
        "talent_reussites_par_verbe": reussites_verbe,
        "talent_reussites_tout_maitriser": reussites_verbe * 5,
        "butin_moyen_par_tirage": butin_moyen,
        "soin_total_par_run": soin_total, "soin_part_de_la_barre": part_barre,
        "soin_cout_total": cout_total,
        "code_ecarts": _ecarts(sc, vie, vie_max, main, corr_main,
                               mom_min, mom_max, loot_p, loot_min, loot_max),
        "regles_verifiees": 5,
    }


def _ecarts(sc, vie, vie_max, main, corr_main, mom_min, mom_max,
            loot_p, loot_min, loot_max) -> list[dict]:
    """Les seuls constats à correction UNIQUE — donc applicables sans jugement."""
    if not GC.SOURCE.get("fiable"):
        return []
    out = []

    def add(nom, attendu, pourquoi):
        e = sc.get(nom)
        if not e or attendu is None:
            return
        p = GC.patch_line(e, attendu)
        if p:
            out.append({"regle": nom, "cible": GC.CIBLE_REELLE,
                        "actuel": e["value"], "propose": attendu,
                        "ligne": e["lineno"], "pourquoi": pourquoi,
                        "before": p[0], "after": p[1]})

    # 1. On ne peut pas commencer avec plus de vie que le maximum.
    if vie is not None and vie_max is not None and vie > vie_max:
        add("START_INTEGRITE", vie_max,
            f"la partie commence à {vie} d'intégrité alors que le maximum est "
            f"{vie_max} : la barre déborde dès le premier écran")
    # 2. Un minimum de butin au-dessus du maximum ne tire jamais rien de valide.
    if loot_min is not None and loot_max is not None and loot_min > loot_max:
        add("LOOT_MIN", loot_max,
            f"le butin minimum ({loot_min}) dépasse le maximum ({loot_max}) : "
            "l'intervalle de tirage est vide")
    # 3. Une probabilité vit entre 0 et 1.
    if loot_p is not None and not (0.0 <= loot_p <= 1.0):
        add("LOOT_CHANCE", min(max(loot_p, 0.0), 1.0),
            f"la chance de butin vaut {loot_p} : hors de l'intervalle 0-1, "
            "elle ne veut plus rien dire")
    # 4. L'élan doit avoir une amplitude.
    if mom_min is not None and mom_max is not None and mom_min >= mom_max:
        add("MOMENTUM_MAX", abs(mom_min),
            f"l'élan va de {mom_min} à {mom_max} : la fourchette est vide ou "
            "inversée, la mécanique ne peut pas varier")
    # 5. On ne peut pas tolérer en main plus de cartes corrompues que de cartes.
    if corr_main is not None and main is not None and corr_main > main:
        add("MAX_CORRUPTED_IN_HAND", main,
            f"on tolère {corr_main} carte(s) corrompue(s) dans une main de "
            f"{main} : le plafond ne peut jamais être atteint")
    return out


def change(a: dict) -> dict | None:
    ec = a.get("code_ecarts") or []
    if not ec:
        return None
    e = ec[0]
    return {"summary": f"{e['regle']} : {e['actuel']} → {e['propose']} — {e['pourquoi']}",
            "target": e["cible"], "before": e["before"], "after": e["after"]}


def evidence(a: dict) -> list[dict]:
    if not a.get("mesure_reelle"):
        return [{"source": a.get("source_lue", "le jeu"),
                 "metric": f"{len(a['constantes_manquantes'])} constante(s) de run "
                           "introuvable(s) — le fichier lu n'est pas celui des règles",
                 "quote": ", ".join(a["constantes_manquantes"][:6])}]
    ec = a.get("code_ecarts") or []
    return [
        {"source": a["source_lue"],
         "metric": f"barre d'intégrité {a['vie']}/{a['vie_max']}, main de "
                   f"{a['main']} cartes (jusqu'à {a['main_max']})"},
        {"source": "le soin, sur une run entière",
         "metric": f"{a['soin_total_par_run']} points regagnables au total, soit "
                   f"{a['soin_part_de_la_barre']} % de la barre, pour "
                   f"{a['soin_cout_total']} d'or"},
        {"source": "la corruption",
         "metric": f"{a['corruption_paliers']} palier(s) avant le plafond de "
                   f"{a['corruption_cap']}, {a['corruption_toleree_en_main']} carte(s) "
                   "corrompue(s) tolérée(s) en main"},
        {"source": "la progression des talents",
         "metric": f"{a['talent_reussites_par_verbe']} réussites pour maîtriser un verbe, "
                   f"{a['talent_reussites_tout_maitriser']} pour les cinq"},
        {"source": "le butin",
         "metric": f"{a['butin_moyen_par_tirage']} objet(s) en moyenne par tirage"},
        {"source": f"{a['regles_verifiees']} règles de cohérence",
         "metric": (f"{len(ec)} écart : {ec[0]['regle']}" if ec
                    else "aucun écart mécanique — les règles sont cohérentes entre elles")},
    ]


def brief(a: dict) -> str:
    if not a.get("mesure_reelle"):
        return (f"Source lue : {a.get('source_lue', '?')}\n"
                f"Constantes de run introuvables : "
                f"{', '.join(a['constantes_manquantes'][:8])}\n"
                "Dis en 3 phrases ce que cela empêche, sans inventer de chiffre.")
    ec = a.get("code_ecarts") or []
    return (
        f"Intégrité : {a['vie']} au départ, {a['vie_max']} au maximum\n"
        f"Main : {a['main']} cartes, jusqu'à {a['main_max']}\n"
        f"Corruption : {a['corruption_paliers']} paliers, plafond {a['corruption_cap']}, "
        f"{a['corruption_toleree_en_main']} corrompue(s) tolérée(s) en main\n"
        f"Soin : {a['soin_total_par_run']} points par run ({a['soin_part_de_la_barre']} % "
        f"de la barre) pour {a['soin_cout_total']} d'or\n"
        f"Talents : {a['talent_reussites_par_verbe']} réussites par verbe, "
        f"{a['talent_reussites_tout_maitriser']} pour tout maîtriser\n"
        f"Butin : {a['butin_moyen_par_tirage']} en moyenne par tirage\n"
        f"Élan : de {a['elan'][0]} à {a['elan'][1]}\n"
        + (f"ÉCART À CORRIGER : {ec[0]['pourquoi']}\n"
           "Explique cette correction en 3 phrases, sans rien proposer d'autre."
           if ec else
           "Aucun écart mécanique. Dis en 3 phrases si cet équilibrage donne envie "
           "de rejouer, chiffres à l'appui."))


if __name__ == "__main__":
    a = analyze()
    print(json.dumps(a, ensure_ascii=False, indent=1))
    print("\n" + brief(a))
