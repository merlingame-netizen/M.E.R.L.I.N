#!/usr/bin/env python3
"""Refait `data/ai/lore_canon.json` DEPUIS LE JEU, en gardant sa forme.

    python3 tools/gd_agents/refaire_lore_canon.py [--jeu /chemin] [--verifier]

POURQUOI. Le canon avait été écrit à la main le 2026-06-19 et n'a plus jamais été relu. Deux mois
et demi plus tard il décrivait un autre jeu, et pas d'un peu : huit biomes inventés (« Foret de
Broceliande », « Landes de Bruyere ») là où le jeu en a douze aux noms bretons ; douze PNJ dont
aucun n'existe (Maelgwn, Keridwen, Niamh, Manannan, Brigid) alors que le canon appliqué par le
jeu INTERDIT nommément ces dieux ; neuf champs lexicaux et des cartes à trois options, un système
abandonné au pivot v11 au profit de R166 (cinq tuiles, dix runes, 2d6 contre un seuil).

Quatre outils lisaient ce fichier — dont `content_gap.py`, qui écrit le corpus d'entraînement du
futur modèle. Chaque nuit ajoutait donc des exemples d'un jeu qui n'existe pas.

ON GARDE LA FORME, ON REFAIT LE FOND. Les quatre consommateurs lisent des clés précises
(`biomes`, `factions`, `npcs`, `scenario_constraints`, `gaps`, `divergences`, `version`). Les
supprimer casserait le Studio et le cockpit le jour du déploiement. Les clés restent donc, avec
la vérité du jeu dedans : c'est la différence entre réparer et refondre, et seule la première
était demandée.

D'OÙ VIENT CHAQUE CLÉ, et rien n'est écrit à la main :
  biomes ................ data/biomes/*.json          (12 lieux, leurs tags, leur accès)
  factions .............. les `faction` réellement portées par les biomes et les figures
  npcs .................. data/figures/*.json         (nom, rôle, ce qu'il VEUT, sa voix)
  scenario_constraints .. canon_code.json             (5 tuiles, 16 traits, seuils, interdits)
  gaps .................. data/quete/hauts_faits.json (ce que le code ne sait pas encore noter)

`--verifier` ne réécrit rien et rend 1 si le fichier a dérivé. C'est ce mode qui doit tourner en
contrôle : une dérive doit se voir le jour où elle apparaît, pas deux mois et demi plus tard.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[2]
JEU_DEFAUT = pathlib.Path("/home/user/merlin-jeu")
SORTIE = RACINE / "data" / "ai" / "lore_canon.json"
CANON_CODE = RACINE / "data" / "ai" / "canon_code.json"


def _lire_json(p: pathlib.Path, defaut):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return defaut


def biomes(jeu: pathlib.Path) -> list[dict]:
    """Les douze lieux du jeu, tels que le jeu les décrit. `name` et non `nom` : c'est la clé que
    les consommateurs lisent depuis toujours, et la renommer les casserait pour rien."""
    out = []
    for f in sorted((jeu / "data" / "biomes").glob("*.json")):
        b = _lire_json(f, {})
        if not b:
            continue
        acces = b.get("acces") or {}
        out.append({
            "id": b.get("id", f.stem),
            "name": b.get("nom", ""),
            "subtitle": b.get("sous_titre", ""),
            "archetype": b.get("archetype", ""),
            "faction": b.get("faction", ""),
            "tags": b.get("tags", []),
            "corruption": b.get("corruption", 0),
            "seuil_annwn": bool(b.get("seuil_annwn", False)),
            "palier": acces.get("palier"),
            "eclats_requis": acces.get("eclats_requis"),
            "relique": b.get("relique_trouvee", ""),
        })
    return out


def factions(bs: list[dict], ns: list[dict]) -> list[dict]:
    """Les factions ne sont écrites nulle part comme une liste : elles EXISTENT par ce qui les
    porte. On les déduit donc des biomes et des figures, avec leur effectif — un compte à zéro
    signale une faction fantôme, ce que la liste écrite à la main ne pouvait pas montrer."""
    noms: dict[str, dict] = {}
    for b in bs:
        f = b.get("faction") or ""
        if f:
            noms.setdefault(f, {"name": f, "biomes": [], "npcs": []})["biomes"].append(b["name"])
    for n in ns:
        f = n.get("faction") or ""
        if f:
            noms.setdefault(f, {"name": f, "biomes": [], "npcs": []})["npcs"].append(n["name"])
    return [noms[k] for k in sorted(noms)]


def npcs(jeu: pathlib.Path) -> list[dict]:
    """Les figures du canon, avec ce qui les rend jouables : ce qu'elles VEULENT et comment elles
    parlent. Le canon d'avant donnait des noms et une biographie ; un générateur a besoin d'un
    désir et d'une voix — c'est la leçon de q86, qui a nommé seize figures sans qu'aucune ne veuille
    quoi que ce soit."""
    out = []
    for f in sorted((jeu / "data" / "figures").glob("*.json")):
        n = _lire_json(f, {})
        if not n:
            continue
        lx = n.get("lieux", n.get("lieu", ""))
        out.append({
            "id": n.get("id", f.stem),
            "name": n.get("nom", ""),
            "faction": n.get("faction", ""),
            "role": n.get("role", ""),
            "veut": n.get("veut", ""),
            "voix": n.get("voix", ""),
            "replique_etalon": n.get("replique_etalon", ""),
            "regle_ecriture": n.get("regle_ecriture", ""),
            "secret": n.get("secret", ""),
            "mecanique": n.get("mecanique", ""),
            "biomes": lx if isinstance(lx, list) else ([lx] if lx else []),
            "chapitres": n.get("chapitres", []),
            "tags": n.get("tags", []),
        })
    return out


def contraintes(jeu: pathlib.Path, cc: dict) -> dict:
    """Les règles que le jeu applique VRAIMENT (R166), dans les clés que les outils lisent.

    `verbs_by_field` gardait neuf champs lexicaux et quarante-cinq verbes : un système mort. Le
    jeu d'aujourd'hui a cinq tuiles, chacune d'une famille. On garde donc la forme (champ → verbes)
    avec la vérité dedans — `scenario_validator` en tire son ensemble de verbes autorisés, qui
    devient les cinq tuiles au lieu de quarante-cinq mots d'un autre jeu."""
    par_famille: dict[str, list[str]] = {}
    for v in cc.get("verbes", []):
        par_famille.setdefault(v.get("famille", "?"), []).append(v.get("nom", ""))
    moteur = cc.get("moteur", {}) or {}
    regles = _lire_json(RACINE / "data" / "ai" / "canon_code.json", {})
    return {
        "systeme": "R166 — cinq tuiles, seize traits de départ, 2d6 contre un seuil",
        "verbs_by_field": par_famille,
        "traits_de_depart": [t.get("nom", "") for t in cc.get("traits_de_depart", [])],
        "concepts_de_maniere": cc.get("concepts_de_maniere", []),
        "tags": cc.get("tags", []),
        "lieux_nommes": cc.get("lieux_nommes", []),
        # DEUX CHOSES, ET PAS UNE. `interdits` est une PROSE dans le canon du jeu (« AUCUN dieu
        # nomme (ni Lugh, ni Cernunnos...), AUCUNE magie a incantation... »). La verser telle
        # quelle dans `forbidden_words` donnait une chaîne là où deux outils attendent une liste :
        # `scenario_validator` l'ignorait en silence (il teste `isinstance(list)`) et
        # `content_gap` en découpait les huit premiers CARACTÈRES, envoyant au modèle
        # « Mots interdits : (, c, e,  , n, ', e, s ». On garde donc la prose entière pour les
        # prompts, et on en tire la liste des noms qu'un filtre par mot peut réellement vérifier.
        "forbidden_words": _noms_interdits(cc.get("interdits", "")),
        "forbidden_prose": cc.get("interdits", ""),
        "moteur": moteur or regles.get("moteur", {}),
        # Gardés parce que des outils les lisent, et RENSEIGNÉS comme le jeu les applique
        # aujourd'hui : un beat, pas une carte à options.
        "unite_de_contenu": "beat (scène, geste, issue) — la carte à trois options est morte au pivot v11",
        "options_per_card": 0,
        "card_text": {"note": "sans objet depuis le pivot v11 ; une scène fait trois phrases courtes"},
        "effect_caps": {},
    }


def _noms_interdits(prose: str) -> list[str]:
    """Les noms propres que le canon interdit nommément — les seuls qu'un filtre par mot puisse
    contrôler. Le reste de l'interdiction porte sur des ESPÈCES de choses (« aucune magie à
    incantation », « jamais le 4e mur ») : ça se juge en lisant, pas en cherchant un mot, et
    prétendre le contraire donnerait un validateur qui rassure sans rien voir."""
    if not isinstance(prose, str) or not prose:
        return []
    noms = re.findall(r"\bni ([A-ZÉÈÀÇ][\wéèêàçâîôûïüë'-]+)", prose)
    # « aucun chevalier de la Table Ronde autre qu'Arthur » : ce qui est nommé APRÈS « autre que »
    # est au contraire autorisé — on ne l'ajoute pas.
    vus, out = set(), []
    for n in noms:
        if n not in vus:
            vus.add(n)
            out.append(n)
    return out


def gaps(jeu: pathlib.Path) -> list[str]:
    """Les vraies lacunes d'aujourd'hui, prises là où le jeu les DÉCLARE lui-même : les hauts faits
    qu'aucun code ne sait encore noter, et qui bloquent des chapitres. Le canon d'avant listait des
    lacunes sur des systèmes morts (« 9 Rune-Circuits », « 18 Oghams »)."""
    hf = _lire_json(jeu / "data" / "quete" / "hauts_faits.json", {})
    out = []
    for f in hf.get("hauts_faits", []):
        if not f.get("implemente", True):
            out.append("haut fait non implémenté : %s — %s" % (
                f.get("titre", f.get("cle", "?")), f.get("pourquoi_pas", "raison non dite")))
    ch = _lire_json(jeu / "data" / "quete" / "chapitres.json", {})
    verrous = hf.get("verrous_par_chapitre", {}) or {}
    bloques = sorted({int(k) for k, v in verrous.items()
                      for c in v
                      if any(not x.get("implemente", True) and x.get("cle") == c
                             for x in hf.get("hauts_faits", []))})
    if bloques:
        out.append("chapitres bloqués faute de code : %s sur %d" % (
            ", ".join(str(n) for n in bloques), len((ch.get("chapitres") or ch) or [])))
    return out


def construire(jeu: pathlib.Path) -> dict:
    cc = _lire_json(CANON_CODE, {})
    bs, ns = biomes(jeu), npcs(jeu)
    return {
        "version": "2.0",
        "source": "DÉRIVÉ du jeu (data/biomes, data/figures, data/quete, canon_code.json) — "
                  "ne pas éditer à la main : refaire_lore_canon.py le réécrit",
        "systeme": "R166 / v48",
        "loi_du_monde": cc.get("loi_du_monde", ""),
        "world": {
            "name": "Penn ar Bed (Brocéliande et les terres de l'Ouest)",
            "premise": cc.get("loi_du_monde", ""),
        },
        "biomes": bs,
        "factions": factions(bs, ns),
        "npcs": ns,
        "scenario_constraints": contraintes(jeu, cc),
        # Le canon d'avant portait une liste de divergences entre lore écrit et code. Un artefact
        # dérivé ne peut pas diverger de sa source : la liste est vide, et c'est une information.
        "divergences": [],
        "gaps": gaps(jeu),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--jeu", type=pathlib.Path, default=JEU_DEFAUT)
    ap.add_argument("--verifier", action="store_true",
                    help="ne réécrit rien ; rend 1 si le fichier a dérivé du jeu")
    a = ap.parse_args(argv)
    if not (a.jeu / "data" / "biomes").is_dir():
        print("dépôt du jeu introuvable : %s" % a.jeu, file=sys.stderr)
        return 2
    neuf = construire(a.jeu)
    if a.verifier:
        actuel = _lire_json(SORTIE, {})
        if actuel == neuf:
            print("canon conforme au jeu")
            return 0
        for cle in sorted(set(neuf) | set(actuel)):
            if actuel.get(cle) != neuf.get(cle):
                av, ap_ = actuel.get(cle), neuf.get(cle)
                n = lambda x: len(x) if isinstance(x, (list, dict)) else "—"
                print("  dérive : %-22s %s → %s" % (cle, n(av), n(ap_)))
        return 1
    SORTIE.write_text(json.dumps(neuf, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("écrit : %s" % SORTIE)
    print("  %d biomes · %d factions · %d figures · %d lacunes · %d verbes"
          % (len(neuf["biomes"]), len(neuf["factions"]), len(neuf["npcs"]), len(neuf["gaps"]),
             sum(len(v) for v in neuf["scenario_constraints"]["verbs_by_field"].values())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
