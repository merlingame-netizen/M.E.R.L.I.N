#!/usr/bin/env python3
"""Retirer de Décider ce qui n'a jamais été une décision.

Deux formes de faux choix s'y accumulent, toutes deux mesurées sur la VM.

**Les pannes d'atelier.** 19 propositions en attente dont 18 identiques —
« Professeur du modèle — analyse seule sur <biome> (JSON illisible) ». L'agent
qui écrit les cartes d'entraînement tournait toutes les 30 minutes ; à chaque
échec du modèle il déposait une proposition « preuves seules ». Ces cartes ne
servent qu'à ENTRAÎNER le modèle : leur échec est une panne, pas un choix.

**Les cartes réussies bloquées par la forme.** 19 cartes valides, zéro erreur,
et toutes le même unique reproche : un texte de 34-38 mots pour une cible qui
commence à 40. La porte d'auto-intégration exigeait ZÉRO avertissement, donc
aucune ne passait — 19 gestes demandés à Maxime pour un réglage de style. Ces
cartes-là ne sont pas retirées : elles sont INTÉGRÉES, par le même chemin que la
chaîne (`proposals.decide`), pour rejoindre réellement le corpus.

Les deux causes sont corrigées en amont (`runner.py` ne propose plus rien sur une
carte ratée, et sa porte accepte les écarts de forme). Ce module rattrape ce qui
a déjà été écrit — et LUI ne devine rien : il revalide, ou reconnaît une
signature d'échec exacte.

    python3 tools/gd_agents/menage.py            # ce qu'il FERAIT
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
# Le validateur de cartes vit avec le reste de l'outillage LoRA ; c'est lui qui
# tranche ce qui mérite l'attention de Maxime (voir `soft_only`).
sys.path.insert(0, str(HERE.parents[1] / "tools" / "lora"))
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


def _forme_seulement(d: dict) -> tuple[bool, str]:
    """Cette carte n'attend-elle QUE pour un écart de forme ?

    On ne se fie pas au verdict enregistré : il ne gardait que le NOMBRE
    d'avertissements, jamais leur texte. On revalide la charge utile — c'est le
    même appel que celui de la chaîne, donc le même jugement, sans copie de
    règles. En cas de doute (validateur absent, charge utile perdue), on répond
    NON : une carte reste une décision de Maxime tant qu'on n'a pas vérifié."""
    if d.get("kind") != "content" or not d.get("payload"):
        return False, ""
    try:
        import scenario_validator as sv
    except Exception:
        return False, ""
    try:
        errs, warns = sv.validate_card(d["payload"])
    except Exception:
        return False, ""
    if errs or not sv.soft_only(warns):
        return False, ""
    return True, (str(warns[0])[:70] if warns else "")


def inspecter() -> dict:
    lots = {}
    for nom, dossier in (("en attente", PROP.INBOX), ("acceptées", PROP.ACCEPTED)):
        pannes, formes, vraies = [], [], []
        for p in sorted(dossier.glob("*.json")) if dossier.exists() else []:
            d = PROP._read(p) or {}
            if _est_panne(d):
                pannes.append((p, d))
                continue
            # Une carte que la chaîne intégrerait aujourd'hui n'a rien à faire
            # dans Décider : elle y est parce que la porte exigeait zéro
            # avertissement, et que 19 cartes sur 19 étaient trop courtes de
            # cinq mots. On les fait passer par le MÊME chemin que la chaîne.
            ok, motif = (_forme_seulement(d) if dossier == PROP.INBOX else (False, ""))
            (formes if ok else vraies).append((p, d, motif) if ok else (p, d))
        lots[nom] = {"pannes": pannes, "formes": formes, "vraies": vraies}
    return lots


def rapport(lots: dict) -> str:
    out = []
    for nom, lot in lots.items():
        out.append(f"{nom} : {len(lot['pannes'])} panne(s) technique(s) à retirer, "
                   f"{len(lot['formes'])} carte(s) à intégrer seule(s), "
                   f"{len(lot['vraies'])} vraie(s) proposition(s) conservée(s)")
        for _p, d in lot["vraies"][:6]:
            out.append(f"   ✓ GARDÉ  {d.get('title','')[:78]}")
        for _p, d, motif in lot["formes"][:3]:
            out.append(f"   → intégrée {d.get('title','')[:56]} ({motif[:34]})")
        if len(lot["formes"]) > 3:
            out.append(f"   … et {len(lot['formes']) - 3} autre(s) carte(s) valide(s)")
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
            # `decided_at` et `source` MANQUAIENT, et c'est ce qui faisait
            # raconter au journal « Tu as rejeté une proposition » vingt-cinq
            # fois, étalé de 8 h à 16 h : faute de date de décision, il retombait
            # sur la date de CRÉATION de chaque proposition, et faute de source,
            # il attribuait le geste à Maxime.
            d["decided_at"] = PROP._now()
            d["source"] = "menage"
            d.setdefault("trail", []).append(
                {"t": PROP._now(), "step": "écartée",
                 "detail": "ménage : échec d'écriture, pas un sujet"})
            PROP.REJECTED.mkdir(parents=True, exist_ok=True)
            (PROP.REJECTED / p.name).write_text(
                json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
            p.unlink(missing_ok=True)
            n += 1
    # Les cartes valides passent par `PROP.decide` — le MÊME chemin que la
    # chaîne. Écrire nous-mêmes dans `accepted/` sauterait l'ajout au corpus, la
    # trace en mémoire et le parcours horodaté : la carte serait « acceptée »
    # sans jamais rejoindre le jeu d'entraînement.
    k = 0
    for lot in lots.values():
        for p, d, motif in lot.get("formes", []):
            raison = ("auto : contenu validé, seule la forme du texte s'écarte "
                      f"de la cible ({motif})" if motif
                      else "auto : contenu validé sans erreur ni avertissement")
            res = PROP.decide(d.get("id", p.stem), "accept", raison)
            if not res.get("error"):
                k += 1
    bilan = [f"{n} proposition(s) retirée(s) de Décider (conservées dans rejected/)"]
    if k:
        bilan.append(f"{k} carte(s) intégrée(s) seule(s) au corpus d'entraînement")
    return " · ".join(bilan)


if __name__ == "__main__":
    lots = inspecter()
    print(rapport(lots))
    if "--appliquer" in sys.argv:
        print(appliquer(lots))
    else:
        pannes = sum(len(l["pannes"]) for l in lots.values())
        formes = sum(len(l["formes"]) for l in lots.values())
        print(f"\n(essai à blanc — relancer avec --appliquer pour retirer {pannes} "
              f"panne(s) et intégrer {formes} carte(s))")
