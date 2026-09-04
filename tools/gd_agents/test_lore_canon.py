"""Épreuve du canon dérivé : il dit le jeu d'aujourd'hui, et ses quatre lecteurs le digèrent.

    python3 tools/gd_agents/test_lore_canon.py

POURQUOI ELLE EXISTE. Le canon précédent a dérivé pendant deux mois et demi sans que rien ne le
signale : il nommait des dieux que le jeu interdit, des biomes qui n'existent pas, et des cartes
à trois options d'un système mort. Personne ne relit un fichier de 35 Ko. Cette épreuve le relit
à chaque passage, et elle refuse ce qui a fait le défaut d'avant.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RACINE))
sys.path.insert(0, str(RACINE / "tools"))
sys.path.insert(0, str(RACINE / "tools" / "gd_agents"))
sys.path.insert(0, str(RACINE / "tools" / "lora"))
sys.path.insert(0, str(RACINE / "tools" / "cockpit"))

RATES = 0


def verifier(nom: str, cond: bool, detail: str = "") -> None:
    global RATES
    if cond:
        print("  ok    %s" % nom)
    else:
        RATES += 1
        print("  RATE  %s%s" % (nom, ("  — " + detail) if detail else ""))


def main() -> int:
    print("=== ÉPREUVE DU CANON DÉRIVÉ ===\n")
    canon = json.loads((RACINE / "data" / "ai" / "lore_canon.json").read_text(encoding="utf-8"))

    # ── LE MONDE EST CELUI DU JEU
    biomes = [b.get("name", "") for b in canon.get("biomes", [])]
    figures = [n.get("name", "") for n in canon.get("npcs", [])]
    verifier("douze biomes", len(biomes) == 12, "%d : %s" % (len(biomes), biomes[:4]))
    verifier("les biomes portent leurs noms bretons",
             "Ar C'hoad Kozh" in biomes and "Kerlan" in biomes, str(biomes[:6]))
    verifier("les figures du canon sont là",
             all(f in figures for f in ("Le Chœur des Druides", "La Lavandière de Nuit",
                                        "Fañch le Trotteur", "Ordalc'h")), str(figures[:6]))

    # LE DÉFAUT D'AVANT, REFUSÉ NOMMÉMENT. Le canon écrit à la main nommait Niamh, Manannan et
    # Brigid comme PNJ ; le jeu les INTERDIT dans le même souffle. Un canon qui se contredit
    # nourrissait un modèle qui écrivait ce que le jeu refuse.
    interdits = canon["scenario_constraints"]["forbidden_words"]
    verifier("aucune figure n'est un dieu interdit",
             not [f for f in figures if any(d.lower() in f.lower() for d in interdits)],
             str([f for f in figures if any(d.lower() in f.lower() for d in interdits)]))
    for mort in ("Maelgwn", "Keridwen", "Niamh", "Manannan", "Brigid", "Talwen"):
        verifier("« %s » n'est plus une figure" % mort, mort not in figures)

    # ── LES RÈGLES SONT CELLES DE R166
    cons = canon["scenario_constraints"]
    verbes = sorted({v for vs in cons["verbs_by_field"].values() for v in vs})
    verifier("les cinq tuiles, et rien d'autre",
             verbes == ["AGIR", "COMBATTRE", "OBSERVER", "PARLER", "RÉVÉLER"], str(verbes))
    verifier("les seize traits de départ sont là", len(cons["traits_de_depart"]) == 16,
             "%d" % len(cons["traits_de_depart"]))
    verifier("les mots interdits sont une LISTE, pas une prose découpée",
             isinstance(interdits, list) and all(len(w) > 2 for w in interdits), str(interdits))
    verifier("la prose des interdits est gardée entière",
             "magie a incantation" in cons.get("forbidden_prose", ""),
             cons.get("forbidden_prose", "")[:60])
    verifier("le canon dit que l'unité de contenu est le beat",
             "beat" in cons.get("unite_de_contenu", ""), cons.get("unite_de_contenu", ""))

    # ── LES LACUNES SONT CELLES D'AUJOURD'HUI
    gaps = canon.get("gaps", [])
    verifier("des lacunes sont listées", len(gaps) >= 5, "%d" % len(gaps))
    verifier("aucune lacune ne parle d'un système mort",
             not [g for g in gaps if "Ogham" in g or "Rune-Circuit" in g],
             str([g[:50] for g in gaps if "Ogham" in g or "Rune-Circuit" in g]))
    verifier("un artefact dérivé ne diverge pas de sa source",
             canon.get("divergences") == [], str(canon.get("divergences"))[:60])

    # ── LES QUATRE LECTEURS
    from analyzers import content_gap
    a = content_gap.analyze(seed=1)
    b = content_gap.brief(a)
    verifier("content_gap : le biome vient du jeu", a["biome"] in biomes, a["biome"])
    verifier("content_gap : la faction vient du jeu",
             a["faction"] in [f["name"] for f in canon["factions"]], a["faction"])
    verifier("content_gap : trois options demandées, pas zéro", "exactement 3 options" in b,
             [l for l in b.splitlines() if "options" in l][:1])
    verifier("content_gap : les factions du brief sont réelles",
             "niamh" not in b and "chevalerie" in b,
             [l for l in b.splitlines() if "factions valides" in l][:1])
    verifier("content_gap : les mots interdits sont des mots", "Lugh, Cernunnos" in b,
             [l for l in b.splitlines() if "Mots interdits" in l][:1])
    verifier("content_gap : cinq verbes proposés pour en choisir trois",
             len(a["verbs"]) == 5, str(a["verbs"]))

    from merlin_studio import probes
    c = probes.canon()
    verifier("le Studio lit le canon", c.get("available") and c["counts"]["biomes"] == 12,
             str(c.get("counts")))

    import scenario_validator as sv
    sv._load_canon_overrides()
    verifier("le validateur n'autorise que les cinq tuiles",
             sv.ALL_VERBS == {"observer", "agir", "combattre", "parler", "reveler"},
             str(sorted(sv.ALL_VERBS)))
    verifier("le validateur bannit les dieux interdits",
             "lugh" in sv.BANNED_HARD, str(sv.BANNED_HARD[:5]))

    import control_loops
    verifier("le cockpit lit le canon",
             len(control_loops._load_json(control_loops.CANON, {})) > 5)

    # ── LA DÉRIVE SE VOIT LE JOUR MÊME
    import refaire_lore_canon as R
    jeu = Path("/home/user/merlin-jeu")
    if (jeu / "data" / "biomes").is_dir():
        verifier("le canon est conforme au jeu (mode --verifier)",
                 R.main(["--verifier", "--jeu", str(jeu)]) == 0)
    else:
        print("  (dépôt du jeu absent : conformité non essayée)")

    print("\n%s (%d échec%s)" % ("ÉPREUVE PASSÉE" if RATES == 0 else "ÉPREUVE ÉCHOUÉE",
                                   RATES, "s" if RATES > 1 else ""))
    return 1 if RATES else 0


if __name__ == "__main__":
    sys.exit(main())
