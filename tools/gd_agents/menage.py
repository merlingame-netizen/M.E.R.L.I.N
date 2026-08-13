#!/usr/bin/env python3
"""Retirer de Décider ce qui n'a jamais été une décision.

Le contexte, mesuré sur la VM : 19 propositions en attente, dont 18 identiques —
« Professeur du modèle — analyse seule sur <biome> (JSON illisible) ». L'agent
qui écrit les cartes d'entraînement tournait toutes les 30 minutes ; à chaque
échec du modèle, il déposait une proposition « preuves seules ». Ces cartes ne
servent qu'à ENTRAÎNER le modèle : leur échec est une panne d'atelier, pas un
choix à faire. Elles ont noyé les deux vraies propositions.

La cause est corrigée en amont (runner.py ne propose plus rien sur une carte
ratée). Ce module nettoie ce qui a déjà été écrit — et LUI, il ne devine pas :
il ne retire que ce qui porte la signature exacte d'un échec technique.

    python3 tools/gd_agents/menage.py            # ce qu'il RETIRERAIT
    python3 tools/gd_agents/menage.py --appliquer

Stdlib seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import proposals as PROP  # noqa: E402

# La signature d'une panne technique. Volontairement ÉTROITE : on préfère
# laisser passer du bruit que retirer une vraie proposition de Maxime.
PANNE = re.compile(
    r"(JSON illisible|LLM indisponible|analyse seule|rédaction automatique a échoué"
    r"|validateur indisponible|réponse était inutilisable)", re.I)


def _est_panne(d: dict) -> bool:
    """Une proposition n'est du bruit que si l'échec est dans son TITRE ou son
    argument — pas seulement mentionné quelque part dans ses preuves."""
    txt = f"{d.get('title','')} {d.get('claim','')}"
    return bool(PANNE.search(txt))


def inspecter() -> dict:
    lots = {}
    for nom, dossier in (("en attente", PROP.INBOX), ("acceptées", PROP.ACCEPTED)):
        pannes, vraies = [], []
        for p in sorted(dossier.glob("*.json")) if dossier.exists() else []:
            d = PROP._read(p) or {}
            (pannes if _est_panne(d) else vraies).append((p, d))
        lots[nom] = {"pannes": pannes, "vraies": vraies}
    return lots


def rapport(lots: dict) -> str:
    out = []
    for nom, lot in lots.items():
        out.append(f"{nom} : {len(lot['pannes'])} panne(s) technique(s) à retirer, "
                   f"{len(lot['vraies'])} vraie(s) proposition(s) conservée(s)")
        for _p, d in lot["vraies"][:6]:
            out.append(f"   ✓ GARDÉ  {d.get('title','')[:78]}")
        for _p, d in lot["pannes"][:3]:
            out.append(f"   ✗ retiré {d.get('title','')[:78]}")
        if len(lot["pannes"]) > 3:
            out.append(f"   … et {len(lot['pannes']) - 3} autre(s) du même motif")
    return "\n".join(out)


def appliquer(lots: dict) -> str:
    """Déplace les pannes hors de Décider, sans les détruire.

    Elles partent dans `rejected/` avec leur motif : le principe « rien ne
    s'efface » vaut aussi pour les erreurs — c'est en les gardant qu'on pourra
    mesurer si le correctif a marché."""
    n = 0
    for lot in lots.values():
        for p, d in lot["pannes"]:
            d["status"] = "rejected"
            d["decision_reason"] = ("retiré automatiquement : panne technique de "
                                    "l'atelier, jamais une décision à prendre")
            d.setdefault("trail", []).append(
                {"t": PROP._now(), "step": "écartée",
                 "detail": "ménage : échec d'écriture, pas un sujet"})
            PROP.REJECTED.mkdir(parents=True, exist_ok=True)
            (PROP.REJECTED / p.name).write_text(
                json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
            p.unlink(missing_ok=True)
            n += 1
    return f"{n} proposition(s) retirée(s) de Décider (conservées dans rejected/)"


if __name__ == "__main__":
    lots = inspecter()
    print(rapport(lots))
    if "--appliquer" in sys.argv:
        print(appliquer(lots))
    else:
        total = sum(len(l["pannes"]) for l in lots.values())
        print(f"\n(essai à blanc — relancer avec --appliquer pour retirer les {total})")
