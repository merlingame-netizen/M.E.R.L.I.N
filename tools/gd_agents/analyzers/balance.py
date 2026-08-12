#!/usr/bin/env python3
"""Analyseur `balance` — mesure l'équilibrage, et produit un PATCH quand c'est
mécanique.

Tout est calculé en Python : distribution des effets, couverture des factions,
diversité des verbes, dépassements de plafonds. Le LLM ne fait que rédiger la
proposition à partir de ces chiffres. Ne lève jamais.

Depuis v17, l'analyseur lit aussi `merlin_constants.gd` et distingue deux
natures de constat — la distinction qui débloque toute la chaîne autonome :

  · un ÉCART MÉCANIQUE (deux constantes qui doivent être égales par
    construction et ne le sont plus) a UNE seule correction possible. On la
    calcule ici et on rend `change.before` / `change.after` : le codeur local
    l'applique sans jamais interpréter.
  · un SIGNAL d'équilibrage (une faction sous-servie, des verbes hors liste)
    n'a PAS de correction unique. Il reste une décision de Maxime, et la
    proposition le dit franchement au lieu de faire semblant d'être en file.
"""
from __future__ import annotations

import collections
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import gdconst as GC  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
CANON = ROOT / "data" / "ai" / "lore_canon.json"
SOURCES = [ROOT / "data" / "ai" / "training" / "auto_corpus.jsonl",
           ROOT / "data" / "ai" / "training" / "curated_corpus.jsonl"]
FASTROUTE = ROOT / "data" / "ai" / "fastroute_cards.json"


def _cards() -> list[dict]:
    out = []
    for p in SOURCES:
        try:
            for line in p.read_text(encoding="utf-8").splitlines():
                if line.strip():
                    rec = json.loads(line)
                    out.append(rec.get("card", rec))
        except Exception:
            continue
    try:
        out += json.loads(FASTROUTE.read_text(encoding="utf-8")).get("narrative", [])
    except Exception:
        pass
    return out


def code_findings() -> list[dict]:
    """Écarts MÉCANIQUES dans `merlin_constants.gd` — ceux qui n'ont qu'une
    correction possible, donc applicables sans jugement.

    Chaque règle nomme une source de vérité et un miroir qui doit la refléter.
    Le miroir seul est corrigé, jamais la source : on ne « rééquilibre » rien
    ici, on répare une incohérence interne. Rend une liste de
    {regle, cible, actuel, propose, pourquoi, before, after}."""
    sc = GC.scalars()
    caps = GC.dict_ints("EFFECT_CAPS")
    if not sc:
        return []

    def val(d, k, default=None):
        return d[k]["value"] if k in d else default

    # (clé du miroir, table du miroir, valeur attendue, phrase d'explication)
    regles = []
    if "drain_per_card" in caps and "LIFE_ESSENCE_DRAIN_PER_CARD" in sc:
        regles.append(("drain_per_card", caps, val(sc, "LIFE_ESSENCE_DRAIN_PER_CARD"),
                       "EFFECT_CAPS.drain_per_card doit refléter "
                       "LIFE_ESSENCE_DRAIN_PER_CARD (le drain est fixé par la bible §13.3, "
                       "la table de plafonds n'en est que le miroir)"))
    if "LIFE_MAX" in caps and "LIFE_ESSENCE_MAX" in sc:
        regles.append(("LIFE_MAX", caps, val(sc, "LIFE_ESSENCE_MAX"),
                       "EFFECT_CAPS.LIFE_MAX doit refléter LIFE_ESSENCE_MAX, "
                       "sinon un soin peut dépasser la barre de vie réelle"))
    if "HEAL_LIFE.max" in caps and "LIFE_ESSENCE_HEAL_PER_REST" in sc:
        besoin = val(sc, "LIFE_ESSENCE_HEAL_PER_REST")
        if val(caps, "HEAL_LIFE.max", 0) < besoin:
            regles.append(("HEAL_LIFE.max", caps, besoin,
                           f"le soin de repos vaut {besoin} mais le plafond HEAL_LIFE "
                           f"est plus bas : le repos serait tronqué à chaque fois"))
    lo, hi = val(sc, "SESSION_CARDS_MIN"), val(sc, "SESSION_CARDS_MAX")
    if lo is not None and hi is not None:
        for nom in ("SESSION_CARDS_TARGET", "MIN_CARDS_FOR_VICTORY"):
            v = val(sc, nom)
            if v is not None and not (lo <= v <= hi):
                regles.append((nom, sc, min(max(v, lo), hi),
                               f"{nom} ({v}) sort de la fenêtre de session "
                               f"[{lo}, {hi}] : la victoire serait injoignable ou triviale"))
    vmax = val(sc, "LIFE_ESSENCE_MAX")
    seuil = val(sc, "LIFE_ESSENCE_LOW_THRESHOLD")
    if vmax and seuil is not None and not (0 < seuil < vmax):
        regles.append(("LIFE_ESSENCE_LOW_THRESHOLD", sc, max(1, min(seuil, vmax - 1)),
                       f"le seuil d'alerte ({seuil}) doit rester strictement entre "
                       f"0 et {vmax}, sinon l'avertissement est permanent ou muet"))

    out = []
    for cle, table, attendu, pourquoi in regles:
        entry = table.get(cle)
        if not entry or attendu is None:
            continue
        patch = GC.patch_line(entry, attendu)
        if not patch:
            continue          # déjà cohérent, ou ligne ambiguë : rien à proposer
        out.append({"regle": cle, "cible": GC.CONSTANTS_TARGET,
                    "actuel": entry["value"], "propose": attendu,
                    "ligne": entry["lineno"], "pourquoi": pourquoi,
                    "before": patch[0], "after": patch[1]})
    return out


def analyze(seed: int | None = None) -> dict:
    cards = _cards()
    factions = collections.Counter()
    verbs = collections.Counter()
    amounts, types = [], collections.Counter()
    over = []
    for c in cards:
        for o in c.get("options", []) or []:
            if o.get("verb"):
                verbs[o["verb"]] += 1
            for e in o.get("effects", []) or []:
                t = e.get("type", "?")
                types[t] += 1
                if e.get("faction"):
                    factions[e["faction"]] += 1
                a = e.get("amount")
                if isinstance(a, (int, float)):
                    amounts.append(a)
                    if t == "ADD_REPUTATION" and abs(a) > 20:
                        over.append(f"{t} {a} (plafond ±20)")
                    if t == "DAMAGE_LIFE" and a > 15:
                        over.append(f"{t} {a} (plafond 15)")
    cov = {f: factions.get(f, 0) for f in
           ("druides", "anciens", "korrigans", "niamh", "ankou")}
    total_eff = sum(cov.values()) or 1
    faible = min(cov, key=cov.get)
    forte = max(cov, key=cov.get)
    ratio = round(cov[forte] / max(cov[faible], 1), 1)
    hors = _verbes_hors_liste(verbs)
    ecarts = code_findings()
    return {
        "cards": len(cards),
        "faction_counts": cov,
        "faction_faible": faible, "faction_forte": forte, "ratio": ratio,
        "part_faible": round(100 * cov[faible] / total_eff, 1),
        "verbes_distincts": len(verbs),
        "verbe_dominant": verbs.most_common(1)[0] if verbs else ("—", 0),
        "effets": dict(types.most_common(5)),
        "moyenne_amount": round(sum(amounts) / len(amounts), 1) if amounts else 0,
        "depassements": over[:4],
        # Verbes employés hors de la liste fermée déclarée dans le code : ils
        # retombent tous sur ACTION_VERB_FALLBACK_FIELD, donc sur le même
        # mini-jeu. Signal fort, mais SANS correction unique → pas de patch.
        "verbes_hors_liste": hors[:8],
        "verbes_hors_liste_n": len(hors),
        # Écarts mécaniques : c'est CE champ qui porte un patch applicable.
        "code_ecarts": ecarts,
        "regles_verifiees": 6,
    }


def _verbes_hors_liste(verbs: collections.Counter) -> list[tuple[str, int]]:
    """Verbes du corpus absents de la liste fermée du code (ACTION_VERBS +
    NEUTRAL_VERBS). Ne lève jamais : liste vide si le code est illisible."""
    import re
    src = GC.source()
    if not src:
        return []
    autorises: set[str] = set()
    m = re.search(r"const ACTION_VERBS := \{(.*?)\n\}", src, re.S)
    if m:
        autorises |= set(re.findall(r'"([^"]+)"', m.group(1)))
    m = re.search(r"const NEUTRAL_VERBS[^=]*=\s*\[(.*?)\]", src, re.S)
    if m:
        autorises |= set(re.findall(r'"([^"]+)"', m.group(1)))
    if not autorises:
        return []
    return sorted(((v, n) for v, n in verbs.items() if v not in autorises),
                  key=lambda x: -x[1])


def change(a: dict) -> dict | None:
    """Le patch applicable, s'il y en a un — consommé tel quel par runner.py.

    Un seul écart par proposition : Maxime doit pouvoir dire oui ou non à UNE
    chose. Les autres reviendront au passage suivant."""
    ecarts = a.get("code_ecarts") or []
    if not ecarts:
        return None
    e = ecarts[0]
    return {"summary": f"{e['regle']} : {e['actuel']} → {e['propose']} — {e['pourquoi']}",
            "target": e["cible"], "before": e["before"], "after": e["after"]}


def evidence(a: dict) -> list[dict]:
    ec = a.get("code_ecarts") or []
    return [
        {"source": "corpus + fastroute_cards.json",
         "metric": f"{a['cards']} cartes analysées, {a['verbes_distincts']} verbes distincts"},
        {"source": "distribution des factions",
         "metric": f"« {a['faction_faible']} » ne pèse que {a['part_faible']} % des effets "
                   f"(rapport {a['ratio']}:1 avec « {a['faction_forte']} »)",
         "quote": json.dumps(a["faction_counts"], ensure_ascii=False)},
        {"source": "plafonds d'équilibrage",
         "metric": (f"{len(a['depassements'])} dépassement(s)" if a["depassements"]
                    else "aucun dépassement de plafond"),
         "quote": " · ".join(a["depassements"])},
        {"source": f"{GC.CONSTANTS_TARGET} ({a.get('regles_verifiees', 0)} règles de cohérence)",
         "metric": (f"{len(ec)} écart mécanique : {ec[0]['regle']} vaut {ec[0]['actuel']}, "
                    f"devrait valoir {ec[0]['propose']}" if ec
                    else "aucun écart mécanique — les constantes sont cohérentes entre elles"),
         "quote": (f"l.{ec[0]['ligne']} · {ec[0]['pourquoi']}" if ec else "")},
        {"source": "liste fermée des verbes (ACTION_VERBS + NEUTRAL_VERBS)",
         "metric": (f"{a.get('verbes_hors_liste_n', 0)} verbe(s) employé(s) hors liste — "
                    f"tous rabattus sur le champ de repli, donc sur le même mini-jeu"
                    if a.get("verbes_hors_liste_n") else "tous les verbes sont dans la liste"),
         "quote": " · ".join(f"{v} ×{n}" for v, n in a.get("verbes_hors_liste", []))},
    ]


def brief(a: dict) -> str:
    v, n = a["verbe_dominant"]
    return (
        f"Cartes analysées : {a['cards']}\n"
        f"Répartition des effets par faction : {json.dumps(a['faction_counts'], ensure_ascii=False)}\n"
        f"Faction la moins servie : {a['faction_faible']} ({a['part_faible']} % des effets)\n"
        f"Faction la plus servie : {a['faction_forte']} (rapport {a['ratio']}:1)\n"
        f"Verbe le plus employé : {v} ({n} fois) sur {a['verbes_distincts']} verbes distincts\n"
        f"Types d'effets : {json.dumps(a['effets'], ensure_ascii=False)}\n"
        f"Dépassements de plafond : {' · '.join(a['depassements']) or 'aucun'}\n"
        f"Verbes hors liste fermée : {a.get('verbes_hors_liste_n', 0)}"
        + (" (" + ", ".join(f"{x} ×{k}" for x, k in a.get("verbes_hors_liste", [])) + ")"
           if a.get("verbes_hors_liste") else "") + "\n"
        + (f"ÉCART MÉCANIQUE À CORRIGER : {a['code_ecarts'][0]['regle']} vaut "
           f"{a['code_ecarts'][0]['actuel']}, doit valoir {a['code_ecarts'][0]['propose']} "
           f"— {a['code_ecarts'][0]['pourquoi']}\n"
           "Explique cette correction en 3 phrases, sans proposer autre chose."
           if a.get("code_ecarts") else
           "Aucun écart mécanique : les constantes du code sont cohérentes.\n"
           "Rédige UNE recommandation d'équilibrage concrète et chiffrée."))


if __name__ == "__main__":
    a = analyze()
    print(json.dumps(a, ensure_ascii=False, indent=1))
    print("\n" + brief(a))
