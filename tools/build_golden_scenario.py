#!/usr/bin/env python3
"""Générateur de scénario type — squelette mécanique déterministe.

Un « scénario type » MERLIN se décompose en deux couches :

  MÉCANIQUE (ce script)  — graphe de cartes, routes, types, raretés, arc
      émotionnel, pôles, factions, checks, effets chiffrés. Entièrement
      dérivée du contrat `data/ai/scenario_templates.json` : reproductible,
      auditable, garantie conforme au validateur.
  PROSE (couche suivante) — titre, intro, hook, summaries, labels d'options.
      Écrite par le LLM (ou à la main) et injectée dans les emplacements
      laissés par ce script via `--merge-prose`.

Le squelette produit est le **golden fixture** du projet : il doit scorer
100/100 à `validate_scenario_balance.py --strict`. Il sert de :
  - référence d'écriture (few-shot injecté dans les prompts LLM),
  - fixture de non-régression du validateur,
  - cible de conformité pour le pipeline in-game.

Structure d'un scénario 25 cartes (5 actes × 5), 3 routes isométriques :

    Acte I   n1-n5    TRONC commun (n5 = carte d'aiguillage → 3 pôles)
    Acte II  n6-n10   BRANCHE 1 (×3 pôles)          — SHOP + PROMISE
    Acte III n11      TWIST (convergence commune, EPIQUE MERLIN_DIRECT)
             n12-n15  BRANCHE 2 (×3 pôles)
    Acte IV  n16-n20  BRANCHE 2 (suite)             — SHOP 2 + RUNE_UNLOCK
    Acte V   n21-n25  CONVERGENCE finale commune    — climax LEGENDAIRE

    → 25 cartes par route, pool de 53 cartes (56 % de contenu branché).

Usage :
  python tools/build_golden_scenario.py --out data/ai/scenario_golden_broceliande.json
  python tools/build_golden_scenario.py --prose-slots /tmp/slots.json   # gabarits à remplir
  python tools/build_golden_scenario.py --merge-prose /tmp/prose.json --out ...
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TPL_PATH = REPO / "data/ai/scenario_templates.json"

POLES = ["ordre", "chaos", "liminal"]
POLE_TITLE = {"ordre": "Ordre", "chaos": "Chaos", "liminal": "Liminal"}

# Faction → stat affine (bible §25.1). L'Ankou n'a pas de stat dédiée : il
# agit comme modificateur global, ses options testent Volonté par défaut.
FACTION_STAT = {
    "druides": "logic",
    "niamh": "empathie",
    "anciens": "volonte",
    "korrigans": "instinct",
    "ankou": "volonte",
    "neutre": "logic",
}

# ── Plan de 25 cartes : type, rareté, émotion, segment ────────────────────
# segment : trunk | b1 | twist | b2 | conv
# Compte des types (par route) : NARRATIVE 15 (60 %), EVENT 3, SHOP 2,
# MERLIN_DIRECT 3, PROMISE 1, RUNE_UNLOCK 1 → tous dans les caps du contrat.
# Raretés : COMMUNE 17 (68 %), RARE 5 (20 %), EPIQUE 2 (8 %), LEGENDAIRE 1 (4 %).
PLAN_25 = [
    # n, type,            rarity,       emotion,          segment
    (1,  "NARRATIVE",     "COMMUNE",    "curiosite",      "trunk"),
    (2,  "NARRATIVE",     "COMMUNE",    "fascination",    "trunk"),
    (3,  "EVENT",         "COMMUNE",    "tension",        "trunk"),
    (4,  "NARRATIVE",     "COMMUNE",    "fascination",    "trunk"),
    (5,  "NARRATIVE",     "COMMUNE",    "curiosite",      "trunk"),   # aiguillage
    (6,  "SHOP",          "COMMUNE",    "emerveillement", "b1"),
    (7,  "NARRATIVE",     "COMMUNE",    "tension",        "b1"),
    (8,  "NARRATIVE",     "COMMUNE",    "fascination",    "b1"),
    (9,  "PROMISE",       "RARE",       "tension",        "b1"),
    (10, "NARRATIVE",     "COMMUNE",    "emerveillement", "b1"),
    (11, "MERLIN_DIRECT", "EPIQUE",     "fascination",    "twist"),
    (12, "NARRATIVE",     "COMMUNE",    "tension",        "b2"),
    (13, "EVENT",         "RARE",       "emerveillement", "b2"),
    (14, "NARRATIVE",     "COMMUNE",    "tension",        "b2"),
    (15, "NARRATIVE",     "COMMUNE",    "fascination",    "b2"),
    (16, "NARRATIVE",     "COMMUNE",    "emerveillement", "b2"),
    (17, "SHOP",          "RARE",       "tension",        "b2"),
    (18, "NARRATIVE",     "COMMUNE",    "fascination",    "b2"),
    (19, "EVENT",         "RARE",       "tension",        "b2"),
    (20, "RUNE_UNLOCK",   "RARE",       "emerveillement", "b2"),
    (21, "NARRATIVE",     "COMMUNE",    "tension",        "conv"),
    (22, "NARRATIVE",     "COMMUNE",    "fascination",    "conv"),
    (23, "MERLIN_DIRECT", "EPIQUE",     "emerveillement", "conv"),
    (24, "NARRATIVE",     "COMMUNE",    "tension",        "conv"),
    (25, "MERLIN_DIRECT", "LEGENDAIRE", "sagesse",        "conv"),
]

# ── Dégâts d'échec par acte et par type de check ──────────────────────────
# Réalise la rampe de danger [0.6, 0.8, 1.0, 1.3, 1.6] SANS jamais dépasser
# le cap DAMAGE_LIFE (-15) : la montée passe par le montant, pas par un
# multiplicateur runtime qui ferait sauter le cap.
FAIL_DAMAGE = {
    1: {"white": 3, "contextuel": 7, "red": 12, "fatal": 15},
    2: {"white": 3, "contextuel": 7, "red": 12, "fatal": 15},
    3: {"white": 4, "contextuel": 8, "red": 13, "fatal": 15},
    4: {"white": 4, "contextuel": 9, "red": 14, "fatal": 15},
    5: {"white": 5, "contextuel": 9, "red": 15, "fatal": 15},
}

# Variance du gradient À TYPE DE CHECK ÉGAL : la prudente encaisse moins,
# l'audacieuse plus. Clampé dans la bande du type (white 3-5, contextuel 7-9,
# red 12-15) — c'est ce qui donne de la variance sans multiplier les checks
# durs, et ce qui garde le mix par carte conforme (voir ci-dessous).
GRADIENT_DAMAGE_DELTA = {"prudente": -1, "equilibree": 0, "audacieuse": +1}
DAMAGE_BAND = {"white": (3, 5), "contextuel": (7, 9), "red": (12, 15), "fatal": (15, 15)}

# Mix des checks PAR CARTE (contrat : white 75 % / contextuel 15 % / red 8 % /
# fatal 2 %). Une carte est dite « contextuelle / red / fatale » si son option
# audacieuse porte ce check ; toutes les autres cartes sont intégralement white.
# 25 cartes → 18 white (72 %), 4 contextuel (16 %), 2 red (8 %), 1 fatal (4 %).
CONTEXTUEL_CARDS = {9, 14, 17, 22}
RED_CARDS = {13, 19}          # actes III et IV — jamais 2 dans 3 cartes
FATAL_CARDS = {25}            # climax, acte V — télégraphié, détectable (saille)

# Coût conventionnel d'un échec fatal en PV-équivalent (perte du reste du run).
# Sert uniquement au calcul d'EV ; une option fatale est un pari assumé et est
# exemptée de la bande d'EV du gradient (exception documentée, spec §3).
FATAL_EV_PENALTY = 35.0

# Trios de factions par carte (n) : 3 factions distinctes, équité globale.
# Cibles : druides ≤ 30 %, chaque faction ≥ 8 % des options du pool.
FACTION_TRIOS = {
    1:  ["druides", "anciens", "korrigans"],
    2:  ["anciens", "niamh", "druides"],
    3:  ["korrigans", "druides", "ankou"],
    4:  ["druides", "niamh", "anciens"],
    5:  ["anciens", "korrigans", "niamh"],
    6:  ["druides", "korrigans", "anciens"],
    7:  ["niamh", "anciens", "ankou"],
    8:  ["druides", "ankou", "korrigans"],
    9:  ["anciens", "druides", "niamh"],
    10: ["korrigans", "niamh", "druides"],
    11: ["druides", "anciens", "ankou"],
    12: ["niamh", "korrigans", "anciens"],
    13: ["anciens", "ankou", "druides"],
    14: ["druides", "niamh", "korrigans"],
    15: ["korrigans", "anciens", "niamh"],
    16: ["niamh", "druides", "ankou"],
    17: ["anciens", "korrigans", "druides"],
    18: ["druides", "ankou", "niamh"],
    19: ["korrigans", "anciens", "ankou"],
    20: ["niamh", "druides", "anciens"],
    21: ["anciens", "niamh", "korrigans"],
    22: ["druides", "korrigans", "ankou"],
    23: ["ankou", "anciens", "druides"],
    24: ["niamh", "ankou", "korrigans"],
    25: ["druides", "anciens", "niamh"],
}

GRADIENTS = ["prudente", "equilibree", "audacieuse"]


def act_of(n: int) -> int:
    """Acte 1..5 d'une carte n (1..25) — 5 actes égaux."""
    return min((n - 1) // 5 + 1, 5)


def pv_eq(effects: list, rates: dict) -> float:
    """Valeur d'une liste d'effets en PV-équivalent."""
    total = 0.0
    for e in effects:
        t, amt = e["type"], e.get("amount", 0)
        if t in ("HEAL_LIFE", "DAMAGE_LIFE"):
            total += (amt if t == "HEAL_LIFE" else -amt) * rates["life"]
        elif t == "ADD_REPUTATION":
            total += amt * rates["reputation_point"]
        elif t == "ADD_ESSENCE":
            total += amt * rates["essence"]
        elif t == "ADD_ANAM":
            total += amt * rates["anam"]
    return total


def build_success_effects(n: int, gradient: str, faction: str, card_type: str,
                          act: int, rates: dict, caps: dict) -> list:
    """Effets de réussite, calibrés pour que l'EV tombe dans la bande du gradient.

    Résout S (payoff en PV-éq) depuis EV = 0.6·S − 0.4·D, puis exprime S en
    effets concrets (réputation d'abord, essence/soin en complément), en
    restant sous les caps de la whitelist §5.4.
    """
    check_type = check_for(n, gradient, act)
    damage = fail_damage_for(check_type, gradient, act)
    cost = FATAL_EV_PENALTY if check_type == "fatal" else float(damage)
    target_ev = {"prudente": 0.8, "equilibree": 1.25, "audacieuse": 1.7}[gradient]
    needed = (target_ev + 0.4 * cost) / 0.6  # PV-éq de réussite visés

    effects: list = []
    remaining = needed

    # 1. Réputation de la faction alignée (cap ±20/carte).
    rep = min(int(round(remaining / rates["reputation_point"])), caps["ADD_REPUTATION"])
    rep = max(rep, 1)
    effects.append({"type": "ADD_REPUTATION", "faction": faction, "amount": rep})
    remaining -= rep * rates["reputation_point"]

    # 2. Complément : essence sur les SHOP, soin sur les cartes de repos,
    #    Anam sur le climax — jamais plus de 3 effets par option.
    if remaining > 0.5 and len(effects) < caps["effects_per_option"]:
        if card_type == "SHOP":
            ess = min(int(round(remaining / rates["essence"])), caps["ADD_ESSENCE"])
            if ess >= 1:
                effects.append({"type": "ADD_ESSENCE", "amount": ess})
                remaining -= ess * rates["essence"]
        elif card_type in ("MERLIN_DIRECT", "RUNE_UNLOCK"):
            anam = min(int(round(remaining / rates["anam"])), 8)
            if anam >= 1:
                effects.append({"type": "ADD_ANAM", "amount": anam})
                remaining -= anam * rates["anam"]
        else:
            heal = min(int(round(remaining / rates["life"])), caps["HEAL_LIFE"])
            if heal >= 1:
                effects.append({"type": "HEAL_LIFE", "amount": heal})
                remaining -= heal * rates["life"]

    return effects


def check_for(n: int, gradient: str, act: int) -> str:
    """Type de check d'une option — act gates + placement red/fatal du contrat.

    Seule l'option audacieuse peut porter un check plus dur que white, et
    seulement sur les cartes désignées. Une option prudente n'est JAMAIS red
    (anti-pattern « gradient contredit »).
    """
    if gradient == "audacieuse":
        if n in FATAL_CARDS and act >= 4:
            return "fatal"
        if n in RED_CARDS and act >= 3:
            return "red"
        if n in CONTEXTUEL_CARDS:
            return "contextuel"
    return "white"


def fail_damage_for(check_type: str, gradient: str, act: int) -> int:
    base = FAIL_DAMAGE[act][check_type]
    lo, hi = DAMAGE_BAND[check_type]
    return max(lo, min(hi, base + GRADIENT_DAMAGE_DELTA[gradient]))


def assign_stats(cards: list, stat_mix: dict) -> None:
    """Affecte la stat testée de chaque option pour atteindre le stat_mix.

    La faction porte l'alignement narratif, la stat porte ce que l'option met
    à l'épreuve : les deux sont corrélés mais pas identiques. On sert d'abord
    la stat affine de la faction tant qu'il reste du quota, puis la stat la
    plus déficitaire. Déterministe (ordre de parcours fixe).
    """
    options = [o for c in cards for o in c["options"]]
    total = len(options)
    quota = {s: int(round(share * total)) for s, share in stat_mix.items()}
    # Ajuste l'arrondi sur la stat dominante.
    drift = total - sum(quota.values())
    dominant = max(stat_mix, key=lambda s: stat_mix[s])
    quota[dominant] += drift

    used = {s: 0 for s in quota}
    for o in options:
        pref = FACTION_STAT[o["primary_faction"]]
        if used.get(pref, 0) < quota.get(pref, 0):
            chosen = pref
        else:
            chosen = max(quota, key=lambda s: quota[s] - used[s])
        used[chosen] += 1
        o["check"]["stat"] = chosen


def card_id_for(n: int, segment: str, pole: str | None) -> str:
    if segment == "trunk":
        return f"c{n}"
    if segment == "twist":
        return f"c{n}_twist"
    if segment == "conv":
        return f"c{n}"
    branch = "b1" if segment == "b1" else "b2"
    return f"c{n}_{pole}_{branch}"


def route_mask_for(segment: str, pole: str | None) -> list:
    if segment in ("trunk", "twist", "conv"):
        return [True, True, True]
    return [p == pole for p in POLES]


def build(tpl: dict, archetype_id: str, biome: str, scenario_id: str) -> dict:
    arch = tpl["archetypes"][archetype_id]
    bal = tpl["balance_model"]
    rates = bal["exchange_rates_pv_equivalent"]
    caps = bal["effects_caps"]

    cards: list = []
    routes = {p: [] for p in POLES}

    for (n, ctype, rarity, emotion, segment) in PLAN_25:
        act = act_of(n)
        trio = FACTION_TRIOS[n]
        # Les cartes branchées existent en 3 exemplaires (un par pôle).
        poles_for_card = POLES if segment in ("b1", "b2") else [None]

        for pole in poles_for_card:
            cid = card_id_for(n, segment, pole)
            card_pole = POLE_TITLE[pole] if pole else _common_pole(n, arch)

            options = []
            for i, gradient in enumerate(GRADIENTS):
                faction = trio[i]
                check_type = check_for(n, gradient, act)
                effects = build_success_effects(n, gradient, faction, ctype, act, rates, caps)
                opt = {
                    "label": f"<<{cid}.opt{i}.label>>",
                    "verb": f"<<{cid}.opt{i}.verb>>",
                    "gradient": gradient,
                    "primary_faction": faction,
                    "check": {
                        "stat": FACTION_STAT[faction],  # réaffecté par assign_stats
                        "type": check_type,
                        "fail_damage": fail_damage_for(check_type, gradient, act),
                        "telegraphed": check_type in ("red", "fatal"),
                    },
                    "effects": effects,
                }
                # Graphe de navigation. Seule la carte d'aiguillage (n=5) ouvre
                # des voies différentes selon l'option ; partout ailleurs les
                # trois options mènent à la même carte suivante — le choix pèse
                # sur l'état du joueur, pas sur la topologie.
                nxt = _next_n(n)
                if n == 5:
                    opt["leads_to_card_id"] = card_id_for(6, "b1", POLES[i])
                    opt["opens_route"] = POLES[i]
                elif segment == "twist":
                    # Successeur dépendant de la voie active : résolu au runtime
                    # via route_mask, pas exprimable sur une carte partagée.
                    opt["leads_to_rule"] = "next_in_active_route"
                elif nxt is not None:
                    nxt_seg = _segment_of(nxt)
                    nxt_pole = pole if nxt_seg in ("b1", "b2") else None
                    opt["leads_to_card_id"] = card_id_for(nxt, nxt_seg, nxt_pole)
                options.append(opt)

            cards.append({
                "n": n,
                "card_id": cid,
                "act": act,
                "type": ctype,
                "rarity": rarity,
                "pole": card_pole,
                "emotion": emotion,
                "segment": segment,
                "summary": f"<<{cid}.summary>>",
                "options": options,
                "route_mask": route_mask_for(segment, pole),
                "branch_label": "trunk" if segment in ("trunk", "conv") else (
                    "twist" if segment == "twist" else f"{pole}_{'b1' if segment == 'b1' else 'b2'}"),
            })

            for p in POLES:
                if route_mask_for(segment, pole)[POLES.index(p)]:
                    routes[p].append(cid)

    assign_stats(cards, arch["stat_mix"])

    scenario = {
        "id": scenario_id,
        "title": "<<title>>",
        "archetype_id": archetype_id,
        "archetype_name": arch["name"],
        "pole_dominant": arch["pole_dominant"],
        "twist_pattern": arch["twist_pattern"],
        "biome": biome,
        "length": 25,
        "pool_size": len(cards),
        "emotional_arc": [e for (_, _, _, e, _) in PLAN_25],
        "intro": "<<intro>>",
        "premise": "<<premise>>",
        "essence": "<<essence>>",
        "hook": "<<hook>>",
        "twist_card_id": "c11_twist",
        "cards": cards,
        "routes": [
            {"key": p, "name": f"Voie de l'{POLE_TITLE[p]}" if p == "ordre" else f"Voie du {POLE_TITLE[p]}"
             if p == "chaos" else "Voie Liminale",
             "label": f"<<route.{p}.label>>", "card_ids": routes[p]}
            for p in POLES
        ],
    }
    return scenario


def _common_pole(n: int, arch: dict) -> str:
    """Pôle des cartes communes : dominant de l'archétype ~50 %, sinon rotation."""
    dominant = arch["pole_dominant"]
    others = [p for p in ("Ordre", "Chaos", "Liminal") if p != dominant]
    if n % 2 == 1:
        return dominant
    return others[(n // 2) % len(others)]


def _segment_of(n: int) -> str:
    for (nn, _, _, _, seg) in PLAN_25:
        if nn == n:
            return seg
    return "conv"


def _next_n(n: int):
    return n + 1 if n < 25 else None


# ── Prose : extraction des emplacements / injection ───────────────────────

def prose_slots(scenario: dict) -> dict:
    """Gabarit à remplir par la couche prose (LLM ou humain)."""
    slots = {
        "_instructions": (
            "Remplis chaque valeur. Contraintes : summary 8-22 mots ; label ≤ 6 mots, "
            "sans chiffre ; verb = 1 verbe à l'infinitif. Français celtique, 2e personne, "
            "présent. Aucun anglicisme ni terme technique."
        ),
        "title": "",
        "intro": "",
        "premise": "",
        "essence": "",
        "hook": "",
        "routes": {r["key"]: "" for r in scenario["routes"]},
        "cards": {},
    }
    for c in scenario["cards"]:
        slots["cards"][c["card_id"]] = {
            "_context": {
                "n": c["n"], "acte": c["act"], "type": c["type"], "rarete": c["rarity"],
                "pole": c["pole"], "emotion": c["emotion"], "segment": c["segment"],
            },
            "summary": "",
            "options": [
                {"_gradient": o["gradient"], "_faction": o["primary_faction"],
                 "_check": f"{o['check']['stat']}/{o['check']['type']}",
                 "label": "", "verb": ""}
                for o in c["options"]
            ],
        }
    return slots


def merge_prose(scenario: dict, prose: dict) -> tuple:
    """Injecte la prose ; retourne (scenario, liste des emplacements manquants)."""
    missing = []
    for key in ("title", "intro", "premise", "essence", "hook"):
        val = str(prose.get(key, "")).strip()
        if val:
            scenario[key] = val
        else:
            missing.append(key)

    route_prose = prose.get("routes", {})
    for r in scenario["routes"]:
        val = str(route_prose.get(r["key"], "")).strip()
        if val:
            r["label"] = val
        else:
            missing.append(f"route.{r['key']}")

    card_prose = prose.get("cards", {})
    for c in scenario["cards"]:
        p = card_prose.get(c["card_id"])
        if not p:
            missing.append(f"{c['card_id']}.*")
            continue
        summ = str(p.get("summary", "")).strip()
        if summ:
            c["summary"] = summ
        else:
            missing.append(f"{c['card_id']}.summary")
        opts = p.get("options", [])
        for i, o in enumerate(c["options"]):
            po = opts[i] if i < len(opts) else {}
            lbl, vrb = str(po.get("label", "")).strip(), str(po.get("verb", "")).strip()
            if lbl:
                o["label"] = lbl
            else:
                missing.append(f"{c['card_id']}.opt{i}.label")
            if vrb:
                o["verb"] = vrb
            else:
                missing.append(f"{c['card_id']}.opt{i}.verb")
    return scenario, missing


def audit(scenario: dict, tpl: dict) -> None:
    """Contrôles internes rapides (le vrai audit est fait par le validateur)."""
    from collections import Counter
    rates = tpl["balance_model"]["exchange_rates_pv_equivalent"]
    idx = {c["card_id"]: c for c in scenario["cards"]}

    print(f"  pool         : {len(scenario['cards'])} cartes")
    for r in scenario["routes"]:
        path = [idx[cid] for cid in r["card_ids"]]
        t = Counter(c["type"] for c in path)
        rar = Counter(c["rarity"] for c in path)
        print(f"  route {r['key']:<8}: {len(path)} cartes | {dict(t)} | {dict(rar)}")

    fac = Counter(o["primary_faction"] for c in scenario["cards"] for o in c["options"])
    tot = sum(fac.values())
    print(f"  factions     : " + ", ".join(f"{f} {n / tot:.1%}" for f, n in fac.most_common()))
    st = Counter(o["check"]["stat"] for c in scenario["cards"] for o in c["options"])
    print(f"  stats testées: " + ", ".join(f"{s} {n / tot:.1%}" for s, n in st.most_common()))
    # Mix des checks PAR CARTE (le contrat s'exprime par carte, pas par option) :
    # une carte prend le type le plus dur porté par l'une de ses options.
    hardest = {"white": 0, "contextuel": 1, "red": 2, "fatal": 3}
    per_card = Counter()
    seen_n = set()
    for c in scenario["cards"]:
        if c["n"] in seen_n:
            continue          # une seule fois par position de route
        seen_n.add(c["n"])
        per_card[max((o["check"]["type"] for o in c["options"]),
                     key=lambda t: hardest[t])] += 1
    tot_cards = sum(per_card.values())
    print(f"  checks/carte : " + ", ".join(
        f"{t} {n}/{tot_cards} ({n / tot_cards:.0%})" for t, n in per_card.most_common())
        + "   [cible 75/15/8/2]")

    worst, worst_card = 0.0, ""
    for c in scenario["cards"]:
        evs = []
        for o in c["options"]:
            if o["check"]["type"] == "fatal":
                continue      # pari assumé, exempté de la bande (spec §3)
            evs.append(0.6 * pv_eq(o["effects"], rates) - 0.4 * o["check"]["fail_damage"])
        if len(evs) >= 2 and max(evs) - min(evs) > worst:
            worst, worst_card = max(evs) - min(evs), c["card_id"]
    print(f"  écart EV max : {worst:.2f} PV-éq sur {worst_card} (cap contrat : 2.0)")


ACT_ROLE_FR = {1: "Ouverture", 2: "Pacte", 3: "Épreuve", 4: "Bascule", 5: "Climax"}


def render_markdown(scenario: dict, tpl: dict) -> str:
    """Rend le scénario type sous forme lisible — document de référence humain."""
    from collections import Counter
    arch = tpl["archetypes"][scenario["archetype_id"]]
    idx = {c["card_id"]: c for c in scenario["cards"]}
    L = [f"# ᚛ {scenario['title']} ᚜", ""]
    L.append(f"> **Scénario type de référence** — archétype `{scenario['archetype_id']}` "
             f"({arch['name']}) · pôle {scenario['pole_dominant']} · twist "
             f"`{scenario['twist_pattern']}` · biome {scenario['biome']}.")
    L.append(">")
    L.append("> Généré par `tools/build_golden_scenario.py` : la couche mécanique est "
             "calculée depuis `data/ai/scenario_templates.json`, la prose est écrite "
             "par-dessus. Ce document est régénéré, pas édité à la main.")
    L.append("")
    L.append(f"**{scenario['length']} cartes par route · {scenario['pool_size']} cartes "
             f"au total · 3 voies isométriques.**")
    L.append("")
    L.append(f"*{scenario['essence']}*")
    L.append("")
    L.append("## Accroche")
    L.append("")
    L.append(f"> {scenario['hook']}")
    L.append("")
    L.append("## Intro (parchemin d'ouverture)")
    L.append("")
    L.append(scenario["intro"])
    L.append("")
    L.append("## Les trois voies")
    L.append("")
    for r in scenario["routes"]:
        L.append(f"- **{r['name']}** — {r['label']}")
    L.append("")

    L.append("## Structure")
    L.append("")
    L.append("| Acte | Rôle | Cartes | Contenu | Danger |")
    L.append("|---|---|---|---|---|")
    mults = tpl["balance_model"]["act_danger_multipliers"]
    for act in range(1, 6):
        act_cards = [c for c in scenario["cards"] if c["act"] == act and c["route_mask"][0]]
        types = Counter(c["type"] for c in act_cards)
        span = f"{min(c['n'] for c in act_cards)}–{max(c['n'] for c in act_cards)}"
        seg = act_cards[0]["segment"]
        seg_fr = {"trunk": "tronc commun", "b1": "branche 1 (×3 voies)",
                  "twist": "twist + branche 2", "b2": "branche 2 (×3 voies)",
                  "conv": "convergence commune"}.get(seg, seg)
        L.append(f"| {act} | {ACT_ROLE_FR[act]} | {span} | {seg_fr} — "
                 f"{', '.join(f'{n}×{t}' for t, n in types.most_common())} | ×{mults[act - 1]} |")
    L.append("")

    L.append("## Déroulé de la voie de l'Ordre")
    L.append("")
    L.append("*(les voies du Chaos et Liminale suivent la même ossature ; seules les "
             "cartes de branche diffèrent)*")
    L.append("")
    L.append("| # | Type | Rareté | Émotion | Situation | Épreuves |")
    L.append("|---|---|---|---|---|---|")
    for cid in scenario["routes"][0]["card_ids"]:
        c = idx[cid]
        checks = " · ".join(
            f"{o['check']['stat'][:3]}/{o['check']['type'][:4]}" for o in c["options"])
        L.append(f"| {c['n']} | {c['type']} | {c['rarity']} | {c['emotion']} | "
                 f"{c['summary']} | {checks} |")
    L.append("")

    L.append("## Le twist")
    L.append("")
    tw = idx[scenario["twist_card_id"]]
    L.append(f"Carte {tw['n']} — **{tw['rarity']} {tw['type']}** : {tw['summary']}")
    L.append("")
    for o in tw["options"]:
        L.append(f"- *{o['gradient']}* — **{o['label']}** (`{o['verb']}`, "
                 f"{o['primary_faction']}, épreuve {o['check']['stat']}/{o['check']['type']})")
    L.append("")

    L.append("## Équilibrage mesuré")
    L.append("")
    fac = Counter(o["primary_faction"] for c in scenario["cards"] for o in c["options"])
    st = Counter(o["check"]["stat"] for c in scenario["cards"] for o in c["options"])
    tot = sum(fac.values())
    L.append("| Dimension | Mesuré | Cible du contrat |")
    L.append("|---|---|---|")
    L.append("| Factions sur les options | "
             + ", ".join(f"{f} {n / tot:.0%}" for f, n in fac.most_common())
             + " | chacune ≥ 8 %, druides ≤ 30 % |")
    mix = arch["stat_mix"]
    L.append("| Stats mises à l'épreuve | "
             + ", ".join(f"{s} {n / tot:.0%}" for s, n in st.most_common())
             + " | " + ", ".join(f"{s} {v:.0%}" for s, v in mix.items()) + " |")
    hardest = {"white": 0, "contextuel": 1, "red": 2, "fatal": 3}
    per_card, seen = Counter(), set()
    for c in scenario["cards"]:
        if c["n"] in seen:
            continue
        seen.add(c["n"])
        per_card[max((o["check"]["type"] for o in c["options"]),
                     key=lambda t: hardest[t])] += 1
    L.append("| Épreuves par carte | "
             + ", ".join(f"{t} {n / 25:.0%}" for t, n in per_card.most_common())
             + " | white 75 %, contextuel 15 %, red 8 %, fatal 2 % |")
    L.append("")
    L.append("Conformité : `python tools/validate_scenario_balance.py "
             "--file data/ai/scenario_golden_broceliande.json --strict`")
    L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--templates", default=str(TPL_PATH))
    ap.add_argument("--archetype", default="forgotten_ritual")
    ap.add_argument("--biome", default="foret_broceliande")
    ap.add_argument("--id", default="golden_broc_ritual_25")
    ap.add_argument("--out", default=None)
    ap.add_argument("--prose-slots", default=None,
                    help="Écrit le gabarit de prose à remplir")
    ap.add_argument("--merge-prose", default=None,
                    help="Injecte un fichier de prose rempli")
    ap.add_argument("--markdown", default=None,
                    help="Écrit le rendu lisible du scénario (document de référence)")
    args = ap.parse_args()

    tpl = json.load(open(args.templates, encoding="utf-8"))
    scenario = build(tpl, args.archetype, args.biome, args.id)

    if args.merge_prose:
        prose = json.load(open(args.merge_prose, encoding="utf-8"))
        scenario, missing = merge_prose(scenario, prose)
        if missing:
            print(f"ATTENTION : {len(missing)} emplacements de prose non remplis")
            for m in missing[:15]:
                print(f"  - {m}")
            if len(missing) > 15:
                print(f"  ... et {len(missing) - 15} autres")

    print(f"=== Scénario type « {args.archetype} » — {args.biome} ===")
    audit(scenario, tpl)

    if args.prose_slots:
        Path(args.prose_slots).write_text(
            json.dumps(prose_slots(scenario), ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"Gabarit de prose écrit : {args.prose_slots}")

    if args.markdown:
        Path(args.markdown).write_text(render_markdown(scenario, tpl), encoding="utf-8")
        print(f"Rendu lisible écrit : {args.markdown}")

    if args.out:
        Path(args.out).write_text(
            json.dumps([scenario], ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Scénario écrit : {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
