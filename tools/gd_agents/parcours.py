#!/usr/bin/env python3
"""La carte du parcours — ce que le jeu contient, et ce que Maxime y voit.

Pourquoi ce module existe. Maxime a écrit dans Parler : « la deuxième apparition
de MERLIN une fois le biome sélectionné est inutile ». Le modèle a reformulé en
« la deuxième apparition DU BIOME » — il a interverti le personnage et le décor,
et la mission partie au codeur visait le mauvais écran. La cause n'est pas le
modèle : la mémoire ne contenait QUE des décisions (« accepté ceci », « refusé
cela ») et AUCUNE description du jeu. Aucun écran, aucun enchaînement, aucun nom
de scène. Le modèle devinait.

Ce fichier lit le jeu tel qu'il est codé, et le décrit en français :
  - les écrans (`.tscn`) et leur script ;
  - qui mène à quoi (`change_scene_to_file` + les sous-scènes intégrées) ;
  - ce qu'on y voit (nœuds, textes affichés, modules d'interface) ;
  - la SÉQUENCE de chaque écran : dans quel ordre les choses apparaissent, avec
    le nom de la fonction qui les fait apparaître — c'est ce qui manquait pour
    comprendre « la deuxième apparition de MERLIN » ;
  - les écrans réellement observés par le robot testeur (le vécu, pas le code).

Sortie : ~/merlin-memory/parcours.json (hors dépôt) + un condensé français
injecté dans le contexte de MERLIN et des agents d'UX.

Stdlib seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

SORTIE = Path.home() / "merlin-memory" / "parcours.json"
VUES = Path.home() / "merlin-memory" / "journal" / "vues"


def _racine() -> Path:
    """Le dépôt du JEU s'il est là, l'outillage sinon (poste de dev, tests)."""
    jeu = Path.home() / "workspace" / "merlin-game"
    return jeu if (jeu / "scenes").exists() else HERE.parents[1]


# Ce qui, dans un nom de fonction, trahit une APPARITION à l'écran. C'est le
# vocabulaire réel du projet, relevé dans les scripts — pas une devinette.
APPARITION = re.compile(
    r"_(spawn|build|show|reveal|display|setup|appear|fade|intro|present)_?", re.I)
# Les textes que le joueur lit vraiment.
TEXTE = re.compile(r'(?:text|_info_label\.text|title)\s*=\s*"([^"]{3,90})"')


def _lire(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def _script_de(tscn: Path) -> Path | None:
    m = re.search(r'path="res://(scripts/[^"]+\.gd)"', _lire(tscn))
    return (_racine() / m.group(1)) if m else None


def _sequence(src: str) -> list[dict]:
    """L'ordre d'apparition des choses, tel que le code l'exécute.

    On suit le corps de `_run_flow` / `_ready` : chaque appel de fonction dont le
    nom trahit une apparition devient une étape, dans l'ordre. C'est cette liste
    qui permet de dire « la DEUXIÈME apparition de MERLIN »."""
    etapes = []
    for nom_flux in ("_run_flow", "_ready", "_setup_ui", "_start"):
        m = re.search(rf"func {nom_flux}\(.*?\)\s*->[^:]*:(.*?)(?=\nfunc |\Z)", src, re.S)
        if not m:
            continue
        for ligne in m.group(1).splitlines():
            l = ligne.strip()
            if l.startswith("#") or not l:
                continue
            appel = re.match(r"(?:await\s+)?(_[a-z0-9_]+)\(", l)
            if appel and APPARITION.match(appel.group(1)):
                etapes.append({"flux": nom_flux, "appel": appel.group(1),
                               "quoi": _en_clair(appel.group(1))})
            txt = TEXTE.search(l)
            if txt:
                etapes.append({"flux": nom_flux, "appel": "texte affiché",
                               "quoi": f"le joueur lit « {txt.group(1)} »"})
    return etapes[:20]


MOTS = {
    "spawn": "fait apparaître", "build": "construit", "show": "affiche",
    "reveal": "dévoile", "display": "affiche", "setup": "met en place",
    "fade": "fond enchaîné sur", "intro": "introduit", "present": "présente",
    "merlin": "MERLIN (le personnage)", "card": "les cartes",
    "cards": "les cartes", "scenario": "le scénario", "ui": "l'interface",
    "hud": "le HUD", "world": "le décor", "biome": "le biome",
    "writing": "en train d'écrire", "board": "le plateau",
    "sound": "la barre sonore", "bar": "", "for": "", "the": "",
}


def _en_clair(nom: str) -> str:
    """`_spawn_merlin_for_writing` → « fait apparaître MERLIN en train d'écrire »."""
    bouts = [MOTS.get(x, x) for x in nom.strip("_").split("_")]
    return " ".join(b for b in bouts if b).strip()


def _visible(tscn: Path) -> dict:
    """Ce qu'on voit sur cet écran : nœuds racines et textes en dur."""
    src = _lire(tscn)
    noeuds = re.findall(r'^\[node name="([^"]+)"(?: type="([^"]+)")?', src, re.M)
    textes = re.findall(r'^text = "([^"]{2,60})"', src, re.M)
    return {"noeuds": [n for n, _ in noeuds][:14],
            "textes_affiches": textes[:8]}


def _liens(src: str) -> list[str]:
    return list(dict.fromkeys(re.findall(r'res://(scenes/[\w./-]+\.tscn)', src)))


def construire() -> dict:
    racine = _racine()
    dossier = racine / "scenes"
    ecrans = {}
    for tscn in sorted(dossier.glob("*.tscn")) if dossier.exists() else []:
        script = _script_de(tscn)
        src = _lire(script) if script else ""
        ecrans[tscn.stem] = {
            "scene": f"scenes/{tscn.name}",
            "script": (str(script.relative_to(racine)) if script and script.exists() else ""),
            "lignes_de_code": len(src.splitlines()),
            **_visible(tscn),
            "sequence": _sequence(src),
            "mene_a": [x for x in _liens(src) if Path(x).stem != tscn.stem],
        }
    # Qui mène à qui, dans l'autre sens : « on arrive ici depuis… »
    for nom, e in ecrans.items():
        e["vient_de"] = sorted(
            autre for autre, a in ecrans.items()
            if any(Path(x).stem == nom for x in a.get("mene_a", [])))
    return {
        "t": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "racine": str(racine), "ecrans": ecrans,
        "vecu": _vecu(),
    }


def _vecu() -> dict:
    """Ce que Maxime VOIT vraiment — les écrans clés du dernier playtest.

    Le code dit ce que le jeu est censé faire ; la pellicule dit ce qui s'affiche
    réellement. Les deux sont nécessaires : c'est là qu'on repère qu'un écran
    « prévu » ne s'affiche jamais, ou qu'un écran noir dure quatorze captures."""
    try:
        fichiers = sorted(VUES.glob("*.json"))
        if not fichiers:
            return {}
        d = json.loads(fichiers[-1].read_text(encoding="utf-8"))
        pel = d.get("pellicule") or []
        return {"session": d.get("tag"), "pas_joues": d.get("pas"),
                "anomalies": d.get("anomalies") or [],
                "ecrans_cles": d.get("cles") or [],
                "luminance_min": min((p.get("luminance", 0) for p in pel), default=None),
                "ecrans_identiques_daffilee": max(
                    (sum(1 for _ in g) for g in _suites(pel)), default=0)}
    except Exception:
        return {}


def _suites(pel: list[dict]):
    """Longueurs des séries d'écrans identiques (un écran figé se voit ici)."""
    courant, serie = None, []
    for p in pel:
        if p.get("empreinte") == courant:
            serie.append(p)
        else:
            if serie:
                yield serie
            courant, serie = p.get("empreinte"), [p]
    if serie:
        yield serie


def condense(max_chars: int = 1400) -> str:
    """Le condensé injecté dans les prompts — en français, sans jargon.

    C'est CE texte qui aurait évité de confondre « MERLIN » et « le biome »."""
    d = charger()
    ecrans = d.get("ecrans") or {}
    if not ecrans:
        return ""
    lignes = ["CARTE DU JEU (ce qui existe réellement — ne rien inventer d'autre) :"]
    for nom, e in ecrans.items():
        suite = " → ".join(x["quoi"] for x in (e.get("sequence") or [])[:5])
        bout = f"· {nom} ({e['scene']})"
        if e.get("vient_de"):
            bout += f", où l'on arrive depuis {', '.join(e['vient_de'][:2])}"
        if suite:
            bout += f". Il s'y passe, dans l'ordre : {suite}"
        lignes.append(bout)
    v = d.get("vecu") or {}
    if v.get("anomalies"):
        lignes.append(f"OBSERVÉ EN JOUANT : anomalies {', '.join(v['anomalies'])} "
                      f"sur {v.get('pas_joues', '?')} écrans parcourus.")
    return "\n".join(lignes)[:max_chars]


def charger() -> dict:
    try:
        return json.loads(SORTIE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def ecrire() -> Path:
    d = construire()
    SORTIE.parent.mkdir(parents=True, exist_ok=True)
    SORTIE.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
    return SORTIE


def chercher(mot: str) -> list[str]:
    """Où, dans le jeu, ce mot apparaît-il ? Sert à répondre « quel écran ? ».

    Les résultats sont CLASSÉS, pas seulement listés : un écran dont la SÉQUENCE
    mentionne le mot (« fait apparaître MERLIN en train d'écrire ») vaut bien
    plus qu'un écran qui le contient quelque part dans son code. Sans ce
    classement, « merlin » rendait quatre écrans à égalité et la piste utile se
    noyait dans le bruit."""
    d, mot = charger(), mot.lower().strip()
    if len(mot) < 4:
        return []
    scores = []
    for nom, e in (d.get("ecrans") or {}).items():
        quoi = [s["quoi"] for s in (e.get("sequence") or []) if mot in s["quoi"].lower()]
        textes = [t for t in e.get("textes_affiches", []) if mot in t.lower()]
        noeuds = [n for n in e.get("noeuds", []) if mot in n.lower()]
        score = 6 * len(quoi) + 3 * len(textes) + 2 * len(noeuds)
        if not score and mot in json.dumps(e, ensure_ascii=False).lower():
            score = 1                      # présent, mais sans rôle visible
        if not score:
            continue
        detail = ", ".join((quoi + textes + noeuds)[:2])
        scores.append((score, f"{nom} ({e['script'] or e['scene']})"
                              + (f" — {detail}" if detail else "")))
    scores.sort(key=lambda x: -x[0])
    return [t for _, t in scores]


if __name__ == "__main__":
    if "--chercher" in sys.argv:
        for x in chercher(sys.argv[sys.argv.index("--chercher") + 1]):
            print(" ", x)
    elif "--condense" in sys.argv:
        print(condense())
    else:
        p = ecrire()
        d = charger()
        print(f"{len(d.get('ecrans', {}))} écran(s) cartographié(s) → {p}")
        for nom, e in (d.get("ecrans") or {}).items():
            print(f"  {nom:22} {len(e.get('sequence') or [])} étape(s) · "
                  f"mène à {', '.join(Path(x).stem for x in e.get('mene_a', [])) or '—'}")
