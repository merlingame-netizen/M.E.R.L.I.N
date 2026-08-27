#!/usr/bin/env python3
"""Regenere data/ai/canon_code.json DEPUIS LE CODE DU JEU.

    python3 tools/gd_agents/extraire_canon.py [--jeu /chemin/vers/merlin-game] [--verifier]

POURQUOI CE SCRIPT EXISTE. `lore_canon.json` etait une consolidation ecrite a la main le
2026-06-19, a partir de `docs/50_lore` et d'une Bible v3.8. Deux mois plus tard il decrivait un
AUTRE JEU : cinq factions avec leurs dieux (Lugh, Cernunnos, Brigid, Manannan), huit champs
lexicaux, une Bestiole, dix-huit Oghams. Or le canon que le jeu applique REELLEMENT — la
constante `LORE_CANON` de merlin_prompt_builder.gd, reecrite en v48 — INTERDIT nommement ces
dieux, et la resolution a bascule sur R166 (5 verbes x 16 traits, tags, 2d6 contre DC).

Les agents nourris par lore_canon.json produisaient donc du contenu que le jeu refuse. C'est
pourquoi `gd-content-gap` et `corpus-night` ont ete coupes. Les rallumer suppose que le canon
cesse d'etre une copie manuelle qui derive, et devienne un ARTEFACT DERIVE, regenerable.

ON N'ECRASE PAS lore_canon.json. Quatre consommateurs vivants lisent encore ses cles `biomes`,
`factions`, `npcs` et `scenario_constraints` (content_gap.py, balance.py, probes.py,
control_loops.py) : les remplacer d'un coup casserait le Studio et le cockpit. La verite derivee
va donc dans `canon_code.json`, a cote ; migrer les consommateurs est une etape separee, qui se
fait sans urgence et sans risque.

CE QUI EST EXTRAIT, ET D'OU :
  - les 5 verbes et leurs tags de base ..... merlin_card.gd : make_actions()
  - les 16 traits de depart et leurs tags .. merlin_card.gd : starter_traits()
  - les 25 concepts de maniere ............. merlin_resolution.gd : GESTE_MANIERE
  - le moteur (DC, couverture, seuils) ..... merlin_resolution.gd : les constantes
  - la composition des requis .............. merlin_scenario.gd : REQ_*_BY_DIFF
  - les figures, lieux et interdits ........ merlin_prompt_builder.gd : LORE_CANON
  - la loi du monde ........................ idem, premiere phrase du canon

`--verifier` ne reecrit rien : il compare le fichier existant au code et rend 1 s'il a derive.
C'est ce mode qui a vocation a tourner en CI ou dans un agent de controle : une derive doit se
voir le jour ou elle apparait, pas deux mois plus tard.
"""
import argparse
import json
import pathlib
import re
import sys

JEU_DEFAUT = "/home/user/merlin-jeu"


def lire(jeu: pathlib.Path, rel: str) -> str:
    p = jeu / rel
    if not p.exists():
        sys.exit("introuvable : %s" % p)
    return p.read_text(encoding="utf-8")


def cartes(bloc: str) -> list:
    """Les make(...) d'un bloc GDScript -> [{id, nom, tags}]."""
    out = []
    for m in re.finditer(r'make\(\s*"([^"]+)",\s*"([^"]+)",\s*\[([^\]]*)\]', bloc):
        tags = [t.strip().strip('"') for t in m.group(3).split(",") if t.strip()]
        out.append({"id": m.group(1), "nom": m.group(2), "tags": tags})
    return out


def bloc_func(src: str, nom: str) -> str:
    m = re.search(r'static func %s\(\)[^\n]*\n(.*?)\n\n\n' % re.escape(nom), src, re.S)
    return m.group(1) if m else ""


def const(src: str, nom: str) -> str:
    m = re.search(r'const %s[^=]*=\s*([^#\n]+)' % re.escape(nom), src)
    return m.group(1).strip() if m else ""


def dico(txt: str) -> dict:
    return {int(k): int(v) for k, v in re.findall(r'(\d+)\s*:\s*(\d+)', txt)}


def construire(jeu: pathlib.Path) -> dict:
    card = lire(jeu, "scripts/game/merlin_card.gd")
    reso = lire(jeu, "scripts/game/merlin_resolution.gd")
    scen = lire(jeu, "scripts/llm/merlin_scenario.gd")
    prom = lire(jeu, "scripts/llm/merlin_prompt_builder.gd")

    # --- les verbes : _action(id, nom, famille, [tags], evocation)
    verbes = []
    for m in re.finditer(r'_action\(\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*\[([^\]]*)\]', card):
        verbes.append({"id": m.group(1), "nom": m.group(2), "famille": m.group(3),
                       "tags": [t.strip().strip('"') for t in m.group(4).split(",") if t.strip()]})

    traits = cartes(bloc_func(card, "starter_traits"))

    maniere = re.search(r'const GESTE_MANIERE: Dictionary = \{(.*?)\n\}', reso, re.S)
    concepts = re.findall(r'"([a-z]+)":', maniere.group(1)) if maniere else []

    canon_txt = re.search(r'const LORE_CANON: String = "(.*?)"\n', prom, re.S)
    canon_txt = canon_txt.group(1) if canon_txt else ""
    loi = canon_txt.split("DECOR concret")[0].replace("\\n", " ").strip()
    lieux = re.findall(r'la Fontaine de Barenton|le Val sans Retour|le Pas de Nuit|'
                       r'le Gue des Brumes|la Pierre Qui Oublie|le Chene Creux|le Tertre des Neuf',
                       canon_txt)
    inter = canon_txt.split("INTERDIT car GENERIQUE")[-1].replace("\\n", " ").strip() \
        if "INTERDIT car GENERIQUE" in canon_txt else ""

    tags_connus = sorted({t for c in verbes + traits for t in c["tags"]})

    return {
        "version": "2.0",
        "source": "DERIVE DU CODE par tools/gd_agents/extraire_canon.py — ne pas editer a la main",
        "loi_du_monde": loi,
        "verbes": verbes,
        "traits_de_depart": traits,
        "concepts_de_maniere": concepts,
        "tags": tags_connus,
        "lieux_nommes": sorted(set(lieux)),
        "interdits": inter,
        "moteur": {
            "dc_par_difficulte": dico(const(reso, "DC_BY_DIFF")),
            "couverture_par_tag": int(const(reso, "COVER_PER_TAG") or 0),
            "synergie": int(const(reso, "SYN") or 0),
            "plancher_partiel": int(const(reso, "PARTIEL_LOW") or 0),
            "marge_eclatante": int(const(reso, "ECLAT_MARGIN") or 0),
            "marge_maitrise": int(const(reso, "MARGE_MAITRISE") or 0),
            "seuil_maitrise": int(const(reso, "SEUIL_MAITRISE") or 0),
            "de": "2d6",
            "geste_sur_desactive_au_climax": "beat_type == \"Climax\"" in reso,
        },
        "composition_des_requis": {
            "total_par_difficulte": dico(const(scen, "REQ_TOTAL_BY_DIFF")),
            "hors_tags_de_base_par_difficulte": dico(const(scen, "REQ_GAP_BY_DIFF")),
            "note": ("des la difficulte 2, les DEUX tags requis sont tires HORS des tags de base "
                     "des verbes : ils doivent venir de la main ou d'une greffe. C'est ce qui rend "
                     "la couverture impossible a garantir par le seul choix des cartes."),
        },
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--jeu", default=JEU_DEFAUT)
    ap.add_argument("--sortie", default=None)
    ap.add_argument("--verifier", action="store_true")
    a = ap.parse_args()

    neuf = construire(pathlib.Path(a.jeu))
    cible = pathlib.Path(a.sortie) if a.sortie else \
        pathlib.Path(__file__).resolve().parents[2] / "data" / "ai" / "canon_code.json"

    if a.verifier:
        if not cible.exists():
            print("DERIVE : %s n'existe pas" % cible)
            return 1
        vieux = json.loads(cible.read_text(encoding="utf-8"))
        ecarts = [k for k in neuf if json.dumps(vieux.get(k), sort_keys=True, ensure_ascii=False)
                  != json.dumps(neuf[k], sort_keys=True, ensure_ascii=False)]
        ecarts = [k for k in ecarts if k != "source"]
        if ecarts:
            print("DERIVE sur %d cle(s) : %s" % (len(ecarts), ", ".join(ecarts)))
            return 1
        print("canon conforme au code")
        return 0

    cible.parent.mkdir(parents=True, exist_ok=True)
    cible.write_text(json.dumps(neuf, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("%s ecrit : %d verbes, %d traits, %d concepts, %d tags, %d lieux" % (
        cible, len(neuf["verbes"]), len(neuf["traits_de_depart"]),
        len(neuf["concepts_de_maniere"]), len(neuf["tags"]), len(neuf["lieux_nommes"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
