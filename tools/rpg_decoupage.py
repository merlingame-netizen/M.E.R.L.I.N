#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""rpg_decoupage — segment a run into ACTES -> CARTES -> BEATS (les 3 lies).

The bible (GAME_DESIGN_BIBLE v3.5 §6.4) names "5 actes x 5 cartes = 25" but
never formalises acts or sub-card beats. This module formalises the hierarchy
the first time, *backend-agnostically*: it consumes a v731-shaped trace dict
(`cards_played` + `intro`/`outro`), so the SAME code runs on the native
(embedded llama.cpp) trace once the GDExtension .dll lands — no Ollama
dependency here.

Three linked levels:
  ACTE   (x5)        = the 5 narrative movements, given concrete names
                       (replaces enigmatic leads like "La trame se resserre").
  CARTE  (x5/acte)   = a decision node (what v731 calls a "beat").
  BEAT   (x4/carte)  = mise en scene -> choix -> resolution -> consequence,
                       with a CAUSAL bridge threading each consequence into the
                       next card (logique, pas enigmatique).

Pure functions + frozen dataclasses; no LLM calls, no I/O.
"""
from __future__ import annotations

from dataclasses import dataclass


# (name, narrative function) per act index 1..5 — concrete, not enigmatic.
ACT_NAMES: list[tuple[str, str]] = [
    ("L'Appel", "Mise en place"),
    ("La Descente", "Première descente"),
    ("La Bascule", "Bascule de Merlin"),
    ("L'Épreuve", "Approfondissement"),
    ("Le Dénouement", "Dénouement"),
]

_OUTCOME_TITLE = {"success": "Reussite", "partial": "Demi-succes", "failure": "Echec"}
_OUTCOME_BRIDGE = {
    "success": "et cela a porte",
    "partial": "a moitie",
    "failure": "mais cela a echoue",
}


@dataclass(frozen=True)
class Beat:
    """One RPG beat inside a card."""
    kind: str          # mise_en_scene | choix | resolution | consequence
    title: str         # short, player-facing label
    text: str          # human-readable beat content (no raw effect tokens)
    data: dict         # structured payload (options, effects, state delta...)


@dataclass(frozen=True)
class CardSegment:
    """A single card decomposed into its ordered beats + its causal bridge."""
    index: int
    act_index: int
    card_uid: str
    type: str
    rarity: str
    pole: str
    emotion: str
    summary: str
    beats: list[Beat]
    causal_link: str   # bridge from the previous card's consequence ("" for card 1)


@dataclass(frozen=True)
class Act:
    """A narrative act grouping its cards."""
    index: int
    name: str
    function: str
    summary: str
    cards: list[CardSegment]


# --- effect humanisation (no raw tokens reach the player) -------------------

def humanize_effect(eff: str) -> str:
    """Turn an engine effect string into plain readable French (ASCII).

    Accepts the real v731/MerlinEffectEngine formats:
      ADD_REPUTATION:faction:N  (or over-nested ADD_REPUTATION:f:faction:N)
      HEAL_LIFE:N  DAMAGE_LIFE:N  ADD_KARMA:N  ADD_ECLATS:N
      ADD_TAG:tag  PROMISE:to:due
    """
    parts = str(eff).split(":")
    v = parts[0]
    try:
        if v == "ADD_REPUTATION":
            if len(parts) >= 4:
                fac, amt = parts[2], int(parts[3])
            else:
                fac, amt = parts[1], int(parts[2])
            return f"reputation {fac} {'+' if amt > 0 else ''}{amt}"
        if v == "HEAL_LIFE":
            return f"vie +{int(parts[1])}"
        if v == "DAMAGE_LIFE":
            return f"vie -{int(parts[1])}"
        if v == "ADD_KARMA":
            amt = int(parts[1])
            return f"karma {'+' if amt > 0 else ''}{amt}"
        if v == "ADD_ECLATS":
            return f"{int(parts[1])} eclats"
        if v == "ADD_TAG":
            return f"souvenir : {parts[1]}" if len(parts) > 1 else "souvenir acquis"
        if v == "PROMISE":
            return f"promesse envers {parts[1]}" if len(parts) > 1 else "promesse scellee"
    except (IndexError, ValueError):
        pass
    return v.replace("_", " ").lower()


# --- beat layer -------------------------------------------------------------

def card_to_beats(card: dict) -> list[Beat]:
    """Decompose one card record into its 4 ordered beats."""
    # 1. Mise en scene — where you are, what you see. Prefer the LLM-stitched
    # bridge (transition_prose_llm) over the template when the stitcher ran.
    trans = (card.get("transition_prose_llm") or card.get("transition_prose") or "").strip()
    prose = (card.get("prose_long") or card.get("summary") or "").strip()
    mise_text = f"{trans} {prose}".strip() if trans else prose
    b_scene = Beat("mise_en_scene", "Mise en scene", mise_text,
                   {"summary": card.get("summary", "")})

    # 2. Choix — what you can do (3 options + which was taken).
    sigs = card.get("option_signals") or []
    opts = [
        {
            "label": o.get("label", ""),
            "verb": o.get("verb", ""),
            "faction": o.get("faction", "") or o.get("primary_faction", ""),
            "signal": o.get("signal", ""),
        }
        for o in sigs
    ]
    chosen_idx = int(card.get("chosen_option_idx", 0) or 0)
    choix_text = ("Tu peux : " + " / ".join(o["label"] for o in opts if o["label"])) \
        if opts else "Aucune option."
    b_choix = Beat("choix", "Choix", choix_text,
                   {"options": opts, "chosen_idx": chosen_idx})

    # 3. Resolution — what happened when you acted (outcome made explicit).
    dc = card.get("dc_result", "")
    b_res = Beat("resolution", _OUTCOME_TITLE.get(dc, "Issue"),
                 (card.get("resolution_prose") or "").strip(),
                 {"dc_result": dc})

    # 4. Consequence — how the world changed + what it means (no raw tokens).
    effects = list(card.get("effects_applied") or [])
    humanized = [humanize_effect(e) for e in effects]
    cons_text = " - ".join(humanized) if humanized else "Aucun effet notable."
    b_cons = Beat("consequence", "Consequence", cons_text,
                  {"effects": effects, "humanized": humanized,
                   "state_after": card.get("state_after", {})})

    return [b_scene, b_choix, b_res, b_cons]


# --- causal linking (logique, pas enigmatique) ------------------------------

def causal_bridge(prev_card: dict | None, this_card: dict) -> str:
    """One concrete line threading the previous card's action into this one.

    Empty for the first card of the run (nothing precedes it).
    """
    if not prev_card:
        return ""
    pv = ((prev_card.get("chosen_option") or {}).get("verb", "") or "").strip()
    outcome = _OUTCOME_BRIDGE.get(prev_card.get("dc_result", ""), "")
    this_sum = (this_card.get("summary") or "").strip()
    if not pv:
        return f"Te voici : {this_sum}." if this_sum else ""
    inner = " ".join(filter(None, [pv, outcome]))
    head = f"Ton geste precedent ({inner})"
    return f"{head} te mene ici : {this_sum}." if this_sum else f"{head}."


# --- act layer --------------------------------------------------------------

def _act_summary(function: str, cards: list) -> str:
    return f"{function} - {len(cards)} carte(s)."


def build_acts(trace: dict) -> list[Act]:
    """Build the 5 acts (always exactly 5, some may be empty) from a trace.

    Cards are assigned to an act by their ``movement`` field (1..5). The causal
    bridge references the immediately preceding card in run order, even across
    act boundaries.
    """
    cards = trace.get("cards_played") or []
    segments: list = []
    for idx, card in enumerate(cards):
        prev = cards[idx - 1] if idx > 0 else None
        segments.append(
            CardSegment(
                index=int(card.get("beat", idx + 1)),
                # Clamp to 1..5 so a stray movement (0, 6, null) is never
                # orphaned out of every act.
                act_index=max(1, min(5, int(card.get("movement", 1) or 1))),
                card_uid=card.get("card_uid", ""),
                type=card.get("type", ""),
                rarity=card.get("rarity", ""),
                pole=card.get("pole", ""),
                emotion=card.get("emotion", ""),
                summary=card.get("summary", ""),
                beats=card_to_beats(card),
                causal_link=causal_bridge(prev, card),
            )
        )
    acts: list = []
    for ai in range(1, 6):
        name, func = ACT_NAMES[ai - 1]
        act_cards = [s for s in segments if s.act_index == ai]
        acts.append(Act(ai, name, func, _act_summary(func, act_cards), act_cards))
    return acts


# --- metrics (variete + logique) --------------------------------------------

def _chosen_verb(seg: "CardSegment") -> str:
    for b in seg.beats:
        if b.kind == "choix":
            opts = b.data.get("options", [])
            ci = b.data.get("chosen_idx", 0)
            if 0 <= ci < len(opts):
                return opts[ci].get("verb", "")
    return ""


def decoupage_metrics(acts: list) -> dict:
    """Variety + logic metrics over a segmented run.

    variete  : how non-repetitive the run is (unique chosen verbs, poles,
               emotions, card types).
    logique  : how causally threaded it is (share of cards that carry a
               backward causal bridge + a non-empty resolution beat).
    """
    segs = [c for a in acts for c in a.cards]
    total = len(segs)
    verbs, poles, emotions, types = set(), set(), set(), set()
    for s in segs:
        v = _chosen_verb(s)
        if v:
            verbs.add(v)
        if s.pole:
            poles.add(s.pole)
        if s.emotion:
            emotions.add(s.emotion)
        if s.type:
            types.add(s.type)
    causal = sum(1 for s in segs if s.causal_link)
    resolved = sum(
        1 for s in segs
        if any(b.kind == "resolution" and b.text for b in s.beats)
    )
    pct = (lambda num: round(num * 100.0 / total, 1) if total else 0.0)
    return {
        "variete": {
            "total_cards": total,
            "unique_verbs": len(verbs),
            "unique_poles": len(poles),
            "unique_emotions": len(emotions),
            "unique_types": len(types),
            "verb_diversity_pct": pct(len(verbs)),
        },
        "logique": {
            "causal_links": causal,
            "causal_coverage_pct": pct(causal),
            "resolution_coverage_pct": pct(resolved),
        },
        "acts": [{"index": a.index, "name": a.name, "cards": len(a.cards)} for a in acts],
    }
