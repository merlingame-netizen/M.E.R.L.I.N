#!/usr/bin/env python3
"""Repérer les nombres d'équilibrage codés en dur dans le jeu.

Pourquoi. Le jeu réel (~/workspace/merlin-game) ne déclare AUCUNE de ses règles
d'équilibrage dans des constantes lisibles : ni la vie, ni le rythme, ni les
récompenses. Mesuré — `pacing` cherche 9 constantes et n'en trouve aucune,
`economy` 8. Conséquence : personne ne peut mesurer ni régler l'équilibrage,
ni un agent, ni Maxime. Toute la chaîne « analyseur → patch chiffré » construite
au-dessus n'a aucune prise.

Ce module fait le premier pas : il LIT le jeu et dit où sont les chiffres qui
comptent. Il ne modifie rien. L'extraction viendra ensuite, sur cette base et
avec l'accord de Maxime — déplacer un nombre change le comportement du jeu, ce
n'est pas une opération à faire à l'aveugle.

    python3 tools/gd_agents/extraire_constantes.py            # le rapport
    python3 tools/gd_agents/extraire_constantes.py --json     # pour un agent

Stdlib seule. Lecture seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

JEU = Path.home() / "workspace" / "merlin-game"
if not (JEU / "scripts").exists():                 # poste de dev : le dépôt local
    JEU = Path(__file__).resolve().parents[2]

# Les familles de règles qu'un joueur RESSENT, et les mots qui les trahissent
# dans le code. C'est ce vocabulaire — relevé dans les scripts du jeu — qui
# distingue un nombre d'équilibrage d'un nombre d'affichage.
FAMILLES = {
    "vie et dégâts": r"\b(hp|health|vie|life|damage|degat|dmg|heal|soin|drain)\w*",
    "rythme de partie": r"\b(cards?|cartes?|turn|tour|round|deck|main|hand)\w*",
    "récompenses": r"\b(reward|recompense|gain|score|points?|faveur|anam|xp|loot)\w*",
    # PAS « de » : dans un dépôt commenté en français, « de » est partout et
    # ramenait 61 faux positifs (« pied réservé aux 3 slots de greffe »).
    "hasard et dés": r"\b(dice|roll|chance|proba|luck|seuil|threshold)\w*",
    "difficulté": r"\b(difficulty|difficulte|niveau|level|tier|palier|malus|bonus)\w*",
}
# Ce qu'on ne veut PAS : les nombres d'affichage, de position, de durée d'anim.
BRUIT = re.compile(
    r"\b(color|colour|alpha|rgba?|pos|position|offset|margin|padding|size|width|"
    r"height|scale|rot|angle|pixel|px|font|volume|db|hz|fps|delta|lerp|tween|"
    r"anim|fade|zoom|camera|light|shader|mesh|uv|vector|basis|z_index|stagger|"
    r"_ms\b|frame|warmup|viewport|texture|sprite|label|theme|style|panel|"
    r"duration|duree|timer|sleep|wait|msec|seconds?)\w*", re.I)
# Les nombres sans intérêt : 0, 1, -1, 2 (indices, booléens déguisés).
BANALS = {"0", "1", "-1", "2", "0.0", "1.0", "100.0"}

NOMBRE = re.compile(r"(?<![\w.])(-?\d+(?:\.\d+)?)(?![\w.])")


def _fichiers() -> list[Path]:
    d = JEU / "scripts"
    return sorted(d.rglob("*.gd")) if d.exists() else []


def _famille(ligne: str) -> str:
    bas = ligne.lower()
    for nom, motif in FAMILLES.items():
        if re.search(motif, bas):
            return nom
    return ""


def scanner() -> dict:
    """Rend {famille: [{fichier, ligne, texte, nombres}]} + ce qui est déjà const."""
    trouve: dict[str, list] = defaultdict(list)
    deja_const: dict[str, int] = defaultdict(int)
    # Les constantes DÉJÀ déclarées : 203 dans 28 fichiers. Le jeu est donc
    # largement paramétré — simplement pas sous les noms que les analyseurs
    # cherchaient. Avant d'extraire quoi que ce soit, il faut savoir ce qui
    # existe : on ne refactorise pas ce qui est déjà réglable.
    constantes: list[dict] = []
    for f in _fichiers():
        try:
            lignes = f.read_text(encoding="utf-8", errors="replace").splitlines()
        except Exception:
            continue
        rel = str(f.relative_to(JEU))
        for i, ligne in enumerate(lignes, 1):
            nu = ligne.strip()
            if not nu or nu.startswith("#"):
                continue
            # Un commentaire n'est pas du code : le laisser dans l'analyse
            # faisait repérer « pied réservé aux 3 slots » comme une règle de jeu.
            code = nu.split("#", 1)[0].strip()
            if not code:
                continue
            if code.startswith("const ") and re.search(r"=\s*-?\d", code):
                deja_const[rel] += 1
                constantes.append({"fichier": rel, "ligne": i, "texte": code[:110],
                                   "famille": _famille(code)})
                continue                       # déjà réglable : rien à faire
            if BRUIT.search(code):
                continue
            nu = code
            nombres = [n for n in NOMBRE.findall(nu) if n not in BANALS]
            if not nombres:
                continue
            fam = _famille(nu)
            if not fam:
                continue
            trouve[fam].append({"fichier": rel, "ligne": i,
                                "texte": nu[:110], "nombres": nombres[:4]})
    return {"jeu": str(JEU), "familles": dict(trouve),
            "deja_constantes": dict(deja_const),
            "constantes": constantes,
            "fichiers_scannes": len(_fichiers())}


def rapport(d: dict, par_famille: int = 4) -> str:
    lignes = [f"Jeu lu : {d['jeu']} · {d['fichiers_scannes']} scripts",
              f"Constantes déjà déclarées : "
              f"{sum(d['deja_constantes'].values())} dans "
              f"{len(d['deja_constantes'])} fichier(s)", ""]
    # CE QUI EST DÉJÀ RÉGLABLE, par famille : la vraie première question.
    par_fam: dict = {}
    for c in d.get("constantes") or []:
        if c.get("famille"):
            par_fam.setdefault(c["famille"], []).append(c)
    if par_fam:
        lignes.append("DÉJÀ RÉGLABLE (constantes existantes) :")
        for nom, cs in sorted(par_fam.items(), key=lambda x: -len(x[1])):
            lignes.append(f"  ■ {nom} — {len(cs)} constante(s)")
            for c in cs[:5]:
                lignes.append(f"      {c['fichier']}:{c['ligne']}  {c['texte'][:82]}")
            if len(cs) > 5:
                lignes.append(f"      … et {len(cs) - 5} autre(s)")
        lignes.append("")
        lignes.append("EN DUR (candidats à extraire) :")
    fam = d.get("familles") or {}
    if not fam:
        lignes.append("Aucun nombre d'équilibrage repéré — le jeu est peut-être "
                      "entièrement piloté par des données externes.")
        return "\n".join(lignes)
    for nom, cas in sorted(fam.items(), key=lambda x: -len(x[1])):
        # Combien de FICHIERS sont concernés : c'est ça qui dit l'ampleur.
        fichiers = sorted({c["fichier"] for c in cas})
        lignes.append(f"■ {nom.upper()} — {len(cas)} endroit(s) dans "
                      f"{len(fichiers)} fichier(s)")
        for c in cas[:par_famille]:
            lignes.append(f"   {c['fichier']}:{c['ligne']}  [{', '.join(c['nombres'])}]")
            lignes.append(f"      {c['texte']}")
        if len(cas) > par_famille:
            lignes.append(f"   … et {len(cas) - par_famille} autre(s)")
        lignes.append("")
    return "\n".join(lignes)


if __name__ == "__main__":
    d = scanner()
    if "--json" in sys.argv:
        print(json.dumps(d, ensure_ascii=False)[:6000])
    else:
        print(rapport(d))
