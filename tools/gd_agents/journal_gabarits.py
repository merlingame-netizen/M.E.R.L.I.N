#!/usr/bin/env python3
"""Rédaction du chapitre SANS modèle — la version qui ne peut pas échouer.

Le narrateur de 05:50 (étape 5) embellira deux scènes avec le LLM. Mais un
journal qui dépend d'un modèle est un journal qui se tait les nuits où le modèle
est occupé, lent ou muet — et Gemma 4 sait faire les trois. Ce fichier est donc
le socle : il rend toujours un chapitre lisible, phrasé, en français, à partir
de la fiche de `journal.py`.

Principe : on ne paraphrase RIEN. Les agents écrivent déjà leurs résumés en
français (« jeu en cours — la chaîne cède les 4 cœurs », « 29 carte(s) écrite(s),
1 refusée(s) ») ; le validateur donne ses motifs ; le vérificateur son
diagnostic. Le travail des gabarits est de les ORDONNER, de les relier et de
nommer les personnages — pas de réécrire.

Stdlib seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

TROUPE = HERE / "troupe.json"

# Repli si troupe.json est absent : trois tables divergentes donnaient jusqu'ici
# trois noms à la même entité (probes.WHO 7 entrées, WHO_FR 10, CREW_ROLE 22).
NOMS = {
    "gd-content-gap": "l'Atelier d'écriture", "gd-balance": "l'Équilibreur",
    "gd-pacing": "le Rythmeur", "gd-economy": "le Trésorier",
    "gd-audit": "l'Auditeur", "coder-local": "le Codeur", "coder": "le Codeur",
    "playtest-bot": "le Robot testeur", "corpus-night": "l'Atelier d'écriture",
    "billing": "le Comptable", "ci-commit": "le Vérificateur",
    "design-council": "le Conseil", "smoke-scenes": "la Sentinelle",
    "health": "la Vigie", "disk-guard": "le Garde-disque",
    "game-watchdog": "le Veilleur", "game-autosync": "le Passeur",
    "tunnel-watch": "le Guetteur", "daily-report": "le Chroniqueur",
    "ollama-serve": "le Porteur de modèle", "llm-bench": "le Métreur",
    "ollama-idle": "le Délesteur",
}


def _nom(acteur: str) -> str:
    """Le nom de scène d'un acteur. Une seule source de vérité."""
    if acteur in ("toi", "le dépôt", "le codeur", "le vérificateur",
                  "le robot testeur", "le contrôle qualité", "la chaîne",
                  "le registre"):
        return acteur
    try:
        t = json.loads(TROUPE.read_text(encoding="utf-8"))
        fiche = t.get("acteurs", {}).get(acteur)
        if fiche and fiche.get("nom"):
            return f"{fiche.get('article', 'le')} {fiche['nom']}".strip()
    except Exception:
        pass
    return NOMS.get(acteur, acteur)


def _pluriel(n: int, singulier: str, pluriel: str | None = None) -> str:
    return f"{n} {singulier}" if n <= 1 else f"{n} {pluriel or singulier + 's'}"


def _chapo(fiche: dict) -> str:
    """Deux ou trois phrases qui disent de quoi la nuit a été faite."""
    faits = fiche.get("faits", [])
    echecs = [f for f in faits if f["type"] == "echec"]
    res = [f for f in faits if f["type"] == "resolution"]
    mine = [f for f in faits if f["type"] == "maxime"]
    mots = [f for f in faits if f["type"] == "mot"]
    # Les changements ENTRÉS DANS LE JEU se comptent en commits, pas en étapes :
    # « patchée » et « poussée » sont deux jalons du même changement, les
    # additionner gonflait le chiffre d'un facteur deux ou trois.
    integ = [f for f in faits if f.get("origine") == "commit" and f["type"] == "integration"]

    if not faits:
        return ("Rien ne s'est passé cette nuit — aucun agent n'a laissé de trace. "
                "Ce n'est pas forcément une bonne nouvelle : vérifie que la "
                "planification tourne encore.")
    bouts = []
    if echecs and res:
        bouts.append(f"Une nuit en deux temps : {_pluriel(len(echecs), 'accroc')} "
                     f"et {_pluriel(len(res), 'résolution')}.")
    elif echecs:
        bouts.append(f"Une nuit contrariée : {_pluriel(len(echecs), 'accroc')}, "
                     "et rien de refermé.")
    elif res:
        bouts.append(f"Une nuit qui range : {_pluriel(len(res), 'chose réglée', 'choses réglées')}, "
                     "aucun incident.")
    else:
        bouts.append("Personne n'a rien cassé cette nuit, et personne n'a rien "
                     "refermé non plus : l'atelier a tourné à son rythme.")
    if mine:
        bouts.append(f"Tu es passé par là — {_pluriel(len(mine), 'décision')} de ta main.")
    if mots:
        bouts.append(f"Tu as aussi écrit {_pluriel(len(mots), 'message')} aux agents.")
    if integ:
        bouts.append(f"{_pluriel(len(integ), 'changement')} {'est entré' if len(integ) <= 1 else 'sont entrés'} "
                     "dans le jeu.")
    return " ".join(bouts)


def _scene(fait: dict, causalite: dict) -> str:
    """Un fait devient un paragraphe daté, avec son acteur nommé."""
    tete = f"**{fait['heure']} — {_nom(fait['acteur']).upper()}**"
    corps = fait["titre"]
    n = fait.get("repetitions", 1)
    if n > 1:
        corps += f" — et {n - 1} autre(s) cas identiques dans la nuit"
    if fait.get("detail"):
        corps += f" {fait['detail']}" if corps.endswith((".", "!", "?")) else f" — {fait['detail']}"
    if not corps.endswith((".", "!", "?", "»")):
        corps += "."
    return f"{tete}\n{corps}"


def _chiffres(fiche: dict) -> str:
    """Ce qui a bougé depuis hier. Rien d'inventé : deux relevés comparés."""
    c = fiche.get("chiffres") or {}
    bouge = c.get("bouge") or {}
    if not bouge:
        return ""
    LISIBLE = {"cartes": "cartes au recueil", "propositions_attente": "décisions en attente",
               "propositions_acceptees": "décisions prises", "missions_faites": "corrections appliquées",
               "missions_en_file": "missions en file", "scenes_ko": "scènes en erreur",
               "agents_ko": "agents en échec", "commits_24h": "changements du jour"}
    lignes = []
    for k, v in sorted(bouge.items(), key=lambda x: -abs(x[1]["delta"]))[:4]:
        signe = "+" if v["delta"] > 0 else ""
        lignes.append(f"· {LISIBLE.get(k, k)} : {v['avant']} → {v['apres']} ({signe}{v['delta']})")
    return "**CE QUI A BOUGÉ**\n" + "\n".join(lignes)


def _fils(fiche: dict) -> str:
    """Les arcs en cours — ce qui relie ce chapitre aux précédents."""
    ouverts = fiche.get("fils_ouverts") or []
    if not ouverts:
        return ""
    lignes = []
    for f in ouverts[:4]:
        n = len(f.get("jours") or [])
        duree = ("ouvert cette nuit" if n <= 1 else
                 f"ouvert le {f.get('ouvert', '?')}, {n}ᵉ nuit consécutive")
        lignes.append(f"· {f.get('sujet', f.get('cle', ''))} — {duree}.")
    return "**FILS EN COURS**\n" + "\n".join(lignes)


def rediger(fiche: dict) -> str:
    """Le chapitre complet, en français, sans un seul appel au modèle."""
    faits = fiche.get("faits", [])
    # Cinq fois le même acteur disant la même chose n'est pas cinq scènes : c'est
    # une scène et un chiffre. On regroupe sur TOUS les faits — les répétitions
    # se cachent dans la masse, pas dans les cinq déjà retenus —, on garde les
    # cinq groupes les plus lourds, et on les raconte dans l'ordre où ils se sont
    # produits : un récit qui saute de 17 h 58 à 15 h 58 n'en est plus un.
    groupes: dict[tuple, list] = {}
    for f in faits:
        groupes.setdefault((f["acteur"], f["type"], f.get("detail", "")[:60]), []).append(f)
    retenus = [{**min(g, key=lambda x: x["t"]), "repetitions": len(g)}
               for g in groupes.values()]
    retenus.sort(key=lambda f: (-f["poids"], -f["repetitions"], -f["t"]))
    scenes = [_scene(f, fiche.get("causalite", {}))
              for f in sorted(retenus[:5], key=lambda x: x["t"])]

    entete = (f"**JOURNAL DE L'ATELIER — {fiche.get('jour', '')} · chapitre {fiche.get('n', '?')}**\n"
              f"*« {_titre_court(fiche)} »*")
    blocs = [entete, _chapo(fiche)] + scenes
    for extra in (_chiffres(fiche), _fils(fiche)):
        if extra:
            blocs.append(extra)
    blocs.append(f"*{_pluriel(len(faits), 'fait consigné', 'faits consignés')} cette nuit. "
                 "Rédigé sans modèle.*")
    return "\n\n".join(blocs)


def _titre_court(fiche: dict) -> str:
    """Le titre du chapitre : ce qui a fait la nuit.

    On préfère une TENSION (un échec, une décision) à une conclusion : « la
    scène qui refuse de démarrer » raconte mieux que « … — fusionnée », qui ne
    fait que répéter la première scène."""
    s = fiche.get("saillants") or []
    if not s:
        return "Une nuit sans histoire"
    prio = ([f for f in s if f["type"] == "echec"]
            or [f for f in s if f["type"] == "maxime"] or s)
    t = re.sub(r"\s+—\s+(fusionnée|poussée|patchée|smoke \w+)$", "", prio[0]["titre"])
    return (t[:70] + "…") if len(t) > 71 else t


if __name__ == "__main__":
    import journal as J
    print(rediger(J.collecte(int(sys.argv[1]) if len(sys.argv) > 1 else 24)))
