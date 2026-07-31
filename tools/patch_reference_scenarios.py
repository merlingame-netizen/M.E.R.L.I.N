#!/usr/bin/env python3
"""Patch conservateur des 100 scenarios de reference Broceliande.

Aligne les METADONNEES (type / rarity) du corpus sur le contrat des scenarios
types (`data/ai/scenario_templates.json`) SANS toucher a la prose (title /
intro / premise / summaries / options). Les embeddings restent valides : ils
sont calcules sur title + archetype_name + intro uniquement
(cf. tools/embed_reference_scenarios.py).

Corrections appliquees, par scenario :
  1. CLIMAX     — la derniere carte (convergence commune aux 3 routes) devient
                  LEGENDAIRE + MERLIN_DIRECT (canon : climax legendaire).
  2. LEG_EARLY  — toute autre carte LEGENDAIRE situee avant 70% d'une route
                  est retrogradee en EPIQUE.
  3. RESPIRATION— si une route n'a aucune carte SHOP (resp. EVENT), une carte
                  NARRATIVE de l'acte II (resp. IV) est retypee, avec
                  preference aux summaries a mots-cles marchands/evenementiels.
  4. RARITES    — l'excedent d'EPIQUE (cible 8%) puis de RARE (cible 20%) est
                  retrograde (EPIQUE->RARE, RARE->COMMUNE), en partant des
                  cartes les plus precoces, twist et climax proteges.
  5. ADJACENCE  — garde-fou final : jamais 2 SHOP / MERLIN_DIRECT / RUNE_UNLOCK
                  consecutifs sur une route (retype en NARRATIVE si besoin).

Usage :
  python tools/patch_reference_scenarios.py --dry-run     # apercu
  python tools/patch_reference_scenarios.py               # applique (backup .bak)
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DATA = REPO / "data/ai/scenarios_reference_broceliande.json"
TPL = REPO / "data/ai/scenario_templates.json"

SHOP_KEYWORDS = ("troc", "échange", "echange", "marché", "marche", "offre",
                 "offrande", "don ", "présent", "present", "pacte", "prix",
                 "monnaie", "négoc", "negoc")
EVENT_KEYWORDS = ("soudain", "surgit", "éclate", "eclate", "tempête", "tempete",
                  "orage", "cri", "tremble", "s'effondre", "brusque", "jaillit",
                  "irruption", "alarme")


def act_of(idx: int, n: int) -> int:
    return min(idx * 5 // max(n, 1), 4)


def route_id_paths(s: dict):
    return [(r.get("key", "?"), list(r.get("card_ids", []))) for r in s.get("routes", [])]


def patch_scenario(s: dict, tpl: dict, stats: Counter) -> None:
    idx = {c.get("card_id"): c for c in s.get("cards", [])}
    paths = route_id_paths(s)
    if not paths or not s.get("cards"):
        return
    twist_id = s.get("twist_card_id")
    leg_share = tpl["structure_constraints"]["legendary_start_share"]

    # -- 1. Climax : derniere carte de chaque route -> LEGENDAIRE MERLIN_DIRECT
    last_ids = {ids[-1] for _, ids in paths if ids}
    for cid in last_ids:
        c = idx[cid]
        if c.get("rarity") != "LEGENDAIRE":
            c["rarity"] = "LEGENDAIRE"
            stats["climax_rarity_promoted"] += 1
        if c.get("type") != "MERLIN_DIRECT":
            c["type"] = "MERLIN_DIRECT"
            stats["climax_type_promoted"] += 1

    # -- 2. Legendaires precoces -> EPIQUE (position < 70% sur au moins 1 route)
    for key, ids in paths:
        n = len(ids)
        threshold = math.ceil(n * leg_share)
        for pos, cid in enumerate(ids, start=1):
            c = idx[cid]
            if cid in last_ids:
                continue
            if c.get("rarity") == "LEGENDAIRE" and pos < threshold:
                c["rarity"] = "EPIQUE"
                stats["legendary_demoted"] += 1

    # -- 3. Respiration : garantir >= 1 SHOP (acte II) et >= 1 EVENT (acte IV)
    for want_type, want_act, keywords in (("SHOP", 1, SHOP_KEYWORDS),
                                          ("EVENT", 3, EVENT_KEYWORDS)):
        for key, ids in paths:
            n = len(ids)
            types_on_path = {idx[cid].get("type") for cid in ids}
            if want_type in types_on_path:
                continue
            # Candidats : cartes NARRATIVE de l'acte vise, hors twist/climax
            candidates = [(pos, cid) for pos, cid in enumerate(ids)
                          if idx[cid].get("type") == "NARRATIVE"
                          and cid != twist_id and cid not in last_ids
                          and act_of(pos, n) == want_act]
            if not candidates:  # fallback : n'importe quel acte 1..3
                candidates = [(pos, cid) for pos, cid in enumerate(ids)
                              if idx[cid].get("type") == "NARRATIVE"
                              and cid != twist_id and cid not in last_ids
                              and 1 <= act_of(pos, n) <= 3]
            if not candidates:
                stats[f"{want_type.lower()}_unfixable"] += 1
                continue
            # Preference mots-cles, sinon milieu de l'acte
            scored = sorted(
                candidates,
                key=lambda pc: (0 if any(k in str(idx[pc[1]].get("summary", "")).lower()
                                         for k in keywords) else 1,
                                abs(pc[0] - (n * (want_act * 5 + 2) / 25.0))))
            _, chosen = scored[0]
            idx[chosen]["type"] = want_type
            stats[f"{want_type.lower()}_injected"] += 1

    # -- 4. Rarites : retrograder l'excedent EPIQUE puis RARE (pool-level)
    targets = tpl["structure_constraints"]["rarity_targets"]
    protected = set(last_ids) | ({twist_id} if twist_id else set())
    pool = s["cards"]
    total = len(pool)
    for src, dst, target_share in (("EPIQUE", "RARE", targets["EPIQUE"]),
                                   ("RARE", "COMMUNE", targets["RARE"])):
        have = [c for c in pool if c.get("rarity") == src
                and c.get("card_id") not in protected]
        target_cnt = round(target_share * total)
        excess = len(have) - target_cnt
        if excess <= 0:
            continue
        # Retrograder les plus precoces (n le plus petit) : la rarete monte
        # vers la fin du run (courbe StS).
        for c in sorted(have, key=lambda c: int(c.get("n", 0)))[:excess]:
            c["rarity"] = dst
            stats[f"{src.lower()}_demoted"] += 1

    # -- 5. Caps de types par route : MERLIN_DIRECT max 3 (climax protege),
    #       et part NARRATIVE <= 0.7 (injecter des EVENT supplementaires,
    #       cap EVENT = 4).
    caps = tpl["structure_constraints"]["card_type_caps"]
    md_max = caps["MERLIN_DIRECT"]["max_count"]
    ev_max = caps["EVENT"]["max_count"]
    narr_max_share = caps["NARRATIVE"]["max_share"]
    for key, ids in paths:
        n = len(ids)
        md_on_path = [cid for cid in ids if idx[cid].get("type") == "MERLIN_DIRECT"]
        excess = len(md_on_path) - md_max
        for cid in md_on_path:
            if excess <= 0:
                break
            if cid in last_ids or cid == twist_id:
                continue
            idx[cid]["type"] = "NARRATIVE"
            stats["merlin_direct_demoted"] += 1
            excess -= 1
        # Part NARRATIVE : retyper en EVENT (actes II-IV) jusqu'a <= 0.7
        while True:
            narr = [(pos, cid) for pos, cid in enumerate(ids)
                    if idx[cid].get("type") == "NARRATIVE"]
            ev_cnt = sum(1 for cid in ids if idx[cid].get("type") == "EVENT")
            if len(narr) / n <= narr_max_share + 1e-9 or ev_cnt >= ev_max:
                break
            candidates = [(pos, cid) for pos, cid in narr
                          if cid != twist_id and cid not in last_ids
                          and 1 <= act_of(pos, n) <= 3
                          and not _would_break_adjacency(idx, ids, pos, "EVENT")]
            if not candidates:
                break
            scored = sorted(candidates,
                            key=lambda pc: (0 if any(k in str(idx[pc[1]].get("summary", "")).lower()
                                                     for k in EVENT_KEYWORDS) else 1,
                                            abs(pc[0] - n * 0.55)))
            idx[scored[0][1]]["type"] = "EVENT"
            stats["event_injected_narr_share"] += 1

    # -- 5b. Fixpoint : les cartes partagees entre routes peuvent faire
    #        depasser le cap EVENT (4) sur une route voisine. On retrograde
    #        l'excedent (positions les plus precoces d'abord) en NARRATIVE,
    #        en gardant >= 1 EVENT par route.
    for _ in range(3):
        stable = True
        for key, ids in paths:
            ev_on_path = [(pos, cid) for pos, cid in enumerate(ids)
                          if idx[cid].get("type") == "EVENT"]
            excess = len(ev_on_path) - ev_max
            if excess <= 0:
                continue
            stable = False
            for pos, cid in ev_on_path:
                if excess <= 0:
                    break
                if cid in last_ids or cid == twist_id:
                    continue
                idx[cid]["type"] = "NARRATIVE"
                stats["event_excess_demoted"] += 1
                excess -= 1
        if stable:
            break

    # -- 6. Adjacence : pas 2 types uniques consecutifs sur une route
    no_repeat = set(tpl["structure_constraints"]["no_repeat_cardtypes"])
    for key, ids in paths:
        for a, b in zip(ids, ids[1:]):
            ca, cb = idx[a], idx[b]
            if ca.get("type") == cb.get("type") and ca.get("type") in no_repeat:
                victim = ca if a not in last_ids and a != twist_id else cb
                if victim.get("card_id") in last_ids or victim.get("card_id") == twist_id:
                    continue
                victim["type"] = "NARRATIVE"
                stats["adjacency_fixed"] += 1


def _would_break_adjacency(idx: dict, ids: list, pos: int, new_type: str) -> bool:
    """True si retyper ids[pos] en new_type creerait 2 types identiques adjacents."""
    for neighbor in (pos - 1, pos + 1):
        if 0 <= neighbor < len(ids) and idx[ids[neighbor]].get("type") == new_type:
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", default=str(DATA))
    ap.add_argument("--templates", default=str(TPL))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = Path(args.file)
    tpl = json.load(open(args.templates, encoding="utf-8"))
    scenarios = json.load(open(path, encoding="utf-8"))

    stats: Counter = Counter()
    for s in scenarios:
        patch_scenario(s, tpl, stats)

    print("=== Patch corpus — operations ===")
    for k, v in sorted(stats.items()):
        print(f"  {k:<28} {v}")
    if args.dry_run:
        print("(dry-run : rien n'a ete ecrit)")
        return 0

    backup = path.with_suffix(path.suffix + ".bak")
    shutil.copy2(path, backup)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(scenarios, fh, ensure_ascii=False, indent=2)
    print(f"Ecrit : {path} (backup : {backup})")
    return 0


if __name__ == "__main__":
    main()
