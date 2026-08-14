#!/usr/bin/env python3
"""
scenario_validator.py — deterministic hard-constraint gate for MERLIN scenario cards.

This is the FILTER stage of the hybrid scenario-generation flywheel (plan Add-on 5,
Phase B): every generated card/scenario must pass these *deterministic* checks before a
(more expensive) LLM judge ever scores it for diversity/coherence/twist. No LLM, no deps.

Canonical sources (single source of truth):
  - scripts/merlin/merlin_constants.gd : ACTION_VERBS (45), EFFECT_CAPS, FACTIONS
  - scripts/merlin/merlin_llm_adapter.gd : ALLOWED_EFFECT_TYPES
  - docs/50_lore/NARRATIVE_GUARDRAILS.md : banned terms
Values are mirrored below and can be overridden by data/ai/lore_canon.json
(scenario_constraints) once that canon exists.

Usage:
  python3 tools/lora/scenario_validator.py <file>            # scenario json / list / jsonl
  python3 tools/lora/scenario_validator.py <file> --strict   # warnings count as failures
  python3 tools/lora/scenario_validator.py --selftest
Exit code 0 = all cards pass (errors==0; with --strict also warnings==0).
"""
from __future__ import annotations
import json
import os
import re
import sys
import unicodedata

# ── canonical constants (mirror of the GDScript source of truth) ─────────────
ACTION_VERBS = {
    "chance": ["cueillir", "chercher au hasard", "tenter sa chance", "deviner", "fouiller a l'aveugle"],
    "bluff": ["marchander", "convaincre", "mentir", "negocier", "charmer", "amadouer"],
    "observation": ["observer", "scruter", "memoriser", "examiner", "fixer", "inspecter"],
    "logique": ["dechiffrer", "analyser", "resoudre", "decoder", "interpreter", "etudier"],
    "finesse": ["se faufiler", "esquiver", "contourner", "se cacher", "escalader", "traverser"],
    "vigueur": ["combattre", "courir", "fuir", "forcer", "pousser", "resister physiquement"],
    "esprit": ["calmer", "apaiser", "mediter", "resister mentalement", "se concentrer", "endurer"],
    "perception": ["ecouter", "suivre", "pister", "sentir", "flairer", "tendre l'oreille"],
    "neutre": ["parler", "accepter", "refuser", "attendre", "s'approcher"],
}
FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"]
ALLOWED_EFFECT_TYPES = [
    "ADD_REPUTATION", "PROGRESS_MISSION", "ADD_KARMA", "ADD_TENSION", "ADD_NARRATIVE_DEBT",
    "DAMAGE_LIFE", "HEAL_LIFE", "SET_FLAG", "ADD_TAG", "REMOVE_TAG", "TRIGGER_EVENT",
    "CREATE_PROMISE", "FULFILL_PROMISE", "BREAK_PROMISE", "ADD_ANAM", "ADD_BIOME_CURRENCY",
    "UNLOCK_OGHAM",
]
EFFECT_CAPS = {
    "ADD_REPUTATION": {"max": 20, "min": -20},
    "HEAL_LIFE": {"max": 18}, "HEAL_CRITICAL": {"max": 5},
    "DAMAGE_LIFE": {"max": 15}, "DAMAGE_CRITICAL": {"max": 22},
    "ADD_BIOME_CURRENCY": {"max": 10}, "UNLOCK_OGHAM": {"max_per_card": 1},
    "effects_per_option": 3,
}
# Banned terms (NARRATIVE_GUARDRAILS.md) + anachronism/4th-wall set (extended).
BANNED_HARD = ["fin du monde", "simulation", "ia", "programme", "serveur", "sauvegarde"]
BANNED_EXTENDED = ["spawn", "loot", "hub", "boss", "respawn", "checkpoint", "interface",
                   "pixel", "glitch", "buffer", "cyber", "neon"]
# Card text length (bible/narrative_writer target 40-120 words, 2-4 sentences).
WORDS_SOFT = (40, 120)
WORDS_HARD = (12, 160)
SENT_SOFT = (2, 4)
SENT_HARD = (1, 8)
JACCARD_MAX = 0.7


def _ascii(s: str) -> str:
    s = unicodedata.normalize("NFD", str(s))
    return "".join(c for c in s if unicodedata.category(c) != "Mn").lower().strip()


ALL_VERBS = {_ascii(v) for vs in ACTION_VERBS.values() for v in vs}


def _load_canon_overrides() -> None:
    """Best-effort: override constants from data/ai/lore_canon.json if present."""
    here = os.path.dirname(os.path.abspath(__file__))
    canon = os.path.normpath(os.path.join(here, "..", "..", "data", "ai", "lore_canon.json"))
    if not os.path.isfile(canon):
        return
    try:
        c = json.load(open(canon, encoding="utf-8")).get("scenario_constraints", {})
    except Exception:
        return
    global ALL_VERBS
    vbf = c.get("verbs_by_field")
    if isinstance(vbf, dict) and vbf:
        ALL_VERBS = {_ascii(v) for vs in vbf.values() for v in vs}
    fw = c.get("forbidden_words")
    if isinstance(fw, list) and fw:
        BANNED_HARD[:] = [_ascii(w) for w in fw]


# ── effect parsing ───────────────────────────────────────────────────────────
def _parse_effect(e):
    """Return (type, amount_or_None). Accepts dict or 'TYPE:faction:amount' string."""
    if isinstance(e, dict):
        amt = e.get("amount", e.get("delta", e.get("value")))
        try:
            amt = float(amt) if amt is not None else None
        except (TypeError, ValueError):
            amt = None
        return str(e.get("type", "")).upper(), amt, e.get("faction")
    if isinstance(e, str):
        parts = e.split(":")
        t = parts[0].upper()
        amt, fac = None, None
        if len(parts) == 3:
            fac = parts[1]
            try:
                amt = float(parts[2])
            except ValueError:
                amt = None
        elif len(parts) == 2:
            try:
                amt = float(parts[1])
            except ValueError:
                fac = parts[1]
        return t, amt, fac
    return "", None, None


def _sentences(text: str) -> int:
    return len([s for s in re.split(r"[.!?…]+", text) if s.strip()])


def _tokens(text: str):
    return set(re.findall(r"[a-z]+", _ascii(text)))


def jaccard(a: str, b: str) -> float:
    ta, tb = _tokens(a), _tokens(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


# ── card / scenario validation ───────────────────────────────────────────────
def _banned_hit(low: str, term: str) -> bool:
    """Word-boundary match so short/acronym terms (e.g. 'ia') don't match inside words."""
    return re.search(r"(?<![a-z])" + re.escape(term) + r"(?![a-z])", low) is not None


# Les deux seuls avertissements qui portent sur la FORME du texte : la longueur
# et le nombre de phrases s'écartent de la cible douce, tout en restant dans les
# bornes DURES (sinon ce serait une erreur, pas un avertissement). Tous les
# autres — terme anachronique, verbe hors des 45, répétition Jaccard — touchent
# au CONTENU et méritent un arbitrage humain.
_FORME = ("words outside target", "sentences outside target")


def soft_only(warns) -> bool:
    """Les avertissements ne portent-ils QUE sur la forme du texte ?

    Sert à décider ce qui mérite l'attention de Maxime. Mesuré sur la VM :
    19 cartes sur 19 attendaient une décision pour un texte de 34-38 mots là où
    la cible douce commence à 40 — un réglage de style, jamais un arbitrage.
    La liste est BLANCHE : un motif inconnu est considéré comme bloquant."""
    return all(any(f in str(w) for f in _FORME) for w in (warns or []))


def validate_card(card: dict, recent_texts=None):
    """Return (errors, warnings) for a single card dict.

    Two schemas are auto-detected:
      - RUNTIME card  : has `text` and/or option `effects` -> full rules (length, caps).
      - SKELETON card : reference dataset (`summary` + branching, no effects) -> structure
        only; word-count/effects checks are skipped (a summary is short by design).
    The 45-verb whitelist is a WARNING, not an error: the engine maps any out-of-list verb
    to 'esprit' (merlin_constants.gd ACTION_VERB_FALLBACK_FIELD).
    """
    errs, warns = [], []
    if not isinstance(card, dict):
        return ["card is not an object"], []
    cid = card.get("card_id", card.get("id", card.get("n", "?")))
    tag = f"card[{cid}]"
    opts = card.get("options", [])
    opts_list = opts if isinstance(opts, list) else []
    text = str(card.get("text", "") or "")
    has_effects = any(isinstance(o, dict) and o.get("effects") for o in opts_list)
    skeleton = (not text) and not has_effects  # reference skeleton vs runtime card
    body = text or str(card.get("summary", "") or "")

    # text length + sentences (RUNTIME only — skeleton summaries are intentionally short)
    if text and not skeleton:
        nw, ns = len(text.split()), _sentences(text)
        if not (WORDS_HARD[0] <= nw <= WORDS_HARD[1]):
            errs.append(f"{tag}: text {nw} words outside hard {WORDS_HARD}")
        elif not (WORDS_SOFT[0] <= nw <= WORDS_SOFT[1]):
            warns.append(f"{tag}: text {nw} words outside target {WORDS_SOFT}")
        if not (SENT_HARD[0] <= ns <= SENT_HARD[1]):
            errs.append(f"{tag}: {ns} sentences outside hard {SENT_HARD}")
        elif not (SENT_SOFT[0] <= ns <= SENT_SOFT[1]):
            warns.append(f"{tag}: {ns} sentences outside target {SENT_SOFT}")

    # banned / anachronistic terms (error on runtime text, warning on skeleton summary)
    if body:
        low = _ascii(body)
        for w in BANNED_HARD:
            if _banned_hit(low, w):
                (warns if skeleton else errs).append(f"{tag}: banned term '{w}' (4th-wall/anachronism)")
        for w in BANNED_EXTENDED:
            if _banned_hit(low, w):
                warns.append(f"{tag}: anachronistic term '{w}'")

    # options
    if not isinstance(opts, list) or len(opts) != 3:
        errs.append(f"{tag}: must have exactly 3 options (got {len(opts) if isinstance(opts, list) else 'n/a'})")
    unlock_count = 0
    for i, opt in enumerate(opts_list):
        otag = f"{tag}.opt[{i}]"
        if not isinstance(opt, dict):
            errs.append(f"{otag}: not an object")
            continue
        if not str(opt.get("label", "")).strip():
            errs.append(f"{otag}: missing label")
        verb = opt.get("verb")
        if verb is not None and _ascii(verb) not in ALL_VERBS:
            warns.append(f"{otag}: verb '{verb}' out of the 45-verb list (engine maps to esprit)")
        fac = opt.get("primary_faction") or opt.get("faction")
        if fac and fac not in FACTIONS and fac != "neutre":
            errs.append(f"{otag}: faction '{fac}' not in {FACTIONS}")
        effs = opt.get("effects", [])
        if isinstance(effs, list) and effs:
            if len(effs) > EFFECT_CAPS["effects_per_option"]:
                errs.append(f"{otag}: {len(effs)} effects > cap {EFFECT_CAPS['effects_per_option']}")
            for e in effs:
                t, amt, ef = _parse_effect(e)
                if t and t not in ALLOWED_EFFECT_TYPES:
                    errs.append(f"{otag}: effect type '{t}' not allowed")
                if t == "ADD_REPUTATION":
                    if ef and ef not in FACTIONS:
                        errs.append(f"{otag}: ADD_REPUTATION faction '{ef}' invalid")
                    if amt is not None and not (EFFECT_CAPS['ADD_REPUTATION']['min'] <= amt <= EFFECT_CAPS['ADD_REPUTATION']['max']):
                        errs.append(f"{otag}: reputation {amt} outside ±20")
                cap = EFFECT_CAPS.get(t, {})
                if amt is not None and "max" in cap and abs(amt) > cap["max"]:
                    errs.append(f"{otag}: {t} |{amt}| > cap {cap['max']}")
                if t == "UNLOCK_OGHAM":
                    unlock_count += 1
    if unlock_count > EFFECT_CAPS["UNLOCK_OGHAM"]["max_per_card"]:
        errs.append(f"{tag}: {unlock_count} UNLOCK_OGHAM > 1/card")

    # repetition vs recent
    if recent_texts and body:
        for prev in recent_texts:
            if jaccard(body, prev) >= JACCARD_MAX:
                warns.append(f"{tag}: Jaccard ≥ {JACCARD_MAX} vs a recent card (repetition)")
                break
    return errs, warns


def validate_scenario(scn: dict):
    errs, warns = [], []
    if not isinstance(scn, dict):
        return ["scenario is not an object"], []
    cards = scn.get("cards", [])
    if not isinstance(cards, list) or not cards:
        return [f"scenario[{scn.get('id','?')}]: no cards"], []
    recent = []
    for card in cards:
        e, w = validate_card(card, recent_texts=recent[-5:])
        errs += e
        warns += w
        t = str(card.get("text", card.get("summary", "")) or "")
        if t:
            recent.append(t)
    return errs, warns


# ── file dispatch ────────────────────────────────────────────────────────────
def _extract_card_from_chatml(obj):
    """Training jsonl: {conversations:[...]} or {messages:[...]} with assistant=JSON card."""
    msgs = obj.get("conversations") or obj.get("messages") or []
    for m in reversed(msgs):
        if m.get("role") == "assistant":
            c = m.get("content", "")
            try:
                return json.loads(c)
            except Exception:
                mm = re.search(r"\{.*\}", c, re.S)
                if mm:
                    try:
                        return json.loads(mm.group(0))
                    except Exception:
                        return None
    return None


def validate_obj(obj):
    """Route any object to scenario/card/chatml validation."""
    if isinstance(obj, dict):
        if "cards" in obj:
            return validate_scenario(obj)
        if "conversations" in obj or "messages" in obj:
            card = _extract_card_from_chatml(obj)
            if card is None:
                return ["chatml sample: assistant content is not JSON"], []
            return validate_scenario(card) if "cards" in card else validate_card(card)
        if "options" in obj or "text" in obj:
            return validate_card(obj)
    if isinstance(obj, list):
        e, w = [], []
        for o in obj:
            ee, ww = validate_obj(o)
            e += ee
            w += ww
        return e, w
    return ["unrecognized object shape"], []


def validate_file(path):
    units = []
    if path.endswith(".jsonl"):
        with open(path, encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if ln:
                    units.append(json.loads(ln))
    else:
        data = json.load(open(path, encoding="utf-8"))
        units = data if isinstance(data, list) else [data]
    results = []
    for u in units:
        results.append(validate_obj(u))
    return results


# ── selftest ─────────────────────────────────────────────────────────────────
def _selftest():
    good = {"id": "t1", "cards": [{
        "card_id": "c1",
        "text": "La mousse sous tes pieds fremit comme une langue qui se souvient de ton nom. "
                "Le vieux chene incline ses branches vers toi, patient. Quelque chose attend, "
                "tapi sous les racines, et la brume retient son souffle. Choisiras-tu d'ecouter ?",
        "options": [
            {"label": "Ecouter la foret", "verb": "ecouter", "primary_faction": "druides",
             "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}]},
            {"label": "Examiner les racines", "verb": "examiner", "primary_faction": "anciens",
             "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
            {"label": "S'approcher du chene", "verb": "s'approcher", "primary_faction": "neutre",
             "effects": [{"type": "ADD_ANAM", "amount": 2}]},
        ]}]}
    bad = {"id": "t2", "cards": [{
        "card_id": "c1", "text": "Tu ouvres l'interface de simulation.",  # banned + too short
        "options": [
            {"label": "Hack", "verb": "hacker", "effects": [{"type": "GIVE_GOLD", "amount": 999}]},
            {"label": "Wait", "verb": "attendre", "effects": [{"type": "ADD_REPUTATION", "faction": "klingon", "amount": 80}]},
        ]}]}
    ge, gw = validate_obj(good)
    be, bw = validate_obj(bad)
    print("GOOD errors:", ge)
    print("GOOD warns :", gw)
    print("BAD  errors:", be)
    ok = (len(ge) == 0) and (len(be) >= 4)
    print("SELFTEST", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main(argv):
    _load_canon_overrides()
    if "--selftest" in argv:
        return _selftest()
    args = [a for a in argv[1:] if not a.startswith("--")]
    strict = "--strict" in argv
    if not args:
        print(__doc__)
        return 2
    path = args[0]
    results = validate_file(path)
    n = len(results)
    n_err = sum(1 for e, w in results if e)
    n_warn = sum(1 for e, w in results if w and not e)
    total_e = sum(len(e) for e, w in results)
    total_w = sum(len(w) for e, w in results)
    for i, (e, w) in enumerate(results):
        for msg in e:
            print(f"  [{i}] ERROR  {msg}")
        for msg in w:
            print(f"  [{i}] warn   {msg}")
    print(f"\n{n} units | {n - n_err} pass | {n_err} with errors | {n_warn} warn-only "
          f"| {total_e} errors, {total_w} warnings")
    fail = total_e > 0 or (strict and total_w > 0)
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
