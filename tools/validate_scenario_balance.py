#!/usr/bin/env python3
"""Validateur d'equilibrage des scenarios MERLIN contre les scenarios types.

Depuis le canon v4.0 (2026-07-26) un scenario est LINEAIRE : `cards` est la
sequence jouee, de `length` cartes, et le branchement est narratif (la
resolution de chaque carte varie selon l'etat accumule). La validation
structurelle s'applique donc a cette sequence unique.

Compatibilite ascendante : les fixtures de l'ancien modele a 3 routes
(ordre / chaos / liminal) restent validables — si le scenario porte un tableau
`routes`, chaque route est projetee et validee comme un chemin joue.

Verifications contre `data/ai/scenario_templates.json` :

  STRUCTURE (par route) — longueur canonique, caps de card types, adjacence,
      distribution de rarete, presence + placement du LEGENDAIRE (dernier 30%),
      climax (derniere carte) LEGENDAIRE + MERLIN_DIRECT
  ECRITURE (pool + arc) — titre, arc emotionnel (ouverture curiosite, pas de
      repetition consecutive, finale sagesse/peur/emerveillement), summaries
      8-22 mots (agrege), options (3, verbes 1 mot, factions distinctes)
  EQUILIBRE — diversite des factions sur les options (anti mono-build),
      budget de danger analytique EV par acte (danger_modifier d'archetype)

Sortie : score 0-100 par scenario + rapport agrege optionnel. Exit 1 si un
scenario passe sous --min-score (defaut 60).

Usage :
  python tools/validate_scenario_balance.py
  python tools/validate_scenario_balance.py --report docs/30_jdr/SCENARIO_BALANCE_REPORT.md
  python tools/validate_scenario_balance.py --file autre.json --min-score 80
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

SEVERITY_POINTS = {"error": 10, "warn": 3}
MAX_OCCURRENCES_PER_CODE = 2  # au-dela, un code repete ne re-penalise plus


def load_json(path: Path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


class Finding:
    __slots__ = ("severity", "code", "message")

    def __init__(self, severity: str, code: str, message: str):
        self.severity = severity
        self.code = code
        self.message = message

    def __str__(self) -> str:
        return f"[{self.severity.upper()}] {self.code}: {self.message}"


def route_paths(s: dict):
    """[(route_key, [card dict, ...]), ...] — chemins joues, dans l'ordre.

    Canon v4.0 : un seul chemin, la sequence `cards` elle-meme. Les anciennes
    fixtures a 3 routes restent supportees tant qu'elles portent `routes`.
    """
    cards = s.get("cards", [])
    if not s.get("routes"):
        return [("lineaire", list(cards))]
    idx = {c.get("card_id"): c for c in cards}
    out = []
    for r in s.get("routes", []):
        path = [idx[cid] for cid in r.get("card_ids", []) if cid in idx]
        out.append((r.get("key", "?"), path))
    return out


def branching_abandoned(tpl: dict) -> bool:
    br = tpl["structure_constraints"].get("branching", {})
    return "routes" not in br or str(br.get("_statut", "")).startswith("ABANDONNE")


# ---------------------------------------------------------------- structure --

def check_structure(s: dict, tpl: dict, findings: list):
    st = tpl["structure_constraints"]
    n = int(s.get("length", 0))

    if n not in st["canonical_lengths"]:
        findings.append(Finding("warn", "LEN_NON_CANON",
                                f"longueur {n} hors {st['canonical_lengths']}"))

    arch = tpl["archetypes"].get(s.get("archetype_id", ""), {})
    if arch:
        if s.get("pole_dominant") != arch["pole_dominant"]:
            findings.append(Finding("error", "POLE_ARCH",
                                    f"pole {s.get('pole_dominant')} != canon {arch['pole_dominant']}"))
        if s.get("twist_pattern") != arch["twist_pattern"]:
            findings.append(Finding("error", "TWIST_ARCH",
                                    f"twist {s.get('twist_pattern')} != canon {arch['twist_pattern']}"))
        if arch.get("length_bias") and n not in arch["length_bias"]:
            findings.append(Finding("warn", "LEN_BIAS",
                                    f"longueur {n} hors bias archetype {arch['length_bias']}"))
    else:
        findings.append(Finding("error", "ARCH_UNKNOWN",
                                f"archetype_id inconnu: {s.get('archetype_id')}"))

    paths = route_paths(s)
    if branching_abandoned(tpl):
        # Canon v4.0 : sequence unique. Porter encore des routes est une erreur
        # de modele, pas seulement un ecart de compte.
        if s.get("routes"):
            findings.append(Finding("error", "ROUTES_OBSOLETES",
                                    f"{len(s['routes'])} routes de topologie — le "
                                    "branchement est narratif depuis le 2026-07-26"))
    elif len(paths) != st["branching"]["routes"]:
        findings.append(Finding("error", "ROUTES_COUNT",
                                f"{len(paths)} routes != {st['branching']['routes']}"))
    else:
        keys = sorted(k for k, _ in paths)
        if keys != sorted(st["branching"]["route_poles"]):
            findings.append(Finding("error", "ROUTES_POLES", f"routes {keys}"))

    caps = st["card_type_caps"]
    no_repeat = set(st["no_repeat_cardtypes"])
    targets = st["rarity_targets"]

    for key, path in paths:
        pn = len(path)
        if pn != n:
            findings.append(Finding("error", "ROUTE_LEN",
                                    f"route {key} = {pn} cartes != length {n}"))
            continue

        # Caps de card types sur le chemin joue
        types = Counter(c.get("type") for c in path)
        narr_share = types.get("NARRATIVE", 0) / pn
        lo, hi = caps["NARRATIVE"]["min_share"], caps["NARRATIVE"]["max_share"]
        if not (lo <= narr_share <= hi + 1e-9):
            findings.append(Finding("warn", "NARR_SHARE",
                                    f"route {key}: part NARRATIVE {narr_share:.2f} hors [{lo}, {hi}]"))
        for ct, rule in caps.items():
            if "min_count" not in rule:
                continue
            cnt = types.get(ct, 0)
            if cnt < rule["min_count"]:
                findings.append(Finding("warn", f"{ct}_MIN",
                                        f"route {key}: {ct}={cnt} < min {rule['min_count']}"))
            if cnt > rule["max_count"]:
                findings.append(Finding("error", f"{ct}_MAX",
                                        f"route {key}: {ct}={cnt} > max {rule['max_count']}"))

        # Adjacence sur le chemin joue
        for a, b in zip(path, path[1:]):
            if a.get("type") == b.get("type") and a.get("type") in no_repeat:
                findings.append(Finding("error", "ADJACENCY",
                                        f"route {key}: 2x {a.get('type')} consecutifs"))

        # Rarete sur le chemin joue
        rar = Counter(c.get("rarity") for c in path)
        for r, share in targets.items():
            actual = rar.get(r, 0) / pn
            if abs(actual - share) > 0.15:
                findings.append(Finding("warn", "RARITY_DRIFT",
                                        f"route {key}: {r} {actual:.2f} vs cible {share:.2f}"))

        # LEGENDAIRE : present, place dans le dernier 30%, climax final
        threshold = math.ceil(pn * st["legendary_start_share"])
        leg_pos = [i + 1 for i, c in enumerate(path) if c.get("rarity") == "LEGENDAIRE"]
        if not leg_pos:
            findings.append(Finding("error", "NO_LEGENDARY",
                                    f"route {key}: aucune carte LEGENDAIRE sur le chemin"))
        else:
            for p in leg_pos:
                if p < threshold:
                    findings.append(Finding("error", "LEGENDARY_EARLY",
                                            f"route {key}: LEGENDAIRE en {p}/{pn} < seuil {threshold}"))
        last = path[-1]
        if last.get("rarity") != st["climax_rarity"]:
            findings.append(Finding("error", "CLIMAX_RARITY",
                                    f"route {key}: climax {last.get('rarity')} != {st['climax_rarity']}"))
        if last.get("type") != st["climax_card_type"]:
            findings.append(Finding("warn", "CLIMAX_TYPE",
                                    f"route {key}: climax type {last.get('type')} != {st['climax_card_type']}"))


# ------------------------------------------------------------------ writing --

def check_writing(s: dict, tpl: dict, findings: list):
    w = tpl["writing_constraints"]
    cards = s.get("cards", [])
    n = int(s.get("length", 0))

    title = str(s.get("title", ""))
    title_words = len(title.split())
    if not (w["title"]["min_words"] <= title_words <= w["title"]["max_words"]):
        findings.append(Finding("warn", "TITLE_WORDS",
                                f"titre '{title}' = {title_words} mots"))
    if len(title) > w["title"]["max_chars"]:
        findings.append(Finding("error", "TITLE_CHARS", "titre > 60 caracteres"))

    arc = s.get("emotional_arc", [])
    if len(arc) != n:
        findings.append(Finding("warn", "ARC_LEN",
                                f"emotional_arc {len(arc)} != length {n}"))
    if arc:
        if arc[0] not in w["first_beat_emotions"]:
            findings.append(Finding("warn", "ARC_OPEN", f"ouverture '{arc[0]}'"))
        if arc[-1] not in w["final_beat_emotions"]:
            findings.append(Finding("error", "ARC_FINAL",
                                    f"finale '{arc[-1]}' hors {w['final_beat_emotions']}"))
        bad = [e for e in arc if e not in w["emotions_allowed"]]
        if bad:
            findings.append(Finding("error", "ARC_VOCAB",
                                    f"emotions inconnues {sorted(set(bad))}"))
        if w["emotion_no_repeat_consecutive"]:
            repeats = sum(1 for a, b in zip(arc, arc[1:]) if a == b)
            if repeats:
                findings.append(Finding("warn", "ARC_REPEAT",
                                        f"{repeats} repetitions consecutives d'emotion"))

    # Verifications par carte, agregees en part du pool.
    # `summary` = identite courte du beat (8-22 mots) ; `text` = la situation
    # lue a l'ecran (18-38 mots). Les deux champs ne se substituent pas : une
    # carte qui n'a que l'un des deux est mesuree sur celui qu'elle porte.
    opt_rule = w["options"]
    smin, smax = w["beat_summary"]["min_words"], w["beat_summary"]["max_words"]
    ct_rule = w.get("card_text")
    total = max(len(cards), 1)
    bad_summary = bad_text = bad_verbs = bad_factions = 0
    for c in cards:
        if c.get("summary"):
            sw = len(str(c["summary"]).split())
            if not (smin <= sw <= smax):
                bad_summary += 1
        if ct_rule and c.get("text"):
            tw = len(str(c["text"]).split())
            if not (ct_rule["min_words"] <= tw <= ct_rule["max_words"]):
                bad_text += 1
        elif ct_rule and not c.get("summary"):
            findings.append(Finding("error", "NO_SITUATION",
                                    f"carte {c.get('card_id')}: ni `text` ni `summary` "
                                    "— le beat 1 de card_grammar est absent"))
        opts = c.get("options", [])
        if c.get("type") == "MERLIN_DIRECT" and not opts:
            continue  # climax/twist : Merlin parle, pas de choix standard
        if len(opts) != opt_rule["count"]:
            findings.append(Finding("error", "OPT_COUNT",
                                    f"carte {c.get('card_id')} a {len(opts)} options"))
            continue
        if any(len(str(o.get("verb", "")).split()) != 1 for o in opts):
            bad_verbs += 1
        if opt_rule["distinct_primary_factions"]:
            if len({o.get("primary_faction") for o in opts}) < 3:
                bad_factions += 1

    if bad_summary / total > 0.15:
        findings.append(Finding("warn", "SUMMARY_LEN",
                                f"{bad_summary}/{total} summaries hors [{smin}-{smax}] mots (> 15%)"))
    if ct_rule and bad_text / total > 0.15:
        findings.append(Finding("warn", "CARD_TEXT_LEN",
                                f"{bad_text}/{total} situations hors "
                                f"[{ct_rule['min_words']}-{ct_rule['max_words']}] mots (> 15%)"))
    if bad_verbs:
        findings.append(Finding("warn", "OPT_VERB", f"{bad_verbs} cartes avec verbe multi-mots"))
    if bad_factions / total > 0.15:
        findings.append(Finding("warn", "OPT_FACTIONS",
                                f"{bad_factions}/{total} cartes sans 3 factions distinctes"))


# ------------------------------------------------- voyageur & continuite --

def _sans_accents(txt: str) -> str:
    table = str.maketrans("aaaaeeeeiiiooouuuc", "aaaaeeeeiiiooouuuc")
    out = []
    for ch in txt.lower():
        out.append({"à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e",
                    "ë": "e", "î": "i", "ï": "i", "ô": "o", "ö": "o", "û": "u",
                    "ù": "u", "ü": "u", "ç": "c"}.get(ch, ch))
    return "".join(out).translate(table)


MOTS_VIDES = {
    "le", "la", "les", "un", "une", "des", "du", "de", "au", "aux", "et", "ou",
    "que", "qui", "quoi", "dont", "ce", "cet", "cette", "ces", "son", "sa", "ses",
    "ton", "ta", "tes", "mon", "ma", "mes", "il", "elle", "on", "tu", "je", "nous",
    "vous", "ils", "elles", "pas", "ne", "plus", "est", "sont", "etre", "avoir",
    "dans", "sur", "sous", "pour", "par", "avec", "sans", "vers", "chez", "comme",
    "mais", "donc", "car", "si", "quand", "tout", "toute", "tous", "toutes", "en",
    "y", "a", "d", "l", "s", "n", "c", "j", "t", "m", "qu", "se", "sa", "leur",
    "leurs", "plus", "moins", "tres", "bien", "encore", "deja", "rien", "fait",
}


def mots_concrets(txt: str) -> set:
    """Mots porteurs de reference : lieu, objet, temoin, trace."""
    import re as _re
    return {w for w in _re.findall(r"[a-zA-Z\u00c0-\u017f]+", _sans_accents(txt))
            if len(w) > 3 and w not in MOTS_VIDES}


def check_voyageur_et_continuite(s: dict, tpl: dict, findings: list):
    """Bible §33 — le voyageur n'a pas de passe, et les cartes ne sautent rien."""
    w = tpl["writing_constraints"].get("voyageur", {})
    interdits = [_sans_accents(x) for x in w.get("interdit", [])]
    cards = s.get("cards", [])

    # 33.1 — aucun passe partage. On scanne intro, hook, essence et tous les textes.
    zones = [("intro", s.get("intro", "")), ("hook", s.get("hook", "")),
             ("essence", s.get("essence", ""))]
    for c in cards:
        cid = c.get("card_id", "?")
        zones.append((f"{cid}.text", c.get("text", c.get("summary", ""))))
        for i, o in enumerate(c.get("options", [])):
            zones.append((f"{cid}.opt{i}.outcome", o.get("outcome", "")))
            zones.append((f"{cid}.opt{i}.outcome_fail", o.get("outcome_fail", "")))
            for v in o.get("outcome_variants", []):
                zones.append((f"{cid}.opt{i}.variante", v.get("texte", "")))
    for nom, txt in zones:
        plat = _sans_accents(str(txt))
        for motif in interdits:
            if motif and motif in plat:
                findings.append(Finding("error", "MEMOIRE_INTERDITE",
                                        f"{nom}: « {motif} » — le voyageur ne connait "
                                        "personne et n'a pas de passe ici (bible §33.1)"))

    # 33.2 — continuite : chaque carte partage un element concret avec la precedente.
    for a, b in zip(cards, cards[1:]):
        ta = str(a.get("text", a.get("summary", "")))
        tb = str(b.get("text", b.get("summary", "")))
        # Les resolutions de la carte A font partie du fil : c'est d'elles que
        # part la carte B — la reussite comme l'echec, puisque le joueur a lu
        # l'une des deux.
        for o in a.get("options", []):
            ta += " " + str(o.get("outcome", "")) + " " + str(o.get("outcome_fail", ""))
        if not (mots_concrets(ta) & mots_concrets(tb)):
            findings.append(Finding("error", "CONTINUITE_ROMPUE",
                                    f"{b.get('card_id')}: aucun element concret partage "
                                    f"avec {a.get('card_id')} — ellipse (bible §33.2)"))


# ------------------------------------------------------------------ balance --

def act_of(idx: int, n: int) -> int:
    """Index de carte (0-based) sur un chemin de n cartes -> acte 0..4."""
    return min(idx * 5 // max(n, 1), 4)


def check_balance(s: dict, tpl: dict, findings: list, stats_out: dict):
    bal = tpl["balance_model"]
    arch = tpl["archetypes"].get(s.get("archetype_id", ""), {})
    danger_mod = arch.get("danger_modifier", 1.0)
    heal_mod = arch.get("heal_modifier", 1.0)

    # Diversite des factions sur les options du POOL (anti mono-build)
    fac = Counter(o.get("primary_faction")
                  for c in s.get("cards", []) for o in c.get("options", []))
    total_opts = sum(fac.values())
    if total_opts:
        for f in ("druides", "anciens", "korrigans", "niamh", "ankou"):
            share = fac.get(f, 0) / total_opts
            stats_out.setdefault("faction_shares", defaultdict(list))[f].append(share)
            if share < 0.08:
                findings.append(Finding("warn", "FACTION_STARVED",
                                        f"faction {f} = {share:.0%} des options (< 8%) — "
                                        "build associe sous-nourri"))
        dru = fac.get("druides", 0) / total_opts
        if dru > 0.30:
            findings.append(Finding("warn", "FACTION_DRUID_HEAVY",
                                    f"druides = {dru:.0%} des options (> 30%)"))

    # Budget de danger analytique par route (first-run stats=1, pass 60%)
    mix = bal["check_mix_global"]
    dmg = bal["check_damage_on_fail"]
    heal = bal["heal_policy"]
    mults = bal["act_danger_multipliers"]
    p_fail = 0.40
    ev_fail_dmg = (mix["white"] * sum(dmg["white"]) / 2
                   + mix["contextuel"] * sum(dmg["contextuel"]) / 2
                   + mix["red"] * sum(dmg["red"]) / 2)
    for key, path in route_paths(s):
        pn = len(path)
        if pn == 0:
            continue
        exp_damage = sum(p_fail * ev_fail_dmg * mults[act_of(i, pn)] * danger_mod
                         for i in range(pn))
        p_succ = 1 - p_fail
        ev_heal_card = p_succ * (heal["success_heal_share"] * sum(heal["success_heal_amount"]) / 2
                                 + 0.10 * heal["critical_heal_amount"]) * heal_mod
        n_shops = sum(1 for c in path if c.get("type") == "SHOP")
        exp_heal = ev_heal_card * pn + n_shops * heal["shop_heal_ev"] * heal_mod

        scale = pn / 25.0
        lo, hi = bal["danger_budget_25_cards"]["expected_gross_damage"]
        # L'enveloppe cible est definie a danger_modifier 1.0 : on la scale par
        # le modifier d'archetype (sinon faux positifs sur les archetypes doux).
        lo, hi = lo * danger_mod, hi * danger_mod
        if not (lo * scale * 0.6 <= exp_damage <= hi * scale * 1.4):
            findings.append(Finding("warn", "DANGER_BUDGET",
                                    f"route {key}: EV degats {exp_damage:.0f} PV hors "
                                    f"[{lo * scale * 0.6:.0f}-{hi * scale * 1.4:.0f}] "
                                    f"(len {pn}, mod {danger_mod})"))
        stats_out.setdefault("net_attrition", []).append(
            (exp_damage - exp_heal) / scale if scale else 0)


# ------------------------------------------------------------------- strict --

def pv_eq(effects: list, rates: dict) -> float:
    total = 0.0
    for e in effects or []:
        t, amt = e.get("type"), e.get("amount", 0)
        if t == "HEAL_LIFE":
            total += amt * rates["life"]
        elif t == "DAMAGE_LIFE":
            total -= amt * rates["life"]
        elif t == "ADD_REPUTATION":
            total += amt * rates["reputation_point"]
        elif t == "ADD_ESSENCE":
            total += amt * rates["essence"]
        elif t == "ADD_ANAM":
            total += amt * rates["anam"]
    return total


def check_strict(s: dict, tpl: dict, findings: list):
    """Contrôles de la couche mécanique enrichie : checks, gradient, effets, EV.

    Ne s'applique qu'aux scénarios qui portent ces champs (golden fixture,
    sorties futures du pipeline). Un scénario sans champ `check` est signalé
    une seule fois, pas carte par carte.
    """
    bal = tpl["balance_model"]
    schema = bal["check_schema"]
    wl = bal["effects_whitelist"]
    rates = bal["exchange_rates_pv_equivalent"]
    gates = bal["check_act_gates"]
    mix = bal["check_mix_global"]
    grad_ev = bal["option_gradient_ev"]
    hardest = {"white": 0, "contextuel": 1, "red": 2, "fatal": 3}

    cards = s.get("cards", [])
    with_check = [c for c in cards
                  if any("check" in o for o in c.get("options", []))]
    if not with_check:
        findings.append(Finding("error", "NO_CHECK_LAYER",
                                "aucune option ne porte de champ `check` — la couche "
                                "mecanique (stats/gradient/effets) est absente"))
        return

    for c in cards:
        cid = c.get("card_id", f"n{c.get('n')}")
        act = int(c.get("act") or (min((int(c.get("n", 1)) - 1) // 5 + 1, 5)))
        opts = c.get("options", [])
        for i, o in enumerate(opts):
            # Gradient : ordre canonique prudente / equilibree / audacieuse
            g = o.get("gradient")
            if g and i < len(schema["gradient_order"]) and g != schema["gradient_order"][i]:
                findings.append(Finding("error", "GRADIENT_ORDER",
                                        f"{cid} opt{i}: gradient '{g}' != "
                                        f"'{schema['gradient_order'][i]}'"))
            ck = o.get("check")
            if not ck:
                findings.append(Finding("error", "OPT_NO_CHECK", f"{cid} opt{i}: pas de check"))
                continue
            if ck.get("stat") not in schema["stats"]:
                findings.append(Finding("error", "CHECK_STAT",
                                        f"{cid} opt{i}: stat '{ck.get('stat')}' inconnue"))
            ctype = ck.get("type")
            if ctype not in schema["types"]:
                findings.append(Finding("error", "CHECK_TYPE",
                                        f"{cid} opt{i}: type '{ctype}' inconnu"))
                continue
            # Act gates
            if ctype == "red" and not gates.get(f"act_{act}", {}).get("red", False):
                findings.append(Finding("error", "CHECK_GATE_RED",
                                        f"{cid} opt{i}: check red en acte {act} (interdit)"))
            if ctype == "fatal" and not gates.get(f"act_{act}", {}).get("fatal", False):
                findings.append(Finding("error", "CHECK_GATE_FATAL",
                                        f"{cid} opt{i}: check fatal en acte {act} (interdit)"))
            # L'option prudente ne porte jamais mieux que white
            if g == "prudente" and hardest[ctype] > hardest[schema["prudente_max_check"]]:
                findings.append(Finding("error", "GRADIENT_CONTRADICTION",
                                        f"{cid}: option prudente avec check {ctype}"))
            # Telegraphie obligatoire des checks red/fatal
            if ctype in schema["telegraphed_required_for"] and not ck.get("telegraphed"):
                findings.append(Finding("warn", "CHECK_NOT_TELEGRAPHED",
                                        f"{cid} opt{i}: check {ctype} non telegraphe"))

            # Beat 3 de la grammaire de carte : la resolution. Sans elle, le
            # joueur agit et rien ne lui repond — c'est le manquement constate
            # en jeu le 2026-07-26 (« on creuse avec precaution » suivi de rien).
            outcome = str(o.get("outcome", "")).strip()
            if not outcome:
                findings.append(Finding("error", "NO_OUTCOME",
                                        f"{cid} opt{i}: aucune resolution narree "
                                        "(card_grammar, beat 3)"))
            elif any(ch.isdigit() for ch in outcome):
                findings.append(Finding("warn", "OUTCOME_CHIFFRE",
                                        f"{cid} opt{i}: la resolution contient un chiffre — "
                                        "l'effet doit se lire dans la scene"))

            # Beat 3bis : la resolution d'echec. Sans elle, le moteur affiche le
            # texte de la reussite apres un echec d'epreuve — le systeme de
            # checks ment au joueur.
            fail = str(o.get("outcome_fail", "")).strip()
            if not fail:
                findings.append(Finding("error", "NO_OUTCOME_FAIL",
                                        f"{cid} opt{i}: aucune resolution d'echec narree "
                                        "(card_grammar, beat 3bis)"))
            elif any(ch.isdigit() for ch in fail):
                findings.append(Finding("warn", "OUTCOME_FAIL_CHIFFRE",
                                        f"{cid} opt{i}: la resolution d'echec contient un chiffre"))
            elif fail == outcome:
                findings.append(Finding("error", "OUTCOME_FAIL_IDENTIQUE",
                                        f"{cid} opt{i}: echec et reussite racontent la meme chose"))

            # Effets : whitelist, caps, nombre
            eff = o.get("effects", [])
            if len(eff) > tpl["writing_constraints"]["options"]["max_effects_per_option"]:
                findings.append(Finding("error", "EFFECTS_COUNT",
                                        f"{cid} opt{i}: {len(eff)} effets (max 3)"))
            for e in eff:
                t = e.get("type")
                if t not in wl["types"]:
                    findings.append(Finding("error", "EFFECT_NOT_WHITELISTED",
                                            f"{cid} opt{i}: effet '{t}' hors whitelist"))
                    continue
                cap = wl["amount_caps"].get(t)
                if cap is not None and abs(int(e.get("amount", 0))) > cap:
                    findings.append(Finding("error", "EFFECT_CAP",
                                            f"{cid} opt{i}: {t} {e.get('amount')} > cap {cap}"))

        # Ecart d'EV entre options (les options fatales sont exemptees)
        evs = []
        for o in opts:
            ck = o.get("check") or {}
            if ck.get("type") == "fatal" and schema.get("fatal_ev_exempt"):
                continue
            evs.append(0.6 * pv_eq(o.get("effects"), rates)
                       - 0.4 * float(ck.get("fail_damage", 0)))
        if len(evs) >= 2:
            gap = max(evs) - min(evs)
            if gap > grad_ev["max_ev_gap_between_options"] + 1e-9:
                findings.append(Finding("warn", "EV_GAP",
                                        f"{cid}: ecart d'EV {gap:.2f} > "
                                        f"{grad_ev['max_ev_gap_between_options']} PV-eq"))

    # Mix des checks PAR CARTE et espacement des red, sur chaque route jouee
    for key, path in route_paths(s):
        if not path:
            continue
        per_card = []
        for c in path:
            types = [(o.get("check") or {}).get("type", "white") for o in c.get("options", [])]
            per_card.append(max(types, key=lambda t: hardest.get(t, 0)) if types else "white")
        counts = Counter(per_card)
        for t, target in mix.items():
            if t.startswith("_"):
                continue
            actual = counts.get(t, 0) / len(path)
            if abs(actual - target) > 0.10:
                findings.append(Finding("warn", "CHECK_MIX",
                                        f"route {key}: checks '{t}' {actual:.0%} vs cible "
                                        f"{target:.0%} (tolerance 10 pts)"))
        red_pos = [i for i, t in enumerate(per_card) if t == "red"]
        for a, b in zip(red_pos, red_pos[1:]):
            if b - a < 3:
                findings.append(Finding("error", "RED_SPACING",
                                        f"route {key}: 2 checks red en {a + 1} et {b + 1} "
                                        "(< 3 cartes d'ecart)"))

        # Anti-safe-spam : l'option prudente ne doit pas etre optimale plus de
        # 2 fois par acte (sinon le joueur peut jouer safe en boucle).
        by_act = defaultdict(list)
        for i, c in enumerate(path):
            by_act[min(i * 5 // len(path), 4)].append(c)
        for act_i, act_cards in by_act.items():
            best_prudente = 0
            for c in act_cards:
                evs, prud_ev = [], None
                for o in c.get("options", []):
                    ck = o.get("check") or {}
                    if ck.get("type") == "fatal":
                        continue
                    ev = 0.6 * pv_eq(o.get("effects"), rates) - 0.4 * float(ck.get("fail_damage", 0))
                    evs.append(ev)
                    if o.get("gradient") == "prudente":
                        prud_ev = ev
                if evs and prud_ev is not None and prud_ev >= max(evs) - 1e-9:
                    best_prudente += 1
            if best_prudente > 2:
                findings.append(Finding("warn", "SAFE_SPAM",
                                        f"route {key} acte {act_i + 1}: l'option prudente est "
                                        f"optimale sur {best_prudente}/5 cartes (max 2)"))


# -------------------------------------------------------------------- main --

def score_findings(findings: list) -> int:
    per_code = Counter()
    pts = 0
    for f in findings:
        per_code[f.code] += 1
        if per_code[f.code] <= MAX_OCCURRENCES_PER_CODE:
            pts += SEVERITY_POINTS[f.severity]
    return max(0, 100 - pts)


def validate(scenarios: list, tpl: dict, strict: bool = False):
    results = []
    agg = {}
    for s in scenarios:
        findings: list = []
        check_structure(s, tpl, findings)
        check_writing(s, tpl, findings)
        check_voyageur_et_continuite(s, tpl, findings)
        check_balance(s, tpl, findings, agg)
        if strict:
            check_strict(s, tpl, findings)
        results.append({"id": s.get("id"), "archetype": s.get("archetype_id"),
                        "length": s.get("length"), "score": score_findings(findings),
                        "findings": findings})
    return results, agg


def render_report(results: list, agg: dict, tpl: dict) -> str:
    lines = ["# Rapport d'equilibrage — Scenarios types MERLIN", ""]
    lines.append(f"> Genere par `tools/validate_scenario_balance.py` contre "
                 f"`data/ai/scenario_templates.json` v{tpl['_meta']['version']}. "
                 f"{len(results)} scenarios valides (validation PAR ROUTE : le pool "
                 "branchant est projete sur les 3 chemins ordre/chaos/liminal).")
    lines.append("")
    scores = [r["score"] for r in results]
    lines.append(f"**Score moyen : {sum(scores) / len(scores):.1f}/100** — "
                 f"min {min(scores)}, max {max(scores)}.")
    lines.append("")

    code_counts = Counter(f.code for r in results for f in r["findings"])
    sev_by_code = {f.code: f.severity for r in results for f in r["findings"]}
    lines.append("## Findings par frequence")
    lines.append("")
    lines.append("| Code | Severite | Occurrences | Scenarios touches |")
    lines.append("|---|---|---:|---:|")
    touched = Counter()
    for r in results:
        for code in {f.code for f in r["findings"]}:
            touched[code] += 1
    for code, cnt in code_counts.most_common(20):
        lines.append(f"| {code} | {sev_by_code[code]} | {cnt} | {touched[code]} |")
    lines.append("")

    if "faction_shares" in agg:
        lines.append("## Equite deck-building : part des factions sur les options")
        lines.append("")
        lines.append("Chaque faction nourrit un build de stat (Logic=druides, "
                     "Empathie=niamh, Volonte=anciens, Instinct=korrigans). Une faction "
                     "sous 8% affame le build associe.")
        lines.append("")
        lines.append("| Faction | Part moyenne | Statut |")
        lines.append("|---|---:|---|")
        for f, shares in agg["faction_shares"].items():
            m = sum(shares) / len(shares)
            statut = "OK"
            if f == "druides" and m > 0.30:
                statut = "SUR-REPRESENTEE (> 30%)"
            elif m < 0.08:
                statut = "SOUS-NOURRIE (< 8%)"
            lines.append(f"| {f} | {m:.1%} | {statut} |")
        lines.append("")

    if "net_attrition" in agg:
        vals = sorted(agg["net_attrition"])
        mid = vals[len(vals) // 2]
        lines.append("## Attrition nette EV first-run (normalisee 25 cartes)")
        lines.append("")
        lines.append(f"p50 = **{mid:.0f} PV** (min {vals[0]:.0f} / max {vals[-1]:.0f}) — "
                     "cible : vie finale p50 dans "
                     f"{tpl['balance_model']['danger_budget_25_cards']['target_final_life_p50_first_run']} "
                     "=> attrition 30-45 PV.")
        lines.append("")

    by_arch = defaultdict(list)
    for r in results:
        by_arch[r["archetype"]].append(r["score"])
    lines.append("## Score par archetype")
    lines.append("")
    lines.append("| Archetype | Score moyen | N |")
    lines.append("|---|---:|---:|")
    for a, ss in sorted(by_arch.items(), key=lambda kv: -sum(kv[1]) / len(kv[1])):
        lines.append(f"| {a} | {sum(ss) / len(ss):.1f} | {len(ss)} |")
    lines.append("")

    worst = sorted(results, key=lambda r: r["score"])[:5]
    lines.append("## 5 scenarios les plus faibles")
    lines.append("")
    for r in worst:
        lines.append(f"### {r['id']} ({r['archetype']}, {r['length']} cartes) — {r['score']}/100")
        for f in r["findings"][:10]:
            lines.append(f"- {f}")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", default=str(REPO / "data/ai/scenarios_reference_broceliande.json"))
    ap.add_argument("--templates", default=str(REPO / "data/ai/scenario_templates.json"))
    ap.add_argument("--report", default=None, help="Chemin du rapport markdown a ecrire")
    ap.add_argument("--min-score", type=int, default=60)
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--strict", action="store_true",
                    help="Valide aussi la couche mecanique enrichie : checks de stats, "
                         "act gates, gradient, effets et ecarts d'EV (golden fixture).")
    args = ap.parse_args()

    tpl = load_json(Path(args.templates))
    data = load_json(Path(args.file))
    scenarios = data if isinstance(data, list) else list(data.get("scenarios", {}).values())

    results, agg = validate(scenarios, tpl, strict=args.strict)

    if not args.quiet:
        for r in results:
            errs = sum(1 for f in r["findings"] if f.severity == "error")
            warns = len(r["findings"]) - errs
            print(f"{r['id']:<14} {str(r['archetype']):<22} len={r['length']:<3} "
                  f"score={r['score']:>3}  ({errs} err, {warns} warn)")
    scores = [r["score"] for r in results]
    print(f"\n=== {len(results)} scenarios — score moyen {sum(scores) / len(scores):.1f} "
          f"(min {min(scores)}, max {max(scores)}) ===")

    if args.report:
        Path(args.report).write_text(render_report(results, agg, tpl), encoding="utf-8")
        print(f"Rapport ecrit : {args.report}")

    failing = [r for r in results if r["score"] < args.min_score]
    if failing:
        print(f"ECHEC : {len(failing)} scenario(s) sous le score minimal {args.min_score}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
